import Foundation

/// Calculates streak with auto-freeze support.
///
/// Rules:
/// - A streak is consecutive days with at least one session.
/// - If the user misses exactly 1 day and returns the next day,
///   that missed day is auto-frozen (preserved in the streak).
/// - Max 1 freeze per 7 days of streak. A second miss within
///   7 days of the last freeze breaks the streak.
/// - Frozen days are tracked so the calendar can show an ice icon.
///
/// The streak counts backward from today. If today has no session,
/// the streak is still alive if the user worked out yesterday
/// (they might work out later today).
struct StreakCalculator {

    struct Result {
        let count: Int              // total streak days (active + frozen)
        let activeDays: Int         // days with actual sessions
        let frozenDates: Set<Date>  // dates that were auto-frozen
    }

    /// Calculate streak from a set of active dates (days with sessions).
    static func calculate(activeDates: Set<Date>, today: Date = .now) -> Result {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: today)

        // Start from today or yesterday (today might not have a session yet)
        let hasToday = activeDates.contains(todayStart)
        let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart)!
        let hasYesterday = activeDates.contains(yesterday)

        // If neither today nor yesterday has a session, streak is 0
        guard hasToday || hasYesterday else { return Result(count: 0, activeDays: 0, frozenDates: []) }

        // Walk backward from the most recent active day
        let startDate = hasToday ? todayStart : yesterday
        var current = startDate
        var streakCount = 0
        var activeDayCount = 0
        var frozenDates: Set<Date> = []
        var daysSinceLastFreeze = 7  // allow freeze immediately

        while true {
            if activeDates.contains(current) {
                // Active day
                streakCount += 1
                activeDayCount += 1
                daysSinceLastFreeze += 1
            } else {
                // Missed day. Check if we can auto-freeze.
                let dayBefore = cal.date(byAdding: .day, value: -1, to: current)!
                let hasDayBefore = activeDates.contains(dayBefore)

                if hasDayBefore && daysSinceLastFreeze >= 7 {
                    // Auto-freeze: user came back, and it's been 7+ days since last freeze
                    frozenDates.insert(current)
                    streakCount += 1
                    daysSinceLastFreeze = 0
                } else {
                    // Streak breaks here
                    break
                }
            }

            // Move to previous day
            let prev = cal.date(byAdding: .day, value: -1, to: current)!
            current = prev
        }

        return Result(count: streakCount, activeDays: activeDayCount, frozenDates: frozenDates)
    }
}
