import XCTest
@testable import PlankFood

// MARK: - PlateEnergyRecordTests (p61)
//
// ONE LAW: **the record holds the number the reading showed her.**
//
// It did not. `SnapResultView.displayKcal` spoke one rule (the items
// price the plate; the model's band is the estimate only when there
// are no items to price; round to 5 because precision theatre is
// dishonest at ±20% model accuracy) and `FoodLogPersister.persist`
// spoke another (if the model returned a band at all, store its
// MIDPOINT). `total_kcal_low` / `total_kcal_high` are REQUIRED fields
// of the food-vision strict schema, so the band always exists and the
// midpoint branch was the branch EVERY photographed plate took.
//
// The two numbers are different quantities. The band is the sum of the
// items' own low/high bounds; the hero is the sum of their point
// estimates. Nothing makes them agree — and the physics clamp (the
// "27-million-calorie candy bar" guard) runs on items only, so a
// clamped plate was clamped on screen and unclamped in the record.
//
// The stored number is what reaches Home's dial, the day totals, Apple
// Health, the coach's envelope and the clinician packet. So the defect
// was not cosmetic: she agreed to one number and the product kept a
// different one, everywhere, forever.
//
// Every pre-existing `persist` fixture passed `kcalLow: nil`, which is
// why nothing caught it: the tests exercised the fallback and shipped
// the branch.
//
// `CapturedFood.recordedKcal` is now the ONE rule, and both the
// reading and the record read it.

final class PlateEnergyRecordTests: XCTestCase {

    // MARK: - Fixtures

    private func item(
        id: String = "a",
        name: String = "jeyuk bokkeum",
        grams: Double = 500,
        kcal: Double? = 1000,
        p: Double? = 80
    ) -> CapturedItem {
        CapturedItem(
            id: id, name: name,
            portionGrams: grams, portionGramsLow: grams * 0.8, portionGramsHigh: grams * 1.2,
            usdaSearchTerms: [name], preparation: nil, cuisineHint: nil,
            confidence: 0.85, notes: nil,
            kcal: kcal, proteinG: p, carbsG: 50, fatG: 40, fiberG: 5,
            nutritionSource: .llmDirect
        )
    }

    private func plate(
        _ items: [CapturedItem],
        lo: Double? = 950,
        hi: Double? = 1250,
        source: EntryMethod = .photo
    ) -> CapturedFood {
        CapturedFood(
            items: items, plateType: .mixed, source: source,
            confidence: 0.85, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: lo, kcalHigh: hi
        )
    }

    // MARK: - The law

    /// THE defect, stated as the package's own fixture states it:
    /// items sum to 1000, the model's band is 950…1250 (midpoint 1100).
    /// The screen said 1000. The record kept 1100.
    func testTheItemsPriceThePlateEvenWhenTheModelReturnedABand() {
        let food = plate([item(kcal: 1000)], lo: 950, hi: 1250)
        XCTAssertEqual(food.recordedKcal, 1000, accuracy: 0.001,
                       "the items price the plate; the band is honesty metadata, not a second opinion")
    }

    /// The band is not discarded — it still describes the plate. It is
    /// simply never the stored total when items can price it.
    func testTheBandSurvivesForTheHonestyLabel() {
        let food = plate([item(kcal: 1000)], lo: 950, hi: 1250)
        XCTAssertEqual(food.kcalLow, 950)
        XCTAssertEqual(food.kcalHigh, 1250)
    }

    /// Several items sum. 1000 + 240 = 1240 → 1240 (already a multiple
    /// of 5).
    func testSeveralItemsSum() {
        let food = plate([item(id: "a", kcal: 1000), item(id: "b", name: "rice", kcal: 240)])
        XCTAssertEqual(food.recordedKcal, 1240, accuracy: 0.001)
    }

    /// Rounded to the nearest 5, exactly as the reading rounds it —
    /// so the number in the record IS the number on the screen, and a
    /// day's plates add up to the day's total she was shown.
    func testRoundsToFiveLikeTheReadingDoes() {
        let food = plate([item(kcal: 1002)], lo: nil, hi: nil)
        XCTAssertEqual(food.recordedKcal, 1000, accuracy: 0.001)

        let up = plate([item(kcal: 1003)], lo: nil, hi: nil)
        XCTAssertEqual(up.recordedKcal, 1005, accuracy: 0.001)
    }

    /// The restaurant-range door identifies no items, so there is
    /// nothing to sum and the band IS the estimate — the one place the
    /// midpoint is the honest answer, and the reading shows the same
    /// number.
    func testNoItemsFallsBackToTheBandMidpoint() {
        let food = plate([], lo: 900, hi: 1300, source: .restaurant)
        XCTAssertEqual(food.recordedKcal, 1100, accuracy: 0.001)
    }

    /// No items and no band is not a plate worth a number.
    func testNoItemsAndNoBandIsZero() {
        let food = plate([], lo: nil, hi: nil, source: .restaurant)
        XCTAssertEqual(food.recordedKcal, 0, accuracy: 0.001)
    }

    /// A partially-priced plate keeps the record equal to the screen:
    /// the reading sums what it could price, so the record does too.
    /// (What the reading OWES the user here is a visible "couldn't
    /// price this" marker — that is a display defect, and it must never
    /// be papered over by storing a bigger, differently-derived number.)
    func testPartiallyPricedPlateStoresWhatTheReadingSummed() {
        let food = plate([item(id: "a", kcal: 600), item(id: "b", name: "sauce", kcal: nil)],
                         lo: 950, hi: 1250)
        XCTAssertEqual(food.recordedKcal, 600, accuracy: 0.001,
                       "the record may not silently out-count the screen")
    }

    // MARK: - The clamp reaches the record

    /// The physics clamp exists because the model occasionally reports
    /// a 20g sweet at 27,000,000 kcal. It runs on items — so as long as
    /// the band was the stored total, the guard protected the screen
    /// and not the record.
    func testTheClampNowReachesTheRecord() {
        let absurd = item(id: "candy", name: "candy", grams: 20, kcal: 27_000_000)
        let clamped = PlateEditSession.physicsClamped(absurd)
        XCTAssertTrue(clamped.adjusted)
        let food = plate([clamped.item], lo: 26_000_000, hi: 28_000_000)
        XCTAssertEqual(food.recordedKcal, 400, accuracy: 0.001,
                       "a clamped plate is clamped in the record too")
    }

    // MARK: - Edits keep the two numbers together

    /// Halving the portion halves the plate, in the record as on the
    /// screen. `rebuiltFood` scales the band by the same ratio, so the
    /// honesty label stays truthful about the new number.
    func testAnEditMovesTheRecordAndTheScreenTogether() {
        var session = PlateEditSession(food: plate([item(kcal: 1000)], lo: 900, hi: 1100))
        session.setFraction(0.5)
        let rebuilt = session.rebuiltFood()
        XCTAssertEqual(rebuilt.recordedKcal, 500, accuracy: 0.001)
        XCTAssertEqual(rebuilt.kcalLow ?? 0, 450, accuracy: 0.5)
        XCTAssertEqual(rebuilt.kcalHigh ?? 0, 550, accuracy: 0.5)
    }

    /// Removing an item removes its energy from the record.
    func testRemovingAnItemMovesTheRecord() {
        var session = PlateEditSession(
            food: plate([item(id: "a", kcal: 1000), item(id: "b", name: "rice", kcal: 240)])
        )
        session.remove("b")
        XCTAssertEqual(session.rebuiltFood().recordedKcal, 1000, accuracy: 0.001)
    }
}
