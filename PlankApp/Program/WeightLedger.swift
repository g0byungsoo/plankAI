import Foundation

// MARK: - WeightLedger — the weigh-ins, listed (v25 §34)
//
// THE GAP THIS CLOSES, and it is the same shape `33` found in the
// medication domain one day earlier.
//
// `WeightLogRecord` has stored a day and a number since v1. Five
// engines read it — `TargetsService.resolvedWeightKg` (which is the
// numerator of the calorie target AND the protein floor),
// `WeightEMA`, `WeightJourney`, `WeightWeekReadEngine`, the Becoming
// tile — and **no screen has ever listed the rows.** Becoming draws a
// LINE. A line is a trend; it is not a record. You cannot read a date
// off it, you cannot tell a scale-with-shoes-on from a real day, and
// you cannot touch it.
//
// So the one number the whole product is priced on was, until today,
// the only record in Jeni with no list and no repair: food has THE
// BOOK (tap · fix · remove), doses have `the doses`, symptoms have
// their chips. The weigh-in had a chart.
//
// The cost was not cosmetic. A mistyped weigh-in is not a cosmetic
// error: the freshest row outranks every stored weight, so one wrong
// number silently moves her daily calorie target and her protein
// floor, and the only repair the product offered was to weigh again
// on the same calendar day. Miss that window and it is permanent.
//
// This engine is the list. It states facts and refuses everything
// else — no streak, no adherence, no "you skipped a week", no
// smoothing, no grade. `DoseLedger` is its sibling and its model.
//
// Pure over value types so the whole table is testable without a
// SwiftData container.

enum WeightLedger {

    /// One stored weigh-in, flattened out of `WeightLogRecord`.
    struct Entry: Equatable {
        var id: String
        var at: Date
        var kg: Double
        /// "manual" | "onboarding" | "healthkit"
        var source: String
    }

    /// Where a row came from, which decides what may be done to it.
    enum Provenance: String, Equatable {
        /// She typed it. The default, and the only silent one.
        case hers
        /// Apple Health handed it over.
        case health
        /// The number she gave at sign-up.
        case signUp
    }

    struct Row: Equatable, Identifiable {
        var id: String
        /// "today" · "yesterday" · "aug 12" (· ", 2025" across a year)
        var day: String
        /// "165.3 lb"
        var value: String
        /// "0.4 lb down" · "0.4 lb up" · "same" — against the weigh-in
        /// BEFORE it. nil on the oldest row, which has nothing behind
        /// it to compare against.
        var change: String?
        /// "from health" · "at sign-up". Hers renders nothing: a record
        /// does not need to announce that it is the ordinary case.
        var provenanceWord: String?
        var provenance: Provenance
        /// The stored value, so an editor can seed its ruler without
        /// re-deriving it from the display string.
        var kg: Double
        var at: Date
        var voiceOver: String
    }

    // MARK: - Rows

    /// Newest first. `now` and `calendar` are injected so the day words
    /// and the year rule are testable.
    static func rows(
        _ entries: [Entry],
        unit: WeightUnit,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Row] {
        // Newest first. Every stored row is listed — same-day rows are
        // NOT merged, because a row you cannot see is a row you cannot
        // remove, and Apple Health imports plus legacy data can leave
        // two on one day.
        let sorted = entries.sorted { $0.at > $1.at }
        var built = sorted.enumerated().map { index, entry in
            let previous = index + 1 < sorted.count ? sorted[index + 1] : nil
            return row(entry, previous: previous, unit: unit,
                       now: now, calendar: calendar)
        }

        // A DAY WORD MUST IDENTIFY EXACTLY ONE ROW.
        //
        // Two weigh-ins on one day are both listed on purpose (a row you
        // cannot see is a row you cannot remove), and the moment they
        // are, "yesterday" over "yesterday" is a screen asking her to
        // guess which one she is about to correct. When — and only
        // when — a day carries more than one row, each of them states
        // its time. Filmed: a Health import and a manual weigh-in on the
        // same yesterday.
        let dayCounts = built.reduce(into: [String: Int]()) { $0[$1.day, default: 0] += 1 }
        for index in built.indices where (dayCounts[built[index].day] ?? 0) > 1 {
            let clock = timeWord(built[index].at, calendar: calendar)
            built[index].day = "\(built[index].day) \u{00B7} \(clock)"
            built[index].voiceOver = spoken(built[index])
        }
        return built
    }

    /// "8:02am" — lowercase, no space before the meridiem, the same
    /// grammar THE BOOK's ledger rows use for a plate's time.
    static func timeWord(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mma"
        return f.string(from: date).lowercased()
    }

    static func row(
        _ entry: Entry,
        previous: Entry?,
        unit: WeightUnit,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Row {
        let shown = unit.display(fromKg: entry.kg)
        let value = "\(number(shown)) \(unit.label)"
        let day = dayWord(entry.at, now: now, calendar: calendar)
        let provenance = provenance(for: entry.source)
        let change = previous.map { changeWord(from: $0.kg, to: entry.kg, unit: unit) }

        let row = Row(
            id: entry.id,
            day: day,
            value: value,
            change: change,
            provenanceWord: provenanceWord(provenance),
            provenance: provenance,
            kg: entry.kg,
            at: entry.at,
            voiceOver: ""
        )
        return Row(
            id: row.id, day: row.day, value: row.value, change: row.change,
            provenanceWord: row.provenanceWord, provenance: row.provenance,
            kg: row.kg, at: row.at, voiceOver: spoken(row)
        )
    }

    /// VoiceOver reads the row as one sentence — the day, the number,
    /// the change, then where it came from — so the list is navigable
    /// without seeing the two-column layout.
    private static func spoken(_ row: Row) -> String {
        var out = "\(row.day), \(row.value)"
        if let change = row.change { out += ", \(change)" }
        if let word = row.provenanceWord { out += ", \(word)" }
        return out
    }

    // MARK: - The change
    //
    // THE NUMBER ON SCREEN MUST BE THE DIFFERENCE OF THE TWO NUMBERS ON
    // SCREEN. The change is computed from the DISPLAYED values, not
    // from the stored kilograms: `165.3` above `164.9` has to read
    // `0.4 lb down` or the row is arguing with the rows around it. This
    // is a ledger, not the trend — `WeightEMA` owns smoothing and
    // `WeightJourney` owns the story. Nothing here is smoothed, and a
    // gain is stated in exactly the same words as a loss.

    static func changeWord(from previousKg: Double, to kg: Double, unit: WeightUnit) -> String {
        let delta = unit.display(fromKg: kg) - unit.display(fromKg: previousKg)
        let rounded = (delta * 10).rounded() / 10
        guard abs(rounded) >= 0.05 else { return "same" }
        return "\(number(abs(rounded))) \(unit.label) \(rounded < 0 ? "down" : "up")"
    }

    // MARK: - Provenance

    static func provenance(for source: String) -> Provenance {
        switch source {
        case "healthkit": return .health
        case "onboarding": return .signUp
        default: return .hers
        }
    }

    static func provenanceWord(_ provenance: Provenance) -> String? {
        switch provenance {
        case .hers:   return nil
        case .health: return "from health"
        case .signUp: return "at sign-up"
        }
    }

    /// What the confirmation must say before a row leaves the record.
    ///
    /// A Health row names its other home: Apple Health still holds the
    /// sample. Since §44's day tombstone and pass 51's instant
    /// tombstone, `BodyMassImportService` refuses to re-import a
    /// cleared day or a cleared sample — this note used to warn "a
    /// later sync can bring it back", which stopped being true the day
    /// the tombstone shipped, and copy that under-promises the record's
    /// own guarantees is still a lie.
    static func removalNote(_ provenance: Provenance, day: String) -> String {
        switch provenance {
        case .health:
            return "this one came from apple health. it leaves your record here. apple health keeps its own copy, and jeni won't pull it back in."
        case .signUp:
            return "this is the weight you gave at sign-up. removing it takes it out of your line; it never touched your starting weight."
        case .hers:
            return "it leaves your line for \(day). your starting weight doesn't move."
        }
    }

    /// A correction to a Health row becomes HERS, and that is not a
    /// cosmetic relabel: `BodyMassImportService` re-imports the last
    /// thirty days on launch and overwrites any row still marked
    /// `healthkit`, so a typed correction that kept the old source
    /// would be silently reverted by the next sync. Its own rule —
    /// *"manual rows always win their day"* — is the fix, used
    /// correctly.
    static func sourceAfterCorrection(_ current: String) -> String { "manual" }

    // MARK: - Words

    /// "165.3" — one decimal, never a trailing `.0` on a whole number.
    static func number(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.001 {
            return String(Int(rounded.rounded()))
        }
        return String(format: "%.1f", rounded)
    }

    static func dayWord(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "yesterday" }
        let f = DateFormatter()
        f.calendar = calendar
        // The formatter must render in the SAME zone the calendar
        // decided the day in, or a row whose day the calendar called
        // "aug 11" prints "aug 10" — the ledger disagreeing with itself
        // about which day it is listing.
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        let sameYear = calendar.component(.year, from: date)
            == calendar.component(.year, from: now)
        f.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        return f.string(from: date).lowercased()
    }

    /// "37 on file since june" — the record's own weight, never a
    /// grade and never a cadence claim. A gap between weigh-ins is not
    /// reported, because "you didn't weigh in for nine days" is a
    /// reprimand wearing a fact's clothes.
    static func countLine(
        _ entries: [Entry], now: Date = .now, calendar: Calendar = .current
    ) -> String? {
        guard !entries.isEmpty else { return nil }
        let noun = entries.count == 1 ? "weigh-in" : "weigh-ins"
        guard let oldest = entries.map(\.at).min() else { return nil }
        if calendar.isDate(oldest, equalTo: now, toGranularity: .month) {
            return "\(entries.count) \(noun) this month"
        }
        let month = oldest.formatted(.dateTime.month(.wide)).lowercased()
        return "\(entries.count) \(noun) since \(month)"
    }

    // NOT BUILT, deliberately, and each refusal is a line this ledger
    // could have carried and does not:
    //   · a weigh-in streak or "N days since your last one" — the
    //     product has refused streaks four times and a cadence count is
    //     one with a date on it;
    //   · a per-row verdict, colour or arrow glyph — `up` and `down`
    //     are the same typography, and there is no red anywhere;
    //   · the EMA value beside the raw one — two numbers per row is how
    //     a ledger becomes a dashboard, and `WeightJourney` already
    //     states the trend once, in one place;
    //   · a rate ("0.8 lb/wk") — that is the weekly read's, floor-gated
    //     and cited, and it must not be recomputed here from two rows.
}
