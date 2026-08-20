import XCTest
import SwiftData
import PlankSync
@testable import plankAI

// MARK: - AnsweringRegimenTests (app v25 pass 53 — THE ANSWERING RECORD)
//
// G1's closure: the schedule model must represent the regimens real
// customers are actually on — every N days (Scripps ran q2wk–q6wk
// under physician direction; ~15% of injectable users stretch or
// split), split dosing as two named weekdays (the guides' own
// canonical "5 mg monday + 5 mg thursday"; labels forbid two doses
// inside 48–72h, so SAME-day splits do not exist and the per-day
// deterministic id is safe), a treatment start that predates jeni,
// and a per-event dose word. PLAN and EVENT stay separate objects:
// the chain re-anchors on what HAPPENED (a taken dose counts N days
// from the day it was actually taken), which is what "every 5 days"
// means to the person saying it.
//
// RED before GREEN: these ran against the honest-BEFORE stubs (the
// shipped two-arm vocabulary, the G1 silence, the packet's
// "your weekly medication" for every self plan) and failed.

@MainActor
final class AnsweringRegimenTests: XCTestCase {

    // A fixed calendar so slot math is deterministic wherever CI runs.
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func intervalFacts(
        n: Int, anchor: String, startedAt: Date? = nil
    ) -> MedicationScheduleEngine.RegimenFacts {
        .init(
            scheduleRule: "intervalDays",
            intervalDays: n,
            anchorDayKey: anchor,
            startedAt: startedAt ?? day(2026, 8, 1)
        )
    }

    // MARK: interval — the due chain

    func testAFiveDayIntervalHasDoseDaysEveryFiveDays() {
        let facts = intervalFacts(n: 5, anchor: "2026-08-01")
        XCTAssertTrue(MedicationScheduleEngine.isDoseDay(
            day(2026, 8, 1), facts: facts, calendar: cal))
        XCTAssertTrue(MedicationScheduleEngine.isDoseDay(
            day(2026, 8, 6), facts: facts, calendar: cal))
        XCTAssertFalse(MedicationScheduleEngine.isDoseDay(
            day(2026, 8, 4), facts: facts, calendar: cal))
        XCTAssertTrue(MedicationScheduleEngine.isDoseDay(
            day(2026, 8, 11), facts: facts, calendar: cal))
    }

    func testALateTakeReanchorsTheIntervalChain() {
        // Due aug 6, actually taken aug 8 → the chain counts five
        // days from the REAL injection: next due aug 13, not aug 11.
        let facts = intervalFacts(n: 5, anchor: "2026-08-01")
        let events: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-08-01", status: "taken"),
            .init(dayKey: "2026-08-06", status: "taken", takenDayKey: "2026-08-08"),
        ]
        let dues = MedicationScheduleEngine.intervalDueDays(
            through: day(2026, 8, 20), facts: facts, events: events, calendar: cal
        ).map { MedicationScheduleEngine.dayKey(for: $0, calendar: cal) }
        XCTAssertEqual(dues, ["2026-08-01", "2026-08-06", "2026-08-13", "2026-08-18"])
        XCTAssertTrue(MedicationScheduleEngine.isDoseDay(
            day(2026, 8, 13), facts: facts, events: events, calendar: cal))
        XCTAssertFalse(MedicationScheduleEngine.isDoseDay(
            day(2026, 8, 11), facts: facts, events: events, calendar: cal))
    }

    func testAnUnresolvedIntervalSlotKeepsTheGridWhereItWas() {
        // Nothing recorded for aug 6 → the plan's grid walks on
        // (aug 11), exactly as a missed week keeps a weekly anchor.
        let facts = intervalFacts(n: 5, anchor: "2026-08-01")
        let events: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-08-01", status: "taken")
        ]
        let dues = MedicationScheduleEngine.intervalDueDays(
            through: day(2026, 8, 15), facts: facts, events: events, calendar: cal
        ).map { MedicationScheduleEngine.dayKey(for: $0, calendar: cal) }
        XCTAssertEqual(dues, ["2026-08-01", "2026-08-06", "2026-08-11"])
    }

    func testAnIntervalNextDoseIsTodayWhileTodayIsUnresolved() {
        let facts = intervalFacts(n: 5, anchor: "2026-08-01")
        let events: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-08-01", status: "taken")
        ]
        let next = MedicationScheduleEngine.nextDoseDate(
            after: day(2026, 8, 6, hour: 9), facts: facts, events: events, calendar: cal
        )
        XCTAssertNotNil(next)
        XCTAssertEqual(
            next.map { MedicationScheduleEngine.dayKey(for: $0, calendar: cal) },
            "2026-08-06"
        )
        // Resolved today → the next chain due, five days out.
        let resolved: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-08-01", status: "taken"),
            .init(dayKey: "2026-08-06", status: "taken"),
        ]
        let after = MedicationScheduleEngine.nextDoseDate(
            after: day(2026, 8, 6, hour: 20), facts: facts, events: resolved, calendar: cal
        )
        XCTAssertEqual(
            after.map { MedicationScheduleEngine.dayKey(for: $0, calendar: cal) },
            "2026-08-11"
        )
    }

    func testAnIntervalCyclePositionCountsFromTheLastRealShot() {
        let facts = intervalFacts(n: 5, anchor: "2026-08-01")
        let events: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-08-06", status: "taken", takenDayKey: "2026-08-08")
        ]
        let cycle = MedicationScheduleEngine.cyclePosition(
            now: day(2026, 8, 10), facts: facts, events: events, calendar: cal
        )
        XCTAssertEqual(cycle?.day, 3)
        XCTAssertEqual(cycle?.length, 5)
        XCTAssertEqual(cycle?.basis, .takenDose)
    }

    func testAnOpenPastIntervalSlotOutranksTheRhythm() {
        // Due aug 11, nothing recorded, today aug 13 → no fabricated
        // "day 3": the open slot is the honest state.
        let facts = intervalFacts(n: 5, anchor: "2026-08-01")
        let events: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-08-01", status: "taken"),
            .init(dayKey: "2026-08-06", status: "taken"),
        ]
        XCTAssertNil(MedicationScheduleEngine.cyclePosition(
            now: day(2026, 8, 13), facts: facts, events: events, calendar: cal
        ))
        let open = MedicationScheduleEngine.openLateSlot(
            now: day(2026, 8, 13), facts: facts, events: events, calendar: cal
        )
        XCTAssertEqual(
            open.map { MedicationScheduleEngine.dayKey(for: $0, calendar: cal) },
            "2026-08-11"
        )
    }

    func testAnIntervalSlotsLateWindowRunsToTheNextDue() {
        let facts = intervalFacts(n: 10, anchor: "2026-08-01")
        let end = MedicationScheduleEngine.lateWindowEnd(
            slotDay: day(2026, 8, 1), facts: facts, calendar: cal
        )
        XCTAssertEqual(
            MedicationScheduleEngine.dayKey(for: end, calendar: cal), "2026-08-11"
        )
    }

    func testAClosedUnrecordedIntervalSlotIsMissed() {
        let facts = intervalFacts(n: 5, anchor: "2026-08-01")
        let events: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-08-01", status: "taken")
        ]
        // aug 6 never recorded; its window closed aug 11; today aug 12.
        let missed = MedicationScheduleEngine.missedSlotDays(
            now: day(2026, 8, 12), facts: facts, events: events, calendar: cal
        ).map { MedicationScheduleEngine.dayKey(for: $0, calendar: cal) }
        XCTAssertEqual(missed, ["2026-08-06"])
    }

    func testSlotDaysListsTheIntervalChain() {
        let facts = intervalFacts(n: 5, anchor: "2026-08-01")
        let slots = MedicationScheduleEngine.slotDays(
            through: day(2026, 8, 15), lookbackDays: 30, facts: facts,
            events: [], calendar: cal
        ).map { MedicationScheduleEngine.dayKey(for: $0, calendar: cal) }
        XCTAssertEqual(slots, ["2026-08-01", "2026-08-06", "2026-08-11"])
    }

    // MARK: twice weekly — the split rhythm

    private var splitFacts: MedicationScheduleEngine.RegimenFacts {
        // monday + thursday — the guides' canonical split.
        .init(
            scheduleRule: "weeklyAnchor",
            anchorWeekday: 1,
            secondAnchorWeekday: 4,
            startedAt: day(2026, 8, 1)
        )
    }

    func testTwiceWeeklyHasBothDoseDays() {
        // aug 3 2026 = monday, aug 6 = thursday, aug 5 = wednesday.
        XCTAssertTrue(MedicationScheduleEngine.isDoseDay(
            day(2026, 8, 3), facts: splitFacts, calendar: cal))
        XCTAssertTrue(MedicationScheduleEngine.isDoseDay(
            day(2026, 8, 6), facts: splitFacts, calendar: cal))
        XCTAssertFalse(MedicationScheduleEngine.isDoseDay(
            day(2026, 8, 5), facts: splitFacts, calendar: cal))
    }

    func testTwiceWeeklyNextDoseIsTheNearerAnchor() {
        // From tuesday aug 4, the next dose is thursday aug 6.
        let next = MedicationScheduleEngine.nextDoseDate(
            after: day(2026, 8, 4), facts: splitFacts, events: [], calendar: cal
        )
        XCTAssertEqual(
            next.map { MedicationScheduleEngine.dayKey(for: $0, calendar: cal) },
            "2026-08-06"
        )
    }

    func testTwiceWeeklyLateWindowEndsAtTheOtherAnchor() {
        // Monday's slot stays markable until thursday (3 days);
        // thursday's until monday (4 days).
        let monEnd = MedicationScheduleEngine.lateWindowEnd(
            slotDay: day(2026, 8, 3), facts: splitFacts, calendar: cal
        )
        XCTAssertEqual(MedicationScheduleEngine.dayKey(for: monEnd, calendar: cal), "2026-08-06")
        let thuEnd = MedicationScheduleEngine.lateWindowEnd(
            slotDay: day(2026, 8, 6), facts: splitFacts, calendar: cal
        )
        XCTAssertEqual(MedicationScheduleEngine.dayKey(for: thuEnd, calendar: cal), "2026-08-10")
    }

    func testTwiceWeeklyRefusesACyclePosition() {
        // A split rhythm has no single-dose arc — the doses overlap
        // by design (that is the split's whole point). Fabricating
        // "day 3 of 7" would be fake precision; nil is the answer.
        let events: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-08-03", status: "taken")
        ]
        XCTAssertNil(MedicationScheduleEngine.cyclePosition(
            now: day(2026, 8, 5), facts: splitFacts, events: events, calendar: cal
        ))
    }

    func testASingleAnchorWeeklyCycleStillWorks() {
        // Control: the shipped weekly behavior is unchanged.
        let facts = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "weeklyAnchor", anchorWeekday: 2,
            startedAt: day(2026, 7, 1)
        )
        let events: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-08-04", status: "taken")   // tuesday
        ]
        let cycle = MedicationScheduleEngine.cyclePosition(
            now: day(2026, 8, 6), facts: facts, events: events, calendar: cal
        )
        XCTAssertEqual(cycle?.day, 3)
        XCTAssertEqual(cycle?.length, 7)
    }

    // MARK: the cycle band generalizes (7-day shape preserved exactly)

    func testTheSevenDayBandsAreUnchanged() {
        func band(_ d: Int) -> MedicationScheduleEngine.CyclePosition.Band {
            MedicationScheduleEngine.CyclePosition(
                day: d, length: 7, basis: .takenDose
            ).band
        }
        XCTAssertEqual(band(1), .landing)
        XCTAssertEqual(band(2), .landing)
        XCTAssertEqual(band(3), .steady)
        XCTAssertEqual(band(5), .steady)
        XCTAssertEqual(band(6), .waning)
        XCTAssertEqual(band(7), .waning)
    }

    func testAnIntervalBandScalesToItsOwnLength() {
        func band(_ d: Int, of n: Int) -> MedicationScheduleEngine.CyclePosition.Band {
            MedicationScheduleEngine.CyclePosition(
                day: d, length: n, basis: .takenDose
            ).band
        }
        // every 5: landing 1-2 · steady 3 · waning 4-5
        XCTAssertEqual(band(2, of: 5), .landing)
        XCTAssertEqual(band(3, of: 5), .steady)
        XCTAssertEqual(band(4, of: 5), .waning)
        // every 14: landing 1-4 · waning 11-14
        XCTAssertEqual(band(4, of: 14), .landing)
        XCTAssertEqual(band(7, of: 14), .steady)
        XCTAssertEqual(band(11, of: 14), .waning)
    }

    // MARK: cadence — one vocabulary authority

    func testTheCadenceWordTellsTheTruthForEveryRhythm() {
        func word(_ facts: MedicationScheduleEngine.RegimenFacts) -> String {
            MedicationScheduleEngine.cadenceWord(facts)
        }
        XCTAssertEqual(word(.init(
            scheduleRule: "weeklyAnchor", anchorWeekday: 2, startedAt: .now
        )), "weekly")
        XCTAssertEqual(word(.init(scheduleRule: "daily", startedAt: .now)), "daily")
        XCTAssertEqual(word(splitFacts), "twice a week")
        XCTAssertEqual(word(intervalFacts(n: 5, anchor: "2026-08-01")), "every 5 days")
        XCTAssertEqual(word(intervalFacts(n: 14, anchor: "2026-08-01")), "every 14 days")
        // The shipped vocabulary called an as-needed plan "weekly" —
        // an invented rhythm on a plan that refuses rhythms.
        XCTAssertEqual(word(.init(scheduleRule: "asNeeded", startedAt: .now)), "as needed")
    }

    // MARK: treatment tenure — jeni day is not treatment day

    func testTreatmentMonthsCountWholeCalendarMonths() {
        XCTAssertEqual(MedicationScheduleEngine.treatmentMonths(
            startedOn: "2026-03-10", now: day(2026, 8, 18), calendar: cal
        ), 5)
        XCTAssertEqual(MedicationScheduleEngine.treatmentMonths(
            startedOn: "2026-08-01", now: day(2026, 8, 18), calendar: cal
        ), 0)
        XCTAssertEqual(MedicationScheduleEngine.treatmentMonths(
            startedOn: "2024-08-18", now: day(2026, 8, 18), calendar: cal
        ), 24)
    }

    func testTenureRefusesGarbageAndAbsence() {
        XCTAssertNil(MedicationScheduleEngine.treatmentMonths(
            startedOn: nil, now: day(2026, 8, 18), calendar: cal))
        XCTAssertNil(MedicationScheduleEngine.treatmentMonths(
            startedOn: "soon", now: day(2026, 8, 18), calendar: cal))
        // A future date is not a tenure — refuse, never negative.
        XCTAssertNil(MedicationScheduleEngine.treatmentMonths(
            startedOn: "2027-01-01", now: day(2026, 8, 18), calendar: cal))
    }

    // MARK: the packet stops lying about the rhythm (G2)

    func testThePacketNamesADailyRegimenDaily() {
        let line = VisitPacketBuilder.regimenDisplayLine(
            managed: false, displayName: "rybelsus",
            strengthValue: nil, strengthUnit: nil,
            facts: .init(scheduleRule: "daily", route: "oral", startedAt: .now)
        )
        XCTAssertEqual(line, "your daily medication")
    }

    func testThePacketNamesAnIntervalRegimenByItsInterval() {
        let line = VisitPacketBuilder.regimenDisplayLine(
            managed: false, displayName: "compounded",
            strengthValue: nil, strengthUnit: nil,
            facts: intervalFacts(n: 10, anchor: "2026-08-01")
        )
        XCTAssertEqual(line, "your medication, every 10 days")
    }

    func testThePacketStillNamesAWeeklyRegimenWeekly() {
        // Control — the reviewed sentence survives for the rhythm it
        // was true for.
        let line = VisitPacketBuilder.regimenDisplayLine(
            managed: false, displayName: "ozempic",
            strengthValue: nil, strengthUnit: nil,
            facts: .init(scheduleRule: "weeklyAnchor", anchorWeekday: 2, startedAt: .now)
        )
        XCTAssertEqual(line, "your weekly medication")
    }

    func testThePacketCountsDailyScheduledDoses() {
        // A 28-day window of a daily regimen is 28 scheduled doses,
        // not zero (G2's denominator).
        let window = VisitPacketBuilder.window(now: day(2026, 8, 18))
        let plan = RegimenPlanRecord(
            userId: "u", kind: "medication", displayName: "rybelsus",
            scheduleRule: "daily", startedAt: day(2026, 1, 1), route: "oral"
        )
        let keys = VisitPacketBuilder.scheduledSlotKeys(
            window: window, plan: plan,
            facts: RegimenService.facts(for: plan), events: []
        )
        XCTAssertEqual(keys.count, VisitPacketBuilder.windowDays)
    }

    func testThePacketCountsIntervalScheduledDoses() {
        let window = VisitPacketBuilder.window(now: day(2026, 8, 18))
        let plan = RegimenPlanRecord(
            userId: "u", kind: "medication", displayName: "compounded",
            scheduleRule: "intervalDays", startedAt: day(2026, 6, 1)
        )
        plan.intervalDays = 10
        plan.anchorDayKey = "2026-07-25"
        let keys = VisitPacketBuilder.scheduledSlotKeys(
            window: window, plan: plan,
            facts: RegimenService.facts(for: plan), events: []
        )
        // Window jul 22 – aug 18 holds jul 25, aug 4, aug 14.
        XCTAssertEqual(keys, ["2026-07-25", "2026-08-04", "2026-08-14"])
    }

    // MARK: the spec round-trips the new facts through the chokepoint

    func testApplySelfRegimenCarriesIntervalAndTenure() throws {
        let context = ModelContext(TestModelContainer.shared)
        var spec = RegimenService.SelfRegimenSpec()
        spec.displayName = "compounded semaglutide"
        spec.scheduleRule = "intervalDays"
        spec.intervalDays = 5
        spec.anchorDayKey = "2026-08-20"
        let plan = RegimenService.applySelfRegimen(
            spec, userId: "p53-reg-1", in: context
        )
        XCTAssertEqual(plan?.scheduleRule, "intervalDays")
        XCTAssertEqual(plan?.intervalDays, 5)
        XCTAssertEqual(plan?.anchorDayKey, "2026-08-20")

        // The tenure fact is biographical, not a regimen version —
        // setting it mutates the active row and survives a later
        // version chain.
        RegimenService.setTreatmentStart(
            civilDay: "2026-02-01", userId: "p53-reg-1", in: context
        )
        XCTAssertEqual(
            RegimenService.activeMedicationPlan(userId: "p53-reg-1", in: context)?
                .treatmentStartedOn,
            "2026-02-01"
        )
        var change = spec
        change.intervalDays = 7
        let v2 = RegimenService.applySelfRegimen(
            change, userId: "p53-reg-1",
            now: .now.addingTimeInterval(86_400 * 2), in: context
        )
        XCTAssertEqual(v2?.treatmentStartedOn, "2026-02-01")
        XCTAssertEqual(v2?.intervalDays, 7)
    }

    func testAnIntervalChangeIsAScheduleChange() throws {
        // matchesFacts must SEE interval fields — otherwise a 5→7
        // day change silently matches and never versions.
        let context = ModelContext(TestModelContainer.shared)
        var spec = RegimenService.SelfRegimenSpec()
        spec.displayName = "x"
        spec.scheduleRule = "intervalDays"
        spec.intervalDays = 5
        spec.anchorDayKey = "2026-08-20"
        let v1 = RegimenService.applySelfRegimen(spec, userId: "p53-reg-2", in: context)
        XCTAssertNotNil(v1)
        var changed = spec
        changed.intervalDays = 7
        let v2 = RegimenService.applySelfRegimen(
            changed, userId: "p53-reg-2",
            now: .now.addingTimeInterval(86_400 * 3), in: context
        )
        // The change versioned: v2 chains back to v1, whose end
        // reason names the schedule.
        XCTAssertEqual(v2?.previousPlanId, v1?.id)
        XCTAssertEqual(v2?.intervalDays, 7)
        XCTAssertEqual(v1?.endReason, "schedule_changed")
    }

    // MARK: the event keeps her word for the dose

    func testADoseEventCarriesHerDoseWord() throws {
        let context = ModelContext(TestModelContainer.shared)
        let record = DoseEventStore.upsert(
            dayKey: "2026-08-10",
            scheduledAt: day(2026, 8, 10, hour: 18),
            status: "taken",
            doseLabel: "1.25",
            source: "sheet",
            userId: "p53-reg-3",
            regimenPlanId: "plan-1",
            in: context,
            sync: false
        )
        XCTAssertEqual(record?.doseLabel, "1.25")
        // Marking again without a label PRESERVES her word (the
        // checklist quick-mark never erases the sheet's detail).
        let again = DoseEventStore.upsert(
            dayKey: "2026-08-10",
            scheduledAt: day(2026, 8, 10, hour: 18),
            status: "taken",
            source: "checklist",
            userId: "p53-reg-3",
            regimenPlanId: "plan-1",
            in: context,
            sync: false
        )
        XCTAssertEqual(again?.doseLabel, "1.25")
    }

    func testAHistoricalShotCanBeBackfilled() throws {
        // Treatment began before jeni: a past taken event lands on
        // its own day, anchors the cycle, and never disturbs the
        // deterministic id shape.
        let context = ModelContext(TestModelContainer.shared)
        let record = DoseEventStore.upsert(
            dayKey: "2026-07-30",
            scheduledAt: day(2026, 7, 30, hour: 18),
            status: "taken",
            takenAt: day(2026, 7, 30, hour: 19),
            source: "backfill",
            userId: "p53-reg-4",
            regimenPlanId: "plan-1",
            in: context,
            sync: false
        )
        XCTAssertEqual(record?.id, "p53-reg-4-dose-2026-07-30")
        XCTAssertEqual(record?.status, "taken")
    }
}
