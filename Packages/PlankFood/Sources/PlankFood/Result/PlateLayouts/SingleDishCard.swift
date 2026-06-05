#if canImport(UIKit)
import SwiftUI

// MARK: - SingleDishCard
//
// Result card layout for `plate_type: single | bowl` — when the LLM
// identifies one dominant food (e.g. "creamy carbonara" or "açaí
// bowl"). Composes ItemRow + ConfidencePill + NutrientGrid + JeniLine
// per v5 §Calorie scan Screen 3.
//
// D54 (2026-06-05): pre-eat / just-ate mode collapsed. The card has
// one unified layout. Jeni's copy line carries permission framing
// regardless of whether the user took the photo pre-eat or mid-meal.
// Primary CTA "log it" + secondary "actually skip →" let the user
// decide intent AFTER seeing the result, not before the photo.

public struct SingleDishCard: View {

    public let food: CapturedFood
    public let primaryAction: () -> Void
    public let secondaryAction: () -> Void
    public let onItemTap: (CapturedItem) -> Void

    public init(
        food: CapturedFood,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
        onItemTap: @escaping (CapturedItem) -> Void
    ) {
        self.food = food
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
                    NutrientGrid(
                        kcal: item.kcal,
                        proteinG: item.proteinG,
                        carbsG: item.carbsG,
                        fatG: item.fatG,
                        fiberG: item.fiberG,
                        sugarG: item.sugarG,
                        sodiumMg: item.sodiumMg,
                        saturatedFatG: item.saturatedFatG
                    )
                }
            }

            // Jeni interpretation line. D54: single unified copy that
            // lands as permission OR verdict depending on the context
            // the user brings (pre-eat or mid-meal — only the user
            // knows which).
            if let jeniCopy = Self.synthesizeJeniLine(for: food) {
                JeniLine(jeniCopy)
            }

            Divider()
                .overlay(FoodTheme.accentSubtle)

            // CTAs.
            actionButtons
        }
        .padding(FoodTheme.Space.lg)
        .background(FoodTheme.bgElevated)
        // Scrapbook chrome per v5 D37 + feedback_visual_richness_over_restraint:
        // 1.5pt accent border + hard offset shadow (radius:0, x/y:3)
        // gives the y2k-coquette weight WITHOUT relying on bitmap
        // stickers. Subtle by itself; loud when combined with the
        // sticker overlay below.
        .clipShape(RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous)
                .stroke(FoodTheme.accent.opacity(0.5), lineWidth: FoodTheme.Stroke.scrapbook)
        )
        .shadow(color: FoodTheme.textPrimary.opacity(0.2), radius: 0, x: 3, y: 3)
        // Sticker scatter — flower3D emoji rotated and offset to read
        // as a hand-placed scrapbook accent. Decorative only, hidden
        // from VoiceOver.
        .overlay(alignment: .topTrailing) {
            Text("🌸")
                .font(.system(size: 32))
                .rotationEffect(.degrees(15))
                .offset(x: 8, y: -12)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Action buttons

    @ViewBuilder private var actionButtons: some View {
        VStack(spacing: FoodTheme.Space.sm) {
            Button(action: primaryAction) {
                Text("log it")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(FoodTheme.textPrimary))
            }

            Button(action: secondaryAction) {
                Text("actually skip →")
                    .font(.system(size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
        }
    }

    // MARK: - Copy

    /// Unified Jeni copy — lands as permission OR verdict depending
    /// on the user's context (only they know if they ate it or are
    /// deciding). Real per-item interpretation will come from the
    /// GPT-5 system prompt later; this is the voice-locked fallback
    /// when the upstream pipeline doesn't inject anything custom.
    ///
    /// Voice locked: no banned vocabulary, italic on punch word,
    /// heart as terminal punctuation.
    static func synthesizeJeniLine(for food: CapturedFood) -> String? {
        guard food.items.first != nil else { return nil }
        if let kcal = food.items.first?.kcal {
            return "this is around \(Int(kcal.rounded())) — *fits*. easy yes if you want it. ♥"
        }
        return "this *fits*. easy yes if you want it. ♥"
    }
}

// MARK: - Preview

#Preview("SingleDishCard — logged data") {
    SingleDishCard(
        food: .preview(),
        primaryAction: { print("log it") },
        secondaryAction: { print("actually skip") },
        onItemTap: { _ in print("tap item") }
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

#Preview("SingleDishCard — USDA pending") {
    SingleDishCard(
        food: .previewPending(),
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
