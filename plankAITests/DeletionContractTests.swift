import XCTest
import SwiftData
import PlankSync
import PlankFood
@testable import plankAI

// MARK: - DeletionContractTests (v25 §38)
//
// ▎ IF THE CUSTOMER DELETES SOMETHING, JENI MUST NEVER SILENTLY
// ▎ RESURRECT IT.
//
// Every test here is a CUSTOMER PROMISE, not a mechanism. There is no
// `testTombstoneRecorded` and no `testSweepWasCalled`: each test seeds
// the record, deletes it through the SAME function the customer's own
// button calls, replays the exact resurrection the audit reproduced
// (§38 §3 — a stale second device pushes the row back, the deleting
// device's insert-only hydrate re-inserts it), and asserts the record
// is gone from the surfaces she reads.
//
// WHAT IS DELIBERATELY NOT TESTED HERE, and why: that a deletion
// propagates TO the other device. It cannot, without the server
// tombstone migration drafted in §38 §5. Faking it with a
// repository-local simulation and calling production safe is the
// failure mode this whole line of work exists to remove. §38 §21
// answers that question in words instead.

@MainActor
final class DeletionContractTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }

    override func setUp() {
        super.setUp()
        // The seam a test installs IS the seam the product installs —
        // the same static `configure()` calls. Without it, deleting a
        // plate would not reach the ledger and this file would be
        // testing a fixture instead of the product.
        AppSync.installFoodDeletionSeam()
    }

    // MARK: helpers

    private func wipe(_ uid: String) {
        let owner = uid
        try? context.delete(model: WeightLogRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: DoseEventRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: ObservationRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: ConsentGrantRecord.self,
                            where: #Predicate { $0.userId == owner })
        try? context.delete(model: UserRecord.self,
                            where: #Predicate { $0.id == owner })
        try? context.save()
        FoodLogPersister.deleteAllEntries(userId: owner)
        DeletionLedger.clear(userId: owner)
        MoveManualStore.wipe()
    }

    /// Everything device B does to device A, in one call: B still holds
    /// its own copy of the row, so B re-uploads it and A's insert-only
    /// hydrate puts it back. This is `mergeRemote` /
    /// `applyHydratedWeightLogs` / `hydrateDoseEvents` /
    /// `hydrateObservations` — the real functions, not a stand-in.
    private func aStaleSecondDevicePushesItBackAndThisPhoneHydrates(
        userId: String, in body: () -> Void
    ) {
        body()
        DeletionLedger.sweep(userId: userId, in: context)
    }

    // MARK: - 1 · FOOD

    func testAPlateDeletedOnThisPhoneNeverComesBackToThisPhone() {
        let uid = "deletion-food-a"
        wipe(uid); defer { wipe(uid) }

        let plateId = UUID().uuidString
        let row = FoodLogPersister.SyncableEntry(
            id: plateId, userId: uid, loggedAt: .now,
            kcal: 640, protein: 42, carbs: 55, fat: 22, fiber: 9,
            sugar: 12, sodiumMg: 880, satFatG: 6,
            title: "chicken and rice", source: "photo"
        )
        FoodLogPersister.mergeRemote([row])
        XCTAssertEqual(FoodLogPersister.allEntries(userId: uid).count, 1)

        // Her delete — the same function THE BOOK's `remove` calls.
        FoodLogPersister.deleteEntry(id: plateId)
        XCTAssertTrue(FoodLogPersister.allEntries(userId: uid).isEmpty)

        aStaleSecondDevicePushesItBackAndThisPhoneHydrates(userId: uid) {
            FoodLogPersister.mergeRemote([row])
        }

        XCTAssertTrue(
            FoodLogPersister.allEntries(userId: uid).isEmpty,
            "a plate she removed came back because her other phone re-uploaded it"
        )
    }

    func testAPlateSheNeverDeletedStillArrivesFromTheServer() {
        let uid = "deletion-food-control"
        wipe(uid); defer { wipe(uid) }

        let keptId = UUID().uuidString
        let deletedId = UUID().uuidString
        func entry(_ id: String, _ title: String) -> FoodLogPersister.SyncableEntry {
            FoodLogPersister.SyncableEntry(
                id: id, userId: uid, loggedAt: .now,
                kcal: 300, protein: 20, carbs: 30, fat: 8, fiber: 4,
                sugar: 3, sodiumMg: 200, satFatG: 2,
                title: title, source: "photo"
            )
        }
        FoodLogPersister.mergeRemote([entry(deletedId, "the one she removed")])
        FoodLogPersister.deleteEntry(id: deletedId)

        aStaleSecondDevicePushesItBackAndThisPhoneHydrates(userId: uid) {
            FoodLogPersister.mergeRemote([
                entry(deletedId, "the one she removed"),
                entry(keptId, "the one she logged on her ipad"),
            ])
        }

        let titles = FoodLogPersister.allEntries(userId: uid).map(\.title)
        XCTAssertEqual(
            titles, ["the one she logged on her ipad"],
            "the ledger must block exactly one plate, never the record around it"
        )
    }

    // MARK: - 2 · WEIGHT

    func testAWeighInDeletedOnThisPhoneNeverComesBackToThisPhone() {
        let uid = "deletion-weight-a"
        wipe(uid); defer { wipe(uid) }

        let rowId = UUID().uuidString
        insertHydratedWeighIn(id: rowId, userId: uid)
        XCTAssertEqual(weighIns(uid), 1)

        // Her delete — the same chokepoint `your weigh-ins` calls.
        XCTAssertTrue(WeightLogWriter.remove(id: rowId, userId: uid, in: context))
        XCTAssertEqual(weighIns(uid), 0)

        aStaleSecondDevicePushesItBackAndThisPhoneHydrates(userId: uid) {
            insertHydratedWeighIn(id: rowId, userId: uid)
        }

        XCTAssertEqual(
            weighIns(uid), 0,
            "a weigh-in she removed came back — and it is the numerator of both daily targets"
        )
    }

    // MARK: - 3 · DOSE

    func testADoseDeletedOnThisPhoneNeverComesBackToThisPhone() {
        let uid = "deletion-dose-a"
        wipe(uid); defer { wipe(uid) }

        let dayKey = "2026-08-11"
        DoseEventStore.upsert(
            dayKey: dayKey, scheduledAt: .now, status: "taken", takenAt: .now,
            source: "sheet", userId: uid, regimenPlanId: "plan-1",
            in: context, sync: false
        )
        XCTAssertEqual(doses(uid), 1)

        // Her unmark — "didn't, actually".
        DoseEventStore.delete(dayKey: dayKey, userId: uid, in: context)
        XCTAssertEqual(doses(uid), 0)

        aStaleSecondDevicePushesItBackAndThisPhoneHydrates(userId: uid) {
            insertHydratedDose(userId: uid, dayKey: dayKey)
        }

        XCTAssertEqual(
            doses(uid), 0,
            "a dose she unmarked came back on the next pull"
        )
    }

    /// The control that makes the ledger safe for DETERMINISTIC ids.
    /// A dose slot's id is `user × slot`, so without `supersede` the
    /// ledger would refuse her own re-mark forever.
    func testMarkingTheSameDoseSlotAgainIsNotBlockedByTheOldDeletion() {
        let uid = "deletion-dose-supersede"
        wipe(uid); defer { wipe(uid) }

        let dayKey = "2026-08-11"
        DoseEventStore.upsert(
            dayKey: dayKey, scheduledAt: .now, status: "taken", takenAt: .now,
            source: "sheet", userId: uid, regimenPlanId: "plan-1",
            in: context, sync: false
        )
        DoseEventStore.delete(dayKey: dayKey, userId: uid, in: context)
        // She changes her mind and marks it again.
        DoseEventStore.upsert(
            dayKey: dayKey, scheduledAt: .now, status: "taken", takenAt: .now,
            source: "sheet", userId: uid, regimenPlanId: "plan-1",
            in: context, sync: false
        )
        XCTAssertEqual(doses(uid), 1)

        DeletionLedger.sweep(userId: uid, in: context)

        XCTAssertEqual(
            doses(uid), 1,
            "her own re-mark was deleted by a tombstone the re-mark should have cleared"
        )
    }

    // MARK: - 4 · SYMPTOM

    func testASymptomClearedOnThisPhoneNeverComesBackToThisPhone() {
        let uid = "deletion-symptom-a"
        wipe(uid); defer { wipe(uid) }

        let dayKey = "2026-08-12"
        SideEffectLog.record(.nausea, severity: .aTouch, dayKey: dayKey, userId: uid, in: context)
        XCTAssertEqual(symptoms(uid), 1)

        SideEffectLog.remove(.nausea, dayKey: dayKey, userId: uid, in: context)
        XCTAssertEqual(symptoms(uid), 0)

        let symptomId = SideEffectLog.id(
            userId: uid, symptom: SideEffectSymptom.nausea.rawValue, dayKey: dayKey
        )
        aStaleSecondDevicePushesItBackAndThisPhoneHydrates(userId: uid) {
            insertHydratedSymptom(id: symptomId, userId: uid, dayKey: dayKey)
        }

        XCTAssertEqual(
            symptoms(uid), 0,
            "a symptom she cleared came back, and VisitPacket reads these rows"
        )
    }

    func testLoggingTheSameSymptomAgainIsNotBlockedByTheOldClear() {
        let uid = "deletion-symptom-supersede"
        wipe(uid); defer { wipe(uid) }

        let dayKey = "2026-08-12"
        SideEffectLog.record(.nausea, severity: .aTouch, dayKey: dayKey, userId: uid, in: context)
        SideEffectLog.remove(.nausea, dayKey: dayKey, userId: uid, in: context)
        SideEffectLog.record(.nausea, severity: .noticeable, dayKey: dayKey, userId: uid, in: context)

        DeletionLedger.sweep(userId: uid, in: context)

        XCTAssertEqual(
            symptoms(uid), 1,
            "she logged it again and the old clear deleted her new record"
        )
    }

    // MARK: - 5 · THE LEDGER IS HERS, AND ONLY HERS

    func testTheLedgerNeverReachesAnotherAccount() {
        let a = "deletion-ledger-x", b = "deletion-ledger-y"
        wipe(a); wipe(b); defer { wipe(a); wipe(b) }

        let sharedId = "same-id-two-accounts"
        DeletionLedger.record(id: sharedId, userId: a)

        XCTAssertTrue(DeletionLedger.contains(id: sharedId, userId: a))
        XCTAssertFalse(
            DeletionLedger.contains(id: sharedId, userId: b),
            "one account's deletion must never suppress another account's record"
        )
    }

    func testSigningOutKeepsTheDeletionLedger() {
        let uid = "deletion-signout"
        wipe(uid); defer { wipe(uid) }

        DeletionLedger.record(id: "a-plate-she-removed", userId: uid)

        // The sign-out sweep, verbatim — the same function
        // AccountView.performSignOut calls.
        AppSync.shared.clearOnboardingUserDefaults()

        XCTAssertTrue(
            DeletionLedger.contains(id: "a-plate-she-removed", userId: uid),
            """
            the ledger was swept at SIGN-OUT. sign-out preserves the rows it \
            protects, so clearing it there re-opens every resurrection the \
            next time she signs back in.
            """
        )
    }

    func testDeletingTheAccountLeavesNoDeletionLedgerBehind() {
        let uid = "deletion-account-ledger"
        wipe(uid); defer { wipe(uid) }

        DeletionLedger.record(id: "a-plate-she-removed", userId: uid)
        XCTAssertEqual(DeletionLedger.count(userId: uid), 1)

        AppSync.clearLocalUserRecords(userId: uid, in: context)

        XCTAssertEqual(
            DeletionLedger.count(userId: uid), 0,
            "the ledger is derived entirely from her own deletions. it is hers, and it goes with the account."
        )
    }

    // MARK: - 6 · MANUAL MOVEMENT — the P0 this pass found

    func testDeletingTheAccountLeavesNoWorkoutSheTypedOnThisDevice() {
        let uid = "deletion-move"
        wipe(uid); defer { wipe(uid) }

        MoveManualStore.record(kind: .strength, minutes: 30, weightKg: 74)
        XCTAssertFalse(MoveManualStore.all().isEmpty)

        AppSync.shared.clearOnboardingUserDefaults()

        XCTAssertTrue(
            MoveManualStore.all().isEmpty,
            """
            every workout she typed into MOVE survived "delete my account" on \
            disk and in every device backup afterwards, and survived sign-out \
            into the next account on this phone.
            """
        )
    }

    // MARK: - 7 · CROSS-ACCOUNT

    func testAnotherAccountOnThisDeviceInheritsNothing() {
        let a = "deletion-account-a", b = "deletion-account-b"
        wipe(a); wipe(b); defer { wipe(a); wipe(b) }

        for uid in [a, b] {
            context.insert(UserRecord(id: uid, name: uid))
            let row = WeightLogRecord(userId: uid, weightKg: 70, loggedAt: .now, source: "manual")
            context.insert(row)
            DeletionLedger.record(id: "\(uid)-removed-plate", userId: uid)
        }
        try? context.save()

        AppSync.clearLocalUserRecords(userId: a, in: context)

        XCTAssertEqual(weighIns(a), 0)
        XCTAssertEqual(DeletionLedger.count(userId: a), 0)
        XCTAssertEqual(weighIns(b), 1, "one account's deletion reached another account's record")
        XCTAssertEqual(
            DeletionLedger.count(userId: b), 1,
            "one account's deletion cleared another account's deletion ledger"
        )
    }

    // MARK: - 8 · CONSENT — the account's answer, not the device's

    func testHydratingAConsentGrantShowsTheAccountsAnswerNotTheDevices() {
        let uid = "deletion-consent-a"
        wipe(uid); defer { wipe(uid) }

        // A clean phone: she granted this on her old phone, so there is
        // no local row. Before the hydrate the toggle read OFF.
        XCTAssertFalse(ConsentService.isActive(
            scope: ConsentService.visitPacketScope, userId: uid, in: context
        ))

        // What the hydrate lands.
        let hydrated = ConsentGrantRecord(
            id: "grant-from-her-other-phone", userId: uid,
            scope: ConsentService.visitPacketScope,
            purpose: "share the visit packet with a connected care team"
        )
        hydrated.pendingUpsert = false
        context.insert(hydrated)
        try? context.save()

        XCTAssertTrue(
            ConsentService.isActive(
                scope: ConsentService.visitPacketScope, userId: uid, in: context
            ),
            "the toggle showed a device fact where she reads an account fact"
        )

        // And now she CAN withdraw it from this phone — `revoke()`
        // needs a local active grant, which is exactly what was missing.
        ConsentService.revoke(
            scope: ConsentService.visitPacketScope, userId: uid, in: context
        )
        XCTAssertFalse(ConsentService.isActive(
            scope: ConsentService.visitPacketScope, userId: uid, in: context
        ))
        XCTAssertNotNil(hydrated.revokedAt, "a revoke must be a durable timestamp, not a local absence")
    }

    func testAnUnknownConsentIsNeverPermission() {
        let uid = "deletion-consent-unknown"
        wipe(uid); defer { wipe(uid) }

        // No local row and no hydrated row — the read failed, or she
        // has never answered. Either way the answer is the same.
        XCTAssertFalse(
            ConsentService.isActive(
                scope: ConsentService.visitPacketScope, userId: uid, in: context
            ),
            "unknown consent must never read as permission"
        )
    }

    // MARK: - counters

    private func weighIns(_ uid: String) -> Int {
        ((try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == uid }))) ?? []).count
    }

    private func doses(_ uid: String) -> Int {
        ((try? context.fetch(FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == uid }))) ?? []).count
    }

    private func symptoms(_ uid: String) -> Int {
        ((try? context.fetch(FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.userId == uid }))) ?? []).count
    }

    // MARK: - 5 · THE SCALE (v25 §44)
    //
    // ▎ A WEIGH-IN SHE REMOVED MUST NOT COME BACK FROM APPLE HEALTH.
    //
    // `34` gave the weigh-in a list and a `remove it`, and the screen
    // states the promise in as many words: *"every weigh-in lands here
    // with its date, and you can fix or remove any of them."*
    //
    // `BodyMassImportService` re-reads ninety days of
    // `HKQuantityTypeIdentifierBodyMass` at every launch AND on every
    // observer fire, and it decides BY CALENDAR DAY: a day with no local
    // row is a day it creates one for. It mints a FRESH uuid when it
    // does — so the deletion ledger, which names the id she removed,
    // cannot see it.
    //
    // So for the commonest weigh-in source this product has (a smart
    // scale writing into Health), `remove it` undid itself on the next
    // launch, silently, and the resurrected number went straight back to
    // being the numerator of BOTH daily targets and a row in the
    // clinician packet's weight section.
    //
    // The ledger names IDS. A scale sample has no id this device chose,
    // so the retraction is recorded against the thing she actually
    // cleared: THE DAY.

    func testAWeighInSheRemovedIsNotReImportedFromAppleHealth() {
        let uid = "deletion-scale-a"
        wipe(uid); defer { wipe(uid) }

        let day = Date()
        let row = WeightLogRecord(
            userId: uid, weightKg: 74.2, loggedAt: day, source: "healthkit"
        )
        row.pendingUpsert = false
        context.insert(row)
        try? context.save()

        // Her delete — the same function `your weigh-ins` › `remove it`
        // calls.
        XCTAssertTrue(WeightLogWriter.remove(id: row.id, userId: uid, in: context))
        XCTAssertTrue(WeightLogWriter.entries(userId: uid, in: context).isEmpty)

        // The scale still holds the sample and the importer runs again.
        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: day, existingSource: nil, userId: uid
            ),
            .skip,
            "a day she cleared must not be re-created from Apple Health"
        )
    }

    func testClearingOneDayLeavesEveryOtherDayOpenToTheScale() {
        let uid = "deletion-scale-b"
        wipe(uid); defer { wipe(uid) }

        let cal = Calendar.current
        let today = Date()
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else {
            return XCTFail("calendar")
        }

        let row = WeightLogRecord(
            userId: uid, weightKg: 74.2, loggedAt: yesterday, source: "healthkit"
        )
        row.pendingUpsert = false
        context.insert(row)
        try? context.save()
        XCTAssertTrue(WeightLogWriter.remove(id: row.id, userId: uid, in: context))

        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: yesterday, existingSource: nil, userId: uid
            ),
            .skip
        )
        // The retraction is about ONE day. It is not a decision to stop
        // reading her scale.
        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: today, existingSource: nil, userId: uid
            ),
            .insert
        )
    }

    /// CONTROL — the rule that was already there and must not move:
    /// a row she typed always wins its day, and a healthkit row is the
    /// one the scale may update in place.
    func testManualStillWinsItsDayAndAHealthRowStillUpdates() {
        let uid = "deletion-scale-c"
        wipe(uid); defer { wipe(uid) }

        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: Date(), existingSource: "manual", userId: uid
            ),
            .skip
        )
        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: Date(), existingSource: "healthkit", userId: uid
            ),
            .update
        )
        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: Date(), existingSource: nil, userId: uid
            ),
            .insert
        )
    }

    /// The tombstone is HERS: it goes with the account, and it is not
    /// visible to the next person on this phone.
    func testAClearedDayIsScopedToTheAccountThatClearedIt() {
        let a = "deletion-scale-d-a"
        let b = "deletion-scale-d-b"
        wipe(a); wipe(b); defer { wipe(a); wipe(b) }

        let day = Date()
        let row = WeightLogRecord(
            userId: a, weightKg: 74.2, loggedAt: day, source: "healthkit"
        )
        row.pendingUpsert = false
        context.insert(row)
        try? context.save()
        XCTAssertTrue(WeightLogWriter.remove(id: row.id, userId: a, in: context))

        XCTAssertEqual(
            BodyMassImportService.importDecision(forDay: day, existingSource: nil, userId: a),
            .skip
        )
        XCTAssertEqual(
            BodyMassImportService.importDecision(forDay: day, existingSource: nil, userId: b),
            .insert,
            "account A's retraction says nothing about account B's scale"
        )
    }

    // MARK: - the stale device's push, as the hydrates actually write it
    //
    // `mergeRemote` (food) is public, so the food test above drives the
    // REAL hydrate. `applyHydratedWeightLogs`, `hydrateDoseEvents` and
    // `hydrateObservations` are internal to `PlankSync` and take a live
    // PostgREST client, so the three helpers below construct exactly
    // what those functions construct — the record, with
    // `pendingUpsert = false` because it came from the server. That is
    // the PRECONDITION of each test, never its assertion: what is being
    // asserted is the product's response to it.

    private func insertHydratedWeighIn(id: String, userId: String) {
        let record = WeightLogRecord(
            id: id, userId: userId, weightKg: 74.2, loggedAt: .now, source: "manual"
        )
        record.pendingUpsert = false
        context.insert(record)
        try? context.save()
    }

    private func insertHydratedDose(userId: String, dayKey: String) {
        let record = DoseEventRecord(
            id: DoseEventStore.deterministicId(userId: userId, dayKey: dayKey),
            userId: userId, regimenPlanId: "plan-1", dayKey: dayKey,
            scheduledAt: .now, status: "taken", takenAt: .now,
            site: nil, note: nil, skipReason: nil, source: "sheet"
        )
        record.pendingUpsert = false
        context.insert(record)
        try? context.save()
    }

    private func insertHydratedSymptom(id: String, userId: String, dayKey: String) {
        let record = ObservationRecord(
            id: id, userId: userId,
            kind: ObservationKind.symptom.rawValue, dayKey: dayKey,
            valueText: SideEffectSymptom.nausea.rawValue, valueNum: 1,
            unit: nil, source: "manual"
        )
        record.pendingUpsert = false
        context.insert(record)
        try? context.save()
    }
}
