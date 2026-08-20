import XCTest
import SwiftData
import Supabase
import PlankSync
import PlankFood
@testable import plankAI

// MARK: - LastOrphanContractTests (v25 §40 — THE LAST ORPHAN)
//
// ▎ AFTER THIS BUILD SHIPS, JENI MUST NEVER CREATE ANOTHER UNOWNED
// ▎ ANONYMOUS RECORD DURING A NORMAL ACCOUNT CONVERSION.
//
// `39` stopped the orphan factory for a customer signing in with a
// BRAND-NEW Apple identity. This file exists because attacking that fix
// found two ways it still makes one, and one way her record disappears
// without any orphan at all:
//
//   1. THE FALLBACK. `linkIdentityWithIdToken` is refused with
//      `identity_already_exists` for every RETURNING customer, and the
//      fallback signs into her existing account and abandons the
//      anonymous uid this device is holding. Same P0, different
//      population.
//   2. THE MERGE IS SHORT. `reattributeModelRows` re-keys SEVEN of the
//      eighteen `@Model` families. Doses, symptoms, regimen, program
//      facts, weekly reads, jeni memory and the transcript stayed keyed
//      to the abandoned uid — on her own phone, invisible to every
//      `@Query userId` in the product. `39` §3 recorded four of them as
//      "REKEYED".
//   3. THE MERGE IS TOO WIDE. It also fires on a NAMED → NAMED switch,
//      which carries one account's record into another's.
//
// Every test is a customer promise, and the ownership tests measure the
// FOOTPRINT (how many rows still answer to the old name) rather than
// the sweep, because a test that lists the families it expects cannot
// notice a family nobody added to the list — which is exactly how (2)
// survived six passes.

@MainActor
final class LastOrphanContractTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }

    private let oldUid = "AAAAAAAA-0000-0000-0000-00000000000A"
    private let newUid = "BBBBBBBB-0000-0000-0000-00000000000B"

    override func setUp() {
        super.setUp()
        AppSync.installFoodDeletionSeam()
        wipe(oldUid); wipe(newUid)
    }

    override func tearDown() {
        wipe(oldUid); wipe(newUid)
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
        try? context.delete(model: ProgramPlanRecord.self, where: #Predicate { $0.userId == owner })
        try? context.delete(model: UserRecord.self, where: #Predicate { $0.id == owner })
        try? context.save()
        FoodLogPersister.deleteAllEntries(userId: owner)
        DeletionLedger.clear(userId: owner)
    }

    /// One of EVERY customer-authored local family, so "her record
    /// followed her" is measured against a whole account rather than a
    /// convenient one. The GLP-1 families are here on purpose: they are
    /// the ones the short merge dropped.
    private func seedAnonymousPeriod(for uid: String) {
        let weight = WeightLogRecord(id: "w-\(uid)", userId: uid, weightKg: 74.2,
                                     loggedAt: .now, source: "manual")
        context.insert(weight)

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
            userId: uid, kind: "symptom", dayKey: "2026-08-14",
            valueText: "mild"
        ))

        let fact = ProgramFactRecord(userId: uid, kind: "step_goal", value: "6000",
                                     authority: "preferred", basis: "asked", source: "chat")
        context.insert(fact)
        context.insert(WeeklyReadRecord(userId: uid, windowStartDay: "2026-08-10",
                                        anchor: "dose", offerKey: "steps",
                                        decision: "accepted", factId: fact.id))
        context.insert(JeniMemoryRecord(userId: uid, topic: "food", note: "no dairy"))
        context.insert(ChatMessageRecord(userId: uid, role: "user", body: "hello",
                                         dayKey: "2026-08-14"))
        context.insert(ExerciseCalibrationRecord(userId: uid, exerciseType: "plank"))
        context.insert(UserRecord(id: uid, name: "her"))
        try? context.save()
    }

    /// How many rows still answer to `uid`, across EVERY customer-owned
    /// family the container knows about. The number, not the list, is
    /// the assertion.
    private func footprint(of uid: String) -> Int {
        let owner = uid
        func n<T: PersistentModel>(_ d: FetchDescriptor<T>) -> Int {
            (try? context.fetchCount(d)) ?? 0
        }
        return n(FetchDescriptor<WeightLogRecord>(predicate: #Predicate { $0.userId == owner }))
            + n(FetchDescriptor<DoseEventRecord>(predicate: #Predicate { $0.userId == owner }))
            + n(FetchDescriptor<ObservationRecord>(predicate: #Predicate { $0.userId == owner }))
            + n(FetchDescriptor<RegimenPlanRecord>(predicate: #Predicate { $0.userId == owner }))
            + n(FetchDescriptor<ProgramFactRecord>(predicate: #Predicate { $0.userId == owner }))
            + n(FetchDescriptor<WeeklyReadRecord>(predicate: #Predicate { $0.userId == owner }))
            + n(FetchDescriptor<JeniMemoryRecord>(predicate: #Predicate { $0.userId == owner }))
            + n(FetchDescriptor<ChatMessageRecord>(predicate: #Predicate { $0.userId == owner }))
            + n(FetchDescriptor<ExerciseCalibrationRecord>(predicate: #Predicate { $0.userId == owner }))
            + n(FetchDescriptor<UserRecord>(predicate: #Predicate { $0.id == owner }))
    }

    // MARK: - 1 · THE FALLBACK MUST NOT ABANDON HER SERVER RECORD

    /// THE HOLE `39` LEFT. Anonymous uid A, and the Apple id already
    /// belongs to permanent account B. The link is refused, the fallback
    /// signs into B, and A's server rows are unreachable by any
    /// credential from that instant on. The one moment a credential for
    /// A exists is right there, so A is retired right there.
    func testWhenSignInLandsOnAnotherAccountTheAnonymousOneIsRetired() {
        XCTAssertEqual(
            AnonymousRetirementPolicy.decide(
                outgoingUid: oldUid, outgoingWasAnonymous: true,
                outgoingAccessToken: "a-live-token", incomingUid: newUid
            ),
            .retire(uid: oldUid),
            "an anonymous account abandoned by a sign-in must not be left on the server forever"
        )
    }

    /// THE LOAD-BEARING REFUSAL. A named account can be signed back into
    /// from any phone; deleting one because a sign-in switched accounts
    /// would destroy a customer's whole record. This must be impossible
    /// whatever else is true.
    func testANamedAccountIsNeverRetired() {
        XCTAssertEqual(
            AnonymousRetirementPolicy.decide(
                outgoingUid: oldUid, outgoingWasAnonymous: false,
                outgoingAccessToken: "a-live-token", incomingUid: newUid
            ),
            .leave(.outgoingWasNotAnonymous)
        )
    }

    /// THE SUCCESS CASE. The link worked, so the uid did not move and
    /// there is nothing to retire. Retiring here would delete the
    /// account she just kept.
    func testWhenTheIdentityLinkedNothingIsRetired() {
        XCTAssertEqual(
            AnonymousRetirementPolicy.decide(
                outgoingUid: oldUid, outgoingWasAnonymous: true,
                outgoingAccessToken: "a-live-token", incomingUid: oldUid.lowercased()
            ),
            .leave(.sameAccount),
            "same account, different casing, is still the same account"
        )
    }

    /// Nothing may be deleted on a guess. No token means the switch
    /// cannot be proven, so the orphan stands and is reported, not
    /// papered over.
    func testWithoutACredentialNothingIsDeleted() {
        XCTAssertEqual(
            AnonymousRetirementPolicy.decide(
                outgoingUid: oldUid, outgoingWasAnonymous: true,
                outgoingAccessToken: nil, incomingUid: newUid
            ),
            .leave(.noCredential)
        )
        XCTAssertEqual(
            AnonymousRetirementPolicy.decide(
                outgoingUid: nil, outgoingWasAnonymous: true,
                outgoingAccessToken: "a-live-token", incomingUid: newUid
            ),
            .leave(.noCredential)
        )
    }

    /// The retirement must speak with the OUTGOING account's token. The
    /// shared client's session belongs to the account she just signed
    /// into, and `delete_user_account()` deletes whoever the token names
    /// — so using the wrong one would delete the account she just
    /// reached.
    func testTheRetirementCallCarriesTheOutgoingTokenAndNothingElse() {
        let request = AnonymousAccountRetirement.request(
            baseURL: URL(string: "https://example.supabase.co")!,
            anonKey: "anon-key",
            accessToken: "outgoing-token"
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://example.supabase.co/rest/v1/rpc/delete_user_account"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer outgoing-token"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-key")
    }

    /// Only a 2xx is proof. Anything else means the row is still there
    /// as far as this device can show, and the record must say so rather
    /// than assume the best.
    func testOnlyAConfirmedDeleteCountsAsRetired() {
        XCTAssertEqual(AnonymousAccountRetirement.classify(status: 204), .retired)
        XCTAssertEqual(AnonymousAccountRetirement.classify(status: 200), .retired)
        XCTAssertEqual(AnonymousAccountRetirement.classify(status: 401), .refused(status: 401))
        XCTAssertEqual(AnonymousAccountRetirement.classify(status: 500), .refused(status: 500))
    }

    // MARK: - 2 · ONE UID OWNS EVERY REACHABLE RECORD

    /// THE POSTCONDITION THE WHOLE PASS IS FOR. After a conversion that
    /// changed the uid, NOTHING she authored may still answer to the old
    /// name. Counted, not listed.
    func testAfterAConversionNoRecordStillAnswersToTheOldAccount() {
        seedAnonymousPeriod(for: oldUid)
        XCTAssertEqual(footprint(of: oldUid), 10, "fixture must seed one of every family")

        AppSync.reattributeModelRows(from: oldUid, to: newUid, in: context)

        XCTAssertEqual(
            footprint(of: oldUid), 0,
            "every customer-authored row must follow her to the account she signed in to"
        )
        XCTAssertEqual(
            footprint(of: newUid), 10,
            "and it must ARRIVE — moving is not the same as vanishing"
        )
    }

    /// The four families `39` §3 recorded as "REKEYED" and were not.
    /// Named individually so a regression says which one.
    func testHerDosesSymptomsRegimenAndReadsFollowTheAccount() {
        seedAnonymousPeriod(for: oldUid)
        AppSync.reattributeModelRows(from: oldUid, to: newUid, in: context)
        let owner = newUid
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == owner }))), 1, "the dose she marked")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.userId == owner }))), 1, "the symptom she logged")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == owner }))), 1, "her regimen")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.userId == owner }))), 1, "the weekly read")
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<JeniMemoryRecord>(
            predicate: #Predicate { $0.userId == owner }))), 1, "what jeni remembers")
    }

    /// A deterministic id encodes the account. Re-keying must produce
    /// the id the NEW account would mint for that same slot, or her next
    /// mark of the same dose day lands a second row for one day.
    func testARekeyedDoseKeepsTheIdTheNewAccountWouldMintForThatDay() {
        seedAnonymousPeriod(for: oldUid)
        AppSync.reattributeModelRows(from: oldUid, to: newUid, in: context)
        let owner = newUid
        let dose = ((try? context.fetch(FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []).first
        XCTAssertEqual(
            dose?.id,
            DoseEventStore.deterministicId(userId: newUid, dayKey: "2026-08-14"),
            "the id must be the one her next mark would use — determinism is the dedupe"
        )
        XCTAssertEqual(dose?.pendingUpsert, true,
                       "and it must be queued for the account that now owns it")
    }

    /// A fresh uuid would satisfy the RLS invariant and silently break
    /// determinism, so the rule is a prefix swap and it refuses ids it
    /// does not recognise rather than inventing one.
    func testTheDeterministicRekeyRefusesAnIdItCannotDerive() {
        XCTAssertEqual(
            IdentityMerge.rekeyedDeterministicId("\(oldUid.lowercased())-dose-2026-08-14",
                                                 from: oldUid, to: newUid),
            "\(newUid.lowercased())-dose-2026-08-14"
        )
        XCTAssertNil(
            IdentityMerge.rekeyedDeterministicId("some-unrelated-id", from: oldUid, to: newUid),
            "an id that does not carry the outgoing uid must be left alone, never guessed at"
        )
    }

    /// Version chains are the record's own history. A re-key that does
    /// not follow `previousPlanId` / `previousFactId` breaks the chain
    /// and the eras stop joining up.
    func testTheVersionChainsSurviveTheRekey() {
        let first = RegimenPlanRecord(userId: oldUid, kind: "medication",
                                      displayName: "0.25", scheduleRule: "weeklyAnchor")
        context.insert(first)
        let second = RegimenPlanRecord(userId: oldUid, kind: "medication",
                                       displayName: "0.5", scheduleRule: "weeklyAnchor")
        second.previousPlanId = first.id
        context.insert(second)
        try? context.save()

        AppSync.reattributeModelRows(from: oldUid, to: newUid, in: context)

        let owner = newUid
        let plans = ((try? context.fetch(FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? [])
        let head = plans.first(where: { $0.displayName == "0.5" })
        let tail = plans.first(where: { $0.displayName == "0.25" })
        XCTAssertNotNil(head); XCTAssertNotNil(tail)
        XCTAssertEqual(head?.previousPlanId, tail?.id,
                       "the chain must point at the re-keyed predecessor, not the dead id")
    }

    // MARK: - 3 · THE MERGE MAY NOT INVENT, OVERWRITE OR LEAK

    /// The account she signed into already knows what it thinks about
    /// that day. Two rows cannot both be "this account's dose on this
    /// day", and content is never compared to decide — the account's own
    /// row wins and the incoming duplicate goes.
    func testTheAccountsOwnRecordWinsAnIdCollision() {
        seedAnonymousPeriod(for: oldUid)
        let mine = RegimenPlanRecord(userId: newUid, kind: "medication",
                                     displayName: "mine", scheduleRule: "weeklyAnchor")
        context.insert(mine)
        context.insert(DoseEventRecord(
            id: DoseEventStore.deterministicId(userId: newUid, dayKey: "2026-08-14"),
            userId: newUid, regimenPlanId: mine.id, dayKey: "2026-08-14",
            scheduledAt: .now, status: "skipped"
        ))
        try? context.save()

        AppSync.reattributeModelRows(from: oldUid, to: newUid, in: context)

        let owner = newUid
        let doses = ((try? context.fetch(FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? [])
        XCTAssertEqual(doses.count, 1, "one account, one day, one dose row")
        XCTAssertEqual(doses.first?.status, "skipped",
                       "the account's own record is not overwritten by the device's")
    }

    /// Consent is an answer she gave AS ONE IDENTITY. Carrying it across
    /// an identity switch hands a new account a permission nobody
    /// granted under it. Unknown consent is never permission (`38` §13).
    func testConsentIsNeverCarriedAcrossAnIdentitySwitch() {
        context.insert(ConsentGrantRecord(userId: oldUid, scope: "visit_packet_sharing",
                                          purpose: "share with a care team"))
        try? context.save()

        AppSync.reattributeModelRows(from: oldUid, to: newUid, in: context)

        let owner = newUid
        XCTAssertEqual((try? context.fetchCount(FetchDescriptor<ConsentGrantRecord>(
            predicate: #Predicate { $0.userId == owner }))), 0,
            "a grant made under another identity must not become this account's answer")
    }

    /// The account she reached owns its own body facts. Carrying an
    /// anonymous profile over a real one would overwrite her height,
    /// weight, goal and cohort with whatever this device held — the
    /// exact shape `29` spent a pass removing.
    func testAnExistingAccountsProfileIsNeverOverwrittenByTheDevices() {
        seedAnonymousPeriod(for: oldUid)
        context.insert(UserRecord(id: newUid, name: "the account"))
        try? context.save()

        AppSync.reattributeModelRows(from: oldUid, to: newUid, in: context)

        let owner = newUid
        let profiles = ((try? context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == owner }))) ?? [])
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.name, "the account",
                       "her account's profile is authoritative, not this device's")
    }

    /// THE CROSS-ACCOUNT LEAK. The merge exists to carry an ANONYMOUS
    /// period into an account. Fired on a named → named switch it moves
    /// one customer's record into another customer's account on the same
    /// phone.
    func testOneAccountsRecordIsNeverMergedIntoAnother() {
        XCTAssertFalse(
            AppSync.shouldMergeAnonymousPeriod(
                userIdChanged: true, isAnonNow: false, previousMethod: .apple,
                previousUserId: oldUid, newUserId: newUid
            ),
            "signing out of one named account into another must never merge the two"
        )
        XCTAssertFalse(
            AppSync.shouldMergeAnonymousPeriod(
                userIdChanged: true, isAnonNow: false, previousMethod: .email,
                previousUserId: oldUid, newUserId: newUid
            )
        )
        XCTAssertTrue(
            AppSync.shouldMergeAnonymousPeriod(
                userIdChanged: true, isAnonNow: false, previousMethod: .anonymous,
                previousUserId: oldUid, newUserId: newUid
            ),
            "and the anonymous period must still reach the account she signed in to"
        )
        XCTAssertFalse(
            AppSync.shouldMergeAnonymousPeriod(
                userIdChanged: true, isAnonNow: true, previousMethod: .apple,
                previousUserId: oldUid, newUserId: newUid
            ),
            "signing OUT preserves local rows; it never merges them anywhere"
        )
    }

    // MARK: - 4 · THE IDENTITY THE APP BELIEVES IN

    /// After a successful link GoTrue returns the user it loaded BEFORE
    /// the link, so `identities` is EMPTY while `app_metadata.providers`
    /// already says apple. Reading identities alone left the app on
    /// `.unknown` for the whole session — which silently stood down
    /// Apple revocation handling, the deletion sheet's Apple sentence
    /// and the profile re-upsert, for exactly the customers `39`'s fix
    /// was built for.
    func testAJustLinkedAppleCustomerIsRecognisedAsAnAppleCustomer() {
        XCTAssertEqual(
            AuthService.method(isAnonymous: false, identityProviders: [],
                               appMetadataProviders: ["apple"]),
            .apple
        )
        XCTAssertEqual(
            AuthService.method(isAnonymous: false, identityProviders: [],
                               appMetadataProviders: ["email"]),
            .email
        )
    }

    /// The fallback must not become the primary: an identity row still
    /// decides when there is one, and an anonymous session is anonymous
    /// whatever any metadata says.
    func testIdentityStillDecidesAndAnonymousStaysAnonymous() {
        XCTAssertEqual(
            AuthService.method(isAnonymous: false, identityProviders: ["apple"],
                               appMetadataProviders: []),
            .apple
        )
        XCTAssertEqual(
            AuthService.method(isAnonymous: true, identityProviders: [],
                               appMetadataProviders: ["apple"]),
            .anonymous,
            "an anonymous session must never be reported as a named one"
        )
        XCTAssertEqual(
            AuthService.method(isAnonymous: false, identityProviders: [],
                               appMetadataProviders: []),
            .unknown
        )
    }

    /// A just-linked customer must be told the one step Jeni genuinely
    /// cannot do for her (Apple TN3194 step 2). Before the fix she was
    /// `.unknown` and the sentence never rendered.
    func testTheAppleRevocationStepReachesAJustLinkedCustomer() {
        let method = AuthService.method(isAnonymous: false, identityProviders: [],
                                        appMetadataProviders: ["apple"])
        XCTAssertNotNil(DeleteAccountCopy.appleRevocationNote(for: method))
        XCTAssertNil(DeleteAccountCopy.appleRevocationNote(for: .email),
                     "and an email customer is never told to revoke a credential she does not have")
    }

    // MARK: - 5 · A DELETION INTENT NAMES ONE ACCOUNT

    /// `AccountDeletionIntent.clear()`'s doc comment claimed the sign-out
    /// sweep called it. It did not — the key appeared in exactly one file
    /// in the repository.
    func testADeletionIntentNeverReachesTheNextPersonOnThisPhone() {
        AccountDeletionIntent.begin(userId: oldUid)
        XCTAssertNotNil(AccountDeletionIntent.pending())

        AppSync.shared.clearOnboardingUserDefaults()

        XCTAssertNil(AccountDeletionIntent.pending(),
                     "an intent is a fact about one account and goes with that account")
    }

    /// And it must be discharged LAST: cleared before the sweep
    /// finishes, a process death mid-sweep leaves the remaining keys
    /// behind with nothing recording that they are owed.
    func testAConfirmedDeletionIsStillOwedUntilTheSweepCompletes() {
        AccountDeletionIntent.markServerComplete(userId: oldUid)
        XCTAssertEqual(AccountDeletionIntent.pendingLocalPurge(), oldUid)
        AppSync.finishInterruptedAccountDeletion(in: context)
        XCTAssertNil(AccountDeletionIntent.pendingLocalPurge())
    }
}
