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

    /// Whether the current user has the Pro entitlement active. Phase B
    /// will wire this to Purchases.shared.customerInfoStream; for now it
    /// stays false until the entitlement plumbing lands.
    private(set) var hasProAccess: Bool = false

    /// Configure RevenueCat once, after AuthService.bootstrap completes.
    /// Pass the current Supabase user_id as appUserID so RevenueCat scopes
    /// purchases to the same identity used for cloud data — anonymous and
    /// authenticated users each get their own RevenueCat record. Phase B
    /// will add Purchases.logIn / logOut on auth-state transitions.
    ///
    /// `appUserID` may be nil if AuthService.bootstrap failed; in that
    /// case we don't configure (no anonymous RevenueCat user gets
    /// created), and the next bootstrap retry will trigger configure.
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
    }
}
