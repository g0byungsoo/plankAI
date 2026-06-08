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

        // MARK: - v1.0.9 Theme A — micronutrient panel
        //
        // 10 cohort-relevant nutrients pulled from USDA FDC. All
        // values default to 0 when the lookup source doesn't have
        // them (USDA Foundation typically has all 10; Survey has
        // most; SR Legacy has fewer; canonical_pantry overrides may
        // populate only the ones a brand publishes).
        //
        // Units per USDA standard nutrient list:
        //   Vitamin A — µg RAE (retinol activity equivalent)
        //   Vitamin C — mg
        //   Vitamin D — µg
        //   Vitamin E — mg (alpha-tocopherol)
        //   Vitamin B12 — µg
        //   Calcium — mg
        //   Iron — mg
        //   Magnesium — mg
        //   Potassium — mg
        //   Zinc — mg

        public let vitaminAUgPer100g: Double      // 1106
        public let vitaminCMgPer100g: Double      // 1162
        public let vitaminDUgPer100g: Double      // 1114
        public let vitaminEMgPer100g: Double      // 1109
        public let vitaminB12UgPer100g: Double    // 1178
        public let calciumMgPer100g: Double       // 1087
        public let ironMgPer100g: Double          // 1089
        public let magnesiumMgPer100g: Double     // 1090
        public let potassiumMgPer100g: Double     // 1092
        public let zincMgPer100g: Double          // 1095

        public init(
            kcalPer100g: Double,
            proteinPer100g: Double = 0,
            carbsPer100g: Double = 0,
            fatPer100g: Double = 0,
            fiberPer100g: Double = 0,
            sugarPer100g: Double = 0,
            sodiumMgPer100g: Double = 0,
            saturatedFatPer100g: Double = 0,
            vitaminAUgPer100g: Double = 0,
            vitaminCMgPer100g: Double = 0,
            vitaminDUgPer100g: Double = 0,
            vitaminEMgPer100g: Double = 0,
            vitaminB12UgPer100g: Double = 0,
            calciumMgPer100g: Double = 0,
            ironMgPer100g: Double = 0,
            magnesiumMgPer100g: Double = 0,
            potassiumMgPer100g: Double = 0,
            zincMgPer100g: Double = 0
        ) {
            self.kcalPer100g = kcalPer100g
            self.proteinPer100g = proteinPer100g
            self.carbsPer100g = carbsPer100g
            self.fatPer100g = fatPer100g
            self.fiberPer100g = fiberPer100g
            self.sugarPer100g = sugarPer100g
            self.sodiumMgPer100g = sodiumMgPer100g
            self.saturatedFatPer100g = saturatedFatPer100g
            self.vitaminAUgPer100g = vitaminAUgPer100g
            self.vitaminCMgPer100g = vitaminCMgPer100g
            self.vitaminDUgPer100g = vitaminDUgPer100g
            self.vitaminEMgPer100g = vitaminEMgPer100g
            self.vitaminB12UgPer100g = vitaminB12UgPer100g
            self.calciumMgPer100g = calciumMgPer100g
            self.ironMgPer100g = ironMgPer100g
            self.magnesiumMgPer100g = magnesiumMgPer100g
            self.potassiumMgPer100g = potassiumMgPer100g
            self.zincMgPer100g = zincMgPer100g
        }

        // v1.0.9 Theme A — backwards-compat Codable. Entries written
        // before micronutrient fields existed decode with 0 for each
        // missing key. Same pattern as FoodLogPersister.Entry.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kcalPer100g    = try c.decode(Double.self, forKey: .kcalPer100g)
            proteinPer100g = (try? c.decode(Double.self, forKey: .proteinPer100g)) ?? 0
            carbsPer100g   = (try? c.decode(Double.self, forKey: .carbsPer100g)) ?? 0
            fatPer100g     = (try? c.decode(Double.self, forKey: .fatPer100g)) ?? 0
            fiberPer100g   = (try? c.decode(Double.self, forKey: .fiberPer100g)) ?? 0
            sugarPer100g   = (try? c.decode(Double.self, forKey: .sugarPer100g)) ?? 0
            sodiumMgPer100g = (try? c.decode(Double.self, forKey: .sodiumMgPer100g)) ?? 0
            saturatedFatPer100g = (try? c.decode(Double.self, forKey: .saturatedFatPer100g)) ?? 0
            vitaminAUgPer100g = (try? c.decode(Double.self, forKey: .vitaminAUgPer100g)) ?? 0
            vitaminCMgPer100g = (try? c.decode(Double.self, forKey: .vitaminCMgPer100g)) ?? 0
            vitaminDUgPer100g = (try? c.decode(Double.self, forKey: .vitaminDUgPer100g)) ?? 0
            vitaminEMgPer100g = (try? c.decode(Double.self, forKey: .vitaminEMgPer100g)) ?? 0
            vitaminB12UgPer100g = (try? c.decode(Double.self, forKey: .vitaminB12UgPer100g)) ?? 0
            calciumMgPer100g = (try? c.decode(Double.self, forKey: .calciumMgPer100g)) ?? 0
            ironMgPer100g = (try? c.decode(Double.self, forKey: .ironMgPer100g)) ?? 0
            magnesiumMgPer100g = (try? c.decode(Double.self, forKey: .magnesiumMgPer100g)) ?? 0
            potassiumMgPer100g = (try? c.decode(Double.self, forKey: .potassiumMgPer100g)) ?? 0
            zincMgPer100g = (try? c.decode(Double.self, forKey: .zincMgPer100g)) ?? 0
        }

        enum CodingKeys: String, CodingKey {
            case kcalPer100g, proteinPer100g, carbsPer100g, fatPer100g
            case fiberPer100g, sugarPer100g, sodiumMgPer100g, saturatedFatPer100g
            case vitaminAUgPer100g, vitaminCMgPer100g, vitaminDUgPer100g
            case vitaminEMgPer100g, vitaminB12UgPer100g
            case calciumMgPer100g, ironMgPer100g, magnesiumMgPer100g
            case potassiumMgPer100g, zincMgPer100g
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
