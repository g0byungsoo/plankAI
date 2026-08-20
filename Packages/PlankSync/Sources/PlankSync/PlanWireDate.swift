import Foundation

// MARK: - PlanWireDate — the civil-date boundary (v25 pass 51)
//
// `program_plans.start_date` and `goal_date` are Postgres `date`
// columns. A `date` is a CIVIL DATE — "the calendar day, where she
// was" — not an instant. The program day is derived from it in the
// device's LOCAL calendar (`ProgramScheduleCalculator.compute` takes
// `startOfDay` in the current zone), so the wire format's job is to
// carry the LOCAL calendar day across serialize → store → hydrate
// unchanged.
//
// THE DEFECT THIS ENDS (P1, pass 50 §4): the upsert wrote the UTC
// date of the start instant and the hydrate reparsed the string as
// UTC MIDNIGHT. UTC midnight of day D lands on D−1's evening for
// every zone west of UTC, so a reinstall or new phone moved every
// non-UTC customer's program day by ±1 — "day 5" became "day 6"
// overnight, from a sync that changed nothing.
//
// The rule: SERIALIZE the local civil date, REPARSE to local
// midnight. One boundary, both directions, no formatter time-zone
// pitfalls (component arithmetic, not string formatting through a
// cached formatter whose zone snapshots at init).

// MARK: - WireTimestamp — the tolerant instant parser (pass 51)
//
// Every `timestamptz` this client writes is whole-second (its own
// ISO8601 formatter), but every value the SERVER writes — `now()`
// defaults, support SQL, RPCs — carries microseconds, and a plain
// `ISO8601DateFormatter` returns nil for those. Half the hydrate
// sites carried the two-formatter fallback and half did not, and the
// half that did not produced real corruption: the pass-43 production
// repair (`archived_at = now()`) parsed nil, `ProgramPlanMerge`
// adopted the nil, and the support-archived duplicate plan silently
// UN-archived on every hydrate; `established_at` (always
// server-defaulted) parsed nil for 100% of care connections, so the
// active-clinic sort ran on `.distantPast`s. One parser, both shapes,
// used at every timestamp read.

public enum WireTimestamp {
    private static let plain = ISO8601DateFormatter()
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    public static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        return plain.date(from: string) ?? fractional.date(from: string)
    }
}

public enum PlanWireDate {

    /// "2026-08-01" — the date's civil day in `calendar`'s zone
    /// (the device's current zone by default, which is the zone the
    /// program day is being lived in). Component arithmetic + C-locale
    /// formatting: no cached formatter whose zone snapshots at init,
    /// no localized numerals on the wire.
    public static func wireString(
        from date: Date, calendar: Calendar = .current
    ) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1
        )
    }

    /// The instant that anchors a wire civil date in `calendar`'s
    /// zone: local midnight (or the first existing instant of that
    /// day where a DST rule skips midnight — `Calendar.date(from:)`
    /// resolves it forward). `startOfDay` of the result is always the
    /// same civil day the string names.
    ///
    /// Tolerant of a timestamp where a date was expected (takes the
    /// leading `yyyy-MM-dd`); nil for anything unparseable — the
    /// caller decides the fallback, never this boundary.
    public static func localDate(
        fromWire wire: String, calendar: Calendar = .current
    ) -> Date? {
        let head = wire.prefix(10)
        let parts = head.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day)
        else { return nil }
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day))
    }
}
