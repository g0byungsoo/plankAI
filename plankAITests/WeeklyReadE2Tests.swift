import XCTest
@testable import plankAI

// MARK: - WeeklyReadE2Tests (v25 E2 — B8, the read grows up)
//
// "your dose week, read" finally contains the dose — and the weekly
// ritual of a weight-loss app finally contains weight. Pins: the
// weekly slot's story leads the observations, the weight band joins
// the signals (floors-honoring, anti-shame up-weeks), cycle/plateau
// teachings speak ONLY when the offer teaches nothing, and a
// non-medicated read leaks nothing. Grammar caps unchanged: ≤3
// signals, ≤2 observations, one teaching, ONE offer.

final class WeeklyReadE2Tests: XCTestCase {

    private func inputs(
        doseWeek: WeeklyReadComposer.Inputs.DoseWeekState? = nil,
        cycleDay: Int? = nil,
        eraChanged: Bool = false,
        weight: WeeklyReadComposer.Inputs.WeightSignal? = nil,
        offer: WeeklyReadOffer = .v4(.holdSteady(reason: "the plan holds.")),
        plateDays: Int = 5,
        steps: [Int] = Array(repeating: 6_000, count: 7)
    ) -> WeeklyReadComposer.Inputs {
        var i = WeeklyReadComposer.Inputs(
            windowStartDay: "2026-08-03",
            anchorKind: .doseDay,
            offer: offer
        )
        i.stepsThisWeek = steps
        i.stepsTrailing = Array(repeating: 5_500, count: 21)
        i.plateDays = plateDays
        i.plateCount = plateDays * 2
        i.proteinDaysMet = 4
        i.doseWeek = doseWeek
        i.cycleDay = cycleDay
        i.eraChangedRecently = eraChanged
        i.weight = weight
        return i
    }

    // MARK: the dose enters the read

    func testWeeklyInjectorDoseStoryLeadsObservations() {
        let model = WeeklyReadComposer.compose(inputs(doseWeek: .takenOnDay))
        XCTAssertEqual(
            model.observations.first?.text,
            "the dose landed on its day. the week kept its anchor."
        )
    }

    func testLateSkippedOpenMissedAllSpeakWithoutShame() {
        let cases: [(WeeklyReadComposer.Inputs.DoseWeekState, String)] = [
            (.takenLate, "the dose landed late and the record holds it honestly. rhythms recover."),
            (.skipped, "this week's dose was a no, and a recorded no is an answer, not a gap."),
            (.open, "this week's dose is still open. log it late, or let it go."),
            (.missed, "the week ran without its dose. recorded, no debt carried."),
        ]
        for (state, line) in cases {
            let model = WeeklyReadComposer.compose(inputs(doseWeek: state))
            XCTAssertEqual(model.observations.first?.text, line, "\(state)")
        }
    }

    func testDailyCadenceKeepsItsCountLine() {
        var i = inputs()   // no doseWeek — a daily user's shape
        i.dosesResolved = 6
        i.dosesExpected = 7
        let model = WeeklyReadComposer.compose(i)
        XCTAssertEqual(
            model.observations.first?.text,
            "6 of 7 dose slots resolved. the record stays honest either way."
        )
    }

    func testNonMedicatedReadLeaksNothing() {
        let model = WeeklyReadComposer.compose(inputs())
        for obs in model.observations {
            XCTAssertFalse(obs.text.contains("dose"))
            XCTAssertFalse(obs.text.contains("cycle"))
        }
        XCTAssertNil(model.signals.first { $0.key == "weight" })
        XCTAssertNil(model.teaching)   // hold_steady + no context = calm
    }

    // MARK: the weight signal

    func testWeightBandJoinsTheSignals() {
        let model = WeeklyReadComposer.compose(inputs(
            weight: .init(band: "trending_down", sufficiency: "established",
                          deltaText: "0.8 lb")
        ))
        let weight = model.signals.first { $0.key == "weight" }
        XCTAssertEqual(weight?.thisWeek, "−0.8 lb")
        XCTAssertEqual(weight?.direction, -1)
        XCTAssertNil(weight?.versus)
        XCTAssertLessThanOrEqual(model.signals.count, 3)
    }

    func testProvisionalWeightSaysEarlyRead() {
        let model = WeeklyReadComposer.compose(inputs(
            weight: .init(band: "trending_down", sufficiency: "provisional",
                          deltaText: "0.6 lb")
        ))
        XCTAssertEqual(
            model.signals.first { $0.key == "weight" }?.versus,
            "an early read"
        )
    }

    func testInsufficientWeightStaysSilent() {
        let model = WeeklyReadComposer.compose(inputs(
            weight: .init(band: nil, sufficiency: "insufficient")
        ))
        XCTAssertNil(model.signals.first { $0.key == "weight" })
    }

    func testWeightDisplacesProteinInTheBandNeverTheCap() {
        let model = WeeklyReadComposer.compose(inputs(
            weight: .init(band: "holding_steady", sufficiency: "established")
        ))
        XCTAssertEqual(model.signals.count, 3)
        XCTAssertEqual(model.signals.map(\.key), ["steps", "weight", "plates"])
    }

    func testUpDriftMeetsTheWaterTruthNotDebt() {
        let model = WeeklyReadComposer.compose(inputs(
            doseWeek: .takenOnDay,
            weight: .init(band: "drifting_up", sufficiency: "established",
                          deltaText: "0.5 lb")
        ))
        XCTAssertEqual(model.observations.count, 2)
        XCTAssertEqual(
            model.observations.last?.text,
            "the trend drifted up a touch this week. water writes most weeks like this."
        )
        let joined = model.observations.map(\.text).joined()
        XCTAssertFalse(joined.contains("debt"))
    }

    func testDownWeekGetsNoCommentaryBeyondTheBand() {
        let model = WeeklyReadComposer.compose(inputs(
            weight: .init(band: "trending_down", sufficiency: "established",
                          deltaText: "1.0 lb")
        ))
        XCTAssertFalse(model.observations.contains {
            $0.text.contains("trend")
        })
    }

    // MARK: teachings — the offer outranks the week

    func testOfferTeachingOutranksCycleTeaching() {
        let model = WeeklyReadComposer.compose(inputs(
            cycleDay: 6,
            offer: .stepGoalRecalc(newGoal: 6_200, reason: "fit to your weeks.")
        ))
        XCTAssertEqual(
            model.teaching,
            "goals that move with your own weeks are the ones that keep."
        )
    }

    func testWaningCycleTeachesTheShapeOfTheWeek() {
        let model = WeeklyReadComposer.compose(inputs(
            doseWeek: .takenOnDay, cycleDay: 6
        ))
        XCTAssertEqual(
            model.teaching,
            "the last days of a dose week often run hungrier. that's the shape of the week, not a slip."
        )
    }

    func testEarlyCycleTeachesNothing() {
        let model = WeeklyReadComposer.compose(inputs(
            doseWeek: .takenOnDay, cycleDay: 2
        ))
        XCTAssertNil(model.teaching)
    }

    func testEraChangeTeachesTheRecordRoute() {
        let model = WeeklyReadComposer.compose(inputs(
            doseWeek: .takenOnDay, cycleDay: 3, eraChanged: true
        ))
        XCTAssertEqual(
            model.teaching,
            "the first weeks after a change often run differently. the record is how you and your prescriber see it."
        )
    }

    func testEstablishedPlateauTeachesTheTrendTruth() {
        let model = WeeklyReadComposer.compose(inputs(
            weight: .init(band: "holding_steady", sufficiency: "established")
        ))
        XCTAssertEqual(
            model.teaching,
            "plateaus are part of every real descent. the trend, not one morning, is the measure."
        )
    }

    func testObservationCapHoldsUnderPressure() {
        // dose story + up-drift + protein + steps all compete → 2.
        var i = inputs(
            doseWeek: .takenLate,
            weight: .init(band: "drifting_up", sufficiency: "established",
                          deltaText: "0.4 lb"),
            steps: Array(repeating: 8_000, count: 7)
        )
        i.plateDays = 5
        let model = WeeklyReadComposer.compose(i)
        XCTAssertEqual(model.observations.count, 2)
    }
}
