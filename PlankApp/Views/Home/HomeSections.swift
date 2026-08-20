import SwiftUI
import SwiftData
import PlankFood
import PlankSync

// MARK: - HomeNutritionSummary (v25 E9 — THE FOOD BAND)
//
// Home's food band on three tiers, on the paper (no card: a reading
// lives on the paper, v15's container law). It replaces v21's
// five-face hero carousel — see the reasoning on `body`.
//
//   1 THE FLOOR — protein: the one food number with a collected
//     personal target, and so the only one that earns a ring.
//   2 THE DAY   — energy as ONE shape. The macros are one
//     relationship, not three metrics (v18.1), so the split carries
//     carbs/fat/protein and kcal states itself once beside it.
//   3 THE REST  — fiber · sugar · sodium in aligned columns:
//     quantity in serif, unit and published reference demoted.
//
// Tiers render only what a store produced (§1.6): nothing logged →
// the later tiers wait, absent rather than zeroed. The safety gate
// (targets.numericsSuppressed) collapses the band to the words-only
// face — no numerals anywhere.

struct HomeNutritionSummary: View {
    let snapshot: TodaySnapshot
    var userId: String = ""
    let onOpenFood: () -> Void
    /// Opens the repair door for the one fact that is stopping the energy
    /// target from existing. nil = the host has no door to offer, and the
    /// reference stays a bare word rather than a promise it cannot keep.
    var onRepairNumbers: ((TargetsService.MissingEnergyInput) -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Which metric heads the band. The law, not a layout preference:
    /// `00_THE_SYSTEM` §9 — "protein floor + fiber lead; kcal quiet".
    enum Lead: String { case protein, calories }

    /// Pure so the ordering law stays testable. E8 made protein lead a
    /// five-face carousel; E9 removed the carousel and kept the law.
    ///
    /// The honest exception survives verbatim: with no weight collected
    /// there is no floor, so protein would be a bare gram count measured
    /// against nothing (E7's law — a denominator never renders without a
    /// floor). Calories lead in exactly that case and no other.
    static func lead(proteinFloorG: Int?, proteinEatenG: Int) -> Lead {
        (proteinFloorG ?? 0) > 0 ? .protein : .calories
    }

    private var leadMetric: Lead {
        Self.lead(proteinFloorG: snapshot.targets.proteinG,
                  proteinEatenG: snapshot.proteinEatenG)
    }

    // MARK: - the band
    //
    // v25 E9 — THE CAROUSEL IS GONE, and this is the reasoning.
    //
    // v21 built Home's food band as a five-face pager (calories ·
    // protein · plate · chemistry · week). E8 re-ordered it so protein
    // led; E8.1 added the resting strip beneath the lead face; E8.2
    // taught it to measure its own faces after a fixed height sheared
    // three different rows across three eras.
    //
    // Measured here, the faces are mutually REDUNDANT: `calories`
    // duplicates the strip's kcal cell, `plate` duplicates carbs+fat,
    // `chemistry` duplicates fiber/sugar/sodium, and `week` duplicates
    // Becoming's week scope — which is where "what the record means over
    // time" belongs. Only the lead face said something no other face
    // could, which is why E8 promoted it and why the remaining four were
    // a swipe with nothing behind it. A pager whose pages repeat each
    // other is not density; it is the same information charged four
    // times.
    //
    // The shear class of bug came from the same place: a face carrying a
    // hero AND a full ledger cannot share one stage with a face carrying
    // a sparkline. Removing the stage removes the bug by construction.
    //
    // What replaces it is ONE composed instrument on three tiers:
    //
    //   1. THE FLOOR   — protein, with the only food shape that measures
    //                    against a collected personal target.
    //   2. THE DAY     — energy as ONE shape. The macros are one
    //                    relationship, not three metrics (v18.1), so the
    //                    split bar carries carbs/fat/protein and its
    //                    legend carries their grams. kcal states itself
    //                    once, beside the shape it explains.
    //   3. THE REST    — fiber · sugar · sodium, aligned in three
    //                    columns, quantity in serif, reference demoted.
    //
    // Every number the founder's E8 steer asked to keep at rest is still
    // at rest here. It costs ~280pt instead of ~750, and it answers
    // Home's second question ("how am I doing") without a swipe.
    var body: some View {
        Button(action: onOpenFood) {
            VStack(alignment: .leading, spacing: 0) {
                if snapshot.targets.numericsSuppressed {
                    gateFace
                } else {
                    leadBlock
                    if hasDay {
                        dayBlock.padding(.top, Space.blockGap)
                    }
                    if !chemistry.isEmpty {
                        chemistryBlock.padding(.top, 18)
                        dvFootnote
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11ySummary)
        .accessibilityHint("opens the book, your food record")
        .padding(.top, Space.sm)
    }

    // MARK: - tier 1 — the floor

    @ViewBuilder private var leadBlock: some View {
        switch leadMetric {
        case .protein: proteinLead
        case .calories: caloriesLead
        }
    }

    private var proteinLead: some View {
        VStack(alignment: .leading, spacing: 0) {
            bandLabel("protein")
            if typeSize.isAccessibilitySize {
                // A ring cannot hold its numeral at accessibility sizes
                // (§10.2, filmed twice). The fraction keeps a shape as a
                // bar and the words keep their size.
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        proteinNumeral(size: 40)
                        Text(proteinMeta)
                            .font(Typo.numeralMeta)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    if let target = snapshot.targets.proteinG, target > 0 {
                        proteinBar(target: target)
                        proteinReading
                    }
                }
                .padding(.top, 10)
            } else {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        JeniRing(fraction: proteinFraction, size: 116, lineWidth: 10)
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
                    proteinReading
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
            }
        }
    }

    /// The reading beside the ring. E8 left ~120pt of void here by
    /// hanging one 12pt caption against a 116pt instrument; the state
    /// now leads at reading weight and its reason sits under it, so the
    /// column carries the ring instead of apologising to it.
    private var proteinReading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(proteinState.head)
                .font(.custom("DMSans-Medium", size: 15, relativeTo: .subheadline))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(proteinState.tail)
                .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The calories lead — the honest exception, and the only place the
    /// kcal ring survives on Home.
    ///
    /// 2026-08-14: this face carried two `if let kcal` branches that
    /// **cannot execute.** It is reached only when the protein floor is
    /// absent, and the floor is absent only when no weight is known at
    /// all — the same condition that makes `targets.kcal` nil. So the
    /// remaining-kcal line and the words *"weigh in to set a protein
    /// floor"* had never once rendered, and what she actually saw was an
    /// empty ring, a bare "kcal", and no way out. Unreachable copy that
    /// promises the repair is worse than no copy: it makes the file read
    /// as if the state were handled.
    ///
    /// So this face states what it is (nothing measured against anything)
    /// and offers the one door that changes it.
    private var caloriesLead: some View {
        VStack(alignment: .leading, spacing: 0) {
            bandLabel("calories")
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    JeniCountingNumeral(
                        value: Double(snapshot.kcalEaten),
                        font: .custom("JeniHeroSerif-Regular", size: 40,
                                      relativeTo: .largeTitle)
                    )
                    Text("kcal today")
                        .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.textSecondary)
                    repairLine
                }
                .padding(.top, 10)
            } else {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        JeniRing(fraction: ringFraction, size: 116, lineWidth: 10)
                        VStack(spacing: 0) {
                            JeniCountingNumeral(
                                value: Double(snapshot.kcalEaten),
                                font: .custom("JeniHeroSerif-Regular", size: 34,
                                              relativeTo: .title)
                            )
                            Text("kcal")
                                .font(.custom("DMSans-Regular", size: 11,
                                              relativeTo: .caption2))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .frame(maxWidth: 88)
                        .minimumScaleFactor(0.6)
                    }
                    repairLine
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
            }
        }
    }

    /// The no-target repair, stated as a sentence rather than a warning.
    /// Silent when the host has no door, and silent under numeric
    /// suppression — a suppressed cohort is never asked for a weight.
    @ViewBuilder
    private var repairLine: some View {
        if !snapshot.targets.numericsSuppressed,
           let missing = snapshot.missingEnergyInput,
           let onRepairNumbers {
            Button {
                Haptics.light()
                onRepairNumbers(missing)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("no daily target yet")
                        .font(.custom("DMSans-Medium", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Palette.textPrimary)
                    Text(missing.repairSubline)
                        .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("no daily target yet. add \(missing.word) and it arrives.")
        }
    }

    // MARK: - tier 2 — the day, as one shape

    private var hasDay: Bool { snapshot.kcalEaten > 0 }

    /// XXXL frame-caught: a label, a serif figure and a reference on ONE
    /// line became "the day  1,66 of 1,47…", and the three-across legend
    /// became "· p… 2… · c… 3… · f… 11 g". Both are the same mistake —
    /// a row that fits at 17pt does not fit at 53pt — so both stack from
    /// the accessibility sizes up, where a column is the only honest
    /// layout left.
    private var stacksForType: Bool {
        typeSize.isAccessibilitySize || typeSize >= .xxxLarge
    }

    private var dayBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            hairline
            Group {
                if stacksForType {
                    VStack(alignment: .leading, spacing: 2) {
                        dayLabel
                        if leadMetric == .protein { dayKcal }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        dayLabel
                        Spacer(minLength: 8)
                        if leadMetric == .protein { dayKcal }
                    }
                }
            }
            .padding(.top, 12)

            PlateEnergySplit(
                proteinG: snapshot.proteinEatenG,
                carbsG: snapshot.carbsEatenG,
                fatG: snapshot.fatEatenG
            )
            .padding(.top, 10)

            // The legend is what makes the shape readable, and it is
            // also where carbs and fat live now — they were never three
            // metrics, they are this one relationship's parts.
            Group {
                if stacksForType {
                    VStack(alignment: .leading, spacing: 6) {
                        splitLegend("protein", grams: snapshot.proteinEatenG,
                                    color: Palette.roseBerry)
                        splitLegend("carbs", grams: snapshot.carbsEatenG,
                                    color: Palette.accent)
                        splitLegend("fat", grams: snapshot.fatEatenG,
                                    color: Palette.roseBlush)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        splitLegend("protein", grams: snapshot.proteinEatenG,
                                    color: Palette.roseBerry)
                        Spacer(minLength: Space.sm)
                        splitLegend("carbs", grams: snapshot.carbsEatenG,
                                    color: Palette.accent)
                        Spacer(minLength: Space.sm)
                        splitLegend("fat", grams: snapshot.fatEatenG,
                                    color: Palette.roseBlush)
                    }
                }
            }
            .padding(.top, 10)
        }
    }

    private var dayLabel: some View {
        Text("the day")
            .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
            .foregroundStyle(Palette.cocoaTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// kcal states itself ONCE — here, beside the shape it explains —
    /// instead of once in a ring and again in a strip cell two tiers down.
    /// FRAME REVIEW, AX5: `kcal · add a goal weight` truncated to
    /// `add a goal…` — the door's whole meaning is the word it ends with,
    /// and a repair link that cannot be read is not a repair. The numeral
    /// keeps `lineLimit(1)` because a NUMERAL must never wrap (the
    /// `124` → `12`/`4` law); the sentence beside it may.
    @ViewBuilder
    private var dayKcal: some View {
        let numeral = Text(snapshot.kcalEaten.formatted())
            .font(.custom("JeniHeroSerif-Regular", size: 20, relativeTo: .title3))
            .monospacedDigit()
            .foregroundStyle(Palette.textPrimary)
        if stacksForType {
            VStack(alignment: .leading, spacing: 2) {
                numeral.lineLimit(1).fixedSize(horizontal: true, vertical: false)
                reference
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                numeral
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                reference
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    /// WHAT IS LEFT TODAY — the subtraction the product asked her to do
    /// in her head.
    ///
    /// The band stated `1,660 of 1,460 kcal` and stopped. That is the
    /// eaten figure and its provenance; it is not the number that changes
    /// her next decision, which is *how much room is left*. The whole
    /// grammar for it already ships one tier up: `PlateAnswerEngine`
    /// closes every protein sentence with "18 g to go", and the evening
    /// close is built on the same gap. Energy — the number this plan is
    /// priced on — was the one place the product computed a position and
    /// declined to state the remainder.
    ///
    /// It is also a promise. The consult's own device demo (`V8Device`,
    /// face 1) draws this exact ring and captions it, in italic serif,
    /// **"what's left today"** — a caption for a subtraction the shipped
    /// app never performed. Same class as `31` §4's two broken promises
    /// ("you can change this anytime"), about the number she is paying
    /// for.
    ///
    /// Rides the established `· <word>` suffix (`31` §8's `· holding`)
    /// so it is one line, one tier, no new furniture.
    ///
    /// **Maintenance keeps `· holding` and gets no remainder**, and the
    /// refusal is the point: a maintenance figure is an ESTIMATE OF HER
    /// EXPENDITURE, not a budget she was given to spend. "220 left"
    /// against an estimate is an instruction to eat that nothing in the
    /// record supports.
    /// Pure so the honesty table is testable without a view.
    /// p53 — `countUpOnly` is the GLP-1 posture: the medication is
    /// already doing the deficit, and "over" is the market's named
    /// harm for this cohort (the countdown trauma; the what-the-hell
    /// effect). Under stays spoken — it invites eating, which is this
    /// cohort's actual job — and past the target the pair of numbers
    /// states the fact plainly with no judgment tail.
    static func energyRemainderWord(
        targetKcal: Int?, eatenKcal: Int, isMaintenance: Bool,
        countUpOnly: Bool = false
    ) -> String? {
        guard let kcal = targetKcal, kcal > 0, !isMaintenance else { return nil }
        let diff = kcal - eatenKcal
        if diff > 0 { return "\(diff.formatted()) left" }
        if diff < 0 { return countUpOnly ? nil : "\((-diff).formatted()) over" }
        return "right on it"
    }

    /// The whole reference sentence, so a nil remainder can never leave a
    /// dangling separator on screen.
    static func energyReferenceLine(
        targetKcal: Int?, eatenKcal: Int, isMaintenance: Bool,
        countUpOnly: Bool = false
    ) -> String? {
        guard let kcal = targetKcal, kcal > 0 else { return nil }
        let base = "of \(kcal.formatted()) kcal"
        if isMaintenance { return base + " · holding" }
        guard let word = energyRemainderWord(
            targetKcal: kcal, eatenKcal: eatenKcal, isMaintenance: false,
            countUpOnly: countUpOnly
        ) else { return base }
        return base + " · " + word
    }

    private var energyReference: String? {
        Self.energyReferenceLine(
            targetKcal: snapshot.targets.kcal,
            eatenKcal: snapshot.kcalEaten,
            isMaintenance: snapshot.energyIsMaintenance,
            // p53 — the on-medication chapter counts UP.
            countUpOnly: snapshot.chapter == .onMedication
        )
    }

    /// THE EMPTY DENOMINATOR IS A DOOR.
    ///
    /// When the energy target cannot exist, this said "kcal" — factually
    /// true, and a dead end for the one user who most needs to act.
    /// `missingEnergyInput` knows which fact is absent, so the line names
    /// it and opens on it.
    @ViewBuilder
    private var reference: some View {
        if let line = energyReference {
            // A maintenance number and a loss target are the same glyph
            // and opposite instructions. When she reaches her goal the
            // target jumps by the whole deficit; without the word, that
            // is a number changing for no stated reason, which is a
            // support email.
            Text(line)
                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(
                    "\(snapshot.kcalEaten.formatted()) kcal, "
                    + line.replacingOccurrences(of: " · ", with: ", ")
                )
        } else if !snapshot.targets.numericsSuppressed,
                  let missing = snapshot.missingEnergyInput,
                  let onRepairNumbers {
            Button {
                Haptics.light()
                onRepairNumbers(missing)
            } label: {
                Text("kcal · \(missing.doorLine)")
                    .font(.custom("DMSans-Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .underline(true, pattern: .solid)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("no daily target yet. \(missing.doorLine)")
        } else {
            Text("kcal")
                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(Palette.cocoaTertiary)
        }
    }

    private func splitLegend(_ label: String, grams: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(Palette.cocoaTertiary)
            Text("\(grams) g")
                .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
        }
        .lineLimit(1)
        .accessibilityHidden(true)
    }

    // MARK: - tier 3 — the rest, aligned

    /// fiber · sugar · sodium. Today's own numbers only: a week
    /// condition used to keep a row alive on a day it measured nothing,
    /// which renders a zero the day never collected.
    ///
    /// Which of these gets a denominator is unchanged from E8 and the
    /// reasoning is unchanged with it: fiber and sodium quote the
    /// published FDA Daily Value (21 CFR 101.9) marked `dv`; TOTAL sugar
    /// gets none, deliberately, because the FDA limit is on ADDED sugars
    /// and pairing them would overstate every plate containing fruit or
    /// milk.
    private struct Cell: Identifiable {
        let label: String
        let amount: String
        let unit: String
        let reference: String?
        var id: String { label }
        var spoken: String {
            "\(label) \(amount) \(unit)" + (reference.map { ", \($0)" } ?? "")
        }
    }

    private var chemistry: [Cell] {
        guard !snapshot.targets.numericsSuppressed else { return [] }
        var out: [Cell] = []
        if snapshot.fiberEatenG > 0 {
            out.append(Cell(label: "fiber", amount: "\(snapshot.fiberEatenG)",
                            unit: "g", reference: "of \(Self.dvFiberG) dv"))
        }
        if snapshot.sugarEatenG > 0 {
            out.append(Cell(label: "sugar", amount: "\(snapshot.sugarEatenG)",
                            unit: "g", reference: nil))
        }
        let sodium = Int(snapshot.plates.reduce(0) { $0 + $1.sodiumMg }.rounded())
        if sodium > 0 {
            out.append(Cell(label: "sodium", amount: sodium.formatted(),
                            unit: "mg", reference: "of \(Self.dvSodiumMg.formatted()) dv"))
        }
        return out
    }

    /// FDA Daily Values (21 CFR 101.9), quoted as published. General
    /// adult references, never personalized targets.
    private static let dvFiberG = 28
    private static let dvSodiumMg = 2_300

    /// Three stacked columns, values on one baseline, references beneath
    /// them. The E8.1 finding stands — a cell is PARTS, not a string, so
    /// sodium stops reading as the loudest number on the screen — but
    /// the reference moves UNDER the quantity instead of trailing it,
    /// which is what stopped "sodiu… 1,770 mg of 2,30…" from truncating
    /// at a third of the width. One column from XXXL up.
    private var chemistryBlock: some View {
        let cells = chemistry
        let columns = (typeSize.isAccessibilitySize || typeSize >= .xxxLarge) ? 1 : cells.count
        return LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: Space.md, alignment: .topLeading),
                count: max(1, columns)
            ),
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(cells) { cell in
                if columns == 1 {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(cell.label)
                            .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                            .foregroundStyle(Palette.cocoaTertiary)
                        Spacer(minLength: 4)
                        Text(cell.amount)
                            .font(.custom("JeniHeroSerif-Regular", size: 18, relativeTo: .body))
                            .monospacedDigit()
                            .foregroundStyle(Palette.textPrimary)
                        Text(cell.unit)
                            .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                        if let reference = cell.reference {
                            Text(reference)
                                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cell.label)
                            .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .lineLimit(1)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(cell.amount)
                                .font(.custom("JeniHeroSerif-Regular", size: 18,
                                              relativeTo: .body))
                                .monospacedDigit()
                                .foregroundStyle(Palette.textPrimary)
                            Text(cell.unit)
                                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        Text(cell.reference ?? " ")
                            .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(cell.reference == nil ? 0 : 1)
                    }
                }
            }
        }
    }

    @ViewBuilder private var dvFootnote: some View {
        if chemistry.contains(where: { $0.reference != nil }) {
            Text("dv is a general daily value, not your target")
                .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 8)
        }
    }

    // MARK: - furniture

    private var hairline: some View {
        Rectangle()
            .fill(Palette.hairlineCocoa)
            .frame(height: 0.5)
    }

    private func bandLabel(_ word: String) -> some View {
        Text(word)
            .font(.custom("DMSans-SemiBold", size: 13, relativeTo: .footnote))
            .foregroundStyle(Palette.textPrimary.opacity(0.55))
    }

    // MARK: - the safety-gate face (words, never numerals)

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

    // MARK: - the stores behind the tiers (§1.6 — collected fields only)

    private func proteinNumeral(size: CGFloat) -> some View {
        JeniCountingNumeral(
            value: Double(snapshot.proteinEatenG),
            font: .custom("JeniHeroSerif-Regular", size: size,
                          relativeTo: size >= 40 ? .largeTitle : .title)
        )
    }

    private var proteinMeta: String {
        if let target = snapshot.targets.proteinG, target > 0 {
            return "of \(target) g"
        }
        return "g"
    }

    private var proteinFraction: Double {
        guard let target = snapshot.targets.proteinG, target > 0 else { return 0 }
        return Double(snapshot.proteinEatenG) / Double(target)
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

    /// The state, then its reason. Split so the reading can carry two
    /// registers instead of one 12pt line.
    private var proteinState: (head: String, tail: String) {
        guard let target = snapshot.targets.proteinG, target > 0 else {
            return ("\(snapshot.proteinEatenG) g today", "protein first")
        }
        let left = target - snapshot.proteinEatenG
        if left > 0 { return ("\(left) g to the floor", "protein first") }
        return ("floor met", "muscle kept fed")
    }

    private var ringFraction: Double {
        guard let kcal = snapshot.targets.kcal, kcal > 0 else { return 0 }
        return Double(snapshot.kcalEaten) / Double(kcal)
    }

    private var a11ySummary: String {
        if snapshot.targets.numericsSuppressed {
            return "\(platesLine.text) gentle plates, protein first"
        }
        var parts: [String] = []
        if let target = snapshot.targets.proteinG, target > 0 {
            parts.append("protein \(snapshot.proteinEatenG) of \(target) grams, \(proteinState.head)")
        } else {
            parts.append("protein \(snapshot.proteinEatenG) grams")
        }
        if snapshot.kcalEaten > 0 {
            if let kcal = snapshot.targets.kcal, kcal > 0 {
                parts.append("\(snapshot.kcalEaten) calories of \(kcal) kcal")
            } else if let missing = snapshot.missingEnergyInput {
                parts.append("\(snapshot.kcalEaten) calories, no daily target yet — \(missing.doorLine)")
            } else {
                parts.append("\(snapshot.kcalEaten) calories")
            }
            parts.append("carbs \(snapshot.carbsEatenG) grams, fat \(snapshot.fatEatenG) grams")
        }
        parts.append(contentsOf: chemistry.map(\.spoken))
        return parts.joined(separator: ", ")
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
