import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - OneTargetEverywhereTests
//
// **ONE DERIVED TARGET, EVERYWHERE.**
//
// Home, the plan screen and jeni's envelope have each, in some era of
// this app, published a daily calorie number of their own. The customer
// report of 2026-08-13 and the four-numbers-one-body table in
// `docs/app_v25/30` §1 are what that costs. The rule is not "they happen
// to agree today"; it is that **all three read the same function**, and
// where there is no honest number, **all three say so**.
//
// This file is the table. Every row is a state a real account can be in,
// including the ones nobody designed for, and each is asserted three
// ways:
//
//   HOME     `TargetsService.current(...).kcal`
//   PLAN     `PlanSummary.build(...).energyKcal`
//   JENI     the `targets.kcal` the chat envelope publishes
//
// plus the honesty pair: when there is no target, `missingEnergyInput`
// must NAME the fact, and `PlanSummary` must not draw a number.

@MainActor
final class OneTargetEverywhereTests: XCTestCase {

    private let d = UserDefaults.standard
    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let userId = "one-target-tests"

    private static let ownedKeys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onboardingPickedTier",
        "onboarding_goal_direction", "program_mode", "safety_pace_cap",
        "safety_numeric_suppression", "onboarding_glp1_status",
        "onboardingHormonalStage", "onboardingSleepHours",
        "onboarding_weight_trend", "onboarding_glp1_phase",
        "onb_v4_movement_baseline", "activityLevel", "onboardingActivityLevel",
        "onb_v5_age_years", "ageRange", "onboardingAgeRange", "weightUnit",
    ]

    override func setUpWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        wipePlans()
    }

    override func tearDownWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        wipePlans()
    }

    private func wipePlans() {
        let uid = userId
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.delete(model: WeightLogRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.save()
    }

    // MARK: - The state matrix

    private struct State {
        let name: String
        var currentKg: Double? = 124 / 2.20462
        var goalKg: Double? = 110 / 2.20462
        /// A logged weigh-in, which outranks every stored weight.
        var latestKg: Double? = nil
        var heightCm: Double? = 160.02
        var sex: String = "female"
        var activity: String? = "walks"
        var ageYears: Int? = 34
        var glp1: String = ""
        var tier: String = "medium"
        var maintenance: Bool = false
        /// A plan record, described by (startKg, goalKg, totalDays).
        var plan: (Double, Double, Int)? = (124 / 2.20462, 110 / 2.20462, 119)
        /// True when NO honest target exists in this state.
        var expectsNoTarget: Bool = false
        var expectedMissing: TargetsService.MissingEnergyInput? = nil
    }

    private static let states: [State] = [
        State(name: "loss · complete facts"),
        State(name: "maintenance chosen", goalKg: nil, maintenance: true, plan: nil),
        State(name: "missing goal", goalKg: nil, plan: nil,
              expectsNoTarget: true, expectedMissing: .goal),
        State(name: "missing height", heightCm: nil,
              expectsNoTarget: true, expectedMissing: .height),
        State(name: "missing weight", currentKg: nil, plan: nil,
              expectsNoTarget: true, expectedMissing: .weight),
        State(name: "GLP-1 current", glp1: "current"),
        State(name: "non-GLP-1", glp1: "never"),
        State(name: "sedentary", activity: "barely"),
        State(name: "walks / light", activity: "walks"),
        State(name: "moderate", activity: "regular_ish"),
        State(name: "athlete", activity: "very_active"),
        State(name: "male", sex: "male"),
        State(name: "female", sex: "female"),
        State(name: "unspecified sex", sex: "nonbinary"),
        State(name: "restored: age from band only", ageYears: nil),
        State(name: "restored: collapsed activity alias", activity: "moderate"),
        State(name: "no plan record at all", plan: nil),
        State(name: "server-repaired legacy plan",
              plan: (75.0, 110 / 2.20462, 119)),
        State(name: "plan disagrees with her goal (stale hydrate)",
              plan: (75.0, 65.0, 140)),
        State(name: "plan goal above her body",
              plan: (75.0, 65.0, 140), expectsNoTarget: false),
        State(name: "soft tier", tier: "soft"),
        State(name: "hard tier", tier: "hard"),
        // She hit her target. A goal on file is not a missing goal, and
        // "holding" is a real number — the state used to publish neither.
        State(name: "goal reached", latestKg: 108 / 2.20462, plan: nil),
        State(name: "goal reached, to the gram",
              latestKg: 110 / 2.20462, plan: nil),
        // THE FABRICATION SIGNATURE: goal == current == start, written by
        // the app itself, never chosen. It must NOT read as "she asked to
        // hold" — that is the original customer bug wearing a new hat.
        State(name: "fabricated goal (== start)",
              goalKg: 124 / 2.20462, plan: nil,
              expectsNoTarget: true, expectedMissing: .goal),
    ]

    private func seed(_ s: State) {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        wipePlans()
        if let v = s.currentKg { d.set(v, forKey: "onboardingCurrentWeightKg") }
        if let v = s.goalKg { d.set(v, forKey: "onboardingGoalWeightKg") }
        if let v = s.heightCm { d.set(v, forKey: "onboardingHeightCm") }
        d.set(s.sex, forKey: "onboardingGender")
        if let v = s.activity { d.set(v, forKey: "onb_v4_movement_baseline") }
        if let v = s.ageYears {
            d.set(v, forKey: "onb_v5_age_years")
        } else {
            d.set("25to34", forKey: "ageRange")
        }
        d.set(s.glp1, forKey: "onboarding_glp1_status")
        d.set(s.tier, forKey: "onboardingPickedTier")
        if s.maintenance {
            d.set("maintain", forKey: "onboarding_goal_direction")
            d.set("maintenance", forKey: "program_mode")
        }
        if let v = s.latestKg {
            let log = WeightLogRecord(userId: userId, weightKg: v)
            context.insert(log)
            try? context.save()
        }
        if let (start, goal, days) = s.plan {
            let startDate = Calendar.current.date(byAdding: .day, value: -20, to: .now) ?? .now
            let plan = ProgramPlanRecord(
                userId: userId, startDate: startDate,
                goalDate: startDate.addingTimeInterval(Double(days) * 86_400),
                totalDays: days, currentWeightKg: start, goalWeightKg: goal,
                intensityTier: s.tier
            )
            plan.pendingUpsert = false
            context.insert(plan)
            try? context.save()
        }
    }

    /// THE THREE READERS, resolved exactly as the surfaces resolve them.
    private func readers() -> (home: Int?, plan: Int?, jeni: Int?, missing: TargetsService.MissingEnergyInput?) {
        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        let targets = TargetsService.current(userId: userId, in: context)
        let weight = TargetsService.resolvedWeightKg(userId: userId, plan: plan, in: context)
        let summary = PlanSummary.build(
            plan: plan, latestWeightKg: weight,
            proteinG: targets.proteinG, stepsGoal: targets.steps,
            numericsSuppressed: targets.numericsSuppressed, defaults: d
        )
        // The chat envelope publishes `snapshot.targets.kcal`, which IS
        // `TargetsService.current`. Reading it through the same call is
        // the point: if a fourth calculation ever appears, this line has
        // to change and someone has to justify it.
        let jeni = targets.kcal
        return (targets.kcal, summary.energyKcal, jeni,
                TargetsService.missingEnergyInput(
                    plan: plan, latestWeightKg: weight, defaults: d))
    }

    func testHomePlanAndJeniPublishTheSameNumberInEveryState() throws {
        for state in Self.states {
            seed(state)
            let r = readers()
            XCTAssertEqual(r.home, r.plan,
                "[\(state.name)] Home and the plan screen must publish the same integer")
            XCTAssertEqual(r.home, r.jeni,
                "[\(state.name)] jeni must quote the number the screens show")

            if state.expectsNoTarget {
                XCTAssertNil(r.home,
                    "[\(state.name)] no honest basis means NO number — never a quiet fall back to TDEE")
                XCTAssertNotNil(r.missing,
                    "[\(state.name)] and the missing fact must be nameable, or the empty state has no door")
                if let expected = state.expectedMissing {
                    XCTAssertEqual(r.missing, expected, "[\(state.name)]")
                }
            } else {
                XCTAssertNotNil(r.home, "[\(state.name)] a coherent state must produce a target")
                XCTAssertNil(r.missing,
                    "[\(state.name)] a publishable target must not also report a missing input")
            }
        }
    }

    /// A maintenance number is a REAL number and must never be reported
    /// as a missing input — and a missing goal must never be reported as
    /// maintenance. They are the same glyph and opposite instructions.
    func testMaintenanceAndMissingGoalAreNeverConfused() throws {
        seed(State(name: "maintenance", goalKg: nil, maintenance: true, plan: nil))
        var r = readers()
        XCTAssertNotNil(r.home, "she asked to hold; holding has a number")
        XCTAssertNil(r.missing, "and it is not an absence")

        seed(State(name: "no goal", goalKg: nil, plan: nil))
        r = readers()
        XCTAssertNil(r.home)
        XCTAssertEqual(r.missing, .goal)

        // And the arrival branch must not become a second fallback into
        // maintenance. `goal == current == start` is the app's own
        // fabrication, not a decision she made.
        seed(State(name: "fabricated", goalKg: 124 / 2.20462, plan: nil))
        r = readers()
        XCTAssertNil(r.home,
            "a goal the app invented must never be published as a maintenance target — that IS the 2026-08-13 report")
        XCTAssertEqual(r.missing, .goal)

        // Arrival, on the other hand, is real: a loss goal, met.
        seed(State(name: "arrived", latestKg: 108 / 2.20462, plan: nil))
        r = readers()
        XCTAssertNotNil(r.home, "she got there; holding has a number")
        XCTAssertNil(r.missing)
    }

    /// The backward-compatibility pin. A user whose facts are coherent
    /// and unchanged gets the byte-identical number, asserted against the
    /// arithmetic inlined here rather than against the code under test.
    func testTheCoherentPersonaStillGetsHerExactNumber() throws {
        seed(State(name: "persona"))
        let r = readers()

        let kg = 124 / 2.20462, cm = 160.02, age = 34.0
        let bmr = 10 * kg + 6.25 * cm - 5 * age - 161
        // TDEE rounds to a whole calorie BEFORE the deficit comes off —
        // `dailyTarget` takes `Double(tdee(...))`. Skipping that
        // intermediate rounding here puts the expectation one kcal out,
        // which is how this assertion first failed: the test was wrong,
        // not the arithmetic.
        let tdee = Double(max(1200, Int((bmr * 1.375).rounded())))
        let rate = ((kg - 110 / 2.20462) / kg) / (119.0 / 7.0)
        let deficit = rate * kg * 7700.0 / 7.0
        let expected = Int(min(3500.0, max(max(1200.0, bmr), tdee - deficit)).rounded())

        XCTAssertEqual(r.home, expected,
            "the 5'3\" 124 lb persona's target is arithmetic, not a preference")
        XCTAssertEqual(r.home, 1282, "and it is the number the record has pinned since 2026-08-13")
    }

    // MARK: - The disagreement matrix (docs/app_v25/31 §9)
    //
    // Adversarial combinations. There must be ONE coherent answer or an
    // explicit repair state — never "whichever record was easiest to
    // reach".

    func testALoggedWeighInOutranksEveryStoredWeight() throws {
        seed(State(name: "conflict"))
        let log = WeightLogRecord(userId: userId, weightKg: 121 / 2.20462)
        context.insert(log)
        try context.save()
        defer {
            context.delete(log)
            try? context.save()
        }

        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        XCTAssertEqual(
            TargetsService.resolvedWeightKg(userId: userId, plan: plan, in: context) ?? 0,
            121 / 2.20462, accuracy: 0.01,
            "the freshest weigh-in is her weight; the onboarding answer and the plan's start weight are older facts")
        XCTAssertEqual(plan?.currentWeightKg ?? 0, 124 / 2.20462, accuracy: 0.01,
            "and the plan's START weight is untouched by it — 'since you started' has to keep meaning something")
    }

    func testAPlanAimingAboveHerBodyIsNeverAdoptedAsHerGoal() throws {
        // The filmed defect: a hydrated plan reading 75 -> 65 adopted as
        // the goal of a 56 kg woman, rendered "124 lb -> 143.3 lb" beside
        // the words "you reached your goal".
        seed(State(name: "stale plan, no stored goal", goalKg: nil,
                   plan: (75.0, 65.0, 140)))
        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        let summary = PlanSummary.build(
            plan: plan,
            latestWeightKg: TargetsService.resolvedWeightKg(
                userId: userId, plan: plan, in: context),
            proteinG: 70, stepsGoal: 7_500, numericsSuppressed: false, defaults: d
        )
        XCTAssertEqual(summary.intent, .goalMissing)
        XCTAssertNil(summary.energyKcal)
        XCTAssertNotEqual(summary.distanceLine(unit: .lb), "you reached your goal")
    }

    func testHerStoredGoalOutranksADisagreeingPlan() throws {
        seed(State(name: "disagreement", plan: (75.0, 65.0, 140)))
        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        let summary = PlanSummary.build(
            plan: plan,
            latestWeightKg: TargetsService.resolvedWeightKg(
                userId: userId, plan: plan, in: context),
            proteinG: 70, stepsGoal: 7_500, numericsSuppressed: false, defaults: d
        )
        XCTAssertEqual(summary.goalKg ?? 0, 110 / 2.20462, accuracy: 0.01,
            "the goal she can see and edit is the goal the screen states")
        XCTAssertEqual(TargetsService.current(userId: userId, in: context).kcal,
                       summary.energyKcal,
            "and the number the math uses is the number on the screen")
    }
}
