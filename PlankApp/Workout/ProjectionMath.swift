import Foundation

// MARK: - ProjectionMath
//
// Single source of truth for the projected goal-weight date shown across
// onboarding (cases 161, 170, 206 recap card) AND on `BecomingProjectionCard`
// (paywall hero + onboarding reveal sequence). Before this consolidation,
// three separate calculations lived in three files and produced different
// dates for the same inputs — user reported the mismatch 2026-06-01 when
// case 170 showed "Jun 29" but the recap card showed "Jul 5" for the
// same weight goal.
//
// All consumers must call `ProjectionMath.projectedGoalDate(...)` (the Date)
// or `ProjectionMath.formattedShortDate(...)` (the "MMM d" lowercase string).
// Never re-implement the math in a screen-specific helper. If a new screen
// needs to "sharpen" the projection visually, do it via chart styling
// (dashed → solid stroke, hide → show date pill), not by tweaking the
// underlying number.

enum ProjectionMath {

    /// ACSM 0.5–1%/wk sustainable-loss pace; anchored at 0.75%. This is the
    /// rate used everywhere — research-defensible, brand-consistent across
    /// paywall, projection card, and onboarding prediction screens.
    static let weeklyLossFraction: Double = 0.0075

    /// Minimum window the projection can compress to. 14 days = 2 weeks.
    /// Floor exists so a tiny loss goal (e.g., 2 lbs) doesn't render as
    /// "next Tuesday" — which reads aspirational-but-fake.
    static let minDays: Int = 14

    /// Maximum window the projection can extend to. 182 days = 26 weeks
    /// (6 months). Cap exists so a large loss goal (50+ lbs at slow pace)
    /// doesn't render as "next March" — which reads daunting.
    static let maxDays: Int = 182

    /// Projected goal-weight date from current/goal weights + activity
    /// level. Returns `nil` when the inputs don't describe a weight-loss
    /// goal (currentKg <= goalKg). Activity level applies a ±14 day
    /// nudge: athletes hit goals sooner, sedentary users hit them later.
    ///
    /// This is the canonical projection across the app. DO NOT re-implement.
    static func projectedGoalDate(
        currentKg: Double,
        goalKg: Double,
        activityLevel: String? = nil
    ) -> Date? {
        guard currentKg > goalKg else { return nil }
        let kgToLose = currentKg - goalKg
        let kgPerWeek = currentKg * weeklyLossFraction
        guard kgPerWeek > 0 else { return nil }
        let weeksRaw = kgToLose / kgPerWeek
        let weeks = min(max(weeksRaw, 2.0), 26.0)
        let baseDays = Int(weeks * 7) + activityNudge(activityLevel)
        let clampedDays = min(max(baseDays, minDays), maxDays)
        return Calendar.current.date(byAdding: .day, value: clampedDays, to: Date())
    }

    /// "MMM d" lowercase ("jul 5") for inline copy. Returns nil when no
    /// projection is possible (no loss goal).
    static func formattedShortDate(
        currentKg: Double,
        goalKg: Double,
        activityLevel: String? = nil
    ) -> String? {
        guard let date = projectedGoalDate(
            currentKg: currentKg,
            goalKg: goalKg,
            activityLevel: activityLevel
        ) else { return nil }
        return Self.shortFormatter.string(from: date).lowercased()
    }

    /// Days-from-today integer when callers need the raw count (chart
    /// width calculations, week-1 callout positioning). Returns the
    /// default 12-week window when no loss goal is set so screens that
    /// drive layout off this number don't collapse.
    static func projectedDays(
        currentKg: Double,
        goalKg: Double,
        activityLevel: String? = nil
    ) -> Int {
        let defaultDays = 84
        guard currentKg > goalKg else { return defaultDays + activityNudge(activityLevel) }
        let kgToLose = currentKg - goalKg
        let kgPerWeek = currentKg * weeklyLossFraction
        guard kgPerWeek > 0 else { return defaultDays + activityNudge(activityLevel) }
        let weeksRaw = kgToLose / kgPerWeek
        let weeks = min(max(weeksRaw, 2.0), 26.0)
        let baseDays = Int(weeks * 7) + activityNudge(activityLevel)
        return min(max(baseDays, minDays), maxDays)
    }

    private static func activityNudge(_ activityLevel: String?) -> Int {
        switch activityLevel {
        case "athlete":   return -14
        case "sedentary": return  14
        default:          return 0
        }
    }

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}
