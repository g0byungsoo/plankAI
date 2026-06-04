#if canImport(UIKit)
import SwiftUI

// MARK: - MacroRow
//
// Per v5 D43 (founder override of designer #2's tap-to-reveal) +
// §Calorie scan Screen 3: macros default-visible on the result card
// in a single horizontal row: cal · P · C · F. Compact, monospaced
// numbers, no "g" suffix on macros (label P/C/F is enough; the
// per-glance read is "how big are these compared to each other").
//
// Renders gracefully when any field is nil — shows "—" placeholder
// for that slot (the USDA join didn't resolve for this item yet).
//
// Calories shown without unit; macros shown without "g" — match
// convention of MFP / Cal AI / MacroFactor's data-dense macro chips.

public struct MacroRow: View {

    public let kcal: Double?
    public let proteinG: Double?
    public let carbsG: Double?
    public let fatG: Double?
    public var emphasized: Bool = false

    public init(
        kcal: Double?,
        proteinG: Double?,
        carbsG: Double?,
        fatG: Double?,
        emphasized: Bool = false
    ) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.emphasized = emphasized
    }

    public var body: some View {
        HStack(spacing: FoodTheme.Space.md) {
            macroChip(label: nil, value: kcal, suffix: "")
            dot
            macroChip(label: "P", value: proteinG, suffix: "g")
            dot
            macroChip(label: "C", value: carbsG, suffix: "g")
            dot
            macroChip(label: "F", value: fatG, suffix: "g")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityCopy)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func macroChip(label: String?, value: Double?, suffix: String) -> some View {
        HStack(spacing: 3) {
            if let label {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
            Text(formattedValue(value, suffix: suffix))
                .font(.system(
                    size: emphasized ? 16 : 14,
                    weight: emphasized ? .semibold : .medium,
                    design: .rounded
                ))
                .foregroundStyle(FoodTheme.textPrimary)
                .monospacedDigit()
        }
    }

    private var dot: some View {
        Circle()
            .fill(FoodTheme.textSecondary.opacity(0.4))
            .frame(width: 2.5, height: 2.5)
    }

    // MARK: - Helpers

    private func formattedValue(_ value: Double?, suffix: String) -> String {
        guard let value else { return "—" }
        let rounded = Int(value.rounded())
        return "\(rounded)\(suffix)"
    }

    private var accessibilityCopy: String {
        guard let kcal else { return "macros pending" }
        let p = proteinG.map { Int($0.rounded()) } ?? 0
        let c = carbsG.map { Int($0.rounded()) } ?? 0
        let f = fatG.map { Int($0.rounded()) } ?? 0
        return "\(Int(kcal.rounded())) calories, \(p)g protein, \(c)g carbs, \(f)g fat"
    }
}

// MARK: - Preview

#Preview("MacroRow") {
    VStack(spacing: 16) {
        MacroRow(kcal: 480, proteinG: 22, carbsG: 50, fatG: 18)
        MacroRow(kcal: 480, proteinG: 22, carbsG: 50, fatG: 18, emphasized: true)
        MacroRow(kcal: nil, proteinG: nil, carbsG: nil, fatG: nil)
    }
    .padding()
    .background(FoodTheme.bgPrimary)
}

#endif  // canImport(UIKit)
