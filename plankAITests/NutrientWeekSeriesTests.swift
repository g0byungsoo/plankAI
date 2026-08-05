import XCTest
@testable import plankAI
import PlankFood

// v11 T4 — the tile aggregator (docs/app_v11/01_PLAN.md Task 4).
// Provenance is the whole game here (L8): a day with no plates is
// nil; a day whose plates carry NO data for a nutrient (the 0 =
// not-collected convention on sodium/sugar/sat-fat) is ALSO nil —
// never a fake zero the chart would draw as "she ate none".
final class NutrientWeekSeriesTests: XCTestCase {

    private let cal = Calendar.current

    private func entry(_ daysAgo: Int, hour: Int = 12,
                       protein: Double = 20, fiber: Double = 0,
                       sugar: Double = 0, sodiumMg: Double = 0) -> FoodLogPersister.FoodLogEntry {
        let base = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: .now))!
        let at = cal.date(byAdding: .hour, value: hour, to: base)!
        return .init(
            id: UUID().uuidString, loggedAt: at, title: "t",
            kcal: 400, protein: protein, carbs: 30, fat: 10,
            fiber: fiber, sugar: sugar, sodiumMg: sodiumMg,
            satFatG: 0, items: nil, source: nil, itemsDetail: nil
        )
    }

    func testSevenDayShapeOldestFirst() {
        let s = NutrientWeekAggregator.week(
            for: .protein, entries: [entry(0), entry(6)],
            endingOn: .now, calendar: cal
        )
        XCTAssertEqual(s.days.count, 7)
        XCTAssertEqual(s.days.last?.value, 20, "today is last")
        XCTAssertEqual(s.days.first?.value, 20, "six days ago is first")
    }

    func testMissingDaysAreNilNeverZero() {
        let s = NutrientWeekAggregator.week(
            for: .protein, entries: [entry(2, protein: 30)],
            endingOn: .now, calendar: cal
        )
        XCTAssertEqual(s.days.filter { $0.value != nil }.count, 1)
        XCTAssertNil(s.days.last?.value, "no plates today = nil, not 0")
        XCTAssertEqual(s.loggedCount, 1)
    }

    func testSodiumSums_andZeroMeansNotCollected() {
        // Two plates today: one carries sodium, one predates the field
        // (0 = silent). The day's truth is the collected 900mg.
        let s = NutrientWeekAggregator.week(
            for: .sodium,
            entries: [entry(0, sodiumMg: 900), entry(0, hour: 18, sodiumMg: 0)],
            endingOn: .now, calendar: cal
        )
        XCTAssertEqual(s.days.last?.value, 900)

        // A day whose plates ALL carry 0 sodium = not collected = nil.
        let silent = NutrientWeekAggregator.week(
            for: .sodium, entries: [entry(1, sodiumMg: 0)],
            endingOn: .now, calendar: cal
        )
        XCTAssertNil(silent.days[5].value,
                     "an uncollected nutrient day must be a gap, not a zero bar")
        XCTAssertEqual(silent.loggedCount, 0)
    }

    func testProteinSumsAcrossPlates() {
        let s = NutrientWeekAggregator.week(
            for: .protein,
            entries: [entry(0, protein: 32), entry(0, hour: 19, protein: 41)],
            endingOn: .now, calendar: cal
        )
        XCTAssertEqual(s.days.last?.value, 73)
    }

    func testFloorNeedsThreeLoggedDays() {
        let two = NutrientWeekAggregator.week(
            for: .protein, entries: [entry(0), entry(1)],
            endingOn: .now, calendar: cal
        )
        XCTAssertFalse(two.meetsFloor)

        let three = NutrientWeekAggregator.week(
            for: .protein, entries: [entry(0), entry(1), entry(3)],
            endingOn: .now, calendar: cal
        )
        XCTAssertTrue(three.meetsFloor)
    }

    func testLateNightEntryLandsOnItsLocalDay() {
        // 23:40 yesterday stays yesterday — never bleeds into today.
        let s = NutrientWeekAggregator.week(
            for: .protein, entries: [entry(1, hour: 23, protein: 25)],
            endingOn: .now, calendar: cal
        )
        XCTAssertEqual(s.days[5].value, 25)
        XCTAssertNil(s.days.last?.value)
    }
}
