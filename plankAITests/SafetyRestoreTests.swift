import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - SafetyRestoreTests
//
// **DO NOT DELETE THIS FILE WITHOUT READING THIS PARAGRAPH.**
//
// A user can answer something in the consult that makes Jeni refuse to
// put her in a calorie deficit — she is pregnant, the eating-pattern
// screen came back positive, her BMI is under 18.5, she takes insulin,
// she is under 18. The gate writes that decision to four `@AppStorage`
// keys (`safety_pace_cap`, `safety_numeric_suppression`,
// `program_mode`, `onboarding_goal_direction`) and builds her a plan
// with `goal == start`.
//
// `AppSync.clearOnboardingUserDefaults()` sweeps the whole `safety_`
// family by prefix, and `program_mode` and `onboarding_goal_direction`
// by name. It is right to: on a shared device, user A's clinical
// answers must never bend user B's program. **Nothing puts them back.**
// `UserRecord` has no field for any of them and `public.users` has no
// column the client writes.
//
// So after a sign-out → sign-in, a reinstall, or a new phone:
//
//   1. `isMaintenanceRequested` → false. The hold is gone.
//   2. `safetyRateCap` → nil (a missing key reads 0.0, and the guard is
//      `> 0`). Every clamp is gone.
//   3. `CohortStore.isNumericSuppressed` → false. The numerals return.
//   4. `energyBasis` falls to rule 3 — the onboarding fallback added on
//      2026-08-13 — which re-derives a rate from her stored LOSS goal
//      and publishes **a deficit**.
//
// The production build lands these users on TDEE, because the old
// `planImpliedRate` returned 0 for a `goal == start` plan. The next
// build's fallback turns that accident into a real deficit. **The
// change that makes the branch reachable owns the branch.**
//
//     AN ACCOUNT TRANSITION MAY FORGET THE DEVICE.
//     IT MAY NEVER FORGET A SAFETY DECISION.
//
// The tests below hold both halves of that, and they must both stay
// true: ACCOUNT A's safety state must survive A's own round trip, and
// must reach ACCOUNT B under no circumstances.

@MainActor
final class SafetyRestoreTests: XCTestCase {

    private let d = UserDefaults.standard
    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let userId = "SAFE0000-0000-4000-8000-00000000AAAA"
    private let otherId = "SAFE0000-0000-4000-8000-00000000BBBB"

    /// Every key these tests write or the sweep removes. Reset both
    /// ways so a failure cannot leak into the next class.
    private static let ownedKeys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onboardingPickedTier",
        "onboarding_goal_direction", "program_mode",
        "safety_pace_cap", "safety_numeric_suppression",
        "safety_pregnancy_status", "safety_scoff_yes", "safety_scoff_core",
        "safety_screen_completed",
        "onboarding_glp1_status", "onboarding_glp1_phase",
        "onboardingHormonalStage", "onboardingSleepHours",
        "onboarding_weight_trend", "onboardingStressLevel",
        "onboardingFoodRelationship", "onboarding_medication_status",
        "onb_v4_movement_baseline", "activityLevel", "onb_v5_age_years",
        "ageRange", "onboardingAgeRange", "weightUnit",
        "hasCompletedOnboarding",
    ]

    override func setUpWithError() throws { reset() }
    override func tearDownWithError() throws { reset() }

    private func reset() {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        for uid in [userId, otherId] {
            try? context.delete(model: ProgramPlanRecord.self,
                                where: #Predicate { $0.userId == uid })
            try? context.delete(model: WeightLogRecord.self,
                                where: #Predicate { $0.userId == uid })
            try? context.delete(model: UserRecord.self,
                                where: #Predicate { $0.id == uid })
        }
        try? context.save()
    }

    // MARK: - The bodies

    /// The regression body, in the units the app stores.
    private enum Body {
        static let heightCm = 160.02          // 5'3"
        static let currentKg = 124 / 2.20462  // 56.2452
        static let goalKg = 110 / 2.20462     // 49.8952 — SHE ASKED TO LOSE
        /// BMI 17.6 at the same height: the `bmi_low` branch's body. Her
        /// stored goal is BELOW it, because the gate fires on the body
        /// she has, not on the goal she picked — she asked to lose and
        /// the screen held her.
        static let underweightKg = 45.0
        static let underweightGoalKg = 42.0
    }

    /// What the pre-paywall gate wrote, per reason. Taken from
    /// `ProgramGoalCalculator.SafetyAssessment.paceCap` /
    /// `.numericSuppression`, not invented.
    private struct GateOutput {
        let reason: String
        let paceCap: Double
        let suppression: Bool
        let programMode: String
        var pregnancyStatus: String = ""
        var scoffYes: Int = -1
        var medicationKey: String = ""
        var ageBand: String = "25to34"
        var exactAge: Int = 34
        var currentKg: Double = Body.currentKg
        var goalKg: Double = Body.goalKg

        static let pregnant = GateOutput(
            reason: "pregnant", paceCap: 0, suppression: true,
            programMode: "maintenance", pregnancyStatus: "pregnant")
        static let edScreen = GateOutput(
            reason: "ed_screen", paceCap: 0, suppression: true,
            programMode: "recovery", scoffYes: 3)
        static let bmiLow = GateOutput(
            reason: "bmi_low", paceCap: 0, suppression: false,
            programMode: "maintenance",
            currentKg: Body.underweightKg, goalKg: Body.underweightGoalKg)
        static let breastfeeding = GateOutput(
            reason: "breastfeeding", paceCap: 0.0025, suppression: false,
            programMode: "maintenance", pregnancyStatus: "breastfeeding")
        /// The one capped-but-not-held cohort: `.blocked` writes
        /// `program_mode = "blocked"`, so rule 1 does NOT fire and the
        /// deficit is governed purely by the 0.25%/wk cap.
        static let under18 = GateOutput(
            reason: "under18", paceCap: 0.0025, suppression: false,
            programMode: "blocked", ageBand: "under18", exactAge: 17)
        /// The control: a clean pass. `-1` is the sentinel for "no cap".
        static let cleanPass = GateOutput(
            reason: "ok", paceCap: -1, suppression: false,
            programMode: "loss")
    }

    // MARK: - Seeding

    /// HER DEVICE, the day after the consult: the gate's four outputs,
    /// her body facts, and the plan `ProgramSetupSubflow` built from
    /// them. A zero cap builds `goal == start`
    /// (`safetyAdjustedGoalWeightKg`); a positive cap builds a real loss
    /// plan whose geometry already carries the clamp.
    @discardableResult
    private func seedDevice(_ gate: GateOutput, glp1: String = "") -> ProgramPlanRecord {
        d.set(gate.currentKg, forKey: "onboardingCurrentWeightKg")
        d.set(gate.goalKg, forKey: "onboardingGoalWeightKg")
        d.set(Body.heightCm, forKey: "onboardingHeightCm")
        d.set("female", forKey: "onboardingGender")
        d.set(gate.ageBand, forKey: "onboardingAgeRange")
        // The consult stores the exact year; the `onb_v5_` prefix sweep
        // takes it and only the band comes home. That drift is the
        // documented 35 kcal (`31` §5) and it is the ONLY drift an
        // ordinary user is allowed to see.
        d.set(gate.exactAge, forKey: "onb_v5_age_years")
        d.set("walks", forKey: "onb_v4_movement_baseline")
        d.set("medium", forKey: "onboardingPickedTier")
        d.set("lb", forKey: "weightUnit")
        d.set(true, forKey: "hasCompletedOnboarding")
        if !glp1.isEmpty { d.set(glp1, forKey: "onboarding_glp1_status") }

        // The gate's own writes (`SafetyGatePresentation.route`).
        d.set(gate.paceCap, forKey: "safety_pace_cap")
        d.set(gate.suppression, forKey: "safety_numeric_suppression")
        d.set(gate.programMode, forKey: "program_mode")
        d.set(true, forKey: "safety_screen_completed")
        if !gate.pregnancyStatus.isEmpty {
            d.set(gate.pregnancyStatus, forKey: "safety_pregnancy_status")
        }
        if gate.scoffYes >= 0 { d.set(gate.scoffYes, forKey: "safety_scoff_yes") }
        if !gate.medicationKey.isEmpty {
            d.set(gate.medicationKey, forKey: "onboarding_medication_status")
        }

        let start = Calendar.current.date(byAdding: .day, value: -26, to: .now) ?? .now
        // THE PLAN `ProgramSetupSubflow` WOULD HAVE BUILT, through the
        // same calculator with the same cap — not a number typed into a
        // fixture. A zero cap collapses the goal onto the start weight
        // (`safetyAdjustedGoalWeightKg`); a positive cap leaves a real
        // loss goal and stretches the window instead.
        let planGoal = gate.paceCap == 0 ? gate.currentKg : gate.goalKg
        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: gate.currentKg,
            goalWeightKg: planGoal,
            sex: .female,
            age: nil,
            isGLP1User: ProgramGoalCalculator.isGLP1User(from: glp1),
            paceCapPctPerWeek: gate.paceCap > 0 ? gate.paceCap : nil
        ))
        let days = window.weeks(for: .medium) * 7
        let plan = ProgramPlanRecord(
            userId: userId, startDate: start,
            goalDate: start.addingTimeInterval(Double(days) * 86_400),
            totalDays: days, currentWeightKg: gate.currentKg,
            goalWeightKg: planGoal, intensityTier: "medium"
        )
        plan.pendingUpsert = false
        context.insert(plan)
        context.insert(serverRecord(gate, glp1: glp1))
        try? context.save()
        return plan
    }

    /// THE SERVER ROW, exactly as `hydrateUser` leaves the local
    /// `UserRecord`. Note what is NOT here: there is no field on
    /// `UserRecord` for a pace cap, a suppression flag, a pregnancy
    /// answer, a SCOFF count, a program mode or a goal direction. That
    /// absence is the defect, stated as a fixture.
    private func serverRecord(_ gate: GateOutput, glp1: String = "") -> UserRecord {
        let record = UserRecord(id: userId, name: "restored")
        record.onboardingCurrentWeightKg = gate.currentKg
        record.onboardingGoalWeightKg = gate.goalKg
        record.onboardingHeightCm = Body.heightCm
        record.onboardingGender = "female"
        record.onboardingAgeRange = gate.ageBand
        record.onboardingActivityLevel = "walks"
        if !glp1.isEmpty { record.onboardingGlp1Status = glp1 }
        record.pendingUpsert = false
        return record
    }

    /// THE ROUND TRIP, performed with the production functions.
    ///
    /// The sweep is `AppSync.clearOnboardingUserDefaults()` itself — not
    /// a list of keys copied into a test, which is how a sweep test
    /// stops testing the sweep. The restore is what `hydrateUser` →
    /// `syncUserDefaultsFromUserRecord` performs: the two static
    /// mirrors, plus the two keys that function writes inline.
    private func signOutAndBackIn(as record: UserRecord) {
        AppSync.shared.clearOnboardingUserDefaults()
        AppSync.restoreBodyDefaults(from: record, into: d)
        AppSync.restoreCohortDefaults(from: record, into: d)
        AppSync.mirrorActivityAlias(from: record, into: d)
        if let band = record.onboardingAgeRange { d.set(band, forKey: "ageRange") }
        if let act = record.onboardingActivityLevel { d.set(act, forKey: "activityLevel") }
        d.set(true, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Readers

    private func basis() -> TargetsService.EnergyBasis {
        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        let weight = TargetsService.resolvedWeightKg(
            userId: userId, plan: plan, in: context) ?? 0
        return TargetsService.energyBasis(
            plan: plan, fallbackWeightKg: weight, defaults: d)
    }

    private func targets() -> TargetsService.Targets {
        TargetsService.current(userId: userId, in: context)
    }

    private func isDeficit(_ b: TargetsService.EnergyBasis) -> Bool {
        if case .deficit(let r) = b { return r > 0 }
        return false
    }

    // MARK: - ① THE HOLD MUST SURVIVE HER OWN ACCOUNT

    /// A pregnancy hold, through a sign-out and back in.
    ///
    /// This is the whole session in one test. Before: `.maintenance`,
    /// no deficit, no numerals. After: the sweep has removed every
    /// output the gate wrote, and rule 3 re-derives a rate from the
    /// loss goal she gave the consult BEFORE the gate ran.
    func testAPregnancyHoldMustNotBecomeADeficitWhenSheSignsBackIn() throws {
        seedDevice(.pregnant)
        XCTAssertEqual(basis(), .maintenance,
            "before: the gate's instruction is in force")

        signOutAndBackIn(as: serverRecord(.pregnant))

        XCTAssertFalse(isDeficit(basis()),
            "AN ACCOUNT TRANSITION MAY NEVER FORGET A SAFETY DECISION. She told Jeni not to put her in a deficit; signing back in must not undo that.")
    }

    /// The eating-pattern screen. Same shape, different reason, and the
    /// one where a resumed deficit is least acceptable.
    func testAnEatingPatternHoldMustNotBecomeADeficitWhenSheSignsBackIn() throws {
        seedDevice(.edScreen)
        XCTAssertEqual(basis(), .maintenance)

        signOutAndBackIn(as: serverRecord(.edScreen))

        XCTAssertFalse(isDeficit(basis()),
            "a positive eating-pattern screen is the one state where a silently resumed deficit is a harm, not an inconvenience")
    }

    /// BMI < 18.5. Unlike the two above, **this one is reconstructible**
    /// — height and current weight both survive the round trip — so the
    /// app should not need to ask anybody anything.
    func testALowBMIHoldIsRebuiltFromFactsThatSurvive() throws {
        seedDevice(.bmiLow)
        XCTAssertEqual(basis(), .maintenance)

        signOutAndBackIn(as: serverRecord(.bmiLow))

        XCTAssertEqual(basis(), .maintenance,
            "her height and her weight both came back, so the gate's own arithmetic can be re-run — no ask, no guess, no deficit")
    }

    /// A FRESH DEVICE. Nothing was ever swept because nothing was ever
    /// here; the hydrate is the only writer. This is the case
    /// "stop sweeping on a same-account sign-in" cannot reach.
    func testAFreshDeviceRestoresTheSameSafeProgram() throws {
        seedDevice(.pregnant)
        let record = serverRecord(.pregnant)

        // A brand-new phone: no @AppStorage at all, the same account.
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        AppSync.restoreBodyDefaults(from: record, into: d)
        AppSync.restoreCohortDefaults(from: record, into: d)
        AppSync.mirrorActivityAlias(from: record, into: d)
        d.set(record.onboardingAgeRange ?? "", forKey: "ageRange")
        d.set(true, forKey: "hasCompletedOnboarding")

        XCTAssertFalse(isDeficit(basis()),
            "a new phone is the commonest account transition and the one a sweep-time fix cannot reach at all")
    }

    /// The containment for a cohort the gate instructed us to show no
    /// numerals to. Suppression itself cannot be reconstructed — there
    /// is no column and it must never be inferred — so the guarantee
    /// that has to hold is the stronger one: **she is not handed a
    /// calorie target either.**
    func testASuppressedCohortIsNotHandedACalorieNumberAfterRestore() throws {
        seedDevice(.edScreen)
        XCTAssertNil(targets().kcal, "before: suppression withholds the numeral")

        signOutAndBackIn(as: serverRecord(.edScreen))

        XCTAssertNil(targets().kcal,
            "after: the suppression flag is gone and cannot be rebuilt, so the refusal has to come from the basis instead")
    }

    /// The 0.25%/wk cohorts. `under18` survives because the age band
    /// does; the cap must clamp a later goal edit exactly as it clamped
    /// the build.
    func testAnUnderageCapStillClampsARecomputedHorizonAfterRestore() throws {
        seedDevice(.under18)
        let cappedDays = try XCTUnwrap(
            ProgramService.shared.activePlan(userId: userId, in: context)?.totalDays)

        signOutAndBackIn(as: serverRecord(.under18))
        GoalWeightStore.setGoalWeightKg(Body.goalKg, userId: userId, in: context, defaults: d)

        let after = try XCTUnwrap(
            ProgramService.shared.activePlan(userId: userId, in: context)?.totalDays)
        XCTAssertGreaterThanOrEqual(after, cappedDays,
            "the gate capped her glide at 0.25%/wk. A goal edit after a sign-in must not hand a 17-year-old the uncapped window.")
    }

    // MARK: - ② THE COHORT FACTS THE SERVER ALREADY HOLDS

    /// GLP-1 status is on `users` and has been since 2026-06-23. It is
    /// swept on sign-out and never restored, so a GLP-1 payer comes back
    /// as a non-GLP-1 user: the protein floor drops from 1.6 g/kg to
    /// 1.2, the 0.3%/wk pace floor is gone, and `HardTierGate` unlocks.
    func testTheGLP1ProteinFloorSurvivesTheAccountTransition() throws {
        seedDevice(.cleanPass, glp1: "current")
        let before = try XCTUnwrap(targets().proteinG)
        XCTAssertTrue(CohortStore.isGLP1Current, "before: she is on a GLP-1")

        signOutAndBackIn(as: serverRecord(.cleanPass, glp1: "current"))

        XCTAssertTrue(CohortStore.isGLP1Current,
            "the server has carried onboarding_glp1_status since 2026-06-23; the client simply never read it back")
        XCTAssertEqual(targets().proteinG, before,
            "the lean-mass floor is the cohort's cited advisory band, not a preference")
    }

    /// The same fact through the pace floor: a GLP-1 user's gentlest
    /// glide is 0.3%/wk, not 0.5%.
    func testTheGLP1PaceFloorSurvivesTheAccountTransition() throws {
        seedDevice(.cleanPass, glp1: "current")
        signOutAndBackIn(as: serverRecord(.cleanPass, glp1: "current"))

        GoalWeightStore.setPaceTier(.soft, userId: userId, in: context, defaults: d)
        let days = try XCTUnwrap(
            ProgramService.shared.activePlan(userId: userId, in: context)?.totalDays)
        // 6.35 kg at 0.3%/wk of 56.245 kg ≈ 38 weeks; at 0.5%/wk ≈ 23.
        XCTAssertGreaterThan(days, 23 * 7,
            "losing the cohort silently speeds her up, which is the opposite of what the cited band says")
    }

    // MARK: - ③ THE APP ASKS, AND ONLY HER ANSWER GETS HER OUT

    /// `missingEnergyInput` used to answer `.goal` for every `.unknown`
    /// basis, so a woman who had already given us a goal weight was
    /// pointed at "add a goal weight". She taps it, re-enters the same
    /// number, and nothing changes — `31` §8's exact dead end.
    func testTheUnknownDirectionNamesItselfInsteadOfTheGoalSheAlreadyGave() throws {
        seedDevice(.pregnant)
        signOutAndBackIn(as: serverRecord(.pregnant))

        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        XCTAssertEqual(
            TargetsService.missingEnergyInput(
                plan: plan,
                latestWeightKg: TargetsService.resolvedWeightKg(
                    userId: userId, plan: plan, in: context),
                defaults: d),
            .direction,
            "she has a goal weight on file. the fact that is missing is which way this plan points.")
    }

    /// The plan screen must not state a goal and a distance over a
    /// screen with no daily number.
    func testThePlanScreenAsksInsteadOfClaimingSheIsLosing() throws {
        seedDevice(.pregnant)
        signOutAndBackIn(as: serverRecord(.pregnant))

        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        let summary = PlanSummary.build(
            plan: plan,
            latestWeightKg: TargetsService.resolvedWeightKg(
                userId: userId, plan: plan, in: context),
            proteinG: 90, stepsGoal: 7_500, numericsSuppressed: false, defaults: d)
        XCTAssertEqual(summary.intent, .directionUnknown)
        XCTAssertTrue(summary.needsDirection)
        XCTAssertNil(summary.energyKcal, "no basis, no number")
    }

    /// And jeni is told the same thing, in the same word.
    func testTheCoachIsNotToldToAskForAGoalWeightSheAlreadyGave() throws {
        seedDevice(.pregnant)
        signOutAndBackIn(as: serverRecord(.pregnant))

        let envelope = CoachContextAssembler.assemble(userId: userId, in: context)
        let targetsBlock = envelope["targets"] as? [String: Any]
        XCTAssertEqual(targetsBlock?["kcal_missing"] as? String, "direction",
            "the coach and the screen must name the same missing fact, or the product has two front desks")
        XCTAssertNil(targetsBlock?["kcal"],
            "and jeni must not quote a number the screens refuse to draw")
    }

    /// HER ANSWER IS THE ONLY WAY OUT, and it goes both ways.
    func testHerOwnAnswerIsTheOnlyWayOutOfTheHold() throws {
        seedDevice(.pregnant)
        signOutAndBackIn(as: serverRecord(.pregnant))
        XCTAssertFalse(isDeficit(basis()))

        GoalWeightStore.setDirection(holding: true, defaults: d)
        XCTAssertEqual(basis(), .maintenance,
            "she says it holds: a real number, and it is a maintenance estimate")

        GoalWeightStore.setDirection(holding: false, defaults: d)
        XCTAssertTrue(isDeficit(basis()),
            "she says she is losing: her own goal weight prices the deficit, exactly as rule 3 intends")
    }

    /// The answer must not cost her anything else. It writes two keys.
    func testAnsweringTheDirectionTouchesNothingButTheDirection() throws {
        let plan = seedDevice(.pregnant)
        let id = plan.id
        let startDate = plan.startDate
        let startWeight = plan.currentWeightKg
        let goal = plan.goalWeightKg
        let days = plan.totalDays
        signOutAndBackIn(as: serverRecord(.pregnant))

        GoalWeightStore.setDirection(holding: true, defaults: d)

        let after = try XCTUnwrap(ProgramService.shared.activePlan(userId: userId, in: context))
        XCTAssertEqual(after.id, id)
        XCTAssertEqual(after.startDate, startDate)
        XCTAssertEqual(after.currentWeightKg, startWeight)
        XCTAssertEqual(after.goalWeightKg, goal)
        XCTAssertEqual(after.totalDays, days)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), Body.goalKg,
            "her goal weight is still on file, so 'holding' stays reversible from the goal ritual")
    }

    /// THE DERIVED CAP MAY ONLY FILL AN ABSENCE. A device that still
    /// holds the gate's answer must behave exactly as it did yesterday,
    /// including when the gate's answer is "no cap".
    func testTheDerivedCapIsNeverConsultedWhileTheStoredAnswerIsOnFile() throws {
        // A clean pass whose body has since dropped below BMI 18.5.
        d.set(Body.heightCm, forKey: "onboardingHeightCm")
        d.set(-1.0, forKey: "safety_pace_cap")
        XCTAssertNil(
            TargetsService.resolvedSafetyCap(currentWeightKg: Body.underweightKg, d),
            "the gate ran once, pre-paywall, and said no cap. Re-screening her from a later weight would be a new feature, not a restore.")

        d.removeObject(forKey: "safety_pace_cap")
        XCTAssertEqual(
            TargetsService.resolvedSafetyCap(currentWeightKg: Body.underweightKg, d), 0,
            "with the answer GONE, the derivable half of the gate's own arithmetic is re-run")
    }

    /// The three reasons that are not derivable are never guessed.
    func testPregnancyAndTheEatingScreenAreNeverInferred() throws {
        d.set(Body.heightCm, forKey: "onboardingHeightCm")
        d.set("25to34", forKey: "onboardingAgeRange")
        XCTAssertNil(
            TargetsService.derivedSafetyCap(currentWeightKg: Body.currentKg, d),
            "a healthy-BMI adult derives NO cap. Pregnancy, a positive eating-pattern screen and an insulin prescription have no server-side proxy and must never be inferred from one.")
    }

    // MARK: - ④ CROSS-ACCOUNT ISOLATION MUST STILL HOLD

    /// ACCOUNT A is safety-restricted. ACCOUNT B is an ordinary
    /// weight-loss user on the same phone. B must inherit NOTHING.
    ///
    /// This is the test that makes "just stop sweeping" unshippable,
    /// and it must keep passing after any repair.
    func testAccountBInheritsNoneOfAccountAsSafetyState() throws {
        seedDevice(.pregnant, glp1: "current")

        // B signs in. The sweep runs, then B's own record hydrates.
        AppSync.shared.clearOnboardingUserDefaults()
        let b = UserRecord(id: otherId, name: "b")
        b.onboardingCurrentWeightKg = 80
        b.onboardingGoalWeightKg = 70
        b.onboardingHeightCm = 170
        b.onboardingGender = "female"
        b.onboardingAgeRange = "35to44"
        b.onboardingActivityLevel = "walks"
        b.pendingUpsert = false
        AppSync.restoreBodyDefaults(from: b, into: d)
        AppSync.restoreCohortDefaults(from: b, into: d)
        AppSync.mirrorActivityAlias(from: b, into: d)
        d.set(b.onboardingAgeRange ?? "", forKey: "ageRange")

        XCTAssertNil(d.object(forKey: "safety_pace_cap"),
            "A's pace cap must not clamp B's program")
        XCTAssertFalse(d.bool(forKey: "safety_numeric_suppression"),
            "B must not lose her numbers because A was screened")
        XCTAssertNil(d.object(forKey: "safety_pregnancy_status"))
        XCTAssertNil(d.object(forKey: "safety_scoff_yes"))
        XCTAssertNil(d.string(forKey: "program_mode"))
        XCTAssertNil(d.string(forKey: "onboarding_goal_direction"))
        XCTAssertFalse(CohortStore.isGLP1Current,
            "A's medication state is A's clinical intake")
        XCTAssertFalse(CohortStore.isMaintenanceMode)
        XCTAssertEqual(d.double(forKey: "onboardingCurrentWeightKg"), 80,
            "and B's own body facts are the ones on the device")
    }

    /// The clean-record guard, on the new mirror. A record carrying an
    /// unsent local edit is not server truth and must overwrite nothing
    /// — the same rule `restoreBodyDefaults` runs on, for the same
    /// reason (`31` §12 rule 1).
    func testADirtyRecordNeverOverwritesTheCohortOnThisDevice() throws {
        d.set("current", forKey: "onboarding_glp1_status")
        let pending = UserRecord(id: userId, name: "her edit is unsent")
        pending.onboardingGlp1Status = "past"
        pending.pendingUpsert = true

        AppSync.restoreCohortDefaults(from: pending, into: d)

        XCTAssertEqual(d.string(forKey: "onboarding_glp1_status"), "current",
            "her unsent edit wins in both directions")
    }

    /// And an absent server value never deletes a fact the device holds
    /// (`31` §12 rule 3) — the "lose the goal" defect arriving from the
    /// other direction.
    func testAnAbsentServerCohortValueNeverDeletesALocalFact() throws {
        d.set("current", forKey: "onboarding_glp1_status")
        d.set("perimenopause", forKey: "onboardingHormonalStage")
        let blank = UserRecord(id: userId, name: "legacy row")
        blank.pendingUpsert = false

        AppSync.restoreCohortDefaults(from: blank, into: d)

        XCTAssertEqual(d.string(forKey: "onboarding_glp1_status"), "current")
        XCTAssertEqual(d.string(forKey: "onboardingHormonalStage"), "perimenopause")
    }

    // MARK: - ⑤ THE FRESH-DEVICE CONTRACT

    /// **DEVICE B, ZERO LOCAL STATE, SAME ACCOUNT.**
    ///
    /// The one place the whole restore contract is stated as a list. If
    /// a future field is added to `UserRecord` and to the upsert but not
    /// to a restore path, this file is where it should be caught — and
    /// the two sections below say plainly which facts the server carries
    /// and which it does not, so the second list can never be quietly
    /// mistaken for the first.
    func testEveryProgramCriticalServerFactReachesAFreshDevice() throws {
        let record = UserRecord(id: userId, name: "maya")
        record.onboardingCurrentWeightKg = Body.currentKg
        record.onboardingGoalWeightKg = Body.goalKg
        record.onboardingHeightCm = Body.heightCm
        record.onboardingGender = "female"
        record.onboardingAgeRange = "35to44"
        record.onboardingActivityLevel = "walks"
        record.onboardingGlp1Status = "current"
        record.onboardingGlp1Phase = "established"
        record.onboardingHormonalStage = "perimenopause"
        record.onboardingSleepHours = "under5"
        record.onboardingWeightTrend = "cycling"
        record.onboardingStressLevel = "heavy"
        record.onboardingFoodRelationship = "control"
        record.pendingUpsert = false

        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        AppSync.restoreBodyDefaults(from: record, into: d)
        AppSync.restoreCohortDefaults(from: record, into: d)
        AppSync.mirrorActivityAlias(from: record, into: d)
        d.set(record.onboardingAgeRange ?? "", forKey: "ageRange")

        // ON THE SERVER, AND HOME AFTER THIS PASS.
        XCTAssertEqual(d.double(forKey: "onboardingCurrentWeightKg"), Body.currentKg)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), Body.goalKg)
        XCTAssertEqual(d.double(forKey: "onboardingHeightCm"), Body.heightCm)
        XCTAssertEqual(d.string(forKey: "onboardingGender"), "female")
        XCTAssertEqual(d.string(forKey: "activityLevel"), "walks")
        XCTAssertEqual(TargetsService.ageBandOnFile(d), "35to44")
        XCTAssertTrue(CohortStore.isGLP1Current, "the protein floor and the pace floor")
        XCTAssertTrue(CohortStore.isPerimenopausal, "the cycle gating reads the stage")
        XCTAssertTrue(CohortStore.hasGentlerPaceStage, "the pace floor and the Hard lock")
        XCTAssertTrue(CohortStore.isShortSleeper, "the 0.4%/wk floor")
        XCTAssertTrue(CohortStore.isRegainRisk, "the cycling-trend floor")
        XCTAssertTrue(CohortStore.isHighStress)
        XCTAssertTrue(CohortStore.isRestrictiveRisk, "the quiet-hours gate")

        // NOT ON THE SERVER, AND THEREFORE NOT HERE. Every one of these
        // is a decision the gate made and no column records. They are
        // NOT inferred, and the calorie deficit is refused instead
        // (§`planHoldsWithUnknownDirection`). The lossless fix is
        // persistence, and it is a migration.
        XCTAssertNil(d.object(forKey: "safety_pace_cap"))
        XCTAssertFalse(d.bool(forKey: "safety_numeric_suppression"))
        XCTAssertNil(d.object(forKey: "safety_pregnancy_status"))
        XCTAssertNil(d.object(forKey: "safety_scoff_yes"))
        XCTAssertNil(d.string(forKey: "onboarding_medication_status"))
        XCTAssertTrue(TargetsService.directionIsUnknown(d))
        XCTAssertTrue(TargetsService.ageIsApproximate(d),
            "the exact year is coarse to its band, stated on screen as `about N`")
    }

    // MARK: - ⑥ ORDINARY USERS MUST NOT MOVE

    /// The golden persona: 5'3", 124 lb, goal 110 lb, coherent, no
    /// safety flag. Her number is a release fixture
    /// (`CalorieGoldenMatrixTests`) and nothing in a safety repair may
    /// touch it — before the round trip or after it.
    func testTheOrdinaryLossUserIsUntouchedByAnySafetyRepair() throws {
        seedDevice(.cleanPass)
        XCTAssertEqual(targets().kcal, 1282,
            "the anchor number, unchanged since 2026-08-13")
        XCTAssertTrue(isDeficit(basis()), "and it is a real deficit, from her own plan")

        signOutAndBackIn(as: serverRecord(.cleanPass))

        XCTAssertEqual(targets().kcal, 1317,
            "the ONLY permitted drift is the documented age band (docs/app_v25/32 §3). A safety repair that moves this number is a safety repair that broke an ordinary customer.")
        XCTAssertTrue(isDeficit(basis()),
            "an ordinary loss user still gets a deficit after signing back in")
    }

    /// A user who never signed out still holds the gate's answer, so
    /// nothing about her resolution may change either.
    func testADeviceThatStillHoldsTheGateAnswerIsUnchanged() throws {
        seedDevice(.pregnant)
        XCTAssertEqual(basis(), .maintenance)
        XCTAssertNil(targets().kcal, "suppression is still in force")

        reset()
        seedDevice(.breastfeeding)
        XCTAssertEqual(basis(), .maintenance,
            "breastfeeding assesses as .maintenance, so `route` writes program_mode = maintenance and rule 1 holds her — the 0.25%/wk cap shapes the PLAN, and the mode decides the basis")

        reset()
        seedDevice(.under18)
        // `.blocked` is the one capped mode that is not maintenance, so
        // this is where the cap itself has to do the work.
        XCTAssertTrue(isDeficit(basis()))
        if case .deficit(let rate) = basis() {
            XCTAssertLessThanOrEqual(rate, 0.0025 + 0.00001,
                "the cap clamps the rate while the answer is on the device")
        }
    }
}
