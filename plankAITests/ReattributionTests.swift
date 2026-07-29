import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - ReattributionTests
//
// The sign-in merge (anonymous experimentation folds into the account
// the user just signed into) re-keys the anon rows. THE BUG this pins:
// keeping the same primary-key `id` while only changing `user_id` makes
// the next Supabase push an upsert-on-`id` that resolves to an UPDATE of
// a row still owned by the OLD uid. RLS's `USING (auth.uid() = user_id)`
// rejects it (42501), the fire-and-forget push swallows the error, and
// the row lives only on-device — gone on the next reinstall (the new
// account's cloud never got it). That was the "my weigh-ins reset every
// reinstall" report. The fix mints a FRESH id so the push is a clean
// INSERT the new account owns; these tests hold that invariant.

@MainActor
final class ReattributionTests: XCTestCase {

    // MARK: - Integration: the real reattributeModelRows (fetch + apply + save)
    //
    // ONE container per test-class run. The project's cross-package @Model
    // registration HANGS the main thread on a second in-memory container in
    // the same process (same failure that exiled the food models from the
    // app container — see PlankAIApp.modelContainer notes), so both
    // scenarios share a single container and one save/reattribute pass.
    // A subset schema also crashes; the full app model list is required.

    func testReattributeModelRows_movesAnonRows_scopesToOldId_remapsPointers() throws {
        // v8: the one process-wide container moved to
        // TestModelContainer.shared so ObservationStoreTests can
        // share it (second-container hang law).
        let container = TestModelContainer.shared
        let ctx = container.mainContext
        let anon = "anon-A", named = "named-B", foreign = "other-C"

        let w = WeightLogRecord(id: "w-anon", userId: anon, weightKg: 74.2)
        w.pendingUpsert = false   // already pushed under the anon uid
        ctx.insert(w)
        let s = SessionLogRecord(
            id: "s-anon", userId: anon, exerciseType: "routine",
            holdTime: 0, targetTime: 0, qualityScore: 1, sessionType: "routine"
        )
        ctx.insert(s)
        let p = DayProgressRecord(
            userId: anon, programDay: 3, primarySessionId: "s-anon",
            primaryQualityScore: 1, primaryHoldTime: 0
        )
        p.sessionLogIds = ["s-anon"]
        ctx.insert(p)
        // A different account's row that must stay put — proves the fetch
        // predicate only moves the signing-in user's own anon rows.
        let foreignW = WeightLogRecord(id: "w-foreign", userId: foreign, weightKg: 60)
        ctx.insert(foreignW)
        try ctx.save()

        AppSync.reattributeModelRows(from: anon, to: named, in: ctx)

        // Re-fetch fresh so we're reading persisted state (reattributeModelRows saves).
        let weights = try ctx.fetch(FetchDescriptor<WeightLogRecord>())
        XCTAssertEqual(weights.count, 2)
        let moved = weights.first { $0.userId == named }
        let stayed = weights.first { $0.userId == foreign }
        XCTAssertNotNil(moved, "the anon weigh-in must now belong to the signed-in account")
        XCTAssertNotEqual(moved?.id, "w-anon",
            "id must be fresh — a same-id push is an RLS-rejected UPDATE of the old-owned cloud row")
        XCTAssertEqual(moved?.pendingUpsert, true, "the re-keyed row must be queued for the push")
        XCTAssertEqual(moved?.weightKg, 74.2)
        XCTAssertEqual(stayed?.id, "w-foreign", "another account's row must never be re-keyed")
        XCTAssertEqual(stayed?.userId, foreign)

        let sessions = try ctx.fetch(FetchDescriptor<SessionLogRecord>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertNotEqual(sessions[0].id, "s-anon")
        XCTAssertEqual(sessions[0].userId, named)
        let newSessionId = sessions[0].id

        let prog = try ctx.fetch(FetchDescriptor<DayProgressRecord>())
        XCTAssertEqual(prog.count, 1)
        XCTAssertEqual(prog[0].userId, named)
        XCTAssertEqual(prog[0].compositeKey, "\(named):3")
        XCTAssertEqual(prog[0].primarySessionId, newSessionId,
            "day_progress.primarySessionId must follow the re-keyed session, else the day points at a dead id")
        XCTAssertEqual(prog[0].sessionLogIds, [newSessionId],
            "the v2 multi-session list must follow the remap too")

        // Second scenario, same container: a no-match old id touches nothing.
        AppSync.reattributeModelRows(from: "never-existed", to: named, in: ctx)
        let after = try ctx.fetch(FetchDescriptor<WeightLogRecord>())
        XCTAssertEqual(after.count, 2, "a no-match reattribution must not add, drop, or duplicate rows")
        XCTAssertEqual(after.first { $0.userId == foreign }?.id, "w-foreign",
            "the foreign row stays put across a second pass too")
    }

    // MARK: - Unit: the pure applyReattribution (no container, exhaustive on the mutation)

    func testWeightLogGetsFreshIdSoPushIsCleanInsert() {
        let newId = "named-B"
        let w = WeightLogRecord(id: "w-original", userId: "anon-A", weightKg: 74.2)
        w.pendingUpsert = false

        AppSync.applyReattribution(to: newId, sessions: [], progress: [], weightLogs: [w])

        XCTAssertEqual(w.userId, newId, "the weigh-in must belong to the signed-in account")
        XCTAssertNotEqual(w.id, "w-original",
            "id must be fresh — a same-id push is an RLS-rejected UPDATE of the old-owned cloud row")
        XCTAssertTrue(w.pendingUpsert,
            "the re-keyed row must be queued so retryPendingUpserts pushes it to the new account")
        XCTAssertEqual(w.weightKg, 74.2, "the weigh-in value survives the re-key")
    }

    func testEveryWeighInGetsADistinctFreshId() {
        let logs = (0..<5).map { WeightLogRecord(id: "w-\($0)", userId: "anon-A", weightKg: 74.0 + Double($0) * 0.1) }
        AppSync.applyReattribution(to: "named-B", sessions: [], progress: [], weightLogs: logs)
        let ids = Set(logs.map(\.id))
        XCTAssertEqual(ids.count, 5, "each re-keyed weigh-in needs its own id, or the cloud collapses them")
        XCTAssertFalse(ids.contains("w-0"), "old ids must all be replaced")
        XCTAssertTrue(logs.allSatisfy { $0.userId == "named-B" && $0.pendingUpsert })
    }

    func testSessionReKeyDragsDayProgressPointerAlong() {
        let newId = "named-B"
        let s = SessionLogRecord(
            id: "s-original", userId: "anon-A", exerciseType: "routine",
            holdTime: 0, targetTime: 0, qualityScore: 1, sessionType: "routine"
        )
        let p = DayProgressRecord(
            userId: "anon-A", programDay: 3, primarySessionId: "s-original",
            primaryQualityScore: 1, primaryHoldTime: 0
        )
        p.sessionLogIds = ["s-original"]

        AppSync.applyReattribution(to: newId, sessions: [s], progress: [p], weightLogs: [])

        XCTAssertNotEqual(s.id, "s-original", "session id must be fresh for the clean INSERT")
        XCTAssertEqual(s.userId, newId)
        XCTAssertEqual(p.userId, newId)
        XCTAssertEqual(p.compositeKey, "\(newId):3", "the composite key must re-scope to the new account")
        XCTAssertEqual(p.primarySessionId, s.id,
            "day_progress.primarySessionId must follow the re-keyed session, else the day points at a dead id")
        XCTAssertEqual(p.sessionLogIds, [s.id], "the v2 multi-session list must follow the remap too")
    }

    func testRatingFollowsTheReKeyedSessionAndGetsAFreshId() {
        // session_ratings sync now, so a merge must re-key them with the
        // same fresh-id invariant and drag the sessionLogId pointer along.
        let s = SessionLogRecord(
            id: "s-rated", userId: "anon-A", exerciseType: "routine",
            holdTime: 0, targetTime: 0, qualityScore: 1, sessionType: "routine"
        )
        let r = SessionRatingRecord(
            id: "r-anon", userId: "anon-A", sessionLogId: "s-rated", rating: 5
        )
        r.pendingUpsert = false   // already pushed under the anon uid

        AppSync.applyReattribution(
            to: "named-B", sessions: [s], progress: [], weightLogs: [],
            ratings: [r]
        )

        XCTAssertNotEqual(r.id, "r-anon", "rating id must be fresh for the clean INSERT")
        XCTAssertEqual(r.userId, "named-B")
        XCTAssertEqual(r.sessionLogId, s.id,
            "the rating must follow the re-keyed session, else it orphans from the delete join and the push")
        XCTAssertTrue(r.pendingUpsert, "the re-keyed rating must be queued for the push")
    }

    func testUnrelatedSessionPointerIsLeftAlone() {
        let p = DayProgressRecord(
            userId: "anon-A", programDay: 1, primarySessionId: "some-other-session",
            primaryQualityScore: 1, primaryHoldTime: 0
        )
        AppSync.applyReattribution(to: "named-B", sessions: [], progress: [p], weightLogs: [])
        XCTAssertEqual(p.primarySessionId, "some-other-session",
            "a pointer to a session that isn't in the remap must be preserved verbatim")
        XCTAssertEqual(p.userId, "named-B")
    }

    // MARK: - v1.1.6 — the program plan (the day anchor) + its day-checks

    func testProgramPlanGetsFreshIdAndChecksFollowThePointer() {
        let newId = "named-B"
        let plan = ProgramPlanRecord(
            id: "plan-anon", userId: "anon-A",
            startDate: .now, goalDate: .now, totalDays: 140, intensityTier: "medium"
        )
        plan.pendingUpsert = false   // already pushed under the anon uid
        let check = ProgramDayCheckRecord(
            id: "check-anon", userId: "anon-A",
            programPlanId: "plan-anon", programDay: 5, itemKey: "snapMeal", state: "complete"
        )
        check.pendingUpsert = false

        AppSync.applyReattribution(
            to: newId, sessions: [], progress: [], weightLogs: [],
            plans: [plan], checks: [check]
        )

        XCTAssertEqual(plan.userId, newId, "the enrollment must belong to the signed-in account")
        XCTAssertNotEqual(plan.id, "plan-anon",
            "plan id must be fresh — a same-id push is an RLS-rejected UPDATE of the old-owned cloud row (the day would reset)")
        XCTAssertTrue(plan.pendingUpsert, "the re-keyed plan must be queued for the push")
        XCTAssertEqual(plan.totalDays, 140, "the program length survives the re-key")

        XCTAssertEqual(check.userId, newId)
        XCTAssertNotEqual(check.id, "check-anon", "the day-check needs its own fresh id")
        XCTAssertEqual(check.programPlanId, plan.id,
            "the day-check must follow the re-keyed plan, else the kept-item state points at a dead plan")
        XCTAssertTrue(check.pendingUpsert)
    }

    func testReSignedPlanParentPointerFollowsTheRemap() {
        // A re-signed plan points parentPlanId at its archived predecessor;
        // when both re-key in one merge, the pointer must follow.
        let parent = ProgramPlanRecord(
            id: "plan-parent", userId: "anon-A",
            startDate: .now, goalDate: .now, totalDays: 90, intensityTier: "soft"
        )
        let child = ProgramPlanRecord(
            id: "plan-child", userId: "anon-A",
            startDate: .now, goalDate: .now, totalDays: 140, intensityTier: "medium",
            parentPlanId: "plan-parent"
        )
        AppSync.applyReattribution(
            to: "named-B", sessions: [], progress: [], weightLogs: [],
            plans: [parent, child], checks: []
        )
        XCTAssertNotEqual(parent.id, "plan-parent")
        XCTAssertEqual(child.parentPlanId, parent.id,
            "the re-signed plan's parent pointer must follow the predecessor's fresh id")
    }

    func testCheckPointerToUnbatchedPlanIsPreserved() {
        // A check whose plan isn't in this batch keeps its pointer verbatim.
        let check = ProgramDayCheckRecord(
            userId: "anon-A", programPlanId: "some-other-plan",
            programDay: 1, itemKey: "logWeight"
        )
        AppSync.applyReattribution(
            to: "named-B", sessions: [], progress: [], weightLogs: [],
            plans: [], checks: [check]
        )
        XCTAssertEqual(check.programPlanId, "some-other-plan",
            "a pointer to a plan that isn't in the remap must be preserved verbatim")
        XCTAssertEqual(check.userId, "named-B")
    }

    // MARK: - One live plan per account (the day-1 reset)
    //
    // THE BUG these pin: a re-key sign-in carried the interim anon plan
    // (startDate = today, minted when the auto-logged-out user was forced
    // to re-enroll) into an account that already held its real journey.
    // Nothing reconciled, ProgramService.activePlan sorts createdAt DESC
    // with fetchLimit 1, so the junk plan won and the user woke up on
    // day 1. The rule: the genuine journey is the plan with the EARLIEST
    // startDate; every other live plan archives.

    func testMergeArchivesTheInterimAnonPlanWhenAccountAlreadyHasOne() {
        let real = ProgramPlanRecord(
            id: "plan-real", userId: "named-B",
            startDate: .now.addingTimeInterval(-40 * 86_400),
            goalDate: .now.addingTimeInterval(100 * 86_400),
            totalDays: 140, intensityTier: "medium"
        )
        real.pendingUpsert = false
        let interim = ProgramPlanRecord(
            id: "plan-interim", userId: "anon-A",
            startDate: .now, goalDate: .now.addingTimeInterval(140 * 86_400),
            totalDays: 140, intensityTier: "medium"
        )

        AppSync.applyReattribution(
            to: "named-B", sessions: [], progress: [], weightLogs: [],
            plans: [interim], checks: [], existingPlans: [real]
        )

        XCTAssertEqual(interim.userId, "named-B", "the interim plan still merges into the account")
        XCTAssertEqual(interim.phase, "abandoned",
            "the interim plan must arrive archived, or createdAt-DESC makes it win and resets the day to 1")
        XCTAssertNotNil(interim.archivedAt)
        XCTAssertTrue(interim.pendingUpsert, "the archived phase must reach the cloud too")
        XCTAssertEqual(real.phase, "active", "the genuine journey (earlier startDate) stays live")
        XCTAssertNil(real.archivedAt)
    }

    func testMergeIntoEmptyAccountKeepsTheAnonPlanLive() {
        let plan = ProgramPlanRecord(
            id: "plan-only", userId: "anon-A",
            startDate: .now, goalDate: .now.addingTimeInterval(90 * 86_400),
            totalDays: 90, intensityTier: "soft"
        )
        AppSync.applyReattribution(
            to: "named-B", sessions: [], progress: [], weightLogs: [],
            plans: [plan], checks: [], existingPlans: []
        )
        XCTAssertEqual(plan.phase, "active",
            "with no destination plan, the anon enrollment IS the journey and must stay live")
        XCTAssertNil(plan.archivedAt)
    }

    func testReconcileKeepsEarliestStartDateLiveAndArchivesTheRest() {
        let real = ProgramPlanRecord(
            id: "plan-earliest", userId: "u",
            startDate: .now.addingTimeInterval(-60 * 86_400),
            goalDate: .now.addingTimeInterval(80 * 86_400),
            totalDays: 140, intensityTier: "medium"
        )
        real.pendingUpsert = false
        let junk = ProgramPlanRecord(
            id: "plan-junk", userId: "u",
            startDate: .now, goalDate: .now.addingTimeInterval(140 * 86_400),
            totalDays: 140, intensityTier: "medium"
        )
        junk.pendingUpsert = false
        let finished = ProgramPlanRecord(
            id: "plan-finished", userId: "u",
            startDate: .now.addingTimeInterval(-300 * 86_400),
            goalDate: .now.addingTimeInterval(-200 * 86_400),
            totalDays: 90, intensityTier: "soft", phase: "completed"
        )
        finished.pendingUpsert = false

        let archived = AppSync.reconcileLivePlans([junk, real, finished])

        XCTAssertEqual(archived.map(\.id), ["plan-junk"],
            "only the younger live plan archives; reconcile returns it so the caller can push")
        XCTAssertEqual(real.phase, "active", "earliest startDate keeps the day anchor")
        XCTAssertNil(real.archivedAt)
        XCTAssertEqual(junk.phase, "abandoned")
        XCTAssertNotNil(junk.archivedAt)
        XCTAssertTrue(junk.pendingUpsert, "the healed phase must be queued for the cloud so reinstalls stop re-importing the corruption")
        XCTAssertEqual(finished.phase, "completed", "non-live plans are never touched")
        XCTAssertNil(finished.archivedAt)
        XCTAssertFalse(finished.pendingUpsert)
    }

    func testReconcileWithSingleLivePlanIsANoOp() {
        let plan = ProgramPlanRecord(
            id: "plan-solo", userId: "u",
            startDate: .now.addingTimeInterval(-10 * 86_400),
            goalDate: .now.addingTimeInterval(65 * 86_400),
            totalDays: 75, intensityTier: "medium"
        )
        plan.pendingUpsert = false
        XCTAssertTrue(AppSync.reconcileLivePlans([plan]).isEmpty)
        XCTAssertEqual(plan.phase, "active")
        XCTAssertNil(plan.archivedAt)
        XCTAssertFalse(plan.pendingUpsert)
    }

    func testReconcileTreatsPausedPlanAsLive() {
        // pause is a live phase: a paused journey must still beat a
        // freshly-minted interim plan, not lose to it.
        let paused = ProgramPlanRecord(
            id: "plan-paused", userId: "u",
            startDate: .now.addingTimeInterval(-90 * 86_400),
            goalDate: .now.addingTimeInterval(50 * 86_400),
            totalDays: 140, intensityTier: "medium", phase: "pause"
        )
        paused.pendingUpsert = false
        let junk = ProgramPlanRecord(
            id: "plan-junk-2", userId: "u",
            startDate: .now, goalDate: .now.addingTimeInterval(140 * 86_400),
            totalDays: 140, intensityTier: "medium"
        )
        let archived = AppSync.reconcileLivePlans([paused, junk])
        XCTAssertEqual(archived.map(\.id), ["plan-junk-2"])
        XCTAssertEqual(paused.phase, "pause", "the paused journey survives untouched")
    }
}
