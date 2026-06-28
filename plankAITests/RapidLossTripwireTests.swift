import XCTest
@testable import plankAI

final class RapidLossTripwireTests: XCTestCase {
    func testFiresWhenLossExceedsCeiling() {
        // 80kg losing 1.2kg/wk = 1.5%/wk > 1% ceiling.
        let r = RapidLossTripwire.evaluate(trendKgPerWeek: 1.2, currentWeightKg: 80)
        XCTAssertTrue(r.isTooFast)
        XCTAssertNotNil(r.careMessage)
    }
    func testSilentWithinEnvelope() {
        // 80kg losing 0.6kg/wk = 0.75%/wk < 1%.
        let r = RapidLossTripwire.evaluate(trendKgPerWeek: 0.6, currentWeightKg: 80)
        XCTAssertFalse(r.isTooFast)
        XCTAssertNil(r.careMessage)
    }
    func testWeightGainNeverFires() {
        let r = RapidLossTripwire.evaluate(trendKgPerWeek: -0.5, currentWeightKg: 80)
        XCTAssertFalse(r.isTooFast)
    }
}
