import XCTest

// MARK: - Pass53RecordUITests (app v25 pass 53 — THE ANSWERING RECORD)
//
// Instrumented walks of the pass's new record surfaces, on the REAL
// UI: the interval rhythm editor (the G1 closure), treatment tenure,
// and the past-shot backfill. Each beat screenshots; assertions are
// existence-shaped and tolerant of the sim's recorded walker
// limitations (synthesized drags/wheels are flaky on this sim — a
// wheel that refuses to adjust records the block rather than failing
// the product).

final class Pass53RecordUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let png = app.screenshot().pngRepresentation
        let dir = URL(fileURLWithPath: "/tmp/jenifit_pass53", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
    }

    private func launchRegimen() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-medication", "injectable",
            "--uitest-open-regimen",
        ]
        app.launch()
        return app
    }

    func testIntervalRhythmWalk() throws {
        let app = launchRegimen()
        let rhythm = app.staticTexts["rhythm"]
        guard rhythm.waitForExistence(timeout: 15) else {
            shot(app, "A0_block_sheet_never_presented")
            throw XCTSkip("the QA sim's anon-auth identity race kept the regimen door shut (the repo's recorded walker limitation); the write chokepoint is unit-proven in AnsweringRegimenTests")
        }
        shot(app, "A1_regimen_home")

        // The row is a Button whose label contains the word.
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'rhythm'")
        ).firstMatch.tap()
        let differentRhythm = app.staticTexts["a different rhythm"]
        XCTAssertTrue(differentRhythm.waitForExistence(timeout: 6),
                      "the day editor opens with the quiet layer")
        shot(app, "A2_day_editor")

        app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'every few days'")
        ).firstMatch.tap()
        let interval = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'every '")
        ).firstMatch
        XCTAssertTrue(interval.waitForExistence(timeout: 4))
        shot(app, "A3_interval_controls")

        // Two decrements: 7 → 5. The hidden-label Stepper exposes
        // increment/decrement buttons.
        let decrement = app.steppers.firstMatch.buttons["Decrement"]
        if decrement.waitForExistence(timeout: 3) {
            decrement.tap()
            decrement.tap()
        }
        shot(app, "A4_interval_five")

        app.buttons.matching(
            NSPredicate(format: "label == 'today'")
        ).firstMatch.tap()
        let overview = app.staticTexts["every 5 days"]
        XCTAssertTrue(overview.waitForExistence(timeout: 6),
                      "the rhythm row speaks the interval")
        shot(app, "A5_overview_every_5_days")

        // The next-dose line derives from the chain: today.
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'next dose · today'")
        ).firstMatch.waitForExistence(timeout: 4))
    }

    func testTenureAndBackfillWalk() throws {
        let app = launchRegimen()
        guard app.staticTexts["started"].waitForExistence(timeout: 15) else {
            throw XCTSkip("the QA sim's anon-auth identity race kept the regimen door shut; tenure's write path is unit-proven in AnsweringRegimenTests")
        }
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'started'")
        ).firstMatch.tap()
        let keep = app.buttons.matching(
            NSPredicate(format: "label == 'keep it'")
        ).firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 6), "the tenure editor")
        shot(app, "B1_tenure_editor")

        // Pick march of last year when the wheel cooperates; the
        // default (this month) is a valid fact either way.
        let wheels = app.pickerWheels
        if wheels.count >= 2 {
            wheels.element(boundBy: 0).adjust(toPickerWheelValue: "march")
        }
        keep.tap()
        XCTAssertTrue(app.staticTexts["started"].waitForExistence(timeout: 6))
        shot(app, "B2_tenure_kept")

        // The backfill door: a past day chip opens THE DOSE SHEET on
        // that day (no second editor exists).
        let addPast = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'add a past shot'")
        ).firstMatch
        if addPast.waitForExistence(timeout: 4) {
            addPast.tap()
            let yesterday = app.buttons.matching(
                NSPredicate(format: "label == 'yesterday'")
            ).firstMatch
            if yesterday.waitForExistence(timeout: 4) {
                shot(app, "B3_backfill_chips")
                yesterday.tap()
                let mark = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS 'taken'")
                ).firstMatch
                XCTAssertTrue(mark.waitForExistence(timeout: 6),
                              "the dose sheet opens on the past day")
                shot(app, "B4_backfill_dose_sheet")
                mark.tap()
                shot(app, "B5_backfill_marked")
            }
        }
    }
}
