import SwiftUI
import SwiftData
import PlankFood
import PlankSync
import Auth  // MemberImportVisibility: User.id lives in Supabase's Auth submodule
import RevenueCat
import PostHog
import TikTokBusinessSDK
import os.log
import ActivityKit
import PhotosUI  // PhotosPicker for the handwritten preview harnesses

// MARK: - Orientation Control

/// Controls which orientations are allowed. Session sets this to .all,
/// everything else keeps .portrait.
class OrientationManager {
    static let shared = OrientationManager()
    var allowedOrientations: UIInterfaceOrientationMask = .portrait
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // App v2 — notification taps route through AppRouter (queued
        // until the entitled shell mounts; docs/app_v2/09).
        NotificationDelegate.shared.install()
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationManager.shared.allowedOrientations
    }

    /// Programmatic scene config — required because the pure SwiftUI App
    /// lifecycle doesn't reliably read scene-delegate class names from
    /// Info.plist alone. Returning a fully-constructed UISceneConfiguration
    /// here is the supported path for AirPlay external-display routing.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let role = connectingSceneSession.role
        #if DEBUG
        print("[AppDelegate] configurationForConnecting role=\(role.rawValue)")
        #endif
        if role == .windowExternalDisplayNonInteractive {
            let config = UISceneConfiguration(name: "External Display", sessionRole: role)
            config.delegateClass = ExternalDisplaySceneDelegate.self
            return config
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: role)
    }
}

@main
struct PlankAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
        // App v2 QA — force the migration phase on next derive by
        // clearing the v2 stamp IN-PROCESS (simctl spawn defaults
        // can't reliably reach the app sandbox's plist — cfprefsd
        // split-brain). Pair with --uitest-pro-access + an enrolled
        // store: xcrun simctl launch booted com.bk.plankAI \
        //   --uitest-pro-access --uitest-force-migration
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-migration") {
            UserDefaults.standard.removeObject(forKey: "appV2SeenAt")
            UserDefaults.standard.set(true, forKey: "programEraEnabled")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        // UI-test hook: one-shot reset instead of an NSArgumentDomain pin
        // ("-hasCompletedOnboarding NO"), which would override the app's
        // own write of `true` for the whole run and trap RootView in the
        // onboarding branch — the flow would loop instead of handing off
        // to the hard paywall.
        if ProcessInfo.processInfo.arguments.contains("--uitest-fresh-onboarding") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "ratingPrompt.postPlanReveal.shown")
            UserDefaults.standard.removeObject(forKey: "ratingPrompt.lastDate")
            UserDefaults.standard.removeObject(forKey: "onboardingReviewPromptShown")
            // v5 resume-safe store: sweep every persisted answer so the
            // walker always exercises a truly fresh flow (strikes,
            // branches, and receipts re-derive from blank state).
            let d = UserDefaults.standard
            for key in d.dictionaryRepresentation().keys
            where key.hasPrefix("onb_v5_") || key.hasPrefix("onb_v8_") {
                d.removeObject(forKey: key)
            }
            d.removeObject(forKey: "care_entitlement_active")
            for key in ["onboarding_glp1_status", "onboarding_glp1_phase",
                        "onboarding_glp1_stop_window", "onboarding_appetite_return",
                        "onboardingFoodRelationship", "onboardingEatingCadence",
                        "onboardingPriorWin", "onboardingCuisinePreference",
                        "onboarding_dietary", "onb_v4_movement_baseline",
                        "onboardingSleepHours", "onboardingStressLevel",
                        "onboarding_weight_trend", "onboarding_goal_direction",
                        "onboardingNsvPriority", "onboarding_medication_status",
                        "onboardingHormonalStage", "onboardingPriorAttempts",
                        "onb_fear_quickResults", "onb_fear_anotherDiet",
                        "onb_fear_priorAttempt", "onb_fear_offramp",
                        "onb_fear_regain", "medicalDisclaimerAckAtISO",
                        "onboardingPickedTier",
                        // Day-1 machinery: a stale promise/bucket from a
                        // prior QA run must not leak into a fresh walk
                        // (round-3 catch: promise 8am, nudge "afternoons").
                        "plankTime", "notificationsEnabled",
                        "day1PromiseAction", "day1PromiseAnchor",
                        "day1PromiseTimeISO"] {
                d.removeObject(forKey: key)
            }
        }
        // In-app QA hook: lands the walker on MainTabView as a
        // completed-onboarding user (pair with --uitest-pro-access for
        // the entitlement). Program flags reset so the run exercises
        // the onramp → setup → PlanView chain.
        // v9 P2 — the prefs half of --uitest-reset-body-scan runs
        // synchronously (the consent check fires the instant the QA
        // door presents the cover; the record purge follows in the
        // launch task).
        if ProcessInfo.processInfo.arguments.contains("--uitest-reset-body-scan") {
            for key in ["bodyScan.consentSeen", "bodyScan.renderMode",
                        "bodyScan.backupOn", "bodyScan.introSeenAt",
                        "bodyScan.coverOptIn", "bodyScan.landingFigure"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--uitest-inapp-qa") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "hasEnrolledInProgram")
            UserDefaults.standard.removeObject(forKey: "programEraEnabled")
            UserDefaults.standard.removeObject(forKey: "planFirstRunHintSeen")
            UserDefaults.standard.removeObject(forKey: "planChecksMigratedV1")
            // Keep-wall recovery flags reset so every QA run exercises
            // the full chain (downsell / smaller-step are once-per-
            // install and would otherwise be consumed by run 1).
            UserDefaults.standard.removeObject(forKey: "downsellShownOnce")
            UserDefaults.standard.removeObject(forKey: "smallerStepShownOnce")
            // v4: a prior run's re-signing must not silence this
            // run's (records + consent knobs are QA state too).
            // --uitest-keep-reviews opts out for multi-launch legs
            // that sign in launch 1 and read the signature in 2.
            if !ProcessInfo.processInfo.arguments.contains("--uitest-keep-reviews") {
                WeeklyReview._wipeForQA()
            }
        }
        // DEBUG QA hook: auto-presents the v2 CBT lesson reader at a
        // given (totalDays, programDay) so screenshots can capture the
        // new manifest-driven flow without navigating UI. Pair with
        // --uitest-inapp-qa --uitest-pro-access for a clean cold-start.
        // Example: --uitest-cbt-lesson 75 1
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "--uitest-cbt-lesson"),
           idx + 2 < args.count,
           let n = Int(args[idx + 1]),
           let d = Int(args[idx + 2]) {
            UserDefaults.standard.set(n, forKey: "uitest.cbt.totalDays")
            UserDefaults.standard.set(d, forKey: "uitest.cbt.day")
        } else {
            // The key persists across launches; without this reset a
            // single QA run haunts every later launch with the cover
            // (burned two verification sessions before the fix).
            UserDefaults.standard.set(0, forKey: "uitest.cbt.day")
        }
        // Same persistence rule for the downsell preview's dismissal.
        UserDefaults.standard.set(false, forKey: "uitest.downsell.dismissed")
        if let idx = args.firstIndex(of: "--uitest-cbt-page"),
           idx + 1 < args.count,
           let p = Int(args[idx + 1]) {
            UserDefaults.standard.set(p, forKey: "uitest.cbt.startPage")
        } else {
            UserDefaults.standard.set(0, forKey: "uitest.cbt.startPage")
        }
        // v1.1 (2026-06-14) — auto-presents the legacy
        // `JeniMethodRitualView` reader directly, so simctl screenshots
        // can capture the v1.1 archetype-B spread + practice embeds
        // without UI navigation. Pair with --uitest-inapp-qa for
        // clean cold-start. Example: --uitest-jeni-lesson 1 → opens
        // Day 1 spread. `--uitest-jeni-lesson 8` → Day 8 practice.
        if let idx = args.firstIndex(of: "--uitest-jeni-lesson"),
           idx + 1 < args.count,
           let day = Int(args[idx + 1]) {
            UserDefaults.standard.set(day, forKey: "uitest.jeni.day")
        } else {
            UserDefaults.standard.set(0, forKey: "uitest.jeni.day")
        }
        // Optional flag — auto-open the prompt sheet on appear so a
        // simctl screenshot can capture it without UI automation.
        UserDefaults.standard.set(
            args.contains("--uitest-cbt-open-prompt"),
            forKey: "uitest.cbt.openPrompt")
        #endif

        // PostHog must be set up *before* any Analytics.track call lands
        // — the wrapper queues to its own background queue, so a race
        // where an early track fires before sink registration would be
        // dropped. Initializing in App.init() (before any view body or
        // service init) keeps the funnel intact from the very first
        // event (onboarding_start / paywall_view).
        Self.bootstrapAnalytics()

        // TikTok Business SDK — deferred OFF the first-frame critical
        // path (loading-experience pass 2026-06-11): its SKAN + config
        // fetch was the largest single contributor to the blank-launch
        // gap, and nothing in-app reads it (PostHog owns the funnel;
        // TikTok's auto Launch event fires whenever it initializes).
        // Low priority so the render loop wins the first frames.
        Task.detached(priority: .background) {
            await MainActor.run { Self.bootstrapTikTok() }
        }

        // Ensure Application Support directory exists before SwiftData tries to create the store
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

        // Migrate any legacy `voicePreference == "sarah"` value to the
        // current "encouraging" key. Sarah was renamed to Jeni in the
        // rebrand; users who upgraded with an old preference set in
        // UserDefaults would otherwise hit the default-fallback branch
        // and lose their selection. Idempotent — no-op once normalized.
        if UserDefaults.standard.string(forKey: "voicePreference") == "sarah" {
            UserDefaults.standard.set("encouraging", forKey: "voicePreference")
        }

        // v3 dead-code rip (2026-06-10) — the `onboarding_v2_enabled`
        // force-true migration is no longer needed; v1 path was
        // removed from OnboardingView so the flag is unread. Leaving
        // the AppStorage key untouched in UserDefaults for legacy
        // installs — nothing consumes it now.

        // Register every .ttf file bundled with the app. INFOPLIST_KEY_UIAppFonts
        // as a space-separated string doesn't actually populate UIAppFonts in
        // the generated Info.plist (Xcode interprets the whole value as one
        // filename), so iOS never auto-loads the fonts. Programmatic
        // registration bypasses the Info.plist parsing entirely and survives
        // future font additions without re-touching project settings.
        Self.registerBundledFonts()

        // Eagerly decode the 442KB CBT lesson manifest on a background
        // queue so the first lesson reader open doesn't pay a synchronous
        // JSON decode stutter. The service memoizes the manifest, so this
        // populates the cache before any UI reads it.
        Task.detached(priority: .background) {
            _ = CBTCurriculumService.shared.manifest()
        }

        // Run the self-checks once at launch in DEBUG. Output is
        // silent on success; failures print with a clear prefix so
        // regressions surface in Xcode's console without needing a
        // separate test target. Detached + low priority so the work
        // doesn't block first-frame rendering.
        #if DEBUG
        Task.detached(priority: .background) {
            _ = WorkoutGeneratorSelfCheck.runAll()
            _ = StreakCalculatorSelfCheck.runAll()
            _ = WeightSelfCheck.runAll()
            _ = EngagementDayCalculatorSelfCheck.runAll()
        }
        #endif
    }

    /// Initialize PostHog and append a sink to `Analytics.sinks` so
    /// every existing `Analytics.track(...)` call flows to PostHog
    /// without any call-site change. Idempotent — guarded against a
    /// re-invocation (App.init can run more than once in SwiftUI
    /// previews / hot-reload). DEBUG-only console sink stays in
    /// place alongside PostHog so events are still visible in Xcode.
    private static func bootstrapAnalytics() {
        // Re-init guard. PostHogSDK has its own internal guard but
        // re-appending the sink would double-fire every event.
        guard !analyticsBootstrapped else { return }
        analyticsBootstrapped = true

        let config = PostHogConfig(
            projectToken: PostHogAppConfig.apiKey,
            host: PostHogAppConfig.host
        )
        config.captureApplicationLifecycleEvents = PostHogAppConfig.captureApplicationLifecycleEvents
        config.captureScreenViews = false  // we emit our own screen events
        #if DEBUG
        // DEBUG-only verification helpers:
        //   - debug: PostHog SDK logs every capture + flush to console
        //     so "[PostHog] queue capture …" lines appear alongside our
        //     "[ANALYTICS] …" lines — confirms the SDK actually received
        //     the event from the sink.
        //   - flushAt = 1: ship every event immediately instead of
        //     batching at the default of 20. PostHog "Live events"
        //     stream shows them in <5s instead of waiting for a batch
        //     fill or the 30s flush interval. Release builds keep the
        //     defaults for battery / network efficiency.
        config.debug = true
        config.flushAt = 1
        #endif
        // Crash autocapture → $exception events carry the stack/fingerprint
        // metadata PostHog's Error Tracking needs to group issues. Without
        // this the manual Analytics.trackException calls still fire but never
        // group into issues (they coexist; this adds Mach/POSIX/NSException
        // crash capture delivered on next launch).
        config.errorTrackingConfig.autoCapture = true
        PostHogSDK.shared.setup(config)

        // v6 release pass: routed through the queue-serialized door
        // (direct array mutation races the send iteration).
        Analytics.addSink(PostHogSink())

        // Wire PlankFood's FoodAnalytics closure-sink into the main app
        // analytics layer. PlankFood is a leaf SPM package and can't
        // import AnalyticsManager directly; this closure is the
        // boundary. Every food event flows through Analytics.track so
        // sink lists, super-properties, queue, and dedup all apply.
        FoodAnalytics.register { eventName, properties in
            Analytics.track(eventName, properties: properties)
            // W5-T5 — cancel the pending Day 3 first-log nudge the
            // moment the user's first log lands. Cheap event-name
            // check; runs on the analytics background queue.
            if eventName == "food_first_log_saved" {
                RetentionNotifications.cancelFirstLogNudge()
            }
        }

        // Wire PlankFood's FoodHealthKitWriter closure-sink. Each
        // successful FoodLogPersister.persist call invokes this
        // closure with (kcal, timestamp). The writer inspects the
        // user's AppStorage toggle + HK authorization status and
        // either saves to HealthKit's Dietary Energy or no-ops.
        // PlankFood stays leaf — no HK entitlement in the package.
        FoodHealthKitWriter.register { kcal, date in
            Task { @MainActor in
                HealthKitDietaryEnergyWriter.shared.write(kcal: kcal, at: date)
            }
        }

        // v1.0.7 Phase F — wire PlankFood's FoodScanActivity closure-
        // sink to the JenifitWidgets Live Activity. PhotoCaptureView
        // calls start at scan begin and end on completion/failure;
        // the closures here own the Activity instance (the opaque
        // handle PlankFood treats as Any?).
        FoodScanActivity.register(
            start: { displayName in
                guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
                let attrs = ScanActivityAttributes(displayName: displayName)
                let state = ScanActivityAttributes.ContentState(phase: .reading, startedAt: Date())
                do {
                    let activity = try Activity.request(
                        attributes: attrs,
                        content: .init(state: state, staleDate: nil)
                    )
                    return activity
                } catch {
                    #if DEBUG
                    print("[FoodScanActivity] start failed: \(error)")
                    #endif
                    return nil
                }
            },
            update: { handle, phaseString in
                guard let activity = handle as? Activity<ScanActivityAttributes> else { return }
                let phase = ScanActivityAttributes.ContentState.Phase(rawValue: phaseString) ?? .reading
                let state = ScanActivityAttributes.ContentState(phase: phase, startedAt: Date())
                Task {
                    await activity.update(.init(state: state, staleDate: nil))
                }
            },
            end: { handle in
                guard let activity = handle as? Activity<ScanActivityAttributes> else { return }
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        )

        #if DEBUG
        // Internal/test traffic separation. Two layers in PostHog:
        //
        //   1. Person identity. Stable distinct_id prefixed `dev-…` so
        //      every test device shows up as one Person profile per
        //      simulator/device instead of a fresh anonymous user
        //      each launch. PostHog → Persons → search "dev-" gives
        //      you exactly the test sessions.
        //
        //   2. Super-properties via `register`. PostHog attaches these
        //      to every subsequent event AND person profile. Pair
        //      with PostHog → Settings → "Internal & test accounts"
        //      filter (set: person property `is_test_user` equals
        //      true) so insights / funnels hide test traffic by
        //      default — toggleable per insight.
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        PostHogSDK.shared.identify("dev-\(vendorId)")
        PostHogSDK.shared.register([
            "environment":  "debug",
            "is_test_user": true,
            "device_model": UIDevice.current.model,
            "device_name":  UIDevice.current.name
        ])
        #else
        PostHogSDK.shared.register([
            "environment": "production"
        ])
        #endif
    }

    /// Initialize the TikTok Business SDK for app-install attribution
    /// from TikTok Ads Manager campaigns. Idempotent — guarded against
    /// re-invocation the same way PostHog is. Silent no-op when
    /// TikTokAppConfig still has placeholder values so the DEBUG
    /// pre-launch flow keeps working before secrets land.
    ///
    /// What this enables:
    /// - Install + Launch + 2DRetention + Purchase auto-tracking
    ///   (the optimization signals TikTok's CPI bidder reads).
    /// - SKAdNetwork postback chain owned by TikTok — no MMP in the
    ///   app currently (no Adjust/AppsFlyer/Branch), so leaving
    ///   SKAN ownership to the only SDK that handles it is correct.
    ///
    /// ATT (NSUserTrackingUsageDescription) is already prompted at
    /// loader 30% in BuildingPlanLoadingView via
    /// ATTrackingManager.requestTrackingAuthorization(). The TikTok
    /// SDK reads the same IDFA once granted — no second prompt needed.
    private static func bootstrapTikTok() {
        guard !tiktokBootstrapped else { return }
        guard let config = TikTokAppConfig.makeSdkConfig() else {
            #if DEBUG
            print("[TikTok] init skipped — TikTokAppConfig has placeholder values")
            #endif
            return
        }
        tiktokBootstrapped = true

        #if DEBUG
        // Marks every generated event as a test event in the
        // TikTok Events Manager "Test Events" tab. Strip before
        // shipping (the !DEBUG branch is the release path).
        config.enableDebugMode()
        config.setLogLevel(TikTokLogLevelVerbose)
        #endif

        TikTokBusiness.initializeSdk(config) { success, error in
            #if DEBUG
            if success {
                print("[TikTok] SDK initialized")
            } else {
                print("[TikTok] SDK init failed: \(error?.localizedDescription ?? "unknown")")
            }
            #endif
        }
    }

    /// v1.0.7 QA blocker 2: identify the current user in PostHog with
    /// their Supabase user_id. Wired post-bootstrap + on every auth
    /// change so anon→named upgrades unify in one PostHog Person.
    /// Without this, every Apple/email upgrade creates a brand-new
    /// distinct_id and the funnel splits cohorts on every signup.
    ///
    /// Called from `.onChange(of: auth.currentUser?.id)` and
    /// `.onChange(of: auth.authMethod)` so it fires both on the
    /// initial anon bootstrap and on signup-upgrade. Idempotent at
    /// the PostHog side — repeated identify with the same id is a
    /// no-op except for property merge.
    @MainActor
    static func identifyPostHogUser() {
        guard let uid = AuthService.shared.currentUser?.id.uuidString else { return }
        #if DEBUG
        // Keep the dev-{vendorId} alias so internal builds don't
        // pollute the production person graph.
        return
        #else
        PostHogSDK.shared.identify(uid, userProperties: [
            "auth_method": AuthService.shared.authMethod.rawValue
        ])
        #endif
    }
    nonisolated(unsafe) private static var analyticsBootstrapped_unused = false
    nonisolated(unsafe) private static var analyticsBootstrapped = false
    nonisolated(unsafe) private static var tiktokBootstrapped = false

    private static func registerBundledFonts() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else {
            return
        }
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                #if DEBUG
                print("[Fonts] Failed to register \(url.lastPathComponent): \(error.debugDescription)")
                #endif
            }
        }
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("userExperience") private var userExperience = ""
    @AppStorage("voicePreference") private var voicePreference = "encouraging"

    var body: some Scene {
        WindowGroup {
            // Wrap the window root in cream so the system window background
            // never bleeds through during the brief moment iOS spends
            // swapping snapshot → launch screen → real UI on cold launch
            // and on background→foreground returns. Combined with the
            // LaunchBackground colorset (Info.plist UILaunchScreen.UIColorName)
            // there is no grey/white flash at any transition point — the
            // user sees cream from the moment they tap the icon. The
            // ResumeBloom modifier layers a soft blur fade-in on top so
            // the foreground transition reads as a deliberate breath-in
            // rather than a hard cut.
            ZStack {
                Palette.bgPrimary.ignoresSafeArea()
                #if DEBUG
                DebugPreviewRoutes()
                #else
                RootView()
                    .modifier(ResumeBloom())
                #endif
            }
        }
        .modelContainer(for: [
            UserRecord.self,
            SessionLogRecord.self,
            DayProgressRecord.self,
            ExerciseRecord.self,
            ExerciseCalibrationRecord.self,
            SessionRatingRecord.self,
            WeightLogRecord.self,
            // v1.1 program pivot. Both @Models lightweight-migrate
            // on first launch; existing users get empty stores until
            // they opt in via the full-screen cover. Reads are
            // gated by ProgramService.activePlan != nil, so an
            // empty store is a clean "no program yet" state, never
            // a crash. Per docs/program_pivot_v1_1_plan_2026_06_09.md
            // §"Data model diff" — migration safety notes.
            ProgramPlanRecord.self,
            ProgramDayCheckRecord.self,
            // App v2 — jeni chat transcript (local-first; app-target
            // @Model, so the cross-package registration hang that
            // exiled the food models does not apply).
            ChatMessageRecord.self,
            // App v8 — the chart (typed observations) + regimen
            // plans. PlankSync-package models, same package as the
            // nine that have always registered cleanly (the
            // PlankFood cross-package hang never applied here).
            // Both lightweight-migrate; empty stores are clean
            // "nothing recorded yet" states.
            ObservationRecord.self,
            RegimenPlanRecord.self,
            BodyScanRecord.self,
            // App v8 S3 — the consent seam (explicit, scoped,
            // revocable; inactive by default).
            ConsentGrantRecord.self,
            // W3-T6 food rail SwiftData @Models removed from the
            // container 2026-06-04 — caused the app to hang on launch
            // (black/white screen, main thread blocked, persists across
            // delete+reinstall). Suspect cross-package @Model
            // registration on iOS 17. v1.0.8 ships a proper SwiftData
            // integration; v1.0.7 persists food logs via the in-memory
            // stop-gap inside FoodLogPersister.
        ])
    }
}

// MARK: - ResumeBloom
//
// Soft blur fade-in on background→foreground transitions. The system
// already cross-fades from snapshot → launch screen → real UI; this
// modifier layers a 0.4s easeOut blur dissolve on top so the moment the
// user is back in JeniFit reads as a deliberate breath-in rather than a
// hard cut. The Calm / Headspace / Apple Fitness pattern adapted for the
// scrapbook register.
//
// Cold-launch behavior: scenePhase starts at .active, so the first
// .onChange fires when going .active → .background → .active. The cold
// launch itself doesn't trigger a bloom (the HomeView's own animateIn
// owns that beat); only resumes from background do.
//
// Reduce-motion: snaps with no bloom (the cream backdrop + launch screen
// still kill the grey flash; only the polish is dropped).
struct ResumeBloom: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blur: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var wasBackgrounded = false

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .opacity(opacity)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    wasBackgrounded = true
                case .active where wasBackgrounded:
                    wasBackgrounded = false
                    guard !reduceMotion else { return }
                    // Set the bloom-from state THIS frame, then resolve
                    // next runloop so the blur actually renders before
                    // it animates away — same trick TabBloom uses.
                    blur = 6
                    opacity = 0.92
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.4)) {
                            blur = 0
                            opacity = 1
                        }
                    }
                default:
                    break
                }
            }
    }
}

#if DEBUG
struct SleepCardPreviewHarness: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                header

                section(label: "1. populated · 7h 41m asleep, deep") {
                    LastNightSleepCard(
                        sleep: .sample(),
                        authStatus: .authorized
                    )
                }

                section(label: "2. populated · 4h 36m asleep, light night") {
                    LastNightSleepCard(
                        sleep: .lightNightSample(),
                        authStatus: .authorized
                    )
                }

                section(label: "3. notDetermined · connect prompt") {
                    LastNightSleepCard(sleep: nil, authStatus: .notDetermined)
                }

                section(label: "4. denied · recovery prompt") {
                    LastNightSleepCard(sleep: nil, authStatus: .denied)
                }

                section(label: "5. authorized · no data yet") {
                    LastNightSleepCard(sleep: nil, authStatus: .authorized)
                }

                Spacer(minLength: 48)
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("last night sleep card")
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(Palette.textPrimary)
            Text("--debug-sleep-preview · sprint A 2026-06-15")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func section<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
                .textCase(.lowercase)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension LastNightSleep {
    /// Cheap debug scaler — keeps the realistic stage architecture
    /// but compresses or stretches to a target asleep duration so the
    /// preview can show different durations without rewriting stages.
    func scaledForDebug(asleepHours: Double, inBedHours: Double) -> LastNightSleep {
        let asleepFactor = (asleepHours * 3600) / max(asleepDuration, 1)
        let inBedFactor  = (inBedHours * 3600) / max(inBedDuration, 1)
        let scaledStages: [LastNightSleep.Stage] = stages.map { s in
            let asleepKinds: Set<LastNightSleep.Stage.Kind> = [.asleepCore, .asleepDeep, .asleepREM, .asleep]
            let factor = asleepKinds.contains(s.kind) ? asleepFactor : inBedFactor
            return LastNightSleep.Stage(
                kind: s.kind,
                startOffset: s.startOffset * factor,
                duration: s.duration * factor
            )
        }
        let inBed = inBedHours * 3600
        let asleep = asleepHours * 3600
        return LastNightSleep(
            bedtime: bedtime,
            wakeTime: bedtime.addingTimeInterval(inBed),
            asleepDuration: asleep,
            inBedDuration: inBed,
            stages: scaledStages
        )
    }
}

struct SleepCardEmptyStatesHarness: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("sleep card · empty states")
                        .font(.custom("Fraunces72pt-SemiBold", size: 24))
                        .foregroundStyle(Palette.textPrimary)
                    Text("--debug-sleep-preview-empty")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                labeled("notDetermined") {
                    LastNightSleepCard(sleep: nil, authStatus: .notDetermined)
                }
                labeled("denied") {
                    LastNightSleepCard(sleep: nil, authStatus: .denied)
                }
                labeled("authorized, no data tonight") {
                    LastNightSleepCard(sleep: nil, authStatus: .authorized)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)
            .padding(.bottom, 48)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
                .textCase(.lowercase)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// v1.0.12 (2026-06-17) — shared helper for harnesses: render any
/// SwiftUI view to a 1080×1920 UIImage and save it to the user's
/// Photos library via ShareImageSaver. Used by the daily / weekly /
/// snap preview harnesses so the founder can verify the save path
/// without running the full food-log timeline flow.
@MainActor
private func saveCardToPhotos<V: View>(_ view: V) async -> ShareImageSaver.SaveResult {
    let renderer = ImageRenderer(
        content: view
            .frame(width: 1080, height: 1920)
    )
    renderer.scale = 1
    guard let img = renderer.uiImage else { return .failed }
    return await ShareImageSaver.save(img)
}

/// v1.0.10 (2026-06-17) — full-screen preview of the Pinterest
/// handwritten share card with mock food entries. Renders the card
/// at its native 1080×1920 then scales-to-fit the device screen so
/// the founder can compare against the editorial daily card without
/// going through the food-journal share flow. Launch with
/// `--debug-handwritten-share`; tap a corner to swap archetype.
struct HandwrittenSharePreviewHarness: View {

    @State private var archetype: String = "protein"
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var pickedPhotos: [UIImage] = []
    @State private var saveToast: ShareImageSaver.SaveResult? = nil
    @State private var isSaving: Bool = false

    private let archetypes = ["protein", "balanced", "movement", "rest"]

    var body: some View {
        GeometryReader { geo in
            let scale = min(
                geo.size.width / 1080,
                geo.size.height / 1920
            )
            ZStack {
                Color.black.ignoresSafeArea()

                HandwrittenDailyShareCard.preview(
                    archetype: archetype,
                    photos: pickedPhotos
                )
                .frame(width: 1080, height: 1920)
                .scaleEffect(scale, anchor: UnitPoint.center)
                .frame(width: geo.size.width, height: geo.size.height)

                overlayControls

                if let saveToast {
                    VStack {
                        Spacer()
                        SaveToPhotosToast(result: saveToast)
                            .padding(.bottom, 80)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .task(id: pickedItems) {
            var loaded: [UIImage] = []
            for item in pickedItems.prefix(8) {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    loaded.append(img)
                }
            }
            pickedPhotos = loaded
        }
        .onChange(of: saveToast) { _, newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                await MainActor.run { saveToast = nil }
            }
        }
    }

    @ViewBuilder private var overlayControls: some View {
        VStack {
            HStack {
                PhotosPicker(
                    selection: $pickedItems,
                    maxSelectionCount: 8,
                    matching: .images
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 12, weight: .medium))
                        Text("pick up to 8 photos")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                }
                Spacer()
                Button {
                    guard !isSaving else { return }
                    isSaving = true
                    Task {
                        let card = HandwrittenDailyShareCard.preview(
                            archetype: archetype,
                            photos: pickedPhotos
                        )
                        let result = await saveCardToPhotos(card)
                        await MainActor.run {
                            saveToast = result
                            isSaving = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSaving ? "arrow.down.circle" : "arrow.down.to.line")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isSaving ? "saving" : "save")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                if !pickedPhotos.isEmpty {
                    Button {
                        pickedPhotos = []
                        pickedItems = []
                    } label: {
                        Text("reset")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()
        }
    }
}

struct HandwrittenWeeklyPreviewHarness: View {
    @State private var archetype: String = "protein"
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var pickedPhotos: [UIImage] = []
    @State private var saveToast: ShareImageSaver.SaveResult? = nil
    @State private var isSaving: Bool = false
    private let archetypes = ["protein", "balanced", "movement", "rest"]

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 1080, geo.size.height / 1920)
            ZStack {
                Color.black.ignoresSafeArea()
                HandwrittenWeeklyShareCard.preview(
                    archetype: archetype,
                    photos: pickedPhotos
                )
                .frame(width: 1080, height: 1920)
                .scaleEffect(scale, anchor: UnitPoint.center)
                .frame(width: geo.size.width, height: geo.size.height)
                overlayControls
                if let saveToast {
                    VStack {
                        Spacer()
                        SaveToPhotosToast(result: saveToast)
                            .padding(.bottom, 80)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .task(id: pickedItems) {
            var loaded: [UIImage] = []
            for item in pickedItems.prefix(10) {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    loaded.append(img)
                }
            }
            pickedPhotos = loaded
        }
        .onChange(of: saveToast) { _, newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                await MainActor.run { saveToast = nil }
            }
        }
    }

    @ViewBuilder private var overlayControls: some View {
        VStack {
            HStack {
                PhotosPicker(
                    selection: $pickedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 12, weight: .medium))
                        Text("pick up to 10 photos")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                }
                Spacer()
                Button {
                    guard !isSaving else { return }
                    isSaving = true
                    Task {
                        let card = HandwrittenWeeklyShareCard.preview(
                            archetype: archetype,
                            photos: pickedPhotos
                        )
                        let result = await saveCardToPhotos(card)
                        await MainActor.run {
                            saveToast = result
                            isSaving = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSaving ? "arrow.down.circle" : "arrow.down.to.line")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isSaving ? "saving" : "save")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                if !pickedPhotos.isEmpty {
                    Button {
                        pickedPhotos = []
                        pickedItems = []
                    } label: {
                        Text("reset")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()
        }
    }
}

struct HandwrittenSnapPreviewHarness: View {
    @State private var archetype: String = "protein"
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedPhoto: UIImage?
    @State private var saveToast: ShareImageSaver.SaveResult? = nil
    @State private var isSaving: Bool = false
    private let archetypes = ["protein", "balanced", "movement", "rest"]

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 1080, geo.size.height / 1920)
            ZStack {
                Color.black.ignoresSafeArea()
                cardView
                    .frame(width: 1080, height: 1920)
                    .scaleEffect(scale, anchor: UnitPoint.center)
                    .frame(width: geo.size.width, height: geo.size.height)
                overlayControls
                if let saveToast {
                    VStack {
                        Spacer()
                        SaveToPhotosToast(result: saveToast)
                            .padding(.bottom, 80)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .task(id: pickedItem) {
            guard let item = pickedItem,
                  let data = try? await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data) else { return }
            pickedPhoto = img
        }
        .onChange(of: saveToast) { _, newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                await MainActor.run { saveToast = nil }
            }
        }
    }

    /// Real photo from Photos library when picked; falls back to the
    /// preview placeholder when the founder hasn't chosen one yet.
    @ViewBuilder private var cardView: some View {
        if let pickedPhoto {
            HandwrittenSnapResultShareCard(
                photo: pickedPhoto,
                mealLabel: "Breakfast",
                dishName: "your meal",
                itemNames: ["scrambled eggs", "avocado toast", "raspberries", "matcha latte"],
                totals: (carbs: 42, protein: 28, fat: 22, fiber: 7, kcal: 420),
                archetype: archetype
            )
        } else {
            HandwrittenSnapResultShareCard.preview(archetype: archetype)
        }
    }

    @ViewBuilder private var overlayControls: some View {
        VStack {
            HStack {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 12, weight: .medium))
                        Text("pick photo")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                }
                Spacer()
                Button {
                    guard !isSaving else { return }
                    isSaving = true
                    let arch = archetype
                    let pic = pickedPhoto
                    Task {
                        let view: AnyView
                        if let pic {
                            view = AnyView(
                                HandwrittenSnapResultShareCard(
                                    photo: pic,
                                    mealLabel: "Breakfast",
                                    dishName: "your meal",
                                    itemNames: ["scrambled eggs", "avocado toast", "raspberries", "matcha latte"],
                                    totals: (carbs: 42, protein: 28, fat: 22, fiber: 7, kcal: 420),
                                    archetype: arch
                                )
                            )
                        } else {
                            view = AnyView(HandwrittenSnapResultShareCard.preview(archetype: arch))
                        }
                        let result = await saveCardToPhotos(view)
                        await MainActor.run {
                            saveToast = result
                            isSaving = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSaving ? "arrow.down.circle" : "arrow.down.to.line")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isSaving ? "saving" : "save")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                if pickedPhoto != nil {
                    Button {
                        pickedPhoto = nil
                        pickedItem = nil
                    } label: {
                        Text("reset")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()
        }
    }
}


/// v1.0.11 (2026-06-17) — lesson share is no longer handwritten per
/// founder direction. Harness flag name kept for muscle memory but
/// mounts the rebuilt magazine-register LessonQuoteCard (JeniHeroSerif
/// italic on warm off-white, no card chrome, no stickers).
struct HandwrittenLessonPreviewHarness: View {
    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 1080, geo.size.height / 1920)
            ZStack {
                Color.black.ignoresSafeArea()
                LessonQuoteCard(
                    headline: "the voice in your head was taught",
                    italicWords: ["taught"],
                    bodyLine: "you're seven, maybe nine. someone at the table says she's being good today. someone else laughs about being bad later. you didn't decide to absorb any of this.",
                    dayLabel: "day one",
                    pillarTitle: "voice + food noise"
                )
                .frame(width: 1080, height: 1920)
                .scaleEffect(scale, anchor: UnitPoint.center)
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

/// v1.0.18 (2026-06-18) — debug harness for the new 3-slide result
/// carousel. Mounts NutritionCarousel with a mock CapturedFood +
/// rose-gradient placeholder photo so the founder can review the
/// new slides without going through the camera + paywall.
struct ResultCarouselPreviewHarness: View {
    /// `--carousel-page=N` (0 plate · 1 note · 2 share) jumps straight
    /// to a slide for screenshot capture, same arg the v1.1.2 carousel
    /// harness used.
    @State private var selectedPage: Int = {
        if let arg = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("--carousel-page=")
        }), let n = Int(arg.dropFirst("--carousel-page=".count)),
            (0..<3).contains(n) {
            return n
        }
        return 0
    }()

    private static let mockItems: [CapturedItem] = [
        CapturedItem(
            id: "preview-1", name: "scrambled eggs",
            portionGrams: 120, portionGramsLow: 100, portionGramsHigh: 140,
            usdaSearchTerms: ["scrambled eggs"],
            preparation: "pan", cuisineHint: "american",
            confidence: 0.92, notes: "",
            kcal: 180, proteinG: 10, carbsG: 2, fatG: 12, fiberG: 0,
            nutritionSource: .llmDirect,
            sugarG: 1, sodiumMg: 240, saturatedFatG: 4
        ),
        CapturedItem(
            id: "preview-2", name: "avocado toast",
            portionGrams: 140, portionGramsLow: 120, portionGramsHigh: 160,
            usdaSearchTerms: ["avocado toast"],
            preparation: "toasted", cuisineHint: "cafe",
            confidence: 0.88, notes: "",
            kcal: 230, proteinG: 6, carbsG: 24, fatG: 14, fiberG: 5,
            nutritionSource: .llmDirect,
            sugarG: 2, sodiumMg: 380, saturatedFatG: 3
        ),
        CapturedItem(
            id: "preview-3", name: "raspberries",
            portionGrams: 60, portionGramsLow: 50, portionGramsHigh: 70,
            usdaSearchTerms: ["raspberries"],
            preparation: "raw", cuisineHint: "fresh",
            confidence: 0.95, notes: "",
            kcal: 30, proteinG: 1, carbsG: 7, fatG: 0, fiberG: 4,
            nutritionSource: .llmDirect,
            sugarG: 5, sodiumMg: 1, saturatedFatG: 0
        ),
        CapturedItem(
            id: "preview-4", name: "matcha latte",
            portionGrams: 240, portionGramsLow: 220, portionGramsHigh: 260,
            usdaSearchTerms: ["matcha latte"],
            preparation: "oat milk", cuisineHint: "cafe",
            confidence: 0.86, notes: "",
            kcal: 110, proteinG: 4, carbsG: 12, fatG: 5, fiberG: 1,
            nutritionSource: .llmDirect,
            sugarG: 10, sodiumMg: 95, saturatedFatG: 1
        ),
    ]

    private static var mockFood: CapturedFood {
        CapturedFood(
            items: mockItems,
            plateType: .mixed,
            source: .photo,
            confidence: 0.88,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: 500, kcalHigh: 600
        )
    }

    private static let mockPhoto: UIImage = {
        let size = CGSize(width: 1080, height: 1920)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            // Faux breakfast plate so the develop-reveal (soft-focus →
            // crisp, desaturated → saturated) is visible in the harness
            // the way it would be over a real food photo.
            let bg = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.93, green: 0.90, blue: 0.86, alpha: 1).cgColor,
                    UIColor(red: 0.80, green: 0.75, blue: 0.70, alpha: 1).cgColor,
                ] as CFArray, locations: [0, 1])!
            c.drawLinearGradient(bg, start: .zero,
                                 end: CGPoint(x: size.width, y: size.height), options: [])
            c.setFillColor(UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: 80, y: 600, width: 920, height: 920))
            c.setFillColor(UIColor(red: 0.90, green: 0.88, blue: 0.85, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: 145, y: 665, width: 790, height: 790))
            func blob(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ col: UIColor) {
                c.setFillColor(col.cgColor)
                c.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
            }
            blob(220, 960, 320, 240, UIColor(red: 0.96, green: 0.82, blue: 0.30, alpha: 1)) // eggs
            blob(520, 880, 250, 270, UIColor(red: 0.44, green: 0.62, blue: 0.30, alpha: 1)) // avocado
            blob(560, 1150, 230, 210, UIColor(red: 0.74, green: 0.16, blue: 0.24, alpha: 1)) // berries
            blob(280, 1180, 250, 190, UIColor(red: 0.66, green: 0.44, blue: 0.24, alpha: 1)) // toast
            blob(410, 1010, 130, 130, UIColor(red: 0.99, green: 0.95, blue: 0.55, alpha: 1)) // yolk
        }
    }()

    var body: some View {
        // v1.2 snap-food rebuild — the harness now mounts the
        // production result surface (full-bleed photo + SnapResultView
        // carousel) so the slides can be iterated in isolation with a
        // 4-item mock plate.
        ZStack {
            Color.clear.onAppear {
                // Harness roots skip RootView's task, so the day-line
                // provider is mocked here (Home's QA-seed morning:
                // 860 eaten of ~1,470) for deterministic captures.
                FoodModule.dayContextProvider = {
                    FoodModule.SnapDayContext(kcalEatenToday: 860, kcalTarget: 1470)
                }
                // v22 — the protein floor too, so the plate's floor
                // bar renders in harness captures.
                FoodModule.proteinTargetProvider = { 90 }
            }
            Image(uiImage: Self.mockPhoto)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            // v22 — the understanding chips ride the harness photo
            // exactly as they ride the live result stage.
            SnapUnderstandingChips(items: Self.mockItems)
                .allowsHitTesting(false)
                .task {
                    // `--carousel-autoplay` walks plate → note → share →
                    // back while a sim video records, for frame-by-frame
                    // transition review (XCUITest swipes need a tty).
                    guard ProcessInfo.processInfo.arguments.contains("--carousel-autoplay") else { return }
                    try? await Task.sleep(nanoseconds: 2_600_000_000)
                    for target in [1, 2, 1, 0] {
                        withAnimation(.easeOut(duration: 0.3)) { selectedPage = target }
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                    }
                }
            SnapResultView(
                // A throwaway id keeps slide 2's "protein today" sane:
                // the empty-id branch sums the device-wide legacy
                // store (years of QA seeds → absurd totals).
                userId: "qa-carousel-harness",
                food: Self.mockFood,
                mealLabel: "breakfast",
                dishName: "scrambled eggs + avocado toast +2",
                page: $selectedPage,
                onLog: { _ in },
                onRetake: {},
                onEdited: { _ in },
                // Offline mock refine so the composer round-trip can be
                // exercised in the harness: fix-words returns the plate
                // at 80% (visible number roll), add appends an oil item.
                refine: { request in
                    try await Task.sleep(nanoseconds: 1_400_000_000)
                    switch request {
                    case .fixWords(let current, _):
                        let scaled = current.items.map { item in
                            CapturedItem(
                                id: item.id, name: item.name,
                                portionGrams: item.portionGrams * 0.8,
                                portionGramsLow: item.portionGramsLow * 0.8,
                                portionGramsHigh: item.portionGramsHigh * 0.8,
                                usdaSearchTerms: item.usdaSearchTerms,
                                preparation: item.preparation,
                                cuisineHint: item.cuisineHint,
                                confidence: item.confidence, notes: item.notes,
                                kcal: (item.kcal ?? 0) * 0.8,
                                proteinG: (item.proteinG ?? 0) * 0.8,
                                carbsG: (item.carbsG ?? 0) * 0.8,
                                fatG: (item.fatG ?? 0) * 0.8,
                                fiberG: (item.fiberG ?? 0) * 0.8,
                                nutritionSource: item.nutritionSource
                            )
                        }
                        return .rebased(CapturedFood(
                            items: scaled, plateType: current.plateType,
                            source: current.source, confidence: current.confidence,
                            needsSecondPhoto: false, secondPhotoHint: nil,
                            kcalLow: current.kcalLow.map { $0 * 0.8 },
                            kcalHigh: current.kcalHigh.map { $0 * 0.8 }
                        ))
                    case .addItem:
                        return .added([CapturedItem(
                            id: UUID().uuidString, name: "olive oil drizzle",
                            portionGrams: 10, portionGramsLow: 5, portionGramsHigh: 15,
                            usdaSearchTerms: ["olive oil"], preparation: "raw",
                            cuisineHint: nil, confidence: 0.8, notes: nil,
                            kcal: 80, proteinG: 0, carbsG: 0, fatG: 9, fiberG: 0,
                            nutritionSource: .llmDirect
                        )])
                    }
                }
            )
        }
    }
}


// MARK: - SnapCameraDebugHarness — food camera scan states
//
// 2026-06-23 — mounts the real PhotoCaptureView so the scanning state,
// the hard-deadline, and the new failure/retry card can be verified in
// the simulator (no camera there). Configure a dummy vision service so
// the dispatcher routes into FoodVisionService.scan, where the
// --food-debug-* faults fire (they short-circuit before any network, so
// the config is never actually used). Drive with, e.g.:
//   --debug-snap-camera --food-debug-autostart --food-debug-hang --food-debug-deadline 4
//   --debug-snap-camera --food-debug-autostart --food-debug-empty
//   --debug-snap-camera --food-debug-autostart --food-debug-hang --food-debug-deadline 30  (hold scanning to screenshot)
struct SnapCameraDebugHarness: View {
    @State private var showRecents = false

    init() {
        FoodModule.configure(
            visionService: FoodVisionService(
                config: .init(
                    supabaseURL: URL(string: "https://debug.invalid")!,
                    anonKey: "debug",
                    tokenProvider: { "debug-token" }
                )
            )
        )
        // v23 — the harness carries the reading's real grammar: a
        // protein floor + a day context so the floor bar and the
        // gain-frame day line render on film exactly as in the app.
        FoodModule.proteinTargetProvider = { 110 }
        FoodModule.dayContextProvider = {
            FoodModule.SnapDayContext(kcalEatenToday: 620, kcalTarget: 1900)
        }
    }

    var body: some View {
        PhotoCaptureView(
            onDismiss: {},
            onCaptured: { _, _ in },
            onQuickAddTapped: {}
        )
        .sheet(isPresented: $showRecents) {
            RecentMealsSheet(
                userId: FoodJournalDebugSeeder.debugUserId,
                onLogged: { showRecents = false },
                onClose: { showRecents = false }
            )
            .presentationDetents([.fraction(0.55), .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            // `--debug-again-sheet` auto-opens the relog sheet with
            // seeded recents for screenshot capture.
            if ProcessInfo.processInfo.arguments.contains("--debug-again-sheet") {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                FoodJournalDebugSeeder.seedIfNeeded()
                showRecents = true
            }
        }
    }
}

// MARK: - FoodJournalDebugSeeder — seeded debug journal entries
//
// v4 sweep (2026-07-06): the FoodJournalPreviewHarness view died with
// the legacy FoodLogTimelineView (`--debug-food-journal`), but its
// seeding statics survive here — SnapCameraDebugHarness feeds them to
// RecentMealsSheet for the relog ("again") path. Seeds go through
// FoodLogPersister.relog (persist() wants a ModelContext; relog builds
// entries directly).

private enum FoodJournalDebugSeeder {
    static let debugUserId = "debug-journal-user"

    static func seedIfNeeded() {
        guard FoodLogPersister.allEntries(userId: debugUserId).isEmpty else { return }
        let seeds: [FoodLogPersister.FoodLogEntry] = [
            .init(
                id: UUID().uuidString, loggedAt: Date(),
                title: "jeyuk bokkeum + steamed rice",
                kcal: 820, protein: 52, carbs: 68, fat: 34, fiber: 6,
                items: ["jeyuk bokkeum", "steamed rice"],
                source: "photo",
                itemsDetail: [
                    .init(name: "jeyuk bokkeum", portionG: 320, kcal: 640,
                          protein: 48, carbs: 22, fat: 34),
                    .init(name: "steamed rice", portionG: 150, kcal: 180,
                          protein: 4, carbs: 46, fat: 0),
                ]
            ),
            .init(
                id: UUID().uuidString, loggedAt: Date(),
                title: "greek yogurt with berries",
                kcal: 220, protein: 18, carbs: 24, fat: 6, fiber: 4,
                items: ["greek yogurt", "mixed berries"],
                source: "text",
                itemsDetail: [
                    .init(name: "greek yogurt", portionG: 170, kcal: 150,
                          protein: 16, carbs: 8, fat: 5),
                    .init(name: "mixed berries", portionG: 80, kcal: 70,
                          protein: 2, carbs: 16, fat: 1),
                ]
            ),
            .init(
                id: UUID().uuidString, loggedAt: Date(),
                title: "matcha latte with oat milk",
                kcal: 140, protein: 4, carbs: 18, fat: 6, fiber: 1,
                items: ["matcha latte"],
                source: "text",
                itemsDetail: nil
            ),
        ]
        for seed in seeds {
            FoodLogPersister.relog(seed, userId: debugUserId)
        }
    }
}

// v4: DayPeekPreviewHarness + DayStripPreviewHarness died with the
// strip family — past days live in becoming's journey ledger now.

struct LogWeightSheetPreviewHarness: View {
    @State private var showingSheet: Bool = true

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            VStack {
                Text("--debug-log-weight-sheet")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
                Button("re-present sheet") { showingSheet = true }
                    .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showingSheet) {
            JKWeightRitual(
                startingFromKg: 65,
                priorLoggedCount: 2,
                isUpdatingToday: false,
                onSave: { _ in },
                onDone: { showingSheet = false },
                onCancel: { showingSheet = false }
            )
            .presentationDetents([.fraction(0.7)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)
        }
    }
}

#endif

// MARK: - Root view
//
// Gates the entire app on AuthService.bootstrap() completing. Returning users
// with a cached anonymous session see the splash for one or two frames; fresh
// installs see it for the round-trip of supabase.auth.signInAnonymously().
// No view writes to data before bootstrap is ready, so the user_id is always
// available when SessionLog/DayProgress writes happen.

#if DEBUG
/// QA-launch tracer: appends timestamped markers to a file in the app
/// container (tmp/qaseed.trace) so `simctl get_app_container … data`
/// + cat gives ground truth about how far the launch task ran, even
/// when console/os_log capture is flaky. QA-only; never ships.
enum QASeedTrace {
    static func mark(_ label: String) {
        guard ProcessInfo.processInfo.arguments.contains("--uitest-seed-program") else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("qaseed.trace")
        let stamp = ISO8601DateFormatter().string(from: .now)
        let line = "\(stamp) \(label)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}
#endif

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    /// v8 THE DOOR — clinic patients with a live provider connection
    /// bypass the subscription wall (server-verified at sync).
    @AppStorage("care_entitlement_active") private var careEntitlementActive = false
    @AppStorage("userName") private var userName = ""
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("userExperience") private var userExperience = ""
    @AppStorage("voicePreference") private var voicePreference = "encouraging"
    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService.shared
    @State private var payment = PaymentService.shared

    // Minimum dwell for the editorial launch splash (all launches).
    @State private var loaderMinHoldDone = false

    // App v2 (docs/app_v2/07_GATING.md) — phase-machine inputs. The
    // paywall/downsell/winback machinery moved to WallView; the
    // post-purchase cover + trial-nudge machinery moved to MainShell.
    /// ISO stamp of the first v2 shell mount; empty = never seen v2.
    @AppStorage("appV2SeenAt") private var appV2SeenAt = ""
    /// Legacy footprint signal for the migration phase: an enrolled
    /// program predating v2.
    @AppStorage("programEraEnabled") private var programEraEnabled = false
    /// Last stable phase — held through auth transitions so identity
    /// swaps never flash the wall (07_GATING suppression-hold).
    @State private var lastStablePhase: AppPhase?

    #if DEBUG
    /// QA-seed helper: user-scoped weight-log count (the nil-latest
    /// guard broke when cloud hydration restored one stray old log).
    private func seededWeightCount(userId: String, in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
    #endif

    private var currentPhase: AppPhase {
        AppPhaseMachine.derive(.init(
            hasCompletedOnboarding: hasCompletedOnboarding,
            authReady: auth.isReady,
            entitlementReady: payment.isEntitlementReady,
            loaderHoldDone: loaderMinHoldDone,
            hasPro: payment.effectiveHasProAccess,
            hasCareEntitlement: careEntitlementActive,
            isInAuthTransition: payment.isInAuthTransition,
            wasEverEntitled: payment.wasEverEntitled,
            appV2Seen: !appV2SeenAt.isEmpty,
            hasLegacyFootprint: programEraEnabled,
            lastStablePhase: lastStablePhase
        ))
    }

    var body: some View {
        // App v2 (docs/app_v2/07_GATING.md): the route-level phase
        // machine replaces the paywall-cover-over-content model.
        // Exactly ONE phase is mounted — unpaid/expired users never
        // have main-app content in the hierarchy at all. Derivation
        // is pure (AppPhaseMachine.derive, table-tested in
        // AppPhaseTests); this body renders its answer.
        let phase = currentPhase
        Group {
            switch phase {
            case .booting:
                AffirmationLoaderScreen(state: auth.bootstrapState) {
                    Task { await auth.retryBootstrap() }
                }
                .transition(.opacity)

            case .onboarding:
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--onboarding-v4") {
                    // Debug escape to the legacy v4.5 flow while v5
                    // burns in. Remove with the v4.5 code sweep.
                    OnboardingView(onComplete: handleOnboardingComplete)
                        .transition(.opacity)
                } else if ProcessInfo.processInfo.arguments.contains("--onboarding-v5") {
                    // Debug escape to the v5 screen flow while v8
                    // burns in. Remove with the v5 sweep.
                    OnboardingV5Flow(onComplete: handleOnboardingComplete)
                        .transition(.opacity)
                } else {
                    // Onboarding v8 — THE CONSULT (2026-08-06):
                    // conversational, continuous, ink-on-paper
                    // (docs/onboarding_v8). Same completion pipeline.
                    OnboardingV8Flow(onComplete: handleOnboardingComplete)
                        .transition(.opacity)
                }
                #else
                // Onboarding v8 — THE CONSULT (2026-08-06). The
                // Debug-only launch-arg escapes compile out of Release.
                OnboardingV8Flow(onComplete: handleOnboardingComplete)
                    .transition(.opacity)
                #endif

            case .wall(let reason):
                // The hard paywall as a DESTINATION (WallView owns the
                // exit-intent downsell/winback chain + the expired
                // welcome-back variant). Purchase/restore flips the
                // entitlement stream -> the phase leaves on its own.
                WallView(reason: reason)
                    .transition(.opacity)

            case .migration:
                // Existing users (legacy program footprint) meet v2
                // once. Stamps appV2SeenAt on completion.
                MigrationMomentView()
                    .transition(.opacity)

            case .main:
                MainShell()
                    .transition(.opacity)
            }
        }
        .onChange(of: phase) { _, newPhase in
            if AppPhaseMachine.isStable(newPhase) {
                lastStablePhase = newPhase
            }
        }
        // Cross-fade between phases. Every leaf carries an explicit
        // `.transition(.opacity)`; the phase value is the ONE watch.
        .animation(Motion.crossFade, value: currentPhase)
        #if DEBUG
        // QA hook: auto-present the v2 CBT lesson reader on top of
        // whatever the root resolved to. The cover is keyed off
        // UserDefaults "uitest.cbt.day" being set non-zero (set via
        // the --uitest-cbt-lesson launch arg). Allows simctl-driven
        // screenshot of the new reader without UI navigation.
        .fullScreenCover(isPresented: Binding(
            get: { UserDefaults.standard.integer(forKey: "uitest.cbt.day") > 0 },
            set: { newValue in
                if !newValue {
                    UserDefaults.standard.set(0, forKey: "uitest.cbt.day")
                }
            }
        )) {
            CBTQACoverHost()
        }
        // Parallel QA hook for the legacy JeniMethodRitualView (the
        // active production reader from PlanView.swift:213). Lets
        // simctl screenshot the v1.1 archetype-B spread + practice
        // embeds without UI navigation. Wired by --uitest-jeni-lesson.
        .fullScreenCover(isPresented: Binding(
            get: { UserDefaults.standard.integer(forKey: "uitest.jeni.day") > 0 },
            set: { newValue in
                if !newValue {
                    UserDefaults.standard.set(0, forKey: "uitest.jeni.day")
                }
            }
        )) {
            JeniMethodQACoverHost()
        }
        // QA hook for the discounted-year sheet's facelift — presents
        // it directly over the root so the recovery chain isn't needed
        // for a visual pass. `--uitest-downsell-preview`; the
        // dismissed flag resets at the arg parser so every launch
        // with the arg shows it fresh.
        .fullScreenCover(isPresented: Binding(
            get: {
                ProcessInfo.processInfo.arguments
                    .contains("--uitest-downsell-preview")
                    && !UserDefaults.standard.bool(forKey: "uitest.downsell.dismissed")
            },
            // Deliberate no-op: the boot phase transition cancels an
            // early presentation and SwiftUI writes false through
            // this setter — a flag write here would disarm the
            // preview forever. Only the explicit onDismiss records
            // dismissal, so a cancelled presentation retries.
            set: { _ in }
        )) {
            DownsellPaywallView(
                trigger: "qa_preview",
                onSubscribed: {},
                onDismiss: {
                    UserDefaults.standard.set(true, forKey: "uitest.downsell.dismissed")
                }
            )
        }
        #endif
        .task {
            // Start the loader dwell clock at first frame, not at
            // bootstrap completion, so the hold overlaps the real wait.
            //
            // 1.8s per the splash-duration research (round 6): the
            // celebrated band is 1.5-3.0s total perceived; 8 words at
            // skim speed need ~2.0s of availability and the line stays
            // legible through the 0.45s crossFade exit, so 1.8 + 0.45
            // ≈ 2.2s perceived. Gating is max(hold, load-ready) — the
            // best-feeling apps' pattern, never a pure timer.
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            loaderMinHoldDone = true
        }
        .task {
            // Order matters: auth bootstrap → AppSync configure + onLaunch.
            // AppSync needs both AuthService.currentUser and the model
            // container, so we run it after both are ready. PaymentService
            // also depends on the authenticated user_id (RevenueCat scopes
            // purchases by appUserID), so it's configured here too.
            AppSync.shared.configure(modelContainer: modelContext.container)
            #if DEBUG
            QASeedTrace.mark("task-start")
            #endif
            await auth.bootstrap()
            #if DEBUG
            QASeedTrace.mark("bootstrap-done user=\(auth.currentUser?.id.uuidString.prefix(8) ?? "nil") state=\(String(describing: auth.bootstrapState))")
            // QA seed needs a user id. Bootstrap can legitimately land
            // .failed on a cold sim (first anonymous sign-in racing the
            // network stack) while a retry succeeds seconds later — the
            // "seed hydration race" from the v5 report. Poll briefly so
            // one launch is enough instead of silently no-oping.
            if ProcessInfo.processInfo.arguments.contains("--uitest-seed-program"),
               auth.currentUser == nil {
                for _ in 0..<24 {   // ≤12s
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if auth.currentUser != nil { break }
                    if case .failed = auth.bootstrapState {
                        await auth.retryBootstrap()
                    }
                }
                QASeedTrace.mark("seed-auth-wait user=\(auth.currentUser?.id.uuidString.prefix(8) ?? "nil")")
            }
            #endif
            PaymentService.shared.configure(appUserID: auth.currentUser?.id.uuidString)
            // W1-T4 — wire the food rail flag stack now that PaymentService
            // is configured. FoodFlags.isEnabled gates every food UI render.
            // The provider closure reads hasProAccess reactively, so flag
            // state tracks customerInfoStream emits without re-configure.
            // App v2: the bridge reads effectiveHasProAccess so DEBUG
            // QA overrides gate the food rail consistently.
            FoodFlags.configure(entitlement: FoodFlagsEffectiveEntitlement.shared)
            // W2-T3 + W2-T4 — wire the food rail pipeline. Once configured,
            // FoodCaptureDispatcher.dispatch(.photo(...)) runs the full chain:
            // FoodVisionService -> NutritionLookupService (pantry > USDA > OFF
            // parallel) -> CalorieMathService -> CapturedFood with kcal+macros.
            // 2026-06-24 — tokenProviders use freshAccessToken(), which
            // REFRESHES the session when the cached JWT has expired. The old
            // `currentSession?.accessToken` read a cached Keychain token that
            // never refreshed, so after ~1h scans sent an expired JWT and the
            // Edge Function 401'd ("food snap doesn't work anymore").
            FoodModule.configure(
                visionService: FoodVisionService(
                    config: FoodVisionService.Config(
                        supabaseURL: SupabaseConfig.url,
                        anonKey: SupabaseConfig.anonKey,
                        tokenProvider: { @Sendable in
                            await AuthService.shared.freshAccessToken()
                        }
                    )
                ),
                nutritionLookup: AppSideNutritionLookup(
                    usda: USDAClient(
                        config: USDAClient.Config(apiKey: USDAConfig.apiKey)
                    ),
                    pantry: CanonicalPantryClient(
                        config: CanonicalPantryClient.Config(
                            supabaseURL: SupabaseConfig.url,
                            anonKey: SupabaseConfig.anonKey,
                            tokenProvider: { @Sendable in
                                await AuthService.shared.freshAccessToken()
                            }
                        )
                    )
                ),
                // App v2 — the snap result renders the SAME protein
                // target as Today/Becoming/chat (TargetsService is the
                // one formula; audit defect #1).
                proteinTargetProvider: {
                    guard
                        let uid = AuthService.shared.currentUser?.id.uuidString,
                        !uid.isEmpty
                    else { return nil }
                    let stored = UserDefaults.standard
                        .double(forKey: "onboardingCurrentWeightKg")
                    let kg = TargetsService.latestWeightKg(
                        userId: uid, in: modelContext
                    ) ?? (stored > 0 ? stored : nil)
                    guard let kg else { return nil }
                    return TargetsService.proteinTargetG(weightKg: kg)
                },
                // v5.1 — the result card's day line: today-so-far +
                // the kcal target, same sources as Home's kcal bar
                // (TargetsService owns suppression: kcal comes back
                // nil for suppressed cohorts and the line stays off).
                dayContextProvider: {
                    guard
                        let uid = AuthService.shared.currentUser?.id.uuidString,
                        !uid.isEmpty
                    else { return nil }
                    let targets = TargetsService.current(userId: uid, in: modelContext)
                    let macros = FoodLogPersister.todayMacros(userId: uid)
                    return FoodModule.SnapDayContext(
                        kcalEatenToday: Int(macros.kcal.rounded()),
                        kcalTarget: targets.kcal
                    )
                }
            )
            #if DEBUG
            // App v2 QA — seed an enrolled program for the current
            // user so TodayView renders without walking onboarding +
            // the setup subflow. Pair with --uitest-pro-access.
            //   xcrun simctl launch booted com.bk.plankAI \
            //     --uitest-inapp-qa --uitest-pro-access --uitest-seed-program
            QASeedTrace.mark("seed-blocks user=\(auth.currentUser?.id.uuidString.prefix(8) ?? "nil")")
            if ProcessInfo.processInfo.arguments.contains("--uitest-seed-program"),
               auth.currentUser != nil {
                let d = UserDefaults.standard
                // Always re-assert (--uitest-inapp-qa clears these at
                // init on every launch).
                d.set(true, forKey: "programEraEnabled")
                d.set(true, forKey: "hasEnrolledInProgram")
                d.set("maya", forKey: "userName")
                d.set(75.0, forKey: "onboardingCurrentWeightKg")
                d.set(65.0, forKey: "onboardingGoalWeightKg")
                d.set(165.0, forKey: "onboardingHeightCm")
                d.set(29, forKey: "onb_v5_age_years")
                d.set("female", forKey: "onboardingGender")
                d.set("walks", forKey: "onb_v4_movement_baseline")
                // --uitest-cohort current|past|considering routes the
                // seeded account's chapter (on-medication evening
                // asks, cohort letters); default = general WL.
                if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "--uitest-cohort"),
                   i + 1 < ProcessInfo.processInfo.arguments.count {
                    d.set(ProcessInfo.processInfo.arguments[i + 1],
                          forKey: "onboarding_glp1_status")
                }
                // Seeded QA accounts are past the migration moment
                // (pair --uitest-force-migration to test it instead).
                if !ProcessInfo.processInfo.arguments.contains("--uitest-force-migration"),
                   (d.string(forKey: "appV2SeenAt") ?? "").isEmpty {
                    d.set(ISO8601DateFormatter().string(from: .now), forKey: "appV2SeenAt")
                }
            }
            if ProcessInfo.processInfo.arguments.contains("--uitest-seed-program"),
               let uid = auth.currentUser?.id.uuidString,
               ProgramService.shared.activePlan(userId: uid, in: modelContext) == nil {
                _ = ProgramService.shared.startProgram(
                    input: ProgramService.StartProgramInput(
                        currentWeightKg: 75.0,
                        goalWeightKg: 65.0,
                        tier: .medium,
                        goalCalculator: ProgramGoalCalculator.Inputs(
                            currentWeightKg: 75.0,
                            goalWeightKg: 65.0,
                            sex: .female,
                            age: 29
                        )
                    ),
                    userId: uid,
                    in: modelContext
                )
            }
            // Backdate the start so "day 12" states render — EVERY
            // launch, because cloud hydration (LWW) restores the
            // un-backdated startDate the creation upsert pushed.
            // pendingUpsert=true makes the backdate win server-side.
            if ProcessInfo.processInfo.arguments.contains("--uitest-seed-program"),
               let uid = auth.currentUser?.id.uuidString,
               let plan = ProgramService.shared.activePlan(userId: uid, in: modelContext) {
                // --uitest-seed-day N picks the demo day (default 12):
                // 12 = protein day, 14 = rest day (breath beat).
                let args = ProcessInfo.processInfo.arguments
                let seedDay: Int = {
                    if let i = args.firstIndex(of: "--uitest-seed-day"),
                       i + 1 < args.count, let n = Int(args[i + 1]), n >= 1 {
                        return n
                    }
                    return 12
                }()
                let targetStart = Calendar.current.date(byAdding: .day, value: -(seedDay - 1), to: .now) ?? .now
                if !Calendar.current.isDate(plan.startDate, inSameDayAs: targetStart) {
                    plan.startDate = targetStart
                    plan.pendingUpsert = true
                    plan.updatedAt = .now
                    try? modelContext.save()
                    Task { await AppSync.shared.upsertProgramPlan(plan) }
                }
            }
            // v8 — QA determinism: the chart persists across the
            // defaults wipe (records, not keys), so stale dev-device
            // history (a "tender" yesterday from a prior session)
            // leaks tone into every run. Wipe the seeded user's
            // observations + regimen each QA launch and pin the
            // backfill flag so hydrate can't re-import device
            // strings. (--uitest-seed-regimen re-creates its plan
            // right below.)
            if ProcessInfo.processInfo.arguments.contains("--uitest-inapp-qa"),
               let uid = auth.currentUser?.id.uuidString {
                // S4: preserve care-team plans (server-authoritative;
                // the care QA relies on the hydrated assignment).
                ObservationStore.deleteAllPreservingCareTeam(userId: uid, in: modelContext)
                UserDefaults.standard.set(
                    true, forKey: "observations.backfilled.v1.\(uid.lowercased())"
                )
            }
            // v8 — --uitest-seed-regimen: a medication plan anchored
            // on TODAY'S weekday (today composes as a dose day) with
            // startedAt = now (titration window live), so the
            // medication lead + hydration invitation + RegimenSheet
            // all render deterministically. Pair --uitest-cohort
            // current for the evening dose/sit asks.
            if ProcessInfo.processInfo.arguments.contains("--uitest-seed-regimen"),
               let uid = auth.currentUser?.id.uuidString {
                if RegimenService.activeMedicationPlan(userId: uid, in: modelContext) == nil {
                    _ = RegimenService.setShotDay(
                        RegimenService.isoWeekday(.now),
                        userId: uid, in: modelContext
                    )
                } else if let plan = RegimenService.activeMedicationPlan(
                    userId: uid, in: modelContext
                ), plan.anchorWeekday != RegimenService.isoWeekday(.now) {
                    // Re-anchor on every launch (the seed must hold
                    // across midnight crossings on a long-lived sim).
                    _ = RegimenService.setShotDay(
                        RegimenService.isoWeekday(.now),
                        userId: uid, in: modelContext
                    )
                }
            }
            // Two plates today so the journal, plate strip, protein
            // arc, kcal line, wins block, and insight cards all carry
            // real state in the walker ledger. mergeRemote is the
            // public insert-only seam (no photos; recipe-card minis).
            // No presence guard: the ids carry the dayKey and
            // mergeRemote is insert-only by id, so re-seeding is
            // idempotent per day (an any-entries guard starved every
            // run after the first midnight crossing; a today-guard
            // then blocked the prev-dinner plate).
            if ProcessInfo.processInfo.arguments.contains("--uitest-seed-program"),
               let uid = auth.currentUser?.id.uuidString {
                let cal = Calendar.current
                let today = cal.startOfDay(for: .now)
                let dayKey = TodayStateService.dayKey()
                // debugSeed (not mergeRemote) so the plates carry sugar —
                // the cloud SyncableEntry drops it, so a mergeRemote seed
                // would render the sugar surfaces empty in QA.
                FoodLogPersister.debugSeed(
                    id: "qa-plate-\(dayKey)-1", userId: uid,
                    loggedAt: today.addingTimeInterval(8.2 * 3600),
                    kcal: 340, protein: 24, carbs: 38, fat: 11, fiber: 6,
                    sugar: 16, sodiumMg: 320, title: "greek yogurt bowl", source: "quick_add")
                FoodLogPersister.debugSeed(
                    id: "qa-plate-\(dayKey)-2", userId: uid,
                    loggedAt: today.addingTimeInterval(12.7 * 3600),
                    kcal: 520, protein: 38, carbs: 52, fat: 17, fiber: 7,
                    sugar: 9, sodiumMg: 740, title: "chicken poke bowl", source: "quick_add")
                // Last night's dinner so the overnight window
                // (dinner → first plate) narrates in QA.
                FoodLogPersister.debugSeed(
                    id: "qa-plate-\(dayKey)-prev", userId: uid,
                    loggedAt: today.addingTimeInterval(-5 * 3600),
                    kcal: 610, protein: 34, carbs: 58, fat: 22, fiber: 8,
                    sugar: 3, sodiumMg: 610, title: "salmon and rice", source: "quick_add")
                // v18 — a real WEEK of plates so the nutrient sparks
                // (and Becoming's scoped charts) can be judged on
                // shape, not on two days. Deterministic per day; the
                // ids carry the dayKey so re-seeding stays idempotent.
                // Thirteen prior days: a full week PLUS the week
                // before it, so week-over-week reads (the insight
                // carousel, the tile deltas) have both windows and can
                // be judged on real comparison rather than on absence.
                // The older week runs heavier — the deltas then say
                // something true.
                let weekShape: [(kcal: Double, p: Double, c: Double,
                                 f: Double, fib: Double, sug: Double, na: Double)] = [
                    (1880, 74, 212, 68, 14, 71, 3120),
                    (1810, 79, 198, 64, 16, 64, 2980),
                    (1930, 71, 224, 71, 13, 78, 3260),
                    (1770, 84, 190, 61, 17, 58, 2870),
                    (1850, 76, 205, 66, 15, 66, 3040),
                    (1690, 88, 176, 57, 18, 49, 2720),
                    (1740, 82, 186, 60, 17, 55, 2810),
                    (1580, 96, 168, 54, 22, 44, 2450),
                    (1490, 104, 150, 49, 25, 31, 2180),
                    (1620, 88, 182, 58, 19, 52, 2600),
                    (1440, 112, 140, 46, 27, 28, 1950),
                    (1510, 99, 158, 52, 24, 36, 2050),
                    (1380, 118, 132, 44, 29, 22, 1760),
                ]
                for (offset, day) in weekShape.enumerated() {
                    let dayBack = 13 - offset
                    guard let when = cal.date(byAdding: .day, value: -dayBack, to: today)
                    else { continue }
                    FoodLogPersister.debugSeed(
                        id: "qa-week-\(TodayStateService.dayKey(for: when))",
                        userId: uid,
                        loggedAt: when.addingTimeInterval(13 * 3600),
                        kcal: day.kcal, protein: day.p, carbs: day.c, fat: day.f,
                        fiber: day.fib, sugar: day.sug, sodiumMg: day.na,
                        title: "the day's plates", source: "quick_add")
                }
                // A realistic step week so the movement bar chart renders
                // with data (the sim reports ~0). Mixed above/below the
                // 7,500 goal; today mid-afternoon.
                StepsService.shared.seedForQA(
                    weekly: [6200, 8100, 5400, 9300, 7600, 4800, 6420],
                    today: 6420
                )
            }
            // --uitest-force-expired: stamp prior entitlement WITHOUT
            // granting pro so the wall(.expired) state is walkable.
            if ProcessInfo.processInfo.arguments.contains("--uitest-force-expired") {
                UserDefaults.standard.set(true, forKey: "PaymentService.wasEverEntitled")
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
            // Weight history so the trend story + canvas render
            // (6 weigh-ins easing 75.4 → 74.2 over 11 days).
            // --uitest-seed-oneweight seeds EXACTLY ONE weigh-in
            // instead, to exercise the single-weight trend state.
            if ProcessInfo.processInfo.arguments.contains("--uitest-seed-program"),
               let uid = auth.currentUser?.id.uuidString,
               seededWeightCount(userId: uid, in: modelContext) < 3 {
                let series: [(daysAgo: Int, kg: Double)] =
                    ProcessInfo.processInfo.arguments.contains("--uitest-seed-oneweight")
                    ? [(0, 74.2)]
                    : [(11, 75.4), (9, 75.1), (7, 75.2), (5, 74.8), (2, 74.5), (0, 74.2)]
                for point in series {
                    let record = WeightLogRecord(
                        userId: uid,
                        weightKg: point.kg,
                        loggedAt: Calendar.current.date(byAdding: .day, value: -point.daysAgo, to: .now) ?? .now,
                        source: "manual"
                    )
                    record.pendingUpsert = false   // QA data stays local
                    modelContext.insert(record)
                }
                try? modelContext.save()
            }
            if ProcessInfo.processInfo.arguments.contains("--uitest-seed-program") {
                let uid = auth.currentUser?.id.uuidString ?? "NIL"
                let plan = ProgramService.shared.activePlan(userId: uid, in: modelContext)
                let day = plan.map {
                    ProgramScheduleCalculator.compute(
                        .init(startDate: $0.startDate, totalDays: $0.totalDays)
                    ).programDay
                }
                let kg = TargetsService.latestWeightKg(userId: uid, in: modelContext)
                NSLog("[SeedQA] uid=%@ plan=%@ day=%@ latestKg=%@",
                      String(uid.prefix(8)),
                      plan?.id.prefix(8).description ?? "nil",
                      day.map(String.init) ?? "nil",
                      kg.map { String($0) } ?? "nil")
                QASeedTrace.mark("seed-done uid=\(uid.prefix(8)) plan=\(plan?.id.prefix(8).description ?? "nil") day=\(day.map(String.init) ?? "nil")")
            }
            #endif
            await AppSync.shared.onLaunch(modelContext: modelContext)
            // Steps: silent permission probe at launch (never prompts).
            // StepsService's docs always promised this call; it was only
            // wired through the Home pulse tile's .task, so program
            // users who land on the Plan tab kept seeing "connect
            // steps" on Becoming even after granting access.
            await StepsService.shared.bootstrap()
            // Sleep: same silent permission probe at launch (never
            // prompts). The Becoming card surfaces the connect CTA
            // when authorization is .notDetermined. Mirrors StepsService
            // launch pattern.
            await SleepService.shared.bootstrap()
            // Vitals: same silent probe (resting HR / HRV / cardio
            // fitness / respiratory rate — the passive clinical rail,
            // 04_CLINICAL_CHECKLIST.md §4 #2). Never prompts; the rail
            // renders only when data flows.
            await VitalsService.shared.bootstrap()
            // Movement: same silent probe (workouts / active energy /
            // distance — v9 P0 W6 plumbing; the authorization ask
            // ships with P3's rendered surface, L5).
            await MovementService.shared.bootstrap()
            // v9 P0 (W3): passive weight, actually passive. Silent —
            // imports only after the ask has ever been shown; the
            // observer keeps future scale samples flowing (background
            // delivery, entitlement-backed). Manual rows still win
            // their day (BodyMassImportService policy).
            if let uid = auth.currentUser?.id.uuidString, !uid.isEmpty {
                #if DEBUG
                let dbgArgs = ProcessInfo.processInfo.arguments
                if let flagIdx = dbgArgs.firstIndex(of: "--debug-hk-write-weight"),
                   dbgArgs.indices.contains(flagIdx + 1),
                   let kgArg = Double(dbgArgs[flagIdx + 1]) {
                    await BodyMassImportService.shared.debugWriteSample(kg: kgArg)
                }
                #endif
                await BodyMassImportService.shared.importIfEnabled(
                    userId: uid, into: modelContext)
                BodyMassImportService.shared.startObservingIfEnabled(
                    userId: uid, into: modelContext)
                #if DEBUG
                BodyScanQA.resetIfRequested(userId: uid, in: modelContext)
                BodyScanQA.seedScansIfRequested(userId: uid, in: modelContext)
                #endif
                // v9 P1 (D3) — the opt-in scan backup: retry queued
                // uploads + rebuild the record after a reinstall.
                // Both no-op unless she turned backup on.
                await BodyScanSyncService.shared.flushPendingUploads(
                    userId: uid, in: modelContext)
                await BodyScanSyncService.shared.restoreIfEnabled(
                    userId: uid, in: modelContext)
            }
            // Re-fill the local retention notifications (affirmation drops +
            // win-back). No-op + never prompts when notifications aren't
            // authorized; purely additive over the daily + trial reminders.
            RetentionNotifications.reschedule()
        }
        .onChange(of: auth.currentUser?.id) { _, _ in
            // Fires on sign-in (different user_id) and sign-out (named -> anon).
            Task { await AppSync.shared.onAuthChanged(modelContext: modelContext) }
            // v1.0.7 QA blocker 2 — keep PostHog distinct_id in sync
            // with Supabase user_id so cross-device sessions + funnel
            // cohorts unify in one Person.
            PlankAIApp.identifyPostHogUser()
            // v1.1.1 — re-point RevenueCat at the new appUserID so
            // entitlements + customerInfoStream reflect the signed-in
            // identity (not the prior anonymous user). Without this,
            // a sign-out + sign-back-in flow keeps Pro entitlement
            // looking up under the wrong anonymous appUserID until
            // the next cold launch — i.e. the user appears unpaid
            // for the rest of the session. Idempotent.
            PaymentService.shared.configure(appUserID: auth.currentUser?.id.uuidString)
        }
        .onChange(of: auth.authMethod) { _, _ in
            // Fires on signup-upgrade (anon -> email/apple, same user_id).
            // Without this, retry/hydrate never run after upgrade.
            Task { await AppSync.shared.onAuthChanged(modelContext: modelContext) }
            // Re-identify on upgrade so auth_method super-property
            // is set and the merged Person picks up the new method.
            PlankAIApp.identifyPostHogUser()
        }
    }

    // App v2: post-purchase eligibility + the exit-intent chain moved
    // to WallView; the post-purchase cover itself is MainShell's
    // (docs/app_v2/07_GATING.md).

    private func handleOnboardingComplete(_ data: OnboardingData) {
        userName = data.name
        // focusArea (Q10) drives the WorkoutGoal pipeline (anatomy).
        switch data.focusArea {
        case "abs": userGoal = "definition"
        case "obliques": userGoal = "sculpting"
        case "lowerBack": userGoal = "strength"
        default: userGoal = "fullCore"
        }
        userExperience = data.experience
        voicePreference = data.voicePreference
        // Q1 motivation (the "why") — drives plan reveal copy + coach intro.
        UserDefaults.standard.set(data.goal, forKey: "userMotivation")
        UserDefaults.standard.set(data.ageRange, forKey: "ageRange")
        UserDefaults.standard.set(data.activityLevel, forKey: "activityLevel")
        UserDefaults.standard.set(data.focusArea, forKey: "focusArea")
        // Phase 7: bodyFocus.first surfaces the new aesthetic-zone field
        // to AppStorage readers (PaywallView headline). focusArea above is
        // the legacy lossy mapping; bodyFocus is the truthful answer.
        UserDefaults.standard.set(data.bodyFocus.first ?? "", forKey: "bodyFocus")
        UserDefaults.standard.set(data.plankTime, forKey: "plankTime")
        UserDefaults.standard.set(data.commitmentDaysPerWeek, forKey: "commitmentDays")
        UserDefaults.standard.set(data.sessionLengthMinutes, forKey: "sessionLengthPref")
        UserDefaults.standard.set(data.baselineHoldSeconds, forKey: "userBaselineSeconds")
        UserDefaults.standard.set(data.barriers.joined(separator: ","), forKey: "userBarriers")
        // Phase 9.20 — identityFeeling (Q140: "how do you want to feel?")
        // persisted so JeniMethodUserContext can personalize ritual copy.
        // Values: "powerful" | "calm" | "light" | "strong" | "radiant" | "".
        UserDefaults.standard.set(data.identityFeeling, forKey: "identityFeeling")
        UserDefaults.standard.set(data.notificationsEnabled, forKey: "notificationsEnabled")
        // Phase A: AnalyticsView reads weights via @AppStorage. Without
        // this write the keys default to 0, the chart's starting-baseline
        // path never fires, and the seed-on-onboarding step below is
        // dead weight. (Bug existed silently — OnboardingView held weight
        // in @State only.)
        UserDefaults.standard.set(data.currentWeightKg, forKey: "onboardingCurrentWeightKg")
        UserDefaults.standard.set(data.goalWeightKg, forKey: "onboardingGoalWeightKg")
        // Canonical sex term for TargetsService's Mifflin-St Jeor BMR
        // (the v5 store mirrors this live too; written here so the key
        // is never missed even if the gender screen was skipped).
        UserDefaults.standard.set(data.gender, forKey: "onboardingGender")
        // Phase A: persist the goal date the user just saw on the projection
        // chart so CoachIntroView + JenisNoteCard can reference it without
        // recomputing. Mirrors `predictionDate()` in OnboardingView.swift:5278
        // — 12-week base (84 days) ± 14 days for activityLevel. Stored as a
        // TimeInterval (seconds since reference date) for @AppStorage compat.
        let goalDateDays: Int = {
            var d = 84
            switch data.activityLevel {
            case "athlete":   d -= 14
            case "sedentary": d += 14
            default: break
            }
            return d
        }()
        if let goalDate = Calendar.current.date(byAdding: .day, value: goalDateDays, to: Date()) {
            UserDefaults.standard.set(goalDate.timeIntervalSinceReferenceDate, forKey: "onboardingGoalDate")
        }

        // Persist the profile to SwiftData + Supabase. Anonymous-first
        // bootstrap guarantees currentUserId exists by the time onboarding
        // completes; the guard is defensive against init-order regressions.
        if let userId = AppSync.shared.currentUserId, !userId.isEmpty {
            let record = upsertLocalUserRecord(userId: userId, data: data)

            // Phase 1a - clinical baseline. Computed here so the persisted
            // numbers trace directly to the collected fields (provenance rule).
            //
            // Medical disclaimer acknowledgment. The disclaimer screen (Task 8)
            // writes an ISO8601 timestamp to AppStorage("medicalDisclaimerAckAtISO")
            // before calling onRevealComplete(). We read it back here and set
            // it on the UserRecord so it syncs to Supabase alongside the other
            // onboarding fields. Left nil for existing users who onboarded
            // before the disclaimer screen shipped.
            let ackISOString = UserDefaults.standard.string(forKey: "medicalDisclaimerAckAtISO") ?? ""
            if !ackISOString.isEmpty,
               let ackDate = ISO8601DateFormatter().date(from: ackISOString) {
                record.medicalDisclaimerAckAt = ackDate
            }
            let cgInputs = ProgramGoalCalculator.Inputs(
                currentWeightKg:  data.currentWeightKg,
                goalWeightKg:     data.goalWeightKg,
                sex:              ProgramGoalCalculator.sex(fromGenderKey: data.gender),  // FIX 4: centralized mapping
                // TODO(age): age is passed nil because OnboardingData.ageRange is a band string ("18_24"),
                // not a parsed Int, and the current rate math doesn't use age. If ProgramGoalCalculator.compute()
                // ever uses age (e.g. age-stratified loss-rate floors / TDEE), parse `data.ageRange` here AND
                // recompute the persisted `record.targetRatePctPerWeek` so the onboarding-time baseline stays consistent.
                age:              nil,
                isGLP1User:       ProgramGoalCalculator.isGLP1User(
                                      from: UserDefaults.standard.string(
                                                forKey: "onboarding_glp1_status") ?? ""),
                isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(
                                      from: UserDefaults.standard.string(
                                                forKey: "onboardingHormonalStage") ?? ""),
                isShortSleeper:   ProgramGoalCalculator.isShortSleeper(
                                      from: UserDefaults.standard.string(
                                                forKey: "onboardingSleepHours") ?? ""),
                weightTrendKey:   UserDefaults.standard.string(
                                      forKey: "onboarding_weight_trend") ?? "",
                glp1PhaseKey:     UserDefaults.standard.string(
                                      forKey: "onboarding_glp1_phase") ?? ""
            )
            let cgWindow = ProgramGoalCalculator.compute(cgInputs)
            record.computedStartBMI     = ClinicalBaseline.bmi(weightKg: data.currentWeightKg,
                                                                heightCm: data.heightCm)
            record.targetRatePctPerWeek = cgWindow.lossRateFloor * 100
            record.pendingUpsert        = true

            // Fire-and-forget — don't block the UI on the network call. RLS
            // failures or table-missing conditions surface in Supabase logs;
            // SyncService.upsertUser swallows them and the next anon → named
            // transition will retry.
            Task { await AppSync.shared.upsertUser(record) }

            // Phase A: seed the first weight log at the actual onboarding
            // completion moment (not lazily on first Analytics view, which
            // pre-Phase-A dated the row at view-time and was prone to never
            // firing if the user logged a manual weight first). Source
            // tagged "onboarding" so the analytics surface can label it
            // distinctly from manual logs.
            if data.currentWeightKg > 0 {
                let log = WeightLogRecord(
                    userId: userId,
                    weightKg: data.currentWeightKg,
                    loggedAt: .now,
                    source: "onboarding"
                )
                modelContext.insert(log)
                try? modelContext.save()
                Task { await AppSync.shared.upsertWeightLog(log) }
            }

            // v8 Stage A — the shot day she offered at intake
            // becomes her SELF-managed regimen (authority "self").
            // setShotDay's guard makes this care_team-safe and
            // duplicate-safe: an existing self plan re-anchors, a
            // clinician-managed plan is returned untouched, no pick
            // (or non-current cohort) writes nothing — and a
            // no-medication user gets no medication state anywhere.
            if CohortStore.isGLP1Current,
               let iso = RegimenService.isoWeekday(
                   fromWord: UserDefaults.standard.string(forKey: "onb_v5_shot_day")
               ) {
                _ = RegimenService.setShotDay(iso, userId: userId, in: modelContext)
            }
        } else {
            os_log("onboarding complete but no current auth user; profile not persisted",
                   log: .default, type: .error)
        }

        hasCompletedOnboarding = true
    }

    /// Insert-or-update the local UserRecord for the current Supabase user
    /// with the onboarding answers. Returns the persisted record so the
    /// caller can hand it to AppSync for cloud upsert. SwiftData write is
    /// synchronous so MainTabView reads consistent state on the next render.
    private func upsertLocalUserRecord(userId: String, data: OnboardingData) -> UserRecord {
        let descriptor = FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == userId }
        )
        let record: UserRecord
        if let existing = try? modelContext.fetch(descriptor).first {
            record = existing
        } else {
            record = UserRecord(id: userId, name: data.name)
            modelContext.insert(record)
        }
        record.name = data.name
        record.onboardingGoal = data.goal
        record.onboardingExperience = data.experience
        // 2026-06-29: the plank-hold question (case 3) was cut.
        // `data.baselineHoldSeconds` is now a movement-derived difficulty
        // PROXY (used only for userBaselineSeconds / the workout engine) —
        // it is NOT a measured plank hold. This record field feeds the
        // Becoming "PLANK PROGRESS · from Ns at start" mastery curve, which
        // is a plank-provenance claim, so it must stay nil unless the user
        // has a real plank baseline. Data-provenance rule: every number in
        // UI traces to a collected field; movement-fit is not a plank hold.
        // Leaving it nil means the mastery curve (gated on > 0) simply
        // doesn't render for users who never logged a real plank.
        record.onboardingBaselineHoldSeconds = nil
        record.onboardingBarriers = data.barriers
        record.onboardingAgeRange = data.ageRange
        record.onboardingActivityLevel = data.activityLevel
        record.onboardingCommitmentDaysPerWeek = data.commitmentDaysPerWeek
        record.onboardingNotificationEnabled = data.notificationsEnabled
        record.onboardingNotificationTime = data.notificationTime
        record.onboardingVoicePreference = data.voicePreference
        record.onboardingFocusArea = data.focusArea
        record.onboardingPlankTime = data.plankTime
        record.onboardingSessionLengthPref = data.sessionLengthMinutes
        // Phase 4 fields persisted to UserRecord (and synced to Supabase
        // via SyncService.upsertUser). The bodyFocus AppStorage mirror
        // above stays for backward-compat with PaywallView's existing
        // @AppStorage("bodyFocus") read; v1.1 EditProfile work can move
        // PaywallView to UserRecord-only and drop the mirror.
        record.onboardingBodyFocus = data.bodyFocus
        record.onboardingCurrentWeightKg = data.currentWeightKg
        record.onboardingGoalWeightKg = data.goalWeightKg
        // Phase 4 remaining 11 fields. OnboardingData carries non-
        // optional Swift defaults today (heightCm = 170, bodyType* =
        // 1/2, relatability* = false), so the values written here
        // include those defaults verbatim — same caveat tracked in the
        // v1.1 weight-optionality TODO. Persisting them anyway because
        // the schema columns are nullable and forward-compatible with
        // the optional refactor.
        record.onboardingMotivation = data.motivation
        record.onboardingWorkoutLocation = data.workoutLocation
        record.onboardingWorkoutStyle = data.workoutStyle
        record.onboardingGender = data.gender
        record.onboardingHeightCm = data.heightCm
        record.onboardingBodyTypeCurrent = data.bodyTypeCurrent
        record.onboardingBodyTypeDesired = data.bodyTypeDesired
        record.onboardingIdentityFeeling = data.identityFeeling
        record.onboardingRewardChoice = data.rewardChoice
        record.onboardingRelatability1 = data.relatability1
        record.onboardingRelatability2 = data.relatability2
        record.onboardingRelatability3 = data.relatability3
        // Epic #1 child #7 (2026-05-30): TikTok/IG/friend attribution.
        // Empty string from never-answered users persists as nil so the
        // Supabase column reflects "no answer" instead of an empty string.
        record.onboardingAcquisitionSource = data.acquisitionSource.isEmpty ? nil : data.acquisitionSource
        // 2026-06-23 — cohort + clinical intake (persistence P0,
        // docs/medical_grade_survey_audit_2026_06_23.md). These signals live
        // in @AppStorage (set during onboarding) and previously never synced,
        // so the GLP-1 cohort routing never reached Supabase + no cohort
        // analytics was possible. Copy them into the synced UserRecord here.
        // Empty string = never answered -> nil.
        let cohortDefaults = UserDefaults.standard
        let cohortValue: (String) -> String? = { key in
            let v = cohortDefaults.string(forKey: key) ?? ""
            return v.isEmpty ? nil : v
        }
        record.onboardingGlp1Status      = cohortValue("onboarding_glp1_status")
        record.onboardingGlp1Phase       = cohortValue("onboarding_glp1_phase")
        record.onboardingHormonalStage   = cohortValue("onboardingHormonalStage")
        record.onboardingWeightTrend     = cohortValue("onboarding_weight_trend")
        record.onboardingSleepHours      = cohortValue("onboardingSleepHours")
        record.onboardingStressLevel     = cohortValue("onboardingStressLevel")
        record.onboardingEatingCadence   = cohortValue("onboardingEatingCadence")
        record.onboardingEatingWindow    = cohortValue("onboardingEatingWindow")
        record.onboardingFoodRelationship = cohortValue("onboardingFoodRelationship")
        record.pendingUpsert = true
        try? modelContext.save()
        return record
    }
}

#if DEBUG
// QA cover host — resolves the requested day and presents the legacy
// `JeniMethodRitualView` (the active production reader via PlanView).
// Driven by the --uitest-jeni-lesson <day> launch arg. Mirrors
// CBTQACoverHost; targets the v1.1 archetype-B + practice-embed
// changes from the 2026-06-14 roundtable redesign.
private struct JeniMethodQACoverHost: View {
    var body: some View {
        let d = UserDefaults.standard.integer(forKey: "uitest.jeni.day")
        if let lessonID = LessonID(rawValue: d) {
            JeniMethodRitualView(
                lesson: lessonID,
                user: JeniMethodUserContext.fromAppStorage(),
                onComplete: { UserDefaults.standard.set(0, forKey: "uitest.jeni.day") },
                onSkip:     { _ in UserDefaults.standard.set(0, forKey: "uitest.jeni.day") }
            )
        } else {
            VStack(spacing: 12) {
                Text("JeniMethod lesson day out of range")
                    .font(.system(size: 14, weight: .semibold))
                Text("day=\(d)  (valid 1..14 or 15+ for generic)")
                    .font(.system(size: 12))
                Button("close") {
                    UserDefaults.standard.set(0, forKey: "uitest.jeni.day")
                }
                .padding(.top, 6)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bgPrimary)
        }
    }
}

// QA cover host — resolves the requested CBT lesson from the bundled
// manifest and presents the v2 LessonReaderView. Driven by the
// --uitest-cbt-lesson <totalDays> <day> launch arg.
private struct CBTQACoverHost: View {
    var body: some View {
        let n = UserDefaults.standard.integer(forKey: "uitest.cbt.totalDays")
        let d = UserDefaults.standard.integer(forKey: "uitest.cbt.day")
        let totalDays = n > 0 ? n : 75
        let cohort = CohortFlags.fromAppStorage()
        if let ref = CBTCurriculumService.shared.lesson(
            forProgramDay: d, totalDays: totalDays, cohort: cohort
        ) {
            LessonReaderView(
                scheduled: ref.scheduled,
                slot: ref.slot,
                variant: ref.variant,
                onComplete: { UserDefaults.standard.set(0, forKey: "uitest.cbt.day") },
                onSkip:     { _ in UserDefaults.standard.set(0, forKey: "uitest.cbt.day") }
            )
        } else {
            VStack(spacing: 12) {
                Text("CBT manifest unavailable or day out of range")
                    .font(.system(size: 14, weight: .semibold))
                Text("totalDays=\(totalDays) day=\(d)")
                    .font(.system(size: 12))
                Button("close") {
                    UserDefaults.standard.set(0, forKey: "uitest.cbt.day")
                }
                .padding(.top, 6)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bgPrimary)
        }
    }
}

// MARK: - ArrivalHeroPreviewHarness (Phase 1a, 2026-06-28)
//
// Renders the arrival horizon hero with seeded data so the component
// can be iterated and screenshot without a full enrolled account.
// Launch via `--debug-arrival`.
//
// Seed values:
//   goalDate: 84 days from today (~12 weeks, a typical medium plan)
//   actionsThisWeek: 4  (of target 5)
//
// Optional launch args:
//   --arrival-actions N   override actionsThisWeek (0..7)
//   --arrival-target N    override target (1..7)

struct ArrivalHeroPreviewHarness: View {

    private let seedGoalDate: Date = Calendar.current.date(
        byAdding: .day, value: 84, to: .now
    ) ?? .now

    private var seedActions: Int {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--arrival-actions"), i + 1 < args.count,
           let v = Int(args[i + 1]) { return max(0, min(7, v)) }
        return 4
    }

    private var seedTarget: Int {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--arrival-target"), i + 1 < args.count,
           let v = Int(args[i + 1]) { return max(1, min(7, v)) }
        return 5
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 64)

                // Eyebrow (mirrors PlanView layout)
                Text("DAY 4 OF 84")
                    .font(Typo.editorialEyebrow)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .kerning(0.66)
                    .padding(.horizontal, Space.lg)

                Spacer().frame(height: 10)

                // Arrival horizon hero - v2 masthead plate (Phase 1a, 2026-06-28).
                // Mirrors PlanView.arrivalHorizonHero exactly so the harness
                // screenshot reflects the live screen.
                let dateLabel = Self.dateFormatter.string(from: seedGoalDate).lowercased()
                VStack(alignment: .leading, spacing: 0) {
                    Text("~\(dateLabel)")
                        .font(Typo.questionHero)
                        .foregroundStyle(Palette.textPrimary)

                    HairlineRule()
                        .padding(.top, 8)

                    HStack(alignment: .center, spacing: 12) {
                        TickRow(
                            filled: seedActions,
                            total: seedTarget,
                            animateFill: true,
                            pulseLast: true
                        )
                        Text("you're showing up")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                        // Right micro-stat: week number balances the masthead row.
                        // Seed day = 4 → WEEK 1. Kept in sync with PlanView edit.
                        Text("WEEK 1")
                            .font(Typo.captionTracked)
                            .kerning(1.98)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.lg)

                Spacer()
            }
        }
    }
}

// MARK: - PromiseConfirmPreviewHarness (Task 10, 2026-06-28)
//
// Renders the post-purchase promise confirmation screen directly.
// Seeds AppStorage with a sample promise so the view has something
// to replay. Launch via `--debug-promise-confirm`.

struct PromiseConfirmPreviewHarness: View {
    var body: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()
            StickerScatter(placements: StickerScatter.coachIntroDefault())
                .allowsHitTesting(false)
            PostPurchasePromisePhase(
                action: "log breakfast",
                anchor: "after coffee",
                onContinue: {}
            )
        }
    }
}

// MARK: - KeptPromisePreviewHarness (Task 10, 2026-06-28)
//
// Standalone render of the Day-1 kept-promise card in its PlanView
// context (eyebrow + arrival hero above it). Self-contained: no auth,
// no payment, no SwiftData needed. Launch via `--debug-kept-promise`.
//
// The card reads AppStorage at render time, but this harness seeds
// its own values so the condition always fires regardless of sim state.

struct KeptPromisePreviewHarness: View {
    // Arrival hero label computed once - 84 days from today ("dec 27").
    private var goalLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let d = Calendar.current.date(byAdding: .day, value: 84, to: .now) ?? .now
        return f.string(from: d).lowercased()
    }

    var body: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 64)

                // Eyebrow - mirrors PlanView layout
                Text("DAY 2 OF 84")
                    .font(Typo.editorialEyebrow)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .kerning(0.66)
                    .padding(.horizontal, Space.lg)

                Spacer().frame(height: 10)

                // Arrival horizon hero - mirrors arrivalHorizonHero
                VStack(alignment: .leading, spacing: 4) {
                    Text("~\(goalLabel)")
                        .font(Typo.questionHero)
                        .foregroundStyle(Palette.textPrimary)
                    Text("you're showing up, 1 of 5 this week")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.lg)

                Spacer().frame(height: 16)

                // Kept-promise ticket - mirrors keptPromiseCard in PlanView
                // (Phase 1a premium redesign, 2026-06-28)
                HStack(spacing: 0) {
                    // Leading accent rule - cocoa accent at 65% opacity
                    Rectangle()
                        .fill(Palette.accent.opacity(0.65))
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 6) {
                            Text("you said you'd log breakfast, after coffee.")
                                .font(.custom("DMSans-Regular", size: 15))
                                .foregroundStyle(Palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        HStack(alignment: .center) {
                            Text("done")
                                .font(.custom("DMSans-SemiBold", size: 14))
                                .foregroundStyle(Palette.textInverse)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 9)
                                .background(Palette.cocoaPrimary)
                                .clipShape(Capsule())
                            Spacer()
                            // Anchor echo - tracked caps, tertiary
                            Text("AFTER COFFEE")
                                .font(Typo.captionTracked)
                                .kerning(1.98)
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Palette.hairlineCocoa, lineWidth: 0.75)
                )
                .shadow(color: Palette.cocoaPrimary.opacity(0.06), radius: 10, x: 0, y: 2)
                // Clamp to content height - Rectangle accent bar is flexible; without
                // this the card expands to split vertical space with the Spacer below.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.lg)

                Spacer()
            }
        }
    }
}

// MARK: - ActivationGalleryHarness (DEBUG-only)
//
// One vertical gallery of the activation design foundation so each
// reusable component can be eyeballed + screenshot in isolation.
// Launch: `xcrun simctl launch booted com.bk.plankAI --debug-activation-gallery`
struct ActivationGalleryHarness: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // 1. The alive-surface background under everything.
            GrainfieldBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    header

                    section("arc sparkline") {
                        ArcSparkline(animate: animate, startLabel: "today", endpointLabel: "arrival")
                            .frame(height: 110)
                    }

                    section("tick row · 4 of 5") {
                        TickRow(filled: 4, total: 5, animateFill: true, pulseLast: true)
                    }

                    section("lab readout block") {
                        LabReadoutBlock(rows: [
                            .init(label: "this week", value: "4 of 5"),
                            .init(label: "since you started", value: "12 days"),
                            .init(label: "next", value: "tomorrow"),
                        ])
                    }

                    section("earned sticker cluster") {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Palette.bgElevated)
                                .frame(height: 150)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Palette.hairlineCocoa, lineWidth: 0.75)
                                )
                                .overlay(alignment: .bottomLeading) {
                                    Text("a kept promise.")
                                        .font(Typo.sectionTitle)
                                        .foregroundStyle(Palette.textPrimary)
                                        .padding(20)
                                }
                            EarnedStickerCluster(animate: animate)
                                .frame(width: 116, height: 116)
                                .offset(x: 8, y: 8)
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding(28)
                .padding(.top, 40)
            }
        }
        .onAppear {
            ActivationHaptics.shared.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { animate = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("activation foundation")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
            Text("--debug-activation-gallery · phase 1a")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func section<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(label.uppercased())
                .font(Typo.statLabel)
                .kerning(0.06 * 11)
                .foregroundStyle(Palette.cocoaTertiary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - RatingGateDebugHost (--debug-rating-gate)
//
// Presents the first-win sentiment gate over a cream backdrop exactly
// as it fires from TodayModuleHost after a workout completion. "yes"
// fires the native review sheet (iOS suppresses in sim); "not really"
// opens the feedback path.
struct RatingGateDebugHost: View {
    @State private var showFeedback = false
    var body: some View {
        RatingSentimentScreen(
            onYes: { RatingPromptService.shared.presentSystemReviewSheet() },
            onNotReally: { showFeedback = true }
        )
        .sheet(isPresented: $showFeedback) {
            FeedbackView(source: "rating_gate_negative")
                .presentationDetents([.large])
                .presentationBackground(Palette.programEraBg)
        }
    }
}
#endif

