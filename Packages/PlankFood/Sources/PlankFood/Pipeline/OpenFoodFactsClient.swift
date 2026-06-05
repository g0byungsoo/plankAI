import Foundation

// MARK: - OpenFoodFactsClient
//
// REST adapter for Open Food Facts. No auth required. Community-
// edited, US coverage is patchy but improving. Used as second-tier
// fallback after USDA FDC misses.
//
// Docs: https://wiki.openfoodfacts.org/API
//
// API quirk: nutrient field names use hyphens in JSON
// (`energy-kcal_100g`), which Codable doesn't handle natively without
// CodingKeys. We use a manual decode path below.

public struct OpenFoodFactsClient: Sendable {

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Search the OFF database by text. Returns the top product's
    /// nutrition density per 100g, or nil if no products matched.
    public func search(_ query: String) async throws -> NutritionLookupResult? {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "5"),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("JeniFit-iOS/1.0", forHTTPHeaderField: "User-Agent")
        // OFF is unhappy with anonymous requests at scale — adding a
        // UA identifier per their API etiquette docs.

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NutritionLookupError.networkError(source: .openFoodFacts, underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NutritionLookupError.parseError(source: .openFoodFacts, detail: "non-HTTP")
        }

        switch http.statusCode {
        case 200:
            break
        case 429:
            throw NutritionLookupError.rateLimited(source: .openFoodFacts)
        default:
            throw NutritionLookupError.upstreamFailure(source: .openFoodFacts, status: http.statusCode)
        }

        // OFF's response shape is loose: products[].nutriments has
        // optional energy-kcal_100g, proteins_100g, etc. Use
        // JSONSerialization rather than Codable to handle the hyphenated
        // keys + frequent missing fields without a custom decoder per
        // field name.
        guard
            let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let products = raw["products"] as? [[String: Any]],
            let first = products.first
        else {
            return nil
        }

        guard let nutriments = first["nutriments"] as? [String: Any] else {
            return nil
        }

        let kcal = Self.doubleValue(nutriments["energy-kcal_100g"])
        let protein = Self.doubleValue(nutriments["proteins_100g"])
        let carbs = Self.doubleValue(nutriments["carbohydrates_100g"])
        let fat = Self.doubleValue(nutriments["fat_100g"])
        let fiber = Self.doubleValue(nutriments["fiber_100g"])
        // 2026-06-05 — extra nutrients per founder feedback.
        // OFF's `sodium_100g` is in grams; convert to mg for unit
        // consistency with USDA + the canonical_pantry column shape.
        let sugar = Self.doubleValue(nutriments["sugars_100g"])
        let sodiumMg = Self.doubleValue(nutriments["sodium_100g"]) * 1000
        let saturatedFat = Self.doubleValue(nutriments["saturated-fat_100g"])

        // If we don't have kcal, the entry is useless. Bail.
        guard kcal > 0 else { return nil }

        let density = CalorieMathService.NutritionDensity(
            kcalPer100g: kcal,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            fiberPer100g: fiber,
            sugarPer100g: sugar,
            sodiumMgPer100g: sodiumMg,
            saturatedFatPer100g: saturatedFat
        )

        let code = (first["code"] as? String) ?? (first["_id"] as? String) ?? "off-\(query.hashValue)"
        let name = (first["product_name"] as? String)
            ?? (first["generic_name"] as? String)
            ?? query

        return NutritionLookupResult(
            density: density,
            source: .openFoodFacts,
            sourceId: code,
            cachedAt: Date(),
            displayName: name
        )
    }

    // MARK: - Helpers

    private static func doubleValue(_ raw: Any?) -> Double {
        if let d = raw as? Double { return d }
        if let i = raw as? Int { return Double(i) }
        if let s = raw as? String { return Double(s) ?? 0 }
        return 0
    }
}
