import XCTest
import SwiftData
@testable import plankAI
@testable import PlankSync

// MARK: - PenSupplyTests (p70)
//
// THE PEN, COUNTED — the stated fact + the subtraction. The laws:
//   · remaining derives (her count minus doses recorded after the
//     statement) — nothing decrements, so un-marking a dose gives the
//     count back and restating replaces the fact.
//   · a run-out DAY exists only on a fixed-interval rhythm;
//     twiceWeekly/as-needed get the count and no date.
//   · doses taken BEFORE the statement never draw it down (she counted
//     what was left, not what the record holds).
//   · the whisper speaks only at 1 and 0.

@MainActor
final class PenSupplyTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "PenSupplyTests-\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(
            byAdding: .day, value: offset,
            to: Calendar.current.startOfDay(for: .now)
        )!
    }

    // MARK: the stated fact

    func testStatementRoundTripsAndClears() {
        XCTAssertNil(PenSupply.statement(defaults: defaults))
        PenSupply.state(4, defaults: defaults)
        XCTAssertEqual(PenSupply.statement(defaults: defaults)?.dosesOnHand, 4)
        PenSupply.clear(defaults: defaults)
        XCTAssertNil(PenSupply.statement(defaults: defaults))
    }

    func testGarbageCountsAreRefusedAtTheDoor() {
        PenSupply.state(0, defaults: defaults)
        XCTAssertNil(PenSupply.statement(defaults: defaults))
        PenSupply.state(-3, defaults: defaults)
        XCTAssertNil(PenSupply.statement(defaults: defaults))
        PenSupply.state(500, defaults: defaults)
        XCTAssertNil(PenSupply.statement(defaults: defaults), "a slipped digit is not a supply")
    }

    // MARK: the subtraction

    func testRemainingDerivesFromDosesAfterTheStatement() {
        let s = PenSupply.Statement(dosesOnHand: 4, statedAt: .now)
        XCTAssertEqual(PenSupply.read(statement: s, takenAfterStatement: 0,
                                      nextDoseDay: nil, intervalDays: nil).remaining, 4)
        XCTAssertEqual(PenSupply.read(statement: s, takenAfterStatement: 3,
                                      nextDoseDay: nil, intervalDays: nil).remaining, 1)
        XCTAssertEqual(PenSupply.read(statement: s, takenAfterStatement: 9,
                                      nextDoseDay: nil, intervalDays: nil).remaining, 0,
                       "the floor is 0 — a count never goes negative")
    }

    func testRunOutDayNeedsAFixedInterval() {
        let s = PenSupply.Statement(dosesOnHand: 3, statedAt: .now)
        let next = day(2)
        // weekly: 3 doses left, next in 2 days → last = next + 2×7.
        let weekly = PenSupply.read(statement: s, takenAfterStatement: 0,
                                    nextDoseDay: next, intervalDays: 7)
        XCTAssertEqual(weekly.lastDoseDay, day(2 + 14))
        // no interval (twiceWeekly / as-needed): the count, no date.
        let vague = PenSupply.read(statement: s, takenAfterStatement: 0,
                                   nextDoseDay: next, intervalDays: nil)
        XCTAssertEqual(vague.remaining, 3)
        XCTAssertNil(vague.lastDoseDay,
                     "a rhythm without a fixed interval must not claim a run-out day")
        // a done pen claims no day either.
        let done = PenSupply.read(statement: s, takenAfterStatement: 3,
                                  nextDoseDay: next, intervalDays: 7)
        XCTAssertNil(done.lastDoseDay)
    }

    func testIntervalVocabularyMatchesTheCadence() {
        XCTAssertEqual(PenSupply.intervalDays(for: .weekly(anchor: 3)), 7)
        XCTAssertEqual(PenSupply.intervalDays(for: .daily), 1)
        XCTAssertEqual(PenSupply.intervalDays(for: .everyNDays(10)), 10)
        XCTAssertNil(PenSupply.intervalDays(for: .twiceWeekly(1, 4)))
        XCTAssertNil(PenSupply.intervalDays(for: .asNeeded))
        XCTAssertNil(PenSupply.intervalDays(for: .unknown))
    }

    // MARK: the words

    func testTheRowSpeaksHerCount() {
        // p78 — the regimen row's label is "doses left" now, so the
        // value is the count alone (the pair used to say it twice).
        XCTAssertEqual(PenSupply.rowWord(remaining: 4), "4")
        XCTAssertEqual(PenSupply.rowWord(remaining: 1), "1")
        XCTAssertEqual(PenSupply.rowWord(remaining: 0), "none, by your count")
    }

    func testTheWhisperSpeaksOnlyWhenItMatters() {
        XCTAssertNil(PenSupply.whisper(remaining: 4))
        XCTAssertNil(PenSupply.whisper(remaining: 2))
        XCTAssertNotNil(PenSupply.whisper(remaining: 1))
        XCTAssertNotNil(PenSupply.whisper(remaining: 0))
        // The words record and name logistics; they never grade or urge.
        for w in [PenSupply.whisper(remaining: 1)!, PenSupply.whisper(remaining: 0)!] {
            for banned in ["must", "hurry", "warning", "danger", "!"] {
                XCTAssertFalse(w.contains(banned), w)
            }
        }
    }

    // MARK: the record-side count

    func testTakenCountRespectsTheStatementMoment() throws {
        let schema = Schema([DoseEventRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let uid = UUID().uuidString
        let statedAt = Date()

        func event(_ id: String, status: String, takenAt: Date?, scheduledAt: Date) {
            let e = DoseEventRecord(
                id: id, userId: uid, regimenPlanId: "plan-1",
                dayKey: "2026-09-02", scheduledAt: scheduledAt, status: status
            )
            e.takenAt = takenAt
            context.insert(e)
        }

        // Taken BEFORE the statement: already in her count.
        event("before", status: "taken",
              takenAt: statedAt.addingTimeInterval(-3600),
              scheduledAt: statedAt.addingTimeInterval(-3600))
        // Taken AFTER: draws down.
        event("after", status: "taken",
              takenAt: statedAt.addingTimeInterval(3600),
              scheduledAt: statedAt.addingTimeInterval(3600))
        // Skipped after: a skip spends nothing.
        event("skipped", status: "skipped", takenAt: nil,
              scheduledAt: statedAt.addingTimeInterval(7200))
        // Taken after with no takenAt: the slot's moment stands in.
        event("after-noat", status: "taken", takenAt: nil,
              scheduledAt: statedAt.addingTimeInterval(9000))
        try context.save()

        XCTAssertEqual(
            PenSupply.takenCount(since: statedAt, userId: uid, in: context), 2
        )
    }
}
