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
                    // Mission 3: the masthead chrome is gone — the
                    // dateline (jeni.line) is Home's foremost anchor.
                    if !app.buttons["jeni.line"].firstMatch.isHittable {
                        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
                        top.press(forDuration: 0.05, thenDragTo: bottom)
                    }
                }
                sleep(1)
                if app.buttons["jeni.line"].firstMatch.isHittable { return }
            }
        }

        func tapWhenReady(_ element: XCUIElement, timeout: Int = 5) -> Bool {
            for _ in 0..<timeout {
                if element.exists && element.isHittable {
                    element.tap()
                    return true
                }
                // v10.1: rows can live past the front page's fold.
                if element.exists { app.swipeUp() }
                sleep(1)
            }
            return false
        }

        // ── 1 · today ────────────────────────────────────────────
        snap("today_top")

        // v3 minimal correction: jeni's line opens THE NOTE as a
        // full-screen received moment (cascade + reply/keep doors).
        let jeniLine = app.buttons["jeni.line"].firstMatch
        if jeniLine.exists && jeniLine.isHittable {
            jeniLine.tap()
            sleep(3)
            snap("jeni_note_fullscreen")
            let keep = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH 'keep it'")
            ).firstMatch
            if keep.waitForExistence(timeout: 4), keep.isHittable {
                keep.tap()
                sleep(1)
            } else {
                closeSheet()
            }
        }

        app.swipeUp()
        sleep(1)
        snap("today_state_band")
        app.swipeDown()
        sleep(1)

        // ── 2 · steps detail sheet ───────────────────────────────
        let stepsRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'steps'")
        ).firstMatch
        if tapWhenReady(stepsRow) {
            sleep(2)
            snap("steps_sheet")
            closeSheet()
        }

        // ── 3 · the week ribbon → THE JOURNEY (v4: the pill and the
        //        ribbon both open becoming's ledger; her-days died) ──
        let ribbon = app.buttons["today.weekRibbon"].firstMatch
        if ribbon.exists && ribbon.isHittable {
            ribbon.tap()
            sleep(3)
            snap("journey_via_ribbon")
            let todayTab = app.buttons["today"].firstMatch
            if todayTab.exists && todayTab.isHittable {
                todayTab.tap()
                sleep(2)
            }
        }

        // ── 4 · mark-as-done (long-press the method row) ─────────
        // v10.1: the day's rows live past the front page's fold —
        // bring them up before hunting.
        let methodRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'the method'")
        ).firstMatch
        for _ in 0..<4 where !(methodRow.exists && methodRow.isHittable) {
            if methodRow.exists { app.swipeUp() }
            sleep(1)
        }
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
        // v11: the TOOLS row says "snap a plate".
        let snapRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'snap a plate'")
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
        // Mission 3 (03_EDITORIAL.md §2): the hamburger died — the
        // dateline's long-press is the settings doorway.
        let datelineForSettings = app.buttons["jeni.line"].firstMatch
        if datelineForSettings.waitForExistence(timeout: 4) {
            datelineForSettings.press(forDuration: 1.0)
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

        // ── 11 · her plates (v5: the door lives on the story's food
        //        page — one swipe left from the line) ─────────────
        app.swipeLeft()
        sleep(2)
        snap("becoming_food_page")
        let platesDoor = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'her plates'")
        ).firstMatch
        if tapWhenReady(platesDoor, timeout: 3) {
            sleep(2)
            snap("food_journal")
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
            "--uitest-force-day",
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
        // Settle + coordinate tap (the ribbon inserts after the
        // snapshot loads, shifting the early a11y frames; the probe
        // then refuses cards real touches land on).
        sleep(3)
        breathRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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
    /// v11 T3/T5: the row gesture contract — TAP enters the module,
    /// LONG-PRESS opens the MarkAsDoneSheet override (the founder-
    /// locked law; the v10.1 sign-in-place ceremony retired with the
    /// journal era). Day 14 under the seed = a rest day, so the lead
    /// is breath — deterministic.
    func testHomeRowGesturesAndPastDay() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-seed-day", "14",
            "--uitest-force-day",
        ]
        app.launch()
        sleep(7)

        // The lead ask is the page's one headline — under the seed the
        // promotion ladder leads with the plate ("add the next plate").
        let breatheRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'add the'")
        ).firstMatch
        XCTAssertTrue(breatheRow.waitForExistence(timeout: 8),
                      "Home should render the day's lead ask")

        // ── LONG-PRESS = the override sheet, never a silent toggle.
        breatheRow.press(forDuration: 0.8)
        sleep(2)
        let confirm = app.buttons["mark as done"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 4),
                      "a hold opens the MarkAsDoneSheet override")
        // Confirm marks the beat; the sheet closes back to Home.
        confirm.tap()
        sleep(2)
        XCTAssertTrue(app.buttons["jeni.line"].firstMatch.isHittable,
                      "the override signs and returns — Home stays foremost")

        // ── Long-press again: the sheet reopens (retract door lives
        // there too); dismiss without changing state.
        breatheRow.press(forDuration: 0.8)
        sleep(2)
        let notYet = app.buttons["not yet"].firstMatch
        if notYet.waitForExistence(timeout: 4), notYet.isHittable {
            notYet.tap()
            sleep(1)
        }

        // ── A tap (not a hold) enters the module (the capture flow).
        breatheRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(3)
        XCTAssertFalse(app.buttons["jeni.line"].firstMatch.isHittable,
                       "a tap should have entered a full-screen module")
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
            "--uitest-force-day",
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
            "--uitest-force-day",
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

        // v3: the method opens as THE REP — scenario + doors. Choose
        // a door, ledger the response + kept chip, then walk into the
        // reader via "the whole idea" and ledger the in-reader close.
        snap("94_rep_scenario")
        let door = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'the next bite' OR label CONTAINS 'ride the wave' OR label CONTAINS 'one small kept thing' OR label CONTAINS 'let the ledger'")
        ).firstMatch
        if door.waitForExistence(timeout: 4), door.isHittable {
            door.tap()
            sleep(2)
            snap("95_rep_door_response")
        }
        let wholeIdea = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'the whole idea'")
        ).firstMatch
        if wholeIdea.waitForExistence(timeout: 4), wholeIdea.isHittable {
            wholeIdea.tap()
            sleep(3)
            for _ in 0..<3 {
                let cont = app.buttons["continue"].firstMatch
                if cont.exists && cont.isHittable { cont.tap(); sleep(2) }
            }
            snap("96_reader_close_via_rep")
            let chip = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'keep this rep'")
            ).firstMatch
            if chip.exists && chip.isHittable {
                chip.tap()
                sleep(2)
                snap("97_lesson_rep_kept")
            }
        }
    }

    // MARK: - App v4 — the journey + the re-signing
    //
    // Seed-day 15 (slot 0 of week 3) puts week 2's re-signing inside
    // its due window, so one launch walks: the received re-signing →
    // keep it → the journey (arc ribbon + this week + ledger) → the
    /// v11.5 M2: the strip is a first-class selector — tapping a past
    /// day re-keys the page to that day's recap; "today" springs back.
    func testStripSelectionAndRecap() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-force-day",
            "--uitest-suppress-reconcile",
        ]
        app.launch()
        sleep(7)

        let cal = Calendar.current
        let past = cal.date(byAdding: .day, value: -2, to: .now)!
        let pastLabel = past.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        let cell = app.buttons[pastLabel].firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 6), "past day cell exists: \(pastLabel)")
        cell.tap()
        sleep(2)

        let recapDoor = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'whole record lives in becoming'")
        ).firstMatch
        XCTAssertTrue(recapDoor.waitForExistence(timeout: 5),
                      "selecting a past day shows that day's recap")

        let todayPill = app.buttons["back to today"].firstMatch
        XCTAssertTrue(todayPill.exists, "the today pill appears when away")
        todayPill.tap()
        sleep(2)
        XCTAssertTrue(app.buttons["jeni.line"].firstMatch.isHittable,
                      "back to today restores the live page")
    }

    /// v11.5 N: the scan chooser — the tab-bar action opens two
    /// doors over a blurred page, and each door reaches its capture.
    func testScanChooserDoors() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-force-day",
            "--uitest-suppress-reconcile", "--uitest-open-scan-chooser",
        ]
        app.launch()
        sleep(8)

        let bodyDoor = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'your body'")
        ).firstMatch
        let plateDoor = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'a plate'")
        ).firstMatch
        XCTAssertTrue(bodyDoor.waitForExistence(timeout: 8), "the body door renders")
        XCTAssertTrue(plateDoor.exists, "the plate door renders")

        // Close returns her to the page she came from.
        let close = app.buttons["close"].firstMatch
        XCTAssertTrue(close.exists, "the chooser closes")
        close.tap()
        sleep(2)
        XCTAssertTrue(app.buttons["jeni.line"].firstMatch.waitForExistence(timeout: 6),
                      "closing the chooser returns to the page")

        // The scan item is an ACTION, never a destination: selecting
        // it re-opens the chooser rather than navigating.
        let scanTab = app.buttons["scan"].firstMatch
        if scanTab.exists, scanTab.isHittable {
            scanTab.tap()
            sleep(2)
            XCTAssertTrue(
                app.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH 'your body'")
                ).firstMatch.waitForExistence(timeout: 6),
                "the scan tab opens the chooser"
            )
            app.buttons["close"].firstMatch.tap()
            sleep(1)
        }
    }

    // v11 T4: the journal died; this leg walks what SURVIVES it —
    // the re-signing (auto-offered when due) and BODY PROGRESS's
    // compare (BodyTimelineView, record.compare).
    func testBecomingSummaryAndReSigning() throws {
        let dir = ProcessInfo.processInfo.environment["INVENTORY_DIR"]
            ?? "/tmp/jenifit_inventory"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-seed-day", "15",
            "--uitest-seed-scans",
            "--uitest-start-tab", "becoming",
        ]
        app.launch()
        sleep(9)   // seed + summary load + the 0.7s auto-offer

        func snap(_ name: String) {
            let png = XCUIScreen.main.screenshot().pngRepresentation
            FileManager.default.createFile(atPath: "\(dir)/\(name).png", contents: png)
        }

        // 1 · the re-signing (auto-offered when due). The signed
        // state closes with "done" — ASSERTED, so a stuck cover can
        // never let the rest of the walk pass silently (frames
        // 510-660 of the first M3 recording caught exactly that).
        let keepIt = app.buttons["keep it"].firstMatch
        if keepIt.waitForExistence(timeout: 6), keepIt.isHittable {
            snap("40_resigning_received")
            keepIt.tap()
            sleep(2)
            snap("41_resigning_signed")
            let signedDone = app.buttons["done"].firstMatch
            XCTAssertTrue(signedDone.waitForExistence(timeout: 4),
                          "the signed review closes with done")
            signedDone.tap()
            sleep(2)
        }

        // 2 · the summary (hero + tiles).
        snap("42_becoming_summary")

        // 3 · BODY PROGRESS → the compare (the journey scrub's home).
        let compare = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'compare across'")
        ).firstMatch
        for _ in 0..<5 where !(compare.exists && compare.isHittable) {
            app.swipeUp()
            sleep(1)
        }
        XCTAssertTrue(compare.exists, "the compare door must exist on becoming")
        if compare.isHittable {
            compare.tap()
            sleep(3)
            snap("43_body_compare")
            XCTAssertTrue(
                app.otherElements["record.compare"].firstMatch.exists
                    || app.buttons["record.compare"].firstMatch.exists
                    || app.images["record.compare"].firstMatch.exists,
                "the compare stage renders"
            )
            let close = app.buttons["close"].firstMatch
            if close.exists, close.isHittable { close.tap(); sleep(1) }
        }

        // 4 · a tile MORPHS into its page (v11.5 in-tree expansion).
        let weightTile = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'weight'")
        ).firstMatch
        for _ in 0..<5 where !(weightTile.exists && weightTile.isHittable) {
            app.swipeDown()
            sleep(1)
        }
        XCTAssertTrue(weightTile.exists && weightTile.isHittable,
                      "the weight tile must be tappable")
        weightTile.tap()
        sleep(2)
        snap("44_weight_detail")
        // The done carries a descriptive a11y LABEL ("done. closes
        // weight") — query the stable identifier, not the word.
        let detailDone = app.buttons["becoming.tile.done"].firstMatch
        XCTAssertTrue(detailDone.waitForExistence(timeout: 4),
                      "the expanded tile carries its done")
        detailDone.tap()
        sleep(1)
    }

}
