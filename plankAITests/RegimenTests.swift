import XCTest
@testable import plankAI

// Regimen (app v8, docs/app_v8/03_ARCHITECTURE.md §3c) — the
// shot-day anchor's date math and the dose-day composition laws:
// medication leads dose days, the keystone demotes to supporting,
// a gentle dose day composes to the dose alone, hydration rides
// the titration window as an invitation, and the ask caps hold.

final class RegimenTests: XCTestCase {

    // MARK: - Date math

    private func date(_ iso: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: iso)!
    }

    func testIsoWeekdayMapping() {
        // 2026-07-27 is a Monday; 2026-08-02 is a Sunday.
        XCTAssertEqual(RegimenService.isoWeekday(date("2026-07-27")), 1)
        XCTAssertEqual(RegimenService.isoWeekday(date("2026-07-30")), 4)
        XCTAssertEqual(RegimenService.isoWeekday(date("2026-08-02")), 7)
    }

    func testDoseDayDetection() {
        XCTAssertTrue(RegimenService.isDoseDay(date("2026-08-02"), anchorWeekday: 7))
        XCTAssertFalse(RegimenService.isDoseDay(date("2026-08-01"), anchorWeekday: 7))
        XCTAssertFalse(RegimenService.isDoseDay(date("2026-08-02"), anchorWeekday: nil))
    }

    func testDayInMedicationWeekWraps() {
        // Anchor Sunday (7): Monday is day 1 after, Saturday day 6.
        XCTAssertEqual(
            RegimenService.dayInMedicationWeek(date("2026-08-02"), anchorWeekday: 7), 0
        )
        XCTAssertEqual(
            RegimenService.dayInMedicationWeek(date("2026-07-27"), anchorWeekday: 7), 1
        )
        XCTAssertEqual(
            RegimenService.dayInMedicationWeek(date("2026-08-01"), anchorWeekday: 7), 6
        )
        XCTAssertNil(RegimenService.dayInMedicationWeek(date("2026-08-01"), anchorWeekday: nil))
    }

    func testTitrationWindowBoundaries() {
        let start = date("2026-06-01")
        XCTAssertTrue(RegimenService.titrationWindowActive(
            date("2026-06-01"), startedAt: start
        ))
        // Day 55 of an 8-week (56-day) window is inside; day 56 is out.
        XCTAssertTrue(RegimenService.titrationWindowActive(
            date("2026-07-25"), startedAt: start
        ))
        XCTAssertFalse(RegimenService.titrationWindowActive(
            date("2026-07-27"), startedAt: start
        ))
        XCTAssertFalse(RegimenService.titrationWindowActive(
            date("2026-06-01"), startedAt: nil
        ))
    }

    // MARK: - Dose-day composition

    private func day(beats: [ProgramDayPrescription]) -> PrescriptionEngineV2.Day {
        PrescriptionEngineV2.Day(
            archetype: .protein, beats: beats,
            weighInIsStaleFallback: false, programDay: 12
        )
    }

    private let fullBeats: [ProgramDayPrescription] = [
        .snapMeal,
        .workout(tier: .medium, minutes: 10, bodyFocus: nil),
        .lesson(lessonId: nil),
        .steps(goal: 7_500),
        .weighIn,
    ]

    func testDoseDayLeadsWithMedication() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats), isDoseDay: true
        ))
        guard case .medication = plan.lead?.beat else {
            return XCTFail("expected the medication lead")
        }
        XCTAssertNotNil(plan.lead?.because)
        // The keystone the prescription led with demotes to the
        // first supporting row (med + one keystone stay the plan).
        guard case .snapMeal = plan.supporting.first?.beat else {
            return XCTFail("expected the demoted keystone as supporting")
        }
        XCTAssertLessThanOrEqual(plan.actionableBeats.count, 3)
    }

    func testNonDoseDayComposesNoMedication() {
        let plan = CarePlanEngine.compose(.init(day: day(beats: fullBeats)))
        let all = plan.actionableBeats + plan.offered.map(\.beat)
        XCTAssertFalse(all.contains { beat in
            if case .medication = beat { return true } else { return false }
        })
    }

    func testGentleDoseDayIsTheDoseAlone() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            yesterdayFeeling: "tender",
            isDoseDay: true
        ))
        XCTAssertEqual(plan.tone, .gentle)
        guard case .medication = plan.lead?.beat else {
            return XCTFail("expected the medication lead on a gentle dose day")
        }
        XCTAssertTrue(plan.supporting.isEmpty)
        XCTAssertTrue(plan.offered.isEmpty)
        XCTAssertEqual(plan.actionableBeats.count, 1)
    }

    func testTitrationWindowOffersHydrationFirst() {
        let plan = CarePlanEngine.compose(.init(
            day: day(beats: fullBeats),
            titrationWindowActive: true
        ))
        guard case .water = plan.offered.first?.beat else {
            return XCTFail("expected hydration to lead the invitations")
        }
        XCTAssertNotNil(plan.offered.first?.because)
        // Invitations stay capped; hydration is never counted.
        XCTAssertLessThanOrEqual(plan.offered.count, 2)
        XCTAssertFalse(plan.actionableBeats.contains { beat in
            if case .water = beat { return true } else { return false }
        })
    }

    func testDoseDayCanBeConfiguredOffLead() {
        var p = CareProtocol.default
        p.regimen.doseDayLeads = false
        let plan = CarePlanEngine.compose(
            .init(day: day(beats: fullBeats), isDoseDay: true),
            careProtocol: p
        )
        if case .medication = plan.lead?.beat {
            XCTFail("doseDayLeads=false must keep the keystone lead")
        }
    }
}
