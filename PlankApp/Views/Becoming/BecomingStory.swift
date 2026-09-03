import Foundation

// MARK: - BecomingStory (pass 74 — BECOMING'S JOB)
//
// The pure reads behind Becoming's progress story. Research
// (docs/app_v25/74_*): the questions a customer actually opens a
// progress page to answer are "am I changing over THIS period",
// "how fast", and "is the last week making me misread the longer
// trend" — and for a medicated customer, "what has happened at each
// dose". Every read here derives from the ONE trend authority
// (WeightWeekReadEngine) so a spoken number can never disagree with
// the drawn line (the Cronometer failure: a delta indicator its own
// chart contradicted).
//
// Truth gates, stated once:
//   · a window delta speaks only when the trend series actually
//     COVERS the window (≥ ~3/4 of it) and the read's sufficiency
//     allows a band — a 30-day claim from 12 days of record is a
//     guess in a fact's clothes;
//   · a young dose era (< 4 weeks) never gets a rate — the standard
//     titration interval is the community/clinical floor for judging
//     a dose at all ("too early to read" is the honest sentence);
//   · rates are observed, never projected. No goal dates.

enum BecomingStory {

    // MARK: - the lens's own weight read

    struct WindowRead: Equatable {
        /// "down 4.6 lb this month." — nil when the record can't
        /// honestly carry the claim (caller falls back to the
        /// standing week read / journey line).
        let periodLine: String?
        let periodItalic: [String]
        /// "about 1.1 lb a week." — the observed rate over the
        /// window; nil unless the period line spoke a direction.
        let rateLine: String?
    }

    /// The flatness scale for a window claim — the trend authority's
    /// own plateau band.
    static var flatBandKg: Double { WeightWeekReadEngine.plateauFlatBandKg }

    /// The window's spoken name per lens.
    static func windowWord(_ scope: JeniScope) -> String {
        switch scope {
        case .month: return "this month"
        case .threeMonths: return "over 3 months"
        default: return "this window"
        }
    }

    /// Month / 3-month period read. Week keeps the standing band
    /// read; year/all keep the whole-distance journey line — this
    /// exists for the lenses that had NO story of their own (filmed:
    /// week and month rendered the identical hero).
    static func windowRead(
        samples: [WeightWeekReadEngine.Sample],
        scope: JeniScope,
        unit: WeightUnit,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WindowRead {
        let silent = WindowRead(periodLine: nil, periodItalic: [], rateLine: nil)
        guard scope == .month || scope == .threeMonths,
              let windowDays = scope.windowDays else { return silent }

        let read = WeightWeekReadEngine.read(
            samples: samples, now: now, calendar: calendar
        )
        // A band the engine won't speak weekly, this engine won't
        // stretch monthly; stale records claim nothing.
        guard read.band != nil else { return silent }

        let series = WeightWeekReadEngine.trendSeries(
            samples: samples, now: now,
            windowDays: windowDays, calendar: calendar
        )
        guard let first = series.first, let last = series.last else {
            return silent
        }
        // Coverage: the drawn trend must reach across ≥ ~3/4 of the
        // window, or the claim exceeds the record.
        let covered = calendar.dateComponents(
            [.day], from: first.day, to: last.day
        ).day ?? 0
        guard Double(covered) >= Double(windowDays) * 0.72 else { return silent }

        let deltaKg = last.trendKg - first.trendKg
        let word = windowWord(scope)

        if abs(deltaKg) <= flatBandKg {
            return WindowRead(
                periodLine: "held about steady \(word).",
                periodItalic: ["steady"],
                rateLine: nil
            )
        }

        let display = abs(unit.display(fromKg: deltaKg))
        let amount = "\(WeightLedger.number(display)) \(unit.label)"
        let weeks = Double(covered) / 7.0
        let ratePerWeek = display / max(1, weeks)
        // A rate under a tenth of a unit a week is noise spoken aloud.
        let rate = ratePerWeek >= 0.1
            ? "about \(WeightLedger.number(ratePerWeek)) \(unit.label) a week."
            : nil

        if deltaKg < 0 {
            return WindowRead(
                periodLine: "down \(amount) \(word).",
                periodItalic: ["down"],
                rateLine: rate
            )
        }
        return WindowRead(
            // §11.4 — a fuller month is never scolded.
            periodLine: "up about \(amount) \(word).",
            periodItalic: ["up"],
            rateLine: nil
        )
    }

    // MARK: - the flat week inside a moving month
    //
    // The research's single most repeated progress job: "is the last
    // week making me overreact to a longer trend?" (Happy Scale's
    // decade-tenure reviews are this sentence as a product). Speaks
    // ONLY when both halves are separately honest: the week's band is
    // holdingSteady AND the month's covered trend moved down by more
    // than noise.

    static func steadyContext(
        samples: [WeightWeekReadEngine.Sample],
        unit: WeightUnit,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (line: String, italic: [String])? {
        let read = WeightWeekReadEngine.read(
            samples: samples, now: now, calendar: calendar
        )
        guard read.band == .holdingSteady else { return nil }
        let month = windowRead(
            samples: samples, scope: .month, unit: unit,
            now: now, calendar: calendar
        )
        guard let line = month.periodLine, line.hasPrefix("down"),
              let amount = line.range(of: " this month.").map({
                  String(line[line.startIndex..<$0.lowerBound])
              })
        else { return nil }
        // "down 4.6 lb" → "this week reads flat. the month is still
        // down 4.6 lb."
        return ("this week reads flat. the month is still \(amount).", ["still"])
    }

    // MARK: - the dose seat (GLP-1 context on the progress story)
    //
    // Research: weight response per dose period is the category's
    // most-praised medicated read (Shotsy), and premature judgment
    // of a young dose is the dominant real-world failure mode — the
    // honest gate is ~4 weeks at a dose before any rate reads.

    struct DoseSeat: Equatable {
        /// "1 mg"
        let doseWord: String
        /// Whole weeks at the current dose (floored).
        let weeksAtDose: Int
        /// "week 9 at this dose" / "week 3 at this dose"
        var weeksLine: String { "week \(max(1, weeksAtDose + 1)) at this dose" }
        /// true while the current era is younger than 4 weeks.
        let tooEarly: Bool
        /// The young-era honesty line (nil once the era can read).
        let contextLine: String?
        /// Per-era weight rows, newest era first, ≤ 3 —
        /// ("on 1 mg", "down 8.0 lb · 8 wks"). The current era while
        /// young carries its standing instead of a number.
        let eraRows: [EraRow]

        struct EraRow: Equatable {
            let label: String
            let value: String
        }
    }

    struct EraInput: Equatable {
        let startedAt: Date
        let endedAt: Date?
        let doseWord: String?
        init(startedAt: Date, endedAt: Date?, doseWord: String?) {
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.doseWord = doseWord
        }
    }

    static let eraReadFloorDays = 28

    static func doseSeat(
        eras: [EraInput],
        samples: [WeightWeekReadEngine.Sample],
        unit: WeightUnit,
        numericsSuppressed: Bool = false,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DoseSeat? {
        guard let current = eras.last, let doseWord = current.doseWord
        else { return nil }

        let daysAtDose = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: current.startedAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        let weeks = max(0, daysAtDose / 7)
        let tooEarly = daysAtDose < eraReadFloorDays

        // The whole-record trend, walked once; era deltas read the
        // fold at each era's edges so the rows can never disagree
        // with the drawn line.
        let span = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(
                for: samples.map(\.day).min() ?? now
            ),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        let series = WeightWeekReadEngine.trendSeries(
            samples: samples, now: now,
            windowDays: span + 2, calendar: calendar
        )
        let trendByDay = Dictionary(
            uniqueKeysWithValues: series.map {
                (calendar.startOfDay(for: $0.day), $0.trendKg)
            }
        )
        func trend(on day: Date) -> Double? {
            trendByDay[calendar.startOfDay(for: day)]
        }

        var rows: [DoseSeat.EraRow] = []
        for era in eras.suffix(3).reversed() {
            guard let word = era.doseWord else { continue }
            let start = era.startedAt
            let end = min(era.endedAt ?? now, now)
            let eraDays = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: start),
                to: calendar.startOfDay(for: end)
            ).day ?? 0
            let eraWeeks = max(1, Int((Double(eraDays) / 7.0).rounded()))
            let isCurrent = era.endedAt == nil

            if isCurrent, eraDays < eraReadFloorDays {
                rows.append(.init(
                    label: "on \(word)",
                    value: "week \(max(1, eraDays / 7 + 1)) · early to read"
                ))
                continue
            }
            guard !numericsSuppressed,
                  let startTrend = trend(on: start),
                  let endTrend = trend(on: end),
                  eraDays >= 7
            else {
                rows.append(.init(
                    label: "on \(word)",
                    value: "\(eraWeeks) wk\(eraWeeks == 1 ? "" : "s")"
                ))
                continue
            }
            let deltaKg = endTrend - startTrend
            let display = unit.display(fromKg: abs(deltaKg))
            let sign = abs(deltaKg) <= flatBandKg ? "held"
                : (deltaKg < 0 ? "down" : "up")
            let value = sign == "held"
                ? "held · \(eraWeeks) wks"
                : "\(sign) \(WeightLedger.number(display)) \(unit.label) · \(eraWeeks) wk\(eraWeeks == 1 ? "" : "s")"
            rows.append(.init(label: "on \(word)", value: value))
        }

        return DoseSeat(
            doseWord: doseWord,
            weeksAtDose: weeks,
            tooEarly: tooEarly,
            contextLine: tooEarly
                ? "the weight response at a new dose usually reads after about 4 weeks."
                : nil,
            eraRows: rows
        )
    }
}
