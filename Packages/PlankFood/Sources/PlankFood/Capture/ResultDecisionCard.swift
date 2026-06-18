#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ResultDecisionCard
//
// v1.0.18 (2026-06-18) — slide 1 of the new post-scan carousel,
// designed by the her75 + WL-researcher + GLP-1-MD panel and locked
// against the Cal AI / SnapCalorie / MacroFactor competitive
// research. Replaces MealSummaryCard.
//
// Layout (1080×1920, cream `bgPrimary` canvas):
//
//   - Photo, full-width edge-to-edge, ~40% of canvas (768pt tall)
//   - Calorie HERO numeral (JeniHeroSerif 220pt cocoa) + "calories"
//     label (DMSans-Medium 30pt textSecondary)
//   - Macro row: protein → carbs → fat → fiber. Protein pill carries
//     visual weight (italic Fraunces accent), the rest are quieter.
//     Numbers rounded to clean buckets per the WL expert's
//     uncertainty-in-language rule.
//   - Item list (scrollable on iOS, fixed for the share PNG). Each
//     row = item name (JeniHeroSerif 44pt) + portion (DMSans-Light
//     28pt textSecondary) + per-item kcal trailing (DMSans-Medium
//     24pt cocoa). Hairline 0.5pt cocoa @ 0.15 between rows.
//   - Conditional tag chips strip (high protein / high fiber / fits
//     your day). No alarms, no good/bad labels.
//   - Bottom safe area for the camera-frame toolbar (log it / share
//     / retake live in the parent, NOT this card).
//
// Tap on an item row fires `onEditItem(index)` — caller surfaces a
// portion-edit sheet. v1 ships view-only; the sheet is a follow-up.

struct ResultDecisionCard: View {

    let result: CapturedFood
    let photo: UIImage?
    let mealLabel: String      // "Breakfast" / "Lunch" / etc.
    let dishName: String       // dish-level title
    var loggedAt: Date = Date()
    var onEditItem: ((Int) -> Void)? = nil

    var body: some View {
        ZStack {
            Color(red: 0.992, green: 0.965, blue: 0.957)  // bgPrimary cream

            VStack(spacing: 0) {
                photoBleed
                    .frame(width: 1080, height: 760)
                    .clipped()

                contentColumn
                    .padding(.horizontal, 64)
                    .padding(.top, 36)
                    .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1920)
        .clipShape(Rectangle())
    }

    // MARK: - Photo

    @ViewBuilder private var photoBleed: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 1080, height: 760)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.78, blue: 0.79),
                    Color(red: 0.85, green: 0.55, blue: 0.62),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 1080, height: 760)
        }
    }

    // MARK: - Content column

    @ViewBuilder private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 28) {
            eyebrow
            calorieHero
            macroRow
            divider
            itemList
            tagChips
            Spacer(minLength: 0)
        }
    }

    // MARK: - Eyebrow

    @ViewBuilder private var eyebrow: some View {
        HStack(spacing: 8) {
            Text(mealLabel.lowercased())
                .font(.custom("DMSans-Medium", size: 26))
                .foregroundStyle(textSecondary)
            Text("·")
                .font(.custom("DMSans-Medium", size: 26))
                .foregroundStyle(textSecondary.opacity(0.6))
            Text(timeString)
                .font(.custom("DMSans-Medium", size: 26))
                .foregroundStyle(textSecondary)
        }
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: loggedAt).lowercased()
    }

    // MARK: - Calorie hero

    @ViewBuilder private var calorieHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(totalKcal)")
                .font(.custom("JeniHeroSerif-Regular", size: 220))
                .foregroundStyle(textPrimary)
                .lineSpacing(-12)
            Text("calories")
                .font(.custom("DMSans-Medium", size: 30))
                .foregroundStyle(textSecondary)
                .offset(y: -16)
        }
    }

    // MARK: - Macro row

    @ViewBuilder private var macroRow: some View {
        HStack(spacing: 18) {
            macroPill(
                value: totalProtein,
                unit: "g",
                label: "protein",
                highlight: true
            )
            macroPill(value: totalCarbs, unit: "g", label: "carbs")
            macroPill(value: totalFat, unit: "g", label: "fat")
            macroPill(value: totalFiber, unit: "g", label: "fiber")
        }
    }

    @ViewBuilder
    private func macroPill(
        value: Int,
        unit: String,
        label: String,
        highlight: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.custom(
                        highlight ? "JeniHeroSerif-Italic" : "JeniHeroSerif-Regular",
                        size: 56
                    ))
                    .foregroundStyle(textPrimary)
                Text(unit)
                    .font(.custom("DMSans-Medium", size: 20))
                    .foregroundStyle(textSecondary)
            }
            Text(label)
                .font(.custom("DMSans-Medium", size: 20))
                .foregroundStyle(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(highlight ? accentSubtle.opacity(0.55) : Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(textPrimary.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Item list

    @ViewBuilder private var divider: some View {
        Rectangle()
            .fill(textPrimary.opacity(0.12))
            .frame(height: 1)
    }

    @ViewBuilder private var itemList: some View {
        VStack(spacing: 0) {
            ForEach(Array(result.items.enumerated()), id: \.offset) { idx, item in
                if idx > 0 {
                    Rectangle()
                        .fill(textPrimary.opacity(0.10))
                        .frame(height: 0.5)
                        .padding(.vertical, 4)
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
                    .font(.custom("JeniHeroSerif-Regular", size: 44))
                    .foregroundStyle(textPrimary)
                if let portion = portionLabel(for: item) {
                    Text(portion)
                        .font(.custom("DMSans-Light", size: 26))
                        .foregroundStyle(textSecondary)
                }
            }
            Spacer(minLength: 12)
            if let kcal = itemKcal(item) {
                Text("\(kcal)")
                    .font(.custom("DMSans-Medium", size: 30))
                    .foregroundStyle(textPrimary)
                + Text(" cal")
                    .font(.custom("DMSans-Light", size: 22))
                    .foregroundStyle(textSecondary)
            }
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture { onEditItem?(index) }
    }

    /// Pulls per-item portion in household-friendly form when grams
    /// are available; falls back to grams if not. Cohort research
    /// said household > grams reads cleaner on this surface, but the
    /// vision pipeline currently only returns grams — so we ship
    /// grams now and the household-unit pass can layer in later.
    private func portionLabel(for item: CapturedItem) -> String? {
        guard item.portionGrams > 0 else { return nil }
        let rounded = Int((item.portionGrams / 5).rounded()) * 5  // clean buckets
        return "\(rounded)g"
    }

    private func itemKcal(_ item: CapturedItem) -> Int? {
        guard let kcal = item.kcal else { return nil }
        let rounded = Int((kcal / 5).rounded()) * 5  // clean buckets
        return rounded
    }

    // MARK: - Tag chips
    //
    // Conditional. Surface only when the threshold actually holds —
    // we never lie about the food. No "low sodium" alarms; only
    // positive/neutral signals.

    @ViewBuilder private var tagChips: some View {
        let tags = activeTags
        if !tags.isEmpty {
            HStack(spacing: 10) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.custom("DMSans-Medium", size: 22))
                        .foregroundStyle(textPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(accentSubtle.opacity(0.85))
                        )
                }
                Spacer(minLength: 0)
            }
        }
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
        return Int((raw / 5).rounded()) * 5  // clean buckets, 5-cal increments
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

    // MARK: - Palette helpers (cocoa-on-cream)

    private var textPrimary: Color { Color(red: 0.239, green: 0.165, blue: 0.165) }
    private var textSecondary: Color { Color(red: 0.482, green: 0.349, blue: 0.349) }
    private var accentSubtle: Color { Color(red: 0.961, green: 0.835, blue: 0.847) }
}

#endif  // canImport(UIKit)
