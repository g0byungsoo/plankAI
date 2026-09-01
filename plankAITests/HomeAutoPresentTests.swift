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

// MARK: - p62: becoming joins the grammar

// The weekly read was the second, unreformed director: it scheduled
// from refresh() (every plate log, scan change, scope tap), stamped
// its once-per-week flag at SCHEDULE time, and its delayed closure
// was blind to the five sibling covers and the shared gate — so an
// open BOOK ate the read with its week already burned. The timing
// lived in a view body (the §36 lesson: no seam, no RED); these pins
// hold the extracted law.
final class BecomingAutoPresentTests: XCTestCase {

    func testADueUnofferedWeekOffersOnBecoming() {
        XCTAssertTrue(BecomingAutoPresent.shouldOffer(
            dueWeekIndex: 3, offeredWeek: nil, onBecoming: true))
        XCTAssertTrue(BecomingAutoPresent.shouldOffer(
            dueWeekIndex: 4, offeredWeek: 3, onBecoming: true))
    }

    func testAnOfferedWeekNeverReoffers() {
        XCTAssertFalse(BecomingAutoPresent.shouldOffer(
            dueWeekIndex: 3, offeredWeek: 3, onBecoming: true))
    }

    func testNoDueOrWrongTabOffersNothing() {
        XCTAssertFalse(BecomingAutoPresent.shouldOffer(
            dueWeekIndex: nil, offeredWeek: nil, onBecoming: true))
        XCTAssertFalse(BecomingAutoPresent.shouldOffer(
            dueWeekIndex: 3, offeredWeek: nil, onBecoming: false))
    }

    /// The defect this pass closes, as law: a sibling cover (THE BOOK,
    /// the ledger, the packet, the timeline) blocks the present — and
    /// because the caller stamps only on a true return, the week
    /// SURVIVES the block. Same for the shared gate and a tab switch
    /// during the settle beat.
    func testABlockedPresentKeepsTheWeek() {
        XCTAssertFalse(BecomingAutoPresent.mayPresent(
            stillDueWeekIndex: 3, scheduledWeekIndex: 3,
            siblingSurfaceUp: true, onBecoming: true, gateOccupied: false))
        XCTAssertFalse(BecomingAutoPresent.mayPresent(
            stillDueWeekIndex: 3, scheduledWeekIndex: 3,
            siblingSurfaceUp: false, onBecoming: true, gateOccupied: true))
        XCTAssertFalse(BecomingAutoPresent.mayPresent(
            stillDueWeekIndex: 3, scheduledWeekIndex: 3,
            siblingSurfaceUp: false, onBecoming: false, gateOccupied: false))
        // The blocked week is still offerable on the next arrival —
        // stamp-at-present is what makes this true.
        XCTAssertTrue(BecomingAutoPresent.shouldOffer(
            dueWeekIndex: 3, offeredWeek: nil, onBecoming: true))
    }

    /// A read that stopped being due (she signed it through the door
    /// mid-beat) or whose week moved never presents the stale one.
    func testAStaleScheduleNeverPresents() {
        XCTAssertFalse(BecomingAutoPresent.mayPresent(
            stillDueWeekIndex: nil, scheduledWeekIndex: 3,
            siblingSurfaceUp: false, onBecoming: true, gateOccupied: false))
        XCTAssertFalse(BecomingAutoPresent.mayPresent(
            stillDueWeekIndex: 4, scheduledWeekIndex: 3,
            siblingSurfaceUp: false, onBecoming: true, gateOccupied: false))
    }

    func testAClearBeatPresents() {
        XCTAssertTrue(BecomingAutoPresent.mayPresent(
            stillDueWeekIndex: 3, scheduledWeekIndex: 3,
            siblingSurfaceUp: false, onBecoming: true, gateOccupied: false))
    }
}

// MARK: - p62: the gate is an owner set

// Tested through the singleton (state restored after each test): a
// MainActor class deinit aborts on the iOS 26.2 simulator — the
// recorded gotcha — so no instance is ever created here.
final class PresentationGateTests: XCTestCase {

    @MainActor
    private func lowerAll() {
        PresentationGate.shared.set(.shell, up: false)
        PresentationGate.shared.set(.home, up: false)
        PresentationGate.shared.set(.becoming, up: false)
    }

    @MainActor
    func testAnOwnersOwnSurfaceNeverSelfBlocks() {
        defer { lowerAll() }
        let gate = PresentationGate.shared
        gate.set(.home, up: true)
        XCTAssertFalse(gate.occupied(besides: .home))
        XCTAssertTrue(gate.occupied(besides: .becoming))
        XCTAssertTrue(gate.occupied())
    }

    @MainActor
    func testLoweringClearsExactlyOneOwner() {
        defer { lowerAll() }
        let gate = PresentationGate.shared
        gate.set(.shell, up: true)
        gate.set(.becoming, up: true)
        gate.set(.becoming, up: false)
        XCTAssertTrue(gate.occupied(besides: .home))
        gate.set(.shell, up: false)
        XCTAssertFalse(gate.occupied())
    }
}
