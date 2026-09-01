import SwiftUI
import SwiftData
import Auth
import PlankFood
import PlankSync

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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

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

    private func publishGate() {
        // p62 — the chooser holds the modal slot too: an auto-present
        // firing beneath the scan doors is the same silent collision.
        PresentationGate.shared.set(
            .shell, up: showingPostPurchase || showingReauth || showScanChooser)
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
            // QA: go straight through the meal door to the capture flow.
            // The chooser's door needed a TAP to reach the surface behind
            // it, and simctl cannot tap — so the reading, the surface
            // where the most important decisions in the food rail are
            // made, could only be filmed by a full XCUI leg. Pair with
            // --food-debug-autostart and a --food-debug-* fixture.
            if ProcessInfo.processInfo.arguments.contains("--uitest-open-camera") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    router.tab = .today
                    router.open(.snap)
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
        // p58 — the widget hears the session's records the moment she
        // leaves: one publish per backgrounding (foreground reloads
        // are budget-exempt; this is the last truthful word until the
        // next launch).
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background,
                  let uid = auth.currentUser?.id.uuidString
            else { return }
            WidgetBridge.publish(userId: uid, in: modelContext)
        }
        .jeniCover(isPresented: $showingPostPurchase) {
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
        .jeniSheet(isPresented: Binding(
            get: { false },
            set: { if !$0 { trialNudge.clearPending() } }
        ), detents: JeniSheetHeight.full) {
            EmptyView()
        }
        .onChange(of: auth.needsReauth) { _, _ in presentReauthIfNeeded() }
        // p61 — the shell's surfaces occupy the same one-modal slot
        // Home's auto-presents fire into; the gate makes that visible
        // to the arbiter so a winner never dies against an invisible
        // occupant (the D3 failure class, one level up).
        .onChange(of: showingPostPurchase) { _, _ in publishGate() }
        .onChange(of: showingReauth) { _, _ in publishGate() }
        .onChange(of: showScanChooser) { _, _ in publishGate() }
        .jeniSheet(isPresented: $showingReauth, detents: JeniSheetHeight.full) {
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
    /// v25 ship — the paper fade: every tab root is a full-bleed scroll
    /// on paper, so scrolled text used to collide with the status-bar
    /// clock raw (walk-caught on Home and Becoming). A short bgPrimary
    /// gradient under the status bar keeps the clock legible without a
    /// material bar; invisible until content actually passes beneath it.
    @ViewBuilder
    private func tabRoot(@ViewBuilder content: () -> some View) -> some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            content()
        }
        // Pass 51 (D1) — the same paper-fade law at the BOTTOM edge:
        // scrolled content used to ghost raw through the floating bar
        // ("TO…" of TOOLS clipped on Home, Becoming's ledger text
        // visible through the pill — three independent shots in the
        // pass-50 audit). The content margin lets every scroller's
        // last row come to rest clear of the bar; the fade keeps
        // whatever passes beneath it reading as paper, not collision.
        .contentMargins(.bottom, 18, for: .scrollContent)
        .overlay(alignment: .top) {
            GeometryReader { geo in
                LinearGradient(
                    stops: [
                        .init(color: Palette.bgPrimary, location: 0),
                        .init(color: Palette.bgPrimary.opacity(0.85), location: 0.55),
                        .init(color: Palette.bgPrimary.opacity(0), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: geo.safeAreaInsets.top + 10)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
            .frame(height: 0)
        }
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                LinearGradient(
                    stops: [
                        .init(color: Palette.bgPrimary.opacity(0), location: 0),
                        .init(color: Palette.bgPrimary.opacity(0.85), location: 0.5),
                        .init(color: Palette.bgPrimary, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: geo.safeAreaInsets.bottom + 14)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
            .frame(height: 0)
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

    // v25 §43 — **A LIVE PLAN OUTRANKS A DEVICE FLAG, BECAUSE THE FLAG
    // IS SWEPT AND THE PLAN IS NOT.**
    //
    // MEASURED ON A REAL PHONE, 2026-08-15: `programEraEnabled` is one of
    // the 94 keys `clearOnboardingUserDefaults` removes at sign-out, and
    // it is put back only by `syncUserDefaultsFromUserRecord`. So between
    // a sign-in and that restore, a paying customer with an eleven-day-old
    // program was shown **"your plan is here · start my program"** — and
    // she tapped it. `ProgramService.startProgram` archives the live plan
    // and mints a new one with `startDate = today` UNCONDITIONALLY, so her
    // day went back to 1 and `DailyBriefEngine` greeted her with *"day
    // one. one card a day"*. Both screenshots the founder filed are this
    // one line.
    //
    // **The worse outcome is the one where the app knows MORE**: if her
    // plan had already hydrated locally, `startProgram` would have
    // archived it, leaving exactly one live plan and nothing for
    // `reconcileLivePlans` to heal. It survived only because the plan had
    // NOT hydrated yet, which left two live plans and a repairable state.
    //
    // Scheduling the restore earlier (this pass, `AppSync.hydrateAndSync`)
    // shrinks the window. It does not close it: on a slow network it opens
    // right back up, and a slow network is exactly when a returning
    // customer sits longest on the wrong screen. **This closes it**, and
    // reactively — `@Query` republishes the instant the hydrate inserts
    // the plan, so there is no window to lose a race in.
    //
    // A genuinely new customer still gets the onramp: she has no plan.
    // So does a graduated one, whose plans are all archived — the same
    // rule `AppSync` already applies when it restores the flag.
    @Query private var plans: [ProgramPlanRecord]

    private var hasLivePlan: Bool {
        guard let userId = AuthService.shared.currentUser?.id.uuidString else { return false }
        return plans.contains {
            $0.userId.caseInsensitiveCompare(userId) == .orderedSame
                && $0.archivedAt == nil
                && AppSync.livePlanPhases.contains($0.phase)
        }
    }

    var body: some View {
        Group {
            if !programEraEnabled && !hasLivePlan {
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
