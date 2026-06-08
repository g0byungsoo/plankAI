#if canImport(UIKit)
import SwiftUI

// MARK: - ResultCard
//
// Thin router that picks the right plate layout based on the
// CapturedFood's plate_type. Centralizes the dispatch so call sites
// (PhotoCaptureView, FoodCorrectionSheet preview, etc.) don't switch
// on plate_type at every render site.
//
// Per v3 D27 / v5 §Architecture: hand-written switch (no generic
// `ResultCardRenderer<PlateType>`) until plate type #4 lands as a
// distinct layout. Today we have 2 layouts covering 6 plate types
// — the redundancy is fine.

public struct ResultCard: View {

    public let food: CapturedFood
    /// v1.0.8 Phase E (2026-06-07) — primaryAction now receives the
    /// (potentially corrected) food. SingleDishCard supports in-place
    /// calorie corrections via the "correct me ♥" pill row; tapping
    /// "log it" persists the CORRECTED CapturedFood, not the original.
    /// MixedPlateCard passes the food through unchanged.
    public let primaryAction: (CapturedFood) -> Void
    public let secondaryAction: () -> Void
    public let onItemTap: (CapturedItem) -> Void

    public init(
        food: CapturedFood,
        primaryAction: @escaping (CapturedFood) -> Void,
        secondaryAction: @escaping () -> Void,
        onItemTap: @escaping (CapturedItem) -> Void
    ) {
        self.food = food
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.onItemTap = onItemTap
    }

    public var body: some View {
        switch food.plateType {
        case .single, .bowl:
            SingleDishCard(
                food: food,
                primaryAction: primaryAction,
                secondaryAction: secondaryAction,
                onItemTap: onItemTap
            )

        case .mixed, .charcuterie, .shared, .restaurantRange:
            MixedPlateCard(
                food: food,
                primaryAction: primaryAction,
                secondaryAction: secondaryAction,
                onItemTap: onItemTap
            )
        }
    }
}

#endif  // canImport(UIKit)
