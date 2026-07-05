import XCTest

// MARK: - SurfaceInventoryUITests
//
// App v2.2 (docs/app_v2/15_SURFACE_INVENTORY.md). The coverage
// walker: drives the seeded app through every reachable surface —
// beats, sheets, module doorways, settings sub-screens, tabs — and
// writes a PNG per stop to INVENTORY_DIR (simulator processes share
// the host filesystem). The doc's before/after ledger cites these.
//
// Run (NOTE: xcodebuild only forwards TEST_RUNNER_-prefixed env to
// the runner — a bare INVENTORY_DIR never arrives and captures land
// in the default path):
//   TEST_RUNNER_INVENTORY_DIR=/tmp/jenifit_inventory xcodebuild test \
//     -only-testing:plankAIUITests/SurfaceInventoryUITests

final class SurfaceInventoryUITests: XCTestCase {

    private var shot = 0

    func testWalkEveryReachableSurface() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-mock-chat",
        ]
        app.launch()
        sleep(6)   // seed + hydrate settle

        let dir = ProcessInfo.processInfo.environment["INVENTORY_DIR"]
            ?? "/tmp/jenifit_inventory"
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )

        func snap(_ name: String) {
            let image = XCUIScreen.main.screenshot().pngRepresentation
            let path = "\(dir)/\(String(format: "%02d", shot))_\(name).png"
            FileManager.default.createFile(atPath: path, contents: image)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            shot += 1
        }

        func closeSheet() {
            // Prefer explicit closes; then a grabber-area drag; then a
            // plain swipe. Loop until the today masthead is hittable
            // again (max 3 rounds) so a stuck sheet can't poison the
            // rest of the walk.
            for _ in 0..<3 {
                var closed = false
                for label in ["got it", "not yet", "not now", "not today", "cancel", "close",
                              "done", "skip for now", "xmark", "Close"] {
                    let button = app.buttons[label].firstMatch
                    if button.exists && button.isHittable {
                        button.tap()
                        closed = true
                        break
                    }
                }
                if !closed {
                    // Drag from INSIDE a partial sheet (0.45) so
                    // fraction-detent sheets dismiss too; a second
                    // drag from the very top covers full covers.
                    let mid = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
                    let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
                    mid.press(forDuration: 0.05, thenDragTo: bottom)
                    sleep(1)
                    if !app.buttons["settings"].firstMatch.isHittable {
                        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
                        top.press(forDuration: 0.05, thenDragTo: bottom)
                    }
                }
                sleep(1)
                if app.buttons["settings"].firstMatch.isHittable { return }
            }
        }

        func tapWhenReady(_ element: XCUIElement, timeout: Int = 5) -> Bool {
            for _ in 0..<timeout {
                if element.exists && element.isHittable {
                    element.tap()
                    return true
                }
                sleep(1)
            }
            return false
        }

        // ── 1 · today ────────────────────────────────────────────
        snap("today_top")
        app.swipeUp()
        sleep(1)
        snap("today_state_band")
        app.swipeDown()
        sleep(1)

        // ── 2 · steps detail sheet ───────────────────────────────
        let stepsRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'steps'")
        ).firstMatch
        if stepsRow.exists {
            stepsRow.tap()
            sleep(2)
            snap("steps_sheet")
            closeSheet()
        }

        // ── 3 · future-day peek from the strip ───────────────────
        let day13 = app.buttons["13"].firstMatch
        if day13.exists && day13.isHittable {
            day13.tap()
            sleep(2)
            snap("day_peek_sheet")
            closeSheet()
        }

        // ── 4 · mark-as-done (long-press the method row) ─────────
        let methodRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'the method'")
        ).firstMatch
        for _ in 0..<4 where !(methodRow.exists && methodRow.isHittable) { sleep(1) }
        if methodRow.exists && methodRow.isHittable {
            methodRow.press(forDuration: 0.8)
            sleep(2)
            snap("mark_as_done_sheet")
            closeSheet()
        }

        // ── 5 · lesson reader ────────────────────────────────────
        if tapWhenReady(methodRow) {
            sleep(3)
            snap("lesson_reader_p1")
            closeSheet()
            sleep(1)
        }

        // ── 6 · workout brief (PreRoutine) ───────────────────────
        let moveRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'move'")
        ).firstMatch
        if tapWhenReady(moveRow) {
            sleep(3)
            snap("workout_brief")
            closeSheet()
            sleep(1)
        }

        // ── 7 · snap camera / consent chrome ─────────────────────
        let snapRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'snap a meal'")
        ).firstMatch
        if tapWhenReady(snapRow) {
            sleep(3)
            snap("snap_entry")
            // The camera's close affordance isn't exposed as a
            // .button — query ANY element type for the label.
            for label in ["cancel", "close", "xmark"] {
                let any = app.descendants(matching: .any)[label].firstMatch
                if any.exists && any.isHittable {
                    any.tap()
                    sleep(1)
                    break
                }
            }
            closeSheet()
            sleep(1)
        }

        // ── 8 · settings hub + sub-screens ───────────────────────
        let settings = app.buttons["settings"].firstMatch
        if settings.waitForExistence(timeout: 4) {
            settings.tap()
            sleep(2)
            snap("settings_hub")
            for row in ["my pace", "coach", "reminders", "food", "account", "feedback"] {
                let rowButton = app.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH %@", row)
                ).firstMatch
                guard rowButton.waitForExistence(timeout: 3), rowButton.isHittable else { continue }
                rowButton.tap()
                sleep(2)
                snap("settings_\(row.replacingOccurrences(of: " ", with: "_"))")
                let back = app.buttons["chevron.left"].firstMatch
                if back.exists && back.isHittable {
                    back.tap()
                } else {
                    app.buttons["back"].firstMatch.tap()
                }
                sleep(1)
            }
            closeSheet()
        }

        // ── 9 · jeni tab: chips → stream → tool card ─────────────
        app.buttons["jeni"].firstMatch.tap()
        sleep(2)
        snap("jeni_empty_chips")
        let roughDay = app.buttons["i had a rough day"].firstMatch
        if roughDay.exists {
            roughDay.tap()
            sleep(1)
            snap("jeni_streaming")
            sleep(4)
            snap("jeni_answer")
        }
        // Tool-card flow via the composer.
        let composer = app.textFields.firstMatch
        if composer.exists {
            composer.tap()
            composer.typeText("i weighed 74.2 this morning")
            let send = app.buttons["send"].firstMatch
            if send.exists { send.tap() }
            sleep(5)
            snap("jeni_tool_card")
        }
        // v3.0 — the tab bar yields to the keyboard now (product
        // behavior): dismiss the keyboard the way a user would
        // before switching tabs.
        if app.keyboards.count > 0 {
            app.swipeDown(velocity: .fast)
            sleep(1)
        }

        // ── 10 · becoming ────────────────────────────────────────
        app.buttons["becoming"].firstMatch.tap()
        sleep(2)
        snap("becoming_top")
        app.swipeUp()
        sleep(1)
        snap("becoming_journey_wins")

        // ── 11 · food journal (wins chain) ───────────────────────
        let journalChain = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'journal'")
        ).firstMatch
        if tapWhenReady(journalChain, timeout: 3) {
            sleep(2)
            snap("food_journal")
            // meal detail: tap the first plate row
            let plateRow = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'poke' OR label CONTAINS 'yogurt'")
            ).firstMatch
            if tapWhenReady(plateRow, timeout: 3) {
                sleep(2)
                snap("food_detail")
                closeSheet()
            }
            closeSheet()
        }

        // ── done ─────────────────────────────────────────────────
        XCTAssertGreaterThan(shot, 10, "inventory walked \(shot) surfaces")
    }

    /// Gate states + deterministic harness surfaces, one launch each.
    func testStatesLedger() throws {
        let dir = ProcessInfo.processInfo.environment["INVENTORY_DIR"]
            ?? "/tmp/jenifit_inventory"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        func launchAndSnap(_ args: [String], _ name: String, settle: UInt32 = 5) {
            let app = XCUIApplication()
            app.launchArguments = args
            app.launch()
            sleep(settle)
            let png = XCUIScreen.main.screenshot().pngRepresentation
            FileManager.default.createFile(atPath: "\(dir)/90_\(name).png", contents: png)
            app.terminate()
        }

        launchAndSnap(["--uitest-inapp-qa"], "wall_fresh")
        launchAndSnap(["--uitest-force-expired"], "wall_expired")
        launchAndSnap(["--uitest-pro-access", "--uitest-force-migration"], "migration_moment")
        launchAndSnap(["--debug-post-routine"], "workout_completion", settle: 6)
        launchAndSnap(["--debug-program-setup"], "program_setup_p1")
    }

    /// Rest-day leg: the breath beat + intro + (waits out a 1-minute
    /// session) the completion receipt.
    func testRestDayBreath() throws {
        let dir = ProcessInfo.processInfo.environment["INVENTORY_DIR"]
            ?? "/tmp/jenifit_inventory"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-seed-day", "14",
        ]
        app.launch()
        sleep(7)

        var shot = 0
        func snap(_ name: String) {
            let png = XCUIScreen.main.screenshot().pngRepresentation
            FileManager.default.createFile(
                atPath: "\(dir)/8\(shot)_\(name).png", contents: png
            )
            shot += 1
        }

        snap("today_rest_day")
        // v3: on a rest day the breath IS the one-thing card ("the one
        // thing, sixty seconds of breath"); older builds rendered a
        // "breathe" row — match either so the leg stays bisectable.
        let breathRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'sixty seconds of breath' OR label BEGINSWITH 'breathe'")
        ).firstMatch
        guard breathRow.waitForExistence(timeout: 6) else { return }
        breathRow.tap()
        sleep(3)
        snap("breath_intro")
        for label in ["begin", "start", "i'm ready", "breathe with her", "let's breathe"] {
            let b = app.buttons[label].firstMatch
            if b.exists && b.isHittable { b.tap(); break }
        }
        sleep(8)
        snap("breath_session")
        sleep(75)   // ride out the 1-minute default session
        snap("breath_receipt")
    }

    /// v1.1.4 — Home row gesture + past-day nav regression (device level).
    /// Pins the two shipped fixes end to end:
    ///  · Bug 2: tapping a PAST day-strip cell opens the read-only review
    ///    (before the fix the tap was dropped and nothing happened).
    ///  · Bug 1: a long-press opens the manual override foremost (a
    ///    clashing tap would stack the module cover on top), and a normal
    ///    tap AFTER a long-press still enters the module — proving the
    ///    longPressJustFired flag both suppresses the release-tap and
    ///    resets so it never eats a later real tap.
    /// Seeded at day 14 (a rest day): "the method" rhythm row is present
    /// (medium tier = daily lesson cadence) and days 1-13 are in the past.
    /// v3 note: the hero beat became the one-thing CARD, so the gesture
    /// regression pins a rhythm ROW (the surface the fix shipped on).
    func testHomeRowGesturesAndPastDay() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-seed-day", "14",
        ]
        app.launch()
        sleep(7)

        let breatheRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'the method'")
        ).firstMatch
        XCTAssertTrue(breatheRow.waitForExistence(timeout: 8),
                      "Today should render its rhythm rows")

        // ── Bug 2 — a PAST day-strip cell opens the review sheet.
        // Seeded at day 14, so day 13 is yesterday (past, and on-screen
        // next to today). Before the fix this tap did nothing.
        let pastCell = app.buttons.matching(
            NSPredicate(format: "label == '13' OR label BEGINSWITH 'Day 13'")
        ).firstMatch
        XCTAssertTrue(pastCell.waitForExistence(timeout: 5),
                      "the strip should expose past-day cells")
        pastCell.tap()
        XCTAssertTrue(app.buttons["got it"].waitForExistence(timeout: 5),
                      "tapping a past day should open the review sheet")
        app.buttons["got it"].firstMatch.tap()
        sleep(1)
        XCTAssertTrue(app.buttons["settings"].firstMatch.waitForExistence(timeout: 5),
                      "dismissing the review should return to Today")

        // ── Bug 1a — long-press opens the manual override, foremost.
        breatheRow.press(forDuration: 0.7)
        XCTAssertTrue(app.buttons["mark as done"].waitForExistence(timeout: 5),
                      "long-press should open the mark-as-done override")
        XCTAssertTrue(app.buttons["mark as done"].isHittable,
                      "the override must be foremost — a clashing tap would put a module cover on top of it")
        app.buttons["not yet"].firstMatch.tap()
        sleep(2)   // let the 0.7s longPressJustFired flag auto-reset
        XCTAssertTrue(app.buttons["settings"].firstMatch.isHittable,
                      "dismissing the override should return to Today")

        // ── Bug 1b — a normal tap after the long-press still enters the
        // module (flag reset; tap not swallowed) and is NOT the override.
        breatheRow.tap()
        sleep(3)
        XCTAssertFalse(app.buttons["mark as done"].exists,
                       "a normal tap must open the module, not the override")
        XCTAssertFalse(app.buttons["settings"].firstMatch.isHittable,
                       "a normal tap should have entered a full-screen module")
    }

    /// v2.4 — live a day: real mutations, not visits. Marks the
    /// method beat done (sheet confirm -> strike-through), logs a
    /// weight through the sheet, and ledgers the struck states.
    func testLivedDay() throws {
        let dir = ProcessInfo.processInfo.environment["INVENTORY_DIR"]
            ?? "/tmp/jenifit_inventory"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access", "--uitest-seed-program",
        ]
        app.launch()
        sleep(7)

        func snap(_ name: String) {
            let png = XCUIScreen.main.screenshot().pngRepresentation
            FileManager.default.createFile(atPath: "\(dir)/7\(name).png", contents: png)
        }

        // Mark the method beat done via the manual sheet.
        let methodRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'the method'")
        ).firstMatch
        guard methodRow.waitForExistence(timeout: 6) else { return }
        methodRow.press(forDuration: 0.8)
        sleep(2)
        let markDone = app.buttons["mark as done"].firstMatch
        if markDone.waitForExistence(timeout: 3) {
            markDone.tap()
            sleep(2)
        }
        snap("0_lived_method_struck")

        // Log a weight through the trend-check beat when present.
        let weighRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'trend check'")
        ).firstMatch
        if weighRow.exists && weighRow.isHittable {
            weighRow.tap()
            sleep(2)
            snap("1_lived_weigh_sheet")
            for label in ["save", "log it", "keep it"] {
                let b = app.buttons[label].firstMatch
                if b.exists && b.isHittable { b.tap(); break }
            }
            sleep(2)
        }
        snap("2_lived_day_state")
    }

    /// v2.7 — the interactive lesson close: pages to a rep-patched
    /// lesson (seed-day 3 -> D03) and ledgers the rep chip in both
    /// states.
    func testLessonRepChip() throws {
        let dir = ProcessInfo.processInfo.environment["INVENTORY_DIR"]
            ?? "/tmp/jenifit_inventory"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-seed-day", "3",
        ]
        app.launch()
        sleep(7)

        func snap(_ name: String) {
            let png = XCUIScreen.main.screenshot().pngRepresentation
            FileManager.default.createFile(atPath: "\(dir)/\(name).png", contents: png)
        }

        let methodRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'the method'")
        ).firstMatch
        guard methodRow.waitForExistence(timeout: 6) else { return }
        methodRow.tap()
        sleep(3)
        for _ in 0..<3 {
            let cont = app.buttons["continue"].firstMatch
            if cont.exists && cont.isHittable { cont.tap(); sleep(2) }
        }
        snap("95_lesson_close_rep_chip")
        let chip = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'keep this rep'")
        ).firstMatch
        if chip.exists && chip.isHittable {
            chip.tap()
            sleep(2)
            snap("96_lesson_rep_kept")
        }
    }

}
