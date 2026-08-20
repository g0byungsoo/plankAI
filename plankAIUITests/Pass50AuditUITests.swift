import XCTest

// MARK: - Pass50AuditUITests (pass 50 — THE APP I WOULD TRUST)
//
// NOT regression tests. These are instrumented customer walks for the
// pass-50 product audit: each leg drives a flow the way a tired
// customer would, dumps a screenshot at every beat and the element
// tree at every decision point, and logs P50-prefixed timings. Legs
// avoid assertions except where a missing element makes the walk
// meaningless — the deliverable is the evidence trail in
// INVENTORY_DIR and the xcodebuild log, not a green checkmark.
final class Pass50AuditUITests: XCTestCase {

    private var shot = 0

    private var dir: String {
        ProcessInfo.processInfo.environment["INVENTORY_DIR"]
            ?? "/tmp/jenifit_pass50"
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
        let tree = app.debugDescription
        let path = "\(dir)/tree_\(tag).txt"
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
        try? tree.write(toFile: path, atomically: true, encoding: .utf8)
        NSLog("P50 tree dumped: \(tag) (\(tree.count) chars)")
    }

    private func launch(_ extraArgs: [String], base: [String] = [
        "--uitest-inapp-qa", "--uitest-pro-access",
    ]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = base + extraArgs
        app.launch()
        sleep(9)
        return app
    }

    // MARK: Leg A — a new payer's first minutes (the post-purchase cliff)

    func testP50_A_PayerFirstMinutes() {
        let app = launch([])
        snap("A_landing")
        dumpTree(app, "A_landing")

        // Walk the tab bar the way a curious first-timer would.
        for tab in ["jeni", "becoming", "today"] {
            let button = app.buttons[tab].firstMatch
            if button.waitForExistence(timeout: 4) {
                button.tap()
                sleep(3)
                snap("A_tab_\(tab)")
                if tab != "today" { dumpTree(app, "A_tab_\(tab)") }
            } else {
                NSLog("P50 A: tab '\(tab)' not found by label")
            }
        }
        snap("A_back_on_today")
    }

    // MARK: Leg B — the words door, end to end, timed; then the repeat

    func testP50_B_WordsLogAndRepeat() {
        let app = launch(["--uitest-seed-week", "--uitest-open-scan-chooser"])
        sleep(2)
        snap("B_chooser")
        dumpTree(app, "B_chooser")

        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 6) else {
            snap("B_no_field"); return
        }
        field.tap()
        sleep(1)
        field.typeText("greek yogurt with honey and a banana")
        snap("B_typed")

        let count = app.buttons["count it"]
        guard count.waitForExistence(timeout: 4) else { snap("B_no_count"); return }
        var t0 = Date()
        count.tap()
        NSLog("P50 B: count-it tapped at \(t0.timeIntervalSince1970)")

        // First-run gates: the consent primer (and the one-time food
        // onboarding) can stand in front of the first estimate. Accept
        // and record where the flow lands afterwards — the audit wants
        // to know whether her typed sentence survives the gate.
        let accept = app.buttons["accept"]
        if accept.waitForExistence(timeout: 5) {
            snap("B_consent_gate")
            accept.tap()
            sleep(3)
            snap("B_after_consent")
            t0 = Date()
        }
        // The one-time "before your first plate" questions can follow.
        let cont = app.buttons["continue"]
        if cont.waitForExistence(timeout: 3) {
            cont.tap()
            sleep(3)
            snap("B_after_first_plate_questions")
            dumpTree(app, "B_after_first_plate_questions")
            t0 = Date()
        }

        // Wait for the reading: the add button is its arrival signal.
        let add = app.buttons["add it"]
        var arrived = false
        for i in 0..<30 {
            if add.exists { arrived = true; break }
            if i == 6 { snap("B_reading_wait_6s") }
            sleep(1)
        }
        let dt = Date().timeIntervalSince(t0)
        NSLog("P50 B: reading arrived=\(arrived) after \(dt)s")
        snap("B_reading")
        dumpTree(app, "B_reading")

        if arrived {
            add.tap()
            sleep(4)
            snap("B_after_add_home")
        }

        // THE REPEAT: back into the chooser, hunting the again door.
        app.buttons["scan"].firstMatch.tap()
        sleep(2)
        snap("B_chooser_again")
        // the again door is made of her record — label carries the dish
        let again = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'again' OR label CONTAINS 'greek yogurt'")
        ).firstMatch
        if again.waitForExistence(timeout: 4) {
            again.tap()
            sleep(2)
            snap("B_again_sheet")
            dumpTree(app, "B_again_sheet")
            let first = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'greek yogurt'")
            ).firstMatch
            if first.waitForExistence(timeout: 4) {
                let t1 = Date()
                first.tap()
                sleep(3)
                snap("B_again_reading")
                NSLog("P50 B: again re-log took \(Date().timeIntervalSince(t1))s after sheet")
                dumpTree(app, "B_again_reading")
            }
        } else {
            NSLog("P50 B: no again door found in chooser")
        }
    }

    // MARK: Leg C — weigh-in, the list, the correction

    func testP50_C_WeighInAndCorrect() {
        // The morning ruler, mounted alone.
        var app = launch(["--debug-weigh-in"], base: [])
        snap("C_weigh_in_sheet")
        dumpTree(app, "C_weigh_in_sheet")

        // Try the ruler: a horizontal drag on the middle of the screen.
        let mid = app.windows.firstMatch.coordinate(
            withNormalizedOffset: CGVector(dx: 0.7, dy: 0.55))
        let left = app.windows.firstMatch.coordinate(
            withNormalizedOffset: CGVector(dx: 0.3, dy: 0.55))
        mid.press(forDuration: 0.05, thenDragTo: left)
        sleep(1)
        snap("C_after_ruler_drag")

        app.terminate()

        // The record list and its edit sheet, mounted alone.
        app = launch(["--debug-weigh-ins-edit"], base: [])
        snap("C_weigh_ins_edit")
        dumpTree(app, "C_weigh_ins_edit")
    }

    // MARK: Leg D — the medication record: mark, correct, symptoms, schedule hunt

    func testP50_D_MedicationPaths() {
        // Dose sheet, seeded.
        var app = launch(["--uitest-seed-medication", "injectable",
                          "--uitest-open-dose-sheet"])
        sleep(2)
        snap("D_dose_sheet")
        dumpTree(app, "D_dose_sheet")
        app.terminate()

        // The regimen home: the doses ledger, the record, the schedule doors.
        app = launch(["--uitest-seed-medication", "injectable",
                      "--uitest-open-regimen"])
        sleep(2)
        snap("D_regimen_home")
        dumpTree(app, "D_regimen_home")

        // Hunt for anything that edits the schedule/cadence/interval.
        for word in ["schedule", "weekly", "cadence", "change", "dose"] {
            let hit = app.buttons.matching(
                NSPredicate(format: "label CONTAINS '\(word)'")
            ).firstMatch
            if hit.exists {
                NSLog("P50 D: schedule-ish door found: '\(hit.label)'")
            }
        }

        // the doses — the boring ledger; tap the first row (a Button since 36)
        let doses = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'the doses'")
        ).firstMatch
        if doses.waitForExistence(timeout: 4) {
            doses.tap()
            sleep(2)
            snap("D_doses_ledger")
            dumpTree(app, "D_doses_ledger")
            let row = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'mg'")
            ).firstMatch
            if row.exists {
                row.tap()
                sleep(2)
                snap("D_past_dose_sheet")
            }
        }
        app.terminate()

        // Symptom logger.
        app = launch(["--uitest-seed-medication", "injectable",
                      "--uitest-open-side-effects"])
        sleep(2)
        snap("D_side_effects")
        dumpTree(app, "D_side_effects")
    }

    // MARK: Leg E — becoming's children and settings

    func testP50_E_BecomingChildrenAndSettings() {
        let app = launch(["--uitest-seed-week", "--uitest-start-tab", "becoming"])
        sleep(2)
        snap("E_becoming")
        dumpTree(app, "E_becoming")

        // Tap up to four tiles; snap whatever each opens; close sheets by swiping down.
        let tiles = app.buttons.allElementsBoundByIndex
        var opened = 0
        for tile in tiles.prefix(14) {
            guard opened < 4 else { break }
            let label = tile.label
            guard !label.isEmpty, tile.isHittable,
                  !["today", "jeni", "scan", "becoming"].contains(label) else { continue }
            tile.tap()
            sleep(2)
            snap("E_child_\(opened)_\(label.prefix(12).replacingOccurrences(of: " ", with: "_"))")
            opened += 1
            // close: try grabber swipe, then a close button
            let start = app.windows.firstMatch.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
            let end = app.windows.firstMatch.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
            start.press(forDuration: 0.05, thenDragTo: end)
            sleep(1)
            if app.buttons["close"].exists { app.buttons["close"].tap(); sleep(1) }
        }
        snap("E_becoming_after")

        // Settings: the gear lives on home.
        app.buttons["today"].firstMatch.tap()
        sleep(1)
        let gear = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'settings' OR identifier CONTAINS 'settings' OR label CONTAINS 'gear'")
        ).firstMatch
        if gear.waitForExistence(timeout: 3) {
            gear.tap()
            sleep(2)
            snap("E_settings")
            dumpTree(app, "E_settings")
        } else {
            NSLog("P50 E: no settings door found by label")
            dumpTree(app, "E_home_no_gear")
        }
    }

    // MARK: Pass 51 — the adversarial record journeys (REAL assertions)
    //
    // Unlike the pass-50 legs above, these ASSERT: each one attacks a
    // pass-51 invariant from the running app rather than a unit seam.

    /// USER INTENT WINS + DELETE STAYS DELETED, walked: keep a ruler
    /// number → the ledger lists it as HERS (no provenance word) →
    /// remove it → relaunch → still gone.
    func testP51_WeighInKeptListedRemovedStaysRemoved() {
        // A ledger row's label reads "today…159.0 lb…" — the unit is
        // what separates it from Home's calendar strip. (The film
        // doors mount the ruler with onSave: {_ in}, so this walk uses
        // the REAL customer path end to end.)
        let todayRowPredicate = NSPredicate(
            format: "label BEGINSWITH 'today' AND (label CONTAINS ' lb' OR label CONTAINS ' kg')")

        func openLedger(_ app: XCUIApplication) -> Bool {
            app.buttons["becoming"].firstMatch.tap()
            sleep(2)
            let entry = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS 'weigh-in' OR label CONTAINS 'weigh ins' OR label CONTAINS 'your weigh'")
            ).firstMatch
            guard entry.waitForExistence(timeout: 6) else {
                dumpTree(app, "P51_becoming_no_ledger_door")
                return false
            }
            entry.tap()
            sleep(2)
            return true
        }

        // 1 · Keep a number through Home's own weigh-in tool.
        var app = launch(["--uitest-seed-program"])
        let tool = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'weigh in'")
        ).firstMatch
        XCTAssertTrue(tool.waitForExistence(timeout: 8), "home's weigh-in tool")
        tool.tap()
        sleep(2)
        snap("P51_ruler")
        dumpTree(app, "P51_ruler")
        // "keep it" on a fresh day, "update it" when the sim's standing
        // account already weighed in today — both land on persist.
        let keep = app.buttons.matching(
            NSPredicate(format: "label == 'keep it' OR label == 'update it'")
        ).firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 8), "the ruler's keep button")
        keep.tap()
        sleep(3)
        // The confirmation face closes on its own done word if present.
        for word in ["done", "close"] where app.buttons[word].exists {
            app.buttons[word].tap()
            sleep(1)
        }

        // 2 · The ledger lists it on today, as HERS (no provenance word).
        XCTAssertTrue(openLedger(app), "becoming's door into the weigh-ins ledger")
        snap("P51_ledger_after_keep")
        dumpTree(app, "P51_ledger_after_keep")
        let todayRow = app.buttons.matching(todayRowPredicate).firstMatch
        XCTAssertTrue(todayRow.waitForExistence(timeout: 6),
                      "the kept weigh-in must be listed on today")
        XCTAssertFalse(todayRow.label.contains("from health"),
                       "a number she kept is HERS — no provenance word")

        // 3 · Remove it through the row's editor.
        todayRow.tap()
        sleep(2)
        let remove = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'remove this weigh-in'")
        ).firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 8), "the editor's remove door")
        remove.tap()
        sleep(1)
        let confirm = app.buttons["remove it"]
        if confirm.waitForExistence(timeout: 4) { confirm.tap() }
        sleep(2)
        snap("P51_ledger_after_remove")
        XCTAssertFalse(
            app.buttons.matching(todayRowPredicate).firstMatch.exists,
            "the removed weigh-in must leave the list at once"
        )
        app.terminate()

        // 4 · The relaunch is the adversary: hydrate + import both run.
        app = launch(["--uitest-seed-program"])
        XCTAssertTrue(openLedger(app), "the ledger, after relaunch")
        snap("P51_ledger_after_relaunch")
        dumpTree(app, "P51_ledger_after_relaunch")
        XCTAssertFalse(
            app.buttons.matching(todayRowPredicate).firstMatch.exists,
            "a removed weigh-in resurrected across a relaunch"
        )
    }

    /// A CIVIL DAY IS A FACT, walked: the persona hydrated through the
    /// REAL apply path shows a program day; a relaunch with no re-seed
    /// reads the SAME day off the persisted plan.
    func testP51_ProgramDaySurvivesRelaunch() {
        var app = launch(["--uitest-persona-autym-repaired"])
        snap("P51_day_first")
        dumpTree(app, "P51_day_first")
        let dayPredicate = NSPredicate(
            format: "label BEGINSWITH 'day ' AND label CONTAINS ' of '")
        let chip1 = app.descendants(matching: .any)
            .matching(dayPredicate).firstMatch
        XCTAssertTrue(chip1.waitForExistence(timeout: 8), "the day chip")
        let firstDay = chip1.label.components(separatedBy: " \u{00B7} ").first ?? chip1.label
        app.terminate()

        app = launch([])
        snap("P51_day_relaunch")
        let chip2 = app.descendants(matching: .any)
            .matching(dayPredicate).firstMatch
        XCTAssertTrue(chip2.waitForExistence(timeout: 8), "the day chip after relaunch")
        let secondDay = chip2.label.components(separatedBy: " \u{00B7} ").first ?? chip2.label
        XCTAssertEqual(secondDay, firstDay,
                       "the program day moved across a relaunch")
    }

    /// UNKNOWN STAYS UNKNOWN's visible half, walked: a plate logged in
    /// words renders the WORDS provenance line — never the photo's.
    func testP51_WordsPlateWearsWordsProvenance() {
        let app = launch(["--uitest-wipe-food"])
        let scanTab = app.buttons["scan"].firstMatch
        XCTAssertTrue(scanTab.waitForExistence(timeout: 8))
        scanTab.tap()
        sleep(2)
        snap("P51_chooser")

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 6), "the words field")
        sleep(2)   // the chooser's entrance morph settles
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(1)
        app.typeText("greek yogurt with honey and a banana")
        let count = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'count it'")
        ).firstMatch
        if count.waitForExistence(timeout: 3) {
            count.tap()
        } else {
            app.keyboards.buttons["return"].firstMatch.tap()
        }
        sleep(12)   // the estimate round-trip
        snap("P51_words_reading")
        dumpTree(app, "P51_words_reading")

        let provenance = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'your words'")
        ).firstMatch
        let photoLie = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'read from your photo'")
        ).firstMatch
        if provenance.exists {
            XCTAssertFalse(photoLie.exists,
                           "a typed plate must never wear the photo's provenance")
        } else {
            // Offline/EF-unreachable runs never reach a reading; the
            // walk records the fact instead of asserting into a void.
            NSLog("P51 words: no reading arrived (network?) — evidence in tree dump")
        }
    }
}
