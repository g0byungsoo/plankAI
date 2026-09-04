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
        cycleLength: Int? = nil,
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
        i.cycleLength = cycleLength
        i.eraChangedRecently = eraChanged
        i.weight = weight
        return i
    }

    // MARK: the dose enters the read

    func testWeeklyInjectorDoseStoryLeadsObservations() {
        let model = WeeklyReadComposer.compose(inputs(doseWeek: .takenOnDay))
        XCTAssertEqual(
            model.observations.first?.text,
            "your dose landed on its day."
        )
    }

    func testLateSkippedOpenMissedAllSpeakWithoutShame() {
        let cases: [(WeeklyReadComposer.Inputs.DoseWeekState, String)] = [
            (.takenLate, "your dose landed late. logged, and the rhythm recovers from here."),
            (.skipped, "this week's dose was a no. recorded, not a gap."),
            (.open, "this week's dose is still open. log it late, or let it go."),
            (.missed, "no dose this week. recorded, no debt."),
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
            "6 of 7 doses recorded this week."
        )
    }

    func testNonMedicatedReadLeaksNothing() {
        let model = WeeklyReadComposer.compose(inputs())
        for obs in model.observations {
            XCTAssertFalse(obs.text.contains("dose"))
            XCTAssertFalse(obs.text.contains("cycle"))
        }
        XCTAssertNil(model.signals.first { $0.key == "weight" })
        // p79 — the hold week's close is SILENT again (founder
        // steer): "nothing needs a reset." doubled the hold offer's
        // own "nothing needs to change this week." in poetry. The
        // leak law above still holds around the silence.
        XCTAssertNil(model.teaching)
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
            "the trend drifted up a touch. that's usually water, not fat."
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
            "your step goal now follows your own real weeks."
        )
    }

    func testWaningCycleTeachesTheShapeOfTheWeek() {
        // p54 re-pin: the gate is the schedule engine's own band now
        // (day + length), and the copy says "rhythm" because pass 53
        // made intervals real — a q10d user's late days deserve the
        // same sentence a week's do.
        let model = WeeklyReadComposer.compose(inputs(
            doseWeek: .takenOnDay, cycleDay: 6, cycleLength: 7
        ))
        XCTAssertEqual(
            model.teaching,
            "the last days of a dose rhythm often run hungrier. that's the shape of the rhythm, not a slip."
        )
    }

    /// p54 — the Method's exact interval defect lived here too: a
    /// bare `day >= 6` gate read a ten-day rhythm's day 6 (mid-cycle,
    /// medicine still high) as the hungry end, and stayed silent on
    /// days 8-10 when it was finally true.
    func testAnIntervalRhythmsWaningEndIsTheBandNotDaySix() {
        let mid = WeeklyReadComposer.compose(inputs(
            doseWeek: .takenOnDay, cycleDay: 6, cycleLength: 10
        ))
        XCTAssertNotEqual(
            mid.teaching,
            "the last days of a dose rhythm often run hungrier. that's the shape of the rhythm, not a slip.",
            "day 6 of 10 is mid-cycle; the hungry-end teaching would be false"
        )
        let waning = WeeklyReadComposer.compose(inputs(
            doseWeek: .takenOnDay, cycleDay: 9, cycleLength: 10
        ))
        XCTAssertEqual(
            waning.teaching,
            "the last days of a dose rhythm often run hungrier. that's the shape of the rhythm, not a slip."
        )
    }

    func testEarlyCycleClosesTheSteadyWeekInstead() {
        // p54 re-pin: an early-cycle, recorded, non-drifting hold week
        // p79 — silent again: the hold offer beneath already says
        // "nothing needs to change this week." (founder steer).
        let model = WeeklyReadComposer.compose(inputs(
            doseWeek: .takenOnDay, cycleDay: 2, cycleLength: 7
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
            "plateaus are part of every real weight loss. watch the trend, not one morning."
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

    // MARK: - p54 · what actually mattered this week (§9)

    /// The Method's loop reaches HER: what jeni said, and whether the
    /// record answered. Never on a zero-met week (no scold, no slot).
    func testMethodFollowThroughIsReportedBackToHer() {
        var i = inputs()
        i.methodFollowUpsMet = 2
        i.methodFollowUpsSettled = 3
        let model = WeeklyReadComposer.compose(i)
        XCTAssertTrue(model.observations.contains {
            $0.text == "2 of 3 notes jeni left this week were followed by the move they named."
        })

        i.methodFollowUpsMet = 1
        i.methodFollowUpsSettled = 1
        let one = WeeklyReadComposer.compose(i)
        XCTAssertTrue(one.observations.contains {
            $0.text == "the note jeni left this week was followed by the move it named."
        })

        i.methodFollowUpsMet = 0
        i.methodFollowUpsSettled = 2
        let none = WeeklyReadComposer.compose(i)
        XCTAssertFalse(
            none.observations.contains { $0.text.contains("jeni left") },
            "a zero-met week spends no slot — the read never scolds"
        )
    }

    /// §9's attribution: the week's extra energy named to its days,
    /// as a shape, never a problem.
    func testWeekendShapeIsNamedAsARhythm() {
        var i = inputs()
        i.weekendKcalDelta = 350
        let model = WeeklyReadComposer.compose(i)
        XCTAssertTrue(model.observations.contains {
            $0.text == "weekends ran about 350 kcal above your weekdays. your weekdays stayed steady."
        })
    }

    /// Consistency speaks as a delta when it improved; a softer week
    /// states this week only (information, never debt).
    func testProteinConsistencySpeaksAsADeltaOnlyUpward() {
        var i = inputs()
        i.priorProteinDaysMet = 2
        let up = WeeklyReadComposer.compose(i)
        XCTAssertTrue(up.observations.contains {
            $0.text == "protein goal hit 4 of 7 days \u{00B7} up from 2 last week"
        })

        i.priorProteinDaysMet = 6
        let down = WeeklyReadComposer.compose(i)
        XCTAssertTrue(down.observations.contains {
            $0.text == "protein goal hit 4 of 7 days"
        })
        XCTAssertFalse(down.observations.contains {
            $0.text.contains("down from")
        })
    }

    func testStrengthHeldJoinsTheRead() {
        var i = inputs(doseWeek: nil)
        i.strengthSessions7 = 2
        let model = WeeklyReadComposer.compose(i)
        XCTAssertTrue(model.observations.contains {
            $0.text == "strength: 2 sessions. that's what keeps muscle."
        })

        i.strengthSessions7 = 1
        let below = WeeklyReadComposer.compose(i)
        XCTAssertFalse(
            below.observations.contains { $0.text.contains("strength held") },
            "one session is not the floor; the read does not round up"
        )
    }

    /// The CHAPTER speaks when it can: a year into treatment, a
    /// holding week is the trials' own curve — and only for a
    /// medicated week, only when tenure is her own stated fact.
    func testTenurePlateauTeachesTheMedicinesShape() {
        var i = inputs(
            doseWeek: .takenOnDay,
            weight: .init(band: "holding_steady", sufficiency: "established")
        )
        i.treatmentMonths = 11
        let model = WeeklyReadComposer.compose(i)
        XCTAssertEqual(
            model.teaching,
            "about a year in, the trials' own curves flatten. holding here is the medicine's shape, not a stall."
        )

        i.treatmentMonths = 3
        let early = WeeklyReadComposer.compose(i)
        XCTAssertEqual(
            early.teaching,
            "plateaus are part of every real weight loss. watch the trend, not one morning."
        )
    }

    /// The close never renders over a drifting week or an empty one.
    func testTheCloseKeepsItsGates() {
        let drifting = WeeklyReadComposer.compose(inputs(
            weight: .init(band: "drifting_up", sufficiency: "established",
                          deltaText: "0.4 lb")
        ))
        XCTAssertNil(drifting.teaching)

        let empty = WeeklyReadComposer.compose(inputs(plateDays: 0))
        XCTAssertNil(empty.teaching)
    }
}
