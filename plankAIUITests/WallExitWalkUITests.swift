import XCTest

// MARK: - WallExitWalkUITests
//
// The App Store 5.6 regression walk, twice rejected and now answered
// from both sides:
//
//   1.1.7 (28) — "the (X) button was unresponsive." The close control
//   walked a three-rung offer ladder and fell through to a no-op once
//   its @AppStorage gates were spent, which is where every returning
//   user lived.
//
//   1.1.7 (32) — "after we dismissed the purchase screen, another one
//   was displayed." The 2026-08-10 answer to the first rejection was to
//   make the X always produce SOMETHING, and it chose an offer as that
//   something. Apple's line is none.
//
// So the walk now asserts the only behaviour that satisfies both: ONE
// press, EVERY time, from a fresh install, produces a visible non-
// purchase destination. No dead end, and no offer.

final class WallExitWalkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWallCloseButtonAlwaysStandsDownAndNeverOffers() throws {
        let app = XCUIApplication()
        // No --uitest-pro-access: unentitled, so the phase machine
        // lands on .wall(.fresh). A FRESH install — the state the
        // reviewer met, and the state the old ladder answered with an
        // offer. There is no offer budget left to burn: the flags, the
        // rule and both offer sheets are gone.
        app.launchArguments = ["--uitest-inapp-qa"]
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

        // BOTH REJECTIONS, IN ONE TAP. It must produce a visible change
        // of surface (28), and that surface must not be another price
        // (32).
        closeButton.tap()

        let seePlans = app.buttons["see the plans"].firstMatch
        XCTAssertTrue(
            seePlans.waitForExistence(timeout: 10),
            "the X did not stand the wall down — this is the 1.1.7 (28) rejection"
        )
        takeShot(app, name: "wall-2-stood-down")

        for offer in ["not today", "or the year", "keep the year",
                      "try the week", "maybe later"] {
            XCTAssertFalse(
                app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", offer)
                ).firstMatch.exists,
                "dismissing the wall presented an offer carrying '\(offer)' — "
                + "this is the 1.1.7 (32) rejection"
            )
        }

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
