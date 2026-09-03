import SwiftUI
import SwiftData
import PlankFood
import PlankSync

// MARK: - BecomingTile (v11 T4 — the tile model)
//
// Eight provenance-backed reads (docs/app_v11/00_REBIRTH.md §7).
// Every number traces to a collected store (L8); a tile below its
// data floor speaks its standing instead of drawing a fake trend.

struct BecomingTile: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case weight, calories, protein, fiber, sugar, sodium, sleep, steps,
             movement, waist, bodyFat,
             // v24 THE REGIMEN — renders ONLY when a regimen exists
             // (hidden-when-absent law); a quiet compact row, never
             // a lead.
             medication
    }

    let kind: Kind
    let title: String
    /// The tile's standing value ("164.2 lb", "112 g", "logging · 2 of 3 days").
    let value: String
    let meetsFloor: Bool
    /// Spark for the tile face; empty when below floor.
    let chart: JeniChartModel
    /// The detail page's read, in words.
    let read: String
    let readItalic: [String]
    /// The detail page's mechanism line — why this explains the body.
    let mechanism: String?
    /// The provenance whisper ("from your plates · last 7 days").
    let provenance: String
    /// v11.5 — word-tiles (waist) render the value compact, 3 lines.
    var compact: Bool = false
    /// v11.5 — chartless faces may carry one whisper where the spark
    /// would sit (body fat's "never from a photo").
    var faceCaption: String? = nil
    /// v11.5 — the honest x-axis label ("2 weeks"), sized to the data
    /// the chart actually holds. nil = the caller's default.
    var spanLabel: String? = nil
    /// v12 — the honest comparison whisper ("down 8% vs last week").
    /// nil when either window is below its floor.
    var deltaWord: String? = nil
    /// v12 C6 — the detail page's comparison ledger (this week / last
    /// week / this month), floor-gated per row.
    var summaryPairs: [SummaryPair] = []
    /// v12 C6 — what the plan DOES with this number (observed, never
    /// prescribed — D8; every claim is true of the live engines).
    var planLine: String? = nil
    /// v16 — the FACE's value at dashboard scale. A three-column grid
    /// cannot carry "about 1,060 a day"; the face says "1,060 /day"
    /// and the page it opens says the sentence. Falls back to `value`.
    var shortValue: String? = nil
    /// What the face shows: short when it has one.
    var faceValue: String { shortValue ?? value }

    struct SummaryPair: Equatable, Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    var id: String { kind.rawValue }

    /// v18.3 — only the metrics that answer "am I changing?" at a
    /// glance earn a TILE. Everything else is a row: same data, a
    /// twelfth of the height. Two columns is the maximum and the grid
    /// should not be filled just because it exists.
    var isPrimary: Bool {
        switch kind {
        case .weight, .calories, .protein, .steps: return true
        default: return false
        }
    }
}

// MARK: - The builder

enum BecomingTileBuilder {

    static func build(
        userId: String,
        snapshot: TodaySnapshot,
        sleepRecaps: [SleepService.NightRecap],
        scans: [BodyScanRecord] = [],
        scope: JeniScope = .week,
        in context: ModelContext
    ) -> [BecomingTile] {
        let cal = Calendar.current
        // Unfiltered — the aggregator windows per scope (and the
        // comparison window reaches one window further back).
        let entries = FoodLogPersister.allEntries(userId: userId)

        var tiles: [BecomingTile] = []
        // v25 E2 — the weight tile finally honors numeric
        // suppression (every other weight surface gated; this one
        // rendered raw numerals for the ed_screen/pregnant cohorts —
        // recon correction, body-privacy law).
        if !snapshot.targets.numericsSuppressed {
            tiles.append(weightTile(userId: userId, snapshot: snapshot,
                                    scope: scope, in: context))
        }
        // v24 — the medication tile sits beside the body it serves;
        // absent regimen = absent tile (never a nag to add one).
        if let medication = medicationTile(
            userId: userId, snapshot: snapshot, in: context
        ) {
            tiles.append(medication)
        }
        tiles.append(caloriesTile(snapshot: snapshot, entries: entries,
                                  scope: scope, cal: cal))
        tiles.append(nutrientTile(.protein, title: "protein", unit: "g",
                                  target: snapshot.targets.proteinG,
                                  entries: entries, scope: scope,
                                  snapshot: snapshot,
                                  mechanism: "protein protects muscle while you lose.",
                                  cal: cal))
        tiles.append(nutrientTile(.fiber, title: "fiber", unit: "g",
                                  target: nil, entries: entries, scope: scope,
                                  snapshot: snapshot,
                                  mechanism: "fiber steadies appetite between plates.",
                                  cal: cal))
        // Voice law: "sugar intake", never "sweetness".
        tiles.append(nutrientTile(.sugar, title: "sugar intake", unit: "g",
                                  target: nil, entries: entries, scope: scope,
                                  snapshot: snapshot,
                                  mechanism: "sugar late in the day feeds the next craving.",
                                  cal: cal))
        tiles.append(nutrientTile(.sodium, title: "sodium", unit: "mg",
                                  target: nil, entries: entries, scope: scope,
                                  snapshot: snapshot,
                                  mechanism: "sodium holds water. the scale follows for a day or two.",
                                  cal: cal))
        tiles.append(sleepTile(sleepRecaps))
        tiles.append(stepsTile())
        tiles.append(movementTile())
        // Pass 57 — the waist tile appends only when a record EXISTS:
        // its empty state advertised a capture feature that has left
        // the shipping experience. The ~8 users who kept scans keep
        // their tile; everyone else loses one "not yet" apology.
        if !scans.isEmpty {
            tiles.append(waistTile(scans: scans, snapshot: snapshot))
        }
        tiles.append(bodyFatTile(userId: userId, in: context))
        return tiles
    }

    // MARK: the scope's windows

    /// (window days, bucket days, the honest span label). The axis
    /// never claims more record than exists (§1.6) — "all" measures
    /// her actual record and buckets it legibly.
    private static func nutrientWindow(
        for scope: JeniScope,
        entries: [FoodLogPersister.FoodLogEntry],
        cal: Calendar
    ) -> (days: Int, bucket: Int, span: String) {
        switch scope {
        case .today: return (1, 1, "today")
        case .week: return (7, 1, "last 7 days")
        case .month: return (30, 1, "last 30 days")
        case .threeMonths: return (91, 7, "13 weeks · weekly averages")
        case .year: return (365, 30, "the last year · monthly averages")
        case .all:
            guard let first = entries.map(\.loggedAt).min() else {
                return (7, 1, "last 7 days")
            }
            let span = max(
                1,
                (cal.dateComponents(
                    [.day],
                    from: cal.startOfDay(for: first),
                    to: cal.startOfDay(for: .now)
                ).day ?? 0) + 1
            )
            if span <= 7 { return (7, 1, "last 7 days") }
            if span <= 31 { return (span, 1, "your whole record · \(span) days") }
            let bucket = max(1, Int((Double(span) / 20.0).rounded(.up)))
            return (span, bucket,
                    "your whole record · each bar ≈ \(bucket) days")
        }
    }

    /// The bucket's honest word — waiting rows must count what the
    /// scope actually counts (§1.6): days at daily scopes, weeks at
    /// 3 months, months at a year.
    private static func bucketWord(_ bucket: Int, count: Int) -> String {
        let word = bucket >= 25 ? "month" : bucket >= 6 ? "week" : "day"
        return "\(word)\(count == 1 ? "" : "s")"
    }

    /// "down 8% vs last week" — only when BOTH windows meet the floor,
    /// only for scopes with a nameable previous window. Neutral words;
    /// a fuller week is never scolded (§11.4).
    private static func deltaWord(
        _ nutrient: NutrientWeekAggregator.Nutrient,
        entries: [FoodLogPersister.FoodLogEntry],
        scope: JeniScope,
        cal: Calendar
    ) -> String? {
        guard let previous = scope.previousWord,
              let window = scope.windowDays else { return nil }
        let current = NutrientWeekAggregator.series(
            for: nutrient, entries: entries, endingOn: .now,
            days: window, bucketDays: 1, calendar: cal
        )
        guard let prevEnd = cal.date(
            byAdding: .day, value: -window, to: cal.startOfDay(for: .now)
        ) else { return nil }
        let prior = NutrientWeekAggregator.series(
            for: nutrient, entries: entries, endingOn: prevEnd,
            days: window, bucketDays: 1, calendar: cal
        )
        let floorCount = scope == .today ? 1 : 3
        guard current.loggedCount >= floorCount,
              prior.loggedCount >= floorCount else { return nil }
        let cur = current.collectedTotal / Double(current.loggedCount)
        let pre = prior.collectedTotal / Double(prior.loggedCount)
        guard pre > 0 else { return nil }
        let pct = (cur - pre) / pre * 100
        if abs(pct) < 3 { return "about even with \(previous)" }
        let word = pct < 0 ? "down" : "up"
        return "\(word) \(Int(abs(pct).rounded()))% vs \(previous)"
    }

    // MARK: calories

    private static func caloriesTile(
        snapshot: TodaySnapshot,
        entries: [FoodLogPersister.FoodLogEntry],
        scope: JeniScope,
        cal: Calendar
    ) -> BecomingTile {
        let (windowDays, bucket, span) = nutrientWindow(
            for: scope, entries: entries, cal: cal
        )
        let series = NutrientWeekAggregator.series(
            for: .calories, entries: entries, endingOn: .now,
            days: windowDays, bucketDays: bucket, calendar: cal
        )
        let mechanism = "keeping near the window is the whole plan."
        let floorCount = scope == .today ? 1 : 3

        guard series.loggedCount >= floorCount else {
            return BecomingTile(
                kind: .calories, title: "calories",
                value: scope == .today
                    ? "nothing logged yet"
                    : "logging · \(series.loggedCount) of 3 \(bucketWord(bucket, count: 3))",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: scope == .today
                    ? "log one plate and this fills in."
                    : "shows after 3 logged \(bucketWord(bucket, count: 3)).",
                readItalic: [],
                mechanism: mechanism,
                provenance: "from your plates · \(span)"
            )
        }

        let window = snapshot.targets.numericsSuppressed ? nil : snapshot.targets.kcal

        if scope == .today {
            let today = Int((series.days.last?.value ?? 0).rounded())
            let read: (String, [String]) = {
                guard let window else { return ("\(today.formatted()) kcal so far today.", []) }
                let left = window - today
                return left > 0
                    ? ("\(today.formatted()) so far · \(left.formatted()) left in the window.", ["left"])
                    : ("\(today.formatted()) so far · the window is met.", ["met."])
            }()
            return BecomingTile(
                kind: .calories, title: "calories",
                value: "\(today.formatted()) kcal today",
                meetsFloor: true,
                chart: JeniChartModel(form: .bars, series: []),
                read: read.0, readItalic: read.1,
                mechanism: mechanism,
                provenance: "from your plates · today",
                faceCaption: window.map { w in
                    let left = w - today
                    return left > 0 ? "\(left.formatted()) left" : "window met"
                },
                deltaWord: deltaWord(.calories, entries: entries, scope: scope, cal: cal)
            )
        }

        let avg = Int((series.collectedTotal / Double(max(1, series.loggedCount))).rounded())
        let read: (String, [String])
        if let window {
            read = avg <= window
                ? ("about \(avg.formatted()) a day, inside your \(window.formatted()) window.", ["inside"])
                : ("about \(avg.formatted()) a day, over the window. fuller weeks happen.", ["happen."])
        } else {
            read = ("about \(avg.formatted()) a day.", [])
        }
        return BecomingTile(
            kind: .calories, title: "calories",
            value: "about \(avg.formatted()) a day",
            meetsFloor: true,
            chart: JeniChartModel(form: .bars, series: [
                .init(values: series.values, role: .ink)
            ]),
            read: read.0, readItalic: read.1,
            mechanism: mechanism,
            provenance: "from your plates · \(span)",
            spanLabel: span,
            deltaWord: deltaWord(.calories, entries: entries, scope: scope, cal: cal),
            summaryPairs: summaryPairs(.calories, unit: "kcal", entries: entries, cal: cal),
            planLine: planLine(for: .calories, snapshot: snapshot),
            shortValue: "\(avg.formatted()) /day"
        )
    }

    // MARK: waist (BandProfile's words — never a number, L3/L7)

    private static func waistTile(
        scans: [BodyScanRecord], snapshot: TodaySnapshot
    ) -> BecomingTile {
        let falling = (snapshot.emaDelta7dKg ?? 0) < -0.05
        var read: BandProfile.Read?
        if scans.count >= 2,
           let nowInk = BodyScanPhotoStore.silhouette(scanId: scans[0].id),
           let thenInk = BodyScanPhotoStore.silhouette(scanId: scans[1].id),
           let now = BandProfile.profile(of: nowInk),
           let then = BandProfile.profile(of: thenInk) {
            read = BandProfile.read(now: now, then: then, trendFalling: falling)
        }

        guard let read else {
            return BecomingTile(
                kind: .waist, title: "waist",
                value: scans.count < 2 ? "needs two check-ins" : "the plates read close",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: "two comparable check-ins and this page fills in.",
                readItalic: ["two"],
                mechanism: "the camera reads shape only. it never guesses a number.",
                provenance: "from your check-ins · on your phone only",
                compact: true
            )
        }
        return BecomingTile(
            kind: .waist, title: "waist",
            value: read.headline,
            meetsFloor: true,
            chart: JeniChartModel(form: .bars, series: []),
            read: read.headline,
            readItalic: [],
            mechanism: read.notes.first ?? "compare week to week, not day to day.",
            provenance: "from your check-ins · never a number",
            compact: true
        )
    }

    // MARK: body fat (the provenance ladder — L7 holds)

    private static func bodyFatTile(
        userId: String, in context: ModelContext
    ) -> BecomingTile {
        let body = BodyStateService.current(userId: userId, in: context)
        let d = UserDefaults.standard
        let heightCm = d.double(forKey: "onboardingHeightCm")
        let age = d.integer(forKey: "onb_v5_age_years")
        let startKg = d.double(forKey: "onboardingCurrentWeightKg")
        let isFemale: Bool? = {
            switch (d.string(forKey: "onboardingGender") ?? "").lowercased() {
            case "female": return true
            case "male": return false
            default: return nil
            }
        }()
        let read = BodyFatEstimate.read(
            healthPct: body.composition?.bodyFatPct,
            weightKg: body.weight?.latestKg ?? (startKg > 25 ? startKg : nil),
            heightCm: heightCm > 100 ? heightCm : nil,
            ageYears: age >= 18 ? age : nil,
            isFemale: isFemale
        )

        guard let read else {
            return BecomingTile(
                kind: .bodyFat, title: "body fat",
                value: "needs your numbers",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: "height, weight and age unlock the estimate. a smart scale beats it.",
                readItalic: [],
                mechanism: "never read from your photo. the consent promise holds.",
                provenance: "estimated · never from a photo"
            )
        }
        return BecomingTile(
            kind: .bodyFat, title: "body fat",
            value: read.isMeasured ? read.value : "\(read.value) · estimated",
            // v19 — only a MEASURED body fat is a reading. The
            // Deurenberg band is a legitimate estimate (the provenance
            // ladder, L7) but a six-point range is not something to
            // scan on a dashboard; it states its standing instead and
            // the page still carries the full ladder.
            meetsFloor: read.isMeasured,
            chart: JeniChartModel(form: .bars, series: []),
            read: read.isMeasured
                ? "\(read.value), from your scale."
                : "somewhere around \(read.value), by the standard estimate.",
            readItalic: [read.value],
            mechanism: read.caveat,
            provenance: read.provenance,
            faceCaption: read.isMeasured ? "measured" : "estimated"
        )
    }

    // MARK: weight

    private static func weightTile(
        userId: String, snapshot: TodaySnapshot,
        scope: JeniScope = .week,
        in context: ModelContext
    ) -> BecomingTile {
        let cal = Calendar.current
        // Weight reads in trends, so the window floors at 4 weeks even
        // on tighter scopes; wider scopes widen it; "all" opens to the
        // whole record.
        let scopeDays: Int = {
            guard let days = scope.windowDays else { return 3650 }
            return max(28, days)
        }()
        let start = cal.date(byAdding: .day, value: -(scopeDays - 1),
                             to: cal.startOfDay(for: .now)) ?? .now

        // Pass 51 — ONE weight story. This tile carried a FIFTH copy of
        // the weight resolution (its own fetch, latest-of-day, a
        // hand-ported 7-day EMA) and spoke direction words from the
        // fast trigger fold — the most-seen weight line in the product
        // could slope and speak against jeni's sentence. It now draws
        // the canonical series through THE trend authority and speaks
        // the same gated band the coach and the weekly read speak.
        // p55 — the FOLD runs over the whole record; the scope only
        // decides what the chart DRAWS. Pre-filtering the samples
        // re-seeded the τ-EMA at the window edge, so the tile's
        // weekly delta could differ from Home's and jeni's on the
        // same morning.
        let allSamples = WeightSeries.samples(userId: userId, in: context, calendar: cal)
        let samples = allSamples.filter { $0.day >= start }
        let weekRead = WeightWeekReadEngine.read(
            samples: allSamples, now: .now, calendar: cal
        )

        let unit = WeightUnit(
            rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
        ) ?? .lb

        // The window scopes to the RECORD, not to a fixed 28 days: a
        // chart whose left half is empty reads as a rendering bug and
        // its "4 weeks ago" label lies. Start at her first weigh-in
        // (keeping at least a week of context), end today.
        let today = cal.startOfDay(for: .now)
        let weekBack = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let firstLogged = samples.first.map { cal.startOfDay(for: $0.day) } ?? start
        let windowStart = min(max(start, firstLogged), weekBack)
        let span = max(1, (cal.dateComponents([.day], from: windowStart, to: today).day ?? 27))

        // The drawn line folds the whole record too (windowDays only
        // trims the OUTPUT); the chart shows the window, the fold
        // remembers the history.
        let trendByDay = Dictionary(
            uniqueKeysWithValues: WeightWeekReadEngine.trendSeries(
                samples: allSamples, now: .now,
                windowDays: span + 1, calendar: cal
            ).map { ($0.day, $0) }
        )
        let gridDays: [Date?] = (0...span).map {
            cal.date(byAdding: .day, value: $0, to: windowStart)
        }
        let raw: [Double?] = gridDays.map { day in
            day.flatMap { trendByDay[cal.startOfDay(for: $0)]?.rawKg }
                .map { unit.display(fromKg: $0) }
        }
        let ema: [Double?] = gridDays.map { day in
            day.flatMap { trendByDay[cal.startOfDay(for: $0)]?.trendKg }
                .map { unit.display(fromKg: $0) }
        }

        // p57 — one number grammar for one number: the ledger's own
        // rule (one decimal, never a trailing .0) so the tile and
        // `your weigh-ins` can never disagree about the same row
        // ("159.0 lb" here vs "159 lb" there, walk-caught).
        let latest = snapshot.latestWeightKg.map {
            "\(WeightLedger.number(unit.display(fromKg: $0))) \(unit.label)"
        }

        let established = weekRead.band != nil
        let read: (String, [String])
        if let band = weekRead.band, let delta = weekRead.weeklyDeltaKg {
            let word = "\(WeightLedger.number(abs(unit.display(fromKg: delta)))) \(unit.label)"
            switch band {
            case .trendingDown:
                read = ("down about \(word) this week.", ["down"])
            case .driftingUp:
                read = ("up about \(word) this week. weeks like this happen.", ["happen."])
            case .holdingSteady:
                read = ("holding steady this week.", ["steady"])
            }
        } else {
            read = ("your trend needs a few more weigh-ins.", ["trend"])
        }

        // The detail ledger (C6): the week beside the whole record —
        // the same gated band as the face line (one story).
        var pairs: [BecomingTile.SummaryPair] = []
        if let band = weekRead.band, let delta = weekRead.weeklyDeltaKg {
            let word = "\(WeightLedger.number(abs(unit.display(fromKg: delta)))) \(unit.label)"
            let direction: String = switch band {
            case .trendingDown: "down about"
            case .driftingUp: "up about"
            case .holdingSteady: "steady, within"
            }
            pairs.append(.init(label: "this week", value: "\(direction) \(word)"))
        }
        let reals = raw.compactMap { $0 }
        if reals.count >= 2, let firstW = reals.first, let nowW = reals.last {
            pairs.append(.init(
                label: "the record",
                value: "from \(WeightLedger.number(firstW)) to \(WeightLedger.number(nowW)) \(unit.label)"
            ))
        }
        if pairs.count < 2 { pairs = [] }

        // p58 — THE DOSE ERAS reach the trend (v24's prepared design,
        // founder-gated until now): a hairline seam where the dose
        // actually moved, labeled with the new dose's own word.
        // Timing, never causality — the delta-per-era read stays on
        // the medication tile's ledger and is not repeated here. A
        // change before the window draws nothing (no seam at the
        // chart's edge); suppression is upstream (this tile does not
        // render for suppressed cohorts at all).
        var markers: [JeniChartModel.Marker] = []
        let doseEras = RegimenEras.eras(RegimenEras.versions(
            of: RegimenService.medicationHistory(userId: userId, in: context)
        ))
        if doseEras.count >= 2 {
            for i in 1..<doseEras.count {
                guard let before = doseEras[i - 1].strengthValue,
                      let after = doseEras[i].strengthValue,
                      before != after else { continue }
                let idx = cal.dateComponents(
                    [.day], from: windowStart,
                    to: cal.startOfDay(for: doseEras[i].startedAt)
                ).day ?? -1
                guard idx > 0, idx <= span else { continue }
                markers.append(.init(
                    index: idx,
                    label: "\(MedicationProduct.doseWord(after)) \(doseEras[i].strengthUnit)"
                ))
            }
        }

        return BecomingTile(
            kind: .weight,
            title: "weight",
            value: latest ?? "no weigh-ins yet",
            meetsFloor: established,
            // p70 — the drawn line shares the SPOKEN fold: when the
            // band is withheld ("your trend needs a few more
            // weigh-ins"), drawing the smoothed trend anyway is the
            // claim the words just refused (filmed: "a few more
            // weigh-ins and your trend line starts." over a drawn
            // trend line). Her raw weigh-ins are the record and
            // always draw; the EMA draws only once it is speakable.
            chart: JeniChartModel(form: .line, series: established ? [
                .init(values: raw, role: .ink),
                .init(values: ema, role: .context),
            ] : [
                .init(values: raw, role: .ink),
            ], yPaddingFraction: 0.45,   // generous headroom: a 2-3 lb
                                          // week must READ gentle, not
                                          // a cliff (the zoom lies)
               bridgeGaps: true,    // weigh-ins are sparse by nature
               markers: markers),
            read: read.0,
            readItalic: read.1,
            mechanism: "single days bounce. the trend is what counts.",
            // p55 — with no real weigh-in on file, the value shown is
            // the ladder's (her sign-up answer); "from your weigh-ins"
            // would call a typed consult answer a weigh-in.
            provenance: allSamples.isEmpty
                ? "from your sign-up answer"
                : "from your weigh-ins · \(spanWord(days: span))",
            spanLabel: spanWord(days: span),
            summaryPairs: pairs,
            planLine: planLine(for: .weight, snapshot: snapshot)
        )
    }

    /// "11 days" / "3 weeks" / "5 months" — the axis never claims
    /// more record than exists.
    private static func spanWord(days: Int) -> String {
        if days >= 350 { return "a year" }
        if days >= 55 {
            return "\(Int((Double(days) / 30.0).rounded())) months"
        }
        if days >= 25 { return "4 weeks" }
        if days >= 18 { return "3 weeks" }
        if days >= 11 { return "2 weeks" }
        if days >= 6 { return "a week" }
        return "\(days + 1) days"
    }

    // MARK: nutrients

    private static func nutrientTile(
        _ nutrient: NutrientWeekAggregator.Nutrient,
        title: String, unit: String, target: Int?,
        entries: [FoodLogPersister.FoodLogEntry],
        scope: JeniScope,
        snapshot: TodaySnapshot,
        mechanism: String, cal: Calendar
    ) -> BecomingTile {
        let (windowDays, bucket, span) = nutrientWindow(
            for: scope, entries: entries, cal: cal
        )
        let series = NutrientWeekAggregator.series(
            for: nutrient, entries: entries, endingOn: .now,
            days: windowDays, bucketDays: bucket, calendar: cal
        )
        let kind: BecomingTile.Kind = {
            switch nutrient {
            case .protein: return .protein
            case .fiber: return .fiber
            case .sugar: return .sugar
            case .sodium: return .sodium
            case .calories: return .calories
            case .saturatedFat: return .fiber   // unreachable in the tile set
            }
        }()
        let floorCount = scope == .today ? 1 : 3

        guard series.loggedCount >= floorCount else {
            return BecomingTile(
                kind: kind, title: title,
                value: scope == .today
                    ? "nothing logged yet"
                    : "logging · \(series.loggedCount) of 3 \(bucketWord(bucket, count: 3))",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: scope == .today
                    ? "log one plate and this fills in."
                    : "shows after 3 logged \(bucketWord(bucket, count: 3)).",
                readItalic: [],
                mechanism: mechanism,
                provenance: "from your plates · \(span)"
            )
        }

        let delta = deltaWord(nutrient, entries: entries, scope: scope, cal: cal)

        if scope == .today {
            let today = Int((series.days.last?.value ?? 0).rounded())
            return BecomingTile(
                kind: kind, title: title,
                value: "\(today.formatted()) \(unit) today",
                meetsFloor: true,
                chart: JeniChartModel(form: .bars, series: []),
                read: {
                    if nutrient == .protein, let target {
                        let left = target - today
                        return left > 0
                            ? "\(today)g so far · about \(left)g to your floor."
                            : "\(today)g so far · the floor is met."
                    }
                    return "\(today.formatted()) \(unit) so far today."
                }(),
                readItalic: [],
                mechanism: mechanism,
                provenance: "from your plates · today",
                deltaWord: delta
            )
        }

        let avg = series.collectedTotal / Double(max(1, series.loggedCount))
        let value = "about \(Int(avg.rounded())) \(unit) a day"

        let read: (String, [String])
        switch nutrient {
        case .protein:
            if let target, bucket == 1 {
                let met = series.days.compactMap(\.value)
                    .filter { $0 >= Double(target) }.count
                read = ("protein reached \(target)g on \(met) of \(series.loggedCount) logged days.", ["\(met)"])
            } else {
                read = ("about \(Int(avg.rounded()))g a day.", [])
            }
        case .sodium:
            if bucket == 1 {
                let high = series.days.compactMap(\.value).filter { $0 > 2300 }.count
                read = high > 0
                    ? ("sodium ran high on \(high) day\(high == 1 ? "" : "s").", ["high"])
                    : ("sodium stayed steady.", ["steady"])
            } else {
                read = ("about \(Int(avg.rounded())) mg a day.", [])
            }
        case .sugar:
            read = ("about \(Int(avg.rounded()))g of sugar a day.", [])
        case .fiber:
            read = ("about \(Int(avg.rounded()))g of fiber a day.", [])
        case .calories, .saturatedFat:
            read = ("", [])   // calories has its own builder
        }

        return BecomingTile(
            kind: kind, title: title, value: value,
            meetsFloor: true,
            chart: JeniChartModel(form: .bars, series: [
                .init(values: series.values, role: .ink)
            ]),
            read: read.0, readItalic: read.1,
            mechanism: mechanism,
            provenance: "from your plates · \(span)",
            spanLabel: span,
            deltaWord: delta,
            summaryPairs: summaryPairs(nutrient, unit: unit, entries: entries, cal: cal),
            planLine: planLine(for: kind, snapshot: snapshot),
            // A third-width face cannot carry "2,094 mg/day" (it
            // clipped — frame-caught). Long units drop the cadence;
            // the page it opens still says "a day".
            shortValue: unit == "mg"
                ? "\(Int(avg.rounded()).formatted()) mg"
                : "\(Int(avg.rounded()).formatted()) \(unit)/day"
        )
    }

    // MARK: sleep / steps / movement

    // MARK: medication (v24 THE REGIMEN)

    /// The quiet clinical tile: her dose as the value, the last
    /// slots as a tally strip (taken = a full bar, unresolved = a
    /// gap — honest by geometry), the pattern engine's observations
    /// in the detail, and THE DOSE ERAS as a ledger (what her
    /// weight did on each dose — timing, never causality). nil
    /// without a regimen: medication that doesn't exist renders
    /// nowhere.
    private static func medicationTile(
        userId: String, snapshot: TodaySnapshot, in context: ModelContext
    ) -> BecomingTile? {
        guard let plan = RegimenService.activeMedicationPlan(
            userId: userId, in: context
        ) else { return nil }

        let name = MedicationCatalog.renderName(
            productId: plan.productId, displayName: plan.displayName
        )
        let doseWord = plan.strengthValue.map {
            "\(MedicationProduct.doseWord($0)) \(plan.strengthUnit ?? "mg")"
        }
        let value = doseWord ?? (name == "your medication" ? "set up" : name)

        let events = DoseEventStore.events(userId: userId, limit: 12, in: context)
        guard !events.isEmpty else {
            // v25 E2 (08_E2 outcome 6) — an ACTIVE regimen with a
            // history never reads "not enough to read yet": her
            // medication and dose are already facts worth showing;
            // only the marks are still to come.
            return BecomingTile(
                kind: .medication, title: "your medication",
                value: value,
                meetsFloor: true,
                chart: JeniChartModel(form: .bars, series: []),
                read: "dose marks land here.",
                readItalic: [],
                mechanism: "the day composes around the dose. marking it keeps the record honest.",
                provenance: "from your dose marks"
            )
        }

        // The tally strip, oldest → newest: taken = 1, everything
        // else a gap. Uniform height on purpose — a rhythm, not a
        // quantity.
        let strip: [Double?] = events.reversed().map {
            $0.status == "taken" ? 1.0 : nil
        }
        let resolved = events.filter {
            ["taken", "skipped", "missed"].contains($0.status)
        }
        let taken = resolved.filter { $0.status == "taken" }.count
        let adherence = MedicationPatternEngine.adherenceLine(
            taken: taken, resolved: resolved.count
        )

        // The pattern engine's read — p72: the ONE inputs composer
        // (this build, jeni's read_patterns and the regimen page used
        // to each hand-copy the mapping).
        let history = RegimenService.medicationHistory(userId: userId, in: context)
        let doseEras = RegimenEras.eras(RegimenEras.versions(of: history))
        let observations = MedicationPatternEngine.observations(
            MedicationPatternEngine.composedInputs(
                plan: plan, userId: userId, in: context
            )
        )

        // THE DOSE ERAS ledger — her weight across each dose's span
        // (numeric-suppressed cohorts read the eras without numbers).
        var pairs: [BecomingTile.SummaryPair] = []
        if !snapshot.targets.numericsSuppressed {
            let unit = WeightUnit.current
            let weightDescriptor = FetchDescriptor<WeightLogRecord>(
                predicate: #Predicate { $0.userId == userId },
                sortBy: [SortDescriptor(\.loggedAt)]
            )
            let logs = ((try? context.fetch(weightDescriptor)) ?? [])
                .filter { $0.source != "onboarding" }
            // p58 — one row per DOSE ERA, not per version: a schedule
            // change used to split one dose's span into two rows.
            for era in doseEras.suffix(3).reversed() where era.strengthValue != nil {
                let span = logs.filter {
                    $0.loggedAt >= era.startedAt
                        && $0.loggedAt <= (era.endedAt ?? .now)
                }
                guard let first = span.first, let last = span.last,
                      span.count >= 2 else { continue }
                let delta = unit.display(fromKg: last.weightKg)
                    - unit.display(fromKg: first.weightKg)
                let weeks = max(
                    1,
                    Calendar.current.dateComponents(
                        [.day], from: era.startedAt,
                        to: era.endedAt ?? .now
                    ).day.map { $0 / 7 } ?? 1
                )
                let doseLabel = era.strengthValue.map {
                    "on \(MedicationProduct.doseWord($0)) \(era.strengthUnit)"
                } ?? "earlier"
                pairs.append(.init(
                    label: doseLabel,
                    value: String(
                        format: "%+.1f %@ · %d wk%@",
                        delta, unit.label, weeks, weeks == 1 ? "" : "s"
                    )
                ))
            }
        }

        return BecomingTile(
            kind: .medication, title: "your medication",
            value: value,
            meetsFloor: true,
            chart: JeniChartModel(form: .bars, series: [
                .init(values: strip, role: .ink)
            ]),
            read: adherence ?? "the record is young. it reads after a few doses.",
            readItalic: [],
            mechanism: observations.first?.sentence
                ?? "patterns read here once doses and days accumulate. timing, never blame.",
            provenance: "from your dose marks and weigh-ins · estimates say so",
            summaryPairs: pairs,
            planLine: observations.dropFirst().first?.sentence,
            shortValue: doseWord ?? "—"
        )
    }

    private static func sleepTile(_ recaps: [SleepService.NightRecap]) -> BecomingTile {
        let hours = recaps.map { Optional($0.hours) }
        let counted = recaps.count
        guard counted >= 3 else {
            return BecomingTile(
                kind: .sleep, title: "sleep",
                value: counted == 0 ? "no nights read yet" : "reading · \(counted) of 3 nights",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: "this reads after 3 nights.",
                readItalic: [],
                mechanism: "short nights raise appetite the next day.",
                provenance: "from your phone's sleep record"
            )
        }
        let avg = recaps.map(\.hours).reduce(0, +) / Double(counted)
        let short = recaps.map(\.hours).filter { $0 < 6 }.count
        return BecomingTile(
            kind: .sleep, title: "sleep",
            value: String(format: "%.1f h a night", avg),
            meetsFloor: true,
            chart: JeniChartModel(form: .bars, series: [
                .init(values: hours, role: .ink)
            ]),
            read: short > 0
                ? "\(short) short night\(short == 1 ? "" : "s") this week. appetite runs louder after them."
                : "your nights held this week.",
            readItalic: short > 0 ? ["louder"] : ["held"],
            mechanism: "short nights raise appetite the next day.",
            provenance: "from your phone's sleep record · last 7 nights",
            planLine: "short nights soften the next day's plan — the gentle tone is automatic.",
            shortValue: String(format: "%.1f h", avg)
        )
    }

    private static func stepsTile() -> BecomingTile {
        let counts = StepsService.shared.weeklyCounts
        let active = counts.filter { $0 > 0 }.count
        let values: [Double?] = counts.map { $0 > 0 ? Double($0) : nil }
        guard active >= 3 else {
            return BecomingTile(
                kind: .steps, title: "steps",
                value: active == 0 ? "not reading yet" : "reading · \(active) of 3 days",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: "this reads after 3 active days.",
                readItalic: [],
                mechanism: "steps are the quiet half of the deficit.",
                provenance: "from your phone · last 7 days"
            )
        }
        let avg = counts.reduce(0, +) / max(1, active)
        return BecomingTile(
            kind: .steps, title: "steps",
            value: "\(avg.formatted()) a day",
            meetsFloor: true,
            chart: JeniChartModel(form: .bars, series: [
                .init(values: values, role: .ink)
            ]),
            read: "about \(avg.formatted()) steps on your active days.",
            readItalic: [],
            mechanism: "steps are the quiet half of the deficit.",
            provenance: "from your phone · last 7 days",
            planLine: "steps count toward the day on their own — no logging.",
            shortValue: "\(avg.formatted()) /day"
        )
    }

    private static func movementTile() -> BecomingTile {
        // p53 — a hand-kept record is a record: the tile counts her
        // recorded sessions alongside health's and says which is
        // which. "not connected" renders only when NO source exists —
        // a user who records every session by hand was reading it
        // with three sessions on file.
        let healthKit = MovementService.shared.everRequested
            ? MovementService.shared.strengthSessionsLast7 : 0
        let entered = MoveManualStore.strengthLastWeek()
        guard MovementService.shared.everRequested || entered > 0 else {
            return BecomingTile(
                kind: .movement, title: "movement",
                value: "not connected",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: "connect workouts in settings, or add one by hand under move.",
                readItalic: [],
                mechanism: "strength work tells the body to keep muscle.",
                provenance: "from apple health, when you allow it"
            )
        }
        let sessions = healthKit + entered
        let provenance: String = {
            if healthKit > 0 && entered > 0 {
                return "apple health + your entries · last 7 days"
            }
            if entered > 0 { return "recorded by you · last 7 days" }
            return "from apple health · last 7 days"
        }()
        return BecomingTile(
            kind: .movement, title: "movement",
            value: sessions == 0 ? "quiet week"
                : "\(sessions) session\(sessions == 1 ? "" : "s") this week",
            meetsFloor: true,
            chart: JeniChartModel(form: .bars, series: []),
            read: sessions > 0
                ? "\(sessions) strength session\(sessions == 1 ? "" : "s") in the last 7 days."
                : "a quiet week for training. the plan holds.",
            readItalic: [],
            mechanism: "strength work tells the body to keep muscle.",
            provenance: provenance,
            shortValue: sessions == 0 ? "quiet week" : "\(sessions) session\(sessions == 1 ? "" : "s")"
        )
    }
}

// MARK: - BecomingInsightBuilder (v12 C5 — the week, read)
//
// The insight carousel's facts. Every card traces to a collected
// store and renders ONLY past its floor (D9) — an insight without
// data is decoration. Weekly by design: these are the week's reads,
// whatever scope the grid below is set to.

enum BecomingInsightBuilder {

    static func build(
        userId: String,
        snapshot: TodaySnapshot,
        scans: [BodyScanRecord],
        keptRun: Int,
        cal: Calendar = Calendar.current
    ) -> [JeniInsight] {
        let entries = FoodLogPersister.allEntries(userId: userId)
        var out: [JeniInsight] = []

        // v18.3 — the protein-days card was CUT. It restated the
        // protein tile in a whole panel, and on a thin week it said
        // "0 of 4 days", which is a panel spent on nothing. An
        // insight must say something the grid cannot.

        // 2 — sodium, moving (week vs the week before).
        if let card = deltaCard(
            .sodium, eyebrow: "sodium", entries: entries, cal: cal,
            downSentence: "less held water. the scale reads truer.",
            downItalic: ["truer."],
            upSentence: "salt ran higher. the scale can read heavy for a day or two. water, not fat.",
            upItalic: ["water, not fat."]
        ) { out.append(card) }

        // 3 — the run (her consistency, from the kept-day record).
        // A card never leads with a zero; below the floor it simply
        // does not render.
        if keptRun >= 3 {
            out.append(JeniInsight(
                id: "kept-run", eyebrow: "consistency",
                value: Double(keptRun), word: "days",
                figure: .none,
                sentence: "you've shown up \(keptRun) days in a row.",
                sentenceItalic: ["\(keptRun) days"]
            ))
        }

        // v20 — the "body record" card was CUT. It took the screen's
        // second-most-valuable slot to announce "1 check-in this
        // month", which is a fact the BODY panel above it already
        // implies and which no one opens an app to read. Same rule as
        // the protein card: an insight must say something the grid
        // cannot, and it must be worth the space it takes.

        return out
    }

    /// A week-over-week movement card — only when both weeks meet the
    /// floor AND the move is big enough to mean something (±8%; daily
    /// chemistry is noisy, and a card that reads noise is decoration).
    private static func deltaCard(
        _ nutrient: NutrientWeekAggregator.Nutrient,
        eyebrow: String,
        entries: [FoodLogPersister.FoodLogEntry],
        cal: Calendar,
        downSentence: String, downItalic: [String],
        upSentence: String, upItalic: [String]
    ) -> JeniInsight? {
        let current = NutrientWeekAggregator.week(
            for: nutrient, entries: entries, endingOn: .now, calendar: cal
        )
        guard let prevEnd = cal.date(
            byAdding: .day, value: -7, to: cal.startOfDay(for: .now)
        ) else { return nil }
        let prior = NutrientWeekAggregator.week(
            for: nutrient, entries: entries, endingOn: prevEnd, calendar: cal
        )
        guard current.loggedCount >= 3, prior.loggedCount >= 3 else { return nil }
        let cur = current.collectedTotal / Double(current.loggedCount)
        let pre = prior.collectedTotal / Double(prior.loggedCount)
        guard pre > 0 else { return nil }
        let pct = (cur - pre) / pre * 100
        guard abs(pct) >= 8 else { return nil }

        // The figure: two weeks of daily bars, gap between the weeks.
        let bars = NutrientWeekAggregator.series(
            for: nutrient, entries: entries, endingOn: .now,
            days: 14, bucketDays: 1, calendar: cal
        )
        let down = pct < 0
        return JeniInsight(
            id: "delta-\(eyebrow)", eyebrow: eyebrow,
            value: nil,
            valueText: "\(down ? "down" : "up") \(Int(abs(pct).rounded()))%",
            word: "vs last week",
            figure: .bars(bars.values),
            sentence: down ? downSentence : upSentence,
            sentenceItalic: down ? downItalic : upItalic
        )
    }

    private static func dayLetter(_ date: Date, cal: Calendar) -> String {
        let letters = ["s", "m", "t", "w", "t", "f", "s"]
        return letters[cal.component(.weekday, from: date) - 1]
    }
}

// MARK: - The detail ledger (v12 C6)
//
// Week / last week / month comparison rows for a nutrient page —
// computed independently of the grid's scope, each row floor-gated
// (≥3 collected days or it doesn't render).

extension BecomingTileBuilder {

    static func summaryPairs(
        _ nutrient: NutrientWeekAggregator.Nutrient,
        unit: String,
        entries: [FoodLogPersister.FoodLogEntry],
        cal: Calendar
    ) -> [BecomingTile.SummaryPair] {
        func avgWord(days: Int, endingOn: Date) -> String? {
            let s = NutrientWeekAggregator.series(
                for: nutrient, entries: entries, endingOn: endingOn,
                days: days, bucketDays: 1, calendar: cal
            )
            guard s.loggedCount >= 3 else { return nil }
            let avg = s.collectedTotal / Double(s.loggedCount)
            return "about \(Int(avg.rounded()).formatted()) \(unit) a day"
        }

        var pairs: [BecomingTile.SummaryPair] = []
        if let week = avgWord(days: 7, endingOn: .now) {
            pairs.append(.init(label: "this week", value: week))
        }
        if let prevEnd = cal.date(byAdding: .day, value: -7,
                                  to: cal.startOfDay(for: .now)),
           let last = avgWord(days: 7, endingOn: prevEnd) {
            pairs.append(.init(label: "last week", value: last))
        }
        if let month = avgWord(days: 30, endingOn: .now), pairs.count >= 1 {
            pairs.append(.init(label: "this month", value: month))
        }
        // One row is not a comparison — the ledger earns its place
        // with two or more.
        return pairs.count >= 2 ? pairs : []
    }

    /// What the live engines actually do with each number (D8). Every
    /// sentence is true of shipped behavior — never a promise, never
    /// an instruction.
    static func planLine(
        for kind: BecomingTile.Kind, snapshot: TodaySnapshot
    ) -> String? {
        switch kind {
        case .calories:
            guard let kcal = snapshot.targets.kcal,
                  !snapshot.targets.numericsSuppressed else { return nil }
            return "your plan holds the window at \(kcal.formatted()) kcal, paced to your goal."
        case .protein:
            guard let target = snapshot.targets.proteinG else { return nil }
            return "your plan keeps a \(target)g floor — protein first on protein days."
        case .sodium:
            return "no target here. jeni reads it so a heavy scale day can be named water, not fat."
        case .sugar:
            return "no target here. jeni watches the pattern, not single days."
        case .fiber:
            return "no target here. steadier fiber usually reads as steadier appetite."
        case .sleep:
            return "short nights soften the next day's plan — the gentle tone is automatic."
        case .weight:
            return "the plan paces 0.5-1% a week (acsm) and reads the trend, not the day."
        case .steps:
            return "steps count toward the day on their own — no logging."
        case .medication:
            // The tile carries its own planLine (the pattern
            // engine's second observation) — nothing generic here.
            return nil
        case .movement, .waist, .bodyFat:
            return nil
        }
    }
}

// MARK: - BecomingTileView (the face)

struct BecomingTileView: View {
    let tile: BecomingTile
    var isExpanded: Bool = false
    /// v14 choreography: the grid's charts arrive in reading order,
    /// never as a chorus (delay = position × 0.12s).
    var chartDelay: Double = 0
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            JeniSurface(radius: Radius.row, padding: 13) {
                VStack(alignment: .leading, spacing: 5) {
                    // v13: the per-tile chevron died — eight tiny
                    // arrows said "tap me" eight times; the tile
                    // itself is the affordance (the Fitness grammar).
                    Text(tile.title)
                        .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                        .kerning(0.7)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // v21 — the value is the tile's HERO: one register
                    // up, numbers first. A status ("not connected")
                    // stays DM Sans (§2 role law).
                    Text(tile.faceValue)
                        .font(tile.meetsFloor
                            ? .custom("JeniHeroSerif-Regular", size: 20, relativeTo: .title3)
                            : .custom("DMSans-Regular", size: 13, relativeTo: .footnote))
                        .foregroundStyle(
                            tile.meetsFloor ? Palette.textPrimary : Palette.cocoaTertiary
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        // A scope change re-counts the value in place —
                        // the dashboard morphs, it never reloads (§4.5).
                        .contentTransition(.numericText())
                        .animation(JeniMotion.morph, value: tile.value)
                    if tile.meetsFloor, !tile.chart.isEmpty {
                        // v12 — the face carries a REAL mini chart
                        // (R2's move); v21 — a step taller, and rose
                        // by the engine's own law.
                        JeniChart(
                            model: tile.chart,
                            height: 26,
                            emphasizeLast: tile.chart.form == .bars,
                            delay: chartDelay
                        )
                        .allowsHitTesting(false)
                    } else if let caption = tile.faceCaption {
                        // A chartless face carries its one whisper
                        // where the spark would sit.
                        Text(caption)
                            .font(Typo.statLabel)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .frame(height: 26, alignment: .bottomLeading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    } else {
                        // Below the floor the face stays honest air.
                        Color.clear.frame(height: 26)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniPressable())
        .opacity(isExpanded ? 0 : 1)
        .accessibilityLabel("\(tile.title), \(tile.value). opens the page")
    }
}

// MARK: - BecomingMetricRow (v18.3 — the dense half of the grid)
//
// A metric that doesn't lead still deserves its number and its
// shape. A row carries both at ~46pt where a tile costs ~104 — so
// the surface can show everything without a third column.

struct BecomingMetricRow: View {
    let tile: BecomingTile
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Space.md) {
                Text(tile.title)
                    .font(.custom("DMSans-Medium", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: Space.sm)
                if tile.meetsFloor, !tile.chart.isEmpty {
                    JeniChart(model: tile.chart, height: 20,
                              emphasizeLast: tile.chart.form == .bars)
                        .frame(width: 64)
                        .allowsHitTesting(false)
                }
                Text(tile.faceValue)
                    .font(.custom("JeniHeroSerif-Regular", size: 16, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(
                        tile.meetsFloor ? Palette.textPrimary : Palette.cocoaTertiary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minWidth: 84, alignment: .trailing)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("\(tile.title), \(tile.faceValue). opens the page")
    }
}
