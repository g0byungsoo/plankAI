#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ResultDecisionCard
//
// v1.0.20 (2026-06-18) — rebuilt after founder feedback: the camera
// frame already shows the photo behind the carousel slot; embedding
// a second copy of the same photo inside the card reads as
// duplicated. The card is now PURELY DATA, sitting opaque over the
// frozen camera frame. Frees up the vertical real estate for more
// detail per the founder: ingredients, extras (sodium / sugar /
// sat fat), and a packed item ledger with per-item protein / fiber.
//
// Layout (the card body, sized by the carousel slot):
//
//   - Hairline-rule eyebrow (today's *breakfast* · time)
//   - Calorie hero with CountUpNumber + italic curtsy
//   - Comparative insight line (one honest claim, optional)
//   - Macro row: 4 scrapbook-chrome pills (protein · carbs · fat · fiber)
//   - Extras row: sodium · sugar · sat fat (when present)
//   - Item ledger with per-item portion + kcal + protein + fiber
//   - Italic-punch tag chips
//
// No spacer below the tag chips — content fills the slot bottom-up
// from a denser layout.

struct ResultDecisionCard: View {

    let result: CapturedFood
    let mealLabel: String
    let dishName: String
    var loggedAt: Date = Date()
    var onEditItem: ((Int) -> Void)? = nil

    @State private var revealedSteps: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(red: 0.992, green: 0.965, blue: 0.957)

            contentColumn
                .padding(.horizontal, 80)
                .padding(.top, 110)
                .padding(.bottom, 80)
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
        VStack(alignment: .leading, spacing: 30) {
            eyebrowRule.opacity(opacityFor(0))
            calorieHero.opacity(opacityFor(1))
            insightStack.opacity(opacityFor(2))
            macroRow.opacity(opacityFor(3))
            if hasExtras {
                extrasRow.opacity(opacityFor(4))
            }
            ingredientsHeader.opacity(opacityFor(5))
            itemList.opacity(opacityFor(5))
            tagChips.opacity(opacityFor(6))
        }
    }

    // MARK: - Insight stack (multiple lines now)

    /// Up to three observation lines stacked in cocoa-secondary
    /// DM Sans Light with italic-Fraunces punch words + a heart at
    /// the end of each. Founder direction: TikTok/IG-girl-post
    /// register — more information, more aesthetic, hearts as
    /// terminal punctuation.
    @ViewBuilder private var insightStack: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let line = comparativeInsight {
                heartedLine(
                    prefix: line.prefix,
                    punch: line.punch,
                    suffix: line.suffix
                )
                .accessibilityHint("comparative insight from " + line.source.citation)
            }
            heartedLine(
                prefix: "this should hold you ",
                punch: satietyHoursLabel,
                suffix: "."
            )
            if let fitsLine = fitsLine {
                heartedLine(
                    prefix: fitsLine.prefix,
                    punch: fitsLine.punch,
                    suffix: fitsLine.suffix
                )
            }
        }
    }

    @ViewBuilder
    private func heartedLine(
        prefix: String,
        punch: String,
        suffix: String
    ) -> some View {
        (
            Text(prefix)
                .font(.custom("DMSans-Light", size: 26))
            + Text(punch)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 30))
            + Text(suffix)
                .font(.custom("DMSans-Light", size: 26))
            + Text(" ♡")
                .font(.custom("DMSans-Medium", size: 24))
                .foregroundColor(accent.opacity(0.7))
        )
        .foregroundStyle(textSecondary)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var satietyHoursLabel: String {
        SatietyEstimate.hoursLabel(
            kcal: totalKcal,
            proteinG: totalProtein,
            fiberG: totalFiber
        )
    }

    /// Third insight: a "fits your X" observation if the plate is
    /// notable on a single dimension. Returns nil for unremarkable
    /// plates so the slide stays honest.
    private var fitsLine: (prefix: String, punch: String, suffix: String)? {
        if totalProtein >= 30 {
            return ("a real ", "protein win", ".")
        }
        if totalFiber >= 10 {
            return ("your gut will ", "notice", ".")
        }
        if totalKcal > 0, totalKcal <= 350 {
            return ("a ", "lighter", " plate.")
        }
        return nil
    }

    // MARK: - Ingredients header

    @ViewBuilder private var ingredientsHeader: some View {
        if !result.items.isEmpty {
            HStack(spacing: 14) {
                (
                    Text("\(result.items.count) ")
                        .font(.custom("JeniHeroSerif-Regular", size: 32))
                    + Text(result.items.count == 1 ? "ingredient" : "ingredients")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 28))
                )
                .foregroundStyle(textPrimary)

                Rectangle()
                    .fill(textPrimary.opacity(0.22))
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Eyebrow with hairline rule

    @ViewBuilder private var eyebrowRule: some View {
        HStack(alignment: .center, spacing: 14) {
            (
                Text("today's ")
                    .font(.custom("DMSans-Medium", size: 26))
                + Text(mealLabel.isEmpty ? "plate" : mealLabel.lowercased())
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 28))
            )
            .foregroundStyle(textSecondary)
            .kerning(0.4)

            Rectangle()
                .fill(textPrimary.opacity(0.22))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)

            Text(timeString)
                .font(.custom("DMSans-Medium", size: 22))
                .foregroundStyle(textSecondary)
                .kerning(0.6)
        }
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: loggedAt).lowercased()
    }

    // MARK: - Calorie hero

    @ViewBuilder private var calorieHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            CountUpNumber(
                target: totalKcal,
                fontName: "JeniHeroSerif-Regular",
                italicFontName: "JeniHeroSerif-Italic",
                size: 200,
                color: textPrimary
            )
            Text("calories")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 52))
                .foregroundStyle(textPrimary)
                .baselineOffset(24)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Comparative insight line

    private var comparativeInsight: ComparativeInsight.InsightLine? {
        ComparativeInsight.line(
            mealLabel: mealLabel,
            proteinG: totalProtein,
            fiberG: totalFiber
        )
    }

    // MARK: - Macro row (scrapbook chrome)

    @ViewBuilder private var macroRow: some View {
        HStack(spacing: 18) {
            macroPill(value: totalProtein, label: "protein")
            macroPill(value: totalCarbs, label: "carbs")
            macroPill(value: totalFat, label: "fat")
            macroPill(value: totalFiber, label: "fiber")
        }
    }

    @ViewBuilder
    private func macroPill(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.custom("JeniHeroSerif-Regular", size: 52))
                    .foregroundStyle(textPrimary)
                Text("g")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                    .foregroundStyle(textSecondary)
                    .baselineOffset(4)
            }
            Text(label)
                .font(.custom("DMSans-Medium", size: 20))
                .foregroundStyle(textSecondary)
                .kerning(0.8)
                .textCase(.lowercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 1.0, green: 0.98, blue: 0.973))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(textPrimary.opacity(0.16), lineWidth: 1.5)
        )
        .shadow(color: textPrimary.opacity(0.12), radius: 0, x: 2, y: 3)
    }

    // MARK: - Extras row (sodium / sugar / sat fat)

    private var hasExtras: Bool {
        totalSodiumMg > 0 || totalSugarG > 0 || totalSatFatG > 0
    }

    @ViewBuilder private var extrasRow: some View {
        HStack(spacing: 24) {
            if totalSodiumMg > 0 {
                extraItem(value: "\(totalSodiumMg)", unit: "mg", label: "sodium")
                if totalSugarG > 0 || totalSatFatG > 0 { extraDot }
            }
            if totalSugarG > 0 {
                extraItem(value: "\(totalSugarG)", unit: "g", label: "sugar")
                if totalSatFatG > 0 { extraDot }
            }
            if totalSatFatG > 0 {
                extraItem(value: "\(totalSatFatG)", unit: "g", label: "sat fat")
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func extraItem(value: String, unit: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.custom("JeniHeroSerif-Regular", size: 32))
                .foregroundStyle(textPrimary)
            Text(unit)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                .foregroundStyle(textSecondary)
                .baselineOffset(2)
            Text(" \(label)")
                .font(.custom("DMSans-Light", size: 22))
                .foregroundStyle(textSecondary)
        }
    }

    @ViewBuilder private var extraDot: some View {
        Text("·")
            .font(.custom("DMSans-Medium", size: 26))
            .foregroundStyle(textSecondary.opacity(0.55))
    }

    // MARK: - Item ledger with per-item detail

    @ViewBuilder private var itemList: some View {
        VStack(spacing: 0) {
            ForEach(Array(result.items.enumerated()), id: \.offset) { idx, item in
                if idx > 0 {
                    Rectangle()
                        .fill(textPrimary.opacity(0.10))
                        .frame(height: 0.5)
                }
                itemRow(item: item)
            }
        }
    }

    @ViewBuilder
    private func itemRow(item: CapturedItem) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name.lowercased())
                    .font(.custom("JeniHeroSerif-Regular", size: 42))
                    .foregroundStyle(textPrimary)
                    .kerning(-0.4)
                itemDetailLine(item: item)
            }
            Spacer(minLength: 12)
            itemKcalView(item: item)
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func itemDetailLine(item: CapturedItem) -> some View {
        let parts = itemDetailParts(item)
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.custom("DMSans-Light", size: 22))
                .foregroundStyle(textSecondary)
        }
    }

    private func itemDetailParts(_ item: CapturedItem) -> [String] {
        var parts: [String] = []
        if item.portionGrams > 0 {
            let g = Int((item.portionGrams / 5).rounded()) * 5
            parts.append("\(g)g")
        }
        if let p = item.proteinG, p >= 1 {
            parts.append("\(Int(p.rounded()))g protein")
        }
        if let f = item.fiberG, f >= 1 {
            parts.append("\(Int(f.rounded()))g fiber")
        }
        return parts
    }

    @ViewBuilder
    private func itemKcalView(item: CapturedItem) -> some View {
        if let kcal = item.kcal {
            let rounded = Int((kcal / 5).rounded()) * 5
            (
                Text("\(rounded)")
                    .font(.custom("DMSans-Medium", size: 30))
                    .foregroundStyle(textPrimary)
                + Text(" cal")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                    .foregroundStyle(textSecondary)
                    .baselineOffset(2)
            )
            .monospacedDigit()
        }
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
                .font(.custom("DMSans-Medium", size: 22))
            + Text(punch)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 24))
            + Text(" ♡")
                .font(.custom("DMSans-Medium", size: 20))
                .foregroundColor(accent.opacity(0.7))
        )
        .foregroundStyle(textPrimary)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Capsule().fill(accentSubtle.opacity(0.6)))
        .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 0.75))
    }

    private var activeTags: [String] {
        var tags: [String] = []
        if totalProtein >= 25 { tags.append("high protein") }
        if totalFiber >= 8 { tags.append("high fiber") }
        if totalKcal > 0, totalKcal <= 500 { tags.append("light meal") }
        return tags
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
    private var totalSugarG: Int {
        Int(result.items.compactMap { $0.sugarG }.reduce(0, +).rounded())
    }
    private var totalSodiumMg: Int {
        Int(result.items.compactMap { $0.sodiumMg }.reduce(0, +).rounded())
    }
    private var totalSatFatG: Int {
        Int(result.items.compactMap { $0.saturatedFatG }.reduce(0, +).rounded())
    }

    // MARK: - Palette

    private var textPrimary: Color { Color(red: 0.239, green: 0.165, blue: 0.165) }
    private var textSecondary: Color { Color(red: 0.482, green: 0.349, blue: 0.349) }
    private var accent: Color { Color(red: 0.769, green: 0.404, blue: 0.478) }
    private var accentSubtle: Color { Color(red: 0.961, green: 0.835, blue: 0.847) }
}

#endif  // canImport(UIKit)
