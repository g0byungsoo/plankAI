import XCTest
@testable import plankAI

// MARK: - HomeHierarchyTests (v25 E8 → E9)
//
// Home's food band opened on CALORIES from v21 until E8, and reached
// protein only on a swipe — the inverse of the product's own law
// (`00_THE_SYSTEM` §9 "protein floor + fiber lead; kcal quiet", from
// §7.6's finding that protein is one of exactly two proven GLP-1
// content pillars and lean mass is 25-40% of drug-induced loss). E7
// fixed the same inversion in the food reading; E8 pinned it here, on
// the surface every payer actually sees.
//
// These tests exist because the defect was invisible: the old order was
// one array literal in a private view property, and nothing anywhere
// asserted which face came first.
//
// **E9 — the mechanism changed and the law did not.** The five-face
// carousel is gone (its four trailing faces each duplicated something
// the lead face's own tiers already carried). What remains to pin is
// the only part that was ever a product decision: WHICH METRIC HEADS
// THE BAND. The page-count assertions died with the pages; every law
// assertion below is carried over verbatim in meaning.

final class HomeHierarchyTests: XCTestCase {

    private typealias Lead = HomeNutritionSummary.Lead

    private func lead(proteinFloorG: Int? = 90, proteinEatenG: Int = 0) -> Lead {
        HomeNutritionSummary.lead(
            proteinFloorG: proteinFloorG,
            proteinEatenG: proteinEatenG
        )
    }

    // MARK: - the law

    func testProteinLeadsWhenAFloorIsOnFile() {
        XCTAssertEqual(lead(), .protein)
    }

    /// The new payer: entitled, nothing logged. The first three seconds
    /// of the product. This used to be a `0` inside a calorie ring.
    func testBrandNewPayerOpensOnProteinNotAZeroCalorieRing() {
        XCTAssertEqual(lead(proteinEatenG: 0), .protein)
    }

    func testDenseDayStillLeadsWithProtein() {
        XCTAssertEqual(lead(proteinEatenG: 120), .protein)
    }

    // MARK: - the honest exception

    /// E7's law: a denominator never renders without a floor on file.
    /// With no weight collected there is no floor, so protein would be
    /// a bare gram count measured against nothing — weaker than the
    /// ring. Calories lead in exactly this case and no other.
    func testCaloriesLeadOnlyWhenThereIsNoProteinFloor() {
        XCTAssertEqual(lead(proteinFloorG: nil), .calories)
        XCTAssertEqual(lead(proteinFloorG: 0), .calories)
    }

    func testEatenProteinCannotPromoteItselfWithoutAFloor() {
        // She has eaten 40 g and there is still nothing to measure it
        // against. The band says so in words; it does not invent a ring.
        XCTAssertEqual(lead(proteinFloorG: nil, proteinEatenG: 40), .calories)
    }

    func testANegativeOrAbsentFloorIsNeverTreatedAsAFloor() {
        XCTAssertEqual(lead(proteinFloorG: -10), .calories)
    }

    // MARK: - what must NOT have changed

    /// Home is not the reading. E7 deleted the kcal ring in the reading;
    /// here calories remain a real fact that simply stopped leading —
    /// they state themselves once, on the day tier, beside the split.
    func testTheLeadIsTotalAndDeterministic() {
        for floor in [nil, 0, 1, 90, 300] as [Int?] {
            for eaten in [0, 40, 400] {
                let a = lead(proteinFloorG: floor, proteinEatenG: eaten)
                let b = lead(proteinFloorG: floor, proteinEatenG: eaten)
                XCTAssertEqual(a, b, "the lead must not depend on anything unstated")
            }
        }
    }
}
