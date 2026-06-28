import XCTest
@testable import plankAI

final class GoalWeightFloorTests: XCTestCase {
    func testMinimumGoalWeightMatchesBMI185() {
        // 165cm -> BMI 18.5 floor = 18.5 * 1.65^2 = ~50.4kg
        let floor = ProgramGoalCalculator.minimumGoalWeightKg(heightCm: 165)
        XCTAssertEqual(floor, 18.5 * 1.65 * 1.65, accuracy: 0.5)
    }
    func testZeroHeightDoesNotCrashAndReturnsNonPositiveGuard() {
        // height 0 (default before capture) must not produce a usable floor.
        XCTAssertLessThanOrEqual(ProgramGoalCalculator.minimumGoalWeightKg(heightCm: 0), 0.0001 + 0)
    }
}
