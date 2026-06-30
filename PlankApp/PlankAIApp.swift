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
        }
        // In-app QA hook: lands the walker on MainTabView as a
        // completed-onboarding user (pair with --uitest-pro-access for
        // the entitlement). Program flags reset so the run exercises
        // the onramp → setup → PlanView chain.
        if ProcessInfo.processInfo.arguments.contains("--uitest-inapp-qa") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "hasEnrolledInProgram")
            UserDefaults.standard.removeObject(forKey: "programEraEnabled")
            UserDefaults.standard.removeObject(forKey: "planFirstRunHintSeen")
            UserDefaults.standard.removeObject(forKey: "planChecksMigratedV1")
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
        }
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

        Analytics.sinks.append(PostHogSink())

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
                if ProcessInfo.processInfo.arguments.contains("--debug-satiety-preview") {
                    SatietyPillPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-daily-ritual") {
                    // v1.1.2 (2026-06-24) — preview the daily return ritual
                    // standalone (it is otherwise gated to a returning
                    // user's first Today open of the day).
                    DailyReturnRitual(
                        programDay: 14, totalDays: 75, showedUpCount: 12,
                        onDismiss: {}
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-lesson-close") {
                    // v1.1.2 (2026-06-24) — preview the lesson completion
                    // ink-bloom (the inkBleedReveal shader + tomorrow teaser).
                    ZStack {
                        Palette.programBgPrimary.ignoresSafeArea()
                        CompletionBloomOverlay(
                            closingWord: "noted.",
                            subtitle: "tomorrow, the next one \u{2661}"
                        )
                    }
                } else if ProcessInfo.processInfo.arguments.contains("--debug-steps-detail") {
                    // v1.1.2 (2026-06-25) — preview the steps deep-read
                    // (iridescent ring shader + energy/distance + week rhythm).
                    StepsDetailDebugHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-screen") {
                    // v1.2 (2026-06-25) — medical-grade Phase 1: SCOFF screen.
                    SCOFFScreenView(onComplete: { _, _ in })
                } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-recovery") {
                    // v1.2 (2026-06-25) — ED-positive gentle path + resources.
                    SafetyRecoveryView(onContinueGently: {})
                } else if ProcessInfo.processInfo.arguments.contains("--debug-program-setup") {
                    // v1.2 (2026-06-25) — the real program-setup subflow, to
                    // verify the safety gate fires before the program build.
                    ProgramSetupSubflow(onComplete: { _ in })
                } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-consent") {
                    SafetyConsentView(onAccept: {})
                } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-pregnancy") {
                    SafetyPregnancyView(onComplete: { _ in })
                } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-checkin") {
                    SafetyCheckInView(onFinish: {})
                } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-gate") {
                    // T7 + safety-fix (2026-06-29) - the pre-paywall safety gate.
                    // Auto-assesses from seeded AppStorage so each branch is one
                    // launch + one screenshot. Seed then launch, e.g.:
                    //   defaults write com.bk.plankAI onboarding_medication_status -string insulin_or_sulfonylurea
                    //     → clinician-first terminal
                    //   defaults write com.bk.plankAI safety_scoff_yes -int 3 (+ safety_scoff_core 3)
                    //     → recovery terminal
                    //   defaults write com.bk.plankAI safety_pregnancy_status -string pregnant
                    //     → maintenance terminal (pregnancy variant)
                    //   (clean defaults) → "safety passed" proceed marker
                    SafetyGateDebugHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-protein-hero") {
                    // v1.2 (2026-06-26) — medical-grade Phase 2.3: cohort-aware
                    // protein floor + lean-mass framing (flag-gated). Left =
                    // legacy 1.2 g/kg baseline (70kg → 84g); right = GLP-1
                    // elevated 1.6 g/kg (→ 112g) + the "lean-mass first"
                    // note that explains the higher floor.
                    ZStack {
                        Palette.bgPrimary.ignoresSafeArea()
                        VStack(spacing: 28) {
                            Text("protein tile — baseline vs GLP-1 cohort")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundStyle(Palette.textSecondary)
                            HStack(spacing: 16) {
                                BecomingProteinTile(proteinG: 78, targetG: 84)
                                    .padding(16)
                                    .frame(width: 160, height: 168, alignment: .topLeading)
                                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Palette.divider, lineWidth: 1))
                                BecomingProteinTile(proteinG: 78, targetG: 112,
                                                    note: "lean-mass first")
                                    .padding(16)
                                    .frame(width: 160, height: 168, alignment: .topLeading)
                                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Palette.divider, lineWidth: 1))
                            }
                        }
                    }
                } else if ProcessInfo.processInfo.arguments.contains("--debug-rapid-loss") {
                    // v1.2 (2026-06-26) — medical-grade Phase 2.2: rapid-loss
                    // safety guardrail insight. >1%/wk sustained loss → reframe
                    // toward protein (anti-shame, never "slow down / too fast").
                    ZStack {
                        Palette.bgPrimary.ignoresSafeArea()
                        VStack(alignment: .leading, spacing: 16) {
                            Text("rapid-loss guardrail (Phase 2.2)")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundStyle(Palette.textSecondary)
                            BecomingInsightLine(
                                text: "you're losing quickly. a protein-forward week helps you keep the muscle \u{2665}\u{FE0E}",
                                italic: ["protein-forward"]
                            )
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Palette.divider, lineWidth: 1))
                        }
                        .padding(24)
                    }
                } else if ProcessInfo.processInfo.arguments.contains("--debug-adaptive-pace") {
                    // v1.2 (2026-06-26) — medical-grade Phase 2.2: adaptive pace
                    // projection insights. Only the encouraging statuses surface
                    // a reprojected date (anti-shame); slow + stalled don't.
                    ZStack {
                        Palette.bgPrimary.ignoresSafeArea()
                        VStack(alignment: .leading, spacing: 22) {
                            Text("adaptive pace projection (Phase 2.2)")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundStyle(Palette.textSecondary)
                            BecomingInsightLine(
                                text: "you're ahead of your plan. on track for ~september 24 \u{2665}\u{FE0E}",
                                italic: ["ahead"]
                            )
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Palette.divider, lineWidth: 1))
                            BecomingInsightLine(
                                text: "right on pace. ~october 12 is in reach \u{2665}\u{FE0E}",
                                italic: ["pace"]
                            )
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Palette.divider, lineWidth: 1))
                        }
                        .padding(24)
                    }
                } else if ProcessInfo.processInfo.arguments.contains("--debug-glp1-nutrition") {
                    // v1.2 (2026-06-26) — medical-grade Phase 3.3: GLP-1 nutrition
                    // education nudges (hydration / fiber / nutrient density). The
                    // three rotate daily; wellness framing, no medical advice.
                    ZStack {
                        Palette.bgPrimary.ignoresSafeArea()
                        VStack(alignment: .leading, spacing: 18) {
                            Text("GLP-1 nutrition nudges (Phase 3.3)")
                                .font(.custom("DMSans-Regular", size: 13))
                                .foregroundStyle(Palette.textSecondary)
                            ForEach(0..<3, id: \.self) { i in
                                let n = AnalyticsView.glp1NutritionNudge(dayOfYear: i)
                                BecomingInsightLine(text: n.text, italic: n.italic)
                                    .padding(18)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Palette.divider, lineWidth: 1))
                            }
                        }
                        .padding(24)
                    }
                } else if ProcessInfo.processInfo.arguments.contains("--debug-sleep-preview") {
                    SleepCardPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-sleep-preview-empty") {
                    SleepCardEmptyStatesHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-trial-day2") {
                    TrialDay2Modal(
                        expirationDate: Date().addingTimeInterval(28 * 3600),
                        onDismiss: {}
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-trial-day3") {
                    TrialDay3Modal(
                        expirationDate: Date().addingTimeInterval(9 * 3600),
                        onDismiss: {}
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-winback") {
                    CancellationWinbackSheet(onStayOpen: {}, onLeave: {})
                } else if ProcessInfo.processInfo.arguments.contains("--debug-stickers") {
                    StickyNotePreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-log-weight-sheet") {
                    LogWeightSheetPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-handwritten-share") {
                    HandwrittenSharePreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-handwritten-weekly") {
                    HandwrittenWeeklyPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-handwritten-lesson") {
                    HandwrittenLessonPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-handwritten-result") {
                    HandwrittenResultPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-handwritten-snap") {
                    HandwrittenSnapPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-result-carousel") {
                    ResultCarouselPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-snap-camera") {
                    SnapCameraDebugHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-becoming") {
                    BecomingPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-home") {
                    HomePhase1PreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-peek") {
                    DayPeekPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-strip") {
                    DayStripPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-arrival") {
                    // Phase 1a (Task 9, 2026-06-28) - arrival horizon hero.
                    // Renders the hero with seeded data (goalDate ~84 days out,
                    // 4 actions this week of 5 target) so it can be iterated
                    // and screenshot without a full enrolled account.
                    ArrivalHeroPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-promise-confirm") {
                    // Task 10 (2026-06-28) - promise confirmation screen.
                    // Seeds the stored promise and shows PostPurchaseFlowView
                    // jumped straight to the promiseConfirmation phase.
                    // Use simctl defaults to set custom values:
                    //   day1PromiseAction "log breakfast"
                    //   day1PromiseAnchor "after coffee"
                    PromiseConfirmPreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-kept-promise") {
                    // Task 10 (2026-06-28) - Day-1 kept-promise card on the Today screen.
                    // Seeds day1Promise* AppStorage values + a past promise time so
                    // PlanView renders the card immediately. Requires a real program
                    // plan to exist (run --uitest-inapp-qa to set one up first).
                    KeptPromisePreviewHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-activation-gallery") {
                    // Phase 1a (2026-06-28) - activation design foundation
                    // gallery. Renders every reusable component (grainfield
                    // background, arc sparkline, tick row, lab readout block,
                    // earned sticker cluster) in one scroll so the premium
                    // register can be iterated + screenshot without a screen.
                    ActivationGalleryHarness()
                } else if ProcessInfo.processInfo.arguments.contains("--debug-projection") {
                    // Debug harness - jumps straight to the single projection
                    // reveal (T5 merged the former assessment's clinician
                    // credibility strip into it). Provenance line variant
                    // controlled via simctl defaults write:
                    //   onboardingSleepHours five6  → short-sleep line
                    //   onboarding_glp1_status current → GLP-1 line
                    // Launch: `xcrun simctl launch booted com.bk.plankAI --debug-projection`
                    OnboardingRevealView(
                        bodyFocus: ["flatBelly"],
                        sessionLengthKey: "ten",
                        voicePreference: "encouraging",
                        commitmentDaysKey: "five",
                        currentWeightKg: 75,
                        goalWeightKg: 65,
                        onRevealComplete: {},
                        debugStartAtProjection: true
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-projection-maintenance") {
                    // FIX 3 (2026-06-29) - delta-0 (maintenance) reveal. Equal
                    // current + goal weight so the projection step renders its
                    // maintenance-framed variant (maintenance-TDEE calorie hero
                    // + "your plan, steady" headline, curve gracefully omitted)
                    // instead of gutting the reveal. Launch:
                    // `xcrun simctl launch booted com.bk.plankAI --debug-projection-maintenance`
                    OnboardingRevealView(
                        bodyFocus: ["flatBelly"],
                        sessionLengthKey: "ten",
                        voicePreference: "encouraging",
                        commitmentDaysKey: "five",
                        currentWeightKg: 70,
                        goalWeightKg: 70,
                        onRevealComplete: {},
                        debugStartAtProjection: true
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-commitment") {
                    // Task 7 (2026-06-28) - commitment ritual screen.
                    // Jumps straight to CommitmentRitualPresentation so
                    // simctl can screenshot it without running the full
                    // building loader. GLP-1 variant via simctl defaults:
                    //   onboarding_glp1_status current  → "protect your muscle" replay
                    //   onboardingSleepHours five6       → "after i wake up" default anchor
                    OnboardingRevealView(
                        bodyFocus: ["flatBelly"],
                        sessionLengthKey: "ten",
                        voicePreference: "encouraging",
                        commitmentDaysKey: "five",
                        currentWeightKg: 75,
                        goalWeightKg: 65,
                        onRevealComplete: {},
                        debugStartAtCommitment: true
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-building") {
                    // v1.1.3 T6 (2026-06-29) - jumps straight to the trimmed
                    // (~8s) building loader so simctl can time + screenshot it
                    // without tapping through the disclaimer. Launch:
                    // `xcrun simctl launch booted com.bk.plankAI --debug-building`
                    OnboardingRevealView(
                        bodyFocus: ["flatBelly"],
                        sessionLengthKey: "ten",
                        voicePreference: "encouraging",
                        commitmentDaysKey: "five",
                        currentWeightKg: 75,
                        goalWeightKg: 65,
                        onRevealComplete: {},
                        debugStartAtBuilding: true
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-disclaimer") {
                    // Medical disclaimer trust screen (Task 8). Jumps straight
                    // to DisclaimerPresentation so it can be screenshot-ed
                    // without running the full building loader. The screen is
                    // the default production start so this harness is mainly
                    // useful for CI screenshots and design review.
                    // Launch: `xcrun simctl launch booted com.bk.plankAI --debug-disclaimer`
                    OnboardingRevealView(
                        bodyFocus: ["flatBelly"],
                        sessionLengthKey: "ten",
                        voicePreference: "encouraging",
                        commitmentDaysKey: "five",
                        currentWeightKg: 75,
                        goalWeightKg: 65,
                        onRevealComplete: {},
                        debugStartAtDisclaimer: true
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-first-week") {
                    // Jumps straight to the firstWeek reveal beat (skips
                    // the building loader + its ATT modal). Tier reads
                    // from the onboardingPickedTier AppStorage key
                    // (default medium); `simctl ... defaults write
                    // com.bk.plankAI onboardingPickedTier soft|hard` to
                    // check the other tiers.
                    OnboardingRevealView(
                        bodyFocus: ["flatBelly"],
                        sessionLengthKey: "ten",
                        voicePreference: "encouraging",
                        commitmentDaysKey: "five",
                        currentWeightKg: nil,
                        goalWeightKg: nil,
                        onRevealComplete: {},
                        debugStartAtFirstWeek: true
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-rating-ask") {
                    // Jumps straight to the in-onboarding rating ask beat
                    // (RatingAskPresentation) so it can be screenshot without
                    // running the full reveal sequence. The eligibility gate
                    // self-skips when onboardingReviewPromptShown=true - clear
                    // it first: `xcrun simctl spawn booted defaults delete
                    // com.bk.plankAI onboardingReviewPromptShown`
                    // Launch: `xcrun simctl launch booted com.bk.plankAI --debug-rating-ask`
                    OnboardingRevealView(
                        bodyFocus: ["flatBelly"],
                        sessionLengthKey: "ten",
                        voicePreference: "encouraging",
                        commitmentDaysKey: "five",
                        currentWeightKg: nil,
                        goalWeightKg: nil,
                        onRevealComplete: {},
                        debugStartAtRatingAsk: true
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-nudge") {
                    // The founder's redesigned notification opt-in nudge
                    // ("want a nudge from jeni?" - iOS notification-mock
                    // banner + "tap to feel it" haptic + time pills). It now
                    // lives as the reveal's LIVE permissions step
                    // (NudgePermissionAsk), reclaimed from the orphaned case
                    // 23. Jumps straight there for sim capture + design
                    // review. Launch:
                    // `xcrun simctl launch booted com.bk.plankAI --debug-nudge`
                    OnboardingRevealView(
                        bodyFocus: ["flatBelly"],
                        sessionLengthKey: "ten",
                        voicePreference: "encouraging",
                        commitmentDaysKey: "five",
                        currentWeightKg: 75,
                        goalWeightKg: 65,
                        onRevealComplete: {},
                        debugStartAtPermissions: true
                    )
                } else if ProcessInfo.processInfo.arguments.contains("--debug-medication") {
                    // Medication / hypoglycemia intake screen (case 1642, T4)
                    // rendered directly for sim capture + design review. The
                    // case number is set in OnboardingView's DEBUG init. Launch:
                    // `xcrun simctl launch booted com.bk.plankAI --debug-medication`
                    OnboardingView(onComplete: { _ in })
                } else if ProcessInfo.processInfo.arguments.contains("--debug-paywall") {
                    // 2026-06-29 - neat one-screen paywall redesign preview.
                    // Renders PaywallView with DEBUG mock pricing + mock
                    // projection data (no RC packages / no UserRecord needed
                    // in-sim) so the full layout - projection hero, yearly
                    // card, per-day + save anchor, docked CTA - renders for
                    // visual verification. Launch:
                    // `xcrun simctl launch booted com.bk.plankAI --debug-paywall`
                    PaywallView(
                        dismissable: true,
                        onSubscribed: {},
                        onRestore: {},
                        onDismiss: {},
                        onPurchaseCancelled: {}
                    )
                } else {
                    RootView()
                        .modifier(ResumeBloom())
                }
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
private struct ResumeBloom: ViewModifier {
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

// MARK: - SatietyPillPreviewHarness (DEBUG-only)
//
// Launch-arg-gated preview surface for the satiety pill. Three pill
// instances side-by-side in their idle / hungry-selected / meh-selected
// states plus a live one — simctl screenshots can verify the rendering,
// animations, and affirmation copy without navigating onboarding +
// paywall + food capture. Inlined in PlankAIApp.swift so no pbxproj
// edit is needed for the temporary debug entry point.
//
// Launch: `xcrun simctl launch booted com.bk.plankAI --debug-satiety-preview`

#if DEBUG
private struct SleepCardPreviewHarness: View {

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

private struct SleepCardEmptyStatesHarness: View {
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
private struct HandwrittenSharePreviewHarness: View {

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

private struct HandwrittenWeeklyPreviewHarness: View {
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

private struct HandwrittenSnapPreviewHarness: View {
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

private struct HandwrittenResultPreviewHarness: View {
    var body: some View {
        ZStack {
            Color(red: 0.985, green: 0.945, blue: 0.880).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer().frame(height: 60)
                HandwrittenPolaroidHero(
                    mealLabel: "breakfast",
                    dishName: "avocado toast with egg",
                    kcalDisplay: "350 cal"
                )
                .padding(.horizontal, 24)
                Spacer()
            }
        }
    }
}

/// v1.0.11 (2026-06-17) — lesson share is no longer handwritten per
/// founder direction. Harness flag name kept for muscle memory but
/// mounts the rebuilt magazine-register LessonQuoteCard (JeniHeroSerif
/// italic on warm off-white, no card chrome, no stickers).
private struct HandwrittenLessonPreviewHarness: View {
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
private struct ResultCarouselPreviewHarness: View {
    @State private var selectedPage: Int = 0

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
        GeometryReader { geo in
            ZStack {
                // v1.0.25 — fake camera photo behind. In production
                // this is the frozen camera frame; in the harness we
                // simulate with the rose gradient so the floating
                // cards on slides 1+2 read against a photo-like
                // backdrop.
                Image(uiImage: Self.mockPhoto)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                NutritionCarousel(
                    result: Self.mockFood,
                    photo: Self.mockPhoto,
                    mealLabel: "Breakfast",
                    dishName: "scrambled eggs + avocado toast +2",
                    carouselHeight: geo.size.height - 60,
                    onEditItem: { _ in },
                    onLogPair: { _ in }
                )
                .padding(.top, 50)
            }
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
private struct SnapCameraDebugHarness: View {
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
    }

    var body: some View {
        PhotoCaptureView(
            onDismiss: {},
            onCaptured: { _, _ in },
            onQuickAddTapped: {},
            onImOutTapped: {}
        )
    }
}

// MARK: - DayPeekPreviewHarness — Home Phase 2 peek sheet
//
// Mounts the ProgramDayPeekSheet for a chosen archetype + day. Toggle:
//   `--archetype protein|movement|balanced|rest`  (default protein)
//   `--day N`  (default 14)

private struct DayPeekPreviewHarness: View {
    @State private var showing: Bool = false

    private var archetype: ProgramDayArchetype {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--archetype"), i + 1 < args.count {
            switch args[i + 1].lowercased() {
            case "protein":  return .protein
            case "movement": return .movement
            case "balanced": return .balanced
            case "rest":     return .rest
            default:         return .protein
            }
        }
        return .protein
    }

    private var day: Int {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--day"),
           i + 1 < args.count,
           let n = Int(args[i + 1]) {
            return n
        }
        return 14
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
        }
        .sheet(isPresented: $showing) {
            ProgramDayPeekSheet(
                day: day,
                archetype: archetype,
                onDismiss: { showing = false }
            )
            .presentationDetents([.fraction(0.42)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.programCard)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showing = true
            }
        }
    }
}

// MARK: - DayStripPreviewHarness — bare ProgramDayStrip variant
//
// Surfaces the strip alone so the rest-day hairline + bumped letter
// opacity are visible without the full PlanView shell. Launch via
// `--debug-strip`. Adds an archetypeForDay lookup that paints the
// standard rotation so the cohort cadence is visible.

private struct DayStripPreviewHarness: View {
    @State private var centered: Int = 4

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("strip preview")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                ProgramDayStrip(
                    programDay: centered,
                    totalDays: 28,
                    completionByDay: [1: 4, 2: 5, 3: 3],
                    centeredDay: centered,
                    onTap: { _ in },
                    archetypeForDay: { day in
                        ProgramDayArchetype.archetype(
                            forProgramDay: day,
                            glp1Status: "",
                            restrictiveFoodRelationship: false
                        )
                    }
                )
                .padding(.horizontal, 0)

                Spacer()
            }
        }
    }
}

// MARK: - Home Phase 1 preview harness
//
// Mounts the new Home archetype atoms (HomeArchetypeHeader,
// HomeProteinTracker, PlanRow with isAnchor/isPastDay flags) with
// mock data so the redesign can be iterated on without fighting the
// "your program is ready" intercept. Launch with `--debug-home`.
// Toggle the archetype + past-day mode via launch args:
//   `--archetype protein|movement|balanced|rest`
//   `--past` for the past-day disabled treatment

private struct HomePhase1PreviewHarness: View {
    @State private var archetype: ProgramDayArchetype = {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--archetype"), i + 1 < args.count {
            switch args[i + 1].lowercased() {
            case "protein":  return .protein
            case "movement": return .movement
            case "balanced": return .balanced
            case "rest":     return .rest
            default:         return .protein
            }
        }
        return .protein
    }()
    @State private var isPastDay: Bool = ProcessInfo.processInfo.arguments.contains("--past")
    @State private var glp1IsCurrent: Bool = ProcessInfo.processInfo.arguments.contains("--glp1")
    @State private var simulateAfter9pm: Bool = ProcessInfo.processInfo.arguments.contains("--after-9pm")
    @State private var simulateKind: Bool = ProcessInfo.processInfo.arguments.contains("--kind")
    /// Phase 4 Home interactivity peek flags — computed each render
    /// so the launch arg is always fresh (no stale @State init).
    private var debugPeekHomeShowsUp: Bool {
        ProcessInfo.processInfo.arguments.contains("--peek-home-showsup")
    }
    private var debugPeekHomeProtein: Bool {
        ProcessInfo.processInfo.arguments.contains("--peek-home-protein")
    }
    private var debugPeekHomeWhy: Bool {
        ProcessInfo.processInfo.arguments.contains("--peek-home-why")
    }
    @State private var simulateRecap: YesterdayRecapKind? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--recap"), i + 1 < args.count else {
            return nil
        }
        let v = args[i + 1].lowercased()
        if v.hasPrefix("plates:") {
            return .plates(Int(v.dropFirst("plates:".count)) ?? 1)
        }
        if v.hasPrefix("rituals:") {
            return .rituals(Int(v.dropFirst("rituals:".count)) ?? 1)
        }
        if v.hasPrefix("mixed:") {
            let nums = v.dropFirst("mixed:".count).split(separator: ",")
            let p = Int(nums.first ?? "") ?? 1
            let r = Int(nums.dropFirst().first ?? "") ?? 1
            return .mixed(plates: p, rituals: r)
        }
        if v == "engaged" { return .engaged }
        return nil
    }()
    @State private var showsUpCount: Int = {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--shows-up"), i + 1 < args.count,
           let n = Int(args[i + 1]) { return n }
        return 7
    }()

    /// Mock prescription set used by the harness. PlanView's real
    /// composer reorders these by archetype; we replicate that here
    /// so the harness shows the correct anchor at row 0.
    private var orderedRows: [ProgramDayPrescription] {
        var rows: [ProgramDayPrescription] = [
            .lesson(lessonId: nil),
            .snapMeal,
            .workout(tier: .medium, minutes: 18, bodyFocus: nil),
            .steps(goal: 7500),
            .weighIn,
            .breath(minutes: 1, style: .calming),
        ]
        guard let tag = archetype.anchorTag else { return rows }
        let idx = rows.firstIndex { row in
            switch (row, tag) {
            case (.snapMeal, .snapMeal): return true
            case (.workout, .workout):   return true
            case (.breath, .breath):     return true
            default:                     return false
            }
        }
        if let idx { rows.insert(rows.remove(at: idx), at: 0) }
        return rows
    }

    private var anchorColor: Color? {
        switch archetype.anchorAccentColorName {
        case "stickyButter": return Palette.stickyButter
        case "stickyOlive":  return Palette.stickyOlive
        case "stickyMint":   return Palette.stickyMint
        default:             return nil
        }
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(isPastDay ? "viewing past" : "today")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 14) {
                        if !isPastDay {
                            let args = ProcessInfo.processInfo.arguments
                            if let i = args.firstIndex(of: "--away"),
                               i + 1 < args.count,
                               let days = Int(args[i + 1]), days >= 3 {
                                HomeWelcomeBackLine(daysAway: days)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 14)
                            } else if let recap = simulateRecap {
                                let cohort: YesterdayRecapCohort = {
                                    if glp1IsCurrent { return .glp1Current }
                                    if args.contains("--restrictive") { return .restrictiveRisk }
                                    return .default
                                }()
                                HomeYesterdayRecapLine(kind: recap, cohort: cohort)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 14)
                            }
                        }

                        HomeArchetypeHeader(
                            archetype: archetype,
                            pastDay: isPastDay,
                            kindToday: simulateKind && !isPastDay,
                            onLongPressKind: nil,
                            debugInitialWhy: debugPeekHomeWhy
                        )
                            .padding(.horizontal, 20)
                            .padding(.top, simulateRecap == nil ? 14 : 0)

                        if !isPastDay && showsUpCount >= 2 {
                            HomeShowsUpLine(
                                count: showsUpCount,
                                week: [true, true, false, true, true, false, true],
                                debugInitialExpanded: debugPeekHomeShowsUp
                            )
                                .padding(.horizontal, 20)
                        }

                        if archetype == .protein && !isPastDay {
                            HomeProteinTracker(
                                proteinG: 32,
                                targetG: 80,
                                isGLP1Current: glp1IsCurrent,
                                sources: debugPeekHomeProtein ? [
                                    (entryId: "mock-1", proteinG: 18),
                                    (entryId: "mock-2", proteinG: 9),
                                    (entryId: "mock-3", proteinG: 5),
                                ] : nil,
                                debugInitialPeeking: debugPeekHomeProtein
                            )
                            .padding(.horizontal, 20)
                        }

                        if isPastDay {
                            Text("yesterday's page. it counted as it was.")
                                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                                .foregroundStyle(Palette.cocoaTertiary)
                                .padding(.horizontal, 20)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(orderedRows.enumerated()), id: \.offset) { idx, prescription in
                                PlanRow(
                                    prescription: prescription,
                                    state: mockState(for: prescription, idx: idx),
                                    onTap: {},
                                    onLongPress: {},
                                    isAnchor: !isPastDay && idx == 0 && archetype.anchorTag != nil,
                                    anchorAccentColor: idx == 0 ? anchorColor : nil,
                                    isPastDay: isPastDay,
                                    overrideSubtitle: idx == 0 ? archetype.glp1ProteinNudge(glp1Status: glp1IsCurrent ? "current" : "") : nil
                                )
                                if idx < orderedRows.count - 1 {
                                    Divider()
                                        .background(Palette.hairlineCocoa)
                                        .padding(.leading, 72)
                                        .padding(.trailing, 20)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        if !isPastDay && (simulateAfter9pm || simulateKind) {
                            HomeTomorrowResetsLine()
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 8)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.programCard)
                            .fill(Palette.programCard)
                    )
                    .programPaperShadow()
                    .padding(.horizontal, Space.lg)

                    Spacer(minLength: 80)
                }
                .padding(.top, 24)
            }
        }
    }

    private func mockState(
        for prescription: ProgramDayPrescription,
        idx: Int
    ) -> PlanRow.RowState {
        if case .steps = prescription {
            return .progress(current: 4200, target: 7500, unit: "")
        }
        // For past-day mode: mark the first 3 rows as completed (so the
        // "kept" stamp + the lesson "re-read ♥" stamp surface), leave
        // the rest empty.
        if isPastDay {
            return idx < 3
                ? .binaryComplete(isAuto: idx == 1)
                : .binaryEmpty
        }
        if idx == 1 { return .binaryComplete(isAuto: true) }
        return .binaryEmpty
    }
}

// MARK: - Becoming preview harness
//
// Mounts the v1.2 Becoming atoms (BecomingDiaryHero +
// BecomingDeedsCounter + BecomingTrendCanvas) with mock data so the
// premium register can be iterated on without fighting the program-
// intercept fullScreenCover. Launch with `--debug-becoming`.

private struct BecomingPreviewHarness: View {
    /// T9 (2026-06-29) - reads the NSV priorities so the harness shows
    /// the real echo when the key is seeded via simctl defaults write.
    @AppStorage("onboardingNsvPriority") private var nsvPriorityCSV: String = ""

    /// Phase 4 demo flags — set via launch args so each interaction
    /// can be captured in a screenshot without needing simctl tap
    /// support. Production callers never touch these.
    private var debugPeekDay: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--peek-day"), i + 1 < args.count,
              let n = Int(args[i + 1]), (0...6).contains(n) else { return nil }
        return n
    }
    private var debugPeekMacro: BecomingMacroSegment? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--peek-macro"), i + 1 < args.count else { return nil }
        switch args[i + 1].lowercased() {
        case "protein": return .protein
        case "carbs":   return .carbs
        case "fat":     return .fat
        case "fiber":   return .fiber
        default:        return nil
        }
    }
    private var debugPeekProtein: Bool {
        ProcessInfo.processInfo.arguments.contains("--peek-protein")
    }
    /// Phase 4 Day-2 flags
    private var debugPeekMoved: BecomingMovedStat? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--peek-moved"), i + 1 < args.count else { return nil }
        switch args[i + 1].lowercased() {
        case "steps":  return .steps
        case "plank":  return .plank
        case "breath": return .breath
        default:       return nil
        }
    }
    private var debugPeekDeed: BecomingDeedCell? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--peek-deed"), i + 1 < args.count else { return nil }
        switch args[i + 1].lowercased() {
        case "plates":    return .plates
        case "lessons":   return .lessons
        case "breath":    return .breath
        case "foodnoise": return .foodNoise
        default:          return nil
        }
    }
    private var debugPeekPlateDelete: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--peek-plate-delete"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    private var debugPeekInsightIdx: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--peek-insight"), i + 1 < args.count,
              let n = Int(args[i + 1]) else { return nil }
        return n
    }
    private var debugPeekWindow: Int?? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--peek-window"), i + 1 < args.count else { return nil }
        switch args[i + 1].lowercased() {
        case "60":  return .some(60)
        case "90":  return .some(90)
        case "all": return .some(nil)
        default:    return nil
        }
    }

    @State private var mockLogs: [WeightLogRecord] = {
        // Synthesize 30 days of fake weights — gentle downward EMA
        // with daily noise so the trend canvas has shape to play with.
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<30).reversed().compactMap { offset -> WeightLogRecord? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let baseline = 72.0
            let drift = -Double(29 - offset) * 0.12
            let noise = Double.random(in: -0.4...0.5)
            let kg = baseline + drift + noise
            let log = WeightLogRecord(
                userId: "preview",
                weightKg: kg,
                loggedAt: date,
                source: "preview"
            )
            return log
        }.reversed()
    }()

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            PaperGrainBackground().ignoresSafeArea()
            scrollContent
        }
    }

    // T9 NSV echo for the harness - mirrors the nsvEchoRow logic in
    // AnalyticsView. Uses @AppStorage; also falls back to mock picks
    // when the stored value is empty so the preview always renders.
    @ViewBuilder
    private var nsvEchoPreview: some View {
        let storedPicks = nsvPriorityCSV
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }
        // Fall back to demo picks when not seeded, so the harness
        // always illustrates the row. Real AnalyticsView only renders
        // when the user has genuine picks (provenance rule).
        let picks = storedPicks.isEmpty ? ["energy", "clothes", "sleep"] : storedPicks
        VStack(alignment: .leading, spacing: 6) {
            Text("watching for")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 6) {
                ForEach(picks, id: \.self) { key in
                    Text(nsvPickLabelPreview(key))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().stroke(Palette.divider, lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func nsvPickLabelPreview(_ key: String) -> String {
        switch key {
        case "core":    return "core that holds"
        case "energy":  return "energy that lasts"
        case "clothes": return "clothes that fit right"
        case "sleep":   return "sleep that resets"
        default:        return key
        }
    }

    private var scrollContent: some View {
        let focusBelow = debugPeekMoved != nil || debugPeekDeed != nil || debugPeekInsightIdx != nil || debugPeekPlateDelete != nil
        let focusPlate = debugPeekPlateDelete != nil
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !focusPlate {
                    BecomingDiaryHero(
                        dayNumber: 33,
                        totalDays: 84,
                        dateRange: "apr 2 → jun 25",
                        showedUpCount: 28,
                        identityLine: "becoming steady.",
                        identityItalic: ["steady"]
                    )
                    .padding(.bottom, 4)
                }

                if !focusPlate {
                    // Phase 4 demo wiring (2026-06-19) — week row + recaps
                    // so the dot-tap interaction has data to surface.
                    BecomingWeekRow(
                        states: [.done, .done, .done, .open, .done, .done, .todayDone],
                        doneCount: 6,
                        archetypes: [.protein, .balanced, .movement, .protein, .balanced, .rest, .protein],
                        recaps: [
                            .init(weekdayName: "thursday", plates: 2, rituals: 1, weightLogged: false),
                            .init(weekdayName: "friday", plates: 3, rituals: 1, weightLogged: true),
                            .init(weekdayName: "saturday", plates: 1, rituals: 0, weightLogged: false),
                            .init(weekdayName: "sunday", plates: 0, rituals: 0, weightLogged: false),
                            .init(weekdayName: "monday", plates: 2, rituals: 1, weightLogged: false),
                            .init(weekdayName: "yesterday", plates: 0, rituals: 1, weightLogged: false),
                            .init(weekdayName: "today", plates: 2, rituals: 1, weightLogged: true),
                        ],
                        debugInitialSelectedIdx: debugPeekDay
                    )

                    // Bento pair: today's energy + today's protein
                    HStack(alignment: .top, spacing: 10) {
                        BecomingTodayEnergyTile(
                            eatenKcal: 1247,
                            movedMinutes: 23,
                            paceKcalTarget: 1580
                        )
                        BecomingProteinTile(
                            proteinG: 67,
                            targetG: 95,
                            sources: debugPeekProtein ? [
                                .init(entryId: "mock-1", proteinG: 32),
                                .init(entryId: "mock-2", proteinG: 21),
                                .init(entryId: "mock-3", proteinG: 14),
                            ] : nil,
                            debugInitialPeeking: debugPeekProtein
                        )
                    }

                    BecomingMacroRow(
                        protein: 67,
                        carbs: 142,
                        fat: 38,
                        fiber: 18,
                        debugInitialSelected: debugPeekMacro
                    )

                    BecomingTrendCanvas(
                        logs: mockLogs,
                        goalWeightKg: 66.0,
                        unit: .lb,
                        debugInitialWindowDays: debugPeekWindow
                    )
                }

                BecomingPlateTimelineToday(
                    plates: debugPeekPlateDelete == "empty" ? [] : [
                        (id: "mock-1", loggedAt: Date().addingTimeInterval(-7 * 3600), kcal: 380),
                        (id: "mock-2", loggedAt: Date().addingTimeInterval(-3 * 3600), kcal: 520),
                        (id: "mock-3", loggedAt: Date().addingTimeInterval(-1 * 3600), kcal: 347),
                    ],
                    onTapPlate: { _ in },
                    onLogTapped: {},
                    onDeletePlate: { _ in },
                    onOpenJournal: {},
                    debugInitialRevealedId: debugPeekPlateDelete == "empty" ? nil : debugPeekPlateDelete
                )

                BecomingMovedStrip(
                    steps: 7432,
                    workoutMinutes: 8,
                    breathMinutes: 12,
                    stepsWeek: [6200, 5800, 4100, 9300, 7400, 6900, 7432],
                    plankWeek: [0, 6, 0, 8, 5, 0, 8],
                    breathWeek: [0, 4, 8, 0, 2, 0, 12],
                    debugInitialRevealed: debugPeekMoved
                )

                BecomingDeedsCounter(
                    plates: 87,
                    lessons: 34,
                    breathMinutes: 47,
                    platesSince: Calendar.current.date(byAdding: .day, value: -45, to: .now),
                    lessonsSince: Calendar.current.date(byAdding: .day, value: -30, to: .now),
                    breathSince: Calendar.current.date(byAdding: .day, value: -22, to: .now),
                    foodNoiseSince: Calendar.current.date(byAdding: .day, value: -30, to: .now),
                    debugInitialRevealed: debugPeekDeed
                )

                // T9 (2026-06-29) - NSV echo: shows real picks from
                // nsvPriorityCSV (onboardingNsvPriority). Seed via:
                //   xcrun simctl spawn booted defaults write com.bk.plankAI
                //     onboardingNsvPriority "energy,clothes,sleep"
                nsvEchoPreview

                // Phase 4 Day-3 (2026-06-19) — multi-insight swipe
                // cycle. Three mock insights so the gesture has
                // something to walk through.
                BecomingInsightLine(
                    insights: [
                        .init(id: "demo-1",
                              text: "your trend is moving. gently is the point \u{2665}\u{FE0E}",
                              italic: ["gently"]),
                        .init(id: "demo-2",
                              text: "protein led 4 of 6 this week. that's how lean mass stays \u{2661}",
                              italic: ["lean mass"]),
                        .init(id: "demo-3",
                              text: "two weeks of showing up. that's the pattern that bends the line.",
                              italic: ["pattern"]),
                    ],
                    debugInitialIdx: debugPeekInsightIdx
                )

                Spacer(minLength: 80)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, 24)
        }
        .defaultScrollAnchor(focusBelow ? .bottom : .top)
    }
}

private struct LogWeightSheetPreviewHarness: View {
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
            LogWeightSheet(
                startingFromKg: 65,
                isUpdatingToday: false,
                onSave: { _ in showingSheet = false },
                onCancel: { showingSheet = false }
            )
            .presentationDetents([.fraction(0.55)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.programCard)
        }
    }
}

private struct StickyNotePreviewHarness: View {
    // Mirrors the locked row order in PlanView.composeTodaysChecklist
    // so the lineup reads as the user's actual day. Includes weigh-in
    // with the new heart-lock sticker (2026-06-15 founder direction).
    private let prescriptions: [ProgramDayPrescription] = [
        .lesson(lessonId: nil),
        .snapMeal,
        .workout(tier: .medium, minutes: 12, bodyFocus: nil),
        .steps(goal: 7500),
        .weighIn,
        .breath(minutes: 1, style: .calming),
        .water(ml: 2000),
        .plank(targetSeconds: 60),
        .measurements
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("sticky notes")
                        .font(.custom("Fraunces72pt-SemiBold", size: 28))
                        .foregroundStyle(Palette.textPrimary)
                    Text("--debug-stickers · weigh-in = sticker_heart_lock")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)
                }

                // 3-up grid so each row marker is visible at full size.
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 28),
                    GridItem(.flexible(), spacing: 28),
                    GridItem(.flexible(), spacing: 28)
                ], spacing: 28) {
                    ForEach(prescriptions.indices, id: \.self) { i in
                        VStack(spacing: 6) {
                            ProgramStickyNote(prescription: prescriptions[i])
                            Text(prescriptions[i].itemKey)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 12)

                // Solo weigh-in inspection at 2× scale so the heart-lock
                // sticker is large enough to read every iridescent edge.
                VStack(alignment: .leading, spacing: 12) {
                    Text("weigh-in inspection · 2×")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)
                    ProgramStickyNote(prescription: .weighIn)
                        .scaleEffect(2.0)
                        .frame(width: 80, height: 80)
                        .padding(40)
                }

                Spacer(minLength: 48)
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
    }
}

private struct SatietyPillPreviewHarness: View {

    @State private var idleChoice: SatietyChoice? = nil
    @State private var hungryChoice: SatietyChoice? = .hungry
    @State private var mehChoice: SatietyChoice? = .meh
    @State private var liveChoice: SatietyChoice? = nil

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    header

                    section(label: "1. idle (no choice)") {
                        SatietyPill(choice: $idleChoice, onSelect: { _ in })
                    }

                    section(label: "2. selected → hungry") {
                        SatietyPill(choice: $hungryChoice, onSelect: { _ in })
                    }

                    section(label: "3. selected → meh") {
                        SatietyPill(choice: $mehChoice, onSelect: { _ in })
                    }

                    section(label: "4. live (tap to feel the haptic + bloom)") {
                        SatietyPill(choice: $liveChoice, onSelect: { _ in })
                    }

                    Spacer(minLength: 48)
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("satiety pill")
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(Palette.textPrimary)
            Text("--debug-satiety-preview · sprint A 2026-06-15")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    @ViewBuilder
    private func section<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
                .textCase(.lowercase)
            content()
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Palette.accent.opacity(0.18), lineWidth: 0.75)
                )
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

private struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("userExperience") private var userExperience = ""
    @AppStorage("voicePreference") private var voicePreference = "encouraging"
    // Task 10 (2026-06-28) - promise values from onboarding commitment ritual.
    // Read here to pass into PostPurchaseFlowView so the confirmation phase
    // can replay the user's own words without re-reading AppStorage inside
    // the flow view (cleaner dependency direction).
    @AppStorage("day1PromiseAction") private var day1PromiseAction: String = ""
    @AppStorage("day1PromiseAnchor") private var day1PromiseAnchor: String = ""

    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService.shared
    @State private var payment = PaymentService.shared
    /// Sprint A (2026-06-15) — observed for Day-2 / Day-3 in-app trial
    /// nudges. PaymentService pumps the coordinator on every customer
    /// info emit; this @State drives the sheet presentation.
    @State private var trialNudge = TrialNudgeCoordinator.shared

    // Downsell paywall state. Hard-paywall model: the cover stays up
    // until the user subscribes or restores. The downsell is presented
    // as a .sheet over PaywallView on exit intent (X tap on main
    // paywall or Apple purchase-sheet cancel). Shows once per install
    // via AppStorage guard; subsequent exit intents fall through to
    // CancellationWinbackSheet.
    // Re-wired 2026-06-29 - founder reversed the May-31 premium-
    // positioning hold; discounted annual is now the exit-intent offer.
    @AppStorage("downsellShownOnce") private var downsellShownOnce = false
    @State private var showingDownsell = false

    // Celebration screen state. Set true by PaywallView/DownsellPaywallView
    // `onSubscribed` callbacks — so it fires ONLY on a fresh-from-paywall
    // purchase, not when a returning paid user's entitlement auto-restores
    // on cold launch. PremiumWelcomeScreen calls onComplete after ~2.5s
    // and we flip this back to false.

    // The JeniFit Method post-purchase education flow (Phase 2 of
    // docs/diet_education_plan.md). Set true from PremiumWelcomeScreen's
    // onComplete iff the feature flag is on AND the user's goal is on
    // the fat-loss allowlist AND Lesson 1 has not already started.
    // Forward-only: restore-purchase and cold relaunch never re-fire
    // because both go through onSubscribed-less code paths (restore) or
    // never transition effectiveHasProAccess false→true (cold relaunch
    // on an already-paid user). Default-off behind the flag.
    @State private var showingCoachIntro = false
    /// Sprint A (2026-06-15) - soft cancellation-intent winback.
    /// After 2026-06-29 re-wire: fires as the SECONDARY beat after
    /// the downsell has already shown (or as fallback once per session
    /// when downsellShownOnce is already true). Voice-aligned identity
    /// reflection - no price cut. Re-firing on repeat exits in the
    /// same session would read as nagging.
    @State private var showingWinback = false
    @State private var winbackShownThisSession = false

    // Minimum dwell for the editorial launch splash (all launches).
    @State private var loaderMinHoldDone = false

    var body: some View {
        // Phase 20a: route swaps now cross-fade through Motion.crossFade
        // (0.45s easeInOut) so cold-launch / onboarding-complete / auth-
        // resolved transitions stop snapping. Per-leaf `.transition(.opacity)`
        // is required for SwiftUI to interpolate between sibling views;
        // the watch-value `.animation(_:value:)` chain at the bottom of
        // the Group fires on every state that drives a route change.
        Group {
            // Every launch shows the same editorial splash
            // (AffirmationLoaderScreen) for max(1.8s, bootstrap):
            // brand-new users before onboarding, returning users
            // before MainTabView. One doorbell for the whole app.
            if hasCompletedOnboarding {
                // Hold the splash until BOTH auth and the first
                // entitlement check have resolved. Without the
                // isEntitlementReady gate, returning paying users see a
                // ~200-500ms paywall flash on cold launch because
                // hasProAccess defaults to its cached value (or false on
                // fresh install) before customerInfoStream has emitted
                // RevenueCat's authoritative answer. The seeded cache +
                // 3s safety timeout in PaymentService bound the wait.
                //
                // loaderMinHoldDone (founder QA 2026-06-11): fast
                // bootstraps unmounted the editorial loader before the
                // affirmation could land. 1.6s minimum hold so the
                // moment reads; slow bootstraps are unaffected (the
                // hold elapses while they're still waiting).
                if auth.isReady && payment.isEntitlementReady && loaderMinHoldDone {
                    MainTabView()
                        .transition(.opacity)
                        .fullScreenCover(isPresented: .constant(!payment.effectiveHasProAccess && !payment.isInAuthTransition)) {
                            // Hard paywall - sits between onboarding completion
                            // and MainTabView. Cover dismisses only when
                            // PaymentService.hasProAccess flips true (purchase
                            // or restore). Exit intent (X tap or Apple-sheet
                            // cancel) routes to DownsellPaywallView once per
                            // install, then CancellationWinbackSheet. Sheet
                            // dismiss returns here without letting the user
                            // out of the cover.
                            PaywallView(
                                // 2026-06-29: dismissable restored to true.
                                // X tap now routes to the exit-intent downsell
                                // (once per install) via triggerExitIntent().
                                // Cover stays up regardless - the X does NOT
                                // dismiss the hard-paywall cover.
                                dismissable: true,
                                onSubscribed: {
                                    #if DEBUG
                                    print("[Paywall.main] onSubscribed fired (debugForcePaywall was \(payment.debugForcePaywall))")
                                    // Phase 9.31 — auto-clear the force-
                                    // paywall debug flag on a successful
                                    // purchase. Otherwise the paywall
                                    // never dismisses (effectiveHasProAccess
                                    // stays false) and the coach flow gets
                                    // stuck queued forever. Dev re-enables
                                    // in Debug menu to re-test.
                                    payment.debugForcePaywall = false
                                    #endif
                                    // Phase A (2026-05-27): PremiumWelcomeScreen
                                    // removed — it was redundant with Jeni's
                                    // welcome (CoachIntroView). Purchase now
                                    // goes straight to the post-purchase flow.
                                    // The feature-flag + idempotency gate that
                                    // lived in the welcome CTA moves here.
                                    presentPostPurchaseFlowIfEligible()
                                },
                                onRestore: {
                                    Task {
                                        do {
                                            _ = try await Purchases.shared.restorePurchases()
                                        } catch {
                                            #if DEBUG
                                            print("[Paywall] restore FAILED: \(error)")
                                            #endif
                                        }
                                    }
                                },
                                onDismiss: {
                                    // 2026-06-29: exit-intent downsell wired.
                                    // analytics fires inside PaywallView.topBar
                                    // before this callback - no double-emit.
                                    triggerExitIntent()
                                },
                                onPurchaseCancelled: {
                                    // Transaction-abandon: user started StoreKit
                                    // checkout, backed out of the Apple sheet.
                                    // Funnel signal first, then exit-intent offer
                                    // (downsell once per install, winback after).
                                    Analytics.track(.paywallTransactionAbandoned)
                                    triggerExitIntent()
                                }
                            )
                            .onAppear {
                                // Paywall view event. variant_id is fixed
                                // until we run paywall experiments; the
                                // property is here so future variants slot
                                // in without changing the call site.
                                //
                                // 2026-06-15: default_plan now genuinely
                                // matches the in-view default (annual for
                                // every cohort, no goal-aware quarterly
                                // override). If the default ever flips
                                // again, keep these three properties
                                // — default_plan, has_trial, trial_days —
                                // in sync with PaywallView.selectedPlan's
                                // initial value.
                                Analytics.track(.paywallView, properties: [
                                    "paywall_id": "main",
                                    "placement": "onboarding_final",
                                    "variant_id": "control",
                                    "default_plan": "annual",
                                    "has_trial": true,
                                    "trial_days": 3
                                ])
                            }
                            // Cancellation-intent winback. MUST be attached
                            // INSIDE this fullScreenCover closure (i.e. on
                            // PaywallView), not as a sibling on MainTabView
                            // — SwiftUI doesn't let a `.sheet` present over
                            // a `.fullScreenCover` from the same view, but
                            // a `.sheet` ON the presented PaywallView
                            // surfaces normally over it. Sprint A 2026-06-15.
                            .sheet(isPresented: $showingWinback) {
                                CancellationWinbackSheet(
                                    onStayOpen: { showingWinback = false },
                                    onLeave:    { showingWinback = false }
                                )
                                .presentationDetents([.large])
                                .presentationDragIndicator(.hidden)
                                .interactiveDismissDisabled(false)
                            }
                            // Exit-intent downsell - discounted annual offer.
                            // Presented once per install (downsellShownOnce
                            // AppStorage guard in triggerExitIntent). Must be
                            // a separate .sheet from winback so SwiftUI can
                            // chain them: downsell dismiss sets showingWinback
                            // true before this sheet fully closes.
                            // interactiveDismissDisabled so the fall-through
                            // to CancellationWinbackSheet always fires via
                            // onDismiss (no silent swipe-away).
                            .sheet(isPresented: $showingDownsell) {
                                DownsellPaywallView(
                                    onSubscribed: {
                                        showingDownsell = false
                                        presentPostPurchaseFlowIfEligible()
                                    },
                                    onDismiss: {
                                        showingDownsell = false
                                        // Fall through to winback (once per session).
                                        if !winbackShownThisSession {
                                            winbackShownThisSession = true
                                            showingWinback = true
                                        }
                                    }
                                )
                                .presentationDetents([.large])
                                .presentationDragIndicator(.hidden)
                                .interactiveDismissDisabled(true)
                            }
                        }
                        .onChange(of: payment.effectiveHasProAccess) { oldValue, newValue in
                            #if DEBUG
                            print("[FUNNEL] paywall_cover_state_change | effectiveHasProAccess: \(oldValue) → \(newValue) | cover will \(newValue ? "DISMISS" : "PRESENT")")
                            #endif
                            // Purchase / trial start events fire from
                            // PaymentService.startCustomerInfoStream where
                            // product_id and trial-period info are
                            // first-class — don't double-emit here.
                        }
                        .sheet(isPresented: Binding(
                            // v1.1.3 pay-upfront: trial modals permanently
                            // gated off. No intro offer ships; these sheets
                            // are preserved for re-enable when a trial
                            // is re-introduced in a future version.
                            get: { false },
                            set: { if !$0 { trialNudge.clearPending() } }
                        )) {
                            // Sprint A 2026-06-15 — in-app trial nudges.
                            // PaymentService.reconcileTrialReminder pumps
                            // the coordinator on every entitlement emit.
                            // Day-2 fires in [24h, 48h] until renewal;
                            // Day-3 fires in (0h, 18h]. One-shot per
                            // trial via UserDefaults flag scoped to the
                            // expiration date.
                            switch trialNudge.pending {
                            case .day2:
                                TrialDay2Modal(
                                    expirationDate: trialNudge.expirationDate,
                                    onDismiss: {
                                        trialNudge.dismiss(.day2,
                                            expirationDate: trialNudge.expirationDate)
                                    }
                                )
                                .presentationDetents([.large])
                                .presentationDragIndicator(.hidden)
                            case .day3:
                                TrialDay3Modal(
                                    expirationDate: trialNudge.expirationDate,
                                    onDismiss: {
                                        trialNudge.dismiss(.day3,
                                            expirationDate: trialNudge.expirationDate)
                                    }
                                )
                                .presentationDetents([.large])
                                .presentationDragIndicator(.hidden)
                            case .none:
                                EmptyView()
                            }
                        }
                        .fullScreenCover(isPresented: $showingCoachIntro) {
                            // Phase A: the post-purchase sequence — forging
                            // → Jeni welcome → breathwork primer → breath
                            // session. All phases live inside
                            // PostPurchaseFlowView (one cover, internal
                            // cross-fades) so transitions read as smooth
                            // fades, not iOS cover slides. The single exit
                            // lands the user on the Today tab's program
                            // onramp.
                            PostPurchaseFlowView(
                                onFinish: {
                                    CoachIntroState.markShown()
                                    var t = Transaction()
                                    t.disablesAnimations = true
                                    withTransaction(t) {
                                        showingCoachIntro = false
                                    }
                                },
                                promiseAction: day1PromiseAction.isEmpty ? nil : day1PromiseAction,
                                promiseAnchor: day1PromiseAnchor.isEmpty ? nil : day1PromiseAnchor
                            )
                            .presentationBackground(Palette.bgPrimary)
                        }
                } else {
                    AffirmationLoaderScreen(state: auth.bootstrapState) {
                        Task { await auth.retryBootstrap() }
                    }
                    .transition(.opacity)
                }
            } else {
                if !auth.isReady || !loaderMinHoldDone {
                    // Every pre-onboarding launch (first install,
                    // re-onboards, recovered accounts) shows the SAME
                    // editorial splash with the same 1.8s floor. Round 7
                    // (founder QA): this replaces the old first-launch
                    // AffirmationScreen, whose 5.5s triplet ceremony was
                    // both off the new register and a forced wait on
                    // every new user's first open.
                    AffirmationLoaderScreen(state: auth.bootstrapState) {
                        Task { await auth.retryBootstrap() }
                    }
                    .transition(.opacity)
                } else {
                    OnboardingView(onComplete: handleOnboardingComplete)
                        .transition(.opacity)
                }
            }
        }
        // Cross-fade between route states. Each watch-value triggers a
        // re-evaluation of the Group; SwiftUI interpolates between the
        // outgoing leaf and the incoming one because every leaf carries
        // an explicit `.transition(.opacity)`. Without these, a route
        // swap reads as a hard cut even with the .animation modifier.
        .animation(Motion.crossFade, value: hasCompletedOnboarding)
        .animation(Motion.crossFade, value: auth.isReady)
        .animation(Motion.crossFade, value: payment.isEntitlementReady)
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
        #endif
        .animation(Motion.crossFade, value: loaderMinHoldDone)
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
            await auth.bootstrap()
            PaymentService.shared.configure(appUserID: auth.currentUser?.id.uuidString)
            // W1-T4 — wire the food rail flag stack now that PaymentService
            // is configured. FoodFlags.isEnabled gates every food UI render.
            // The provider closure reads hasProAccess reactively, so flag
            // state tracks customerInfoStream emits without re-configure.
            FoodFlags.configure(entitlement: PaymentService.shared)
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
                )
            )
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

    // MARK: - The JeniFit Method (Phase 2)

    /// Phase A (2026-05-27): present the post-purchase flow (Jeni welcome
    /// → breathwork primer → breath session → choice) if eligible.
    /// Replaces the old PremiumWelcomeScreen + shouldTriggerJeniMethodPostPurchase
    /// gate. The Jeni welcome is UNIVERSAL — every paying user meets their
    /// coach, regardless of goal (the old growGlutes exclusion applied to
    /// the fat-loss curriculum, which now gates separately on the home
    /// lesson card). Only the feature flag + once-per-user idempotency
    /// (CoachIntroState) gate this. Wrapped in a no-animation transaction
    /// so the cover presents as the paywall dismisses, no double slide.
    private func presentPostPurchaseFlowIfEligible() {
        let flagEnabled = JeniMethodFeatureFlag.isEnabled
        // 2026-06-07 (founder bug): a returning user re-purchasing on
        // a fresh-install device was seeing "DAY 1 WITH JENI" even
        // though their account already had several days of session
        // history. The per-device UserDefaults stamp gets wiped on
        // reinstall, so the device gate said "first time" while the
        // account had real history. Now: query the model store for
        // any qualifying session_log for the current user_id; if
        // there are any, suppress the coach intro entirely. Skip
        // the DB check if the user isn't authenticated yet (anon
        // bootstrap path) — in that case the per-device gate is
        // still the right signal.
        let hasActivity = userHasExistingSessionActivity()
        let idempotencyOK = CoachIntroState.shouldShowOnPurchase(hasExistingActivity: hasActivity)
        #if DEBUG
        print("[PostPurchase] onSubscribed. shouldShow=\(flagEnabled && idempotencyOK) (flag=\(flagEnabled), idempotency=\(idempotencyOK), hasActivity=\(hasActivity))")
        #endif
        guard flagEnabled && idempotencyOK else { return }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            showingCoachIntro = true
        }
    }

    /// True iff the current signed-in user has any prior session_log
    /// or day_progress records in the local store. Used to suppress
    /// the post-purchase Jeni intro for returning accounts. Returns
    /// false (treating as a new user) when the user isn't signed in
    /// yet OR the fetch errors — both fall back to the existing
    /// per-device idempotency gate.
    private func userHasExistingSessionActivity() -> Bool {
        guard let uid = auth.currentUser?.id.uuidString else { return false }
        let sessionPredicate = #Predicate<SessionLogRecord> { $0.userId == uid }
        var descriptor = FetchDescriptor<SessionLogRecord>(predicate: sessionPredicate)
        descriptor.fetchLimit = 1
        do {
            let any = try modelContext.fetch(descriptor)
            if !any.isEmpty { return true }
        } catch {
            #if DEBUG
            print("[PostPurchase] activity check failed for session_logs: \(error)")
            #endif
        }
        let dayPredicate = #Predicate<DayProgressRecord> { $0.userId == uid }
        var dayDescriptor = FetchDescriptor<DayProgressRecord>(predicate: dayPredicate)
        dayDescriptor.fetchLimit = 1
        do {
            let any = try modelContext.fetch(dayDescriptor)
            return !any.isEmpty
        } catch {
            #if DEBUG
            print("[PostPurchase] activity check failed for day_progress: \(error)")
            #endif
            return false
        }
    }

    /// Exit-intent routing for the hard paywall. First exit ever
    /// (per install) shows the discounted-annual DownsellPaywallView.
    /// After downsellShownOnce is set, subsequent exits fall back to
    /// CancellationWinbackSheet (once per session). Both sheets sit
    /// over the hard-paywall cover which stays up until
    /// effectiveHasProAccess flips true.
    private func triggerExitIntent() {
        if !downsellShownOnce {
            downsellShownOnce = true
            showingDownsell = true
        } else if !winbackShownThisSession {
            winbackShownThisSession = true
            showingWinback = true
        }
    }

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
        record.onboardingBaselineHoldSeconds = data.baselineHoldSeconds
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

private struct ArrivalHeroPreviewHarness: View {

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

private struct PromiseConfirmPreviewHarness: View {
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

private struct KeptPromisePreviewHarness: View {
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
                            // Editorial heart accent - text presentation (FE0E pins glyph, not emoji)
                            Text("\u{2665}\u{FE0E}")
                                .font(.custom("DMSans-Regular", size: 11))
                                .foregroundStyle(Palette.accent.opacity(0.55))
                                .padding(.top, 3)
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
private struct ActivationGalleryHarness: View {
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
#endif

