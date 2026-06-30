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

    // MARK: - Task 3 safety upgrades

    // Convenience alias so test bodies stay readable
    private typealias SI = ProgramGoalCalculator.SafetyInputs

    // (a) insulin or sulfonylurea -> .clinicianFirst (hypoglycemia hazard on a deficit)
    func testInsulinOrSulfonylureaRoutesToClinicianFirst() {
        let s = SI(
            currentWeightKg: 80, goalWeightKg: 65, heightCm: 165,
            ageRange: "adult", scoffYesCount: 0, pregnancyStatus: "none",
            medicationKey: "insulin_or_sulfonylurea"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .clinicianFirst)
        XCTAssertEqual(result.reasonKey, "med_hypo")
        XCTAssertFalse(result.showCrisisResources)
    }

    // (b) current-GLP-1 user with 2 total yes but ONLY expected-effect items (core=0)
    // -> .loss, NOT .recovery. Rapid loss + food-noise are normal on GLP-1 drugs.
    func testCurrentGLP1WithOnlyExpectedEffectSCOFFItemsNotRoutedToRecovery() {
        let s = SI(
            currentWeightKg: 80, goalWeightKg: 65, heightCm: 165,
            ageRange: "adult", scoffYesCount: 2, pregnancyStatus: "none",
            medicationKey: "none", glp1StatusKey: "current",
            scoffCoreYesCount: 0   // both yes-items are the GLP-1-expected ones
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        // Core count is 0 (no real ED signal) -> should NOT route to recovery
        XCTAssertNotEqual(result.mode, .recovery)
        XCTAssertEqual(result.mode, .loss)
    }

    // (c) current-GLP-1 user with 2 CORE yes (genuine ED signal) -> still .recovery
    func testCurrentGLP1WithCoreSCOFFPositiveRoutesToRecovery() {
        let s = SI(
            currentWeightKg: 80, goalWeightKg: 65, heightCm: 165,
            ageRange: "adult", scoffYesCount: 4, pregnancyStatus: "none",
            medicationKey: "none", glp1StatusKey: "current",
            scoffCoreYesCount: 2   // 2 real ED signals independent of GLP-1 effects
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .recovery)
        XCTAssertEqual(result.reasonKey, "ed_screen")
        XCTAssertTrue(result.showCrisisResources)
    }

    // (d) non-GLP-1 user with 2 yes -> .recovery (unchanged behavior)
    func testNonGLP1WithTwoSCOFFYesRoutesToRecovery() {
        let s = SI(
            currentWeightKg: 80, goalWeightKg: 65, heightCm: 165,
            ageRange: "adult", scoffYesCount: 2, pregnancyStatus: "none",
            medicationKey: "none", glp1StatusKey: "none"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .recovery)
        XCTAssertEqual(result.reasonKey, "ed_screen")
    }

    // (e) ttc -> .maintenance (no aggressive pre-conception deficit)
    func testTTCRoutesToMaintenance() {
        let s = SI(
            currentWeightKg: 80, goalWeightKg: 65, heightCm: 165,
            ageRange: "adult", scoffYesCount: 0, pregnancyStatus: "ttc",
            medicationKey: "none"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .maintenance)
        XCTAssertEqual(result.reasonKey, "ttc")
        XCTAssertFalse(result.showCrisisResources)
    }

    // (f) regression: existing pregnant and breastfeeding branches still work
    func testPregnantStillRoutesToMaintenance() {
        let s = SI(
            currentWeightKg: 75, goalWeightKg: 60, heightCm: 165,
            ageRange: "adult", scoffYesCount: 0, pregnancyStatus: "pregnant",
            medicationKey: "none"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .maintenance)
        XCTAssertEqual(result.reasonKey, "pregnant")
    }

    func testBreastfeedingStillRoutesToMaintenance() {
        let s = SI(
            currentWeightKg: 75, goalWeightKg: 60, heightCm: 165,
            ageRange: "adult", scoffYesCount: 0, pregnancyStatus: "breastfeeding",
            medicationKey: "none"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .maintenance)
        XCTAssertEqual(result.reasonKey, "breastfeeding")
    }

    func testUnder18StillBlocked() {
        let s = SI(
            currentWeightKg: 55, goalWeightKg: 50, heightCm: 160,
            ageRange: "under18", scoffYesCount: 0, pregnancyStatus: "none",
            medicationKey: "none"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .blocked)
        XCTAssertEqual(result.reasonKey, "under18")
    }

    func testLowBMIStillRoutesToMaintenance() {
        // 45kg at 165cm -> BMI ~16.5 (underweight)
        let s = SI(
            currentWeightKg: 45, goalWeightKg: 40, heightCm: 165,
            ageRange: "adult", scoffYesCount: 0, pregnancyStatus: "none",
            medicationKey: "none"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .maintenance)
        XCTAssertEqual(result.reasonKey, "bmi_low")
    }

    // MARK: - Healthy-BMI normal loss plan (founder correction)
    //
    // A woman with a healthy BMI wants to lose weight for aesthetic or fitness
    // reasons. This is valid. She must NOT be capped or suppressed.
    // The goal-weight picker BMI-18.5 floor is the only guard needed.

    // Healthy BMI (22) with a loss goal -> normal .loss, uncapped, numbers shown.
    func testHealthyBMIGetsNormalLossNoCap() {
        // BMI 22 at 165 cm -> weight = 22 * (1.65)^2 = 22 * 2.7225 = ~59.9 kg.
        let heightCm = 165.0
        let weightKg = 22.0 * (heightCm / 100) * (heightCm / 100)
        let s = SI(
            currentWeightKg: weightKg,
            goalWeightKg: weightKg - 5,
            heightCm: heightCm,
            ageRange: "adult",
            scoffYesCount: 0,
            pregnancyStatus: "none",
            medicationKey: "none"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .loss,           "healthy-BMI must get a full .loss plan")
        XCTAssertEqual(result.reasonKey, "bmi_healthy")
        XCTAssertNil(result.paceCap,                 "healthy-BMI must be uncapped (nil)")
        XCTAssertFalse(result.numericSuppression,    "healthy-BMI must show numbers")
    }

    // Underweight (BMI < 18.5) -> maintenance. Genuine health concern; stays adapted.
    func testUnderweightGetsMaintenanceNotLoss() {
        // BMI 17 at 165 cm -> weight = 17 * 2.7225 = ~46.3 kg
        let heightCm = 165.0
        let weightKg = 17.0 * (heightCm / 100) * (heightCm / 100)
        let s = SI(
            currentWeightKg: weightKg,
            goalWeightKg: weightKg - 5,
            heightCm: heightCm,
            ageRange: "adult",
            scoffYesCount: 0,
            pregnancyStatus: "none",
            medicationKey: "none"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .maintenance, "underweight must stay in maintenance")
        XCTAssertEqual(result.reasonKey, "bmi_low")
        XCTAssertEqual(result.paceCap, 0.0,       "underweight has a zero-deficit cap")
        XCTAssertFalse(result.numericSuppression, "underweight: show nourishment numbers, not loss")
    }

    // Pregnant -> zero-deficit cap AND numeric suppression (no loss numbers ever).
    func testPregnantGetsZeroDeficitAndSuppression() {
        let s = SI(
            currentWeightKg: 75, goalWeightKg: 60, heightCm: 165,
            ageRange: "adult", scoffYesCount: 0, pregnancyStatus: "pregnant",
            medicationKey: "none"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .maintenance)
        XCTAssertEqual(result.reasonKey, "pregnant")
        XCTAssertEqual(result.paceCap, 0.0,      "pregnant must have hard zero-deficit cap")
        XCTAssertTrue(result.numericSuppression, "pregnant must suppress all loss numbers")
    }

    // Normal loss (no special flags, BMI > 25) -> uncapped, numbers shown.
    func testNormalLossIsUncappedNoSuppression() {
        // 80 kg at 165 cm -> BMI = 80 / 2.7225 = ~29.4 (overweight). Clean path.
        let s = SI(
            currentWeightKg: 80, goalWeightKg: 70, heightCm: 165,
            ageRange: "adult", scoffYesCount: 0, pregnancyStatus: "none",
            medicationKey: "none"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertEqual(result.mode, .loss)
        XCTAssertEqual(result.reasonKey, "ok")
        XCTAssertNil(result.paceCap,              "normal loss must be uncapped")
        XCTAssertFalse(result.numericSuppression, "normal loss must show numbers")
    }

    // MARK: - Pace-cap APPLICATION (the bug: cap was computed, never applied)
    //
    // SafetyAssessment.paceCap is now consumed at the program build (via
    // ProgramGoalCalculator.compute's paceCapPctPerWeek) and at the projection
    // reveal. These lock the compute-layer clamp the build relies on.

    // Baseline: 80 -> 70 kg at the default 0.5%/wk floor needs 25 weeks
    // (10 / (80 * 0.005) = 25). Used as the uncapped reference below.
    func testUncappedFloorReference() {
        let w = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80, goalWeightKg: 70, sex: .female, age: 28))
        XCTAssertEqual(w.maxWeeks, 25)
        XCTAssertFalse(w.isMaintenance)
    }

    // A zero pace cap (pregnant / ED / low-BMI) must force a MAINTENANCE window
    // regardless of the loss delta - the built program carries no deficit, so
    // the shipped plan matches the suppressed projection (rate 0, no numbers).
    func testZeroPaceCapForcesMaintenanceWindow() {
        let w = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80, goalWeightKg: 70, sex: .female, age: 28,
            paceCapPctPerWeek: 0.0))
        XCTAssertTrue(w.isMaintenance, "zero pace cap must build a zero-deficit maintenance plan")
        XCTAssertEqual(w.deltaKg, 0,  "maintenance window reports no deficit")
    }

    // A gentle 0.25%/wk cap (breastfeeding / ttc / under-18 / clinician-first)
    // must stretch the calendar vs the uncapped 0.5%/wk floor: 10 / (80 *
    // 0.0025) = 50 weeks. Proves the cap actually clamps the floor rate.
    func testGentlePaceCapStretchesWindow() {
        let w = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80, goalWeightKg: 70, sex: .female, age: 28,
            paceCapPctPerWeek: 0.0025))
        XCTAssertFalse(w.isMaintenance)
        XCTAssertEqual(w.maxWeeks, 50, "0.25%/wk cap must stretch the window to 50 weeks")
        XCTAssertEqual(w.lossRateFloor, 0.0025, accuracy: 1e-9,
                       "floor must be clamped down to the cap")
    }

    // The gentle cap also clamps the FAST (Hard) tier: the min-weeks side uses
    // the capped rate, never the 1%/wk ceiling. 10 / (80 * 0.0025) = 50, so
    // minWeeks must be far above the uncapped 13-week Hard plan.
    func testGentlePaceCapClampsFastTierToo() {
        let w = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80, goalWeightKg: 70, sex: .female, age: 28,
            paceCapPctPerWeek: 0.0025))
        XCTAssertGreaterThanOrEqual(w.minWeeks, 50,
            "the Hard tier must also obey the cap, not the 1%/wk ceiling")
    }

    // Regression: a nil pace cap leaves the normal band untouched.
    func testNilPaceCapLeavesNormalBand() {
        let capped = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80, goalWeightKg: 70, sex: .female, age: 28,
            paceCapPctPerWeek: nil))
        let plain = ProgramGoalCalculator.compute(.init(
            currentWeightKg: 80, goalWeightKg: 70, sex: .female, age: 28))
        XCTAssertEqual(capped.minWeeks, plain.minWeeks)
        XCTAssertEqual(capped.maxWeeks, plain.maxWeeks)
    }

    // Medication does NOT route clinicianFirst for "other_glucose" or "none" or "prefer_not_say"
    func testOtherMedicationDoesNotRouteToClinician() {
        let s = SI(
            currentWeightKg: 80, goalWeightKg: 65, heightCm: 165,
            ageRange: "adult", scoffYesCount: 0, pregnancyStatus: "none",
            medicationKey: "other_glucose"
        )
        let result = ProgramGoalCalculator.safetyAssessment(s)
        XCTAssertNotEqual(result.mode, .clinicianFirst)
    }
}
