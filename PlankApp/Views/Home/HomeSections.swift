import SwiftUI
import PlankFood

// MARK: - HomeNutritionSummary (v12 — the centerpiece)
//
// docs/app_v12/00_CRAFT.md §2.2: the three-second read. The kcal
// numeral leads with its remaining clause; the ring gives the
// fraction at a glance (R2's number-left / visual-right); the macro
// tri-column carries landing bars (protein alone owns a floor — D2);
// fiber · sugar intake · sodium whisper beneath (sodium summed from
// the day's plates — D3). A landed plate MORPHS the numeral and the
// ring forward — addition, never a reset.
//
// The safety gate (targets.numericsSuppressed) still drops every
// numeral for words. Over-window is "window met" — never red, never
// minus (law §11.4).

struct HomeNutritionSummary: View {
    let snapshot: TodaySnapshot
    /// v18 — the week behind each nutrient is read from the same
    /// store the day's numbers come from.
    var userId: String = ""
    let onOpenFood: () -> Void

    // v15 THE TASTE PASS — elevation means ACTIONABILITY. The day's
    // numbers are a READING, not a control: they leave the card and
    // stand on the paper, the way Becoming's body read does. What
    // survives in a surface on Home is what she touches — the ask and
    // the tools. One card in the top half, and the eye knows where to
    // look. (Tapping still opens food; that's a convenience, not the
    // block's reason to exist.)
    // v17 — the FOOD section header died. A section header costs 50pt
    // (28 air + 14 type + 8) and this band already names itself: a
    // calorie figure with "of 1,473 kcal" beside it needs no label,
    // exactly as the reference's card carries "Calories" INSIDE it.
    // Three headers were costing 150pt — a fifth of the screen — to
    // say what the content says.
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpenFood) {
                Group {
                    if snapshot.targets.numericsSuppressed {
                        gateFace
                    } else {
                        numericFace
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .accessibilityLabel(a11ySummary)
            .accessibilityHint("opens food")
        }
    }

    // MARK: the safety-gate face (words, never numerals)

    private var gateFace: some View {
        VStack(alignment: .leading, spacing: 4) {
            JeniHeadline(platesLine.text, italic: platesLine.italic)
            Text("gentle plates, protein first · numbers off")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    // MARK: the numeric face

    /// v16 THE CONTROL CENTER — the whole plate in one band.
    ///
    /// The references' density mechanism isn't more cards, it's SHORT
    /// blocks: a lead figure at ~44pt (not 64), its context inline on
    /// the same baseline rather than stacked beneath, one full-width
    /// measure, then every remaining nutrient on a uniform grid. Seven
    /// numbers, ~190pt, no scrolling and nothing hidden behind a tap.
    private var numericFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The label rides INSIDE the band (the reference's move),
            // so the block is self-naming without a section header.
            Text("TODAY'S FOOD")
                .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                .kerning(1.2)
                .foregroundStyle(Palette.cocoaTertiary)

            HStack(alignment: .center, spacing: Space.md) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    JeniCountingNumeral(
                        value: Double(snapshot.kcalEaten),
                        font: Typo.numeralDash
                    )
                    Text(kcalMetaLine)
                        .font(Typo.numeralMeta)
                        .foregroundStyle(Palette.textSecondary)
                        // "373 left" counts down as the numeral counts
                        // up — one connected motion, never a swap.
                        .contentTransition(.numericText(countsDown: true))
                        .animation(JeniMotion.morph, value: kcalMetaLine)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: Space.sm)
                if let kcal = snapshot.targets.kcal, kcal > 0 {
                    JeniRing(
                        fraction: Double(snapshot.kcalEaten) / Double(kcal),
                        size: 40, lineWidth: 4
                    )
                }
            }
            .padding(.top, 2)

            // One full-width measure under the lead figure — the
            // day's window at a glance, the reference's move.
            if let kcal = snapshot.targets.kcal, kcal > 0 {
                windowBar(fraction: Double(snapshot.kcalEaten) / Double(kcal))
                    .padding(.top, 10)
            }

            nutrientGrid
                .padding(.top, Space.bandRow)
        }
    }

    private func windowBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairlineCocoa).frame(height: 3)
                Capsule()
                    .fill(Palette.textPrimary)
                    .frame(width: max(3, geo.size.width * min(1, max(0, fraction))),
                           height: 3)
                    .animation(JeniMotion.morph, value: fraction)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    /// v18 — the week behind each nutrient, from the same store the
    /// numbers come from. A metric without a target still gets a
    /// SHAPE (its seven days, today emphasized) so the band can be
    /// understood while squinting.
    private func spark(for nutrient: NutrientWeekAggregator.Nutrient) -> [Double?] {
        guard !userId.isEmpty else { return [] }
        return NutrientWeekAggregator.week(
            for: nutrient,
            entries: FoodLogPersister.allEntries(userId: userId),
            endingOn: .now,
            calendar: Calendar.current
        ).values
    }

    /// Six cells on one grid: the macro that owns a floor carries a
    /// bar; every other cell carries its week. Uniform cells are what
    /// make a dense block scannable — the eye learns the shape once.
    private var nutrientGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .topLeading),
                      GridItem(.flexible(), alignment: .topLeading),
                      GridItem(.flexible(), alignment: .topLeading)],
            spacing: 10
        ) {
            if let target = snapshot.targets.proteinG, target > 0 {
                JeniMetricBar(label: "protein",
                              value: "\(snapshot.proteinEatenG) / \(target) g",
                              fraction: Double(snapshot.proteinEatenG) / Double(target),
                              index: 0)
            } else {
                JeniMetricBar(label: "protein",
                              value: "\(snapshot.proteinEatenG) g", index: 0)
            }
            JeniMetricBar(label: "carbs", value: "\(snapshot.carbsEatenG) g",
                          spark: carbsSpark, index: 1)
            JeniMetricBar(label: "fat", value: "\(snapshot.fatEatenG) g",
                          spark: fatSpark, index: 2)
            ForEach(Array(plateChemistry.enumerated()), id: \.element.0) { i, pair in
                JeniMetricBar(label: pair.0, value: pair.1,
                              spark: chemistrySpark(pair.0), index: 3 + i)
            }
        }
    }

    // Carbs and fat have no collected target (D2 — a bar there would
    // invent one), so their identity is the week's shape.
    private var carbsSpark: [Double?] { weekOf(\.carbs) }
    private var fatSpark: [Double?] { weekOf(\.fat) }

    private func chemistrySpark(_ label: String) -> [Double?] {
        switch label {
        case "fiber": return spark(for: .fiber)
        case "sugar": return spark(for: .sugar)
        case "sodium": return spark(for: .sodium)
        default: return []
        }
    }

    /// Carbs/fat aren't in the aggregator's nutrient set, so their
    /// week is summed here from the same entries, with the same
    /// honesty: a day with no plates is nil, never zero.
    private func weekOf(_ key: KeyPath<FoodLogPersister.FoodLogEntry, Double>) -> [Double?] {
        guard !userId.isEmpty else { return [] }
        let cal = Calendar.current
        let end = cal.startOfDay(for: .now)
        let entries = FoodLogPersister.allEntries(userId: userId)
        var sums: [Date: Double] = [:]
        var logged: Set<Date> = []
        for e in entries {
            let day = cal.startOfDay(for: e.loggedAt)
            guard let back = cal.date(byAdding: .day, value: -6, to: end),
                  day >= back, day <= end else { continue }
            logged.insert(day)
            sums[day, default: 0] += e[keyPath: key]
        }
        return (0..<7).map { i in
            guard let day = cal.date(byAdding: .day, value: i - 6, to: end),
                  logged.contains(day) else { return nil }
            return sums[day]
        }
    }

    /// "of 1,473 kcal · 613 left" — the lead's second clause carries
    /// what to do with the number (R3's move).
    private var kcalMetaLine: String {
        guard let kcal = snapshot.targets.kcal else { return "kcal today" }
        let target = kcal.formatted()
        let left = kcal - snapshot.kcalEaten
        if left > 0 { return "of \(target) kcal · \(left.formatted()) left" }
        return "of \(target) kcal · window met"
    }

    /// The rest of the plate, whispered. Only what the day actually
    /// collected renders — a zero that was never measured is not a
    /// zero (law §1.6).
    private var plateChemistry: [(String, String)] {
        var pairs: [(String, String)] = []
        if snapshot.fiberEatenG > 0 {
            pairs.append(("fiber", "\(snapshot.fiberEatenG) g"))
        }
        if snapshot.sugarEatenG > 0 {
            pairs.append(("sugar", "\(snapshot.sugarEatenG) g"))
        }
        let sodium = Int(snapshot.plates.reduce(0) { $0 + $1.sodiumMg }.rounded())
        if sodium > 0 {
            pairs.append(("sodium", "\(sodium.formatted()) mg"))
        }
        return pairs
    }

    private var platesLine: (text: String, italic: [String]) {
        let n = snapshot.plates.count
        if n == 0 { return ("no plates yet today.", []) }
        if n == 1 { return ("one plate, counted.", ["counted."]) }
        return ("\(n) plates, counted.", ["counted."])
    }

    private var a11ySummary: String {
        if snapshot.targets.numericsSuppressed {
            return "\(platesLine.text) gentle plates, protein first"
        }
        var parts = ["\(snapshot.kcalEaten) calories today"]
        if let kcal = snapshot.targets.kcal {
            let left = kcal - snapshot.kcalEaten
            parts.append(left > 0 ? "\(left) left" : "window met")
        }
        if let target = snapshot.targets.proteinG {
            parts.append("protein \(snapshot.proteinEatenG) of \(target) grams")
        } else {
            parts.append("protein \(snapshot.proteinEatenG) grams")
        }
        for pair in plateChemistry {
            parts.append("\(pair.0) \(pair.1)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - HomeDayRecap (v11.5 — the strip's answer for other days)
//
// Selecting a past day re-keys the page to that day's RECORD: what
// landed, in that day's own numbers. Never a report card — quiet
// memory (L10). Future days decline politely.

struct HomeDayRecap: View {
    let date: Date
    let userId: String
    let onOpenRecord: () -> Void
    let onBackToToday: () -> Void

    private var cal: Calendar { Calendar.current }
    private var isFuture: Bool { date > cal.startOfDay(for: .now) }

    private struct DayTotals {
        var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
        var plates = 0
    }

    private var totals: DayTotals {
        var t = DayTotals()
        for entry in FoodLogPersister.allEntries(userId: userId)
        where cal.isDate(entry.loggedAt, inSameDayAs: date) {
            t.kcal += entry.kcal
            t.protein += entry.protein
            t.carbs += entry.carbs
            t.fat += entry.fat
            t.plates += 1
        }
        return t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                JeniSectionHeader(dayLabel)
                Spacer(minLength: Space.md)
                Button(action: onBackToToday) {
                    Text("today")
                        .font(.custom("DMSans-SemiBold", size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.textPrimary))
                }
                .buttonStyle(JeniPressable())
                .accessibilityLabel("back to today")
            }

            if isFuture {
                JeniSurface {
                    JeniHeadline("still ahead.")
                }
            } else if totals.plates == 0 {
                JeniSurface {
                    JeniHeadline("nothing logged this day.")
                }
            } else {
                JeniSurface {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(Int(totals.kcal.rounded()).formatted())")
                                .font(Typo.numeralHero)
                                .foregroundStyle(Palette.textPrimary)
                            Text("kcal that day")
                                .font(Typo.numeralMeta)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                            recapPair("plates", "\(totals.plates)")
                            recapPair("protein", "\(Int(totals.protein.rounded())) g")
                            recapPair("carbs", "\(Int(totals.carbs.rounded())) g")
                            recapPair("fat", "\(Int(totals.fat.rounded())) g")
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            Button(action: onOpenRecord) {
                HStack(spacing: 6) {
                    Text("the full record is in becoming")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.md)
        }
    }

    private var dayLabel: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day()).lowercased()
    }

    private func recapPair(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(Typo.statLabel)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(value)
                .font(.custom("DMSans-Medium", size: 13, relativeTo: .caption))
                .foregroundStyle(Palette.textPrimary.opacity(0.85))
        }
    }
}
