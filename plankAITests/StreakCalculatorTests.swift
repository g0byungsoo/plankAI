import XCTest
@testable import plankAI

final class StreakCalculatorTests: XCTestCase {

    private let cal = Calendar.current
    private lazy var today: Date = cal.startOfDay(for: Date())

    private func dayOffset(_ n: Int) -> Date {
        cal.date(byAdding: .day, value: n, to: today)!
    }

    private func assertResult(
        _ result: StreakCalculator.Result,
        count: Int,
        active: Int,
        frozen: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(result.count, count, "count", file: file, line: line)
        XCTAssertEqual(result.activeDays, active, "activeDays", file: file, line: line)
        XCTAssertEqual(result.frozenDates.count, frozen, "frozenDates.count", file: file, line: line)
    }

    func testEmptyInput() {
        assertResult(
            StreakCalculator.calculate(activeDates: [], today: today),
            count: 0, active: 0, frozen: 0
        )
    }

    func testTodayOnly() {
        assertResult(
            StreakCalculator.calculate(activeDates: [dayOffset(0)], today: today),
            count: 1, active: 1, frozen: 0
        )
    }

    func testYesterdayOnly() {
        assertResult(
            StreakCalculator.calculate(activeDates: [dayOffset(-1)], today: today),
            count: 1, active: 1, frozen: 0
        )
    }

    func testTodayAndYesterday() {
        assertResult(
            StreakCalculator.calculate(
                activeDates: Set([dayOffset(0), dayOffset(-1)]),
                today: today
            ),
            count: 2, active: 2, frozen: 0
        )
    }

    func testAutoFreezeCoversYesterdayMiss() {
        // Today + missed yesterday + active day-before → freeze kicks in.
        assertResult(
            StreakCalculator.calculate(
                activeDates: Set([dayOffset(0), dayOffset(-2)]),
                today: today
            ),
            count: 3, active: 2, frozen: 1
        )
    }

    func testTwoMissesInRowDoNotFreeze() {
        assertResult(
            StreakCalculator.calculate(
                activeDates: Set([dayOffset(0)]),
                today: today
            ),
            count: 1, active: 1, frozen: 0
        )
    }

    func testTenDayStreakWithOneFreeze() {
        // 0..-9 except -3 missed.
        var dates = Set<Date>()
        for off in [0, -1, -2, -4, -5, -6, -7, -8, -9] {
            dates.insert(dayOffset(off))
        }
        assertResult(
            StreakCalculator.calculate(activeDates: dates, today: today),
            count: 10, active: 9, frozen: 1
        )
    }

    func testFourteenDayStreakWithOneFreeze() {
        // 0..-13 except -8 missed.
        var dates = Set<Date>()
        for off in [0, -1, -2, -3, -4, -5, -6, -7, -9, -10, -11, -12, -13] {
            dates.insert(dayOffset(off))
        }
        assertResult(
            StreakCalculator.calculate(activeDates: dates, today: today),
            count: 14, active: 13, frozen: 1
        )
    }

    func testSecondFreezeTooCloseBreaksStreak() {
        // 0..-5 active, -6 miss (freeze ok), -7 active, -8 miss (too soon — break).
        var dates = Set<Date>()
        for off in [0, -1, -2, -3, -4, -5, -7, -9] {
            dates.insert(dayOffset(off))
        }
        assertResult(
            StreakCalculator.calculate(activeDates: dates, today: today),
            count: 8, active: 7, frozen: 1
        )
    }
}
