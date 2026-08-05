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
    /// v11.5 — the FACE's measure, 0…1. Tile faces draw a ribbed
    /// ribbon instead of a live chart: eleven charts on arrival was
    /// the lag and the scatter the founder named. nil = no measure
    /// (the face stays words).
    var faceFraction: Double? = nil

    var id: String { kind.rawValue }
}

// MARK: - The builder

enum BecomingTileBuilder {

    static func build(
        userId: String,
        snapshot: TodaySnapshot,
        sleepRecaps: [SleepService.NightRecap],
        scans: [BodyScanRecord] = [],
        in context: ModelContext
    ) -> [BecomingTile] {
        let cal = Calendar.current
        let weekStart = cal.date(
            byAdding: .day, value: -6, to: cal.startOfDay(for: .now)
        ) ?? .now
        let entries = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= weekStart }

        var tiles: [BecomingTile] = []
        tiles.append(weightTile(userId: userId, snapshot: snapshot, in: context))
        tiles.append(caloriesTile(snapshot: snapshot, entries: entries, cal: cal))
        tiles.append(nutrientTile(.protein, title: "protein", unit: "g",
                                  target: snapshot.targets.proteinG,
                                  entries: entries,
                                  mechanism: "protein protects muscle while you lose.",
                                  cal: cal))
        tiles.append(nutrientTile(.fiber, title: "fiber", unit: "g",
                                  target: nil, entries: entries,
                                  mechanism: "fiber steadies appetite between plates.",
                                  cal: cal))
        // Voice law: "sugar intake", never "sweetness".
        tiles.append(nutrientTile(.sugar, title: "sugar intake", unit: "g",
                                  target: nil, entries: entries,
                                  mechanism: "sugar late in the day feeds the next craving.",
                                  cal: cal))
        tiles.append(nutrientTile(.sodium, title: "sodium", unit: "mg",
                                  target: nil, entries: entries,
                                  mechanism: "sodium holds water. the scale follows for a day or two.",
                                  cal: cal))
        tiles.append(sleepTile(sleepRecaps))
        tiles.append(stepsTile())
        tiles.append(movementTile())
        tiles.append(waistTile(scans: scans, snapshot: snapshot))
        tiles.append(bodyFatTile(userId: userId, in: context))
        return tiles
    }

    // MARK: calories

    private static func caloriesTile(
        snapshot: TodaySnapshot,
        entries: [FoodLogPersister.FoodLogEntry],
        cal: Calendar
    ) -> BecomingTile {
        let series = NutrientWeekAggregator.week(
            for: .calories, entries: entries, endingOn: .now, calendar: cal
        )
        guard series.meetsFloor else {
            return BecomingTile(
                kind: .calories, title: "calories",
                value: "logging · \(series.loggedCount) of 3 days",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: "a few more logged days and this page can speak.",
                readItalic: ["speak."],
                mechanism: "the window, kept gently, is the whole plan.",
                provenance: "from your plates · last 7 days"
            )
        }
        let avg = Int((series.collectedTotal / Double(max(1, series.loggedCount))).rounded())
        let window = snapshot.targets.numericsSuppressed ? nil : snapshot.targets.kcal
        let read: (String, [String])
        if let window {
            read = avg <= window
                ? ("about \(avg.formatted()) a day, inside your \(window.formatted()) window.", ["inside"])
                : ("about \(avg.formatted()) a day, over the window. fuller weeks happen.", ["happen."])
        } else {
            read = ("about \(avg.formatted()) a day this week.", [])
        }
        // Against her window when she has one, else the week's peak.
        let today = series.days.last?.value
        let peak = series.days.compactMap(\.value).max() ?? 0
        let denominator = Double(window ?? 0) > 0 ? Double(window!) : peak
        return BecomingTile(
            kind: .calories, title: "calories",
            value: today.map { "\(Int($0.rounded()).formatted()) today" }
                ?? "about \(avg.formatted()) a day",
            meetsFloor: true,
            chart: JeniChartModel(form: .bars, series: [
                .init(values: series.values, role: .ink)
            ]),
            read: read.0, readItalic: read.1,
            mechanism: "the window, kept gently, is the whole plan.",
            provenance: "from your plates · last 7 days",
            faceFraction: denominator > 0 ? (today ?? Double(avg)) / denominator : nil
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
                value: scans.count < 2 ? "two check-ins to speak" : "the plates read close",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: "your waist speaks in check-ins. two comparable ones and this page reads.",
                readItalic: ["reads."],
                mechanism: "the camera never guesses a number. it reads the band's shape (never your worth).",
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
            faceCaption: read.isMeasured ? "measured" : "estimated · never from a photo"
        )
    }

    // MARK: weight

    private static func weightTile(
        userId: String, snapshot: TodaySnapshot, in context: ModelContext
    ) -> BecomingTile {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -27,
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
            mechanism: "the trend line is the truth. single days are weather.",
            provenance: "from your weigh-ins · \(spanWord(days: span))",
            spanLabel: spanWord(days: span),
            // The ribbon reads her position between the window's
            // lightest and heaviest readings — movement, not a target.
            faceFraction: {
                let real = raw.compactMap { $0 }
                guard let lo = real.min(), let hi = real.max(), hi > lo,
                      let now = real.last else { return nil }
                return (now - lo) / (hi - lo)
            }()
        )
    }

    /// "11 days" / "3 weeks" — the axis never claims more record
    /// than exists.
    private static func spanWord(days: Int) -> String {
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
        mechanism: String, cal: Calendar
    ) -> BecomingTile {
        let series = NutrientWeekAggregator.week(
            for: nutrient, entries: entries, endingOn: .now, calendar: cal
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

        guard series.meetsFloor else {
            return BecomingTile(
                kind: kind, title: title,
                value: "logging · \(series.loggedCount) of 3 days",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: "a few more logged days and this page can speak.",
                readItalic: ["speak."],
                mechanism: mechanism,
                provenance: "from your plates · last 7 days"
            )
        }

        let todayValue = series.days.last?.value
        let avg = series.collectedTotal / Double(max(1, series.loggedCount))
        let value: String = {
            if let todayValue { return "\(Int(todayValue.rounded())) \(unit) today" }
            return "about \(Int(avg.rounded())) \(unit) a day"
        }()

        let read: (String, [String])
        switch nutrient {
        case .protein:
            if let target {
                let met = series.days.compactMap(\.value)
                    .filter { $0 >= Double(target) }.count
                read = ("protein reached \(target)g on \(met) of \(series.loggedCount) logged days.", ["\(met)"])
            } else {
                read = ("about \(Int(avg.rounded()))g a day this week.", [])
            }
        case .sodium:
            let high = series.days.compactMap(\.value).filter { $0 > 2300 }.count
            read = high > 0
                ? ("sodium ran high on \(high) day\(high == 1 ? "" : "s") this week.", ["high"])
                : ("sodium stayed steady this week.", ["steady"])
        case .sugar:
            read = ("about \(Int(avg.rounded()))g of sugar a day this week.", [])
        case .fiber:
            read = ("about \(Int(avg.rounded()))g of fiber a day this week.", [])
        case .calories, .saturatedFat:
            read = ("", [])   // calories has its own builder
        }

        // The face's measure: today against the week's strongest day,
        // so the ribbon answers "where does today sit?" at a glance.
        let peak = series.days.compactMap(\.value).max() ?? 0
        let faceFraction = peak > 0
            ? (todayValue ?? avg) / peak
            : nil

        return BecomingTile(
            kind: kind, title: title, value: value,
            meetsFloor: true,
            chart: JeniChartModel(form: .bars, series: [
                .init(values: series.values, role: .ink)
            ]),
            read: read.0, readItalic: read.1,
            mechanism: mechanism,
            provenance: "from your plates · last 7 days",
            faceFraction: faceFraction
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
                read: "a few more nights and this page can speak.",
                readItalic: ["speak."],
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
            // Against 8 hours — the rest most bodies want.
            faceFraction: min(1, avg / 8.0)
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
                read: "a few more days of motion and this page can speak.",
                readItalic: ["speak."],
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
            faceFraction: min(1, Double(avg) / Double(max(1, StepsService.dailyGoal)))
        )
    }

    private static func movementTile() -> BecomingTile {
        guard MovementService.shared.everRequested else {
            return BecomingTile(
                kind: .movement, title: "movement",
                value: "not connected",
                meetsFloor: false,
                chart: JeniChartModel(form: .bars, series: []),
                read: "connect your workouts and this page can speak. the door is in settings, under body vision.",
                readItalic: ["speak."],
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
            provenance: "from apple health · last 7 days"
        )
    }
}

// MARK: - BecomingTileView (the face)

struct BecomingTileView: View {
    let tile: BecomingTile
    var namespace: Namespace.ID
    var isExpanded: Bool = false
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            JeniCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(tile.title)
                            .font(Typo.statLabel)
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Palette.cocoaTertiary.opacity(0.7))
                    }
                    Text(tile.value)
                        .font(.custom(
                            "JeniHeroSerif-Regular",
                            size: tile.compact ? 16 : 20,
                            relativeTo: tile.compact ? .subheadline : .title3
                        ))
                        .foregroundStyle(
                            tile.meetsFloor ? Palette.textPrimary : Palette.cocoaTertiary
                        )
                        .lineLimit(tile.compact ? 3 : 2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    if tile.meetsFloor, let fraction = tile.faceFraction {
                        // The ribbed measure (v11.5): one light Canvas
                        // per tile, not a chart engine each.
                        JeniRibbon(progress: fraction, height: 26)
                            .allowsHitTesting(false)
                    } else if let caption = tile.faceCaption {
                        // A chartless face carries its one whisper
                        // where the spark would sit.
                        Text(caption)
                            .font(Typo.statLabel)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .frame(height: 30, alignment: .bottomLeading)
                    } else {
                        // Below the floor the face stays honest air.
                        Color.clear.frame(height: 30)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniPressable())
        .matchedGeometryEffect(id: "card.\(tile.id)", in: namespace, isSource: !isExpanded)
        .opacity(isExpanded ? 0 : 1)
        .accessibilityLabel("\(tile.title), \(tile.value). opens the page")
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
