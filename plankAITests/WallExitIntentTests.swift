import XCTest
@testable import plankAI

// MARK: - WallExitIntentTests
//
// The regression table for the App Store 5.6 rejection of 1.1.7 (28):
// "the (X) button was unresponsive." The old ladder fell through to a
// no-op once its once-flags were spent, and the flags persist across
// launches — so the dead X was the NORMAL state, not an edge case.
//
// Row one of this table (testSpentLadderStandsDown) is the rejection
// itself: it cannot pass against the old fall-through, and it is the
// state a reviewer reaches on their second launch.

final class WallExitIntentTests: XCTestCase {

    private func inputs(
        abandonedPlan: String? = nil,
        smallerStepShown: Bool = false,
        downsellShown: Bool = false
    ) -> WallExitIntent.Inputs {
        .init(
            abandonedPlan: abandonedPlan,
            smallerStepShownOnce: smallerStepShown,
            downsellShownOnce: downsellShown
        )
    }

    // MARK: the rejection

    /// THE 5.6 ROW. Both once-flags spent — the state every returning
    /// user is in — must still produce a visible action.
    func testSpentLadderStandsDown() {
        XCTAssertEqual(
            WallExitIntent.next(inputs(smallerStepShown: true, downsellShown: true)),
            .standDown
        )
    }

    /// The reviewer's exact path: the save sheet fired once, then the
    /// next X press must leave the buy surface rather than dead-end.
    func testSecondPressAfterSmallerStepStandsDown() {
        let first = WallExitIntent.next(inputs())
        XCTAssertEqual(first, .smallerStep)
        let second = WallExitIntent.next(inputs(smallerStepShown: true))
        XCTAssertEqual(second, .standDown)
    }

    /// Same for the yearly-abandon route: one tier-matched offer, then
    /// the exit.
    func testSecondYearlyAbandonStandsDown() {
        let first = WallExitIntent.next(inputs(abandonedPlan: "yearly"))
        XCTAssertEqual(first, .discountedYear)
        let second = WallExitIntent.next(
            inputs(abandonedPlan: "yearly", downsellShown: true)
        )
        XCTAssertEqual(second, .standDown)
    }

    /// Totality: no combination of inputs may fail to produce an
    /// action. This is the property the old code violated.
    func testEveryInputProducesAnAction() {
        let plans: [String?] = [nil, "yearly", "quarterly", "weekly", "unknown"]
        for plan in plans {
            for smaller in [false, true] {
                for downsell in [false, true] {
                    let action = WallExitIntent.next(
                        inputs(
                            abandonedPlan: plan,
                            smallerStepShown: smaller,
                            downsellShown: downsell
                        )
                    )
                    // Compiles only because Action has no no-op case;
                    // asserted so the intent survives a future case.
                    XCTAssertTrue(
                        [.smallerStep, .discountedYear, .standDown].contains(action),
                        "plan=\(plan ?? "nil") smaller=\(smaller) downsell=\(downsell)"
                    )
                }
            }
        }
    }

    // MARK: the offer, while it is still unspent

    func testFreshXPressOffersTheSmallerStep() {
        XCTAssertEqual(WallExitIntent.next(inputs()), .smallerStep)
    }

    func testFreshYearlyAbandonIsTierMatched() {
        XCTAssertEqual(
            WallExitIntent.next(inputs(abandonedPlan: "yearly")),
            .discountedYear
        )
    }

    /// Non-yearly abandons take the smallest door, not the year.
    func testQuarterlyAndWeeklyAbandonsTakeTheSmallerStep() {
        XCTAssertEqual(
            WallExitIntent.next(inputs(abandonedPlan: "quarterly")),
            .smallerStep
        )
        XCTAssertEqual(
            WallExitIntent.next(inputs(abandonedPlan: "weekly")),
            .smallerStep
        )
    }

    /// One offer per install is counted ACROSS the rungs: taking the
    /// discounted year (via the save sheet's "or the year" door) spends
    /// the budget, so a later plain X press exits instead of pitching
    /// the week.
    func testDiscountedYearSpendsTheBudgetForPlainPresses() {
        XCTAssertEqual(
            WallExitIntent.next(inputs(downsellShown: true)),
            .standDown
        )
    }

    /// And the reverse: the week spends it for yearly abandons too.
    func testSmallerStepSpendsTheBudgetForYearlyAbandons() {
        XCTAssertEqual(
            WallExitIntent.next(inputs(abandonedPlan: "yearly", smallerStepShown: true)),
            .standDown
        )
    }
}
