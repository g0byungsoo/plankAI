import SwiftUI

enum AppTab: String, CaseIterable {
    case workout
    case analytics
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .workout

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .workout:
                    HomeView()
                case .analytics:
                    AnalyticsView()
                }
            }

            // Custom pill tab bar
            pillTabBar
        }
    }

    // MARK: - Pill Tab Bar

    private var pillTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    Haptics.light()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(Typo.caption)
                        .fontWeight(selectedTab == tab ? .bold : .medium)
                        .foregroundStyle(selectedTab == tab ? Palette.textInverse : Palette.textSecondary)
                        .padding(.horizontal, Space.lg)
                        .padding(.vertical, Space.sm + 2)
                        .background(
                            selectedTab == tab
                                ? Palette.bgInverse
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(Space.xs)
        .background(Palette.bgElevated)
        .clipShape(Capsule())
        .plankShadow()
        .padding(.bottom, Space.sm)
    }
}
