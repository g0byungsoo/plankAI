import XCTest
@testable import plankAI

// Pass 73 — THE LENS. Becoming's time filter became the page's one
// view-level control (pinned under the masthead). These pin the
// product decisions that make it honest:
//
//  · `today` is not a Becoming lens — a one-day window cannot answer
//    "am I changing?", and today's numbers live on Home (the
//    three-questions law). The case survives for one-day surfaces.
//  · every offered lens names a real window (or the whole record),
//    so the control's promise never exceeds the data behavior.
//  · delta comparisons exist exactly where a previous window has a
//    name — week and month — so a "vs last week" card can never
//    render under a lens the control claims to govern.
final class BecomingLensTests: XCTestCase {

    func testBecomingLensesExcludeTodayAndKeepChangeCapableRanges() {
        XCTAssertEqual(
            JeniScope.becomingLenses,
            [.week, .month, .threeMonths, .year, .all]
        )
        XCTAssertFalse(JeniScope.becomingLenses.contains(.today))
    }

    func testEveryLensNamesItsWindow() {
        XCTAssertEqual(JeniScope.week.windowDays, 7)
        XCTAssertEqual(JeniScope.month.windowDays, 30)
        XCTAssertEqual(JeniScope.threeMonths.windowDays, 91)
        XCTAssertEqual(JeniScope.year.windowDays, 365)
        XCTAssertNil(JeniScope.all.windowDays) // the whole record
    }

    func testDeltaBasisExistsOnlyWhereAPreviousWindowHasAName() {
        // week and month can say "vs last week" / "vs last month";
        // 3 months, year and all have no honest previous word, so no
        // delta card may claim one.
        XCTAssertEqual(JeniScope.week.previousWord, "last week")
        XCTAssertEqual(JeniScope.month.previousWord, "last month")
        XCTAssertNil(JeniScope.threeMonths.previousWord)
        XCTAssertNil(JeniScope.year.previousWord)
        XCTAssertNil(JeniScope.all.previousWord)
    }
}
