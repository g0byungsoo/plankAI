import Foundation
import Observation
import RevenueCat

// MARK: - PaymentService
//
// Single source of truth for the Pro entitlement. Mirrors AuthService's
// shape: @MainActor @Observable singleton, configure-once on app launch.
//
// Phase A scope: install the SDK + initialize Purchases with the
// authenticated user_id. Phase B will observe customerInfoStream and
// expose hasProAccess reactively. Phase D will gate paywall presentation
// on offering data fetched here.

@MainActor
@Observable
final class PaymentService {
    static let shared = PaymentService()
    private init() {}

    /// Whether `configure(appUserID:)` has run. Idempotent — guarded so a
    /// re-render of RootView's task block doesn't double-configure.
    private(set) var isConfigured: Bool = false

    /// Whether the current user has the Pro entitlement active. Driven by
    /// Purchases.shared.customerInfoStream — flips reactively on every
    /// purchase, restore, expiration, or RevenueCat dashboard tweak.
    private(set) var hasProAccess: Bool = false

    /// Last appUserID we've sent to RevenueCat via logIn/logOut. Skips
    /// redundant calls when AppSync.onAuthChanged fires multiple times
    /// for the same identity transition (currentUser?.id onChange +
    /// authMethod onChange both spawning Tasks).
    private var lastSyncedUserID: String?

    /// Long-lived task observing the customer info stream. Persists for
    /// the app lifetime since PaymentService is a singleton. Stored so
    /// configure() can no-op if it's already running.
    private var streamTask: Task<Void, Never>?

    /// Configure RevenueCat once, after AuthService.bootstrap completes.
    /// Pass the current Supabase user_id as appUserID so RevenueCat scopes
    /// purchases to the same identity used for cloud data. Starts the
    /// customerInfoStream observation immediately after configure so
    /// hasProAccess reflects the cached entitlement state on first emit.
    ///
    /// `appUserID` may be nil if AuthService.bootstrap failed; in that
    /// case we don't configure (no orphan anonymous RevenueCat user
    /// gets created), and the next bootstrap retry will trigger configure.
    func configure(appUserID: String?) {
        guard !isConfigured else { return }
        guard let appUserID, !appUserID.isEmpty else {
            print("[PaymentService] configure skipped: no appUserID (auth not ready)")
            return
        }

        #if DEBUG
        Purchases.logLevel = .info
        #else
        Purchases.logLevel = .error
        #endif

        Purchases.configure(
            with: Configuration.Builder(withAPIKey: RevenueCatConfig.apiKey)
                .with(appUserID: appUserID)
                .build()
        )

        isConfigured = true
        lastSyncedUserID = appUserID
        startCustomerInfoStream()
    }

    private func startCustomerInfoStream() {
        streamTask?.cancel()
        streamTask = Task { @MainActor [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard let self else { return }
                let isActive = customerInfo.entitlements[RevenueCatConfig.entitlementID]?.isActive ?? false
                self.hasProAccess = isActive
                let activeKeys = customerInfo.entitlements.active.keys.sorted()
                print("[PaymentService] customerInfo updated: hasProAccess=\(isActive) entitlements=\(activeKeys)")
            }
        }
    }

    /// Sync RevenueCat's appUserID with AuthService. Called from
    /// AppSync.onAuthChanged on every observable auth-state change:
    ///   - sign-up upgrade (anon → apple/email, same Supabase uid):
    ///     RevenueCat aliases the prior anonymous user to the named
    ///     uid, so any anonymous purchases (none in our flow today,
    ///     but future-proof) carry forward.
    ///   - sign-in to existing account (different Supabase uid, non-anon):
    ///     RevenueCat switches to the new user's purchase history.
    ///   - sign-out + re-bootstrap (different Supabase uid, anon now):
    ///     RevenueCat switches to the new anon. Old user's entitlements
    ///     no longer surface on this device.
    /// No-op when newUserID matches lastSyncedUserID — guards against
    /// the duplicate onChange Tasks spawned by RootView's two observers.
    func handleAuthChange(newUserID: String?) async {
        guard isConfigured else { return }
        let normalized = (newUserID?.isEmpty == false) ? newUserID : nil
        if normalized == lastSyncedUserID { return }
        lastSyncedUserID = normalized

        do {
            if let normalized {
                let result = try await Purchases.shared.logIn(normalized)
                print("[PaymentService] logIn: created=\(result.created) userID=\(normalized)")
            } else {
                _ = try await Purchases.shared.logOut()
                print("[PaymentService] logOut succeeded")
            }
        } catch {
            print("[PaymentService] auth sync FAILED: \(error)")
        }
    }
}
