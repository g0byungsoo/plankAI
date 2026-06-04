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
            .photo(Data(), mode: .justAte),
            .quickAdd(PantryItemID("matcha_latte_oat_m")),
            .imOutTonight(cuisine: .mexican),
        ]

        for capture in cases {
            switch capture {
            case .photo(let data, let mode):
                XCTAssertEqual(data, Data())
                XCTAssertEqual(mode, .justAte)
            case .quickAdd(let id):
                XCTAssertEqual(id.value, "matcha_latte_oat_m")
            case .imOutTonight(let cuisine):
                XCTAssertEqual(cuisine, .mexican)
            }
        }
    }

    func testPhotoModeCases() {
        XCTAssertEqual(PhotoMode.allCases.count, 2)
    }

    func testCuisineChipCases() {
        XCTAssertEqual(CuisineChip.allCases.count, 6)
    }
}
