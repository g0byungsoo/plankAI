#if canImport(UIKit)
import SwiftUI

// MARK: - SingleDishCard
//
// Result card layout for `plate_type: single | bowl` — when the LLM
// identifies one dominant food (e.g. "creamy carbonara" or "açaí
// bowl"). Composes ItemRow + ConfidencePill + MacroRow + JeniLine
// per v5 §Calorie scan Screen 3.
//
// Two visual modes driven by `mode`:
//   .justAte    → verdict frame: "looks good — log it" primary CTA
//                 + "fix something" secondary. Macros emphasized.
//   .deciding   → permission frame: "you have *room* today" Jeni
//                 line + "have it" primary + "save for later"
//                 secondary (per v5 D8 — "skip this one" removed
//                 because it moralized the binary).

public struct SingleDishCard: View {

    public let food: CapturedFood
    public let mode: PhotoMode
    public let primaryAction: () -> Void
    public let secondaryAction: () -> Void
    public let onItemTap: (CapturedItem) -> Void

    public init(
        food: CapturedFood,
        mode: PhotoMode,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
        onItemTap: @escaping (CapturedItem) -> Void
    ) {
        self.food = food
        self.mode = mode
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.onItemTap = onItemTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FoodTheme.Space.lg) {
            // Hero: kcal + uncertainty copy.
            if let item = food.items.first, let kcal = item.kcal {
                ConfidencePill(
                    kcal: kcal,
                    kcalLow: nil,
                    kcalHigh: nil
                )
            } else if food.totalKcal == nil {
                // USDA join pending — show name only, kcal lands when it does.
                if let item = food.items.first {
                    Text(ItalicAccentText.parseAsterisks(item.name).base)
                        .font(.custom("Fraunces72pt-SemiBold", size: 24))
                        .foregroundStyle(FoodTheme.textPrimary)
                    Text("reading the plate…")
                        .font(.system(size: 13))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
            }

            // The item itself — tap to edit.
            if let item = food.items.first {
                ItemRow(
                    name: item.name,
                    portionGrams: item.portionGrams,
                    confidence: item.confidence,
                    onTap: { onItemTap(item) }
                )

                if item.kcal != nil {
                    MacroRow(
                        kcal: item.kcal,
                        proteinG: item.proteinG,
                        carbsG: item.carbsG,
                        fatG: item.fatG,
                        emphasized: true
                    )
                }
            }

            // Jeni interpretation line.
            if mode == .deciding {
                JeniLine(decidingCopy)
            } else if let jeniCopy = Self.synthesizeJeniLine(for: food) {
                JeniLine(jeniCopy)
            }

            Divider()
                .overlay(FoodTheme.accentSubtle)

            // CTAs.
            actionButtons
        }
        .padding(FoodTheme.Space.lg)
        .background(FoodTheme.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous)
                .stroke(FoodTheme.textPrimary.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous))
    }

    // MARK: - Action buttons

    @ViewBuilder private var actionButtons: some View {
        VStack(spacing: FoodTheme.Space.sm) {
            Button(action: primaryAction) {
                Text(mode == .deciding ? "have it" : "looks good — log it")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(FoodTheme.textPrimary))
            }

            Button(action: secondaryAction) {
                Text(mode == .deciding ? "save for later →" : "fix something →")
                    .font(.system(size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
        }
    }

    // MARK: - Copy

    /// Pre-eat mode permission frame. Eventually personalized with
    /// the user's day total ("you're at 1,100 today — you have room").
    /// For W3-T2 we show the canonical voice-locked line; W4-T1 wires
    /// real day-total data.
    private var decidingCopy: String {
        if let kcal = food.items.first?.kcal {
            return "this is around \(Int(kcal.rounded())). you have *room*. easy yes. ♥"
        }
        return "you have *room*. easy yes. ♥"
    }

    /// Fallback Jeni line when the upstream pipeline hasn't injected
    /// one. Real interpretation lands from the GPT-5 system prompt
    /// in W2-T3 (when it includes per-item Jeni copy in the response
    /// — TBD whether that lives in the LLM call or a separate model
    /// step). For now: gentle filler that matches voice locks.
    static func synthesizeJeniLine(for food: CapturedFood) -> String? {
        guard food.items.first != nil else { return nil }
        // Voice locked: no banned vocabulary, italic on punch word,
        // heart as terminal punctuation.
        return "logged. *tomorrow* resets. ♥"
    }
}

// MARK: - Preview

#Preview("SingleDishCard — just ate") {
    SingleDishCard(
        food: .preview(),
        mode: .justAte,
        primaryAction: { print("log it") },
        secondaryAction: { print("fix it") },
        onItemTap: { _ in print("tap item") }
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

#Preview("SingleDishCard — deciding") {
    SingleDishCard(
        food: .preview(),
        mode: .deciding,
        primaryAction: { print("have it") },
        secondaryAction: { print("save for later") },
        onItemTap: { _ in print("tap item") }
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

#Preview("SingleDishCard — USDA pending") {
    SingleDishCard(
        food: .previewPending(),
        mode: .justAte,
        primaryAction: { },
        secondaryAction: { },
        onItemTap: { _ in }
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

// MARK: - Preview helpers

extension CapturedFood {
    static func preview() -> CapturedFood {
        CapturedFood(
            items: [
                CapturedItem(
                    id: "1",
                    name: "creamy *carbonara*",
                    portionGrams: 320,
                    portionGramsLow: 280,
                    portionGramsHigh: 360,
                    usdaSearchTerms: ["carbonara", "pasta with cream sauce"],
                    preparation: "boiled",
                    cuisineHint: "italian",
                    confidence: 0.87,
                    notes: nil,
                    kcal: 480,
                    proteinG: 22,
                    carbsG: 50,
                    fatG: 18,
                    fiberG: 2,
                    nutritionSource: .canonicalPantry
                )
            ],
            plateType: .single,
            source: .photo,
            confidence: 0.87,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )
    }

    static func previewPending() -> CapturedFood {
        CapturedFood(
            items: [
                CapturedItem(
                    id: "1",
                    name: "*matcha* latte with oat",
                    portionGrams: 350,
                    portionGramsLow: 300,
                    portionGramsHigh: 400,
                    usdaSearchTerms: ["matcha latte"],
                    preparation: nil,
                    cuisineHint: "japanese",
                    confidence: 0.92,
                    notes: nil,
                    kcal: nil, proteinG: nil, carbsG: nil, fatG: nil, fiberG: nil,
                    nutritionSource: nil
                )
            ],
            plateType: .single,
            source: .photo,
            confidence: 0.92,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )
    }
}

#endif  // canImport(UIKit)
