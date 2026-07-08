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

            // v3 minimal correction: the week as a consistency
            // dot-band — rhythm, never magnitude (bars invite
            // comparing a 10k day against a 2k day; dots read as
            // kept days). Filled = the anchor landed; ring = a real
            // walk; dash = a quiet day (a fact, not a verdict).
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ForEach(Array(steps.weeklyCounts.enumerated()), id: \.offset) { _, count in
                        Group {
                            if count >= goal {
                                Circle()
                                    .fill(Palette.cocoaPrimary)
                                    .frame(width: 6, height: 6)
                            } else if count >= goal / 2 {
                                Circle()
                                    .strokeBorder(Palette.cocoaSecondary, lineWidth: 1)
                                    .frame(width: 6, height: 6)
                            } else {
                                Capsule()
                                    .fill(Palette.hairlineCocoa)
                                    .frame(width: 6, height: 1.5)
                            }
                        }
                        .frame(height: 6)
                    }
                }
                Text("the week's rhythm")
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
        // One authored line from HER week when it has shape; the
        // today-frame otherwise. Passive data earns interpretation.
        let goalDays = steps.weeklyCounts.filter { $0 >= goal }.count
        let walkedDays = steps.weeklyCounts.filter { $0 >= goal / 2 }.count
        if goalDays >= 2 {
            return "\(goalDays) of 7 days reached \(goal.formatted()). the easiest lever, working."
        }
        if walkedDays >= 3 {
            return "real walks on \(walkedDays) days this week. quiet miles count."
        }
        let f = Double(steps.todayCount) / Double(max(goal, 1))
        switch f {
        // The gentle-floor fact (STEPS_VALUE research): low days get
        // the honest curve, not a bigger ask.
        case ..<0.3: return "the benefit starts far below 10k. that number was marketing."
        case ..<1: return "the day is carrying you there."
        default: return "the anchor landed today \u{2665}\u{FE0E}"
        }
    }
}
