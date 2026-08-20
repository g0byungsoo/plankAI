import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - UpgradeBoundaryTests
//
// **THE MOST IMPORTANT PATH IS NOT A FRESH INSTALL.**
//
// It is: production build → App Store update → this build, over an
// existing sandbox. Existing UserDefaults. Existing SwiftData rows.
// Existing auth session, subscription, program, food, weight and
// medication history.
//
// The question these tests answer is NOT "can the next build construct
// this state" — every other suite in this repo does that. It is:
//
//              **CAN THE NEXT BUILD INHERIT THIS STATE?**
//
// So every fixture here is seeded in the shape the PRODUCTION build left
// it, and then the next build's launch reconciliation is run over it:
//
//     PULL   SyncService.applyHydratedProgramPlans   (ProgramPlanMerge)
//     MERGE  AppSync.restoreBodyDefaults / mirrorActivityAlias
//     HEAL   AppSync.reconcileLivePlans
//     READ   ProgramService.activePlan · TargetsService · PlanSummary
//
// in the order `AppSync.onLaunch` runs them.
//
// ## What is proven elsewhere, and why
//
// **SwiftData schema:** no `@Model` definition has changed since the
// reviewed release `1710180` (`Models.swift` has a zero diff, and no
// file declaring a `@Model` moved). There is no store migration on
// upgrade, so no fixture here can test one — the risk is absent by
// construction, not by assertion.
//
// **Food history:** `Packages/PlankFood` has a zero diff this session
// and nothing in the changed launch path calls `FoodLogPersister`. It is
// covered by the diff, not by a fixture that would pollute the shared
// JSONL store.
//
// **Payment / auth / paywall:** zero diff on all six protected paths.

@MainActor
final class UpgradeBoundaryTests: XCTestCase {

    private let d = UserDefaults.standard
    private var context: ModelContext { TestModelContainer.shared.mainContext }

    /// Every fixture owns its own userId so the shared container can hold
    /// them all at once without cross-talk.
    private enum Fixture: String, CaseIterable {
        case coherentLegacy      = "UPG-A-COHERENT"
        case autym               = "UPG-B-AUTYM"
        case fabricatedGoal      = "UPG-C-FABRICATED"
        case correctedServer     = "UPG-D-CORRECTED"
        case richPayingUser      = "UPG-E-RICH"
        case maintenance         = "UPG-F-MAINTAIN"
        case kilograms           = "UPG-G-KG"
        case alreadyAtGoal       = "UPG-H-ATGOAL"
        case pendingLocalEdit    = "UPG-I-PENDING"
        case noValidPlan         = "UPG-J-NOPLAN"
    }

    private static let ownedKeys = [
        "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
        "onboardingHeightCm", "onboardingGender", "onb_v5_gender",
        "onboardingPickedTier", "onboarding_goal_direction", "program_mode",
        "safety_pace_cap", "safety_numeric_suppression",
        "onboarding_glp1_status", "onboardingHormonalStage",
        "onboardingSleepHours", "onboarding_weight_trend",
        "onboarding_glp1_phase", "onb_v4_movement_baseline", "activityLevel",
        "onboardingActivityLevel", "onb_v5_age_years", "ageRange",
        "onboardingAgeRange", "weightUnit", "heightUnit",
        "hasCompletedOnboarding", "hasEnrolledInProgram", "programEraEnabled",
        "sync.truthRefreshStamp",
    ]

    override func setUpWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        Fixture.allCases.forEach { wipe($0.rawValue) }
    }

    override func tearDownWithError() throws {
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        Fixture.allCases.forEach { wipe($0.rawValue) }
    }

    private func wipe(_ uid: String) {
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.delete(model: UserRecord.self,
                            where: #Predicate { $0.id == uid })
        try? context.delete(model: WeightLogRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.delete(model: ObservationRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.delete(model: RegimenPlanRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.delete(model: DoseEventRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.delete(model: ProgramDayCheckRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.save()
    }

    // MARK: - What the production build left behind

    private struct OldState {
        var currentKg: Double? = 124 / 2.20462
        var goalKg: Double? = 110 / 2.20462
        var heightCm: Double? = 160.02
        var sex: String = "female"
        /// The lossy alias is what a signed-out/in production user holds.
        var activityAlias: String? = "moderate"
        var rawActivity: String? = "walks"
        var exactAge: Int? = 34
        var band: String? = "25to34"
        var unit: String = "lb"
        var maintenance: Bool = false
        /// (startKg, goalKg, totalDays) on the plan record.
        var plan: (Double, Double, Int)? = (124 / 2.20462, 110 / 2.20462, 119)
        var planIsDirty: Bool = false
        /// The `users` row as the SERVER holds it.
        var serverGoalKg: Double? = 110 / 2.20462
        var latestWeighInKg: Double? = nil
    }

    private let startDate = Calendar.current.date(
        byAdding: .day, value: -26, to: Calendar.current.startOfDay(for: .now)
    ) ?? Date()

    /// Seeds the sandbox exactly as the shipping build would have left it.
    @discardableResult
    private func seedOldSandbox(_ f: Fixture, _ s: OldState) -> ProgramPlanRecord? {
        let uid = f.rawValue
        Self.ownedKeys.forEach { d.removeObject(forKey: $0) }
        d.set(true, forKey: "hasCompletedOnboarding")
        d.set(true, forKey: "hasEnrolledInProgram")
        d.set(true, forKey: "programEraEnabled")
        if let v = s.currentKg { d.set(v, forKey: "onboardingCurrentWeightKg") }
        if let v = s.goalKg { d.set(v, forKey: "onboardingGoalWeightKg") }
        if let v = s.heightCm { d.set(v, forKey: "onboardingHeightCm") }
        d.set(s.sex, forKey: "onboardingGender")
        if let v = s.rawActivity { d.set(v, forKey: "onb_v4_movement_baseline") }
        if let v = s.activityAlias { d.set(v, forKey: "activityLevel") }
        if let v = s.exactAge { d.set(v, forKey: "onb_v5_age_years") }
        if let v = s.band { d.set(v, forKey: "ageRange") }
        d.set(s.unit, forKey: "weightUnit")
        d.set("medium", forKey: "onboardingPickedTier")
        if s.maintenance {
            d.set("maintain", forKey: "onboarding_goal_direction")
            d.set("maintenance", forKey: "program_mode")
        } else {
            d.set("lose", forKey: "onboarding_goal_direction")
            d.set("loss", forKey: "program_mode")
        }

        let record = UserRecord(id: uid, name: "upgrade")
        record.onboardingCurrentWeightKg = s.currentKg
        record.onboardingGoalWeightKg = s.serverGoalKg
        record.onboardingHeightCm = s.heightCm
        record.onboardingGender = s.sex
        record.onboardingActivityLevel = s.activityAlias
        record.onboardingAgeRange = s.band
        record.pendingUpsert = false
        context.insert(record)

        if let kg = s.latestWeighInKg {
            context.insert(WeightLogRecord(userId: uid, weightKg: kg))
        }

        var plan: ProgramPlanRecord? = nil
        if let (start, goal, days) = s.plan {
            let p = ProgramPlanRecord(
                id: "\(uid)-PLAN", userId: uid, startDate: startDate,
                goalDate: startDate.addingTimeInterval(Double(days) * 86_400),
                totalDays: days, currentWeightKg: start, goalWeightKg: goal,
                intensityTier: "medium"
            )
            p.pendingUpsert = s.planIsDirty
            context.insert(p)
            plan = p
        }
        try? context.save()
        return plan
    }

    /// Her history: weigh-ins, medication, doses, observations, day checks.
    private func seedHistory(_ f: Fixture) -> (weights: Int, regimens: Int, doses: Int, observations: Int, checks: Int) {
        let uid = f.rawValue
        for i in 1...4 {
            let log = WeightLogRecord(userId: uid, weightKg: 57.0 - Double(i) * 0.2)
            log.pendingUpsert = false
            context.insert(log)
        }
        let regimen = RegimenPlanRecord(
            userId: uid, kind: "medication", displayName: "weekly",
            scheduleRule: "weekly", anchorWeekday: 1
        )
        regimen.pendingUpsert = false
        context.insert(regimen)
        let dayKey: (Date) -> String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return { f.string(from: $0) }
        }()
        for i in 1...3 {
            let day = Calendar.current.date(byAdding: .day, value: -7 * i, to: .now) ?? .now
            let ev = DoseEventRecord(
                id: "\(uid)-dose-\(i)", userId: uid, regimenPlanId: regimen.id,
                dayKey: dayKey(day), scheduledAt: day, status: "taken"
            )
            ev.pendingUpsert = false
            context.insert(ev)
        }
        for i in 1...2 {
            let day = Calendar.current.date(byAdding: .day, value: -i, to: .now) ?? .now
            let obs = ObservationRecord(
                userId: uid, kind: "reflection", dayKey: dayKey(day),
                effectiveAt: day, valueText: "steady"
            )
            obs.pendingUpsert = false
            context.insert(obs)
        }
        let check = ProgramDayCheckRecord(
            userId: uid, programPlanId: "\(uid)-PLAN", programDay: 12,
            itemKey: "weigh_in", state: "complete"
        )
        check.pendingUpsert = false
        context.insert(check)
        try? context.save()
        return counts(uid)
    }

    private func counts(_ uid: String) -> (weights: Int, regimens: Int, doses: Int, observations: Int, checks: Int) {
        func n<T: PersistentModel>(_ d: FetchDescriptor<T>) -> Int {
            (try? context.fetchCount(d)) ?? 0
        }
        return (
            n(FetchDescriptor<WeightLogRecord>(predicate: #Predicate { $0.userId == uid })),
            n(FetchDescriptor<RegimenPlanRecord>(predicate: #Predicate { $0.userId == uid })),
            n(FetchDescriptor<DoseEventRecord>(predicate: #Predicate { $0.userId == uid })),
            n(FetchDescriptor<ObservationRecord>(predicate: #Predicate { $0.userId == uid })),
            n(FetchDescriptor<ProgramDayCheckRecord>(predicate: #Predicate { $0.userId == uid }))
        )
    }

    // MARK: - The first launch of the next build

    private let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func serverRow(
        _ f: Fixture, goalKg: Double?, startKg: Double?, totalDays: Int,
        phase: String = "active"
    ) -> ProgramPlanHydrateRow {
        ProgramPlanHydrateRow(
            id: "\(f.rawValue)-PLAN".lowercased(),
            user_id: f.rawValue.lowercased(),
            start_date: iso.string(from: startDate),
            goal_date: iso.string(from: startDate.addingTimeInterval(Double(totalDays) * 86_400)),
            total_days: totalDays, current_weight_kg: startKg,
            goal_weight_kg: goalKg, intensity_tier: "medium", phase: phase,
            parent_plan_id: nil, archived_at: nil, completed_at: nil,
            started_at: ISO8601DateFormatter().string(from: startDate)
        )
    }

    /// The launch path, in `AppSync.onLaunch`'s order: PULL → MERGE → HEAL.
    /// The push comes after, which is the whole point of the reordering.
    private func firstLaunchOfNextBuild(_ f: Fixture, serverRows: [ProgramPlanHydrateRow]) {
        let uid = f.rawValue
        SyncService.applyHydratedProgramPlans(serverRows, userId: uid, context: context)
        if let record = try? context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid })).first {
            AppSync.restoreBodyDefaults(from: record, into: d)
            AppSync.mirrorActivityAlias(from: record, into: d)
        }
        let mine = ((try? context.fetch(FetchDescriptor<ProgramPlanRecord>())) ?? [])
            .filter { $0.userId.caseInsensitiveCompare(uid) == .orderedSame }
        AppSync.reconcileLivePlans(mine)
        try? context.save()
    }

    private func read(_ f: Fixture) -> (kcal: Int?, plan: ProgramPlanRecord?, summary: PlanSummary) {
        let uid = f.rawValue
        let plan = ProgramService.shared.activePlan(userId: uid, in: context)
        let targets = TargetsService.current(userId: uid, in: context)
        let summary = PlanSummary.build(
            plan: plan,
            latestWeightKg: TargetsService.resolvedWeightKg(userId: uid, plan: plan, in: context),
            proteinG: targets.proteinG, stepsGoal: targets.steps,
            numericsSuppressed: targets.numericsSuppressed, defaults: d
        )
        return (targets.kcal, plan, summary)
    }

    // MARK: - A · the coherent legacy customer

    func testA_coherentCustomerInheritsEverythingUnchanged() throws {
        let f = Fixture.coherentLegacy
        let plan = try XCTUnwrap(seedOldSandbox(f, OldState()))
        let before = seedHistory(f)
        let beforeKcal = read(f).kcal
        let beforeStart = plan.startDate
        let beforeId = plan.id

        firstLaunchOfNextBuild(f, serverRows: [serverRow(
            f, goalKg: 110 / 2.20462, startKg: 124 / 2.20462, totalDays: 119)])

        let after = read(f)
        XCTAssertEqual(after.kcal, beforeKcal,
            "a customer whose facts are coherent must see the SAME integer after the update")
        XCTAssertEqual(after.plan?.id, beforeId, "same plan, not a new one")
        XCTAssertEqual(after.plan?.startDate, beforeStart, "same day anchor")
        XCTAssertEqual(counts(f.rawValue).weights, before.weights, "history intact")
        XCTAssertEqual(counts(f.rawValue).doses, before.doses)
        XCTAssertEqual(counts(f.rawValue).regimens, before.regimens)
        XCTAssertEqual(counts(f.rawValue).observations, before.observations)
        XCTAssertEqual(counts(f.rawValue).checks, before.checks)
        XCTAssertTrue(d.bool(forKey: "hasCompletedOnboarding"),
            "onboarding must not restart")
        XCTAssertTrue(d.bool(forKey: "hasEnrolledInProgram"))
        XCTAssertEqual(d.string(forKey: "weightUnit"), "lb", "units survive")
        XCTAssertFalse(after.plan?.pendingUpsert ?? true,
            "an unchanged row must not be queued for upload by the mere act of updating")
    }

    // MARK: - B · Autym, at the upgrade boundary

    func testB_autymInheritsTheRepairOnHerFirstLaunch() throws {
        let f = Fixture.autym
        // Her phone: the fabricated goal AND the corrupt plan.
        let plan = try XCTUnwrap(seedOldSandbox(f, OldState(
            goalKg: 124 / 2.20462,
            plan: (124 / 2.20462, 124 / 2.20462, 210),
            serverGoalKg: 110 / 2.20462
        )))
        let before = seedHistory(f)

        firstLaunchOfNextBuild(f, serverRows: [serverRow(
            f, goalKg: 110 / 2.20462, startKg: 124 / 2.20462, totalDays: 119)])

        let after = read(f)
        XCTAssertEqual(after.summary.goalKg ?? 0, 110 / 2.20462, accuracy: 0.01)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), 110 / 2.20462, accuracy: 0.01)
        XCTAssertEqual(plan.totalDays, 119)
        XCTAssertEqual(plan.startDate, startDate, "her day count does not move")
        XCTAssertNotNil(after.kcal)
        XCTAssertEqual(after.summary.energyKind, .deficit)
        XCTAssertEqual(counts(f.rawValue).weights, before.weights)
        XCTAssertEqual(counts(f.rawValue).doses, before.doses)
        XCTAssertFalse(plan.pendingUpsert, "the adopted row is not queued back")
    }

    // MARK: - C · fabricated goal, and the server cannot help

    func testC_fabricatedGoalWithNoServerTruthAsksInsteadOfInventing() throws {
        let f = Fixture.fabricatedGoal
        let plan = try XCTUnwrap(seedOldSandbox(f, OldState(
            goalKg: 124 / 2.20462,
            plan: (124 / 2.20462, 124 / 2.20462, 210),
            serverGoalKg: nil                      // profile goal is NULL
        )))

        firstLaunchOfNextBuild(f, serverRows: [serverRow(
            f, goalKg: nil, startKg: 124 / 2.20462, totalDays: 210)])

        let after = read(f)
        XCTAssertNil(after.kcal,
            "no goal anywhere: silence, never the maintenance number that started all of this")
        XCTAssertEqual(after.summary.intent, .goalMissing)
        XCTAssertEqual(
            TargetsService.missingEnergyInput(
                plan: after.plan,
                latestWeightKg: TargetsService.resolvedWeightKg(
                    userId: f.rawValue, plan: after.plan, in: context),
                defaults: d),
            .goal,
            "and the missing fact is NAMED, so Home's denominator is a door")
        XCTAssertEqual(plan.currentWeightKg ?? 0, 124 / 2.20462, accuracy: 0.01,
            "her start weight is not collapsed into the missing goal")
        XCTAssertEqual(plan.goalWeightKg ?? 0, 124 / 2.20462, accuracy: 0.01,
            "a NULL server goal deletes nothing: the local row keeps what it had, and the READERS refuse it — repair is her tap, not a silent overwrite")
    }

    // MARK: - D · corrected server facts over old local mirrors

    func testD_correctedServerBodyFactsReachOldLocalMirrors() throws {
        let f = Fixture.correctedServer
        seedOldSandbox(f, OldState(heightCm: 150.0, sex: "female"))
        // Support corrected height and sex in `users`.
        let uid = f.rawValue
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid })).first)
        record.onboardingHeightCm = 160.02
        record.onboardingGender = "male"
        record.pendingUpsert = false
        try context.save()

        firstLaunchOfNextBuild(f, serverRows: [serverRow(
            f, goalKg: 110 / 2.20462, startKg: 124 / 2.20462, totalDays: 119)])

        XCTAssertEqual(d.double(forKey: "onboardingHeightCm"), 160.02, accuracy: 0.01)
        XCTAssertEqual(TargetsService.profileInputs(d).sex, .male)
    }

    // MARK: - E · the rich paying user

    func testE_richAccountLosesNothing() throws {
        let f = Fixture.richPayingUser
        let plan = try XCTUnwrap(seedOldSandbox(f, OldState(latestWeighInKg: 55.0)))
        let before = seedHistory(f)
        let beforeWeight = TargetsService.resolvedWeightKg(
            userId: f.rawValue, plan: plan, in: context)

        firstLaunchOfNextBuild(f, serverRows: [serverRow(
            f, goalKg: 110 / 2.20462, startKg: 124 / 2.20462, totalDays: 119)])

        let after = counts(f.rawValue)
        XCTAssertEqual(after.weights, before.weights, "every weigh-in survives")
        XCTAssertEqual(after.regimens, before.regimens, "her regimen survives")
        XCTAssertEqual(after.doses, before.doses, "every dose survives")
        XCTAssertEqual(after.observations, before.observations)
        XCTAssertEqual(after.checks, before.checks, "her day checks survive")
        XCTAssertEqual(
            TargetsService.resolvedWeightKg(userId: f.rawValue, plan: plan, in: context),
            beforeWeight, "the freshest weigh-in still outranks every stored weight")
        XCTAssertEqual(plan.currentWeightKg ?? 0, 124 / 2.20462, accuracy: 0.01,
            "and her START weight is still the start weight")
    }

    // MARK: - F · maintenance

    func testF_maintenanceCustomerStillHolds() throws {
        let f = Fixture.maintenance
        seedOldSandbox(f, OldState(goalKg: nil, maintenance: true, plan: nil,
                                   serverGoalKg: nil))
        firstLaunchOfNextBuild(f, serverRows: [])
        let after = read(f)
        XCTAssertNotNil(after.kcal, "holding is an instruction with a real number")
        XCTAssertEqual(after.summary.intent, .holding)
        XCTAssertEqual(after.summary.energyKind, .maintenance)
        XCTAssertNil(TargetsService.missingEnergyInput(
            plan: nil, latestWeightKg: 124 / 2.20462, defaults: d),
            "maintenance is never reported as a missing input")
    }

    // MARK: - G · kilograms

    func testG_kilogramCustomerKeepsHerUnit() throws {
        let f = Fixture.kilograms
        seedOldSandbox(f, OldState(unit: "kg"))
        firstLaunchOfNextBuild(f, serverRows: [serverRow(
            f, goalKg: 110 / 2.20462, startKg: 124 / 2.20462, totalDays: 119)])
        XCTAssertEqual(d.string(forKey: "weightUnit"), "kg",
            "the unit is device-level and nothing in the merge may touch it")
        // 124 lb − 110 lb = 14 lb = 6.35 kg.
        let after = read(f)
        XCTAssertEqual(after.summary.distanceLine(unit: .kg), "6.4 kg to go")
    }

    // MARK: - H · already at goal

    func testH_customerAtHerGoalGetsMaintenanceNotSilence() throws {
        let f = Fixture.alreadyAtGoal
        seedOldSandbox(f, OldState(plan: nil, latestWeighInKg: 49.0))
        firstLaunchOfNextBuild(f, serverRows: [])
        let after = read(f)
        XCTAssertNotNil(after.kcal,
            "she got there; losing her number and being asked for a goal she already gave is the state nobody can repair")
        XCTAssertEqual(after.summary.energyKind, .maintenance)
    }

    // MARK: - I · a pending local edit at the moment of update

    func testI_anUnsentLocalEditSurvivesTheUpdate() throws {
        let f = Fixture.pendingLocalEdit
        // She changed her goal to 115 lb offline on the OLD build, and the
        // push never landed before the App Store update.
        let herGoal = 115 / 2.20462
        let plan = try XCTUnwrap(seedOldSandbox(f, OldState(
            goalKg: herGoal, plan: (124 / 2.20462, herGoal, 84), planIsDirty: true
        )))
        let uid = f.rawValue
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid })).first)
        record.onboardingGoalWeightKg = herGoal
        record.pendingUpsert = true
        try context.save()

        // The server still holds the older 110.
        firstLaunchOfNextBuild(f, serverRows: [serverRow(
            f, goalKg: 110 / 2.20462, startKg: 124 / 2.20462, totalDays: 119)])

        XCTAssertEqual(plan.goalWeightKg ?? 0, herGoal, accuracy: 0.01,
            "the update must not eat an edit that had not synced yet")
        XCTAssertEqual(plan.totalDays, 84)
        XCTAssertEqual(d.double(forKey: "onboardingGoalWeightKg"), herGoal, accuracy: 0.01)
        XCTAssertTrue(plan.pendingUpsert, "and it is still queued to reach the server")
    }

    // MARK: - J · no valid active plan

    func testJ_customerWithNoLivePlanIsNotGivenOneSilently() throws {
        let f = Fixture.noValidPlan
        seedOldSandbox(f, OldState(plan: nil))
        let before = seedHistory(f)

        firstLaunchOfNextBuild(f, serverRows: [])

        let uid = f.rawValue
        XCTAssertNil(ProgramService.shared.activePlan(userId: uid, in: context),
            "no plan is minted by the act of launching; enrollment is a decision she makes")
        XCTAssertEqual(
            try context.fetchCount(FetchDescriptor<ProgramPlanRecord>(
                predicate: #Predicate { $0.userId == uid })), 0)
        XCTAssertEqual(counts(uid).weights, before.weights, "and her history is still hers")
        // Her own onboarding numbers still produce a target — the onramp is
        // two taps she may never have taken.
        XCTAssertNotNil(read(f).kcal)
    }

    // MARK: - Offline: the launch that cannot reach the server

    /// A cold launch with no network reaches `applyHydratedProgramPlans`
    /// with nothing, because the fetch threw and was caught. Nothing may
    /// change, and anything queued must stay queued.
    func testOfflineLaunchChangesNothingAndKeepsThePushQueued() throws {
        let f = Fixture.pendingLocalEdit
        let herGoal = 115 / 2.20462
        let plan = try XCTUnwrap(seedOldSandbox(f, OldState(
            goalKg: herGoal, plan: (124 / 2.20462, herGoal, 84), planIsDirty: true,
            serverGoalKg: 110 / 2.20462
        )))
        // `GoalWeightStore` dirties the PLAN and the RECORD together, so a
        // fixture that dirties only the plan is not a state the app can
        // produce. (My first version did exactly that, and the clean
        // record correctly pulled her goal back to the server's 110 —
        // which is the merge rule working, on an impossible input.)
        let uid = f.rawValue
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == uid })).first)
        record.onboardingGoalWeightKg = herGoal
        record.pendingUpsert = true
        try context.save()

        let before = seedHistory(f)
        let beforeKcal = read(f).kcal

        firstLaunchOfNextBuild(f, serverRows: [])   // the offline shape

        XCTAssertEqual(read(f).kcal, beforeKcal, "the app stays usable and says the same thing")
        XCTAssertEqual(plan.goalWeightKg ?? 0, herGoal, accuracy: 0.01)
        XCTAssertTrue(plan.pendingUpsert, "her edit is still on its way")
        XCTAssertEqual(counts(f.rawValue).weights, before.weights)
        XCTAssertEqual(counts(f.rawValue).doses, before.doses)
        XCTAssertEqual(
            try context.fetchCount(FetchDescriptor<ProgramPlanRecord>(
                predicate: #Predicate { $0.userId == "UPG-I-PENDING" })), 1,
            "an offline launch mints nothing")
    }

    // MARK: - The upgrade invariants that hold across ALL fixtures

    func testNoFixtureLosesHistoryOrDuplicatesAPlan() throws {
        for f in Fixture.allCases {
            let hasPlan = ![Fixture.maintenance, .alreadyAtGoal, .noValidPlan].contains(f)
            seedOldSandbox(f, OldState(plan: hasPlan ? (124 / 2.20462, 110 / 2.20462, 119) : nil))
            let before = seedHistory(f)
            let rows = hasPlan
                ? [serverRow(f, goalKg: 110 / 2.20462, startKg: 124 / 2.20462, totalDays: 119)]
                : []

            // Launching twice must be identical to launching once.
            firstLaunchOfNextBuild(f, serverRows: rows)
            firstLaunchOfNextBuild(f, serverRows: rows)

            let uid = f.rawValue
            let after = counts(uid)
            XCTAssertEqual(after.weights, before.weights, "[\(f.rawValue)] weights")
            XCTAssertEqual(after.doses, before.doses, "[\(f.rawValue)] doses")
            XCTAssertEqual(after.regimens, before.regimens, "[\(f.rawValue)] regimens")
            XCTAssertEqual(after.observations, before.observations, "[\(f.rawValue)] observations")
            XCTAssertEqual(after.checks, before.checks, "[\(f.rawValue)] day checks")
            XCTAssertEqual(
                try context.fetchCount(FetchDescriptor<ProgramPlanRecord>(
                    predicate: #Predicate { $0.userId == uid })),
                hasPlan ? 1 : 0,
                "[\(f.rawValue)] the merge is idempotent — a second launch may not duplicate a plan")
            XCTAssertTrue(d.bool(forKey: "hasCompletedOnboarding"),
                "[\(f.rawValue)] onboarding must never restart on an update")
            wipe(uid)
        }
    }
}
