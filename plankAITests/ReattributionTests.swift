import XCTest
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
//
// Tests exercise the pure `applyReattribution` on standalone model
// instances — no ModelContainer, so no test-host SwiftData coupling.

@MainActor
final class ReattributionTests: XCTestCase {

    // MARK: - weight_logs: the confirmed symptom

    func testWeightLogGetsFreshIdSoPushIsCleanInsert() {
        let newId = "named-B"
        let w = WeightLogRecord(id: "w-original", userId: "anon-A", weightKg: 74.2)
        w.pendingUpsert = false   // already pushed to the cloud under the anon uid

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

    // MARK: - session_logs: same id-collision, plus its day_progress pointer

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
        XCTAssertEqual(p.sessionLogIds, [s.id],
            "the v2 multi-session list must follow the remap too")
    }

    // MARK: - a day_progress that references a session NOT being moved

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
