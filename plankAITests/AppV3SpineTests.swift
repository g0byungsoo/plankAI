import XCTest
@testable import plankAI

// v3 spine tables (docs/app_v3/03_BUILD_PLAN.md Phase 1): chapter
// derivation, day standing, the one-thing/rhythm split, presence
// ledger idempotence, and break-range coverage. Pure cores + injected
// UserDefaults suites — nothing touches the live defaults.
final class AppV3SpineTests: XCTestCase {

    private var suite: UserDefaults!
    private let suiteName = "app-v3-spine-tests"

    override func setUp() {
        super.setUp()
        suite = UserDefaults(suiteName: suiteName)
        suite.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Chapter

    func testChapterDerivationTable() {
        // (glp1StatusKey, maintenance) → chapter
        let table: [(String, Bool, Chapter)] = [
            ("current", false, .onMedication),
            ("current", true, .onMedication),   // medication wins
            ("past", true, .keeping),
            ("past", false, .losing),           // post-GLP-1 still losing
            ("none", true, .keeping),           // graduate in maintenance
            ("none", false, .losing),
            ("considering", false, .losing),
            ("", false, .losing),
            ("prefer_not_say", false, .losing),
        ]
        for (status, maintenance, expected) in table {
            XCTAssertEqual(
                Chapter.derive(glp1StatusKey: status, isMaintenanceMode: maintenance),
                expected,
                "status=\(status) maintenance=\(maintenance)"
            )
        }
    }

    // MARK: - DayStanding

    func testDayStandingThresholds() {
        XCTAssertEqual(DayStanding.from(completedCount: nil), .quiet)
        XCTAssertEqual(DayStanding.from(completedCount: 0), .quiet)
        XCTAssertEqual(DayStanding.from(completedCount: 1), .partial)
        XCTAssertEqual(DayStanding.from(completedCount: 2), .partial)
        XCTAssertEqual(DayStanding.from(completedCount: 3), .kept)
        XCTAssertEqual(DayStanding.from(completedCount: 5), .kept)
        // one-thing-done promotes a 2-count day to kept, not a 1-count
        XCTAssertEqual(DayStanding.from(completedCount: 2, oneThingDone: true), .kept)
        XCTAssertEqual(DayStanding.from(completedCount: 1, oneThingDone: true), .partial)
    }

    // MARK: - One thing + rhythm split

    func testOneThingIsNeverAProgressRow() {
        // Every day of a 4-week window, across tiers: the one thing
        // exists (enrolled days always carry an actionable beat), is
        // never the steps row, and the rhythm never contains it.
        for tier in [IntensityTier.soft, .medium, .hard] {
            let profile = IntensityProfile.from(tier: tier)
            for day in 1...28 {
                let composed = PrescriptionEngineV2.compose(
                    programDay: day, totalDays: 84, profile: profile,
                    context: .init(
                        glp1Status: "", restrictiveRisk: false,
                        maintenanceMode: false, highStress: false,
                        lastWeighInDaysAgo: 1, lastSnapDaysAgo: nil
                    )
                )
                let one = composed.oneThing
                XCTAssertNotNil(one, "day \(day) \(tier) should have an ask")
                XCTAssertFalse(one?.isProgressRow ?? true,
                               "steps can never be the ask")
                XCTAssertFalse(
                    composed.rhythm.contains(where: { $0.itemKey == one?.itemKey }),
                    "rhythm must not duplicate the one thing"
                )
                XCTAssertEqual(
                    composed.rhythm.count + 1, composed.beats.count,
                    "split must partition the beats"
                )
            }
        }
    }

    func testRestDayOneThingIsBreath() {
        let profile = IntensityProfile.from(tier: .medium)
        // Day 7 is the rest slot in the standard rotation.
        let composed = PrescriptionEngineV2.compose(
            programDay: 7, totalDays: 84, profile: profile,
            context: .init(
                glp1Status: "", restrictiveRisk: false,
                maintenanceMode: false, highStress: false,
                lastWeighInDaysAgo: 1, lastSnapDaysAgo: nil
            )
        )
        guard case .breath = composed.oneThing else {
            return XCTFail("rest day's ask should be the 60s breath, got \(String(describing: composed.oneThing))")
        }
    }

    // MARK: - PresenceLedger

    func testPresenceLedgerCountsOncePerDay() {
        let day1 = ISO8601DateFormatter().date(from: "2026-07-01T09:00:00Z")!
        let day1Later = ISO8601DateFormatter().date(from: "2026-07-01T20:00:00Z")!
        let day2 = ISO8601DateFormatter().date(from: "2026-07-02T08:00:00Z")!

        PresenceLedger.recordMeaningfulAction(suite, now: day1)
        XCTAssertEqual(suite.integer(forKey: PresenceLedger.countKey), 1)

        PresenceLedger.recordMeaningfulAction(suite, now: day1Later)
        XCTAssertEqual(suite.integer(forKey: PresenceLedger.countKey), 1,
                       "same-day repeats must not double-count")

        PresenceLedger.recordMeaningfulAction(suite, now: day2)
        XCTAssertEqual(suite.integer(forKey: PresenceLedger.countKey), 2)
    }

    // MARK: - BreakState

    func testBreakRangesCoverInclusiveDays() {
        let f = ISO8601DateFormatter()
        let start = f.date(from: "2026-07-02T10:00:00Z")!
        let end = f.date(from: "2026-07-04T10:00:00Z")!
        let after = f.date(from: "2026-07-06T10:00:00Z")!

        XCTAssertFalse(BreakState.isActiveIn(suite))
        BreakState.begin(suite, now: start)
        XCTAssertTrue(BreakState.isActiveIn(suite))

        // Active break covers start..today, not the future.
        XCTAssertTrue(BreakState.covers(dayKey: "2026-07-03", suite, now: end))
        XCTAssertFalse(BreakState.covers(dayKey: "2026-07-01", suite, now: end))
        XCTAssertFalse(BreakState.covers(dayKey: "2026-07-09", suite, now: end))

        BreakState.end(suite, now: end)
        XCTAssertFalse(BreakState.isActiveIn(suite))

        // Closed range persists and stays inclusive on both ends.
        XCTAssertTrue(BreakState.covers(dayKey: "2026-07-02", suite, now: after))
        XCTAssertTrue(BreakState.covers(dayKey: "2026-07-04", suite, now: after))
        XCTAssertFalse(BreakState.covers(dayKey: "2026-07-05", suite, now: after))

        // begin() while active is a no-op; a second break appends.
        BreakState.begin(suite, now: f.date(from: "2026-07-08T10:00:00Z")!)
        BreakState.end(suite, now: f.date(from: "2026-07-09T10:00:00Z")!)
        XCTAssertEqual(BreakState.storedRanges(suite).count, 2)
        XCTAssertTrue(BreakState.covers(dayKey: "2026-07-08", suite, now: after))
    }
}
