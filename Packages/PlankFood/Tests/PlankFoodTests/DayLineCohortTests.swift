import XCTest
@testable import PlankFood

// p57 — ONE law for "over", both surfaces. Home has refused the word
// for the on-medication chapter since p53 (count-up grammar: under
// stays spoken, over is never said — the countdown harm is the
// market's named damage for this cohort). The reading's day line was
// the second place the position renders, and it still said "a little
// over today" to the same person on the same day.
final class DayLineCohortTests: XCTestCase {

    func testRoomLeftSpeaksForEveryone() {
        let line = FoodModule.dayLine(
            context: .init(kcalEatenToday: 600, kcalTarget: 1500, countUpOnly: true),
            plateKcal: 300
        )
        XCTAssertEqual(line?.punch, "600 left")
    }

    func testOverIsNeverSaidToTheCountUpCohort() {
        let line = FoodModule.dayLine(
            context: .init(kcalEatenToday: 1400, kcalTarget: 1500, countUpOnly: true),
            plateKcal: 400
        )
        XCTAssertNil(line, "the same silence Home keeps for this cohort")
    }

    func testOverStillSpeaksPlainlyOutsideTheCohort() {
        let line = FoodModule.dayLine(
            context: .init(kcalEatenToday: 1400, kcalTarget: 1500, countUpOnly: false),
            plateKcal: 400
        )
        XCTAssertEqual(line?.punch, "over")
    }

    func testArrivalReadsTheSameForBoth(){
        for countUp in [true, false] {
            let line = FoodModule.dayLine(
                context: .init(kcalEatenToday: 1400, kcalTarget: 1500, countUpOnly: countUp),
                plateKcal: 80
            )
            XCTAssertEqual(line?.punch, "right at", "countUp=\(countUp)")
        }
    }

    // p72 — a plate she dated to yesterday never claims today's room:
    // the line says where it goes, for every cohort, whatever the math.
    func testAStatedYesterdayPlateNeverClaimsToday() {
        for countUp in [true, false] {
            let line = FoodModule.dayLine(
                context: .init(kcalEatenToday: 400, kcalTarget: 1500, countUpOnly: countUp),
                plateKcal: 250,
                statedDaysAgo: 1
            )
            XCTAssertEqual(line?.punch, "goes on yesterday")
            XCTAssertFalse((line?.suffix ?? "").contains("today"))
        }
    }
}
