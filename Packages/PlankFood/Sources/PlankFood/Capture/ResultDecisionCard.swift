#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ResultDecisionCard
//
// v1.0.19 (2026-06-18) — rebuilt against the her75 + iOS-premium +
// data-honest panel synthesis. Adds:
//
//   - Paper-halo photo stamp (inset 68pt, 28pt corner, 12pt cream
//     halo, hard cocoa offset shadow) replacing the edge-to-edge
//     Cal AI strip
//   - Hairline-rule eyebrow: `today's *breakfast*` + 0.5pt cocoa
//     hairline + `8:42am` right
//   - Inline italic calorie hero via CountUpNumber + " calories"
//     italic Fraunces suffix; count-up rolls 0 → final + italic
//     curtsy at landing
//   - ONE comparative insight line (NHANES 19-30 baseline, honest
//     fallback to nil) with italic-Fraunces punch number
//   - Macro pills in scrapbook chrome (22pt corner, 1.5pt cocoa-16%
//     border, hard offset shadow). Drops protein-only italic accent
//     so the row reads as consistent typography, not "one different
//     pill among four"
//   - Item ledger with hairline dividers + italic " cal" suffix
//     trailing
//   - Italic-punch tag chips ("high *protein*")

struct ResultDecisionCard: View {

    let result: CapturedFood
    let photo: UIImage?
    let mealLabel: String
    let dishName: String
    var loggedAt: Date = Date()
    var onEditItem: ((Int) -> Void)? = nil

    var body: some View {
        ZStack {
            Color(red: 0.992, green: 0.965, blue: 0.957)

            VStack(spacing: 0) {
                photoHalo
                    .padding(.top, 32)
                    .padding(.horizontal, 68)

                contentColumn
                    .padding(.horizontal, 80)
                    .padding(.top, 44)
                    .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1920)
        .clipShape(Rectangle())
    }

    // MARK: - Photo halo (paper-stamp register)

    @ViewBuilder private var photoHalo: some View {
        ZStack {
            // 12pt cream halo (the "paper mount" around the print)
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color(red: 1.0, green: 0.98, blue: 0.973))
                .frame(width: 944, height: 672)

            photoLayer
                .frame(width: 920, height: 648)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .frame(width: 944, height: 672)
        // Hard cocoa offset shadow — no blur. Scrapbook register.
        .shadow(color: textPrimary.opacity(0.18), radius: 0, x: 6, y: 8)
    }

    @ViewBuilder private var photoLayer: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.78, blue: 0.79),
                    Color(red: 0.85, green: 0.55, blue: 0.62),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Content column

    @ViewBuilder private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 32) {
            eyebrowRule
            calorieHero
            if let line = comparativeInsight {
                comparativeInsightView(line)
            }
            macroRow
            itemList
            tagChips
            Spacer(minLength: 0)
        }
    }

    // MARK: - Eyebrow with hairline rule

    @ViewBuilder private var eyebrowRule: some View {
        HStack(alignment: .center, spacing: 14) {
            // `today's *breakfast*` — italic-Fraunces punch
            (
                Text("today's ")
                    .font(.custom("DMSans-Medium", size: 24))
                + Text(mealLabel.isEmpty ? "plate" : mealLabel.lowercased())
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
            )
            .foregroundStyle(textSecondary)
            .kerning(0.4)

            // 0.5pt cocoa hairline — the editorial "rule"
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

    // MARK: - Calorie hero (count-up + inline italic suffix)

    @ViewBuilder private var calorieHero: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            CountUpNumber(
                target: totalKcal,
                fontName: "JeniHeroSerif-Regular",
                italicFontName: "JeniHeroSerif-Italic",
                size: 220,
                color: textPrimary
            )
            Text("calories")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 56))
                .foregroundStyle(textPrimary)
                .baselineOffset(28)
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

    @ViewBuilder
    private func comparativeInsightView(
        _ line: ComparativeInsight.InsightLine
    ) -> some View {
        (
            Text(line.prefix)
                .font(.custom("DMSans-Light", size: 28))
            + Text(line.punch)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 32))
            + Text(line.suffix)
                .font(.custom("DMSans-Light", size: 28))
        )
        .foregroundStyle(textSecondary)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityHint("comparative insight from " + line.source.citation)
    }

    // MARK: - Macro row (scrapbook chrome)

    @ViewBuilder private var macroRow: some View {
        HStack(spacing: 22) {
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
                    .font(.custom("JeniHeroSerif-Regular", size: 56))
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
        .padding(.vertical, 22)
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

    // MARK: - Item ledger

    @ViewBuilder private var itemList: some View {
        VStack(spacing: 0) {
            ForEach(Array(result.items.enumerated()), id: \.offset) { idx, item in
                if idx > 0 {
                    Rectangle()
                        .fill(textPrimary.opacity(0.10))
                        .frame(height: 0.5)
                }
                itemRow(item: item, index: idx)
            }
        }
    }

    @ViewBuilder
    private func itemRow(item: CapturedItem, index: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name.lowercased())
                    .font(.custom("JeniHeroSerif-Regular", size: 46))
                    .foregroundStyle(textPrimary)
                    .kerning(-0.4)
                if let portion = portionLabel(for: item) {
                    Text(portion)
                        .font(.custom("DMSans-Light", size: 26))
                        .foregroundStyle(textSecondary)
                }
            }
            Spacer(minLength: 12)
            if let kcal = itemKcal(item) {
                (
                    Text("\(kcal)")
                        .font(.custom("DMSans-Medium", size: 32))
                        .foregroundStyle(textPrimary)
                    + Text(" cal")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                        .foregroundStyle(textSecondary)
                        .baselineOffset(2)
                )
                .monospacedDigit()
            }
        }
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .onTapGesture { onEditItem?(index) }
    }

    private func portionLabel(for item: CapturedItem) -> String? {
        guard item.portionGrams > 0 else { return nil }
        let rounded = Int((item.portionGrams / 5).rounded()) * 5
        return "\(rounded)g"
    }

    private func itemKcal(_ item: CapturedItem) -> Int? {
        guard let kcal = item.kcal else { return nil }
        return Int((kcal / 5).rounded()) * 5
    }

    // MARK: - Tag chips (italic-Fraunces punch word)

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
        // Tags arrive as "high protein" / "high fiber" / "light meal".
        // Split on the trailing word, italic-Fraunces the punch.
        let parts = tag.split(separator: " ", maxSplits: 1).map(String.init)
        let prefix = parts.count == 2 ? parts[0] + " " : ""
        let punch = parts.last ?? tag
        (
            Text(prefix)
                .font(.custom("DMSans-Medium", size: 22))
            + Text(punch)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 24))
        )
        .foregroundStyle(textPrimary)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(accentSubtle.opacity(0.6))
        )
        .overlay(
            Capsule().stroke(accent.opacity(0.35), lineWidth: 0.75)
        )
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

    // MARK: - Palette

    private var textPrimary: Color { Color(red: 0.239, green: 0.165, blue: 0.165) }
    private var textSecondary: Color { Color(red: 0.482, green: 0.349, blue: 0.349) }
    private var accent: Color { Color(red: 0.769, green: 0.404, blue: 0.478) }
    private var accentSubtle: Color { Color(red: 0.961, green: 0.835, blue: 0.847) }
}

#endif  // canImport(UIKit)
