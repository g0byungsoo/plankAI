import XCTest
@testable import plankAI

// MARK: - PlanSummaryTests
//
// THE PLAN, as one answerable object.
//
// After ~45 questions and a payment, the post-purchase screen said
// *"we used what you told us in onboarding to build your plan"* and
// then listed four promises that are identical for every human being
// on earth. It named none of her numbers. `PlanSummary` is the
// content that screen should always have had, and the same object
// the edit surface writes back into.
//
// Its laws are refusals, not features:
//   · it never invents a goal
//   · it never states a distance it cannot compute
//   · it says "maintenance" only when maintenance was chosen
//   · under numeric suppression it carries no numerals at all

@MainActor
final class PlanSummaryTests: XCTestCase {

    private let d = UserDefaults.standard
    private static let keys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onboardingPickedTier",
        "onboarding_goal_direction", "program_mode", "safety_pace_cap",
        "onb_v4_movement_baseline", "onb_v5_age_years",
        "safety_numeric_suppression", "onboarding_glp1_status",
    ]

    override func setUpWithError() throws {
        Self.keys.forEach { d.removeObject(forKey: $0) }
    }

    override func tearDownWithError() throws {
        Self.keys.forEach { d.removeObject(forKey: $0) }
    }

    /// 5'3" · 124 lb · goal 110 lb — the customer class.
    private func seedPersona(goalKg: Double? = 110 / 2.20462) {
        d.set(124 / 2.20462, forKey: "onboardingCurrentWeightKg")
        if let goalKg { d.set(goalKg, forKey: "onboardingGoalWeightKg") }
        d.set(160.02, forKey: "onboardingHeightCm")
        d.set("female", forKey: "onboardingGender")
        d.set(34, forKey: "onb_v5_age_years")
        d.set("walks", forKey: "onb_v4_movement_baseline")
        d.set("medium", forKey: "onboardingPickedTier")
        d.set("lose", forKey: "onboarding_goal_direction")
        d.set("loss", forKey: "program_mode")
    }

    private func summary(latestKg: Double? = 124 / 2.20462,
                         proteinG: Int? = 90,
                         steps: Int = 7_500) -> PlanSummary {
        PlanSummary.build(
            plan: nil,
            latestWeightKg: latestKg,
            proteinG: proteinG,
            stepsGoal: steps,
            numericsSuppressed: d.bool(forKey: "safety_numeric_suppression"),
            defaults: d
        )
    }

    // MARK: - It states her numbers

    func testStatesStartGoalAndDistanceInHerUnit() {
        seedPersona()
        let s = summary()

        guard case .losing(let goal) = s.intent else {
            return XCTFail("124 → 110 lb is a loss plan, got \(s.intent)")
        }
        XCTAssertEqual(goal, 110 / 2.20462, accuracy: 0.001)
        XCTAssertEqual(s.currentKg ?? 0, 124 / 2.20462, accuracy: 0.001)
        XCTAssertEqual(s.distanceKg ?? 0, 14 / 2.20462, accuracy: 0.01)
        XCTAssertEqual(s.distanceLine(unit: .lb), "14 lb to go")
    }

    func testCarriesTheEnergyTargetAndSaysWhatItIs() {
        seedPersona()
        let s = summary()
        XCTAssertNotNil(s.energyKcal)
        XCTAssertEqual(s.energyKind, .deficit)
    }

    func testCarriesTheProteinFloorAndTheStepGoal() {
        seedPersona()
        let s = summary(proteinG: 90, steps: 8_000)
        XCTAssertEqual(s.proteinG, 90)
        XCTAssertEqual(s.stepsGoal, 8_000)
    }

    /// The horizon is derived from the same calculator the reveal used,
    /// never picked. It must be a real number of weeks, not a promise.
    func testHorizonIsDerivedNotPromised() {
        seedPersona()
        let s = summary()
        guard let weeks = s.horizonWeeks else {
            return XCTFail("a loss plan must carry a horizon")
        }
        XCTAssertGreaterThanOrEqual(weeks, 4)
        XCTAssertLessThanOrEqual(weeks, 52)
    }

    // MARK: - It refuses

    /// No goal → the plan says so and asks. It does NOT show a
    /// distance, a horizon, or an energy number.
    func testNoGoalAsksInsteadOfInventing() {
        seedPersona(goalKg: nil)
        let s = summary()

        XCTAssertEqual(s.intent, .goalMissing)
        XCTAssertNil(s.distanceKg)
        XCTAssertNil(s.horizonWeeks)
        XCTAssertNil(s.energyKcal)
        XCTAssertTrue(s.needsGoal)
    }

    /// A goal at or above current, from a user who asked to lose, is
    /// corrupt — not a maintenance instruction.
    func testGoalAboveCurrentAsksRatherThanCallingItMaintenance() {
        seedPersona(goalKg: 124 / 2.20462 + 2)
        let s = summary()
        XCTAssertEqual(s.intent, .goalMissing)
        XCTAssertTrue(s.needsGoal)
    }

    func testMaintenanceChoiceReadsAsHoldingNotAsAMissingGoal() {
        seedPersona(goalKg: 124 / 2.20462)
        d.set("maintain", forKey: "onboarding_goal_direction")
        d.set("maintenance", forKey: "program_mode")

        let s = summary()
        XCTAssertEqual(s.intent, .holding)
        XCTAssertFalse(s.needsGoal)
        XCTAssertEqual(s.energyKind, .maintenance)
        XCTAssertNotNil(s.energyKcal)
    }

    /// The safety gate's numeric-suppression cohorts (ED screen,
    /// pregnancy) get a plan with no numerals in it at all.
    func testNumericSuppressionCarriesNoNumeralsAtAll() {
        seedPersona()
        d.set(true, forKey: "safety_numeric_suppression")

        let s = summary()
        XCTAssertTrue(s.numericsSuppressed)
        XCTAssertNil(s.energyKcal)
        XCTAssertNil(s.distanceKg)
        XCTAssertNil(s.horizonWeeks)
        XCTAssertNil(s.proteinG)
        XCTAssertFalse(s.needsGoal, "never ask a suppressed cohort for a goal weight")
    }

    /// No weight on file at all: nothing to state, and nothing invented.
    func testNoWeightYieldsNoDistanceAndNoEnergy() {
        seedPersona()
        d.removeObject(forKey: "onboardingCurrentWeightKg")
        let s = summary(latestKg: nil)
        XCTAssertNil(s.currentKg)
        XCTAssertNil(s.energyKcal)
        XCTAssertNil(s.distanceKg)
    }

    // MARK: - Grammar

    func testDistanceUnderATenthReadsAsArrived() {
        seedPersona(goalKg: 124 / 2.20462 - 0.01)
        let s = summary()
        XCTAssertEqual(s.distanceLine(unit: .lb), "you reached your goal")
    }

    func testWholeNumbersDropTheTrailingZero() {
        seedPersona()
        XCTAssertFalse(summary().distanceLine(unit: .lb)?.contains(".0") ?? true)
    }
}
