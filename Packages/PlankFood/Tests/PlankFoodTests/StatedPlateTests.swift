import XCTest
@testable import PlankFood

// MARK: - StatedPlateTests (p61)
//
// The statement parser's one law: fire ONLY on a sentence that states
// its own energy; keep verbatim what she stated; invent nothing for
// what she did not.

final class StatedPlateTests: XCTestCase {

    // MARK: - The trigger

    func testASentenceWithoutAnEnergyStatementIsNotAStatement() {
        XCTAssertNil(StatedPlate.parse("2 eggs and toast"))
        XCTAssertNil(StatedPlate.parse("half a turkey sandwich"))
        XCTAssertNil(StatedPlate.parse("chicken salad with 150g of rice"))
        XCTAssertNil(StatedPlate.parse(""))
    }

    func testAStatedEnergySentenceParses() {
        let s = StatedPlate.parse("protein bar, 190 cal")
        XCTAssertEqual(s?.name, "protein bar")
        XCTAssertEqual(s?.kcal, 190)
        XCTAssertNil(s?.proteinG)
    }

    func testEveryCalorieSpelling() {
        for unit in ["cal", "cals", "kcal", "kcals", "calorie", "calories"] {
            let s = StatedPlate.parse("latte 120 \(unit)")
            XCTAssertEqual(s?.kcal, 120, "unit '\(unit)' must parse")
            XCTAssertEqual(s?.name, "latte")
        }
    }

    func testHedgedStatementsStillParse() {
        XCTAssertEqual(StatedPlate.parse("burrito, about 650 calories")?.kcal, 650)
        XCTAssertEqual(StatedPlate.parse("burrito ~650 cal")?.kcal, 650)
    }

    // MARK: - Macros ride along, never invented

    func testStatedMacrosAreKept() {
        let s = StatedPlate.parse("protein shake, 200 cal, 25g protein")
        XCTAssertEqual(s?.kcal, 200)
        XCTAssertEqual(s?.proteinG, 25)
        XCTAssertNil(s?.carbsG, "unstated carbs stay absent")
        XCTAssertNil(s?.fatG)
    }

    func testMacroWordOrderBothWays() {
        XCTAssertEqual(StatedPlate.parse("bar 190 cal protein 20g")?.proteinG, 20)
        XCTAssertEqual(StatedPlate.parse("bar 190 cal, 20 g of protein")?.proteinG, 20)
        let s = StatedPlate.parse("chicken bowl 550 kcal, 40g protein, 60g carbs, 15g fat")
        XCTAssertEqual(s?.proteinG, 40)
        XCTAssertEqual(s?.carbsG, 60)
        XCTAssertEqual(s?.fatG, 15)
        XCTAssertEqual(s?.name, "chicken bowl")
    }

    /// The energy phrase is consumed: a macro pattern may not re-read
    /// the same digits.
    func testNumbersAreNotReadTwice() {
        let s = StatedPlate.parse("450 cal chicken and rice")
        XCTAssertEqual(s?.kcal, 450)
        XCTAssertNil(s?.proteinG)
        XCTAssertEqual(s?.name, "chicken and rice")
    }

    // MARK: - Typo bounds → the model door

    func testImplausibleNumbersFallThroughToTheModel() {
        XCTAssertNil(StatedPlate.parse("dinner 50000 cal"),
                     "five digits never parses as an amount")
        XCTAssertNil(StatedPlate.parse("dinner 9000 cal"),
                     "a slipped digit goes to the model, not the record")
    }

    func testANamelessStatementStillFiles() {
        let s = StatedPlate.parse("300 calories")
        XCTAssertEqual(s?.kcal, 300)
        XCTAssertEqual(s?.name, "quick add")
    }

    // MARK: - The plate a statement becomes

    func testThePlateCarriesHerNumbersVerbatim() {
        let food = StatedPlate.plate(
            from: .init(name: "protein bar", kcal: 190, proteinG: 20,
                        carbsG: nil, fatG: nil)
        )
        XCTAssertEqual(food.recordedKcal, 190)
        XCTAssertEqual(food.items.count, 1)
        XCTAssertEqual(food.items[0].nutritionSource, .userStated)
        XCTAssertNil(food.items[0].carbsG, "nothing invented")
        XCTAssertNil(food.kcalLow, "no band — her number IS the number")
        XCTAssertEqual(food.source, .words)
    }

    /// The ingest physics clamp must not "tidy" a stated plate: with no
    /// recorded mass there is no physics to clamp against. (Before p61
    /// an unknown portion was floored to 1g, whose cap is 400 — a
    /// stated 800-kcal plate was silently rewritten.)
    func testAStatedPlateSurvivesTheIngestClampUntouched() {
        let food = StatedPlate.plate(
            from: .init(name: "burrito", kcal: 800, proteinG: nil,
                        carbsG: nil, fatG: nil)
        )
        let session = PlateEditSession(food: food)
        XCTAssertEqual(session.rebuiltFood().recordedKcal, 800,
                       "no mass, no physics, no rewrite")
    }

    /// The provenance footnote speaks her authorship, never a hedge.
    func testProvenanceSpeaksHerAuthorship() {
        let food = StatedPlate.plate(
            from: .init(name: "protein bar", kcal: 190, proteinG: 20,
                        carbsG: nil, fatG: nil)
        )
        let copy = ResultDetailCopy(
            food: food,
            ctx: .init(proteinTargetG: 120, todayLoggedProtein: 40,
                       kcalTarget: 1500, isGlp1: false, hour: 12)
        )
        XCTAssertEqual(copy.provenance, "your numbers, as you gave them")
    }
}
