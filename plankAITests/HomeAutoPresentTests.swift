import XCTest
@testable import plankAI

// Pass 57 (D3) — the auto-present ordering is a stated law, not an
// accident of four independent timers. p61 — the evening close joins
// the arbiter (it used to bypass it from refresh() and collide with
// the letter 200ms apart on the same modal slot).
final class HomeAutoPresentTests: XCTestCase {

    func testEachCandidateWinsAlone() {
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: true, letterEligible: false, upgradeEligible: false), .reconcile)
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: false, letterEligible: true, upgradeEligible: false), .letter)
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: false, letterEligible: false, upgradeEligible: true), .upgrade)
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: false, eveningEligible: true,
            letterEligible: false, upgradeEligible: false, isEvening: true), .eveningClose)
    }

    func testAClinicalConfirmationOutranksEverything() {
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: true, letterEligible: true, upgradeEligible: true), .reconcile)
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: true, eveningEligible: true,
            letterEligible: true, upgradeEligible: true, isEvening: true), .reconcile)
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

    // MARK: - p61: one voice per arrival

    /// The collision this pass closes: on the first evening open of a
    /// day, BOTH the letter and the close used to be armed — the
    /// letter presented at +0.7s and the close fired at +0.9s into an
    /// occupied slot, then re-armed all evening. One arrival, one
    /// voice: the close speaks, the letter's day-key stays unburned
    /// for tomorrow morning.
    func testInTheEveningTheCloseOutranksTheLetter() {
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: false, eveningEligible: true,
            letterEligible: true, upgradeEligible: false, isEvening: true),
            .eveningClose)
    }

    /// A closed day (day-key already stamped) never resurrects the
    /// MORNING read at night: the letter stands down for the whole
    /// evening, eligible or not.
    func testTheMorningReadNeverFiresInTheEvening() {
        XCTAssertNil(HomeAutoPresent.winner(
            reconcileEligible: false, eveningEligible: false,
            letterEligible: true, upgradeEligible: false, isEvening: true))
    }

    /// The close never fires outside the evening, whatever its flags
    /// say — eligibility is computed by the caller, but the law holds
    /// at the arbiter too.
    func testTheCloseNeverFiresInTheMorning() {
        XCTAssertEqual(HomeAutoPresent.winner(
            reconcileEligible: false, eveningEligible: true,
            letterEligible: true, upgradeEligible: false, isEvening: false),
            .letter)
    }

    /// One settle beat for every self-presenting surface — three
    /// different constants used to make the same gesture at three
    /// speeds.
    func testOneSettleBeat() {
        XCTAssertEqual(HomeAutoPresent.settleBeat, 0.6, accuracy: 0.0001)
    }
}
