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
            "skip for now", "Maybe later", "not right now", "not yet",
            "yeah, that's me",
            "i agree", "i'm in", "i want this version",
            "show me my plan", "show me how it feels",
            "continue", "Continue",
            "see your plan", "let's go", "start now", "connected",
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

        // Open the hub via the eyebrow-row ellipsis (identifier is the
        // SF symbol name; the runtime title-cases the a11y label).
        let settings = app.buttons["ellipsis"]
        XCTAssertTrue(settings.waitForExistence(timeout: 6), "settings entry missing")
        settings.tap()
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

        let settings = app.buttons["ellipsis"]
        XCTAssertTrue(settings.waitForExistence(timeout: 6), "settings entry missing")

        // Two open → X-close cycles so the close animation is captured on
        // the concurrent screen recording and the rapid stills below.
        for cycle in 0..<2 {
            settings.tap()
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
