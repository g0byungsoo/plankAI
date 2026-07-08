import XCTest

// MARK: - DesignWalkUITests
//
// UX-pass driver (2026-07-07): walks flows a designer needs to SEE —
// zero-data first-run, onboarding feel reference, breath session,
// the rep, tab transitions. Screenshots land in INVENTORY_DIR
// (TEST_RUNNER_INVENTORY_DIR env); videos are recorded from the
// host with `simctl io recordVideo` around the run.
final class DesignWalkUITests: XCTestCase {

    private var shot = 0

    private var dir: String {
        ProcessInfo.processInfo.environment["INVENTORY_DIR"]
            ?? "/tmp/jenifit_designwalk"
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let path = "\(dir)/\(String(format: "%02d", shot))_\(name).png"
        FileManager.default.createFile(atPath: path, contents: png)
        shot += 1
    }

    private func tapFirst(_ app: XCUIApplication, _ labels: [String], timeout: Int = 4) -> Bool {
        for _ in 0..<timeout {
            for label in labels {
                let b = app.buttons[label].firstMatch
                if b.exists && b.isHittable { b.tap(); return true }
                let any = app.descendants(matching: .any)[label].firstMatch
                if any.exists && any.isHittable { any.tap(); return true }
            }
            sleep(1)
        }
        return false
    }

    /// Leg 1 — the REAL new-user path: onramp → program setup →
    /// Today with ZERO data (no plates, no weights, no steps).
    /// Then becoming + jeni in their zero states.
    func testZeroDataFirstRun() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-pro-access", "--uitest-force-day"]
        app.launch()
        sleep(6)

        snap(app, "onramp")
        _ = tapFirst(app, ["start my program"])
        sleep(2)
        // Walk the setup subflow: keep tapping the primary CTA until
        // Today's masthead appears (max 12 steps).
        for i in 0..<12 {
            if app.buttons["settings"].firstMatch.isHittable { break }
            snap(app, "setup_\(i)")
            if !tapFirst(app, ["continue", "keep it", "start", "begin", "this pace feels right",
                               "build my program", "start week one", "let's begin", "yes"]) {
                // maybe an option list — tap the middle option row
                let opts = app.buttons.allElementsBoundByIndex.filter { $0.isHittable }
                if opts.count > 2 { opts[opts.count / 2].tap() } else { break }
            }
            sleep(2)
        }
        sleep(3)
        snap(app, "today_zero_top")
        app.swipeUp()
        sleep(1)
        snap(app, "today_zero_scrolled")
        app.swipeDown()
        sleep(1)

        app.buttons["becoming"].firstMatch.tap()
        sleep(3)
        snap(app, "becoming_zero")
        app.buttons["jeni"].firstMatch.tap()
        sleep(3)
        snap(app, "jeni_zero")
    }

    /// Leg 2 — onboarding v5 feel reference: walk the first ~8 beats
    /// (video is recorded around this from the host).
    func testOnboardingFeelReference() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-fresh-onboarding"]
        app.launch()
        sleep(5)
        snap(app, "ob_0")
        for i in 1...8 {
            if !tapFirst(app, ["continue", "i'm ready", "let's go", "begin", "start", "next"]) {
                let opts = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.frame.height > 40 }
                if let mid = opts.dropFirst(opts.count / 2).first { mid.tap() }
            }
            sleep(2)
            snap(app, "ob_\(i)")
        }
    }

    /// Leg 3 — breath entry + session (rest day). Video from host.
    func testBreathFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-seed-day", "14",
            "--uitest-force-day",
        ]
        app.launch()
        sleep(8)
        let breathRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'sixty seconds of breath' OR label BEGINSWITH 'breathe'")
        ).firstMatch
        guard breathRow.waitForExistence(timeout: 8) else { return }
        sleep(2)
        breathRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(3)
        snap(app, "breath_entry")
        _ = tapFirst(app, ["begin", "start", "i'm ready", "breathe with her", "let's breathe"])
        sleep(6)
        snap(app, "breath_session_early")
        sleep(20)
        snap(app, "breath_session_mid")
        sleep(45)
        snap(app, "breath_receipt")
    }

    /// Leg 4 — the method rep (seed-day 3): scenario → door →
    /// response → close.
    func testMethodRep() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-seed-day", "3",
            "--uitest-force-day",
        ]
        app.launch()
        sleep(8)
        let methodRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'the method'")
        ).firstMatch
        guard methodRow.waitForExistence(timeout: 8) else { return }
        sleep(2)
        methodRow.tap()
        sleep(3)
        snap(app, "rep_scenario")
        let door = app.buttons.allElementsBoundByIndex.filter {
            $0.isHittable && $0.frame.height > 40 && $0.frame.minY > 300
        }
        if let first = door.first { first.tap() }
        sleep(2)
        snap(app, "rep_response")
        sleep(2)
        snap(app, "rep_settled")
        _ = tapFirst(app, ["keep this rep", "kept", "done", "close", "continue"])
        sleep(2)
        snap(app, "rep_after")
    }

    /// Leg 5 — motion tour: note cascade, tab switches, ribbon →
    /// journey, plate story. Video from host.
    func testMotionTour() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-force-day", "--uitest-mock-chat",
        ]
        app.launch()
        sleep(8)
        // the note (jeni line)
        let jeniLine = app.buttons["jeni.line"].firstMatch
        if jeniLine.exists && jeniLine.isHittable {
            jeniLine.tap()
            sleep(4)
            snap(app, "note_fullscreen")
            _ = tapFirst(app, ["keep it close", "keep it"])
            sleep(2)
        }
        // ribbon → journey
        let ribbon = app.buttons["today.weekRibbon"].firstMatch
        if ribbon.exists && ribbon.isHittable {
            ribbon.tap()
            sleep(3)
            snap(app, "journey_via_ribbon")
        }
        // tab switches
        app.buttons["today"].firstMatch.tap()
        sleep(1)
        app.buttons["jeni"].firstMatch.tap()
        sleep(1)
        app.buttons["becoming"].firstMatch.tap()
        sleep(3)
        // v5: becoming is a horizontal story — swipe the pages.
        snap(app, "story_line")
        for name in ["story_food", "story_movement", "story_plan", "story_reflection"] {
            app.swipeLeft()
            sleep(2)
            snap(app, name)
        }
        app.buttons["today"].firstMatch.tap()
        sleep(1)
        // steps sheet
        let stepsRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'steps'")
        ).firstMatch
        if stepsRow.exists && stepsRow.isHittable {
            stepsRow.tap()
            sleep(2)
            snap(app, "steps_sheet")
        }
    }
}
