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
                .tabItem {
                    Label("present", systemImage: "sparkles")
                }
                .tag(AppTab.workout)

            AnalyticsView()
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
