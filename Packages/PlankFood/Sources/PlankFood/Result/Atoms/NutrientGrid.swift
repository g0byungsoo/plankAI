#if canImport(UIKit)
import SwiftUI

// MARK: - NutrientGrid
//
// Replaces the bare 4-nutrient MacroRow on the result card. Per
// founder on-device feedback 2026-06-05: cohort cares about more
// than P/C/F. Sugar (blood-sugar awareness), sodium (bloat
// awareness), and fiber (satiety) are surfaced alongside macros.
// Saturated fat is included when present, more subtle.
//
// Layout: 2-column grid, 3 rows. Cohort-priority order top-down:
//   row 1:  protein · fiber
//   row 2:  carbs   · sugar
//   row 3:  fat     · sodium
// Saturated fat: shown as a small subtle "of which N saturated"
// caption under the fat cell when > 0.
//
// Per v5 anti-shame lock + feedback_food_ux_antishame: NO color
// coding (no green/red), NO good/bad framing. Just numbers in
// hierarchy. Cohort interprets values via their own knowledge +
// the Jeni interpretation line above.

public struct NutrientGrid: View {

    public let kcal: Double?
    public let proteinG: Double?
    public let carbsG: Double?
    public let fatG: Double?
    public let fiberG: Double?
    public let sugarG: Double?
    public let sodiumMg: Double?
    public let saturatedFatG: Double?

    public init(
        kcal: Double?,
        proteinG: Double?,
        carbsG: Double?,
        fatG: Double?,
        fiberG: Double?,
        sugarG: Double?,
        sodiumMg: Double?,
        saturatedFatG: Double?
    ) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.sodiumMg = sodiumMg
        self.saturatedFatG = saturatedFatG
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FoodTheme.Space.md) {

            // Header strip: kcal centerpiece.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatted(kcal))
                    .font(.custom("Fraunces72pt-SemiBold", size: 32))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .monospacedDigit()
                Text("cal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary)
            }

            Divider()
                .overlay(FoodTheme.accentSubtle)

            // 2-column nutrient grid.
            let columns = [
                GridItem(.flexible(), spacing: FoodTheme.Space.md),
                GridItem(.flexible(), spacing: FoodTheme.Space.md),
            ]
            LazyVGrid(columns: columns, alignment: .leading, spacing: FoodTheme.Space.md) {
                cell(label: "protein", value: proteinG, unit: "g", emphasis: true)
                cell(label: "fiber",   value: fiberG,   unit: "g", emphasis: true)
                cell(label: "carbs",   value: carbsG,   unit: "g")
                cell(label: "sugar",   value: sugarG,   unit: "g")
                cell(label: "fat",     value: fatG,     unit: "g")
                cell(label: "sodium",  value: sodiumMg, unit: "mg")
            }

            // Saturated fat as subtle caption under the grid when present.
            if let satFat = saturatedFatG, satFat > 0 {
                Text("of which \(Int(satFat.rounded()))g saturated")
                    .font(.system(size: 11))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityCopy)
    }

    // MARK: - Cell

    @ViewBuilder
    private func cell(label: String, value: Double?, unit: String, emphasis: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FoodTheme.textSecondary)
                .tracking(0.5)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatted(value))
                    .font(.system(
                        size: emphasis ? 18 : 16,
                        weight: emphasis ? .semibold : .medium,
                        design: .rounded
                    ))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private func formatted(_ v: Double?) -> String {
        guard let v else { return "—" }
        return "\(Int(v.rounded()))"
    }

    private var accessibilityCopy: String {
        guard let kcal else { return "macros pending" }
        var parts: [String] = ["\(Int(kcal.rounded())) calories"]
        if let p = proteinG { parts.append("\(Int(p.rounded()))g protein") }
        if let f = fiberG   { parts.append("\(Int(f.rounded()))g fiber") }
        if let s = sugarG   { parts.append("\(Int(s.rounded()))g sugar") }
        if let n = sodiumMg { parts.append("\(Int(n.rounded()))mg sodium") }
        if let c = carbsG   { parts.append("\(Int(c.rounded()))g carbs") }
        if let f = fatG     { parts.append("\(Int(f.rounded()))g fat") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview("NutrientGrid — full data") {
    NutrientGrid(
        kcal: 480,
        proteinG: 22,
        carbsG: 50,
        fatG: 18,
        fiberG: 3,
        sugarG: 8,
        sodiumMg: 720,
        saturatedFatG: 7
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

#Preview("NutrientGrid — partial data") {
    NutrientGrid(
        kcal: 200,
        proteinG: 5,
        carbsG: 30,
        fatG: 3,
        fiberG: nil,
        sugarG: 22,
        sodiumMg: nil,
        saturatedFatG: nil
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

#Preview("NutrientGrid — empty (pending USDA join)") {
    NutrientGrid(
        kcal: nil, proteinG: nil, carbsG: nil, fatG: nil,
        fiberG: nil, sugarG: nil, sodiumMg: nil, saturatedFatG: nil
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

#endif  // canImport(UIKit)
