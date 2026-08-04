import XCTest

// v9 P1 batch-A proof: the Body Vision flow end-to-end on the sim.
// The sim's camera shows no person, so the pose gate can never arm —
// --uitest-scan-allow-manual opens the quiet manual door instantly
// and the flow still exercises the REAL pipeline: consent → capture
// → silhouette render (empty mask → paper, graceful) → keep →
// record, persisted across a cold relaunch. The guided pose
// coaching itself is a founder device walk (a camera can't be
// seeded with a person).
final class BodyScanProofUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private let qaArgs = ["--uitest-inapp-qa", "--uitest-pro-access",
                          "--uitest-seed-program",
                          "--uitest-open-body-scan", "--uitest-scan-allow-manual"]

    func testConsentCaptureKeepAndPersist() throws {
        let app = XCUIApplication()
        // Launch 1 resets scan state (legs share the install).
        app.launchArguments = qaArgs + ["--uitest-reset-body-scan"]
        app.launch()

        // Consent (first run) — the truth sheet in the clinical register.
        let consentTitle = app.staticTexts["your record, private."]
        XCTAssertTrue(consentTitle.waitForExistence(timeout: 12), "consent never appeared")
        takeShot(app, name: "p1-proof-1-consent")
        app.buttons["begin"].firstMatch.tap()

        // Camera permission (system alert, first run only).
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            let allow = springboard.alerts.buttons.matching(
                NSPredicate(format: "label IN {'OK', 'Allow'}")
            ).firstMatch
            if allow.exists, allow.isHittable { allow.tap(); break }
            usleep(400_000)
        }

        // Capture — the manual door (sim has no person to align).
        let captureNow = app.buttons["capture now"]
        XCTAssertTrue(captureNow.waitForExistence(timeout: 12), "manual door never opened")
        takeShot(app, name: "p1-proof-2-capture")
        captureNow.tap()

        // Landed — keep it.
        let keep = app.buttons["keep it"]
        XCTAssertTrue(keep.waitForExistence(timeout: 15), "landed moment never arrived")
        takeShot(app, name: "p1-proof-3-landed")
        keep.tap()

        // Record — the first scan exists.
        let recordLine = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'first scan'")
        ).firstMatch
        XCTAssertTrue(recordLine.waitForExistence(timeout: 10), "record view missing the scan")
        takeShot(app, name: "p1-proof-4-record")

        // Cold relaunch — the record persists; consent never re-asks.
        app.terminate()
        app.launchArguments = qaArgs
        app.launch()
        let persisted = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'first scan'")
        ).firstMatch
        XCTAssertTrue(persisted.waitForExistence(timeout: 12),
                      "the scan did not survive a cold relaunch")
        XCTAssertFalse(app.staticTexts["your record, private."].exists,
                       "consent must not re-ask once recorded")
    }

    // MARK: - P2: the body page + the timeline/compare (seeded sim)

    func testBecomingBodyPageAndTimeline() throws {
        let app = XCUIApplication()
        // Launch 1 establishes auth + seeds; launch 2 composes with
        // the seeded record present before becoming's first refresh.
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-pro-access",
                               "--uitest-seed-program", "--uitest-seed-scans"]
        app.launch()
        sleep(5)
        app.terminate()
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-pro-access",
                               "--uitest-seed-program", "--uitest-seed-scans",
                               "--uitest-start-tab", "becoming"]
        app.launch()
        sleep(4)

        // Swipe off the cover into the carousel; the body page rides
        // second (line → body). Seeded span = 14 days (−21 → −7) →
        // the exact floor line is deterministic.
        app.swipeLeft()
        sleep(1)
        app.swipeLeft()
        sleep(1)
        let floorLine = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'week 2 of your record'")
        ).firstMatch
        XCTAssertTrue(floorLine.waitForExistence(timeout: 8),
                      "the body page's floor-gated line never rendered")
        takeShot(app, name: "p2-proof-1-body-page")

        // Open her record.
        app.buttons["open your record"].firstMatch.tap()
        let recordTitle = app.staticTexts["YOUR RECORD"]
        XCTAssertTrue(recordTitle.waitForExistence(timeout: 8), "timeline never opened")
        XCTAssertTrue(app.staticTexts["WEEK BY WEEK"].waitForExistence(timeout: 5))
        takeShot(app, name: "p2-proof-2-timeline")

        // The compare scrub: drag toward "then", capture mid-blend.
        let stage = app.otherElements["compare, then and now"].firstMatch
        if stage.exists {
            let from = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            let to = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
            from.press(forDuration: 0.05, thenDragTo: to)
        } else {
            app.swipeRight()
        }
        sleep(1)
        takeShot(app, name: "p2-proof-3-compare-then")
    }

    private func takeShot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
