import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - Pass55RegimenTruthTests (pass 55 §4)
//
// The weekly-assumption hunt's findings, pinned. Pass 54 fixed the
// hardcoded dose-week band in the Method and the weekly read (M1);
// this suite pins the SAME defect's remaining consumers — the day
// composer's late-cycle line, the dose-day lead's "the week starts
// here", the evening anchor, the clinician packet's "weekly rhythm"
// question, the standing's un-re-anchored grid, and the pattern
// engine's 7-day terminal window. A q10d user must never be spoken
// to in weekly grammar, and her re-anchored chain must be the ONE
// answer to "is today a dose day".

final class Pass55RegimenTruthTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 9) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func q10(anchor: String = "2026-01-01") -> MedicationScheduleEngine.RegimenFacts {
        .init(
            scheduleRule: "intervalDays",
            intervalDays: 10,
            anchorDayKey: anchor,
            startedAt: day(2026, 1, 1)
        )
    }

    // MARK: - The standing reads the re-anchored chain (P0-5)

    /// q10d, anchored 01-01, the first shot taken LATE on 01-03: the
    /// chain is 01-03 → 01-13. The naive grid says 01-11. The standing
    /// must not tell her "your shot is today" on a day her shot is not
    /// due — and must not go silent on the day it actually is.
    func testAReAnchoredIntervalChainDecidesTheStanding() {
        let events: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-01-01", status: "taken", takenDayKey: "2026-01-03"),
        ]
        let onTheNaiveGridDay = DoseStanding.standing(
            now: day(2026, 1, 11), facts: q10(), events: events, calendar: cal
        )
        if case .dueToday = onTheNaiveGridDay {
            XCTFail("jan 11 is the un-re-anchored grid day; her shot is the 13th")
        }
        let onHerRealDoseDay = DoseStanding.standing(
            now: day(2026, 1, 13), facts: q10(), events: events, calendar: cal
        )
        XCTAssertEqual(
            onHerRealDoseDay, .dueToday,
            "the day the chain actually names must read as due"
        )
    }

    // MARK: - The late-cycle line follows the band, not day 6 (P0-3)

    private func composerInput(
        cycleDay: Int?, length: Int?, hour: Int = 15
    ) -> CarePlanEngine.Input {
        .init(
            day: PrescriptionEngineV2.Day(
                archetype: .protein,
                beats: [.snapMeal, .weighIn],
                weighInIsStaleFallback: false,
                programDay: 12
            ),
            hourOfDay: hour,
            dayInDoseWeek: cycleDay,
            doseCycleLength: length,
            doseCadence: length == 7
                ? .weekly(anchor: 4)
                : length.map { .everyNDays($0) }
        )
    }

    func testDaySixOfATenDayRhythmIsNotTheHungryEnd() {
        let plan = CarePlanEngine.compose(composerInput(cycleDay: 6, length: 10))
        XCTAssertFalse(
            plan.lead?.because?.contains("appetite often stirs") ?? false,
            "day 6 of 10 is mid-cycle; the old >= 6 gate spoke there"
        )
    }

    func testDayNineOfATenDayRhythmEarnsTheLine() {
        let plan = CarePlanEngine.compose(composerInput(cycleDay: 9, length: 10))
        XCTAssertTrue(
            plan.lead?.because?.contains("appetite often stirs") ?? false,
            "day 9 of 10 IS the waning band; silence there was the other half of the lie"
        )
    }

    func testDayFourOfAFiveDayRhythmEarnsTheLine() {
        let plan = CarePlanEngine.compose(composerInput(cycleDay: 4, length: 5))
        XCTAssertTrue(
            plan.lead?.because?.contains("appetite often stirs") ?? false,
            "a q5d user's waning band is days 4-5; the old gate could never fire for her"
        )
    }

    func testDaySixOfSevenStillEarnsTheLine() {
        let plan = CarePlanEngine.compose(composerInput(cycleDay: 6, length: 7))
        XCTAssertTrue(
            plan.lead?.because?.contains("appetite often stirs") ?? false,
            "control: the weekly user's band is unchanged"
        )
    }

    // MARK: - The dose-day lead speaks her rhythm (P0-1)

    private func doseDayInput(
        cadence: MedicationScheduleEngine.Cadence
    ) -> CarePlanEngine.Input {
        .init(
            day: PrescriptionEngineV2.Day(
                archetype: .protein,
                beats: [.snapMeal, .weighIn],
                weighInIsStaleFallback: false,
                programDay: 12
            ),
            isDoseDay: true,
            doseCadence: cadence
        )
    }

    func testWeeklyDoseDayKeepsItsWeekSentence() {
        let plan = CarePlanEngine.compose(doseDayInput(cadence: .weekly(anchor: 4)))
        XCTAssertEqual(plan.lead?.because, "your dose day. the week starts here")
    }

    func testIntervalDoseDayNeverSaysWeek() {
        let plan = CarePlanEngine.compose(doseDayInput(cadence: .everyNDays(10)))
        XCTAssertNotNil(plan.lead?.because)
        XCTAssertFalse(
            plan.lead?.because?.contains("week") ?? true,
            "a q10d user has no dose week to start: \(plan.lead?.because ?? "nil")"
        )
    }

    func testSplitDoseDayNeverSaysTheWeekStartsHere() {
        let plan = CarePlanEngine.compose(doseDayInput(cadence: .twiceWeekly(1, 4)))
        XCTAssertNotNil(plan.lead?.because)
        XCTAssertFalse(
            plan.lead?.because?.contains("starts here") ?? true,
            "a monday+thursday plan starts nothing twice a week: \(plan.lead?.because ?? "nil")"
        )
    }

    // MARK: - The evening anchor speaks her rhythm (P0-2)

    func testEveningAnchorForAWeeklyPlanKeepsItsSentence() {
        let close = EveningCloseEngine.close(.init(
            tomorrowIsDoseDay: true,
            tomorrowDoseCadence: .weekly(anchor: 4)
        ))
        XCTAssertEqual(close.anchor, "tomorrow is your dose day. the week starts there.")
    }

    func testEveningAnchorForAnIntervalPlanNeverSaysWeek() {
        let close = EveningCloseEngine.close(.init(
            tomorrowIsDoseDay: true,
            tomorrowDoseCadence: .everyNDays(10)
        ))
        XCTAssertNotNil(close.anchor)
        XCTAssertFalse(
            close.anchor?.contains("week") ?? true,
            "the evening prep line asserted a weekly rhythm at every cadence: \(close.anchor ?? "nil")"
        )
    }

    // MARK: - The packet's question speaks no rhythm the plan lacks (P0-4)

    @MainActor
    func testThePacketRhythmQuestionNeverSaysWeeklyToAnIntervalUser() throws {
        let context = TestModelContainer.shared.mainContext
        let user = "P55-PKT-Q10"
        defer {
            for record in (try? context.fetch(FetchDescriptor<RegimenPlanRecord>(
                predicate: #Predicate { $0.userId == user }
            ))) ?? [] { context.delete(record) }
            ObservationStore.deleteAll(userId: user, in: context)
            try? context.save()
        }
        let anchor = cal.date(byAdding: .day, value: -21, to: .now)!
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let plan = RegimenPlanRecord(
            userId: user, kind: "medication", displayName: "her med",
            scheduleRule: "intervalDays", startedAt: anchor
        )
        plan.intervalDays = 10
        plan.anchorDayKey = f.string(from: anchor)
        context.insert(plan)
        try context.save()

        let packet = VisitPacketBuilder.build(userId: user, in: context)
        let rhythmQ = packet.questions.first { $0.text.contains("rhythm is fitting") }
        XCTAssertNotNil(
            rhythmQ, "two unrecorded interval slots should propose the rhythm question"
        )
        XCTAssertFalse(
            rhythmQ?.text.contains("weekly") ?? false,
            "her packet's own header says 'every 10 days'; the question said weekly: \(rhythmQ?.text ?? "")"
        )
        UserDefaults.standard.removeObject(
            forKey: "visitq.removed.rhythm.\(user.lowercased())"
        )
    }

    // MARK: - The pattern engine's final cycle runs her cycle (P1-2)

    func testAFoodNoiseOnsetOnDayEightOfTheFinalTenDayCycleIsSeen() {
        // Three cycles, onset day 8 in each — the third cycle is still
        // open (no next dose), so its window is the one the hardcoded
        // 7 truncated.
        let inputs = MedicationPatternEngine.Inputs(
            takenDoseDays: ["2026-07-01", "2026-07-11", "2026-07-21"],
            symptoms: [
                .init("2026-07-08", "food_noise"),
                .init("2026-07-18", "food_noise"),
                .init("2026-07-28", "food_noise"),
            ],
            today: "2026-07-29",
            windowDays: 42,
            cycleLengthDays: 10
        )
        let observations = MedicationPatternEngine.observations(inputs)
        XCTAssertTrue(
            observations.contains { $0.sentence.contains("food noise") },
            "day-8 onsets in every cycle of a q10d rhythm are the exact signature this observation exists for"
        )
    }
}
