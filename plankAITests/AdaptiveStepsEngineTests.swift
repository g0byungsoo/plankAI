import XCTest
@testable import plankAI

// E1 THE SPINE — adaptive step goals (docs/app_v25/05_E1_SPINE.md §3).
// The Adams 2017 recipe: 60th percentile of her OWN recent recorded
// days, moved conservatively, clamped to the evidence band. Relief
// is structural: the goal can breathe DOWN.

final class AdaptiveStepsEngineTests: XCTestCase {

    // MARK: - Percentile core

    func testPercentileNearestRankOnFiveDays() {
        // n=5 → 60th percentile = 3rd value ascending (nearest-rank).
        let goal = AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [3_000, 4_000, 5_000, 6_000, 7_000],
            currentGoal: nil
        )
        XCTAssertEqual(goal, 5_000)
    }

    func testOrderOfInputDoesNotMatter() {
        let goal = AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [7_000, 3_000, 6_000, 5_000, 4_000],
            currentGoal: nil
        )
        XCTAssertEqual(goal, 5_000)
    }

    func testRoundsToFifty() {
        let goal = AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [5_163, 5_163, 5_163, 5_163, 5_163],
            currentGoal: nil
        )
        XCTAssertEqual(goal, 5_150)
    }

    // MARK: - Recorded-day honesty

    func testFiltersUnrecordedDays() {
        // Days ≤500 steps read as "phone didn't come along", not
        // zero-effort — they never drag the percentile.
        let goal = AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [0, 200, 500, 6_000, 6_500, 7_000, 5_500, 5_000],
            currentGoal: nil
        )
        // Recorded: [5000, 5500, 6000, 6500, 7000] → 60th = 6000.
        XCTAssertEqual(goal, 6_000)
    }

    func testInsufficientHistoryReturnsNil() {
        XCTAssertNil(AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [6_000, 6_500, 7_000, 5_500],
            currentGoal: nil
        ))
    }

    func testEmptyHistoryReturnsNil() {
        XCTAssertNil(AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [], currentGoal: nil
        ))
    }

    // MARK: - Conservative movement + relief

    func testConservativeMoveCapsRise() {
        // History says 8,000 but her goal is 4,000 — one recalc may
        // rise at most 15%.
        let goal = AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [8_000, 8_000, 8_000, 8_000, 8_000],
            currentGoal: 4_000
        )
        XCTAssertEqual(goal, 4_600)
    }

    func testReliefMovesDownAfterHardWeeks() {
        // The goal breathes DOWN: current 8,000, recent reality
        // 4,000 → down 15% this recalc.
        let goal = AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [4_000, 4_000, 4_000, 4_000, 4_000],
            currentGoal: 8_000
        )
        XCTAssertEqual(goal, 6_800)
    }

    func testStableHistoryHoldsGoal() {
        let goal = AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [5_000, 5_000, 5_000, 5_000, 5_000],
            currentGoal: 5_000
        )
        XCTAssertEqual(goal, 5_000)
    }

    // MARK: - The safe band (shared clamp law)

    func testCeilingAppliesWithoutCurrentGoal() {
        let goal = AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [12_000, 12_000, 12_000, 12_000, 12_000],
            currentGoal: nil
        )
        XCTAssertEqual(goal, 8_000)
    }

    func testFloorApplies() {
        let goal = AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [600, 700, 800, 900, 1_000],
            currentGoal: nil
        )
        XCTAssertEqual(goal, 2_500)
    }

    func testActiveUserNeverRegressesToGenericTarget() {
        // An active user at the ceiling stays at the ceiling — the
        // band never drags her to a "default".
        let goal = AdaptiveStepsEngine.recommendedGoal(
            recentDailySteps: [9_000, 9_500, 10_000, 8_500, 9_200],
            currentGoal: 8_000
        )
        XCTAssertEqual(goal, 8_000)
    }
}
