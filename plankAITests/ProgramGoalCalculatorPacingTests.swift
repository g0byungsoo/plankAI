import XCTest
@testable import plankAI

// MARK: - ProgramGoalCalculatorPacingTests
//
// T2 (2026-06-29): verifies that the two new pacing signals
// (weight-trend key from case 1320, GLP-1 phase key from case 1641)
// actually move the computed window, and that unset values produce
// identical output to the pre-T2 behavior (regression lock).
//
// Representative user: 80kg -> 70kg (10kg delta), female.
// Baseline floor = 0.005 -> maxWeeks = ceil(10/(80*0.005)) = ceil(25) = 25.

final class ProgramGoalCalculatorPacingTests: XCTestCase {

    // Baseline: no special keys. Pre-T2 legacy behavior for the regression lock.
    private func baseline() -> ProgramGoalCalculator.Window {
        ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80,
            goalWeightKg: 70,
            sex: .female,
            age: nil,
            isGLP1User: false,
            isPerimenopausal: false,
            isShortSleeper: false
        ))
    }

    // (a) cycling trend -> maxWeeks >= baseline maxWeeks (gentler pace, wider window).
    // NWCR: regain history predicts higher re-regain risk; one-notch-gentler
    // starting pace (floor 0.005 -> 0.004) widens the window.
    func testCyclingTrendProducesGentlerWindow() {
        let base = baseline()
        let cycling = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80,
            goalWeightKg: 70,
            sex: .female,
            age: nil,
            isGLP1User: false,
            isPerimenopausal: false,
            isShortSleeper: false,
            weightTrendKey: "cycling",
            glp1PhaseKey: ""
        ))
        XCTAssertGreaterThanOrEqual(cycling.maxWeeks, base.maxWeeks,
            "cycling trend must widen the window (maxWeeks >= baseline)")
        // Floor drops one notch from 0.005 to 0.004.
        XCTAssertEqual(cycling.lossRateFloor, 0.004, accuracy: 0.0001,
            "cycling trend must set floor to 0.004 (one notch below default 0.005)")
    }

    // (b) just_started GLP-1 phase -> forces cautious 0.003 floor.
    // Early titration: lean-mass risk + appetite suppression at peak.
    // 80kg at 0.003/wk: ceil(10 / (80*0.003)) = ceil(41.67) = 42 weeks.
    func testJustStartedGLP1PhaseForcesCautiousFloor() {
        let earlyGLP1 = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80,
            goalWeightKg: 70,
            sex: .female,
            age: nil,
            isGLP1User: false,
            isPerimenopausal: false,
            isShortSleeper: false,
            weightTrendKey: "",
            glp1PhaseKey: "just_started"
        ))
        XCTAssertEqual(earlyGLP1.lossRateFloor, 0.003, accuracy: 0.0001,
            "just_started phase must apply the 0.003 cautious floor")
        // maxWeeks for 0.003 floor: ceil(10/(80*0.003)) = 42.
        XCTAssertGreaterThanOrEqual(earlyGLP1.maxWeeks, 42)
        XCTAssertLessThanOrEqual(earlyGLP1.maxWeeks, 42)
    }

    // (c) REGRESSION: empty ("") keys reproduce the EXACT pre-T2 window.
    // Any deviation here means the defaults broke existing users' programs.
    func testUnsetKeysPreserveExistingBehavior() {
        let withEmpty = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80,
            goalWeightKg: 70,
            sex: .female,
            age: nil,
            isGLP1User: false,
            isPerimenopausal: false,
            isShortSleeper: false,
            weightTrendKey: "",
            glp1PhaseKey: ""
        ))
        let legacy = baseline()
        XCTAssertEqual(withEmpty.minWeeks, legacy.minWeeks,
            "regression: minWeeks must be identical when keys are empty")
        XCTAssertEqual(withEmpty.maxWeeks, legacy.maxWeeks,
            "regression: maxWeeks must be identical when keys are empty")
        XCTAssertEqual(withEmpty.lossRateFloor, legacy.lossRateFloor, accuracy: 0.0001,
            "regression: lossRateFloor must be identical when keys are empty")
    }

    // Extra: GLP-1/peri flag remains dominant even when cycling trend is also set.
    // Cautious floor (0.003) must win over the regain-risk nudge (0.004).
    func testGLP1CautiousFloorDominatesRegainRisk() {
        let combined = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80,
            goalWeightKg: 70,
            sex: .female,
            age: nil,
            isGLP1User: true,
            isPerimenopausal: false,
            isShortSleeper: false,
            weightTrendKey: "cycling",
            glp1PhaseKey: ""
        ))
        XCTAssertEqual(combined.lossRateFloor, 0.003, accuracy: 0.0001,
            "GLP-1 cautious floor (0.003) must dominate regain-risk nudge (0.004)")
    }

    // Extra: non-cycling trend keys produce no adjustment (provenance-safe).
    func testNonCyclingTrendKeysProduceNoAdjustment() {
        for key in ["climbing", "stable", "declining", ""] {
            let w = ProgramGoalCalculator.compute(.init(
                currentWeightKg: 80,
                goalWeightKg: 70,
                sex: .female,
                age: nil,
                isGLP1User: false,
                isPerimenopausal: false,
                isShortSleeper: false,
                weightTrendKey: key,
                glp1PhaseKey: ""
            ))
            XCTAssertEqual(w.lossRateFloor, 0.005, accuracy: 0.0001,
                "key '\(key)' must produce the default 0.005 floor")
        }
    }

    // Extra: non-just_started GLP-1 phase keys produce no adjustment.
    func testNonEarlyGLP1PhaseKeysProduceNoAdjustment() {
        for key in ["few_months", "established", "prefer_not", ""] {
            let w = ProgramGoalCalculator.compute(.init(
                currentWeightKg: 80,
                goalWeightKg: 70,
                sex: .female,
                age: nil,
                isGLP1User: false,
                isPerimenopausal: false,
                isShortSleeper: false,
                weightTrendKey: "",
                glp1PhaseKey: key
            ))
            XCTAssertEqual(w.lossRateFloor, 0.005, accuracy: 0.0001,
                "glp1PhaseKey '\(key)' must produce the default 0.005 floor")
        }
    }
}
