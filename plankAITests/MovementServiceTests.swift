import XCTest
import HealthKit
@testable import plankAI

// MovementService (v9 P0, W6) — dormant plumbing: silent probe only,
// no auth request until P3 renders its surface (L5). The pure part
// under test: which workout types count as strength (the
// muscle-preservation input, P3).

final class MovementServiceTests: XCTestCase {
    func testStrengthTypesCount() {
        XCTAssertEqual(MovementService.strengthCount(
            [.traditionalStrengthTraining, .functionalStrengthTraining, .walking, .yoga]), 2)
    }

    func testNoWorkoutsCountZero() {
        XCTAssertEqual(MovementService.strengthCount([]), 0)
        XCTAssertEqual(MovementService.strengthCount([.running, .cycling]), 0)
    }
}
