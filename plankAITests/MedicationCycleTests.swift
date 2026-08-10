import XCTest
@testable import plankAI

// MARK: - MedicationCycleTests (v25 E2 — B2, RED→GREEN)
//
// The cycle is POSITION, never concentration. These pins encode the
// honesty laws before the implementation exists:
// - zero leakage: daily / as-needed / anchor-less regimens never
//   construct a cycle;
// - day is always 1…7; an unresolved past slot returns nil (the open
//   slot outranks the rhythm — never "day 8 of 7");
// - her actual injection anchors the count when the record has one;
//   the schedule carries it otherwise, and a first-ever week without
//   a single arrived slot says nothing.

final class MedicationCycleTests: XCTestCase {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    /// Monday 2026-08-03 is an anchor day (ISO 1).
    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func weeklyFacts(
        anchor: Int = 2,   // tuesdays
        startedAt: Date
    ) -> MedicationScheduleEngine.RegimenFacts {
        .init(scheduleRule: "weeklyAnchor", anchorWeekday: anchor,
              timeOfDayMinutes: 18 * 60, route: "injection",
              startedAt: startedAt)
    }

    private func taken(_ dayKey: String, takenDayKey: String? = nil)
        -> MedicationScheduleEngine.SlotEvent {
        .init(dayKey: dayKey, status: "taken", takenDayKey: takenDayKey)
    }

    // MARK: zero leakage

    func testDailyRegimenHasNoCycle() {
        let facts = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "daily", route: "oral",
            startedAt: date(2026, 7, 1)
        )
        XCTAssertNil(MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 7), facts: facts, events: [], calendar: cal
        ))
    }

    func testAsNeededAndAnchorlessHaveNoCycle() {
        let asNeeded = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "asNeeded", startedAt: date(2026, 7, 1)
        )
        XCTAssertNil(MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 7), facts: asNeeded, events: [], calendar: cal
        ))
        let anchorless = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "weeklyAnchor", anchorWeekday: nil,
            startedAt: date(2026, 7, 1)
        )
        XCTAssertNil(MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 7), facts: anchorless, events: [], calendar: cal
        ))
    }

    // MARK: first week honesty

    func testNoPositionBeforeTheFirstSlotEverArrives() {
        // Started Wednesday Aug 5; first Tuesday slot is Aug 11.
        // Friday Aug 7: no slot has ever occurred — no position.
        let facts = weeklyFacts(startedAt: date(2026, 8, 5))
        XCTAssertNil(MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 7), facts: facts, events: [], calendar: cal
        ))
    }

    // MARK: event-anchored positions

    func testTakenTodayIsDayOne() {
        let facts = weeklyFacts(startedAt: date(2026, 7, 1))
        let pos = MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 4, hour: 20),   // tuesday, after the shot
            facts: facts,
            events: [taken("2026-08-04")], calendar: cal
        )
        XCTAssertEqual(pos?.day, 1)
        XCTAssertEqual(pos?.length, 7)
        XCTAssertEqual(pos?.basis, .takenDose)
        XCTAssertEqual(pos?.band, .landing)
    }

    func testMidCycleIsSteadyAndLateCycleWanes() {
        let facts = weeklyFacts(startedAt: date(2026, 7, 1))
        let events = [taken("2026-08-04")]   // tuesday
        // friday = day 4
        let friday = MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 7), facts: facts, events: events, calendar: cal
        )
        XCTAssertEqual(friday?.day, 4)
        XCTAssertEqual(friday?.band, .steady)
        // monday = day 7
        let monday = MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 10), facts: facts, events: events, calendar: cal
        )
        XCTAssertEqual(monday?.day, 7)
        XCTAssertEqual(monday?.band, .waning)
    }

    func testLateTakeAnchorsToTheActualInjectionDay() {
        // Tuesday slot taken late on Thursday. The following Monday
        // is day 5 of HER cycle, not day 7 of the plan's.
        let facts = weeklyFacts(startedAt: date(2026, 7, 1))
        let events = [taken("2026-08-04", takenDayKey: "2026-08-06")]
        let pos = MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 10), facts: facts, events: events, calendar: cal
        )
        XCTAssertEqual(pos?.day, 5)
        XCTAssertEqual(pos?.basis, .takenDose)
    }

    // MARK: the open slot outranks the rhythm

    func testUnresolvedPastSlotYieldsNoPosition() {
        // Tuesday slot never marked; Friday: the open slot leads,
        // the cycle says nothing. Never "day 4" of a phantom cycle.
        let facts = weeklyFacts(startedAt: date(2026, 7, 1))
        let pos = MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 7), facts: facts, events: [], calendar: cal
        )
        XCTAssertNil(pos)
    }

    func testDayCanNeverExceedLength() {
        // Taken 9 days ago, this week's slot unresolved → nil,
        // structurally (no "day 10 of 7").
        let facts = weeklyFacts(startedAt: date(2026, 7, 1))
        let events = [taken("2026-07-28")]
        let pos = MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 6), facts: facts, events: events, calendar: cal
        )
        XCTAssertNil(pos)
    }

    // MARK: schedule-anchored positions

    func testDoseDayBeforeMarkingIsDayOneBySchedule() {
        // Last week taken; today IS the new Tuesday, not yet marked:
        // the seam day reads day 1 (the surface leads with the dose).
        let facts = weeklyFacts(startedAt: date(2026, 7, 1))
        let events = [taken("2026-08-04")]
        let pos = MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 11, hour: 9),
            facts: facts, events: events, calendar: cal
        )
        XCTAssertEqual(pos?.day, 1)
        XCTAssertEqual(pos?.basis, .schedule)
    }

    func testSkippedDoseCarriesPositionBySchedule() {
        // She skipped this week's shot (resolved, honest). The plan
        // still carries a position, hedged by basis .schedule.
        let facts = weeklyFacts(startedAt: date(2026, 7, 1))
        let events = [MedicationScheduleEngine.SlotEvent(
            dayKey: "2026-08-04", status: "skipped"
        )]
        let pos = MedicationScheduleEngine.cyclePosition(
            now: date(2026, 8, 7), facts: facts, events: events, calendar: cal
        )
        XCTAssertEqual(pos?.day, 4)
        XCTAssertEqual(pos?.basis, .schedule)
    }
}
