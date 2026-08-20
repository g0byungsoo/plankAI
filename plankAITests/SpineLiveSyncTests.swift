import XCTest
import SwiftData
import PlankSync
import Supabase
@testable import plankAI

// MARK: - SpineLiveSyncTests (v25 §45 — DID IT ACTUALLY LEAVE THE PHONE?)
//
// **THIS TEST TALKS TO PRODUCTION.** It is gated behind
// `JENI_LIVE_SPINE=1` and skips otherwise, so it never runs in the
// ordinary suite and cannot be dragged into CI by accident.
//
//   JENI_LIVE_SPINE=1 xcodebuild test -scheme plankAI \
//     -only-testing:plankAITests/SpineLiveSyncTests ...
//
// WHY IT EXISTS. `44` proved the spine had never synced by reading the
// catalog. `45` proved the repair over the raw PostgREST surface.
// Neither proves THE APP: the brief's §10 asks for the shipping write,
// push, hydrate and restore, and forbids inventing a debug path and
// calling that proof.
//
// Every call below is a shipping one:
//
//   ProgramFactStore.apply            the E1 write chokepoint
//   WeeklyReadStore.recordDecision    the weekly read's chokepoint
//   SyncService.retryPendingUpserts   the launch sweep (AppSync line 191)
//   SyncService.hydrateProgramFacts   the launch hydrate (AppSync line 660)
//   SyncService.hydrateWeeklyReads    the launch hydrate (AppSync line 661)
//   ProgramFactStore.headValue        the consumer read — the same call
//                                     TargetsService and
//                                     AdaptiveStepsEngine make
//   supabase.rpc("delete_user_account")  the shipping deletion
//
// WHAT "REINSTALL" MEANS HERE. `TestModelContainer` is process-wide by
// necessity (a second in-memory container hangs the main thread on this
// schema), so the reinstall is simulated by deleting every local row of
// the account — precisely the state a reinstalled device is in — and
// then running the shipping hydrate against it. It does not drive the
// UI, and that is not claimed.
//
// THE ASSERTION THAT MATTERS: `pendingUpsert` is cleared ONLY inside
// the success branch after `.execute()` returns. A row whose flag is
// false is a row the server accepted. For these two families that flag
// was `true` forever, on every device, from 2026-08-10 until the grant
// landed.

@MainActor
final class SpineLiveSyncTests: XCTestCase {

    private var service: SyncService!
    private var scratchDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["JENI_LIVE_SPINE"] == "1",
            "live production test — set JENI_LIVE_SPINE=1 to run"
        )
        AppSync.shared.configure(modelContainer: TestModelContainer.shared)
        service = SyncService(
            supabaseClient: supabase, modelContainer: TestModelContainer.shared
        )
        UserDefaults.standard.removePersistentDomain(forName: "SpineLiveSyncTests")
        scratchDefaults = UserDefaults(suiteName: "SpineLiveSyncTests")!
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: "SpineLiveSyncTests")
        try await super.tearDown()
    }

    // MARK: - Helpers

    private struct Identity {
        let uid: String
        let accessToken: String
        let refreshToken: String
    }

    private func signInFreshAnonymous() async throws -> Identity {
        let s = try await supabase.auth.signInAnonymously()
        return Identity(
            uid: s.user.id.uuidString,
            accessToken: s.accessToken,
            refreshToken: s.refreshToken
        )
    }

    /// The shipping deletion: `AuthService.deleteAccount`'s exact call.
    private func deleteCurrentAccount() async {
        _ = try? await supabase.rpc("delete_user_account").execute()
    }

    private func becomeAgain(_ identity: Identity) async throws {
        try await supabase.auth.setSession(
            accessToken: identity.accessToken,
            refreshToken: identity.refreshToken
        )
    }

    private func localFacts(_ uid: String) -> [ProgramFactRecord] {
        (try? TestModelContainer.shared.mainContext.fetch(
            FetchDescriptor<ProgramFactRecord>(predicate: #Predicate { $0.userId == uid })
        )) ?? []
    }

    private func localReads(_ uid: String) -> [WeeklyReadRecord] {
        (try? TestModelContainer.shared.mainContext.fetch(
            FetchDescriptor<WeeklyReadRecord>(predicate: #Predicate { $0.userId == uid })
        )) ?? []
    }

    /// The reinstall: the account's local rows are gone, the account is not.
    private func wipeLocalRows(_ uid: String) {
        let ctx = TestModelContainer.shared.mainContext
        localFacts(uid).forEach { ctx.delete($0) }
        localReads(uid).forEach { ctx.delete($0) }
        try? ctx.save()
    }

    // MARK: - Scenario 1 · write → push → reinstall → hydrate → consumer

    func testTheSpineLeavesThePhoneAndComesBack() async throws {
        let ctx = TestModelContainer.shared.mainContext
        let me = try await signInFreshAnonymous()

        // ── WRITE, through the one writer the product has.
        let fact = ProgramFactStore.apply(
            .stepGoal, value: .int(5150), authority: .preferred,
            basis: .stated, source: "user", userId: me.uid, in: ctx,
            legacyDefaults: scratchDefaults
        )
        let factId = try XCTUnwrap(fact?.id, "the shipping write chokepoint refused a legal fact")

        let read = WeeklyReadStore.recordDecision(
            windowStartDay: "2001-01-01",
            anchor: .enrollment,
            shown: nil,
            offer: .v4(.holdSteady(reason: "")),
            decision: "declined",
            factId: nil,
            userId: me.uid,
            in: ctx
        )
        let readId = try XCTUnwrap(read?.id)

        // ── PUSH, through the launch sweep.
        await service.retryPendingUpserts()

        let pushedFact = try XCTUnwrap(localFacts(me.uid).first { $0.id == factId })
        XCTAssertFalse(pushedFact.pendingUpsert, "the program fact never reached the server")
        let pushedRead = try XCTUnwrap(localReads(me.uid).first { $0.id == readId })
        XCTAssertFalse(pushedRead.pendingUpsert, "the weekly read never reached the server")

        // ── REINSTALL.
        wipeLocalRows(me.uid)
        XCTAssertTrue(localFacts(me.uid).isEmpty)
        XCTAssertTrue(localReads(me.uid).isEmpty)

        // ── HYDRATE, through the launch path.
        await service.hydrateProgramFacts(userId: me.uid)
        await service.hydrateWeeklyReads(userId: me.uid)

        let restoredFact = try XCTUnwrap(
            localFacts(me.uid).first { $0.id == factId },
            "program_facts did not come back from the server"
        )
        XCTAssertEqual(restoredFact.kind, "stepGoal")
        XCTAssertEqual(restoredFact.value, "i:5150")
        XCTAssertEqual(restoredFact.authority, "preferred")
        XCTAssertFalse(restoredFact.pendingUpsert, "a hydrated row must not queue a push back")

        let restoredRead = try XCTUnwrap(
            localReads(me.uid).first { $0.id == readId },
            "weekly_reads did not come back from the server"
        )
        XCTAssertEqual(restoredRead.windowStartDay, "2001-01-01")
        XCTAssertEqual(restoredRead.decision, "declined")

        // ── THE RESTORED FACT REACHES ITS CONSUMER. A 200 is not a
        // restore. This is the resolver every surface reads through.
        XCTAssertEqual(
            ProgramFactStore.headValue(.stepGoal, userId: me.uid, in: ctx),
            .int(5150),
            "the restored fact never reached the resolver every surface reads"
        )
        XCTAssertEqual(WeeklyReadStore.latest(userId: me.uid, in: ctx)?.id, readId)

        // ── CLEANUP: the shipping account deletion, then the local sweep.
        await deleteCurrentAccount()
        wipeLocalRows(me.uid)
    }

    // MARK: - Scenario 3 · account A signs out, account B signs in

    func testAccountBSeesNothingOfAccountA() async throws {
        let ctx = TestModelContainer.shared.mainContext
        let a = try await signInFreshAnonymous()

        _ = ProgramFactStore.apply(
            .weighCadence, value: .word("softened"), authority: .preferred,
            basis: .stated, source: "user", userId: a.uid, in: ctx,
            legacyDefaults: scratchDefaults
        )
        await service.retryPendingUpserts()
        XCTAssertFalse(
            try XCTUnwrap(localFacts(a.uid).first).pendingUpsert,
            "account A's fact never reached the server, so the test proves nothing"
        )

        // B is a different identity on the same device.
        let b = try await signInFreshAnonymous()
        wipeLocalRows(a.uid)

        // The server answers to the TOKEN, never to the argument.
        await service.hydrateProgramFacts(userId: a.uid)
        XCTAssertTrue(localFacts(a.uid).isEmpty, "account B pulled account A's program facts")

        await service.hydrateProgramFacts(userId: b.uid)
        XCTAssertTrue(localFacts(b.uid).isEmpty, "account B received rows it never wrote")

        // ── CLEANUP: delete B, then step back into A and delete it too.
        await deleteCurrentAccount()
        try await becomeAgain(a)
        await deleteCurrentAccount()
        wipeLocalRows(a.uid)
        wipeLocalRows(b.uid)
    }
}
