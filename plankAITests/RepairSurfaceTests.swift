import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - RepairSurfaceTests
//
// **CAN SHE FIX IT HERSELF?**
//
// The support desk's answer to "my calories look wrong" used to be
// *delete your account and start over*. `GoalWeightStore` (2026-08-13)
// and `BodyFactsStore` (2026-08-14) closed the goal, the height and the
// movement answer. This file holds the last three inputs to the same
// equation — the SEX term, the AGE term and the PACE — and the rule
// every repair obeys:
//
//   a repair changes the number and NOTHING ELSE.
//   not the start date. not the start weight. not the goal. not the
//   plan's identity. not a single logged thing.
//
// Two of these were promises already printed on screen and impossible to
// keep: the consult acknowledges *"we'll use the more conservative
// equation. you can change this anytime"* and the pace screen says
// *"pick the rhythm. you can change it later."*

@MainActor
final class RepairSurfaceTests: XCTestCase {

    private let d = UserDefaults.standard
    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let userId = "repair-surface-tests"

    private static let keys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onb_v5_gender",
        "onboardingPickedTier", "onboarding_goal_direction", "program_mode",
        "safety_pace_cap", "onb_v4_movement_baseline", "activityLevel",
        "onb_v5_age_years", "ageRange", "onboardingAgeRange",
        "onboarding_glp1_status", "onboardingHormonalStage",
    ]

    override func setUpWithError() throws {
        Self.keys.forEach { d.removeObject(forKey: $0) }
        wipe()
        d.set(124 / 2.20462, forKey: "onboardingCurrentWeightKg")
        d.set(110 / 2.20462, forKey: "onboardingGoalWeightKg")
        d.set(160.02, forKey: "onboardingHeightCm")
        d.set("female", forKey: "onboardingGender")
        d.set(34, forKey: "onb_v5_age_years")
        d.set("walks", forKey: "onb_v4_movement_baseline")
        d.set("medium", forKey: "onboardingPickedTier")
    }

    override func tearDownWithError() throws {
        Self.keys.forEach { d.removeObject(forKey: $0) }
        wipe()
    }

    private func wipe() {
        let uid = userId
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.delete(model: UserRecord.self,
                            where: #Predicate { $0.id == uid })
        try? context.save()
    }

    @discardableResult
    private func seedPlan(days: Int = 119) -> ProgramPlanRecord {
        let start = Calendar.current.date(byAdding: .day, value: -18, to: .now) ?? .now
        let plan = ProgramPlanRecord(
            userId: userId, startDate: start,
            goalDate: start.addingTimeInterval(Double(days) * 86_400),
            totalDays: days, currentWeightKg: 124 / 2.20462,
            goalWeightKg: 110 / 2.20462, intensityTier: "medium"
        )
        plan.pendingUpsert = false
        context.insert(plan)
        let record = UserRecord(id: userId, name: "tester")
        context.insert(record)
        try? context.save()
        return plan
    }

    private var kcal: Int? {
        TargetsService.current(userId: userId, in: context).kcal
    }

    // MARK: - Sex

    func testCorrectingTheSexTermMovesTheTargetAndNothingElse() throws {
        let plan = seedPlan()
        let startDate = plan.startDate
        let planId = plan.id
        let before = try XCTUnwrap(kcal)

        BodyFactsStore.setSex("male", userId: userId, in: context)

        let after = try XCTUnwrap(kcal)
        // Mifflin-St Jeor's only sex term: -161 vs +5. 166 kcal of BMR,
        // times the light activity factor, minus nothing else.
        XCTAssertEqual(Double(after - before), 166 * 1.375, accuracy: 2.0,
            "the delta is the equation's own constant, not a new formula")

        XCTAssertEqual(plan.id, planId, "a sex correction does not restart her program")
        XCTAssertEqual(plan.startDate, startDate)
        XCTAssertEqual(plan.currentWeightKg ?? 0, 124 / 2.20462, accuracy: 0.001,
            "and does not touch her start weight")
        XCTAssertEqual(plan.goalWeightKg ?? 0, 110 / 2.20462, accuracy: 0.001,
            "or her goal")
        XCTAssertEqual(plan.totalDays, 119, "or her horizon")
    }

    func testTheSexTermSurvivesASignOutRoundTrip() throws {
        seedPlan()
        BodyFactsStore.setSex("male", userId: userId, in: context)
        let uid = userId
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid })).first)
        XCTAssertEqual(record.onboardingGender, "male",
            "the record is the only thing that survives the sweep")

        // The sweep, then the restore.
        d.removeObject(forKey: "onboardingGender")
        d.removeObject(forKey: "onb_v5_gender")
        record.pendingUpsert = false
        AppSync.restoreBodyDefaults(from: record, into: d)

        XCTAssertEqual(TargetsService.profileInputs(d).sex, .male)
    }

    func testTheTwoNonBinaryAnswersRunTheConservativeEquationAndSaySo() throws {
        seedPlan()
        for key in ["nonbinary", "private"] {
            BodyFactsStore.setSex(key, userId: userId, in: context)
            XCTAssertEqual(TargetsService.profileInputs(d).sex, .unspecified)
            XCTAssertTrue(BodyFactsStore.sexUsesConservativeEquation(d),
                "\(key): the assumption has to be sayable, or it is presented as neutral arithmetic")
        }
        BodyFactsStore.setSex("female", userId: userId, in: context)
        XCTAssertFalse(BodyFactsStore.sexUsesConservativeEquation(d))
    }

    func testAnUnknownSexKeyIsRefusedRatherThanStored() throws {
        seedPlan()
        BodyFactsStore.setSex("woman", userId: userId, in: context)
        XCTAssertEqual(d.string(forKey: "onboardingGender"), "female",
            "an unrecognised key silently becomes the conservative equation; refuse it at the door instead")
    }

    // MARK: - Age

    func testCorrectingTheAgeMovesTheTargetByFiveCaloriesAYear() throws {
        seedPlan()
        let before = try XCTUnwrap(kcal)
        BodyFactsStore.setAgeYears(44, userId: userId, in: context)
        let after = try XCTUnwrap(kcal)
        XCTAssertEqual(Double(before - after), 10 * 5 * 1.375, accuracy: 2.0)
        XCTAssertEqual(d.string(forKey: "ageRange"), "35to44")
        XCTAssertEqual(d.string(forKey: "onboardingAgeRange"), "35to44",
            "both band keys, because two different readers read two different ones")
    }

    func testTheAgeIsMarkedApproximateExactlyWhenItCameFromABand() throws {
        seedPlan()
        XCTAssertFalse(TargetsService.ageIsApproximate(d),
            "she typed 34; nothing is approximate about it")
        XCTAssertEqual(TargetsService.knownAge(d), 34)

        // What a sign-out actually leaves: the exact year swept, the band
        // restored from UserRecord.
        d.removeObject(forKey: "onb_v5_age_years")
        d.set("25to34", forKey: "ageRange")
        XCTAssertTrue(TargetsService.ageIsApproximate(d),
            "29 is not her age; it is the midpoint of her range, and the screen must say so")
        XCTAssertEqual(TargetsService.knownAge(d), 29)
    }

    func testAnAgeWeDoNotHoldIsNilRatherThanTheCohortDefault() throws {
        seedPlan()
        d.removeObject(forKey: "onb_v5_age_years")
        d.removeObject(forKey: "ageRange")
        d.removeObject(forKey: "onboardingAgeRange")
        XCTAssertNil(TargetsService.knownAge(d),
            "a SAFETY GATE must be able to tell 'she is 29' from 'we are guessing 32'")
        XCTAssertEqual(TargetsService.profileInputs(d).age, 32,
            "while the arithmetic keeps its documented conservative fallback")
    }

    func testTheBandIsFoundUnderEitherKey() throws {
        seedPlan()
        d.removeObject(forKey: "onb_v5_age_years")
        d.removeObject(forKey: "ageRange")
        d.set("45to54", forKey: "onboardingAgeRange")
        XCTAssertEqual(TargetsService.profileInputs(d).age, 49,
            "the consult writes one key and the cloud restore writes the other; reading one handed her the 32-year-old default")
    }

    func testTheRevealAndTheAppAgreeOnEveryAgeBand() throws {
        for band in ["under18", "18to24", "25to34", "35to44", "45to54", "55plus"] {
            XCTAssertEqual(EnergyLedger.ageMidpoint(fromRange: band),
                           TargetsService.representativeAge(band: band),
                "\(band): the pre-purchase quote and the daily target must run the same age")
        }
        XCTAssertEqual(EnergyLedger.ageMidpoint(fromRange: "55+"),
                       TargetsService.representativeAge(band: "55plus"),
            "legacy hyphen/plus rows too")
    }

    // MARK: - Pace

    func testChangingThePaceMovesTheFinishLineAndNothingElse() throws {
        let plan = seedPlan()
        let planId = plan.id
        let startDate = plan.startDate
        let startWeight = plan.currentWeightKg
        let goal = plan.goalWeightKg
        let before = plan.totalDays

        let result = GoalWeightStore.setPaceTier(.soft, userId: userId, in: context)

        XCTAssertEqual(result.tier, .soft)
        XCTAssertFalse(result.wasRefused)
        XCTAssertEqual(plan.intensityTier, "soft")
        XCTAssertGreaterThan(plan.totalDays, before,
            "a gentler pace is a longer plan, and the horizon has to follow or the rate stays wrong")
        XCTAssertEqual(plan.goalDate,
                       Calendar.current.date(byAdding: .day, value: plan.totalDays,
                                             to: plan.startDate) ?? plan.goalDate,
            accuracy: 86_400 * 2)

        XCTAssertEqual(plan.id, planId, "same plan; changing pace is not re-enrolling")
        XCTAssertEqual(plan.startDate, startDate, "same start date; her day number does not move")
        XCTAssertEqual(plan.currentWeightKg, startWeight)
        XCTAssertEqual(plan.goalWeightKg, goal)
        XCTAssertEqual(d.string(forKey: "onboardingPickedTier"), "soft")
    }

    func testThePaceEditorCannotUnlockHardWhereThePickerLocksIt() throws {
        seedPlan()
        d.set("current", forKey: "onboarding_glp1_status")
        XCTAssertFalse(GoalWeightStore.hardIsUnlocked(d))

        let result = GoalWeightStore.setPaceTier(.hard, userId: userId, in: context)
        XCTAssertTrue(result.wasRefused,
            "an editor that could unlock Hard where the picker locks it is a safety gate with a back door")
        XCTAssertEqual(result.tier, .medium)
        XCTAssertEqual(d.string(forKey: "onboardingPickedTier"), "medium")
    }

    func testThePaceChangeIsQueuedForTheServer() throws {
        let plan = seedPlan()
        GoalWeightStore.setPaceTier(.soft, userId: userId, in: context)
        XCTAssertTrue(plan.pendingUpsert,
            "her own edit is the newest fact; it has to reach the server or the next hydrate reverts it")
    }

    func testAPaceChangeWithNoPlanStillRecordsThePreference() throws {
        // No plan record: the onramp is two taps she may not have taken.
        GoalWeightStore.setPaceTier(.soft, userId: userId, in: context)
        XCTAssertEqual(d.string(forKey: "onboardingPickedTier"), "soft",
            "TargetsService.onboardingImpliedRate reads this, so it means something even before a plan exists")
    }

    // MARK: - The safety gate's age vocabulary

    func testTheHardGateReadsAnAgeVocabularyThatIsActuallyWritten() throws {
        // `ProgramSetupSubflow.parsedAge` switched on "18-24"/"55+",
        // which nothing writes, so `HardTierGate` saw age == nil and
        // locked Hard for every human being — with a lock reason that
        // named no reason.
        d.set(30, forKey: "onb_v5_age_years")
        d.set("regular_ish", forKey: "onb_v4_movement_baseline")
        d.set("never", forKey: "onboarding_glp1_status")
        XCTAssertEqual(TargetsService.knownAge(d), 30)
        XCTAssertTrue(GoalWeightStore.hardIsUnlocked(d))

        d.set(41, forKey: "onb_v5_age_years")
        XCTAssertFalse(GoalWeightStore.hardIsUnlocked(d), "past 40 the gate closes, as written")

        d.set(30, forKey: "onb_v5_age_years")
        d.set("barely", forKey: "onb_v4_movement_baseline")
        XCTAssertFalse(GoalWeightStore.hardIsUnlocked(d),
            "and week 1 of Hard is not for someone who is not moving yet")
    }
}

private func XCTAssertEqual(
    _ a: Date, _ b: Date, accuracy: TimeInterval,
    file: StaticString = #filePath, line: UInt = #line
) {
    XCTAssertEqual(a.timeIntervalSince1970, b.timeIntervalSince1970,
                   accuracy: accuracy, file: file, line: line)
}
