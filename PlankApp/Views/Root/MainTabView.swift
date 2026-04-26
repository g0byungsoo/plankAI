import SwiftUI

enum AppTab: String, CaseIterable {
    case workout
    case analytics
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .workout

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .workout:
                    HomeView()
                case .analytics:
                    AnalyticsView()
                }
            }

            // Bottom tab bar — SetLog style
            HStack(spacing: 0) {
                tabButton(.workout, label: "workout")
                tabButton(.analytics, label: "analytics")
            }
            .padding(.horizontal, Space.xs + 2)
            .padding(.vertical, Space.xs)
            .background(
                Capsule()
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.bgInverse.opacity(0.08), radius: 12, y: 4)
            )
            .padding(.bottom, Space.sm)
        }
    }

    private func tabButton(_ tab: AppTab, label: String) -> some View {
        Button {
            Haptics.light()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(label)
                .font(Typo.caption)
                .fontWeight(selectedTab == tab ? .bold : .medium)
                .foregroundStyle(selectedTab == tab ? Palette.textInverse : Palette.textSecondary)
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.sm + 2)
                .background(
                    selectedTab == tab
                        ? Capsule().fill(Palette.bgInverse)
                        : Capsule().fill(Color.clear)
                )
        }
    }
}
