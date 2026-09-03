import XCTest
import PlankFood
@testable import plankAI

// Pass 57 (W5) — Home's band speaks one grammar. The rest line is the
// single quiet register everything-at-rest now shares; these pin its
// absence laws and its wrap-safety.
final class HomeRestLineTests: XCTestCase {

    func testAFullDayStatesEverythingInOneLine() {
        let facts = HomeNutritionSummary.restFacts(
            carbsG: 59, fatG: 33, fiberG: 11, sugarG: 20, sodiumMg: 710,
            hasDay: true, numericsSuppressed: false
        )
        XCTAssertEqual(facts.map(\.spoken), [
            "carbs 59 grams", "fat 33 grams", "fiber 11 grams",
            "sugar 20 grams", "sodium 710 milligrams",
        ])
    }

    /// A day that measured nothing prints nothing (the §1.6 law).
    func testUnmeasuredChemistryDropsItsFacts() {
        let facts = HomeNutritionSummary.restFacts(
            carbsG: 12, fatG: 4, fiberG: 0, sugarG: 0, sodiumMg: 0,
            hasDay: true, numericsSuppressed: false
        )
        XCTAssertEqual(facts.map(\.label), ["carbs", "fat"])
    }

    /// p71 — the absence law reaches carbs and fat: a stated
    /// protein-only day measured neither, and "carbs 0 g · fat 0 g"
    /// would state a zero-carb day she never had.
    func testAStatedProteinOnlyDayPrintsNoInventedZeros() {
        XCTAssertTrue(HomeNutritionSummary.restFacts(
            carbsG: 0, fatG: 0, fiberG: 0, sugarG: 0, sodiumMg: 0,
            hasDay: true, numericsSuppressed: false
        ).isEmpty)
    }

    func testNoPlatesMeansNoLine() {
        XCTAssertTrue(HomeNutritionSummary.restFacts(
            carbsG: 0, fatG: 0, fiberG: 0, sugarG: 0, sodiumMg: 0,
            hasDay: false, numericsSuppressed: false
        ).isEmpty)
    }

    func testSuppressionSilencesEveryNumeral() {
        XCTAssertTrue(HomeNutritionSummary.restFacts(
            carbsG: 59, fatG: 33, fiberG: 11, sugarG: 20, sodiumMg: 710,
            hasDay: true, numericsSuppressed: true
        ).isEmpty)
    }

    /// A wrap may only break BETWEEN facts: within a fact, the label,
    /// number and unit are bound with no-break spaces so "sodium" can
    /// never end a line its "710 mg" doesn't start.
    func testAFactIsUnbreakable() {
        let fact = HomeNutritionSummary.RestFact(label: "sodium", amount: "1,585", unit: "mg")
        XCTAssertEqual(fact.text, "sodium\u{00A0}1,585\u{00A0}mg")
        XCTAssertFalse(fact.text.contains(" "), "a plain space is a break opportunity")
    }
}

// p71 — the day-level recap obeys p70's absence law. The card summed
// the raw (flattened) macro fields, so a stated "protein bar, 190 cal,
// 20g protein" day printed "carbs 0 g · fat 0 g" and drew a 100%
// protein split — day-level statements she never made.
final class HomeDayRecapTotalsTests: XCTestCase {

    private func statedBar(on date: Date) -> FoodLogPersister.FoodLogEntry {
        FoodLogPersister.FoodLogEntry(
            id: "e1", loggedAt: date, title: "protein bar",
            kcal: 190, protein: 20, carbs: 0, fat: 0,
            source: EntryMethod.words.rawValue,
            itemsDetail: [FoodLogPersister.ItemDetail(
                name: "protein bar", portionG: 0,
                kcal: 190, protein: 20, carbs: nil, fat: nil,
                source: "user_stated"
            )]
        )
    }

    private func measuredBowl(on date: Date) -> FoodLogPersister.FoodLogEntry {
        FoodLogPersister.FoodLogEntry(
            id: "e2", loggedAt: date, title: "greek yogurt bowl",
            kcal: 340, protein: 24, carbs: 30, fat: 10,
            source: EntryMethod.photo.rawValue,
            itemsDetail: [FoodLogPersister.ItemDetail(
                name: "greek yogurt bowl", portionG: 250,
                kcal: 340, protein: 24, carbs: 30, fat: 10,
                source: "llm_direct"
            )]
        )
    }

    func testAStatedProteinOnlyDayNeverMeasuredCarbsOrFat() {
        let day = Date.now
        let t = HomeDayRecap.dayTotals([statedBar(on: day)], on: day)
        XCTAssertTrue(t.proteinMeasured)
        XCTAssertFalse(t.carbsMeasured)
        XCTAssertFalse(t.fatMeasured)
        XCTAssertFalse(t.splitKnown, "one stated macro is not a composition")
        XCTAssertEqual(Int(t.kcal), 190)
    }

    func testAFullyMeasuredDayKeepsItsSplitAndSums() {
        let day = Date.now
        let t = HomeDayRecap.dayTotals([measuredBowl(on: day)], on: day)
        XCTAssertTrue(t.splitKnown)
        XCTAssertTrue(t.carbsMeasured && t.fatMeasured && t.proteinMeasured)
        XCTAssertEqual(Int(t.protein), 24)
        XCTAssertEqual(Int(t.carbs), 30)
    }

    /// A mixed day: sums cover what was measured, but the split is a
    /// composition claim and one unknown plate withholds it.
    func testOneUnknownPlateWithholdsTheDaySplit() {
        let day = Date.now
        let t = HomeDayRecap.dayTotals(
            [statedBar(on: day), measuredBowl(on: day)], on: day
        )
        XCTAssertFalse(t.splitKnown)
        XCTAssertTrue(t.carbsMeasured, "the measured plate's carbs still count")
        XCTAssertEqual(Int(t.protein), 44)
        XCTAssertEqual(t.plates, 2)
    }

    func testAnEmptyDayHasNoSplit() {
        XCTAssertFalse(HomeDayRecap.dayTotals([], on: .now).splitKnown)
    }
}
