import XCTest
@testable import plankAI

// MARK: - EntitlementRecoveryTests
//
// Identity-recovery fix (2026-07-25). The silent syncPurchases
// decision is one pure function (EntitlementRecoveryDecision in
// PaymentService.swift); this table IS its specification. The rows
// encode the guard rails that keep the recovery from looping on
// genuinely-expired subscriptions or fighting an in-flight restore.

final class EntitlementRecoveryTests: XCTestCase {

    private func inputs(
        active: Bool = false,
        everEntitled: Bool = true,
        userID: String? = "uid-a",
        attempted: Set<String> = [],
        syncInFlight: Bool = false,
        restoreInFlight: Bool = false,
        trigger: EntitlementRecoveryDecision.Trigger = .passive
    ) -> EntitlementRecoveryDecision.Inputs {
        .init(
            hasActiveEntitlement: active,
            wasEverEntitled: everEntitled,
            appUserID: userID,
            attemptedUserIDs: attempted,
            isRecoverySyncInFlight: syncInFlight,
            isRestoreInFlight: restoreInFlight,
            trigger: trigger
        )
    }

    // MARK: the walled-payer signature

    /// No active entitlement + install was ever entitled = the exact
    /// signature of identity loss. The sync fires.
    func testFiresOnEntitlementLossSignature() {
        XCTAssertTrue(EntitlementRecoveryDecision.shouldAutoSync(inputs()))
    }

    /// An entitled customer needs no recovery.
    func testSkipsWhenEntitlementActive() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(active: true)))
    }

    /// A fresh install that never saw an entitlement is a prospect,
    /// not a walled payer — never post the receipt speculatively.
    func testSkipsWhenNeverEntitled() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(everEntitled: false)))
    }

    // MARK: identity guards

    func testSkipsWithoutAppUserID() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(userID: nil)))
    }

    func testSkipsWithEmptyAppUserID() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(userID: "")))
    }

    // MARK: once per launch per appUserID

    /// The expired-sub loop breaker: after one attempt for uid-a this
    /// launch, a still-empty stream emit must NOT retrigger.
    func testSkipsWhenAlreadyAttemptedForThisUser() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(attempted: ["uid-a"])))
    }

    /// A re-key mid-session (sign-in to a different account) gets its
    /// own attempt — the bound is per appUserID, not per launch.
    func testReKeyedIdentityGetsItsOwnAttempt() {
        XCTAssertTrue(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(userID: "uid-b", attempted: ["uid-a"])))
    }

    /// The full loop, as PaymentService drives it: decision fires,
    /// the userID is marked attempted BEFORE the async call, the
    /// sync's still-empty result re-enters the check and is refused.
    func testExpiredSubscriptionDoesNotLoop() {
        var attempted: Set<String> = []
        XCTAssertTrue(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(attempted: attempted)))
        attempted.insert("uid-a")
        // syncPurchases resolved; entitlements still empty; next emit:
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(attempted: attempted)))
    }

    // MARK: interactive sign-in trigger (2026-07-25 scope extension)

    /// The reinstalled-payer path: container wipe cleared
    /// wasEverEntitled, but she just signed in through a wall/paywall
    /// door — an explicit sign-in is strong evidence of a returning
    /// user, so the interactive trigger waives that one requirement.
    func testInteractiveSignInWaivesWasEverEntitled() {
        XCTAssertTrue(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(everEntitled: false, trigger: .interactiveSignIn)))
    }

    /// The waiver is ONLY for wasEverEntitled: an entitled customer
    /// still needs no recovery, sign-in or not.
    func testInteractiveSignInStillSkipsWhenEntitlementActive() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(active: true, everEntitled: false, trigger: .interactiveSignIn)))
    }

    /// The once-per-launch-per-uid loop guard binds the interactive
    /// trigger too — a sign-in cannot re-arm a sync that already ran
    /// for this uid.
    func testInteractiveSignInStillRespectsAttemptedSet() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(everEntitled: false, attempted: ["uid-a"],
                   trigger: .interactiveSignIn)))
    }

    func testInteractiveSignInStillRequiresAppUserID() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(everEntitled: false, userID: nil,
                   trigger: .interactiveSignIn)))
    }

    func testInteractiveSignInStillSkipsWhileInFlight() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(everEntitled: false, syncInFlight: true,
                   trigger: .interactiveSignIn)))
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(everEntitled: false, restoreInFlight: true,
                   trigger: .interactiveSignIn)))
    }

    // MARK: in-flight guards

    func testSkipsWhileRecoverySyncInFlight() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(syncInFlight: true)))
    }

    func testSkipsWhileManualRestoreInFlight() {
        XCTAssertFalse(EntitlementRecoveryDecision.shouldAutoSync(
            inputs(restoreInFlight: true)))
    }
}
