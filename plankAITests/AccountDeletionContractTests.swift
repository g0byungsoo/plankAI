import XCTest
import SwiftData
import AuthenticationServices
import Supabase
import PlankSync
import PlankFood
@testable import plankAI

// MARK: - AccountDeletionContractTests (v25 §39)
//
// ▎ WHEN A CUSTOMER DELETES HER JENI ACCOUNT, THE ACCOUNT ACTUALLY
// ▎ DISAPPEARS.
//
// `38` proved RECORD deletion on the phone she is holding. This file
// proves ACCOUNT deletion, and it exists because the production census
// found the promise broken in three places that no test could have
// caught, because none of them are reachable from a green suite:
//
//   1. Sign in with Apple mints a NEW uid, so everything she recorded
//      before signing in is left under an anonymous uid the deletion
//      RPC (scoped to auth.uid()) can never reach. 559 of 559 Apple
//      identities in production were created in the same instant as
//      their uid — max gap ZERO seconds — while 278 of 308 email
//      identities were attached to a uid that already existed. The
//      email path preserves; the Apple path replaces. The doc comment
//      on `signInWithApple` claims the opposite.
//   2. Account deletion is NOT idempotent. The server RPC and the
//      local purge are two steps with nothing between them, so a
//      crash, a lost response or a dropped connection leaves the
//      server empty and every local record on disk FOREVER, with no
//      marker anywhere that the purge was owed.
//   3. Sign in with Apple credentials are never revoked, and Jeni
//      holds no token that could revoke them — `authorizationCode`
//      has zero call sites in first-party code. Apple's TN3194
//      documents exactly what an app must do in that position, and
//      Jeni does none of it.
//
// Every test is a CUSTOMER PROMISE. The word "account" in these names
// means what she means by it: her data, on the server, on this phone,
// and her identity.
//
// WHAT IS DELIBERATELY NOT TESTED HERE, and why: that the server
// actually dropped the rows. That needs a live Postgres and a live
// auth session; a repository-local simulation asserting it would be
// the `Executed 0 tests` trap in different clothes. §39 answers it
// from the production catalog instead, and every boundary this file
// cannot cross is named in §39 §18.

@MainActor
final class AccountDeletionContractTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }

    override func setUp() {
        super.setUp()
        AppSync.installFoodDeletionSeam()
        AccountDeletionIntent.clear()
    }

    override func tearDown() {
        AccountDeletionIntent.clear()
        super.tearDown()
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
        try? context.delete(model: UserRecord.self,
                            where: #Predicate { $0.id == owner })
        try? context.save()
        FoodLogPersister.deleteAllEntries(userId: owner)
        DeletionLedger.clear(userId: owner)
        MoveManualStore.wipe()
    }

    /// One of every local family the customer authored, so "zero
    /// recoverable customer-owned data" is measured against a full
    /// account rather than a convenient one.
    private func seedEverything(for uid: String) {
        let weight = WeightLogRecord(
            id: "w-\(uid)", userId: uid, weightKg: 56.2, loggedAt: .now, source: "manual"
        )
        weight.pendingUpsert = false
        context.insert(weight)
        context.insert(UserRecord(id: uid, name: "her"))
        try? context.save()

        FoodLogPersister.mergeRemote([
            FoodLogPersister.SyncableEntry(
                id: "plate-\(uid)", userId: uid, loggedAt: .now,
                kcal: 500, protein: 30, carbs: 40, fat: 20, fiber: 6,
                sugar: 4, sodiumMg: 300, satFatG: 3,
                title: "a plate", source: "photo"
            )
        ])
        MoveManualStore.record(kind: .strength, minutes: 30, weightKg: 56.2)
        DeletionLedger.record(id: "some-deleted-row", userId: uid)
    }

    private func localFootprint(of uid: String) -> Int {
        let owner = uid
        let weights = (try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []
        let users = (try? context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == owner }))) ?? []
        let plates = FoodLogPersister.allEntries(userId: owner).count
        let moves = MoveManualStore.all().count
        let ledger = DeletionLedger.contains(id: "some-deleted-row", userId: owner) ? 1 : 0
        return weights.count + users.count + plates + moves + ledger
    }

    // MARK: - 1 · THE IDENTITY THAT MUST NOT SPLIT

    /// The whole orphan class exists because this returned
    /// `.signInAsAppleUser` for an anonymous session. Everything she
    /// recorded before tapping the button belongs to the uid she is
    /// holding, so the Apple identity must attach to THAT uid.
    func testSigningInWithAppleFromAnAnonymousSessionKeepsHerUserId() {
        XCTAssertEqual(
            AppleIdentityPolicy.strategy(hasSession: true, isAnonymous: true),
            .linkToCurrentUser,
            "an anonymous session must gain the Apple identity, not be replaced by one"
        )
    }

    /// A returning customer on a new phone has no anonymous work worth
    /// keeping and MUST reach her existing account. Linking would fail;
    /// signing in is correct.
    func testAReturningCustomerSigningInOnANewPhoneStillReachesHerAccount() {
        XCTAssertEqual(
            AppleIdentityPolicy.strategy(hasSession: false, isAnonymous: false),
            .signInAsAppleUser
        )
        XCTAssertEqual(
            AppleIdentityPolicy.strategy(hasSession: true, isAnonymous: false),
            .signInAsAppleUser,
            "a session that is already named must never try to link a second identity"
        )
    }

    /// THE SAFETY PROPERTY THAT LETS THIS SHIP. If linking cannot
    /// work for any reason at all — the Apple id already belongs to an
    /// account, the server is old, the SDK errors — the fallback is
    /// EXACTLY the call the product makes today, so the worst case is
    /// today's behaviour and never a customer who cannot sign in.
    func testWhenLinkingIsImpossibleSignInStillSucceedsTheOldWay() {
        let alreadyLinked = NSError(domain: "test", code: 422,
                                    userInfo: [NSLocalizedDescriptionKey: "identity_already_exists"])
        XCTAssertEqual(AppleIdentityPolicy.fallback(after: alreadyLinked), .signInAsAppleUser)

        let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        XCTAssertEqual(AppleIdentityPolicy.fallback(after: offline), .signInAsAppleUser,
                       "every link failure falls back; none of them may strand the sign-in")
    }

    // MARK: - 2 · THE DELETION THAT MUST FINISH

    /// The interrupted-purge hole. The server said yes, the app died
    /// before the local sweep, and today NOTHING records that the
    /// sweep is owed — so her weigh-ins, plates and workouts sit on
    /// disk and in every device backup after an account she was told
    /// was deleted.
    func testAServerDeletionThatWasInterruptedFinishesOnTheNextLaunch() {
        let uid = "uid-interrupted"
        wipe(uid); defer { wipe(uid) }
        seedEverything(for: uid)
        XCTAssertGreaterThan(localFootprint(of: uid), 0, "fixture must have something to lose")

        // The server half completed; the process died here.
        AccountDeletionIntent.begin(userId: uid)
        AccountDeletionIntent.markServerComplete(userId: uid)

        // Next launch.
        AppSync.finishInterruptedAccountDeletion(in: context)

        XCTAssertEqual(localFootprint(of: uid), 0,
                       "an account the server already deleted must leave nothing on this phone")
        XCTAssertNil(AccountDeletionIntent.pending(),
                     "and the marker must not survive the purge it asked for")
    }

    /// The direction that must NOT converge. If the server verdict is
    /// unknown, purging locally would destroy the only copy she can
    /// still reach while the server keeps its own. Deletion converges
    /// toward deletion, never toward data loss with the server intact.
    func testAnUnconfirmedDeletionNeverDestroysHerDataOnItsOwn() {
        // This test deliberately leaves the record STANDING, which is
        // the whole assertion — so it is also the one that must clean up
        // after itself. The shared test container is real: leaving two
        // rows here broke `ReattributionTests`' global row count, the
        // exact fixture-leak `36` recorded. Fixed here, never there.
        let uid = "uid-unconfirmed"
        wipe(uid); defer { wipe(uid) }
        seedEverything(for: uid)
        let before = localFootprint(of: uid)

        AccountDeletionIntent.begin(userId: uid)   // no server confirmation
        AppSync.finishInterruptedAccountDeletion(in: context)

        XCTAssertEqual(localFootprint(of: uid), before,
                       "an unconfirmed server delete must leave the device alone")
        XCTAssertNotNil(AccountDeletionIntent.pending(),
                        "and must stay on the books rather than being forgotten")
    }

    /// Tapping delete twice, and the trap underneath it: the second tap
    /// runs under a FRESH anonymous uid, so a naive retry deletes an
    /// empty account and reports success while the first account's rows
    /// are still on disk. The marker names whose purge is owed.
    func testDeletingTwiceFinishesTheFirstAccountNotTheSecond() {
        let first = "uid-first"
        let second = "uid-second-anon"
        wipe(first); wipe(second)
        defer { wipe(first); wipe(second) }
        seedEverything(for: first)
        context.insert(UserRecord(id: second, name: "someone else"))
        try? context.save()

        AccountDeletionIntent.begin(userId: first)
        AccountDeletionIntent.markServerComplete(userId: first)
        // She taps again while the app has already re-bootstrapped anon.
        AppSync.finishInterruptedAccountDeletion(in: context)

        XCTAssertEqual(localFootprint(of: first), 0)
        let survivors = (try? context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == second }))) ?? []
        XCTAssertEqual(survivors.count, 1,
                       "the purge is scoped to the account she deleted, never the one she is on")
        wipe(second)
    }

    /// The RPC returning "this user does not exist" is not a failure —
    /// it is the server saying the work is already done. Treating it as
    /// an error is what stranded the local purge.
    func testAnAccountTheServerSaysIsAlreadyGoneStillGetsPurgedLocally() {
        XCTAssertEqual(AccountDeletionVerdict.classify(nil), .serverComplete)

        let gone = AuthError.sessionMissing
        XCTAssertEqual(AccountDeletionVerdict.classify(gone), .serverComplete,
                       "a dead session on the delete call means the account is unreachable, not that it survived")

        let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        XCTAssertEqual(AccountDeletionVerdict.classify(offline), .retryable,
                       "a timeout says nothing about the server, so it must not claim completion")
    }

    /// The sheet may not say "account deleted." for a deletion that
    /// only half happened. It also may not trap her in a failure she
    /// cannot clear.
    func testTheScreenNeverClaimsADeletionItDidNotFinish() {
        XCTAssertTrue(AccountDeletionVerdict.serverComplete.isSafeToReportAsDeleted)
        XCTAssertFalse(AccountDeletionVerdict.retryable.isSafeToReportAsDeleted)
    }

    // MARK: - 3 · THE IDENTITY THAT MUST BE RELEASED

    /// TN3194: when Apple tells the app the credential was revoked, the
    /// app must delete the user's data and revert to an unauthenticated
    /// state. Jeni observed nothing at all.
    func testWhenAppleSaysTheCredentialIsRevokedJeniLetsGoOfTheAccount() {
        XCTAssertEqual(
            AppleRevocationPolicy.response(authMethod: .apple, state: .revoked),
            .revertToUnauthenticated
        )
        XCTAssertEqual(
            AppleRevocationPolicy.response(authMethod: .apple, state: .notFound),
            .revertToUnauthenticated,
            "an Apple id the system no longer knows is a revoked one"
        )
    }

    /// Every Apple customer who signed in before this build has no
    /// stored Apple user identifier, so the credential state cannot be
    /// read for any of them. A watcher that stayed silent without one
    /// would be a fix that helps nobody who currently has the problem.
    func testARevocationIsHonouredEvenWhenTheCredentialStateCannotBeRead() {
        XCTAssertEqual(
            AppleRevocationPolicy.response(authMethod: .apple, state: nil),
            .revertToUnauthenticated
        )
        XCTAssertEqual(
            AppleRevocationPolicy.response(authMethod: .email, state: nil),
            .ignore,
            "an unreadable state is still not a reason to sign out somebody with no apple credential"
        )
    }

    /// The control. A notification that arrives while the credential is
    /// still authorized, or for a customer who never used Apple, must
    /// not sign anybody out of anything.
    func testARevocationNoticeNeverSignsOutSomebodyItDoesNotConcern() {
        XCTAssertEqual(
            AppleRevocationPolicy.response(authMethod: .apple, state: .authorized),
            .ignore
        )
        XCTAssertEqual(
            AppleRevocationPolicy.response(authMethod: .email, state: .revoked),
            .ignore
        )
        XCTAssertEqual(
            AppleRevocationPolicy.response(authMethod: .anonymous, state: .revoked),
            .ignore
        )
    }

    /// Apple's documented fallback for an app holding no revocable
    /// token: delete the data, then direct the customer to revoke
    /// access herself. Jeni holds no token, so this sentence IS the
    /// compliance path, and it must appear for exactly the people it
    /// applies to.
    func testAnAppleCustomerIsToldTheOneStepJeniCannotDoForHer() {
        XCTAssertNotNil(DeleteAccountCopy.appleRevocationNote(for: .apple))
        XCTAssertNil(DeleteAccountCopy.appleRevocationNote(for: .email))
        XCTAssertNil(DeleteAccountCopy.appleRevocationNote(for: .anonymous))
        XCTAssertNil(DeleteAccountCopy.appleRevocationNote(for: .unknown))
    }

    /// The deletion screen is the last thing she reads before an
    /// irreversible act, so it may not carry a sentence the product
    /// cannot keep, and it may not break the voice law on the way.
    func testTheDeletionCopyStaysTrueAndStaysInVoice() {
        let apple = DeleteAccountCopy.appleRevocationNote(for: .apple) ?? ""
        XCTAssertFalse(apple.contains("—"), "em-dash between words is banned (voice law)")
        XCTAssertFalse(apple.contains("--"))
        XCTAssertFalse(apple.lowercased().contains(" ai "))
        XCTAssertEqual(apple, apple.lowercased(),
                       "settings copy is lowercase casual")
        for banned in ["revoked for you", "we revoked", "automatically revoked"] {
            XCTAssertFalse(apple.lowercased().contains(banned),
                           "must never claim a revocation Jeni cannot perform")
        }
    }

    // MARK: - 4 · WHAT THE ACCOUNT LEAVES BEHIND ON THIS PHONE

    /// The end-to-end promise, measured over one of every local family
    /// including the two `38` closed and the one it added.
    func testDeletingTheAccountLeavesNothingSheAuthoredOnThisDevice() {
        let uid = "uid-full-sweep"
        wipe(uid); defer { wipe(uid) }
        seedEverything(for: uid)
        XCTAssertGreaterThan(localFootprint(of: uid), 0)

        AppSync.clearLocalUserRecords(userId: uid, in: context)
        AppSync.shared.clearOnboardingUserDefaults()

        XCTAssertEqual(localFootprint(of: uid), 0)
    }

    /// Cross-account isolation of the new marker itself. A deletion
    /// intent is a fact about one account; it may never reach the next
    /// person on this phone.
    func testTheDeletionMarkerNeverOutlivesTheAccountItNamed() {
        let uid = "uid-marker"
        AccountDeletionIntent.begin(userId: uid)
        AccountDeletionIntent.markServerComplete(userId: uid)
        AccountDeletionIntent.finish()
        XCTAssertNil(AccountDeletionIntent.pending())

        AppSync.shared.clearOnboardingUserDefaults()
        XCTAssertNil(AccountDeletionIntent.pending())
    }
}
