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
             movement, waist, bodyFat
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
        tiles.append(weightTile(userId: userId, snapshot: snapshot,
                                scope: scope, in: context))
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
        tiles.append(waistTile(scans: scans, snapshot: snapshot))
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
        let mechanism = "the window, kept gently, is the whole plan."
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
                    ? "the first plate opens today's read."
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
                read: "your waist speaks in check-ins. two comparable ones and this page reads.",
                readItalic: ["reads."],
                mechanism: "the camera never guesses a number. it reads the band's shape.",
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
            mechanism: read.notes.first ?? "week to week, the shape is the honest read.",
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
            value: read.value,
            meetsFloor: true,
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
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId && $0.loggedAt >= start },
            sortBy: [SortDescriptor(\.loggedAt)]
        )
        let logs = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.source != "onboarding" }

        let unit = WeightUnit(
            rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
        ) ?? .lb

        // The window scopes to the RECORD, not to a fixed 28 days: a
        // chart whose left half is empty reads as a rendering bug and
        // its "4 weeks ago" label lies. Start at her first weigh-in
        // (keeping at least a week of context), end today.
        var byDay: [Date: Double] = [:]
        for log in logs {
            byDay[cal.startOfDay(for: log.loggedAt)] = log.weightKg
        }
        let today = cal.startOfDay(for: .now)
        let weekBack = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let firstLogged = byDay.keys.min() ?? start
        let windowStart = min(max(start, firstLogged), weekBack)
        let span = max(1, (cal.dateComponents([.day], from: windowStart, to: today).day ?? 27))

        let raw: [Double?] = (0...span).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: windowStart)
            else { return nil }
            return byDay[cal.startOfDay(for: day)].map { unit.display(fromKg: $0) }
        }

        // The 7-day EMA context line (WeightTrendChart's math, ported
        // before that file died with the journal).
        let alpha = 2.0 / 8.0
        var ema: [Double?] = []
        var prev: Double?
        for value in raw {
            if let value {
                let next = prev.map { alpha * value + (1 - alpha) * $0 } ?? value
                ema.append(next)
                prev = next
            } else {
                ema.append(prev)   // the trend holds between weigh-ins
            }
        }

        let established = snapshot.trendIsEstablished
        let latest = snapshot.latestWeightKg.map {
            String(format: "%.1f %@", unit.display(fromKg: $0), unit.label)
        }

        let read: (String, [String])
        if established, let delta = snapshot.emaDelta7dKg {
            let word = String(format: "%.1f %@",
                              abs(unit.display(fromKg: delta)), unit.label)
            read = delta < -0.05
                ? ("down about \(word) this week.", ["down"])
                : delta > 0.05
                    ? ("up about \(word) this week. weeks like this happen.", ["happen."])
                    : ("holding steady this week.", ["steady"])
        } else {
            read = ("your trend needs a few more weigh-ins.", ["trend"])
        }

        // The detail ledger (C6): the week beside the whole record.
        var pairs: [BecomingTile.SummaryPair] = []
        if established, let delta = snapshot.emaDelta7dKg {
            let word = String(format: "%.1f %@",
                              abs(unit.display(fromKg: delta)), unit.label)
            let direction = delta < -0.05 ? "down about"
                : delta > 0.05 ? "up about" : "steady, within"
            pairs.append(.init(label: "this week", value: "\(direction) \(word)"))
        }
        let reals = raw.compactMap { $0 }
        if reals.count >= 2, let firstW = reals.first, let nowW = reals.last {
            pairs.append(.init(
                label: "the record",
                value: String(format: "from %.1f to %.1f %@", firstW, nowW, unit.label)
            ))
        }
        if pairs.count < 2 { pairs = [] }

        return BecomingTile(
            kind: .weight,
            title: "weight",
            value: latest ?? "no weigh-ins yet",
            meetsFloor: established,
            chart: JeniChartModel(form: .line, series: [
                .init(values: raw, role: .ink),
                .init(values: ema, role: .context),
            ], yPaddingFraction: 0.45,   // generous headroom: a 2-3 lb
                                          // week must READ gentle, not
                                          // a cliff (the zoom lies)
               bridgeGaps: true),   // weigh-ins are sparse by nature
            read: read.0,
            readItalic: read.1,
            mechanism: "the trend is the signal. single days move around it.",
            provenance: "from your weigh-ins · \(spanWord(days: span))",
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
                    ? "the first plate opens today's read."
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
        guard MovementService.shared.everRequested else {
            return BecomingTile(
                kind: .movement, title: "movement",
                value: "not connected",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: "connect workouts in settings, under body vision.",
                readItalic: [],
                mechanism: "strength work tells the body to keep muscle.",
                provenance: "from apple health, when you allow it"
            )
        }
        let sessions = MovementService.shared.strengthSessionsLast7
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
            provenance: "from apple health · last 7 days",
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

        // 4 — check-ins landed (the body record building).
        let monthStart = cal.date(
            byAdding: .day, value: -29, to: cal.startOfDay(for: .now)
        ) ?? .now
        let recentScans = scans.filter { $0.capturedAt >= monthStart }.count
        if recentScans >= 1 {
            out.append(JeniInsight(
                id: "scans", eyebrow: "body record",
                value: Double(recentScans),
                word: "check-in\(recentScans == 1 ? "" : "s")",
                figure: .none,
                sentence: recentScans == 1
                    ? "one check-in this month. the record has begun."
                    : "\(recentScans) check-ins this month. the record is building.",
                sentenceItalic: recentScans == 1 ? ["begun."] : ["building."]
            ))
        }

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
            JeniSurface(radius: 16, padding: 12) {
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
                    // Serif is Jeni's VOICE — a value she can actually
                    // read. A status ("not connected") is the system
                    // labelling itself, so it takes DM Sans (§2 role
                    // law). Setting status lines in 20pt serif made
                    // empty tiles shout louder than real readings.
                    Text(tile.faceValue)
                        .font(tile.meetsFloor
                            ? .custom("JeniHeroSerif-Regular", size: 17, relativeTo: .headline)
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
                        // (R2's move): the week's bars with today in
                        // full ink, or the trend line small.
                        JeniChart(
                            model: tile.chart,
                            height: 22,
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
                            .frame(height: 22, alignment: .bottomLeading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    } else {
                        // Below the floor the face stays honest air.
                        Color.clear.frame(height: 22)
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

// MARK: - BecomingDetailPage (one template for every tile)

struct BecomingDetailPage: View {
    let tile: BecomingTile
    let onClose: () -> Void

    @State private var arrived = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(tile.title)
                        .font(Typo.questionHero)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Button("done") { onClose() }
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .accessibilityLabel("done. closes \(tile.title)")
                }
                .jeniArrive(arrived, index: 0)
                .padding(.top, Space.hero)

                VStack(alignment: .leading, spacing: 0) {
                    if tile.meetsFloor, !tile.chart.isEmpty {
                        JeniChart(
                            model: tile.chart,
                            height: 120,
                            endLabels: chartLabels,
                            scrubbable: true,
                            accessibilityText: tile.read
                        )
                    }
                }
                .jeniArrive(arrived, index: 1)
                .padding(.top, Space.sectionGap)

                VStack(alignment: .leading, spacing: Space.blockGap) {
                    JeniHeadline(tile.read, italic: tile.readItalic)
                    if let mechanism = tile.mechanism {
                        Text(mechanism)
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(tile.provenance)
                        .font(Typo.statLabel)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .jeniArrive(arrived, index: 2)
                .padding(.top, Space.sectionGap)

                Spacer(minLength: Space.heroGap)
            }
            .padding(.horizontal, Space.gutter)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .environment(\.jeniArrived, arrived)
        .task {
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
            arrived = true
        }
    }

    private var chartLabels: (String, String)? {
        switch tile.kind {
        case .weight: return ("4 weeks ago", "today")
        case .movement: return nil
        default: return ("a week ago", "today")
        }
    }
}
