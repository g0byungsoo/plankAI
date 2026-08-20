import Foundation

// MARK: - DoseLedger — the shot log, and nothing else (v25 §33)
//
// THE GAP THIS CLOSES. `RegimenSheet`'s "the record" has always shown
// the ERA chain — the versions of her plan (`ozempic · 0.5 mg · since
// aug 13`). That answers *did my dose change*. It does not answer the
// four questions a GLP-1 user actually asks between visits, which the
// category's own reviews say out loud:
//
//   did I log my shot? · when was my last one? · what dose was it? ·
//   which site did I use?
//
// Every one of those facts has been on the device since v24 — every
// mark writes a `DoseEventRecord` with a day, a status, a site and a
// source — and **no screen has ever listed them.** `JeniReadTools`
// could answer in chat; the record itself was write-only, which is the
// `26_WHAT_THE_RECORD_KEEPS` defect class exactly.
//
// The brief's standard for this surface is the whole design: *"the
// history must be extremely obvious. No poetic language. No
// interpretation required."* So this engine states facts and refuses
// everything else — no adherence rate, no streak, no grading of a
// missed dose, no pattern claim, no causal link to a symptom or a
// weight. A skipped week reads `skipped`, not "you missed one".
//
// Pure over value types so the whole table is testable without a
// SwiftData container.

enum DoseLedger {

    /// One recorded slot, flattened out of `DoseEventRecord` + the
    /// regimen version that was in force for it.
    struct Entry: Equatable {
        /// "2026-08-13" — the SLOT's local day.
        var dayKey: String
        /// "pending" | "taken" | "skipped" | "missed"
        var status: String
        /// When she actually took it, if that differed from the slot.
        var takenAt: Date?
        /// Canonical site id ("left_abdomen"); nil for oral + unspecified.
        var site: String?
        /// The dose word in force for this slot ("0.5 mg"), if known.
        var doseWord: String?
        /// "traveling" | "out_of_medication" | "clinician_paused" |
        /// "just_didnt"
        var skipReason: String?
    }

    struct Row: Equatable, Identifiable {
        var id: String { dayKey }
        var dayKey: String
        /// "aug 13" (or "aug 13, 2025" across a year boundary).
        var day: String
        /// "0.5 mg · left abdomen" · "skipped · traveling" · "not recorded"
        var detail: String
        /// A slot that produced no dose renders quieter. Never struck
        /// through, never red — it is a fact, not a failure.
        var isMuted: Bool
        var voiceOver: String
    }

    /// The reason words, in her register. An unknown reason is not
    /// invented — it simply does not appear.
    static func skipWord(_ raw: String?) -> String? {
        switch raw {
        case "traveling": return "traveling"
        case "out_of_medication": return "none on hand"
        case "clinician_paused": return "your clinician paused it"
        case "just_didnt": return nil
        default: return nil
        }
    }

    /// Newest first. `now` is injected so the year rule is testable.
    static func rows(
        _ entries: [Entry], now: Date = .now, limit: Int = 24,
        calendar: Calendar = .current
    ) -> [Row] {
        entries
            .sorted { $0.dayKey > $1.dayKey }
            .prefix(limit)
            .map { row($0, now: now, calendar: calendar) }
    }

    static func row(
        _ entry: Entry, now: Date = .now, calendar: Calendar = .current
    ) -> Row {
        let day = dayWord(entry.dayKey, now: now, calendar: calendar)
        let detail: String
        var muted = false
        switch entry.status {
        case "taken":
            let parts = [entry.doseWord, siteWord(entry.site), lateWord(entry, calendar: calendar)]
                .compactMap { $0 }
            // A dose with no recorded dose value and no site still
            // states that it happened — "taken" is the fact.
            detail = parts.isEmpty ? "taken" : parts.joined(separator: " · ")
        case "skipped":
            muted = true
            if let reason = skipWord(entry.skipReason) {
                detail = "skipped · \(reason)"
            } else {
                detail = "skipped"
            }
        case "missed":
            muted = true
            detail = "not recorded"
        default:
            muted = true
            detail = "due"
        }
        return Row(
            dayKey: entry.dayKey,
            day: day,
            detail: detail,
            isMuted: muted,
            voiceOver: "\(day), \(detail)"
        )
    }

    /// "took it a day late" — stated only when the take day genuinely
    /// differs from the slot day. It is provenance, not a reprimand:
    /// a late dose is a dose, and the app already refuses to grade one.
    private static func lateWord(_ entry: Entry, calendar: Calendar) -> String? {
        guard let takenAt = entry.takenAt,
              let slot = date(from: entry.dayKey, calendar: calendar) else { return nil }
        let takenDay = calendar.startOfDay(for: takenAt)
        let days = calendar.dateComponents([.day], from: slot, to: takenDay).day ?? 0
        guard days != 0 else { return nil }
        if days == 1 { return "a day late" }
        if days > 1 { return "\(days) days late" }
        return nil
    }

    static func siteWord(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        return raw.replacingOccurrences(of: "_", with: " ")
    }

    /// ONE DAY GRAMMAR ACROSS THE THREE RECORD LISTS (v25 §37).
    ///
    /// `the doses` and `the symptoms` sit in the SAME frame — the
    /// regimen home draws one above the other — and `your weigh-ins` is
    /// the same object one tab over. Both siblings say `today` and
    /// `yesterday`; this one, written first, said `aug 14` for a shot
    /// marked an hour ago while the list directly beneath it said
    /// `today` for a symptom logged at the same moment. One date, two
    /// words, on one screen.
    ///
    /// The time zone is the second half of the same law. The PARSER
    /// below has always set `f.timeZone`; this printer did not, so it
    /// rendered in `TimeZone.current` whatever zone the calendar had
    /// decided the day in — a row the calendar placed on `aug 11`
    /// printing `aug 10`, the ledger disagreeing with itself about which
    /// day it is listing. `34` found it in `WeightLedger` and fixed it;
    /// `36` wrote it into `SymptomLedger` on the way in; this is the
    /// third and last copy.
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

    // NOT BUILT, and the reason is worth keeping: a "last time · <site>"
    // line for the dose sheet. Shotsy and MeAgain both state the last
    // site on the logging screen and it looked like a gap — it is not.
    // `SiteRotationAdvisor.line` has shipped since v24 and already says
    // *"left abdomen last time — the right side keeps the rotation"*,
    // which is the same fact plus the reason the cell is pre-picked.
    // It renders empty in QA only because the seeded account has no
    // prior TAKEN dose. Checked against the running product rather than
    // assumed from a competitor's screenshot.
}
