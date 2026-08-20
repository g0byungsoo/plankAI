import Foundation

// MARK: - SymptomLedger — how it sat, listed (v25 §36)
//
// THE GAP THIS CLOSES, and it is the third instance of one shape.
//
// `33` found it in medication: `DoseEventRecord` had stored a day, a
// status and a site since v24 and no screen had ever listed them.
// `34` found it in weight: `WeightLogRecord` had stored a day and a
// number since v1 and Becoming drew a LINE, which is a trend and not a
// record. **Side effects are the last one.**
//
// `ObservationRecord` has carried a day, a symptom and a severity for
// every chip she has ever tapped since v24. Five readers consume them —
// `MedicationPatternEngine`, `MethodInputBuilder`, the Becoming tile,
// `JeniReadTools.read_symptoms` and `VisitPacket.symptomSection`, which
// prints them for a clinician — and **the only surface that shows them
// to HER is the chip cloud, which filters to today.**
//
// So the product would tell her doctor what she recorded three weeks ago
// and would not tell her. That is `26_WHAT_THE_RECORD_KEEPS`'s write-only
// defect class in the domain with the highest stakes attached to it.
//
// The engine states facts and refuses everything else, exactly as its
// two siblings do: no count of bad days, no "worse than last week", no
// severity average, no streak, no link to a dose or a weight. The
// pattern engine is the ONLY thing in this product allowed to observe,
// it is floor-gated, and it speaks timing and never causality.
//
// Pure over value types so the whole table is testable without a
// SwiftData container.

enum SymptomLedger {

    /// One recorded symptom, flattened out of `SideEffectLog.Entry` so
    /// this engine stays free of SwiftData and of `@MainActor`.
    struct Entry: Equatable {
        /// "2026-08-13" — the local day she recorded it for.
        var dayKey: String
        /// Her word for it: "queasy", "food noise", "mood low".
        var word: String
        /// "a touch" · "noticeable" · "rough".
        var severityWord: String
    }

    /// One DAY, not one symptom — the record answers "how did that day
    /// sit", and a day that carried three things is one row with three
    /// facts in it, never three rows competing for the same date.
    struct Row: Equatable, Identifiable {
        var id: String { dayKey }
        var dayKey: String
        /// "today" · "yesterday" · "aug 12" (· ", 2025" across a year)
        var day: String
        /// "queasy · a touch, worn down · noticeable"
        var detail: String
        var voiceOver: String
    }

    /// Newest first. `now` and `calendar` are injected so the day words
    /// and the year rule are testable without waiting for midnight.
    static func rows(
        _ entries: [Entry], now: Date = .now, limit: Int = 24,
        calendar: Calendar = .current
    ) -> [Row] {
        Dictionary(grouping: entries, by: \.dayKey)
            .sorted { $0.key > $1.key }
            .prefix(limit)
            .map { dayKey, dayEntries in
                row(dayKey: dayKey, dayEntries, now: now, calendar: calendar)
            }
    }

    static func row(
        dayKey: String, _ entries: [Entry],
        now: Date = .now, calendar: Calendar = .current
    ) -> Row {
        let day = dayWord(dayKey, now: now, calendar: calendar)
        // Alphabetical WITHIN a day. Not "most severe first" — ranking
        // her symptoms is a judgement, and the order a Dictionary hands
        // back is not an order at all. This one is stable and means
        // nothing, which is the point.
        let detail = entries
            .sorted { $0.word < $1.word }
            .map { "\($0.word) · \($0.severityWord)" }
            .joined(separator: ", ")
        return Row(
            dayKey: dayKey,
            day: day,
            detail: detail,
            voiceOver: "\(day), \(detail)"
        )
    }

    /// The same rule `WeightLedger` uses, including the fix `34` found
    /// in the product rather than in a test: the formatter must render
    /// in the SAME zone the calendar decided the day in, or a row the
    /// calendar placed on `aug 11` prints `aug 10` — the ledger
    /// disagreeing with itself about which day it is listing.
    static func dayWord(
        _ dayKey: String, now: Date, calendar: Calendar
    ) -> String {
        guard let date = date(from: dayKey, calendar: calendar) else { return dayKey }
        if calendar.isDate(date, inSameDayAs: now) { return "today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "yesterday" }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        let sameYear = calendar.component(.year, from: date)
            == calendar.component(.year, from: now)
        f.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        return f.string(from: date).lowercased()
    }

    private static func date(from dayKey: String, calendar: Calendar) -> Date? {
        // Pass 51: keys are pinned-Gregorian; parse them that way even
        // when the caller's calendar is Islamic/Buddhist, or the day
        // word narrates a different day than the key names.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = calendar.timeZone
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = cal.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dayKey)
    }

    /// The last fourteen days, newest first — the window a symptom may
    /// be recorded or corrected in.
    ///
    /// Fourteen because that is what the plate's day picker already
    /// offers (`34`), and one product should not hold two opinions about
    /// how far back a person can honestly remember. An unbounded picker
    /// on a clinical record is an invitation to invent history, and this
    /// record is the one that reaches a clinician.
    static func dayOptions(
        now: Date = .now, calendar: Calendar = .current, days: Int = 14
    ) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
    }
}
