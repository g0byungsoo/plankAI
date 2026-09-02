import XCTest

// MARK: - SayItWalkUITests (v25 E7 — SAY IT)
//
// The era's loop, driven for real: the centre tab → a typed sentence →
// the return key → the reading → the answer. No mocks in the path
// except the estimate itself (the sim has no network to the vision EF,
// so the walk asserts up to the point where the network would answer,
// and the answer morph is proven separately in the harness leg below,
// which runs the SAME `fileIt()` the button runs).
//
// Screenshots land in INVENTORY_DIR so frames can be inspected one by
// one — the era's design loop is capture → look → fix → repeat.
final class SayItWalkUITests: XCTestCase {

    private var shot = 0

    private var dir: String {
        ProcessInfo.processInfo.environment["INVENTORY_DIR"]
            ?? "/tmp/jenifit_sayit"
    }

    private func snap(_ name: String) {
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let path = "\(dir)/\(String(format: "%02d", shot))_\(name).png"
        FileManager.default.createFile(atPath: path, contents: png)
        shot += 1
    }

    private func launch(_ extraArgs: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitest-inapp-qa", "--uitest-pro-access",
            "--uitest-seed-program", "--uitest-force-hour", "16",
        ] + extraArgs
        app.launch()
        sleep(9)
        return app
    }

    // MARK: - THE DOOR IS WORDS
    //
    // Proves the era's central claim in gestures: from the tab bar, a
    // record costs one sentence and one return key.

    func testTheDoorIsWords() {
        let app = launch(["--uitest-seed-week", "--uitest-open-scan-chooser"])
        sleep(3)
        snap("capture-surface")

        // The question changed from a lens question to a record one.
        XCTAssertTrue(
            app.staticTexts["what did you eat?"].waitForExistence(timeout: 6),
            "the capture surface must ask what she ate, not what we are looking at"
        )

        // E5's meal door survives the field's arrival. p68 — the BODY
        // door assertion is gone: p57 removed Body Snap's entrances
        // (founder decision, ScanChooser.swift carries the comment);
        // this walker had been asserting the pre-p57 product — the
        // exact stale-walker class p46 recorded.
        XCTAssertTrue(app.buttons["a meal. counted from one photo"].exists,
                      "the meal door must survive")

        // The field: tap, type, and the submit arms itself.
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the field must exist")
        field.tap()
        sleep(1)
        snap("keyboard-up")
        field.typeText("greek yogurt and berries")
        sleep(1)
        snap("typed")

        XCTAssertTrue(app.buttons["count it"].isEnabled,
                      "typed words must arm the submit")
    }

    // MARK: - Sparse, zero and no-floor states
    //
    // The standing line is the capture surface's only claim, so its
    // honesty matters more than its presence. An empty day must not
    // invent a start; a user with no weight on file must never be
    // shown a floor she did not give us.

    func testStandingLineNeverInventsANumber() {
        let app = launch(["--uitest-wipe-food", "--uitest-open-scan-chooser"])
        sleep(3)
        snap("zero-state")

        XCTAssertTrue(
            app.staticTexts["what did you eat?"].waitForExistence(timeout: 6),
            "the question stands with or without a record"
        )
        // Nothing on file → the standing line never says "0 g".
        //
        // The matcher is anchored, not a `CONTAINS '0 g of protein'`:
        // that substring also hits "9**0 g** of protein" and the first
        // cut of this test failed on a perfectly correct sentence. An
        // assertion that fires on prose it should allow teaches the
        // next person to delete it.
        let zeroish = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH '0 g' OR label CONTAINS ' 0 g of protein'")
        )
        XCTAssertEqual(zeroish.count, 0, "an empty day is not '0 g'")

        // And it never shows a floor she did not give us: with no
        // record the line is either absent or states the floor alone.
        let ratio = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '.*[0-9]+ of [0-9]+ g.*'")
        ).firstMatch
        if ratio.exists {
            XCTFail("with nothing on file the standing line must not show a ratio: \(ratio.label)")
        }
    }

    // MARK: - THE ANSWER
    //
    // The reading resolves to one sentence and files. Driven through
    // the harness because the sim cannot reach the vision EF, but via
    // the SAME `fileIt()` path the pill fires.

    /// The RESTING reading — no auto-file, so the grid is still there
    /// to assert against. (The first cut of this test launched WITH
    /// `--uitest-file-plate` and then asserted the grid six seconds
    /// later, by which time the answer had correctly replaced it: four
    /// failures, all the test's own.)
    func testTheReadingLeadsWithProtein() {
        let app = XCUIApplication()
        app.launchArguments = ["--debug-result-carousel"]
        app.launch()
        sleep(6)
        snap("reading")

        // PROTEIN LEADS (00_THE_SYSTEM §9). The lead cell carries the
        // grams and the day's floor; the kcal ring is gone.
        XCTAssertTrue(
            app.staticTexts["PROTEIN"].waitForExistence(timeout: 6),
            "protein must lead the reading"
        )
        XCTAssertEqual(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS '% of today'")
            ).count,
            0,
            "the kcal ring's percentage caption must be gone"
        )

        // The founder's asks, visible at rest rather than below a fold.
        XCTAssertTrue(app.staticTexts["fiber"].exists, "fiber must render")
        XCTAssertTrue(app.staticTexts["sugar intake"].exists, "sugar must render")
        XCTAssertTrue(app.staticTexts["sodium"].exists, "sodium must render")
        // …and the micronutrients USDA was already paying for.
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH 'vitamin' OR label IN {'b12','calcium','iron','magnesium','potassium','zinc'}")
            ).count > 0,
            "a USDA-grounded plate must be able to name what it carried"
        )
    }

    /// THE ANSWER — the same `fileIt()` the pill fires, on film.
    func testTheReadingAnswersAndFiles() {
        let app = XCUIApplication()
        app.launchArguments = ["--debug-result-carousel", "--uitest-file-plate"]
        app.launch()
        // --uitest-file-plate fires fileIt() 2.2s after the reading
        // appears; the sentence rises ~0.4s after that.
        sleep(9)
        snap("the-answer")

        let answered = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'g of protein'")
        ).firstMatch
        XCTAssertTrue(answered.waitForExistence(timeout: 6),
                      "the reading must resolve to a sentence about protein")
        // The grid is gone: the sentence took its place, it did not
        // stack on top of it.
        XCTAssertFalse(app.staticTexts["PROTEIN"].exists,
                       "the grid must leave before the sentence arrives")
        // Never a verdict, never a percentage, on the surface itself.
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '%'")).count,
            0,
            "the answer may never carry a percentage"
        )
    }
}
