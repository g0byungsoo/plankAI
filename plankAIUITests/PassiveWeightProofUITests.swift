import XCTest

// v9 P0 exit-criterion proof (docs/app_v9/02_PLAN.md P0): a body-mass
// sample in Apple Health lands in her trend with ZERO manual weigh-in
// taps. Launch 1 seeds two HK samples (71.5 today, 72.2 three days
// back) via --debug-hk-write-weight — the only taps are the one-time
// system permission grant, the same grant a real scale user gave in
// onboarding. Launch 2 runs fully silent: the launch bootstrap
// imports, and Becoming's landing read speaks a DOWN trend.
// Why "down" is the proof: the seeded program carries exactly one
// starting weigh-in (75 kg), which alone can only ever read steady —
// a downward read is impossible without the imported lower samples.
final class PassiveWeightProofUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testScaleSampleLandsInTrendWithZeroTaps() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-pro-access",
                               "--uitest-seed-program",
                               "--debug-hk-write-weight", "71.5"]
        app.launch()

        // The Health Access sheet (write+read, DEBUG seeder only).
        // "Turn On All" row, then "Allow" — checked in both the app
        // proxy and springboard scopes (iOS hosts it in-process, but
        // stay defensive).
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(25)
        var granted = false
        while Date() < deadline, !granted {
            for scope in [app, springboard] {
                let turnOnAll = scope.staticTexts["Turn On All"].firstMatch
                if turnOnAll.exists, turnOnAll.isHittable { turnOnAll.tap() }
                let allow = scope.buttons["Allow"].firstMatch
                if allow.exists, allow.isHittable {
                    allow.tap()
                    granted = true
                    break
                }
            }
            if !granted { usleep(500_000) }
        }
        XCTAssertTrue(granted, "the Health Access sheet never offered Allow")

        // Let the seeder finish writing + the first import settle.
        sleep(4)
        takeShot(app, name: "p0-proof-1-post-grant")

        // Relaunch SILENT — the passive path: bootstrap import only.
        app.terminate()
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-pro-access",
                               "--uitest-seed-program"]
        app.launch()
        sleep(5)

        // Becoming's index must speak the imported weigh-ins.
        let becomingTab = app.tabBars.buttons["becoming"].firstMatch
        XCTAssertTrue(becomingTab.waitForExistence(timeout: 10), "no becoming tab")
        becomingTab.tap()
        sleep(2)

        let downLine = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'down about'")
        ).firstMatch
        XCTAssertTrue(downLine.waitForExistence(timeout: 10),
                      "imported weigh-ins never reached the trend read")
        takeShot(app, name: "p0-proof-2-trend-read")
    }

    private func takeShot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
