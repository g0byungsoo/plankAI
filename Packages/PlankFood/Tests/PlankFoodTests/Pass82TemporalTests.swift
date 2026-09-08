import XCTest
@testable import PlankFood

/// p82 — the tell-clock flag. A "last night…" plate's `loggedAt`
/// clock is the moment she TOLD the record, not the moment she ate;
/// THE BOOK was printing that tell-time as if it were the meal's
/// ("· 8:04am" on yesterday's spread). The record now knows the
/// difference, and the surfaces suppress the time for those rows.
@MainActor
final class Pass82TemporalTests: XCTestCase {

    private func item(_ name: String) -> CapturedItem {
        CapturedItem(
            id: UUID().uuidString, name: name, portionGrams: 300,
            portionGramsLow: 300, portionGramsHigh: 300,
            usdaSearchTerms: [name], preparation: nil, cuisineHint: nil,
            confidence: 0.9, notes: nil,
            kcal: 300, proteinG: 20, carbsG: 20, fatG: 10,
            fiberG: nil, nutritionSource: .llmDirect
        )
    }

    private func plate(_ title: String, statedDaysAgo: Int? = nil) -> CapturedFood {
        var food = CapturedFood(
            items: [item(title)], plateType: .single, source: .words,
            confidence: 0.9, needsSecondPhoto: false,
            secondPhotoHint: nil, kcalLow: nil, kcalHigh: nil
        )
        food.statedDaysAgo = statedDaysAgo
        return food
    }

    func testAStatedYesterdayPlateCarriesTheTellClockFlag() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(
            plate("chicken soup", statedDaysAgo: 1), userId: userId
        )
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertTrue(
            entry.clockIsTellTime,
            "a stated-yesterday plate's clock is a tell time and must say so"
        )
    }

    func testANormalPlateKeepsAMealClock() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(plate("omelette"), userId: userId)
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertFalse(entry.clockIsTellTime,
                       "an ordinary log's clock stays a meal clock")
    }

    func testMovingAPlateToAnotherDayMarksItsClockAsTellTime() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(plate("beef chili"), userId: userId)
        let entry = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        let target = Calendar.current.date(byAdding: .day, value: -2, to: .now)!
        XCTAssertTrue(FoodLogPersister.setLoggedDay(id: entry.id, to: target))
        let moved = try XCTUnwrap(FoodLogPersister.allEntries(userId: userId).first)
        XCTAssertTrue(
            moved.clockIsTellTime,
            "a day-moved plate keeps the original log moment's clock — a tell time"
        )
    }

    func testTheSyncRowCarriesTheTellClock() throws {
        let userId = UUID().uuidString
        _ = try FoodLogPersister.persist(
            plate("chicken soup", statedDaysAgo: 1), userId: userId
        )
        let row = try XCTUnwrap(
            FoodLogPersister.allSyncableEntries(userId: userId).first
        )
        XCTAssertTrue(row.clockIsTellTime,
                      "the tell-clock flag must ride to the payload")
    }
}
