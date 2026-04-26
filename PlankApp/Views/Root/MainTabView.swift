import SwiftUI

enum AppTab: String, CaseIterable {
    case workout
    case log
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .workout

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .workout:
                    HomeView()
                case .log:
                    AnalyticsView()
                }
            }

            // iOS-style pill tab bar
            HStack(spacing: 0) {
                tabButton(.workout, label: "workout")
                tabButton(.log, label: "log")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.bgInverse.opacity(0.06), radius: 16, y: 6)
            )
            .padding(.bottom, 20)
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
                .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                .foregroundStyle(selectedTab == tab ? Palette.textInverse : Palette.textSecondary)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    selectedTab == tab
                        ? Capsule().fill(Palette.bgInverse)
                        : Capsule().fill(Color.clear)
                )
        }
    }
}
