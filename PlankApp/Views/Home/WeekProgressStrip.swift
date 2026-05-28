import SwiftUI

// MARK: - WeekProgressStrip
//
// Engagement-based program-shape signal at the top of HomeView (Phase 10).
// Shows the user's progress through the 14-day JeniFit Method by their
// ENGAGEMENT day — their Nth completed session — NOT calendar time since
// signup. Nobody "falls behind": the day only advances when they show up,
// so there's no program-debt / "you're behind" guilt trigger (the cancel
// driver the day-model research flagged for this audience).
//
//     day 3 of 14
//     ● ● ● ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○
//
// Source: HomeView's existing `currentDay` (derived from
// DayProgressRecord.programDay) — no new persisted state, no DB change.
// Phase 2 restyles this into the arc + "shown up N times" momentum.

struct WeekProgressStrip: View {
    /// The user's current engagement day (1-based). < 1 = hidden.
    let currentDay: Int

    /// Total numbered lessons in the method arc.
    var totalDays: Int = 14

    var body: some View {
        if currentDay >= 1 {
            let filled = min(currentDay, totalDays)
            VStack(spacing: Space.xs) {
                Text(headline)
                    .font(Typo.caption)
                    .tracking(0.4)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityLabel(accessibilityLabel)

                HStack(spacing: 5) {
                    ForEach(0..<totalDays, id: \.self) { idx in
                        Circle()
                            .fill(dotFill(idx: idx, filled: filled))
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.xs)
        }
    }

    private var headline: String {
        currentDay <= totalDays
            ? "day \(currentDay) of \(totalDays)"
            : "the method is yours now"
    }

    private var accessibilityLabel: String {
        currentDay <= totalDays ? "Day \(currentDay) of \(totalDays)" : "Day \(currentDay)"
    }

    private func dotFill(idx: Int, filled: Int) -> Color {
        if idx < filled - 1 {
            return Palette.textSecondary.opacity(0.6)   // completed days
        } else if idx == filled - 1 {
            return Palette.accent                         // today
        } else {
            return Palette.divider                        // upcoming
        }
    }
}

#if DEBUG
#Preview("day 3") {
    WeekProgressStrip(currentDay: 3).padding().background(Palette.bgPrimary)
}

#Preview("day 14") {
    WeekProgressStrip(currentDay: 14).padding().background(Palette.bgPrimary)
}

#Preview("past arc (day 20)") {
    WeekProgressStrip(currentDay: 20).padding().background(Palette.bgPrimary)
}
#endif
