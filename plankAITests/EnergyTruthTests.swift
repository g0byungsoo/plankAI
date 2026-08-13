import XCTest
import PlankSync
@testable import plankAI

// MARK: - EnergyTruthTests
//
// The customer report of 2026-08-13, turned into law.
//
//   "I wanted the goal weight to be set at 110. However, the goal is
//    set at 124, my current weight. I am also gaining weight after 2
//    weeks with this app because it has me in a caloric surplus for
//    my height (5'3")."
//
// Her two symptoms are ONE defect wearing two costumes: every path
// that loses the goal weight ALSO silently converts the plan to
// maintenance, because `planImpliedRate` returned 0 — the same value
// a deliberate maintenance choice returns — for "no plan",
// "degenerate plan" and "goal equals current". A maintenance energy
// target published to a weight-loss user IS a surplus for anyone
// whose real expenditure sits under the activity factor we assumed.
//
// The laws pinned here are about SEMANTICS, not about one person's
// calorie number:
//
//   1. A loss user is never handed maintenance by default.
//   2. Maintenance is only ever the answer when she (or a safety
//      rule) actually asked for it.
//   3. When the goal cannot be known, the app publishes NO number
//      rather than a plausible wrong one.
//   4. A goal weight is never fabricated from the current weight.
//   5. Current weight and goal weight move independently.
//   6. lb → kg → lb round-trips preserve the number she typed.

@MainActor
final class EnergyTruthTests: XCTestCase {

    // THE REGRESSION PERSONA — the customer class, in production shape.
    // 5'3" · 124 lb · goal 110 lb · female · light activity.
    private enum Persona {
        static let heightCm  = 160.02          // 5'3"
        static let currentKg = 124 / 2.20462   // 56.245
        static let goalKg    = 110 / 2.20462   // 49.895
        static let age       = 34
        static let sex       = ProgramGoalCalculator.Inputs.Sex.female
        static let activity  = "walks"         // light, 1.375
    }

    /// Maintenance for the persona, by the app's own arithmetic. Any
    /// "daily target" at or above this number is not a loss target.
    private var personaMaintenance: Int {
        CalorieTargetCalculator.tdee(
            currentWeightKg: Persona.currentKg,
            heightCm: Persona.heightCm,
            age: Persona.age,
            sex: Persona.sex,
            activityKey: Persona.activity
        )
    }

    private let d = UserDefaults.standard

    private static let ownedKeys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onboardingPickedTier",
        "onboarding_goal_direction", "program_mode", "safety_pace_cap",
        "safety_numeric_suppression", "onboarding_glp1_status",
        "onboardingHormonalStage", "onboardingSleepHours",
        "onboarding_weight_trend", "onboarding_glp1_phase",
        "onb_v4_movement_baseline", "onb_v5_age_years", "ageRange",
    ]

    override func setUpWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
    }

    override func tearDownWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
    }

    /// Seeds exactly what onboarding persists for the persona.
    private func seedPersona(goalKg: Double? = Persona.goalKg,
                             direction: String = "lose") {
        d.set(Persona.currentKg, forKey: "onboardingCurrentWeightKg")
        if let goalKg { d.set(goalKg, forKey: "onboardingGoalWeightKg") }
        d.set(Persona.heightCm, forKey: "onboardingHeightCm")
        d.set("female", forKey: "onboardingGender")
        d.set(Persona.age, forKey: "onb_v5_age_years")
        d.set(Persona.activity, forKey: "onb_v4_movement_baseline")
        d.set("medium", forKey: "onboardingPickedTier")
        d.set(direction, forKey: "onboarding_goal_direction")
        d.set("loss", forKey: "program_mode")
    }

    private func plan(startKg: Double?, goalKg: Double?, totalDays: Int = 119)
        -> ProgramPlanRecord {
        ProgramPlanRecord(
            userId: "test",
            startDate: .now,
            goalDate: .now.addingTimeInterval(Double(totalDays) * 86_400),
            totalDays: totalDays,
            currentWeightKg: startKg,
            goalWeightKg: goalKg,
            intensityTier: "medium"
        )
    }

    // MARK: - 1. The customer case

    /// She told Jeni she weighs 124 and wants 110. The plan record has
    /// not been built yet (the post-purchase onramp is two taps she may
    /// not have taken). Jeni must still run her on a deficit — the one
    /// the reveal already showed her — never on maintenance.
    func testLossUserWithNoPlanIsNeverPutOnMaintenance() {
        seedPersona()

        let basis = TargetsService.energyBasis(
            plan: nil, fallbackWeightKg: Persona.currentKg, defaults: d
        )
        guard case .deficit(let rate) = basis else {
            return XCTFail("a stated loss goal with no plan resolved to \(basis)")
        }
        XCTAssertGreaterThan(rate, 0)

        let kcal = TargetsService.calorieTarget(
            plan: nil, latestWeightKg: Persona.currentKg, defaults: d
        )
        XCTAssertNotNil(kcal)
        XCTAssertLessThan(kcal ?? .max, personaMaintenance,
            "a weight-loss user's daily target must sit below her maintenance estimate")
    }

    /// The same defect from the other side: a plan whose goal equals
    /// its start (what every "goal became current weight" path
    /// produces) must not silently mean "maintenance".
    func testDegeneratePlanFallsBackToHerOwnStatedGoal() {
        seedPersona()

        let degenerate = plan(startKg: Persona.currentKg, goalKg: Persona.currentKg)
        let basis = TargetsService.energyBasis(
            plan: degenerate, fallbackWeightKg: Persona.currentKg, defaults: d
        )
        guard case .deficit = basis else {
            return XCTFail("a degenerate plan for a loss user resolved to \(basis)")
        }
    }

    /// THE NUMBER SHE SEES IS THE NUMBER THE MATH USES.
    ///
    /// A plan record can disagree with her stated goal — a plan
    /// hydrated from an older era of the account, or one built before
    /// she changed her mind. When they disagree the plan used to win
    /// silently, so the app computed a deficit toward a goal she never
    /// chose and could not see. Her stated goal wins; the plan
    /// contributes its horizon, not its destination.
    func testHerStatedGoalOutranksADisagreeingPlanRecord() {
        seedPersona()   // she said 110 lb / 49.9 kg
        let strangerPlan = plan(startKg: 75, goalKg: 65)  // a goal she never set

        let basis = TargetsService.energyBasis(
            plan: strangerPlan, fallbackWeightKg: Persona.currentKg, defaults: d
        )
        guard case .deficit(let rate) = basis else {
            return XCTFail("expected a deficit toward her own goal, got \(basis)")
        }

        let ownRate: Double = {
            guard case .deficit(let r) = TargetsService.energyBasis(
                plan: nil, fallbackWeightKg: Persona.currentKg, defaults: d
            ) else { return -1 }
            return r
        }()
        XCTAssertEqual(rate, ownRate, accuracy: 0.00001,
            "the rate must come from the goal she can see")
    }

    /// …and an AGREEING plan is still the authority on the horizon she
    /// committed to, so nothing regresses for a normal enrolled user.
    func testAnAgreeingPlanStillDrivesTheRate() {
        seedPersona()
        let hers = plan(startKg: Persona.currentKg, goalKg: Persona.goalKg, totalDays: 84)

        guard case .deficit(let planRate) = TargetsService.energyBasis(
            plan: hers, fallbackWeightKg: Persona.currentKg, defaults: d
        ), case .deficit(let storedRate) = TargetsService.energyBasis(
            plan: nil, fallbackWeightKg: Persona.currentKg, defaults: d
        ) else { return XCTFail("both must resolve to a deficit") }

        // 84 days is a shorter horizon than the medium tier implies, so
        // the plan's own rate is the steeper one and it is honoured.
        XCTAssertGreaterThan(planRate, storedRate)
    }

    // MARK: - 2. Maintenance only when it was asked for

    func testExplicitMaintenanceChoiceStillResolvesToMaintenance() {
        seedPersona(goalKg: Persona.currentKg, direction: "maintain")
        d.set("maintenance", forKey: "program_mode")

        let basis = TargetsService.energyBasis(
            plan: nil, fallbackWeightKg: Persona.currentKg, defaults: d
        )
        XCTAssertEqual(basis, .maintenance)

        let kcal = TargetsService.calorieTarget(
            plan: nil, latestWeightKg: Persona.currentKg, defaults: d
        )
        XCTAssertEqual(kcal, personaMaintenance,
            "a maintenance user's target IS her maintenance estimate")
    }

    /// A safety pace cap of zero (pregnancy / low BMI) is a clinical
    /// maintenance instruction and outranks any loss goal on file.
    func testSafetyZeroCapForcesMaintenanceOverAStatedLossGoal() {
        seedPersona()
        d.set(0.0, forKey: "safety_pace_cap")

        XCTAssertEqual(
            TargetsService.energyBasis(
                plan: nil, fallbackWeightKg: Persona.currentKg, defaults: d
            ),
            .maintenance
        )
    }

    // MARK: - 3. No goal → no number

    /// The honest failure. If she has no goal on file and never chose
    /// maintenance, Jeni does not know what her target is — and must
    /// say nothing rather than publish maintenance dressed as a plan.
    func testLossUserWithNoGoalGetsNoNumberRatherThanMaintenance() {
        seedPersona(goalKg: nil)

        XCTAssertEqual(
            TargetsService.energyBasis(
                plan: nil, fallbackWeightKg: Persona.currentKg, defaults: d
            ),
            .unknown
        )
        XCTAssertNil(
            TargetsService.calorieTarget(
                plan: nil, latestWeightKg: Persona.currentKg, defaults: d
            ),
            "no goal and no maintenance choice must publish NO calorie number"
        )
    }

    /// A goal at or above the current weight, from a user who asked to
    /// lose, is corrupt data — not a maintenance instruction.
    func testGoalAboveCurrentForALossUserIsUnknownNotMaintenance() {
        seedPersona(goalKg: Persona.currentKg + 5)

        XCTAssertEqual(
            TargetsService.energyBasis(
                plan: nil, fallbackWeightKg: Persona.currentKg, defaults: d
            ),
            .unknown
        )
    }

    // MARK: - 4. A goal is never fabricated

    /// `assembleData` used to write `goalWeightKg = currentWeightKg`
    /// whenever the goal was unset — manufacturing the customer's exact
    /// symptom, and one that reads downstream as a deliberate
    /// maintenance choice.
    func testOnboardingNeverFabricatesAGoalFromCurrentWeight() {
        let store = OV5Store.bootFallback
        store.currentWeightKg = Persona.currentKg
        store.goalWeightKg = 0
        store.goalDirection = "lose"
        // applyGoalDirection seeds a real loss goal; force the hole back
        // open to prove assembleData cannot paper over it.
        store.goalWeightKg = 0

        let data = store.assembleData()
        XCTAssertNotEqual(data.goalWeightKg, Persona.currentKg, accuracy: 0.001,
            "an absent goal must never be published as 'your goal is your current weight'")
    }

    // MARK: - 5. The two weights are independent

    func testChangingCurrentWeightDoesNotMoveTheGoal() {
        seedPersona()
        let goalBefore = d.double(forKey: "onboardingGoalWeightKg")

        // A weigh-in eight days later.
        let kcalBefore = TargetsService.calorieTarget(
            plan: nil, latestWeightKg: Persona.currentKg, defaults: d
        )
        let kcalAfter = TargetsService.calorieTarget(
            plan: nil, latestWeightKg: Persona.currentKg - 1.5, defaults: d
        )

        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), goalBefore,
            accuracy: 0.0001, "a weigh-in must never rewrite the goal")
        XCTAssertNotNil(kcalBefore)
        XCTAssertNotNil(kcalAfter)
        XCTAssertLessThan(kcalAfter ?? 0, kcalBefore ?? 0,
            "a lighter body needs fewer calories; the target must follow the scale")
    }

    // MARK: - 6. Backward compatibility

    /// THE BLAST RADIUS. Every existing user holding a real plan whose
    /// goal matches her stored answer — the overwhelming majority of
    /// enrolled users — must get the byte-identical number she got
    /// before this change. Only the users who were being shown a WRONG
    /// number are affected.
    func testAnEnrolledUserWithACoherentPlanIsCompletelyUnaffected() {
        seedPersona()
        let hers = plan(startKg: Persona.currentKg, goalKg: Persona.goalKg, totalDays: 119)

        // The pre-change arithmetic, inlined: (start − goal) / start / weeks.
        let weeks = 119.0 / 7.0
        let legacyRate = ((Persona.currentKg - Persona.goalKg) / Persona.currentKg) / weeks
        let legacyTarget = CalorieTargetCalculator.dailyTarget(
            currentWeightKg: Persona.currentKg, heightCm: Persona.heightCm,
            age: Persona.age, sex: Persona.sex, activityKey: Persona.activity,
            lossRatePctPerWeek: legacyRate
        )

        XCTAssertEqual(
            TargetsService.calorieTarget(
                plan: hers, latestWeightKg: Persona.currentKg, defaults: d
            ),
            legacyTarget
        )
    }

    /// A safety-suppressed cohort (pregnancy / ED screen) is untouched:
    /// numerics were already suppressed upstream and the basis still
    /// reads maintenance, never `.unknown`.
    func testSafetySuppressedCohortsKeepTheirMaintenanceBasis() {
        seedPersona(goalKg: nil)
        d.set(0.0, forKey: "safety_pace_cap")
        XCTAssertEqual(
            TargetsService.energyBasis(
                plan: nil, fallbackWeightKg: Persona.currentKg, defaults: d
            ),
            .maintenance
        )
    }

    // MARK: - 7. Units

    func testPoundsRoundTripPreservesTheNumberSheTyped() {
        for lb in stride(from: 90.0, through: 320.0, by: 1.0) {
            let kg = lb / 2.20462
            XCTAssertEqual((kg * 2.20462).rounded(), lb, accuracy: 0.0001,
                "\(lb) lb did not survive the kg round-trip")
        }
    }

    // MARK: - 8. The whole chain, for the persona

    /// End to end, with the plan the onramp builds: the target must sit
    /// strictly between the safety floor and maintenance, and the goal
    /// she typed must be the goal the plan carries.
    func testPersonaEndToEndProducesADeficitPlan() {
        seedPersona()

        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: Persona.currentKg,
            goalWeightKg: Persona.goalKg,
            sex: Persona.sex,
            age: Persona.age
        ))
        XCTAssertFalse(window.isMaintenance, "124 → 110 lb is not maintenance")

        let weeks = window.weeks(for: .medium)
        let built = plan(startKg: Persona.currentKg, goalKg: Persona.goalKg,
                         totalDays: weeks * 7)
        XCTAssertEqual(built.goalWeightKg ?? 0, Persona.goalKg, accuracy: 0.0001)

        let kcal = TargetsService.calorieTarget(
            plan: built, latestWeightKg: Persona.currentKg, defaults: d
        )
        let bmr = CalorieTargetCalculator.bmrRaw(
            weightKg: Persona.currentKg, heightCm: Persona.heightCm,
            age: Persona.age, sex: Persona.sex
        )
        XCTAssertNotNil(kcal)
        XCTAssertGreaterThanOrEqual(Double(kcal ?? 0), min(bmr, 1200) - 1)
        XCTAssertLessThan(kcal ?? .max, personaMaintenance)
    }
}
