import XCTest
@testable import plankAI

// Pass 57 (D3) — the auto-present ordering is a stated law, not an
// accident of four independent timers.
final class HomeAutoPresentTests: XCTestCase {

    func testEachCandidateWinsAlone() {
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: true, letterEligible: false, upgradeEligible: false), .reconcile)
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: false, letterEligible: true, upgradeEligible: false), .letter)
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: false, letterEligible: false, upgradeEligible: true), .upgrade)
    }

    func testAClinicalConfirmationOutranksEverything() {
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: true, letterEligible: true, upgradeEligible: true), .reconcile)
    }

    /// The defect this arbiter exists to prevent, pinned as the law:
    /// commerce never outranks the morning read.
    func testTheUpgradeNeverBeatsTheLetter() {
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: false, letterEligible: true, upgradeEligible: true), .letter)
    }

    func testAQuietMorningPresentsNothing() {
        XCTAssertNil(HomeAutoPresent.winner(
            reconcileEligible: false, letterEligible: false, upgradeEligible: false))
    }
}
