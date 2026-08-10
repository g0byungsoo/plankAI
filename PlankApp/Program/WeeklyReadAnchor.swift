import Foundation

// MARK: - WeeklyReadAnchor (E1 THE SPINE — B2)
//
// docs/app_v25/05_E1_SPINE.md §2. The generalized weekly rhythm:
// preference › dose-day › enrollment. Dose day is an insight, never
// dogma — a daily pill or no medication at all falls to the
// enrollment-relative week the v4 law already owns, with ZERO
// weekly-injection assumptions. Pure and deterministic.

enum WeeklyReadAnchor {

    enum Kind: String, Equatable {
        case preference
        case doseDay
        case enrollment
    }

    struct Resolution: Equatable {
        let kind: Kind
        /// dayKey of the 7-day window's first day (the window ends
        /// the day before the read's due day).
        let windowStartDay: String
        /// The morning the read became available.
        let dueSince: Date
    }

    static func dueResolution(
        now: Date,
        readAnchorWord: String?,
        regimenAnchorWeekday: Int?,
        programDay: Int?,
        signedWindowStartDays: Set<String>,
        breakActive: Bool,
        calendar: Calendar = .current
    ) -> Resolution? {
        guard !breakActive else { return nil }
        let today = calendar.startOfDay(for: now)

        // A weekday-anchored read: due on its weekday's morning,
        // carried through 3 grace days; the window is the 7 days
        // ENDING the day before the due day.
        func weekdayResolution(dueWeekday: Int, kind: Kind) -> Resolution? {
            let todayIso = RegimenService.isoWeekday(now, calendar: calendar)
            let daysSinceDue = (todayIso - dueWeekday + 7) % 7
            guard daysSinceDue <= 3,
                  let dueDay = calendar.date(
                    byAdding: .day, value: -daysSinceDue, to: today),
                  let windowStart = calendar.date(
                    byAdding: .day, value: -7, to: dueDay)
            else { return nil }
            let key = TodayStateService.dayKey(for: windowStart)
            guard !signedWindowStartDays.contains(key) else { return nil }
            return Resolution(kind: kind, windowStartDay: key, dueSince: dueDay)
        }

        // 1 — her explicit preference outranks everything.
        if let word = readAnchorWord, word.hasPrefix("weekday:"),
           let n = Int(word.dropFirst("weekday:".count)),
           (1...7).contains(n) {
            return weekdayResolution(dueWeekday: n, kind: .preference)
        }

        // 2 — the weekly injectable's physiological monday: the
        // morning AFTER dose day. Daily regimens pass nil here by
        // construction — zero weekly-injection leakage.
        if let anchor = regimenAnchorWeekday, (1...7).contains(anchor) {
            return weekdayResolution(dueWeekday: anchor % 7 + 1, kind: .doseDay)
        }

        // 3 — the enrollment-relative week (the v4 re-signing law,
        // preserved): due on the week's closing evening (slot 6,
        // hour ≥17) and through the first 3 days of the next week.
        if let programDay, programDay >= 7 {
            let slot = PrescriptionEngineV2.dayInWeek(programDay)
            let week = PrescriptionEngineV2.programWeek(programDay)
            let hour = calendar.component(.hour, from: now)
            let daysIntoDue: Int?
            if slot == 6, hour >= 17 {
                daysIntoDue = 0
            } else if slot <= 2, week >= 2 {
                daysIntoDue = slot + 1
            } else {
                daysIntoDue = nil
            }
            guard let daysIntoDue else { return nil }
            let startOffset = slot == 6 ? -6 : -(slot + 7)
            guard let windowStart = calendar.date(
                    byAdding: .day, value: startOffset, to: today),
                  let dueDay = calendar.date(
                    byAdding: .day, value: -daysIntoDue, to: today)
            else { return nil }
            let key = TodayStateService.dayKey(for: windowStart)
            guard !signedWindowStartDays.contains(key) else { return nil }
            return Resolution(kind: .enrollment, windowStartDay: key, dueSince: dueDay)
        }

        return nil
    }
}
