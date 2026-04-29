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
    func bootstrap() async {
        guard !didStartBootstrap else { return }
        didStartBootstrap = true
        bootstrapState = .running

        // 1. Try to restore an existing session from Keychain.
        if let restored = try? await supabase.auth.session {
            currentSession = restored
            currentUser = restored.user
            bootstrapState = .ready
            return
        }

        // 2. No session — sign in anonymously.
        do {
            let session = try await supabase.auth.signInAnonymously()
            currentSession = session
            currentUser = session.user
            bootstrapState = .ready
        } catch {
            // Surfaces in the splash so the user can retry.
            bootstrapState = .failed(error.localizedDescription)
            didStartBootstrap = false  // allow retry
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
