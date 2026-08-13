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

    // MARK: - I'm Out Tonight (D14 locked rule-based estimator)

    func testImOutTonightItalianReturnsRange() async throws {
        let dispatcher = FoodCaptureDispatcher()
        let food = try await dispatcher.dispatch(.imOutTonight(cuisine: .italian))

        XCTAssertEqual(food.plateType, .restaurantRange)
        XCTAssertEqual(food.source, .restaurant)
        XCTAssertTrue(food.items.isEmpty, "restaurant estimates have no per-item rows")
        XCTAssertEqual(food.kcalLow, 700)   // italian center 850 − 150
        XCTAssertEqual(food.kcalHigh, 1000) // italian center 850 + 150
    }

    func testImOutTonightNilCuisineUsesGenericCenter() async throws {
        let dispatcher = FoodCaptureDispatcher()
        let food = try await dispatcher.dispatch(.imOutTonight(cuisine: nil))

        XCTAssertEqual(food.kcalLow, 550)   // generic center 700 − 150
        XCTAssertEqual(food.kcalHigh, 850)  // generic center 700 + 150
    }

    func testImOutTonightAllCuisinesProduceValidRange() async throws {
        let dispatcher = FoodCaptureDispatcher()
        for cuisine in CuisineChip.allCases {
            let food = try await dispatcher.dispatch(.imOutTonight(cuisine: cuisine))
            XCTAssertNotNil(food.kcalLow, "kcalLow nil for \(cuisine)")
            XCTAssertNotNil(food.kcalHigh, "kcalHigh nil for \(cuisine)")
            XCTAssertGreaterThan(food.kcalHigh ?? 0, food.kcalLow ?? 0,
                                 "range degenerate for \(cuisine)")
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

    /// E8.1 — `CaptureSource` is gone; `EntryMethod` is the single
    /// vocabulary for the column, the event and the plate. The full
    /// contract pin lives in EntryMethodTests; this keeps the two values
    /// whose spelling was inherited from the shipped column rather than
    /// chosen, because those are the ones a tidy-up would break.
    func testSourceRawValuesMatchSupabaseSchema() {
        XCTAssertEqual(EntryMethod.photo.rawValue, "photo")
        XCTAssertEqual(EntryMethod.pantry.rawValue, "quick_add")
        XCTAssertEqual(EntryMethod.restaurant.rawValue, "restaurant_estimate")
        XCTAssertEqual(EntryMethod.barcode.rawValue, "barcode")
    }

    /// The dispatcher is the chokepoint that stamps the door. If it ever
    /// stops, every plate through the camera, the label and the words
    /// field lands in the record as `unknown` — silently, because
    /// nothing else in the pipeline reads it.
    func testDispatcherStampsTheDoorOnTheRestaurantPath() async throws {
        let dispatcher = FoodCaptureDispatcher()
        let food = try await dispatcher.dispatch(.imOutTonight(cuisine: .pizza))
        XCTAssertEqual(food.source, .restaurant)
    }

    func testPlateTypeCases() {
        XCTAssertEqual(PlateType.allCases.count, 6)
    }

    func testNutritionSourceVocabulary() {
        // Was a bare count, which fires on any change and explains none.
        // The raw values are what telemetry groups by, so pin those.
        //
        // 4 lookup-family cases + llmDirect + usdaCalibrated +
        // usdaOverride (v1.0.7 direct-kcal rewrite) + labelDeclared: the
        // manufacturer's own declaration off a photographed panel, which
        // is neither an estimate nor a database lookup and had been
        // stamped `llm_direct` — the provenance of a guess.
        XCTAssertEqual(
            Set(NutritionSource.allCases.map(\.rawValue)),
            ["usda_fdc", "open_food_facts", "canonical_pantry",
             "rule_based_estimate", "llm_direct", "usda_calibrated",
             "usda_override", "label_declared"]
        )
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
