import XCTest
@testable import plankAI

// E1 THE SPINE — the read's composer (docs/app_v25/05_E1_SPINE §2).
// WHAT HAPPENED → WHAT MATTERS → WHAT TO TRY: ≤3 signals, ≤2
// floor-gated observations, one teaching line, ONE offer. Sparse
// weeks read honestly ("no fake intelligence"); down weeks carry no
// debt; non-medication inputs produce zero medication vocabulary.

final class WeeklyReadComposerTests: XCTestCase {

    private func inputs(
        stepsThisWeek: [Int] = [],
        stepsTrailing: [Int] = [],
        plateDays: Int = 0,
        plateCount: Int = 0,
        proteinDaysMet: Int = 0,
        elapsedDays: Int = 7,
        dosesResolved: Int? = nil,
        dosesExpected: Int? = nil,
        offer: WeeklyReadOffer = .v4(.holdSteady(reason: "the plan holds."))
    ) -> WeeklyReadComposer.Inputs {
        .init(
            windowStartDay: "2026-08-03",
            anchorKind: .enrollment,
            stepsThisWeek: stepsThisWeek,
            stepsTrailing: stepsTrailing,
            plateDays: plateDays,
            plateCount: plateCount,
            proteinDaysMet: proteinDaysMet,
            elapsedDays: elapsedDays,
            dosesResolved: dosesResolved,
            dosesExpected: dosesExpected,
            offer: offer
        )
    }

    // MARK: - The quiet week (no fake intelligence)

    func testQuietWeekReadsHonestly() {
        let model = WeeklyReadComposer.compose(inputs())
        XCTAssertTrue(model.heroLine.contains("quiet"))
        XCTAssertTrue(model.signals.isEmpty)
        XCTAssertTrue(model.observations.isEmpty)
    }

    // MARK: - Signals (only when data exists)

    func testStepsSignalAveragesRecordedDays() {
        let model = WeeklyReadComposer.compose(inputs(
            stepsThisWeek: [0, 200, 6_000, 5_000, 7_000, 0, 4_000]
        ))
        let steps = model.signals.first { $0.key == "steps" }
        // Recorded (>500): 6000+5000+7000+4000 = 22000 / 4 = 5500.
        XCTAssertEqual(steps?.thisWeek, "5,500")
        XCTAssertNil(steps?.versus)   // no trailing history
    }

    func testStepsVersusRequiresTrailingHistory() {
        let model = WeeklyReadComposer.compose(inputs(
            stepsThisWeek: [6_000, 6_000, 6_000, 6_000, 6_000],
            stepsTrailing: [5_000, 5_000, 5_000, 5_000, 5_000]
        ))
        let steps = model.signals.first { $0.key == "steps" }
        XCTAssertNotNil(steps?.versus)
        XCTAssertTrue(steps?.versus?.contains("5,000") ?? false)
    }

    func testPlatesAndProteinSignals() {
        let model = WeeklyReadComposer.compose(inputs(
            plateDays: 5, plateCount: 11, proteinDaysMet: 3
        ))
        XCTAssertNotNil(model.signals.first { $0.key == "plates" })
        XCTAssertNotNil(model.signals.first { $0.key == "protein" })
        XCTAssertLessThanOrEqual(model.signals.count, 3)
    }

    // MARK: - Observations (floor-gated, ≤2, anti-shame)

    func testProteinObservationNeedsLoggedFloor() {
        let sparse = WeeklyReadComposer.compose(inputs(
            plateDays: 2, proteinDaysMet: 1
        ))
        XCTAssertFalse(sparse.observations.contains {
            $0.text.contains("protein")
        })
        let logged = WeeklyReadComposer.compose(inputs(
            plateDays: 5, proteinDaysMet: 4
        ))
        XCTAssertTrue(logged.observations.contains {
            $0.text.contains("protein")
        })
    }

    func testStepsDownWeekCarriesNoDebt() {
        let model = WeeklyReadComposer.compose(inputs(
            stepsThisWeek: [3_000, 3_000, 3_000, 3_000, 3_000],
            stepsTrailing: [6_000, 6_000, 6_000, 6_000, 6_000]
        ))
        let stepsObs = model.observations.first { $0.text.contains("quieter") }
        XCTAssertNotNil(stepsObs)
        XCTAssertTrue(stepsObs?.text.contains("no debt") ?? false)
        XCTAssertFalse(stepsObs?.text.contains("%") ?? true)
    }

    func testDoseObservationOnlyForMedicationUsers() {
        let nonMed = WeeklyReadComposer.compose(inputs(plateDays: 5))
        XCTAssertFalse(nonMed.observations.contains { $0.text.contains("dose") })

        let med = WeeklyReadComposer.compose(inputs(
            dosesResolved: 6, dosesExpected: 7
        ))
        XCTAssertTrue(med.observations.contains { $0.text.contains("dose") })
    }

    func testObservationsCapAtTwo() {
        let model = WeeklyReadComposer.compose(inputs(
            stepsThisWeek: [7_000, 7_000, 7_000, 7_000, 7_000],
            stepsTrailing: [5_000, 5_000, 5_000, 5_000, 5_000],
            plateDays: 5, proteinDaysMet: 5,
            dosesResolved: 7, dosesExpected: 7
        ))
        XCTAssertLessThanOrEqual(model.observations.count, 2)
    }

    // MARK: - Teaching (keyed to the offer)

    func testTeachingKeyedToStepRecalc() {
        let model = WeeklyReadComposer.compose(inputs(
            stepsThisWeek: [5_000, 5_000, 5_000, 5_000, 5_000],
            offer: .stepGoalRecalc(newGoal: 5_150, reason: "r")
        ))
        XCTAssertNotNil(model.teaching)
    }

    func testQuietWeekHasNoTeachingLecture() {
        let model = WeeklyReadComposer.compose(inputs())
        XCTAssertNil(model.teaching)
    }
}
