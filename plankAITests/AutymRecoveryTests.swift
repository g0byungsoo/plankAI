import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - AutymRecoveryTests
//
// **DO NOT DELETE THIS FILE WITHOUT READING THIS PARAGRAPH.**
//
// A paying customer wrote in. Her `program_plans` row said
// `start = 124 lb`, `goal = 124 lb`, `210 days`. A goal equal to the
// start weight is not a weight-loss plan, so every energy path read it
// as maintenance and published her maintenance estimate as her daily
// food target. Support repaired the row in the database —
// `goal = 110 lb`, `119 days`, `goal_date = start + 119` — and confirmed
// her `users` profile had held `goal = 110` the whole time.
//
// **Her phone went on showing 124.**
//
// The database was right and the device stayed wrong, which means the
// recovery contract itself had failed. Three separate walls stood
// between a corrected row and her screen, and it took all three falling
// to fix it:
//
//   1. `AppSync.shouldHydrateOnLaunch` only fires when some synced
//      family is locally EMPTY, and a settled payer's device has none —
//      so the launch hydrate never ran for the people who have been
//      paying longest. (`AppSync.refreshProgramTruth`.)
//   2. `SyncService.applyHydratedProgramPlans` was insert-only, so even
//      when it did run it skipped a plan whose id it already had.
//      (`ProgramPlanMerge`.)
//   3. `AppSync.restoreBodyDefaults` was absent-only, so the corrected
//      goal landed in the local `UserRecord` and never reached the
//      `@AppStorage` key every surface reads.
//
// Each of the three, alone, is enough to keep her on the wrong number.
// The tests below hold all three, plus the thing that makes a repair
// worth doing at all: **the repaired value must not be pushed back over
// by the device on the next sync.** A visually-correct reader over a
// poisoned writer is not a fix.

@MainActor
final class AutymRecoveryTests: XCTestCase {

    // The customer's own numbers. 5'3", 124 lb today, 110 lb wanted,
    // female, 18-24, "moderate" on file, an active program already
    // running when the corruption was found.
    private enum Autym {
        static let heightCm  = 160.02
        static let currentKg = 124 / 2.20462      // 56.2445
        static let goalKg    = 110 / 2.20462      // 49.8954
        static let corruptGoalKg = currentKg       // goal == start: THE BUG
        static let corruptTotalDays = 210
        static let repairedTotalDays = 119
        static let ageBand = "18to24"
    }

    private let d = UserDefaults.standard
    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let userId = "AAAA0000-0000-0000-0000-00000000A17M"

    private static let ownedKeys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onboardingPickedTier",
        "onboarding_goal_direction", "program_mode", "safety_pace_cap",
        "onb_v4_movement_baseline", "activityLevel", "onb_v5_age_years",
        "ageRange", "onboarding_glp1_status", "onboardingHormonalStage",
        "onboardingSleepHours", "onboarding_weight_trend",
        "onboarding_glp1_phase", "weightUnit",
    ]

    override func setUpWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        wipe()
    }

    override func tearDownWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        wipe()
    }

    private func wipe() {
        let uid = userId
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.delete(model: UserRecord.self,
                            where: #Predicate { $0.id == uid })
        try? context.delete(model: WeightLogRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.save()
    }

    // MARK: - The fixture: what her phone held, and what the server held

    private let startDate = Calendar.current.date(
        byAdding: .day, value: -26, to: Calendar.current.startOfDay(for: .now)
    ) ?? .now

    private let planId = "BBBB0000-1111-2222-3333-0000000000P1"

    /// HER DEVICE. Stale plan (goal == start, 210 days) plus the locally
    /// persisted facts that reproduce the output she reported.
    @discardableResult
    private func seedDevice(
        localGoalKg: Double = Autym.corruptGoalKg,
        planGoalKg: Double? = nil,
        dirty: Bool = false
    ) -> ProgramPlanRecord {
        d.set(Autym.currentKg, forKey: "onboardingCurrentWeightKg")
        d.set(localGoalKg, forKey: "onboardingGoalWeightKg")
        d.set(Autym.heightCm, forKey: "onboardingHeightCm")
        d.set("female", forKey: "onboardingGender")
        d.set(Autym.ageBand, forKey: "ageRange")
        d.set("moderate", forKey: "activityLevel")
        d.set("medium", forKey: "onboardingPickedTier")
        d.set("lb", forKey: "weightUnit")

        let plan = ProgramPlanRecord(
            id: planId,
            userId: userId,
            startDate: startDate,
            goalDate: startDate.addingTimeInterval(Double(Autym.corruptTotalDays) * 86_400),
            totalDays: Autym.corruptTotalDays,
            currentWeightKg: Autym.currentKg,
            goalWeightKg: planGoalKg ?? Autym.corruptGoalKg,
            intensityTier: "medium"
        )
        plan.pendingUpsert = dirty
        context.insert(plan)

        let record = UserRecord(id: userId, name: "autym")
        record.onboardingGoalWeightKg = localGoalKg
        record.onboardingCurrentWeightKg = Autym.currentKg
        record.onboardingHeightCm = Autym.heightCm
        record.onboardingGender = "female"
        record.onboardingActivityLevel = "moderate"
        record.pendingUpsert = false
        context.insert(record)
        try? context.save()
        return plan
    }

    /// THE SERVER, after support repaired it. `hydrateUser` copies every
    /// column of `users` into the local record already (guarded by
    /// `pendingUpsert`), so the repaired profile is modelled by writing
    /// the record — the untested seam is the network, not the copy.
    private func repairServerProfile(goalKg: Double = Autym.goalKg) {
        let uid = userId
        guard let record = try? context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid })).first else { return }
        record.onboardingGoalWeightKg = goalKg
        record.pendingUpsert = false
        try? context.save()
    }

    /// The repaired `program_plans` row, exactly as PostgREST returns it:
    /// lowercase uuid columns, `yyyy-MM-dd` dates.
    private func repairedServerRow(
        goalKg: Double = Autym.goalKg,
        totalDays: Int = Autym.repairedTotalDays,
        phase: String = "active"
    ) -> ProgramPlanHydrateRow {
        let dateOnly: (Date) -> String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            return { f.string(from: $0) }
        }()
        return ProgramPlanHydrateRow(
            id: planId.lowercased(),
            user_id: userId.lowercased(),
            start_date: dateOnly(startDate),
            goal_date: dateOnly(startDate.addingTimeInterval(Double(totalDays) * 86_400)),
            total_days: totalDays,
            current_weight_kg: Autym.currentKg,
            goal_weight_kg: goalKg,
            intensity_tier: "medium",
            phase: phase,
            parent_plan_id: nil,
            archived_at: nil,
            completed_at: nil
        )
    }

    private func hydrate(_ rows: [ProgramPlanHydrateRow]) {
        SyncService.applyHydratedProgramPlans(rows, userId: userId, context: context)
        let uid = userId
        if let record = try? context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid })).first {
            AppSync.restoreBodyDefaults(from: record, into: d)
            AppSync.mirrorActivityAlias(from: record, into: d)
        }
    }

    private func summary(_ plan: ProgramPlanRecord?) -> PlanSummary {
        PlanSummary.build(
            plan: plan,
            latestWeightKg: TargetsService.resolvedWeightKg(
                userId: userId, plan: plan, in: context),
            proteinG: 90, stepsGoal: 7_500, numericsSuppressed: false,
            defaults: d
        )
    }

    // MARK: - THE AUTYM TEST

    /// SERVER → DEVICE. The repair reaches her, and takes nothing with it.
    func testServerRepairReachesCustomerWithoutResettingHerProgram() throws {
        let plan = seedDevice()

        // A weigh-in and a program-day check stand for "her history".
        let log = WeightLogRecord(userId: userId, weightKg: Autym.currentKg)
        context.insert(log)
        try context.save()

        // BEFORE — the state she reported.
        let before = summary(plan)
        XCTAssertEqual(before.intent, .goalMissing,
            "with goal == start the plan is not a loss plan; the next build already refuses to call it one")
        XCTAssertNil(before.energyKcal,
            "and refuses to publish a number for a destination nobody chose")

        // THE REPAIR ARRIVES.
        repairServerProfile()
        hydrate([repairedServerRow()])

        // AFTER — resolved goal is 110.
        let after = summary(plan)
        XCTAssertEqual(after.goalKg ?? 0, Autym.goalKg, accuracy: 0.01,
            "the repaired goal must be the one every surface resolves")
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), Autym.goalKg, accuracy: 0.01,
            "and it must reach the @AppStorage key the surfaces actually read, not just the local UserRecord")

        // The plan summary reads 124 -> 110.
        XCTAssertEqual(after.currentKg ?? 0, Autym.currentKg, accuracy: 0.01)
        XCTAssertEqual(after.distanceKg ?? 0, Autym.currentKg - Autym.goalKg, accuracy: 0.01)
        XCTAssertEqual(after.distanceLine(unit: .lb), "14 lb to go")

        // PLAN IDENTITY AND START DATE ARE EXPLICITLY UNCHANGED. Minting
        // a fresh plan resets her day count; that incident is documented
        // at AppSync:520 and it is not an acceptable repair.
        XCTAssertEqual(plan.id, planId, "the plan she is living in keeps its identity")
        XCTAssertEqual(plan.startDate, startDate, "and its start date — the day anchor")
        XCTAssertEqual(
            try context.fetchCount(FetchDescriptor<ProgramPlanRecord>(
                predicate: #Predicate { $0.id == "BBBB0000-1111-2222-3333-0000000000P1" })), 1,
            "the repair must not mint a second plan")

        // The horizon travels WITH the goal, or the rate stays wrong.
        XCTAssertEqual(plan.totalDays, Autym.repairedTotalDays)
        XCTAssertEqual(plan.goalWeightKg ?? 0, Autym.goalKg, accuracy: 0.01)

        // CURRENT WEIGHT IS INDEPENDENT. Goal and current collapsing into
        // each other is the original defect; a repair must not re-do it.
        XCTAssertEqual(plan.currentWeightKg ?? 0, Autym.currentKg, accuracy: 0.01,
            "the plan's start weight is not the goal and never becomes it")
        XCTAssertEqual(d.double(forKey: "onboardingCurrentWeightKg"), Autym.currentKg, accuracy: 0.01)

        // HISTORY UNTOUCHED.
        let logId = log.id
        XCTAssertEqual(
            try context.fetchCount(FetchDescriptor<WeightLogRecord>(
                predicate: #Predicate { $0.id == logId })), 1,
            "a plan repair may never take a weigh-in with it")

        // And the number means something again.
        XCTAssertEqual(after.energyKind, .deficit)
        XCTAssertNotNil(after.energyKcal)
        XCTAssertEqual(
            TargetsService.energyBasis(plan: plan, fallbackWeightKg: Autym.currentKg, defaults: d),
            .deficit(ratePctPerWeek: ((Autym.currentKg - Autym.goalKg) / Autym.currentKg)
                     / (Double(Autym.repairedTotalDays) / 7.0)))
    }

    /// DEVICE → SERVER. No resurrection.
    ///
    /// This is the half that decides whether the repair was worth doing.
    /// `upsertProgramPlan` sends the WHOLE row, so a local copy that
    /// stayed stale would push 124 back over the repaired 110 the moment
    /// anything marked it dirty.
    func testRepairedGoalIsNotResurrectedByTheNextOutboundSync() throws {
        let plan = seedDevice()
        repairServerProfile()
        hydrate([repairedServerRow()])

        // 1. Adoption is a READ. It must not queue a push of its own.
        XCTAssertFalse(plan.pendingUpsert,
            "adopting the server's own row and then pushing it back is a write loop, not a merge")

        // 2. Whatever dirties the row next — an archive, a graduation, a
        //    re-enroll — the row it pushes now carries the REPAIRED
        //    values. This is the assertion that makes the fix real: the
        //    outbound payload is built from these fields.
        plan.pendingUpsert = true
        XCTAssertEqual(plan.goalWeightKg ?? 0, Autym.goalKg, accuracy: 0.01,
            "a later push must carry 110, not the 124 the device used to hold")
        XCTAssertEqual(plan.totalDays, Autym.repairedTotalDays)

        // 3. The counterfactual, so the test cannot silently stop
        //    testing anything: the SAME row, left un-merged, is the
        //    resurrection vector.
        let unmerged = ProgramPlanRecord(
            id: "CCCC0000-1111-2222-3333-0000000000P2",
            userId: userId, startDate: startDate, goalDate: startDate,
            totalDays: Autym.corruptTotalDays,
            currentWeightKg: Autym.currentKg,
            goalWeightKg: Autym.corruptGoalKg, intensityTier: "medium"
        )
        unmerged.pendingUpsert = true
        XCTAssertEqual(unmerged.goalWeightKg ?? 0, Autym.corruptGoalKg, accuracy: 0.01)
        ProgramPlanMerge.apply(repairedServerRow(), to: unmerged)
        XCTAssertEqual(unmerged.goalWeightKg ?? 0, Autym.corruptGoalKg, accuracy: 0.01,
            "a DIRTY row keeps its local value — her unsent edit is the newest fact, and this is the guard that stops the merge being 'server always wins'")
    }

    /// The offline-edit case the absent-only rule was written for, and
    /// which the merge must not break: she changed her goal on a plane.
    func testAnUnsentLocalEditIsNeverOverwrittenByTheServer() throws {
        let plan = seedDevice(localGoalKg: Autym.goalKg, dirty: true)
        // Her device says 105; the server has never heard it.
        let herNewGoal = 105 / 2.20462
        plan.goalWeightKg = herNewGoal
        plan.pendingUpsert = true
        let uid = userId
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid })).first)
        record.onboardingGoalWeightKg = herNewGoal
        record.pendingUpsert = true
        d.set(herNewGoal, forKey: "onboardingGoalWeightKg")
        try context.save()

        // The server still holds the older 110.
        hydrate([repairedServerRow(goalKg: Autym.goalKg)])

        XCTAssertEqual(plan.goalWeightKg ?? 0, herNewGoal, accuracy: 0.01,
            "the plan row she edited offline must survive a hydrate")
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), herNewGoal, accuracy: 0.01,
            "and so must the stored answer — a pending record is not server truth")
    }

    /// **THE SYMMETRY TEST.** The Autym case proves a CLEAN local row
    /// adopts server truth. This proves the inverse in the same shape,
    /// end to end, including the push — because a merge rule that only
    /// works in one direction is not a merge rule, it is
    /// "server always wins" with extra steps.
    ///
    ///     SERVER   goal 110  (older, already synced)
    ///     DEVICE   goal 115  (her edit, pendingUpsert = true)
    ///     LAUNCH → the repair machinery must not touch 115
    ///     PUSH   → the eventual truth on both sides is 115
    func testALegitimateOfflineEditWinsAndThenReachesTheServer() throws {
        let herGoal = 115 / 2.20462
        let plan = seedDevice(localGoalKg: herGoal, planGoalKg: herGoal, dirty: true)
        plan.totalDays = 84
        let uid = userId
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid })).first)
        record.onboardingGoalWeightKg = herGoal
        record.pendingUpsert = true
        d.set(herGoal, forKey: "onboardingGoalWeightKg")
        try context.save()

        // LAUNCH: pull, merge, mirror. The server still says 110.
        hydrate([repairedServerRow(goalKg: Autym.goalKg)])

        XCTAssertEqual(plan.goalWeightKg ?? 0, herGoal, accuracy: 0.01,
            "the pull may not casually replace an edit the server has never seen")
        XCTAssertEqual(plan.totalDays, 84, "nor the horizon that came with it")
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), herGoal, accuracy: 0.01)
        XCTAssertEqual(summary(plan).goalKg ?? 0, herGoal, accuracy: 0.01,
            "and the screen shows HER number, not the stale one")
        XCTAssertTrue(plan.pendingUpsert, "still queued")
        XCTAssertTrue(record.pendingUpsert)

        // PUSH: `upsertProgramPlan` sends the whole row and clears the flag
        // on success. Modelled here — the network is the untested seam,
        // the payload is not: it is built from these fields.
        let uploaded = (goal: plan.goalWeightKg, days: plan.totalDays)
        plan.pendingUpsert = false
        record.pendingUpsert = false

        XCTAssertEqual(uploaded.goal ?? 0, herGoal, accuracy: 0.01,
            "the eventual truth on BOTH sides is 115")
        XCTAssertEqual(uploaded.days, 84)

        // And the server, now agreeing, must be a no-op on the next pull.
        let dateOnly: (Date) -> String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            return { f.string(from: $0) }
        }()
        let echo = ProgramPlanHydrateRow(
            id: planId.lowercased(), user_id: userId.lowercased(),
            start_date: dateOnly(plan.startDate),
            goal_date: dateOnly(plan.goalDate),
            total_days: 84, current_weight_kg: Autym.currentKg,
            goal_weight_kg: herGoal, intensity_tier: "medium", phase: "active",
            parent_plan_id: nil, archived_at: nil, completed_at: nil
        )
        // The FIRST merge may still normalise `goalDate`: the column is a
        // Postgres `date`, so a locally-computed goal date carrying a time
        // component snaps to UTC midnight. That is a one-time
        // normalisation, and the property that matters is that it settles.
        ProgramPlanMerge.apply(echo, to: plan)
        XCTAssertFalse(ProgramPlanMerge.apply(echo, to: plan),
            "the merge must reach a fixed point — a second identical pull changes nothing, so it can never churn or re-push")
        XCTAssertEqual(plan.goalWeightKg ?? 0, herGoal, accuracy: 0.01)
        XCTAssertEqual(plan.totalDays, 84)
    }

    /// The same symmetry on a second mutable plan fact, so the rule is
    /// shown to be about the RECORD's dirty state and not about one field.
    func testTheSameSymmetryHoldsForThePaceTier() throws {
        let plan = seedDevice(localGoalKg: Autym.goalKg, planGoalKg: Autym.goalKg)
        plan.intensityTier = "soft"
        plan.pendingUpsert = true          // she changed her pace offline
        try context.save()

        hydrate([repairedServerRow()])     // the server still says medium

        XCTAssertEqual(plan.intensityTier, "soft",
            "the guard is per-record: every field of a dirty row is hers")

        plan.pendingUpsert = false         // her push lands
        hydrate([repairedServerRow()])     // and now a stale server row arrives
        XCTAssertEqual(plan.intensityTier, "medium",
            "once clean, the row adopts — which is the other half of the same rule")
    }

    /// A legacy row whose column is NULL must not delete a fact the
    /// device holds. The same "lose the goal" defect, arriving from the
    /// other direction.
    func testAnAbsentServerValueNeverDeletesALocalFact() throws {
        let plan = seedDevice(localGoalKg: Autym.goalKg, planGoalKg: Autym.goalKg)
        d.set(Autym.goalKg, forKey: "onboardingGoalWeightKg")

        let uid = userId
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid })).first)
        record.onboardingGoalWeightKg = nil
        record.onboardingHeightCm = nil
        record.pendingUpsert = false
        try context.save()

        var row = repairedServerRow()
        row = ProgramPlanHydrateRow(
            id: row.id, user_id: row.user_id, start_date: row.start_date,
            goal_date: row.goal_date, total_days: row.total_days,
            current_weight_kg: nil, goal_weight_kg: nil,
            intensity_tier: row.intensity_tier, phase: row.phase,
            parent_plan_id: nil, archived_at: nil, completed_at: nil
        )
        hydrate([row])

        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), Autym.goalKg, accuracy: 0.01)
        XCTAssertEqual(d.double(forKey: "onboardingHeightCm"), Autym.heightCm, accuracy: 0.01)
        XCTAssertEqual(plan.goalWeightKg ?? 0, Autym.goalKg, accuracy: 0.01,
            "an empty column is 'the server never learned it', never 'she gave it up'")
        XCTAssertEqual(plan.currentWeightKg ?? 0, Autym.currentKg, accuracy: 0.01)
    }

    /// A support-side archive (de-duplicating a second live plan) must
    /// reach the device, or every launch re-imports the corruption.
    func testASupportSideArchiveReachesTheDevice() throws {
        let plan = seedDevice()
        hydrate([repairedServerRow(phase: "abandoned")])
        XCTAssertEqual(plan.phase, "abandoned",
            "lifecycle is server-repairable: otherwise a duplicate plan cannot be retired from the desk")
        XCTAssertNil(ProgramService.shared.activePlan(userId: userId, in: context),
            "and the retirement has to be visible to the reader that picks her live plan")
    }
}
