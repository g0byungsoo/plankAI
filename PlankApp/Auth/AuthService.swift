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

// MARK: - VerifyFailureClass
//
// Why a restored session's server verification failed. The distinction is
// the whole fix for the 2026-07 re-key bug: only a DEFINITIVE server
// rejection may destroy the keychain session. Everything else (timeout,
// offline, captive portal, 5xx, rate limit) keeps the session and proceeds
// optimistically; the SDK's auto-refresh reconciles when the network
// returns. Destroying the only credential on a transient failure minted a
// brand-new anonymous user_id, orphaning every userId-scoped row and the
// RevenueCat entitlement.

enum VerifyFailureClass: Equatable {
    /// Network-ish failure, the server never told us this session is bad.
    /// Keep the session, proceed with the cached user.
    case transient
    /// The auth server explicitly rejected this session/user
    /// (user deleted, refresh token revoked/reused, 401/403).
    case definitive
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

    /// True when a LINKED (Apple/email) identity's session was definitively
    /// rejected by the auth server and the app fell back to a fresh
    /// anonymous session. The UI should prompt a re-sign-in; the linked
    /// account's cloud data is fully recoverable through
    /// `signInWithEmail` / `signInWithApple`, which also clear this flag.
    /// Never set for anonymous users (nothing to re-sign into).
    ///
    /// Persisted (release audit 2026-08-08): the flag used to be
    /// in-memory only, so a linked user who missed the one prompt
    /// lived on an empty anonymous account with no further signal —
    /// the fallback anon session restores cleanly on the next launch
    /// and nothing ever re-raised the sheet. The didSet mirror keeps
    /// the prompt alive across launches until a sign-in resolves it.
    private(set) var needsReauth: Bool = UserDefaults.standard.bool(forKey: "auth.needsReauth") {
        didSet { UserDefaults.standard.set(needsReauth, forKey: "auth.needsReauth") }
    }

    private var didStartBootstrap = false

    /// Set by `signOut()` (also the delete-account flow, which funnels
    /// through it) so the auth-event listener can tell an app-initiated
    /// `.signedOut` apart from an SDK-initiated session wipe (e.g. a
    /// refresh-token rotation race → `refresh_token_already_used` →
    /// sessionManager.remove()). Consumed by the listener.
    private var isAppInitiatedSignOut = false

    /// Long-lived subscription to `supabase.auth.authStateChanges`.
    /// Started once, on first bootstrap. Never cancelled: AuthService is
    /// a process-lifetime singleton.
    private var authEventsTask: Task<Void, Never>?

    /// Re-entrancy guard for the mid-run anonymous recovery path.
    private var isRecoveringAnonSession = false

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
        return Self.method(
            isAnonymous: user.isAnonymous,
            identityProviders: user.identities?.map(\.provider) ?? [],
            appMetadataProviders: (user.appMetadata["providers"]?.arrayValue ?? [])
                .compactMap(\.stringValue)
        )
    }

    /// v25 §40 — THE SECOND SOURCE IS NOT A NICETY, IT IS THE ONLY ONE
    /// THAT IS POPULATED IMMEDIATELY AFTER A LINK.
    ///
    /// `linkIdentityWithIdToken` returns the session GoTrue built from
    /// the user it loaded BEFORE the link, and `createNewIdentity` never
    /// appends to that in-memory user's `identities` (read from
    /// `internal/api/identity.go`). It DOES call
    /// `UpdateAppMetaDataProviders`, so the response carries
    /// `app_metadata.providers = ["apple"]` and an EMPTY `identities`
    /// array.
    ///
    /// Reading `identities` alone therefore returned `.unknown` for the
    /// whole session after a successful link, which is not cosmetic:
    /// `AppleRevocationPolicy` requires `.apple` before it will honour a
    /// revocation notice, `DeleteAccountCopy` requires `.apple` before it
    /// will show Apple's manual-revocation step, and `onAuthChanged`'s
    /// `upgraded` branch requires `.apple`/`.email` before it re-upserts
    /// the profile. All three stood down for exactly the customers `39`'s
    /// fix was built for, until the next launch re-read the user from the
    /// server.
    ///
    /// Nonisolated + pure so it is testable without a session.
    nonisolated static func method(
        isAnonymous: Bool,
        identityProviders: [String],
        appMetadataProviders: [String]
    ) -> AuthMethod {
        if isAnonymous { return .anonymous }
        let providers = identityProviders + appMetadataProviders
        if providers.contains("apple") { return .apple }
        if providers.contains("email") { return .email }
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
        startAuthEventListener()

        // v25 §39 — TN3194 step 3. Idempotent, process-lifetime, and
        // beside the auth-event listener because it is the same kind of
        // thing: a signal from outside the app that our identity is no
        // longer what we think it is.
        AppleCredentialWatcher.start {
            await AppSync.shared.handleAppleCredentialRevoked()
        }

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
            // Verify against the server, but CLASSIFY the failure instead
            // of treating every miss as a stale session. The old code
            // (`try? ...` + signOut on nil) destroyed the only credential
            // on a plain timeout, minting a new anonymous identity that
            // orphaned all of the user's data. The verify exists (b13e12c)
            // to catch server-side user deletion; it must fail OPEN, not
            // fail destructive.
            let verifyResult: Result<User, any Error>? = await Self.withTimeout(seconds: 10) {
                do {
                    return .success(try await supabase.auth.user())
                } catch {
                    return .failure(error)
                }
            }

            let failureClass: VerifyFailureClass
            switch verifyResult {
            case .success(let user):
                currentSession = supabase.auth.currentSession ?? restored
                currentUser = user
                bootstrapState = .ready
                return
            case .failure(let error):
                failureClass = Self.classifyVerifyFailure(error)
            case nil:
                // Timed out: the server never answered. Transient by
                // definition.
                failureClass = .transient
            }

            if failureClass == .transient {
                // Offline / degraded network / 5xx. Keep the session and
                // open the app on the cached identity; the SDK's
                // auto-refresh reconciles when the network returns, and
                // AppSync.retryPendingUpserts() catches up the writes.
                currentSession = supabase.auth.currentSession ?? restored
                currentUser = restored.user
                bootstrapState = .ready
                return
            }

            // DEFINITIVE rejection: the server said this session/user is
            // gone (deleted user, revoked/reused refresh token, 401/403).
            // For an anonymous user there is nothing to recover: drop the
            // stale session and fall through to a fresh anonymous sign-in
            // (pre-fix behavior, and the only possible move).
            // For a LINKED (Apple/email) user, the account still exists in
            // the cloud, so never re-key silently. We still fall through to
            // an anonymous session so the app has a valid auth.uid(), but
            // raise `needsReauth` so the UI can prompt a re-sign-in that
            // restores the linked identity and its data.
            let wasLinkedIdentity = !restored.user.isAnonymous
            // Local cleanup; if the SDK already removed the session as part
            // of mapping the error (session-cleanup codes), this is a no-op.
            try? await supabase.auth.signOut()
            if wasLinkedIdentity {
                needsReauth = true
                #if DEBUG
                print("[AuthService] bootstrap: linked session definitively rejected, needsReauth raised")
                #endif
                Analytics.trackException(
                    NSError(domain: "AuthService", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "linked session invalidated; reauth needed"]),
                    context: "auth.session_invalidated_needs_reauth"
                )
            }
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
            // Fail-soft: anonymous sign-in failed but a cached session is
            // still in the Keychain. Open the app offline on that identity
            // rather than hard-blocking the splash with a retry prompt;
            // AppSync.retryPendingUpserts() reconciles when the network
            // returns. With the transient-keep fix above, the common
            // offline-returning-user case exits earlier (restored session
            // kept on a transient verify failure); this branch is the
            // last-resort net for exotic states where the restore read
            // itself came up empty but a session appeared since.
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
    /// `withTimeout` cancels the losing refresh on timeout, so a stalled
    /// refresh can't finish minutes later and write a stale session over
    /// whatever the Keychain holds by then.
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
    /// (guard.tryFire returns false).
    ///
    /// The losing operation is CANCELLED when the timeout wins. Before this
    /// (2026-07), the orphaned task kept running and could complete minutes
    /// later, e.g. a slow token refresh finishing AFTER bootstrap had
    /// already re-keyed to a new anonymous user, overwriting the Keychain
    /// with the OLD user's session (identity flapping). Supabase's async
    /// calls ride URLSession, which honors Task cancellation; if a
    /// particular code path doesn't, the guard still makes the late resume
    /// a no-op; cancellation just closes the keychain-overwrite window.
    private static func withTimeout<T: Sendable>(seconds: TimeInterval, _ op: @escaping @Sendable () async -> T?) async -> T? {
        let guardian = AuthBootstrapResumeGuard()

        return await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            let opTask = Task {
                let result = await op()
                if await guardian.tryFire() {
                    continuation.resume(returning: result)
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if await guardian.tryFire() {
                    opTask.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: Verify-failure classification

    /// Error codes that mean the auth server has EXPLICITLY rejected this
    /// session or user: the credential is dead and keeping it can't help.
    /// Mirrors the SDK's own sessionCleanupErrorCodes plus user-level
    /// rejections. Everything not matched here fails open as transient.
    private nonisolated static let definitiveRejectionCodes: Set<ErrorCode> = [
        .userNotFound,
        .sessionNotFound,
        .sessionExpired,
        .refreshTokenNotFound,
        .refreshTokenAlreadyUsed,
        .userBanned,
    ]

    /// Pure classifier for a failed `supabase.auth.user()` verification.
    /// Nonisolated so unit tests can call it off the main actor.
    ///
    /// Rules:
    /// - `AuthError.sessionMissing` → definitive. The SDK maps the
    ///   session-cleanup codes (session_not_found, session_expired,
    ///   refresh_token_not_found, refresh_token_already_used) to this case
    ///   after removing the local session itself (APIClient.swift).
    /// - `AuthError.jwtVerificationFailed` → definitive (local JWT check).
    /// - `AuthError.api` → definitive when the error code is in
    ///   `definitiveRejectionCodes` OR the HTTP status is 401/403;
    ///   transient otherwise (5xx, 429 rate limits, unknown codes).
    /// - Any other error (URLError offline/timeout, CancellationError,
    ///   decode hiccups) → transient. The server never told us the session
    ///   is bad, so we must not destroy it.
    nonisolated static func classifyVerifyFailure(_ error: any Error) -> VerifyFailureClass {
        guard let authError = error as? AuthError else {
            return .transient
        }
        switch authError {
        case .sessionMissing:
            return .definitive
        case .jwtVerificationFailed:
            return .definitive
        case let .api(_, errorCode, _, response):
            if definitiveRejectionCodes.contains(errorCode) { return .definitive }
            if response.statusCode == 401 || response.statusCode == 403 { return .definitive }
            return .transient
        default:
            return .transient
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

    // MARK: Auth event stream

    /// Subscribe to the SDK's auth events. Without this (pre-2026-07), an
    /// SDK-initiated session wipe mid-run (refresh-token rotation race →
    /// refresh_token_already_used → sessionManager.remove() + .signedOut)
    /// left the app holding a stale in-memory currentUser, then silently
    /// re-keyed on the next launch. Idempotent; started from bootstrap().
    private func startAuthEventListener() {
        guard authEventsTask == nil else { return }
        authEventsTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                self.handleAuthEvent(event, session: session)
            }
        }
    }

    private func handleAuthEvent(_ event: AuthChangeEvent, session: Session?) {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
            // Keep the in-memory identity coherent with the SDK's view.
            // A refresh rotates the access token; adopting it here means
            // currentSession is never the stale pre-refresh one.
            if event == .signedIn { isAppInitiatedSignOut = false }
            if let session {
                currentSession = session
                currentUser = session.user
            }

        case .signedOut, .userDeleted:
            // App-initiated: signOut() / delete-account manage their own
            // state and immediately re-bootstrap. Consume the flag and
            // stand down.
            if isAppInitiatedSignOut {
                isAppInitiatedSignOut = false
                return
            }
            // During bootstrap, the verify path owns classification:
            // the SDK emits .signedOut while mapping session-cleanup
            // codes, and reacting here would race the fall-through
            // anonymous sign-in.
            if bootstrapState == .running { return }

            // SDK-initiated wipe mid-run.
            #if DEBUG
            print("[AuthService] SDK-initiated \(event), recovering (anonymous=\(isAnonymous))")
            #endif
            if let user = currentUser, !user.isAnonymous {
                // Linked identity: the account still exists in the cloud.
                // Keep currentUser as the last-known identity (userId-scoped
                // reads stay stable), drop the dead session, and prompt a
                // re-sign-in instead of silently minting a new user_id.
                currentSession = nil
                needsReauth = true
                Analytics.trackException(
                    NSError(domain: "AuthService", code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "sdk wiped linked session mid-run"]),
                    context: "auth.sdk_signout_needs_reauth"
                )
            } else {
                // Anonymous: the refresh token is dead and there is no
                // account to sign back into, so controlled re-anon is the
                // only recovery. Same trade-off bootstrap makes for a
                // definitively rejected anonymous session.
                currentSession = nil
                Task { await self.recoverAnonymousSession() }
            }

        case .passwordRecovery, .mfaChallengeVerified:
            break
        }
    }

    /// Mid-run recovery after the SDK wiped an anonymous session: mint a
    /// fresh anonymous identity so the app keeps a valid auth.uid().
    private func recoverAnonymousSession() async {
        guard !isRecoveringAnonSession else { return }
        isRecoveringAnonSession = true
        defer { isRecoveringAnonSession = false }
        let session: Session? = await Self.withRetry(maxAttempts: 2, baseDelay: 0.8) {
            await Self.withTimeout(seconds: 10) {
                try? await supabase.auth.signInAnonymously()
            }
        }
        if let session {
            currentSession = session
            currentUser = session.user
        }
        // On failure, leave the last-known currentUser in place for offline
        // reads; the next launch's bootstrap runs the full recovery ladder.
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
        // v25 §40 — captured BEFORE the switch, because the shared
        // client's session belongs to the incoming account a line later
        // and this is the last instant a credential for the outgoing
        // anonymous account exists anywhere. In memory only; a bearer
        // token is never written to disk.
        let outgoingUid = currentUser?.id.uuidString
        let outgoingWasAnonymous = isAnonymous
        let outgoingToken = currentSession?.accessToken
            ?? supabase.auth.currentSession?.accessToken

        let session = try await supabase.auth.signIn(email: email, password: password)
        currentSession = session
        currentUser = session.user
        // A successful sign-in IS the re-auth the invalidated-session
        // state was asking for.
        needsReauth = false

        // The email UPGRADE (`signUpWithEmail` → `auth.update(user:)`)
        // is untouched and still preserves the uid — proven in
        // production at 278 of 278 real conversions (§40 §7). THIS is
        // the other email door: a RETURNING customer reaching an
        // existing account, which abandons the anonymous uid exactly the
        // way the Apple fallback does.
        await retireAbandonedAnonymousAccount(
            outgoingUid: outgoingUid,
            outgoingWasAnonymous: outgoingWasAnonymous,
            outgoingToken: outgoingToken,
            incomingUid: session.user.id.uuidString
        )
    }

    // MARK: Retire an abandoned anonymous account (v25 §40)

    /// Called immediately after ANY sign-in that could have replaced an
    /// anonymous session. Does nothing at all unless the outgoing
    /// session was anonymous AND the incoming session names a different
    /// account — see `AnonymousRetirementPolicy` for why the outcome,
    /// and not the error, is the signal.
    ///
    /// Best-effort by construction: it cannot throw, it cannot fail a
    /// sign-in, and it is never shown to the customer. If it does not
    /// land, the result is exactly today's behaviour — an orphan — so
    /// there is no input for which this is worse than shipping nothing.
    ///
    /// The LOCAL half is not this function's job and must not be:
    /// `AppSync.onAuthChanged` re-keys the local rows to the incoming
    /// account and marks them `pendingUpsert`, which is what actually
    /// moves her record. The two are order-independent — the merge acts
    /// on local rows and pushes under the new uid, this acts on the old
    /// uid's server rows, and neither can see the other's work.
    @discardableResult
    func retireAbandonedAnonymousAccount(
        outgoingUid: String?,
        outgoingWasAnonymous: Bool,
        outgoingToken: String?,
        incomingUid: String,
        handoffOpened: Bool = false
    ) async -> AnonymousAccountRetirement.Outcome {
        let decision = AnonymousRetirementPolicy.decide(
            outgoingUid: outgoingUid,
            outgoingWasAnonymous: outgoingWasAnonymous,
            outgoingAccessToken: outgoingToken,
            incomingUid: incomingUid
        )

        // v25 §40 — THE MERGE RECEIPT IS WRITTEN AT THE SWITCH, NOT WHEN
        // THE MERGE STARTS.
        //
        // `AppSync.onAuthChanged` writes this marker before it re-keys,
        // which makes the merge crash-safe from that point on — but it
        // is driven by a SwiftUI `onChange`, so there is a window
        // between the session changing here and the merge beginning at
        // all. A process death inside that window left the local rows
        // keyed to a uid the app would never use again, with nothing
        // anywhere recording that a merge was owed. Written here it is
        // owed from the instant the identity moves, and `onLaunch`'s
        // `resumePendingMergeIfNeeded` finishes it at the next launch.
        //
        // Same pair, so `onAuthChanged` writing it again is a no-op, and
        // it is still cleared only after the retry push has had its shot.
        // Gated on the SAME condition as the retirement: an anonymous
        // period moving into an account, never an account into another.
        //
        // v25 §42 — AND IT CARRIES THE ID POLICY, WRITTEN BEFORE THE
        // CALL THAT DECIDES IT.
        //
        // `.preserve` the moment a receipt EXISTS, because the two wrong
        // guesses are not symmetrical. Guessing `.mintFresh` when the
        // server did move duplicates her entire record and cannot be
        // undone; guessing `.preserve` when it did not leaves her rows
        // re-keyed locally and unpushed, which the very next launch
        // repairs by completing the still-open receipt. **A marker is
        // never downgraded from `.preserve`**, because "the server may
        // already have moved these rows" is not a fact that expires.
        //
        // When no receipt was opened — the migration is not applied, the
        // BEGIN was offline, the id token carried no `sub` — the policy
        // is unambiguously the legacy one and this is exactly build 31.
        if case let .retire(uid) = decision {
            AppSync.writePendingMergeMarker(
                from: uid, to: incomingUid,
                idPolicy: handoffOpened ? .preserve : .mintFresh
            )
        }

        // v25 §42 — **COMPLETE, AS THE DESTINATION, AND IT IS THE WHOLE
        // POINT OF THE MIGRATION.**
        //
        // The session now belongs to B, whose credential is permanent
        // and legitimately hers, so this call needs no token for A and
        // never will — which is precisely the property `40` said it
        // could not have. It runs on EVERY successful Apple sign-in that
        // landed on a permanent account, not only on an adopt, because
        // it is also what closes the receipt a same-uid UPGRADE opened
        // before the link.
        var serverRetiredTheSource = false
        if !isAnonymous, let destinationToken = currentSession?.accessToken,
           !destinationToken.isEmpty {
            let outcome = await AccountHandoff.complete(accessToken: destinationToken, mode: "move")
            serverRetiredTheSource = outcome.retiredTheSource
            #if DEBUG
            print("[AuthService] handoff COMPLETE: \(outcome)")
            #endif
        }

        guard case let .retire(sourceUid) = decision, let token = outgoingToken else {
            if case let .leave(reason) = decision { return .skipped(reason) }
            return .skipped(.noCredential)
        }

        // ▎ ONLY THE SERVER MAY DECLARE THE TRANSITION COMPLETE — and
        // ▎ when it has, the client's one best-effort attempt has nothing
        // ▎ left to attempt.
        //
        // The legacy retirement is NOT removed (`41` §31 step 5: it
        // should probably never be). It is the only thing that works
        // when the network dies between BEGIN and COMPLETE, and it is
        // the whole behaviour on a project where the migration has not
        // been applied.
        if serverRetiredTheSource {
            return .retired
        }

        // v25 §41 — [CORR] on `40` §3.4. The retirement's whole safety
        // argument rests on "the local store is a superset of A's server
        // rows", and there is one reachable state where it is not: a
        // reinstall re-adopts the Keychain session with an EMPTY store
        // and the launch hydrate has not landed yet. Retiring then
        // deletes the only copy that exists. `SourceRetirementSafety`
        // makes the trade explicit — never delete what this device is
        // not carrying, and accept an empty `auth.users` row instead.
        let carrying = AppSync.localFootprint(of: sourceUid)
        guard SourceRetirementSafety.mayRetire(sourceLocalRowCount: carrying) else {
            #if DEBUG
            print("[AuthService] retirement refused: this device carries no row for the outgoing account")
            #endif
            return .skipped(.nothingToCarry)
        }

        let outcome = await AnonymousAccountRetirement.retire(accessToken: token)
        #if DEBUG
        print("[AuthService] anonymous retirement outcome: \(outcome)")
        #endif
        if outcome != .retired {
            // Categorical only — no uid, no token, no email. It records
            // that an orphan was created, never whose.
            Analytics.trackException(
                NSError(domain: "AuthService", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "anonymous account not retired at sign-in"]),
                context: "auth.anonymous_retirement_failed"
            )
        }
        return outcome
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
        // Mark the .signedOut event the SDK is about to emit as ours, so
        // the auth-event listener doesn't treat it as an SDK-initiated
        // wipe and fight the re-bootstrap below. The listener consumes
        // the flag; a subsequent .signedIn also clears it.
        isAppInitiatedSignOut = true
        needsReauth = false
        do {
            try await supabase.auth.signOut()
        } catch {
            // Release audit 2026-08-08 — fail-open, mirroring bootstrap:
            // the SDK removes the LOCAL session and emits .signedOut
            // BEFORE the server /logout POST, so a network error here
            // means the sign-out already happened on-device. Rethrowing
            // stranded the app half signed out — the caller's sweep had
            // run, the keychain session was gone, and no re-bootstrap
            // followed, so anything (re-)onboarded attached to a stale
            // uid that would never sync and could merge into the wrong
            // account later. The server token ages out on its own;
            // finish the local transition.
            #if DEBUG
            print("[AuthService] signOut: server revoke failed (\(error)) — continuing local sign-out")
            #endif
        }
        currentUser = nil
        currentSession = nil
        didStartBootstrap = false
        await bootstrap()
    }

    // MARK: Apple Sign-In

    /// Run Sign in with Apple, then exchange the identity token for a
    /// Supabase session.
    ///
    /// v25 §39 — THE COMMENT THAT USED TO SIT HERE WAS FALSE, AND THE
    /// PRODUCTION DATABASE PROVED IT WITHOUT AN EXCEPTION. It claimed
    /// this "preserves the user_id when called from an anonymous
    /// session"; all 559 Apple identities in production were created in
    /// the same instant as their uid (max gap ZERO seconds), while 278
    /// of 308 email identities were attached to a uid that already
    /// existed. `signInWithIdToken` posts to `/token?grant_type=id_token`
    /// with no Authorization header, so GoTrue mints a new user instead
    /// of linking. Everything recorded before the tap was left under the
    /// abandoned anonymous uid, where `delete_user_account()` (scoped to
    /// `auth.uid()`) can never reach it. `AppleIdentityPolicy` is the
    /// fix and states the whole argument.
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
            fullName: result.fullName,
            appleUserID: result.userIdentifier
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
        fullName: PersonNameComponents?,
        appleUserID: String? = nil
    ) async throws {
        let credentials = OpenIDConnectCredentials(
            provider: .apple,
            idToken: idToken,
            nonce: rawNonce
        )

        // v25 §39 — LINK FIRST, SO NO ORPHAN IS CREATED.
        //
        // `linkIdentityWithIdToken` hits the same endpoint with
        // `linkIdentity = true` and the current session's bearer token,
        // so GoTrue attaches the Apple identity to the uid this device
        // is already holding instead of minting a second one. No server
        // change, no migration, no config: the method is in the pinned
        // supabase-swift already.
        //
        // The fallback is not a nicety. A returning customer already has
        // an account under this Apple id, so the link is REFUSED
        // (`identity_already_exists`) and signing in is the correct
        // outcome. Every other failure lands in the same place on
        // purpose — a customer who cannot sign in is worse than an
        // orphaned anonymous uid, and this is the shipping call, so the
        // worst case here is exactly today's behaviour.
        let strategy = AppleIdentityPolicy.strategy(
            hasSession: currentSession != nil || supabase.auth.currentSession != nil,
            isAnonymous: isAnonymous
        )

        // v25 §40 — THE FALLBACK'S OWN ORPHAN. Captured before anything
        // switches, because `linkIdentityWithIdToken` is refused with
        // `identity_already_exists` for every RETURNING customer, the
        // fallback then signs into her existing account, and the
        // anonymous uid this device is holding is abandoned with
        // everything she recorded before the tap still under it. In
        // memory only, for the length of this function.
        let outgoingUid = currentUser?.id.uuidString
        let outgoingWasAnonymous = isAnonymous
        let outgoingToken = currentSession?.accessToken
            ?? supabase.auth.currentSession?.accessToken

        // v25 §42 — **BEGIN, WHILE SHE IS STILL THE ACCOUNT THAT OWNS
        // THE RECORD.**
        //
        // This is the only instant at which the association between the
        // anonymous account and the destination can be recorded ANYWHERE
        // durable, and `39` §4 proved that once it is lost it can never
        // be reconstructed. One RPC, with the outgoing token, writing a
        // receipt that names `auth.uid()` (never a parameter) and a
        // one-way digest of the Apple subject this device is about to
        // reach.
        //
        // It runs before the token exchange on purpose: after it, no
        // credential for her exists. And it is safe to run even when the
        // link is about to SUCCEED — the resulting receipt names the
        // caller as its own source, is unredeemable by anyone, and
        // `complete_account_handoff` deletes it on the next call.
        //
        // `handoffOpened` is a LOCAL fact about THIS call and is never
        // persisted, so a cancelled sheet, an email sign-in or a second
        // attempt with a different Apple ID cannot inherit it.
        var handoffOpened = false
        if outgoingWasAnonymous, let token = outgoingToken, !token.isEmpty,
           let subject = AccountHandoff.appleSubject(fromIdentityToken: idToken) {
            let opened = await AccountHandoff.begin(appleSubject: subject, accessToken: token)
            handoffOpened = opened == .opened
            #if DEBUG
            print("[AuthService] handoff BEGIN: \(opened)")
            #endif
        }

        var session: Session
        if strategy == .linkToCurrentUser {
            do {
                session = try await supabase.auth.linkIdentityWithIdToken(credentials: credentials)
            } catch {
                #if DEBUG
                print("[AuthService] apple link declined (\(error)); signing in instead")
                #endif
                guard AppleIdentityPolicy.fallback(after: error) == .signInAsAppleUser else { throw error }
                session = try await supabase.auth.signInWithIdToken(credentials: credentials)
            }
        } else {
            session = try await supabase.auth.signInWithIdToken(credentials: credentials)
        }

        currentSession = session
        currentUser = session.user
        // A successful sign-in IS the re-auth the invalidated-session
        // state was asking for.
        needsReauth = false

        // v25 §39 — store the Apple user identifier so a revocation
        // notice can be CONFIRMED with `getCredentialState` before the
        // app acts on it. An identifier, not a token; already on the
        // server as `identity_data.sub`; swept with the account.
        if let appleUserID, !appleUserID.isEmpty {
            UserDefaults.standard.set(appleUserID, forKey: AppleCredentialWatcher.userIdentifierKey)
        }

        // v25 §40 — decided on the OUTCOME, never on the error. The two
        // `identity_already_exists` cases share a code and differ only by
        // an English sentence, and a 5xx link followed by a successful
        // sign-in abandons the uid with no error to read at all. The uid
        // in hand after the switch is the only thing that cannot lie.
        await retireAbandonedAnonymousAccount(
            outgoingUid: outgoingUid,
            outgoingWasAnonymous: outgoingWasAnonymous,
            outgoingToken: outgoingToken,
            incomingUid: session.user.id.uuidString,
            handoffOpened: handoffOpened
        )

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
