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

    enum Page: String, CaseIterable, Identifiable {
        case calories, protein, plate, chemistry, week
        var id: String { rawValue }
    }

    /// nil until the scroll view reports its own resting page. Was
    /// hardcoded `.calories`, which after E8's re-order would have
    /// scrolled Home to page 2 on every appear — the lead page is
    /// whatever `pages` puts first, and a nil scroll position rests at
    /// the leading edge by construction.
    @State private var page: Page?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// One design height for every page so the pager never reflows
    /// the list beneath it; scales with the reader's type (§10.2).
    ///
    /// v25 E8, walk-caught: 208 was sized for the protein block alone.
    /// With the resting nutrition strip beneath it the second row
    /// (fiber · sugar · sodium) rendered its labels and then sheared its
    /// VALUES off against the stage — a caption with no number under it,
    /// which reads as a rendering fault rather than as information. The
    /// other faces centre their content, so the extra height lands as
    /// air on them rather than as a hole.
    /// E8.1 — 252 → 286 → 322, and each bump was measured against one
    /// arrangement and sheared under the next (E8: the third row under
    /// the page dots; E8.1: the second row, twice; the ship walk: the
    /// `dv` footnote under sodium). Three recurrences is the proof that
    /// the CONSTANT is the defect. The carousel now measures its faces
    /// at their real width and takes the tallest natural height — this
    /// value survives only as the first-frame fallback before the first
    /// measurement lands.
    @ScaledMetric(relativeTo: .body) private var faceHeight: CGFloat = 322
    /// The tallest face's measured natural height (0 until first layout).
    @State private var measuredFaceHeight: CGFloat = 0
    private var resolvedFaceHeight: CGFloat {
        measuredFaceHeight > 0 ? measuredFaceHeight : faceHeight
    }

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
                        current: page.flatMap { pages.firstIndex(of: $0) } ?? 0
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
            }
        }
    }

    // MARK: the pages that have something to say

    // v25 E8 — PROTEIN LEADS.
    //
    // The carousel opened on calories from v21 until now, and reached
    // protein only on a swipe. That inverted the product's own law
    // (`00_THE_SYSTEM` §9: "protein floor + fiber lead; kcal quiet",
    // from §7.6 — protein 1.2-2.0 g/kg is one of exactly two proven
    // GLP-1 content pillars, and lean mass is 25-40% of drug-induced
    // loss) on the most-seen surface in the app. E7 had already fixed
    // the same inversion in the reading and deleted the kcal ring there.
    //
    // Why it matters more here than anywhere else: the payer median is
    // 2.0 active days, so Home's first three seconds are close to the
    // whole relationship. For a GLP-1 user specifically, a ring counting
    // UP toward a calorie budget rewards the one behaviour the drug
    // already over-supplies — eating less — while the floor that
    // protects lean mass sat one swipe away. And for a brand-new payer
    // with nothing logged, calories-first opens the app on a `0` inside
    // a ring: a budget with nothing in it, which answers none of Home's
    // three questions. Protein at zero reads "90 g to the floor ·
    // protein first" — the same pixel count, carrying an instruction.
    //
    // The one case where calories still leads: no protein floor on file
    // (no weight collected). E7's law — a denominator never renders
    // without a floor — means protein would show a bare gram count with
    // nothing to measure it against, which is weaker than the kcal ring.
    //
    // Deliberately NOT changed: the faces themselves, the page count,
    // the paging mechanics, or the kcal ring (Home is not the reading;
    // calories remain a real fact, they just stop being the lead).
    // Nothing deep-links into a page identity — checked, not assumed.
    private var pages: [Page] {
        Self.pageOrder(
            proteinFloorG: snapshot.targets.proteinG,
            proteinEatenG: snapshot.proteinEatenG,
            kcalEaten: snapshot.kcalEaten,
            hasChemistry: !plateChemistry.isEmpty,
            weekDaysWithData: weekKcal.compactMap { $0 }.count
        )
    }

    /// Pure so the ordering law is testable — the law is the point of
    /// the change, and a law that only exists inside a private view
    /// property is one refactor away from silently inverting again.
    static func pageOrder(
        proteinFloorG: Int?,
        proteinEatenG: Int,
        kcalEaten: Int,
        hasChemistry: Bool,
        weekDaysWithData: Int
    ) -> [Page] {
        var result: [Page] = []
        let hasProteinFloor = (proteinFloorG ?? 0) > 0
        if hasProteinFloor { result.append(.protein) }
        result.append(.calories)
        // Protein without a floor still deserves a page once she has
        // actually eaten some — it just cannot lead.
        if !hasProteinFloor && proteinEatenG > 0 { result.append(.protein) }
        if kcalEaten > 0 { result.append(.plate) }
        if hasChemistry { result.append(.chemistry) }
        if weekDaysWithData >= 2 { result.append(.week) }
        return result
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(pages) { p in
                    face(for: p)
                        .frame(height: resolvedFaceHeight, alignment: .top)
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
        .frame(height: resolvedFaceHeight)
        // The measuring copy: every face laid out invisibly at the
        // carousel's own width, natural height, tallest wins. LazyHStack
        // only realizes visible pages, so measuring in-line would let a
        // taller unvisited face shear on arrival; this measures them all
        // up front at the real wrap width.
        .background {
            ZStack(alignment: .top) {
                ForEach(pages) { p in
                    face(for: p)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(
                            GeometryReader { g in
                                Color.clear.preference(
                                    key: MaxFaceHeightKey.self,
                                    value: g.size.height
                                )
                            }
                        )
                }
            }
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onPreferenceChange(MaxFaceHeightKey.self) { measuredFaceHeight = $0 }
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
        //
        // v25 E8, walk-caught: that fix assumed the week row was there
        // to weight the bottom. On a brand-new payer it is not (it needs
        // two days), so the block sat at the top of a 208pt stage and
        // left ~120pt of void beneath the floor line. Invisible while
        // calories led — page 2 is a surface nobody arrives on — and
        // the first thing on screen the moment protein leads. Without a
        // week to anchor the bottom, the block centres in its stage
        // instead of hanging from the top.
        let hasWeek = weekProtein.compactMap { $0 }.count >= 2
        return VStack(alignment: .leading, spacing: 0) {
            faceLabel("protein")

            // v25 E8 (founder steer: "i prefer donut chart than bar
            // chart for this usecase"). The floor bar became a ring —
            // the same instrument the calories face has always used,
            // now on the metric the product's law says leads. It also
            // buys back the width the bar spent on nothing: the reading
            // sits BESIDE the ring instead of under it, which is what
            // makes room for the nutrition strip below.
            //
            // At accessibility sizes the ring cannot hold its numeral
            // (§10.2, the same finding the calories face recorded), so
            // the block falls back to numeral-over-bar.
            VStack(alignment: .leading, spacing: 0) {
                if typeSize.isAccessibilitySize {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        proteinNumeral(size: 40)
                        Text(proteinMeta)
                            .font(Typo.numeralMeta)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    if let target = snapshot.targets.proteinG, target > 0 {
                        proteinBar(target: target).padding(.top, 12)
                        proteinCaption(target: target).padding(.top, 8)
                    }
                } else {
                    HStack(alignment: .center, spacing: 16) {
                        ZStack {
                            JeniRing(
                                fraction: proteinFraction,
                                size: 116,
                                lineWidth: 10
                            )
                            VStack(spacing: 0) {
                                proteinNumeral(size: 34)
                                Text(proteinMeta)
                                    .font(.custom("DMSans-Regular", size: 11,
                                                  relativeTo: .caption2))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .frame(maxWidth: 88)
                            .minimumScaleFactor(0.6)
                        }
                        if let target = snapshot.targets.proteinG, target > 0 {
                            proteinCaption(target: target)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, hasWeek ? 6 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // top when something anchors the bottom, centred when
            // nothing does — the same stage, never a void.
            .frame(maxHeight: .infinity,
                   alignment: (hasWeek || !restingNutrition.isEmpty) ? .top : .center)

            // v25 E8 (founder steer): "snapshot of other nutritional
            // info + calories still provide a lot of values in home
            // screen". Protein leads, but the rest of the day should not
            // cost a swipe — most people never page a carousel. The
            // strip is deliberately quiet (small caps labels, ~19pt
            // values) so it reads as instrumentation under the hero
            // rather than competing with it, and it renders ONLY what a
            // store produced (v21 §1.6) — a new payer with nothing
            // logged still sees a clean protein-first instruction, never
            // a row of zeros.
            if !restingNutrition.isEmpty {
                restingStrip
                dvFootnote
            } else if hasWeek {
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

    private func proteinNumeral(size: CGFloat) -> some View {
        JeniCountingNumeral(
            value: Double(snapshot.proteinEatenG),
            font: .custom("JeniHeroSerif-Regular", size: size,
                          relativeTo: size >= 40 ? .largeTitle : .title)
        )
    }

    private func proteinCaption(target: Int) -> some View {
        Text(proteinWord(target: target))
            .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var proteinFraction: Double {
        guard let target = snapshot.targets.proteinG, target > 0 else { return 0 }
        return Double(snapshot.proteinEatenG) / Double(target)
    }

    /// v25 E8 (founder steer: "it's kinda confusing whats the
    /// recommended consumption ceiling for each nutrient and calories").
    ///
    /// The strip showed six bare numbers with nothing to read them
    /// against. The honest fix is NOT to invent six targets — `Targets`
    /// carries exactly two food numbers (`kcal` and `proteinG`), and
    /// fabricating the rest would break the provenance rule this product
    /// is built on. So each cell says precisely as much as the product
    /// actually knows:
    ///
    ///   - **kcal** — HER target, derived from her own collected fields.
    ///   - **fiber · sodium** — the published FDA Daily Value, marked
    ///     `dv` and footnoted as a general reference, never as a
    ///     personal target. Same posture as v24's label facts: a
    ///     published number, quoted as published.
    ///   - **carbs · fat** — no denominator. There is no universal
    ///     ceiling for either; they are a distribution, not a limit.
    ///   - **sugar** — no denominator, deliberately. The FDA limit is on
    ///     ADDED sugars and this figure is TOTAL sugars (USDA "sugars"),
    ///     so pairing them would overstate every plate that contains
    ///     fruit or milk. The one comparison a nutrition app is most
    ///     tempted to make wrong.
    ///
    /// No percentages, no "high"/"low", no red — E7's micronutrient
    /// rules, applied one register up.
    ///
    /// E8.1 REDESIGN. The founder: *"this nutritional info looks good
    /// functionally but it doesn't look too aesthetic, modern,
    /// minimalistic."* Correct, and the diagnosis is typographic rather
    /// than informational — every value and every denominator decision
    /// below is unchanged.
    ///
    /// What was wrong: each cell rendered ONE uniform serif string, so
    /// `"420 of 2,300 mg"` read as a single enormous number and **sodium
    /// was visually the loudest thing in the strip** — an exact inversion
    /// of the product's own hierarchy. Six values at identical weight in a
    /// ragged three-column grid is a spreadsheet, not a glance. And the
    /// legend underneath was the tell: a layout that needs explaining has
    /// already failed.
    ///
    /// So a cell is now PARTS, not a string: the quantity carries the
    /// serif, the unit and the reference are demoted to a caption face,
    /// and `dv` is a marker rather than part of the label. Nothing about
    /// which numbers get a denominator changed.
    private struct Nutrient: Identifiable {
        let label: String
        /// The quantity, and the only part that carries the serif.
        let amount: String
        /// "g" / "mg" / nil. Demoted: a unit is not a number.
        let unit: String?
        /// "of 1,473" — the reference, demoted the same way. nil where
        /// the product deliberately has no denominator.
        let reference: String?
        /// Marks the two references that quote the published FDA Daily
        /// Value rather than one of hers.
        let isDV: Bool

        var id: String { label }

        /// One string, for VoiceOver and for the tests.
        var spoken: String {
            var out = "\(label) \(amount)"
            if let unit { out += " \(unit)" }
            if let reference { out += " \(reference)" }
            if isDV { out += ", daily value" }
            return out
        }
    }

    private var restingNutrition: [Nutrient] {
        guard !snapshot.targets.numericsSuppressed else { return [] }
        var rows: [Nutrient] = []
        if snapshot.kcalEaten > 0 {
            rows.append(Nutrient(
                label: "kcal",
                amount: snapshot.kcalEaten.formatted(),
                unit: nil,
                reference: (snapshot.targets.kcal).flatMap {
                    $0 > 0 ? "of \($0.formatted())" : nil
                },
                isDV: false
            ))
        }
        if snapshot.carbsEatenG > 0 {
            rows.append(Nutrient(label: "carbs", amount: "\(snapshot.carbsEatenG)",
                                 unit: "g", reference: nil, isDV: false))
        }
        if snapshot.fatEatenG > 0 {
            rows.append(Nutrient(label: "fat", amount: "\(snapshot.fatEatenG)",
                                 unit: "g", reference: nil, isDV: false))
        }
        for row in plateChemistry where rows.count < 6 {
            switch row.label {
            case "fiber":
                rows.append(Nutrient(
                    label: "fiber", amount: "\(snapshot.fiberEatenG)", unit: "g",
                    reference: "of \(Self.dvFiberG)", isDV: true
                ))
            case "sodium":
                let mg = Int(snapshot.plates.reduce(0) { $0 + $1.sodiumMg }.rounded())
                rows.append(Nutrient(
                    label: "sodium", amount: mg.formatted(), unit: "mg",
                    reference: "of \(Self.dvSodiumMg.formatted())", isDV: true
                ))
            default:
                // "sugar intake" — measured, never compared (see above).
                rows.append(Nutrient(
                    label: "sugar",
                    amount: row.value.replacingOccurrences(of: " g", with: ""),
                    unit: "g", reference: nil, isDV: false
                ))
            }
        }
        return rows
    }

    /// FDA Daily Values (21 CFR 101.9), quoted as published. General
    /// adult references, NOT personalized targets — the strip marks them
    /// `dv` and says so in one line beneath.
    private static let dvFiberG = 28
    private static let dvSodiumMg = 2_300

    /// THE PANEL. Two columns of `label ......... value` pairs, hairline
    /// between rows, values right-aligned so the eye reads DOWN one edge
    /// — the reason a well-set nutrition panel is legible at a glance and
    /// a grid of equal-weight numbers is not.
    ///
    /// Three rows instead of two makes it no taller, because each row is
    /// one line of type rather than a stacked label-over-value pair.
    ///
    /// At accessibility sizes it becomes one column: two columns of
    /// `label` + a right-aligned number cannot survive the label growing,
    /// and Move's own week caption truncating to "THE WE… · YOUR…" at XXXL
    /// this same era is the reminder.
    private var restingStrip: some View {
        let cells = restingNutrition
        // CONTENT SHAPE DRIVES LAYOUT. The two `dv` items carry a label, a
        // value, a unit AND a published reference — genuinely more than
        // "carbs 19 g" — so at half a screen width sodium truncated to
        // "sodiu… 420 mg of 2,30…", caught by filming. They get a full row
        // each; everything else pairs up. It also puts the two published
        // references next to each other, directly above the one line that
        // explains them.
        let paired = cells.filter { !$0.isDV }
        let wide = cells.filter(\.isDV)
        // One column from XXXL up, not only at accessibility sizes:
        // the ship walk filmed "kcal 1,6… of 1,4…" at XXXL — the kcal
        // cell carries a value AND her target, and half a screen stops
        // fitting both one size before the accessibility switch.
        let columns = (typeSize.isAccessibilitySize || typeSize >= .xxxLarge) ? 1 : 2
        return VStack(spacing: 0) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 20, alignment: .leading),
                    count: columns
                ),
                alignment: .leading,
                spacing: 0
            ) {
                ForEach(Array(paired.enumerated()), id: \.element.id) { index, cell in
                    nutrientRow(cell, showsRule: index >= columns)
                }
            }
            ForEach(Array(wide.enumerated()), id: \.element.id) { index, cell in
                nutrientRow(cell, showsRule: index == 0 ? !paired.isEmpty : true)
            }
        }
        .padding(.top, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(cells.map(\.spoken).joined(separator: ", ")))
    }

    @ViewBuilder
    private func nutrientRow(_ cell: Nutrient, showsRule: Bool) -> some View {
        VStack(spacing: 0) {
            if showsRule {
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.5)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(cell.label)
                    .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // THE QUANTITY carries the serif. Everything else is
                // demoted, which is what stops "420 of 2,300 mg" reading
                // as one enormous number.
                Text(cell.amount)
                    .font(.custom("JeniHeroSerif-Regular", size: 18, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)

                if let unit = cell.unit {
                    Text(unit)
                        .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                if let reference = cell.reference {
                    Text(reference + (cell.isDV ? " dv" : ""))
                        .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 7)
        }
    }

    /// One line, only when a `dv` actually rendered. The distinction it
    /// draws is the whole point of the founder's question: which of
    /// these numbers is HERS and which is a published reference.
    @ViewBuilder
    private var dvFootnote: some View {
        if restingNutrition.contains(where: \.isDV) {
            // Tightened to the row above it: it explains the two rows it
            // sits directly under, so it belongs to them rather than
            // floating as a page-level legend.
            Text("dv is a general daily value, not your target")
                .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 5)
        }
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

/// Tallest measured hero-face height (the carousel's measuring copy).
private struct MaxFaceHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
