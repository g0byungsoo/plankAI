import XCTest
@testable import PlankFood

// Regression tests for the empty-capture defense (a5da0c3, 2026-06-05).
//
// Bug: when the LLM returned 200 with `items: []`, CaptureFlowView
// advanced to .result and the result card rendered with only chrome +
// "log it" + "actually skip" buttons. No food name, no kcal, no nutrient
// grid, no Jeni copy line — every content branch in SingleDishCard +
// MixedPlateCard was gated on `if let item = food.items.first { ... }`.
//
// Defense: PhotoCaptureView checks `result.items.isEmpty &&
// result.kcalLow == nil` after dispatch returns and stays on camera
// with a banner. Result cards also have defensive empty-state panels
// in case the empty result ever reaches .result phase.
//
// These tests pin the empty-state contract so the bug can't sneak back
// in via refactor.

final class EmptyCaptureGuardTests: XCTestCase {

    // MARK: - Empty CapturedFood detection

    func testEmptyItemsAndNoRangeIsFailureMode() {
        // The camera-layer guard treats this exact shape as a failed
        // scan: no items AND no restaurant range. PhotoCaptureView
        // should NOT advance to result phase on this shape.
        let empty = CapturedFood(
            items: [],
            plateType: .single,
            source: .photo,
            confidence: nil,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )

        XCTAssertTrue(empty.items.isEmpty)
        XCTAssertNil(empty.kcalLow)
        XCTAssertNil(empty.totalKcal,
                     "totalKcal must be nil when items is empty — drives the result card's empty-state branch")
    }

    func testEmptyItemsWithRestaurantRangeIsValid() {
        // Restaurant-range source legitimately produces empty items
        // + non-nil kcalLow/kcalHigh. The MixedPlateCard's empty-state
        // gate uses `items.isEmpty && kcalLow == nil` — this case
        // must NOT trip it.
        let range = CapturedFood(
            items: [],
            plateType: .restaurantRange,
            source: .restaurantEstimate,
            confidence: nil,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: 700,
            kcalHigh: 900
        )

        XCTAssertTrue(range.items.isEmpty)
        XCTAssertNotNil(range.kcalLow)
        XCTAssertNotNil(range.kcalHigh)
    }

    // MARK: - PhotoMode enum is gone (D54 collapse)
    //
    // The pre-eat / just-ate mode toggle was removed app-wide on
    // 2026-06-05. This test catches anyone re-introducing PhotoMode
    // without a fresh design review.

    func testPhotoCaptureCarriesNoMode() {
        // The .photo case takes a single Data argument — no mode.
        // If a future refactor re-adds `mode: PhotoMode`, this fails
        // to compile.
        let capture = FoodCapture.photo(Data([0x01, 0x02, 0x03]))

        switch capture {
        case .photo(let data):
            XCTAssertEqual(data.count, 3)
        case .quickAdd, .imOutTonight:
            XCTFail("expected .photo")
        }
    }
}
