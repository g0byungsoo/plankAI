import XCTest
@testable import plankAI

// MARK: - AppPhaseTests
//
// App v2 (docs/app_v2/07_GATING.md QA matrix). The entire
// subscription wall is one pure function; this table IS the gate's
// specification. Every row here is a user state the shipping app
// must route correctly.

final class AppPhaseTests: XCTestCase {

    private func inputs(
        onboarded: Bool = true,
        authReady: Bool = true,
        entitlementReady: Bool = true,
        holdDone: Bool = true,
        pro: Bool = false,
        authTransition: Bool = false,
        everEntitled: Bool = false,
        v2Seen: Bool = false,
        footprint: Bool = false,
        lastStable: AppPhase? = nil
    ) -> AppPhaseMachine.Inputs {
        .init(
            hasCompletedOnboarding: onboarded,
            authReady: authReady,
            entitlementReady: entitlementReady,
            loaderHoldDone: holdDone,
            hasPro: pro,
            isInAuthTransition: authTransition,
            wasEverEntitled: everEntitled,
            appV2Seen: v2Seen,
            hasLegacyFootprint: footprint,
            lastStablePhase: lastStable
        )
    }

    // MARK: fresh install

    func testFreshInstallBootsThenOnboards() {
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(onboarded: false, authReady: false)),
            .booting
        )
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(onboarded: false, holdDone: false)),
            .booting
        )
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(onboarded: false)),
            .onboarding
        )
    }

    func testPreOnboardingIgnoresEntitlementReadiness() {
        // Entitlement is meaningless before an account exists — the
        // splash must not wait on it.
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(onboarded: false, entitlementReady: false)),
            .onboarding
        )
    }

    // MARK: the wall

    func testCompletedNeverPaidHitsFreshWall() {
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs()),
            .wall(.fresh)
        )
    }

    func testExpiredPayerHitsExpiredWall() {
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(everEntitled: true)),
            .wall(.expired)
        )
    }

    func testCompletedWaitsForFullBootSet() {
        XCTAssertEqual(AppPhaseMachine.derive(inputs(authReady: false)), .booting)
        XCTAssertEqual(AppPhaseMachine.derive(inputs(entitlementReady: false)), .booting)
        XCTAssertEqual(AppPhaseMachine.derive(inputs(holdDone: false)), .booting)
    }

    // MARK: entitled routing

    func testPaidNewUserGoesStraightToMain() {
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(pro: true)),
            .main
        )
    }

    func testPaidLegacyUserSeesMigrationOnce() {
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(pro: true, footprint: true)),
            .migration
        )
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(pro: true, v2Seen: true, footprint: true)),
            .main
        )
    }

    // MARK: auth-transition suppression

    func testAuthTransitionHoldsLastStablePhaseInsteadOfWall() {
        // Mid sign-in, RevenueCat's transient not-entitled emit must
        // not flash the wall over a paid session.
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(authTransition: true, lastStable: .main)),
            .main
        )
        // With nothing to hold, boot rather than leak content.
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(authTransition: true)),
            .booting
        )
        // A transition while actually entitled routes normally.
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(pro: true, authTransition: true)),
            .main
        )
    }

    func testWallIsNeverHeldAsStable() {
        // Holding a wall through sign-in would flash it over a paid
        // account; walls re-derive fresh every time.
        XCTAssertFalse(AppPhaseMachine.isStable(.wall(.fresh)))
        XCTAssertFalse(AppPhaseMachine.isStable(.booting))
        XCTAssertTrue(AppPhaseMachine.isStable(.main))
        XCTAssertTrue(AppPhaseMachine.isStable(.migration))
        XCTAssertTrue(AppPhaseMachine.isStable(.onboarding))
    }

    // MARK: mid-session expiry

    func testMidSessionExpiryLeavesMainForExpiredWall() {
        // Stream emits not-entitled while she's inside: next derive
        // is the wall, and content unmounts (route-level guarantee).
        XCTAssertEqual(
            AppPhaseMachine.derive(inputs(
                pro: false, everEntitled: true, lastStable: .main
            )),
            .wall(.expired)
        )
    }
}
