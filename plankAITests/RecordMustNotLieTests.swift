import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - RecordMustNotLieTests
//
// v25 pass 51 — A USER RECORD MUST NEVER BECOME LESS TRUE BECAUSE JENI
// READ IT, IMPORTED IT, EDITED IT, SYNCED IT, REINSTALLED IT, OR
// CROSSED MIDNIGHT.
//
// Two of pass 50's P1 defects live here because both need the real
// store and the real chokepoints, not a view:
//
// **W1 — USER INTENT WINS.** `WeightLogWriter.persist` updated today's
// row in place without relabeling `source`. So when today's row came
// from Apple Health (the commonest weigh-in source in the product — a
// smart scale) and she TYPED a number over it — the Today ruler, the
// plan-numbers sheet and jeni's log_weight tool all land on this one
// chokepoint — the row kept `"healthkit"`, and `BodyMassImportService`'s
// own per-day rule ("a healthkit row is the one the scale may correct
// in place") overwrote her typed number with the scale's on the next
// launch or observer fire. The law already existed one function down:
// `WeightLogWriter.update` relabels via
// `WeightLedger.sourceAfterCorrection` for exactly this reason. The
// daily chokepoint now uses it too.
//
// **P1 — A CIVIL DAY IS A FACT.** `program_plans.start_date` is a
// Postgres `date` — a CIVIL DATE: "the calendar day she enrolled, where
// she was". The upsert wrote the UTC date of the mint instant and the
// hydrate reparsed the string as UTC MIDNIGHT, which
// `ProgramScheduleCalculator` then re-anchored in the LOCAL calendar.
// For every user west of UTC that instant lands on the PREVIOUS local
// day, so a reinstall/new-phone hydrate read "day 6" where the same
// account read "day 5" the evening before. East of UTC the WRITE side
// shifts instead (a morning mint stores yesterday's date). The fix
// serializes and reparses the LOCAL civil date through one boundary
// (`PlanWireDate`), so the day she enrolled stays the day she enrolled.

@MainActor
final class RecordMustNotLieTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let userId = "RECORD-MUST-NOT-LIE"
    private var savedTimeZone: TimeZone = NSTimeZone.default

    override func setUpWithError() throws {
        savedTimeZone = NSTimeZone.default
        wipe()
    }

    override func tearDownWithError() throws {
        NSTimeZone.default = savedTimeZone
        wipe()
    }

    private func wipe() {
        let uid = userId
        try? context.delete(model: WeightLogRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.delete(model: ProgramPlanRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.save()
    }

    // MARK: - W1 · USER INTENT WINS

    /// The reproduction: scale writes today, she types over it, the
    /// import must never revert her. RED before the fix: the row kept
    /// `"healthkit"` and the importer's decision for the day was
    /// `.update` — the revert.
    func testATypedWeighInOverAHealthRowBecomesHersAndTheImportStandsDown() throws {
        let scaleRow = WeightLogRecord(
            userId: userId, weightKg: 80.0, loggedAt: .now, source: "healthkit"
        )
        context.insert(scaleRow)
        try context.save()

        // She types 76.2 — jeni's tool, the Today ruler and the plan
        // sheet all share this one write path.
        WeightLogWriter.persist(kg: 76.2, userId: userId, in: context)

        XCTAssertEqual(scaleRow.weightKg, 76.2, accuracy: 0.001,
                       "her number lands on the same row (one row per day)")
        XCTAssertEqual(scaleRow.source, "manual",
                       "a number she typed is HERS — keeping 'healthkit' hands the row back to the importer")
        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: .now, existingSource: scaleRow.source, userId: userId
            ),
            .skip,
            "the importer's own manual-wins rule must now protect her typed number"
        )
    }

    /// Control — the scale's own re-weigh correction stays possible: a
    /// row still marked healthkit is the one the importer may update.
    func testAnUntouchedHealthRowIsStillTheScalesToCorrect() {
        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: .now, existingSource: "healthkit", userId: userId
            ),
            .update
        )
    }

    /// Control — typing over her OWN row neither relabels away from
    /// manual nor forks a second row.
    func testTypingOverHerOwnRowStaysHersAndStaysOneRow() throws {
        let hers = WeightLogRecord(
            userId: userId, weightKg: 77.0, loggedAt: .now, source: "manual"
        )
        context.insert(hers)
        try context.save()

        WeightLogWriter.persist(kg: 76.5, userId: userId, in: context)

        let uid = userId
        let rows = (try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == uid }))) ?? []
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.source, "manual")
        XCTAssertEqual(rows.first?.weightKg ?? 0, 76.5, accuracy: 0.001)
    }

    /// Control — a fresh day's typed weigh-in is born manual.
    func testAFreshTypedWeighInIsBornManual() {
        WeightLogWriter.persist(kg: 76.0, userId: userId, in: context)
        let uid = userId
        let rows = (try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == uid }))) ?? []
        XCTAssertEqual(rows.first?.source, "manual")
    }

    // MARK: - P1 · A CIVIL DAY IS A FACT

    /// One calendar pinned to a zone, for building instants the test
    /// controls completely.
    private func calendar(_ zone: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: zone)!
        return cal
    }

    private func hydrateRow(startDate: String, goalDate: String) -> ProgramPlanHydrateRow {
        ProgramPlanHydrateRow(
            id: "P51-CIVIL", user_id: userId.lowercased(),
            start_date: startDate, goal_date: goalDate,
            total_days: 119, current_weight_kg: 75, goal_weight_kg: 65,
            intensity_tier: "medium", phase: "active",
            parent_plan_id: nil, archived_at: nil, completed_at: nil,
            started_at: nil
        )
    }

    private func hydratedProgramDay(
        wireStartDate: String, zone: String, nowLocal: DateComponents
    ) throws -> Int {
        NSTimeZone.default = TimeZone(identifier: zone)!
        defer { NSTimeZone.default = savedTimeZone }

        SyncService.applyHydratedProgramPlans(
            [hydrateRow(startDate: wireStartDate, goalDate: "2026-11-28")],
            userId: userId, context: context
        )
        let uid = userId
        let plan = try XCTUnwrap(
            (try? context.fetch(FetchDescriptor<ProgramPlanRecord>(
                predicate: #Predicate { $0.userId == uid })))?.first
        )
        let now = try XCTUnwrap(calendar(zone).date(from: nowLocal))
        return ProgramScheduleCalculator.compute(
            .init(startDate: plan.startDate, totalDays: plan.totalDays, now: now)
        ).programDay
    }

    /// The reproduction. She enrolled Aug 1 in Los Angeles (10:00 —
    /// mid-morning, so the server's stored civil date is exactly
    /// "2026-08-01" under BOTH the old and the new writer: the fixture
    /// is production-shaped either way). On Aug 5 she is living day 5,
    /// proven locally as the control. Then the phone is reinstalled and
    /// the plan comes back from the server. RED before the fix: the
    /// hydrate anchored "2026-08-01" at UTC midnight = Jul 31, 17:00 in
    /// LA, and the calculator read DAY 6.
    func testAReinstallInLosAngelesKeepsTheProgramDay() throws {
        let la = calendar("America/Los_Angeles")
        let mint = try XCTUnwrap(la.date(from: .init(
            year: 2026, month: 8, day: 1, hour: 10)))
        let now = try XCTUnwrap(la.date(from: .init(
            year: 2026, month: 8, day: 5, hour: 12)))

        NSTimeZone.default = TimeZone(identifier: "America/Los_Angeles")!
        let localTruth = ProgramScheduleCalculator.compute(
            .init(startDate: mint, totalDays: 119, now: now)).programDay
        XCTAssertEqual(localTruth, 5, "control: the day she was living pre-reinstall")

        let hydrated = try hydratedProgramDay(
            wireStartDate: "2026-08-01",
            zone: "America/Los_Angeles",
            nowLocal: .init(year: 2026, month: 8, day: 5, hour: 12)
        )
        XCTAssertEqual(hydrated, 5,
                       "a reinstall must not move what day of the program she is on")
    }

    /// Same fact pattern for a zone EAST of UTC, where the old parse
    /// happened to land on the right day — pinned so the fix cannot
    /// trade one hemisphere for the other.
    func testAReinstallInTokyoKeepsTheProgramDay() throws {
        let hydrated = try hydratedProgramDay(
            wireStartDate: "2026-08-01",
            zone: "Asia/Tokyo",
            nowLocal: .init(year: 2026, month: 8, day: 5, hour: 12)
        )
        XCTAssertEqual(hydrated, 5)
    }

    /// New York and UTC, same contract.
    func testAReinstallInNewYorkAndUTCKeepsTheProgramDay() throws {
        let ny = try hydratedProgramDay(
            wireStartDate: "2026-08-01",
            zone: "America/New_York",
            nowLocal: .init(year: 2026, month: 8, day: 5, hour: 9)
        )
        XCTAssertEqual(ny, 5)
        wipe()
        let utc = try hydratedProgramDay(
            wireStartDate: "2026-08-01",
            zone: "UTC",
            nowLocal: .init(year: 2026, month: 8, day: 5, hour: 12)
        )
        XCTAssertEqual(utc, 5)
    }

    /// Hydrating the same wire date twice (sync replay, second device
    /// pulling the same row) reads the same day both times — the parse
    /// must be a fixed point, not a drift.
    func testReplayingTheHydrateIsAFixedPoint() throws {
        let first = try hydratedProgramDay(
            wireStartDate: "2026-08-01",
            zone: "America/Los_Angeles",
            nowLocal: .init(year: 2026, month: 8, day: 5, hour: 12)
        )
        let second = try hydratedProgramDay(
            wireStartDate: "2026-08-01",
            zone: "America/Los_Angeles",
            nowLocal: .init(year: 2026, month: 8, day: 5, hour: 12)
        )
        XCTAssertEqual(first, second)
        XCTAssertEqual(first, 5)
    }

    /// DST fall-back sits between enrollment and today: the civil-day
    /// arithmetic must not lose or gain a day across the 25-hour day.
    func testTheProgramDaySurvivesTheFallBackTransition() throws {
        // US DST ends 2026-11-01. Enroll Oct 30, read Nov 3 → day 5.
        let hydrated = try hydratedProgramDay(
            wireStartDate: "2026-10-30",
            zone: "America/Los_Angeles",
            nowLocal: .init(year: 2026, month: 11, day: 3, hour: 12)
        )
        XCTAssertEqual(hydrated, 5)
    }

    /// DST spring-forward (2026-03-08) between enrollment and today.
    func testTheProgramDaySurvivesTheSpringForwardTransition() throws {
        let hydrated = try hydratedProgramDay(
            wireStartDate: "2026-03-06",
            zone: "America/Los_Angeles",
            nowLocal: .init(year: 2026, month: 3, day: 10, hour: 12)
        )
        XCTAssertEqual(hydrated, 5)
    }
}

// MARK: - WeightOneStoryTests
//
// v25 pass 51 — ONE WEIGHT STORY. `WeightSeries` is the single place
// that decides which rows are the weigh-in series and how a day
// reduces to one sample; `WeightWeekReadEngine` is the single fold
// behind every drawn line and spoken direction. These tests pin the
// three resolution laws and the timezone-proof deletion.

@MainActor
final class WeightOneStoryTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let userId = "WEIGHT-ONE-STORY"

    override func setUpWithError() throws { wipe() }
    override func tearDownWithError() throws { wipe() }

    private func wipe() {
        let uid = userId
        try? context.delete(model: WeightLogRecord.self,
                            where: #Predicate { $0.userId == uid })
        try? context.save()
        DeletionLedger.clear(userId: userId)
    }

    @discardableResult
    private func row(
        _ kg: Double, daysAgo: Int, hour: Int = 8, source: String = "manual"
    ) -> WeightLogRecord {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: .now))!
        let at = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        let r = WeightLogRecord(userId: userId, weightKg: kg, loggedAt: at, source: source)
        context.insert(r)
        try? context.save()
        return r
    }

    /// THE SIGN-UP SELF-REPORT IS NOT A WEIGH-IN — the trend series
    /// excludes it; the LEDGER (a row you cannot see is a row you
    /// cannot remove) still lists it, provenance visible.
    func testTheSignUpSelfReportFeedsNoTrendButStaysListed() {
        row(60.0, daysAgo: 10, source: "onboarding")
        row(58.4, daysAgo: 2)
        row(58.1, daysAgo: 1)

        let samples = WeightSeries.samples(userId: userId, in: context)
        XCTAssertEqual(samples.count, 2)
        XCTAssertFalse(samples.contains { abs($0.kg - 60.0) < 0.001 },
                       "the consult answer seeded the scale trend")

        let listed = WeightLogWriter.entries(userId: userId, in: context)
        XCTAssertEqual(listed.count, 3, "the ledger hides nothing")
        XCTAssertEqual(listed.last?.source, "onboarding")
    }

    /// A DAY'S SAMPLE IS THE EARLIEST OF THE DAY — in the canonical
    /// reduction AND in the trigger fold, so one physical weigh-in day
    /// can never count differently on two surfaces.
    func testOnePhysicalDayReducesToItsEarliestSampleEverywhere() {
        let morning = row(76.0, daysAgo: 0, hour: 7)
        row(77.4, daysAgo: 0, hour: 20)

        let samples = WeightSeries.samples(userId: userId, in: context)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.kg ?? 0, 76.0, accuracy: 0.001,
                       "the fasted-morning sample is the day")

        let ema = WeightTrendChart.computeEMA(
            logs: [morning] + WeightSeries.records(userId: userId, in: context)
        )
        XCTAssertEqual(ema.last?.emaKg ?? 0, 76.0, accuracy: 0.001,
                       "the trigger fold picked a different sample for the same day")
    }

    /// THE DRAWN LINE IS THE SPOKEN TREND — same fold, same series, so
    /// Becoming's line can never slope against jeni's sentence.
    func testTheDrawnLineEndsExactlyWhereTheSpokenTrendStands() {
        for d in 0..<12 { row(80.0 - Double(d) * 0.1, daysAgo: d) }
        let samples = WeightSeries.samples(userId: userId, in: context)
        let line = WeightWeekReadEngine.trendSeries(samples: samples, now: .now)
        let read = WeightWeekReadEngine.read(samples: samples, now: .now)
        XCTAssertEqual(line.last?.trendKg ?? -1, read.trendKg ?? -2,
                       accuracy: 0.0001,
                       "two folds again — the one-story law broke")
        XCTAssertFalse(line.isEmpty)
    }

    /// DELETE STAYS DELETED, ACROSS TIME ZONES. The day tombstone is a
    /// zone reading; the instant tombstone is not. The two decisions
    /// below differ ONLY in whether the sample's instant is consulted —
    /// the differential that proves why pass 51 added it.
    func testAClearedWeighInStaysClearedAcrossATimeZoneChange() throws {
        // She cleared a weigh-in whose sample instant straddles
        // midnight between Los Angeles and Tokyo.
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let sampleInstant = la.date(from: .init(
            year: 2026, month: 8, day: 17, hour: 23, minute: 30))!

        // Delete under LA: the day tombstone says aug 17 (LA), the
        // instant tombstone says the epoch second.
        NSTimeZone.default = TimeZone(identifier: "America/Los_Angeles")!
        defer { NSTimeZone.default = TimeZone.autoupdatingCurrent }
        DeletionLedger.record(
            id: DeletionLedger.clearedWeightDayId(
                userId: userId, dayKey: TodayStateService.dayKey(for: sampleInstant)),
            userId: userId
        )
        DeletionLedger.record(
            id: DeletionLedger.clearedWeightInstantId(userId: userId, at: sampleInstant),
            userId: userId
        )

        // The phone lands in Tokyo; the importer re-reads the same
        // Health sample, which now buckets onto aug 18 (JST).
        NSTimeZone.default = TimeZone(identifier: "Asia/Tokyo")!
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let tokyoBucket = tokyo.startOfDay(for: sampleInstant)

        // WITHOUT the instant (the pre-51 rule): the day keys diverge
        // and the cleared weigh-in would resurrect.
        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: tokyoBucket, sampleAt: nil,
                existingSource: nil, userId: userId, calendar: tokyo
            ),
            .insert,
            "control: the day tombstone alone cannot see across the zone change"
        )
        // WITH the instant: cleared stays cleared.
        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: tokyoBucket, sampleAt: sampleInstant,
                existingSource: nil, userId: userId, calendar: tokyo
            ),
            .skip,
            "the instant tombstone is zone-proof"
        )
    }

    /// The importer's injected calendar is honored (it used to be an
    /// inert parameter, which made the whole timezone axis untestable):
    /// the same cleared LA day, checked with an LA calendar, skips.
    func testTheImportDecisionHonorsItsInjectedCalendar() {
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let sampleInstant = la.date(from: .init(
            year: 2026, month: 8, day: 17, hour: 23, minute: 30))!
        DeletionLedger.record(
            id: DeletionLedger.clearedWeightDayId(userId: userId, dayKey: "2026-08-17"),
            userId: userId
        )
        XCTAssertEqual(
            BodyMassImportService.importDecision(
                forDay: la.startOfDay(for: sampleInstant), sampleAt: nil,
                existingSource: nil, userId: userId, calendar: la
            ),
            .skip
        )
    }
}

// MARK: - DayKeyVocabularyTests
//
// v25 pass 51 — ONE DAY-KEY VOCABULARY, ON EVERY DEVICE.
//
// The repo's most-used day-key producer (`TodayStateService.dayKey`)
// was a `DateFormatter` with `calendar = .current` and NO locale pin,
// while its ten sibling producers/parsers are pinned Gregorian +
// en_US_POSIX. On any device whose locale renders non-Latin numerals
// (ar, fa, bn, …) or whose region prefers a non-Gregorian calendar
// (Thai Buddhist, Japanese era), the two vocabularies fork — and the
// string is not display: it is IDENTITY. Dose slot ids
// ("<uid>-dose-<dayKey>") split into two rows for one shot, the
// clinician packet's adherence loop queries keys the write path never
// minted (a patient who marked every dose reads as zero), the
// weight-day tombstone stops matching, and one backfill parses a
// Buddhist-era year as Gregorian 2569.
//
// These tests are locale-parametric BY RUNNING THE SUITE TWICE: the
// pass runs them under the host locale and again with
// `-testLanguage ar -testRegion SA`. Before the pin the ar_SA run
// fails (Arabic-Indic digits out of the formatter); after it both
// runs pass byte-identically.

final class DayKeyVocabularyTests: XCTestCase {

    /// Instants that historically expose day boundaries.
    private var probes: [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return [
            Date(),
            cal.date(from: .init(year: 2026, month: 8, day: 18, hour: 0, minute: 5))!,
            cal.date(from: .init(year: 2026, month: 12, day: 31, hour: 23, minute: 55))!,
            cal.date(from: .init(year: 2026, month: 3, day: 8, hour: 12))!,   // DST spring
            cal.date(from: .init(year: 2026, month: 11, day: 1, hour: 12))!,  // DST fall
        ]
    }

    /// The two producers must emit byte-identical keys for the same
    /// instant, whatever the device's locale or preferred calendar —
    /// they feed the SAME deterministic-id namespace.
    func testTheTwoDayKeyProducersAgreeByteForByte() {
        for date in probes {
            XCTAssertEqual(
                TodayStateService.dayKey(for: date),
                MedicationScheduleEngine.dayKey(for: date),
                "the dose-slot id namespace forked for \(date)"
            )
        }
    }

    /// The key is wire-and-id material: ASCII Gregorian, always.
    func testDayKeysAreASCIIGregorianEverywhere() {
        for date in probes {
            let key = TodayStateService.dayKey(for: date)
            XCTAssertTrue(key.allSatisfy { $0.isASCII },
                          "locale numerals leaked into an identity key: \(key)")
            XCTAssertEqual(key.count, 10)
            let year = Int(key.prefix(4)) ?? 0
            XCTAssertTrue((2020...2100).contains(year),
                          "a non-Gregorian era leaked into an identity key: \(key)")
        }
    }

    /// A pinned READER parses what the producer mints — the round trip
    /// that broke the packet's adherence loop when the vocabularies
    /// forked. The engine's own parser is the shipped Gregorian+POSIX
    /// reader shape shared by ObservationStore / VisitPacket /
    /// MedicationLog / the ledgers.
    func testThePinnedReadersParseTheProducersKeys() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        for date in probes {
            let key = TodayStateService.dayKey(for: date)
            let parsed = MedicationScheduleEngine.parseDayKey(key, calendar: cal)
            XCTAssertNotNil(parsed, "a pinned reader refused the producer's key \(key)")
            if let parsed {
                XCTAssertEqual(TodayStateService.dayKey(for: parsed), key,
                               "the round trip moved the day")
            }
        }
    }
}
