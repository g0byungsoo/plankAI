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
                Chapter.derive(glp1StatusKey: status, isMaintenanceMode: maintenance,
                               hasActiveMedicationRegimen: false),
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

    // MARK: - BandModel (keeping chapter)

    func testBandZoneTable() {
        let settle = 70.0
        // (ema, expected) — thresholds at +1.4 / +2.3 kg over settle.
        let table: [(Double, BandZone)] = [
            (68.0, .steady),    // below settle = holding
            (70.0, .steady),
            (71.3, .steady),
            (71.4, .drifting),  // ~3 lb — the watch window opens
            (72.2, .drifting),
            (72.3, .reset),     // ~5 lb — the supported reset arc
            (75.0, .reset),
        ]
        for (ema, expected) in table {
            XCTAssertEqual(
                BandModel.zone(emaKg: ema, settleKg: settle), expected,
                "ema \(ema) over settle \(settle)"
            )
        }
    }

    func testBandCrossingFiresOncePerTransition() {
        // First read is the baseline — never a crossing.
        XCTAssertNil(BandModel.consumeCrossing(newZone: .steady, suite))
        // Same zone again: no crossing.
        XCTAssertNil(BandModel.consumeCrossing(newZone: .steady, suite))
        // Transition: fires once...
        XCTAssertEqual(BandModel.consumeCrossing(newZone: .drifting, suite), .drifting)
        // ...and not again while unchanged.
        XCTAssertNil(BandModel.consumeCrossing(newZone: .drifting, suite))
        // Recovery back is also a (good) crossing.
        XCTAssertEqual(BandModel.consumeCrossing(newZone: .steady, suite), .steady)
    }

    func testKeptWeekRequiresPatternAndBand() {
        XCTAssertTrue(BandModel.weekIsKept(weighDays: 1, presenceDays: 3, zone: .steady))
        XCTAssertTrue(BandModel.weekIsKept(weighDays: 2, presenceDays: 6, zone: .steady))
        XCTAssertFalse(BandModel.weekIsKept(weighDays: 0, presenceDays: 7, zone: .steady),
                       "no weigh-in = the pattern broke (the earliest drift signal)")
        XCTAssertFalse(BandModel.weekIsKept(weighDays: 1, presenceDays: 2, zone: .steady))
        XCTAssertFalse(BandModel.weekIsKept(weighDays: 1, presenceDays: 5, zone: .drifting))
    }

    // MARK: - Phase-7 JITAI gates

    func testLapseSupportEligibility() {
        // The early window only, never beside the evening review,
        // never on a break.
        XCTAssertTrue(NotificationOrchestrator.lapseSupportEligible(
            programDay: 1, eveningReviewActive: false, onBreak: false))
        XCTAssertTrue(NotificationOrchestrator.lapseSupportEligible(
            programDay: 42, eveningReviewActive: false, onBreak: false))
        XCTAssertFalse(NotificationOrchestrator.lapseSupportEligible(
            programDay: 43, eveningReviewActive: false, onBreak: false),
            "the JITAI window closes after week 6 (prompt half-life)")
        XCTAssertFalse(NotificationOrchestrator.lapseSupportEligible(
            programDay: 10, eveningReviewActive: true, onBreak: false),
            "never two uninvited evening pushes")
        XCTAssertFalse(NotificationOrchestrator.lapseSupportEligible(
            programDay: 10, eveningReviewActive: false, onBreak: true))
        XCTAssertFalse(NotificationOrchestrator.lapseSupportEligible(
            programDay: 0, eveningReviewActive: false, onBreak: false))
    }

    func testJitaiDeepLinkDestinations() {
        // The 4-site id protocol's delegate leg: every phase-7 ping
        // must resolve to a route (a dead deep link is a silent
        // gating hazard).
        XCTAssertEqual(
            NotificationDelegate.destination(forNotificationId: "lapse_support")?.absoluteString,
            "jenifit://breath"
        )
        XCTAssertEqual(
            NotificationDelegate.destination(forNotificationId: "keeping_zone")?.absoluteString,
            "jenifit://today"
        )
        XCTAssertEqual(
            NotificationDelegate.destination(forNotificationId: "keeping_line_quiet")?.absoluteString,
            "jenifit://today"
        )
    }

    func testZonePushCopy() {
        XCTAssertNil(NotificationOrchestrator.zonePushCopy(.steady),
                     "recovery celebrates in-app; no push")
        let drifting = NotificationOrchestrator.zonePushCopy(.drifting)
        let reset = NotificationOrchestrator.zonePushCopy(.reset)
        XCTAssertNotNil(drifting)
        XCTAssertNotNil(reset)
        // Voice floors: lowercase, no alarm words.
        for copy in [drifting!, reset!] {
            XCTAssertEqual(copy.title, copy.title.lowercased())
            XCTAssertFalse(copy.body.lowercased().contains("alarm"))
            XCTAssertFalse(copy.body.lowercased().contains("warning"))
            XCTAssertFalse(copy.body.lowercased().contains("fail"))
        }
    }

    // MARK: - QuietHours (zero-input rhythm)

    func testOvernightQuietHours() {
        let f = ISO8601DateFormatter()
        let now = f.date(from: "2026-07-06T12:00:00Z")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        // dinner 19:30 yesterday → breakfast 08:30 today = 13h
        let times = [
            f.date(from: "2026-07-05T12:10:00Z")!,
            f.date(from: "2026-07-05T19:30:00Z")!,
            f.date(from: "2026-07-06T08:30:00Z")!,
        ]
        let hours = QuietHours.overnightQuietHours(
            plateTimes: times, now: now, calendar: cal
        )
        XCTAssertEqual(hours ?? 0, 13.0, accuracy: 0.01)

        // No plate today yet → nil (never narrate a stretch that
        // hasn't ended).
        XCTAssertNil(QuietHours.overnightQuietHours(
            plateTimes: Array(times.prefix(2)), now: now, calendar: cal
        ))

        // A 26h gap (missed logging) is outside the sanity band.
        let sparse = [
            f.date(from: "2026-07-05T06:00:00Z")!,
            f.date(from: "2026-07-06T08:30:00Z")!,
        ]
        XCTAssertNil(QuietHours.overnightQuietHours(
            plateTimes: sparse, now: now, calendar: cal
        ))
    }

    func testEatingWindowAndQuietNights() {
        let f = ISO8601DateFormatter()
        let now = f.date(from: "2026-07-06T21:00:00Z")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let today = [
            f.date(from: "2026-07-06T09:00:00Z")!,
            f.date(from: "2026-07-06T13:00:00Z")!,
            f.date(from: "2026-07-06T19:00:00Z")!,
        ]
        XCTAssertEqual(
            QuietHours.eatingWindowHours(plateTimes: today, now: now, calendar: cal) ?? 0,
            10.0, accuracy: 0.01
        )

        // Three consecutive evenings 19:00 → mornings 09:00 = 14h
        // nights ×3 (needs a plate on BOTH sides of each night).
        var week: [Date] = []
        for day in ["2026-07-03", "2026-07-04", "2026-07-05", "2026-07-06"] {
            week.append(f.date(from: "\(day)T09:00:00Z")!)
            week.append(f.date(from: "\(day)T19:00:00Z")!)
        }
        XCTAssertEqual(
            QuietHours.quietNights(plateTimes: week, minHours: 11, now: now, calendar: cal),
            3
        )
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
