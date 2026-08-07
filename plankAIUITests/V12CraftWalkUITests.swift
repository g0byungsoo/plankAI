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

    /// The kit gallery: every primitive arriving, then the glance
    /// layer below the fold — the ring's trace, the bars landing,
    /// the dot row, the scope morph, the insight pager.
    func testGalleryWalk() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--debug-v11-gallery"]
        app.launch()
        sleep(5)                       // the page arrival

        // Down to the glance sections, in watchable steps.
        app.swipeUp(velocity: .slow)
        sleep(2)
        app.swipeUp(velocity: .slow)
        sleep(3)                       // ring + bars arrive

        // The scope morph: walk a few words.
        for word in ["month", "3 months", "week"] {
            let b = app.buttons[word].firstMatch
            if b.exists && b.isHittable { b.tap(); usleep(700_000) }
        }
        sleep(1)

        // The insight pager: page twice, dwell on each card.
        app.swipeUp(velocity: .slow)
        sleep(2)
        let pager = app.scrollViews.firstMatch
        pager.swipeLeft(velocity: .slow)
        sleep(2)
        pager.swipeLeft(velocity: .slow)
        sleep(2)
    }
}
