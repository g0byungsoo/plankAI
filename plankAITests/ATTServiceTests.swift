import XCTest
import AppTrackingTransparency
@testable import plankAI

// MARK: - ATTServiceTests
//
// App Review 2.1 (2026-08-28, submission b7b6a6d4): the reviewer
// could not locate the ATT prompt while the app declares tracking and
// embeds the TikTok Business SDK. The fix is ATTService — one source
// of truth whose decision core (ATTFlow, a pure value type) is pinned
// here. The laws:
//
//   1. .notDetermined  → request, exactly once per launch.
//   2. .authorized / .denied / .restricted → never request.
//   3. Tracking-capable SDKs (TikTok) start only AFTER the status is
//      resolved, and only once.
//   4. A request result of .notDetermined means iOS declined to
//      PRESENT (app not active) — the flow may retry on the next
//      activation. A real ANSWER is never re-asked.
//
// The launch gate itself (RootView.attRequestGate) fires on every
// phase except .booting — deliberately wider than
// AppPhaseMachine.isStable, so a returning payer parked on the wall
// still meets the prompt. That gate is a one-line SwiftUI computed;
// the laws it feeds are what this file pins.

final class ATTServiceTests: XCTestCase {

    // MARK: 1. .notDetermined → request invoked exactly once

    func testNotDeterminedRequestsExactlyOnce() {
        var flow = ATTFlow()
        XCTAssertEqual(flow.decideRequest(status: .notDetermined), .request)
        // Second ask in the same launch — the dialog is in flight or
        // shown; never double-present.
        XCTAssertEqual(flow.decideRequest(status: .notDetermined), .skip)
        XCTAssertEqual(flow.decideRequest(status: .notDetermined), .skip)
    }

    // MARK: 2. Resolved statuses never prompt

    func testAuthorizedNeverRequests() {
        var flow = ATTFlow()
        XCTAssertEqual(flow.decideRequest(status: .authorized), .skip)
    }

    func testDeniedNeverRequests() {
        var flow = ATTFlow()
        XCTAssertEqual(flow.decideRequest(status: .denied), .skip)
    }

    func testRestrictedNeverRequests() {
        var flow = ATTFlow()
        XCTAssertEqual(flow.decideRequest(status: .restricted), .skip)
    }

    // MARK: 3. Tracking SDK start is gated on resolution

    func testTrackingSDKsNeverStartWhileNotDetermined() {
        var flow = ATTFlow()
        XCTAssertFalse(flow.decideStartTrackingSDKs(status: .notDetermined))
        XCTAssertFalse(flow.decideStartTrackingSDKs(status: .notDetermined))
        XCTAssertFalse(flow.trackingSDKsStarted)
    }

    func testTrackingSDKsStartOnceAfterResolution() {
        var flow = ATTFlow()
        // Pre-consent launch: no start.
        XCTAssertFalse(flow.decideStartTrackingSDKs(status: .notDetermined))
        // The prompt resolves (any answer) — start exactly once.
        XCTAssertTrue(flow.decideStartTrackingSDKs(status: .denied))
        XCTAssertFalse(flow.decideStartTrackingSDKs(status: .denied))
        XCTAssertFalse(flow.decideStartTrackingSDKs(status: .authorized))
    }

    func testReturningUserStartsTrackingWithoutAnyPrompt() {
        // The common launch: a previous run answered the prompt. SDKs
        // start immediately at configure-time and no request fires.
        var flow = ATTFlow()
        XCTAssertTrue(flow.decideStartTrackingSDKs(status: .authorized))
        XCTAssertEqual(flow.decideRequest(status: .authorized), .skip)
    }

    // MARK: 4. Failed presentation may retry; a real answer may not

    func testFailedPresentationAllowsRetry() {
        var flow = ATTFlow()
        XCTAssertEqual(flow.decideRequest(status: .notDetermined), .request)
        // iOS declined to present (app resigned active): result stays
        // .notDetermined → the next activation retries.
        flow.noteRequestResult(.notDetermined)
        XCTAssertEqual(flow.decideRequest(status: .notDetermined), .request)
    }

    func testRealAnswerIsNeverReAsked() {
        var flow = ATTFlow()
        XCTAssertEqual(flow.decideRequest(status: .notDetermined), .request)
        flow.noteRequestResult(.denied)
        // Even if a caller passes a stale .notDetermined snapshot, the
        // once-flag holds: the user answered.
        XCTAssertEqual(flow.decideRequest(status: .notDetermined), .skip)
        XCTAssertEqual(flow.decideRequest(status: .denied), .skip)
    }

    // MARK: End-to-end decision sequence against a mock authorizer
    //
    // Drives the same call shape ATTService uses, through the
    // ATTAuthorizing seam, proving the request happens at most once
    // and the SDK start strictly FOLLOWS resolution.

    private final class MockAuthorizer: ATTAuthorizing {
        var status: ATTrackingManager.AuthorizationStatus
        var answer: ATTrackingManager.AuthorizationStatus
        private(set) var requestCount = 0
        init(status: ATTrackingManager.AuthorizationStatus,
             answer: ATTrackingManager.AuthorizationStatus) {
            self.status = status
            self.answer = answer
        }
        func request() async -> ATTrackingManager.AuthorizationStatus {
            requestCount += 1
            status = answer
            return answer
        }
    }

    private func drive(
        _ flow: inout ATTFlow,
        authorizer: MockAuthorizer,
        starts: inout Int
    ) async {
        if flow.decideRequest(status: authorizer.status) == .request {
            let result = await authorizer.request()
            flow.noteRequestResult(result)
        }
        if flow.decideStartTrackingSDKs(status: authorizer.status) {
            starts += 1
        }
    }

    func testFreshInstallSequence_promptThenSDKStart() async {
        let authorizer = MockAuthorizer(status: .notDetermined, answer: .authorized)
        var flow = ATTFlow()
        var starts = 0

        // configure() at app init: status unresolved → no SDK start.
        XCTAssertFalse(flow.decideStartTrackingSDKs(status: authorizer.status))

        // Launch gate fires: prompt shown once, answered, SDKs start.
        await drive(&flow, authorizer: authorizer, starts: &starts)
        XCTAssertEqual(authorizer.requestCount, 1)
        XCTAssertEqual(starts, 1)

        // The building-loader secondary call later in onboarding:
        // no second prompt, no second start.
        await drive(&flow, authorizer: authorizer, starts: &starts)
        XCTAssertEqual(authorizer.requestCount, 1)
        XCTAssertEqual(starts, 1)
    }

    func testDenialSequence_appKeepsWorkingAndSDKStillInitializes() async {
        // Denial gates NOTHING in-app; the SDK still initializes
        // post-resolution (without an IDFA) so SKAN stays owned.
        let authorizer = MockAuthorizer(status: .notDetermined, answer: .denied)
        var flow = ATTFlow()
        var starts = 0
        await drive(&flow, authorizer: authorizer, starts: &starts)
        XCTAssertEqual(authorizer.requestCount, 1)
        XCTAssertEqual(starts, 1)
    }

    func testRestrictedDeviceSequence_noPromptSDKStarts() async {
        // MDM / Screen-Time-restricted device: never prompt, SDK may
        // still initialize (it simply gets no IDFA).
        let authorizer = MockAuthorizer(status: .restricted, answer: .restricted)
        var flow = ATTFlow()
        var starts = 0
        await drive(&flow, authorizer: authorizer, starts: &starts)
        XCTAssertEqual(authorizer.requestCount, 0)
        XCTAssertEqual(starts, 1)
    }
}
