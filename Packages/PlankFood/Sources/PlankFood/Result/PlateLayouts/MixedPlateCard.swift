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

    @State private var showMacros: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: FoodTheme.Space.lg) {

            // Defensive empty-state — see SingleDishCard for rationale.
            // Restaurant-range source can produce items=[] legitimately
            // (kcalLow/High carry the data), so empty-items is only the
            // fail mode when ALSO kcalLow == nil.
            if food.items.isEmpty && food.kcalLow == nil {
                emptyStatePanel
            }

            // 2026-06-06 — feeling-word hero reverted per founder
            // direction. ConfidencePill back as the visible hero for
            // plate-total flows; RestaurantRangeBar still wins for the
            // imOut estimator path. See SingleDishCard for the full
            // rationale.
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

            // Macros hidden behind a tap — see SingleDishCard A.4
            // for rationale. NutrientGrid sums across all plate items.
            if food.totalKcal != nil {
                plateMacrosDisclosure
            }

            // Jeni interpretation. D54: single unified copy via
            // SingleDishCard.synthesizeJeniLine (shared between
            // single + mixed plate layouts).
            if let copy = SingleDishCard.synthesizeJeniLine(for: food) {
                JeniLine(copy)
            }

            // tell me *more* ♥ — routes the user to the per-item
            // correction sheet via the first item. v1.0.8 will swap
            // for the inline conversation.
            if let item = food.items.first {
                tellMeMoreLink(item: item)
            }

            // Second-photo hint, if the LLM flagged it.
            if food.needsSecondPhoto, let hint = food.secondPhotoHint {
                secondPhotoTip(hint)
            }

            Divider()
                .overlay(FoodTheme.accentSubtle)

            if food.items.isEmpty && food.kcalLow == nil {
                emptyStateActions
            } else {
                actionButtons
            }
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
        // v1.0.7 Phase E sticker discipline — cherries emoji per the
        // luxury brief sticker-family mapping (cherries = food). Was
        // ✨ (sparkle/lessons family — mis-categorized). Both single
        // + mixed plate cards now share the food sticker family;
        // mixed-vs-single is conveyed by content (item count caption),
        // not by sticker variant. v1.0.8: bundle the brand cherries
        // 3D asset into PlankFood and swap to Image(name:).
        .overlay(alignment: .topTrailing) {
            Text("🍒")
                .font(.system(size: 28))
                .rotationEffect(.degrees(-10))
                .offset(x: 6, y: -10)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Feeling-word hero (v1.0.7 Phase A.4)

    /// Plate-total feeling-word hero. Same five-bucket scheme as
    /// SingleDishCard.feelingWord(forKcal:). Plate caption uses item
    /// count instead of a single meal name ("3 things on your plate").
    @ViewBuilder
    private func plateFeelingHero(totalKcal: Double) -> some View {
        let feeling = SingleDishCard.feelingWord(forKcal: totalKcal)
        let plateCaption: String = {
            let n = food.items.count
            if n == 0 { return "your plate" }
            if n == 1 { return "1 thing on your plate" }
            return "\(n) things on your plate"
        }()

        VStack(alignment: .leading, spacing: 6) {
            (Text(feeling)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 32))
                .foregroundStyle(FoodTheme.textPrimary)
             + Text(" ♥")
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(FoodTheme.accent))

            Text(plateCaption)
                .font(.custom("Fraunces72pt-Regular", size: 17))
                .foregroundStyle(FoodTheme.textSecondary)

            HStack(spacing: 4) {
                Text("around \(Int(totalKcal.rounded())) cal")
                    .font(.system(size: 13))
                    .foregroundStyle(FoodTheme.textSecondary)
                Text("·")
                    .font(.system(size: 13))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.6))
                (Text("fits")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    .foregroundStyle(FoodTheme.accent)
                 + Text(" ♥")
                    .font(.system(size: 13))
                    .foregroundStyle(FoodTheme.accent))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feeling), \(plateCaption), around \(Int(totalKcal.rounded())) calories, fits")
    }

    @ViewBuilder
    private var plateMacrosDisclosure: some View {
        VStack(alignment: .leading, spacing: FoodTheme.Space.sm) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    showMacros.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(showMacros ? "hide macros" : "show macros")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FoodTheme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(FoodTheme.textSecondary.opacity(0.7))
                        .rotationEffect(.degrees(showMacros ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if showMacros {
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func tellMeMoreLink(item: CapturedItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onItemTap(item)
        } label: {
            HStack(spacing: 6) {
                Text("tell me")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FoodTheme.textPrimary)
                (Text("more")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
                    .foregroundStyle(FoodTheme.accent)
                 + Text(" ♥")
                    .font(.system(size: 15))
                    .foregroundStyle(FoodTheme.accent))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FoodTheme.accent.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(FoodTheme.accentSubtle.opacity(0.45))
            .overlay(
                Capsule().stroke(FoodTheme.accent.opacity(0.35), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    // MARK: - Empty state

    @ViewBuilder private var emptyStatePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("couldn't read this one")
                .font(.custom("Fraunces72pt-SemiBold", size: 22))
                .foregroundStyle(FoodTheme.textPrimary)
            Text("no food made it through — too dark, too blurry, or maybe nothing on the plate yet. let's try again.")
                .font(.system(size: 14))
                .foregroundStyle(FoodTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, FoodTheme.Space.sm)
    }

    @ViewBuilder private var emptyStateActions: some View {
        Button(action: secondaryAction) {
            Text("retake →")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FoodTheme.bgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(FoodTheme.textPrimary))
        }
    }

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
