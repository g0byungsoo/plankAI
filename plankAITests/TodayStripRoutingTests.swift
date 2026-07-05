import XCTest
@testable import plankAI

// v1.1.4 — the day-strip tap routing net.
//
// Bug: past-day taps on the Home strip were dropped on the floor
// (`guard case .locked = day else { return }`), so tapping yesterday /
// 3 days ago / 7 days ago did nothing. These pin the pure routing that
// replaced the guard: past → review, near future (≤ +7) → peek, far
// future → lock, today / new-program → no sheet. The future rows must
// keep their prior behavior exactly.
@MainActor
final class TodayStripRoutingTests: XCTestCase {

    private let today = 10

    func testPastDaysOpenTheReviewSheet() {
        // yesterday, 3 days ago, 7 days ago — all reachable now.
        for d in [9, 7, 3, 1] {
            XCTAssertEqual(
                TodayModuleState.stripSheet(for: .past(day: d), programDay: today),
                .dayReview(day: d),
                "past day \(d) should open the review sheet"
            )
        }
    }

    func testNearFutureKeepsThePeek() {
        // +1 through +7 stay a warm peek (unchanged behavior).
        XCTAssertEqual(
            TodayModuleState.stripSheet(for: .locked(day: 11), programDay: today),
            .dayPeek(day: 11)
        )
        // boundary: exactly +7 is still a peek.
        XCTAssertEqual(
            TodayModuleState.stripSheet(for: .locked(day: 17), programDay: today),
            .dayPeek(day: 17)
        )
    }

    func testFarFutureKeepsTheLock() {
        // +8 and beyond lock (unchanged behavior).
        XCTAssertEqual(
            TodayModuleState.stripSheet(for: .locked(day: 18), programDay: today),
            .dayLock(day: 18)
        )
        XCTAssertEqual(
            TodayModuleState.stripSheet(for: .locked(day: 40), programDay: today),
            .dayLock(day: 40)
        )
    }

    func testTodayAndNewProgramNavigateNowhere() {
        XCTAssertNil(TodayModuleState.stripSheet(for: .today, programDay: today))
        XCTAssertNil(TodayModuleState.stripSheet(for: .newProgram, programDay: today))
    }
}
