import FacebookCore
import Foundation
import RevenueCat
#if DEBUG
import AdSupport
import AppTrackingTransparency
#endif

// MARK: - MetaAttributionService
//
// The ONE owner of the Meta (Facebook) Business SDK, added 2026-08-29 so
// Meta ad campaigns can attribute installs and purchases.
//
// Shape deliberately mirrors ATTService and the TikTok bootstrap that
// already live beside it: a @MainActor enum (the iOS 26.2 sim aborts on
// @MainActor class deinit — reference_mainactor_class_deinit), idempotent
// entry points, and DEBUG-only automation suppression so no walker or
// XCTest host ever starts a tracking SDK mid-run.
//
// AUTOMATIC LOGGING IS OFF, BY TWO MECHANISMS, ON PURPOSE.
// RevenueCat forwards this app's purchases to Meta server-side. If the
// Meta SDK ALSO logged them from its own StoreKit observer, every
// purchase would be counted twice — inflating ROAS with no error and no
// failing test. Verified against the v18.1.1 source: the observer is
// started at FBSDKAppEvents.m:1001, gated on `isAutoLogAppEventsEnabled`.
//
//   1. Info.plist `FacebookAutoLogAppEventsEnabled = false` — read
//      during SDK initialization, so nothing is logged even before any
//      of our code runs.
//   2. `Settings.shared.isAutoLogAppEventsEnabled = false` set BEFORE
//      `ApplicationDelegate.shared.application(_:didFinishLaunching…)`
//      — RevenueCat's documented flag, and it persists to UserDefaults,
//      which outranks the Info.plist value in the SDK's own resolution
//      order (Settings+AutoLogAppEvents.swift).
//
// CAVEAT, from that same resolution order: a server-side value in
// `migratedAutoLogValues["auto_log_app_events_enabled"]` outranks BOTH
// client mechanisms. The definitive control is the Meta app dashboard —
// Settings › Platform › iOS › "Log In-App Events Automatically" › No.
//
// ATT: this service NEVER prompts. ATTService owns the one prompt (App
// Review 2.1, 2026-08-28) and this service is only told when that prompt
// has RESOLVED, so device identifiers are collected after the answer
// rather than before it. From FBSDK v17 on iOS 17+, the SDK reads
// `ATTrackingManager.trackingAuthorizationStatus` itself, so the
// deprecated `isAdvertiserTrackingEnabled` flag is deliberately not set.
// Denial gates nothing: the SDK simply runs without an IDFA, and
// `$fbAnonId` is still sent (it feeds the Conversions API path, which
// does not depend on IDFA).

@MainActor
enum MetaAttributionService {

    private static var sdkStarted = false
    private static var attResolved = false
    private static var identifiersSynced = false
    private static var activationLogged = false
    private static var waiterRunning = false

    /// DEBUG-only: same door as `ATTService.isSuppressedForAutomation`.
    /// Release builds compile it out, so App Review and customers always
    /// get the real initialization.
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

    // MARK: launch

    /// Called once from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
    /// Idempotent.
    static func start(
        application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        guard !sdkStarted, !isSuppressedForAutomation else { return }
        sdkStarted = true

        // Belt #2 — set before initialization so the SDK never observes
        // a true value, not even transiently.
        Settings.shared.isAutoLogAppEventsEnabled = false

        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )

        // ATT may already have resolved during PlankAIApp.init().
        logActivationIfReady()
        syncIdentifiersIfReady()

        #if DEBUG
        print("""
        [Meta] SDK initialized \
        appID=\(Settings.shared.appID ?? "nil") \
        autoLogAppEvents=\(Settings.shared.isAutoLogAppEventsEnabled) \
        advertiserIDCollection=\(Settings.shared.isAdvertiserIDCollectionEnabled) \
        skAdNetworkReport=\(Settings.shared.isSKAdNetworkReportEnabled)
        """)
        // The read above happens BEFORE the SDK's server configuration
        // lands, and `checkAutoLogAppEventsEnabled()` lets a server-side
        // `auto_log_app_events_enabled` outrank both client mechanisms.
        // Re-read once the config has had time to arrive, so "automatic
        // logging is off" is something we OBSERVE rather than assume.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            let live = Settings.shared.isAutoLogAppEventsEnabled
            print("[Meta] autoLogAppEvents after server config = \(live)"
                  + (live ? "  ⚠️ SERVER OVERRODE THE CLIENT FLAG — turn off"
                          + " Settings › Platform › iOS › \"Log In-App Events"
                          + " Automatically\" in the Meta app dashboard" : "  (off, as intended)"))
        }
        #endif
    }

    // MARK: ATT resolution

    /// Called by the existing ATTService resolution path (via the
    /// `startTrackingSDKs` callback in `PlankAIApp.init()`), i.e. the
    /// moment `trackingAuthorizationStatus != .notDetermined`. Never
    /// prompts, never re-prompts.
    static func noteATTResolved() {
        guard !isSuppressedForAutomation else { return }
        attResolved = true
        logActivationIfReady()
        syncIdentifiersIfReady()
    }

    /// Meta's install/activation signal, logged MANUALLY because
    /// automatic logging is off to stop RevenueCat and the Meta SDK
    /// both reporting the same purchase. This is RevenueCat's own
    /// documented pairing ("Keep install and usage events on-device")
    /// and Meta's ("if you have disabled automatic logging, but still
    /// want to log specific events, such as install or purchase
    /// events, manually implement logging for these events in your
    /// app").
    ///
    /// It does NOT re-enable purchase logging. The StoreKit observer is
    /// started at FBSDKAppEvents.m:1001 behind
    /// `isAutoLogAppEventsEnabled && implicitPurchaseLoggingEnabled`,
    /// and the first term stays false; activateApp reaches that same
    /// method via fetchServerConfiguration and short-circuits there.
    ///
    /// What it restores is `publishInstall` (MOBILE_APP_INSTALL, which
    /// is ungated) and `fb_mobile_activate_app` through the PUBLIC
    /// logEvent chain — and that chain is the only thing that feeds
    /// SKAdNetwork conversion values and the AEM reporter
    /// (FBSDKAppEvents.m:1219/1225/1232). Without it, SKAdNetwork
    /// postbacks carry conversion value 0 and AEM records nothing,
    /// which is most of Meta's attribution for ATT-denied users.
    ///
    /// Ordering: fired only once BOTH the SDK has initialized and ATT
    /// has resolved, whichever lands last — PlankAIApp.init() runs
    /// before didFinishLaunchingWithOptions, so on a launch where ATT
    /// was already answered the resolution arrives first. Never at
    /// launch-time before the prompt is answered: `publishInstall` is
    /// once-per-install (guarded by `lastAttributionPing`), so firing
    /// it while the status is still .notDetermined would burn that one
    /// shot with no consent decision recorded.
    private static func logActivationIfReady() {
        guard sdkStarted, attResolved, !activationLogged else { return }
        activationLogged = true
        AppEvents.shared.activateApp()
        #if DEBUG
        print("[Meta] activateApp() logged manually"
              + " (auto-log stays \(Settings.shared.isAutoLogAppEventsEnabled))")
        #endif
    }

    /// Collect the identifiers RevenueCat forwards to Meta.
    ///
    /// Ordering is the whole point: ATT must have been ANSWERED before
    /// `collectDeviceIdentifiers()` runs, or `$idfa` is empty. RevenueCat
    /// must also be configured — `Purchases.shared` traps before
    /// `configure`, and this app configures it lazily once Supabase auth
    /// hands over an appUserID, which is usually AFTER ATT resolves on a
    /// returning launch. So we wait for both, then run once.
    private static func syncIdentifiersIfReady() {
        // `sdkStarted` matters: PlankAIApp.init() runs BEFORE
        // AppDelegate.didFinishLaunchingWithOptions, so on any launch
        // where ATT was already answered, noteATTResolved() arrives
        // first. Reading AppEvents.shared.anonymousID before the SDK is
        // initialized would hand RevenueCat an empty $fbAnonId and fail
        // silently — exactly the class of bug this integration is most
        // exposed to. Whichever of the two conditions lands last calls
        // this method, so the order of arrival stops mattering.
        guard sdkStarted, attResolved, !identifiersSynced else { return }

        guard Purchases.isConfigured else {
            startWaitingForRevenueCat()
            return
        }
        identifiersSynced = true

        // 1. IDFA / IDFV / IP → RevenueCat subscriber attributes.
        Purchases.shared.attribution.collectDeviceIdentifiers()

        // 2. Meta's per-install anonymous id → $fbAnonId. Sent on EVERY
        //    resolved status, including denied: the Conversions API path
        //    uses it independently of the IDFA.
        let anonymousID = AppEvents.shared.anonymousID
        Purchases.shared.attribution.setFBAnonymousID(anonymousID)

        #if DEBUG
        logIdentifiers(anonymousID: anonymousID)
        #endif
    }

    /// Poll for RevenueCat configuration rather than reaching into
    /// PaymentService — this pass must not touch purchase logic. Bounded
    /// so a launch where auth never lands does not spin forever.
    private static func startWaitingForRevenueCat() {
        guard !waiterRunning else { return }
        waiterRunning = true
        Task { @MainActor in
            for _ in 0..<60 {  // ≈30s at 0.5s
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Purchases.isConfigured {
                    waiterRunning = false
                    syncIdentifiersIfReady()
                    return
                }
            }
            waiterRunning = false
            #if DEBUG
            print("[Meta] identifiers NOT synced — RevenueCat never configured this launch")
            #endif
        }
    }

    #if DEBUG
    /// Temporary instrumentation (step 6 of the Meta integration brief).
    /// DEBUG-only by construction, so the Release binary carries neither
    /// the log nor the AdSupport IDFA read.
    private static func logIdentifiers(anonymousID: String) {
        let status = ATTrackingManager.trackingAuthorizationStatus
        let statusWord: String
        switch status {
        case .authorized:    statusWord = "authorized"
        case .denied:        statusWord = "denied"
        case .restricted:    statusWord = "restricted"
        case .notDetermined: statusWord = "notDetermined"
        @unknown default:    statusWord = "unknown"
        }
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        let idfaIsZeroed = (idfa == "00000000-0000-0000-0000-000000000000")
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? "nil"

        print("""
        [Meta] identifiers synced to RevenueCat
          att            = \(statusWord)
          $idfa          = \(idfaIsZeroed ? "EMPTY (zeroed — expected unless authorized)" : idfa)
          $idfv          = \(idfv)
          $fbAnonId      = \(anonymousID.isEmpty ? "EMPTY ⚠️" : anonymousID)
          autoLogAppEvents = \(Settings.shared.isAutoLogAppEventsEnabled) (must be false)
        """)
    }
    #endif
}
