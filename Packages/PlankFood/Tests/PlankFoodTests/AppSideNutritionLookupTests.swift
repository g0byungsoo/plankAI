import XCTest
@testable import PlankFood

final class AppSideNutritionLookupTests: XCTestCase {

    // MARK: - Fixtures

    private let matchaLatte = CalorieMathService.NutritionDensity(
        kcalPer100g: 60,
        proteinPer100g: 1.5,
        carbsPer100g: 8.0,
        fatPer100g: 2.4,
        fiberPer100g: 0.2
    )

    private let usdaResult = NutritionLookupResult(
        density: CalorieMathService.NutritionDensity(kcalPer100g: 50),
        source: .usdaFDC,
        sourceId: "12345",
        cachedAt: Date(),
        displayName: "Latte, with whole milk"
    )

    private let pantryResult = NutritionLookupResult(
        density: CalorieMathService.NutritionDensity(kcalPer100g: 60),
        source: .canonicalPantry,
        sourceId: "matcha-latte-oat-m",
        cachedAt: Date(),
        displayName: "matcha latte (oat, medium)"
    )

    private let offResult = NutritionLookupResult(
        density: CalorieMathService.NutritionDensity(kcalPer100g: 55),
        source: .openFoodFacts,
        sourceId: "1234567890",
        cachedAt: Date(),
        displayName: "Generic matcha latte"
    )

    // MARK: - Codable round-trip

    func testNutritionLookupResultRoundTripsThroughJSON() throws {
        let encoded = try JSONEncoder().encode(pantryResult)
        let decoded = try JSONDecoder().decode(NutritionLookupResult.self, from: encoded)
        XCTAssertEqual(decoded, pantryResult)
    }

    // MARK: - TTL / staleness

    func testCanonicalPantryHasInfiniteTTL() {
        XCTAssertTrue(pantryResult.ttl.isInfinite)
    }

    func testUSDAHas90DayTTL() {
        XCTAssertEqual(usdaResult.ttl, 90 * 86_400)
    }

    func testOpenFoodFactsHas30DayTTL() {
        XCTAssertEqual(offResult.ttl, 30 * 86_400)
    }

    func testFreshResultIsNotStale() {
        let result = NutritionLookupResult(
            density: matchaLatte,
            source: .usdaFDC,
            sourceId: "1",
            cachedAt: Date().addingTimeInterval(-86_400),  // 1 day ago
            displayName: "fresh"
        )
        XCTAssertFalse(result.isStale())
    }

    func testStaleResultIsStale() {
        let result = NutritionLookupResult(
            density: matchaLatte,
            source: .usdaFDC,
            sourceId: "1",
            cachedAt: Date().addingTimeInterval(-100 * 86_400),  // 100 days
            displayName: "stale"
        )
        XCTAssertTrue(result.isStale())
    }

    func testCanonicalPantryIsNeverStale() {
        let ancient = NutritionLookupResult(
            density: matchaLatte,
            source: .canonicalPantry,
            sourceId: "1",
            cachedAt: Date().addingTimeInterval(-10_000 * 86_400),  // 27 years ago
            displayName: "ancient pantry"
        )
        XCTAssertFalse(ancient.isStale(), "pantry entries are curated; never stale")
    }

    // MARK: - NutritionCache

    func testCacheGetMissReturnsNil() {
        let cache = NutritionCache()
        XCTAssertNil(cache.get("missing-key"))
    }

    func testCacheRoundTrip() {
        let cache = NutritionCache()
        cache.set("test-key", pantryResult)
        XCTAssertEqual(cache.get("test-key"), pantryResult)
    }

    func testCacheRemove() {
        let cache = NutritionCache()
        cache.set("k", pantryResult)
        cache.remove("k")
        XCTAssertNil(cache.get("k"))
    }

    func testCacheClear() {
        let cache = NutritionCache()
        cache.set("a", pantryResult)
        cache.set("b", usdaResult)
        cache.clear()
        XCTAssertNil(cache.get("a"))
        XCTAssertNil(cache.get("b"))
    }

    func testCacheKeyConventions() {
        XCTAssertEqual(NutritionCache.usdaKey(fdcId: 12345), "usda_fdc:12345")
        XCTAssertEqual(NutritionCache.offKey(barcodeOrHash: "abc"), "off:abc")
        XCTAssertEqual(NutritionCache.pantryKey(slug: "matcha"), "pantry:matcha")
    }

    // MARK: - Source priority via mock service

    /// Mock NutritionLookupService for testing dispatcher enrichment
    /// without spinning up actual USDA / OFF / pantry clients.
    final class MockLookup: NutritionLookupService, @unchecked Sendable {
        var stubbed: [NutritionLookupResult?] = []
        var receivedQueries: [NutritionQuery] = []

        func lookup(_ queries: [NutritionQuery]) async -> [NutritionLookupResult?] {
            receivedQueries = queries
            // Pad to match queries.count
            var result = stubbed
            while result.count < queries.count { result.append(nil) }
            return result
        }
    }

    // MARK: - Dispatcher enrichment

    @MainActor
    func testDispatcherEnrichesItemsWithLookupResults() async {
        let mock = MockLookup()
        mock.stubbed = [pantryResult]

        let item = CapturedItem(
            id: "1",
            name: "matcha latte",
            portionGrams: 350,
            portionGramsLow: 300,
            portionGramsHigh: 400,
            usdaSearchTerms: ["matcha latte"],
            preparation: nil,
            cuisineHint: "japanese",
            confidence: 0.92,
            notes: nil,
            kcal: nil,  // ← starts nil
            proteinG: nil,
            carbsG: nil,
            fatG: nil,
            fiberG: nil,
            nutritionSource: nil
        )
        let identified = CapturedFood(
            items: [item],
            plateType: .single,
            source: .photo,
            confidence: 0.92,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )

        let enriched = await FoodCaptureDispatcher.enrich(identified, using: mock)

        XCTAssertEqual(enriched.items.count, 1)
        // 350g × 60 kcal/100g = 210 kcal
        XCTAssertEqual(enriched.items[0].kcal!, 210, accuracy: 0.5)
        XCTAssertEqual(enriched.items[0].nutritionSource, .canonicalPantry)
        // Original fields preserved
        XCTAssertEqual(enriched.items[0].name, "matcha latte")
        XCTAssertEqual(enriched.items[0].usdaSearchTerms, ["matcha latte"])
    }

    @MainActor
    func testDispatcherKeepsItemsKcalNilWhenLookupReturnsNil() async {
        let mock = MockLookup()
        mock.stubbed = [nil]  // lookup miss

        let item = CapturedItem(
            id: "1",
            name: "exotic dish",
            portionGrams: 200,
            portionGramsLow: 200,
            portionGramsHigh: 200,
            usdaSearchTerms: ["something unrecognized"],
            preparation: nil,
            cuisineHint: nil,
            confidence: 0.7,
            notes: nil,
            kcal: nil,
            proteinG: nil,
            carbsG: nil,
            fatG: nil,
            fiberG: nil,
            nutritionSource: nil
        )
        let identified = CapturedFood(
            items: [item],
            plateType: .single,
            source: .photo,
            confidence: 0.7,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )

        let enriched = await FoodCaptureDispatcher.enrich(identified, using: mock)

        XCTAssertNil(enriched.items[0].kcal,
                     "lookup miss should leave kcal nil for UI 'couldn't ID' state")
        XCTAssertNil(enriched.items[0].nutritionSource)
    }

    @MainActor
    func testDispatcherReturnsIdentifiedUnchangedWhenLookupNotConfigured() async {
        let identified = CapturedFood(
            items: [],
            plateType: .single,
            source: .photo,
            confidence: nil,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )

        let result = await FoodCaptureDispatcher.enrich(identified, using: nil)
        // Should pass through (no lookup = same items)
        XCTAssertEqual(result.items.count, 0)
    }

    @MainActor
    func testDispatcherIsolatesPerItemLookupFailures() async {
        let mock = MockLookup()
        mock.stubbed = [pantryResult, nil, pantryResult]  // middle item fails

        let items = (0..<3).map { i in
            CapturedItem(
                id: "\(i)", name: "item\(i)",
                portionGrams: 100, portionGramsLow: 100, portionGramsHigh: 100,
                usdaSearchTerms: ["item"], preparation: nil, cuisineHint: nil,
                confidence: 0.8, notes: nil,
                kcal: nil, proteinG: nil, carbsG: nil, fatG: nil, fiberG: nil,
                nutritionSource: nil
            )
        }
        let identified = CapturedFood(
            items: items,
            plateType: .mixed,
            source: .photo,
            confidence: 0.8,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )

        let enriched = await FoodCaptureDispatcher.enrich(identified, using: mock)

        XCTAssertNotNil(enriched.items[0].kcal)
        XCTAssertNil(enriched.items[1].kcal,
                     "middle item should keep nil — failure is per-item, not per-batch")
        XCTAssertNotNil(enriched.items[2].kcal)
    }
}
