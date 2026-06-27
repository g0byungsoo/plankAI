import Foundation
import Observation
import PlankFood
import RevenueCat

// MARK: - FoodFlagsEntitlementProvider conformance
//
// Lets `FoodFlags` (in PlankFood) read `hasProAccess` without PlankFood
// importing the main app target (would cycle). PaymentService already
// exposes the matching property; this is just the protocol bridge.
// Wired up in PlankAIApp.swift via FoodFlags.configure(entitlement:).
extension PaymentService: FoodFlagsEntitlementProvider {}

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

    /// UserDefaults key for the last-known entitlement state. Read at
    /// init to seed hasProAccess so returning paying users don't see a
    /// paywall flash before the customerInfoStream first emit lands;
    /// written on every emit. Stale-true risk (churned user, cached true)
    /// is bounded — the stream emit (typically <500ms after configure)
    /// corrects any divergence and the next render re-evaluates the
    /// paywall gate.
    private static let lastKnownEntitlementKey = "PaymentService.lastKnownEntitlement"

    /// UserDefaults key mirroring whether the last-known entitlement was
    /// in its trial period. Persisted across cold starts so a user who
    /// kills the app mid-trial and reopens after the renewal still fires
    /// the `purchase_completed{is_trial:true}` analytic — without this,
    /// the trial→paid transition is invisible in PostHog when the stream
    /// emit that flipped periodType happened while the process was dead.
    private static let lastKnownInTrialKey = "PaymentService.lastKnownInTrial"

    /// UserDefaults key mirroring whether the last-known entitlement had
    /// auto-renew on. Paired with `lastKnownInTrialKey` to detect a
    /// cancel-during-trial (willRenew true → false while periodType stays
    /// .trial) so the 3-day trial cancel rate is measurable in PostHog.
    private static let lastKnownWillRenewKey = "PaymentService.lastKnownWillRenew"

    private init() {
        hasProAccess = UserDefaults.standard.bool(forKey: Self.lastKnownEntitlementKey)
        wasInTrial = UserDefaults.standard.bool(forKey: Self.lastKnownInTrialKey)
        wasWillRenew = UserDefaults.standard.bool(forKey: Self.lastKnownWillRenewKey)
    }

    /// Whether `configure(appUserID:)` has run. Idempotent — guarded so a
    /// re-render of RootView's task block doesn't double-configure.
    private(set) var isConfigured: Bool = false

    /// Whether the current user has the Pro entitlement active. Seeded
    /// in init from the last-known cached value (UserDefaults) so the
    /// app doesn't render hasProAccess=false on every cold start; then
    /// driven by Purchases.shared.customerInfoStream — flips reactively
    /// on every purchase, restore, expiration, or RevenueCat dashboard
    /// tweak.
    private(set) var hasProAccess: Bool = false

    /// Whether the customerInfoStream has emitted at least once (or the
    /// 3s safety timeout fired) since startCustomerInfoStream ran.
    /// Default false; flips true on the first emit. RootView holds the
    /// splash until this is true so the paywall fullScreenCover never
    /// evaluates against a never-checked default — fixes the cold-start
    /// paywall flash for paying users where hasProAccess hadn't been
    /// confirmed yet by RevenueCat.
    private(set) var isEntitlementReady: Bool = false

    /// True from the moment handleAuthChange flips RevenueCat's appUserID
    /// until the next customerInfoStream emit lands (or a 1s safety
    /// timeout fires). The paywall fullScreenCover is suppressed during
    /// this window — without the gate, the stream's transient
    /// hasProAccess=false emit between logIn and the new user's
    /// entitlement fetch causes a paywall flicker on sign-in.
    private(set) var isInAuthTransition: Bool = false

    #if DEBUG
    /// DEBUG-only override that forces the paywall to present even when
    /// the user has the `pro` entitlement on RevenueCat. Set from
    /// `DebugAuthView` so we can QA the paywall flow without revoking
    /// entitlements in the RC dashboard or signing out. Reads through
    /// `effectiveHasProAccess` so production code keeps the simple
    /// `hasProAccess` API.
    var debugForcePaywall: Bool = false

    /// DEBUG-only inverse: grants pro access for in-app QA runs
    /// (XCUITest walkers, sim screenshots) without an RC sandbox
    /// purchase. Compile-gated out of release.
    let debugForceProAccess: Bool =
        ProcessInfo.processInfo.arguments.contains("--uitest-pro-access")
    #endif

    /// Effective entitlement state used by the paywall gate. In DEBUG
    /// honors the QA overrides; in release it's identical to
    /// `hasProAccess`. Always reads through this in PlankAIApp.
    var effectiveHasProAccess: Bool {
        #if DEBUG
        return (hasProAccess || debugForceProAccess) && !debugForcePaywall
        #else
        return hasProAccess
        #endif
    }

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

    /// Safety timeout that flips isEntitlementReady true even if the
    /// customerInfoStream hangs (offline launch, RevenueCat outage).
    /// Without this, RootView's splash would never dismiss for users
    /// in that state. 3s is generous for cached emits (<500ms typical)
    /// and short enough that users in a true offline launch see the
    /// cached hasProAccess decision quickly.
    private var entitlementReadyTimeoutTask: Task<Void, Never>?

    /// Last trial-end date we passed to TrialEndNotificationService.
    /// nil means no trial-active state was last observed. Used by
    /// reconcileTrialReminder to no-op on repeat customerInfoStream
    /// emits with the same trial state — schedule/cancel only fires on
    /// transitions, not every emit.
    private var lastScheduledTrialEnd: Date?

    /// Whether the prior customerInfoStream emit observed the entitlement
    /// inside its trial period. Used to detect the trial→paid renewal
    /// (was-trial + still-active + no-longer-trial) so PostHog gets a
    /// `purchase_completed{is_trial:true}` event at conversion. Seeded
    /// from UserDefaults at init so backgrounded-during-trial users still
    /// fire the conversion analytic on next launch.
    private var wasInTrial: Bool = false

    /// Whether the prior customerInfoStream emit observed auto-renew on.
    /// Used to detect a cancel-during-trial (willRenew true → false while
    /// periodType stays .trial). Seeded from UserDefaults at init so a
    /// cancel that lands while the process is dead still resolves on the
    /// next launch's first emit.
    private var wasWillRenew: Bool = false

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
            #if DEBUG
            print("[PaymentService] configure skipped: no appUserID (auth not ready)")
            #endif
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
                let entitlement = customerInfo.entitlements[RevenueCatConfig.entitlementID]
                let isActive = entitlement?.isActive ?? false
                let isInTrial = isActive && entitlement?.periodType == .trial
                let wasActive = self.hasProAccess
                let wasInTrial = self.wasInTrial
                let currentWillRenew = entitlement?.willRenew ?? false
                let wasWillRenew = self.wasWillRenew
                self.hasProAccess = isActive
                self.wasInTrial = isInTrial
                self.wasWillRenew = currentWillRenew
                UserDefaults.standard.set(isActive, forKey: Self.lastKnownEntitlementKey)
                UserDefaults.standard.set(isInTrial, forKey: Self.lastKnownInTrialKey)
                UserDefaults.standard.set(currentWillRenew, forKey: Self.lastKnownWillRenewKey)
                #if DEBUG
                let activeKeys = customerInfo.entitlements.active.keys.sorted()
                print("[PaymentService] customerInfo updated: hasProAccess=\(isActive) isInTrial=\(isInTrial) entitlements=\(activeKeys)")
                #endif
                // Monetization analytics — three discrete transitions,
                // each fires exactly once per state change so funnel
                // queries can split trial vs. paid vs. trial-converted.
                //
                //   1. inactive → active in trial:
                //        trial_start{is_trial:true}
                //   2. inactive → active not in trial (direct purchase):
                //        purchase_completed{is_trial:false}
                //   3. active in trial → active not in trial (renewal):
                //        purchase_completed{is_trial:true}
                //
                // Branch #3 was the silent gap pre-2026-06-17: hasProAccess
                // stays true across trial→paid so the !wasActive guard
                // missed the renewal entirely, and PostHog's
                // purchase_completed{is_trial:true} stayed at zero. The
                // wasInTrial flag (persisted across cold launches) closes
                // the gap so the conversion is visible even when the
                // process was dead at the moment RC emitted the renewal.
                let productId = entitlement?.productIdentifier ?? "unknown"
                if isActive && !wasActive {
                    Analytics.track(isInTrial ? .trialStart : .purchaseCompleted,
                                    properties: [
                                        "product_id": productId,
                                        "placement": "onboarding_final",
                                        "is_trial": isInTrial
                                    ])
                } else if isActive && wasActive && wasInTrial && !isInTrial {
                    Analytics.track(.purchaseCompleted,
                                    properties: [
                                        "product_id": productId,
                                        "placement": "trial_conversion",
                                        "is_trial": true
                                    ])
                    // Distinct event so trial→paid is unambiguous in funnels
                    // (purchase_completed also fires for direct no-trial buys).
                    Analytics.track(.trialConverted,
                                    properties: ["product_id": productId])
                }
                // Cancel-during-trial: still active + still in trial, but
                // auto-renew flipped off (willRenew true → false). RevenueCat
                // resolves the actual lapse server-side, but the cancel intent
                // is visible here — fires once on the transition so the 3-day
                // trial cancel rate is measurable. Weekly has no trial, so it
                // never matches; the explicit guard is belt-and-suspenders.
                if isInTrial && wasInTrial && wasWillRenew && !currentWillRenew &&
                    !productId.lowercased().contains("weekly") {
                    Analytics.track(.trialCancelled,
                                    properties: ["product_id": productId])
                }
                self.markEntitlementReady(reason: "customerInfoStream emit")
                // First emit since an auth change closes the suppression
                // window early — paywall presentation is allowed again as
                // soon as we know the new user's actual entitlement state.
                self.clearAuthTransition(reason: "customerInfoStream emit")
                await self.reconcileTrialReminder(from: customerInfo)
            }
        }

        entitlementReadyTimeoutTask?.cancel()
        entitlementReadyTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            // Soft-spot fix #3 (2026-06-01): the safety timeout used
            // to flip isEntitlementReady true purely based on the
            // cached hasProAccess. If a user with a previously-Pro
            // cache cold-launches offline + RC stream hangs, they
            // could see MainTabView without the paywall presenting.
            // Now: before flipping the gate, force a one-shot
            // Purchases.shared.customerInfo() refresh. If it
            // resolves quickly, the truth lands first; if it hangs
            // too, we proceed with the cached value but at least we
            // tried to validate.
            Task { @MainActor [weak self] in
                do {
                    let info = try await Purchases.shared.customerInfo()
                    let entitlement = info.entitlements[RevenueCatConfig.entitlementID]
                    let isActive = entitlement?.isActive ?? false
                    let isInTrial = isActive && entitlement?.periodType == .trial
                    self?.hasProAccess = isActive
                    self?.wasInTrial = isInTrial
                    UserDefaults.standard.set(isActive, forKey: Self.lastKnownEntitlementKey)
                    UserDefaults.standard.set(isInTrial, forKey: Self.lastKnownInTrialKey)
                    #if DEBUG
                    print("[PaymentService] safety-timeout refresh: hasProAccess=\(isActive) isInTrial=\(isInTrial)")
                    #endif
                } catch {
                    Analytics.trackException(error, context: "payment.safety_timeout_refresh")
                    #if DEBUG
                    print("[PaymentService] safety-timeout refresh failed: \(error)")
                    #endif
                }
                self?.markEntitlementReady(reason: "safety timeout")
            }
        }
    }

    private func markEntitlementReady(reason: String) {
        guard !isEntitlementReady else { return }
        isEntitlementReady = true
        entitlementReadyTimeoutTask?.cancel()
        entitlementReadyTimeoutTask = nil
        #if DEBUG
        print("[PaymentService] entitlement ready (\(reason))")
        #endif
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

        // Sprint A (2026-06-15) — also pump the in-app trial nudge
        // coordinator. The Day-2 + Day-3 modals render on app foreground
        // when the entitlement is in trial and the user opens the app
        // inside the relevant hour window. Re-evaluated on every emit
        // so the coordinator picks up restored / cancelled trials too.
        TrialNudgeCoordinator.shared.evaluate(
            purchaseDate: trialActive ? entitlement?.latestPurchaseDate : nil,
            expirationDate: trialEndDate,
            isTrial: trialActive
        )

        if trialEndDate == lastScheduledTrialEnd { return }
        let priorTrialEndDate = lastScheduledTrialEnd
        lastScheduledTrialEnd = trialEndDate

        if let trialEndDate {
            await TrialEndNotificationService.shared.scheduleIfNeeded(trialEndDate: trialEndDate)
        } else {
            await TrialEndNotificationService.shared.cancelTrialEndReminder()
            // v2 (2026-06-16): trial→paid transition detection. When
            // the prior emit had a trial-end date and this emit
            // doesn't, AND the entitlement is still active, the user
            // just converted from trial to paid. Schedule the Day 5
            // anti-refund push for annual + quarterly converters
            // (skip weekly tier — no refund risk at $5.99).
            //
            // v1.1.1 (2026-06-19) — the original guard fired even on
            // cancel-during-trial because the user is still inside
            // the trial WINDOW (entitlement.isActive=true) with
            // periodType=.trial but willRenew=false. Resulting bug:
            // a user who cancels her trial on Day 1 still gets a
            // Day-5 anti-refund nudge framed as "your charge cleared,
            // here's why you'll love staying" — actively misleading,
            // and likely to drive refund requests from people who
            // thought they HAD cancelled. New guard:
            //   - periodType != .trial (truly post-trial)
            //   - willRenew == true (didn't cancel)
            // both required before the Day-5 push schedules.
            if priorTrialEndDate != nil,
               let entitlement,
               entitlement.isActive,
               entitlement.periodType != .trial,
               entitlement.willRenew,
               !entitlement.productIdentifier.lowercased().contains("weekly") {
                let chargeDate = entitlement.latestPurchaseDate ?? Date()
                RetentionNotifications.scheduleDay5AntiRefundIfNeeded(chargeDate: chargeDate)
            }
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
        #if DEBUG
        print("[PaymentService] auth transition END (\(reason)) — paywall presentation re-enabled")
        #endif
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
    /// Trigger a RevenueCat restore. Pulls the user's purchase history
    /// from Apple's receipt + RevenueCat's records and reapplies any
    /// active entitlements. customerInfoStream emits the result, so
    /// hasProAccess updates reactively — the returned Bool is a
    /// convenience for the caller's immediate UI feedback ("Restored"
    /// vs "Nothing to restore").
    @discardableResult
    func restorePurchases() async throws -> Bool {
        let info = try await Purchases.shared.restorePurchases()
        return info.entitlements[RevenueCatConfig.entitlementID]?.isActive ?? false
    }

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
        #if DEBUG
        print("[PaymentService] auth transition START — paywall presentation suppressed")
        #endif
        authTransitionSafetyTask?.cancel()
        authTransitionSafetyTask = Task { @MainActor [weak self] in
            // Soft-spot fix #2 (2026-06-01): tightened 1s → 500ms.
            // The narrower window reduces the bypass surface where
            // !isInAuthTransition is false during user-driven auth
            // changes (sign-in / sign-up) and the cover doesn't
            // present. customerInfoStream emits in <500ms typically;
            // safety timeout only fires on rare hangs.
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.clearAuthTransition(reason: "safety timeout")
        }

        do {
            if let normalized {
                let result = try await Purchases.shared.logIn(normalized)
                #if DEBUG
                print("[PaymentService] logIn: created=\(result.created) userID=\(normalized)")
                #endif
            } else {
                _ = try await Purchases.shared.logOut()
                // Soft-spot fix #1 (2026-06-01): wipe the cached
                // entitlement on sign-out so a previously-Pro user who
                // signs out (e.g., cancelled + switching accounts)
                // doesn't carry stale hasProAccess=true through the
                // PaymentService init() cache-read. RC stream re-emits
                // the truth for the new (anonymous) user shortly after,
                // but the cache window is the soft-spot.
                UserDefaults.standard.removeObject(forKey: Self.lastKnownEntitlementKey)
                UserDefaults.standard.removeObject(forKey: Self.lastKnownInTrialKey)
                hasProAccess = false
                wasInTrial = false
                #if DEBUG
                print("[PaymentService] logOut succeeded — cached entitlement cleared")
                #endif
            }
        } catch {
            Analytics.trackException(error, context: "payment.auth_sync",
                                     properties: ["new_user_id_present": normalized != nil])
            #if DEBUG
            print("[PaymentService] auth sync FAILED: \(error)")
            #endif
            // Failed network call won't trigger a stream emit; clear the
            // gate explicitly so the user isn't stuck in suppression
            // forever (until the safety timeout would fire anyway).
            clearAuthTransition(reason: "logIn/logOut failed")
        }
    }
}
