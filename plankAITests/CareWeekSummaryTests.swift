import XCTest
@testable import plankAI

// CareWeekSummary (v9 P6) — the between-visit weekly facts. Pinned
// laws: unrecorded is unrecorded (never skipped); absent streams are
// absent keys (provenance — the dashboard renders what exists);
// taken never exceeds scheduled; the week key is monday-anchored.

final class CareWeekSummaryTests: XCTestCase {

    func testEmptyFactsCarryOnlyWeekAndWeight() {
        let s = CareWeekSummary.compose(.init(weekKey: "2026-08-03"))
        XCTAssertEqual(s.weekKey, "2026-08-03")
        XCTAssertNil(s.payload["regimen"])
        XCTAssertNil(s.payload["nutrition"])
        XCTAssertNil(s.payload["movement"])
        XCTAssertEqual((s.payload["weight"] as? [String: Any])?["entryCount"] as? Int, 0)
    }

    func testRegimenCountsUnrecordedHonestly() {
        var f = CareWeekSummary.Facts(weekKey: "2026-08-03")
        f.doseScheduled = 1
        f.doseTaken = 0
        let regimen = CareWeekSummary.compose(f).payload["regimen"] as? [String: Any]
        XCTAssertEqual(regimen?["taken"] as? Int, 0)
        XCTAssertEqual(regimen?["unrecorded"] as? Int, 1)
    }

    func testTakenNeverExceedsScheduled() {
        var f = CareWeekSummary.Facts(weekKey: "2026-08-03")
        f.doseScheduled = 1
        f.doseTaken = 3   // duplicate marks across devices
        let regimen = CareWeekSummary.compose(f).payload["regimen"] as? [String: Any]
        XCTAssertEqual(regimen?["taken"] as? Int, 1)
        XCTAssertEqual(regimen?["unrecorded"] as? Int, 0)
    }

    func testNutritionNeedsLoggedDaysAndATarget() {
        var f = CareWeekSummary.Facts(weekKey: "2026-08-03")
        f.loggedDays = 5
        f.proteinDaysMet = 3
        XCTAssertNil(CareWeekSummary.compose(f).payload["nutrition"])   // no target
        f.proteinTargetG = 90
        let nutrition = CareWeekSummary.compose(f).payload["nutrition"] as? [String: Any]
        XCTAssertEqual(nutrition?["proteinDaysMet"] as? Int, 3)
        XCTAssertEqual(nutrition?["targetG"] as? Int, 90)
    }

    func testMovementRendersFromEitherStream() {
        var f = CareWeekSummary.Facts(weekKey: "2026-08-03")
        f.movedDays = 4
        f.stepsWeekAvg = 6200
        let movement = CareWeekSummary.compose(f).payload["movement"] as? [String: Any]
        XCTAssertEqual(movement?["movedDays"] as? Int, 4)
        XCTAssertEqual(movement?["stepsWeekAvg"] as? Int, 6200)
    }

    func testWeekKeyIsMondayAnchored() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // 2026-08-04 is a Tuesday → the week's monday is 2026-08-03.
        let tuesday = DateComponents(
            calendar: cal, year: 2026, month: 8, day: 4, hour: 12
        ).date!
        XCTAssertEqual(CareWeekSummary.weekKey(for: tuesday, calendar: cal), "2026-08-03")
        // A monday maps to itself.
        let monday = DateComponents(
            calendar: cal, year: 2026, month: 8, day: 3, hour: 9
        ).date!
        XCTAssertEqual(CareWeekSummary.weekKey(for: monday, calendar: cal), "2026-08-03")
    }
}
