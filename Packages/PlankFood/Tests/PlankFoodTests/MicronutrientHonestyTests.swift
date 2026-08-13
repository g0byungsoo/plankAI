import XCTest
@testable import PlankFood

// MARK: - MicronutrientHonestyTests (2026-08-12)
//
// E7 carried ten micronutrients through the pipeline and rendered them
// on the post-scan reading. It shipped with NO tests, and the QA harness
// hand-attached micros to `.llmDirect` items — a state the pipeline
// cannot produce — so two eras of design review looked at a panel that
// was, in production, either silent or wrong.
//
// THE PROVENANCE MAP, measured by reading every path:
//
//   photo, confidence >= 0.5   NO   llm_direct; USDA never consulted.
//                                   This is the DEFAULT path since
//                                   v1.0.7, so it is most items.
//   photo, confidence < 0.5    yes  that item only, via USDA calibration
//   photo, kcal missing        yes  that item only, via the full join
//   label photo                NO   the food-vision schema returns no
//                                   micronutrients, and a legible panel
//                                   is high-confidence, so no join runs
//   typed words                NO   same response shape
//   barcode                    NO   OpenFoodFactsClient parses none
//   pantry / quick add         NO   canonical_pantry has no micro columns
//   restaurant estimate        NO   rule-based arithmetic
//   again / relog              NO   copies persisted fields
//
// So micros reach a plate only through USDA, and only for the items the
// model was least sure about. That is why the record does NOT persist
// them — freezing a partial, inverted-reliability figure into a plate
// forever would make the poorest plates read as the richest — and why
// the live panel must be gated on the PLATE being fully grounded.

final class MicronutrientHonestyTests: XCTestCase {

    // MARK: - Which sources can speak at all

    func testOnlyUSDAPublishesMicronutrients() {
        for source in NutritionSource.allCases {
            let expected: Bool
            switch source {
            case .usdaFDC, .usdaCalibrated, .usdaOverride: expected = true
            case .openFoodFacts, .canonicalPantry,
                 .ruleBasedEstimate, .llmDirect:          expected = false
            }
            XCTAssertEqual(
                item(source: source).publishesMicros, expected,
                "\(source.rawValue) claims the wrong micronutrient capability"
            )
        }
    }

    /// An item whose source was never recorded has not been asked.
    func testAnUnattributedItemNeverClaimsToPublishMicronutrients() {
        XCTAssertFalse(item(source: nil).publishesMicros)
    }

    // MARK: - A partial sum is not a plate's nutrition

    /// THE DEFECT. A four-item plate where only the mystery item hit USDA
    /// printed that ONE item's potassium as the plate's. Understating is
    /// still misrepresenting, and it is exactly the estimate-dressed-as-
    /// measurement the provenance law exists to prevent.
    func testAMixedPlateSaysNothingRatherThanOneItemsVitamins() {
        let plate = [
            item(source: .llmDirect),                       // no micros
            item(source: .llmDirect),                       // no micros
            item(source: .usdaOverride, micros: .init(potassiumMg: 500)),
        ]
        XCTAssertTrue(
            SnapResultView.namedMicros(plate).isEmpty,
            "a partial sum was rendered as the plate's own nutrition"
        )
    }

    /// The common production plate: every item answered by the model
    /// directly. The panel simply does not appear — E7's own stated rule,
    /// now enforced at the plate rather than at the item.
    func testTheDefaultLLMPlateHasNoPanelAtAll() {
        let plate = [item(source: .llmDirect), item(source: .llmDirect)]
        XCTAssertTrue(SnapResultView.namedMicros(plate).isEmpty)
    }

    func testAFullyGroundedPlateStillSpeaks() {
        let plate = [
            item(source: .usdaFDC, micros: .init(ironMg: 4, potassiumMg: 900)),
            item(source: .usdaCalibrated, micros: .init(potassiumMg: 500)),
        ]
        let named = SnapResultView.namedMicros(plate)
        XCTAssertFalse(named.isEmpty)
        // Potassium leads: the larger share of its daily value.
        XCTAssertEqual(named.first?.label, "potassium")
        XCTAssertEqual(named.first?.amount, "1,400 mg")
        XCTAssertLessThanOrEqual(named.count, 4, "at most four are named")
    }

    /// A grounded plate whose USDA records list nothing is knowledge, not
    /// a reason to guess. It stays silent, without pretending it was never
    /// asked.
    func testAGroundedPlateWithNoPublishedValuesStaysSilent() {
        let plate = [item(source: .usdaFDC, micros: .init())]
        XCTAssertTrue(SnapResultView.namedMicros(plate).isEmpty)
    }

    func testAnEmptyPlateSaysNothing() {
        XCTAssertTrue(SnapResultView.namedMicros([]).isEmpty)
    }

    /// Below 5% of a day's value the number is noise dressed as
    /// nutrition. The share RANKS; it never renders — no percentages
    /// (`00_THE_SYSTEM` §12).
    func testTraceAmountsAreNotNamedAndNoShareEverRenders() {
        let plate = [item(source: .usdaFDC, micros: .init(vitaminCMg: 1))]
        XCTAssertTrue(SnapResultView.namedMicros(plate).isEmpty)

        let real = [item(source: .usdaFDC, micros: .init(vitaminCMg: 40))]
        let named = SnapResultView.namedMicros(real)
        XCTAssertEqual(named.count, 1)
        for entry in named {
            XCTAssertFalse(entry.amount.contains("%"), entry.amount)
            XCTAssertFalse(entry.label.contains("%"), entry.label)
        }
    }

    // MARK: - A prior scales the micronutrients with the portion

    /// Her own correction must not make the plate poorer. `scale` dropped
    /// micros while keeping `nutritionSource`, so a grounded plate went
    /// silent the moment her prior improved it.
    func testHerPriorScalesTheMicronutrientsInsteadOfDroppingThem() {
        let food = CapturedFood(
            items: [item(source: .usdaFDC, micros: .init(potassiumMg: 400),
                         kcal: 200)],
            plateType: .single, source: .photo, confidence: 0.9,
            needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
        let scaled = PlatePriors.scale(food, by: 1.5)
        XCTAssertEqual(scaled.items.first?.micros?.potassiumMg, 600)
        XCTAssertFalse(SnapResultView.namedMicros(scaled.items).isEmpty,
                       "a corrected plate lost the vitamins it had grounded")
    }

    // MARK: - Helper

    private func item(
        source: NutritionSource?,
        micros: CalorieMathService.Micronutrients? = nil,
        kcal: Double = 180
    ) -> CapturedItem {
        CapturedItem(
            id: UUID().uuidString, name: "test food",
            portionGrams: 100, portionGramsLow: 100, portionGramsHigh: 100,
            usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
            confidence: 0.9, notes: nil,
            kcal: kcal, proteinG: 10, carbsG: 10, fatG: 5, fiberG: 2,
            nutritionSource: source, micros: micros
        )
    }
}
