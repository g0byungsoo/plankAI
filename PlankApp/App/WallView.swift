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
    /// v6.3 — the save sheet's "or the year" door queues the
    /// discounted year for after the sheet's dismissal settles.
    @State private var yearQueuedAfterSave = false
    /// 5.6 fix (2026-08-10) — the fresh wall's stand-down. Once the
    /// one offer is spent, the X leaves the buy surface for a quiet
    /// screen instead of dead-ending. The expired wall already had its
    /// own stand-down (ExpiredWelcomeView) and reuses that.
    @State private var standingDown = false
    /// Which tier's abandon opened the current recovery (analytics).
    @State private var lastAbandonedPlan: String?
    /// How the downsell was opened this time: "exit_intent" (the
    /// once-per-install auto-show) or "reclaim" (the wall row).
    @State private var downsellTrigger = "exit_intent"
    /// Expired users land on the welcome-back beat first; "see plans"
    /// swaps to the standard paywall.
    @State private var showingPlansFromExpired = false
    /// Release audit 2026-08-08 — the expired wall's restore used to
    /// swallow both outcomes silently; this is the churned payer's
    /// primary CTA, so both "no subscription found" and failure now
    /// speak, mirroring PaywallView's restore alerts.
    @State private var restoreNotice: RestoreNotice?

    private struct RestoreNotice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        Group {
            switch reason {
            case .fresh:
                // 5.6 fix — the fresh wall is two-state now, the shape
                // .expired always had. The X is never a dead end: it
                // either makes the one offer or lands here.
                if standingDown {
                    StandDownView(
                        onSeePlans: {
                            withAnimation(Motion.crossFade) { standingDown = false }
                        },
                        onRestore: { Task { await restore() } }
                    )
                    .transition(JFPageTransition.softDissolve)
                } else {
                    paywall(placement: "onboarding_final")
                        .transition(JFPageTransition.softDissolve)
                }
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
        .alert(item: $restoreNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
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
            // QA: arrive with the one offer already spent, so the very
            // first X press must stand the wall down. This is the state
            // App Store review reached on 1.1.7 (28), where the X did
            // nothing at all.   --uitest-wall-spent
            if ProcessInfo.processInfo.arguments.contains("--uitest-wall-spent") {
                smallerStepShownOnce = true
                downsellShownOnce = true
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
        .sheet(isPresented: $showingDownsell) {
            DownsellPaywallView(
                trigger: downsellTrigger,
                abandonedPlan: lastAbandonedPlan,
                onSubscribed: {
                    showingDownsell = false
                    stampPostPurchasePendingIfEligible()
                },
                onDismiss: {
                    // 5.6 fix — closing an offer returns to the wall and
                    // nothing else. The old code queued a goodbye sheet
                    // here, so one X press could stack two interstitials.
                    showingDownsell = false
                }
            )
            .presentationDetents([.large])
            // 5.6 fix — the grabber is back and the swipe works. A
            // purchase offer she cannot flick away is the same trap the
            // dead X was, one gesture down.
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSmallerStep, onDismiss: {
            if yearQueuedAfterSave {
                yearQueuedAfterSave = false
                downsellShownOnce = true
                downsellTrigger = "from_save"
                showingDownsell = true
            }
        }) {
            SmallerStepSheet(
                onSubscribed: {
                    showingSmallerStep = false
                    stampPostPurchasePendingIfEligible()
                },
                onDismiss: { showingSmallerStep = false },
                onWantYear: {
                    // The price-objector's door: swap to the
                    // discounted year after this sheet settles.
                    yearQueuedAfterSave = true
                    showingSmallerStep = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    /// Recovery ladder v4 (2026-08-10, App Store 5.6 rejection of
    /// 1.1.7 (28): "the (X) button was unresponsive"). The v3 ladder
    /// walked save sheet → discounted year → winback and fell through
    /// to NOTHING once the once-flags were spent; two of them are
    /// @AppStorage, so from the second launch the X was a live button
    /// wired to a no-op on a phase that mounts nothing else.
    ///
    /// The rule is a pure function now (WallExitIntent, table-tested)
    /// and it is total: one tier-matched offer per install, then the
    /// wall stands down. Every press does something the user can see.
    ///   first X / quarterly- / weekly-abandon → the week (smaller step)
    ///   first yearly-abandon                  → the discounted year
    ///   thereafter                            → stand down, always
    ///
    /// The discounted year keeps its two voluntary doors: the save
    /// sheet's "or the year" and the wall's reclaim row. Offers she
    /// opens herself are not pressure; offers that chase her are.
    private func triggerExitIntent(abandonedPlan: String?) {
        lastAbandonedPlan = abandonedPlan
        let action = WallExitIntent.next(
            .init(
                abandonedPlan: abandonedPlan,
                smallerStepShownOnce: smallerStepShownOnce,
                downsellShownOnce: downsellShownOnce
            )
        )
        switch action {
        case .smallerStep:
            smallerStepShownOnce = true
            showingSmallerStep = true
        case .discountedYear:
            downsellShownOnce = true
            downsellTrigger = "exit_intent"
            showingDownsell = true
        case .standDown:
            standDown()
        }
    }

    /// Leave the buy surface. The fresh wall swaps to its quiet screen;
    /// the expired wall returns to the welcome beat it came from. Both
    /// are visible, both are reversible, neither asks for money.
    private func standDown() {
        Analytics.track("wall_stood_down", properties: [
            "reason": reason == .expired ? "expired" : "fresh"
        ])
        withAnimation(Motion.crossFade) {
            switch reason {
            case .fresh:   standingDown = true
            case .expired: showingPlansFromExpired = false
            }
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
        PaymentService.shared.suppressPurchaseAnalytics(reason: "expired_wall_restore")
        V6Funnel.track("restore_started", properties: ["surface": "expired_wall"])
        do {
            let info = try await Purchases.shared.restorePurchases()
            let active = info.entitlements[RevenueCatConfig.entitlementID]?.isActive ?? false
            V6Funnel.track("restore_completed", properties: [
                "surface": "expired_wall",
                "entitlement_active": active,
            ])
            if active {
                Haptics.success()
                // Returning payer: never the first-run intro.
                CoachIntroState.markShown()
            } else {
                restoreNotice = RestoreNotice(
                    title: "No active subscription found",
                    message: "Sign in to the Apple ID with your purchase to restore."
                )
            }
        } catch {
            Analytics.trackException(error, context: "wall.restore")
            #if DEBUG
            print("[Wall] restore FAILED: \(error)")
            #endif
            V6Funnel.track("restore_failed", properties: ["surface": "expired_wall"])
            restoreNotice = RestoreNotice(
                title: "Couldn't restore",
                message: "Something went wrong checking your subscription. Try again in a moment."
            )
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

// MARK: - StandDownView
//
// The fresh wall's exit (2026-08-10, App Store 5.6). Where the X used
// to dead-end, it now lands here: no price, no offer, no countdown.
// The register is the one the app uses everywhere else — her work is
// safe, the door is open, nobody is chasing her. The plans are one
// tap away because she should be able to change her mind, not because
// we are still asking.
//
// It is honest about the wall: a subscription is required, said once,
// plainly, with no consequence framing.

struct StandDownView: View {
    let onSeePlans: () -> Void
    let onRestore: () -> Void

    @AppStorage("userName") private var userName = ""
    /// The reinstalled payer's door, same as the expired wall carries.
    @State private var showingSignIn = false

    var body: some View {
        JKScreenChrome {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: Space.md) {
                    ItalicAccentText(
                        greeting,
                        italic: ["we'll be here."],
                        baseFont: Typo.heroHeadline,
                        italicFont: Typo.heroHeadlineItalic,
                        alignment: .center
                    )
                    .lineSpacing(Typo.heroHeadlineLineGap)
                    .kerning(-0.4)
                    .padding(.horizontal, Space.lg)
                    .jkBeat1()

                    Text("your answers are saved and your plan is already built. it keeps until you want it.")
                        .font(Typo.teachSub)
                        .lineSpacing(Typo.teachSubLineSpacing)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg + Space.sm)
                        .jkBeat2()

                    // Said once, plainly. She is entitled to know why
                    // the app stops here instead of guessing at it.
                    Text("jeni runs on a subscription, so nothing starts until you pick a plan.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg + Space.sm)
                        .padding(.top, Space.sm)
                        .jkBeat2(extraDelay: 0.15)
                }

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                JFContinueButton(
                    label: "see the plans",
                    action: onSeePlans
                )
                Button(action: onRestore) {
                    Text("already subscribed · restore")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(Palette.textSecondary)
                        .tappableArea()
                }
                .buttonStyle(.plain)
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
            NavigationStack {
                SignInPromptView(
                    onContinue: {
                        showingSignIn = false
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
        .task { Analytics.captureScreen("WallStandDown") }
    }

    private var greeting: String {
        userName.isEmpty
            ? "no rush. we'll be here."
            : "\(userName). no rush. we'll be here."
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
