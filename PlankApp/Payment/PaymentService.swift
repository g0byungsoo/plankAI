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

    /// True from the moment handleAuthChange flips RevenueCat's appUserID
    /// until the next customerInfoStream emit lands (or a 1s safety
    /// timeout fires). The paywall fullScreenCover is suppressed during
    /// this window — without the gate, the stream's transient
    /// hasProAccess=false emit between logIn and the new user's
    /// entitlement fetch causes a paywall flicker on sign-in.
    private(set) var isInAuthTransition: Bool = false

    /// Last appUserID we've sent to RevenueCat via logIn/logOut. Skips
    /// redundant calls when AppSync.onAuthChanged fires multiple times
    /// for the same identity transition (currentUser?.id onChange +
    /// authMethod onChange both spawning Tasks).
    private var lastSyncedUserID: String?

    /// Long-lived task observing the customer info stream. Persists for
    /// the app lifetime since PaymentService is a singleton. Stored so
    /// configure() can no-op if it's already running.
    private var streamTask: Task<Void, Never>?

    /// Safety timeout that clears isInAuthTransition if no
    /// customerInfoStream emit lands within 1s of an auth change. Stored
    /// so handleAuthChange can cancel the prior timeout when a new auth
    /// transition starts before the previous one's window closes.
    private var authTransitionSafetyTask: Task<Void, Never>?

    /// Last trial-end date we passed to TrialEndNotificationService.
    /// nil means no trial-active state was last observed. Used by
    /// reconcileTrialReminder to no-op on repeat customerInfoStream
    /// emits with the same trial state — schedule/cancel only fires on
    /// transitions, not every emit.
    private var lastScheduledTrialEnd: Date?

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
                // First emit since an auth change closes the suppression
                // window early — paywall presentation is allowed again as
                // soon as we know the new user's actual entitlement state.
                self.clearAuthTransition(reason: "customerInfoStream emit")
                await self.reconcileTrialReminder(from: customerInfo)
            }
        }
    }

    /// Single source of truth for trial-end notification scheduling.
    /// Called on every customerInfoStream emit so the four edge cases
    /// (initial purchase, restore-during-trial, cancel-during-trial,
    /// trial-converted-to-normal) all flow through one path:
    ///   - active + trial period + willRenew: schedule reminder
    ///   - any other state (including trial cancelled): cancel reminder
    /// lastScheduledTrialEnd guard prevents repeated schedule/cancel on
    /// no-op emits where the trial state hasn't actually changed.
    private func reconcileTrialReminder(from customerInfo: CustomerInfo) async {
        let entitlement = customerInfo.entitlements[RevenueCatConfig.entitlementID]
        let trialActive = entitlement?.isActive == true
            && entitlement?.periodType == .trial
            && entitlement?.willRenew == true
        let trialEndDate = trialActive ? entitlement?.expirationDate : nil

        if trialEndDate == lastScheduledTrialEnd { return }
        lastScheduledTrialEnd = trialEndDate

        if let trialEndDate {
            await TrialEndNotificationService.shared.scheduleIfNeeded(trialEndDate: trialEndDate)
        } else {
            await TrialEndNotificationService.shared.cancelTrialEndReminder()
        }
    }

    /// Lift the auth-transition suppression. Idempotent — early-returns
    /// when the gate is already cleared so the customerInfoStream emit
    /// path doesn't fight with the safety timeout.
    private func clearAuthTransition(reason: String) {
        guard isInAuthTransition else { return }
        isInAuthTransition = false
        authTransitionSafetyTask?.cancel()
        authTransitionSafetyTask = nil
        print("[PaymentService] auth transition END (\(reason)) — paywall presentation re-enabled")
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

        // Suppress paywall presentation during the window between
        // calling logIn and the customerInfoStream emitting the new
        // user's entitlement state. Stream transitions from old user's
        // hasProAccess to new user's hasProAccess can briefly emit
        // false, causing a flash of paywall before the cover dismisses
        // again. RootView's fullScreenCover binding ANDs against this
        // flag.
        isInAuthTransition = true
        print("[PaymentService] auth transition START — paywall presentation suppressed")
        authTransitionSafetyTask?.cancel()
        authTransitionSafetyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.clearAuthTransition(reason: "safety timeout")
        }

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
            // Failed network call won't trigger a stream emit; clear the
            // gate explicitly so the user isn't stuck in suppression
            // forever (until the safety timeout would fire anyway).
            clearAuthTransition(reason: "logIn/logOut failed")
        }
    }
}
