import XCTest
@testable import PlankFood

// MARK: - PlatePriorsTests (v25 E4 — THE PLATE'S MEMORY)
//
// The corrections flywheel's law, pinned: only corrected dishes build
// priors; matching is exact on the normalized title; application is a
// uniform, revertible scale; printed truth and agreeing scans are
// never touched.

final class PlatePriorsTests: XCTestCase {

    private func item(
        _ id: String, _ name: String,
        grams: Double = 150, kcal: Double = 300,
        p: Double = 20, c: Double = 30, f: Double = 10
    ) -> CapturedItem {
        CapturedItem(
            id: id, name: name,
            portionGrams: grams, portionGramsLow: grams * 0.8,
            portionGramsHigh: grams * 1.2,
            usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
            confidence: 0.8, notes: nil,
            kcal: kcal, proteinG: p, carbsG: c, fatG: f, fiberG: 4,
            nutritionSource: .llmDirect
        )
    }

    private func plate(
        _ items: [CapturedItem], source: CaptureSource = .photo
    ) -> CapturedFood {
        CapturedFood(
            items: items, plateType: .single, source: source,
            confidence: 0.8, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
    }

    private func obs(
        _ title: String, kcal: Double, corrected: Bool = true,
        daysAgo: Double = 1
    ) -> PlatePriors.Observation {
        PlatePriors.Observation(
            title: title, kcal: kcal, proteinG: 40,
            corrected: corrected,
            at: Date(timeIntervalSinceNow: -daysAgo * 86_400)
        )
    }

    // — normalize

    func testNormalizeStripsTheMoreSuffixAndCase() {
        XCTAssertEqual(
            PlatePriors.normalize("Chicken Burrito + 2 more"),
            "chicken burrito"
        )
        XCTAssertEqual(PlatePriors.normalize("  Pad Thai.  "), "pad thai")
    }

    // — index

    func testOnlyCorrectedRowsBuildPriors() {
        let index = PlatePriors.index([
            obs("chicken burrito", kcal: 700, corrected: true),
            obs("greek salad", kcal: 300, corrected: false),
        ])
        XCTAssertNotNil(index["chicken burrito"])
        XCTAssertNil(index["greek salad"])
    }

    func testLatestCorrectionWins() {
        let index = PlatePriors.index([
            obs("pho", kcal: 500, daysAgo: 9),
            obs("pho", kcal: 620, daysAgo: 1),
        ])
        XCTAssertEqual(index["pho"]?.kcal, 620)
        XCTAssertEqual(index["pho"]?.timesCorrected, 2)
    }

    // — apply

    func testApplyScalesTheWholePlateToHerNumber() {
        let food = plate([
            item("a", "chicken burrito", grams: 200, kcal: 400, p: 25),
            item("b", "chips", grams: 50, kcal: 100, p: 2),
        ])
        let index = PlatePriors.index([obs("chicken burrito + 1 more", kcal: 750)])
        let out = PlatePriors.apply(to: food, index: index)
        XCTAssertNotNil(out.priorApplied)
        XCTAssertEqual(out.totalKcal ?? 0, 750, accuracy: 0.01)
        // Coherence: macros + portions ride the same factor (1.5).
        XCTAssertEqual(out.items[0].proteinG ?? 0, 37.5, accuracy: 0.01)
        XCTAssertEqual(out.items[0].portionGrams, 300, accuracy: 0.01)
    }

    func testAgreementWithinBandLeavesThePlateAlone() {
        let food = plate([item("a", "chicken burrito", kcal: 700)])
        let index = PlatePriors.index([obs("chicken burrito", kcal: 750)])
        let out = PlatePriors.apply(to: food, index: index)
        XCTAssertNil(out.priorApplied)
        XCTAssertEqual(out.totalKcal ?? 0, 700, accuracy: 0.01)
    }

    func testNoPriorNoTouch() {
        let food = plate([item("a", "brand new dish", kcal: 400)])
        let out = PlatePriors.apply(to: food, index: [:])
        XCTAssertNil(out.priorApplied)
    }

    func testBarcodeIsPrintedTruth() {
        let food = plate([item("a", "protein bar", kcal: 190)], source: .barcode)
        let index = PlatePriors.index([obs("protein bar", kcal: 300)])
        XCTAssertNil(PlatePriors.apply(to: food, index: index).priorApplied)
    }

    func testAbsurdFactorRefuses() {
        // Family-size lasagna prior vs a single-slice scan: the same
        // name is not the same plate. Refuse rather than distort.
        let food = plate([item("a", "lasagna", kcal: 300)])
        let index = PlatePriors.index([obs("lasagna", kcal: 2_400)])
        XCTAssertNil(PlatePriors.apply(to: food, index: index).priorApplied)
    }

    func testNeverAppliesTwice() {
        let food = plate([item("a", "pho", kcal: 400)])
        let index = PlatePriors.index([obs("pho", kcal: 600)])
        let once = PlatePriors.apply(to: food, index: index)
        let twice = PlatePriors.apply(to: once, index: index)
        XCTAssertEqual(once.totalKcal ?? 0, twice.totalKcal ?? 0, accuracy: 0.01)
    }

    // — revert

    func testRevertRestoresTheModelExactly() {
        let food = plate([item("a", "pho", grams: 320, kcal: 400, p: 22)])
        let index = PlatePriors.index([obs("pho", kcal: 600)])
        let applied = PlatePriors.apply(to: food, index: index)
        let reverted = PlatePriors.revert(applied)
        XCTAssertNil(reverted.priorApplied)
        XCTAssertEqual(reverted.totalKcal ?? 0, 400, accuracy: 0.01)
        XCTAssertEqual(reverted.items[0].portionGrams, 320, accuracy: 0.01)
        XCTAssertEqual(reverted.items[0].proteinG ?? 0, 22, accuracy: 0.01)
    }

    func testRevertWithoutAPriorIsInert() {
        let food = plate([item("a", "pho", kcal: 400)])
        XCTAssertEqual(
            PlatePriors.revert(food).totalKcal ?? 0, 400, accuracy: 0.01
        )
    }

    // — the correction dissolves the prior (her words outrank her
    //   old numbers): pinned at the SnapRefine seam via the struct's
    //   own contract here.

    func testCorrectionsRideTheRebuiltPlate() {
        var food = plate([item("a", "pho", kcal: 400)])
        food.appliedCorrections = ["extra noodles"]
        var session = PlateEditSession(food: food)
        session.setFraction(0.5)
        let rebuilt = session.rebuiltFood()
        XCTAssertEqual(rebuilt.appliedCorrections, ["extra noodles"])
    }
}
