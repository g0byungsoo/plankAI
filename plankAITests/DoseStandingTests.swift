import XCTest
@testable import plankAI

// THE STANDING — "when is my next shot, and did I take the last one?"
//
// Built because production said so: over the three days these events
// have existed, 42 users configured a regimen, 34 logged a side
// effect, and 3 ever marked a dose taken. These tests pin the four
// standings and the two ways the sentence could lie — a noun that
// calls a pill a shot, and a countdown that reads "in 1 days".

final class DoseStandingTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)

    /// Thursday 2026-08-13, 09:00 local.
    private func thursday(_ hour: Int = 9) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 13; c.hour = hour
        return cal.date(from: c)!
    }

    private func weekly(
        anchorWeekday: Int = 4,          // ISO Thursday
        startedDaysAgo: Int = 30
    ) -> MedicationScheduleEngine.RegimenFacts {
        .init(
            scheduleRule: "weeklyAnchor",
            anchorWeekday: anchorWeekday,
            timeOfDayMinutes: 18 * 60,
            route: "injection",
            startedAt: cal.date(byAdding: .day, value: -startedDaysAgo,
                                to: thursday())!
        )
    }

    private func key(_ daysAgo: Int) -> String {
        MedicationScheduleEngine.dayKey(
            for: cal.date(byAdding: .day, value: -daysAgo, to: thursday())!,
            calendar: cal
        )
    }

    // MARK: - The four standings

    func testDoseDayWithNothingRecordedIsDue() {
        let s = DoseStanding.standing(
            now: thursday(), facts: weekly(), events: [], calendar: cal
        )
        XCTAssertEqual(s, .dueToday)
    }

    func testTakenTodayReadsAsDone() {
        let s = DoseStanding.standing(
            now: thursday(), facts: weekly(),
            events: [.init(dayKey: key(0), status: "taken")],
            calendar: cal
        )
        XCTAssertEqual(s, .doneToday(site: nil))
    }

    func testSkippedTodayIsStatedFlatly() {
        let s = DoseStanding.standing(
            now: thursday(), facts: weekly(),
            events: [.init(dayKey: key(0), status: "skipped")],
            calendar: cal
        )
        XCTAssertEqual(s, .skippedToday)
    }

    /// The state Home could not speak AT ALL before this engine: five
    /// days out of seven, the product said nothing about her medication.
    ///
    /// Her recent slots are RESOLVED here, which is the point — an
    /// unresolved one outranks the countdown, and the sibling test
    /// below pins that.
    func testNonDoseDayNamesTheNextOne() {
        let monday = cal.date(byAdding: .day, value: -3, to: thursday())!
        let s = DoseStanding.standing(
            now: monday, facts: weekly(),
            events: [
                .init(dayKey: key(7), status: "taken"),     // 2026-08-06
                .init(dayKey: key(14), status: "taken")     // 2026-07-30
            ],
            calendar: cal
        )
        XCTAssertEqual(s, .upcoming(days: 3, weekday: "thursday"))
    }

    /// A dose she can still take outranks a dose she will take.
    ///
    /// This is the branch that failed the first draft of the test
    /// above: with NO events seeded every past slot is unresolved, so
    /// the engine correctly refused to count down to the next shot
    /// while a previous one was still open. The engine was right and
    /// the fixture was wrong.
    func testOpenLateSlotOutranksTheUpcomingOne() {
        let monday = cal.date(byAdding: .day, value: -3, to: thursday())!
        let s = DoseStanding.standing(
            now: monday, facts: weekly(), events: [], calendar: cal
        )
        guard case let .late(_, weekday) = s else {
            return XCTFail("expected a late standing, got \(String(describing: s))")
        }
        XCTAssertEqual(weekday, "thursday")
    }

    // MARK: - Silence

    func testAsNeededHasNoStanding() {
        let facts = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "asNeeded", startedAt: thursday()
        )
        XCTAssertNil(DoseStanding.standing(
            now: thursday(), facts: facts, events: [], calendar: cal
        ))
    }

    /// Before the regimen began there is no schedule to stand in.
    func testNothingBeforeTheRegimenStarts() {
        let facts = weekly(startedDaysAgo: -7)   // starts a week from now
        XCTAssertNil(DoseStanding.standing(
            now: thursday(), facts: facts, events: [], calendar: cal
        ))
    }

    // MARK: - The sentence

    func testOneDayAwayIsAWordNotACount() {
        let read = DoseStanding.read(
            .upcoming(days: 1, weekday: "friday"), isOral: false
        )
        XCTAssertEqual(read.headline, "your next shot is tomorrow")
        XCTAssertNil(read.detail, "\"in 1 days\" must be unreachable")
    }

    func testMultipleDaysCarryTheCount() {
        let read = DoseStanding.read(
            .upcoming(days: 3, weekday: "thursday"), isOral: false
        )
        XCTAssertEqual(read.headline, "your next shot is thursday")
        XCTAssertEqual(read.detail, "in 3 days")
    }

    /// A pill is not a shot. The catalog's own noun, every branch.
    func testOralNeverReadsAsAnInjection() {
        for standing: DoseStanding.Standing in [
            .dueToday,
            .doneToday(site: nil),
            .skippedToday,
            .upcoming(days: 2, weekday: "sunday"),
            .late(slotDayKey: "2026-08-06", weekday: "thursday")
        ] {
            let read = DoseStanding.read(standing, isOral: true)
            XCTAssertFalse(read.headline.contains("shot"), read.headline)
            XCTAssertTrue(read.headline.contains("dose"), read.headline)
        }
    }

    /// Home is a screen she may hand to someone. The standing follows
    /// the existing to-do row's discretion and names no product.
    func testTheStandingNamesNoMedication() {
        let read = DoseStanding.read(.dueToday, isOral: false)
        XCTAssertEqual(read.headline, "your shot is today")
        XCTAssertEqual(read.detail, "mark it when you take it")
    }

    /// Only a late standing carries a slot to open; the rest route to
    /// her regimen, so a tap never marks a day she did not name.
    func testOnlyTheLateStandingCarriesASlot() {
        XCTAssertEqual(
            DoseStanding.read(
                .late(slotDayKey: "2026-08-06", weekday: "thursday"),
                isOral: false
            ).slotDayKey,
            "2026-08-06"
        )
        XCTAssertNil(DoseStanding.read(.dueToday, isOral: false).slotDayKey)
        XCTAssertNil(DoseStanding.read(.skippedToday, isOral: false).slotDayKey)
    }

    func testVoiceOverIsASentencePerState() {
        let labels = [
            DoseStanding.read(.dueToday, isOral: false).voiceOver,
            DoseStanding.read(.doneToday(site: "left abdomen"), isOral: false).voiceOver,
            DoseStanding.read(.upcoming(days: 1, weekday: "friday"), isOral: false).voiceOver
        ]
        XCTAssertEqual(Set(labels).count, 3, "each state needs its own label")
        XCTAssertTrue(labels.allSatisfy { $0.hasSuffix(".") })
        XCTAssertTrue(labels[1].contains("left abdomen"))
    }
}
