import AppTrackingTransparency
import Foundation

// MARK: - ATTService
//
// The ONE source of truth for App Tracking Transparency (App Review
// 2.1 rejection, 2026-08-28, submission b7b6a6d4): the reviewer could
// not locate the ATT prompt on iOS 26.6.1 / iPadOS 26.6 while the app
// declares tracking and embeds the TikTok Business SDK. Two defects,
// one shape:
//
//   1. The only request lived at 30% of the plan-building loader —
//      reachable only by finishing the entire consult, only on the
//      .loss safety path, only on a true first run. Returning,
//      expired, restored and safety-parked users NEVER saw a request.
//   2. TikTok initialized unconditionally in PlankAIApp.init(), with
//      Install/Launch/Retention/Purchase auto-events on, before ATT
//      was ever resolved — tracking-capable collection ahead of the
//      prompt, the exact thing 5.1.2 forbids.
//
// The architecture now:
//
//   - The request fires at the FIRST SETTLED SURFACE of any launch
//     (onboarding arrival, proof, wall, migration, or main —
//     RootView's `.task(id:)` gate, every phase except .booting),
//     while the scene is active, after one fixed 0.6s settle beat so
//     the dialog never races the phase cross-fade.
//     Path-independent: no onboarding branch can skip it, and iPhone
//     and iPad share the identical code path.
//   - The loader's historical call remains as a secondary belt; it
//     routes through here and no-ops once the status is resolved.
//   - TikTok's initializeSdk is invoked by THIS service, only once
//     `trackingAuthorizationStatus != .notDetermined`. On every launch
//     after the user has answered (the common case) that is immediate
//     at configure() — behaviorally identical to the old init-time
//     bootstrap. On a fresh install it happens the moment the prompt
//     resolves. Denial does not gate any app feature; the SDK simply
//     initializes without an IDFA (SKAdNetwork support stays enabled —
//     SKAN does not require ATT).
//   - A request that resolves .notDetermined means iOS never presented
//     the dialog (app resigned active mid-flight — the documented
//     silent-failure mode). The once-per-launch flag resets so the
//     next scene activation retries; a REAL answer never returns
//     .notDetermined, so an answered prompt is never re-asked.

/// Seam over the system framework so the decision logic is testable
/// without the ATT runtime.
protocol ATTAuthorizing {
    var status: ATTrackingManager.AuthorizationStatus { get }
    func request() async -> ATTrackingManager.AuthorizationStatus
}

struct SystemATTAuthorizer: ATTAuthorizing {
    var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }
    func request() async -> ATTrackingManager.AuthorizationStatus {
        await ATTrackingManager.requestTrackingAuthorization()
    }
}

/// Pure decision core — no system dependencies, pinned by
/// ATTServiceTests. A value type on purpose (the iOS 26.2 sim aborts
/// on @MainActor class deinit; see reference_mainactor_class_deinit).
struct ATTFlow {
    enum RequestDecision: Equatable {
        /// Present the system dialog now.
        case request
        /// Status already resolved, or a request is already in flight /
        /// completed this launch — never re-prompt.
        case skip
    }

    private(set) var requestedThisLaunch = false
    private(set) var trackingSDKsStarted = false

    /// .notDetermined → request exactly once per launch; any resolved
    /// status → never prompt.
    mutating func decideRequest(
        status: ATTrackingManager.AuthorizationStatus
    ) -> RequestDecision {
        guard status == .notDetermined, !requestedThisLaunch else { return .skip }
        requestedThisLaunch = true
        return .request
    }

    /// A result of .notDetermined is iOS declining to PRESENT (the app
    /// wasn't active) — clear the flag so the next activation retries.
    /// Every real answer (.authorized/.denied/.restricted) keeps the
    /// flag, so a user who answered is never re-asked.
    mutating func noteRequestResult(
        _ status: ATTrackingManager.AuthorizationStatus
    ) {
        if status == .notDetermined { requestedThisLaunch = false }
    }

    /// Tracking-capable SDKs (TikTok) may start only after ATT is
    /// resolved, and only once per launch. Returns true exactly when
    /// the caller should perform the start.
    mutating func decideStartTrackingSDKs(
        status: ATTrackingManager.AuthorizationStatus
    ) -> Bool {
        guard status != .notDetermined, !trackingSDKsStarted else { return false }
        trackingSDKsStarted = true
        return true
    }
}

@MainActor
enum ATTService {
    private static var flow = ATTFlow()
    private static var startTrackingSDKs: (() -> Void)?
    static var authorizer: ATTAuthorizing = SystemATTAuthorizer()

    static var status: ATTrackingManager.AuthorizationStatus { authorizer.status }

    /// p61 — true while this launch still owes the system prompt.
    /// Home's auto-present director stands down on it so a designed
    /// cover never races the legal dialog for the same moment.
    static var promptIsPending: Bool {
        !isSuppressedForAutomation && authorizer.status == .notDetermined
    }

    /// DEBUG-only: QA walkers and the unit-test host must never meet a
    /// system dialog mid-run. Release builds compile the doors out, so
    /// this is always false for App Review and customers.
    static var isSuppressedForAutomation: Bool {
        #if DEBUG
        let p = ProcessInfo.processInfo
        if p.environment["XCTestConfigurationFilePath"] != nil { return true }
        if p.arguments.contains(where: {
            $0.hasPrefix("--uitest") || $0.hasPrefix("--debug")
                || $0.hasPrefix("--food-debug") || $0.hasPrefix("--onboarding")
        }) { return true }
        #endif
        return false
    }

    /// Called once from PlankAIApp.init(). When a previous launch
    /// already resolved ATT, the tracking SDKs start immediately (same
    /// timing as the old init-time bootstrap); otherwise they start
    /// when the prompt resolves.
    static func configure(startTrackingSDKs start: @escaping () -> Void) {
        startTrackingSDKs = start
        startTrackingSDKsIfResolved()
    }

    private static func startTrackingSDKsIfResolved() {
        guard flow.decideStartTrackingSDKs(status: authorizer.status) else { return }
        startTrackingSDKs?()
    }

    /// Present the system prompt iff status is .notDetermined; always
    /// follow up by starting tracking SDKs once resolved. `context`
    /// stamps the analytics events ("launch" vs "building_loader") so
    /// placements stay comparable on real data (F3 instrumentation).
    static func requestIfNeeded(context: String) async {
        guard !isSuppressedForAutomation else { return }
        guard flow.decideRequest(status: authorizer.status) == .request else {
            startTrackingSDKsIfResolved()
            return
        }
        V6Funnel.track("att_prompt_shown", once: true,
                       properties: ["context": context])
        let result = await authorizer.request()
        flow.noteRequestResult(result)
        if result != .notDetermined {
            V6Funnel.track("att_result", once: true, properties: [
                "context": context,
                "status": statusWord(result),
            ])
        }
        startTrackingSDKsIfResolved()
    }

    private static func statusWord(
        _ status: ATTrackingManager.AuthorizationStatus
    ) -> String {
        switch status {
        case .authorized:    return "authorized"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .notDetermined: return "not_determined"
        @unknown default:    return "unknown"
        }
    }
}
