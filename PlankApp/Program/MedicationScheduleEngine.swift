import Foundation

// MARK: - MedicationScheduleEngine (app v24 THE REGIMEN)
//
// docs/app_v24/00_REGIMEN.md §4 — the pure schedule math every
// medication surface reads. No I/O, no SwiftData: callers hand in
// `RegimenFacts` (lifted off the active RegimenPlanRecord) and
// lightweight slot events; the engine answers WHEN.
//
// Anchoring law: LOCAL WALL CLOCK. "Tuesday, 6pm" means Tuesday
// 6pm wherever she wakes up — travel never moves her shot day,
// and every computation goes through Calendar (never epoch math
// on anchors), so DST transitions cannot shift a slot.
//
// Honesty law: a slot is the PLAN; an event is what HAPPENED.
// A weekly dose stays markable until the next one is due (the
// late window); "missed" is derived only after the window closes,
// and a late log reverses it. Missed never scolds — it becomes
// "log it late, or let it go" language at the surface.

enum MedicationScheduleEngine {

    // MARK: Facts

    /// The slice of a regimen the schedule needs — value-typed so
    /// the engine stays pure and testable.
    struct RegimenFacts: Equatable {
        /// "weeklyAnchor" | "daily" | "asNeeded"
        var scheduleRule: String
        /// ISO 1 = Monday … 7 = Sunday (weeklyAnchor only).
        var anchorWeekday: Int?
        /// Minutes from midnight; nil falls to the route default.
        var timeOfDayMinutes: Int?
        /// "injection" | "oral" | nil (pre-v24 rows = injection).
        var route: String?
        var startedAt: Date

        init(
            scheduleRule: String,
            anchorWeekday: Int? = nil,
            timeOfDayMinutes: Int? = nil,
            route: String? = nil,
            startedAt: Date
        ) {
            self.scheduleRule = scheduleRule
            self.anchorWeekday = anchorWeekday
            self.timeOfDayMinutes = timeOfDayMinutes
            self.route = route
            self.startedAt = startedAt
        }

        var isOral: Bool { route == "oral" }

        /// Her hour, else the route default: oral rides the morning
        /// (empty-stomach label rhythm), injections the evening.
        var resolvedMinutes: Int {
            if let timeOfDayMinutes, (0..<1_440).contains(timeOfDayMinutes) {
                return timeOfDayMinutes
            }
            return isOral ? 8 * 60 : 18 * 60
        }
    }

    /// A recorded outcome for a slot day (lifted off DoseEventRecord).
    struct SlotEvent: Equatable {
        var dayKey: String
        var status: String   // "taken" | "skipped" | "missed" | "pending"

        init(dayKey: String, status: String) {
            self.dayKey = dayKey
            self.status = status
        }

        var isResolved: Bool { status == "taken" || status == "skipped" }
    }

    // MARK: Day math

    /// Is `date` a scheduled dose day?
    static func isDoseDay(
        _ date: Date, facts: RegimenFacts, calendar: Calendar = .current
    ) -> Bool {
        guard calendar.startOfDay(for: date)
            >= calendar.startOfDay(for: facts.startedAt) else { return false }
        switch facts.scheduleRule {
        case "daily":
            return true
        case "weeklyAnchor":
            guard let anchor = facts.anchorWeekday else { return false }
            return RegimenService.isoWeekday(date, calendar: calendar) == anchor
        default:
            return false
        }
    }

    /// The planned datetime for a slot on `day` (her hour, wall
    /// clock). `bySettingHour` — NEVER minute addition from
    /// midnight, which crosses the DST fold (540 minutes after an
    /// EDT midnight is 08:00 EST on fall-back day; her 9am slot
    /// must stay 9am on the clock she reads).
    static func scheduledAt(
        onDay day: Date, facts: RegimenFacts, calendar: Calendar = .current
    ) -> Date {
        let start = calendar.startOfDay(for: day)
        let minutes = facts.resolvedMinutes
        return calendar.date(
            bySettingHour: minutes / 60, minute: minutes % 60, second: 0,
            of: start
        ) ?? start
    }

    /// The next due dose datetime at-or-after `now`. Today's slot
    /// counts as next while it is still unresolved — a dose stays
    /// due all day (and through its late window), it never
    /// "expires" at her reminder hour.
    static func nextDoseDate(
        after now: Date, facts: RegimenFacts,
        events: [SlotEvent] = [],
        calendar: Calendar = .current
    ) -> Date? {
        switch facts.scheduleRule {
        case "daily":
            let todayKey = dayKey(for: now, calendar: calendar)
            let resolvedToday = events.contains {
                $0.dayKey == todayKey && $0.isResolved
            }
            if !resolvedToday, isDoseDay(now, facts: facts, calendar: calendar) {
                return scheduledAt(onDay: now, facts: facts, calendar: calendar)
            }
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)
            else { return nil }
            return scheduledAt(onDay: tomorrow, facts: facts, calendar: calendar)
        case "weeklyAnchor":
            guard facts.anchorWeekday != nil else { return nil }
            if isDoseDay(now, facts: facts, calendar: calendar) {
                let todayKey = dayKey(for: now, calendar: calendar)
                let resolvedToday = events.contains {
                    $0.dayKey == todayKey && $0.isResolved
                }
                if !resolvedToday {
                    return scheduledAt(onDay: now, facts: facts, calendar: calendar)
                }
            }
            guard let nextDay = nextAnchorDay(
                strictlyAfter: now, facts: facts, calendar: calendar
            ) else { return nil }
            return scheduledAt(onDay: nextDay, facts: facts, calendar: calendar)
        default:
            return nil
        }
    }

    /// The scheduled slot days inside a lookback window, oldest
    /// first, clamped to the regimen's start. `through` is
    /// inclusive.
    static func slotDays(
        through now: Date, lookbackDays: Int, facts: RegimenFacts,
        calendar: Calendar = .current
    ) -> [Date] {
        guard lookbackDays > 0 else { return [] }
        let end = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(
            byAdding: .day, value: -(lookbackDays - 1), to: end
        ) else { return [] }
        let start = max(windowStart, calendar.startOfDay(for: facts.startedAt))
        guard start <= end else { return [] }

        var days: [Date] = []
        var cursor = start
        while cursor <= end {
            if isDoseDay(cursor, facts: facts, calendar: calendar) {
                days.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor)
            else { break }
            cursor = next
        }
        return days
    }

    /// When a slot's late window closes: weekly doses stay open
    /// until the NEXT slot is due; daily doses close at end of day.
    static func lateWindowEnd(
        slotDay: Date, facts: RegimenFacts, calendar: Calendar = .current
    ) -> Date {
        let start = calendar.startOfDay(for: slotDay)
        switch facts.scheduleRule {
        case "weeklyAnchor":
            let days = 7
            return calendar.date(byAdding: .day, value: days, to: start)
                ?? start
        default:
            return calendar.date(byAdding: .day, value: 1, to: start)
                ?? start
        }
    }

    /// The most recent PAST slot that is still unresolved and still
    /// inside its late window — the "log it late, or let it go"
    /// door. Today's own slot is not "open" (it is simply due).
    static func openLateSlot(
        now: Date, facts: RegimenFacts, events: [SlotEvent],
        calendar: Calendar = .current
    ) -> Date? {
        let today = calendar.startOfDay(for: now)
        let candidates = slotDays(
            through: now, lookbackDays: 8, facts: facts, calendar: calendar
        )
        for slot in candidates.reversed() where slot < today {
            let key = dayKey(for: slot, calendar: calendar)
            let resolved = events.contains { $0.dayKey == key && $0.isResolved }
            if resolved { continue }
            if now < lateWindowEnd(slotDay: slot, facts: facts, calendar: calendar) {
                return slot
            }
            return nil   // the nearest unresolved slot is already closed
        }
        return nil
    }

    /// Slot days whose late window has CLOSED with no resolution —
    /// the lazily-stamped "missed" set. Reversible: stamping writes
    /// an event a late log can overwrite (the store's law).
    static func missedSlotDays(
        now: Date, facts: RegimenFacts, events: [SlotEvent],
        lookbackDays: Int = 35, calendar: Calendar = .current
    ) -> [Date] {
        slotDays(
            through: now, lookbackDays: lookbackDays,
            facts: facts, calendar: calendar
        ).filter { slot in
            let key = dayKey(for: slot, calendar: calendar)
            let recorded = events.contains { $0.dayKey == key }
            guard !recorded else { return false }
            return now >= lateWindowEnd(
                slotDay: slot, facts: facts, calendar: calendar
            )
        }
    }

    // MARK: Helpers

    static func dayKey(
        for date: Date, calendar: Calendar = .current
    ) -> String {
        var cal = calendar
        cal.locale = Locale(identifier: "en_US_POSIX")
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0
        )
    }

    /// The next calendar day strictly after `now` matching the
    /// weekly anchor (wall-clock; `.nextTime` rides DST safely).
    private static func nextAnchorDay(
        strictlyAfter now: Date, facts: RegimenFacts, calendar: Calendar
    ) -> Date? {
        guard let iso = facts.anchorWeekday else { return nil }
        let apple = iso == 7 ? 1 : iso + 1
        let startOfTomorrow = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: now)
        ) ?? now
        return calendar.nextDate(
            after: startOfTomorrow - 1,
            matching: DateComponents(weekday: apple),
            matchingPolicy: .nextTime
        )
    }
}
