import XCTest
@testable import PlankFood

// MARK: - SnapResultMathTests
//
// v1.2 snap-food rebuild (2026-07-01) — the coherence contract, pinned.
// The category leader's most-documented credibility bug is edit math
// that doesn't add up (macro edits leaving calories frozen, totals
// disagreeing with their parts). Every rule the result card relies on
// is asserted here without a view in sight.

final class SnapResultMathTests: XCTestCase {

    // MARK: - Fixtures

    private func item(
        id: String = "a",
        name: String = "jeyuk bokkeum",
        grams: Double = 500,
        kcal: Double? = 1000,
        p: Double? = 80,
        c: Double? = 50,
        f: Double? = 40
    ) -> CapturedItem {
        CapturedItem(
            id: id, name: name,
            portionGrams: grams, portionGramsLow: grams * 0.8, portionGramsHigh: grams * 1.2,
            usdaSearchTerms: [name], preparation: nil, cuisineHint: nil,
            confidence: 0.85, notes: nil,
            kcal: kcal, proteinG: p, carbsG: c, fatG: f, fiberG: 5,
            nutritionSource: .llmDirect
        )
    }

    private func plate(_ items: [CapturedItem], lo: Double? = 950, hi: Double? = 1250) -> CapturedFood {
        CapturedFood(
            items: items, plateType: .mixed, source: .photo,
            confidence: 0.85, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: lo, kcalHigh: hi
        )
    }

    // MARK: - Atwater coherence

    func testKcalFromMacrosUsesAtwaterFactors() {
        // 4·30 + 4·40 + 9·20 = 120 + 160 + 180 = 460
        XCTAssertEqual(PlateMath.kcalFromMacros(protein: 30, carbs: 40, fat: 20), 460)
    }

    func testMacrosScaledPreservesShape() {
        // 80/50/40 → 4·80 + 4·50 + 9·40 = 880 kcal. Halving kcal halves each macro.
        let scaled = PlateMath.macrosScaled(toKcal: 440, protein: 80, carbs: 50, fat: 40)
        XCTAssertEqual(scaled.protein, 40, accuracy: 0.001)
        XCTAssertEqual(scaled.carbs, 25, accuracy: 0.001)
        XCTAssertEqual(scaled.fat, 20, accuracy: 0.001)
    }

    func testMacrosScaledWithZeroMacrosLeavesThemAlone() {
        let scaled = PlateMath.macrosScaled(toKcal: 300, protein: 0, carbs: 0, fat: 0)
        XCTAssertEqual(scaled.protein, 0)
        XCTAssertEqual(scaled.carbs, 0)
        XCTAssertEqual(scaled.fat, 0)
    }

    // MARK: - Physics clamp

    func testPhysicsClampTidiesImpossibleKcal() {
        // The "27-million-calorie candy bar": 50g of anything carries
        // at most max(400, 50·9 = 450) kcal.
        let absurd = item(grams: 50, kcal: 27_000_000, p: 2, c: 30, f: 10)
        let clamped = PlateEditSession.physicsClamped(absurd)
        XCTAssertTrue(clamped.adjusted)
        XCTAssertEqual(clamped.item.kcal ?? 0, 450, accuracy: 0.001)
    }

    func testPhysicsClampLeavesSaneValuesUntouched() {
        let sane = item(grams: 500, kcal: 1000, p: 80, c: 50, f: 40)
        let result = PlateEditSession.physicsClamped(sane)
        XCTAssertFalse(result.adjusted)
        XCTAssertEqual(result.item.kcal, 1000)
    }

    func testPhysicsClampBoundsMacrosByMass() {
        // 100g of food can't carry 400g of protein.
        let absurd = item(grams: 100, kcal: 400, p: 400, c: 10, f: 5)
        let clamped = PlateEditSession.physicsClamped(absurd)
        XCTAssertTrue(clamped.adjusted)
        XCTAssertEqual(clamped.item.proteinG ?? 0, 100, accuracy: 0.001)
    }

    // MARK: - Fraction ("ate about half") is non-destructive

    func testFractionScalesTotalsAndRestores() {
        var session = PlateEditSession(food: plate([item()]))
        let fullKcal = session.totals.kcal

        session.setFraction(0.5)
        XCTAssertEqual(session.totals.kcal, fullKcal * 0.5, accuracy: 0.01)
        XCTAssertEqual(session.totals.protein, 40, accuracy: 0.01)

        session.setFraction(1.0)
        XCTAssertEqual(session.totals.kcal, fullKcal, accuracy: 0.01)
        XCTAssertFalse(session.isPlateEdited)
    }

    func testFractionAppliesOnTopOfItemEdits() {
        var session = PlateEditSession(food: plate([item()]))
        session.stepPortion("a", up: false)   // 1.0 → 0.75 of the scan
        session.setFraction(0.5)
        // 1000 · 0.75 · 0.5 = 375
        XCTAssertEqual(session.totals.kcal, 375, accuracy: 0.5)
    }

    // MARK: - Portion stepper grid

    func testStepPortionMovesOneGridNotch() {
        var session = PlateEditSession(food: plate([item()]))
        session.stepPortion("a", up: true)    // 1.0 → 1.25
        XCTAssertEqual(session.item("a")?.portionGrams ?? 0, 625, accuracy: 0.5)
        XCTAssertEqual(session.item("a")?.kcal ?? 0, 1250, accuracy: 0.5)

        session.stepPortion("a", up: false)   // 1.25 → 1.0
        XCTAssertEqual(session.item("a")?.portionGrams ?? 0, 500, accuracy: 0.5)
        XCTAssertFalse(session.isEdited("a"))
    }

    func testStepPortionStopsAtGridBounds() {
        var session = PlateEditSession(food: plate([item()]))
        for _ in 0..<20 { session.stepPortion("a", up: false) }
        XCTAssertEqual(session.portionMultiplier("a"), 0.25, accuracy: 0.001)
        XCTAssertFalse(session.canStepPortion("a", up: false))
        XCTAssertTrue(session.canStepPortion("a", up: true))
    }

    func testNeighborSnapsOffGridValuesInTravelDirection() {
        // 1.1× sits between 1.0 and 1.25: down goes to 1.0, up to 1.25.
        XCTAssertEqual(PlateEditSession.neighbor(of: 1.1, up: false) ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(PlateEditSession.neighbor(of: 1.1, up: true) ?? 0, 1.25, accuracy: 0.001)
    }

    // MARK: - Replace / reset / edited provenance

    func testReplaceMarksEditedAndResetRestores() {
        var session = PlateEditSession(food: plate([item()]))
        XCTAssertFalse(session.isEdited("a"))

        let edited = item(kcal: 850, p: 70, c: 45, f: 35)
        session.replace(edited)
        XCTAssertTrue(session.isEdited("a"))
        XCTAssertTrue(session.isPlateEdited)

        session.resetItem("a")
        XCTAssertFalse(session.isEdited("a"))
        XCTAssertEqual(session.totals.kcal, 1000, accuracy: 0.01)
    }

    func testRemoveAndAppend() {
        var session = PlateEditSession(food: plate([item(), item(id: "b", name: "rice", grams: 180, kcal: 230, p: 4, c: 52, f: 0)]))
        session.remove("b")
        XCTAssertEqual(session.effectiveItems.count, 1)
        XCTAssertEqual(session.totals.kcal, 1000, accuracy: 0.01)

        let added = item(id: "c", name: "kimchi", grams: 60, kcal: 20, p: 1, c: 4, f: 0)
        session.append([added])
        XCTAssertEqual(session.effectiveItems.count, 2)
        // Appended items are their own baseline — not "edited".
        XCTAssertFalse(session.isEdited("c"))
    }

    // MARK: - Rebuilt plate honesty bounds

    func testRebuiltFoodScalesHonestyBoundsWithTotal() {
        var session = PlateEditSession(food: plate([item()], lo: 900, hi: 1100))
        session.setFraction(0.5)
        let rebuilt = session.rebuiltFood()
        XCTAssertEqual(rebuilt.kcalLow ?? 0, 450, accuracy: 0.5)
        XCTAssertEqual(rebuilt.kcalHigh ?? 0, 550, accuracy: 0.5)
        XCTAssertEqual(rebuilt.totalKcal ?? 0, 500, accuracy: 0.5)
    }

    func testRebaseAdoptsCorrectionAndClearsEdits() {
        var session = PlateEditSession(food: plate([item()]))
        session.setFraction(0.5)
        session.stepPortion("a", up: true)

        let corrected = plate([item(kcal: 700, p: 60, c: 40, f: 28)], lo: 650, hi: 750)
        session.rebase(on: corrected)
        XCTAssertFalse(session.isPlateEdited)
        XCTAssertEqual(session.totals.kcal, 700, accuracy: 0.01)
    }
}
