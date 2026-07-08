import XCTest
import PlankSync
@testable import plankAI

// MARK: - GentleWorkoutTests
//
// v5.1 — THE GENTLE FIVE's contract, pinned. The mode exists for the
// day a beginner is tired: every invariant here is a promise the
// preview makes ("okay, i can do that") that the generated session
// must keep. Random selection runs many times so a lucky draw can't
// hide a violation.

final class GentleWorkoutTests: XCTestCase {

    private func gentleInput(
        minutes: Int = 5,
        focus: [BodyFocus] = [.fullBody],
        tier: Int = 3,
        offset: Int = 1
    ) -> WorkoutGenerator.Input {
        WorkoutGenerator.Input(
            bodyFocus: focus,
            lengthMinutes: minutes,
            recentSessionExerciseIds: [],
            recentRatings: [],
            startingTier: tier,       // gentle must override even tier 3
            intensityOffset: offset,  // ...and a push-it energy knob
            gentle: true
        )
    }

    // MARK: - The pool promise: no jumps, nothing hard

    func testGentleMainSlotsAreLowImpactEasyAndQuiet() {
        for focus in BodyFocus.allCases {
            for _ in 0..<20 {
                let workout = WorkoutGenerator.generate(from: gentleInput(focus: [focus]))
                for slot in workout.exercises where slot.category == .main {
                    guard let ex = slot.exercise else {
                        XCTFail("unresolvable exercise id \(slot.exerciseId)"); continue
                    }
                    XCTAssertEqual(ex.impact, .low,
                        "\(focus): \(ex.id) is \(ex.impact) impact in a gentle session")
                    XCTAssertLessThanOrEqual(ex.difficulty, 2,
                        "\(focus): \(ex.id) difficulty \(ex.difficulty) > 2 in a gentle session")
                    XCTAssertLessThanOrEqual(ex.met, 5,
                        "\(focus): \(ex.id) MET \(ex.met) > 5 in a gentle session")
                }
            }
        }
    }

    // MARK: - The structure promise: few moves, repeated

    func testGentleFiveRunsTwoFamiliarMovesTwice() {
        for _ in 0..<20 {
            let workout = WorkoutGenerator.generate(from: gentleInput())
            let main = workout.exercises.filter { $0.category == .main }
            let uniqueIds = Set(main.map(\.exerciseId))
            XCTAssertLessThanOrEqual(uniqueIds.count, 3,
                "gentle five main block should read as familiar repeats, got \(uniqueIds.count) unique moves")
            XCTAssertEqual(Set(main.map(\.round)).count, 2,
                "gentle five should emit two rounds")
            // Total unique moves across the whole session stays small
            // enough to hold in a tired head.
            let allUnique = Set(workout.exercises.map(\.exerciseId))
            XCTAssertLessThanOrEqual(allUnique.count, 5,
                "a gentle five should never ask her to learn \(allUnique.count) moves")
        }
    }

    // MARK: - The rest promise: room to breathe

    func testGentleMainRestsNeverDropUnderTenSeconds() {
        for _ in 0..<20 {
            let workout = WorkoutGenerator.generate(from: gentleInput())
            for slot in workout.exercises where slot.category == .main {
                XCTAssertGreaterThanOrEqual(slot.restAfter, 10,
                    "\(slot.exerciseId) rest \(slot.restAfter)s < 10s in a gentle session")
            }
        }
    }

    // MARK: - The size promise: it really is about five minutes

    func testGentleFiveTotalTimeStaysNearFiveMinutes() {
        for _ in 0..<20 {
            let workout = WorkoutGenerator.generate(from: gentleInput())
            let total = workout.exercises.reduce(0) { $0 + $1.duration + $1.restAfter }
            XCTAssertGreaterThanOrEqual(total, 180, "a gentle five under 3 minutes is a stub")
            XCTAssertLessThanOrEqual(total, 390, "a gentle five over 6½ minutes broke its promise")
        }
    }

    // MARK: - The identity promise

    func testGentlePresetCarriesItsMark() {
        let workout = WorkoutGenerator.generate(from: gentleInput())
        XCTAssertTrue(workout.isGentle)
        XCTAssertEqual(workout.name, "The Gentle Five")
        XCTAssertNotNil(workout.description)
    }

    // MARK: - The completion promise: halfway counts

    func testGentleCompletionBarIsHalf() {
        XCTAssertEqual(SessionCompletion.threshold(isGentle: true), 0.5)
        XCTAssertEqual(SessionCompletion.threshold(isGentle: false), 0.7)

        // 5 slots of 60s planned; she does 3 of 5 (60%).
        let results = (0..<5).map { i in
            ExerciseResultEntry(
                exerciseId: "x\(i)", duration: 60,
                completedDuration: i < 3 ? 60 : 0, skipped: i >= 3
            )
        }
        XCTAssertTrue(SessionCompletion.didMeetThreshold(results, isGentle: true),
            "60% of a gentle session must count")
        XCTAssertFalse(SessionCompletion.didMeetThreshold(results, isGentle: false),
            "60% of a standard session stays under the 70% bar")
    }

    // MARK: - The standard path is untouched

    func testStandardFiveKeepsItsStructure() {
        var input = gentleInput()
        input.gentle = false
        let workout = WorkoutGenerator.generate(from: input)
        XCTAssertFalse(workout.isGentle)
        let main = workout.exercises.filter { $0.category == .main }
        XCTAssertGreaterThanOrEqual(Set(main.map(\.exerciseId)).count, 4,
            "standard sessions keep their variety")
    }
}
