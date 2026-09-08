import XCTest
@testable import plankAI

/// Pass 82 — 1.1.8 final release hardening pins.
///
/// Each test protects a customer truth the pass's audit found broken:
/// the medication reminder family must die at every identity boundary
/// (a repeating "shot day" push survived account deletion); the master
/// toggle must mean OFF at the one gate every interruption passes
/// through; a resolved dose slot must not re-fire its own reminder;
/// the backfill door's "when" must default to the day she picked; the
/// chat consent sheet must name the cycle signal the envelope sends.
final class Pass82HardeningTests: XCTestCase {

    // MARK: - the identity boundary sweeps the medication family

    /// Deleting the account (or signing out, or losing the Apple
    /// credential) removes EVERY pending notification the identity
    /// earned — including the medication lane, whose weekly/daily
    /// reminders are REPEATING triggers that otherwise fire forever
    /// on this device under the next identity.
    @MainActor
    func testIdentityBoundarySweepCoversTheMedicationReminderFamily() {
        let boundary = Set(NotificationCensus.identityBoundaryIds)
        for id in MedicationReminders.allIds {
            XCTAssertTrue(
                boundary.contains(id),
                "medication reminder id '\(id)' is not in the identity-boundary sweep — it survives sign-out and account deletion"
            )
        }
        // The families the sweep already covered must stay covered.
        for id in NotificationOrchestrator.ladderIds
            + [NotificationOrchestrator.reSigningKnockId] {
            XCTAssertTrue(boundary.contains(id),
                          "identity-boundary census dropped '\(id)'")
        }
    }

    /// The census is only a law if the sweep actually reads it: the
    /// sign-out sweep must remove the identity-boundary ids by NAME
    /// of the census, not by a hand-copied list that can drift.
    func testTheSignOutSweepUsesTheIdentityBoundaryCensus() throws {
        let appSync = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PlankApp/Sync/AppSync.swift")
        guard let source = try? String(contentsOf: appSync, encoding: .utf8) else {
            throw XCTSkip("app sources not visible from this runner")
        }
        XCTAssertTrue(
            source.contains("NotificationCensus.identityBoundaryIds"),
            "AppSync's identity-boundary sweep does not read the census"
        )
    }

    // MARK: - master toggle means OFF at the gate

    /// p54's law, closed at the chokepoint: with the master toggle
    /// off, NOTHING passes the gate — not budgeted interruptions,
    /// not consented cadences. (The medication lane guards itself;
    /// everything else comes through here.)
    func testTheGateStandsDownWhenTheMasterToggleIsOff() {
        let d = UserDefaults(suiteName: "p82.gate.off")!
        d.removePersistentDomain(forName: "p82.gate.off")
        // notificationsEnabled unset reads false — the pre-grant state.
        XCTAssertFalse(
            NotificationGate.shouldSchedule(
                category: .support, id: "evening_plate_review", defaults: d
            ),
            "a support push passed the gate with the master toggle off"
        )
        XCTAssertFalse(
            NotificationGate.shouldSchedule(
                category: .morningRead, id: "anchor_d1", defaults: d
            ),
            "a consented cadence passed the gate with the master toggle off"
        )
    }

    func testTheGateAdmitsNormallyWhenTheMasterToggleIsOn() {
        let d = UserDefaults(suiteName: "p82.gate.on")!
        d.removePersistentDomain(forName: "p82.gate.on")
        d.set(true, forKey: "notificationsEnabled")
        XCTAssertTrue(
            NotificationGate.shouldSchedule(
                category: .support, id: "evening_plate_review", defaults: d
            ),
            "an in-budget support push was refused with the master toggle on"
        )
        XCTAssertTrue(
            NotificationGate.shouldSchedule(
                category: .morningRead, id: "anchor_d1", defaults: d
            ),
            "a consented cadence was refused with the master toggle on"
        )
    }

    // MARK: - a resolved slot never re-fires its own reminder

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 9) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    /// 2026-09-07 is a Monday. Weekly anchor monday (ISO 1), dose
    /// marked this morning: the standing reminder must become a
    /// ONE-SHOT at the NEXT anchor, not a repeating trigger that
    /// fires "mark it when it's taken" tonight about a dose already
    /// on the record.
    @MainActor
    func testAResolvedWeeklySlotDowngradesTheReminderToAOneShot() {
        let facts = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "weeklyAnchor", anchorWeekday: 1,
            startedAt: day(2026, 8, 3)
        )
        let resolved: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-09-07", status: "taken")
        ]
        let planned = MedicationReminders.plannedStandingRequests(
            facts: facts, events: resolved,
            isOral: false, emptyStomach: false,
            now: day(2026, 9, 7, hour: 10), calendar: cal
        )
        XCTAssertEqual(planned.count, 1)
        guard case .oneShot(let fireDate) = planned[0].trigger else {
            XCTFail("resolved weekly slot kept a repeating trigger: \(planned[0].trigger)")
            return
        }
        // The next monday, at her hour.
        XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: fireDate),
                       DateComponents(year: 2026, month: 9, day: 14))
    }

    /// Control: an UNRESOLVED weekly slot keeps the repeating
    /// trigger — the standing rhythm survives dormancy exactly as
    /// shipped.
    @MainActor
    func testAnUnresolvedWeeklySlotKeepsTheRepeatingTrigger() {
        let facts = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "weeklyAnchor", anchorWeekday: 1,
            startedAt: day(2026, 8, 3)
        )
        let planned = MedicationReminders.plannedStandingRequests(
            facts: facts, events: [],
            isOral: false, emptyStomach: false,
            now: day(2026, 9, 7, hour: 8), calendar: cal
        )
        XCTAssertEqual(planned.count, 1)
        guard case .repeatingWeekday = planned[0].trigger else {
            XCTFail("unresolved weekly slot lost its repeating trigger")
            return
        }
    }

    /// The daily pill, marked at breakfast, must not ping at her
    /// reminder hour tonight — one-shot at tomorrow's hour instead.
    @MainActor
    func testAResolvedDailySlotDowngradesTheReminderToAOneShot() {
        let facts = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "daily", startedAt: day(2026, 8, 3)
        )
        let resolved: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-09-07", status: "taken")
        ]
        let planned = MedicationReminders.plannedStandingRequests(
            facts: facts, events: resolved,
            isOral: true, emptyStomach: false,
            now: day(2026, 9, 7, hour: 8), calendar: cal
        )
        XCTAssertEqual(planned.count, 1)
        guard case .oneShot(let fireDate) = planned[0].trigger else {
            XCTFail("resolved daily slot kept a repeating trigger")
            return
        }
        XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: fireDate),
                       DateComponents(year: 2026, month: 9, day: 8))
    }

    /// Control: the interval one-shot behavior is unchanged (it was
    /// already event-anchored and resolved-today-aware).
    @MainActor
    func testTheIntervalOneShotBehaviorIsUnchanged() {
        let facts = MedicationScheduleEngine.RegimenFacts(
            scheduleRule: "intervalDays", intervalDays: 10,
            startedAt: day(2026, 8, 28)
        )
        let events: [MedicationScheduleEngine.SlotEvent] = [
            .init(dayKey: "2026-08-28", status: "taken")
        ]
        let planned = MedicationReminders.plannedStandingRequests(
            facts: facts, events: events,
            isOral: false, emptyStomach: false,
            now: day(2026, 9, 5, hour: 9), calendar: cal
        )
        XCTAssertEqual(planned.count, 1)
        guard case .oneShot(let fireDate) = planned[0].trigger else {
            XCTFail("interval reminder lost its one-shot shape")
            return
        }
        XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: fireDate),
                       DateComponents(year: 2026, month: 9, day: 7))
    }

    // MARK: - the backfill door's "when" is the day she picked

    /// "+ add a past shot" exists to record a PAST day; the sheet it
    /// opens must default the when-chip to that day, never to "took
    /// it just now" (which re-anchors the cycle and the interval
    /// chain to today).
    @MainActor
    func testTheBackfillDoorDefaultsTheWhenChipToTheSlotDay() {
        XCTAssertEqual(
            DoseSheet.defaultWhenTakenDay(
                backfill: true, slotDayKey: "2026-09-03"
            ),
            "2026-09-03",
            "the backfill door defaulted to 'took it just now'"
        )
        // The open-slot late face keeps its shipped default: nil =
        // "took it just now" (she may genuinely be taking it late).
        XCTAssertNil(
            DoseSheet.defaultWhenTakenDay(
                backfill: false, slotDayKey: "2026-09-06"
            )
        )
    }

    // MARK: - the chat consent sheet names what actually leaves

    /// The envelope carries the menstrual-cycle phase (the app's most
    /// carefully gated signal), her meals, and what jeni remembers.
    /// The sheet that asks permission must say so.
    func testTheChatConsentSheetNamesTheCycleMealsAndMemories() {
        let copy = ChatAIConsent.disclosureFacts.joined(separator: " ")
        XCTAssertTrue(copy.contains("cycle"),
                      "the consent sheet does not name the cycle signal the envelope sends")
        XCTAssertTrue(copy.contains("meal"),
                      "the consent sheet does not name the meal log the envelope sends")
        XCTAssertTrue(copy.contains("remember"),
                      "the consent sheet does not name jeni's memories")
    }
}
