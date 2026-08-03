import Foundation
import Observation
import PlankFood
import RevenueCat

// MARK: - FoodFlagsEntitlementProvider bridge
//
// Lets `FoodFlags` (in PlankFood) read the entitlement without
// PlankFood importing the main app target (would cycle). App v2: the
// bridge reads `effectiveHasProAccess` (not raw `hasProAccess`) so
// DEBUG QA overrides (`--uitest-pro-access`, force-paywall) gate the
// food rail consistently with the shell — pre-v2 the walker had app
// entry but no food rail (audit weakness #6).
@MainActor
final class FoodFlagsEffectiveEntitlement: FoodFlagsEntitlementProvider {
    static let shared = FoodFlagsEffectiveEntitlement()
    var hasProAccess: Bool { PaymentService.shared.effectiveHasProAccess }
}

// MARK: - EntitlementRecoveryDecision
//
// Identity-recovery fix (2026-07-25). When auth re-keys to a new
// Supabase uid (sign-in recovery, delete + re-bootstrap, reinstall),
// RevenueCat follows via logIn and can land on a customer with NO
// entitlement while the device's receipt still holds a live
// subscription — a PAYING user hits the wall. The recovery: silently
// post the device receipt (Purchases.syncPurchases) so RevenueCat's
// default transfer-on-restore behavior re-attaches the subscription
// to the current appUserID, no user interaction needed.
//
// This type is the pure decision seam (unit-tested in
// EntitlementRecoveryTests); PaymentService feeds it live state.
enum EntitlementRecoveryDecision {
    /// What put the recovery check in motion.
    ///   .passive           — a customerInfo landing (stream emit,
    ///                        forced refresh, post-logIn). Requires
    ///                        wasEverEntitled: never post the receipt
    ///                        speculatively for a plain prospect.
    ///   .interactiveSignIn — the user just signed in through a wall
    ///                        or paywall sign-in door. An explicit
    ///                        sign-in is strong evidence of a
    ///                        returning user, and a reinstall wipes
    ///                        the wasEverEntitled flag with the
    ///                        container — so this trigger relaxes
    ///                        that one requirement. Still silent,
    ///                        still bounded by the attempted set.
    enum Trigger: Equatable {
        case passive
        case interactiveSignIn
    }

    struct Inputs {
        var hasActiveEntitlement: Bool
        var wasEverEntitled: Bool
        var appUserID: String?
        var attemptedUserIDs: Set<String>
        var isRecoverySyncInFlight: Bool
        var isRestoreInFlight: Bool
        var trigger: Trigger = .passive
    }

    /// True when a silent syncPurchases attempt is warranted.
    /// Guard rails:
    ///   - only when the current customer has NO active entitlement;
    ///   - passive trigger additionally requires that this install
    ///     observed an entitlement before (wasEverEntitled): the
    ///     exact signature of identity loss. The interactiveSignIn
    ///     trigger waives only this — reinstalls wipe the flag;
    ///   - at most once per launch per appUserID: a genuinely-expired
    ///     sub makes syncPurchases return still-empty entitlements,
    ///     which re-enters this check via the next stream emit — the
    ///     attempted set breaks the loop;
    ///   - never while a recovery sync or a manual restore is already
    ///     in flight.
    static func shouldAutoSync(_ i: Inputs) -> Bool {
        guard !i.hasActiveEntitlement else { return false }
        if i.trigger == .passive {
            guard i.wasEverEntitled else { return false }
        }
        guard let id = i.appUserID, !id.isEmpty else { return false }
        guard !i.attemptedUserIDs.contains(id) else { return false }
        guard !i.isRecoverySyncInFlight, !i.isRestoreInFlight else { return false }
        return true
    }
}

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

    /// App v2 (07_GATING) — set true the first time an active
    /// entitlement is ever observed, never unset. Drives the
    /// wall(.expired) welcome-back variant for churned payers.
    private static let wasEverEntitledKey = "PaymentService.wasEverEntitled"

    /// App v2 (07_GATING) — when the entitlement state was last
    /// confirmed by a RevenueCat emit or a successful forced refresh.
    /// Bounds the offline fail-open window: the shell surfaces a
    /// quiet re-verify state when this goes stale past 72h.
    private static let entitlementVerifiedAtKey = "PaymentService.entitlementVerifiedAt"

    private init() {
        hasProAccess = UserDefaults.standard.bool(forKey: Self.lastKnownEntitlementKey)
        wasInTrial = UserDefaults.standard.bool(forKey: Self.lastKnownInTrialKey)
        wasWillRenew = UserDefaults.standard.bool(forKey: Self.lastKnownWillRenewKey)
        // Backfill for installs predating the flag: a cached active
        // entitlement proves prior entitlement.
        if hasProAccess {
            UserDefaults.standard.set(true, forKey: Self.wasEverEntitledKey)
        }
    }

    /// True if this install has ever observed an active entitlement.
    var wasEverEntitled: Bool {
        UserDefaults.standard.bool(forKey: Self.wasEverEntitledKey)
    }

    /// Seconds since the entitlement was last confirmed against
    /// RevenueCat. nil = never confirmed on this install.
    var entitlementVerifiedAgo: TimeInterval? {
        let t = UserDefaults.standard.double(forKey: Self.entitlementVerifiedAtKey)
        guard t > 0 else { return nil }
        return Date.now.timeIntervalSince1970 - t
    }

    /// Stale-verification signal for the shell's quiet re-verify
    /// banner (72h bound per 07_GATING).
    var entitlementVerificationIsStale: Bool {
        guard hasProAccess else { return false }
        guard let ago = entitlementVerifiedAgo else { return true }
        return ago > 72 * 3600
    }

    private func stampEntitlementVerified() {
        UserDefaults.standard.set(
            Date.now.timeIntervalSince1970,
            forKey: Self.entitlementVerifiedAtKey
        )
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

    /// The active entitlement's product id ("jenifit_weekly_v2"…),
    /// nil until the stream's first emit or when nothing is active.
    /// v6.5: drives the day-6 weekly→quarterly upgrade moment.
    private(set) var activeProductId: String?

    /// True when the active subscription is a weekly SKU (legacy or
    /// v2 — the id substring is the stable signal across both).
    var activeProductIsWeekly: Bool {
        (activeProductId ?? "").lowercased().contains("weekly")
    }

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

    /// appUserIDs already given one silent syncPurchases recovery
    /// attempt this launch. Never cleared while the process lives —
    /// the once-per-launch-per-user bound is what keeps a genuinely
    /// expired subscription from looping receipt posts (each still-
    /// empty sync result re-emits on the stream and re-enters the
    /// recovery check).
    private var recoverySyncAttemptedUserIDs: Set<String> = []

    /// True while the silent syncPurchases recovery call is awaiting
    /// RevenueCat. Blocks overlapping recovery attempts.
    private var isRecoverySyncInFlight = false

    /// True while a user-initiated restorePurchases is awaiting
    /// RevenueCat. The recovery decision skips while a manual restore
    /// runs — the restore already posts the receipt.
    private var isRestoreInFlight = false

    /// When the user last completed an interactive sign-in through a
    /// wall/paywall sign-in door. While inside the recovery window,
    /// checks run with trigger .interactiveSignIn, which waives the
    /// wasEverEntitled requirement (reinstalls wipe that flag with the
    /// container). Cleared when a recovery sync fires off it.
    private var lastInteractiveSignInAt: Date?

    /// How long an interactive sign-in keeps the relaxed trigger
    /// alive. Long enough to cover the onAuthChanged → logIn → stream
    /// emit pipeline (typically <2s), short enough that a much later
    /// passive landing doesn't inherit the relaxed rule.
    private static let interactiveSignInRecoveryWindow: TimeInterval = 5 * 60

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
        #if DEBUG
        // QA harness door: `--uitest-skip-payment` keeps RevenueCat
        // entirely unconfigured for sim capture runs, so StoreKit never
        // raises the "Sign in to Apple Account" system dialog over the
        // screen being photographed. Safe app-wide: every StoreKit
        // consumer (wall, downsell, reveal prefetch) already guards on
        // `Purchases.isConfigured` and renders its unresolved state.
        if ProcessInfo.processInfo.arguments.contains("--uitest-skip-payment") {
            print("[PaymentService] configure skipped: --uitest-skip-payment")
            return
        }
        #endif
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
                // Sandbox breadcrumb (2026-07-25): TestFlight runs
                // against the sandbox environment where subs expire in
                // minutes — carried on logs + purchase analytics so a
                // future "I got walled" report can separate legitimate
                // sandbox expiry from identity loss. Observability
                // only; gating never branches on it.
                let isSandbox = entitlement?.isSandbox ?? false
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
                // App v2 gating flags: every emit is a confirmation.
                if isActive {
                    UserDefaults.standard.set(true, forKey: Self.wasEverEntitledKey)
                }
                self.stampEntitlementVerified()
                #if DEBUG
                let activeKeys = customerInfo.entitlements.active.keys.sorted()
                print("[PaymentService] customerInfo updated: hasProAccess=\(isActive) isInTrial=\(isInTrial) sandbox=\(isSandbox) entitlements=\(activeKeys)")
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
                self.activeProductId = isActive ? entitlement?.productIdentifier : nil
                if isActive && !wasActive {
                    Analytics.track(isInTrial ? .trialStart : .purchaseCompleted,
                                    properties: [
                                        "product_id": productId,
                                        "placement": "onboarding_final",
                                        "is_trial": isInTrial,
                                        "is_sandbox": isSandbox
                                    ])
                } else if isActive && wasActive && wasInTrial && !isInTrial {
                    Analytics.track(.purchaseCompleted,
                                    properties: [
                                        "product_id": productId,
                                        "placement": "trial_conversion",
                                        "is_trial": true,
                                        "is_sandbox": isSandbox
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
                // Identity-recovery (2026-07-25): a no-entitlement emit
                // on an install that was ever entitled is the walled-
                // payer signature — try one silent receipt sync.
                self.attemptEntitlementRecoveryIfNeeded(
                    hasActiveEntitlement: isActive,
                    source: "stream_emit"
                )
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
                    // App v2: a successful forced refresh confirms too.
                    if isActive {
                        UserDefaults.standard.set(true, forKey: Self.wasEverEntitledKey)
                    }
                    self?.stampEntitlementVerified()
                    #if DEBUG
                    print("[PaymentService] safety-timeout refresh: hasProAccess=\(isActive) isInTrial=\(isInTrial) sandbox=\(entitlement?.isSandbox ?? false)")
                    #endif
                    // Identity-recovery (2026-07-25): when the forced
                    // refresh is the only landing (stream hung), it
                    // still gets the walled-payer check.
                    self?.attemptEntitlementRecoveryIfNeeded(
                        hasActiveEntitlement: isActive,
                        source: "safety_timeout_refresh"
                    )
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
            // v1.1.3 pay-upfront: no intro offer ships; trial-end push
            // is disabled app-wide. Left in place for easy re-enable
            // when/if a trial is re-introduced.
            // await TrialEndNotificationService.shared.scheduleIfNeeded(trialEndDate: trialEndDate)
            _ = trialEndDate  // silence unused-var warning
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
        isRestoreInFlight = true
        defer { isRestoreInFlight = false }
        let info = try await Purchases.shared.restorePurchases()
        return info.entitlements[RevenueCatConfig.entitlementID]?.isActive ?? false
    }

    /// Identity-recovery (2026-07-25), the sign-in door's half. Called
    /// by the wall/paywall sign-in sheets when a sign-in actually
    /// completed (caller checks AuthService.isAnonymous first). Opens
    /// the interactiveSignIn recovery window so the next customerInfo
    /// landing may sync the receipt even on a reinstalled device where
    /// wasEverEntitled was wiped.
    ///
    /// When the sign-in did NOT change the identity (she re-signed
    /// into the account RevenueCat is already keyed to), no re-key,
    /// no logIn, and possibly no fresh emit will follow — this call is
    /// the only landing, so it checks immediately. A re-keyed sign-in
    /// must NOT check here: syncing before logIn completes would post
    /// the receipt to the OUTGOING anonymous user; the post-logIn
    /// landings carry the window instead.
    func noteInteractiveSignIn(signedInUserID: String?) {
        lastInteractiveSignInAt = Date.now
        #if DEBUG
        print("[PaymentService] interactive sign-in noted — recovery window open")
        #endif
        guard isConfigured else { return }
        if let signedInUserID,
           signedInUserID.caseInsensitiveCompare(lastSyncedUserID ?? "") == .orderedSame {
            attemptEntitlementRecoveryIfNeeded(
                hasActiveEntitlement: hasProAccess,
                source: "interactive_sign_in_same_identity"
            )
        }
    }

    /// Identity-recovery (2026-07-25). Called wherever customerInfo
    /// lands (stream emit, safety-timeout refresh, post-logIn). When
    /// the decision seam says the current customer looks like a
    /// walled payer (no entitlement, install was ever entitled),
    /// silently posts the device receipt via syncPurchases —
    /// RevenueCat's transfer-on-restore then re-attaches the
    /// subscription to the current appUserID. syncPurchases over
    /// restorePurchases on purpose: no App Store sign-in prompt, no
    /// user interaction. The result flows back through
    /// customerInfoStream, which stays the single writer of
    /// hasProAccess.
    private func attemptEntitlementRecoveryIfNeeded(hasActiveEntitlement: Bool, source: String) {
        guard isConfigured else { return }
        #if DEBUG
        // QA walkers grant pro via launch arg; the sim has no receipt
        // to post — skip so every walker launch doesn't burn a sync.
        if debugForceProAccess { return }
        #endif
        let trigger: EntitlementRecoveryDecision.Trigger = {
            if let t = lastInteractiveSignInAt,
               Date.now.timeIntervalSince(t) < Self.interactiveSignInRecoveryWindow {
                return .interactiveSignIn
            }
            return .passive
        }()
        let inputs = EntitlementRecoveryDecision.Inputs(
            hasActiveEntitlement: hasActiveEntitlement,
            wasEverEntitled: wasEverEntitled,
            appUserID: lastSyncedUserID,
            attemptedUserIDs: recoverySyncAttemptedUserIDs,
            isRecoverySyncInFlight: isRecoverySyncInFlight,
            isRestoreInFlight: isRestoreInFlight,
            trigger: trigger
        )
        guard EntitlementRecoveryDecision.shouldAutoSync(inputs),
              let userID = lastSyncedUserID else { return }
        // Insert BEFORE the async call: a sync that resolves to still-
        // empty entitlements (genuinely expired sub) triggers another
        // stream emit that re-enters this check — the set entry is
        // what breaks the loop.
        recoverySyncAttemptedUserIDs.insert(userID)
        isRecoverySyncInFlight = true
        // One sync per sign-in: the relaxed window is consumed here.
        if trigger == .interactiveSignIn { lastInteractiveSignInAt = nil }
        #if DEBUG
        print("[PaymentService] auto-sync recovery START (\(source)): wasEverEntitled with no active entitlement — posting device receipt for userID=\(userID)")
        #endif
        Task { @MainActor [weak self] in
            do {
                let info = try await Purchases.shared.syncPurchases()
                let entitlement = info.entitlements[RevenueCatConfig.entitlementID]
                let recovered = entitlement?.isActive ?? false
                Analytics.track("entitlement_auto_sync", properties: [
                    "recovered": recovered,
                    "is_sandbox": entitlement?.isSandbox ?? false,
                    "source": source,
                    "trigger": trigger == .interactiveSignIn
                        ? "interactive_sign_in" : "passive"
                ])
                #if DEBUG
                print("[PaymentService] auto-sync recovery DONE (\(source)): recovered=\(recovered) sandbox=\(entitlement?.isSandbox ?? false)")
                #endif
            } catch {
                Analytics.trackException(error, context: "payment.auto_sync_recovery",
                                         properties: ["source": source])
                #if DEBUG
                print("[PaymentService] auto-sync recovery FAILED (\(source)): \(error)")
                #endif
            }
            self?.isRecoverySyncInFlight = false
        }
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
                // Identity-recovery (2026-07-25): a re-keyed identity
                // (created=true, or an existing RC customer with no
                // entitlement) is exactly where the walled-payer bug
                // lived — check immediately off logIn's customerInfo
                // instead of waiting on the next stream emit.
                let entitlement = result.customerInfo.entitlements[RevenueCatConfig.entitlementID]
                attemptEntitlementRecoveryIfNeeded(
                    hasActiveEntitlement: entitlement?.isActive ?? false,
                    source: "auth_rekey_login"
                )
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
