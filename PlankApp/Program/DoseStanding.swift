import Foundation

/// THE STANDING — where she is in the dose week, as one sentence.
///
/// Measured 2026-08-13 over the three days these events have existed
/// (test users excluded, identical instrumentation age): **42 users
/// configured a medication regimen, 34 logged a side effect, and 3
/// ever recorded taking a dose.** `dose_marked` last fired the hour it
/// shipped while the other two fired that day and every day since.
/// That is not a cold-start artifact — it is a live funnel with a hole.
///
/// Walking the product found the hole, and it is placement, not
/// capability. Every piece of machinery exists: `MedicationScheduleEngine`
/// answers the next dose date, `DoseEventStore` holds the outcomes,
/// the dose sheet pre-selects a rotated site. But on a dose day the
/// mark is a to-do row roughly 1,400pt down the page, under the
/// protein ring, the macro split, the fiber row and a daily-value
/// footnote — and on **any other day Home says nothing about her
/// medication at all.** She could not learn when her next shot was
/// without opening a sheet behind a row she had to scroll to find.
///
/// "When is my next shot, and did I take the last one?" is the single
/// most repeated job in this category's user reviews. It is why people
/// install a GLP-1 app at all. This engine answers it.
///
/// Pure and value-typed, like the schedule engine it reads through.
/// It states a standing; it never prescribes, never grades a missed
/// dose, and never names the medication — Home is a screen she may
/// hand to someone, and the existing to-do row's discretion ("take
/// today's shot", no product name) is the precedent this follows.
enum DoseStanding {

    // MARK: - The standing

    enum Standing: Equatable {
        /// Today is a slot day and nothing is recorded for it yet.
        case dueToday
        /// An earlier slot is unresolved and still inside its late
        /// window. Outranks everything — a dose she may still take.
        case late(slotDayKey: String, weekday: String)
        /// Today's slot is recorded as taken.
        case doneToday(site: String?)
        /// Today's slot is recorded as skipped. Her call, stated flat.
        case skippedToday
        /// No slot today; the next one is `days` away.
        case upcoming(days: Int, weekday: String)
    }

    /// What Home draws. `slotDayKey` is the slot the tap should open;
    /// nil means "no slot to mark" and the tap opens her regimen.
    struct Read: Equatable {
        var headline: String
        var detail: String?
        var slotDayKey: String?
        var voiceOver: String
    }

    // MARK: - Deriving

    /// The standing at `now`, or nil when there is nothing true to
    /// say. `asNeeded` regimens have no schedule, so they have no
    /// standing — an as-needed dose is never late and never due.
    static func standing(
        now: Date,
        facts: MedicationScheduleEngine.RegimenFacts,
        events: [MedicationScheduleEngine.SlotEvent],
        calendar: Calendar = .current
    ) -> Standing? {
        guard facts.scheduleRule == "weeklyAnchor" || facts.scheduleRule == "daily"
        else { return nil }
        guard calendar.startOfDay(for: now)
            >= calendar.startOfDay(for: facts.startedAt) else { return nil }

        // A dose she can still take outranks a dose she will take.
        if let openSlot = MedicationScheduleEngine.openLateSlot(
            now: now, facts: facts, events: events, calendar: calendar
        ) {
            return .late(
                slotDayKey: MedicationScheduleEngine.dayKey(
                    for: openSlot, calendar: calendar
                ),
                weekday: weekdayWord(openSlot, calendar: calendar)
            )
        }

        let todayKey = MedicationScheduleEngine.dayKey(for: now, calendar: calendar)
        if MedicationScheduleEngine.isDoseDay(now, facts: facts, calendar: calendar) {
            let recorded = events.first { $0.dayKey == todayKey }
            switch recorded?.status {
            case "taken":   return .doneToday(site: nil)
            case "skipped": return .skippedToday
            default:        return .dueToday
            }
        }

        guard let next = MedicationScheduleEngine.nextDoseDate(
            after: now, facts: facts, events: events, calendar: calendar
        ) else { return nil }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: next)
        ).day ?? 0
        guard days > 0 else { return nil }
        return .upcoming(days: days, weekday: weekdayWord(next, calendar: calendar))
    }

    // MARK: - Reading

    /// The sentence. `isOral` picks her noun — the catalog's own
    /// vocabulary (a pill is not a shot), so an oral regimen never
    /// reads as an injection.
    static func read(_ standing: Standing, isOral: Bool, site: String? = nil) -> Read {
        let noun = isOral ? "dose" : "shot"
        switch standing {
        case .dueToday:
            return Read(
                headline: "your \(noun) is today",
                detail: "mark it when you take it",
                slotDayKey: nil,
                voiceOver: "your \(noun) is due today. mark it when you take it."
            )

        case let .late(slotDayKey, weekday):
            return Read(
                headline: "\(weekday)'s \(noun) is still open",
                detail: "log it, or let it go",
                slotDayKey: slotDayKey,
                voiceOver: "\(weekday)'s \(noun) is still open. log it, or let it go."
            )

        case let .doneToday(recordedSite):
            let where_ = recordedSite ?? site
            return Read(
                headline: "today's \(noun), done",
                detail: where_,
                slotDayKey: nil,
                voiceOver: where_.map { "today's \(noun) is done, \($0)." }
                    ?? "today's \(noun) is done."
            )

        case .skippedToday:
            return Read(
                headline: "today's \(noun), skipped",
                detail: nil,
                slotDayKey: nil,
                voiceOver: "today's \(noun) is marked skipped."
            )

        case let .upcoming(days, weekday):
            // One day away is a word, not a count. "in 1 days" is the
            // grammar bug this branch exists to make impossible.
            if days == 1 {
                return Read(
                    headline: "your next \(noun) is tomorrow",
                    detail: nil,
                    slotDayKey: nil,
                    voiceOver: "your next \(noun) is tomorrow."
                )
            }
            return Read(
                headline: "your next \(noun) is \(weekday)",
                detail: "in \(days) days",
                slotDayKey: nil,
                voiceOver: "your next \(noun) is \(weekday), in \(days) days."
            )
        }
    }

    // MARK: - Words

    /// Lowercase weekday, her locale's calendar, jeni's register.
    static func weekdayWord(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale.current
        f.timeZone = calendar.timeZone
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f.string(from: date).lowercased()
    }
}
