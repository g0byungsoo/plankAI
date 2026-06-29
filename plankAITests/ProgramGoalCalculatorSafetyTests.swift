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
        XCTAssertFalse(result.softConfirm)
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
