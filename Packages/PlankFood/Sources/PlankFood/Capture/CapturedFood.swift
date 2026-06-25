import Foundation

// MARK: - CapturedFood
//
// Common output type returned by FoodCaptureDispatcher for every
// FoodCapture variant. The result card renders the same shape
// regardless of capture source — that's the seam that lets the UI
// stay simple while the pipelines stay specialized.
//
// Mirrors the LLM response schema in supabase/functions/food-vision/
// index.ts (FOOD_VISION_SCHEMA) but with USDA-joined kcal/macros
// populated where available. The .quickAdd and .imOutTonight paths
// produce CapturedFood with kcal already known (from canonical_pantry
// or rule-based estimate); the .photo path produces CapturedFood where
// kcal lands after the USDA join completes app-side.

public struct CapturedFood: Sendable {
    public let items: [CapturedItem]
    public let plateType: PlateType
    public let source: CaptureSource
    public let confidence: Double?       // 0...1, nil for non-LLM sources
    public let needsSecondPhoto: Bool
    public let secondPhotoHint: String?  // nil unless needsSecondPhoto
    /// Range fields for `.imOutTonight` / `.restaurantRange` sources.
    /// nil for single-value sources. Per v3 §Honesty Doctrine:
    /// uncertainty is in COPY, not in a %, but range data drives the
    /// RestaurantRangeBar atom.
    public let kcalLow: Double?
    public let kcalHigh: Double?

    public init(
        items: [CapturedItem],
        plateType: PlateType,
        source: CaptureSource,
        confidence: Double?,
        needsSecondPhoto: Bool,
        secondPhotoHint: String?,
        kcalLow: Double?,
        kcalHigh: Double?
    ) {
        self.items = items
        self.plateType = plateType
        self.source = source
        self.confidence = confidence
        self.needsSecondPhoto = needsSecondPhoto
        self.secondPhotoHint = secondPhotoHint
        self.kcalLow = kcalLow
        self.kcalHigh = kcalHigh
    }

    /// Sum of all items' kcal. nil if any item is missing kcal (the
    /// USDA join hasn't completed for at least one). Caller can show
    /// a loading state until non-nil.
    public var totalKcal: Double? {
        // Empty items means "no plate identified" — return nil so
        // consumers can distinguish from "plate identified, totals
        // zero." Without this guard the reduce(0, +) returned 0 for
        // both cases, which can mask the empty-capture failure path
        // downstream (caught by EmptyCaptureGuardTests 2026-06-05).
        guard !items.isEmpty else { return nil }
        let kcalValues = items.compactMap { $0.kcal }
        guard kcalValues.count == items.count else { return nil }
        return kcalValues.reduce(0, +)
    }
}

// MARK: - CapturedItem

public struct CapturedItem: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let portionGrams: Double
    public let portionGramsLow: Double
    public let portionGramsHigh: Double
    /// USDA search terms ordered specific → generic. Populated by LLM
    /// for .photo source; empty for .quickAdd (already resolved via
    /// PantryItemID) and .imOutTonight (no item-level data).
    public let usdaSearchTerms: [String]
    public let preparation: String?
    public let cuisineHint: String?
    public let confidence: Double?
    public let notes: String?

    /// Populated after the USDA join completes. nil during the
    /// streaming-result-card phase.
    public let kcal: Double?
    public let proteinG: Double?
    public let carbsG: Double?
    public let fatG: Double?
    public let fiberG: Double?
    /// 2026-06-05 — extra nutrients the cohort cares about (per
    /// founder on-device feedback: P/C/F alone reads MFP-era).
    public let sugarG: Double?
    public let sodiumMg: Double?
    public let saturatedFatG: Double?

    /// Lookup source attribution — which DB answered when the join
    /// completes. nil until then.
    public let nutritionSource: NutritionSource?

    /// 2026-06-23 accuracy fields (populated by the food-vision EF once
    /// deployed; nil on legacy/pre-deploy responses, so all of these are
    /// optional + safe to ignore until the EF ships them).
    /// - englishName: plain-english gloss when `name` is a native dish
    ///   name (e.g. name "bulgogi", englishName "marinated grilled beef").
    /// - count + unit: the visible quantity ("5" + "piece"). nil or
    ///   count<=1 means a single/continuous serving.
    /// - servingsInDish: how many standard servings the WHOLE visible
    ///   food is, for the shared-food split (nil ⇒ treat as 1).
    /// - isShareable: a whole/shared dish the user can apply their share
    ///   to (whole pizza, platter). nil/false = a single personal serving.
    public let englishName: String?
    public let count: Int?
    public let unit: String?
    public let servingsInDish: Int?
    public let isShareable: Bool?

    public init(
        id: String,
        name: String,
        portionGrams: Double,
        portionGramsLow: Double,
        portionGramsHigh: Double,
        usdaSearchTerms: [String],
        preparation: String?,
        cuisineHint: String?,
        confidence: Double?,
        notes: String?,
        kcal: Double?,
        proteinG: Double?,
        carbsG: Double?,
        fatG: Double?,
        fiberG: Double?,
        nutritionSource: NutritionSource?,
        sugarG: Double? = nil,
        sodiumMg: Double? = nil,
        saturatedFatG: Double? = nil,
        englishName: String? = nil,
        count: Int? = nil,
        unit: String? = nil,
        servingsInDish: Int? = nil,
        isShareable: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.portionGrams = portionGrams
        self.portionGramsLow = portionGramsLow
        self.portionGramsHigh = portionGramsHigh
        self.usdaSearchTerms = usdaSearchTerms
        self.preparation = preparation
        self.cuisineHint = cuisineHint
        self.confidence = confidence
        self.notes = notes
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.nutritionSource = nutritionSource
        self.sugarG = sugarG
        self.sodiumMg = sodiumMg
        self.saturatedFatG = saturatedFatG
        self.englishName = englishName
        self.count = count
        self.unit = unit
        self.servingsInDish = servingsInDish
        self.isShareable = isShareable
    }
}

// MARK: - PlateType

/// Raw values match the strings the Edge Function returns (per
/// `FOOD_VISION_SCHEMA.properties.plate_type.enum` in
/// supabase/functions/food-vision/index.ts). Renaming a case here
/// requires a matching enum update in the schema + a release migration.
public enum PlateType: String, Sendable, CaseIterable {
    case single
    case mixed
    case bowl
    case charcuterie
    case shared
    case restaurantRange = "restaurant_range"
}

// MARK: - CaptureSource

/// Mirrors the `source` CHECK constraint on the food_logs Supabase
/// table. Adding a case here requires a matching ALTER TABLE on the
/// CHECK list — surface that in a migration when expanding plug-in
/// slots.
public enum CaptureSource: String, Sendable, CaseIterable {
    case photo
    case quickAdd       = "quick_add"
    case imOut          = "im_out"
    case restaurantEstimate = "restaurant_estimate"
    case barcode
    case voice
    case text
    case menu
}

// MARK: - NutritionSource

/// Which path produced the per-item kcal/macros. Tracked for
/// telemetry and the v1.0.8+ correction flywheel.
///
/// Three families:
///
/// - **Lookup-produced** — the original W2-T4 path. The LLM returned
///   portion grams only and `AppSideNutritionLookup` joined per-100g
///   density from `canonical_pantry` / `usda_fdc` / `open_food_facts`.
///   Still hit when the LLM returns `kcal == nil` (no longer the
///   default after v1.0.7 direct-kcal rewrite, but the fallback path
///   stays for resilience).
///
/// - **LLM-direct** (v1.0.7+) — the new default. `food-vision` Edge
///   Function returns kcal + macros directly from GPT-5 vision; no
///   USDA join needed. Marked `.llmDirect` for telemetry.
///
/// - **Hybrid calibrated** (v1.0.7+) — for low-confidence LLM items
///   (< 0.5), `FoodCaptureDispatcher.enrich` runs the USDA lookup as
///   a sanity check. If the USDA estimate sits within ±30% of the
///   LLM kcal, the LLM number is kept and tagged `.usdaCalibrated`
///   (we trust the model, but flagged the check ran). If drift
///   exceeds ±30%, the USDA number wins and the item is tagged
///   `.usdaOverride` so the cohort analyst sees how often LLM
///   accuracy drifts on ambiguous items.
public enum NutritionSource: String, Sendable, Codable, Hashable, CaseIterable {
    case usdaFDC = "usda_fdc"
    case openFoodFacts = "open_food_facts"
    case canonicalPantry = "canonical_pantry"
    case ruleBasedEstimate = "rule_based_estimate"
    /// LLM returned kcal + macros directly; no USDA join attempted
    /// (high-confidence path, v1.0.7+ default).
    case llmDirect = "llm_direct"
    /// LLM returned kcal; USDA lookup ran as a sanity check and
    /// agreed within ±30%. Kept LLM number, flagged the check.
    case usdaCalibrated = "usda_calibrated"
    /// LLM returned kcal; USDA lookup disagreed by >±30%. USDA
    /// number wins, LLM number logged for the correction flywheel.
    case usdaOverride = "usda_override"
}
