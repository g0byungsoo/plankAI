import SwiftUI
import SwiftData
import PlankSync
import RevenueCat
import Auth

// MARK: - WallView
//
// App v2 (docs/app_v2/07_GATING.md). The hard paywall as a
// DESTINATION, not a cover — nothing else is mounted while the user
// isn't entitled. Hosts:
//   .fresh    — the acquisition paywall (PaywallView unchanged) with
//               the exit-intent chain (downsell once/install →
//               winback once/session) migrated from RootView.
//   .expired  — the reactivation state churned payers deserved and
//               never had: her plan is intact, restore is first-class,
//               and the acquisition paywall is one tap deeper.
//
// On subscribe: PaymentService's stream flips entitlement → the
// phase machine leaves the wall on its own. This view only stamps
// the post-purchase first-run flag (consumed by MainShell) using the
// same eligibility rules the old RootView applied.

struct WallView: View {
    let reason: AppPhase.WallReason

    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService.shared

    @AppStorage("downsellShownOnce") private var downsellShownOnce = false
    /// The quarterly-abandon smaller-step offer mirrors the downsell's
    /// once-per-install rule so the recovery never nags.
    @AppStorage("smallerStepShownOnce") private var smallerStepShownOnce = false
    @State private var showingDownsell = false
    @State private var showingSmallerStep = false
    @State private var showingWinback = false
    @State private var winbackShownThisSession = false
    /// A recovery sheet's "not today" queues the winback; it PRESENTS
    /// from the sheet's onDismiss (after the swap animation completes).
    /// Presenting directly from the callback raced the dismissal and
    /// silently dropped the winback (round-3 walker evidence).
    @State private var winbackQueuedAfterSheet = false
    /// Which tier's abandon opened the current recovery (analytics).
    @State private var lastAbandonedPlan: String?
    /// How the downsell was opened this time: "exit_intent" (the
    /// once-per-install auto-show) or "reclaim" (the wall row).
    @State private var downsellTrigger = "exit_intent"
    /// Expired users land on the welcome-back beat first; "see plans"
    /// swaps to the standard paywall.
    @State private var showingPlansFromExpired = false

    var body: some View {
        Group {
            switch reason {
            case .fresh:
                paywall(placement: "onboarding_final")
            case .expired:
                if showingPlansFromExpired {
                    paywall(placement: "expired_reactivation")
                        .transition(JFPageTransition.softDissolve)
                } else {
                    ExpiredWelcomeView(
                        onSeePlans: {
                            withAnimation(Motion.crossFade) {
                                showingPlansFromExpired = true
                            }
                        },
                        onRestore: { Task { await restore() } }
                    )
                    .transition(JFPageTransition.softDissolve)
                }
            }
        }
    }

    // MARK: - The acquisition paywall + exit-intent chain

    private func paywall(placement: String) -> some View {
        PaywallView(
            dismissable: true,
            onSubscribed: { stampPostPurchasePendingIfEligible() },
            onRestore: { Task { await restore() } },
            onDismiss: { triggerExitIntent(abandonedPlan: nil) },
            onPurchaseCancelled: { plan, productId in
                // Tier-attributed at last — the 48h outage of this
                // property is why "which price shocks?" needed a funnel
                // reconstruction instead of one breakdown.
                Analytics.track(.paywallTransactionAbandoned, properties: [
                    "plan": plan,
                    "product_id": productId ?? "unknown"
                ])
                triggerExitIntent(abandonedPlan: plan)
            },
            onReclaimDownsell: {
                // The wall's reclaim row — the offer is a STATE once
                // unlocked, not a one-shot popup. Reopens regardless
                // of the once-per-install auto-show flags.
                Analytics.track(.downsellReclaimTapped)
                downsellTrigger = "reclaim"
                showingDownsell = true
            }
        )
        .onAppear {
            Analytics.track(.paywallView, properties: [
                "paywall_id": "main",
                "placement": placement,
                "variant_id": "keep_wall_v1",
                "default_plan": "quarterly",
                "price_preframe": true,
                "has_trial": false,
                "trial_days": 0
            ])
        }
        .sheet(isPresented: $showingWinback) {
            CancellationWinbackSheet(
                onStayOpen: { showingWinback = false },
                onLeave: { showingWinback = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showingDownsell, onDismiss: { presentQueuedWinbackIfNeeded() }) {
            DownsellPaywallView(
                trigger: downsellTrigger,
                abandonedPlan: lastAbandonedPlan,
                onSubscribed: {
                    showingDownsell = false
                    stampPostPurchasePendingIfEligible()
                },
                onDismiss: {
                    // Reclaim visits don't re-queue the winback — she
                    // opened the sheet herself; a goodbye beat after a
                    // voluntary look reads as pressure.
                    if downsellTrigger == "exit_intent" {
                        winbackQueuedAfterSheet = true
                    }
                    showingDownsell = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showingSmallerStep, onDismiss: { presentQueuedWinbackIfNeeded() }) {
            SmallerStepSheet(
                onSubscribed: {
                    showingSmallerStep = false
                    stampPostPurchasePendingIfEligible()
                },
                onDismiss: {
                    winbackQueuedAfterSheet = true
                    showingSmallerStep = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(true)
        }
    }

    /// Fires from a recovery sheet's onDismiss — the safe moment to
    /// present the next sheet (the swap animation has finished).
    private func presentQueuedWinbackIfNeeded() {
        guard winbackQueuedAfterSheet else { return }
        winbackQueuedAfterSheet = false
        guard !winbackShownThisSession else { return }
        winbackShownThisSession = true
        showingWinback = true
    }

    /// Recovery ladder (2026-07-07 v2, founder call): tier-agnostic,
    /// monotonic de-escalation — the pattern the winning subscription
    /// apps run.
    ///   exit intent #1 → the discounted year (LTV-max first: for a
    ///                    quarterly flincher "$5 more for the whole
    ///                    year" is the strongest frame; for weekly,
    ///                    the per-week math story)
    ///   exit intent #2 → the smaller step (weekly at $5.99)
    ///   after that     → warm winback, once per session
    /// Each sheet auto-shows once per install; the discount stays
    /// reachable forever via the wall's reclaim row once unlocked, so
    /// nobody is ever stranded between the anchor she saw and a
    /// full price she'll no longer pay.
    private func triggerExitIntent(abandonedPlan: String?) {
        lastAbandonedPlan = abandonedPlan
        if !downsellShownOnce {
            downsellShownOnce = true
            downsellTrigger = "exit_intent"
            showingDownsell = true
            return
        }
        if !smallerStepShownOnce {
            smallerStepShownOnce = true
            showingSmallerStep = true
            return
        }
        if !winbackShownThisSession {
            winbackShownThisSession = true
            showingWinback = true
        }
    }

    private func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            let active = info.entitlements[RevenueCatConfig.entitlementID]?.isActive ?? false
            if active {
                // Returning payer: never the first-run intro.
                CoachIntroState.markShown()
            }
        } catch {
            #if DEBUG
            print("[Wall] restore FAILED: \(error)")
            #endif
        }
    }

    // MARK: - Post-purchase first-run stamp
    //
    // Same eligibility the old RootView.presentPostPurchaseFlowIfEligible
    // applied (feature flag + account-activity check + per-device
    // idempotency). The flag is consumed by MainShell on first mount.

    private func stampPostPurchasePendingIfEligible() {
        #if DEBUG
        PaymentService.shared.debugForcePaywall = false
        #endif
        let flagEnabled = JeniMethodFeatureFlag.isEnabled
        let hasActivity = userHasExistingSessionActivity()
        let idempotencyOK = CoachIntroState.shouldShowOnPurchase(hasExistingActivity: hasActivity)
        guard flagEnabled && idempotencyOK else { return }
        UserDefaults.standard.set(true, forKey: MainShell.postPurchasePendingKey)
    }

    private func userHasExistingSessionActivity() -> Bool {
        guard let uid = auth.currentUser?.id.uuidString else { return false }
        let sessionPredicate = #Predicate<SessionLogRecord> { $0.userId == uid }
        var descriptor = FetchDescriptor<SessionLogRecord>(predicate: sessionPredicate)
        descriptor.fetchLimit = 1
        if let hits = try? modelContext.fetch(descriptor), !hits.isEmpty { return true }
        let dayPredicate = #Predicate<DayProgressRecord> { $0.userId == uid }
        var dayDescriptor = FetchDescriptor<DayProgressRecord>(predicate: dayPredicate)
        dayDescriptor.fetchLimit = 1
        return ((try? modelContext.fetch(dayDescriptor))?.isEmpty == false)
    }
}

// MARK: - ExpiredWelcomeView
//
// The reactivation beat. Everything on it is provenance-true: her
// plan day, her shown-up count. Register: warm, zero guilt, restore
// treated as the likely intent.

struct ExpiredWelcomeView: View {
    let onSeePlans: () -> Void
    let onRestore: () -> Void

    @AppStorage("userName") private var userName = ""
    @Environment(\.modelContext) private var modelContext
    @State private var planLine: String? = nil
    @State private var showedUp: Int = 0

    var body: some View {
        JKScreenChrome {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: Space.md) {
                    ItalicAccentText(
                        greeting,
                        italic: ["still yours."],
                        baseFont: Typo.heroHeadline,
                        italicFont: Typo.heroHeadlineItalic,
                        alignment: .center
                    )
                    .lineSpacing(Typo.heroHeadlineLineGap)
                    .kerning(-0.4)
                    .padding(.horizontal, Space.lg)
                    .jkBeat1()

                    Text("your plan, your plates, your trend line. all kept, exactly where you left them.")
                        .font(Typo.teachSub)
                        .lineSpacing(Typo.teachSubLineSpacing)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg + Space.sm)
                        .jkBeat2()
                }

                if planLine != nil || showedUp > 0 {
                    VStack(spacing: 0) {
                        if let planLine {
                            JKReceiptRow(
                                lead: "your plan",
                                punch: planLine,
                                punchItalic: ["waiting"],
                                showsRule: false
                            )
                        }
                        if showedUp > 0 {
                            JKReceiptRow(
                                lead: "you showed up",
                                punch: "\(showedUp) times \u{2665}\u{FE0E}",
                                punchItalic: []
                            )
                        }
                    }
                    .padding(.horizontal, Space.lg + Space.sm)
                    .padding(.top, Space.xl)
                    .jkBeat2(extraDelay: 0.15)
                }

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                JFContinueButton(
                    label: "pick it back up",
                    action: onSeePlans
                )
                Button(action: onRestore) {
                    Text("i already re-subscribed · restore")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(Palette.textSecondary)
                        .tappableArea()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.sm)
            .jkBeat2(extraDelay: 0.25)
        }
        .task { loadReceipts() }
    }

    private var greeting: String {
        userName.isEmpty
            ? "still here. still yours."
            : "\(userName). still here. still yours."
    }

    private func loadReceipts() {
        guard let uid = AuthService.shared.currentUser?.id.uuidString else { return }
        if let plan = ProgramService.shared.activePlan(userId: uid, in: modelContext) {
            let schedule = ProgramScheduleCalculator.compute(
                ProgramScheduleCalculator.Inputs(
                    startDate: plan.startDate, totalDays: plan.totalDays
                )
            )
            let day = min(schedule.programDay, plan.totalDays)
            planLine = "day \(day) is waiting"
        }
        showedUp = UserDefaults.standard.integer(forKey: "stats.shown_up_count")
    }
}
