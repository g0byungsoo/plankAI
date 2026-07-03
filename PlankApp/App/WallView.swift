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
    @State private var showingDownsell = false
    @State private var showingWinback = false
    @State private var winbackShownThisSession = false
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
            onDismiss: { triggerExitIntent() },
            onPurchaseCancelled: {
                Analytics.track(.paywallTransactionAbandoned)
                triggerExitIntent()
            }
        )
        .onAppear {
            Analytics.track(.paywallView, properties: [
                "paywall_id": "main",
                "placement": placement,
                "variant_id": "control",
                "default_plan": "annual",
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
        .sheet(isPresented: $showingDownsell) {
            DownsellPaywallView(
                onSubscribed: {
                    showingDownsell = false
                    stampPostPurchasePendingIfEligible()
                },
                onDismiss: {
                    showingDownsell = false
                    if !winbackShownThisSession {
                        winbackShownThisSession = true
                        showingWinback = true
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(true)
        }
    }

    private func triggerExitIntent() {
        if !downsellShownOnce {
            downsellShownOnce = true
            showingDownsell = true
        } else if !winbackShownThisSession {
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
