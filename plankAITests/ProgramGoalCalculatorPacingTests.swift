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

    // MARK: - FIX 2 — soft-tier date uses the cohort floor, not a flat 0.005
    //
    // Pre-fix: the calorie hero used `revealWindow.lossRateFloor` (0.003 for
    // a GLP-1 user) but the projected DATE drew gentle at a hard-coded 0.005,
    // so the date she saw wasn't actually gentler while the provenance line
    // said it was. The fix stores the cohort floor in
    // `ProjectionMath.softFloorDefaultsKey`, which `weeklyFraction("gentle")`
    // now reads. This test proves the date + the calorie deficit imply the
    // SAME %/wk for a cohort-floor user picking soft.

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ProjectionMath.softFloorDefaultsKey)
        super.tearDown()
    }

    func testSoftTierDateUsesCohortFloorNotFlatGentle() {
        // GLP-1 user -> cautious 0.003 floor. Modest delta keeps both the
        // cohort date and the default date inside the 4..26 ProjectionMath band.
        let curr = 70.0, goal = 66.0   // delta 4kg
        let glp1Window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: curr,
            goalWeightKg: goal,
            sex: .female,
            age: nil,
            isGLP1User: true,
            isPerimenopausal: false,
            isShortSleeper: false
        ))
        XCTAssertEqual(glp1Window.lossRateFloor, 0.003, accuracy: 0.0001,
            "GLP-1 user must get the cautious 0.003 floor")

        // No floor stored yet -> gentle falls back to the flat 0.005.
        UserDefaults.standard.removeObject(forKey: ProjectionMath.softFloorDefaultsKey)
        let flatWeeks = ProjectionMath.projectedWeeks(currentKg: curr, goalKg: goal, paceKey: "gentle")
        XCTAssertEqual(ProjectionMath.weeklyFraction(paceKey: "gentle"), 0.005, accuracy: 0.0001,
            "unset floor -> gentle defaults to 0.005 (regression lock)")

        // Persist the cohort floor (what the reveal does) -> gentle is now cohort-aware.
        UserDefaults.standard.set(glp1Window.lossRateFloor, forKey: ProjectionMath.softFloorDefaultsKey)
        XCTAssertEqual(ProjectionMath.weeklyFraction(paceKey: "gentle"), 0.003, accuracy: 0.0001,
            "stored cohort floor must drive the gentle rate (no more flat 0.005)")

        guard let cohortWeeks = ProjectionMath.projectedWeeks(currentKg: curr, goalKg: goal, paceKey: "gentle"),
              let flat = flatWeeks else {
            return XCTFail("projectedWeeks must resolve for a loss goal")
        }
        // Cohort floor is gentler -> strictly MORE weeks (a later, truly
        // gentler date) than the flat 0.005 path.
        XCTAssertGreaterThan(cohortWeeks, flat,
            "the cohort-floor gentle date must be later than the flat-0.005 date")

        // Consistency: the date %/wk and the calorie-deficit %/wk now match.
        // Calorie deficit for soft uses revealWindow.lossRateFloor (0.003);
        // the date implies delta/(curr*weeks) -> must be ~0.003, not ~0.005.
        let dateImpliedRate = (curr - goal) / (curr * Double(cohortWeeks))
        XCTAssertEqual(dateImpliedRate, glp1Window.lossRateFloor, accuracy: 0.0004,
            "the soft date must imply the same %/wk the calorie deficit uses")
        XCTAssertLessThan(dateImpliedRate, 0.0045,
            "the soft date must be clearly gentler than the generic 0.005")
    }
}
