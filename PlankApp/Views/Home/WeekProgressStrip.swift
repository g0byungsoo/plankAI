import SwiftUI

// MARK: - WeekProgressStrip
//
// One soft, flat program-shape signal under the hero (replaces the old
// 3-box stat dashboard). `THEME.md §4`: only the hero is raised — this
// surface has no fill, border, or shadow. `product_direction_2026.md`
// §5.2 (single program-shape signal) + §5.3 (soft commitment, never
// loss aversion — no flame, no "day streak", no streak-loss copy).
//
// Two modes:
//   .method — JeniFit-Method enrollees see their 14-day engagement arc.
//             ENGAGEMENT day (Nth completed session), NOT calendar time,
//             so nobody "falls behind".
//
//                 day 3 of 14
//                 ● ● ● ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○
//
//   .weekly — everyone else sees this week's showing-up rhythm.
//
//                 this week
//                 ● ● ○ ○ ○ ○ ○
//
// Both share the additive "you've shown up N times" tenure (Burke 2011
// self-monitoring without gamification). Source: HomeView's existing
// `currentDay` / `weeklyCount` / `dayProgress.count` — no new persisted
// state, no DB change.

struct WeekProgressStrip: View {
    enum Mode {
        /// Enrolled: engagement day through the 14-day method arc.
        case method(currentDay: Int)
        /// Everyone: sessions logged in the current week.
        case weekly(sessionsThisWeek: Int)
    }

    let mode: Mode

    /// Total completed sessions (day_progress count) — the additive tenure.
    /// Monotonic, never decrements; the "shown up N times" line.
    var sessionsShownUp: Int = 0

    /// Numbered lessons in the method arc (method mode only).
    var methodTotalDays: Int = 14

    /// Dots in the weekly rhythm (weekly mode only).
    private let weeklyDots = 7

    var body: some View {
        switch mode {
        case .method(let currentDay):
            if currentDay >= 1 { methodStrip(currentDay: currentDay) }
        case .weekly(let sessionsThisWeek):
            weeklyStrip(sessionsThisWeek: sessionsThisWeek)
        }
    }

    // MARK: - Method arc (enrolled)

    @ViewBuilder
    private func methodStrip(currentDay: Int) -> some View {
        let filled = min(currentDay, methodTotalDays)
        let headline = currentDay <= methodTotalDays
            ? "day \(currentDay) of \(methodTotalDays)"
            : "the method is yours now"
        let a11y = currentDay <= methodTotalDays
            ? "Day \(currentDay) of \(methodTotalDays)"
            : "Day \(currentDay)"

        strip(headline: headline, headlineA11y: a11y) {
            HStack(spacing: 5) {
                ForEach(0..<methodTotalDays, id: \.self) { idx in
                    Circle()
                        .fill(methodDotFill(idx: idx, filled: filled))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    /// Completed / today / upcoming — a quiet three-tone walk.
    private func methodDotFill(idx: Int, filled: Int) -> Color {
        if idx < filled - 1 {
            return Palette.textSecondary.opacity(0.6)   // completed days
        } else if idx == filled - 1 {
            return Palette.accent                         // today
        } else {
            return Palette.divider                        // upcoming
        }
    }

    // MARK: - Weekly rhythm (everyone)

    @ViewBuilder
    private func weeklyStrip(sessionsThisWeek: Int) -> some View {
        let filled = min(max(sessionsThisWeek, 0), weeklyDots)

        strip(headline: "this week", headlineA11y: "\(sessionsThisWeek) sessions this week") {
            HStack(spacing: 6) {
                ForEach(0..<weeklyDots, id: \.self) { idx in
                    Circle()
                        .fill(idx < filled ? Palette.accent : Palette.divider)
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    // MARK: - Shared shell

    @ViewBuilder
    private func strip<Dots: View>(
        headline: String,
        headlineA11y: String,
        @ViewBuilder dots: () -> Dots
    ) -> some View {
        VStack(spacing: Space.xs) {
            Text(headline)
                .font(Typo.caption)
                .tracking(0.4)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityLabel(headlineA11y)

            dots()
                .accessibilityHidden(true)

            if let tenure = tenureLine {
                Text(tenure)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.accent)
                    .accessibilityLabel(tenure)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xs)
    }

    /// Additive tenure — never decrements; omitted before the first
    /// session (nothing to celebrate yet). Singular/plural handled.
    private var tenureLine: String? {
        guard sessionsShownUp >= 1 else { return nil }
        return sessionsShownUp == 1
            ? "you've shown up once"
            : "you've shown up \(sessionsShownUp) times"
    }
}

#if DEBUG
#Preview("weekly · 2 of 7") {
    WeekProgressStrip(mode: .weekly(sessionsThisWeek: 2), sessionsShownUp: 9)
        .padding().background(Palette.bgPrimary)
}

#Preview("weekly · fresh") {
    WeekProgressStrip(mode: .weekly(sessionsThisWeek: 0), sessionsShownUp: 0)
        .padding().background(Palette.bgPrimary)
}

#Preview("method · day 3") {
    WeekProgressStrip(mode: .method(currentDay: 3), sessionsShownUp: 3)
        .padding().background(Palette.bgPrimary)
}

#Preview("method · day 20 (past arc)") {
    WeekProgressStrip(mode: .method(currentDay: 20), sessionsShownUp: 22)
        .padding().background(Palette.bgPrimary)
}
#endif
