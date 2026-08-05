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
        case weight, protein, fiber, sugar, sodium, sleep, steps, movement
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

    var id: String { kind.rawValue }
}

// MARK: - The builder

enum BecomingTileBuilder {

    static func build(
        userId: String,
        snapshot: TodaySnapshot,
        sleepRecaps: [SleepService.NightRecap],
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
        return tiles
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

        // 28 daily slots; a weigh-in day carries its last reading.
        var byDay: [Date: Double] = [:]
        for log in logs {
            byDay[cal.startOfDay(for: log.loggedAt)] = log.weightKg
        }
        let raw: [Double?] = (0..<28).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: start)
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
            provenance: "from your weigh-ins · 4 weeks"
        )
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
        case .saturatedFat:
            read = ("", [])
        }

        return BecomingTile(
            kind: kind, title: title, value: value,
            meetsFloor: true,
            chart: JeniChartModel(form: .bars, series: [
                .init(values: series.values, role: .ink)
            ]),
            read: read.0, readItalic: read.1,
            mechanism: mechanism,
            provenance: "from your plates · last 7 days"
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
            provenance: "from your phone's sleep record · last 7 nights"
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
            provenance: "from your phone · last 7 days"
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
                        .font(.custom("JeniHeroSerif-Regular", size: 20, relativeTo: .title3))
                        .foregroundStyle(
                            tile.meetsFloor ? Palette.textPrimary : Palette.cocoaTertiary
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    if tile.meetsFloor, !tile.chart.isEmpty {
                        JeniChart(model: sparkModel, height: 30)
                            .allowsHitTesting(false)
                    } else {
                        // Below the floor the face stays honest air.
                        Color.clear.frame(height: 30)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("\(tile.title), \(tile.value). opens the page")
    }

    /// The tile face draws the spark form of its chart.
    private var sparkModel: JeniChartModel {
        if tile.chart.form == .line {
            // Ink only at spark scale — a 1pt context line aliases
            // into stray dots inside a 30pt canvas.
            return JeniChartModel(
                form: .spark,
                series: tile.chart.series.filter { $0.role == .ink },
                bridgeGaps: tile.chart.bridgeGaps
            )
        }
        return tile.chart
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
