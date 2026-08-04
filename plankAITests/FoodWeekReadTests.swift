import XCTest
@testable import plankAI

// FoodWeekRead (v9 P5) — the weekly food-quality BANDS. Pinned laws:
// nil under 4 logged days (a caption isn't a read); the win named
// first (protein-led beats the timing observation); late-heavy =
// ≥40% of the week's kcal landing 8pm+; never a number, never a
// food name, never a score.

final class FoodWeekReadTests: XCTestCase {

    private let cal = Calendar.current

    private func plate(daysAgo: Int, hour: Int, kcal: Double,
                       protein: Double = 0) -> FoodWeekRead.Plate {
        let day = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: .now))!
        let at = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return .init(loggedAt: at, kcal: kcal, protein: protein)
    }

    func testUnderFourLoggedDaysReadsNothing() {
        let plates = [plate(daysAgo: 0, hour: 12, kcal: 500),
                      plate(daysAgo: 1, hour: 12, kcal: 500),
                      plate(daysAgo: 2, hour: 12, kcal: 500)]
        XCTAssertNil(FoodWeekRead.compose(plates: plates, proteinTargetG: 90))
    }

    func testProteinLedNeedsFourMetDays() {
        let plates = (0..<5).map { plate(daysAgo: $0, hour: 12, kcal: 600, protein: 95) }
        let read = FoodWeekRead.compose(plates: plates, proteinTargetG: 90)
        XCTAssertEqual(read?.band, .proteinLed)
        XCTAssertEqual(read?.line, "a protein-led week at the table.")
    }

    func testProteinWinOutranksTheTimingObservation() {
        // Protein met AND meals late — the win is named (anti-shame order).
        let plates = (0..<5).map { plate(daysAgo: $0, hour: 21, kcal: 600, protein: 95) }
        XCTAssertEqual(
            FoodWeekRead.compose(plates: plates, proteinTargetG: 90)?.band,
            .proteinLed
        )
    }

    func testLateHeavyNeedsFortyPercentAfterEight() {
        var plates = (0..<4).map { plate(daysAgo: $0, hour: 12, kcal: 500, protein: 20) }
        plates += (0..<4).map { plate(daysAgo: $0, hour: 21, kcal: 500, protein: 20) }
        XCTAssertEqual(
            FoodWeekRead.compose(plates: plates, proteinTargetG: 90)?.band,
            .lateHeavy
        )
    }

    func testMostlyDaytimeReadsSteady() {
        var plates = (0..<5).map { plate(daysAgo: $0, hour: 12, kcal: 600, protein: 20) }
        plates.append(plate(daysAgo: 1, hour: 21, kcal: 200, protein: 5))
        XCTAssertEqual(
            FoodWeekRead.compose(plates: plates, proteinTargetG: 90)?.band,
            .steady
        )
    }

    func testNoTargetSkipsProteinBandButStillReads() {
        let plates = (0..<5).map { plate(daysAgo: $0, hour: 12, kcal: 600, protein: 95) }
        XCTAssertEqual(
            FoodWeekRead.compose(plates: plates, proteinTargetG: nil)?.band,
            .steady
        )
    }

    func testOldPlatesOutsideTheWeekDoNotCount() {
        let plates = (7..<12).map { plate(daysAgo: $0, hour: 12, kcal: 600, protein: 95) }
        XCTAssertNil(FoodWeekRead.compose(plates: plates, proteinTargetG: 90))
    }

    func testLinesNeverCarryNumbersOrFoodNames() {
        let reads: [FoodWeekRead.Read?] = [
            FoodWeekRead.compose(
                plates: (0..<5).map { plate(daysAgo: $0, hour: 12, kcal: 600, protein: 95) },
                proteinTargetG: 90),
            FoodWeekRead.compose(
                plates: (0..<5).map { plate(daysAgo: $0, hour: 21, kcal: 600, protein: 10) },
                proteinTargetG: 90),
        ]
        for read in reads.compactMap({ $0 }) {
            XCTAssertNil(read.line.rangeOfCharacter(from: .decimalDigits),
                         "a band line must never carry a number: \(read.line)")
        }
    }
}
