import XCTest
import SwiftData
import PlankSync
import PlankFood
@testable import plankAI

// MARK: - HandoffContractTests (v25 §41 — THE HANDOFF)
//
// ▎ AN ACCOUNT TRANSITION IS NOT COMPLETE UNTIL EVERY CUSTOMER-OWNED
// ▎ RECORD HAS ONE KNOWN OWNER AND THE SOURCE IDENTITY HAS REACHED ITS
// ▎ EXPLICIT TERMINAL STATE.
//
// ▎ NAMED → NAMED IS ACCOUNT SWITCHING. IT IS NEVER DATA MIGRATION.
//
// ▎ NO CUSTOMER RECORD MAY DISAPPEAR MERELY BECAUSE ITS USER_ID
// ▎ CHANGED.
//
// `40` proved `39`'s prospective fix was directionally right and
// incomplete. This file exists because attacking `40`'s fix found five
// more ways an account transition goes wrong, and three of them are the
// same shape: **a decision that belongs to ONE identity being carried
// into another.**
//
//   1. THE MERGE CAN FAIL SILENTLY AND PERMANENTLY.
//      `DayProgressRecord.compositeKey` is `@Attribute(.unique)` and the
//      re-key rewrites it with no destination guard — the one unguarded
//      unique key in the whole merge. The server has the same shape
//      (`day_progress`'s PRIMARY KEY is `(user_id, program_day)`, read
//      from the live catalog). One duplicate discards EVERY family,
//      because the merge is one context and one `save()`, and the
//      receipt was cleared immediately afterwards.
//   2. A PRESCRIPTION FOLLOWED THE PERSON. The deployed RLS refuses a
//      client insert of a care-team regimen or a prescribed program
//      fact; the merge re-keyed both. Nine care-team regimen rows exist
//      in production and all nine are under anonymous accounts.
//   3. NAMED → NAMED STILL CARRIED HER WORDS. The isolation sweep runs
//      on sign-out and account deletion and on nothing else.
//   4. SIGNING OUT MID-HANDOFF STRANDED THE ANONYMOUS PERIOD, because
//      the same sweep removed the receipt that owed it.
//   5. THE RETIREMENT COULD DESTROY THE ONLY COPY, because "the local
//      store is a superset" is false for a reinstall whose hydrate has
//      not landed.
//
// Every ownership test measures the FOOTPRINT — how many rows still
// answer to each name — rather than listing families, because a test
// that lists what it expects cannot notice a family nobody added to the
// list, which is exactly how ten of them survived six passes.

@MainActor
final class HandoffContractTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }

    private let sourceUid = "11111111-1111-1111-1111-111111111111"
    private let destUid   = "22222222-2222-2222-2222-222222222222"

    override func setUp() {
        super.setUp()
        AppSync.installFoodDeletionSeam()
        wipe(sourceUid); wipe(destUid)
        wipeDeviceScopedKeys()
        AppSync.clearPendingMergeMarker()
        AccountDeletionIntent.clear()
    }

    override func tearDown() {
        wipe(sourceUid); wipe(destUid)
        wipeDeviceScopedKeys()
        AppSync.clearPendingMergeMarker()
        AccountDeletionIntent.clear()
        super.tearDown()
    }

    // MARK: helpers

    private func wipe(_ uid: String) {
        let owner = uid
        try? context.delete(model: WeightLogRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: DoseEventRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ObservationRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: RegimenPlanRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ProgramFactRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: WeeklyReadRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ConsentGrantRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: JeniMemoryRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ChatMessageRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ExerciseCalibrationRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: SessionLogRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: SessionRatingRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: DayProgressRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ProgramPlanRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: ProgramDayCheckRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: BodyScanRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: UserRecord.self, where: #Predicate { $0.id == owner })
        try? context.save()
        FoodLogPersister.deleteAllEntries(userId: owner)
        DeletionLedger.clear(userId: owner)
    }

    /// The customer-authored keys that are scoped to the DEVICE rather
    /// than to an account. They are the whole of finding 3.
    private static let deviceScopedKeys = [
        "move.manual.v1",
        "day.note.2026-08-14",
        "day.reflection.2026-08-14",
        "day.sit.2026-08-14",
        "safety_pregnancy_status",
    ]

    private func wipeDeviceScopedKeys() {
        for key in Self.deviceScopedKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func seedDeviceScopedRecord() {
        let defaults = UserDefaults.standard
        defaults.set(Data("[{\"kind\":\"strength\"}]".utf8), forKey: "move.manual.v1")
        defaults.set("i felt steady tonight", forKey: "day.note.2026-08-14")
        defaults.set("proud", forKey: "day.reflection.2026-08-14")
        defaults.set("yes", forKey: "day.sit.2026-08-14")
        defaults.set("pregnant", forKey: "safety_pregnancy_status")
    }

    private func deviceScopedSurvivors() -> Int {
        Self.deviceScopedKeys.filter { UserDefaults.standard.object(forKey: $0) != nil }.count
    }

    private func footprint(of uid: String) -> Int {
        LocalHandoffInventory.footprint(of: uid, in: context)
    }

    /// One row of every carryable family, so "her record followed her"
    /// is measured against a whole account rather than a convenient one.
    @discardableResult
    private func seedAnonymousPeriod(for uid: String) -> RegimenPlanRecord {
        context.insert(WeightLogRecord(id: "w-\(uid)", userId: uid, weightKg: 74.2,
                                       loggedAt: .now, source: "manual"))
        let regimen = RegimenPlanRecord(userId: uid, kind: "medication",
                                        displayName: "her medication",
                                        scheduleRule: "weeklyAnchor", anchorWeekday: 4)
        context.insert(regimen)
        context.insert(DoseEventRecord(
            id: DoseEventStore.deterministicId(userId: uid, dayKey: "2026-08-14"),
            userId: uid, regimenPlanId: regimen.id, dayKey: "2026-08-14",
            scheduledAt: .now, status: "taken", takenAt: .now, site: "left thigh"
        ))
        context.insert(ObservationRecord(
            id: SideEffectLog.id(userId: uid, symptom: "nausea", dayKey: "2026-08-14"),
            userId: uid, kind: "symptom", dayKey: "2026-08-14", valueText: "mild"
        ))
        context.insert(JeniMemoryRecord(userId: uid, topic: "food", note: "no dairy"))
        context.insert(ChatMessageRecord(userId: uid, role: "user", body: "hello",
                                         dayKey: "2026-08-14"))
        try? context.save()
        return regimen
    }

    private func dayProgress(for uid: String, day: Int, quality: Double) -> DayProgressRecord {
        DayProgressRecord(userId: uid, programDay: day, primarySessionId: "s-\(uid)-\(day)",
                          primaryQualityScore: quality, primaryHoldTime: 30)
    }

    // ================================================================
    // MARK: - 1 · THE THREE OPERATIONS
    // ================================================================

    /// ▎ THE FORBIDDEN RULE: `oldUid != newUid ⇒ MERGE`.
    ///
    /// A uid change is the one fact all three operations share, so it is
    /// evidence of none of them.
    func testTheThreeOperationsAreNamedAndNeverInferredFromAUidChange() {
        XCTAssertEqual(
            AccountOperationClassifier.classify(
                previousUid: sourceUid, previousMethod: .anonymous,
                newUid: sourceUid, newIsAnonymous: false),
            .upgradeIdentity(uid: sourceUid),
            "anonymous → permanent on the SAME uid is an identity upgrade, not a merge"
        )
        XCTAssertEqual(
            AccountOperationClassifier.classify(
                previousUid: sourceUid, previousMethod: .anonymous,
                newUid: destUid, newIsAnonymous: false),
            .adopt(source: sourceUid, destination: destUid),
            "an anonymous period reaching an existing account is the ONE transferring operation"
        )
        XCTAssertEqual(
            AccountOperationClassifier.classify(
                previousUid: sourceUid, previousMethod: .apple,
                newUid: destUid, newIsAnonymous: false),
            .switchAccount(source: sourceUid, destination: destUid),
            "named → named is account switching, and it transfers nothing"
        )
        XCTAssertEqual(
            AccountOperationClassifier.classify(
                previousUid: sourceUid, previousMethod: .apple,
                newUid: destUid, newIsAnonymous: true),
            .signOut(source: sourceUid, destination: destUid),
            "signing out preserves local rows; it never merges them anywhere"
        )

        // And the permissions, stated per operation rather than
        // re-derived at each call site.
        XCTAssertTrue(AccountOperation.adopt(source: sourceUid, destination: destUid)
            .carriesTheAnonymousPeriod)
        XCTAssertFalse(AccountOperation.switchAccount(source: sourceUid, destination: destUid)
            .carriesTheAnonymousPeriod)
        XCTAssertFalse(AccountOperation.upgradeIdentity(uid: sourceUid)
            .carriesTheAnonymousPeriod)
        XCTAssertTrue(AccountOperation.switchAccount(source: sourceUid, destination: destUid)
            .isolatesTheOutgoingAccount)
        XCTAssertFalse(AccountOperation.adopt(source: sourceUid, destination: destUid)
            .isolatesTheOutgoingAccount)
        XCTAssertTrue(AccountOperation.adopt(source: sourceUid, destination: destUid)
            .mayRetireTheSource)
        XCTAssertFalse(AccountOperation.switchAccount(source: sourceUid, destination: destUid)
            .mayRetireTheSource)
    }

    /// A HANDOFF NEEDS POSITIVE PROOF THAT THE SOURCE WAS ANONYMOUS.
    ///
    /// `.unknown` is not a weaker form of `.anonymous` — it is the
    /// absence of proof, and `40` §0 finding 4 showed a just-linked Apple
    /// customer genuinely reads it. It must classify as the operation
    /// that moves nothing.
    func testAnUnprovenSourceIsNeverTreatedAsAnonymous() {
        XCTAssertEqual(
            AccountOperationClassifier.classify(
                previousUid: sourceUid, previousMethod: .unknown,
                newUid: destUid, newIsAnonymous: false),
            .switchAccount(source: sourceUid, destination: destUid),
            "an unproven source is a permanent account, because that is the safe direction"
        )
        XCTAssertFalse(
            AppSync.shouldMergeAnonymousPeriod(
                userIdChanged: true, isAnonNow: false, previousMethod: .unknown,
                previousUserId: sourceUid, newUserId: destUid),
            "and the shipping predicate agrees, because there is only one rule"
        )
    }

    /// **OPERATION A MUST BE BORING.** Same uid: no row copied, no id
    /// minted, no timestamp moved, no receipt written.
    func testASameUidUpgradeCarriesNothingAndMintsNoId() {
        let regimen = seedAnonymousPeriod(for: sourceUid)
        let before = footprint(of: sourceUid)
        let regimenIdBefore = regimen.id
        let updatedBefore = regimen.updatedAt

        let operation = AccountOperationClassifier.classify(
            previousUid: sourceUid, previousMethod: .anonymous,
            newUid: sourceUid, newIsAnonymous: false)
        XCTAssertFalse(operation.carriesTheAnonymousPeriod)
        XCTAssertFalse(operation.isolatesTheOutgoingAccount)
        XCTAssertFalse(operation.mayRetireTheSource)

        // The merge machinery itself refuses the same-uid pair, so even a
        // caller that ignored the operation would move nothing.
        AppSync.reattributeModelRows(from: sourceUid, to: sourceUid, in: context)

        XCTAssertEqual(footprint(of: sourceUid), before,
                       "an identity upgrade must not move a single row")
        XCTAssertEqual(regimen.id, regimenIdBefore,
                       "no id may be minted merely because authentication became permanent")
        XCTAssertEqual(regimen.updatedAt, updatedBefore,
                       "no timestamp may move merely because authentication became permanent")
        XCTAssertNil(AppSync.pendingMergeMarker(),
                     "an upgrade owes no handoff, so it writes no receipt")
    }

    // ================================================================
    // MARK: - 2 · THE NAMED → NAMED FIREWALL
    // ================================================================

    /// The SwiftData half — `40`'s fix, pinned here as a regression.
    func testOneAccountsRecordIsNeverMergedIntoAnother() {
        for method in [AuthMethod.apple, .email, .unknown] {
            XCTAssertFalse(
                AccountOperationClassifier.classify(
                    previousUid: sourceUid, previousMethod: method,
                    newUid: destUid, newIsAnonymous: false
                ).carriesTheAnonymousPeriod,
                "a switch from a \(method.rawValue) account must never carry its record"
            )
        }
    }

    /// **THE HALF `40` DID NOT CLOSE.** The device-scoped customer-
    /// authored keys — every workout she typed, her evening words, her
    /// sit-check, her safety answers — are not `@Model` rows, so the
    /// merge guard never saw them, and the cross-account isolation sweep
    /// runs only on explicit sign-out.
    ///
    /// And the rule has TWO halves, because a fact keyed to the device
    /// follows the PERSON: it must be cleared on a SWITCH and must
    /// survive an ADOPT.
    func testASwitchClearsHerDeviceScopedRecordAndAnAdoptKeepsIt() {
        seedDeviceScopedRecord()
        XCTAssertEqual(deviceScopedSurvivors(), Self.deviceScopedKeys.count)

        // ADOPT — the same person. Nothing is swept.
        XCTAssertFalse(
            AppSync.applyIsolationIfNeeded(
                for: .adopt(source: sourceUid, destination: destUid)),
            "an adopt is the same person; her device-scoped record follows her"
        )
        XCTAssertEqual(deviceScopedSurvivors(), Self.deviceScopedKeys.count,
                       "an adopt must not sweep the workouts and words she just wrote")

        // UPGRADE — the same person AND the same account.
        XCTAssertFalse(
            AppSync.applyIsolationIfNeeded(for: .upgradeIdentity(uid: sourceUid)))
        XCTAssertEqual(deviceScopedSurvivors(), Self.deviceScopedKeys.count)

        // SWITCH — a different person on the same phone.
        XCTAssertTrue(
            AppSync.applyIsolationIfNeeded(
                for: .switchAccount(source: sourceUid, destination: destUid)),
            "named → named is a different person on this phone"
        )
        XCTAssertEqual(deviceScopedSurvivors(), 0,
                       "account B must not read account A's workouts, evening words or safety answers")
    }

    /// Two fully populated permanent accounts. Switching moves nothing,
    /// in either direction, and switching BACK finds the first account
    /// exactly as it was.
    func testSwitchingBetweenTwoAccountsLeavesBothRecordsIntact() {
        seedAnonymousPeriod(for: sourceUid)
        seedAnonymousPeriod(for: destUid)
        let a = footprint(of: sourceUid)
        let b = footprint(of: destUid)
        XCTAssertGreaterThan(a, 0)
        XCTAssertGreaterThan(b, 0)

        let out = AccountOperationClassifier.classify(
            previousUid: sourceUid, previousMethod: .apple,
            newUid: destUid, newIsAnonymous: false)
        if out.carriesTheAnonymousPeriod {
            AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context)
        }
        XCTAssertEqual(footprint(of: sourceUid), a, "ZERO of A's rows may change owner")
        XCTAssertEqual(footprint(of: destUid), b, "ZERO of B's rows may change because A existed")

        let back = AccountOperationClassifier.classify(
            previousUid: destUid, previousMethod: .apple,
            newUid: sourceUid, newIsAnonymous: false)
        if back.carriesTheAnonymousPeriod {
            AppSync.reattributeModelRows(from: destUid, to: sourceUid, in: context)
        }
        XCTAssertEqual(footprint(of: sourceUid), a, "and switching back finds A intact")
        XCTAssertEqual(footprint(of: destUid), b)
    }

    // ================================================================
    // MARK: - 3 · THE COLLISION HANDOFF
    // ================================================================

    /// **THE ONE UNGUARDED UNIQUE KEY, THROUGH THE REAL STORE.** A day
    /// the destination account already lived must not take the whole
    /// handoff down with it.
    ///
    /// This one measures the blast radius rather than the row, because
    /// the whole carry is one context and one `save()`. It is a CONTROL:
    /// it stays green against the unguarded merge, because SwiftData
    /// resolves the duplicate key silently rather than throwing — which
    /// is the finding, not a weakness of the test. The determinism is
    /// asserted next door, on the pure mutation.
    func testADayTheDestinationAlreadyLivedDoesNotDiscardTheWholeHandoff() {
        seedAnonymousPeriod(for: sourceUid)
        context.insert(dayProgress(for: sourceUid, day: 3, quality: 0.4))
        context.insert(dayProgress(for: destUid, day: 3, quality: 0.9))
        try? context.save()

        let carried = AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context)

        XCTAssertTrue(carried, "the handoff must COMMIT, not be discarded by one duplicate key")
        XCTAssertEqual(footprint(of: sourceUid), 0,
                       "no row may still answer to the retired account")
        XCTAssertGreaterThan(footprint(of: destUid), 1,
                             "and her record must be IN the account — moving is not vanishing")
    }

    /// The account's own day wins, and content is never compared. Two
    /// days that look alike are not evidence about each other.
    ///
    /// **Asserted on the PURE mutation, deliberately.** Left to
    /// SwiftData, a duplicate `@Attribute(.unique)` key does not throw —
    /// it silently collapses the two rows into one, and nothing
    /// specifies which one survives. That is worse than a throw and it
    /// is exactly why the defect was invisible: no error, no log, no
    /// number moved, and a footprint test cannot tell a resolved
    /// collision from a correct carry. The guard makes the outcome a
    /// stated rule instead of a merge policy.
    func testTheDestinationsOwnDayWinsAndContentIsNeverCompared() {
        let accountDay = dayProgress(for: destUid, day: 3, quality: 0.9)
        let incomingDay = dayProgress(for: sourceUid, day: 3, quality: 0.4)

        let dropped = AppSync.applyReattribution(
            to: destUid, sessions: [], progress: [incomingDay], weightLogs: [],
            existingProgress: [accountDay])

        XCTAssertEqual(dropped.count, 1,
                       "the incoming day must be REFUSED by the merge, not by a merge policy")
        XCTAssertIdentical(dropped.first, incomingDay)
        XCTAssertEqual(incomingDay.userId, sourceUid,
                       "a refused row is never re-keyed, so it cannot collide at save time")
        XCTAssertEqual(accountDay.primaryQualityScore, 0.9,
                       "the destination's own day stands, and content is never compared")
        XCTAssertEqual(accountDay.compositeKey, "\(destUid):3")

        // And the day the destination does NOT have still carries.
        let freshDay = dayProgress(for: sourceUid, day: 9, quality: 0.5)
        let none = AppSync.applyReattribution(
            to: destUid, sessions: [], progress: [freshDay], weightLogs: [],
            existingProgress: [accountDay])
        XCTAssertEqual(none.count, 0)
        XCTAssertEqual(freshDay.userId, destUid, "a day the account never lived is hers to keep")
        XCTAssertEqual(freshDay.compositeKey, "\(destUid):9")
    }

    /// ▎ AN AUTHORITY GRANTED TO ONE IDENTITY IS NOT ANOTHER'S.
    ///
    /// The deployed RLS refuses a client insert of a care-team regimen
    /// (`authority = 'self' AND org_id IS NULL AND source_protocol_id IS
    /// NULL`), so a re-keyed one could never reach the server — and
    /// LOCALLY it would make the destination account's regimen read-only
    /// and put "assigned by your care team" on the screen of somebody
    /// that clinic has never met.
    func testACareTeamRegimenNeverBecomesAnotherIdentitysPrescription() {
        let assigned = RegimenPlanRecord(userId: sourceUid, kind: "medication",
                                         displayName: "assigned", scheduleRule: "weeklyAnchor",
                                         anchorWeekday: 2)
        assigned.authority = "care_team"
        assigned.orgId = "org-lakeside"
        context.insert(assigned)
        try? context.save()

        let report = IdentityMerge.carryRemainingFamilies(
            from: sourceUid, to: destUid, in: context)
        try? context.save()

        XCTAssertEqual(report.refusedForeignAuthority, 1)
        XCTAssertEqual(report.regimenPlans, 0, "a clinic's assignment is not hers to move")
        let carried = (try? context.fetchCount(FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == destUid }))) ?? -1
        XCTAssertEqual(carried, 0,
                       "the destination account must not acquire a prescription nobody wrote for it")
        XCTAssertEqual(RegimenService.activeCareTeamMedicationPlan(userId: destUid, in: context),
                       nil,
                       "and no surface may read it as care-team managed")
    }

    /// The same law one layer over: iOS writes `prescribed` NEVER, and
    /// the RLS enforces it. Zero rows in production today, which is the
    /// cheapest moment this rule will ever be made.
    func testAPrescribedProgramFactNeverFollowsThePerson() {
        context.insert(ProgramFactRecord(userId: sourceUid, kind: "stepGoal", value: "i:5000",
                                         authority: "prescribed", basis: "assigned",
                                         source: "clinic"))
        context.insert(ProgramFactRecord(userId: sourceUid, kind: "proteinAdjust", value: "w:up",
                                         authority: "preferred", basis: "stated",
                                         source: "user"))
        try? context.save()

        let report = IdentityMerge.carryRemainingFamilies(
            from: sourceUid, to: destUid, in: context)
        try? context.save()

        XCTAssertEqual(report.refusedForeignAuthority, 1)
        XCTAssertEqual(report.programFacts, 1, "and her OWN preference still follows her")
        let owner = destUid
        let facts = (try? context.fetch(FetchDescriptor<ProgramFactRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []
        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts.first?.authority, "preferred")
        XCTAssertFalse(facts.contains { $0.authority == "prescribed" },
                       "no authority is ever downgraded to make a row carryable")
    }

    /// The control beside the two refusals: they must not over-refuse.
    /// Her own medication, her own doses and her own symptoms are hers
    /// and they follow her.
    func testHerOwnRegimenDosesAndSymptomsStillFollowTheAccount() {
        seedAnonymousPeriod(for: sourceUid)

        let report = IdentityMerge.carryRemainingFamilies(
            from: sourceUid, to: destUid, in: context)
        try? context.save()

        XCTAssertEqual(report.refusedForeignAuthority, 0)
        XCTAssertEqual(report.regimenPlans, 1)
        XCTAssertEqual(report.doseEvents, 1)
        XCTAssertEqual(report.observations, 1)
        XCTAssertEqual(report.memories, 1)
        XCTAssertEqual(report.chatMessages, 1)
    }

    /// §17 — ONE LIVE PLAN, and the destination's is the account's
    /// truth. `31`'s earliest-startDate rule was built to kill an
    /// interim plan minted TODAY; it differs from this one in exactly
    /// one shape, and that shape re-dates the journey she is living in.
    func testTheDestinationsLivePlanSurvivesAnOlderAnonymousOne() {
        let accountPlan = ProgramPlanRecord(
            id: "plan-account", userId: destUid,
            startDate: .now.addingTimeInterval(-20 * 86_400),
            goalDate: .now.addingTimeInterval(70 * 86_400),
            totalDays: 90, intensityTier: "medium")
        accountPlan.pendingUpsert = false
        let anonPlan = ProgramPlanRecord(
            id: "plan-anon", userId: sourceUid,
            startDate: .now.addingTimeInterval(-60 * 86_400),
            goalDate: .now.addingTimeInterval(30 * 86_400),
            totalDays: 90, intensityTier: "soft")

        AppSync.applyReattribution(
            to: destUid, sessions: [], progress: [], weightLogs: [],
            plans: [anonPlan], checks: [], existingPlans: [accountPlan])

        XCTAssertEqual(accountPlan.phase, "active",
                       "the plan she has been living in must not be re-dated by a sign-in")
        XCTAssertNil(accountPlan.archivedAt)
        XCTAssertEqual(anonPlan.userId, destUid, "and A's plan is not discarded")
        XCTAssertEqual(anonPlan.phase, "abandoned", "it arrives as history, not as a second present tense")
        XCTAssertNotNil(anonPlan.archivedAt)
    }

    /// §16 — a regimen chain's head is a CURRENT-STATE claim, and
    /// `activeMedicationPlan` resolves two heads by `createdAt` DESC,
    /// which on a hydrated row is the hydration instant. So the rule has
    /// to be explicit.
    func testTheDestinationsLiveRegimenStaysTheOnlyPresentTense() {
        let accountRegimen = RegimenPlanRecord(userId: destUid, kind: "medication",
                                               displayName: "her account's medication",
                                               scheduleRule: "weeklyAnchor", anchorWeekday: 1)
        context.insert(accountRegimen)
        seedAnonymousPeriod(for: sourceUid)

        let report = IdentityMerge.carryRemainingFamilies(
            from: sourceUid, to: destUid, in: context)
        try? context.save()

        XCTAssertEqual(report.regimensEndedByDestination, 1)
        XCTAssertNil(accountRegimen.endedAt, "the account's own regimen keeps the present tense")
        XCTAssertEqual(
            RegimenService.activeMedicationPlan(userId: destUid, in: context)?.id,
            accountRegimen.id,
            "there must be exactly one live medication regimen and it is the account's")
        let owner = destUid
        let all = (try? context.fetch(FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []
        XCTAssertEqual(all.count, 2, "and A's regimen is preserved as history, not discarded")
        XCTAssertEqual(all.filter { $0.endedAt == nil }.count, 1)
    }

    /// Unknown consent is never permission — `38` §13, `40` §2, pinned
    /// again here because this pass added two more refusals beside it
    /// and they must not drift apart.
    func testConsentIsNeverCarriedAcrossAnIdentityTransition() {
        context.insert(ConsentGrantRecord(userId: sourceUid, scope: "visit_packet_sharing",
                                          purpose: "share the packet"))
        try? context.save()

        AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context)

        let carried = (try? context.fetchCount(FetchDescriptor<ConsentGrantRecord>(
            predicate: #Predicate { $0.userId == destUid }))) ?? -1
        XCTAssertEqual(carried, 0,
                       "a grant made as one identity is not another identity's answer")
    }

    // ================================================================
    // MARK: - 4 · CONVERGENCE
    // ================================================================

    /// ▎ AN ISOLATION SWEEP CLEARS WHAT THE NEXT PERSON MUST NOT SEE.
    /// ▎ IT MUST NOT CLEAR WHAT THIS DEVICE STILL OWES.
    ///
    /// The receipt names two uids and no content. Swept at sign-out, an
    /// interrupted handoff lost the only record that the anonymous
    /// period had never reached her account.
    func testTheHandoffReceiptSurvivesASignOut() {
        AppSync.writePendingMergeMarker(from: sourceUid, to: destUid)
        XCTAssertNotNil(AppSync.pendingMergeMarker())

        AppSync.shared.clearOnboardingUserDefaults()

        let marker = AppSync.pendingMergeMarker()
        XCTAssertEqual(marker?.from, sourceUid,
                       "signing out between an interrupted handoff and the next launch must not strand it")
        XCTAssertEqual(marker?.to, destUid)
    }

    /// The same sentence for the deletion intent. An intent at
    /// `.serverComplete` is the only record that a CONFIRMED deletion's
    /// local purge has not run.
    func testAConfirmedDeletionIsStillOwedAfterASignOut() {
        AccountDeletionIntent.markServerComplete(userId: sourceUid)
        XCTAssertEqual(AccountDeletionIntent.pendingLocalPurge(), sourceUid)

        AppSync.shared.clearOnboardingUserDefaults()

        XCTAssertEqual(AccountDeletionIntent.pendingLocalPurge(), sourceUid,
                       "a confirmed deletion's purge is owed until it runs, sign-out or not")

        // …and an UNCONFIRMED one still goes, because nothing is owed.
        AccountDeletionIntent.begin(userId: sourceUid)
        AppSync.shared.clearOnboardingUserDefaults()
        XCTAssertNil(AccountDeletionIntent.pending(),
                     "an intent the server never answered owes nothing and must not follow the phone")
    }

    /// A receipt whose source or destination no longer exists can only
    /// ever re-key rows into an account that is gone.
    func testAnAccountDeletionTakesItsHandoffReceiptWithIt() {
        AppSync.writePendingMergeMarker(from: sourceUid, to: destUid)
        AppSync.clearLocalUserRecords(userId: destUid, in: context)
        XCTAssertNil(AppSync.pendingMergeMarker(),
                     "the receipt goes with either account it names")

        AppSync.writePendingMergeMarker(from: sourceUid, to: destUid)
        AppSync.clearLocalUserRecords(userId: sourceUid, in: context)
        XCTAssertNil(AppSync.pendingMergeMarker())
    }

    /// §19 — DELETE BEATS TRANSFER, and a deletion is scoped to the
    /// account that made it. The source's ledger names ids that were
    /// just re-keyed or retired, so it can never match again; it must
    /// not become the destination's answer about the destination's own
    /// rows.
    func testTheDeletionLedgerNeverCrossesIntoTheDestination() {
        seedAnonymousPeriod(for: sourceUid)
        DeletionLedger.record(id: "a-plate-she-removed", userId: sourceUid)
        XCTAssertEqual(DeletionLedger.count(userId: sourceUid), 1)

        AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context)

        XCTAssertEqual(DeletionLedger.count(userId: sourceUid), 0,
                       "the source's ledger protects ids that no longer exist anywhere")
        XCTAssertEqual(DeletionLedger.count(userId: destUid), 0,
                       "and a deletion she made as one identity is never asserted about another's rows")
    }

    /// **EVERY FAMILY THAT CAN COLLIDE, COLLIDING AT ONCE.**
    ///
    /// The carry is one context and one `save()`, so a single
    /// unguarded unique key discards all of it. Rather than fake a
    /// failure, this seeds the WORST case — a destination account that
    /// already holds a colliding row in every family whose key is not a
    /// fresh uuid — and asserts the transaction commits, the source is
    /// empty, and every one of the destination's own rows is the one
    /// that survived.
    ///
    /// It is also the coverage claim: after this, there is no reachable
    /// unique-key collision left in the merge, which is why no test in
    /// this file has to simulate one.
    func testEveryFamilyThatCanCollideIsGuardedSoTheHandoffCommits() {
        seedAnonymousPeriod(for: sourceUid)
        context.insert(dayProgress(for: sourceUid, day: 3, quality: 0.4))
        context.insert(ExerciseCalibrationRecord(userId: sourceUid, exerciseType: "plank"))
        context.insert(WeeklyReadRecord(userId: sourceUid, windowStartDay: "2026-08-10",
                                        anchor: "doseDay", offerKey: "steps",
                                        decision: "accepted"))
        context.insert(UserRecord(id: sourceUid, name: "the device"))

        // The destination already holds a colliding row in EVERY family
        // whose key is not a fresh uuid.
        context.insert(dayProgress(for: destUid, day: 3, quality: 0.9))
        context.insert(ExerciseCalibrationRecord(userId: destUid, exerciseType: "plank"))
        context.insert(WeeklyReadRecord(userId: destUid, windowStartDay: "2026-08-10",
                                        anchor: "doseDay", offerKey: "protein",
                                        decision: "declined"))
        let destRegimen = RegimenPlanRecord(userId: destUid, kind: "medication",
                                            displayName: "the account's", scheduleRule: "daily")
        context.insert(destRegimen)
        context.insert(DoseEventRecord(
            id: DoseEventStore.deterministicId(userId: destUid, dayKey: "2026-08-14"),
            userId: destUid, regimenPlanId: destRegimen.id, dayKey: "2026-08-14",
            scheduledAt: .now, status: "skipped"))
        context.insert(ObservationRecord(
            id: SideEffectLog.id(userId: destUid, symptom: "nausea", dayKey: "2026-08-14"),
            userId: destUid, kind: "symptom", dayKey: "2026-08-14", valueText: "severe"))
        context.insert(UserRecord(id: destUid, name: "the account"))
        try? context.save()

        AppSync.writePendingMergeMarker(from: sourceUid, to: destUid)
        let committed = AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context)

        XCTAssertTrue(committed,
                      "a destination that collides in every guarded family must still commit")
        XCTAssertEqual(footprint(of: sourceUid), 0,
                       "and nothing may be left answering to the retired account")

        let owner = destUid
        let profile = (try? context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == owner })))?.first
        XCTAssertEqual(profile?.name, "the account",
                       "the account's own body facts are never overwritten by the device's")
        let reads = (try? context.fetch(FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []
        XCTAssertEqual(reads.count, 1, "one week means one read for one account")
        XCTAssertEqual(reads.first?.decision, "declined", "and the account's own decision stands")
        let doses = (try? context.fetch(FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []
        XCTAssertEqual(doses.count, 1)
        XCTAssertEqual(doses.first?.status, "skipped",
                       "two dose events are never merged because they look alike")
    }

    // ================================================================
    // MARK: - 5 · THE TERMINAL STATE OF THE SOURCE
    // ================================================================

    /// **[CORR] on `40` §3.4.** Its safety argument rests on "the local
    /// store is a superset of A's server rows". A reinstall re-adopts
    /// the Keychain session with an EMPTY store, and if the launch
    /// hydrate has not landed, retiring A deletes the only copy that
    /// exists anywhere.
    func testAnAccountThisDeviceHoldsNoRowsForIsNeverRetired() {
        XCTAssertEqual(footprint(of: sourceUid), 0)
        XCTAssertFalse(
            SourceRetirementSafety.mayRetire(sourceLocalRowCount: footprint(of: sourceUid)),
            "never delete a server account whose record this device is not carrying"
        )

        seedAnonymousPeriod(for: sourceUid)
        XCTAssertGreaterThan(footprint(of: sourceUid), 0)
        XCTAssertTrue(
            SourceRetirementSafety.mayRetire(sourceLocalRowCount: footprint(of: sourceUid)),
            "and an account whose record IS in hand is retired, which is the whole fix"
        )
    }

    /// The gate that must be checked first, whatever else is true.
    func testANamedAccountIsStillNeverRetired() {
        XCTAssertEqual(
            AnonymousRetirementPolicy.decide(
                outgoingUid: sourceUid, outgoingWasAnonymous: false,
                outgoingAccessToken: "token", incomingUid: destUid),
            .leave(.outgoingWasNotAnonymous)
        )
    }

    /// §21 — REPLAY. The same transition run twice must reach the same
    /// final state: no duplicate weigh-in, dose, symptom, regimen or
    /// profile.
    func testReplayingTheHandoffDoesNotDuplicateHerRecord() {
        seedAnonymousPeriod(for: sourceUid)
        let before = footprint(of: sourceUid)

        AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context)
        let once = footprint(of: destUid)
        AppSync.reattributeModelRows(from: sourceUid, to: destUid, in: context)
        let twice = footprint(of: destUid)

        XCTAssertEqual(once, before, "her whole record arrives")
        XCTAssertEqual(twice, once, "and running the handoff again adds nothing")
        XCTAssertEqual(footprint(of: sourceUid), 0)
    }
}
