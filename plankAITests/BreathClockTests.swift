import XCTest
@testable import plankAI

// MARK: - BreathClockTests
//
// docs/app_v4/03_FEATURES.md §6 — the breath's motion laws, pinned:
// sinusoidal position with near-zero velocity at every turn, holds
// as stillness (micro-drift bounded), anticipation glow before turns
// and never after the final exhale, rep accounting exact.

final class BreathClockTests: XCTestCase {

    private func state(_ elapsed: Double, i: Double = 4, h: Double = 0,
                       e: Double = 6, reps: Int = 3) -> BreathClock.State {
        BreathClock.state(elapsed: elapsed, inhale: i, hold: h, exhale: e, reps: reps)
    }

    func testPhaseBoundaries() {
        XCTAssertEqual(state(0).phase, .inhale)
        XCTAssertEqual(state(3.99).phase, .inhale)
        XCTAssertEqual(state(4.01).phase, .exhale)   // no hold on 4-0-6
        XCTAssertEqual(state(9.99).phase, .exhale)
        XCTAssertEqual(state(10.01).phase, .inhale)  // rep 2 begins
        XCTAssertEqual(state(30.0).phase, .done)     // 3 × 10s
    }

    func testHoldRendersAsStillness() {
        // 4-7-8: the hold sits between inhale and exhale.
        let mid = state(7.5, i: 4, h: 7, e: 8, reps: 1)
        XCTAssertEqual(mid.phase, .hold)
        // Micro-drift stays within ±0.01 of full.
        XCTAssertEqual(mid.p, 1.0, accuracy: 0.01)
    }

    func testSinusoidalZeroVelocityAtTurns() {
        // Near the start of the inhale the position barely moves —
        // velocity approaches zero at the turn (the premium tell vs
        // linear ramps).
        XCTAssertEqual(state(0).p, 0, accuracy: 0.0001)
        XCTAssertLessThan(state(0.04).p, 0.001)
        // Near the apex, equally still.
        XCTAssertEqual(state(4.0).p, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(state(3.96).p, 0.999)
        // Near the bottom of the exhale, still again.
        XCTAssertEqual(state(9.99).p, 0, accuracy: 0.001)
    }

    func testAnticipationGlowPeaksBeforeTurnsOnly() {
        // ~0.3s before the inhale→exhale turn the glow approaches 1.
        XCTAssertGreaterThan(state(3.7).turnGlow, 0.9)
        // Mid-phase it sleeps.
        XCTAssertLessThan(state(2.0).turnGlow, 0.01)
        // The final exhale anticipates nothing (nothing follows).
        XCTAssertEqual(state(29.7).turnGlow, 0, accuracy: 0.0001)
        // But the SAME point in an earlier rep does glow.
        XCTAssertGreaterThan(state(9.7).turnGlow, 0.9)
    }

    func testRepAccounting() {
        XCTAssertEqual(state(0).rep, 0)
        XCTAssertEqual(state(10.5).rep, 1)
        XCTAssertEqual(state(25).rep, 2)
        XCTAssertEqual(state(29.99).repsDone, 2)
        let done = state(30)
        XCTAssertEqual(done.phase, .done)
        XCTAssertEqual(done.repsDone, 3)
    }

    func testDegenerateInputsNeverTrap() {
        let zero = BreathClock.state(elapsed: 5, inhale: 0, hold: 0, exhale: 0, reps: 3)
        XCTAssertEqual(zero.phase, .done)
        let none = BreathClock.state(elapsed: 5, inhale: 4, hold: 0, exhale: 6, reps: 0)
        XCTAssertEqual(none.phase, .done)
        XCTAssertEqual(state(-2).phase, .inhale)   // pre-start clamps
    }
}
