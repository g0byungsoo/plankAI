import XCTest

// MARK: - V12CraftWalkUITests
//
// THE CRAFT PASS's loop driver (docs/app_v12/00_CRAFT.md §4): slow,
// watchable walks of the surfaces this pass touches. Videos are
// recorded from the host with `simctl io recordVideo` around the run;
// the legs pace themselves so every arrival, morph and landing is on
// film. Run legs SOLO (house law — unit-suite chaining drops presses).

final class V12CraftWalkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private var shot = 0
    private var dir: String {
        ProcessInfo.processInfo.environment["INVENTORY_DIR"] ?? "/tmp/v12_walk"
    }

    private func snap(_ name: String) {
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let path = "\(dir)/\(String(format: "%02d", shot))_\(name).png"
        FileManager.default.createFile(atPath: path, contents: png)
        shot += 1
    }

    /// Scroll probe — which gesture actually moves a JeniPage.
    func testGalleryProbe() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--debug-v11-gallery"]
        app.launch()
        sleep(4)
        snap("p0_top")
        let sv = app.scrollViews.firstMatch
        print("V12PROBE scrollViews=\(app.scrollViews.count) svFrame=\(sv.frame)")
        for label in ["NUMERALS COUNT", "THE SCOPE MORPHS", "INSIGHTS PAGE",
                      "3 months", "continue"] {
            let e = app.staticTexts[label].firstMatch
            let b = app.buttons[label].firstMatch
            print("V12PROBE '\(label)' textExists=\(e.exists) btnExists=\(b.exists) frame=\(e.exists ? e.frame : b.frame)")
        }

        app.swipeUp()
        sleep(1)
        snap("p1_appSwipe")

        app.scrollViews.firstMatch.swipeUp()
        sleep(1)
        snap("p2_svSwipe")

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        start.press(forDuration: 0.06, thenDragTo: end,
                    withVelocity: .default, thenHoldForDuration: 0.12)
        sleep(1)
        snap("p3_coordDrag")
    }

    /// The kit gallery: the self-driving tour (synthesized drags
    /// cannot scroll this sim runtime — probe-proven below). The leg
    /// keeps the app alive while the tour walks every glance section;
    /// the host records around it.
    func testGalleryWalk() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--debug-v11-gallery", "--debug-gallery-tour"]
        app.launch()
        sleep(30)
        XCTAssertTrue(app.staticTexts["INSIGHTS PAGE"].exists,
                      "the glance sections rendered")
    }
}
