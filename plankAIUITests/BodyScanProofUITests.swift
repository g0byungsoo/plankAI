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
        tapBeginUntilConsentYields(app)

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

    // MARK: - P2/v10: the record landing + the timeline/compare

    func testBecomingBodyPageAndTimeline() throws {
        let app = XCUIApplication()
        // Launch 1 establishes auth + seeds; launch 2 composes with
        // the seeded record present before becoming's first refresh.
        // Reset on BOTH launches: earlier legs in this class leave a
        // fresh scan behind, and seed-scans no-ops on any record.
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-pro-access",
                               "--uitest-seed-program",
                               "--uitest-reset-body-scan", "--uitest-seed-scans"]
        app.launch()
        sleep(5)
        app.terminate()
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-pro-access",
                               "--uitest-seed-program",
                               "--uitest-reset-body-scan", "--uitest-seed-scans",
                               "--uitest-start-tab", "becoming"]
        app.launch()
        sleep(4)

        // v10 (V4): the LANDING leads with her figure — the matted
        // scan is the journal's opening page, no swiping required.
        let mat = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'your latest scan'")
        ).firstMatch
        XCTAssertTrue(mat.waitForExistence(timeout: 10),
                      "the landing never led with her figure")
        takeShot(app, name: "p2-proof-1-record-landing")

        // Open her record from the mat.
        mat.tap()
        let recordTitle = app.staticTexts["YOUR RECORD"]
        XCTAssertTrue(recordTitle.waitForExistence(timeout: 8), "timeline never opened")
        // Seeded span = 14 days (−21 → −7) → the exact floor line is
        // deterministic; the record explains its own standing (v10).
        let floorLine = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'week 2 of your record'")
        ).firstMatch
        XCTAssertTrue(floorLine.waitForExistence(timeout: 8),
                      "the record's floor-gated line never rendered")
        XCTAssertTrue(app.staticTexts["WEEK BY WEEK"].waitForExistence(timeout: 5))
        takeShot(app, name: "p2-proof-2-timeline")

        // The compare scrub: drag toward "then", then release —
        // v10 (V5): the blend settles to the nearest pole and the
        // stage SPEAKS which scan it rests on (asserted, not hoped).
        let stage = app.otherElements["record.compare"].firstMatch
        XCTAssertTrue(stage.waitForExistence(timeout: 5), "the compare stage is missing")
        XCTAssertTrue((stage.value as? String)?.hasPrefix("showing") == true,
                      "the compare never spoke its pole")
        let restingOnNow = stage.value as? String
        let from = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let to = stage.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5))
        from.press(forDuration: 0.05, thenDragTo: to)
        sleep(1)
        let settled = stage.value as? String
        XCTAssertNotEqual(settled, restingOnNow,
                          "the drag toward then must settle the compare on the then pole")
        takeShot(app, name: "p2-proof-3-compare-then")
    }

    // MARK: - v10: the guided capture, walked by the pose script

    /// --uitest-scan-simulate-pose scripts a person into the camera-
    /// less sim: searching → aligned → the arming frame inks in →
    /// countdown → shutter → THE DEVELOP → keep. The one flow the
    /// founder device walk used to be the only witness of.
    func testGuidedCaptureSimulatedPose() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-pro-access",
                               "--uitest-seed-program",
                               "--uitest-reset-body-scan",
                               "--uitest-open-body-scan",
                               "--uitest-scan-simulate-pose"]
        app.launch()

        XCTAssertTrue(app.staticTexts["your record, private."].waitForExistence(timeout: 12),
                      "consent never appeared")
        tapBeginUntilConsentYields(app)

        // Camera permission (system alert, first run only) — break
        // the moment the capture chrome is up so the wait never
        // outlives the scripted flow.
        let searchingLine = app.staticTexts["stand where I can see all of you"]
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if searchingLine.exists { break }
            let allow = springboard.alerts.buttons.matching(
                NSPredicate(format: "label IN {'OK', 'Allow'}")
            ).firstMatch
            if allow.exists, allow.isHittable { allow.tap(); break }
            usleep(300_000)
        }

        // The script walks the coaching: searching first…
        XCTAssertTrue(searchingLine.waitForExistence(timeout: 6),
                      "the searching coach line never rendered")
        takeShot(app, name: "c-proof-1-chamber-searching")
        // …then the held pose ("hold there") arms the frame.
        XCTAssertTrue(app.staticTexts["hold there"].waitForExistence(timeout: 10),
                      "the aligned coach line never rendered")
        takeShot(app, name: "c-proof-2-armed")

        // Countdown → shutter → THE DEVELOP lands her on keep it.
        let keep = app.buttons["keep it"]
        XCTAssertTrue(keep.waitForExistence(timeout: 20), "the landed moment never arrived")
        sleep(3)   // the develop wash completes on camera
        takeShot(app, name: "c-proof-3-developed")
        keep.tap()

        let recordLine = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'first scan'")
        ).firstMatch
        XCTAssertTrue(recordLine.waitForExistence(timeout: 10),
                      "the record never kept the scripted scan")
    }

    /// The launch loader can still cover consent when its title first
    /// EXISTS (existence ≠ visibility) — a tap then lands on the
    /// loader and consent stays. Tap only while hittable, and keep
    /// tapping until the sheet actually yields.
    private func tapBeginUntilConsentYields(_ app: XCUIApplication) {
        let consentTitle = app.staticTexts["your record, private."]
        let begin = app.buttons["begin"].firstMatch
        let deadline = Date().addingTimeInterval(15)
        while consentTitle.exists, Date() < deadline {
            if begin.exists, begin.isHittable { begin.tap() }
            usleep(700_000)
        }
        XCTAssertFalse(consentTitle.exists, "consent never yielded to begin")
    }

    private func takeShot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
