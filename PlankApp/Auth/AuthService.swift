import Foundation
import Observation
import Supabase

// MARK: - AuthMethod

enum AuthMethod: String {
    case anonymous
    case apple
    case email
    case unknown
}

// MARK: - BootstrapState

enum BootstrapState: Equatable {
    case idle
    case running
    case ready
    case failed(String)
}

// MARK: - AuthService
//
// Single source of truth for the current Supabase user. On app launch,
// `bootstrap()` either restores an existing keychain-persisted session or
// signs the user in anonymously. After bootstrap completes, every user
// (anonymous or upgraded) has a stable `user_id` for the lifetime of the
// install.
//
// Anonymous-first means session 1 already has a user_id, so SessionLog +
// DayProgress writes attach to a real auth.uid() from the very first
// workout. When the user later upgrades via Apple or email, Supabase
// preserves the same user_id, so historical rows stay attached.

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var currentUser: User?
    private(set) var currentSession: Session?
    private(set) var bootstrapState: BootstrapState = .idle

    private var didStartBootstrap = false

    private init() {}

    // MARK: Derived state

    /// Always true after a successful bootstrap, even for anonymous users.
    /// Supabase treats anonymous sessions as authenticated for RLS purposes.
    var isAuthenticated: Bool { currentUser != nil }

    /// True for the anonymous-on-first-launch user, false after upgrade.
    var isAnonymous: Bool { currentUser?.isAnonymous ?? false }

    /// Whether the bootstrap has completed (success or failure). Drives
    /// the splash gate in PlankAIApp.
    var isReady: Bool {
        if case .ready = bootstrapState { return true }
        return false
    }

    var authMethod: AuthMethod {
        guard let user = currentUser else { return .unknown }
        if user.isAnonymous { return .anonymous }
        // Identity providers Supabase records on the User: "apple", "email", etc.
        if let providers = user.identities?.map(\.provider), !providers.isEmpty {
            if providers.contains("apple") { return .apple }
            if providers.contains("email") { return .email }
        }
        return .unknown
    }

    // MARK: Bootstrap

    /// Idempotent. Safe to call multiple times — only runs once.
    /// Restores an existing session if present, otherwise signs in anonymously.
    ///
    /// Each Supabase call is wrapped in a 10s timeout. Without it, a
    /// degraded network or a session stuck in refresh-loop state (see
    /// supabase-swift PR 822, the "Initial session emitted after
    /// attempting to refresh" warning) hangs the await forever and
    /// the entire app sits on the splash. The timeout converts that
    /// hang into the existing `.failed` state which RootView already
    /// renders as a retry prompt.
    func bootstrap() async {
        guard !didStartBootstrap else { return }
        didStartBootstrap = true
        bootstrapState = .running

        // 1. Try to restore an existing session from Keychain, then verify
        //    it against the server. If the user was deleted server-side
        //    (dashboard cleanup, schema reset, project wipe), the cached
        //    session JWT will reference a sub claim that no longer maps to
        //    a real user — every later API call would fail with
        //    "User from sub claim in JWT does not exist". We catch that
        //    here, sign the stale session out, and fall through to a
        //    fresh anonymous sign-in.
        // Prefer the synchronous, local Keychain read (currentSession) — a
        // valid cached token must never be blocked by a stalled network
        // refresh. Only fall back to the throwing `auth.session` getter
        // (which forces a server refresh, the call that hangs on degraded
        // networks) when there is no local session at all.
        let restoredSession: Session?
        if let localSession = supabase.auth.currentSession {
            restoredSession = localSession
        } else {
            restoredSession = await Self.withTimeout(seconds: 10) {
                try? await supabase.auth.session
            }
        }
        if let restored = restoredSession {
            let verifiedUser: User? = await Self.withTimeout(seconds: 10) {
                try? await supabase.auth.user()
            }
            if let user = verifiedUser {
                currentSession = restored
                currentUser = user
                bootstrapState = .ready
                return
            }
            // Stale session OR verify timed out. Drop it locally and
            // fall through to anonymous sign-in.
            try? await supabase.auth.signOut()
        }

        // 2. No session — sign in anonymously, with a short retry so a
        //    transient cold-start network stall (radio wake / DNS / captive
        //    portal) doesn't hard-fail a brand-new user on the first attempt.
        let signInResult: Session? = await Self.withRetry(maxAttempts: 2, baseDelay: 0.8) {
            await Self.withTimeout(seconds: 10) {
                try? await supabase.auth.signInAnonymously()
            }
        }
        if let session = signInResult {
            currentSession = session
            currentUser = session.user
            bootstrapState = .ready
        } else if let cached = supabase.auth.currentSession {
            // Fail-soft: restore + anonymous sign-in both failed (network
            // down, or a Supabase hang the timeout caught), but a cached
            // session is still in the Keychain. Open the app offline on that
            // identity rather than hard-blocking the splash with a retry
            // prompt — AppSync.retryPendingUpserts() reconciles when the
            // network returns. This is the common returning-user case the
            // 2026-06-04 timeout regression was bouncing to the error screen
            // purely because a token refresh stalled.
            currentSession = cached
            currentUser = cached.user
            bootstrapState = .ready
        } else {
            // No cached session AND retries exhausted — a genuine first-run
            // network failure. Surface the retry prompt.
            #if DEBUG
            print("[AuthService] bootstrap FAILED: timeout or network error")
            #endif
            Analytics.trackException(
                NSError(domain: "AuthService", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "bootstrap timed out or failed"]),
                context: "auth.bootstrap_failed"
            )
            bootstrapState = .failed("Make sure you're connected to the internet, then try again.")
            didStartBootstrap = false  // allow retry
        }
    }

    /// Returns a valid access token for a per-request authenticated API
    /// call (food-vision, canonical_pantry), REFRESHING the session first
    /// if the cached token is expired or near expiry.
    ///
    /// 2026-06-24 — the food tokenProviders previously read
    /// `currentSession?.accessToken`, a cached Keychain value that does NOT
    /// auto-refresh. Once a session passed its ~1h access-token lifetime,
    /// every scan sent an expired JWT and the Edge Function rejected it with
    /// 401 → `VisionError.notAuthenticated` ("food snap doesn't work
    /// anymore", PostHog confirmed). The throwing `auth.session` getter
    /// refreshes when needed (and is a cheap local check when the token is
    /// still valid); we bound it so a degraded-network refresh can't hang
    /// the scan, and fall back to the cached token if the refresh stalls.
    func freshAccessToken() async -> String? {
        let refreshed: Session? = await Self.withTimeout(seconds: 8) {
            try? await supabase.auth.session
        }
        if let refreshed {
            currentSession = refreshed
            return refreshed.accessToken
        }
        return currentSession?.accessToken ?? supabase.auth.currentSession?.accessToken
    }

    /// Race an async operation against a timeout. Returns the operation's
    /// result on success, nil on timeout. Static so it doesn't capture self.
    ///
    /// Uses a continuation + actor guard instead of `withTaskGroup` because
    /// TaskGroup waits for ALL child tasks to complete before returning,
    /// even after `cancelAll()`. If Supabase's network call doesn't honor
    /// cancellation (URLSession cancellation may not propagate through
    /// every Supabase code path), the TaskGroup deadlocks waiting for the
    /// hung task. With this pattern, whichever Task resumes the
    /// continuation first wins; the loser's eventual resume is a no-op
    /// (guard.tryFire returns false) and the loser keeps running in the
    /// background until it naturally completes — but the function caller
    /// has already moved on.
    private static func withTimeout<T: Sendable>(seconds: TimeInterval, _ op: @escaping @Sendable () async -> T?) async -> T? {
        let guardian = AuthBootstrapResumeGuard()

        return await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            Task {
                let result = await op()
                if await guardian.tryFire() {
                    continuation.resume(returning: result)
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if await guardian.tryFire() {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Retry an async operation up to `maxAttempts` times with exponential
    /// backoff between attempts, returning the first non-nil result (or nil
    /// if every attempt fails). Per-attempt timeouts are the caller's job —
    /// wrap the op in `withTimeout`. Static so it doesn't capture self.
    private static func withRetry<T: Sendable>(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        _ op: @escaping @Sendable () async -> T?
    ) async -> T? {
        var attempt = 0
        while true {
            if let result = await op() { return result }
            attempt += 1
            if attempt >= maxAttempts { return nil }
            let delay = baseDelay * Double(1 << (attempt - 1))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    /// Force a retry from the splash. Resets the run-once guard.
    func retryBootstrap() async {
        didStartBootstrap = false
        await bootstrap()
    }

    // MARK: Email upgrade (anonymous → email)

    /// Upgrade the current anonymous user to an email/password account.
    /// Supabase preserves the user_id across the upgrade, so every existing
    /// SessionLog/DayProgress/etc. row stays attached.
    ///
    /// If the project has email confirmation enabled, the user receives a
    /// confirmation email. `is_anonymous` flips to false and `email` is set
    /// once they confirm. Until confirmation, the email is stored on the user
    /// record but the anonymous flag may still read true.
    func signUpWithEmail(_ email: String, password: String) async throws {
        let user = try await supabase.auth.update(
            user: UserAttributes(email: email, password: password)
        )
        currentUser = user
        currentSession = try? await supabase.auth.session
    }

    // MARK: Email sign-in (returning user)

    /// Sign in to an existing email/password account. Used on a fresh install
    /// to recover a user who previously upgraded on another device.
    ///
    /// Note: this discards any anonymous session that was active. The
    /// anonymous user_id from this device's keychain is replaced by the
    /// signed-in user's user_id. Local SwiftData rows attached to the old
    /// anonymous id will not match auth.uid() under RLS — Phase F handles
    /// hydrating the new identity's data from Supabase.
    func signInWithEmail(_ email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(email: email, password: password)
        currentSession = session
        currentUser = session.user
    }

    // MARK: Password reset

    /// Send a password reset email. The user clicks a link from their inbox
    /// that lets them set a new password. No state change here.
    func sendPasswordReset(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }

    // MARK: Delete account

    /// Permanently delete the current user from Supabase. Calls the
    /// SECURITY DEFINER RPC `public.delete_user_account()` which removes
    /// the auth.users row; ON DELETE CASCADE on the user-data tables
    /// removes everything else (public.users, session_logs, day_progress,
    /// session_ratings, exercise_calibrations). RPC-only — local SwiftData
    /// + UserDefaults cleanup is the caller's responsibility (AppSync
    /// orchestrates).
    func deleteAccount() async throws {
        #if DEBUG
        let uid = currentUser?.id.uuidString ?? "<nil>"
        print("[AuthService] deleteAccount: calling RPC delete_user_account for user_id=\(uid)")
        #endif
        do {
            let response = try await supabase.rpc("delete_user_account").execute()
            #if DEBUG
            print("[AuthService] deleteAccount: RPC returned status=\(response.status)")
            #endif
        } catch {
            #if DEBUG
            print("[AuthService] deleteAccount FAILED: \(error)")
            print("[AuthService] error type: \(type(of: error))")
            print("[AuthService] error localizedDescription: \(error.localizedDescription)")
            let mirror = Mirror(reflecting: error)
            for child in mirror.children {
                if let label = child.label {
                    print("[AuthService] error.\(label) = \(child.value)")
                }
            }
            #endif
            throw error
        }
    }

    // MARK: Sign out

    /// Sign out of the Supabase session, then immediately bootstrap a new
    /// anonymous session so the app always has a valid auth.uid(). Local
    /// SwiftData is preserved (the old user_id rows stay on disk for
    /// offline reading) but won't sync to Supabase under the new identity
    /// until the user signs back in. Phase F handles the re-hydration
    /// semantics when an identity change happens.
    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
        currentSession = nil
        didStartBootstrap = false
        await bootstrap()
    }

    // MARK: Apple Sign-In

    /// Run Sign in with Apple, then exchange the identity token for a
    /// Supabase session. Like email upgrade, this preserves the user_id
    /// when called from an anonymous session — the anonymous account links
    /// to the Apple identity rather than getting replaced.
    ///
    /// First-time authorizations: Apple sends `fullName` exactly once. If
    /// we get it and the local userName is still empty, we capture it.
    /// Subsequent sign-ins won't include fullName; that's expected.
    ///
    /// "Hide my email" is transparent here — Apple gives us a relay
    /// address (xxx@privaterelay.appleid.com), we hand it to Supabase
    /// the same way as a real email.
    func signInWithApple() async throws {
        let service = AppleSignInService()
        let result = try await service.signIn()
        try await completeAppleSignIn(
            idToken: result.identityToken,
            rawNonce: result.rawNonce,
            fullName: result.fullName
        )
    }

    /// Token-exchange portion of Apple Sign-In, separate from the
    /// authorization phase. SignInPromptView uses Apple's first-class
    /// `SignInWithAppleButton` (HIG-compliant), which runs its own
    /// ASAuthorizationController under the hood and hands us the credential
    /// in `onCompletion` — we hand the resulting identity token + raw nonce
    /// here for the same Supabase exchange the programmatic path uses.
    func completeAppleSignIn(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws {
        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: rawNonce
            )
        )
        currentSession = session
        currentUser = session.user

        if let nameComponents = fullName {
            let formatted = PersonNameComponentsFormatter().string(from: nameComponents)
            let existing = UserDefaults.standard.string(forKey: "userName") ?? ""
            if !formatted.isEmpty && existing.isEmpty {
                UserDefaults.standard.set(formatted, forKey: "userName")
            }
        }
    }
}

/// File-scoped because Swift doesn't allow nested actor types inside
/// generic functions (the natural place for it, inside withTimeout,
/// produces "Type 'ResumeGuard' cannot be nested in generic function").
/// Used by AuthService.withTimeout to atomically pick a winner between
/// the racing operation and the timeout sleep.
fileprivate actor AuthBootstrapResumeGuard {
    private var fired = false
    func tryFire() -> Bool {
        if fired { return false }
        fired = true
        return true
    }
}
