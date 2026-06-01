import Foundation
import PlankSync

// MARK: - EngagementDayCalculator
//
// The single source of truth for "what day of the JeniFit journey is the
// user on." Pure struct (no instance state, no SwiftData / Supabase
// dependencies), follows the same pattern as StreakCalculator.
//
// Definition: a user's engagement day is the count of DISTINCT CALENDAR
// DAYS on which they completed at least one qualifying session, on or
// before `asOf`.
//
// Why derived, not stored:
//   The prior design stored `programDay: Int` on DayProgressRecord and
//   bumped it by `(max + 1)` on each session save. That counter raced
//   under three real conditions:
//     1) SwiftData @Query lag between two back-to-back saves on the
//        same calendar day → second save couldn't see the first → it
//        treated today as new and wrote programDay+1
//     2) Cloud hydrate (last-write-wins on updatedAt) could resurrect
//        duplicate rows for the same date with different programDay
//     3) Date round-trip through JSON could drift across midnight
//   All three race classes vanish when `programDay` becomes a derived
//   read from the immutable, append-only SessionLogRecord set.
//
// Properties:
//   • Idempotent — same input set, same output, every time
//   • Race-free — no incremental writes anywhere
//   • Self-healing — existing users with corrupted programDay values
//     get the correct count on the very next render, no migration
//   • Skips inactive days — only days with actual sessions count
//   • Caps multi-session days at one day each — finishing 3 sessions
//     in one calendar day is one engagement day, not three
//
// Performance: O(N) over the user's full session history. N is < 500
// for a year of daily use (~365 sessions), so the worst case is
// microseconds on every device JeniFit ships to.

enum EngagementDayCalculator {

    /// Distinct calendar days the user completed a qualifying session,
    /// on or before `asOf`. Returns 0 if no qualifying sessions exist.
    /// "Today" counts only if the user has already saved a session today;
    /// otherwise the count reflects history through end-of-yesterday.
    static func daysCompleted(
        sessionLogs: [SessionLogRecord],
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let cutoff = calendar.startOfDay(for: asOf)
        var days: Set<Date> = []
        for log in sessionLogs where isQualifying(log) {
            let day = calendar.startOfDay(for: log.completedAt)
            // <= cutoff so a session completed earlier today is counted,
            // but tomorrow's clock-skewed write (rare) isn't.
            // Use `< cutoff + 1 day` to include all of "today" exactly.
            if day <= cutoff { days.insert(day) }
        }
        return days.count
    }

    /// "What day of the journey is the user on" — the user-facing number.
    /// This is the count of distinct days they've ALREADY shown up
    /// (including today if they've saved a session today). It's the same
    /// number as `daysCompleted`; the alias clarifies the read intent at
    /// call sites that want the program-day display value.
    static func currentDay(
        sessionLogs: [SessionLogRecord],
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        daysCompleted(sessionLogs: sessionLogs, asOf: asOf, calendar: calendar)
    }

    /// Pre-save preview: "what programDay should this session be stamped
    /// with." Used at the write site to populate DayProgressRecord.programDay
    /// with the correct derived value (so cross-device sync gets a
    /// consistent column even though the column is no longer source of
    /// truth). The session being saved is appended into the set before
    /// counting, so if today was previously empty, this returns N+1; if
    /// today was already counted (a prior session today), this returns N.
    static func programDayForNewSession(
        existingLogs: [SessionLogRecord],
        newSessionCompletedAt: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let cutoff = calendar.startOfDay(for: newSessionCompletedAt)
        var days: Set<Date> = []
        for log in existingLogs where isQualifying(log) {
            let day = calendar.startOfDay(for: log.completedAt)
            if day <= cutoff { days.insert(day) }
        }
        days.insert(cutoff)  // include the in-flight session's day
        return days.count
    }

    /// True iff the user has already saved a qualifying session on the
    /// `asOf` calendar day. Used by callers that need to gate "is today
    /// already counted" without calling the full count again.
    static func hasCompletedToday(
        sessionLogs: [SessionLogRecord],
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let today = calendar.startOfDay(for: asOf)
        return sessionLogs.contains { log in
            isQualifying(log) && calendar.isDate(log.completedAt, inSameDayAs: today)
        }
    }

    // MARK: - Qualifying gate

    /// A session counts toward engagement when it's one of the two real
    /// program surfaces: a completed routine or a plank check-in. The
    /// upstream save sites already gate routines on
    /// `SessionCompletion.didMeetThreshold` so anything that lands in the
    /// SessionLogRecord set has already met the bar. Plank check-ins are
    /// short by design and always count.
    private static func isQualifying(_ log: SessionLogRecord) -> Bool {
        log.sessionType == "routine" || log.sessionType == "plank_benchmark"
    }
}
