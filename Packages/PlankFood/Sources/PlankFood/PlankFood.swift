import Foundation

/// PlankFood — JeniFit's food rail module. Camera capture, vision-model
/// pipeline, nutrition lookup, and result rendering for the AI calorie
/// tracking feature shipping in v1.0.7.
///
/// Source-of-truth for design: `docs/food_rail_plan.md` (v5 wins where
/// conflicting). Sprint breakdown: `docs/food_rail_sprint_v1_0_7.md`.
///
/// Module entry surfaces (filled in as W2-W5 tickets land):
/// - `Capture/` — FoodCapture enum + PhotoCaptureView + QuickAddView + ImOutTonightView
/// - `Pipeline/` — FoodVisionService + NutritionLookupService + CalorieMathService
/// - `Model/` — FoodLog (SwiftData @Model, VersionedSchema v1)
/// - `Result/` — 6 atomic Views + 2 plate layout Views
/// - `Tiles/` — HomeFoodTile
/// - `Flags/` — FoodFlags 3-layer flag stack
public enum PlankFood {
    public static let version = "0.1.0-scaffold"
}

// MARK: - FoodCapture (W2-T1 foundation)
//
// Pattern B (enum + associated values) per v3 §Architecture. Adding a new
// input mode = new case → compiler errors at every switch site = built-in
// TODO list. NO `FoodInputProvider` protocol until input mode #3 ships
// (v3 D27 "no abstraction until 3+ examples" rule).

public enum FoodCapture: Sendable {
    case photo(Data, mode: PhotoMode)
    case quickAdd(PantryItemID)
    case imOutTonight(cuisine: CuisineChip?)

    // Future plug-in slots — architected for, NOT implemented in v1.0.7
    // (per v5 §Plug-in slots). Uncomment when shipping each.
    //
    // case barcode(String)
    // case voice(URL)
    // case text(String)
    // case menu(Data)
}

public enum PhotoMode: String, Sendable, CaseIterable {
    case justAte
    case deciding
}

public struct PantryItemID: Sendable, Hashable {
    public let value: String
    public init(_ value: String) { self.value = value }
}

public enum CuisineChip: String, Sendable, CaseIterable {
    case mexican
    case italian
    case asian
    case american
    case pizza
    case other
}
