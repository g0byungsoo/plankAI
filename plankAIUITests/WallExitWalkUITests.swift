import XCTest

// MARK: - WallExitWalkUITests
//
// The App Store 5.6 regression walk. Review of 1.1.7 (28) rejected the
// build with "the (X) button was unresponsive" — the wall's close
// control walked a three-rung offer ladder and then fell through to a
// no-op, and two of its three gates are @AppStorage, so the dead state
// was where every returning user lived.
//
// --uitest-wall-spent arrives in exactly that state: both once-flags
// consumed, nothing left to offer. Under the old code this walk could
// not pass — the X produced no state change of any kind. It now has to
// stand the wall down, and the trip has to be reversible.

final class WallExitWalkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSpentWallCloseButtonAlwaysResponds() throws {
        let app = XCUIApplication()
        // No --uitest-pro-access: unentitled, so the phase machine
        // lands on .wall(.fresh). --uitest-wall-spent burns the offer
        // budget the moment the wall appears.
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-wall-spent"]
        app.launch()

        // The wall paints its hero + pricing rows behind an entrance
        // cascade; wait on the control itself rather than a fixed sleep.
        let closeButton = app.buttons["Close paywall"].firstMatch
        XCTAssertTrue(
            closeButton.waitForExistence(timeout: 30),
            "the wall never presented its close button"
        )
        XCTAssertTrue(closeButton.isHittable, "the close button is not hittable")
        takeShot(app, name: "wall-1-before-close")

        // THE REJECTION. One tap, on a wall with no offer left, must
        // produce a visible change of surface.
        closeButton.tap()

        let seePlans = app.buttons["see the plans"].firstMatch
        XCTAssertTrue(
            seePlans.waitForExistence(timeout: 10),
            "the X did not stand the wall down — this is the 5.6 rejection"
        )
        takeShot(app, name: "wall-2-stood-down")

        // The stand-down is an exit, not a trap: the buy surface is
        // gone and the recovery doors are present.
        XCTAssertFalse(
            closeButton.exists,
            "the paywall is still mounted after standing down"
        )
        XCTAssertTrue(
            app.buttons["already subscribed · restore"].firstMatch.exists,
            "restore is missing from the stand-down"
        )

        // And it is reversible — she can change her mind without a
        // relaunch.
        seePlans.tap()
        XCTAssertTrue(
            closeButton.waitForExistence(timeout: 10),
            "see the plans did not return to the wall"
        )
        takeShot(app, name: "wall-3-back-to-plans")

        // The second close must behave exactly like the first. A
        // control that works once and dies is the bug we are fixing.
        closeButton.tap()
        XCTAssertTrue(
            seePlans.waitForExistence(timeout: 10),
            "the close button went dead on its second press"
        )
        takeShot(app, name: "wall-4-second-close")
    }

    private func takeShot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
