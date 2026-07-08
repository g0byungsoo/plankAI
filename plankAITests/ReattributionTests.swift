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
        let container = try ModelContainer(
            for: UserRecord.self, SessionLogRecord.self, DayProgressRecord.self,
                ExerciseRecord.self, ExerciseCalibrationRecord.self,
                SessionRatingRecord.self, WeightLogRecord.self,
                ProgramPlanRecord.self, ProgramDayCheckRecord.self, ChatMessageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
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
}
