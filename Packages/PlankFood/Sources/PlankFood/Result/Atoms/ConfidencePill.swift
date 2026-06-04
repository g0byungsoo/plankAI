#if canImport(UIKit)
import SwiftUI

// MARK: - ConfidencePill
//
// Per v5 D23 Honesty Doctrine + §Calorie scan Screen 3:
// **uncertainty is in COPY, not in a percentage**.
//
// "around 480, give or take a slice" — anti-CalAI signature.
// Cal AI shows "85% confident" which reads as overconfident-tech.
// "give or take" reads as honest-friend.
//
// Copy variants by uncertainty range (computed from
// portionGramsLow/High / portionGrams ratio):
//
//   wide (>30% spread)   → "give or take a bit"
//   medium (15-30%)      → "give or take a slice" / "give or take a sip"
//   tight (<15%)         → "this looks right"
//
// The kcal centerpiece value is the headline. The qualifier line
// below it carries the honesty.

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
            Text("around \(Int(kcal.rounded()))")
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(FoodTheme.textPrimary)

            Text(qualifierCopy)
                .font(.system(size: 13))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("around \(Int(kcal.rounded())) calories, \(qualifierCopy)")
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
