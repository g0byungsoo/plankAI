import XCTest
@testable import plankAI

// MARK: - CalorieTargetCalculatorTests
//
// Verifies the invariants the plan specifies for Task 1:
//   (a) Soft-pace target for 80kg/165cm/30/female at 0.005/wk sits
//       between BMR and TDEE and comes out below the old 80*22 rule-of-thumb
//       when the deficit drives it to the BMR floor.
//   (b) Hard pace (0.01) produces a strictly lower calorie target than
//       Soft (0.005) for the same person.
//   (c) The target never drops below max(1200, BMR), even at extreme rates.
//   (d) The function is deterministic: same inputs -> same output.
//   (e) Sanity: 80kg/165cm/30/female/sedentary at medium pace returns a
//       plausible number different from the old 22*kg formula.

final class CalorieTargetCalculatorTests: XCTestCase {

    // Reference person for tests (a)-(d): moderately active so both hard
    // and soft deficits fall within the TDEE - BMR gap, making the
    // pace-driven difference visible without the BMR clamp masking both.
    //   BMR = 10*80 + 6.25*165 - 5*30 - 161 = 1520.25 kcal
    //   TDEE (moderate 1.55) = 1520.25 * 1.55 = 2356 kcal
    private let kg: Double  = 80
    private let cm: Double  = 165
    private let age: Int    = 30
    private let sex         = ProgramGoalCalculator.Inputs.Sex.female
    // "regular_ish" is the onboarding movement-baseline key for moderate activity
    private let activity    = "regular_ish"

    private var expectedBMR:  Double { 10*kg + 6.25*cm - 5*Double(age) - 161 }
    private var expectedTDEE: Double { expectedBMR * 1.55 }

    // MARK: (a) Soft-pace target sits between BMR and TDEE

    func testSoftPaceTargetBetweenBMRAndTDEE() {
        let target = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity,
            lossRatePctPerWeek: 0.005
        )
        let bmrFloor = max(1200, Int(expectedBMR.rounded()))
        XCTAssertGreaterThanOrEqual(target, bmrFloor,
            "target must be >= max(1200, BMR)")
        // Soft pace deficit = 0.005 * 80 * 7700 / 7 = 440 kcal
        // raw = 2356 - 440 = 1916 -> not clamped, well within TDEE.
        XCTAssertLessThanOrEqual(Double(target), expectedTDEE + 1.0,
            "target with a non-zero deficit must not exceed TDEE")
    }

    // MARK: (b) Hard pace yields strictly lower target than Soft

    func testHardPaceYieldsLowerTargetThanSoft() {
        // Moderate-activity user: hard deficit (880 kcal) pushes raw below BMR
        // -> clamped to 1520; soft deficit (440) leaves raw at 1916 -> unclamped.
        // 1520 < 1916, so hard < soft.
        let hard = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity,
            lossRatePctPerWeek: 0.01
        )
        let soft = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity,
            lossRatePctPerWeek: 0.005
        )
        XCTAssertLessThan(hard, soft,
            "Hard pace (0.01) must produce a lower calorie target than Soft (0.005)")
    }

    // MARK: (c) Target never drops below max(1200, BMR)

    func testTargetNeverBelowBMRFloor() {
        // Extreme rate that would naively compute a negative daily intake.
        let extremeRate: Double = 0.10
        let target = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity,
            lossRatePctPerWeek: extremeRate
        )
        let floor = max(1200, Int(expectedBMR.rounded()))
        XCTAssertGreaterThanOrEqual(target, floor,
            "target must be clamped to max(1200, BMR) even at extreme rates")
    }

    // MARK: (d) Deterministic

    func testDeterministic() {
        let rate: Double = 0.0075
        let a = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity, lossRatePctPerWeek: rate
        )
        let b = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: kg, heightCm: cm, age: age,
            sex: sex, activityKey: activity, lossRatePctPerWeek: rate
        )
        XCTAssertEqual(a, b, "CalorieTargetCalculator.dailyTarget must be deterministic")
    }

    // MARK: (e) Sanity: sedentary 80kg user at medium pace

    func testSedentaryUserSaneMidRangeValue() {
        // BMR = 1520, TDEE_sedentary = 1824, deficit_medium = 660
        // -> raw 1164 -> clamped to BMR floor 1520.
        // Old formula: 80 * 22 = 1760; our result should differ.
        let target = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: 80, heightCm: 165, age: 30,
            sex: .female, activityKey: "barely",   // sedentary
            lossRatePctPerWeek: 0.0075
        )
        XCTAssertGreaterThanOrEqual(target, 1200,
            "target must clear the absolute 1200 kcal floor")
        XCTAssertLessThanOrEqual(target, 2000,
            "sedentary user at medium pace should be well under 2000 kcal")
        XCTAssertNotEqual(target, 80 * 22,
            "TDEE-derived result should differ from the old 22*kg rule of thumb")
    }
}
