import XCTest

// E8.2 — the Move blocker, closed in the sim. E8.1 shipped Move with
// its HealthKit rows "proven by construction, not by a frame" and
// recorded a device walk as the only way to see them. The premise was
// wrong in a useful way: the simulator has no SENSORS, but its
// HealthKit STORE is real. Launch 1 writes the exact sample shapes a
// watch or gym app would (two strength workouts, one yoga as the
// negative control, a 24-min walk today, split active-energy and
// distance samples) via --debug-hk-write-move; the only taps are the
// one-time system grant. Launch 2 runs SILENT — no seeder, no
// --debug-move stub — so every number on screen came through the
// untouched production read path: HKSampleQuery over workouts,
// strengthCount's classifier, and .cumulativeSum for energy/distance.
//
// Why "2" is the proof: yoga must not count (a generous classifier
// would quietly retire the judgement); 2 strength sessions meet the
// target, so the denominator drops and the hero reads exactly "2".
// Why "312 kcal"/"3.4 km" are the proof: each is a SUM of two split
// samples — presence alone would pass with a broken cumulativeSum.
//
// What this cannot prove (recorded, not hand-waved): HealthKit always
// returns an app its own written samples, so READ GRANT coverage for
// third-party data — plus watch source attribution — still needs one
// device look.
final class MoveHealthProofUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRealHealthKitRowsReachMoveWithZeroStubs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-pro-access",
                               "--uitest-seed-program",
                               "--debug-hk-write-move"]
        app.launch()

        // The Health Access sheet (write+read, DEBUG seeder only).
        // BEST-EFFORT: on a fresh simulator it appears and must be
        // granted; on a re-run the grant persists and no sheet comes.
        // The row assertions below are the actual proof either way.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(15)
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

        // Let the seeder finish writing all four workouts + samples.
        sleep(5)

        // Relaunch SILENT: the production read path only.
        app.terminate()
        app.launchArguments = ["--uitest-inapp-qa", "--uitest-pro-access",
                               "--uitest-seed-program",
                               "--uitest-open-move"]
        app.launch()
        sleep(6)

        // Strength: exactly 2 (yoga refused), denominator dropped.
        // (.combine flattens the HStack, so match any element type.)
        let strengthHero = app.descendants(matching: .any)
            .matching(identifier: "move.strengthCount.2").firstMatch
        XCTAssertTrue(strengthHero.waitForExistence(timeout: 10),
                      "strength hero is not the 2 real HK sessions "
                      + "(yoga must not count; 3 would mean it did)")

        // The three rows E8.1 said only a device could show, each a
        // real sum with its provenance word.
        for label in ["active energy", "distance", "workout time"] {
            XCTAssertTrue(
                app.staticTexts[label].firstMatch.waitForExistence(timeout: 5),
                "\(label) row missing — the read path dropped a real sample"
            )
        }
        XCTAssertTrue(app.staticTexts["312 kcal"].firstMatch.exists,
                      "active energy must be the SUM of the two seeded "
                      + "samples (200+112), not one of them")
        XCTAssertTrue(app.staticTexts["3.4 km"].firstMatch.exists,
                      "distance must sum 2.6+0.8 km")
        XCTAssertFalse(
            app.staticTexts["nothing has come through from health today."].exists,
            "the empty line rendered over real data"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "move-real-healthkit-rows"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
