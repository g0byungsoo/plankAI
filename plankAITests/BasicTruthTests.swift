import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - BasicTruthTests
//
// docs/app_v25/30_BASIC_TRUTH.md, turned into law.
//
// The 2026-08-13 pass fixed the paths that LOSE the goal weight. This
// pass audited what happens when the app holds a plan that is not about
// her, and found the same defect alive one branch over, plus three more
// ways the number she is shown moves without her doing anything.
//
// Every test here is an invariant, not a pixel and not one person's
// calorie number:
//
//   1. A plan goal is only hers while it is a destination for HER body.
//   2. "No goal on file" cannot be rendered as a goal, whatever the plan
//      record happens to contain.
//   3. There is ONE ladder for "her current weight", and start weight is
//      the last rung, never the second.
//   4. Signing out and back in cannot move her energy target: every
//      activity answer round-trips through the alias that survives.
//   5. Missing inputs are NAMED, so a surface can offer the exact repair.
//   6. Nothing here changes the number for a user whose inputs are
//      unchanged and coherent.

@MainActor
final class BasicTruthTests: XCTestCase {

    // The same regression persona EnergyTruthTests uses: 5'3" · 124 lb ·
    // goal 110 lb · female · "walks here and there".
    private enum Persona {
        static let heightCm  = 160.02
        static let currentKg = 124 / 2.20462   // 56.245
        static let goalKg    = 110 / 2.20462   // 49.895
        static let age       = 34
        static let activity  = "walks"
    }

    private let d = UserDefaults.standard

    /// ONE shared store, never deallocated. `OV5Store` is `@Observable`,
    /// and the iOS 26.2 simulator aborts on an isolated class deinit —
    /// `OV5Flow.swift:170` names this family, and `V8ScriptTests` already
    /// holds its store statically for the same reason.
    ///
    /// My first version of the write-path tests below did `let store =
    /// OV5Store()` per test. The suite then reported **"Executed 984
    /// tests, with 0 failures"** and `** TEST FAILED **`: the process
    /// aborted partway and 119 tests never ran, while the line I was
    /// reading said zero failures. A fixture that crashes the runner and
    /// still prints a green count is worse than a failing one.
    private static let sharedStore = OV5Store()
    private var store: OV5Store { Self.sharedStore }

    private static let ownedKeys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onboardingPickedTier",
        "onboarding_goal_direction", "program_mode", "safety_pace_cap",
        "safety_numeric_suppression", "onboarding_glp1_status",
        "onboardingHormonalStage", "onboardingSleepHours",
        "onboarding_weight_trend", "onboarding_glp1_phase",
        "onb_v4_movement_baseline", "activityLevel", "onboardingActivityLevel",
        "onb_v5_age_years", "ageRange", "weightUnit",
    ]

    override func setUpWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
    }

    override func tearDownWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
    }

    private func seedPersona(goalKg: Double? = Persona.goalKg,
                             activity: String? = Persona.activity,
                             exactAge: Bool = true) {
        d.set(Persona.currentKg, forKey: "onboardingCurrentWeightKg")
        if let goalKg { d.set(goalKg, forKey: "onboardingGoalWeightKg") }
        d.set(Persona.heightCm, forKey: "onboardingHeightCm")
        d.set("female", forKey: "onboardingGender")
        if exactAge { d.set(Persona.age, forKey: "onb_v5_age_years") }
        if let activity { d.set(activity, forKey: "onb_v4_movement_baseline") }
        d.set("medium", forKey: "onboardingPickedTier")
        d.set("lose", forKey: "onboarding_goal_direction")
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

    private func summary(plan: ProgramPlanRecord?, latestKg: Double?) -> PlanSummary {
        PlanSummary.build(
            plan: plan, latestWeightKg: latestKg,
            proteinG: 90, stepsGoal: 7_500,
            numericsSuppressed: false, defaults: d
        )
    }

    // MARK: - 1 · A FOREIGN PLAN IS NOT HER GOAL
    //
    // Filmed on the shipping build: a 124 lb persona with NO goal on file
    // and a hydrated plan reading 75 kg → 65 kg was shown
    // `124 lb → 143.3 lb`, the words "you reached your goal", and a
    // 1,281 kcal DEFICIT target — three statements that contradict each
    // other, all built on a destination 19 lb ABOVE her body that appears
    // on no screen she has ever seen.

    func testPlanGoalAboveHerWeightIsNotAdoptedAsHerGoal() {
        seedPersona(goalKg: nil)                       // no goal on file
        let stale = plan(startKg: 75, goalKg: 65, totalDays: 140)

        let s = summary(plan: stale, latestKg: Persona.currentKg)

        XCTAssertEqual(s.intent, .goalMissing,
                       "a plan aiming ABOVE her weight was adopted as her goal")
        XCTAssertTrue(s.needsGoal, "the screen must ask instead of stating")
        XCTAssertNil(s.goalKg)
        XCTAssertNil(s.distanceKg, "no goal means no distance")
    }

    func testPlanGoalAboveHerWeightPublishesNoEnergyTarget() {
        seedPersona(goalKg: nil)
        let stale = plan(startKg: 75, goalKg: 65, totalDays: 140)

        let basis = TargetsService.energyBasis(
            plan: stale, fallbackWeightKg: Persona.currentKg, defaults: d
        )
        XCTAssertEqual(basis, .unknown,
                       "a deficit was computed toward a goal she is already past")

        XCTAssertNil(TargetsService.calorieTarget(
            plan: stale, latestWeightKg: Persona.currentKg, defaults: d
        ), "a number was published for a goal that exists on no screen")
    }

    /// The same reading must never say two opposite things at once. This
    /// is the specific frame that shipped: a goal, an arrival, AND a
    /// deficit.
    func testNoReadingStatesAnArrivalAndADeficitTogether() {
        seedPersona(goalKg: nil)
        let stale = plan(startKg: 75, goalKg: 65, totalDays: 140)

        let s = summary(plan: stale, latestKg: Persona.currentKg)
        let saysArrived = s.distanceLine() == "you reached your goal"
        XCTAssertFalse(saysArrived && s.energyKind == .deficit,
                       "the screen said 'you reached your goal' beside a deficit target")
    }

    /// The narrow case stays intact: with no goal of her own, a plan
    /// aiming BELOW her weight is a destination she once committed to and
    /// is still usable.
    func testPlanGoalBelowHerWeightStillStandsWhenSheHasNone() {
        seedPersona(goalKg: nil)
        let real = plan(startKg: 60, goalKg: 52, totalDays: 119)

        let s = summary(plan: real, latestKg: 58)
        guard case .losing(let goal) = s.intent else {
            return XCTFail("a coherent plan goal was discarded: \(s.intent)")
        }
        XCTAssertEqual(goal, 52, accuracy: 0.01)

        guard case .deficit = TargetsService.energyBasis(
            plan: real, fallbackWeightKg: 58, defaults: d
        ) else { return XCTFail("a coherent plan produced no deficit") }
    }

    // MARK: - 2 · ONE LADDER FOR HER WEIGHT
    //
    // `TargetsService.current` put the plan's START weight ahead of her
    // own stored answer; `PlanSummary`, `proteinTargetLight`,
    // `GoalWeightStore` and `ProfileHubView` all did the opposite. Filmed:
    // Home said `of 1,419 kcal` and the plan screen said `about 1,282
    // kcal`, same persona, same launch.

    func testHerAnswerOutranksAStalePlanStartWeight() {
        seedPersona()
        let stale = plan(startKg: 75, goalKg: 65, totalDays: 140)

        // The plan's goal disagrees with hers, so the rate comes from her
        // own onboarding numbers on BOTH paths. The only thing that can
        // still differ is the weight — which is the point.
        let planScreen = TargetsService.calorieTarget(
            plan: stale, latestWeightKg: Persona.currentKg, defaults: d
        )
        let fromLadder = TargetsService.calorieTarget(
            plan: stale, latestWeightKg: ladderWeight(plan: stale), defaults: d
        )
        XCTAssertEqual(planScreen, fromLadder,
                       "two surfaces resolved two different bodies for one user")
    }

    /// The ladder as `TargetsService.resolvedWeightKg` implements it,
    /// without a ModelContext: no logged weigh-in in this unit.
    private func ladderWeight(plan: ProgramPlanRecord?) -> Double? {
        let stored = d.double(forKey: "onboardingCurrentWeightKg")
        return stored > 0 ? stored : plan?.currentWeightKg
    }

    func testPlanStartWeightIsStillTheLastResort() {
        // Nothing stored, nothing logged — the plan is all there is, and
        // a number is better than silence here.
        d.set(Persona.heightCm, forKey: "onboardingHeightCm")
        d.set("female", forKey: "onboardingGender")
        d.set(Persona.age, forKey: "onb_v5_age_years")
        d.set(Persona.activity, forKey: "onb_v4_movement_baseline")
        d.set("medium", forKey: "onboardingPickedTier")
        let real = plan(startKg: 75, goalKg: 65, totalDays: 140)
        XCTAssertEqual(ladderWeight(plan: real), 75)
        XCTAssertNotNil(TargetsService.calorieTarget(
            plan: real, latestWeightKg: ladderWeight(plan: real), defaults: d
        ))
    }

    // MARK: - 3 · SIGNING BACK IN CANNOT MOVE HER TARGET
    //
    // The sign-out sweep removes `onb_v4_movement_baseline` (identity-
    // scoped body data) and hydrate restores only `activityLevel`, the
    // 3-value alias `UserRecord` carries. Two of the four answers changed
    // factor across that trip: "walks" became 1.55 (+215 kcal for this
    // persona, in the SURPLUS direction) and "very active" fell to the
    // 1.375 default because "athlete" was not in the table at all.
    //
    // Filmed before the fix: Home 1,419 → 1,690 kcal and the plan screen
    // 1,282 → 1,537 kcal, on one sign-out/sign-in, nothing else changed.

    func testEveryActivityAnswerRoundTripsThroughTheAliasThatSurvives() {
        for raw in ["barely", "walks", "regular_ish", "very_active"] {
            guard let alias = BodyFactsStore.alias(forBaseline: raw) else {
                return XCTFail("\(raw) has no completion alias")
            }
            XCTAssertEqual(
                CalorieTargetCalculator.activityFactor(for: raw),
                CalorieTargetCalculator.activityFactor(for: alias),
                "signing out changes the energy factor for '\(raw)' (alias '\(alias)')"
            )
        }
    }

    func testAthleteIsAnActivityValueNotAnUnknownOne() {
        XCTAssertEqual(CalorieTargetCalculator.activityFactor(for: "athlete"), 1.725)
        XCTAssertNotEqual(
            CalorieTargetCalculator.activityFactor(for: "athlete"),
            CalorieTargetCalculator.activityFactor(for: "definitely not a key"),
            "a value the app itself writes was falling through to the default"
        )
    }

    /// The alias change must not disturb the other three readers of
    /// `activityLevel`. Only the energy factor was wrong.
    func testTheWalksAliasIsInertForEveryOtherReader() {
        XCTAssertEqual(
            WorkoutGenerator.startingTier(experience: "some", baselineSeconds: 30,
                                          activityLevel: "walks", ageRange: "25to34"),
            WorkoutGenerator.startingTier(experience: "some", baselineSeconds: 30,
                                          activityLevel: "moderate", ageRange: "25to34")
        )
        let gate = { (key: String) in
            HardTierGate.isUnlocked(.init(
                isGLP1User: false, hasGentlerPaceStage: false, age: 30,
                activityLevel: key == "walks" ? .light : .moderate
            ))
        }
        XCTAssertEqual(gate("walks"), gate("moderate"))
    }

    /// The whole trip, end to end: her energy target must be the same
    /// number before and after the round trip that production performs.
    func testEnergyTargetSurvivesASignOutRoundTrip() {
        seedPersona()
        let before = TargetsService.calorieTarget(
            plan: nil, latestWeightKg: Persona.currentKg, defaults: d
        )

        // What `clearOnboardingUserDefaults` + `syncUserDefaultsFromUserRecord`
        // actually leave behind: the raw key gone, the alias restored.
        d.removeObject(forKey: "onb_v4_movement_baseline")
        d.set(BodyFactsStore.alias(forBaseline: Persona.activity)!, forKey: "activityLevel")

        let after = TargetsService.calorieTarget(
            plan: nil, latestWeightKg: Persona.currentKg, defaults: d
        )
        XCTAssertEqual(before, after,
                       "her daily target moved because she signed back in")
    }

    // MARK: - 4 · THE ONE ACTIVITY RESOLVER

    func testActivityResolverPrefersHerRawAnswerOverTheAlias() {
        d.set("very_active", forKey: "onb_v4_movement_baseline")
        d.set("sedentary", forKey: "activityLevel")
        XCTAssertEqual(TargetsService.activityKey(d), "very_active")
    }

    func testActivityResolverFallsToTheAliasAndNeverToADeadKey() {
        d.set("athlete", forKey: "activityLevel")
        // The key `ProgramSetupSubflow` used to read. It has no writers,
        // and a resolver that consults it would always see nothing.
        d.set("barely", forKey: "onboardingActivityLevel")
        XCTAssertEqual(TargetsService.activityKey(d), "athlete")
    }

    func testEmptyStringsAreAbsenceNotAnAnswer() {
        d.set("", forKey: "onb_v4_movement_baseline")
        d.set("regular_ish", forKey: "activityLevel")
        XCTAssertEqual(TargetsService.activityKey(d), "regular_ish",
                       "an empty raw key shadowed a real alias")
    }

    // MARK: - 5 · MISSING INPUTS ARE NAMED

    func testMissingWeightIsNamedWeight() {
        seedPersona()
        XCTAssertEqual(
            TargetsService.missingEnergyInput(plan: nil, latestWeightKg: nil, defaults: d),
            .weight
        )
    }

    func testMissingHeightIsNamedHeight() {
        seedPersona()
        d.removeObject(forKey: "onboardingHeightCm")
        XCTAssertEqual(
            TargetsService.missingEnergyInput(
                plan: nil, latestWeightKg: Persona.currentKg, defaults: d),
            .height
        )
    }

    func testMissingGoalIsNamedGoal() {
        seedPersona(goalKg: nil)
        XCTAssertEqual(
            TargetsService.missingEnergyInput(
                plan: nil, latestWeightKg: Persona.currentKg, defaults: d),
            .goal
        )
    }

    /// Maintenance is a real number, not a missing one. A user holding
    /// steady must never be told something is absent.
    func testMaintenanceIsNotAMissingInput() {
        seedPersona(goalKg: nil)
        d.set("maintenance", forKey: "program_mode")
        d.set("maintain", forKey: "onboarding_goal_direction")
        XCTAssertNil(
            TargetsService.missingEnergyInput(
                plan: nil, latestWeightKg: Persona.currentKg, defaults: d),
            "an intentional maintenance user was told a fact was missing"
        )
    }

    func testACoherentUserIsMissingNothing() {
        seedPersona()
        XCTAssertNil(TargetsService.missingEnergyInput(
            plan: nil, latestWeightKg: Persona.currentKg, defaults: d))
    }

    // MARK: - 6 · BACKWARD COMPATIBILITY
    //
    // The pin that matters most. A user whose plan agrees with her stored
    // goal gets the byte-identical number she got before this pass —
    // asserted against the arithmetic inline, not against the code under
    // test.

    func testTheCoherentUsersNumberIsUnchanged() {
        seedPersona()
        let coherent = plan(startKg: Persona.currentKg,
                            goalKg: Persona.goalKg, totalDays: 119)

        // Mifflin-St Jeor, female: 10w + 6.25h − 5a − 161.
        let bmr = 10 * Persona.currentKg + 6.25 * Persona.heightCm
            - 5 * Double(Persona.age) - 161
        let tdee = (bmr * 1.375).rounded()                  // "walks"
        let weeks = 119.0 / 7.0
        let rate = ((Persona.currentKg - Persona.goalKg) / Persona.currentKg) / weeks
        let deficit = rate * Persona.currentKg * 7_700 / 7
        let expected = Int(min(3_500, max(max(1_200, bmr), tdee - deficit)).rounded())

        XCTAssertEqual(
            TargetsService.calorieTarget(
                plan: coherent, latestWeightKg: Persona.currentKg, defaults: d),
            expected,
            "an unchanged coherent user's daily target moved"
        )
        XCTAssertEqual(expected, 1_282, "the persona's measured target drifted")
    }

    /// Her plan is not built yet — the pre-purchase reveal's number is
    /// still the one she is held to. Unchanged from the 2026-08-13 pass.
    func testTheNoPlanFallbackIsUnchanged() {
        seedPersona()
        XCTAssertEqual(
            TargetsService.calorieTarget(
                plan: nil, latestWeightKg: Persona.currentKg, defaults: d),
            1_282
        )
    }

    // MARK: - 7 · THE ALIAS MAP IS TOTAL AND CLOSED

    func testOnlyRealBaselineAnswersAreStorable() {
        XCTAssertNil(BodyFactsStore.alias(forBaseline: "moderate"),
                     "an alias was accepted as if it were an answer")
        XCTAssertNil(BodyFactsStore.alias(forBaseline: ""))
        XCTAssertNil(BodyFactsStore.alias(forBaseline: "athlete"))
    }

    func testActivityWordsNeverGuessForAnAbsentAnswer() {
        XCTAssertNil(BodyFactsStore.activityWords(d))
        d.set("walks", forKey: "onb_v4_movement_baseline")
        XCTAssertEqual(BodyFactsStore.activityWords(d), "walks here and there")
    }

    /// The one state the product cannot resolve and must therefore ASK
    /// about: a legacy account whose only surviving activity value is the
    /// alias that meant two different answers.
    func testTheCollapsedAliasIsFlaggedAmbiguousRatherThanGuessed() {
        d.set("moderate", forKey: "activityLevel")
        XCTAssertTrue(BodyFactsStore.activityIsAmbiguous(d))

        d.set("regular_ish", forKey: "onb_v4_movement_baseline")
        XCTAssertFalse(BodyFactsStore.activityIsAmbiguous(d),
                       "a raw answer on file is never ambiguous")
    }

    // MARK: - 8 · CURRENT vs START vs GOAL, AS A LIFECYCLE
    //
    // Three concepts, three facts, and the 2026-08-13 report is what it
    // looks like when any two of them collapse into each other. This is
    // the boring test, walked exactly as the audit brief specifies it,
    // through the REAL writers (`GoalWeightStore`, `WeightLogWriter`)
    // against a real container — not through the pure engines.
    //
    //   start 124 · current 121 · goal 110
    //     → edit the goal to 115   ⇒ start 124 · current 121 · goal 115
    //     → log 120                ⇒ start 124 · current 120 · goal 115

    func testStartCurrentAndGoalMoveIndependently() {
        let ctx = TestModelContainer.shared.mainContext
        let uid = "basic-truth-lifecycle"
        try? ctx.delete(model: ProgramPlanRecord.self,
                        where: #Predicate { $0.userId == "basic-truth-lifecycle" })
        try? ctx.delete(model: WeightLogRecord.self,
                        where: #Predicate { $0.userId == "basic-truth-lifecycle" })
        defer {
            try? ctx.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == "basic-truth-lifecycle" })
            try? ctx.delete(model: WeightLogRecord.self,
                            where: #Predicate { $0.userId == "basic-truth-lifecycle" })
        }

        let startKg   = 124 / 2.20462
        let currentKg = 121 / 2.20462
        let goalKg    = 110 / 2.20462
        seedPersona(goalKg: goalKg)

        // The plan she is living in, started twelve days ago at 124.
        let started = Calendar.current.date(byAdding: .day, value: -12, to: .now)!
        let plan = ProgramPlanRecord(
            userId: uid, startDate: started,
            goalDate: started.addingTimeInterval(119 * 86_400),
            totalDays: 119, currentWeightKg: startKg,
            goalWeightKg: goalKg, intensityTier: "medium"
        )
        ctx.insert(plan)
        WeightLogWriter.persist(kg: currentKg, userId: uid, in: ctx)
        let planId = plan.id
        let planStartDate = plan.startDate

        // — edit the goal to 115 lb.
        let newGoal = 115 / 2.20462
        GoalWeightStore.setGoalWeightKg(newGoal, userId: uid, in: ctx, defaults: d)

        XCTAssertEqual(plan.currentWeightKg ?? 0, startKg, accuracy: 0.01,
                       "editing the goal moved the START weight")
        XCTAssertEqual(TargetsService.latestWeightKg(userId: uid, in: ctx) ?? 0,
                       currentKg, accuracy: 0.01,
                       "editing the goal moved the CURRENT weight")
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), newGoal, accuracy: 0.01)
        XCTAssertEqual(plan.id, planId, "editing the goal minted a new plan")
        XCTAssertEqual(plan.startDate, planStartDate,
                       "editing the goal restarted her program")

        // — log 120 lb.
        let loggedKg = 120 / 2.20462
        WeightLogWriter.persist(kg: loggedKg, userId: uid, in: ctx)

        XCTAssertEqual(plan.currentWeightKg ?? 0, startKg, accuracy: 0.01,
                       "a weigh-in moved the START weight")
        XCTAssertEqual(TargetsService.latestWeightKg(userId: uid, in: ctx) ?? 0,
                       loggedKg, accuracy: 0.01)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), newGoal, accuracy: 0.01,
                       "a weigh-in moved the GOAL")
        XCTAssertEqual(plan.goalWeightKg ?? 0, newGoal, accuracy: 0.01)
        XCTAssertEqual(plan.startDate, planStartDate)
    }


    // MARK: - 9 · THE WRITE PATH ITSELF
    //
    // §3's laws are about how the alias is READ. This one walks the
    // WRITER — the real `OV5Store.assembleData()` the consult calls at
    // completion — for all four answers, because the round-trip law is
    // worthless if the value being round-tripped is not the value the
    // consult actually stores.

    func testAssembleDataWritesTheLosslessActivityAlias() {
        defer {
            d.removeObject(forKey: "onb_v4_movement_baseline")
            d.removeObject(forKey: "onb_v5_unit_lb")
            d.removeObject(forKey: "heightUnit")
        }
        for raw in ["barely", "walks", "regular_ish", "very_active"] {
            store.movementBaseline = raw
            let written = store.assembleData().activityLevel
            XCTAssertEqual(written, BodyFactsStore.alias(forBaseline: raw),
                           "the consult stores a different alias than BodyFactsStore for \(raw)")
            XCTAssertEqual(
                CalorieTargetCalculator.activityFactor(for: written),
                CalorieTargetCalculator.activityFactor(for: raw),
                "the value the consult stores for \(raw) reads back as a different factor"
            )
        }
    }

    /// The unit she picks on the ruler must reach the app in BOTH
    /// dimensions. `weightUnit` was fixed on 2026-08-13; `heightUnit` is
    /// the same defect one unit over — `onb_v5_unit_ftin` is swept by the
    /// `onb_v5_` prefix and never restored.
    func testTheUnitsShePicksReachTheApp() {
        defer {
            d.removeObject(forKey: "weightUnit")
            d.removeObject(forKey: "heightUnit")
            d.removeObject(forKey: "onb_v5_unit_lb")
            d.removeObject(forKey: "onb_v5_unit_ftin")
        }
        store.usesLb = false
        store.usesFtIn = false
        XCTAssertEqual(d.string(forKey: "weightUnit"), "kg")
        XCTAssertEqual(d.string(forKey: "heightUnit"), "cm")

        store.usesLb = true
        store.usesFtIn = true
        XCTAssertEqual(d.string(forKey: "weightUnit"), "lb")
        XCTAssertEqual(d.string(forKey: "heightUnit"), "ftin")
    }

    /// Her distance is stated in the unit SHE picked. Three
    /// acknowledgements hard-coded `lb`, so a kilogram user was told
    /// pounds one line after typing kilograms.
    func testTheDistanceIsStatedInHerOwnUnit() {
        defer {
            d.removeObject(forKey: "weightUnit")
            d.removeObject(forKey: "onb_v5_unit_lb")
            d.removeObject(forKey: "onb_v5_weight_kg")
            d.removeObject(forKey: "onb_v5_goal_kg")
            d.removeObject(forKey: "onboardingCurrentWeightKg")
            d.removeObject(forKey: "onboardingGoalWeightKg")
        }
        store.currentWeightKg = 56.245
        store.goalWeightKg = 49.895

        store.usesLb = true
        XCTAssertEqual(store.deltaWords, "14 lb")

        store.usesLb = false
        XCTAssertEqual(store.deltaWords, "6 kg",
                       "a kilogram user was told her distance in pounds")
    }
}
