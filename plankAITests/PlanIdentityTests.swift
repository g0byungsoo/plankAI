import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - PlanIdentityTests
//
// **WHICH PLAN IS SHE LIVING IN?**
//
// The production repair that started this work assumed exactly one live
// plan. Support will not always be that lucky, and the app cannot let a
// fetch order decide a paying customer's calorie target.
//
// Until 2026-08-14 two readers answered the question differently:
//
//   `ProgramService.activePlan`      sorted `createdAt` DESC, take one
//   `AppSync.reconcileLivePlans`     keeps the EARLIEST `startDate`
//
// So between the moment an account acquired a second live plan and the
// next hydrate, the app rendered the plan the heal was about to archive —
// the interim one minted at a forced re-enroll with `startDate = today`,
// which is what resets a user to day 1.
//
// And `createdAt` was not even the enrollment moment on a hydrated row:
// the initialiser stamps `.now` and the hydrate never read `started_at`
// back, so after a reinstall the sort was ordering plans by the order of
// a `for` loop.

@MainActor
final class PlanIdentityTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let userId = "plan-identity-tests"

    override func setUpWithError() throws { wipe() }
    override func tearDownWithError() throws { wipe() }

    private func wipe() {
        let uid = userId
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.save()
    }

    @discardableResult
    private func plan(
        _ id: String, startedDaysAgo: Int, phase: String = "active",
        createdDaysAgo: Int? = nil, archived: Bool = false
    ) -> ProgramPlanRecord {
        let start = Calendar.current.date(
            byAdding: .day, value: -startedDaysAgo, to: .now) ?? .now
        let p = ProgramPlanRecord(
            id: id, userId: userId, startDate: start,
            goalDate: start.addingTimeInterval(119 * 86_400), totalDays: 119,
            currentWeightKg: 75, goalWeightKg: 65, intensityTier: "medium",
            phase: phase
        )
        if let createdDaysAgo {
            p.createdAt = Calendar.current.date(
                byAdding: .day, value: -createdDaysAgo, to: .now) ?? .now
        }
        if archived { p.archivedAt = .now }
        p.pendingUpsert = false
        context.insert(p)
        try? context.save()
        return p
    }

    func testNoLivePlanReturnsNil() throws {
        XCTAssertNil(ProgramService.shared.activePlan(userId: userId, in: context))
        plan("PI-COMPLETED", startedDaysAgo: 200, phase: "completed")
        XCTAssertNil(ProgramService.shared.activePlan(userId: userId, in: context),
            "a finished program is history, not the plan she is living in")
    }

    func testOneLivePlanIsTheAnswer() throws {
        let only = plan("PI-ONE", startedDaysAgo: 30)
        XCTAssertEqual(ProgramService.shared.activePlan(userId: userId, in: context)?.id, only.id)
    }

    func testTwoLivePlansResolveToTheGenuineJourneyNotTheInterimOne() throws {
        // The exact corruption shape: the real enrollment, plus an
        // interim plan minted today while she was auto-logged-out. The
        // interim one is NEWER by createdAt, which is what used to win.
        let real = plan("PI-REAL", startedDaysAgo: 40, createdDaysAgo: 40)
        plan("PI-INTERIM", startedDaysAgo: 0, createdDaysAgo: 0)

        XCTAssertEqual(
            ProgramService.shared.activePlan(userId: userId, in: context)?.id, real.id,
            "the earliest start date is the journey she has been living in; picking the interim one resets her to day 1")
    }

    func testTheReaderAndTheHealAgreeOnWhichPlanSurvives() throws {
        let real = plan("PI-AGREE-REAL", startedDaysAgo: 40, createdDaysAgo: 40)
        let interim = plan("PI-AGREE-INTERIM", startedDaysAgo: 0, createdDaysAgo: 0)

        let picked = ProgramService.shared.activePlan(userId: userId, in: context)
        let archived = AppSync.reconcileLivePlans([real, interim])

        XCTAssertEqual(picked?.id, real.id)
        XCTAssertEqual(archived.map(\.id), [interim.id],
            "the reader must never render a plan the heal is about to retire — one rule, two call sites")
        XCTAssertEqual(
            ProgramService.shared.activePlan(userId: userId, in: context)?.id, real.id,
            "and the answer must not change when the heal runs")
    }

    func testTheHealNeverMintsAThirdPlanAndNeverDropsHistory() throws {
        let real = plan("PI-KEEP", startedDaysAgo: 40, createdDaysAgo: 40)
        let interim = plan("PI-DROP", startedDaysAgo: 0, createdDaysAgo: 0)
        AppSync.reconcileLivePlans([real, interim])

        let uid = userId
        let all = try context.fetch(FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.userId == uid }))
        XCTAssertEqual(all.count, 2, "corruption is archived, never deleted, and never replaced")
        XCTAssertEqual(interim.phase, "abandoned")
        XCTAssertNotNil(interim.archivedAt)
        XCTAssertTrue(interim.pendingUpsert,
            "the heal has to reach the cloud too, or every reinstall re-imports the corruption")
        XCTAssertEqual(real.phase, "active")
        XCTAssertFalse(real.pendingUpsert, "the keeper is untouched; nothing about it is re-pushed")
    }

    func testAnArchivedRowIsNotLiveEvenWhenItsPhaseStillSaysActive() throws {
        // The shape a support-side archive leaves: `archived_at` set,
        // `phase` untouched. `AppSync.hasActivePlan` and
        // `reconcileLivePlans` have always read it that way; `activePlan`
        // did not, so the three disagreed.
        plan("PI-ARCHIVED", startedDaysAgo: 60, archived: true)
        XCTAssertNil(ProgramService.shared.activePlan(userId: userId, in: context))
    }

    func testAMaintenancePhasePlanIsStillThePlanSheIsLivingIn() throws {
        let held = plan("PI-MAINT", startedDaysAgo: 10, phase: "maintenance")
        XCTAssertEqual(ProgramService.shared.activePlan(userId: userId, in: context)?.id, held.id)
    }

    func testAChildPlanDoesNotOutrankItsArchivedParent() throws {
        let parent = plan("PI-PARENT", startedDaysAgo: 200, phase: "completed")
        let child = plan("PI-CHILD", startedDaysAgo: 10)
        child.parentPlanId = parent.id
        try context.save()
        XCTAssertEqual(ProgramService.shared.activePlan(userId: userId, in: context)?.id, child.id,
            "the parent is completed, so the child is the only live plan — earliest-start applies only among LIVE rows")
    }

    func testHydratedPlansCarryTheirEnrollmentMomentNotTheHydrationMoment() throws {
        let older = "PI-HYD-OLD".uppercased()
        let newer = "PI-HYD-NEW".uppercased()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        func row(_ id: String, daysAgo: Int) -> ProgramPlanHydrateRow {
            let start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            return ProgramPlanHydrateRow(
                id: id.lowercased(), user_id: userId.lowercased(),
                start_date: f.string(from: start),
                goal_date: f.string(from: start.addingTimeInterval(119 * 86_400)),
                total_days: 119, current_weight_kg: 75, goal_weight_kg: 65,
                intensity_tier: "medium", phase: "completed",
                parent_plan_id: nil, archived_at: nil, completed_at: nil,
                started_at: ISO8601DateFormatter().string(from: start)
            )
        }
        // The query returns started_at DESC, so the NEWER row is first.
        SyncService.applyHydratedProgramPlans(
            [row(newer, daysAgo: 10), row(older, daysAgo: 200)],
            userId: userId, context: context)

        let uid = userId
        let plans = try context.fetch(FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.userId == uid }))
        let byId = Dictionary(uniqueKeysWithValues: plans.map { ($0.id, $0) })
        let oldPlan = try XCTUnwrap(byId[older])
        let newPlan = try XCTUnwrap(byId[newer])
        XCTAssertLessThan(oldPlan.createdAt, newPlan.createdAt,
            "createdAt used to be the hydration instant, so a reinstall ordered plans by the order of this loop")
    }
}
