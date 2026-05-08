import XCTest
@testable import plankAI

final class WorkoutGeneratorTests: XCTestCase {

    private func validate(_ workout: WorkoutPreset, tier: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNil(WorkoutGenerator.validateBalance(workout), "balance", file: file, line: line)
        XCTAssertNil(WorkoutGenerator.validatePositionFlow(workout), "positionFlow", file: file, line: line)
        XCTAssertNil(WorkoutGenerator.validateDifficultyBounds(workout, tier: tier), "difficultyBounds", file: file, line: line)
        XCTAssertNil(WorkoutGenerator.validateDurationGrid(workout), "durationGrid", file: file, line: line)
        XCTAssertNil(WorkoutGenerator.validateRestGrid(workout), "restGrid", file: file, line: line)
        XCTAssertTrue(workout.exercises.contains { $0.category == .main }, "empty main block", file: file, line: line)
    }

    func testParameterGridGeneration() {
        let tiers = [1, 2, 3]
        let lengths = [5, 10, 15, 30, 45]
        let focusSets: [(label: String, focus: [BodyFocus])] = [
            ("flatBelly",         [.flatBelly]),
            ("tonedArms",         [.tonedArms]),
            ("roundButt",         [.roundButt]),
            ("slimLegs",          [.slimLegs]),
            ("fullBody",          [.fullBody]),
            ("multi-flat+toned",  [.flatBelly, .tonedArms]),
            ("multi-glutes+legs", [.roundButt, .slimLegs]),
        ]

        for tier in tiers {
            for length in lengths {
                for (focusLabel, focus) in focusSets {
                    let input = WorkoutGenerator.Input(
                        bodyFocus: focus,
                        lengthMinutes: length,
                        recentSessionExerciseIds: [],
                        recentRatings: [],
                        startingTier: tier
                    )
                    let workout = WorkoutGenerator.generate(from: input)
                    XCTContext.runActivity(named: "tier=\(tier) len=\(length)min focus=\(focusLabel)") { _ in
                        validate(workout, tier: tier)
                    }
                }
            }
        }
    }

    func testStretchSession() {
        for length in [5, 10, 15] {
            let workout = WorkoutGenerator.generateStretchSession(lengthMinutes: length)
            XCTContext.runActivity(named: "stretch len=\(length)min") { _ in
                XCTAssertNil(WorkoutGenerator.validateBalance(workout))
                XCTAssertNil(WorkoutGenerator.validatePositionFlow(workout))
            }
        }
    }

    func testEmptyBodyFocusDefaultsToFullBody() {
        let input = WorkoutGenerator.Input(
            bodyFocus: [],
            lengthMinutes: 10,
            recentSessionExerciseIds: [],
            recentRatings: [],
            startingTier: 2
        )
        validate(WorkoutGenerator.generate(from: input), tier: 2)
    }

    func testHighRecentRatingsBumpTierUp() {
        let input = WorkoutGenerator.Input(
            bodyFocus: [.flatBelly],
            lengthMinutes: 10,
            recentSessionExerciseIds: [],
            recentRatings: [5, 5, 5],
            startingTier: 2
        )
        validate(WorkoutGenerator.generate(from: input), tier: 3)
    }

    func testLowRecentRatingsBumpTierDown() {
        let input = WorkoutGenerator.Input(
            bodyFocus: [.flatBelly],
            lengthMinutes: 10,
            recentSessionExerciseIds: [],
            recentRatings: [2, 2, 2],
            startingTier: 2
        )
        validate(WorkoutGenerator.generate(from: input), tier: 1)
    }

    func testLongSessionRoundsAreMonotonic() {
        let input = WorkoutGenerator.Input(
            bodyFocus: [.fullBody],
            lengthMinutes: 45,
            recentSessionExerciseIds: [],
            recentRatings: [],
            startingTier: 2
        )
        let workout = WorkoutGenerator.generate(from: input)
        validate(workout, tier: 2)

        var lastRound = 1
        for slot in workout.exercises where slot.category == .main {
            XCTAssertGreaterThanOrEqual(slot.round, lastRound, "round regressed from \(lastRound) to \(slot.round)")
            lastRound = slot.round
        }
    }
}
