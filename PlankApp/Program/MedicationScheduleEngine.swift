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
        /// "weeklyAnchor" | "daily" | "asNeeded" | "intervalDays"
        var scheduleRule: String
        /// ISO 1 = Monday … 7 = Sunday (weeklyAnchor only).
        var anchorWeekday: Int?
        /// v25 p53 — second weekly anchor (split-dose rhythm).
        var secondAnchorWeekday: Int?
        /// v25 p53 — days between doses (intervalDays rule; 2…90).
        var intervalDays: Int?
        /// v25 p53 — civil day the interval chain counts from (the
        /// first planned dose day; "yyyy-MM-dd", dayKey vocabulary).
        var anchorDayKey: String?
        /// Minutes from midnight; nil falls to the route default.
        var timeOfDayMinutes: Int?
        /// "injection" | "oral" | nil (pre-v24 rows = injection).
        var route: String?
        var startedAt: Date

        init(
            scheduleRule: String,
            anchorWeekday: Int? = nil,
            secondAnchorWeekday: Int? = nil,
            intervalDays: Int? = nil,
            anchorDayKey: String? = nil,
            timeOfDayMinutes: Int? = nil,
            route: String? = nil,
            startedAt: Date
        ) {
            self.scheduleRule = scheduleRule
            self.anchorWeekday = anchorWeekday
            self.secondAnchorWeekday = secondAnchorWeekday
            self.intervalDays = intervalDays
            self.anchorDayKey = anchorDayKey
            self.timeOfDayMinutes = timeOfDayMinutes
            self.route = route
            self.startedAt = startedAt
        }

        /// The interval in force for the intervalDays rule — nil
        /// unless the rule AND a sane value (2…90) are both present
        /// (the engine refuses a rule it cannot honor, the G1
        /// silence turned into an explicit guard).
        var resolvedIntervalDays: Int? {
            guard scheduleRule == "intervalDays",
                  let n = intervalDays, (2...90).contains(n) else { return nil }
            return n
        }

        /// Both weekly anchors, deduped, sorted (weeklyAnchor only).
        var weeklyAnchors: [Int] {
            guard scheduleRule == "weeklyAnchor" else { return [] }
            var days = [anchorWeekday, secondAnchorWeekday]
                .compactMap { $0 }
                .filter { (1...7).contains($0) }
            days = Array(Set(days)).sorted()
            return days
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
        /// v25 E2 — the day the dose was ACTUALLY taken (from
        /// takenAt), when it differs from the slot day. A late take
        /// anchors the physiological cycle to the real injection,
        /// not the plan.
        var takenDayKey: String?

        init(dayKey: String, status: String, takenDayKey: String? = nil) {
            self.dayKey = dayKey
            self.status = status
            self.takenDayKey = takenDayKey
        }

        var isResolved: Bool { status == "taken" || status == "skipped" }
    }

    // MARK: Cycle (v25 E2 — B2)

    /// Where she is between doses — POSITION, never concentration
    /// (the era's defining refusal: no PK curve, no estimated
    /// levels; a day count from her own record).
    ///
    /// Laws (09_E2 §2 E2-D1/D2, structural):
    /// - weekly injectables only — daily and as-needed regimens have
    ///   no cycle, and non-medicated users never construct one;
    /// - `day` is ALWAYS 1…length. Past-window states return nil —
    ///   an open or missed slot outranks the rhythm, and "day 8 of
    ///   7" is a fabricated rhythm;
    /// - the anchor is her last actual injection when the record has
    ///   one (basis .takenDose), the schedule otherwise (.schedule —
    ///   a plan-derived position, surfaces hedge accordingly).
    struct CyclePosition: Equatable {
        /// 1 = dose day … length = the day before the next dose.
        let day: Int
        let length: Int
        enum Basis: String, Equatable { case takenDose, schedule }
        let basis: Basis

        /// The lived arc (r1 §4), proportional to the rhythm's own
        /// length: landing is the first ~2/7 of the cycle, waning
        /// the last ~2/7 (appetite and food noise often return
        /// late). At length 7 this is exactly the shipped 1-2 ·
        /// 3-5 · 6-7.
        enum Band: String, Equatable { case landing, steady, waning }
        var band: Band {
            let edge = max(1, Int((Double(length) * 2.0 / 7.0).rounded(.up)))
            if day <= edge { return .landing }
            if day > length - edge { return .waning }
            return .steady
        }
    }

    /// The cycle position at `now`, or nil when no honest position
    /// exists (daily/as-needed regimen · a SPLIT weekly rhythm,
    /// whose overlapping doses have no single arc — fabricating one
    /// would be fake precision · first slot not yet arrived · an
    /// unresolved past slot outranks the rhythm).
    static func cyclePosition(
        now: Date, facts: RegimenFacts, events: [SlotEvent],
        calendar: Calendar = .current
    ) -> CyclePosition? {
        let length: Int
        let scheduleDay: (Date) -> Int?
        switch cadence(facts) {
        case .weekly(let anchor):
            length = 7
            scheduleDay = { date in
                let iso = RegimenService.isoWeekday(date, calendar: calendar)
                return (iso - anchor + 7) % 7 + 1
            }
        case .everyNDays(let n):
            length = n
            scheduleDay = { date in
                // Position against the chain's most recent due.
                let today = calendar.startOfDay(for: date)
                guard let lastDue = intervalDueDays(
                    through: date, facts: facts, events: events, calendar: calendar
                ).last,
                let diff = calendar.dateComponents(
                    [.day], from: lastDue, to: today
                ).day, diff >= 0, diff < n else { return nil }
                return diff + 1
            }
        default:
            return nil
        }
        let today = calendar.startOfDay(for: now)

        // No slot has ever arrived → nothing to have a position in.
        let arrivedSlots = slotDays(
            through: now, lookbackDays: slotLookback(facts), facts: facts,
            events: events, calendar: calendar
        )
        guard !arrivedSlots.isEmpty else { return nil }

        // 1 — her actual last injection anchors the count.
        let takenDays: [Date] = events
            .filter { $0.status == "taken" }
            .compactMap { parseDayKey($0.takenDayKey ?? $0.dayKey, calendar: calendar) }
            .filter { $0 <= today }
        if let lastTaken = takenDays.max(),
           let diff = calendar.dateComponents(
               [.day], from: lastTaken, to: today
           ).day,
           diff >= 0, diff < length {
            return CyclePosition(day: diff + 1, length: length, basis: .takenDose)
        }

        // 2 — an unresolved PAST slot outranks the rhythm: the open
        // (or missed) dose is the honest state, never "day 8 of 7".
        if let lastSlot = arrivedSlots.last {
            let key = dayKey(for: lastSlot, calendar: calendar)
            let resolved = events.contains { $0.dayKey == key && $0.isResolved }
            if lastSlot < today, !resolved { return nil }
        }

        // 3 — the schedule carries the position (dose day before
        // marking = day 1; a skipped week keeps the plan's rhythm,
        // hedged by basis).
        guard let day = scheduleDay(now) else { return nil }
        return CyclePosition(day: day, length: length, basis: .schedule)
    }

    /// Internal (not private) since pass 51: `DayKeyVocabularyTests`
    /// pins the producer↔reader round trip with this, the engine's own
    /// pinned reader.
    static func parseDayKey(
        _ key: String, calendar: Calendar
    ) -> Date? {
        // Pass 51: keys are pinned-Gregorian ASCII (see `dayKey`); the
        // parse must interpret them in the SAME calendar or an
        // Islamic/Buddhist `.current` reads "2026-…" as its own era.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = calendar.timeZone
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key).map { cal.startOfDay(for: $0) }
    }

    // MARK: Cadence (v25 pass 53 — the ONE vocabulary authority)

    /// The rhythm as data. Every surface that says a cadence word
    /// derives it from here — the pace-word lesson (§36) applied to
    /// medication: copies of a vocabulary drift, an authority cannot.
    enum Cadence: Equatable {
        case weekly(anchor: Int)
        case twiceWeekly(Int, Int)
        case daily
        case everyNDays(Int)
        case asNeeded
        case unknown
    }

    static func cadence(_ facts: RegimenFacts) -> Cadence {
        switch facts.scheduleRule {
        case "daily":
            return .daily
        case "asNeeded":
            return .asNeeded
        case "intervalDays":
            guard let n = facts.resolvedIntervalDays else { return .unknown }
            return .everyNDays(n)
        case "weeklyAnchor":
            let anchors = facts.weeklyAnchors
            if anchors.count == 2 { return .twiceWeekly(anchors[0], anchors[1]) }
            if let a = anchors.first { return .weekly(anchor: a) }
            return .unknown
        default:
            return .unknown
        }
    }

    /// The spoken rhythm ("weekly" · "twice a week" · "daily" ·
    /// "every 5 days" · "as needed").
    static func cadenceWord(_ facts: RegimenFacts) -> String {
        switch cadence(facts) {
        case .weekly: return "weekly"
        case .twiceWeekly: return "twice a week"
        case .daily: return "daily"
        case .everyNDays(let n): return "every \(n) days"
        case .asNeeded: return "as needed"
        case .unknown: return "on file"
        }
    }

    // MARK: Tenure (v25 pass 53)

    /// Whole calendar months since the civil day treatment began.
    /// 0 inside the first month; nil when never stated. The only
    /// reader of `treatmentStartedOn` — jeni day and treatment day
    /// are different truths and this is the second one's arithmetic.
    static func treatmentMonths(
        startedOn: String?, now: Date = .now, calendar: Calendar = .current
    ) -> Int? {
        guard let startedOn, let start = parseDayKey(startedOn, calendar: calendar)
        else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = calendar.timeZone
        let months = cal.dateComponents(
            [.month], from: start, to: cal.startOfDay(for: now)
        ).month
        guard let months, months >= 0 else { return nil }
        return months
    }

    // MARK: Interval chain (v25 pass 53)

    /// The due days of an intervalDays regimen, oldest first,
    /// through `end` inclusive. The chain starts at the plan's
    /// anchor civil day and RE-ANCHORS on each resolved slot: a
    /// taken dose counts N days from the day it was actually taken
    /// (takenDayKey), a skipped slot counts N from the slot, and an
    /// unresolved slot leaves the grid where it was — the same
    /// honesty split as the weekly engine (the plan is the plan,
    /// the event is what happened).
    static func intervalDueDays(
        through end: Date, facts: RegimenFacts, events: [SlotEvent],
        calendar: Calendar = .current
    ) -> [Date] {
        guard let n = facts.resolvedIntervalDays,
              let first = intervalFirstDue(facts, calendar: calendar)
        else { return [] }
        let endDay = calendar.startOfDay(for: end)
        // Resolution lookup: the event ON a due day resolves it; a
        // taken event's REAL day (takenDayKey) re-anchors the chain.
        var resolvedByKey: [String: SlotEvent] = [:]
        for e in events where e.isResolved {
            resolvedByKey[e.dayKey] = e
        }
        var dues: [Date] = []
        var due = first
        // Bounded walk: the chain can only step forward, and a slot
        // is minted at most every 2 days (the label floor), so cap
        // generously against a corrupt input looping.
        var guardRail = 0
        while due <= endDay, guardRail < 2_000 {
            guardRail += 1
            dues.append(due)
            let key = dayKey(for: due, calendar: calendar)
            if let event = resolvedByKey[key] {
                let effective = event.takenDayKey
                    .flatMap { parseDayKey($0, calendar: calendar) } ?? due
                let anchor = max(effective, due)
                guard let next = calendar.date(byAdding: .day, value: n, to: anchor)
                else { break }
                due = calendar.startOfDay(for: next)
            } else {
                guard let next = calendar.date(byAdding: .day, value: n, to: due)
                else { break }
                due = calendar.startOfDay(for: next)
            }
        }
        return dues
    }

    /// The first due day of an interval chain: the civil anchor day
    /// she named at setup, else the plan's start day.
    private static func intervalFirstDue(
        _ facts: RegimenFacts, calendar: Calendar
    ) -> Date? {
        if let key = facts.anchorDayKey,
           let day = parseDayKey(key, calendar: calendar) {
            return day
        }
        return calendar.startOfDay(for: facts.startedAt)
    }

    /// The next due day of an interval chain STRICTLY after `now`'s
    /// day — the chain's forward step from its current state.
    private static func intervalNextDue(
        strictlyAfter now: Date, facts: RegimenFacts, events: [SlotEvent],
        calendar: Calendar
    ) -> Date? {
        guard let n = facts.resolvedIntervalDays else { return nil }
        let today = calendar.startOfDay(for: now)
        let dues = intervalDueDays(
            through: now, facts: facts, events: events, calendar: calendar
        )
        guard let last = dues.last else {
            // The whole chain lies in the future: the first due.
            return intervalFirstDue(facts, calendar: calendar)
                .flatMap { $0 > today ? $0 : nil }
        }
        // Step from the last arrived due's state.
        let key = dayKey(for: last, calendar: calendar)
        let resolved = events.first { $0.dayKey == key && $0.isResolved }
        let effective = resolved?.takenDayKey
            .flatMap { parseDayKey($0, calendar: calendar) }
            .map { max($0, last) } ?? last
        return calendar.date(byAdding: .day, value: n, to: effective)
            .map { calendar.startOfDay(for: $0) }
    }

    // MARK: Day math

    /// Is `date` a scheduled dose day? Interval regimens need the
    /// event chain to answer (their grid re-anchors on resolutions).
    static func isDoseDay(
        _ date: Date, facts: RegimenFacts, events: [SlotEvent] = [],
        calendar: Calendar = .current
    ) -> Bool {
        switch facts.scheduleRule {
        case "intervalDays":
            // The chain is its own authority (it may begin before
            // this plan VERSION's startedAt — a version change never
            // moves her dose days).
            let day = calendar.startOfDay(for: date)
            return intervalDueDays(
                through: date, facts: facts, events: events, calendar: calendar
            ).contains(day)
        default:
            break
        }
        guard calendar.startOfDay(for: date)
            >= calendar.startOfDay(for: facts.startedAt) else { return false }
        switch facts.scheduleRule {
        case "daily":
            return true
        case "weeklyAnchor":
            let anchors = facts.weeklyAnchors
            guard !anchors.isEmpty else { return false }
            return anchors.contains(RegimenService.isoWeekday(date, calendar: calendar))
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
        case "intervalDays":
            guard facts.resolvedIntervalDays != nil else { return nil }
            if isDoseDay(now, facts: facts, events: events, calendar: calendar) {
                let todayKey = dayKey(for: now, calendar: calendar)
                let resolvedToday = events.contains {
                    $0.dayKey == todayKey && $0.isResolved
                }
                if !resolvedToday {
                    return scheduledAt(onDay: now, facts: facts, calendar: calendar)
                }
            }
            guard let nextDay = intervalNextDue(
                strictlyAfter: now, facts: facts, events: events, calendar: calendar
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
        events: [SlotEvent] = [],
        calendar: Calendar = .current
    ) -> [Date] {
        guard lookbackDays > 0 else { return [] }
        let end = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(
            byAdding: .day, value: -(lookbackDays - 1), to: end
        ) else { return [] }

        if facts.scheduleRule == "intervalDays" {
            // The chain replays from its own anchor; the lookback
            // only windows the ANSWER (the chain state upstream of
            // the window still decides where dues fall).
            return intervalDueDays(
                through: now, facts: facts, events: events, calendar: calendar
            ).filter { $0 >= windowStart }
        }

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

    /// The lookback horizon that guarantees the previous slot is in
    /// view for this rhythm (8 was the weekly answer; an interval
    /// chain needs its own length plus a day).
    static func slotLookback(_ facts: RegimenFacts) -> Int {
        max(8, (facts.resolvedIntervalDays ?? 0) + 1)
    }

    /// When a slot's late window closes: a dose stays open until
    /// the NEXT one is due — a week for weekly, the gap to the
    /// other anchor for a split rhythm, N days for an interval;
    /// daily doses close at end of day.
    static func lateWindowEnd(
        slotDay: Date, facts: RegimenFacts, calendar: Calendar = .current
    ) -> Date {
        let start = calendar.startOfDay(for: slotDay)
        switch facts.scheduleRule {
        case "weeklyAnchor":
            let anchors = facts.weeklyAnchors
            if anchors.count == 2,
               let next = nextAnchorDay(
                strictlyAfter: start, facts: facts, calendar: calendar
               ) {
                return next
            }
            return calendar.date(byAdding: .day, value: 7, to: start)
                ?? start
        case "intervalDays":
            let days = facts.resolvedIntervalDays ?? 7
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
            through: now, lookbackDays: slotLookback(facts), facts: facts,
            events: events, calendar: calendar
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
            through: now,
            lookbackDays: max(lookbackDays, slotLookback(facts) * 2),
            facts: facts, events: events, calendar: calendar
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
        // Pass 51: the IDENTIFIER is pinned Gregorian (a caller's
        // `.current` on a Thai/Islamic-calendar device would mint era
        // years like 2569/1448 into the slot id); only the caller's
        // TIME ZONE is honored — which day it is where she stands.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = calendar.timeZone
        cal.locale = Locale(identifier: "en_US_POSIX")
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0
        )
    }

    /// The next calendar day strictly after `now` matching ANY of
    /// the weekly anchors (wall-clock; `.nextTime` rides DST
    /// safely). A split rhythm answers with the nearer of its two
    /// days.
    private static func nextAnchorDay(
        strictlyAfter now: Date, facts: RegimenFacts, calendar: Calendar
    ) -> Date? {
        let anchors = facts.weeklyAnchors
        guard !anchors.isEmpty else { return nil }
        let startOfTomorrow = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: now)
        ) ?? now
        return anchors.compactMap { iso -> Date? in
            let apple = iso == 7 ? 1 : iso + 1
            return calendar.nextDate(
                after: startOfTomorrow - 1,
                matching: DateComponents(weekday: apple),
                matchingPolicy: .nextTime
            )
        }.min()
    }
}
