#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ResultDecisionCard
//
// v1.0.23 (2026-06-18) — rebuilt against the cohort-prioritized
// research agent's spec. Founder feedback: the dense "everything"
// layout read like a nutrition-facts label, not a decision aid.
// The research agent's load-bearing call:
//
//   1. Protein as CO-HERO with calories (equal-sized numerals) —
//      single biggest signal-vs-noise upgrade for the cohort.
//      No major competitor (Cal AI / MacroFactor / SnapCalorie /
//      Yazio / MFP / Lifesum / Foodvisor / ZOE) ships this.
//      Validation: cleaneatzkitchen 2025 + ScienceDirect MPS data,
//      U Texas Austin GLP-1 trial, Midi / TaraMD RD recs.
//   2. Satiety as a qualitative one-line PREDICTION — owns the
//      post-Ozempic food-noise vocabulary nobody else has.
//   3. Ruthless silence on everything else — carbs / fat / sodium /
//      sugar / sat fat / NHANES comparative / week pace / ingredients
//      list ALL drop from slide 1. They live one tap away or on
//      slide 2. Validation: 2025 perfectionism + disordered-eating
//      RCT on dense nutrition-label screens driving anxious tracking
//      in women 22-35.
//
// Layout (top to bottom):
//
//   - Hairline-rule eyebrow (today's *meal* · time)
//   - Italic editorial dish title
//   - CO-HERO row: calories + protein numerals, equal height
//   - Protein threshold micro-line (conditional)
//   - Fiber line + italic satiety prediction (when fiber ≥ 3g)
//   - Divider hairline
//   - Day-context one-liner ("X kcal left today · Y g protein left")
//   - Smart pair suggestion (conditional only when gap exists)
//   - Tag chips (single row, max 2)
//
// v1.0.29 (2026-06-18) — full her75 typography swap: every italic
// punch + supporting roman serif on slide 1 now uses JeniHeroSerif
// (Playfair Display rename) per the locked her75 register. Fraunces
// is out across slide 1 — JeniHeroSerif's roman/italic pair carries
// the editorial voice. DMSans stays on body prose + chips. Hearts
// as terminal punctuation on insight lines per locked voice rules.

struct ResultDecisionCard: View {

    let result: CapturedFood
    let mealLabel: String
    let dishName: String
    var loggedAt: Date = Date()
    var onEditItem: ((Int) -> Void)? = nil

    @State private var revealedSteps: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboardingCurrentWeightKg") private var onboardingCurrentWeightKg: Double = 0

    var body: some View {
        ZStack {
            // v1.0.25 (2026-06-18) — transparent backdrop. The frozen
            // camera photo behind the carousel slot shows around the
            // floating card per founder direction: "slide1 and slide2
            // still need to be card design on captured photo."
            Color.clear

            card
                .padding(.horizontal, 56)
                .padding(.top, 96)
                .padding(.bottom, 160)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 1080, height: 1920)
        .clipShape(Rectangle())
        .onAppear { startCascade() }
    }

    /// The floating cream card. v1.0.30 (2026-06-19) — chrome
    /// upgraded to match the Becoming dashboard's luxuryCard
    /// register. Warm cream-to-warmer-cream linear gradient inside,
    /// hairline cocoa border softened to 7%, soft warm drop shadow
    /// (radius 18, cocoa @ 6%). Drops the heavy her75 hard-offset
    /// cocoa shadow that read as a "text shadow" against the cream
    /// background — founder feedback: "wired with old screens (text
    /// shades)."
    @ViewBuilder private var card: some View {
        contentColumn
            .padding(.horizontal, 56)
            .padding(.vertical, 56)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.980, blue: 0.973),
                                Color(red: 0.984, green: 0.949, blue: 0.933),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(textPrimary.opacity(0.07), lineWidth: 0.75)
            )
            .shadow(
                color: Color(red: 0.36, green: 0.20, blue: 0.18).opacity(0.06),
                radius: 18,
                x: 0,
                y: 6
            )
    }

    private func startCascade() {
        if reduceMotion { revealedSteps = 10; return }
        revealedSteps = 0
        for i in 0...9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07 * Double(i)) {
                withAnimation(.easeOut(duration: 0.40)) {
                    revealedSteps = max(revealedSteps, i)
                }
            }
        }
    }

    private func opacityFor(_ step: Int) -> Double {
        revealedSteps >= step ? 1.0 : 0.0
    }

    // MARK: - Content column
    //
    // v1.0.31 (2026-06-19) — densified per the panel synthesis:
    // founder asked for more info aesthetically. Layout uses hairline
    // rules between zones (magazine convention) so density reads as
    // editorial rather than nutrition-label.
    //
    //   Zone A: meta row — time · meal · confidence pill
    //   Zone B: kcal hero + ±range + italic meal name
    //   Zone C: protein co-hero + adequacy stamp
    //   Zone D: ingredient ledger (3-5 hairline rows w/ portion grams)
    //   Zone E: macro micro-bar (compressed, no legend)
    //   Zone F: satiety line + protein density inline
    //   Zone G: today's protein progress (adequacy, NOT calorie)
    //   Zone H: smart pair suggestion (conditional)
    //   Zone I: tag chips (cap 2)

    @ViewBuilder private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            metaRow.opacity(opacityFor(0))
            zoneRule
            kcalHero.opacity(opacityFor(1))
            proteinCoHero.opacity(opacityFor(2))
            zoneRule
            ingredientLedger.opacity(opacityFor(3))
            zoneRule
            macroMicroBar.opacity(opacityFor(4))
            satietyAndDensity.opacity(opacityFor(5))
            todayProteinBar.opacity(opacityFor(5))
            if let pair = smartPair {
                zoneRule
                smartPairLine(pair).opacity(opacityFor(6))
            }
            tagChips.opacity(opacityFor(6))
        }
    }

    /// Half-pt hairline rule between zones — the single convention
    /// that lets density read as magazine, not spreadsheet.
    @ViewBuilder private var zoneRule: some View {
        Rectangle()
            .fill(textPrimary.opacity(0.12))
            .frame(height: 0.75)
            .padding(.vertical, 2)
    }

    // MARK: - Zone A: meta row (time · meal · confidence pill)

    @ViewBuilder private var metaRow: some View {
        HStack(alignment: .center) {
            (Text(timeLabel)
                .font(.custom("DMSans-Medium", size: 26))
                .foregroundColor(textSecondary)
            + Text("  ·  ")
                .font(.custom("DMSans-Medium", size: 26))
                .foregroundColor(textPrimary.opacity(0.25))
            + Text(mealLabelDisplay)
                .font(.custom("JeniHeroSerif-Italic", size: 28))
                .foregroundColor(textSecondary))
            Spacer(minLength: 0)
            confidencePill
        }
    }

    private var timeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: loggedAt).lowercased()
    }

    private var mealLabelDisplay: String {
        mealLabel.isEmpty ? "today" : mealLabel.lowercased()
    }

    @ViewBuilder private var confidencePill: some View {
        let word = confidenceWord
        (Text(word.0)
            .font(.custom("DMSans-Regular", size: 24))
        + Text(word.1)
            .font(.custom("JeniHeroSerif-Italic", size: 26))
        + Text(" \u{2661}")
            .font(.custom("DMSans-Medium", size: 22)))
            .foregroundStyle(accent.opacity(0.80))
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(Capsule().fill(accentSubtle.opacity(0.45)))
    }

    /// Italic state word reading the AI's confidence — never %.
    /// Same data, voiced.
    private var confidenceWord: (String, String) {
        let c = result.confidence ?? 0.85
        switch c {
        case ..<0.65: return ("let's ", "check")
        case ..<0.85: return ("close ", "enough")
        default:      return ("", "clear")
        }
    }

    // MARK: - Zone B: kcal hero (number + ±range + italic meal name)

    @ViewBuilder private var kcalHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            CountUpNumber(
                target: totalKcal,
                fontName: "JeniHeroSerif-Regular",
                italicFontName: "JeniHeroSerif-Italic",
                size: 144,
                color: textPrimary
            )
            VStack(alignment: .leading, spacing: 0) {
                Text("calories")
                    .font(.custom("JeniHeroSerif-Italic", size: 36))
                    .foregroundStyle(textSecondary)
                if let range = kcalRangeLabel {
                    Text(range)
                        .font(.custom("DMSans-Regular", size: 24))
                        .foregroundStyle(textPrimary.opacity(0.45))
                        .monospacedDigit()
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Honest uncertainty band, e.g. "± 50" — only when low + high
    /// differ enough to matter. Reads as transparency, not anxiety.
    private var kcalRangeLabel: String? {
        guard let lo = result.kcalLow, let hi = result.kcalHigh, hi > lo else { return nil }
        let band = Int(((hi - lo) / 2).rounded())
        guard band >= 20 else { return nil }
        return "± \(band)"
    }

    // MARK: - Zone C: protein co-hero + adequacy stamp

    @ViewBuilder private var proteinCoHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            (Text("\(totalProtein)")
                .font(.custom("JeniHeroSerif-Regular", size: 80))
                .foregroundColor(textPrimary)
            + Text("g")
                .font(.custom("JeniHeroSerif-Italic", size: 44))
                .foregroundColor(accent))
                .monospacedDigit()
            Text("protein")
                .font(.custom("JeniHeroSerif-Italic", size: 36))
                .foregroundStyle(textSecondary)
                .baselineOffset(10)
            Spacer(minLength: 0)
            adequacyStamp
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Single-word stamp reading the protein adequacy. Replaces the
    /// prior "a 25g start — pair it later" caption with a tighter,
    /// peer-of-the-numeral mark.
    @ViewBuilder private var adequacyStamp: some View {
        let word: (prefix: String, italic: String) = {
            switch totalProtein {
            case 30...: return ("hits ", "enough")
            case 20..<30: return ("", "solid")
            case 10..<20: return ("a ", "start")
            default:     return ("", "light")
            }
        }()
        (Text(word.prefix)
            .font(.custom("DMSans-Regular", size: 24))
        + Text(word.italic)
            .font(.custom("JeniHeroSerif-Italic", size: 28)))
            .foregroundStyle(totalProtein >= 30 ? stateGood : textSecondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    (totalProtein >= 30 ? stateGood : textSecondary)
                        .opacity(0.10)
                )
            )
    }

    // MARK: - Zone D: ingredient ledger (3-5 rows)

    @ViewBuilder private var ingredientLedger: some View {
        let items = displayIngredients
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline) {
                        Text("⁄")
                            .font(.custom("JeniHeroSerif-Italic", size: 28))
                            .foregroundStyle(accent.opacity(0.65))
                        Text(item.name.lowercased())
                            .font(.custom("DMSans-Medium", size: 30))
                            .foregroundStyle(textPrimary)
                        Spacer(minLength: 0)
                        Text(item.portion)
                            .font(.custom("DMSans-Regular", size: 24))
                            .foregroundStyle(textPrimary.opacity(0.45))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 10)
                    if idx < items.count - 1 {
                        Rectangle()
                            .fill(textPrimary.opacity(0.08))
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    private var displayIngredients: [(name: String, portion: String)] {
        result.items.prefix(5).map { item in
            let portion = item.portionGrams > 0
                ? "\(Int(item.portionGrams.rounded()))g"
                : ""
            return (name: item.name, portion: portion)
        }
    }

    // MARK: - Zone E: macro micro-bar (compressed, no legend)

    @ViewBuilder private var macroMicroBar: some View {
        let total = max(1, totalProtein + totalCarbs + totalFat + totalFiber)
        GeometryReader { geo in
            let width = geo.size.width
            HStack(spacing: 0) {
                Rectangle()
                    .fill(accent.opacity(0.88))
                    .frame(width: width * CGFloat(totalProtein) / CGFloat(total))
                Rectangle()
                    .fill(textPrimary.opacity(0.55))
                    .frame(width: width * CGFloat(totalCarbs) / CGFloat(total))
                Rectangle()
                    .fill(textPrimary.opacity(0.30))
                    .frame(width: width * CGFloat(totalFat) / CGFloat(total))
                Rectangle()
                    .fill(stateGood.opacity(0.85))
                    .frame(width: width * CGFloat(totalFiber) / CGFloat(total))
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)
    }

    // MARK: - Zone F: satiety + protein density

    @ViewBuilder private var satietyAndDensity: some View {
        VStack(alignment: .leading, spacing: 10) {
            (Text("holds you ")
                .font(.custom("JeniHeroSerif-Regular", size: 36))
            + Text(satietyHoursLabel)
                .font(.custom("JeniHeroSerif-Italic", size: 36))
            + Text("  ·  ")
                .font(.custom("JeniHeroSerif-Regular", size: 36))
                .foregroundColor(textPrimary.opacity(0.25))
            + Text("\(totalFiber)g")
                .font(.custom("JeniHeroSerif-Regular", size: 36))
            + Text(" fiber  \u{2661}")
                .font(.custom("DMSans-Medium", size: 28))
                .foregroundColor(accent.opacity(0.7)))
                .foregroundStyle(textPrimary)
                .kerning(-0.2)
                .fixedSize(horizontal: false, vertical: true)
            if let density = proteinDensityLabel {
                Text(density)
                    .font(.custom("DMSans-Regular", size: 24))
                    .foregroundStyle(textSecondary)
            }
        }
    }

    private var proteinDensityLabel: String? {
        guard totalKcal > 0 else { return nil }
        let perHundred = Double(totalProtein) / Double(totalKcal) * 100
        let rounded = (perHundred * 10).rounded() / 10
        guard rounded >= 4 else { return nil }
        let dense = rounded >= 7 ? " · dense plate" : ""
        return "\(String(format: "%.1f", rounded))g protein per 100 cal\(dense)"
    }

    // MARK: - Zone G: today's protein adequacy bar
    //
    // NOT a calorie remaining bar (that's the diet-culture register
    // the brand is built to refuse). Protein-only progress reads as
    // *adequacy* not *budget*. Target derives from onboarding weight
    // (1.0g/kg, floor 70g) when available.

    @ViewBuilder private var todayProteinBar: some View {
        let target = proteinTargetG
        let logged = todayLoggedProtein + totalProtein
        let progress = min(1.0, Double(logged) / Double(max(target, 1)))
        VStack(alignment: .leading, spacing: 6) {
            (Text("today: ")
                .font(.custom("DMSans-Regular", size: 24))
            + Text("\(logged)g")
                .font(.custom("JeniHeroSerif-Italic", size: 26))
                .foregroundColor(textPrimary)
            + Text(" / ~\(target)g protein")
                .font(.custom("DMSans-Regular", size: 24)))
                .foregroundStyle(textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(textPrimary.opacity(0.10))
                    Capsule()
                        .fill(accent.opacity(0.85))
                        .frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 8)
        }
    }

    private var proteinTargetG: Int {
        let kg = onboardingCurrentWeightKg
        let raw = kg > 30 ? 1.0 * kg : 0
        return max(70, min(150, Int(raw.rounded())))
    }

    private var todayLoggedProtein: Int {
        Int(FoodLogPersister.todayMacros().protein.rounded())
    }

    // MARK: - Macro distribution bar (visual at-a-glance)
    //
    // Horizontal stack bar showing the relative balance of protein /
    // carbs / fat / fiber. Reads how the meal is composed without
    // requiring number-parsing. Colors lean on the locked palette:
    //   - protein: accent rose (cohort priority signal)
    //   - carbs:   cocoa @ 0.55
    //   - fat:     cocoa @ 0.30
    //   - fiber:   stateGood sage (the cohort's "you're doing it"
    //              positive signal)
    //
    // Below the bar: tiny color-dot legend with grams per macro.

    @ViewBuilder private var macroDistributionBar: some View {
        let total = max(1, totalProtein + totalCarbs + totalFat + totalFiber)
        VStack(alignment: .leading, spacing: 18) {
            GeometryReader { geo in
                let width = geo.size.width
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(accent.opacity(0.88))
                        .frame(width: width * CGFloat(totalProtein) / CGFloat(total))
                    Rectangle()
                        .fill(textPrimary.opacity(0.55))
                        .frame(width: width * CGFloat(totalCarbs) / CGFloat(total))
                    Rectangle()
                        .fill(textPrimary.opacity(0.30))
                        .frame(width: width * CGFloat(totalFat) / CGFloat(total))
                    Rectangle()
                        .fill(stateGood.opacity(0.85))
                        .frame(width: width * CGFloat(totalFiber) / CGFloat(total))
                }
                .clipShape(Capsule())
            }
            .frame(height: 18)

            HStack(spacing: 22) {
                macroLegendItem(color: accent.opacity(0.88), label: "protein", grams: totalProtein)
                macroLegendItem(color: textPrimary.opacity(0.55), label: "carbs", grams: totalCarbs)
                macroLegendItem(color: textPrimary.opacity(0.30), label: "fat", grams: totalFat)
                macroLegendItem(color: stateGood.opacity(0.85), label: "fiber", grams: totalFiber)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func macroLegendItem(color: Color, label: String, grams: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            (
                Text("\(grams)g ")
                    .font(.custom("DMSans-Medium", size: 22))
                    .foregroundColor(textPrimary)
                + Text(label)
                    .font(.custom("DMSans-Light", size: 22))
                    .foregroundColor(textSecondary)
            )
        }
    }

    private var stateGood: Color { Color(red: 0.373, green: 0.451, blue: 0.271) }


    // MARK: - Co-hero row (kcal + protein at equal height)

    @ViewBuilder private var coHeroRow: some View {
        HStack(alignment: .top, spacing: 56) {
            VStack(alignment: .leading, spacing: 6) {
                CountUpNumber(
                    target: totalKcal,
                    fontName: "JeniHeroSerif-Regular",
                    italicFontName: "JeniHeroSerif-Italic",
                    size: 180,
                    color: textPrimary
                )
                Text("calories")
                    .font(.custom("JeniHeroSerif-Italic", size: 42))
                    .foregroundStyle(textSecondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    CountUpNumber(
                        target: totalProtein,
                        fontName: "JeniHeroSerif-Regular",
                        italicFontName: "JeniHeroSerif-Italic",
                        size: 180,
                        color: textPrimary
                    )
                    Text("g")
                        .font(.custom("JeniHeroSerif-Italic", size: 60))
                        .foregroundStyle(textSecondary)
                        .baselineOffset(36)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("protein")
                        .font(.custom("JeniHeroSerif-Italic", size: 42))
                        .foregroundStyle(textSecondary)
                    if let line = proteinThresholdLine {
                        (
                            Text(line.prefix)
                                .font(.custom("DMSans-Light", size: 28))
                            + Text(line.punch)
                                .font(.custom("JeniHeroSerif-Italic", size: 30))
                            + Text(line.suffix)
                                .font(.custom("DMSans-Light", size: 28))
                        )
                        .foregroundStyle(accent.opacity(0.85))
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Per-meal protein threshold call-out per the research agent's
    /// load-bearing #3 recommendation. 30g = the MPS / GLP-1
    /// distribution target. Below 15g: hide (don't shame).
    private var proteinThresholdLine: (prefix: String, punch: String, suffix: String)? {
        if totalProtein >= 30 {
            return ("hits the ", "30g", " mark ♡")
        }
        if totalProtein >= 15 {
            return ("a ", "\(totalProtein)g", " start — pair it later")
        }
        return nil
    }

    // MARK: - Satiety + fiber block

    /// Combined: fiber line + italic satiety prediction stacked.
    /// Fiber rendered only when ≥3g (below that the "0g fiber" stat
    /// creates shame without action per research agent). Satiety
    /// always renders.
    @ViewBuilder private var satietyAndFiberBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            if totalFiber >= 3 {
                (
                    Text("\(totalFiber)g")
                        .font(.custom("JeniHeroSerif-Regular", size: 64))
                    + Text(" fiber  ·  ")
                        .font(.custom("JeniHeroSerif-Regular", size: 40))
                        .foregroundColor(textSecondary)
                    + Text(fiberQualitative)
                        .font(.custom("JeniHeroSerif-Italic", size: 40))
                        .foregroundColor(textSecondary)
                )
                .foregroundStyle(textPrimary)
                .kerning(-0.4)
                .fixedSize(horizontal: false, vertical: true)
            }
            (
                Text("this should hold you ")
                    .font(.custom("JeniHeroSerif-Regular", size: 42))
                + Text(satietyHoursLabel)
                    .font(.custom("JeniHeroSerif-Italic", size: 42))
                + Text(".  ")
                    .font(.custom("JeniHeroSerif-Regular", size: 42))
                + Text("♡")
                    .font(.custom("DMSans-Medium", size: 32))
                    .foregroundColor(accent.opacity(0.7))
            )
            .foregroundStyle(textPrimary)
            .kerning(-0.2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fiberQualitative: String {
        if totalFiber >= 8 { return "keeps you full longer" }
        if totalFiber >= 5 { return "easy on your gut" }
        return "a soft start"
    }

    private var satietyHoursLabel: String {
        SatietyEstimate.hoursLabel(
            kcal: totalKcal,
            proteinG: totalProtein,
            fiberG: totalFiber
        )
    }

    // MARK: - Smart pair suggestion

    /// Research agent's load-bearing add: ONE specific suggestion
    /// that closes the largest gap, only when a gap exists. Hide on
    /// balanced plates — silence is the reward.
    private var smartPair: (prefix: String, punch: String, suffix: String)? {
        if totalProtein < 25 {
            return ("a ", "boiled egg", " later pushes you past 30g.")
        }
        if totalFiber < 5 {
            return ("a handful of ", "berries", " later locks in fiber.")
        }
        let fatKcal = totalFat * 9
        if totalKcal > 0, Double(fatKcal) / Double(totalKcal) > 0.55 {
            return ("pair with a ", "lean protein", " to balance.")
        }
        return nil
    }

    @ViewBuilder
    private func smartPairLine(
        _ pair: (prefix: String, punch: String, suffix: String)
    ) -> some View {
        (
            Text(pair.prefix)
                .font(.custom("JeniHeroSerif-Regular", size: 36))
            + Text(pair.punch)
                .font(.custom("JeniHeroSerif-Italic", size: 38))
            + Text(pair.suffix)
                .font(.custom("JeniHeroSerif-Regular", size: 36))
            + Text(" ♡")
                .font(.custom("DMSans-Medium", size: 30))
                .foregroundColor(accent.opacity(0.7))
        )
        .foregroundStyle(textSecondary)
        .kerning(-0.2)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Tag chips

    @ViewBuilder private var tagChips: some View {
        let tags = activeTags
        if !tags.isEmpty {
            HStack(spacing: 12) {
                ForEach(tags, id: \.self) { tag in
                    chip(tag)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func chip(_ tag: String) -> some View {
        let parts = tag.split(separator: " ", maxSplits: 1).map(String.init)
        let prefix = parts.count == 2 ? parts[0] + " " : ""
        let punch = parts.last ?? tag
        (
            Text(prefix)
                .font(.custom("DMSans-Medium", size: 28))
            + Text(punch)
                .font(.custom("JeniHeroSerif-Italic", size: 30))
            + Text(" ♡")
                .font(.custom("DMSans-Medium", size: 24))
                .foregroundColor(accent.opacity(0.7))
        )
        .foregroundStyle(textPrimary)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Capsule().fill(accentSubtle.opacity(0.6)))
        .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 0.75))
    }

    private var activeTags: [String] {
        var tags: [String] = []
        if totalProtein >= 25 { tags.append("high protein") }
        if totalFiber >= 8 { tags.append("high fiber") }
        return Array(tags.prefix(2))
    }

    // MARK: - Totals

    private var totalKcal: Int {
        let raw: Double = result.totalKcal
            ?? Double((result.kcalLow ?? 0) + (result.kcalHigh ?? 0)) / 2
        return Int((raw / 5).rounded()) * 5
    }
    private var totalProtein: Int {
        Int(result.items.compactMap { $0.proteinG }.reduce(0, +).rounded())
    }
    private var totalCarbs: Int {
        Int(result.items.compactMap { $0.carbsG }.reduce(0, +).rounded())
    }
    private var totalFat: Int {
        Int(result.items.compactMap { $0.fatG }.reduce(0, +).rounded())
    }
    private var totalFiber: Int {
        Int(result.items.compactMap { $0.fiberG }.reduce(0, +).rounded())
    }

    // MARK: - Palette

    private var textPrimary: Color { Color(red: 0.239, green: 0.165, blue: 0.165) }
    private var textSecondary: Color { Color(red: 0.482, green: 0.349, blue: 0.349) }
    private var accent: Color { Color(red: 0.769, green: 0.404, blue: 0.478) }
    private var accentSubtle: Color { Color(red: 0.961, green: 0.835, blue: 0.847) }
}

#endif  // canImport(UIKit)
