import XCTest

// v4.5 (2026-06-11) — onboarding flow walker.
//
// Walks the full v4.5 onboarding from welcome to the hard paywall,
// attaching a screenshot of every distinct screen. Replaces the
// no-tap-tooling gap (simctl can't tap; idb needs CLT) with the one
// driver that's always available: XCUITest. Reusable for every future
// onboarding QA pass — run:
//
//   xcodebuild test -project plankAI.xcodeproj -scheme plankAI \
//     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//     -only-testing:plankAIUITests/OnboardingWalkthroughUITests
//
// then export attachments:
//   xcrun xcresulttool export attachments --path <bundle>.xcresult \
//     --output-path screenshots/v4_5_qa/
//
// Strategy per iteration: screenshot on screen change → handle system
// alerts → prefer in-app skip paths → tap an enabled primary CTA →
// otherwise select the first option to enable the CTA. Dividers and
// the loader auto-advance (dwell).

final class OnboardingWalkthroughUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testWalkOnboardingToPaywall() throws {
        let app = XCUIApplication()
        // Fresh-flow reset: DEBUG hook in PlankAIApp.init clears the
        // completion flag once at launch. Do NOT use the
        // "-hasCompletedOnboarding NO" argument-domain pin — it overrides
        // the app's own `true` write for the whole run, RootView never
        // leaves the onboarding branch, and the flow loops at the reveal
        // instead of reaching the paywall (run-3 failure mode).
        app.launchArguments += ["--uitest-fresh-onboarding"]
        app.launch()

        // System alert handler — ATT (mid-loader) + notifications.
        addUIInterruptionMonitor(withDescription: "system alerts") { alert in
            for label in ["Allow", "Allow Once", "OK", "Don't Allow"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }

        var shot = 0
        func snap(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = String(format: "%02d_%@", shot, name)
            attachment.lifetime = .keepAlways
            add(attachment)
            shot += 1
        }

        snap("welcome")

        // CTAs the walker may tap, in preference order. Skip paths
        // first so permission screens never block on system sheets we
        // can't fully script (HealthKit).
        let primaryCTAs = [
            // StoreKit review sheet (sim) — dismiss before anything else.
            // Run-2 failure mode: tapping "loving it" fired the sheet and
            // its star buttons went stale mid-enumeration (race).
            "Not Now",
            // the pre-paywall review gate — "yes" advances (native sheet
            // is suppressed in the sim).
            "yes, loving it",
            "skip for now", "Maybe later", "not right now", "not yet",
            "yeah, that's me",
            "i agree", "i'm in", "i want this version",
            "show me my plan", "show me how it feels",
            "continue", "Continue",
            "see your plan", "let's go", "start now", "connected",
            // v5 fear-resolution beat (also on the legacy path, where it
            // replaced the pre-wall rating ask).
            "keep going",
            "allow notifications",
        ]

        // Ruler screens — drag to realistic values so the loss-goal
        // branches go live (goal annotation states, pace live dates,
        // projection). Drag LEFT = increase, RIGHT = decrease.
        var draggedCurrentWeight = false
        var draggedGoalWeight = false
        var snappedHuddle = false
        var snappedRealisticTarget = false
        func rulerDrag(fromX: CGFloat, toX: CGFloat) {
            let ruler = app.otherElements["biometric_ruler"].firstMatch
            let start: XCUICoordinate
            let end: XCUICoordinate
            if ruler.exists {
                start = ruler.coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: 0.5))
                end = ruler.coordinate(withNormalizedOffset: CGVector(dx: toX, dy: 0.5))
            } else {
                start = app.coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: 0.585))
                end = app.coordinate(withNormalizedOffset: CGVector(dx: toX, dy: 0.585))
            }
            start.press(forDuration: 0.05, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.6)
        }
        func headlineContains(_ needle: String) -> Bool {
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", needle)
            ).firstMatch.exists
        }

        let deadline = Date().addingTimeInterval(420)
        var lastSignature = ""
        var stuckCount = 0

        while Date() < deadline {
            // Nudge the interruption monitor with a harmless tap in the
            // status-bar dead zone (never hits content).
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.012)).tap()

            // Hard paywall = end state.
            if app.buttons["terms"].exists || app.staticTexts["terms"].exists {
                snap("paywall")
                break
            }

            // Screen signature for change detection / stuck detection.
            let sig = app.staticTexts.allElementsBoundByIndex.prefix(4)
                .map(\.label).joined(separator: "|")
            if sig == lastSignature {
                stuckCount += 1
            } else {
                stuckCount = 0
                lastSignature = sig
                snap("screen")
            }
            if stuckCount > 15 {
                snap("stuck")
                XCTFail("walker stuck on: \(sig)")
                break
            }

            // 1. Name field — type, dismiss keyboard via return.
            let field = app.textFields.firstMatch
            if field.exists && field.isHittable {
                field.tap()
                field.typeText("ana\n")
                Thread.sleep(forTimeInterval: 0.4)
            }

            // 1.5 Weight rulers — set current up ~22 lb, goal down ~14 lb
            //     (≈8-9% loss → live projection/annotation states).
            if !draggedCurrentWeight && headlineContains("current weight") {
                rulerDrag(fromX: 0.78, toX: 0.34)
                draggedCurrentWeight = true
                snap("current_weight_dragged")
            }
            if !draggedGoalWeight && headlineContains("goal weight") {
                rulerDrag(fromX: 0.36, toX: 0.64)
                draggedGoalWeight = true
                snap("goal_weight_dragged")
            }

            // 1.6 Dwell-snap screens the signature pass misses: their
            //     CTA is hittable from frame one, so the generic loop
            //     taps through before content (cascade / transition)
            //     is visible. Detect by headline, wait out the
            //     animation, snap explicitly.
            if !snappedHuddle && headlineContains("already inside") {
                Thread.sleep(forTimeInterval: 1.2)
                snap("cohort_huddle")
                snappedHuddle = true
            }
            if !snappedRealisticTarget && headlineContains("dramatic number") {
                Thread.sleep(forTimeInterval: 1.6)
                snap("realistic_target")
                snappedRealisticTarget = true
            }

            // 2. Tap the first available CTA from the preference list.
            var advanced = false
            for label in primaryCTAs {
                let b = app.buttons[label]
                if b.exists && b.isHittable && b.isEnabled {
                    b.tap()
                    advanced = true
                    break
                }
            }
            if advanced {
                Thread.sleep(forTimeInterval: 0.9)
                continue
            }

            // 3. No enabled CTA → select the first plausible option row
            //    (enables the docked continue for the next iteration).
            let banned: Set<String> = ["continue", "Continue", "Back", "sources", "terms", "privacy", "loving it"]
            let options = app.buttons.allElementsBoundByIndex.filter {
                $0.isHittable && !banned.contains($0.label) && !$0.label.isEmpty
                    && !$0.label.lowercased().contains("star")
            }
            if let first = options.first {
                first.tap()
                Thread.sleep(forTimeInterval: 0.7)
                continue
            }

            // 4. Nothing tappable (divider dwell / loader) — wait.
            Thread.sleep(forTimeInterval: 1.5)
        }

        snap("final")
    }
}

// v1.1 release QA (2026-06-12) — in-app core-flow walker.
//
// Pairs --uitest-inapp-qa (completed onboarding, program flags reset)
// with --uitest-pro-access (DEBUG entitlement) and walks the chains
// this release touched: program intro cover → setup subflow → PlanView
// first-run hint → move row → PreRoutine brief → LIVE session start →
// end → breathe row intro → becoming tab. Screenshot per beat.
//
//   xcodebuild test -project plankAI.xcodeproj -scheme plankAI \
//     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//     -only-testing:plankAIUITests/InAppQAUITests

final class InAppQAUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testWalkCoreInAppFlows() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-inapp-qa", "--uitest-pro-access"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "system alerts") { alert in
            for label in ["Allow", "Allow Once", "OK", "Don't Allow"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }

        var shot = 0
        func snap(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = String(format: "%02d_%@", shot, name)
            attachment.lifetime = .keepAlways
            add(attachment)
            shot += 1
        }

        // Splash dwell (1.8s floor + crossfade).
        Thread.sleep(forTimeInterval: 4.0)

        // ── Program intro cover (existing-user opt-in) ──
        let startProgram = app.buttons["start my program"]
        if startProgram.waitForExistence(timeout: 8) {
            Thread.sleep(forTimeInterval: 0.8)   // entrance settle
            snap("program_intro_cover")
            startProgram.tap()

            // ── Setup subflow: goalDateReveal → intensityPick → commitment ──
            for label in ["see your options", "continue", "i'm in"] {
                let b = app.buttons[label]
                if b.waitForExistence(timeout: 6) {
                    Thread.sleep(forTimeInterval: 0.8)
                    snap("setup_\(label.replacingOccurrences(of: " ", with: "_"))")
                    b.tap()
                }
            }
            Thread.sleep(forTimeInterval: 1.5)
        }

        // ── PlanView with first-run hint ──
        snap("plan_view_first_run")
        XCTAssertTrue(
            app.staticTexts["move"].firstMatch.waitForExistence(timeout: 6),
            "PlanView move row missing — plan was not created"
        )

        // ── Workout chain: row → brief → LIVE session ──
        // v10.1: the front page leads with the figure; the day's
        // rows live past the fold — bring them up before tapping.
        if !app.staticTexts["move"].firstMatch.isHittable { app.swipeUp() }
        app.staticTexts["move"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1.2)
        snap("preroutine_brief")
        let startWorkout = app.buttons["start workout"]
        XCTAssertTrue(startWorkout.waitForExistence(timeout: 5), "start workout CTA missing")
        startWorkout.tap()
        Thread.sleep(forTimeInterval: 3.0)
        snap("routine_session_live")
        // The bug this release fixed: tapping start used to do nothing.
        XCTAssertFalse(
            app.buttons["start workout"].exists,
            "still on PreRoutineView — session never started"
        )

        // End the session via the end-workout control + confirm alert.
        let endButton = app.buttons["End workout"]
        if endButton.waitForExistence(timeout: 4) {
            endButton.tap()
            let endConfirm = app.alerts.buttons["End"]
            if endConfirm.waitForExistence(timeout: 3) { endConfirm.tap() }
            Thread.sleep(forTimeInterval: 1.5)
            snap("post_session_or_plan")
            // Post-routine screen (below-threshold copy) — dismiss via
            // any primary CTA if present.
            for label in ["done", "back home", "continue", "keep going", "not today"] {
                let b = app.buttons[label]
                if b.exists && b.isHittable { b.tap(); Thread.sleep(forTimeInterval: 1.0); break }
            }
        }

        // ── Breathwork intro (perfume accent) ──
        let breathe = app.staticTexts["breathe"].firstMatch
        if breathe.waitForExistence(timeout: 5) {
            if !breathe.isHittable { app.swipeUp() }
            breathe.tap()
            Thread.sleep(forTimeInterval: 1.2)
            snap("breathwork_intro")
            let close = app.buttons["Close"].firstMatch
            if close.exists { close.tap(); Thread.sleep(forTimeInterval: 0.8) }
        }

        // ── Becoming tab (steps tile, recap surfaces) ──
        let becomingTab = app.tabBars.buttons["becoming"]
        if becomingTab.waitForExistence(timeout: 4) {
            becomingTab.tap()
            Thread.sleep(forTimeInterval: 1.5)
            snap("becoming_tab")
        }

        snap("final_state")
    }

    /// The Jeni release (1.2.0) fix: Home had no VISIBLE way to reach
    /// settings — only an undiscoverable long-press on the dateline.
    /// This proves the masthead gear exists, is hittable, and opens
    /// the profile hub. Enrolls through the onramp (no seed needed).
    func testHomeSettingsAccess() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-inapp-qa", "--uitest-pro-access"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "system alerts") { alert in
            for label in ["Allow", "Allow Once", "OK", "Don't Allow"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }
        Thread.sleep(forTimeInterval: 4.0)

        // Enroll through the onramp so PlanView (with the masthead) renders.
        let startProgram = app.buttons["start my program"]
        if startProgram.waitForExistence(timeout: 8) {
            Thread.sleep(forTimeInterval: 0.8)
            startProgram.tap()
            for label in ["see your options", "continue", "i'm in"] {
                let b = app.buttons[label]
                if b.waitForExistence(timeout: 6) { Thread.sleep(forTimeInterval: 0.7); b.tap() }
            }
            Thread.sleep(forTimeInterval: 1.5)
        }

        XCTAssertTrue(
            app.staticTexts["move"].firstMatch.waitForExistence(timeout: 8),
            "PlanView didn't render — can't verify the masthead"
        )

        // The visible settings control.
        let settings = app.buttons["settings"].firstMatch
        XCTAssertTrue(
            settings.waitForExistence(timeout: 4),
            "no visible settings control on Home"
        )
        XCTAssertTrue(settings.isHittable, "settings control isn't tappable")

        let masthead = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        masthead.name = "00_home_with_settings_gear"
        masthead.lifetime = .keepAlways
        add(masthead)

        settings.tap()
        Thread.sleep(forTimeInterval: 1.2)

        // ProfileHub is open — the "your account" hub row / close proves it.
        let hubOpened = app.staticTexts["settings"].firstMatch.waitForExistence(timeout: 4)
            || app.buttons["Close"].firstMatch.exists
            || app.scrollViews.firstMatch.exists
        let opened = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        opened.name = "01_settings_opened"
        opened.lifetime = .keepAlways
        add(opened)
        XCTAssertTrue(hubOpened, "tapping settings didn't open the profile hub")
    }

    /// Settings drawer walk — hub + every sub-screen, one screenshot
    /// per beat. Enrolls first (the QA launch arg resets program flags).
    func testWalkSettingsScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-inapp-qa", "--uitest-pro-access"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "system alerts") { alert in
            for label in ["Allow", "Allow Once", "OK", "Don't Allow"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }

        var shot = 0
        func snap(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = String(format: "%02d_%@", shot, name)
            attachment.lifetime = .keepAlways
            add(attachment)
            shot += 1
        }
        // Status-bar dead-zone tap — nudges the interruption monitor
        // so a pending permission alert gets dismissed.
        func nudgeAlerts() {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.012)).tap()
        }

        Thread.sleep(forTimeInterval: 4.0)

        // Enroll through the onramp to reach PlanView.
        let startProgram = app.buttons["start my program"]
        if startProgram.waitForExistence(timeout: 8) {
            startProgram.tap()
            for label in ["see your options", "continue", "i'm in"] {
                let b = app.buttons[label]
                if b.waitForExistence(timeout: 6) {
                    Thread.sleep(forTimeInterval: 0.9)   // entrance settle
                    b.tap()
                }
                nudgeAlerts()
            }
            Thread.sleep(forTimeInterval: 1.5)
            nudgeAlerts()
        }

        // Mission 3 — the quiet mark retired with the masthead
        // chrome; the hub opens via the dateline's long-press.
        let settings = app.buttons["jeni.line"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 6), "settings entry (dateline) missing")
        settings.press(forDuration: 1.0)
        Thread.sleep(forTimeInterval: 1.4)
        snap("settings_hub")

        // Walk each sub-screen: row label → screenshot → back. Rows
        // with a trailing value compose it into the label, so match
        // by prefix.
        for row in ["my pace", "coach", "reminders", "account", "feedback"] {
            let rowButton = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", row)
            ).firstMatch
            guard rowButton.waitForExistence(timeout: 4) else {
                XCTFail("hub row \(row) missing"); continue
            }
            rowButton.tap()
            Thread.sleep(forTimeInterval: 1.2)
            snap("settings_\(row.replacingOccurrences(of: " ", with: "_"))")
            let back = app.buttons["back"].firstMatch
            if back.waitForExistence(timeout: 3) { back.tap(); Thread.sleep(forTimeInterval: 0.8) }
        }

        snap("settings_final")
    }

    /// v1.1 regression check (2026-06-24) — the settings drawer X-button
    /// close must ANIMATE (system slide-down), not cut instantly. Before
    /// the fix, `onClose` routed through a `disablesAnimations` transaction
    /// so the drawer vanished in one frame. This walks open → X-close twice
    /// and snaps rapid frames right after the tap: a working slide shows the
    /// drawer at progressively lower positions; an instant cut would show
    /// PlanView already restored on the very first post-tap frame. Pair with
    /// a concurrent `simctl io recordVideo` for the definitive motion capture.
    func testSettingsCloseAnimation() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-inapp-qa", "--uitest-pro-access"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "system alerts") { alert in
            for label in ["Allow", "Allow Once", "OK", "Don't Allow"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }

        var shot = 0
        func snap(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = String(format: "%02d_%@", shot, name)
            attachment.lifetime = .keepAlways
            add(attachment)
            shot += 1
        }
        func nudgeAlerts() {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.012)).tap()
        }

        Thread.sleep(forTimeInterval: 4.0)

        // Enroll through the onramp to reach PlanView (QA arg resets flags).
        let startProgram = app.buttons["start my program"]
        if startProgram.waitForExistence(timeout: 8) {
            startProgram.tap()
            for label in ["see your options", "continue", "i'm in"] {
                let b = app.buttons[label]
                if b.waitForExistence(timeout: 6) {
                    Thread.sleep(forTimeInterval: 0.9)
                    b.tap()
                }
                nudgeAlerts()
            }
            Thread.sleep(forTimeInterval: 1.5)
            nudgeAlerts()
        }

        let settings = app.buttons["jeni.line"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 6), "settings entry (dateline) missing")

        // Two open → X-close cycles so the close animation is captured on
        // the concurrent screen recording and the rapid stills below.
        for cycle in 0..<2 {
            settings.press(forDuration: 1.0)
            Thread.sleep(forTimeInterval: 2.0)
            snap("\(cycle)_open")

            let close = app.buttons["close"].firstMatch
            XCTAssertTrue(close.waitForExistence(timeout: 4), "close (X) button missing")
            close.tap()
            // Rapid post-tap frames — sample the slide-down in flight.
            snap("\(cycle)_close_t0")
            snap("\(cycle)_close_t1")
            snap("\(cycle)_close_t2")
            snap("\(cycle)_close_t3")
            Thread.sleep(forTimeInterval: 2.0)   // settle before the next cycle
            snap("\(cycle)_settled")
        }
    }
}

// MARK: - SnapCarouselUITests — 3-slide result carousel swipe QA
//
// v1.2 (2026-07-02) — drives the restored result carousel in the
// ResultCarouselPreviewHarness: swipe across plate → note → share and
// back, then confirm an in-panel control (fraction chip) still taps
// after the carousel wrap. Run with a concurrent sim video recording
// for frame-by-frame transition review.
final class SnapCarouselUITests: XCTestCase {

    func testSwipeAcrossCarouselSlides() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--debug-result-carousel"]
        app.launch()

        Thread.sleep(forTimeInterval: 2.8)     // rise-in + cascade settle

        app.swipeLeft()                        // plate → note
        Thread.sleep(forTimeInterval: 1.8)     // sparkles twinkle on video
        app.swipeLeft()                        // note → share
        Thread.sleep(forTimeInterval: 1.8)
        app.swipeRight()                       // share → note
        Thread.sleep(forTimeInterval: 1.2)
        app.swipeRight()                       // note → plate
        Thread.sleep(forTimeInterval: 1.2)

        // The carousel wrap must not eat taps inside the panel.
        let half = app.buttons["ate about half"]
        XCTAssertTrue(half.waitForExistence(timeout: 3), "fraction chip missing after swipes")
        half.tap()
        Thread.sleep(forTimeInterval: 1.2)     // kcal roll on video
    }
}

// MARK: - Onboarding v5 walker (2026-07-02)
//
// Deterministic beat-by-beat walk of the v5 flow (typed state machine,
// cross-off auto-advance, rulers, snap demo, care cluster, reveal) from
// welcome to the hard paywall, one screenshot per beat. Cohort variant
// via GLP1_COHORT env (none | current | past | considering).
//
//   xcodebuild test -project plankAI.xcodeproj -scheme plankAI \
//     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//     -only-testing:plankAIUITests/OnboardingV5WalkerUITests
final class OnboardingV5WalkerUITests: XCTestCase {

    /// v8 Stage A — the iOS 26.2 sim raises SpringBoard nags
    /// ("Apple Account Required") mid-run; unhandled, they occlude
    /// every tap while label queries keep failing and the walker
    /// walks the void. Dismiss anything dismissible.
    private func installSystemAlertMonitor() {
        addUIInterruptionMonitor(withDescription: "system alerts") { alert in
            for label in ["Not Now", "Later", "Cancel", "Don't Allow", "OK"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }
    }

    private var app: XCUIApplication!
    private var shot = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d_%@", shot, name)
        attachment.lifetime = .keepAlways
        add(attachment)
        shot += 1
    }

    /// Wait for a HITTABLE button whose label CONTAINS the needle (the
    /// two-beat entrance holds elements at opacity 0 — they exist before
    /// they can be hit), snap, tap. Multi-select chips + toggling rows
    /// pass `retryIfPresent: false` so a retap can't undo them; advance-
    /// class buttons retry once when the tap didn't take (cold-launch
    /// first-tap race).
    @discardableResult
    private func tapButton(_ needle: String, shotName: String? = nil,
                           timeout: TimeInterval = 10, settle: TimeInterval = 1.0,
                           retryIfPresent: Bool = false,
                           exact: Bool = false) -> Bool {
        // `exact` exists for labels that are substrings of their
        // neighbors — "male" CONTAINS-matches "female" first, which
        // sent the male persona leg down the female path.
        let b = app.buttons.matching(
            NSPredicate(format: exact ? "label ==[c] %@" : "label CONTAINS[c] %@", needle)
        ).firstMatch
        // Wait on EXISTS only — cheap snapshot. isHittable evaluation
        // can hang or false-negative under indefinite animations
        // (welcome's demo cycle + sticker float), which burned whole
        // walks on the slower 16e sim.
        guard b.waitForExistence(timeout: timeout) else {
            snap("MISSING_\(needle.replacingOccurrences(of: " ", with: "_"))")
            return false
        }
        if let shotName { Thread.sleep(forTimeInterval: 0.55); snap(shotName) }
        if b.isHittable {
            b.tap()
        } else {
            // Coordinate-tap the element's frame center directly —
            // bypasses the hittability gate XCUI applies to tap().
            let f = b.frame
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: f.midX, dy: f.midY))
                .tap()
        }
        Thread.sleep(forTimeInterval: settle)
        if retryIfPresent, b.exists, b.isHittable {
            b.tap()
            Thread.sleep(forTimeInterval: settle)
        }
        return true
    }

    /// Receipts / bridges advance on a whole-surface tap. Marker-strict:
    /// when the expected screen never appears we do NOT blind-tap the
    /// center (a stray center-tap on a stalled screen can toggle
    /// answers — the run-5 SCOFF corruption).
    private func tapThrough(_ shotName: String, marker: String, settle: TimeInterval = 1.0) {
        let m = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", marker)
        ).firstMatch
        guard m.waitForExistence(timeout: 10) else {
            snap("MISSING_\(shotName)")
            return
        }
        Thread.sleep(forTimeInterval: 0.9)
        snap(shotName)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: settle)
    }

    private func dragRuler(fromX: CGFloat, toX: CGFloat) {
        let ruler = app.otherElements["biometric_ruler"].firstMatch
        let host: XCUIElement = ruler.exists ? ruler : app
        let start = host.coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: 0.5))
        let end = host.coordinate(withNormalizedOffset: CGVector(dx: toX, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        Thread.sleep(forTimeInterval: 0.7)
    }

    func testWalkV5ToPaywall() throws {
        app = XCUIApplication()
        app.launchArguments += ["--uitest-fresh-onboarding"]
        installSystemAlertMonitor()
        let cohort = ProcessInfo.processInfo.environment["GLP1_COHORT"] ?? "none"
        // v7 persona legs: GENDER=female|male|nonbinary|private
        // (default female). The male leg must route around hormonal +
        // pregnancy (D2) — the walker asserts the absence by walking
        // the gap.
        let gender = ProcessInfo.processInfo.environment["GENDER"] ?? "female"
        let genderTap = [
            "female": "female", "male": "male",
            "nonbinary": "non-binary", "private": "prefer not to say",
        ][gender] ?? "female"
        app.launch()

        addUIInterruptionMonitor(withDescription: "system alerts") { alert in
            for label in ["Allow", "Allow Once", "OK", "Don't Allow", "Not Now"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }

        // act i — her arrival. The welcome runs two indefinite
        // animations (device-demo cycle + sticker float), so element
        // polls during the launch window can block on quiescence —
        // wait for foreground, settle flat (the diag test's dodge),
        // then a generous first timeout (cold first-launch on a
        // freshly booted sim can be slow: auth bootstrap + fonts).
        _ = app.wait(for: .runningForeground, timeout: 30)
        Thread.sleep(forTimeInterval: 6.0)
        tapButton("continue", shotName: "welcome", timeout: 40, settle: 1.6, retryIfPresent: true)
        tapButton("makes sense", shotName: "antiShame")
        tapButton("quiet the food noise", shotName: "outcome")
        tapButton("tiktok", shotName: "attribution")
        tapThrough("credibility", marker: "built differently")
        // name — type, then continue
        let nameField = app.textFields.firstMatch
        if nameField.waitForExistence(timeout: 8) {
            Thread.sleep(forTimeInterval: 0.8)
            snap("name")
            nameField.tap()
            // "ben" is the founder's own male-walk persona (the
            // 08-01 device walk this work answers).
            nameField.typeText(gender == "male" ? "ben" : "maya")
        }
        tapButton("continue", settle: 1.2)

        // act ii — glp1 status fork
        switch cohort {
        case "current":
            tapButton("yes, i'm on one", shotName: "glp1Status", settle: 0.6)
            tapButton("continue", settle: 1.2)
            tapButton("a few months in", shotName: "glp1Phase", settle: 0.6)
            tapButton("continue", settle: 1.2)
            tapButton("late week", shotName: "appetiteRhythm")
            // v8 Stage A — the clinical shot-day beat (current
            // cohort only): pick sunday, continue.
            tapButton("sunday", shotName: "shotDay", settle: 0.5)
            tapButton("continue", settle: 1.2)
            tapButton("continue", shotName: "muscleMath")
        case "past":
            tapButton("i was. not anymore", shotName: "glp1Status", settle: 0.6)
            tapButton("continue", settle: 1.2)
            tapButton("3 to 6 months", shotName: "stopWindow", settle: 0.6)
            tapButton("continue", settle: 1.2)
            tapButton("creeping back", shotName: "appetiteReturn")
            tapButton("continue", shotName: "regainTruth")
        case "considering":
            tapButton("thinking about it", shotName: "glp1Status", settle: 0.6)
            tapButton("continue", settle: 1.2)
            tapButton("continue", shotName: "consideringAgency")
        default:
            tapButton("no", shotName: "glp1Status", settle: 0.6)
            tapButton("continue", settle: 1.2)
        }

        // food story
        tapButton("comfort", shotName: "foodRelationship")
        tapButton("continue", shotName: "foodNoise")
        tapButton("show me", shotName: "preEat")

        // snap demo (founder plates: poke is the marquee)
        let poke = app.buttons["demo_meal_poke"].firstMatch
        if poke.waitForExistence(timeout: 8) {
            Thread.sleep(forTimeInterval: 0.9)
            snap("snapDemo_pick")
            poke.tap()
            Thread.sleep(forTimeInterval: 1.2)
            snap("snapDemo_scanning")
            Thread.sleep(forTimeInterval: 1.6)
            snap("snapDemo_result")
        }
        tapButton("day one, you do this for real", settle: 1.2)

        tapButton("3 steady meals", shotName: "eatingCadence")
        // v7 D3 — proteinRule teach rides every non-current cohort in
        // priorWin's old slot (current already had muscleMath).
        if cohort != "current" {
            tapButton("continue", shotName: "proteinRule")
        }
        // cuisine chips (multi) + continue
        tapButton("korean", shotName: "cuisine", settle: 0.3)
        tapButton("italian", settle: 0.3)
        tapButton("continue", settle: 1.2)
        tapButton("none of these", shotName: "dietary", settle: 0.4)
        tapButton("continue", settle: 1.2)
        // v8 Stage A — the supports single-ask (all branches):
        // "none of these" exercises the skip-equivalent path.
        tapButton("none of these", shotName: "supports", settle: 0.4)
        tapButton("continue", settle: 1.2)
        tapThrough("receiptFood", marker: "food story")

        // act iii — numbers
        tapThrough("numbersBridge", marker: "sixty seconds")
        tapButton("walks here and there", shotName: "movement")
        tapButton("5 to 6", shotName: "sleep")
        tapButton("manageable", shotName: "stress")
        tapButton(genderTap, shotName: "gender", exact: true)
        // age ruler
        Thread.sleep(forTimeInterval: 0.8); snap("age")
        dragRuler(fromX: 0.5, toX: 0.42)
        tapButton("continue", settle: 1.0)
        // height ruler
        Thread.sleep(forTimeInterval: 0.8); snap("height")
        tapButton("continue", settle: 1.0)
        // weight ruler — drag left = increase; commit twice (confirmation beat)
        Thread.sleep(forTimeInterval: 0.8); snap("weight")
        dragRuler(fromX: 0.6, toX: 0.35)
        tapButton("that's me", settle: 1.6)
        snap("weight_confirmed")
        Thread.sleep(forTimeInterval: 0.8)
        tapButton("up and down", shotName: "weightTrend")
        tapButton("lose weight", shotName: "goalDirection")
        // goal ruler — drag right = decrease toward goal
        Thread.sleep(forTimeInterval: 0.9); snap("goalWeight")
        dragRuler(fromX: 0.4, toX: 0.62)
        snap("goalWeight_band")
        tapButton("continue", settle: 1.2)
        tapButton("continue", shotName: "targetReframe")
        tapButton("energy that lasts", shotName: "nsv", settle: 0.3)
        tapButton("clothes that fit right", settle: 0.3)
        tapButton("continue", settle: 1.2)
        tapThrough("careBridge", marker: "care part")
        tapButton("no", shotName: "medication", settle: 0.5)
        tapButton("continue", settle: 1.2)

        // safety gate: pregnancy → SCOFF (all no) → passes. The male
        // persona starts at SCOFF (D2 — no pregnancy screen). The 5
        // SCOFF items overflow the fold — answer visible rows, scroll,
        // repeat until the docked continue enables.
        if gender != "male" {
            tapButton("none of these", shotName: "gate_pregnancy", settle: 0.4)
            tapButton("continue", settle: 1.2)
        }
        Thread.sleep(forTimeInterval: 0.8)
        snap("gate_scoff")
        for round in 0..<5 {
            let nos = app.buttons.matching(NSPredicate(format: "label == %@", "no"))
                .allElementsBoundByIndex
            for b in nos where b.exists && b.isHittable {
                b.tap(); Thread.sleep(forTimeInterval: 0.12)
            }
            let cont = app.buttons["continue"].firstMatch
            if cont.exists && cont.isEnabled { break }
            if round < 4 {
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.6)
            }
        }
        snap("gate_scoff_answered")
        tapButton("continue", settle: 1.6)
        tapThrough("receiptNumbers", marker: "carry")

        // act iv — the part nobody asks. The male persona routes
        // identity → startedOver (D2 — hormonal is cycle-stage-only).
        tapButton("calm", shotName: "identity", settle: 1.0)
        if gender != "male" {
            tapButton("cycling regularly", shotName: "hormonal", settle: 0.5)
            tapButton("continue", settle: 1.2)
        }
        tapButton("lost count", shotName: "startedOver", settle: 2.0)
        tapThrough("dataMirror", marker: "truth")
        tapButton("yes, that's me", shotName: "fear1", settle: 1.2)
        tapButton("not really", shotName: "fear2", settle: 1.2)
        tapButton("yes, that's me", shotName: "fear3", settle: 1.2)
        tapButton("this is the one", shotName: "whyItCameBack")
        tapThrough("receiptCarry", marker: "almost")

        // act v — almost hers
        tapButton("this is me", shotName: "herFile")
        // signature: nothing pre-checked (round 2) — sign all three.
        tapButton("use my answers", shotName: "signature", settle: 0.3, retryIfPresent: false)
        tapButton("check on me", settle: 0.3, retryIfPresent: false)
        tapButton("i know this is a plan", settle: 0.4, retryIfPresent: false)
        snap("signature_signed")
        tapButton("signed", settle: 1.2)
        tapButton("not now", shotName: "healthKit", settle: 1.2)
        // hold to build
        Thread.sleep(forTimeInterval: 0.9)
        snap("holdToBuild")
        let holdButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "hold to build")
        ).firstMatch
        if holdButton.waitForExistence(timeout: 6) {
            holdButton.press(forDuration: 1.8)
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88)).press(forDuration: 1.8)
        }
        Thread.sleep(forTimeInterval: 1.5)

        // reveal: building → pace → projection → firstWeek →
        // fearResolution → commitment → permissions → wall.
        // The ATT dialog fires ~30% into the loader; interruption
        // monitors don't trigger on existence polls, so dismiss it
        // directly on springboard.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        Thread.sleep(forTimeInterval: 3.0)
        snap("building")
        let attAllow = springboard.buttons["Allow"]
        let attDeny = springboard.buttons["Ask App Not to Track"]
        if attAllow.waitForExistence(timeout: 6) {
            attAllow.tap()
        } else if attDeny.exists {
            attDeny.tap()
        }
        Thread.sleep(forTimeInterval: 1.0)
        snap("building_tape")
        tapButton("see your plan", shotName: "building_done", timeout: 30, settle: 1.6)
        tapButton("steady", shotName: "pacePicker", settle: 0.6)
        tapButton("continue", settle: 1.6)
        Thread.sleep(forTimeInterval: 1.4)
        snap("projection")
        // projection's continue label varies; try common ones
        if !tapButton("continue", timeout: 4, settle: 1.4) {
            _ = tapButton("keep", timeout: 3, settle: 1.4)
        }
        Thread.sleep(forTimeInterval: 1.0)
        snap("firstWeek")
        if !tapButton("continue", timeout: 4, settle: 1.4) {
            _ = tapButton("let's go", timeout: 3, settle: 1.4)
        }
        // review gate (pre-paywall, after firstWeek — eligible on a
        // fresh walk since --uitest-fresh-onboarding clears the flag).
        // "yes" fires the native sheet (suppressed in sim) and advances.
        Thread.sleep(forTimeInterval: 1.0)
        _ = tapButton("loving it", shotName: "reviewGate", timeout: 6, settle: 1.6)
        // The native StoreKit review sheet is NOT suppressed on the
        // iOS 26.2 sim — it fires on fresh installs (once-guard clean)
        // and absorbs every later tap; the male P1 leg stalled on it
        // through the "paywall" shot. Dismiss it in-process.
        _ = tapButton("Not Now", timeout: 4, settle: 1.0)
        // fear resolution (fires because fear1/fear3 = yes)
        Thread.sleep(forTimeInterval: 1.0)
        snap("fearResolution")
        _ = tapButton("keep going", timeout: 6, settle: 1.4)

        // commitment ritual: nothing pre-picked (round 2) — choose
        // when + what + time, then hold-to-promise.
        Thread.sleep(forTimeInterval: 1.2)
        snap("commitment")
        tapButton("after i wake up", settle: 0.35, retryIfPresent: false)
        tapButton("log breakfast", settle: 0.35, retryIfPresent: false)
        tapButton("8am", settle: 0.6, retryIfPresent: false)
        snap("commitment_built")
        let promiseHold = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "seal your promise")
        ).firstMatch
        if promiseHold.waitForExistence(timeout: 6) {
            promiseHold.press(forDuration: 1.9)
        }
        Thread.sleep(forTimeInterval: 1.6)

        // permissions (notification mock) → wall
        snap("permissions")
        for label in ["allow notifications", "not right now", "maybe later", "continue"] {
            if tapButton(label, timeout: 3, settle: 1.0) { break }
        }
        // The real iOS notification permission alert.
        let notifAllow = springboard.buttons["Allow"]
        if notifAllow.waitForExistence(timeout: 5) { notifAllow.tap() }

        // hard paywall = end state
        Thread.sleep(forTimeInterval: 3.0)
        snap("paywall")
    }

    // MARK: - v8 THE CONSULT walker (docs/onboarding_v8)
    //
    // Drives the conversational flow end-to-end. The consult types at
    // real cadence and statement beats auto-advance, so this leg
    // mostly WAITS for the next answerable element — generous
    // timeouts are the design, not slack. Cohort legs via
    // GLP1_COHORT (none|current|past|considering), persona via
    // GENDER (female|male|nonbinary|private).
    func testWalkV8ToPaywall() throws {
        app = XCUIApplication()
        app.launchArguments += ["--uitest-fresh-onboarding"]
        installSystemAlertMonitor()
        let cohort = ProcessInfo.processInfo.environment["GLP1_COHORT"] ?? "none"
        let gender = ProcessInfo.processInfo.environment["GENDER"] ?? "female"
        let genderTap = [
            "female": "female", "male": "male",
            "nonbinary": "non-binary", "private": "prefer not to say",
        ][gender] ?? "female"
        app.launch()

        addUIInterruptionMonitor(withDescription: "system alerts") { alert in
            for label in ["Allow", "Allow Once", "OK", "Don't Allow", "Not Now"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }

        // act 0 — arrival (ink): mark wipes on, cascade, begin.
        _ = app.wait(for: .runningForeground, timeout: 30)
        Thread.sleep(forTimeInterval: 5.0)
        tapButton("begin", shotName: "arrival", timeout: 40, settle: 1.2, retryIfPresent: true)

        // the door: weight-loss users skip the clinic fork in one tap.
        tapButton("no, i'm here on my own", shotName: "door", timeout: 25, settle: 0.8)

        // act i — hello types (auto), then the name field arrives.
        let nameField = app.textFields.firstMatch
        if nameField.waitForExistence(timeout: 25) {
            Thread.sleep(forTimeInterval: 0.6)
            snap("name")
            if !nameField.hasFocus { nameField.tap() }
            nameField.typeText(gender == "male" ? "ben\n" : "maya\n")
        }
        Thread.sleep(forTimeInterval: 1.0)
        tapButton("quiet around food", shotName: "outcome", timeout: 20, settle: 0.8)
        tapButton("3 to 5 times", shotName: "history", timeout: 20, settle: 0.8)
        tapButton("comfort", shotName: "foodRelationship", timeout: 20, settle: 0.8)

        // the mirror chapter (ink) — cascade, then the CTA.
        tapButton("show me", shotName: "mirror", timeout: 25, settle: 1.4, retryIfPresent: true)

        // act ii — cohort fork.
        switch cohort {
        case "current":
            tapButton("yes, i'm on one", shotName: "glp1Status", timeout: 20, settle: 0.8)
            tapButton("a few months in", shotName: "glp1Phase", timeout: 20, settle: 0.8)
            tapButton("late week", shotName: "appetiteRhythm", timeout: 20, settle: 0.8)
            tapButton("sunday", shotName: "shotDay", timeout: 20, settle: 0.8)
            // muscleMath statements auto-advance into cadence.
        case "past":
            tapButton("i was. not anymore", shotName: "glp1Status", timeout: 20, settle: 0.8)
            tapButton("3 to 6 months", shotName: "stopWindow", timeout: 20, settle: 0.8)
            tapButton("creeping back", shotName: "appetiteReturn", timeout: 20, settle: 0.8)
        case "considering":
            tapButton("thinking about it", shotName: "glp1Status", timeout: 20, settle: 0.8)
            // considering statements auto-advance.
        default:
            tapButton("no", shotName: "glp1Status", timeout: 20, settle: 0.8)
        }

        tapButton("3 steady meals", shotName: "cadence", timeout: 30, settle: 0.8)
        tapButton("nothing off the table", shotName: "dietary", timeout: 20, settle: 0.8)
        tapButton("korean", shotName: "cuisine", timeout: 20, settle: 0.3, retryIfPresent: false)
        tapButton("italian", settle: 0.3, retryIfPresent: false)
        tapButton("continue", settle: 1.0)
        tapButton("none of these", shotName: "supports", timeout: 20, settle: 0.8)

        // demo intro auto-advances into the snap demo.
        let poke = app.buttons["demo_meal_poke"].firstMatch
        if poke.waitForExistence(timeout: 25) {
            Thread.sleep(forTimeInterval: 0.9)
            snap("snapDemo_pick")
            poke.tap()
            Thread.sleep(forTimeInterval: 1.2)
            snap("snapDemo_scanning")
            Thread.sleep(forTimeInterval: 1.6)
            snap("snapDemo_result")
        }
        tapButton("day one, you do this for real", settle: 1.0)

        // proteinRule (non-current) auto-advances; evidence chapter.
        tapButton("make it mine", shotName: "evidence", timeout: 35, settle: 1.4, retryIfPresent: true)

        // act iii — numbers. numbersLine auto-advances.
        walkV8NumbersAndClose(gender: gender, genderTap: genderTap, cohort: cohort, clinic: false)
    }

    /// v8 shared tail: the numbers act through the paywall. The clinic
    /// flow diverges only in act iv (no identity/fears/attribution).
    private func walkV8NumbersAndClose(gender: String, genderTap: String, cohort: String, clinic: Bool) {
        tapButton(genderTap, shotName: "gender", timeout: 25, settle: 1.0, exact: true)
        Thread.sleep(forTimeInterval: 1.2)
        snap("age")
        dragRuler(fromX: 0.5, toX: 0.42)
        tapButton("continue", settle: 1.0)
        Thread.sleep(forTimeInterval: 1.2)
        snap("height")
        tapButton("continue", settle: 1.0)
        Thread.sleep(forTimeInterval: 1.2)
        snap("weight")
        dragRuler(fromX: 0.6, toX: 0.35)
        tapButton("continue", settle: 1.0)
        // weight ack types before the next question.
        tapButton("up and down", shotName: "weightTrend", timeout: 25, settle: 0.8)
        tapButton("lose weight", shotName: "goalDirection", timeout: 20, settle: 0.8)
        Thread.sleep(forTimeInterval: 1.2)
        snap("goalWeight")
        dragRuler(fromX: 0.4, toX: 0.62)
        snap("goalWeight_band")
        tapButton("set it", settle: 1.0)
        // the reframe ack (computed weeks) types.
        tapButton("walks here and there", shotName: "movement", timeout: 25, settle: 0.8)
        tapButton("5 to 6", shotName: "sleep", timeout: 20, settle: 0.8)
        tapButton("manageable", shotName: "stress", timeout: 25, settle: 0.8)
        tapButton("energy that lasts", shotName: "nsv", timeout: 25, settle: 0.3, retryIfPresent: false)
        tapButton("clothes that fit right", settle: 0.3, retryIfPresent: false)
        tapButton("that's the list", settle: 1.0)
        tapButton("no", shotName: "medication", timeout: 25, settle: 0.8)

        // safety gate (structured; unchanged composition).
        if gender != "male" {
            tapButton("none of these", shotName: "gate_pregnancy", timeout: 25, settle: 0.4)
            tapButton("continue", settle: 1.2)
        }
        Thread.sleep(forTimeInterval: 0.8)
        snap("gate_scoff")
        for round in 0..<5 {
            let nos = app.buttons.matching(NSPredicate(format: "label == %@", "no"))
                .allElementsBoundByIndex
            for b in nos where b.exists && b.isHittable {
                b.tap(); Thread.sleep(forTimeInterval: 0.12)
            }
            let cont = app.buttons["continue"].firstMatch
            if cont.exists && cont.isEnabled { break }
            if round < 4 {
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.6)
            }
        }
        snap("gate_scoff_answered")
        tapButton("continue", settle: 1.6)

        // act iv — hormonal (non-male); the clinic flow goes straight
        // to the file (no identity / fears / attribution).
        if gender != "male" {
            tapButton("cycling regularly", shotName: "hormonal", timeout: 25, settle: 0.8)
        }
        if !clinic {
            tapButton("calm", shotName: "identity", timeout: 25, settle: 0.8)
            tapButton("i'm scared of apps", shotName: "fears", timeout: 25, settle: 0.4, retryIfPresent: false)
            if cohort == "current" {
                tapButton("what happens when i stop", settle: 0.4, retryIfPresent: false)
            } else if cohort == "past" {
                tapButton("it all comes back", settle: 0.4, retryIfPresent: false)
            } else {
                tapButton("given up after the first hard day", settle: 0.4, retryIfPresent: false)
            }
            snap("fears_struck")
            tapButton("that's mine", settle: 1.0)
            tapButton("tiktok", shotName: "attribution", timeout: 25, settle: 0.8)
        }

        // the file chapter (ink) — rows assemble, then sign.
        tapButton("sign it", shotName: "file", timeout: 30, settle: 1.4, retryIfPresent: true)

        // signature: nothing pre-checked — sign all three.
        tapButton("use my answers", shotName: "signature", timeout: 15, settle: 0.3, retryIfPresent: false)
        tapButton("check on me", settle: 0.3, retryIfPresent: false)
        tapButton("i know this is a plan", settle: 0.4, retryIfPresent: false)
        snap("signature_signed")
        tapButton("signed", settle: 1.2)
        tapButton("not now", shotName: "healthKit", timeout: 15, settle: 1.2)

        // hold to build
        Thread.sleep(forTimeInterval: 0.9)
        snap("holdToBuild")
        let holdButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "hold to build")
        ).firstMatch
        if holdButton.waitForExistence(timeout: 8) {
            holdButton.press(forDuration: 1.8)
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88)).press(forDuration: 1.8)
        }
        Thread.sleep(forTimeInterval: 1.5)

        // reveal chain — identical to the v5 leg from here.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        Thread.sleep(forTimeInterval: 3.0)
        snap("building")
        let attAllow = springboard.buttons["Allow"]
        let attDeny = springboard.buttons["Ask App Not to Track"]
        if attAllow.waitForExistence(timeout: 6) {
            attAllow.tap()
        } else if attDeny.exists {
            attDeny.tap()
        }
        Thread.sleep(forTimeInterval: 1.0)
        snap("building_tape")
        tapButton("see your plan", shotName: "building_done", timeout: 30, settle: 1.6)
        tapButton("steady", shotName: "pacePicker", settle: 0.6)
        tapButton("continue", settle: 1.6)
        Thread.sleep(forTimeInterval: 1.4)
        snap("projection")
        if !tapButton("continue", timeout: 4, settle: 1.4) {
            _ = tapButton("keep", timeout: 3, settle: 1.4)
        }
        Thread.sleep(forTimeInterval: 1.0)
        snap("firstWeek")
        if !tapButton("continue", timeout: 4, settle: 1.4) {
            _ = tapButton("let's go", timeout: 3, settle: 1.4)
        }
        Thread.sleep(forTimeInterval: 1.0)
        _ = tapButton("loving it", shotName: "reviewGate", timeout: 6, settle: 1.6)
        _ = tapButton("Not Now", timeout: 4, settle: 1.0)
        Thread.sleep(forTimeInterval: 1.0)
        snap("fearResolution")
        _ = tapButton("keep going", timeout: 6, settle: 1.4)

        Thread.sleep(forTimeInterval: 1.2)
        snap("commitment")
        tapButton("after i wake up", settle: 0.35, retryIfPresent: false)
        tapButton("log breakfast", settle: 0.35, retryIfPresent: false)
        tapButton("8am", settle: 0.6, retryIfPresent: false)
        snap("commitment_built")
        let promiseHold = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "seal your promise")
        ).firstMatch
        if promiseHold.waitForExistence(timeout: 6) {
            promiseHold.press(forDuration: 1.9)
        }
        Thread.sleep(forTimeInterval: 1.6)

        snap("permissions")
        for label in ["allow notifications", "not right now", "maybe later", "continue"] {
            if tapButton(label, timeout: 3, settle: 1.0) { break }
        }
        let notifAllow = springboard.buttons["Allow"]
        if notifAllow.waitForExistence(timeout: 5) { notifAllow.tap() }

        Thread.sleep(forTimeInterval: 3.0)
        snap("paywall")
    }

    // MARK: - v8 clinic door leg (docs/onboarding_v8 §9.3)
    //
    // Drives the clinician-code fork with the offline QA acceptor
    // (--uitest-clinic-code-accept), then the clinical-intake flow:
    // no conversion acts, straight to numbers, gate, file, close.
    func testWalkV8ClinicToPaywall() throws {
        app = XCUIApplication()
        app.launchArguments += ["--uitest-fresh-onboarding", "--uitest-clinic-code-accept"]
        installSystemAlertMonitor()
        app.launch()

        addUIInterruptionMonitor(withDescription: "system alerts") { alert in
            for label in ["Allow", "Allow Once", "OK", "Don't Allow", "Not Now"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }

        _ = app.wait(for: .runningForeground, timeout: 30)
        Thread.sleep(forTimeInterval: 5.0)
        tapButton("begin", shotName: "arrival", timeout: 40, settle: 1.2, retryIfPresent: true)

        tapButton("i have a clinician code", shotName: "door", timeout: 25, settle: 1.0)

        // the code field arrives in-conversation; the QA acceptor
        // short-circuits validation with "demo clinic".
        let codeField = app.textFields.firstMatch
        XCTAssertTrue(codeField.waitForExistence(timeout: 20), "code field never arrived")
        Thread.sleep(forTimeInterval: 0.6)
        snap("clinicCode")
        if !codeField.hasFocus { codeField.tap() }
        codeField.typeText("DEMO1234\n")

        // clinic welcome (statement) auto-advances into the name.
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 30), "name field never arrived")
        Thread.sleep(forTimeInterval: 0.6)
        snap("clinic_name")
        if !nameField.hasFocus { nameField.tap() }
        nameField.typeText("casey\n")

        // straight to the cohort question — no outcome/history/food.
        tapButton("no", shotName: "clinic_glp1", timeout: 30, settle: 0.8)
        tapButton("3 steady meals", shotName: "clinic_cadence", timeout: 30, settle: 0.8)
        tapButton("nothing off the table", timeout: 20, settle: 0.8)
        tapButton("korean", timeout: 20, settle: 0.3, retryIfPresent: false)
        tapButton("continue", settle: 1.0)
        tapButton("none of these", timeout: 20, settle: 0.8)

        // clinic skips demo + evidence: numbers arrive next.
        walkV8NumbersAndClose(gender: "female", genderTap: "female", cohort: "none", clinic: true)
    }
}

// Temporary diagnosis: dump the welcome element tree + frames, tap the
// CTA by element AND by coordinate, and report what the screen shows
// afterward. Deleted once the v5 walker is green.
final class OV5DiagUITests: XCTestCase {
    func testWelcomeTapDiagnosis() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-fresh-onboarding"]
        app.launch()
        Thread.sleep(forTimeInterval: 5.0)

        let ready = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "continue")
        ).firstMatch
        print("DIAG ready.exists=\(ready.exists) hittable=\(ready.exists ? ready.isHittable : false) frame=\(ready.exists ? "\(ready.frame)" : "-")")
        print("DIAG TREE-BEGIN")
        print(app.debugDescription.prefix(6000))
        print("DIAG TREE-END")

        if ready.exists { ready.tap() }
        Thread.sleep(forTimeInterval: 2.5)
        let okay = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "okay")
        ).firstMatch
        print("DIAG after-element-tap okay.exists=\(okay.exists)")

        if !okay.exists, ready.exists {
            // Coordinate tap at the button's visual center.
            ready.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            Thread.sleep(forTimeInterval: 2.5)
            print("DIAG after-coord-tap okay.exists=\(okay.exists)")
        }
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = "diag_final"; att.lifetime = .keepAlways
        add(att)
    }
}

// MARK: - KeepWallUITests (2026-07-07 no-trial keep-wall)
//
// Drives the rebuilt hard paywall through every decisive state:
//   1. testKeepWallStatesAndRecovery — the REAL wall (RootView phase
//      machine, RevenueCat offerings against the local StoreKit
//      configuration): tier selection, receipt-confirm, the ACTUAL
//      Apple/StoreKit purchase sheet, sheet-cancel → the tier-matched
//      recovery chain (quarterly → SmallerStepSheet → winback).
//   2. testKeepWallPricingFail — skeleton prices + failure row + the
//      CTA's retry state (--uitest-pricing-fail suppresses mocks).
//   3. testKeepWallDynamicTypeXXL — accessibility text-size safety.
//
//   xcodebuild test -project plankAI.xcodeproj -scheme plankAI \
//     -destination 'platform=iOS Simulator,name=iPhone 16e' \
//     -only-testing:plankAIUITests/KeepWallUITests
final class KeepWallUITests: XCTestCase {

    private var app: XCUIApplication!
    private var shot = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d_%@", shot, name)
        attachment.lifetime = .keepAlways
        add(attachment)
        shot += 1
    }

    @discardableResult
    private func tapButton(_ needle: String, shotName: String? = nil,
                           timeout: TimeInterval = 10, settle: TimeInterval = 1.0) -> Bool {
        let b = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", needle)
        ).firstMatch
        guard b.waitForExistence(timeout: timeout) else {
            snap("MISSING_\(needle.replacingOccurrences(of: " ", with: "_"))")
            return false
        }
        if let shotName { Thread.sleep(forTimeInterval: 0.55); snap(shotName) }
        if b.isHittable {
            b.tap()
        } else {
            let f = b.frame
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: f.midX, dy: f.midY))
                .tap()
        }
        Thread.sleep(forTimeInterval: settle)
        return true
    }

    /// The full keep-flow: wall → tier switches → receipt-confirm →
    /// StoreKit sheet → cancel → smaller-step recovery → winback.
    /// Defensive throughout: every miss snaps evidence and continues,
    /// so one flaky system sheet doesn't hide the rest of the flow.
    func testKeepWallStatesAndRecovery() throws {
        app = XCUIApplication()
        // Completed-onboarding, NOT entitled → AppPhase routes to
        // wall(.fresh) with PaymentService configured, so RevenueCat
        // resolves the live product IDs against the scheme's local
        // StoreKit configuration (real prices, real purchase sheet).
        app.launchArguments += ["--uitest-inapp-qa"]
        app.launch()

        _ = app.wait(for: .runningForeground, timeout: 30)

        // The wall. Prices arrive async (RC fetch) — wait on the CTA
        // carrying a resolved price ("keep my plan · $x today").
        let cta = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "keep my plan")
        ).firstMatch
        _ = cta.waitForExistence(timeout: 30)
        Thread.sleep(forTimeInterval: 2.5)
        snap("wall_default_quarterly")

        // Tier switches — every row an active, equal-dignity choice.
        // v6: tier titles are "the year" / "the quarter" / "one week"
        // (the old "the full year" / "12 weeks" labels predate the
        // v6.5 wall and were silently MISSING taps — the run ended in
        // a weekly-selected state and the recovery ladder took the
        // weekly branch instead of the scripted yearly one).
        tapButton("the year", shotName: nil, settle: 0.8)
        snap("wall_yearly_selected")
        tapButton("one week", shotName: nil, settle: 0.8)
        snap("wall_weekly_selected")
        tapButton("the quarter", shotName: nil, settle: 0.8)
        snap("wall_quarterly_reselected")
        tapButton("the year", shotName: nil, settle: 0.8)
        snap("wall_yearly_reselected")

        // CTA → straight to the REAL StoreKit sheet (no interstitial).
        tapButton("keep my plan", settle: 2.5)
        snap("storekit_sheet")

        // Cancel the purchase sheet. Under a StoreKit configuration
        // the sheet is system-owned; poll app then springboard for
        // the cancel affordance.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var cancelled = false
        for host in [app!, springboard] {
            for label in ["Cancel", "Close"] {
                let b = host.buttons[label].firstMatch
                if b.waitForExistence(timeout: 4), b.isHittable {
                    b.tap(); cancelled = true; break
                }
            }
            if cancelled { break }
        }
        if !cancelled {
            // Last resort: the sheet's top-right dismiss region.
            snap("storekit_sheet_no_cancel_button")
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.45)).tap()
        }
        Thread.sleep(forTimeInterval: 2.0)

        // Ladder step 1: any abandon → the discounted year.
        snap("recovery_discount_year")
        tapButton("maybe later", settle: 2.0)

        // → winback ("still here" hero).
        snap("recovery_winback")
        tapButton("not today", settle: 1.6)

        // The wall now wears the reclaim row — the offer is a state.
        let reclaim = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "saved")
        ).firstMatch
        XCTAssertTrue(reclaim.waitForExistence(timeout: 8),
                      "reclaim row should render after the discount unlocked")
        snap("wall_with_reclaim_row")
        reclaim.tap()
        Thread.sleep(forTimeInterval: 2.0)
        snap("downsell_reclaimed")
        tapButton("maybe later", settle: 1.6)

        // Ladder step 2: a SECOND abandon → the smaller step.
        tapButton("keep my plan", settle: 2.5)
        var cancelled2 = false
        for host in [app!, springboard] {
            for label in ["Cancel", "Close"] {
                let b = host.buttons[label].firstMatch
                if b.waitForExistence(timeout: 4), b.isHittable {
                    b.tap(); cancelled2 = true; break
                }
            }
            if cancelled2 { break }
        }
        Thread.sleep(forTimeInterval: 2.0)
        snap("recovery_smaller_step")
        tapButton("not today", settle: 1.6)
        snap("wall_final_state")
    }

    /// Pricing failure: skeleton pulses where numbers would be, the
    /// failure row, and the CTA in its "try pricing again" state.
    func testKeepWallPricingFail() throws {
        app = XCUIApplication()
        app.launchArguments += ["--debug-paywall", "--uitest-pricing-fail"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        Thread.sleep(forTimeInterval: 3.0)
        snap("wall_pricing_failed")

        let retry = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "try pricing again")
        ).firstMatch
        XCTAssertTrue(retry.waitForExistence(timeout: 8),
                      "CTA should offer retry when pricing fails")
        let failureRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "pricing didn't load")
        ).firstMatch
        XCTAssertTrue(failureRow.exists, "failure row should render")
        snap("wall_pricing_failed_detail")
    }

    /// Accessibility XXL text — the wall's fixed-size fold convention
    /// must hold (no overlap, all three tiers + docked CTA legible).
    func testKeepWallDynamicTypeXXL() throws {
        app = XCUIApplication()
        app.launchArguments += [
            "--debug-paywall",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"
        ]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        Thread.sleep(forTimeInterval: 3.0)
        snap("wall_dynamic_type_axl")

        let cta = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "keep my plan")
        ).firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 8), "CTA must stay on-screen at AXL")
    }
}

// MARK: - DownsellSheetUITests (2026-07-07 quieter-price redesign)
//
// X-dismiss on the wall → the redesigned discount sheet (receipt
// grammar, save-% marker, cocoa CTA) → "maybe later" → winback.
//
//   xcodebuild test -project plankAI.xcodeproj -scheme plankAI \
//     -destination 'platform=iOS Simulator,name=iPhone 16e' \
//     -only-testing:plankAIUITests/DownsellSheetUITests
final class DownsellSheetUITests: XCTestCase {

    private var shot = 0

    private func snap(_ name: String, in test: XCTestCase) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d_%@", shot, name)
        attachment.lifetime = .keepAlways
        test.add(attachment)
        shot += 1
    }

    func testDownsellFromDismiss() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-inapp-qa"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)

        let cta = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "keep my plan")
        ).firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 30), "wall should mount")
        Thread.sleep(forTimeInterval: 2.0)

        // X-dismiss → exit intent → downsell (flags reset by the QA arg).
        let close = app.buttons["Close paywall"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 8))
        close.tap()
        Thread.sleep(forTimeInterval: 2.2)
        snap("downsell_sheet", in: self)

        let keepYear = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "keep the year")
        ).firstMatch
        XCTAssertTrue(keepYear.waitForExistence(timeout: 8), "downsell CTA should render")

        let later = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "maybe later")
        ).firstMatch
        if later.waitForExistence(timeout: 5) { later.tap() }
        Thread.sleep(forTimeInterval: 2.0)
        snap("winback_after_downsell", in: self)

        let notToday = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "not today")
        ).firstMatch
        if notToday.waitForExistence(timeout: 6) { notToday.tap() }
        Thread.sleep(forTimeInterval: 1.2)
        snap("wall_after_recovery", in: self)

        // The reclaim row — tap it and the discounted year reopens.
        let reclaim = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "saved")
        ).firstMatch
        XCTAssertTrue(reclaim.waitForExistence(timeout: 8),
                      "reclaim row should render once the discount unlocked")
        reclaim.tap()
        Thread.sleep(forTimeInterval: 2.0)
        snap("downsell_reclaimed", in: self)
        let reclaimedCta = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "keep the year")
        ).firstMatch
        XCTAssertTrue(reclaimedCta.waitForExistence(timeout: 8),
                      "reclaimed sheet should render the discount CTA")
    }
}

// MARK: - RatingGateUITests (2026-07-08 first-win sentiment gate)
//
// Drives the re-wired sentiment gate via --debug-rating-gate: the
// "enjoying jenifit?" sheet, the "yes" (native review) affordance, and
// the "not really" → FeedbackView path.
//
//   xcodebuild test -project plankAI.xcodeproj -scheme plankAI \
//     -destination 'platform=iOS Simulator,name=iPhone 16e' \
//     -only-testing:plankAIUITests/RatingGateUITests
final class RatingGateUITests: XCTestCase {

    private var shot = 0
    private func snap(_ name: String, in test: XCTestCase) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = String(format: "%02d_%@", shot, name); a.lifetime = .keepAlways
        test.add(a); shot += 1
    }

    func testSentimentGateAndFeedbackPath() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--debug-rating-gate"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        Thread.sleep(forTimeInterval: 2.0)

        // Screen 1 — the sentiment question, both buttons present.
        let question = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "enjoying")
        ).firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: 8), "sentiment gate should render")
        let yes = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "loving it")
        ).firstMatch
        XCTAssertTrue(yes.exists, "yes path should be present")
        snap("sentiment_gate", in: self)

        // "not really" → the feedback path (never the App Store).
        let no = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "not really")
        ).firstMatch
        XCTAssertTrue(no.waitForExistence(timeout: 5))
        no.tap()
        Thread.sleep(forTimeInterval: 2.0)

        let feedback = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "what's working")
        ).firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 8),
                      "no path should open the feedback form, not the store")
        snap("feedback_path", in: self)
    }

    /// The "yes" celebration: tapping fires the swell + haptic, then the
    /// native review (iOS suppresses in sim). Assert the tap is handled
    /// and the app survives the celebration envelope.
    func testYesCelebration() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--debug-rating-gate"]
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        Thread.sleep(forTimeInterval: 2.0)
        let yes = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "loving it")
        ).firstMatch
        XCTAssertTrue(yes.waitForExistence(timeout: 8))
        snap("before_yes", in: self)
        yes.tap()
        Thread.sleep(forTimeInterval: 0.35)   // mid-swell
        snap("yes_celebration", in: self)
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertEqual(app.state, .runningForeground, "app survives the yes celebration")
    }
}
