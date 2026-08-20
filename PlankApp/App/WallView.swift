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
//   .fresh    — the acquisition paywall (PaywallView unchanged). Its
//               X leaves the buy surface and presents NOTHING else;
//               see the 5.6 note on dismiss() below.
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

    /// The fresh wall's stand-down: the X leaves the buy surface for a
    /// quiet screen. This is now the ONLY thing a dismissal can do —
    /// there is no second state that presents a price.
    @State private var standingDown = false
    /// Expired users land on the welcome-back beat first; "see plans"
    /// swaps to the standard paywall.
    @State private var showingPlansFromExpired = false
    /// v25 E5 — the after-proof wall's second state (the same
    /// say-it-first-then-plans shape .expired has always had).
    @State private var showingPlansFromProof = false
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
            case .fresh, .afterProof:
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
                } else if reason == .afterProof && !showingPlansFromProof {
                    // v25 E5 — she just logged a real plate. Say the
                    // true thing first, THEN show the same plans. The
                    // paywall itself is untouched.
                    FirstPlateWelcomeView(
                        onSeePlans: {
                            withAnimation(Motion.crossFade) { showingPlansFromProof = true }
                        },
                        onRestore: { Task { await restore() } }
                    )
                    .transition(JFPageTransition.softDissolve)
                } else {
                    paywall(placement: reason == .afterProof
                            ? "after_first_plate" : "onboarding_final")
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

    // MARK: - The acquisition paywall
    //
    // THE DISMISSAL LAW (2026-08-20, App Store review of 1.1.7 (32),
    // Guideline 5.6 — Developer Code of Conduct):
    //
    //   "The app attempts to manipulate customers into making unwanted
    //    In-App Purchases. Specifically, after we dismissed the
    //    purchase screen, another one was displayed."
    //
    // DISMISSING A PURCHASE SURFACE MAY NOT PRESENT ANOTHER ONE.
    //
    // The 2026-08-10 pass answered the previous 5.6 rejection (a dead
    // X) by making every press produce *something*, and chose an offer
    // as that something: one tier-matched offer per install, then a
    // stand-down. It reasoned "an offer is a recovery, a repeated
    // offer is pressure." Apple's line is not how many — it is none.
    //
    // So the transition is gone rather than narrowed. There is no
    // exit-intent rule, no offer sheet, no queued second sheet, no
    // once-per-install flag left to reason about. The X stands the
    // wall down; cancelling Apple's sheet returns to the wall she was
    // already on. She can reopen the plans herself from the
    // stand-down, which is a choice she makes, not one made at her.
    //
    // Deleted with this change, call sites proven first:
    //   WallExitIntent          — the rule that answered a dismissal
    //   SmallerStepSheet        — "what if it was just a week?"
    //   DownsellPaywallView     — the discounted year
    //   the reclaim row         — its only unlock was the auto-show

    private func paywall(placement: String) -> some View {
        PaywallView(
            dismissable: true,
            onSubscribed: { stampPostPurchasePendingIfEligible() },
            onRestore: { Task { await restore() } },
            onDismiss: { standDown() },
            onPurchaseCancelled: { plan, productId in
                // Tier-attributed at last — the 48h outage of this
                // property is why "which price shocks?" needed a funnel
                // reconstruction instead of one breakdown.
                //
                // Analytics ONLY. Cancelling Apple's sheet leaves her on
                // the wall she was already reading; presenting anything
                // here is the 5.6 defect.
                Analytics.track(.paywallTransactionAbandoned, properties: [
                    "plan": plan,
                    "product_id": productId ?? "unknown"
                ])
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
    }

    /// Leave the buy surface. The fresh wall swaps to its quiet screen;
    /// the expired wall returns to the welcome beat it came from. Both
    /// are visible, both are reversible, neither asks for money.
    private func standDown() {
        Analytics.track("wall_stood_down", properties: [
            "reason": {
                switch reason {
                case .expired:    return "expired"
                case .afterProof: return "after_proof"
                case .fresh:      return "fresh"
                }
            }()
        ])
        withAnimation(Motion.crossFade) {
            switch reason {
            case .fresh, .afterProof: standingDown = true
            case .expired:            showingPlansFromExpired = false
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
