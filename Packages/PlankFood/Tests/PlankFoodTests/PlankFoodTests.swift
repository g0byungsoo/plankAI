import XCTest
@testable import PlankFood

final class PlankFoodTests: XCTestCase {

    func testModuleVersion() {
        XCTAssertEqual(PlankFood.version, "0.1.0-scaffold")
    }

    // FoodCapture is exhaustive — a new case forces a switch update here.
    // This test exists so a future maintainer can't silently add a case
    // without realizing every switch site needs touching.
    func testFoodCaptureExhaustive() {
        let cases: [FoodCapture] = [
            .photo(Data()),
            .quickAdd(PantryItemID("matcha_latte_oat_m")),
            .imOutTonight(cuisine: .mexican),
            .text("two eggs and toast", cuisineProfile: nil),
            .labelPhoto(Data([0xFF])),
        ]

        for capture in cases {
            switch capture {
            case .photo(let data):
                XCTAssertEqual(data, Data())
            case .quickAdd(let id):
                XCTAssertEqual(id.value, "matcha_latte_oat_m")
            case .imOutTonight(let cuisine):
                XCTAssertEqual(cuisine, .mexican)
            case .text(let description, let cuisineProfile):
                XCTAssertEqual(description, "two eggs and toast")
                XCTAssertNil(cuisineProfile)
            case .labelPhoto(let data):
                // v23 §8 — the nutrition-facts arm rides the same
                // pipeline with the label hint on the text field.
                XCTAssertEqual(data, Data([0xFF]))
            }
        }
    }

    func testCuisineChipCases() {
        XCTAssertEqual(CuisineChip.allCases.count, 6)
    }
}
