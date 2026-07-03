import XCTest

// MARK: - SurfaceInventoryUITests
//
// App v2.2 (docs/app_v2/15_SURFACE_INVENTORY.md). The coverage
// walker: drives the seeded app through every reachable surface —
// beats, sheets, module doorways, settings sub-screens, tabs — and
// writes a PNG per stop to INVENTORY_DIR (simulator processes share
// the host filesystem). The doc's before/after ledger cites these.
//
// Run:
//   INVENTORY_DIR=/tmp/jenifit_inventory xcodebuild test \
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
                for label in ["got it", "not yet", "not today", "cancel", "close",
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

        // ── 10 · becoming ────────────────────────────────────────
        app.buttons["becoming"].firstMatch.tap()
        sleep(2)
        snap("becoming_top")
        app.swipeUp()
        sleep(1)
        snap("becoming_journey_wins")

        // ── done ─────────────────────────────────────────────────
        XCTAssertGreaterThan(shot, 10, "inventory walked \(shot) surfaces")
    }
}
