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
// her75 typography preserved: JeniHeroSerif for hero numerals,
// Fraunces-SemiBoldItalic for punch words, DMSans for body. Hearts
// as terminal punctuation on insight lines per locked voice rules.

struct ResultDecisionCard: View {

    let result: CapturedFood
    let mealLabel: String
    let dishName: String
    var loggedAt: Date = Date()
    var onEditItem: ((Int) -> Void)? = nil

    @State private var revealedSteps: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("foodDailyTarget") private var foodDailyTarget: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.992, green: 0.965, blue: 0.957)

            contentColumn
                .padding(.horizontal, 80)
                .padding(.top, 130)
                .padding(.bottom, 100)
        }
        .frame(width: 1080, height: 1920)
        .clipShape(Rectangle())
        .onAppear { startCascade() }
    }

    private func startCascade() {
        if reduceMotion { revealedSteps = 7; return }
        revealedSteps = 0
        for i in 0...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 * Double(i)) {
                withAnimation(.easeOut(duration: 0.42)) {
                    revealedSteps = max(revealedSteps, i)
                }
            }
        }
    }

    private func opacityFor(_ step: Int) -> Double {
        revealedSteps >= step ? 1.0 : 0.0
    }

    // MARK: - Content column

    @ViewBuilder private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 44) {
            eyebrowRule.opacity(opacityFor(0))
            dishTitle.opacity(opacityFor(1))
            coHeroRow.opacity(opacityFor(2))
            satietyAndFiberBlock.opacity(opacityFor(3))
            divider.opacity(opacityFor(4))
            dayContextLine.opacity(opacityFor(5))
            if let pair = smartPair {
                smartPairLine(pair).opacity(opacityFor(6))
            }
            tagChips.opacity(opacityFor(6))
            Spacer(minLength: 0)
        }
    }

    // MARK: - Eyebrow with hairline rule

    @ViewBuilder private var eyebrowRule: some View {
        HStack(alignment: .center, spacing: 14) {
            (
                Text("today's ")
                    .font(.custom("DMSans-Medium", size: 30))
                + Text(mealLabel.isEmpty ? "plate" : mealLabel.lowercased())
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 32))
            )
            .foregroundStyle(textSecondary)
            .kerning(0.4)

            Rectangle()
                .fill(textPrimary.opacity(0.22))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)

            Text(timeString)
                .font(.custom("DMSans-Medium", size: 26))
                .foregroundStyle(textSecondary)
                .kerning(0.6)
        }
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: loggedAt).lowercased()
    }

    // MARK: - Dish title (editorial mid-size)

    @ViewBuilder private var dishTitle: some View {
        (
            Text("reading your ")
                .font(.custom("JeniHeroSerif-Regular", size: 68))
            + Text(dishLineDisplay)
                .font(.custom("JeniHeroSerif-Italic", size: 68))
            + Text(".")
                .font(.custom("JeniHeroSerif-Regular", size: 68))
        )
        .foregroundStyle(textPrimary)
        .kerning(-0.8)
        .lineSpacing(-2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var dishLineDisplay: String {
        let stripped = dishName
            .replacingOccurrences(
                of: #"\s*\+\s*\d+\s+more$"#,
                with: "",
                options: .regularExpression
            )
            .lowercased()
        return stripped.isEmpty ? "your plate" : stripped
    }

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
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 42))
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
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 60))
                        .foregroundStyle(textSecondary)
                        .baselineOffset(36)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("protein")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 42))
                        .foregroundStyle(textSecondary)
                    if let line = proteinThresholdLine {
                        (
                            Text(line.prefix)
                                .font(.custom("DMSans-Light", size: 28))
                            + Text(line.punch)
                                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 30))
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
                        .font(.custom("Fraunces72pt-Regular", size: 40))
                        .foregroundColor(textSecondary)
                    + Text(fiberQualitative)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 40))
                        .foregroundColor(textSecondary)
                )
                .foregroundStyle(textPrimary)
                .kerning(-0.4)
                .fixedSize(horizontal: false, vertical: true)
            }
            (
                Text("this should hold you ")
                    .font(.custom("Fraunces72pt-Regular", size: 42))
                + Text(satietyHoursLabel)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 42))
                + Text(".  ")
                    .font(.custom("Fraunces72pt-Regular", size: 42))
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

    // MARK: - Divider

    @ViewBuilder private var divider: some View {
        Rectangle()
            .fill(textPrimary.opacity(0.16))
            .frame(height: 0.5)
            .frame(maxWidth: 320)
    }

    // MARK: - Day-context (kcal left + protein left)

    @ViewBuilder private var dayContextLine: some View {
        let kcalLeft = max(0, kcalTarget - kcalToday)
        let proteinLeft = max(0, proteinTarget - proteinToday)
        VStack(alignment: .leading, spacing: 12) {
            Text("today")
                .font(.custom("DMSans-Medium", size: 26))
                .foregroundStyle(textSecondary)
                .kerning(1.4)
                .textCase(.uppercase)
            (
                Text("\(kcalLeft) ")
                    .font(.custom("JeniHeroSerif-Regular", size: 52))
                + Text("kcal")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 36))
                    .foregroundColor(textSecondary)
                + Text(" left  ·  ")
                    .font(.custom("Fraunces72pt-Regular", size: 36))
                    .foregroundColor(textSecondary)
                + Text("\(proteinLeft)g ")
                    .font(.custom("JeniHeroSerif-Regular", size: 52))
                + Text("protein")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 36))
                    .foregroundColor(textSecondary)
                + Text(" left")
                    .font(.custom("Fraunces72pt-Regular", size: 36))
                    .foregroundColor(textSecondary)
            )
            .foregroundStyle(textPrimary)
            .kerning(-0.2)
            .fixedSize(horizontal: false, vertical: true)
        }
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
                .font(.custom("Fraunces72pt-Regular", size: 36))
            + Text(pair.punch)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 38))
            + Text(pair.suffix)
                .font(.custom("Fraunces72pt-Regular", size: 36))
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
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 30))
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
    private var totalFat: Int {
        Int(result.items.compactMap { $0.fatG }.reduce(0, +).rounded())
    }
    private var totalFiber: Int {
        Int(result.items.compactMap { $0.fiberG }.reduce(0, +).rounded())
    }

    // MARK: - Day-context computed

    private var kcalTarget: Int {
        foodDailyTarget > 0 ? Int(foodDailyTarget) : 1950
    }
    private var proteinTarget: Int {
        Int((Double(kcalTarget) * 0.25) / 4)
    }
    private var todayLogged: FoodLogPersister.TodayMacros {
        FoodLogPersister.todayMacros()
    }
    private var kcalToday: Int { Int(todayLogged.kcal.rounded()) + totalKcal }
    private var proteinToday: Int { Int(todayLogged.protein.rounded()) + totalProtein }

    // MARK: - Palette

    private var textPrimary: Color { Color(red: 0.239, green: 0.165, blue: 0.165) }
    private var textSecondary: Color { Color(red: 0.482, green: 0.349, blue: 0.349) }
    private var accent: Color { Color(red: 0.769, green: 0.404, blue: 0.478) }
    private var accentSubtle: Color { Color(red: 0.961, green: 0.835, blue: 0.847) }
}

#endif  // canImport(UIKit)
