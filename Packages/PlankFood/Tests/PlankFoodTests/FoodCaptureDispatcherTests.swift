import XCTest
@testable import PlankFood

@MainActor
final class FoodCaptureDispatcherTests: XCTestCase {

    // MARK: - Exhaustive switch coverage
    //
    // Until W2-T3 / W2-T4 land, every dispatch path returns
    // .notImplemented with the right ticket reference. These tests
    // pin those references so renaming a ticket without updating the
    // dispatcher gets caught.

    func testPhotoDispatchReturnsW2T3NotImplemented() async {
        // D54: PhotoMode collapsed — .photo no longer carries a mode.
        // Module guard test: without FoodModule.visionService configured,
        // dispatch throws notImplemented with W2-T3 ticket.
        let dispatcher = FoodCaptureDispatcher()
        FoodModule.visionService = nil  // force the guard path
        let capture = FoodCapture.photo(Data([0xFF, 0xD8, 0xFF]))

        do {
            _ = try await dispatcher.dispatch(capture)
            XCTFail("expected notImplemented; got result instead")
        } catch let FoodCaptureError.notImplemented(ticket, _, context) {
            XCTAssertEqual(ticket, "W2-T3")
            if case .photo(let bytes) = context {
                XCTAssertEqual(bytes, 3)
            } else {
                XCTFail("expected .photo context, got \(context)")
            }
        } catch {
            XCTFail("expected FoodCaptureError.notImplemented, got \(error)")
        }
    }

    func testQuickAddDispatchReturnsW2T4NotImplemented() async {
        let dispatcher = FoodCaptureDispatcher()
        let id = PantryItemID("matcha_latte_oat_m")
        let capture = FoodCapture.quickAdd(id)

        do {
            _ = try await dispatcher.dispatch(capture)
            XCTFail("expected notImplemented; got result instead")
        } catch let FoodCaptureError.notImplemented(ticket, _, context) {
            XCTAssertEqual(ticket, "W2-T4")
            if case .quickAdd(let pantryID) = context {
                XCTAssertEqual(pantryID, id)
            } else {
                XCTFail("expected .quickAdd context, got \(context)")
            }
        } catch {
            XCTFail("expected FoodCaptureError.notImplemented, got \(error)")
        }
    }

    func testImOutTonightDispatchReturnsTBDNotImplemented() async {
        let dispatcher = FoodCaptureDispatcher()
        let capture = FoodCapture.imOutTonight(cuisine: .italian)

        do {
            _ = try await dispatcher.dispatch(capture)
            XCTFail("expected notImplemented; got result instead")
        } catch let FoodCaptureError.notImplemented(ticket, _, context) {
            XCTAssertEqual(ticket, "W2-TBD")
            if case .imOutTonight(let cuisine) = context {
                XCTAssertEqual(cuisine, .italian)
            } else {
                XCTFail("expected .imOutTonight context, got \(context)")
            }
        } catch {
            XCTFail("expected FoodCaptureError.notImplemented, got \(error)")
        }
    }

    func testImOutTonightNilCuisinePassesThrough() async {
        let dispatcher = FoodCaptureDispatcher()
        let capture = FoodCapture.imOutTonight(cuisine: nil)

        do {
            _ = try await dispatcher.dispatch(capture)
            XCTFail("expected notImplemented")
        } catch let FoodCaptureError.notImplemented(_, _, context) {
            if case .imOutTonight(let cuisine) = context {
                XCTAssertNil(cuisine, "nil cuisine should propagate to context")
            } else {
                XCTFail("expected .imOutTonight context")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - CapturedFood

    func testTotalKcalSumsWhenAllItemsHaveKcal() {
        let food = CapturedFood(
            items: [
                .test(kcal: 100),
                .test(kcal: 200),
                .test(kcal: 50),
            ],
            plateType: .mixed,
            source: .photo,
            confidence: 0.9,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )
        XCTAssertEqual(food.totalKcal, 350)
    }

    func testTotalKcalNilWhenAnyItemMissingKcal() {
        let food = CapturedFood(
            items: [
                .test(kcal: 100),
                .test(kcal: nil),   // missing
                .test(kcal: 50),
            ],
            plateType: .mixed,
            source: .photo,
            confidence: 0.9,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )
        XCTAssertNil(food.totalKcal,
                     "totalKcal should be nil until USDA join completes for every item")
    }

    // MARK: - Enum case pins

    func testCaptureSourceRawValuesMatchSupabaseSchema() {
        // food_logs.source CHECK constraint pins these strings.
        // Renaming any of them without a matching ALTER TABLE will
        // produce 42601 'new row violates check constraint' on insert.
        XCTAssertEqual(CaptureSource.photo.rawValue, "photo")
        XCTAssertEqual(CaptureSource.quickAdd.rawValue, "quick_add")
        XCTAssertEqual(CaptureSource.imOut.rawValue, "im_out")
        XCTAssertEqual(CaptureSource.restaurantEstimate.rawValue, "restaurant_estimate")
        XCTAssertEqual(CaptureSource.barcode.rawValue, "barcode")
        XCTAssertEqual(CaptureSource.voice.rawValue, "voice")
        XCTAssertEqual(CaptureSource.text.rawValue, "text")
        XCTAssertEqual(CaptureSource.menu.rawValue, "menu")
    }

    func testPlateTypeCases() {
        XCTAssertEqual(PlateType.allCases.count, 6)
    }

    func testNutritionSourceCases() {
        XCTAssertEqual(NutritionSource.allCases.count, 4)
    }
}

// MARK: - CapturedItem test fixture

private extension CapturedItem {
    static func test(kcal: Double?) -> CapturedItem {
        CapturedItem(
            id: UUID().uuidString,
            name: "test item",
            portionGrams: 100,
            portionGramsLow: 80,
            portionGramsHigh: 120,
            usdaSearchTerms: [],
            preparation: nil,
            cuisineHint: nil,
            confidence: nil,
            notes: nil,
            kcal: kcal,
            proteinG: nil,
            carbsG: nil,
            fatG: nil,
            fiberG: nil,
            nutritionSource: nil
        )
    }
}
