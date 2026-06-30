import XCTest
@testable import plankAI

// MARK: - GoalDirectionTests
//
// Verifies the weight-MANAGEMENT path unlocked by the goal-direction question
// (case 1330 in OnboardingView). The question routes the non-loss choices to
// the maintenance machinery that already exists:
//
//   maintain / maintain_kept -> goal == current weight -> compute() returns a
//     maintenance window (no deficit) AND the calorie target is the user's real
//     TDEE (her honest maintenance number, provenance-clean — NOT a phantom
//     deficit). This is the load-bearing claim the reveal renders as
//     "your plan, steady" with the maintenance calorie visible.
//
//   recomp -> a GENTLE deficit (~0.25%/wk), clamped below the 0.5% default
//     floor so the tone-up cohort glides slower than any normal loss tier.
//
// A CHOICE maintainer is NOT a safety case: she keeps her numbers (only the
// ED / pregnant cohorts suppress numbers). These tests pin the underlying
// calculator behavior the onboarding + reveal wiring relies on.

final class GoalDirectionTests: XCTestCase {

    // Reference maintainer: 70kg / 165cm / 30 / female, moderately active.
    //   BMR  = 10*70 + 6.25*165 - 5*30 - 161 = 1420.25 kcal
    //   TDEE = 1420.25 * 1.55 (moderate) = 2201 kcal
    private let kg: Double  = 70
    private let cm: Double  = 165
    private let age: Int    = 30
    private let sex         = ProgramGoalCalculator.Inputs.Sex.female
    private let activity    = "regular_ish"   // moderate

    // MARK: maintain -> maintenance window (goal == current, zero loss delta)

    func testMaintainGoalYieldsMaintenanceWindow() {
        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: kg,
            goalWeightKg: kg,            // maintain: goal pre-filled to current
            sex: sex,
            age: age
        ))
        XCTAssertTrue(window.isMaintenance,
            "goal == current must produce a maintenance window")
        XCTAssertEqual(window.deltaKg, 0, accuracy: 0.0001,
            "a maintenance window carries no loss delta")
    }

    // MARK: maintain calorie target == TDEE (her real maintenance number)

    func testMaintainCalorieTargetEqualsTDEE() {
        let tdee = CalorieTargetCalculator.tdee(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity
        )
        // The maintenance reveal computes the target at a 0 loss rate
        // (pickedLossRatePctPerWeek returns 0 when isMaintenanceReveal).
        let target = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity,
            lossRatePctPerWeek: 0
        )
        XCTAssertEqual(target, tdee,
            "a maintenance plan's calorie target must equal the user's TDEE (no deficit)")
    }

    // MARK: recomp -> gentle deficit, slower than any loss tier

    func testRecompGentleRateProducesHigherCalorieThanLossTiers() {
        // 0.0025 is the recomp clamp; 0.0075 is the medium loss tier.
        let recomp = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity,
            lossRatePctPerWeek: 0.0025
        )
        let mediumLoss = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity,
            lossRatePctPerWeek: 0.0075
        )
        XCTAssertGreaterThan(recomp, mediumLoss,
            "a recomp gentle deficit (0.25%/wk) must leave MORE calories than a medium loss tier")
        // And it is still a deficit, not maintenance: strictly below TDEE.
        let tdee = CalorieTargetCalculator.tdee(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity
        )
        XCTAssertLessThan(recomp, tdee,
            "recomp is still a small deficit — below TDEE, unlike a pure maintainer")
    }

    // MARK: recomp build cap clamps every tier to the gentle glide

    func testRecompCapClampsProgramToGentleFloor() {
        // A real loss goal (10% loss) with the recomp 0.25%/wk cap applied.
        let goal = kg * 0.90
        let uncapped = ProgramGoalCalculator.compute(.init(
            currentWeightKg: kg, goalWeightKg: goal, sex: sex, age: age
        ))
        let recompCapped = ProgramGoalCalculator.compute(.init(
            currentWeightKg: kg, goalWeightKg: goal, sex: sex, age: age,
            paceCapPctPerWeek: 0.0025
        ))
        XCTAssertFalse(recompCapped.isMaintenance,
            "recomp still has a loss goal — it is a gentle loss, not maintenance")
        XCTAssertEqual(recompCapped.lossRateFloor, 0.0025, accuracy: 0.0001,
            "the recomp cap clamps the floor rate to the gentle 0.25%/wk glide")
        XCTAssertGreaterThanOrEqual(recompCapped.maxWeeks, uncapped.maxWeeks,
            "a gentler glide stretches the timeline (>= the uncapped max weeks)")
    }
}
