import Foundation

// MARK: - CalorieMathService
//
// **LOAD-BEARING ALGORITHM** (v3 §Architecture).
//
// The pure-function math behind every food-rail kcal/macro number the
// user sees. Per v3 §Architecture, this is the JeniFit equivalent of
// Things 3's conflict-resolution algorithm — protected by a code
// review gate (any PR touching this file requires explicit founder
// review).
//
// Hard rules:
//   - Pure functions. No state. No mutation. Same input = same output.
//   - Zero UIKit, zero AVFoundation, zero networking.
//   - Defensive against bad input (negative grams, low > high). Clamp,
//     don't crash.
//   - Range propagates through kcal ONLY. Macros use the center
//     estimate (per v5: macros are noisy enough already; range
//     fan-out would be over-precision theater).
//
// Inputs (from upstream pipelines):
//   - LLM-identified portion grams (single OR low/high range)
//   - Per-100g nutrition density from USDA FDC / Open Food Facts /
//     canonical_pantry (W2-T4 NutritionLookupService produces these)
//
// Outputs (consumed by CapturedFood / UI):
//   - Per-item nutrition (kcal + range + macros)
//   - Plate-level totals (sum across items)

public enum CalorieMathService {

    // MARK: - NutritionDensity

    /// Per-100g nutrition values from a single source (USDA, OFF, or
    /// canonical pantry row). Macro fields default to 0 if unknown —
    /// preferable to nil because aggregation with nils requires
    /// special-casing and 0g is the honest "no data" reading.
    public struct NutritionDensity: Sendable, Equatable, Codable {
        public let kcalPer100g: Double
        public let proteinPer100g: Double
        public let carbsPer100g: Double
        public let fatPer100g: Double
        public let fiberPer100g: Double
        /// Sugars, total (g per 100g). Added 2026-06-05 — cohort
        /// research said sugar awareness > saturated-fat awareness.
        public let sugarPer100g: Double
        /// Sodium per 100g, expressed in MILLIGRAMS (not grams) — sodium
        /// values are always quoted in mg in nutrition labels + USDA,
        /// keeps the unit consistent end-to-end. 100g of bacon ≈ 1000mg.
        public let sodiumMgPer100g: Double
        /// Saturated fat, g per 100g. Secondary surface (only shown
        /// in expanded view in NutrientGrid).
        public let saturatedFatPer100g: Double

        public init(
            kcalPer100g: Double,
            proteinPer100g: Double = 0,
            carbsPer100g: Double = 0,
            fatPer100g: Double = 0,
            fiberPer100g: Double = 0,
            sugarPer100g: Double = 0,
            sodiumMgPer100g: Double = 0,
            saturatedFatPer100g: Double = 0
        ) {
            self.kcalPer100g = kcalPer100g
            self.proteinPer100g = proteinPer100g
            self.carbsPer100g = carbsPer100g
            self.fatPer100g = fatPer100g
            self.fiberPer100g = fiberPer100g
            self.sugarPer100g = sugarPer100g
            self.sodiumMgPer100g = sodiumMgPer100g
            self.saturatedFatPer100g = saturatedFatPer100g
        }
    }

    // MARK: - ItemNutrition

    /// Per-item nutrition output. `kcal` is the point estimate from
    /// `portionGrams × kcalPer100g / 100`. `kcalLow/kcalHigh` are the
    /// range from `portion_grams_low/high` (collapses to the point
    /// estimate when no range was provided by the LLM).
    public struct ItemNutrition: Sendable, Equatable {
        public let kcal: Double
        public let kcalLow: Double
        public let kcalHigh: Double
        public let proteinG: Double
        public let carbsG: Double
        public let fatG: Double
        public let fiberG: Double
        public let sugarG: Double
        public let sodiumMg: Double
        public let saturatedFatG: Double
    }

    // MARK: - Per-item compute

    /// Compute one item's nutrition from portion grams + density.
    ///
    /// Range propagation:
    ///   - `portionGramsLow ?? portionGrams` × density = `kcalLow`
    ///   - `portionGramsHigh ?? portionGrams` × density = `kcalHigh`
    ///   - Macros use the point estimate (`portionGrams`).
    ///
    /// Defensive clamps:
    ///   - All portion values clamped to ≥ 0 (negative grams = clamp to 0).
    ///   - `kcalHigh` clamped to ≥ `kcalLow` (inverted ranges get
    ///     normalized to a degenerate point at the higher value).
    public static func compute(
        portionGrams: Double,
        portionGramsLow: Double? = nil,
        portionGramsHigh: Double? = nil,
        density: NutritionDensity
    ) -> ItemNutrition {
        // Clamp to non-negative.
        let g = max(portionGrams, 0)
        var gLow = max(portionGramsLow ?? portionGrams, 0)
        var gHigh = max(portionGramsHigh ?? portionGrams, 0)
        // Normalize inverted range (e.g. LLM hallucinated low > high).
        if gHigh < gLow {
            let mid = (gLow + gHigh) / 2
            gLow = mid
            gHigh = mid
        }

        return ItemNutrition(
            kcal:          g * density.kcalPer100g / 100,
            kcalLow:       gLow * density.kcalPer100g / 100,
            kcalHigh:      gHigh * density.kcalPer100g / 100,
            proteinG:      g * density.proteinPer100g / 100,
            carbsG:        g * density.carbsPer100g / 100,
            fatG:          g * density.fatPer100g / 100,
            fiberG:        g * density.fiberPer100g / 100,
            sugarG:        g * density.sugarPer100g / 100,
            sodiumMg:      g * density.sodiumMgPer100g / 100,
            saturatedFatG: g * density.saturatedFatPer100g / 100
        )
    }

    // MARK: - PlateNutrition

    /// Plate-level totals. `totalKcalLow/totalKcalHigh` are the sum of
    /// per-item lows / highs respectively — NOT a confidence interval.
    /// (Genuine confidence-interval propagation would require knowing
    /// per-item correlation, which we don't.)
    public struct PlateNutrition: Sendable, Equatable {
        public let totalKcal: Double
        public let totalKcalLow: Double
        public let totalKcalHigh: Double
        public let totalProteinG: Double
        public let totalCarbsG: Double
        public let totalFatG: Double
        public let totalFiberG: Double
        public let totalSugarG: Double
        public let totalSodiumMg: Double
        public let totalSaturatedFatG: Double

        public static let zero = PlateNutrition(
            totalKcal: 0,
            totalKcalLow: 0,
            totalKcalHigh: 0,
            totalProteinG: 0,
            totalCarbsG: 0,
            totalFatG: 0,
            totalFiberG: 0,
            totalSugarG: 0,
            totalSodiumMg: 0,
            totalSaturatedFatG: 0
        )
    }

    // MARK: - Aggregate

    /// Sum item-level nutrition into plate totals. Empty items list
    /// returns `PlateNutrition.zero` (not an error — a result card
    /// with no recognized items is a valid mid-flight state).
    public static func aggregate(_ items: [ItemNutrition]) -> PlateNutrition {
        guard !items.isEmpty else { return .zero }

        return PlateNutrition(
            totalKcal:           items.reduce(0) { $0 + $1.kcal },
            totalKcalLow:        items.reduce(0) { $0 + $1.kcalLow },
            totalKcalHigh:       items.reduce(0) { $0 + $1.kcalHigh },
            totalProteinG:       items.reduce(0) { $0 + $1.proteinG },
            totalCarbsG:         items.reduce(0) { $0 + $1.carbsG },
            totalFatG:           items.reduce(0) { $0 + $1.fatG },
            totalFiberG:         items.reduce(0) { $0 + $1.fiberG },
            totalSugarG:         items.reduce(0) { $0 + $1.sugarG },
            totalSodiumMg:       items.reduce(0) { $0 + $1.sodiumMg },
            totalSaturatedFatG:  items.reduce(0) { $0 + $1.saturatedFatG }
        )
    }
}
