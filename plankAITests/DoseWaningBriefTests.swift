import XCTest
@testable import plankAI

// MARK: - DoseWaningBriefTests (p79 — THE FELT WEEK)
//
// r2's #1 moment-anchored question ("day 6, my candy thoughts are
// back — is it failing?") answered at the morning it is asked. Pins:
// the clause fires exactly once per cycle (its opening day), speaks
// HER recorded pattern when the signature holds, never a verdict on
// the medication, and sits in the ladder beneath the weigh-in.

final class DoseWaningBriefTests: XCTestCase {

    private func ctx(
        waningOpens: Bool = true,
        cycleDay: Int? = 6,
        typicalDay: Int? = nil,
        sleep: Double? = nil,
        weighDay: Bool = false
    ) -> DailyBriefEngine.Context {
        var c = DailyBriefEngine.Context(
            name: nil,
            programDay: 20,
            archetype: .balanced,
            isWeighInDay: weighDay,
            weighInIsStaleFallback: false,
            emaDelta7dKg: nil,
            lossRatePctPerWeek: nil,
            showedUpCount: 8,
            daysSinceLastOpen: 0,
            promiseJustKept: false,
            proteinTargetG: 90,
            yesterdayStepsHitGoal: false,
            maintenanceMode: false,
            glp1Cohort: .onGlp1,
            dayKey: "2026-09-04"
        )
        c.doseCycleDay = cycleDay
        c.doseWaningOpens = waningOpens
        c.foodNoiseTypicalDay = typicalDay
        c.sleepHoursLastNight = sleep
        return c
    }

    func testWaningOpeningSpeaksTheWeekShape() {
        let brief = DailyBriefEngine.brief(for: ctx())
        XCTAssertEqual(brief.clause, "dose_waning")
        XCTAssertTrue(brief.line.contains("day 6 of your dose week"))
        XCTAssertTrue(brief.line.contains("appetite"))
    }

    func testHerOwnPatternOutranksThePopulationShape() {
        let brief = DailyBriefEngine.brief(for: ctx(typicalDay: 6))
        XCTAssertEqual(brief.clause, "dose_waning")
        XCTAssertTrue(brief.line.contains("food noise has come back near day 6"))
        XCTAssertTrue((brief.chatSeed ?? "").contains("their own record"))
    }

    func testMidWaningStaysQuiet() {
        // Day 7 of the same cycle: the clause spoke yesterday; a
        // week that says "the hungry end" three mornings running
        // teaches her to stop reading.
        let brief = DailyBriefEngine.brief(for: ctx(waningOpens: false, cycleDay: 7))
        XCTAssertNotEqual(brief.clause, "dose_waning")
    }

    func testNeverAVerdictOnTheMedication() {
        // The banned register (r2's constraint): the moment must
        // never read as efficacy judgment or promise relief.
        for face in [ctx(), ctx(typicalDay: 6)] {
            let brief = DailyBriefEngine.brief(for: face)
            let spoken = (brief.line + " " + (brief.second ?? "")).lowercased()
            for banned in ["failing", "tolerance", "working", "wearing off",
                           "next dose", "next shot"] {
                XCTAssertFalse(spoken.contains(banned),
                    "the waning morning may never say '\(banned)'")
            }
            XCTAssertTrue((brief.chatSeed ?? "").contains("never"),
                "the chat seed must carry the refusals forward")
        }
    }

    func testWaningOutranksTheRoutineReceipts() {
        // Once-per-cycle beats every daily-recurring line: the trend
        // receipt (walked: it fired every losing morning and starved
        // this clause), the weigh-day framing, the short-sleep read.
        var trending = ctx(sleep: 5.0, weighDay: true)
        trending.emaDelta7dKg = -0.4
        trending.trendIsEstablished = true
        let brief = DailyBriefEngine.brief(for: trending)
        XCTAssertEqual(brief.clause, "dose_waning")
    }

    // MARK: - The position arithmetic (waningStartDay ⇔ band)

    func testWaningStartDayMatchesTheBandEdgeAtEveryLength() {
        for length in [7, 10, 14, 21, 30] {
            for day in 1...length {
                let p = MedicationScheduleEngine.CyclePosition(
                    day: day, length: length, basis: .takenDose
                )
                XCTAssertEqual(
                    p.band == .waning, day >= p.waningStartDay,
                    "length \(length) day \(day): waningStartDay must be the band's own edge"
                )
            }
        }
    }

    // MARK: - The signature extraction (one arithmetic, two speakers)

    func testFoodNoiseSignatureAgreesWithTheObservation() {
        // Three consecutive cycles with onsets on day 6 — the same
        // fixture shape E2's observation pinned. Signature and
        // sentence must derive from the one arithmetic.
        var inputs = MedicationPatternEngine.Inputs(today: "2026-09-04")
        inputs.takenDoseDays = ["2026-08-14", "2026-08-21", "2026-08-28"]
        inputs.symptoms = [
            .init("2026-08-19", "food_noise"),
            .init("2026-08-26", "food_noise"),
            .init("2026-09-02", "food_noise"),
        ]
        let signature = MedicationPatternEngine.foodNoiseSignature(inputs)
        XCTAssertEqual(signature?.typicalDay, 6)
        XCTAssertEqual(signature?.cycles, 3)
        let observation = MedicationPatternEngine.observations(inputs)
            .first { $0.id == "food-noise-return" }
        XCTAssertEqual(
            observation?.sentence,
            "food noise has come back around day 6 in each of your last three cycles. the days after a dose run quieter."
        )
    }
}
