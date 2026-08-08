import XCTest
@testable import PlankFood

// v23 §8 — the barcode mapper's honesty pins. OFF product JSON →
// CapturedFood with per-serving preferred, per-100g fallback, sodium
// g→mg, and nil (never a fabricated number) when kcal is absent.
final class BarcodeReadTests: XCTestCase {

    private func json(_ s: String) -> Data { Data(s.utf8) }

    func testPerServingLeadsWhenLabelCarriesIt() throws {
        let data = json("""
        {"status":1,"product":{
          "product_name":"Peanut Butter",
          "brands":"Crunchy Co, Other",
          "serving_quantity":32,
          "nutriments":{
            "energy-kcal_serving":190,"proteins_serving":8,
            "carbohydrates_serving":7,"fat_serving":16,
            "fiber_serving":2,"sugars_serving":3,
            "sodium_serving":0.14,"saturated-fat_serving":3,
            "energy-kcal_100g":594}}}
        """)
        let food = try XCTUnwrap(BarcodeRead.food(fromProductJSON: data, code: "0123"))
        XCTAssertEqual(food.source, .barcode)
        let item = try XCTUnwrap(food.items.first)
        XCTAssertEqual(item.name, "crunchy co peanut butter")
        XCTAssertEqual(item.portionGrams, 32)
        XCTAssertEqual(item.kcal, 190)
        XCTAssertEqual(item.proteinG, 8)
        XCTAssertEqual(item.sodiumMg ?? 0, 140, accuracy: 0.001)
        XCTAssertEqual(item.nutritionSource, .openFoodFacts)
        XCTAssertEqual(food.totalKcal, 190)
    }

    func testPer100gFallbackWhenNoServingData() throws {
        let data = json("""
        {"status":1,"product":{
          "product_name":"Sparkling Water Cola",
          "nutriments":{
            "energy-kcal_100g":42,"proteins_100g":0,
            "carbohydrates_100g":10.6,"sugars_100g":10.6,
            "sodium_100g":0.01}}}
        """)
        let food = try XCTUnwrap(BarcodeRead.food(fromProductJSON: data, code: "0456"))
        let item = try XCTUnwrap(food.items.first)
        XCTAssertEqual(item.portionGrams, 100)
        XCTAssertEqual(item.kcal, 42)
        // Zero values stay nil — "not stated" never becomes a number.
        XCTAssertNil(item.proteinG)
        XCTAssertEqual(item.sodiumMg ?? 0, 10, accuracy: 0.001)
    }

    func testNoKcalMeansNoFood() {
        let data = json("""
        {"status":1,"product":{
          "product_name":"Mystery Item",
          "nutriments":{"proteins_100g":5}}}
        """)
        XCTAssertNil(BarcodeRead.food(fromProductJSON: data, code: "0789"))
    }

    func testUnknownProductMeansNil() {
        let data = json("""
        {"status":0,"status_verbose":"product not found"}
        """)
        XCTAssertNil(BarcodeRead.food(fromProductJSON: data, code: "0000"))
    }

    func testBrandNotDuplicatedWhenNameCarriesIt() throws {
        let data = json("""
        {"status":1,"product":{
          "product_name":"Chobani Greek Yogurt",
          "brands":"Chobani",
          "nutriments":{"energy-kcal_100g":97,"proteins_100g":9}}}
        """)
        let food = try XCTUnwrap(BarcodeRead.food(fromProductJSON: data, code: "0111"))
        XCTAssertEqual(food.items.first?.name, "chobani greek yogurt")
    }
}
