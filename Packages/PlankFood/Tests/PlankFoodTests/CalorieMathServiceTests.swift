import XCTest
@testable import PlankFood

final class CalorieMathServiceTests: XCTestCase {

    typealias Service = CalorieMathService
    typealias Density = CalorieMathService.NutritionDensity
    typealias Item = CalorieMathService.ItemNutrition
    typealias Plate = CalorieMathService.PlateNutrition

    // MARK: - Canonical-pantry density fixtures
    //
    // Pinned to the values we expect to seed into the canonical_pantry
    // table at launch. Real entries come from official restaurant menus
    // or USDA. These fixtures aren't the source of truth for the actual
    // table — they're the test inputs to validate the math against
    // known outputs.

    private let matchaLatteOat = Density(
        kcalPer100g: 60,   // 350g serving = 210 kcal (Starbucks matcha latte w/ oat milk grande)
        proteinPer100g: 1.5,
        carbsPer100g: 8.0,
        fatPer100g: 2.4,
        fiberPer100g: 0.2
    )

    private let everythingBagel = Density(
        kcalPer100g: 250,
        proteinPer100g: 10,
        carbsPer100g: 50,
        fatPer100g: 1.5,
        fiberPer100g: 3.0
    )

    private let goudaCheese = Density(
        kcalPer100g: 356,
        proteinPer100g: 25,
        carbsPer100g: 2.2,
        fatPer100g: 27,
        fiberPer100g: 0
    )

    private let salami = Density(
        kcalPer100g: 336,
        proteinPer100g: 22,
        carbsPer100g: 1.5,
        fatPer100g: 27,
        fiberPer100g: 0
    )

    private let grapesRed = Density(
        kcalPer100g: 69,
        proteinPer100g: 0.7,
        carbsPer100g: 18,
        fatPer100g: 0.2,
        fiberPer100g: 0.9
    )

    private let waterCrackers = Density(
        kcalPer100g: 410,
        proteinPer100g: 9,
        carbsPer100g: 80,
        fatPer100g: 6,
        fiberPer100g: 3
    )

    // MARK: - 1. Per-item basic compute

    func test_compute_zeroPortionReturnsZeroEverything() {
        let r = Service.compute(portionGrams: 0, density: matchaLatteOat)
        XCTAssertEqual(r.kcal, 0)
        XCTAssertEqual(r.kcalLow, 0)
        XCTAssertEqual(r.kcalHigh, 0)
        XCTAssertEqual(r.proteinG, 0)
        XCTAssertEqual(r.fatG, 0)
        XCTAssertEqual(r.carbsG, 0)
        XCTAssertEqual(r.fiberG, 0)
    }

    func test_compute_100gAtKnownDensityIsExact() {
        let r = Service.compute(portionGrams: 100, density: matchaLatteOat)
        XCTAssertEqual(r.kcal,     60,  accuracy: 0.001)
        XCTAssertEqual(r.proteinG, 1.5, accuracy: 0.001)
        XCTAssertEqual(r.carbsG,   8.0, accuracy: 0.001)
        XCTAssertEqual(r.fatG,     2.4, accuracy: 0.001)
        XCTAssertEqual(r.fiberG,   0.2, accuracy: 0.001)
    }

    func test_compute_fractionalPortionScalesLinearly() {
        let r = Service.compute(portionGrams: 50, density: everythingBagel)
        XCTAssertEqual(r.kcal,     125,  accuracy: 0.001)
        XCTAssertEqual(r.proteinG, 5.0,  accuracy: 0.001)
        XCTAssertEqual(r.carbsG,   25.0, accuracy: 0.001)
        XCTAssertEqual(r.fatG,     0.75, accuracy: 0.001)
    }

    func test_compute_matchaLatte350gMatchesExpected210kcal() {
        // Canonical pantry test case: Starbucks matcha latte grande.
        // 350g × 60 kcal/100g = 210 kcal.
        let r = Service.compute(portionGrams: 350, density: matchaLatteOat)
        XCTAssertEqual(r.kcal, 210, accuracy: 0.5)
    }

    func test_compute_largePortionLinearity() {
        let r = Service.compute(portionGrams: 1000, density: matchaLatteOat)
        XCTAssertEqual(r.kcal, 600, accuracy: 0.001)
    }

    // MARK: - 2. Range propagation

    func test_compute_pointEstimateCollapsesToEqualLowHigh() {
        let r = Service.compute(portionGrams: 200, density: matchaLatteOat)
        XCTAssertEqual(r.kcalLow, r.kcal)
        XCTAssertEqual(r.kcalHigh, r.kcal)
    }

    func test_compute_explicitRangeProducesDistinctLowHigh() {
        let r = Service.compute(
            portionGrams: 100,
            portionGramsLow: 80,
            portionGramsHigh: 120,
            density: matchaLatteOat
        )
        XCTAssertEqual(r.kcal,     60,  accuracy: 0.001)
        XCTAssertEqual(r.kcalLow,  48,  accuracy: 0.001)   // 80 × 60 / 100
        XCTAssertEqual(r.kcalHigh, 72,  accuracy: 0.001)   // 120 × 60 / 100
    }

    func test_compute_rangeOnlyAffectsKcalNotMacros() {
        // v3: macros use the point estimate even when range provided.
        let r = Service.compute(
            portionGrams: 100,
            portionGramsLow: 50,
            portionGramsHigh: 200,
            density: everythingBagel
        )
        // Macros from point estimate (100g):
        XCTAssertEqual(r.proteinG, 10, accuracy: 0.001)
        XCTAssertEqual(r.carbsG,   50, accuracy: 0.001)
        // kcal ranges:
        XCTAssertEqual(r.kcalLow,  125, accuracy: 0.001)
        XCTAssertEqual(r.kcalHigh, 500, accuracy: 0.001)
    }

    // MARK: - 3. Defensive clamping

    func test_compute_negativePortionClampsToZero() {
        let r = Service.compute(portionGrams: -100, density: matchaLatteOat)
        XCTAssertEqual(r.kcal, 0)
        XCTAssertEqual(r.proteinG, 0)
    }

    func test_compute_negativeRangeBoundClampsToZero() {
        let r = Service.compute(
            portionGrams: 100,
            portionGramsLow: -50,
            portionGramsHigh: 150,
            density: matchaLatteOat
        )
        XCTAssertEqual(r.kcalLow, 0,  accuracy: 0.001)
        XCTAssertEqual(r.kcalHigh, 90, accuracy: 0.001)
    }

    func test_compute_invertedRangeCollapsesToMidpoint() {
        // LLM hallucinated low > high — defensive normalization
        // collapses to the midpoint (a degenerate point estimate).
        let r = Service.compute(
            portionGrams: 100,
            portionGramsLow: 150,
            portionGramsHigh: 80,
            density: matchaLatteOat
        )
        let mid = (150.0 + 80.0) / 2
        XCTAssertEqual(r.kcalLow,  mid * 60 / 100, accuracy: 0.001)
        XCTAssertEqual(r.kcalHigh, mid * 60 / 100, accuracy: 0.001)
        XCTAssertEqual(r.kcalLow, r.kcalHigh)
    }

    // MARK: - 4. Density defaults

    func test_density_defaultsAllMacrosToZero() {
        let d = Density(kcalPer100g: 200)
        XCTAssertEqual(d.proteinPer100g, 0)
        XCTAssertEqual(d.carbsPer100g,   0)
        XCTAssertEqual(d.fatPer100g,     0)
        XCTAssertEqual(d.fiberPer100g,   0)
    }

    func test_density_equatable() {
        let a = Density(kcalPer100g: 200, proteinPer100g: 10, carbsPer100g: 20, fatPer100g: 5)
        let b = Density(kcalPer100g: 200, proteinPer100g: 10, carbsPer100g: 20, fatPer100g: 5)
        XCTAssertEqual(a, b)
    }

    // MARK: - 5. Aggregate

    func test_aggregate_emptyListReturnsZero() {
        XCTAssertEqual(Service.aggregate([]), Plate.zero)
    }

    func test_aggregate_singleItemMatchesItem() {
        let item = Service.compute(portionGrams: 100, density: matchaLatteOat)
        let plate = Service.aggregate([item])
        XCTAssertEqual(plate.totalKcal,     item.kcal)
        XCTAssertEqual(plate.totalKcalLow,  item.kcalLow)
        XCTAssertEqual(plate.totalKcalHigh, item.kcalHigh)
        XCTAssertEqual(plate.totalProteinG, item.proteinG)
    }

    func test_aggregate_girlDinnerSumsCorrectly() {
        // 60g cheese + 30g crackers + 50g grapes
        let cheese = Service.compute(portionGrams: 60, density: goudaCheese)
        let crackers = Service.compute(portionGrams: 30, density: waterCrackers)
        let grapes = Service.compute(portionGrams: 50, density: grapesRed)

        let plate = Service.aggregate([cheese, crackers, grapes])

        // 60×356/100 + 30×410/100 + 50×69/100 = 213.6 + 123 + 34.5 = 371.1
        XCTAssertEqual(plate.totalKcal, 371.1, accuracy: 0.1)
    }

    func test_aggregate_charcuteriePlateFiveItems() {
        // Realistic charcuterie scrap: 40g gouda + 25g salami +
        // 30g crackers + 80g grapes + 15g extra cheese
        let items = [
            Service.compute(portionGrams: 40, density: goudaCheese),
            Service.compute(portionGrams: 25, density: salami),
            Service.compute(portionGrams: 30, density: waterCrackers),
            Service.compute(portionGrams: 80, density: grapesRed),
            Service.compute(portionGrams: 15, density: goudaCheese),
        ]
        let plate = Service.aggregate(items)

        // Hand-computed: 142.4 + 84 + 123 + 55.2 + 53.4 = 458
        XCTAssertEqual(plate.totalKcal, 458, accuracy: 1.0)
    }

    func test_aggregate_rangeSumIsLowSumAndHighSum() {
        // Two items with ranges. Plate range = sum of lows / sum of highs.
        let itemA = Service.compute(
            portionGrams: 100,
            portionGramsLow: 80,
            portionGramsHigh: 120,
            density: matchaLatteOat
        )
        let itemB = Service.compute(
            portionGrams: 50,
            portionGramsLow: 40,
            portionGramsHigh: 60,
            density: everythingBagel
        )
        let plate = Service.aggregate([itemA, itemB])

        XCTAssertEqual(plate.totalKcalLow,
                       itemA.kcalLow + itemB.kcalLow, accuracy: 0.001)
        XCTAssertEqual(plate.totalKcalHigh,
                       itemA.kcalHigh + itemB.kcalHigh, accuracy: 0.001)
    }

    func test_aggregate_macrosSumAcrossItems() {
        let bagel = Service.compute(portionGrams: 100, density: everythingBagel)
        let cheese = Service.compute(portionGrams: 30, density: goudaCheese)
        let plate = Service.aggregate([bagel, cheese])

        XCTAssertEqual(plate.totalProteinG, 10 + 7.5, accuracy: 0.001)
        XCTAssertEqual(plate.totalCarbsG,   50 + 0.66, accuracy: 0.01)
        XCTAssertEqual(plate.totalFatG,     1.5 + 8.1, accuracy: 0.01)
        XCTAssertEqual(plate.totalFiberG,   3.0 + 0, accuracy: 0.001)
    }

    // MARK: - 6. Purity / determinism

    func test_pure_sameInputProducesSameOutput() {
        // Run the same compute twice and compare. If state ever crept
        // in, this will fail with non-deterministic output.
        let r1 = Service.compute(portionGrams: 100, density: everythingBagel)
        let r2 = Service.compute(portionGrams: 100, density: everythingBagel)
        XCTAssertEqual(r1, r2)
    }

    func test_pure_aggregateDeterminism() {
        let items = [
            Service.compute(portionGrams: 50, density: matchaLatteOat),
            Service.compute(portionGrams: 100, density: everythingBagel),
        ]
        let p1 = Service.aggregate(items)
        let p2 = Service.aggregate(items)
        XCTAssertEqual(p1, p2)
    }
}
