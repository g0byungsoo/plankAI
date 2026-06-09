import Foundation

// MARK: - ProgramScheduleCalculator
//
// v1.1 program pivot. Pure function: derives "what day of the
// program is today" from a stored start_date + Calendar offset.
// NEVER stores program_day — always computed at read time. This
// matches the [[project-engagement-day]] precedent for
// EngagementDayCalculator and avoids the "+1 per session" class
// of bugs that come from storing derived counters.
//
// Founder constraint: program is fixed-duration (default 75 days
// for the standard plan; Maintenance 30 = 30 days; Recomp 60 =
// 60 days; Soft Pause = 28 days). The calculator handles all of
// them via a totalDays parameter.
//
// Edge cases:
// - User opens the app on the day they enrolled → programDay = 1
//   (not 0 — Day 1 is the first day, never Day 0).
// - User skips a day → programDay still advances by Calendar.day
//   (we don't pause on inactive days; that's the engagement-day
//   semantic, not the program-day semantic).
// - User finishes Day N → programDay = N until midnight, then N+1.
// - User passes totalDays → isPostGoal = true; UI surfaces the
//   ChapterCompleteView next-program picker.

public enum ProgramScheduleCalculator {

    public struct Inputs {
        public let startDate: Date
        public let totalDays: Int
        public let now: Date

        public init(startDate: Date, totalDays: Int, now: Date = Date()) {
            self.startDate = startDate
            self.totalDays = totalDays
            self.now = now
        }
    }

    public struct Result {
        /// 1-indexed day number within the program. Day 1 = the
        /// enrollment day. Capped at totalDays + 1 once isPostGoal
        /// flips so the home greeting doesn't show "Day 152".
        public let programDay: Int

        /// Total days in the program (passed through from Inputs
        /// for convenience to UI callers).
        public let totalDays: Int

        /// True when programDay > totalDays — fires the Day-75
        /// graduation sentinel + ChapterCompleteView 4-card picker.
        public let isPostGoal: Bool

        /// Date the program ends. Last active day = startDate +
        /// (totalDays - 1) days; the next day after that is
        /// post-goal.
        public let goalDate: Date

        /// Days remaining before goalDate, clamped ≥ 0. Used in
        /// chrome ("12 days to go").
        public let daysRemaining: Int

        /// Program week (1-indexed) — used by IntensityProfile's
        /// ramp rules (Soft wk1=7min, wk2=10, etc.).
        public var programWeek: Int {
            max(1, ((programDay - 1) / 7) + 1)
        }
    }

    /// Default total days for the standard plan. Per the founder-
    /// locked plan, the standard is 75 days but the marketing
    /// surface never says "75 days" — it leads with "custom".
    public static let standardTotalDays: Int = 75

    public static func compute(_ inputs: Inputs) -> Result {
        let calendar = Calendar(identifier: .gregorian)
        let startDay = calendar.startOfDay(for: inputs.startDate)
        let today = calendar.startOfDay(for: inputs.now)

        // Day 1 = the start day itself. ordinal(of: today) - ordinal(of: start)
        // is how many calendar days have passed; +1 to 1-index.
        let dayOffset = calendar.dateComponents([.day], from: startDay, to: today).day ?? 0
        let rawProgramDay = dayOffset + 1

        let isPostGoal = rawProgramDay > inputs.totalDays
        let clampedDay = max(1, min(rawProgramDay, inputs.totalDays + 1))

        // Last active day = start + (totalDays - 1). Goal date = the
        // day after (first post-goal day).
        let goalDate = calendar.date(byAdding: .day, value: inputs.totalDays, to: startDay) ?? startDay

        let remaining: Int
        if isPostGoal {
            remaining = 0
        } else {
            remaining = max(0, inputs.totalDays - rawProgramDay + 1)
        }

        return Result(
            programDay: clampedDay,
            totalDays: inputs.totalDays,
            isPostGoal: isPostGoal,
            goalDate: goalDate,
            daysRemaining: remaining
        )
    }

    // MARK: - Display helpers

    /// Formatter for the "march 16 → april 30" date-range strip
    /// per Her75 register. Lowercase month names + en-dash.
    public static func dateRangeLowercase(startDate: Date, totalDays: Int) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let endDate = calendar.date(byAdding: .day, value: totalDays - 1, to: startDate) ?? startDate
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate).lowercased()
        let end = formatter.string(from: endDate).lowercased()
        return "\(start) → \(end)"
    }

    /// "Day N of total" — used in PlanView greeting.
    public static func dayOfTotalLabel(programDay: Int, totalDays: Int) -> String {
        "day \(programDay) of \(totalDays)"
    }
}
