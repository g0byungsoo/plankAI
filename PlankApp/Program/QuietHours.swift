import Foundation
import PlankFood

// MARK: - QuietHours (app v3 — insight with ZERO new input)
//
// The founder's ask: features that help with weight care with
// minimal input. The plates she already snaps carry timestamps —
// the gaps between them are an eating-rhythm signal she never has
// to log: the overnight quiet stretch (last plate → first plate)
// and the day's eating window (first → last).
//
// Register floors (compliance + anti-shame, non-negotiable):
//   - OBSERVATIONAL ONLY. Never a target, never a timer, never a
//     countdown, never "aim for 16" — time-restricted-eating claims
//     don't clear our evidence bar, and fasting prescriptions to
//     this audience are a harm vector.
//   - "about N hours" always — plate times are approximate truth.
//   - HARD-GATED OFF for restriction-risk and numeric-suppressed
//     users (fasting talk is fuel for the wrong fire).
//   - A short window is NEVER praised; a long one never scolded.
//     The only voice: "the rhythm exists, and it's yours."
//
// Pure core (table-tested); live wrappers read the device journal.

enum QuietHours {

    /// Sanity band: gaps outside 8–20h are travel, missed logs, or
    /// data noise — never narrated.
    static let minNarratableHours: Double = 8
    static let maxNarratableHours: Double = 20

    /// The overnight quiet stretch that ENDED today: the last plate
    /// before today's start → the first plate today. nil when either
    /// side is missing or the gap falls outside the sanity band.
    static func overnightQuietHours(
        plateTimes: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> Double? {
        let dayStart = calendar.startOfDay(for: now)
        let lastBefore = plateTimes.filter { $0 < dayStart }.max()
        let firstToday = plateTimes
            .filter { $0 >= dayStart && $0 <= now }
            .min()
        guard let lastBefore, let firstToday else { return nil }
        let hours = firstToday.timeIntervalSince(lastBefore) / 3600
        guard hours >= minNarratableHours, hours <= maxNarratableHours else { return nil }
        return hours
    }

    /// Today's eating window so far (first plate → last plate). nil
    /// under two plates.
    static func eatingWindowHours(
        plateTimes: [Date], now: Date = .now, calendar: Calendar = .current
    ) -> Double? {
        let dayStart = calendar.startOfDay(for: now)
        let today = plateTimes.filter { $0 >= dayStart && $0 <= now }.sorted()
        guard let first = today.first, let last = today.last, today.count >= 2 else { return nil }
        let hours = last.timeIntervalSince(first) / 3600
        guard hours > 0.5 else { return nil }
        return hours
    }

    /// Nights in the trailing week whose overnight stretch reached
    /// `minHours` — the Becoming receipt's provenance. Counts only
    /// consecutive-day pairs that both have plates.
    static func quietNights(
        plateTimes: [Date], minHours: Double = 11,
        now: Date = .now, calendar: Calendar = .current
    ) -> Int {
        var nights = 0
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset,
                                          to: calendar.startOfDay(for: now))
            else { continue }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let lastBefore = plateTimes.filter { $0 < day }.max()
            let firstOfDay = plateTimes.filter { $0 >= day && $0 < dayEnd }.min()
            guard let lastBefore, let firstOfDay else { continue }
            let hours = firstOfDay.timeIntervalSince(lastBefore) / 3600
            if hours >= minHours, hours <= maxNarratableHours { nights += 1 }
        }
        return nights
    }

    // MARK: - Live wrappers (the journal in, one line out)

    /// Whether the quiet-hours register may speak AT ALL for this
    /// identity (the hard gate).
    static var mayNarrate: Bool {
        !CohortStore.isRestrictiveRisk && !CohortStore.isNumericSuppressed
    }

    static func liveOvernight(userId: String) -> Double? {
        guard mayNarrate, !userId.isEmpty else { return nil }
        let times = FoodLogPersister.allEntries(userId: userId).map(\.loggedAt)
        return overnightQuietHours(plateTimes: times)
    }

    static func liveQuietNights(userId: String) -> Int {
        guard mayNarrate, !userId.isEmpty else { return 0 }
        let times = FoodLogPersister.allEntries(userId: userId).map(\.loggedAt)
        return quietNights(plateTimes: times)
    }

    /// The overnight stretch that ended on a PAST day — the journal's
    /// per-day memory line. Anchors "now" to that day's late evening
    /// so the pure core evaluates that morning's gap.
    static func overnightForDay(
        userId: String, day: Date, calendar: Calendar = .current
    ) -> Double? {
        guard mayNarrate, !userId.isEmpty else { return nil }
        let times = FoodLogPersister.allEntries(userId: userId).map(\.loggedAt)
        let anchor = calendar.date(
            byAdding: .hour, value: 23,
            to: calendar.startOfDay(for: day)
        ) ?? day
        return overnightQuietHours(plateTimes: times, now: anchor, calendar: calendar)
    }
}
