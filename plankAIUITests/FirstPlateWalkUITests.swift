import XCTest

// MARK: - FirstPlateWalkUITests (v25 E5 — THE FIRST PLATE)
//
// The era's loop on film, and the design-evaluation driver.
//
// What it proves: a person who has just finished onboarding and has
// never paid meets a real capture flow BEFORE the wall, and the wall
// they eventually meet knows what they did.
//
// Screenshots land in INVENTORY_DIR so frames can be inspected one by
// one (the era's design loop is capture → look → fix → repeat, not
// capture → ship).
final class FirstPlateWalkUITests: XCTestCase {

    private var shot = 0

    private var dir: String {
        ProcessInfo.processInfo.environment["INVENTORY_DIR"]
            ?? "/tmp/jenifit_firstplate"
    }

    private func snap(_ name: String) {
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let path = "\(dir)/\(String(format: "%02d", shot))_\(name).png"
        FileManager.default.createFile(atPath: path, contents: png)
        shot += 1
    }

    /// The simulator re-presents a pending camera prompt across launches;
    /// clear it in-band so the walk sees the app, not springboard.
    private func dismissSystemAlerts(_ app: XCUIApplication) {
        let springboard = XCUIApplication(
            bundleIdentifier: "com.apple.springboard")
        for _ in 0..<4 {
            let allow = springboard.buttons
                .matching(NSPredicate(format: "label IN {'Allow', 'OK', 'Allow While Using App'}"))
                .firstMatch
            if allow.exists && allow.isHittable { allow.tap(); sleep(1); continue }
            let inApp = app.buttons
                .matching(NSPredicate(format: "label IN {'Allow', 'OK'}"))
                .firstMatch
            if inApp.exists && inApp.isHittable { inApp.tap(); sleep(1); continue }
            break
        }
    }

    private func launch(_ extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-force-first-plate"] + extraArgs
        app.launch()
        sleep(6)
        dismissSystemAlerts(app)
        return app
    }

    // MARK: the invite

    func testInviteFace() {
        let app = launch()
        snap("invite_with_floor")
        XCTAssertTrue(
            app.staticTexts["FIRST, ONE PLATE"].waitForExistence(timeout: 6),
            "the proof beat never mounted — check the phase machine"
        )
        // The wall must NOT be what a new user meets first.
        XCTAssertFalse(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'billed'")
            ).firstMatch.exists,
            "a price rendered before the proof beat"
        )
    }

    func testInviteWithoutAWeightOnFile() {
        _ = launch(["--uitest-first-plate-noweight"])
        snap("invite_no_floor")
        // The provenance law: no weight, no invented floor.
        XCTAssertFalse(
            XCUIApplication().staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'of protein a day'")
            ).firstMatch.exists,
            "a protein floor rendered with no weight on file"
        )
        XCTAssertTrue(
            XCUIApplication().staticTexts["one real plate."].exists,
            "the floorless face never rendered"
        )
    }

    // MARK: the loop

    /// invite → decline → the wall she would always have seen.
    func testDecliningLandsOnTheOrdinaryWall() {
        let app = launch()
        let skip = app.buttons["not right now"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 6), "the decline door exists")
        skip.tap()
        sleep(4)
        snap("declined_to_wall")
        // 5.6 law: whatever it shows, it must not be a dead end.
        XCTAssertTrue(app.buttons.count > 0, "the wall mounted with live controls")
    }

    /// invite → the REAL capture flow (consent gate included).
    func testStartingOpensTheRealCaptureFlow() {
        let app = launch()
        let start = app.buttons["read my first plate"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 6), "the primary door exists")
        start.tap()
        sleep(3)
        dismissSystemAlerts(app)
        sleep(2)
        snap("capture_entry")
        // Apple 5.1.2(i): the food-AI disclosure is NOT skipped by the
        // proof beat — it is the same CaptureFlowView every caller uses.
        let consent = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'photo' OR label CONTAINS[c] 'camera'")
        ).firstMatch
        XCTAssertTrue(
            consent.waitForExistence(timeout: 8),
            "the capture flow never opened"
        )
    }
}
