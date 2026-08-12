import XCTest
@testable import plankAI

// MARK: - HomeHierarchyTests (v25 E8 — THE MERGE)
//
// Home's hero carousel opened on CALORIES from v21 until E8, and
// reached protein only on a swipe — the inverse of the product's own
// law (`00_THE_SYSTEM` §9 "protein floor + fiber lead; kcal quiet",
// from §7.6's finding that protein is one of exactly two proven GLP-1
// content pillars and lean mass is 25-40% of drug-induced loss). E7
// fixed the same inversion in the food reading; this pins it on the
// surface every payer actually sees.
//
// These tests exist because the defect was invisible: the old order was
// one array literal in a private view property, and nothing anywhere
// asserted which face came first.

final class HomeHierarchyTests: XCTestCase {

    private typealias Page = HomeNutritionSummary.Page

    private func order(
        proteinFloorG: Int? = 90,
        proteinEatenG: Int = 0,
        kcalEaten: Int = 0,
        hasChemistry: Bool = false,
        weekDaysWithData: Int = 0
    ) -> [Page] {
        HomeNutritionSummary.pageOrder(
            proteinFloorG: proteinFloorG,
            proteinEatenG: proteinEatenG,
            kcalEaten: kcalEaten,
            hasChemistry: hasChemistry,
            weekDaysWithData: weekDaysWithData
        )
    }

    // MARK: - the law

    func testProteinLeadsWhenAFloorIsOnFile() {
        XCTAssertEqual(order().first, .protein)
    }

    /// The new payer: entitled, nothing logged. The first three seconds
    /// of the product. This used to be a `0` inside a calorie ring.
    func testBrandNewPayerOpensOnProteinNotAZeroCalorieRing() {
        let pages = order(proteinEatenG: 0, kcalEaten: 0)
        XCTAssertEqual(pages.first, .protein)
        XCTAssertEqual(pages, [.protein, .calories],
                       "nothing logged means nothing else has anything to say")
    }

    func testDenseDayStillLeadsWithProtein() {
        let pages = order(
            proteinEatenG: 120, kcalEaten: 1900,
            hasChemistry: true, weekDaysWithData: 7
        )
        XCTAssertEqual(pages.first, .protein)
        XCTAssertEqual(pages, [.protein, .calories, .plate, .chemistry, .week])
    }

    // MARK: - the honest exception

    /// E7's law: a denominator never renders without a floor on file.
    /// With no weight collected there is no floor, so protein would be
    /// a bare gram count measured against nothing — weaker than the
    /// ring. Calories lead in exactly this case and no other.
    func testCaloriesLeadOnlyWhenThereIsNoProteinFloor() {
        XCTAssertEqual(order(proteinFloorG: nil).first, .calories)
        XCTAssertEqual(order(proteinFloorG: 0).first, .calories)
    }

    func testProteinStillGetsAPageWithoutAFloorOnceSheHasEaten() {
        let pages = order(proteinFloorG: nil, proteinEatenG: 40)
        XCTAssertEqual(pages.first, .calories, "it cannot lead without a floor")
        XCTAssertTrue(pages.contains(.protein), "but it is still worth saying")
    }

    func testNoFloorAndNothingEatenShowsNoProteinPage() {
        let pages = order(proteinFloorG: nil, proteinEatenG: 0)
        XCTAssertFalse(pages.contains(.protein))
        XCTAssertEqual(pages, [.calories])
    }

    // MARK: - what must NOT have changed

    func testCaloriesAreNeverRemoved() {
        // Home is not the reading. E7 deleted the kcal ring there; here
        // calories remain a real fact that simply stopped leading.
        for floor in [nil, 0, 90] as [Int?] {
            XCTAssertTrue(order(proteinFloorG: floor).contains(.calories))
        }
    }

    func testPagesRenderOnlyWhatAStoreProduced() {
        // v21 §1.6 — absent rather than zeroed.
        let empty = order(proteinEatenG: 0, kcalEaten: 0,
                          hasChemistry: false, weekDaysWithData: 0)
        XCTAssertFalse(empty.contains(.plate))
        XCTAssertFalse(empty.contains(.chemistry))
        XCTAssertFalse(empty.contains(.week))
    }

    func testWeekNeedsTwoDaysBeforeItSpeaks() {
        XCTAssertFalse(order(weekDaysWithData: 1).contains(.week))
        XCTAssertTrue(order(weekDaysWithData: 2).contains(.week))
    }

    func testNoPageAppearsTwice() {
        let pages = order(
            proteinFloorG: 90, proteinEatenG: 120, kcalEaten: 1900,
            hasChemistry: true, weekDaysWithData: 7
        )
        XCTAssertEqual(Set(pages).count, pages.count)
        // and the same with the no-floor branch, where protein is
        // appended on a different line
        let noFloor = order(
            proteinFloorG: nil, proteinEatenG: 40, kcalEaten: 900,
            hasChemistry: true, weekDaysWithData: 3
        )
        XCTAssertEqual(Set(noFloor).count, noFloor.count)
    }

    func testOrderIsNeverEmpty() {
        XCTAssertFalse(order(proteinFloorG: nil).isEmpty)
    }
}
