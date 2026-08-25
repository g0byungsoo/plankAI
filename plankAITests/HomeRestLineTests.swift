import XCTest
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
