import Foundation

/// PlankFood — JeniFit's food rail module. Camera capture, vision-model
/// pipeline, nutrition lookup, and result rendering for the AI calorie
/// tracking feature shipping in v1.0.7.
///
/// Source-of-truth for design: `docs/food_rail_plan.md` (v5 wins where
/// conflicting). Sprint breakdown: `docs/food_rail_sprint_v1_0_7.md`.
///
/// Module entry surfaces (filled in as W2-W5 tickets land):
/// - `Capture/` — FoodCapture enum + CapturedFood + FoodCaptureDispatcher (W2-T1);
///                PhotoCaptureView (W2-T2), QuickAddView (W3-T3), ImOutTonightView (W3-T4)
/// - `Pipeline/` — FoodVisionService + NutritionLookupService + CalorieMathService
/// - `Model/` — FoodLog (SwiftData @Model, VersionedSchema v1)
/// - `Result/` — 6 atomic Views + 2 plate layout Views
/// - `Tiles/` — HomeFoodTile
/// - `Flags/` — FoodFlags 3-layer flag stack (W1-T4 ✓)
public enum PlankFood {
    public static let version = "0.1.0-scaffold"
}
