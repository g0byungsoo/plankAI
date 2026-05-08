import XCTest
@testable import plankAI

final class WeightUnitTests: XCTestCase {

    func testKgDisplayIsIdentityRoundedToOneDecimal() {
        XCTAssertEqual(WeightUnit.kg.display(fromKg: 70.0), 70.0, accuracy: 0.05)
        XCTAssertEqual(WeightUnit.kg.display(fromKg: 70.456), 70.5, accuracy: 0.05)
    }

    func testLbDisplayConvertsFromKg() {
        XCTAssertEqual(WeightUnit.lb.display(fromKg: 70.0), 154.3, accuracy: 0.05)
    }

    func testRoundTripAcrossUnits() {
        for kg in [50.0, 70.0, 90.0, 120.0] {
            for unit in [WeightUnit.kg, WeightUnit.lb] {
                let displayed = unit.display(fromKg: kg)
                let backToKg = unit.toKg(displayed: displayed)
                let displayedAgain = unit.display(fromKg: backToKg)
                XCTAssertEqual(displayed, displayedAgain, accuracy: 0.1,
                               "round-trip drift for \(unit.label) at kg=\(kg)")
            }
        }
    }

    func testStepDeltas() {
        XCTAssertEqual(WeightUnit.kg.smallStep, 0.1, accuracy: 0.0001)
        XCTAssertEqual(WeightUnit.kg.largeStep, 1.0, accuracy: 0.0001)
        XCTAssertEqual(WeightUnit.lb.smallStep, 0.2, accuracy: 0.0001)
        XCTAssertEqual(WeightUnit.lb.largeStep, 2.0, accuracy: 0.0001)
    }

    func testDisplayRangeEnvelopesTypicalAdultWeights() {
        XCTAssertTrue(WeightUnit.kg.displayRange.contains(50))
        XCTAssertTrue(WeightUnit.kg.displayRange.contains(150))
        XCTAssertTrue(WeightUnit.lb.displayRange.contains(110))
        XCTAssertTrue(WeightUnit.lb.displayRange.contains(330))
    }

    func testFormattedHelper() {
        XCTAssertEqual(WeightUnit.kg.formatted(fromKg: 70.0), "70.0 kg")
        XCTAssertEqual(WeightUnit.lb.formatted(fromKg: 70.0), "154.3 lb")
    }
}

final class WeightAnalyticsTests: XCTestCase {

    func testDisplayGoalKgCapsAtTenPercentLoss() {
        XCTAssertEqual(WeightAnalytics.displayGoalKg(startingKg: 70, declaredGoalKg: 60),
                       63.0, accuracy: 0.05)
    }

    func testDisplayGoalKgPassesThroughWhenWithinCap() {
        XCTAssertEqual(WeightAnalytics.displayGoalKg(startingKg: 70, declaredGoalKg: 65),
                       65.0, accuracy: 0.05)
    }

    func testDisplayGoalKgPassesThroughGainTarget() {
        XCTAssertEqual(WeightAnalytics.displayGoalKg(startingKg: 70, declaredGoalKg: 75),
                       75.0, accuracy: 0.05)
    }

    func testGoalProgressFraction() {
        // 70 → 65 with declared 60 caps to 63. Total needed 7, progressed 5.
        let p = WeightAnalytics.goalProgress(startingKg: 70, currentKg: 65, declaredGoalKg: 60)
        XCTAssertNotNil(p)
        XCTAssertEqual(p ?? 0, 5.0/7.0, accuracy: 0.001)
    }

    func testGoalProgressNilWhenAlreadyAtGoal() {
        XCTAssertNil(WeightAnalytics.goalProgress(startingKg: 70, currentKg: 70, declaredGoalKg: 70))
    }

    func testGoalProgressClampsToOneWhenExceeded() {
        let p = WeightAnalytics.goalProgress(startingKg: 70, currentKg: 60, declaredGoalKg: 65)
        XCTAssertNotNil(p)
        XCTAssertEqual(p ?? 0, 1.0, accuracy: 0.01)
    }

    func testGoalProgressClampsToZeroOnGain() {
        let p = WeightAnalytics.goalProgress(startingKg: 70, currentKg: 75, declaredGoalKg: 65)
        XCTAssertNotNil(p)
        XCTAssertEqual(p ?? 0, 0.0, accuracy: 0.01)
    }

    func testIsStalledFalseOnEmpty() {
        XCTAssertFalse(WeightAnalytics.isStalled(logs: []))
    }
}
