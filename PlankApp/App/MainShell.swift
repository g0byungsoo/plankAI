import SwiftUI

// MARK: - MainShell
//
// App v2 (docs/app_v2/03_IA.md). The entitled experience: three tabs
// over the custom JKTabBar. All three trees stay mounted (state +
// scroll positions survive tab switches, matching the old TabView
// semantics); the inactive ones are hidden + hit-disabled and the
// switch cross-fades with a soft bloom.
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
    @State private var keyboardUp = false
    @State private var trialNudge = TrialNudgeCoordinator.shared

    @State private var showingPostPurchase = false
    @AppStorage("day1PromiseAction") private var day1PromiseAction: String = ""
    @AppStorage("day1PromiseAnchor") private var day1PromiseAnchor: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Defense-in-depth: never render entitled content unentitled.
        if payment.effectiveHasProAccess || payment.isInAuthTransition {
            shell
        } else {
            Palette.bgPrimary.ignoresSafeArea()
        }
    }

    private var shell: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            tabTree(.today) { TodayHost() }
            tabTree(.jeni) { JeniChatHost() }
            tabTree(.becoming) { BecomingHost() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // v3.0 — the bar yields to the keyboard: while she types
            // (chat composer, weight type-in) the tabs step aside
            // instead of floating awkwardly above the keys.
            if !keyboardUp {
                JKTabBar(
                    selection: $router.tab,
                    badge: router.jeniHasUnread ? .jeni : nil
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.22)) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.22)) { keyboardUp = false }
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
            #endif
            Analytics.track(.mainTabAppeared)
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
    }

    /// One tab's tree — mounted always, visible when active. Arrivals
    /// settle with a 4pt rise over the crossfade (v5: the comment
    /// promised this bloom; the code had gone flat) — offset+opacity
    /// only, cheap on mounted trees, skipped under reduce-motion.
    @ViewBuilder
    private func tabTree(_ tab: JKTab, @ViewBuilder content: () -> some View) -> some View {
        let isActive = router.tab == tab
        content()
            .opacity(isActive ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (isActive ? 0 : 4))
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
            .animation(Motion.crossFade, value: router.tab)
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
                // v2.6 RC — PlanView retired (the before-comparison is
                // production build 22 itself; no old JeniFit compiles).
                TodayView()
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
        // v2.6 RC — AnalyticsView retired with PlanView.
        BecomingView()
    }
}
