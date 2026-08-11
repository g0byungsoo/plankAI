import SwiftUI
import SwiftData
import PlankFood
import PlankSync

// MARK: - HomeNutritionSummary (v21 — THE HERO CAROUSEL)
//
// docs/app_v21/00_INSTRUMENT.md §6.2: the nutrition dashboard is the
// page's visual hero — a paged, morphing carousel of instrument
// faces, one insight per page, on the paper (no card: the hero
// breathes; v15's one-card-in-the-top-half virtue holds).
//
//   1 calories — the demo's ring at demo scale, the counted numeral
//     INSIDE it, remaining beneath (the 2-second answer)
//   2 protein  — the one macro with a collected floor: numeral, bar,
//     its week
//   3 the plate — what the day was made of (the split, with grams)
//   4 chemistry — fiber · sugar intake · sodium, each with its week
//   5 the week — seven rounded bars, today berry (the demo's card)
//
// Pages render only what a store produced (§1.6): no plates → the
// later pages wait, absent rather than zeroed. The safety gate
// (targets.numericsSuppressed) collapses the whole carousel to the
// words-only face — no numerals anywhere.
//
// Mechanics: native paging, off-center pages settle at 0.94 / 0.85
// (the morph the founder asked for), a tick per page detent, the
// rose page dots. Every shape arms on first centering (the
// visibility gate rides the pieces themselves).

struct HomeNutritionSummary: View {
    let snapshot: TodaySnapshot
    var userId: String = ""
    let onOpenFood: () -> Void

    private enum Page: String, CaseIterable, Identifiable {
        case calories, protein, plate, chemistry, week
        var id: String { rawValue }
    }

    @State private var page: Page? = .calories
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// One design height for every page so the pager never reflows
    /// the list beneath it; scales with the reader's type (§10.2).
    @ScaledMetric(relativeTo: .body) private var faceHeight: CGFloat = 208

    /// v21 film door — the carousel walks its own pages for THE LOOP
    /// (synthesized drags cannot scroll this sim runtime).
    private var tourAutoAdvance: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--uitest-walk-carousel")
        #else
        return false
        #endif
    }

    var body: some View {
        // v21 (film-caught): the outer "TODAY'S FOOD" label doubled
        // every face's own name — each face is self-naming now (v17's
        // header law), and the calories page carries its own label.
        VStack(alignment: .leading, spacing: 0) {
            if snapshot.targets.numericsSuppressed {
                Button(action: onOpenFood) {
                    gateFace
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
                .accessibilityLabel(a11ySummary)
                .accessibilityHint("opens food")
                .padding(.top, Space.sm)
            } else {
                carousel
                    .padding(.top, Space.sm)
                if pages.count > 1 {
                    JeniPageDots(
                        count: pages.count,
                        current: pages.firstIndex(of: page ?? .calories) ?? 0
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
            }
        }
    }

    // MARK: the pages that have something to say

    private var pages: [Page] {
        var result: [Page] = [.calories]
        if snapshot.targets.proteinG != nil || snapshot.proteinEatenG > 0 {
            result.append(.protein)
        }
        if snapshot.kcalEaten > 0 { result.append(.plate) }
        if !plateChemistry.isEmpty { result.append(.chemistry) }
        if weekKcal.compactMap({ $0 }).count >= 2 { result.append(.week) }
        return result
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(pages) { p in
                    face(for: p)
                        .frame(height: faceHeight, alignment: .top)
                        .containerRelativeFrame(.horizontal)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(
                                    reduceMotion || phase.isIdentity ? 1 : 0.94
                                )
                                .opacity(
                                    reduceMotion || phase.isIdentity ? 1 : 0.75
                                )
                        }
                        .id(p)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .frame(height: faceHeight)
        .onChange(of: page) { old, new in
            guard old != nil, new != nil, old != new else { return }
            JeniHaptic.tick()
        }
        .task {
            guard tourAutoAdvance, pages.count > 1 else { return }
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            for p in pages.dropFirst() {
                guard !Task.isCancelled else { return }
                withAnimation(JeniMotion.morph) { page = p }
                try? await Task.sleep(nanoseconds: 2_600_000_000)
            }
            withAnimation(JeniMotion.morph) { page = pages.first }
        }
    }

    @ViewBuilder
    private func face(for p: Page) -> some View {
        switch p {
        case .calories: caloriesFace
        case .protein: proteinFace
        case .plate: plateFace
        case .chemistry: chemistryFace
        case .week: weekFace
        }
    }

    // MARK: page 1 — calories (the ring)

    private var caloriesFace: some View {
        Button(action: onOpenFood) {
            VStack(alignment: .leading, spacing: 0) {
                faceLabel("calories")
                if typeSize.isAccessibilitySize {
                    // A fixed 176pt ring cannot hold accessibility
                    // type (§10.2 — the numeral block struck through
                    // the arc at XXXL, frame-caught). The fraction
                    // keeps a shape — the window bar — and the words
                    // keep their size.
                    VStack(alignment: .leading, spacing: 6) {
                        JeniCountingNumeral(
                            value: Double(snapshot.kcalEaten),
                            font: .custom("JeniHeroSerif-Regular", size: 40,
                                          relativeTo: .largeTitle)
                        )
                        if let kcal = snapshot.targets.kcal, kcal > 0 {
                            Text("of \(kcal.formatted()) kcal · \(remainingLine(target: kcal))")
                                .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                                .foregroundStyle(Palette.textSecondary)
                            accessibilityFractionBar
                        } else {
                            Text("kcal today")
                                .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 10)
                } else {
                    ZStack {
                        JeniRing(
                            fraction: ringFraction,
                            size: 176,
                            lineWidth: 13
                        )
                        VStack(spacing: 3) {
                            JeniCountingNumeral(
                                value: Double(snapshot.kcalEaten),
                                font: .custom("JeniHeroSerif-Regular", size: 40,
                                              relativeTo: .largeTitle)
                            )
                            if let kcal = snapshot.targets.kcal, kcal > 0 {
                                Text("of \(kcal.formatted()) kcal")
                                    .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                                    .foregroundStyle(Palette.textSecondary)
                                Text(remainingLine(target: kcal))
                                    .font(.custom("DMSans-SemiBold", size: 11, relativeTo: .caption2))
                                    .foregroundStyle(Palette.textPrimary)
                                    .contentTransition(.numericText(countsDown: true))
                                    .animation(JeniMotion.morph, value: snapshot.kcalEaten)
                            } else {
                                Text("kcal today")
                                    .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                        // The ring's inner text may never outgrow the
                        // ring: sub-accessibility Dynamic Type still
                        // scales, so the block clamps to the ring's
                        // safe inner circle.
                        .frame(maxWidth: 128)
                        .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel(a11ySummary)
        .accessibilityHint("opens food")
    }

    /// The accessibility face's fraction — same store, simpler shape.
    private var accessibilityFractionBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.accent.opacity(0.16)).frame(height: 8)
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: max(8, geo.size.width * min(1, max(0, ringFraction))),
                           height: 8)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    private var ringFraction: Double {
        guard let kcal = snapshot.targets.kcal, kcal > 0 else { return 0 }
        return Double(snapshot.kcalEaten) / Double(kcal)
    }

    private func remainingLine(target: Int) -> String {
        let left = target - snapshot.kcalEaten
        return left > 0 ? "\(left.formatted()) left" : "window met"
    }

    // MARK: page 2 — protein (the floor)

    private var proteinFace: some View {
        // Film-caught: the face left its bottom half empty next to
        // the ring's full presence. The block now fills its stage —
        // numeral up a register, the floor bar at instrument weight,
        // the week given real height, air distributed between.
        VStack(alignment: .leading, spacing: 0) {
            faceLabel("protein")
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                JeniCountingNumeral(
                    value: Double(snapshot.proteinEatenG),
                    font: .custom("JeniHeroSerif-Regular", size: 46,
                                  relativeTo: .largeTitle)
                )
                Text(proteinMeta)
                    .font(Typo.numeralMeta)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, 10)

            if let target = snapshot.targets.proteinG, target > 0 {
                proteinBar(target: target)
                    .padding(.top, 14)
                Text(proteinWord(target: target))
                    .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 8)
            }

            Spacer(minLength: Space.sm)

            if weekProtein.compactMap({ $0 }).count >= 2 {
                Text("THE WEEK")
                    .font(.custom("DMSans-Regular", size: 9, relativeTo: .caption2))
                    .kerning(0.8)
                    .foregroundStyle(Palette.cocoaTertiary)
                JeniSparkRow(values: weekProtein)
                    .frame(width: 216, height: 30)
                    .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(proteinA11y))
    }

    private var proteinMeta: String {
        if let target = snapshot.targets.proteinG, target > 0 {
            return "of \(target) g"
        }
        return "g"
    }

    private func proteinBar(target: Int) -> some View {
        GeometryReader { geo in
            let fraction = min(1, max(0, Double(snapshot.proteinEatenG) / Double(target)))
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.accent.opacity(0.16)).frame(height: 7)
                Capsule()
                    .fill(fraction >= 1 ? Palette.roseBerry : Palette.accent)
                    .frame(width: max(7, geo.size.width * fraction), height: 7)
                    .animation(JeniMotion.morph, value: fraction)
            }
        }
        .frame(height: 7)
        .accessibilityHidden(true)
    }

    private func proteinWord(target: Int) -> String {
        let left = target - snapshot.proteinEatenG
        if left > 0 { return "\(left) g to the floor · protein first" }
        return "floor met · muscle kept fed"
    }

    private var proteinA11y: String {
        if let target = snapshot.targets.proteinG {
            return "protein \(snapshot.proteinEatenG) of \(target) grams"
        }
        return "protein \(snapshot.proteinEatenG) grams"
    }

    // MARK: page 3 — the plate (the split)

    private var plateFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            faceLabel("the plate")
            Text(platesCountLine)
                .font(.custom("JeniHeroSerif-Regular", size: 26, relativeTo: .title2))
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 8)

            JeniMacroSplitTall(
                proteinG: snapshot.proteinEatenG,
                carbsG: snapshot.carbsEatenG,
                fatG: snapshot.fatEatenG
            )
            .padding(.top, Space.md)

            HStack(alignment: .firstTextBaseline, spacing: Space.blockGap) {
                splitLegend("protein", grams: snapshot.proteinEatenG,
                            color: Palette.roseBerry)
                splitLegend("carbs", grams: snapshot.carbsEatenG,
                            color: Palette.accent)
                splitLegend("fat", grams: snapshot.fatEatenG,
                            color: Palette.roseBlush)
                Spacer(minLength: 0)
            }
            .padding(.top, Space.md)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "the plate: protein \(snapshot.proteinEatenG) grams, carbs \(snapshot.carbsEatenG) grams, fat \(snapshot.fatEatenG) grams"
        ))
    }

    private var platesCountLine: String {
        let n = snapshot.plates.count
        if n == 0 { return "nothing yet" }
        return n == 1 ? "one plate, counted" : "\(n) plates, counted"
    }

    private func splitLegend(_ label: String, grams: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 0) {
                Text(label.uppercased())
                    .font(.custom("DMSans-Regular", size: 9, relativeTo: .caption2))
                    .kerning(0.6)
                    .foregroundStyle(Palette.cocoaTertiary)
                Text("\(grams) g")
                    .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
            }
        }
    }

    // MARK: page 4 — chemistry

    private var chemistryFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            faceLabel("the chemistry")
            VStack(alignment: .leading, spacing: 15) {
                ForEach(plateChemistry, id: \.label) { row in
                    HStack(alignment: .center, spacing: Space.md) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.label.uppercased())
                                .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                                .kerning(0.7)
                                .foregroundStyle(Palette.cocoaTertiary)
                            Text(row.value)
                                .font(.custom("DMSans-Medium", size: 16, relativeTo: .subheadline))
                                .monospacedDigit()
                                .foregroundStyle(Palette.textPrimary)
                        }
                        Spacer(minLength: Space.md)
                        // Film-caught: at full width the seven marks
                        // spread into sparse dashes. A compact column
                        // reads as an instrument.
                        JeniSparkRow(values: row.week)
                            .frame(width: 124, height: 22)
                    }
                }
            }
            .padding(.top, Space.md)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(chemistryA11y))
    }

    private var chemistryA11y: String {
        "chemistry: " + plateChemistry
            .map { "\($0.label) \($0.value)" }
            .joined(separator: ", ")
    }

    // MARK: page 5 — the week

    private var weekFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            faceLabel("this week")
            JeniChart(
                model: JeniChartModel(form: .bars, series: [
                    .init(values: weekKcal, role: .ink)
                ]),
                height: 108,
                emphasizeLast: true,
                accessibilityText: weekA11y
            )
            .padding(.top, Space.md)
            HStack(spacing: 0) {
                ForEach(Array(weekLetters.enumerated()), id: \.offset) { i, letter in
                    Text(letter)
                        .font(.custom("DMSans-Medium", size: 10, relativeTo: .caption2))
                        .kerning(0.5)
                        .foregroundStyle(
                            i == weekLetters.count - 1
                                ? Palette.textPrimary : Palette.cocoaTertiary
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)
            if let avg = weekAverage {
                Text("averaging \(avg.formatted()) kcal a day")
                    .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 10)
            }
            Spacer(minLength: 0)
        }
    }

    private var weekA11y: String {
        if let avg = weekAverage {
            return "this week, averaging \(avg) calories a day"
        }
        return "this week's calories"
    }

    // MARK: shared face furniture

    private func faceLabel(_ word: String) -> some View {
        Text(word)
            .font(.custom("DMSans-SemiBold", size: 13, relativeTo: .footnote))
            .foregroundStyle(Palette.textPrimary.opacity(0.55))
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

    private var platesLine: (text: String, italic: [String]) {
        let n = snapshot.plates.count
        if n == 0 { return ("no plates yet today.", []) }
        if n == 1 { return ("one plate, counted.", ["counted."]) }
        return ("\(n) plates, counted.", ["counted."])
    }

    // MARK: the stores behind the faces (§1.6 — collected fields only)

    /// The rest of the plate, whispered — only what the day collected.
    private var plateChemistry: [(label: String, value: String, week: [Double?])] {
        var rows: [(String, String, [Double?])] = []
        if snapshot.fiberEatenG > 0 || weekOf(\.fiber).compactMap({ $0 }).count >= 2 {
            rows.append(("fiber", "\(snapshot.fiberEatenG) g", weekOf(\.fiber)))
        }
        if snapshot.sugarEatenG > 0 || weekOf(\.sugar).compactMap({ $0 }).count >= 2 {
            rows.append(("sugar intake", "\(snapshot.sugarEatenG) g", weekOf(\.sugar)))
        }
        let sodium = Int(snapshot.plates.reduce(0) { $0 + $1.sodiumMg }.rounded())
        if sodium > 0 || weekOf(\.sodiumMg).compactMap({ $0 }).count >= 2 {
            rows.append(("sodium", "\(sodium.formatted()) mg", weekOf(\.sodiumMg)))
        }
        return rows.map { (label: $0.0, value: $0.1, week: $0.2) }
    }

    /// Seven days ending today, summed per day from the log; a day
    /// with no entries is nil (never a zero that wasn't measured).
    private func weekOf(_ key: KeyPath<FoodLogPersister.FoodLogEntry, Double>) -> [Double?] {
        guard !userId.isEmpty else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let entries = FoodLogPersister.allEntries(userId: userId)
        return (0..<7).map { back -> Double? in
            guard let day = cal.date(byAdding: .day, value: back - 6, to: today)
            else { return nil }
            let daily = entries.filter { cal.isDate($0.loggedAt, inSameDayAs: day) }
            guard !daily.isEmpty else { return nil }
            let total = daily.reduce(0) { $0 + $1[keyPath: key] }
            return total > 0 ? total : nil
        }
    }

    private var weekKcal: [Double?] { weekOf(\.kcal) }
    private var weekProtein: [Double?] { weekOf(\.protein) }

    private var weekLetters: [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let symbols = cal.veryShortWeekdaySymbols   // S M T W T F S
        return (0..<7).map { back in
            guard let day = cal.date(byAdding: .day, value: back - 6, to: today)
            else { return "" }
            return symbols[cal.component(.weekday, from: day) - 1].lowercased()
        }
    }

    private var weekAverage: Int? {
        let values = weekKcal.compactMap { $0 }
        guard values.count >= 2 else { return nil }
        return Int((values.reduce(0, +) / Double(values.count)).rounded())
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
        return parts.joined(separator: ", ")
    }
}

// MARK: - JeniMacroSplitTall (v21 — the split at plate scale)
//
// The 5pt whisper grown to a 14pt instrument for the carousel's
// plate page. Same honesty: widths derive from collected grams
// (4/4/9 kcal per gram), nothing invented.

private struct JeniMacroSplitTall: View {
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var seen = false

    private var shares: (p: Double, c: Double, f: Double)? {
        let p = Double(proteinG) * 4, c = Double(carbsG) * 4, f = Double(fatG) * 9
        let total = p + c + f
        guard total > 0 else { return nil }
        return (p / total, c / total, f / total)
    }

    var body: some View {
        GeometryReader { geo in
            if let shares {
                let gap: CGFloat = 3
                let usable = max(0, geo.size.width - gap * 2)
                HStack(spacing: gap) {
                    seg(usable * shares.p, Palette.roseBerry)
                    seg(usable * shares.c, Palette.accent)
                    seg(usable * shares.f, Palette.roseBlush)
                }
                .frame(width: geo.size.width, alignment: .leading)
                .scaleEffect(x: landed ? 1 : 0.001, anchor: .leading)
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)   // the legend beneath speaks
        .jeniArmOnVisible($seen)
        .onChange(of: arrived) { _, _ in land() }
        .onChange(of: seen) { _, _ in land() }
        .onAppear { land() }
    }

    private func seg(_ width: CGFloat, _ color: Color) -> some View {
        Capsule(style: .continuous)
            .fill(color)
            .frame(width: max(0, width), height: 14)
    }

    private func land() {
        guard arrived, seen, !landed else { return }
        if reduceMotion {
            landed = true
            return
        }
        withAnimation(JeniMotion.draw) { landed = true }
    }
}

// MARK: - HomeDayRecap (v11.5 — the strip's answer for other days)
//
// Selecting a past day re-keys the page to that day's RECORD: what
// landed, in that day's own numbers. Never a report card — quiet
// memory (L10). Future days decline politely. v21: the recap wears
// the card grammar (label · value · shape).

struct HomeDayRecap: View {
    let date: Date
    let userId: String
    let onOpenRecord: () -> Void
    let onBackToToday: () -> Void

    @Environment(\.modelContext) private var modelContext

    private var cal: Calendar { Calendar.current }
    private var isFuture: Bool { date > cal.startOfDay(for: .now) }

    private struct DayTotals {
        var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
        var plates = 0
        var photoEntryIds: [String] = []
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
            t.photoEntryIds.append(entry.id)
        }
        return t
    }

    /// v25 E4 (R1) — the rest of the day: a manual weigh-in and her
    /// evening word used to vanish from the recap (it rendered food
    /// only, so a kept day read as "nothing logged").
    private var weighedIn: Bool {
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId && $0.source != "onboarding" }
        )
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .contains { cal.isDate($0.loggedAt, inSameDayAs: date) }
    }

    private var feelingWord: String? {
        let key = TodayStateService.dayKey(for: date)
        return ObservationStore.valueText(
            .feeling, dayKey: key, userId: userId, in: modelContext
        ) ?? UserDefaults.standard.string(forKey: "day.reflection.\(key)")
    }

    /// The day line, in the letter's receipt grammar — one product,
    /// one way of saying "this is what the day left behind."
    private var dayLine: String {
        var parts: [String] = []
        if weighedIn { parts.append("weighed in") }
        if let feelingWord { parts.append("closed \(feelingWord)") }
        return parts.joined(separator: " · ")
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
            } else if totals.plates == 0 && dayLine.isEmpty {
                JeniSurface {
                    JeniHeadline("nothing logged this day.")
                }
            } else if totals.plates == 0 {
                // The day left a record even without plates.
                JeniSurface(radius: Radius.card) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("no plates on file.")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                        recapDayLine
                    }
                }
            } else {
                JeniSurface(radius: Radius.card) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        plateThumbs
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(Int(totals.kcal.rounded()).formatted())")
                                .font(Typo.numeralDash)
                                .foregroundStyle(Palette.textPrimary)
                            Text("kcal that day")
                                .font(Typo.numeralMeta)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        JeniMacroSplit(
                            proteinG: Int(totals.protein.rounded()),
                            carbsG: Int(totals.carbs.rounded()),
                            fatG: Int(totals.fat.rounded())
                        )
                        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                            recapPair("plates", "\(totals.plates)")
                            recapPair("protein", "\(Int(totals.protein.rounded())) g")
                            recapPair("carbs", "\(Int(totals.carbs.rounded())) g")
                            recapPair("fat", "\(Int(totals.fat.rounded())) g")
                            Spacer(minLength: 0)
                        }
                        recapDayLine
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

    /// The receipt-grammar footer row ("weighed in · closed proud").
    @ViewBuilder private var recapDayLine: some View {
        if !dayLine.isEmpty {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(width: 28, height: 0.5)
                Text(dayLine)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, 2)
            .accessibilityLabel("that day: \(dayLine)")
        }
    }

    /// v25 E4 (L4) — the day's plate photographs return to Home's
    /// recap (they lived only in the book). Up to three, small,
    /// leading the numbers the way the book leads with photographs.
    @ViewBuilder private var plateThumbs: some View {
        let thumbs = totals.photoEntryIds
            .compactMap { FoodPhotoStore.photo(entryId: $0) }
            .prefix(3)
        if !thumbs.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(thumbs.enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 2)
            .accessibilityHidden(true)
        }
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
