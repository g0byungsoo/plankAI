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
                RootView()
                    .modifier(ResumeBloom())
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

    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService.shared
    @State private var payment = PaymentService.shared

    // Downsell paywall state. Hard-paywall model: the cover stays up
    // until the user subscribes or restores. The downsell is presented
    // as a .sheet over PaywallView — appears ONLY in response to a user
    // action (X tap on the main paywall, or Apple purchase-sheet cancel).
    // Auto-pop after dwell was removed: it was hiding inside successful
    // purchase flows as the discount sheet appearing right as the cover
    // dismissed, creating an awkward "did I get the discount or the
    // standard?" moment for the user.
    // v1.0.7 removed @State private var showingDownsell = false
    // (downsell flow unwired; founder chose premium positioning).

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
                            // Hard paywall — sits between onboarding completion
                            // and MainTabView. Cover dismisses only when
                            // PaymentService.hasProAccess flips true (purchase
                            // or restore). The downsell appears as a .sheet
                            // over this view: auto-pops after dwell time, OR
                            // on X tap. Sheet dismiss returns here without
                            // letting the user out of the cover.
                            PaywallView(
                                // 2026-06-01: dismissable flipped to
                                // false. X button was always decorative
                                // (onDismiss didn't actually dismiss the
                                // hard-paywall cover, only fired analytics)
                                // so its visual presence was misleading.
                                // Hard paywall is now visually honest:
                                // the only way out is to subscribe.
                                dismissable: false,
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
                                    // 2026-05-30 (epic #1 child #4): X tap
                                    // no longer opens the downsell. The
                                    // paywall stays hard-bound to
                                    // effectiveHasProAccess, so the X is a
                                    // visual escape hatch only — the
                                    // paywall_dismiss_attempted event fires
                                    // for the analytics signal. Downsell
                                    // fires ONLY on transaction-abandon
                                    // (Apple sheet cancel) per the spec.
                                },
                                onPurchaseCancelled: {
                                    // v1.0.7: discount-free premium positioning
                                    // (founder decision 2026-05-31 after
                                    // April-2026 Apple Cal AI 5.6 enforcement
                                    // + research-validated brand cost of
                                    // discount-training the cohort).
                                    //
                                    // Transaction-abandon now tracks the event
                                    // for funnel analysis but does NOT present
                                    // a discount paywall. Premium positioning
                                    // is the lever — Calm/Headspace/Mejuri
                                    // pattern. DownsellPaywallView.swift stays
                                    // dormant on disk for potential v1.2
                                    // reactivation if conversion data demands.
                                    Analytics.track(.paywallTransactionAbandoned)
                                }
                            )
                            .onAppear {
                                // Paywall view event. variant_id is fixed
                                // until we run paywall experiments; the
                                // property is here so future variants slot
                                // in without changing the call site.
                                Analytics.track(.paywallView, properties: [
                                    "paywall_id": "main",
                                    "placement": "onboarding_final",
                                    "variant_id": "control",
                                    "default_plan": "annual",
                                    "has_trial": true,
                                    "trial_days": 3
                                ])
                            }
                            // v1.0.7 (2026-05-31): downsell sheet removed.
                            // Discount-free premium positioning. The
                            // DownsellPaywallView.swift file stays on disk
                            // for potential v1.2 reactivation, but is
                            // unwired here. Apple-5.6 risk eliminated;
                            // brand-discount-training risk eliminated.
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
                        .fullScreenCover(isPresented: $showingCoachIntro) {
                            // Phase A: the post-purchase sequence — Jeni
                            // welcome → breathwork primer → breath
                            // session → choice. All phases live inside
                            // PostPurchaseFlowView (one cover, internal
                            // cross-fades) so transitions read as smooth
                            // fades, not iOS cover slides. The single
                            // exit routes the user to the first workout
                            // (launchWorkout: true → the
                            // `pendingPostRitualWorkoutLaunch` flag
                            // HomeView reads on appear) or to Home
                            // (launchWorkout: false → user picks their
                            // own moment, workout card stays prominent).
                            PostPurchaseFlowView(onFinish: { launchWorkout in
                                CoachIntroState.markShown()
                                if launchWorkout {
                                    UserDefaults.standard.set(
                                        true,
                                        forKey: "pendingPostRitualWorkoutLaunch"
                                    )
                                }
                                var t = Transaction()
                                t.disablesAnimations = true
                                withTransaction(t) {
                                    showingCoachIntro = false
                                }
                            })
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
            // tokenProvider closures are called fresh per request so JWT
            // expiration is handled automatically by the underlying session.
            FoodModule.configure(
                visionService: FoodVisionService(
                    config: FoodVisionService.Config(
                        supabaseURL: SupabaseConfig.url,
                        anonKey: SupabaseConfig.anonKey,
                        tokenProvider: { @Sendable in
                            await AuthService.shared.currentSession?.accessToken
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
                                await AuthService.shared.currentSession?.accessToken
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
        record.pendingUpsert = true
        try? modelContext.save()
        return record
    }
}
