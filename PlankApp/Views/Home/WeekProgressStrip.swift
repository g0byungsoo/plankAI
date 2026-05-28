import SwiftUI

// MARK: - WeekProgressStrip
//
// Lightweight program-shape signal at the top of HomeView. Renders:
//
//     Week 1 · day 3 of 12
//     ● ● ● ○ ○ ○ ○
//
// Per docs/product_direction_2026.md §8.2 — the user research synthesized
// across the four 2026 passes was unambiguous that a single program-shape
// signal (Week N · day M of 12) carries the "this is a program, not an
// app of workouts" weight without the over-engineering of an 84-day
// calendar grid (BetterMe's calendar reads as workout-app chrome, which
// pulls JeniFit away from the Noom-alternative weight-loss-program slot).
//
// Day index source priority (handled by caller — strip just renders):
//   1. coach_intro_shown_at   (Phase A — new users)
//   2. jenimethod.enrolled_at (legacy ritual users — pre-Phase-A)
//   3. earliest session log   (users who never saw either gate)
//
// Hides itself (returns EmptyView) if startDate is nil — never shows
// "day 0 of 12" garbage. Caller can pass nil for a clean no-op.

struct WeekProgressStrip: View {
    /// Day the user's 12-week program began. Nil = strip is hidden.
    let startDate: Date?

    /// Total weeks in the program. Locked at 12 per
    /// docs/product_direction_2026.md §12 Q1.
    var totalWeeks: Int = 12

    var body: some View {
        if let info = progressInfo {
            VStack(spacing: Space.xs) {
                Text(info.headline)
                    .font(Typo.caption)
                    .tracking(0.4)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityLabel("Week \(info.weekNumber), day \(info.dayInWeek) of 7")

                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { idx in
                        Circle()
                            .fill(dotFill(idx: idx, todayIdx: info.dayInWeek - 1))
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.xs)
        }
    }

    // MARK: - Day computation

    private var progressInfo: ProgressInfo? {
        guard let start = startDate else { return nil }
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        let today    = cal.startOfDay(for: .now)
        guard let daysSince = cal.dateComponents([.day], from: startDay, to: today).day,
              daysSince >= 0
        else { return nil }

        // Week 1 spans days 0-6 in 0-indexed terms; display is 1-indexed.
        let week = (daysSince / 7) + 1
        let dayInWeek = (daysSince % 7) + 1

        // Past-12-weeks users still get a strip (the line keeps Jeni
        // present), but cap the dot row at week 12 so the layout stays
        // stable. Headline shows "week 12+" beyond the program.
        if week > totalWeeks {
            return ProgressInfo(
                weekNumber: week,
                dayInWeek: dayInWeek,
                headline: "week \(totalWeeks)+ · day \(dayInWeek) of 7",
                capped: true
            )
        }

        return ProgressInfo(
            weekNumber: week,
            dayInWeek: dayInWeek,
            headline: "week \(week) of \(totalWeeks) · day \(dayInWeek) of 7",
            capped: false
        )
    }

    private func dotFill(idx: Int, todayIdx: Int) -> Color {
        if idx < todayIdx {
            return Palette.textSecondary.opacity(0.6)   // past days
        } else if idx == todayIdx {
            return Palette.accent                        // today
        } else {
            return Palette.divider                       // future days
        }
    }
}

private struct ProgressInfo {
    let weekNumber: Int
    let dayInWeek: Int
    let headline: String
    let capped: Bool
}

#if DEBUG
#Preview("week 1 day 3") {
    WeekProgressStrip(startDate: Calendar.current.date(byAdding: .day, value: -2, to: .now))
        .padding()
        .background(Palette.bgPrimary)
}

#Preview("week 4 day 5") {
    WeekProgressStrip(startDate: Calendar.current.date(byAdding: .day, value: -25, to: .now))
        .padding()
        .background(Palette.bgPrimary)
}

#Preview("past 12 weeks") {
    WeekProgressStrip(startDate: Calendar.current.date(byAdding: .day, value: -100, to: .now))
        .padding()
        .background(Palette.bgPrimary)
}

#Preview("nil = hidden") {
    WeekProgressStrip(startDate: nil)
        .padding()
        .background(Palette.bgPrimary)
}
#endif
