import SwiftUI

/// iOS 26 native TabView. Picking native over the prior custom HStack
/// pill so we get liquid glass styling for free — and so future tabs
/// (search, profile, etc.) can be added without reinventing chrome.
///
/// `Tab` (iOS 18+) gets us the cleanest declaration; on iOS 26 the bar
/// renders as liquid glass automatically.
struct MainTabView: View {

    enum AppTab: Hashable {
        case workout
        case log
    }

    @State private var selectedTab: AppTab = .workout

    var body: some View {
        TabView(selection: $selectedTab) {
            // Mindful naming: "present" for today's plan + active state,
            // "past" for the log of what's already happened. The pair reads
            // as a meditation cue, not a feature menu, which fits the
            // JeniFit voice better than "Workout / Log".
            HomeView()
                .tabBloom(isActive: selectedTab == .workout)
                .tabItem {
                    Label("present", systemImage: "sparkles")
                }
                .tag(AppTab.workout)

            AnalyticsView()
                .tabBloom(isActive: selectedTab == .log)
                .tabItem {
                    // "becoming" leans into Dweck/Burnette growth-mindset
                    // research — present-progressive framing accommodates
                    // plateaus better than the static "past" frame did.
                    Label("becoming", systemImage: "book.closed.fill")
                }
                .tag(AppTab.log)
        }
        .tint(Palette.accent)
        .onAppear {
            #if DEBUG
            print("[FUNNEL] main_tab_appeared | paywall cover dismissed, user is now in the app")
            #endif
        }
    }
}

/// Tab-arrival "bloom": when a tab becomes active, its content resolves from
/// a soft blur + slight scale + dimmed opacity into focus (~0.5s), with a
/// soft haptic — so switching present ↔ becoming reads smooth and magical
/// rather than an instant content swap. The native liquid-glass bar stays
/// crisp (this only affects the tab's content, not the bar).
///
/// `appearedOnce` is seeded to the tab's initial active state so each tab's
/// own first-load entrance (HomeView / AnalyticsView animateIn) owns the
/// first reveal, and the bloom takes over on every subsequent arrival —
/// the two never double up. Reduce-motion snaps with no bloom.
private struct TabBloom: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appearedOnce: Bool
    @State private var blur: CGFloat = 0
    @State private var opacity: Double = 1

    init(isActive: Bool) {
        self.isActive = isActive
        _appearedOnce = State(initialValue: isActive)
    }

    func body(content: Content) -> some View {
        // Opaque cream backdrop under the blooming content so the blur + fade
        // never reveal the black window behind the tab. No scaleEffect — the
        // earlier scale shrank the content and exposed black gaps at the
        // top/bottom edges. Just a soft blur resolving into focus.
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            content
                .blur(radius: blur)
                .opacity(opacity)
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            guard appearedOnce else { appearedOnce = true; return }
            guard !reduceMotion else { return }
            // Set the bloom-from state this frame, then resolve to clear next
            // runloop so the blur is actually rendered before it animates away.
            blur = 5; opacity = 0.85
            Haptics.soft()
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.45)) {
                    blur = 0; opacity = 1
                }
            }
        }
    }
}

private extension View {
    func tabBloom(isActive: Bool) -> some View { modifier(TabBloom(isActive: isActive)) }
}
