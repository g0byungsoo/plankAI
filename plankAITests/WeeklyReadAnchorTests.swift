import XCTest
@testable import plankAI

// E1 THE SPINE — the weekly read's anchor ladder
// (docs/app_v25/05_E1_SPINE.md §2). Preference › dose-day ›
// enrollment. The founder's law: dose day is an insight, not dogma —
// daily-medication and non-medication users get a coherent week with
// ZERO weekly-injection assumptions.

final class WeeklyReadAnchorTests: XCTestCase {

    private let cal = Calendar.current

    /// A Monday 09:00 reference (2026-08-10 was a Monday).
    private func monday(atHour hour: Int = 9) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 10
        comps.hour = hour
        return cal.date(from: comps)!
    }
    private func day(_ offset: Int, hour: Int = 9) -> Date {
        cal.date(byAdding: .day, value: offset, to: monday(atHour: hour))!
    }

    private func resolve(
        now: Date,
        readAnchorWord: String? = nil,
        regimenAnchorWeekday: Int? = nil,
        programDay: Int? = nil,
        signed: Set<String> = [],
        breakActive: Bool = false
    ) -> WeeklyReadAnchor.Resolution? {
        WeeklyReadAnchor.dueResolution(
            now: now,
            readAnchorWord: readAnchorWord,
            regimenAnchorWeekday: regimenAnchorWeekday,
            programDay: programDay,
            signedWindowStartDays: signed,
            breakActive: breakActive,
            calendar: cal
        )
    }

    // MARK: - Preference anchor (highest)

    func testPreferenceWeekdayDueOnItsMorning() {
        // readAnchor weekday:1 (monday) — due monday 09:00.
        let r = resolve(now: monday(atHour: 9), readAnchorWord: "weekday:1")
        XCTAssertEqual(r?.kind, .preference)
    }

    func testPreferenceCarriesThroughThreeGraceDays() {
        let r = resolve(now: day(2), readAnchorWord: "weekday:1")
        XCTAssertEqual(r?.kind, .preference)
        XCTAssertNil(resolve(now: day(4), readAnchorWord: "weekday:1"))
    }

    func testPreferenceOutranksDoseDay() {
        // She chose sunday (weekday:7); regimen anchors wednesday.
        // Sunday wins (preference › dose-day).
        let r = resolve(
            now: day(6), readAnchorWord: "weekday:7", regimenAnchorWeekday: 3
        )
        XCTAssertEqual(r?.kind, .preference)
    }

    // MARK: - Dose-day anchor (weekly injectable only)

    func testDoseDayAnchorDueTheMorningAfter() {
        // Weekly shot on monday (iso 1) → the read arrives tuesday.
        XCTAssertNil(resolve(now: monday(atHour: 9), regimenAnchorWeekday: 1))
        let r = resolve(now: day(1), regimenAnchorWeekday: 1)
        XCTAssertEqual(r?.kind, .doseDay)
    }

    func testDoseDayWindowCoversTheDoseWeek() {
        // Read on tuesday after a monday dose: the window is the 7
        // days ENDING monday (the dose week she just lived).
        let r = resolve(now: day(1), regimenAnchorWeekday: 1)
        XCTAssertEqual(r?.windowStartDay, TodayStateService.dayKey(for: day(-6)))
    }

    // MARK: - Enrollment fallback (everyone else — zero leakage)

    func testDailyMedicationUserFallsToEnrollment() {
        // A daily pill has NO weekly anchor — regimenAnchorWeekday is
        // nil by construction; program day 7 evening → enrollment law.
        let r = resolve(now: day(0, hour: 18), programDay: 7)
        XCTAssertEqual(r?.kind, .enrollment)
    }

    func testNonMedicationUserFallsToEnrollment() {
        let r = resolve(now: day(0, hour: 18), programDay: 14)
        XCTAssertEqual(r?.kind, .enrollment)
    }

    func testEnrollmentNotDueMidWeek() {
        // Day 11 = slot 3 — past the v4 grace (slots 0-2 review the
        // prior week; slot 6 evening opens the current one).
        XCTAssertNil(resolve(now: day(0, hour: 18), programDay: 11))
    }

    func testEnrollmentGraceIntoNextWeek() {
        // Program day 15-16 (slot ≤2 of week 3) still reads week 2.
        let r = resolve(now: day(0), programDay: 15)
        XCTAssertEqual(r?.kind, .enrollment)
    }

    // MARK: - Silences

    func testSignedWindowIsSilent() {
        let windowStart = TodayStateService.dayKey(for: day(-6))
        XCTAssertNil(resolve(
            now: day(1), regimenAnchorWeekday: 1, signed: [windowStart]
        ))
    }

    func testBreakIsSilent() {
        XCTAssertNil(resolve(
            now: day(1), regimenAnchorWeekday: 1, breakActive: true
        ))
        XCTAssertNil(resolve(
            now: day(0, hour: 18), programDay: 7, breakActive: true
        ))
    }

    func testNothingDueWithNoAnchorsAndNoProgram() {
        // Brand-new user, no program, no regimen, no preference —
        // the read never invents itself (no fake intelligence).
        XCTAssertNil(resolve(now: day(1)))
    }
}
