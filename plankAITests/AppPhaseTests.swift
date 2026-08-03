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

// MARK: - V6FunnelTests (release pass, 2026-08-02)
//
// The canonical funnel's exactly-once + metadata contract: view
// reappearances must never inflate once-guarded events, and every
// event must carry the approved metadata block under an explicit
// onboarding_version.

private final class CapturingSink: AnalyticsSink {
    let lock = NSLock()
    private(set) var events: [(name: String, props: [String: Any])] = []
    func send(event: String, properties: [String: Any]) {
        lock.lock(); defer { lock.unlock() }
        events.append((event, properties))
    }
    func captured(_ name: String) -> [[String: Any]] {
        lock.lock(); defer { lock.unlock() }
        return events.filter { $0.name == name }.map { $0.props }
    }
}

final class V6FunnelTests: XCTestCase {

    private var sink: CapturingSink!

    override func setUp() {
        super.setUp()
        sink = CapturingSink()
        Analytics.addSink(sink)
        Analytics._resetForTests()
        V6Funnel._resetOnceGuardsForTests()
    }

    override func tearDown() {
        let captured = sink
        Analytics._removeSinksForTests { $0 as? CapturingSink === captured }
        V6Funnel._resetOnceGuardsForTests()
        super.tearDown()
    }

    /// Analytics dispatches on a private serial queue — flush by
    /// waiting until the sink observes the expected count (or fail).
    private func waitForCapture(of name: String, count: Int, timeout: TimeInterval = 2) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if sink.captured(name).count >= count { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    func testOnceGuardedEventFiresExactlyOnceAcrossReappearances() {
        // Simulate the wall presenting three times (downsell dismiss →
        // re-present → relaunch-in-session): the once guard must keep
        // the funnel at ONE paywall_viewed.
        V6Funnel.track("test_paywall_viewed", once: true)
        // The coalesce window would also absorb rapid repeats; space the
        // repeats out past it so ONLY the once-guard is under test.
        Thread.sleep(forTimeInterval: 0.6)
        V6Funnel.track("test_paywall_viewed", once: true)
        Thread.sleep(forTimeInterval: 0.6)
        V6Funnel.track("test_paywall_viewed", once: true)

        waitForCapture(of: "test_paywall_viewed", count: 1)
        XCTAssertEqual(sink.captured("test_paywall_viewed").count, 1,
                       "once-guarded funnel events must never inflate on reappearance")
    }

    func testRepeatableEventsAreNotOnceGuarded() {
        V6Funnel.track("test_plan_selected", properties: ["plan": "yearly"])
        Thread.sleep(forTimeInterval: 0.6)
        V6Funnel.track("test_plan_selected", properties: ["plan": "weekly"])

        waitForCapture(of: "test_plan_selected", count: 2)
        XCTAssertEqual(sink.captured("test_plan_selected").count, 2,
                       "action events (plan_selected, purchase_started…) stay repeatable")
    }

    func testMetadataBlockCarriesTheApprovedKeys() {
        V6Funnel.track("test_metadata_probe")
        waitForCapture(of: "test_metadata_probe", count: 1)

        guard let props = sink.captured("test_metadata_probe").first else {
            return XCTFail("event never reached the sink")
        }
        XCTAssertEqual(props["onboarding_version"] as? String, "v6")
        for key in ["cohort", "acquisition_source", "att_status",
                    "device_class", "locale"] {
            XCTAssertNotNil(props[key], "metadata block must carry \(key)")
        }
        // The approved block stays non-sensitive: no health values.
        XCTAssertNil(props["weight_kg"])
        XCTAssertNil(props["goal_weight_kg"])
    }

    func testCallSitePropertiesOverrideNothingSensitive() {
        V6Funnel.track("test_props_merge", properties: ["surface": "wall"])
        waitForCapture(of: "test_props_merge", count: 1)
        let props = sink.captured("test_props_merge").first
        XCTAssertEqual(props?["surface"] as? String, "wall")
        XCTAssertEqual(props?["onboarding_version"] as? String, "v6")
    }
}
