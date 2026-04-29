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
}
