import XCTest
@testable import plankAI

final class ProgramGoalCalculatorSafetyTests: XCTestCase {
    // 80kg -> 70kg (10kg, 12.5% of body weight) must take >= 13 weeks at the
    // 1%/wk ceiling. A faster plan would be a clinical defect.
    func testFastestPlanNeverExceedsOnePercentPerWeek() {
        let w = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80, goalWeightKg: 70, sex: .female, age: 28,
            isGLP1User: false, isPerimenopausal: false, isShortSleeper: false))
        // minWeeks is the fastest (Hard) plan. 10kg / (80kg * 0.01) = 12.5 -> >=13 wks.
        XCTAssertGreaterThanOrEqual(w.minWeeks, 13)
    }

    func testGLP1CohortFloorsAtGentlerPace() {
        let w = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80, goalWeightKg: 70, sex: .female, age: 28,
            isGLP1User: true, isPerimenopausal: false, isShortSleeper: false))
        // 80kg -> 70kg at the GLP-1 0.3%/wk floor: 10 / (80*0.003) = 41.67 -> rounds up to 42.
        // Lock BOTH sides: floor is applied (>=42) and not eroded toward a slower rate (<=42).
        XCTAssertGreaterThanOrEqual(w.maxWeeks, 42)
        XCTAssertLessThanOrEqual(w.maxWeeks, 42)
    }

    func testClampedToProgramBounds() {
        let w = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 60, goalWeightKg: 59, sex: .female, age: 28,
            isGLP1User: false, isPerimenopausal: false, isShortSleeper: false))
        XCTAssertGreaterThanOrEqual(w.minWeeks, 4)
        XCTAssertLessThanOrEqual(w.maxWeeks, 52)
    }
}
