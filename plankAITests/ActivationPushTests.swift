import XCTest
@testable import plankAI

final class ActivationPushTests: XCTestCase {

    // Suppress the nudge the moment the user has ever completed a core action.
    // Covers: session save, food log, or any signal that sets hasEverActed.
    func testSuppressedOnceUserActed() {
        XCTAssertFalse(
            ActivationPushPolicy.shouldSchedule(
                dayIndex: 1,
                hasEverActed: true,
                alreadyScheduled: 0
            )
        )
    }

    // Never schedule a 4th activation push even if the user hasn't acted.
    // Hard cap: 3 across D1+D2+D3.
    func testCapsAtThree() {
        XCTAssertFalse(
            ActivationPushPolicy.shouldSchedule(
                dayIndex: 3,
                hasEverActed: false,
                alreadyScheduled: 3
            )
        )
    }

    // Happy path: inactive user, first slot, under cap - should schedule.
    func testFiresWhenInactiveUnderCap() {
        XCTAssertTrue(
            ActivationPushPolicy.shouldSchedule(
                dayIndex: 1,
                hasEverActed: false,
                alreadyScheduled: 0
            )
        )
    }
}
