import XCTest
import SwiftData
@testable import plankAI
import PlankSync

// APP v24 THE REGIMEN (docs/app_v24/00_REGIMEN.md) — the platform's
// pure laws: the catalog is data, the schedule engine speaks wall
// clock, rotation suggests, the version chain never overwrites
// history, and dose events converge on deterministic ids.

final class MedicationPlatformTests: XCTestCase {

    private func date(_ iso: String, _ time: String = "12:00") -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: "\(iso) \(time)")!
    }

    // MARK: - Catalog

    func testCatalogCoversTheBrief() {
        for id in ["ozempic", "wegovy", "mounjaro", "zepbound", "rybelsus",
                   "compounded-semaglutide", "compounded-tirzepatide"] {
            XCTAssertNotNil(MedicationCatalog.product(id: id), id)
        }
        XCTAssertEqual(MedicationCatalog.product(id: "rybelsus")?.route, .oral)
        XCTAssertEqual(MedicationCatalog.product(id: "rybelsus")?.defaultCadence, .daily)
        XCTAssertTrue(MedicationCatalog.product(id: "rybelsus")?.emptyStomach ?? false)
        // Saxenda proves the daily-injection composition exists.
        XCTAssertEqual(MedicationCatalog.product(id: "saxenda")?.defaultCadence, .daily)
        XCTAssertEqual(MedicationCatalog.product(id: "saxenda")?.route, .injection)
        // Ladders ascend.
        for product in MedicationCatalog.products {
            XCTAssertEqual(product.doseLadder, product.doseLadder.sorted(), product.id)
        }
    }

    func testRouteFilterAndRenderName() {
        XCTAssertTrue(MedicationCatalog.products(route: .oral).contains { $0.id == "rybelsus" })
        XCTAssertFalse(MedicationCatalog.products(route: .oral).contains { $0.id == "ozempic" })
        XCTAssertEqual(
            MedicationCatalog.renderName(productId: "zepbound", displayName: ""), "zepbound"
        )
        XCTAssertEqual(
            MedicationCatalog.renderName(productId: nil, displayName: "My Vial"), "my vial"
        )
        XCTAssertEqual(
            MedicationCatalog.renderName(productId: nil, displayName: "  "), "your medication"
        )
    }

    func testDoseWordTrimsHonestly() {
        XCTAssertEqual(MedicationProduct.doseWord(0.25), "0.25")
        XCTAssertEqual(MedicationProduct.doseWord(1.0), "1")
        XCTAssertEqual(MedicationProduct.doseWord(2.5), "2.5")
        XCTAssertEqual(MedicationProduct.doseWord(15), "15")
    }

    // MARK: - Rotation

    func testRotationSuggestsMirrorFirst() {
        XCTAssertEqual(SiteRotationAdvisor.suggestion(recent: []), .leftAbdomen)
        XCTAssertEqual(
            SiteRotationAdvisor.suggestion(recent: [.leftAbdomen]), .rightAbdomen
        )
        XCTAssertEqual(
            SiteRotationAdvisor.suggestion(recent: [.rightThigh, .leftAbdomen]), .leftThigh
        )
    }

    func testRotationFallsToLeastRecentlyUsed() {
        // Mirror (right abdomen) was used within the last two —
        // the advisor reaches for a never-used site instead.
        let recent: [InjectionSite] = [.leftAbdomen, .rightAbdomen]
        XCTAssertEqual(SiteRotationAdvisor.suggestion(recent: recent), .leftThigh)

        // All six used: the deepest (least recent) wins.
        let all: [InjectionSite] = [
            .leftAbdomen, .rightAbdomen, .leftThigh, .rightThigh, .leftArm, .rightArm
        ]
        XCTAssertEqual(SiteRotationAdvisor.suggestion(recent: all), .rightArm)
    }

    func testRotationLineSpeaksOnlyWithHistory() {
        XCTAssertNil(SiteRotationAdvisor.line(recent: [], suggested: .leftAbdomen))
        let line = SiteRotationAdvisor.line(
            recent: [.leftThigh], suggested: .rightThigh
        )
        XCTAssertEqual(line, "left thigh last time — the right side keeps the rotation.")
    }

    // MARK: - Schedule engine

    private var weeklyTuesday: MedicationScheduleEngine.RegimenFacts {
        .init(
            scheduleRule: "weeklyAnchor",
            anchorWeekday: 2,                    // Tuesday
            timeOfDayMinutes: 18 * 60,
            route: "injection",
            startedAt: date("2026-06-02", "09:00")
        )
    }

    private var dailyOral: MedicationScheduleEngine.RegimenFacts {
        .init(
            scheduleRule: "daily",
            anchorWeekday: nil,
            timeOfDayMinutes: nil,               // falls to 08:00 oral default
            route: "oral",
            startedAt: date("2026-08-01", "07:00")
        )
    }

    func testIsDoseDayRules() {
        // 2026-08-04 is a Tuesday; 08-05 a Wednesday.
        XCTAssertTrue(MedicationScheduleEngine.isDoseDay(date("2026-08-04"), facts: weeklyTuesday))
        XCTAssertFalse(MedicationScheduleEngine.isDoseDay(date("2026-08-05"), facts: weeklyTuesday))
        // Before the regimen started: never a dose day.
        XCTAssertFalse(MedicationScheduleEngine.isDoseDay(date("2026-05-26"), facts: weeklyTuesday))
        // Daily: every day from start.
        XCTAssertTrue(MedicationScheduleEngine.isDoseDay(date("2026-08-09"), facts: dailyOral))
        XCTAssertFalse(MedicationScheduleEngine.isDoseDay(date("2026-07-31"), facts: dailyOral))
    }

    func testResolvedMinutesDefaults() {
        XCTAssertEqual(weeklyTuesday.resolvedMinutes, 18 * 60)
        XCTAssertEqual(dailyOral.resolvedMinutes, 8 * 60)
        var injectionNoTime = weeklyTuesday
        injectionNoTime.timeOfDayMinutes = nil
        XCTAssertEqual(injectionNoTime.resolvedMinutes, 18 * 60)
    }

    func testNextDoseDateHonorsTheOpenSlot() {
        // Tuesday morning, unresolved → today at 18:00.
        let tuesdayMorning = date("2026-08-04", "09:00")
        XCTAssertEqual(
            MedicationScheduleEngine.nextDoseDate(after: tuesdayMorning, facts: weeklyTuesday),
            date("2026-08-04", "18:00")
        )
        // Tuesday LATE evening, still unresolved → still today (due
        // all day; it never expires at her reminder hour).
        let tuesdayNight = date("2026-08-04", "23:00")
        XCTAssertEqual(
            MedicationScheduleEngine.nextDoseDate(after: tuesdayNight, facts: weeklyTuesday),
            date("2026-08-04", "18:00")
        )
        // Tuesday resolved → next Tuesday.
        let taken = [MedicationScheduleEngine.SlotEvent(dayKey: "2026-08-04", status: "taken")]
        XCTAssertEqual(
            MedicationScheduleEngine.nextDoseDate(
                after: tuesdayNight, facts: weeklyTuesday, events: taken
            ),
            date("2026-08-11", "18:00")
        )
        // Wednesday → next Tuesday.
        XCTAssertEqual(
            MedicationScheduleEngine.nextDoseDate(after: date("2026-08-05"), facts: weeklyTuesday),
            date("2026-08-11", "18:00")
        )
    }

    func testSlotDaysClampToStart() {
        let slots = MedicationScheduleEngine.slotDays(
            through: date("2026-06-16"), lookbackDays: 30, facts: weeklyTuesday
        )
        // Regimen started Tue 06-02: slots are 06-02, 06-09, 06-16.
        XCTAssertEqual(
            slots.map { MedicationScheduleEngine.dayKey(for: $0) },
            ["2026-06-02", "2026-06-09", "2026-06-16"]
        )
    }

    func testLateWindowAndOpenSlot() {
        // Weekly slot stays open until the next slot is due.
        let slotDay = date("2026-08-04")
        let windowEnd = MedicationScheduleEngine.lateWindowEnd(
            slotDay: slotDay, facts: weeklyTuesday
        )
        XCTAssertEqual(
            MedicationScheduleEngine.dayKey(for: windowEnd), "2026-08-11"
        )
        // Thursday after a missed Tuesday: the slot is open late.
        let thursday = date("2026-08-06", "10:00")
        let open = MedicationScheduleEngine.openLateSlot(
            now: thursday, facts: weeklyTuesday, events: []
        )
        XCTAssertEqual(open.map { MedicationScheduleEngine.dayKey(for: $0) }, "2026-08-04")
        // Once resolved, nothing is open.
        let skipped = [MedicationScheduleEngine.SlotEvent(dayKey: "2026-08-04", status: "skipped")]
        XCTAssertNil(MedicationScheduleEngine.openLateSlot(
            now: thursday, facts: weeklyTuesday, events: skipped
        ))
        // Daily pills close at end of day — yesterday is open?
        // No: a daily slot's window ends at midnight; it is missed,
        // not open.
        let friday = date("2026-08-07", "09:00")
        XCTAssertNil(MedicationScheduleEngine.openLateSlot(
            now: friday, facts: dailyOral, events: []
        ))
    }

    func testMissedDerivation() {
        // Two Tuesdays passed unrecorded; the third is still open.
        let now = date("2026-08-19", "12:00")   // a Wednesday
        let missed = MedicationScheduleEngine.missedSlotDays(
            now: now, facts: weeklyTuesday,
            events: [.init(dayKey: "2026-08-04", status: "taken")],
            lookbackDays: 21
        )
        XCTAssertEqual(
            missed.map { MedicationScheduleEngine.dayKey(for: $0) },
            ["2026-08-11"]   // 08-18 is inside its late window, not missed
        )
    }

    func testWallClockSurvivesTimezoneMath() {
        // The same facts read in Seoul: Tuesday is Tuesday, her
        // hour is her hour — wall clock, not epoch.
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let f = DateFormatter()
        f.calendar = seoul
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = seoul.timeZone
        f.dateFormat = "yyyy-MM-dd HH:mm"
        let seoulTuesday = f.date(from: "2026-08-04 09:00")!
        XCTAssertTrue(MedicationScheduleEngine.isDoseDay(
            seoulTuesday, facts: weeklyTuesday, calendar: seoul
        ))
        let next = MedicationScheduleEngine.nextDoseDate(
            after: seoulTuesday, facts: weeklyTuesday, calendar: seoul
        )
        XCTAssertEqual(next, f.date(from: "2026-08-04 18:00")!)
    }

    func testDSTTransitionKeepsTheHour() {
        // US DST ends 2026-11-01 (NY). Her Sunday-9am slot before
        // and after the transition still reads 09:00 wall clock.
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        let facts = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "weeklyAnchor",
            anchorWeekday: 7,                     // Sunday
            timeOfDayMinutes: 9 * 60,
            route: "injection",
            startedAt: Date(timeIntervalSince1970: 1_760_000_000)  // 2025-10 — before
        )
        let f = DateFormatter()
        f.calendar = ny
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = ny.timeZone
        f.dateFormat = "yyyy-MM-dd HH:mm"
        let beforeDST = f.date(from: "2026-10-30 12:00")!   // Friday before
        let next = MedicationScheduleEngine.nextDoseDate(
            after: beforeDST, facts: facts, calendar: ny
        )
        XCTAssertEqual(next, f.date(from: "2026-11-01 09:00")!)
        let afterDST = f.date(from: "2026-11-02 12:00")!    // Monday after
        let following = MedicationScheduleEngine.nextDoseDate(
            after: afterDST, facts: facts, calendar: ny
        )
        XCTAssertEqual(following, f.date(from: "2026-11-08 09:00")!)
    }

    // MARK: - Pattern engine (pure)

    private func patternInputs(
        doseDays: [String], changes: [String] = [],
        symptoms: [(String, String)] = [], protein: [String: Int] = [:],
        today: String
    ) -> MedicationPatternEngine.Inputs {
        var inputs = MedicationPatternEngine.Inputs(today: today)
        inputs.takenDoseDays = doseDays
        inputs.doseChangeDays = changes
        inputs.symptoms = symptoms.map { .init($0.0, $0.1) }
        inputs.proteinByDay = protein
        return inputs
    }

    func testPatternsStaySilentBelowFloors() {
        // Two co-occurrences never speak.
        let quiet = MedicationPatternEngine.observations(patternInputs(
            doseDays: ["2026-07-28", "2026-08-04"],
            symptoms: [("2026-07-29", "nausea"), ("2026-08-05", "nausea")],
            today: "2026-08-09"
        ))
        XCTAssertTrue(quiet.isEmpty)
        XCTAssertNil(MedicationPatternEngine.adherenceLine(taken: 2, resolved: 2))
    }

    func testAfterDoseDayPatternSpeaksTiming() {
        let observations = MedicationPatternEngine.observations(patternInputs(
            doseDays: ["2026-07-21", "2026-07-28", "2026-08-04"],
            symptoms: [
                ("2026-07-22", "nausea"), ("2026-07-29", "nausea"),
                ("2026-08-05", "nausea"), ("2026-07-25", "headache"),
            ],
            today: "2026-08-09"
        ))
        let sentence = try? XCTUnwrap(observations.first?.sentence)
        XCTAssertTrue(sentence?.contains("followed") ?? false)
        XCTAssertFalse(sentence?.contains("because") ?? true, "timing, never causality")
    }

    func testAfterDoseChangeIsTheLeadObservation() {
        // Change 10 days ago; two queasy entries after, none before.
        let observations = MedicationPatternEngine.observations(patternInputs(
            doseDays: ["2026-07-14", "2026-07-21", "2026-07-28", "2026-08-04"],
            changes: ["2026-07-30"],
            symptoms: [("2026-08-01", "nausea"), ("2026-08-05", "nausea")],
            today: "2026-08-09"
        ))
        XCTAssertEqual(observations.first?.id, "after-change-nausea")
        XCTAssertTrue(observations.first?.sentence.contains("after the dose changed") ?? false)
    }

    func testProteinDayAfterDip() {
        let observations = MedicationPatternEngine.observations(patternInputs(
            doseDays: ["2026-07-21", "2026-07-28", "2026-08-04"],
            protein: [
                "2026-07-22": 60, "2026-07-29": 55, "2026-08-05": 58,   // day-afters
                "2026-07-24": 95, "2026-07-31": 100, "2026-08-02": 90,  // baseline
            ],
            today: "2026-08-09"
        ))
        XCTAssertTrue(observations.contains { $0.id == "protein-day-after" })
    }

    func testAdherenceLineSpeaksPlainly() {
        XCTAssertEqual(
            MedicationPatternEngine.adherenceLine(taken: 9, resolved: 10),
            "9 of your last 10 doses, marked."
        )
    }

    // MARK: - Onboarding bridge (pure)

    func testBridgeBuildsNothingFromAllSkips() {
        XCTAssertNil(MedicationOnboardingBridge.spec(from: .init()))
        XCTAssertNil(MedicationOnboardingBridge.spec(from: .init(
            route: "not_sure", product: "not_sure", dose: "not_sure"
        )))
    }

    func testBridgeBuildsTheFullWeeklySpec() throws {
        let spec = try XCTUnwrap(MedicationOnboardingBridge.spec(from: .init(
            route: "shots", product: "ozempic", dose: "0.5",
            shotDayWord: "tue", hour: "evening"
        )))
        XCTAssertEqual(spec.productId, "ozempic")
        XCTAssertEqual(spec.route, "injection")
        XCTAssertEqual(spec.scheduleRule, "weeklyAnchor")
        XCTAssertEqual(spec.anchorWeekday, 2)
        XCTAssertEqual(spec.timeOfDayMinutes, 18 * 60)
        XCTAssertEqual(spec.doseValue, 0.5)
        XCTAssertTrue(spec.reminderEnabled)
    }

    func testBridgeBuildsTheDailyOralSpec() throws {
        let spec = try XCTUnwrap(MedicationOnboardingBridge.spec(from: .init(
            route: "pills", product: "rybelsus", dose: "7", hour: "morning"
        )))
        XCTAssertEqual(spec.route, "oral")
        XCTAssertEqual(spec.scheduleRule, "daily")
        XCTAssertNil(spec.anchorWeekday, "daily cadence carries no weekday")
        XCTAssertEqual(spec.timeOfDayMinutes, 8 * 60)
        XCTAssertEqual(spec.doseValue, 7)
    }

    func testBridgeHonorsAnExplicitQuietChoice() throws {
        // "no reminders, please" alone is still a concrete regimen
        // decision — reminders off, defaults everywhere else.
        let spec = try XCTUnwrap(MedicationOnboardingBridge.spec(from: .init(
            route: "shots", hour: "none"
        )))
        XCTAssertFalse(spec.reminderEnabled)
        XCTAssertNil(spec.timeOfDayMinutes)
        XCTAssertEqual(spec.scheduleRule, "weeklyAnchor")
    }

    func testBridgeDailyInjectableSkipsWeekday() throws {
        let spec = try XCTUnwrap(MedicationOnboardingBridge.spec(from: .init(
            route: "shots", product: "saxenda", dose: "1.2",
            shotDayWord: "tue", hour: "morning"
        )))
        XCTAssertEqual(spec.scheduleRule, "daily")
        XCTAssertNil(spec.anchorWeekday)
        XCTAssertEqual(spec.route, "injection")
    }

    // MARK: - Version chain (SwiftData)

    @MainActor
    func testVersionChainNeverOverwritesHistory() throws {
        let context = TestModelContainer.shared.mainContext
        let userId = "v24-chain-\(UUID().uuidString)"

        // Version 1: onboarding writes ozempic 0.25, Tuesdays 18:00.
        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = "ozempic"
        spec.displayName = "ozempic"
        spec.route = "injection"
        spec.scheduleRule = "weeklyAnchor"
        spec.anchorWeekday = 2
        spec.timeOfDayMinutes = 18 * 60
        spec.doseValue = 0.25
        spec.reminderEnabled = true
        let v1 = RegimenService.applySelfRegimen(
            spec, userId: userId, now: date("2026-08-01"), in: context
        )
        XCTAssertNotNil(v1)
        XCTAssertEqual(v1?.strengthValue, 0.25)
        XCTAssertEqual(v1?.strengthUnit, "mg")

        // Same spec again → NO new row.
        _ = RegimenService.applySelfRegimen(
            spec, userId: userId, now: date("2026-08-02"), in: context
        )
        XCTAssertEqual(RegimenService.medicationHistory(userId: userId, in: context).count, 1)

        // Reminder toggle → in place, still one row.
        spec.reminderEnabled = false
        _ = RegimenService.applySelfRegimen(
            spec, userId: userId, now: date("2026-08-02"), in: context
        )
        let afterToggle = RegimenService.medicationHistory(userId: userId, in: context)
        XCTAssertEqual(afterToggle.count, 1)
        XCTAssertEqual(afterToggle.first?.reminderEnabled, false)

        // A dose change on a LATER day → a settled version.
        spec.doseValue = 0.5
        let v2 = RegimenService.applySelfRegimen(
            spec, userId: userId, now: date("2026-09-06"), in: context
        )
        let history = RegimenService.medicationHistory(userId: userId, in: context)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(v2?.strengthValue, 0.5)
        XCTAssertEqual(v2?.previousPlanId, v1?.id)
        let ended = history.first { $0.id == v1?.id }
        XCTAssertNotNil(ended?.endedAt)
        XCTAssertEqual(ended?.endReason, "dose_changed")
        XCTAssertEqual(ended?.strengthValue, 0.25, "history is never rewritten")
        // Dose change restarts the titration clock.
        XCTAssertEqual(
            MedicationScheduleEngine.dayKey(for: v2!.startedAt), "2026-09-06"
        )

        // A schedule-only change inherits startedAt (titration
        // continuity).
        spec.anchorWeekday = 6
        let v3 = RegimenService.applySelfRegimen(
            spec, userId: userId, now: date("2026-09-20"), in: context
        )
        XCTAssertEqual(v3?.endReason, nil)
        XCTAssertEqual(
            MedicationScheduleEngine.dayKey(for: v3!.startedAt), "2026-09-06"
        )
        XCTAssertEqual(
            RegimenService.medicationHistory(userId: userId, in: context).count, 3
        )

        // Ending records the reason; the chain survives.
        RegimenService.endMedicationPlan(userId: userId, reason: "paused", in: context)
        XCTAssertNil(RegimenService.activeMedicationPlan(userId: userId, in: context))
        XCTAssertEqual(
            RegimenService.medicationHistory(userId: userId, in: context)
                .first?.endReason, "paused"
        )
    }

    @MainActor
    func testSameDayCoalesceAbsorbsCorrections() throws {
        let context = TestModelContainer.shared.mainContext
        let userId = "v24-coalesce-\(UUID().uuidString)"
        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = "wegovy"
        spec.doseValue = 0.25
        spec.anchorWeekday = 3
        let noon = date("2026-08-09", "12:00")
        _ = RegimenService.applySelfRegimen(spec, userId: userId, now: noon, in: context)
        // Minutes later she fixes the dose — same day, same row.
        spec.doseValue = 0.5
        let corrected = RegimenService.applySelfRegimen(
            spec, userId: userId, now: date("2026-08-09", "12:04"), in: context
        )
        XCTAssertEqual(RegimenService.medicationHistory(userId: userId, in: context).count, 1)
        XCTAssertEqual(corrected?.strengthValue, 0.5)
        XCTAssertNil(corrected?.previousPlanId)
    }

    @MainActor
    func testCareTeamBlocksSelfWrites() throws {
        let context = TestModelContainer.shared.mainContext
        let userId = "v24-careteam-\(UUID().uuidString)"
        let carePlan = RegimenPlanRecord(
            userId: userId, kind: "medication",
            displayName: "Wegovy", scheduleRule: "weeklyAnchor",
            anchorWeekday: 4
        )
        carePlan.authority = "care_team"
        context.insert(carePlan)
        try context.save()

        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = "ozempic"
        XCTAssertNil(RegimenService.applySelfRegimen(spec, userId: userId, in: context))
        XCTAssertEqual(
            RegimenService.setShotDay(2, userId: userId, in: context)?.id, carePlan.id,
            "setShotDay returns the clinician plan unchanged"
        )
        XCTAssertEqual(RegimenService.medicationHistory(userId: userId, in: context).count, 1)
    }

    // MARK: - Dose events (SwiftData)

    @MainActor
    func testDoseEventsConvergeOnDeterministicIds() throws {
        let context = TestModelContainer.shared.mainContext
        let userId = "v24-dose-\(UUID().uuidString)"
        let dayKey = "2026-08-04"
        let slot = date("2026-08-04", "18:00")

        // Checklist quick-mark first (no site).
        _ = DoseEventStore.upsert(
            dayKey: dayKey, scheduledAt: slot, status: "taken",
            takenAt: date("2026-08-04", "18:10"),
            source: "checklist", userId: userId, regimenPlanId: "r1",
            in: context, sync: false
        )
        // The sheet enriches with site + note — SAME row.
        _ = DoseEventStore.upsert(
            dayKey: dayKey, scheduledAt: slot, status: "taken",
            site: .leftThigh, note: "stung a little",
            source: "sheet", userId: userId, regimenPlanId: "r1",
            in: context, sync: false
        )
        let events = DoseEventStore.events(userId: userId, in: context)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.site, "left_thigh")
        XCTAssertEqual(events.first?.note, "stung a little")
        XCTAssertNotNil(events.first?.takenAt, "checklist takenAt preserved")

        // Unmark deletes the row (a correction, not history).
        DoseEventStore.delete(dayKey: dayKey, userId: userId, in: context)
        XCTAssertTrue(DoseEventStore.events(userId: userId, in: context).isEmpty)
    }

    @MainActor
    func testMissedStampingIsReversible() throws {
        let context = TestModelContainer.shared.mainContext
        let userId = "v24-missed-\(UUID().uuidString)"
        let facts = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "weeklyAnchor", anchorWeekday: 2,
            timeOfDayMinutes: 18 * 60, route: "injection",
            startedAt: date("2026-07-07")
        )
        // Two Tuesdays whose windows closed: 07-28, 08-04 (now 08-12).
        DoseEventStore.stampMissedIfNeeded(
            userId: userId, facts: facts, regimenPlanId: "r1",
            now: date("2026-08-12"), in: context
        )
        let stamped = DoseEventStore.events(userId: userId, in: context)
        XCTAssertTrue(stamped.count >= 2)
        XCTAssertTrue(stamped.allSatisfy { $0.status == "missed" })

        // She logs 08-04 late → the same row flips to taken.
        _ = DoseEventStore.upsert(
            dayKey: "2026-08-04", scheduledAt: date("2026-08-04", "18:00"),
            status: "taken", takenAt: date("2026-08-12", "09:00"),
            source: "sheet", userId: userId, regimenPlanId: "r1",
            in: context, sync: false
        )
        let after = DoseEventStore.event(dayKey: "2026-08-04", userId: userId, in: context)
        XCTAssertEqual(after?.status, "taken")
        XCTAssertNotNil(after?.takenAt)
        // Re-stamping never resurrects it.
        DoseEventStore.stampMissedIfNeeded(
            userId: userId, facts: facts, regimenPlanId: "r1",
            now: date("2026-08-13"), in: context
        )
        XCTAssertEqual(
            DoseEventStore.event(dayKey: "2026-08-04", userId: userId, in: context)?.status,
            "taken"
        )
    }

    @MainActor
    func testRecentSitesFeedRotation() throws {
        let context = TestModelContainer.shared.mainContext
        let userId = "v24-sites-\(UUID().uuidString)"
        for (i, site) in [InjectionSite.leftAbdomen, .rightAbdomen].enumerated() {
            _ = DoseEventStore.upsert(
                dayKey: "2026-07-0\(i + 1)", scheduledAt: date("2026-07-0\(i + 1)", "18:00"),
                status: "taken", takenAt: date("2026-07-0\(i + 1)", "18:00"),
                site: site, source: "sheet", userId: userId, regimenPlanId: "r1",
                in: context, sync: false
            )
        }
        // Skipped days never contribute sites.
        _ = DoseEventStore.upsert(
            dayKey: "2026-07-03", scheduledAt: date("2026-07-03", "18:00"),
            status: "skipped", skipReason: "traveling",
            source: "sheet", userId: userId, regimenPlanId: "r1",
            in: context, sync: false
        )
        let recent = DoseEventStore.recentSites(userId: userId, in: context)
        XCTAssertEqual(recent, [.rightAbdomen, .leftAbdomen])
        XCTAssertEqual(SiteRotationAdvisor.suggestion(recent: recent), .leftThigh)
    }
}
