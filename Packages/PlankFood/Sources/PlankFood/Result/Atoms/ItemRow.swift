#if canImport(UIKit)
import SwiftUI

// MARK: - ItemRow
//
// Per v5 §Calorie scan Screen 3: single item line on the result
// card. Renders food name with italic Fraunces on punch words
// (driven by *asterisks* in the name string), portion grams as a
// subtle suffix, and an optional uncertainty hint pulled from
// `ConfidencePill` if confidence is provided.
//
// Tap action surfaces the FoodCorrectionSheet (W3-T5) where the user
// can edit portion or swap the identification. Default tap target
// is 44pt min height per HIG.

public struct ItemRow: View {

    public let name: String
    public let portionGrams: Double
    public let confidence: Double?
    public let onTap: (() -> Void)?

    public init(
        name: String,
        portionGrams: Double,
        confidence: Double? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.name = name
        self.portionGrams = portionGrams
        self.confidence = confidence
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: FoodTheme.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    let parsed = ItalicAccentText.parseAsterisks(name)
                    ItalicAccentText(
                        parsed.base,
                        italic: parsed.italic,
                        baseFont: .custom("Fraunces72pt-Regular", size: 17),
                        italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 17),
                        color: FoodTheme.textPrimary
                    )

                    Text(Self.formatPortion(portionGrams))
                        .font(.system(size: 13))
                        .foregroundStyle(FoodTheme.textSecondary)
                }

                Spacer(minLength: 0)

                if let confidence, confidence < 0.7 {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(FoodTheme.textSecondary)
                        .accessibilityLabel("uncertain")
                }
            }
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    /// "350g" / "0.5 cup" formatting will live here when units shift
    /// per v1.0.8. For v1.0.7 we ship grams-only — matches USDA's
    /// per-100g density model directly.
    static func formatPortion(_ grams: Double) -> String {
        let rounded = Int(grams.rounded())
        return "\(rounded)g"
    }
}

// MARK: - Preview

#Preview("ItemRow") {
    VStack(spacing: 0) {
        ItemRow(
            name: "creamy *carbonara*",
            portionGrams: 320,
            confidence: 0.85
        ) { print("tapped") }

        Divider()

        ItemRow(
            name: "matcha *latte* with oat",
            portionGrams: 350,
            confidence: 0.92
        ) { print("tapped") }

        Divider()

        ItemRow(
            name: "*something* unrecognized",
            portionGrams: 200,
            confidence: 0.4
        ) { print("tapped") }
    }
    .padding()
    .background(FoodTheme.bgPrimary)
}

#endif  // canImport(UIKit)
