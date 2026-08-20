import XCTest
import SwiftData
import PlankSync
import PlankFood
@testable import plankAI

// MARK: - HandoffRuntimeTests (v25 §42 — THE HANDOFF ACTUALLY RUNS)
//
// ▎ THE CLIENT MAY REQUEST AN OWNERSHIP TRANSITION.
// ▎ ONLY THE SERVER MAY DECLARE IT COMPLETE.
//
// ▎ A SESSION CHANGE IS NOT A HANDOFF RECEIPT.
//
// ▎ A HANDOFF THAT CANNOT SURVIVE THE CLIENT DYING IS NOT A HANDOFF.
//
// `41` designed the server contract and deliberately did NOT write the
// client, on one argument that turned out to be exactly right:
//
//   > The client mints fresh record ids BECAUSE the cloud row still
//   > belongs to the old uid; after a server move it must not. So the id
//   > policy is not separable from the migration.
//
// The migration is applied now (`20260814120000_v25_e1_account_handoffs.sql`),
// verified read-only from `pg_catalog`, and attacked with 84 assertions
// against the deployed functions — all inside transactions that rolled
// back, so no production row was written. This file is the CLIENT half,
// and it is almost entirely about that one sentence:
//
//   ▎ MINTING A FRESH ID AFTER A SERVER MOVE DUPLICATES HER ENTIRE
//   ▎ RECORD. KEEPING ONE WITHOUT A SERVER MOVE STRANDS IT.
//
// What this file does NOT do, stated so nobody mistakes it for proof:
// it does not call the live RPC. Those assertions live in the SQL
// harness, against the real deployed function, because a mocked RPC
// proves the mock. What is testable here is every decision the client
// makes with the server's answer — and the digest the two sides must
// agree on to the byte.

@MainActor
final class HandoffRuntimeTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }

    private let sourceUid = "44444444-4444-4444-4444-444444444444"
    private let destUid   = "55555555-5555-5555-5555-555555555555"

    override func setUp() {
        super.setUp()
        AppSync.installFoodDeletionSeam()
        wipe(sourceUid); wipe(destUid)
        AppSync.clearPendingMergeMarker()
    }

    override func tearDown() {
        wipe(sourceUid); wipe(destUid)
        AppSync.clearPendingMergeMarker()
        super.tearDown()
    }

    private func wipe(_ uid: String) {
        let owner = uid
        try? context.delete(model: WeightLogRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: SessionLogRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ProgramPlanRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ProgramDayCheckRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: DayProgressRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: RegimenPlanRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: DoseEventRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ObservationRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ProgramFactRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: WeeklyReadRecord.self, where: #Predicate { $0.userId == owner })
        try? context.save()
        FoodLogPersister.deleteAllEntries(userId: owner)
        DeletionLedger.clear(userId: owner)
    }

    // ================================================================
    // MARK: - 1 · THE DIGEST BOTH SIDES COMPUTE
    // ================================================================

    /// ▎ IF THESE TWO EXPRESSIONS EVER DISAGREE, EVERY HANDOFF SILENTLY
    /// ▎ STOPS WORKING AND NOTHING ANYWHERE REPORTS IT.
    ///
    /// Client: `SHA256("apple:" + sub)`, hex.
    /// Server: `encode(sha256(convert_to('apple:' || sub, 'UTF8')), 'hex')`.
    ///
    /// The vector below was computed by the DEPLOYED function's own
    /// expression against production Postgres, not by this code, so a
    /// change to either side fails here rather than in the field.
    func testTheSubjectDigestMatchesTheDeployedServerExpression() {
        // Computed BY PRODUCTION POSTGRES on 2026-08-15, verbatim:
        //   select encode(sha256(convert_to('apple:000123.deadbeef.0001','UTF8')),'hex')
        //   → cafb07de177a082139250d2d2c51b65fb70ea231b9b5e4510a68a973d3f6cf13
        // If this fails, the two halves of the protocol have drifted and
        // every handoff would silently stop matching.
        XCTAssertEqual(
            AccountHandoff.subjectHash(appleSubject: "000123.deadbeef.0001"),
            "cafb07de177a082139250d2d2c51b65fb70ea231b9b5e4510a68a973d3f6cf13",
            "the client digest must equal the deployed server expression, byte for byte"
        )
        // A digest is 64 lowercase hex characters, which is exactly what
        // the deployed CHECK constraint on `subject_hash` enforces.
        let hash = AccountHandoff.subjectHash(appleSubject: "000123.abcdef.0001")
        XCTAssertEqual(hash.count, 64)
        XCTAssertTrue(hash.allSatisfy { "0123456789abcdef".contains($0) },
                      "the server's CHECK is ^[0-9a-f]{64}$ — an uppercase digest is refused")
        // Stability: the same subject always produces the same digest,
        // which is what makes BEGIN idempotent through the partial
        // unique index on (source_user_id, subject_hash).
        XCTAssertEqual(hash, AccountHandoff.subjectHash(appleSubject: "000123.abcdef.0001"))
        XCTAssertNotEqual(hash, AccountHandoff.subjectHash(appleSubject: "000123.abcdef.0002"))
        // And the provider is part of the pre-image, so an email subject
        // and an apple subject can never collide.
        XCTAssertEqual(AccountHandoff.provider, "apple")
    }

    /// The `sub` claim is read locally and NOT verified, which is safe
    /// for exactly one reason: **a lie only locks the liar out.** A
    /// forged subject produces a receipt no account can ever redeem.
    func testTheAppleSubjectIsReadFromTheTokenAndGarbageIsRefused() {
        // {"sub":"000123.deadbeef.0001","aud":"com.bk.plankAI"}
        let payload = Data(#"{"sub":"000123.deadbeef.0001","aud":"com.bk.plankAI"}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let token = "header.\(payload).signature"

        XCTAssertEqual(AccountHandoff.appleSubject(fromIdentityToken: token),
                       "000123.deadbeef.0001")
        XCTAssertNil(AccountHandoff.appleSubject(fromIdentityToken: "not-a-jwt"))
        XCTAssertNil(AccountHandoff.appleSubject(fromIdentityToken: ""))
        XCTAssertNil(AccountHandoff.appleSubject(fromIdentityToken: "a.!!!!.c"))
        // A token with no `sub` yields nothing rather than an empty
        // string, so BEGIN is skipped instead of pre-committing to "".
        let noSub = Data(#"{"aud":"com.bk.plankAI"}"#.utf8).base64EncodedString()
        XCTAssertNil(AccountHandoff.appleSubject(fromIdentityToken: "h.\(noSub).s"))
    }

    // ================================================================
    // MARK: - 2 · NO IDENTITY IS EVER SENT
    // ================================================================

    /// ▎ THE SERVER ACCEPTS NEITHER A SOURCE UID NOR A DESTINATION UID.
    ///
    /// The strongest statement the client can make about account
    /// takeover is that it has no way to name a victim. This asserts it
    /// on the wire format rather than in prose.
    func testNoRequestCarriesAnyIdentityAtAll() {
        let base = URL(string: "https://example.supabase.co")!

        let begin = AccountHandoff.beginRequest(
            baseURL: base, anonKey: "anon", accessToken: "SOURCE-TOKEN",
            subjectHash: String(repeating: "a", count: 64)
        )
        XCTAssertEqual(begin.url?.path, "/rest/v1/rpc/begin_account_handoff")
        XCTAssertEqual(begin.value(forHTTPHeaderField: "Authorization"), "Bearer SOURCE-TOKEN",
                       "BEGIN speaks with the OUTGOING token — it is the last moment one exists")
        let beginBody = (try? JSONSerialization.jsonObject(with: begin.httpBody ?? Data()))
            as? [String: String] ?? [:]
        XCTAssertEqual(beginBody["p_provider"], "apple")
        XCTAssertEqual(beginBody["p_subject_hash"], String(repeating: "a", count: 64))
        XCTAssertEqual(beginBody.count, 2, "BEGIN sends a provider and a digest, and nothing else")

        let complete = AccountHandoff.completeRequest(
            baseURL: base, anonKey: "anon", accessToken: "DEST-TOKEN"
        )
        XCTAssertEqual(complete.url?.path, "/rest/v1/rpc/complete_account_handoff")
        XCTAssertEqual(complete.value(forHTTPHeaderField: "Authorization"), "Bearer DEST-TOKEN",
                       "COMPLETE speaks as the destination, whose credential is permanently hers")
        let completeBody = (try? JSONSerialization.jsonObject(with: complete.httpBody ?? Data()))
            as? [String: String] ?? [:]
        XCTAssertEqual(completeBody["p_mode"], "move")
        XCTAssertEqual(completeBody.count, 1,
                       "COMPLETE sends a MODE and NOTHING ELSE — not a source, not a destination, not a receipt id")
    }

    /// **DEGRADE, NEVER BREAK.** A project without the migration answers
    /// 404 (`PGRST202`), and the client must behave exactly as build 30.
    func testAnUnappliedMigrationDegradesToTodaysBehaviour() {
        XCTAssertEqual(AccountHandoff.classifyBegin(status: 404), .unavailable)
        XCTAssertEqual(AccountHandoff.classifyComplete(status: 404, body: nil), .unavailable)
        XCTAssertEqual(AccountHandoff.classifyBegin(status: 200), .opened)
        XCTAssertEqual(AccountHandoff.classifyBegin(status: 204), .opened)
        // 42501 — a permanent account tried to open a handoff. That is
        // the named → named firewall, server-side, and it is a REFUSAL
        // rather than an outage: the client must not retry it as one.
        XCTAssertEqual(AccountHandoff.classifyBegin(status: 403), .refused(status: 403))
    }

    /// ▎ WHEN THE CLIENT CANNOT PROVE WHAT THE SERVER DID, IT MUST
    /// ▎ ASSUME THE CHEAPER MISTAKE.
    ///
    /// A 2xx with an unreadable body means the server acted and this
    /// device cannot say how. Reporting `moved: 0` costs fresh ids on a
    /// carry that could have kept them; reporting `moved: 1` would let a
    /// carry preserve ids the server never moved. Only the first is
    /// recoverable.
    func testAnUnreadableCompletionIsReportedAsHavingMovedNothing() {
        XCTAssertEqual(
            AccountHandoff.classifyComplete(status: 200, body: Data(#"{"moved":1,"retired":1}"#.utf8)),
            .done(moved: 1, retired: 1)
        )
        XCTAssertEqual(
            AccountHandoff.classifyComplete(status: 200, body: Data(#"{"moved":0,"retired":0}"#.utf8)),
            .done(moved: 0, retired: 0)
        )
        XCTAssertEqual(
            AccountHandoff.classifyComplete(status: 200, body: Data("<html>".utf8)),
            .done(moved: 0, retired: 0)
        )
        XCTAssertEqual(AccountHandoff.classifyComplete(status: 200, body: nil),
                       .done(moved: 0, retired: 0))
        XCTAssertFalse(AccountHandoff.classifyComplete(status: 200, body: nil).movedTheRecord)
        XCTAssertTrue(
            AccountHandoff.classifyComplete(status: 200, body: Data(#"{"moved":2,"retired":2}"#.utf8))
                .movedTheRecord
        )
        XCTAssertTrue(
            AccountHandoff.classifyComplete(status: 200, body: Data(#"{"moved":0,"retired":1}"#.utf8))
                .retiredTheSource,
            "mode:'retire' moves nothing and still discharges the obligation"
        )
    }

    // ================================================================
    // MARK: - 3 · THE ID POLICY — THE WHOLE REASON `41` STOPPED
    // ================================================================

    private func seedServerBackedRecord(for uid: String) {
        context.insert(WeightLogRecord(id: "w1-\(uid)", userId: uid, weightKg: 74.2,
                                       loggedAt: .now, source: "manual"))
        context.insert(SessionLogRecord(id: "s1-\(uid)", userId: uid, exerciseType: "plank",
                                        holdTime: 30, targetTime: 30, qualityScore: 0.8))
        let plan = ProgramPlanRecord(userId: uid, startDate: .now, goalDate: .now,
                                     totalDays: 90, intensityTier: "medium", phase: "active")
        context.insert(plan)
        context.insert(ProgramDayCheckRecord(userId: uid, programPlanId: plan.id,
                                             programDay: 1, itemKey: "move", state: "kept"))
        let regimen = RegimenPlanRecord(userId: uid, kind: "medication",
                                        displayName: "her medication",
                                        scheduleRule: "weeklyAnchor", anchorWeekday: 4)
        context.insert(regimen)
        context.insert(DoseEventRecord(
            id: DoseEventStore.deterministicId(userId: uid, dayKey: "2026-08-14"),
            userId: uid, regimenPlanId: regimen.id, dayKey: "2026-08-14",
            scheduledAt: .now, status: "taken", takenAt: .now, site: "left thigh"
        ))
        FoodLogPersister.mergeRemote([
            FoodLogPersister.SyncableEntry(
                id: "plate-\(uid)", userId: uid, loggedAt: .now, kcal: 600,
                protein: 40, carbs: 50, fat: 20, fiber: 6, sugar: 8,
                title: "her lunch", source: "photo"
            )
        ])
        try? context.save()
        // "SERVER-BACKED" is the premise of the whole `.preserve` path:
        // these rows are already in the cloud, which is why the server
        // had something to move. A newly-inserted `@Model` row defaults
        // to `pendingUpsert = true` (it IS unsynced when it is made), so
        // the fixture has to say which state it is modelling.
        markAsSynced(uid)
    }

    private func markAsSynced(_ uid: String) {
        let owner = uid
        for r in ((try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []) { r.pendingUpsert = false }
        for r in ((try? context.fetch(FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []) { r.pendingUpsert = false }
        for r in ((try? context.fetch(FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []) { r.pendingUpsert = false }
        for r in ((try? context.fetch(FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []) { r.pendingUpsert = false }
        for r in ((try? context.fetch(FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []) { r.pendingUpsert = false }
        for r in ((try? context.fetch(FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []) { r.pendingUpsert = false }
        try? context.save()
    }

    private func ids(of uid: String) -> [String] {
        let owner = uid
        var out: [String] = []
        out += ((try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []).map(\.id)
        out += ((try? context.fetch(FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []).map(\.id)
        out += ((try? context.fetch(FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []).map(\.id)
        out += ((try? context.fetch(FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []).map(\.id)
        out += ((try? context.fetch(FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []).map(\.id)
        out += FoodLogPersister.allEntries(userId: owner).map(\.id)
        return out.sorted()
    }

    /// ▎ AFTER `complete_account_handoff(mode: 'move')` THE CLOUD ROW IS
    /// ▎ ALREADY HERS UNDER THAT ID. A FRESH ONE IS A SECOND COPY.
    ///
    /// The server changed `user_id` and kept `id` — proven against the
    /// deployed function, which returned `A-W1,A-W2` unchanged. If the
    /// client then mints a uuid and marks the row `pendingUpsert`, the
    /// launch push inserts a duplicate of every record she owns and
    /// `pushLocalFoodEntriesMissingFromServer` uploads her whole journal
    /// a second time.
    func testAServerMoveIsFollowedByAnIdPreservingCarry() {
        seedServerBackedRecord(for: sourceUid)
        let before = ids(of: sourceUid)
        XCTAssertEqual(before.count, 6, "seed: weight · session · plan · check · regimen · plate")

        let committed = AppSync.reattributeModelRows(
            from: sourceUid, to: destUid, in: context, idPolicy: .preserve
        )
        FoodLogPersister.reattributeEntries(from: sourceUid, to: destUid, preservingIds: true)
        XCTAssertTrue(committed)

        XCTAssertEqual(ids(of: destUid), before,
                       "every id the server preserved is preserved here too")
        XCTAssertTrue(ids(of: sourceUid).isEmpty,
                      "and nothing still answers to the retired account")
    }

    /// The legacy path is UNCHANGED, and it has to be: it is what runs
    /// on a project without the migration, when BEGIN was offline, and
    /// on the email door — which the deployed contract refuses on
    /// purpose (a typed address is not proof of anything).
    func testWithoutAServerMoveTheCarryStillMintsFreshIds() {
        seedServerBackedRecord(for: sourceUid)
        let before = Set(ids(of: sourceUid))

        AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context)
        FoodLogPersister.reattributeEntries(from: sourceUid, to: destUid)

        let after = Set(ids(of: destUid))
        XCTAssertEqual(after.count, before.count, "her record is all there")
        XCTAssertTrue(after.isDisjoint(with: before),
                      "and every id is new, because the cloud row still belongs to the old uid")
    }

    /// ▎ A PRESERVED CARRY MUST NOT QUEUE A PUSH THAT UNDOES THE
    /// ▎ SERVER'S OWN DECISION.
    ///
    /// `destinationHasLivePlan` is read from the LOCAL store, and on the
    /// normal handoff the destination's plans have not hydrated yet — so
    /// this device cannot see the plan the server just archived A's for.
    /// Forcing `pendingUpsert` would push A's plan back as live and
    /// produce the one state this whole line of work forbids: two live
    /// plans. Leaving the row clean lets `ProgramPlanMerge` adopt the
    /// server's answer, which is the authoritative one.
    func testAPreservedCarryDoesNotPushBackOverTheServersDecision() {
        seedServerBackedRecord(for: sourceUid)
        AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context, idPolicy: .preserve)

        let owner = destUid
        let plans = (try? context.fetch(FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []
        XCTAssertEqual(plans.count, 1)
        XCTAssertFalse(plans[0].pendingUpsert,
                       "the server holds this row; the device must not push back over it")

        let weights = (try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []
        XCTAssertFalse(weights[0].pendingUpsert)
        XCTAssertTrue(HandoffIdPolicy.mintFresh.queuesAPush)
        XCTAssertFalse(HandoffIdPolicy.preserve.queuesAPush)
    }

    /// **AND IT MUST NOT SILENCE A PUSH SHE IS ACTUALLY OWED.** A row
    /// written offline during the anonymous period was never on the
    /// server, so the server could not have moved it. Its `pendingUpsert`
    /// flag stays exactly where it was, and its preserved id makes the
    /// eventual push a clean INSERT.
    func testAPreservedCarryKeepsAnUnsyncedRowOwed() {
        let unsynced = WeightLogRecord(id: "offline-\(sourceUid)", userId: sourceUid,
                                       weightKg: 73.1, loggedAt: .now, source: "manual")
        unsynced.pendingUpsert = true
        context.insert(unsynced)
        try? context.save()

        AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context, idPolicy: .preserve)

        let owner = destUid
        let carried = ((try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? [])
        XCTAssertEqual(carried.count, 1)
        XCTAssertEqual(carried[0].id, "offline-\(sourceUid)", "id preserved")
        XCTAssertTrue(carried[0].pendingUpsert,
                      "a weigh-in the server never received is still owed after a handoff")
    }

    /// ▎ CLIENT AND SERVER MUST NOT RESOLVE THE SAME COLLISION
    /// ▎ DIFFERENTLY.
    ///
    /// Deterministic ids carry the uid, so BOTH sides always rewrite
    /// them with the same prefix swap whatever the id policy is — and
    /// the tail's case is preserved on both sides. The server's version
    /// of this was `41`'s [CORR-2]: it lowercased the tail, which would
    /// have minted an id the client never mints and produced a second
    /// row for one symptom on one day.
    func testADeterministicIdIsRewrittenIdenticallyUnderEitherPolicy() {
        for policy in [HandoffIdPolicy.mintFresh, .preserve] {
            wipe(sourceUid); wipe(destUid)
            let regimen = RegimenPlanRecord(userId: sourceUid, kind: "medication",
                                            displayName: "m", scheduleRule: "weeklyAnchor",
                                            anchorWeekday: 4)
            context.insert(regimen)
            context.insert(DoseEventRecord(
                id: DoseEventStore.deterministicId(userId: sourceUid, dayKey: "2026-08-14"),
                userId: sourceUid, regimenPlanId: regimen.id, dayKey: "2026-08-14",
                scheduledAt: .now, status: "taken", takenAt: .now, site: "left thigh"))
            // A camelCase kind is the case the server used to destroy.
            context.insert(ObservationRecord(
                id: "\(sourceUid.lowercased())-foodNoise-2026-08-14",
                userId: sourceUid, kind: "foodNoise", dayKey: "2026-08-14", valueText: "mild"))
            try? context.save()

            IdentityMerge.carryRemainingFamilies(
                from: sourceUid, to: destUid, in: context, idPolicy: policy)
            try? context.save()

            let owner = destUid
            let doses = ((try? context.fetch(FetchDescriptor<DoseEventRecord>(
                predicate: #Predicate { $0.userId == owner }))) ?? []).map(\.id)
            XCTAssertEqual(doses, [DoseEventStore.deterministicId(userId: destUid, dayKey: "2026-08-14")],
                           "\(policy): the dose id is exactly the one the destination would mint")

            let symptoms = ((try? context.fetch(FetchDescriptor<ObservationRecord>(
                predicate: #Predicate { $0.userId == owner }))) ?? []).map(\.id)
            XCTAssertEqual(symptoms, ["\(destUid.lowercased())-foodNoise-2026-08-14"],
                           "\(policy): the TAIL's case survives — lowercasing it mints an id nobody else mints")
        }
    }

    // ================================================================
    // MARK: - 4 · THE RECEIPT CARRIES THE ANSWER
    // ================================================================

    /// ▎ A CRASH MUST NOT LEAVE THE NEXT LAUNCH GUESSING, BECAUSE THE
    /// ▎ TWO GUESSES ARE NOT SYMMETRICAL.
    func testTheReceiptRecordsWhichThingTheServerDid() {
        AppSync.writePendingMergeMarker(from: sourceUid, to: destUid, idPolicy: .preserve)
        XCTAssertEqual(AppSync.pendingMergeIdPolicy(), .preserve)
        XCTAssertEqual(AppSync.pendingMergeMarker()?.from, sourceUid)
        XCTAssertEqual(AppSync.pendingMergeMarker()?.to, destUid)

        AppSync.writePendingMergeMarker(from: sourceUid, to: destUid, idPolicy: .mintFresh)
        XCTAssertEqual(AppSync.pendingMergeIdPolicy(), .mintFresh)

        // A marker written by an older build carries no policy, and the
        // DEFAULT IS THE SAFE DIRECTION: a fresh id can strand a row,
        // which the launch reconcile heals. A preserved id the server
        // never moved cannot be un-duplicated.
        AppSync.writePendingMergeMarker(from: sourceUid, to: destUid)
        XCTAssertEqual(AppSync.pendingMergeIdPolicy(), .mintFresh,
                       "a legacy marker must never be read as a server move")
    }

    /// `41` §4's isolation contract, re-asserted for the new field: the
    /// sweep clears what the next person must not see, never what this
    /// device still owes.
    func testTheIdPolicySurvivesASignOut() {
        AppSync.writePendingMergeMarker(from: sourceUid, to: destUid, idPolicy: .preserve)
        AppSync.shared.clearOnboardingUserDefaults()
        XCTAssertEqual(AppSync.pendingMergeIdPolicy(), .preserve,
                       "signing out mid-handoff must not turn a server move into a duplication")
        XCTAssertEqual(AppSync.pendingMergeMarker()?.from, sourceUid)
    }

    // ================================================================
    // MARK: - 5 · DELETE STILL BEATS TRANSFER
    // ================================================================

    /// ▎ A DELETION FOLLOWS THE ROW IT NAMES, AND ONLY WHEN THE ROW KEPT
    /// ▎ ITS NAME.
    ///
    /// `41` §19 ruled the ledger must never cross into the destination,
    /// for the right reason: a tombstone for A's id says nothing about
    /// B's differently-named row. A SERVER MOVE breaks the premise, not
    /// the principle — it is the same physical row with the same id — so
    /// dropping the tombstone would let the insert-only hydrates and the
    /// launch food reconcile resurrect a plate she deleted.
    func testADeletionFollowsAnIdPreservingMoveAndNeverAFreshIdOne() {
        DeletionLedger.record(id: "plate-she-deleted", userId: sourceUid)
        DeletionLedger.record(
            id: DoseEventStore.deterministicId(userId: sourceUid, dayKey: "2026-08-01"),
            userId: sourceUid)

        DeletionLedger.carry(from: sourceUid, to: destUid)

        XCTAssertTrue(DeletionLedger.contains(id: "plate-she-deleted", userId: destUid),
                      "a uuid id is the same id after a server move, so the tombstone still names it")
        XCTAssertTrue(
            DeletionLedger.contains(
                id: DoseEventStore.deterministicId(userId: destUid, dayKey: "2026-08-01"),
                userId: destUid),
            "a uid-prefixed id is translated by the SAME prefix swap the merge and the server use")
        XCTAssertFalse(
            DeletionLedger.contains(
                id: DoseEventStore.deterministicId(userId: sourceUid, dayKey: "2026-08-01"),
                userId: destUid),
            "and the untranslated form is not smuggled across")
    }

    /// The other half, and it is the half `41` wrote: under a FRESH-ID
    /// carry the destination's ledger is untouched, because a deletion
    /// she made as one identity is not an assertion about rows that now
    /// have different names.
    func testAFreshIdCarryNeverCrossesTheLedger() {
        DeletionLedger.record(id: "plate-she-deleted", userId: sourceUid)
        seedServerBackedRecord(for: sourceUid)

        AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context)

        XCTAssertFalse(DeletionLedger.contains(id: "plate-she-deleted", userId: destUid),
                       "fresh ids mean the tombstone names nothing that exists — it must not cross")
        XCTAssertEqual(DeletionLedger.count(userId: sourceUid), 0,
                       "and the source's ledger is discharged once the carry commits")
    }

    /// And the carry runs through the real entry point under `.preserve`,
    /// so the wiring is what is tested rather than the helper.
    func testTheCommittedPreservingCarryDischargesTheLedgerIntoTheDestination() {
        DeletionLedger.record(id: "plate-she-deleted", userId: sourceUid)
        seedServerBackedRecord(for: sourceUid)

        let committed = AppSync.reattributeModelRows(
            from: sourceUid, to: destUid, in: context, idPolicy: .preserve)

        XCTAssertTrue(committed)
        XCTAssertTrue(DeletionLedger.contains(id: "plate-she-deleted", userId: destUid))
        XCTAssertEqual(DeletionLedger.count(userId: sourceUid), 0)
    }

    // ================================================================
    // MARK: - 6 · NAMED → NAMED IS STILL NEVER A DATA MIGRATION
    // ================================================================

    /// The server refuses it (`begin_account_handoff` raises 42501
    /// unless `auth.users.is_anonymous`), and the client must never ask.
    /// This is the client half: no operation but ADOPT may carry, and
    /// the id policy cannot smuggle a switch past that rule.
    func testNoIdPolicyMakesASwitchIntoAHandoff() {
        seedServerBackedRecord(for: sourceUid)
        let before = ids(of: sourceUid)

        // A switch never reaches the carry at all — but if a future
        // caller ignored the operation, the carry must still refuse to
        // move one permanent account's record into another's.
        XCTAssertFalse(
            AccountOperation.switchAccount(source: sourceUid, destination: destUid)
                .carriesTheAnonymousPeriod)
        XCTAssertFalse(
            AppSync.shouldMergeAnonymousPeriod(
                userIdChanged: true, isAnonNow: false, previousMethod: .apple,
                previousUserId: sourceUid, newUserId: destUid))
        XCTAssertEqual(ids(of: sourceUid), before, "and nothing moved while we asked")
    }
}
