import Foundation

// MARK: - FoodCapture
//
// Pattern B (enum + associated values) per v3 §Architecture. Adding a
// new input mode = new case → compiler errors at every switch site =
// built-in TODO list. NO `FoodInputProvider` protocol until input mode
// #3 ships (v3 D27 "no abstraction until 3+ examples" rule — and even
// then only if the modes share enough surface to justify it).
//
// Three cases ship in v1.0.7:
//   - .photo with PhotoMode (D13 pre-eat toggle)
//   - .quickAdd via PantryItemID (cohort beverages rail, 6 tiles in v1.0.7)
//   - .imOutTonight with optional CuisineChip (D14 single-tap placeholder)
//
// Future plug-in slots architected but NOT implemented in v1.0.7:
// .barcode, .voice, .text, .menu (per v3 §Plug-in slots).

public enum FoodCapture: Sendable {
    case photo(Data, mode: PhotoMode)
    case quickAdd(PantryItemID)
    case imOutTonight(cuisine: CuisineChip?)

    // Future plug-in slots — uncomment when shipping each. Adding a
    // case here will break the dispatcher's switch, surfacing every
    // call site that needs updating.
    //
    // case barcode(String)
    // case voice(URL)
    // case text(String)
    // case menu(Data)
}

// MARK: - PhotoMode

/// D13 pre-eat toggle. Default is `.justAte` (retrospective log);
/// `.deciding` shows the result card with permission framing ("you
/// have room. easy yes.") instead of verdict framing.
public enum PhotoMode: String, Sendable, CaseIterable {
    case justAte
    case deciding
}

// MARK: - PantryItemID

/// Strongly-typed identifier for canonical_pantry rows. Wrapping a
/// String at the type level prevents accidental cross-table id mixing
/// (e.g. passing a food_log_id where a pantry_item_id is expected).
public struct PantryItemID: Sendable, Hashable {
    public let value: String
    public init(_ value: String) { self.value = value }
}

// MARK: - CuisineChip

/// Cuisine selector for D14 "i'm out tonight" mode. Refines the
/// placeholder estimate (mexican ~600, italian ~850, asian ~750,
/// american ~700, pizza ~900). Optional — tap "just log it" defaults
/// to a generic ~700 kcal placeholder.
public enum CuisineChip: String, Sendable, CaseIterable, Identifiable {
    case mexican
    case italian
    case asian
    case american
    case pizza
    case other

    public var id: String { rawValue }
}
