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
//               the acquisition paywall is one tap deeper, and the
//               sign-in door (2026-07-25) lets a logged-out payer
//               recover her account without leaving the wall.
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
    /// v6.3 — the save sheet's "or the year" door queues the
    /// discounted year for after the sheet's dismissal settles.
    @State private var yearQueuedAfterSave = false
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
            #if DEBUG
            // QA: land inside the save moment without a tap.
            //   --uitest-save-moment
            if ProcessInfo.processInfo.arguments.contains("--uitest-save-moment") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    showingSmallerStep = true
                }
            }
            // QA: land inside the discounted-year sheet.
            //   --uitest-open-downsell
            if ProcessInfo.processInfo.arguments.contains("--uitest-open-downsell") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    downsellTrigger = "reclaim"
                    showingDownsell = true
                }
            }
            #endif
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
        .sheet(isPresented: $showingSmallerStep, onDismiss: {
            if yearQueuedAfterSave {
                yearQueuedAfterSave = false
                downsellShownOnce = true
                downsellTrigger = "from_save"
                showingDownsell = true
            } else {
                presentQueuedWinbackIfNeeded()
            }
        }) {
            SmallerStepSheet(
                onSubscribed: {
                    showingSmallerStep = false
                    stampPostPurchasePendingIfEligible()
                },
                onDismiss: {
                    winbackQueuedAfterSheet = true
                    showingSmallerStep = false
                },
                onWantYear: {
                    // The price-objector's door: swap to the
                    // discounted year after this sheet settles.
                    yearQueuedAfterSave = true
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

    /// Recovery ladder v3 (2026-07-17 DATA REVERSAL of the 07-07
    /// year-first call — docs/app_v6/03_CONVERSION.md): ten days of
    /// year-first exit offers produced 183 downsell views and ~zero
    /// takes while 80-85% of wall viewers dismissed; the wall's own
    /// tier picks run weekly-first (27 of 68). The dismisser's
    /// objection is COMMITMENT, so the save moment now leads with the
    /// smallest door and keeps the discounted year as (a) the sheet's
    /// own quiet second door, (b) the yearly-abandon route where it
    /// is tier-matched, (c) the wall's reclaim row forever.
    ///   X-dismiss / quarterly- / weekly-abandon → the week (smaller
    ///                    step, $5.99) with "or the year, 30% off"
    ///   yearly-abandon → the discounted year (tier-matched)
    ///   after both     → warm winback, once per session
    private func triggerExitIntent(abandonedPlan: String?) {
        lastAbandonedPlan = abandonedPlan
        if abandonedPlan == "yearly" {
            if !downsellShownOnce {
                downsellShownOnce = true
                downsellTrigger = "exit_intent"
                showingDownsell = true
                return
            }
        } else {
            if !smallerStepShownOnce {
                smallerStepShownOnce = true
                showingSmallerStep = true
                return
            }
            if !downsellShownOnce {
                downsellShownOnce = true
                downsellTrigger = "exit_intent"
                showingDownsell = true
                return
            }
        }
        if !winbackShownThisSession {
            winbackShownThisSession = true
            showingWinback = true
        }
    }

    private func restore() async {
        // Purchases.shared fatalErrors before configure. The .wall phase
        // only mounts after entitlementReady (which arms inside
        // startCustomerInfoStream, post-configure), so this is safe today —
        // but the guard matches every sibling paywall surface and future-
        // proofs against a gating-order refactor (same crash class fixed on
        // Downsell/UpgradeMoment 2026-07-17).
        guard Purchases.isConfigured else { return }
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
    /// The sign-in door (2026-07-25) — presents the reusable
    /// SignInPromptView sheet so a logged-out payer can recover her
    /// account from the wall itself.
    @State private var showingSignIn = false

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
                                punch: "\(showedUp) times",
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
                // Identity-recovery (2026-07-25): the sign-in door.
                // A paying user who reinstalled or got re-keyed to a
                // fresh anonymous uid lands here with her subscription
                // attached to her OLD account — restore alone can't
                // find her cloud data, and before this link the wall
                // had no way back in. Sign-in re-keys auth, the
                // existing onAuthChanged pipeline follows with logIn +
                // hydration, and PaymentService's auto-sync recovery
                // re-attaches the receipt.
                Button {
                    Haptics.light()
                    Analytics.track("wall_sign_in_tapped")
                    showingSignIn = true
                } label: {
                    Text("signed in before? sign in")
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
        .sheet(isPresented: $showingSignIn) {
            // Same reusable surface AccountView presents (its
            // NavigationStack + xmark chrome). On success or cancel,
            // onContinue dismisses; the wall re-evaluates from the
            // entitlement stream on its own.
            NavigationStack {
                SignInPromptView(
                    onContinue: {
                        showingSignIn = false
                        // onContinue fires on success AND on cancel;
                        // only a real sign-in (no longer anonymous)
                        // opens the interactive recovery window.
                        if !AuthService.shared.isAnonymous {
                            PaymentService.shared.noteInteractiveSignIn(
                                signedInUserID: AuthService.shared.currentUser?.id.uuidString
                            )
                        }
                    },
                    mode: .signIn
                )
                .background(Palette.programEraBg)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showingSignIn = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(Palette.bgElevated)
                                .clipShape(Circle())
                                .tappableArea()
                        }
                        .accessibilityLabel("Close sign in")
                    }
                }
            }
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
