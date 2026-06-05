#if canImport(UIKit)
import SwiftUI

// MARK: - MixedPlateCard
//
// Result card for `plate_type: mixed | charcuterie | shared |
// restaurant_range` — anything with multiple items or a restaurant-
// scale range estimate. Composes ItemRow per item + plate-level
// NutrientGrid + JeniLine + RestaurantRangeBar (when range data
// present) per v5 §Calorie scan Screen 3.
//
// D54 (2026-06-05): pre-eat / just-ate mode collapsed (see
// SingleDishCard for rationale). One unified layout.
//
// Renders gracefully when items are kcal-nil (USDA join pending) —
// per-item rows show with portion only; aggregate macros show "—".

public struct MixedPlateCard: View {

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

            // Hero — restaurant range bar when the source produced a range
            // (.imOut / .restaurantEstimate), otherwise plate-total ConfidencePill.
            if let low = food.kcalLow, let high = food.kcalHigh {
                RestaurantRangeBar(kcalLow: low, kcalHigh: high)
            } else if let total = food.totalKcal {
                ConfidencePill(
                    kcal: total,
                    kcalLow: nil,
                    kcalHigh: nil
                )
            } else {
                Text("reading the plate…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary)
            }

            // Per-item rows — tap-to-edit each.
            VStack(spacing: 0) {
                ForEach(food.items) { item in
                    ItemRow(
                        name: item.name,
                        portionGrams: item.portionGrams,
                        confidence: item.confidence,
                        onTap: { onItemTap(item) }
                    )
                    if item.id != food.items.last?.id {
                        Divider()
                            .overlay(FoodTheme.accentSubtle.opacity(0.5))
                    }
                }
            }

            // Plate-aggregated nutrients across all items.
            NutrientGrid(
                kcal: food.totalKcal,
                proteinG: food.items.compactMap(\.proteinG).reduce(0, +).optionalNonZero,
                carbsG: food.items.compactMap(\.carbsG).reduce(0, +).optionalNonZero,
                fatG: food.items.compactMap(\.fatG).reduce(0, +).optionalNonZero,
                fiberG: food.items.compactMap(\.fiberG).reduce(0, +).optionalNonZero,
                sugarG: food.items.compactMap(\.sugarG).reduce(0, +).optionalNonZero,
                sodiumMg: food.items.compactMap(\.sodiumMg).reduce(0, +).optionalNonZero,
                saturatedFatG: food.items.compactMap(\.saturatedFatG).reduce(0, +).optionalNonZero
            )

            // Jeni interpretation. D54: single unified copy via
            // SingleDishCard.synthesizeJeniLine (shared between
            // single + mixed plate layouts).
            if let copy = SingleDishCard.synthesizeJeniLine(for: food) {
                JeniLine(copy)
            }

            // Second-photo hint, if the LLM flagged it.
            if food.needsSecondPhoto, let hint = food.secondPhotoHint {
                secondPhotoTip(hint)
            }

            Divider()
                .overlay(FoodTheme.accentSubtle)

            actionButtons
        }
        .padding(FoodTheme.Space.lg)
        .background(FoodTheme.bgElevated)
        // Scrapbook chrome per v5 D37 — see SingleDishCard for rationale.
        .clipShape(RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous)
                .stroke(FoodTheme.accent.opacity(0.5), lineWidth: FoodTheme.Stroke.scrapbook)
        )
        .shadow(color: FoodTheme.textPrimary.opacity(0.2), radius: 0, x: 3, y: 3)
        // Sticker overlay — different emoji from SingleDishCard so
        // result-card variants visually differ at a glance.
        .overlay(alignment: .topTrailing) {
            Text("✨")
                .font(.system(size: 28))
                .rotationEffect(.degrees(-12))
                .offset(x: 6, y: -10)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Subviews

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

    @ViewBuilder
    private func secondPhotoTip(_ hint: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.rotate")
                .font(.system(size: 14))
                .foregroundStyle(FoodTheme.accent)
            Text(hint)
                .font(.system(size: 13))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(FoodTheme.accentSubtle.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

}

// MARK: - Helpers

private extension Double {
    /// Treat 0 as nil for macro display — when no items resolved
    /// kcal yet, summing returns 0 which would render as "0g" and
    /// confuse the user. Better to show "—" until at least one item
    /// has data.
    var optionalNonZero: Double? {
        self > 0 ? self : nil
    }
}

// MARK: - Preview

#Preview("MixedPlateCard — multiple items") {
    MixedPlateCard(
        food: .previewMixed(),
        primaryAction: { print("log") },
        secondaryAction: { print("skip") },
        onItemTap: { _ in print("tap") }
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

#Preview("MixedPlateCard — restaurant range") {
    MixedPlateCard(
        food: .previewRestaurantRange(),
        primaryAction: { },
        secondaryAction: { },
        onItemTap: { _ in }
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

#Preview("MixedPlateCard — needs second photo") {
    MixedPlateCard(
        food: .previewNeedsSecondPhoto(),
        primaryAction: { },
        secondaryAction: { },
        onItemTap: { _ in }
    )
    .padding()
    .background(FoodTheme.bgPrimary)
}

// MARK: - Preview helpers

extension CapturedFood {
    static func previewMixed() -> CapturedFood {
        CapturedFood(
            items: [
                CapturedItem(
                    id: "1", name: "gouda cheese",
                    portionGrams: 40, portionGramsLow: 30, portionGramsHigh: 50,
                    usdaSearchTerms: ["gouda"], preparation: nil, cuisineHint: nil,
                    confidence: 0.85, notes: nil,
                    kcal: 142, proteinG: 10, carbsG: 1, fatG: 11, fiberG: 0,
                    nutritionSource: .usdaFDC
                ),
                CapturedItem(
                    id: "2", name: "water *crackers*",
                    portionGrams: 30, portionGramsLow: 25, portionGramsHigh: 40,
                    usdaSearchTerms: ["water crackers"], preparation: nil, cuisineHint: nil,
                    confidence: 0.78, notes: nil,
                    kcal: 123, proteinG: 3, carbsG: 24, fatG: 2, fiberG: 1,
                    nutritionSource: .usdaFDC
                ),
                CapturedItem(
                    id: "3", name: "red grapes",
                    portionGrams: 80, portionGramsLow: 60, portionGramsHigh: 100,
                    usdaSearchTerms: ["red grapes"], preparation: "raw", cuisineHint: nil,
                    confidence: 0.91, notes: nil,
                    kcal: 55, proteinG: 1, carbsG: 14, fatG: 0, fiberG: 1,
                    nutritionSource: .usdaFDC
                ),
            ],
            plateType: .charcuterie,
            source: .photo,
            confidence: 0.78,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )
    }

    static func previewRestaurantRange() -> CapturedFood {
        CapturedFood(
            items: [],
            plateType: .restaurantRange,
            source: .restaurantEstimate,
            confidence: nil,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: 700,
            kcalHigh: 900
        )
    }

    static func previewNeedsSecondPhoto() -> CapturedFood {
        var food = previewMixed()
        food = CapturedFood(
            items: food.items,
            plateType: food.plateType,
            source: food.source,
            confidence: food.confidence,
            needsSecondPhoto: true,
            secondPhotoHint: "shoot from 45° to estimate rice depth",
            kcalLow: nil,
            kcalHigh: nil
        )
        return food
    }
}

#endif  // canImport(UIKit)
