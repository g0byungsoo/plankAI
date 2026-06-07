#if canImport(UIKit)
import SwiftUI

// MARK: - ConfidencePill
//
// Title: straightforward "N Calories" — founder direction 2026-06-07.
// The earlier "around N" doubled with the Jeni line below the card
// ("this is around N — fits") so the number appeared twice. Title
// now carries the number cleanly; uncertainty/honesty stays in the
// qualifier line + the Jeni interpretation underneath.
//
// Qualifier line variants by uncertainty range (computed from
// portionGramsLow/High / portionGrams ratio):
//
//   wide (>30% spread)   → "give or take a bit"
//   medium (15-30%)      → "give or take a slice" / "give or take a sip"
//   tight (<15%)         → "this looks right"
//
// Why "Calories" not "cal": founder direction. Capital C matches
// how the cohort sees it on packaging + CalAI/competitor apps —
// recognizable unit, no parsing required.

public struct ConfidencePill: View {

    public let kcal: Double
    public let kcalLow: Double?
    public let kcalHigh: Double?
    public var unit: String  // e.g. "slice", "sip", "bite"

    public init(
        kcal: Double,
        kcalLow: Double? = nil,
        kcalHigh: Double? = nil,
        unit: String = "slice"
    ) {
        self.kcal = kcal
        self.kcalLow = kcalLow
        self.kcalHigh = kcalHigh
        self.unit = unit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(Int(kcal.rounded())) Calories")
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(FoodTheme.textPrimary)

            Text(qualifierCopy)
                .font(.system(size: 13))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int(kcal.rounded())) calories, \(qualifierCopy)")
    }

    // MARK: - Copy

    private var qualifierCopy: String {
        guard let low = kcalLow, let high = kcalHigh, high > 0 else {
            return "this looks right"
        }
        let center = (low + high) / 2
        guard center > 0 else { return "this looks right" }
        let spread = (high - low) / center

        switch spread {
        case ..<0.15: return "this looks right"
        case 0.15..<0.30: return "give or take a \(unit)"
        default: return "give or take a bit"
        }
    }
}

// MARK: - Preview

#Preview("ConfidencePill") {
    VStack(alignment: .leading, spacing: 28) {
        ConfidencePill(kcal: 480, kcalLow: 460, kcalHigh: 500)   // tight
        ConfidencePill(kcal: 480, kcalLow: 420, kcalHigh: 560, unit: "slice")   // medium
        ConfidencePill(kcal: 480, kcalLow: 350, kcalHigh: 650)   // wide
        ConfidencePill(kcal: 200)                                // no range
    }
    .padding()
    .background(FoodTheme.bgPrimary)
}

#endif  // canImport(UIKit)
