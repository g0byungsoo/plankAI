import XCTest

// MARK: - Pass52ActivationUITests (pass 52 — THE FIRST DAY)
//
// The reproducible activation harness. Each leg walks the app from the
// instant AFTER a successful purchase (the host stamps
// `postPurchase.firstRunPending` + launches with `--uitest-pro-access`,
// which together are exactly the two mutations WallView makes on a
// completed purchase) and measures the journey to the first trusted
// record and the first useful response.
//
// The SAME legs run against the BEFORE (build 33) and AFTER trees, so
// every leg is tolerant of beats that exist in only one of them: every
// optional surface is an `if exists`, and the log records which beats
// were met. The deliverable is the P52-prefixed timing log + the
// screenshot trail in P52_DIR, not a green checkmark — assertions are
// reserved for traps (a dead end the walk cannot leave).
//
// Timing vocabulary (logged as `P52 <leg> · <beat> · dt=<s>`):
//   t0            — the moment the post-purchase launch is foreground.
//   home          — the first frame of the main shell's Today tab.
//   recordStarted — her first input gesture toward a record.
//   recordKept    — the record is on file (the flow closed over it).
//   usefulResponse— the first surface that answers from her record.
final class Pass52ActivationUITests: XCTestCase {

    private var shot = 0
    private var t0 = Date()

    private var dir: String {
        ProcessInfo.processInfo.environment["P52_DIR"] ?? "/tmp/jenifit_pass52"
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func snap(_ name: String) {
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let path = "\(dir)/\(String(format: "%02d", shot))_\(name).png"
        FileManager.default.createFile(atPath: path, contents: png)
        shot += 1
    }

    private func dumpTree(_ app: XCUIApplication, _ tag: String) {
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
        try? app.debugDescription.write(
            toFile: "\(dir)/tree_\(tag).txt", atomically: true, encoding: .utf8)
    }

    /// One line per beat: name, wall-clock delta from t0, tap count so far.
    private var taps = 0
    private func mark(_ leg: String, _ beat: String) {
        let dt = String(format: "%.1f", Date().timeIntervalSince(t0))
        NSLog("P52 \(leg) · \(beat) · dt=\(dt)s · taps=\(taps)")
    }

    @discardableResult
    private func tapIfExists(
        _ app: XCUIApplication, _ label: String, timeout: TimeInterval = 4,
        settle: TimeInterval = 1.2
    ) -> Bool {
        let b = app.buttons[label].firstMatch
        guard b.waitForExistence(timeout: timeout) else { return false }
        guard b.isHittable else { return false }
        b.tap()
        taps += 1
        Thread.sleep(forTimeInterval: settle)
        return true
    }

    private func launchPostPurchase(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // P52_ARGS lets a host script append doors per run (e.g. the
        // letter suppressor on the standing-account SE fixture, where
        // the enrolled account's letter races a manually-stamped
        // corridor — a state no real payer can hold; see the record).
        let hostExtra = (ProcessInfo.processInfo.environment["P52_ARGS"] ?? "")
            .split(separator: " ").map(String.init)
        app.launchArguments = ["--uitest-pro-access", "--uitest-skip-review"]
            + extra + hostExtra
        addUIInterruptionMonitor(withDescription: "system alerts") { alert in
            for label in ["Allow Full Access", "Allow", "Allow Once", "OK",
                          "Allow While Using App", "Turn On All", "Don't Allow", "Not Now"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        t0 = Date()
        taps = 0
        return app
    }

    /// Walks whatever post-purchase corridor the build under test has —
    /// forging, coach intro, (breath primer on the BEFORE build),
    /// (promise) — until the main shell's tab bar is on screen. Logs
    /// every beat it met. Returns false if the shell never arrived.
    @discardableResult
    private func walkCorridorToShell(_ app: XCUIApplication, leg: String) -> Bool {
        snap("\(leg)_first_frame")
        mark(leg, "first frame")

        // forging → coach intro both use "let's go"; the breath primer
        // (BEFORE only) offers "skip to workout"; unknown future beats
        // that use "continue" are also consumed. Poll until the tab bar
        // exists or nothing tappable is left.
        let deadline = Date().addingTimeInterval(150)
        var beat = 0
        var lastLabel = ""
        var sameLabelCount = 0
        while Date() < deadline {
            // A fullScreenCover keeps the shell IN the hierarchy, so
            // `exists` lies here — hittable is the on-top test. The
            // corridor is done only when no corridor button remains AND
            // the centre tab can actually take a tap.
            let corridorButtons = ["let's go", "skip to workout", "skip", "continue", "keep it"]
            let corridorUp = corridorButtons.contains {
                let b = app.buttons[$0].firstMatch
                return b.exists && b.isHittable
            }
            if !corridorUp, app.buttons["scan"].firstMatch.isHittable {
                mark(leg, "shell reached")
                snap("\(leg)_shell")
                return true
            }
            var advanced = false
            for label in corridorButtons {
                let b = app.buttons[label].firstMatch
                if b.exists && b.isHittable {
                    snap("\(leg)_corridor_\(beat)_\(label.replacingOccurrences(of: " ", with: "_"))")
                    // Coordinate tap at the frame read NOW: the
                    // corridor's CTAs arrive on an offset/opacity
                    // choreography and the element-cached tap landed
                    // 12pt off on the sim (68 no-op taps, filmed).
                    sameLabelCount = (label == lastLabel) ? sameLabelCount + 1 : 0
                    lastLabel = label
                    if sameLabelCount >= 2 {
                        // The tap event is not landing — a short press
                        // is the sim's reliable alternative (the oath's
                        // own workaround).
                        b.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                            .press(forDuration: 0.12)
                    } else {
                        b.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    }
                    taps += 1
                    mark(leg, "corridor tap '\(label)'")
                    beat += 1
                    advanced = true
                    Thread.sleep(forTimeInterval: 1.8)
                    break
                }
            }
            if !advanced { Thread.sleep(forTimeInterval: 1.0) }
        }
        mark(leg, "shell NEVER reached")
        snap("\(leg)_stuck")
        dumpTree(app, "\(leg)_stuck")
        return false
    }

    /// Walks whatever onramp/setup the build under test has — the
    /// "start my program" intro, then the subflow pages in either the
    /// 3-page (BEFORE) or merged (AFTER) shape — until Home's tools are
    /// visible. Every page is optional so the same walk fits both trees.
    @discardableResult
    private func walkOnrampToHome(_ app: XCUIApplication, leg: String) -> Bool {
        // The onramp intro.
        if tapIfExists(app, "start my program", timeout: 10, settle: 1.6) {
            mark(leg, "onramp: start my program")
            snap("\(leg)_after_start")
        } else {
            mark(leg, "no onramp intro (home direct?)")
        }
        // Subflow pages, in order of appearance. "see your options" is
        // the BEFORE goal-date reveal; a pace pill then "continue" and
        // "i'm in" close it out. On the AFTER tree some of these are
        // gone or merged — each is optional.
        if tapIfExists(app, "see your options", timeout: 6, settle: 1.4) {
            mark(leg, "subflow: goal-date reveal passed")
            snap("\(leg)_after_reveal")
        }
        // The pace page (if present): pick medium ("steady").
        for pace in ["steady", "gentle"] {
            let pill = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", pace)
            ).firstMatch
            if pill.waitForExistence(timeout: 4), pill.isHittable {
                snap("\(leg)_pace_page")
                pill.tap()
                taps += 1
                mark(leg, "subflow: pace picked (\(pace))")
                Thread.sleep(forTimeInterval: 0.8)
                break
            }
        }
        if tapIfExists(app, "continue", timeout: 4, settle: 1.4) {
            mark(leg, "subflow: pace continue")
        }
        if tapIfExists(app, "i'm in", timeout: 6, settle: 2.0) {
            mark(leg, "subflow: committed")
            snap("\(leg)_after_commit")
        }
        // Home: the tools row / hero is the arrival signal.
        var arrived = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'weigh in'")
        ).firstMatch.waitForExistence(timeout: 15)
        // THE LETTER: the morning read presents itself over Home once a
        // day — on day one it reads "your file starts with one plate.
        // add the last thing you ate." Real customers read and keep it;
        // the walk does the same (and the film records it as a beat).
        if app.buttons["keep it"].firstMatch.waitForExistence(timeout: 3) {
            snap("\(leg)_letter")
            mark(leg, "the letter presented (day-one morning read)")
            app.buttons["keep it"].firstMatch
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            taps += 1
            Thread.sleep(forTimeInterval: 1.6)
            arrived = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH 'weigh in'")
            ).firstMatch.waitForExistence(timeout: 8)
        }
        // On 375pt the tools grid is lazy and below the fold, so the
        // weigh-in tool may not EXIST yet; an interactive shell is the
        // honest arrival signal there.
        if !arrived, app.buttons["scan"].firstMatch.isHittable {
            arrived = true
            mark(leg, "HOME (shell interactive; tools below the fold)")
        }
        mark(leg, arrived ? "HOME (plan live)" : "home tools never appeared")
        snap("\(leg)_home")
        dumpTree(app, "\(leg)_home")
        return arrived
    }

    // MARK: Leg A — the words record, end to end, measured

    func testP52_A_WordsFirstRecord() throws {
        let app = launchPostPurchase()
        guard walkCorridorToShell(app, leg: "A") else { return }
        guard walkOnrampToHome(app, leg: "A") else { return }

        // The first record: the centre tab → the words field.
        let scanTab = app.buttons["scan"].firstMatch
        guard scanTab.waitForExistence(timeout: 8) else {
            mark("A", "no scan tab"); dumpTree(app, "A_no_scan_tab"); return
        }
        scanTab.tap(); taps += 1
        Thread.sleep(forTimeInterval: 2.0)
        mark("A", "chooser open")
        snap("A_chooser")

        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 6) else {
            mark("A", "no words field"); dumpTree(app, "A_no_field"); return
        }
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        taps += 1
        Thread.sleep(forTimeInterval: 1.0)
        app.typeText("greek yogurt with honey and a banana")
        mark("A", "recordStarted (sentence typed)")
        snap("A_typed")
        let count = app.buttons["count it"].firstMatch
        if count.waitForExistence(timeout: 3), count.isHittable {
            count.tap(); taps += 1
        } else {
            app.keyboards.buttons["return"].firstMatch.tap(); taps += 1
        }
        mark("A", "sentence submitted")

        // Whatever gates the build under test mounts. Each is logged.
        if app.buttons["accept"].waitForExistence(timeout: 6) {
            mark("A", "GATE consent shown")
            snap("A_gate_consent")
            dumpTree(app, "A_gate_consent")
            app.buttons["accept"].tap(); taps += 1
            Thread.sleep(forTimeInterval: 1.6)
            snap("A_after_consent")
        }
        if app.buttons["continue"].waitForExistence(timeout: 4) {
            mark("A", "GATE food questions shown")
            snap("A_gate_questions")
            app.buttons["continue"].tap(); taps += 1
            Thread.sleep(forTimeInterval: 1.6)
            snap("A_after_questions")
        }

        // Where did the flow land — the reading, or the camera?
        let add = app.buttons["add it"].firstMatch
        let orWrite = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'write it'")
        ).firstMatch
        var arrived = false
        for i in 0..<40 {
            if add.exists { arrived = true; break }
            if i == 4, orWrite.exists {
                // The BEFORE trap: the gates exited to the CAMERA over a
                // typed sentence. Record it, then recover the way a
                // customer would have to.
                mark("A", "TRAP: landed in camera over a typed sentence")
                snap("A_trap_camera")
                dumpTree(app, "A_trap_camera")
                orWrite.tap(); taps += 1
                Thread.sleep(forTimeInterval: 1.6)
                snap("A_after_or_write")
                // Her sentence may need re-submitting.
                let go = app.buttons["count it"].firstMatch
                if go.exists, go.isHittable { go.tap(); taps += 1 }
            }
            Thread.sleep(forTimeInterval: 1.0)
        }
        mark("A", arrived ? "READING arrived" : "reading never arrived")
        snap("A_reading")
        dumpTree(app, "A_reading")
        guard arrived else { return }

        add.tap(); taps += 1
        Thread.sleep(forTimeInterval: 2.5)
        mark("A", "recordKept (add it)")
        snap("A_after_add")
        dumpTree(app, "A_after_add")

        // AFTER builds: the three soft questions offer themselves once,
        // behind the filed record. This walk takes the floor path and
        // skips them (a separate leg answers them).
        if app.buttons["not now"].firstMatch.waitForExistence(timeout: 4) {
            mark("A", "questions OFFER shown (post-record)")
            snap("A_questions_offer")
            app.buttons["not now"].firstMatch
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            taps += 1
            Thread.sleep(forTimeInterval: 1.8)
        }

        // The first useful response: whatever the build answers with
        // after the record files — snapped for the audit either way.
        Thread.sleep(forTimeInterval: 2.0)
        snap("A_response_frame")
        mark("A", "response frame captured")

        // If the day-one contract card offers the morning read, take it
        // (the system dialog is handled by the interruption monitor).
        if tapIfExists(app, "yes, a quiet note", timeout: 4, settle: 2.0) {
            mark("A", "notification moment accepted")
            app.tap()   // nudge so the interruption monitor fires
            Thread.sleep(forTimeInterval: 2.0)
            snap("A_after_notification_ask")
        }
        snap("A_final_home")
    }

    // MARK: Leg B — the photo door (to camera-ready; permission counted)

    func testP52_B_PhotoDoor() throws {
        let app = launchPostPurchase()
        _ = walkCorridorToShell(app, leg: "B")
        // Corridor may already be consumed on this account; either way
        // we need Home.
        _ = walkOnrampToHome(app, leg: "B")

        let scanTab = app.buttons["scan"].firstMatch
        guard scanTab.waitForExistence(timeout: 8) else { return }
        scanTab.tap(); taps += 1
        Thread.sleep(forTimeInterval: 2.0)
        snap("B_chooser")

        let meal = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'a meal'")
        ).firstMatch
        guard meal.waitForExistence(timeout: 6) else {
            mark("B", "no meal door"); dumpTree(app, "B_no_meal_door"); return
        }
        meal.tap(); taps += 1
        mark("B", "meal door tapped")
        Thread.sleep(forTimeInterval: 2.0)

        if app.buttons["accept"].waitForExistence(timeout: 6) {
            mark("B", "GATE consent shown (photo door)")
            snap("B_gate_consent")
            app.buttons["accept"].tap(); taps += 1
            Thread.sleep(forTimeInterval: 1.6)
        }
        if app.buttons["continue"].waitForExistence(timeout: 4) {
            mark("B", "GATE food questions shown (photo door)")
            snap("B_gate_questions")
            app.buttons["continue"].tap(); taps += 1
            Thread.sleep(forTimeInterval: 1.6)
        }
        // The camera (permission dialog handled by the monitor; tap to
        // pump the run loop so it fires).
        app.tap()
        Thread.sleep(forTimeInterval: 3.0)
        mark("B", "camera-ready frame")
        snap("B_camera")
        dumpTree(app, "B_camera")
    }

    // MARK: Leg C — the weigh-in from Home's tools

    func testP52_C_WeighIn() throws {
        let app = launchPostPurchase()
        _ = walkCorridorToShell(app, leg: "C")
        _ = walkOnrampToHome(app, leg: "C")

        let tool = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'weigh in'")
        ).firstMatch
        guard tool.waitForExistence(timeout: 8) else {
            mark("C", "no weigh-in tool"); dumpTree(app, "C_no_tool"); return
        }
        tool.tap(); taps += 1
        mark("C", "recordStarted (ruler open)")
        Thread.sleep(forTimeInterval: 2.0)
        snap("C_ruler")

        let keep = app.buttons.matching(
            NSPredicate(format: "label == 'keep it' OR label == 'update it'")
        ).firstMatch
        guard keep.waitForExistence(timeout: 8) else {
            mark("C", "no keep button"); dumpTree(app, "C_no_keep"); return
        }
        keep.tap(); taps += 1
        Thread.sleep(forTimeInterval: 2.0)
        mark("C", "recordKept (weigh-in)")
        snap("C_after_keep")
        for word in ["done", "close"] where app.buttons[word].exists {
            app.buttons[word].tap(); taps += 1
            Thread.sleep(forTimeInterval: 1.0)
        }
        snap("C_home_after")
    }

    // MARK: Leg D — the GLP-1 user's first relevant medication action
    //
    // Run AFTER the cohort=current consult walk: the consult's own
    // bridge has built her regimen, and (when the walk answered
    // "tuesday" on a Tuesday) today is her shot day.

    func testP52_D_GLP1DoseAction() throws {
        let app = launchPostPurchase()
        _ = walkCorridorToShell(app, leg: "D")
        _ = walkOnrampToHome(app, leg: "D")
        snap("D_home")
        dumpTree(app, "D_home")

        // Hunt the dose surface the way she would: a row naming the
        // dose/shot on Today, else the regimen tool.
        let doseRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'dose' OR label CONTAINS 'shot'")
        ).firstMatch
        if doseRow.waitForExistence(timeout: 6), doseRow.isHittable {
            mark("D", "dose surface found: '\(doseRow.label.prefix(60))'")
            doseRow.tap(); taps += 1
            Thread.sleep(forTimeInterval: 2.0)
            snap("D_dose_sheet")
            dumpTree(app, "D_dose_sheet")
            // Mark it taken — coordinate tap (the sheet CTA's element
            // tap missed twice on this sim; the frame is the truth).
            // The CTA's a11y label is richer than its visible text.
            let markBtn = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'taken'")
            ).firstMatch
            if markBtn.waitForExistence(timeout: 5) {
                markBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                taps += 1
                Thread.sleep(forTimeInterval: 2.0)
                mark("D", "recordKept (dose marked)")
                snap("D_after_mark")
                dumpTree(app, "D_after_mark")
            } else {
                mark("D", "mark CTA not found")
            }
        } else {
            mark("D", "no dose surface on Home")
        }
        snap("D_final")
    }

    // MARK: Leg G — the day-one contract's grant, filmed
    //
    // Run on a device whose OS ask is still notDetermined and whose
    // day already holds a record: the card must stand, the yes must
    // raise the SYSTEM dialog, and a grant must leave the switch on.

    func testP52_G_ContractCardGrant() throws {
        let app = launchPostPurchase()
        Thread.sleep(forTimeInterval: 6.0)
        _ = tapIfExists(app, "keep it", timeout: 4, settle: 1.6)

        let yes = app.buttons["yes, a quiet note"].firstMatch
        var seen = yes.waitForExistence(timeout: 8)
        if seen, !yes.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1.0)
            if !yes.isHittable { app.swipeUp(); Thread.sleep(forTimeInterval: 1.0) }
        }
        seen = yes.exists && yes.isHittable
        mark("G", seen ? "contract card on screen" : "contract card not reachable")
        snap("G_card")
        dumpTree(app, "G_card")
        guard seen else { return }

        yes.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        taps += 1
        mark("G", "yes tapped — system ask expected")
        Thread.sleep(forTimeInterval: 1.5)
        snap("G_system_dialog")
        // Pump the run loop so the interruption monitor answers Allow.
        app.tap()
        Thread.sleep(forTimeInterval: 2.5)
        snap("G_after_grant")
        dumpTree(app, "G_after_grant")
        XCTAssertFalse(app.buttons["yes, a quiet note"].firstMatch.exists,
                       "the answered card must leave and never return")
        mark("G", "granted; card gone")
    }

    // MARK: Leg F — the first estimate FAILS (transport dead): no trap
    //
    // `--food-debug-timeout` throws the exact URLError the transport
    // throws when the network is unreachable — the first-estimate
    // failure, injected at the seam the real failure crosses.

    func testP52_F_FirstEstimateFailsNoTrap() throws {
        let app = launchPostPurchase(extra: ["--uitest-inapp-qa", "--food-debug-timeout"])
        _ = walkCorridorToShell(app, leg: "F")
        _ = walkOnrampToHome(app, leg: "F")

        let scanTab = app.buttons["scan"].firstMatch
        guard scanTab.waitForExistence(timeout: 8) else { return }
        scanTab.tap(); taps += 1
        Thread.sleep(forTimeInterval: 2.0)
        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 6) else {
            mark("F", "no words field"); dumpTree(app, "F_no_field"); return
        }
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        taps += 1
        Thread.sleep(forTimeInterval: 1.0)
        app.typeText("greek yogurt with honey")
        let count = app.buttons["count it"].firstMatch
        if count.waitForExistence(timeout: 3), count.isHittable {
            count.tap(); taps += 1
        } else {
            app.keyboards.buttons["return"].firstMatch.tap(); taps += 1
        }
        if app.buttons["accept"].waitForExistence(timeout: 5) {
            snap("F_gate_consent")
            app.buttons["accept"].tap(); taps += 1
            Thread.sleep(forTimeInterval: 1.6)
        }
        // The failure must arrive as a banner over her PRESERVED
        // sentence — never a dead end, never a lost record attempt.
        Thread.sleep(forTimeInterval: 8.0)
        snap("F_estimate_failed")
        dumpTree(app, "F_estimate_failed")
        let sentenceSurvives = app.textViews.matching(
            NSPredicate(format: "value CONTAINS 'greek yogurt'")
        ).firstMatch.exists
            || app.textFields.matching(
                NSPredicate(format: "value CONTAINS 'greek yogurt'")
            ).firstMatch.exists
            || app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'greek yogurt'")
            ).firstMatch.exists
        mark("F", "failure state: sentence survives=\(sentenceSurvives)")
        // She can leave under her own power.
        for label in ["close", "xmark"] where app.buttons[label].exists {
            app.buttons[label].tap(); taps += 1; break
        }
        snap("F_after_close")
    }

    // MARK: Leg H — consent declined, then the camera denied: coherent both times

    func testP52_H_DeclinesAreNotTraps() throws {
        let app = launchPostPurchase(extra: ["--uitest-inapp-qa"])
        _ = walkCorridorToShell(app, leg: "H")
        _ = walkOnrampToHome(app, leg: "H")

        // 1 · words → consent → "not now": back home, nothing broken.
        let scanTab = app.buttons["scan"].firstMatch
        guard scanTab.waitForExistence(timeout: 8) else { return }
        scanTab.tap(); taps += 1
        Thread.sleep(forTimeInterval: 2.0)
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 6) {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            taps += 1
            Thread.sleep(forTimeInterval: 1.0)
            app.typeText("toast and eggs")
            let count = app.buttons["count it"].firstMatch
            if count.waitForExistence(timeout: 3), count.isHittable {
                count.tap(); taps += 1
            } else {
                app.keyboards.buttons["return"].firstMatch.tap(); taps += 1
            }
            if app.buttons["not now"].waitForExistence(timeout: 6) {
                snap("H_consent")
                app.buttons["not now"].firstMatch.tap(); taps += 1
                Thread.sleep(forTimeInterval: 2.0)
                snap("H_after_decline")
                let home = app.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH 'weigh in'")
                ).firstMatch.waitForExistence(timeout: 6)
                mark("H", "consent declined → home coherent=\(home)")
                XCTAssertTrue(home, "declining consent must land her back on Home, whole")
            } else {
                mark("H", "no consent gate met (already accepted on this account)")
            }
        }
        snap("H_final")
    }

    // MARK: Leg E — kill mid-corridor, relaunch: no trap, no restart

    func testP52_E_RelaunchMidCorridor() throws {
        var app = launchPostPurchase()
        snap("E_first_frame")
        // Advance exactly one beat, then die.
        _ = tapIfExists(app, "let's go", timeout: 30, settle: 2.0)
        mark("E", "killed after first corridor beat")
        app.terminate()

        app = launchPostPurchase()
        Thread.sleep(forTimeInterval: 3.0)
        mark("E", "relaunched")
        snap("E_relaunch_frame")
        dumpTree(app, "E_relaunch")
        // The walk must still be able to reach the shell.
        let ok = walkCorridorToShell(app, leg: "E")
        XCTAssertTrue(ok, "a kill mid-corridor must not trap the user")
    }
}
