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
