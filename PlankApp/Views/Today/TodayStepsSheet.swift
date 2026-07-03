import SwiftUI
import UIKit

// MARK: - TodayStepsSheet
//
// App v2.2. The steps beat's detail — a small honest sheet, not a
// fitness dashboard: the ring at reading size, the week as quiet
// bars, and jeni's one-line frame ("the everyday anchor"). HealthKit
// states are first-class: never-asked invites, denied explains the
// path back through Health, connected just shows her week.

struct TodayStepsSheet: View {
    let goal: Int
    @State private var steps = StepsService.shared

    var body: some View {
        JKSheetChrome(
            title: "steps",
            italic: ["steps"],
            eyebrow: "the everyday anchor"
        ) {
            VStack(spacing: Space.lg) {
                switch steps.authStatus {
                case .authorized:
                    connected
                case .notDetermined:
                    JKEmptyState(
                        line: "your steps can count themselves",
                        italic: ["count themselves"],
                        actionLabel: "connect apple health",
                        action: { Task { await steps.requestAccess() } }
                    )
                case .denied, .unavailable:
                    deniedState
                }
            }
            .padding(.top, Space.lg)
            .frame(maxWidth: .infinity)
        }
    }

    private var connected: some View {
        VStack(spacing: Space.lg) {
            JKStepsRing(steps: steps.todayCount, goal: goal, diameter: 128)

            // The week, as quiet bars (device-demo grammar).
            VStack(spacing: 6) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(steps.weeklyCounts.enumerated()), id: \.offset) { idx, count in
                        let maxCount = max(steps.weeklyCounts.max() ?? 1, 1)
                        Capsule()
                            .fill(idx == steps.weeklyCounts.count - 1
                                  ? Palette.accent
                                  : Palette.accentSubtle)
                            .frame(width: 10, height: 14 + 42 * CGFloat(count) / CGFloat(maxCount))
                    }
                }
                Text("your last seven days")
                    .font(Typo.statLabel)
                    .kerning(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
            }

            Text(frameLine)
                .font(.custom("JeniHeroSerif-Italic", size: 16))
                .foregroundStyle(Palette.cocoaSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)
        }
        .padding(.bottom, Space.xl)
    }

    private var deniedState: some View {
        VStack(spacing: Space.md) {
            JKEmptyState(
                line: "health access is off for jenifit",
                italic: ["off"]
            )
            Text("settings, then health, then data access. we'll be here.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                if let url = StepsService.openAppleHealthURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("open health")
                    .font(.custom("DMSans-SemiBold", size: 15))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.22), lineWidth: 1.5)
                    )
            }
            .buttonStyle(JKPress())
        }
        .padding(.bottom, Space.xl)
    }

    private var frameLine: String {
        let f = Double(steps.todayCount) / Double(max(goal, 1))
        switch f {
        case ..<0.3: return "small walks move real numbers."
        case ..<1: return "the day is carrying you there."
        default: return "the anchor landed today \u{2665}\u{FE0E}"
        }
    }
}
