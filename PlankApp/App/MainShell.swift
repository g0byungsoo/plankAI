import SwiftUI
import Auth
import PlankFood

// MARK: - MainShell
//
// App v2 (docs/app_v2/03_IA.md). The entitled experience: three tabs
// on the NATIVE tab bar (founder call 2026-07-07: "i like liquid
// apple navigation more") — on iOS 26 that's the floating Liquid
// Glass bar with scroll-minimize; earlier OSes get the standard
// system bar. The system keeps all three trees mounted, so state +
// scroll positions survive switches exactly as the custom bar did.
//
// Defense in depth (07_GATING): the shell renders nothing if the
// phase machine somehow mounted it without entitlement — a second,
// independent read of the same truth the phase derives from.

struct MainShell: View {
    /// UserDefaults flag WallView stamps after an eligible fresh
    /// purchase; consumed here exactly once to present the first-run
    /// post-purchase flow.
    static let postPurchasePendingKey = "postPurchase.firstRunPending"

    @State private var payment = PaymentService.shared
    @State private var router = AppRouter.shared
    @State private var trialNudge = TrialNudgeCoordinator.shared
    @State private var auth = AuthService.shared

    @State private var showingPostPurchase = false
    /// One prompt per app run: a linked identity whose session the auth
    /// server definitively rejected is running on a fallback anonymous
    /// session (AuthService.needsReauth). Signing back in re-attaches her
    /// account + cloud data; declining just closes the sheet.
    @State private var showingReauth = false
    @State private var reauthPromptConsumed = false
    /// Mirrors AppPhaseMachine's care input — see `body`.
    @AppStorage("care_entitlement_active") private var careEntitlementActive = false
    @AppStorage("day1PromiseAction") private var day1PromiseAction: String = ""
    @AppStorage("day1PromiseAnchor") private var day1PromiseAnchor: String = ""

    var body: some View {
        // Defense-in-depth: never render entitled content unentitled.
        // Care patients never hold a RevenueCat entitlement — a live
        // provider connection is what passes the wall for them — so
        // this must read the same three inputs AppPhaseMachine does.
        // Missing the care leg here rendered the cream void BELOW a
        // correctly-derived `.main`: a clinic user reached the app and
        // saw nothing (caught 2026-08-06).
        if payment.effectiveHasProAccess || careEntitlementActive || payment.isInAuthTransition {
            shell
        } else {
            Palette.bgPrimary.ignoresSafeArea()
        }
    }

    /// v11.5 N — the chooser's presentation + the tab it returns to.
    @State private var showScanChooser = false
    @State private var tabBeforeScan: JKTab = .today

    /// Close the chooser, then hand the route to Home (which owns the
    /// module covers). The tiny delay lets the chooser's exit land
    /// before a full-screen cover takes the window.
    private func closeChooser(then route: AppRouter.Route?) {
        showScanChooser = false
        guard let route else { return }
        router.tab = .today
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            router.open(route)
        }
    }

    /// v25 E4 — the chooser's again rail exists only once a plate is
    /// on record. Cheap read (in-memory store, first match).
    private var hasRecentPlates: Bool { lastPlate != nil }

    /// v25 E5 — the most recent distinct plate on file. Names the
    /// chooser's again door. Nil for a user with nothing on record, and
    /// then the again door does not render at all.
    private var lastPlate: FoodLogPersister.FoodLogEntry? {
        guard let uid = auth.currentUser?.id.uuidString else { return nil }
        return FoodLogPersister.recentMeals(userId: uid, limit: 1).first
    }

    /// v25 E7 SAY IT — where today's protein stands, composed from the
    /// SAME sources every other surface reads: `FoodLogPersister`'s day
    /// totals and the resolved floor `FoodModule.proteinTargetProvider`
    /// hands the food package (which is `TargetsService`). One engine,
    /// two moments — this line and the reading's answer are the same
    /// table, so the question and its answer speak in one voice.
    private var standingProteinLine: PlateAnswerEngine.Answer? {
        guard let uid = auth.currentUser?.id.uuidString else { return nil }
        let macros = FoodLogPersister.todayMacros(userId: uid)
        return PlateAnswerEngine.standing(.init(
            proteinOnFileG: Int(macros.protein.rounded()),
            plateProteinG: nil,
            proteinFloorG: FoodModule.proteinTargetProvider?(),
            numericsSuppressed: CohortStore.isNumericSuppressed
        ))
    }

    /// The photograph the meal door wears. Deliberately NOT "the last
    /// plate's photo": a meal logged in words has none, and falling back
    /// to the drawing because yesterday's last entry happened to be
    /// typed would hide a record she actually has. Search back a short
    /// way for the most recent plate that was photographed.
    private var lastPlatePhoto: UIImage? {
        guard let uid = auth.currentUser?.id.uuidString else { return nil }
        return FoodLogPersister.recentMeals(userId: uid, limit: 8)
            .lazy
            .compactMap { FoodPhotoStore.photo(entryId: $0.id) }
            .first
    }

    private var shell: some View {
        ZStack {
            tabs
            // v11.5 N — THE CHOOSER, over a blurred page. Presented
            // in-tree (not a sheet) so the blur is of the LIVE screen
            // she came from, and so the morph can be ours.
            if showScanChooser {
                ScanChooser(
                    onBody: { closeChooser(then: .bodyScan) },
                    onPlate: { closeChooser(then: .snap) },
                    // v25 E7 SAY IT — her own sentence, her own return
                    // key. Straight to the estimate; the describe
                    // screen never gets in the way of words it already
                    // has.
                    onWords: { closeChooser(then: .foodDescribe(text: $0, spoken: true)) },
                    // v25 E4 — the again rail, only once a plate
                    // exists to repeat (an empty rail is noise).
                    onAgain: hasRecentPlates
                        ? { closeChooser(then: .foodAgain) }
                        : nil,
                    // v25 E5 — the doors are made of her record.
                    lastPlateTitle: lastPlate?.title,
                    lastPlatePhoto: lastPlatePhoto,
                    onClose: { closeChooser(then: nil) },
                    standingLine: standingProteinLine
                )
                .zIndex(3)
            }
        }
        .animation(JeniMotion.morph, value: showScanChooser)
    }

    private var tabs: some View {
        TabView(selection: $router.tab) {
            tabRoot { TodayHost() }
                .tabItem { Label(JKTab.today.label, systemImage: JKTab.today.systemImage) }
                .tag(JKTab.today)
            tabRoot { JeniChatHost() }
                .tabItem { Label(JKTab.jeni.label, systemImage: JKTab.jeni.systemImage) }
                .tag(JKTab.jeni)
            // The action item: it hosts nothing. Selecting it opens
            // the chooser and the bar springs back (the MFP/Lovi
            // centre-action grammar on a native bar).
            Color.clear
                .tabItem { Label(JKTab.scan.label, systemImage: JKTab.scan.systemImage) }
                .tag(JKTab.scan)
            tabRoot { BecomingHost() }
                .tabItem { Label(JKTab.becoming.label, systemImage: JKTab.becoming.systemImage) }
                .tag(JKTab.becoming)
        }
        .tint(Palette.cocoaPrimary)
        .modifier(LiquidTabBarPolish())
        .onChange(of: router.tab) { old, new in
            if new == .scan {
                // Never a destination: remember where she was, open
                // the chooser, restore the bar immediately.
                tabBeforeScan = old == .scan ? .today : old
                router.tab = tabBeforeScan
                JeniHaptic.tick()
                showScanChooser = true
                return
            }
            // The custom bar owned this haptic; the system bar doesn't
            // fire one. Every switch is a change she caused (tap or a
            // link she tapped), so the soft mark stays.
            if old != new { Haptics.soft() }
            // Release audit 2026-08-08 — Becoming went analytics-dark
            // with the v21 rebuild (journey_* events died with their
            // views); one per-visit event keeps the whole tab from
            // being invisible. Rides the 0.5s coalesce like its chat
            // sibling.
            if new == .becoming, old != new {
                Analytics.track("becoming_opened")
            }
        }
        .onAppear {
            #if DEBUG
            // QA: land on a specific tab (simctl can't tap the bar).
            let args = ProcessInfo.processInfo.arguments
            if let idx = args.firstIndex(of: "--uitest-start-tab"),
               idx + 1 < args.count,
               let tab = JKTab(rawValue: args[idx + 1]) {
                router.tab = tab
            }
            // v25 E4 (gap-map T2, finally): the book's door works
            // from ANY start tab — the arg used to be handled only
            // inside Becoming's onAppear, so a launch landing on
            // Today silently no-opped and the walk notes recorded
            // "THE BOOK has no door" against a door that exists.
            if args.contains("--uitest-open-food-journal") {
                router.tab = .becoming
            }
            #endif
            #if DEBUG
            // QA: open THE CHOOSER without a tab tap (simctl can't tap).
            if ProcessInfo.processInfo.arguments.contains("--uitest-open-scan-chooser") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showScanChooser = true
                }
            }
            #endif
            Analytics.track(.mainTabAppeared)
            presentReauthIfNeeded()
            // Stamp v2 for everyone reaching main — post-purchase
            // fresh users must never hit the migration phase later
            // (it exists only for footprints predating this mount).
            if UserDefaults.standard.string(forKey: "appV2SeenAt")?.isEmpty != false {
                UserDefaults.standard.set(
                    ISO8601DateFormatter().string(from: .now),
                    forKey: "appV2SeenAt"
                )
            }
            consumePostPurchaseFlagIfPending()
        }
        .onOpenURL { router.handle(url: $0) }
        .fullScreenCover(isPresented: $showingPostPurchase) {
            PostPurchaseFlowView(
                onFinish: {
                    CoachIntroState.markShown()
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { showingPostPurchase = false }
                },
                promiseAction: day1PromiseAction.isEmpty ? nil : day1PromiseAction,
                promiseAnchor: day1PromiseAnchor.isEmpty ? nil : day1PromiseAnchor
            )
            .presentationBackground(Palette.bgPrimary)
        }
        // Trial-nudge machinery, preserved dormant (v1.1.3 pay-upfront
        // ships no intro offer; re-enable by restoring the binding).
        .sheet(isPresented: Binding(
            get: { false },
            set: { if !$0 { trialNudge.clearPending() } }
        )) {
            EmptyView()
        }
        .onChange(of: auth.needsReauth) { _, _ in presentReauthIfNeeded() }
        .sheet(isPresented: $showingReauth) {
            NavigationStack {
                SignInPromptView(
                    onContinue: {
                        showingReauth = false
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
                            showingReauth = false
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
    }

    private func presentReauthIfNeeded() {
        guard auth.needsReauth, !reauthPromptConsumed else { return }
        reauthPromptConsumed = true
        Analytics.track("reauth_prompt_shown")
        showingReauth = true
    }

    /// One tab's tree over the cream ground. The old custom-bar shell
    /// painted one shared background; native TabView hosts each tab in
    /// its own hierarchy, so each root re-asserts the only background.
    @ViewBuilder
    private func tabRoot(@ViewBuilder content: () -> some View) -> some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            content()
        }
    }

    private func consumePostPurchaseFlagIfPending() {
        let d = UserDefaults.standard
        guard d.bool(forKey: Self.postPurchasePendingKey) else { return }
        d.set(false, forKey: Self.postPurchasePendingKey)
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { showingPostPurchase = true }
    }
}

/// iOS 26's Liquid Glass bar minimizes as she scrolls down — content
/// takes the stage, the bar returns on scroll-up. Earlier OSes keep
/// the standard bar untouched.
private struct LiquidTabBarPolish: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

// MARK: - Tab hosts (P2 scaffolding)
//
// TodayHost swaps PlanView → TodayView in P3; JeniChatHost fills in
// P4; BecomingHost is curated in P6. Hosts exist so the shell's
// structure is final from day one.

struct TodayHost: View {
    @AppStorage("programEraEnabled") private var programEraEnabled: Bool = false

    var body: some View {
        Group {
            if !programEraEnabled {
                ProgramOnrampView()
            } else {
                // v11 T3 — HOME from zero (docs/app_v11 §6). TodayView
                // retired; its spine lives on inside HomeView.
                HomeView()
            }
        }
    }
}

struct JeniChatHost: View {
    var body: some View {
        JeniChatView()
    }
}

struct BecomingHost: View {
    var body: some View {
        // v11 T4 — the journal retired; the chart-driven summary
        // (docs/app_v11 §7) is becoming now.
        BecomingSummaryView()
    }
}
