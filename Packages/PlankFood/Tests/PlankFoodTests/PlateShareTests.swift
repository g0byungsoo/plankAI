import XCTest
@testable import PlankFood

// MARK: - PlateShareTests
//
// THE PORTION IS PART OF THE NUMBER.
//
// The defect these pin: the food-vision Edge Function has computed
// `servings_in_dish` and `is_shareable` since 2026-06-23, its prompt
// says in so many words "the app divides by the user's own input", and
// its worked example says "the app lets the user say they ate 2 slices".
// Nothing in the app ever read either field. A whole 12-inch pizza filed
// ~2,200 kcal, and the finest thing the fraction ladder could express
// was "a few bites" — 25%, or two slices.
//
// The second half: a barcode read maps ONE SERVING as the manufacturer
// defined it, and the ladder was clamped to `min(f, 1.0)`. Every rung on
// the most accurate reading in the app pointed away from the answer.

final class PlateShareTests: XCTestCase {

    // MARK: fixtures
    //
    // Every fixture here is a shape the PRODUCTION pipeline can actually
    // produce: the field values are the ones the EF schema emits for the
    // case named. Nothing hand-attaches data a real response cannot
    // carry — that is the QA-seeder defect this project has now found
    // three times.

    private func item(
        name: String, kcal: Double, count: Int? = nil, unit: String? = nil,
        servings: Int? = nil, shareable: Bool? = nil, grams: Double = 300
    ) -> CapturedItem {
        CapturedItem(
            id: name, name: name, portionGrams: grams,
            portionGramsLow: grams * 0.85, portionGramsHigh: grams * 1.15,
            usdaSearchTerms: [name], preparation: nil, cuisineHint: nil,
            confidence: 0.8, notes: nil,
            kcal: kcal, proteinG: 20, carbsG: 40, fatG: 10, fiberG: 3,
            nutritionSource: .llmDirect,
            count: count, unit: unit,
            servingsInDish: servings, isShareable: shareable
        )
    }

    private func plate(
        _ items: [CapturedItem], source: EntryMethod = .photo
    ) -> CapturedFood {
        CapturedFood(
            items: items, plateType: .single, source: source,
            confidence: 0.8, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
    }

    // MARK: - The common plate is untouched

    func testSinglePlateKeepsTheShippedLadder() {
        // The EF prompt: "for a normal single plate set servings_in_dish=1,
        // is_shareable=false (the common case)."
        let food = plate([item(name: "oatmeal", kcal: 320, servings: 1, shareable: false)])
        XCTAssertNil(PlateShare.servings(in: food))
        XCTAssertEqual(PlateShare.ladder(for: food), PlateShare.soloLadder)
        XCTAssertNil(PlateShare.wholeDishNote(for: food))
    }

    func testMissingFieldsKeepTheShippedLadder() {
        // A pre-deploy EF response, or a model that under-filled the
        // schema, carries nil in both fields. Absence is never a share.
        let food = plate([item(name: "toast", kcal: 200)])
        XCTAssertNil(PlateShare.servings(in: food))
        XCTAssertEqual(PlateShare.ladder(for: food), PlateShare.soloLadder)
    }

    func testServingsWithoutShareableIsNotAShare() {
        // A big lasagne IS four servings and that is irrelevant when one
        // person is holding the plate. BOTH halves are required.
        let food = plate([item(name: "lasagne", kcal: 900, servings: 4, shareable: false)])
        XCTAssertNil(PlateShare.servings(in: food))
    }

    func testShareableWithOneServingIsNotAShare() {
        let food = plate([item(name: "poke bowl", kcal: 600, servings: 1, shareable: true)])
        XCTAssertNil(PlateShare.servings(in: food))
    }

    // MARK: - The whole pizza, which is the case that started this

    func testWholePizzaOffersOneSliceAndSaysWhatTheNumbersAre() {
        // Worked example C from the EF's own system prompt.
        let food = plate([
            item(name: "pepperoni pizza", kcal: 2200,
                 count: 8, unit: "slice", servings: 8, shareable: true)
        ])
        XCTAssertEqual(PlateShare.servings(in: food), 8)

        let rungs = PlateShare.ladder(for: food)
        XCTAssertEqual(rungs.map(\.value), [1.0, 0.5, 0.25, 0.125])
        XCTAssertEqual(rungs.map { $0.label + $0.punch },
                       ["all of it", "about half", "2 slices", "1 slice"])

        // The number the app files by default is now stated, not implied.
        // Kept short deliberately: filmed at AX5, a longer sentence in
        // this position pushed the protein figure out of the reading's
        // opening detent.
        XCTAssertEqual(
            PlateShare.wholeDishNote(for: food),
            "the whole dish \u{00B7} about 8 slices"
        )
        // One slice was unreachable before: the old floor was 0.25.
        XCTAssertEqual(2200 * (rungs.last?.value ?? 0), 275, accuracy: 0.01)
    }

    func testPlatterWithoutACountableUnitSaysServing() {
        // count=1, unit="serving" — a continuous dish. There is no
        // countable noun, so the ladder must not invent one.
        let food = plate([
            item(name: "bulgogi platter", kcal: 1600,
                 count: 1, unit: "serving", servings: 4, shareable: true)
        ])
        let rungs = PlateShare.ladder(for: food)
        XCTAssertEqual(rungs.map { $0.label + $0.punch },
                       ["all of it", "2 servings", "1 serving"])
        // "2 servings" of 4 IS half; the serving label wins because it is
        // the more precise instrument.
        XCTAssertEqual(rungs.map(\.value), [1.0, 0.5, 0.25])
    }

    func testUnitIsIgnoredWhenOneUnitIsNotOneServing() {
        // Five pieces of fried chicken plated for one person: count=5 but
        // servings_in_dish=1. If that dish were ever marked shareable,
        // "1 piece" would be a lie about a serving.
        let food = plate([
            item(name: "fried chicken", kcal: 1250,
                 count: 5, unit: "piece", servings: 2, shareable: true)
        ])
        let rungs = PlateShare.ladder(for: food)
        XCTAssertEqual(rungs.map { $0.label + $0.punch }, ["all of it", "1 serving"])
    }

    func testJunkUnitNeverReachesTheScreen() {
        // `unit` is free-form model output rendered verbatim.
        for junk in ["", "   ", "a-very-long-unit-name", "12345", "🍕"] {
            let food = plate([
                item(name: "platter", kcal: 800,
                     count: 3, unit: junk, servings: 3, shareable: true)
            ])
            let words = PlateShare.ladder(for: food).map(\.punch)
            XCTAssertTrue(words.contains("serving"), "junk unit \(junk) leaked: \(words)")
        }
    }

    func testAbsurdServingCountIsClamped() {
        let food = plate([
            item(name: "catering tray", kcal: 9000, servings: 400, shareable: true)
        ])
        XCTAssertEqual(PlateShare.servings(in: food), 24)
    }

    func testLadderNeverExceedsFourRungs() {
        for n in 2...24 {
            let food = plate([
                item(name: "dish", kcal: 1000, count: n, unit: "piece",
                     servings: n, shareable: true)
            ])
            let rungs = PlateShare.ladder(for: food)
            XCTAssertLessThanOrEqual(rungs.count, 4, "n=\(n)")
            XCTAssertGreaterThanOrEqual(rungs.count, 2, "n=\(n)")
            // Strictly descending, no duplicate rungs.
            XCTAssertEqual(rungs.map(\.value), rungs.map(\.value).sorted(by: >), "n=\(n)")
            XCTAssertEqual(Set(rungs.map(\.value)).count, rungs.count, "n=\(n)")
            // Every rung is a real portion of the dish.
            for r in rungs { XCTAssertTrue(r.value > 0 && r.value <= 1.0, "n=\(n)") }
        }
    }

    func testTheDominantItemDecides() {
        // A shared table: the platter carries the calories, the rice does
        // not. The platter's serving count is the one that means anything.
        let food = plate([
            item(name: "rice", kcal: 200, servings: 1, shareable: false, grams: 150),
            item(name: "galbi platter", kcal: 1800, count: 1, unit: "serving",
                 servings: 4, shareable: true, grams: 900),
        ])
        XCTAssertEqual(PlateShare.servings(in: food), 4)
    }

    // MARK: - Packaged food counts up

    func testBarcodePlateCanSayTwoServings() {
        // The clamp was `min(f, 1.0)`: a person who ate two servings of a
        // four-serving bag had no rung and had to drag a gram slider.
        let food = plate([item(name: "tortilla chips", kcal: 140, grams: 28)],
                         source: .barcode)
        XCTAssertTrue(PlateShare.isPackagedServing(food))
        XCTAssertEqual(PlateShare.maxFraction(for: food), 3.0)
        XCTAssertEqual(PlateShare.ladder(for: food).map(\.value), [3.0, 2.0, 1.0, 0.5])
        XCTAssertEqual(
            PlateShare.wholeDishNote(for: food),
            "these are one serving's numbers, from the label"
        )
    }

    func testLabelPlateCountsUpToo() {
        let food = plate([item(name: "granola", kcal: 210, grams: 55)], source: .label)
        XCTAssertTrue(PlateShare.isPackagedServing(food))
        XCTAssertEqual(PlateShare.maxFraction(for: food), 3.0)
    }

    func testPhotoPlateStillCannotExceedItself() {
        // There is no more food than what was in the frame.
        let food = plate([item(name: "salad", kcal: 300)])
        XCTAssertEqual(PlateShare.maxFraction(for: food), 1.0)
        var session = PlateEditSession(food: food)
        session.setFraction(3.0)
        XCTAssertEqual(session.fraction, 1.0)
    }

    func testSessionHonoursThePackagedCeiling() {
        let food = plate([item(name: "chips", kcal: 140, grams: 28)], source: .barcode)
        var session = PlateEditSession(food: food)
        session.setFraction(2.0)
        XCTAssertEqual(session.fraction, 2.0)
        XCTAssertEqual(session.totals.kcal, 280, accuracy: 0.01)
        XCTAssertEqual(session.totals.grams, 56, accuracy: 0.01)
        // And still refuses the absurd.
        session.setFraction(99)
        XCTAssertEqual(session.fraction, 3.0)
    }

    func testMultiItemPrintedPlateIsNotAPackagedServing() {
        // "+ add something" on a barcode read makes it a meal, not a
        // package. Counting the whole meal up by servings is meaningless.
        let food = plate([
            item(name: "chips", kcal: 140, grams: 28),
            item(name: "salsa", kcal: 40, grams: 30),
        ], source: .barcode)
        XCTAssertFalse(PlateShare.isPackagedServing(food))
        XCTAssertEqual(PlateShare.maxFraction(for: food), 1.0)
    }

    // MARK: - The package's own size, from Open Food Facts

    private func offJSON(_ s: String) -> Data { Data(s.utf8) }

    func testPackageSizeComesFromOpenFoodFactsWithNoDeploy() throws {
        // 340g bag, 28g serving → about 12 servings. Both numbers were
        // already in the response the barcode door has been parsing since
        // v23; nothing here needed a network change.
        let data = offJSON("""
        {"status":1,"product":{
          "product_name":"Tortilla Chips","brands":"Snack Co",
          "serving_quantity":28,"product_quantity":340,
          "nutriments":{"energy-kcal_serving":140,"proteins_serving":2,
            "carbohydrates_serving":19,"fat_serving":7}}}
        """)
        let food = try XCTUnwrap(BarcodeRead.food(fromProductJSON: data, code: "1"))
        XCTAssertEqual(food.items.first?.servingsInDish, 12)
        XCTAssertEqual(PlateShare.packageServings(food), 12)
        XCTAssertEqual(
            PlateShare.wholeDishNote(for: food),
            "one serving \u{00B7} this package holds about 12"
        )
    }

    func testASmallPackageNeverOffersMoreServingsThanItHolds() throws {
        // A two-serving pack. An instrument that can express "three
        // servings of a two-serving pack" is not honest about the package
        // it just read.
        let data = offJSON("""
        {"status":1,"product":{
          "product_name":"Yogurt","serving_quantity":150,
          "product_quantity":300,
          "nutriments":{"energy-kcal_serving":120,"proteins_serving":10}}}
        """)
        let food = try XCTUnwrap(BarcodeRead.food(fromProductJSON: data, code: "2"))
        XCTAssertEqual(PlateShare.maxFraction(for: food), 2.0)
        XCTAssertEqual(PlateShare.ladder(for: food).map(\.value), [2.0, 1.0, 0.5])
    }

    func testCommunityDataThatCannotBeTrustedMakesNoClaim() throws {
        // Open Food Facts is community-edited. A single-serving pack, a
        // missing package size, and a mis-keyed quantity must each
        // produce NO claim rather than a wrong one.
        let cases = [
            #""serving_quantity":30,"product_quantity":30"#,   // one serving
            #""serving_quantity":30"#,                          // no package size
            #""serving_quantity":0,"product_quantity":500"#,    // divide by zero
            #""serving_quantity":30,"product_quantity":9000"#,  // 300 servings
        ]
        for fields in cases {
            let data = offJSON("""
            {"status":1,"product":{"product_name":"Thing",\(fields),
              "nutriments":{"energy-kcal_serving":100,"energy-kcal_100g":300}}}
            """)
            let food = try XCTUnwrap(BarcodeRead.food(fromProductJSON: data, code: "3"))
            XCTAssertNil(PlateShare.packageServings(food), fields)
            // Still usable — it falls back to the generic ladder, never
            // to a fabricated package size.
            XCTAssertEqual(PlateShare.maxFraction(for: food), 3.0, fields)
        }
    }

    // MARK: - Accessibility

    func testEveryRungSpeaksItsWholeMeaning() {
        // The chips are the only control on the reading whose meaning is
        // entirely in its text, and the label is drawn as two typeface
        // runs — VoiceOver must get the sentence, not the fragments.
        let food = plate([
            item(name: "pizza", kcal: 2200, count: 8, unit: "slice",
                 servings: 8, shareable: true)
        ])
        for rung in PlateShare.ladder(for: food) {
            XCTAssertTrue(rung.voiceLabel.hasPrefix("ate "))
            XCTAssertTrue(rung.voiceLabel.count > 5, rung.voiceLabel)
        }
        XCTAssertEqual(
            PlateShare.ladder(for: food).map(\.voiceLabel).last, "ate 1 slice"
        )
    }
}
