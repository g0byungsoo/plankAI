import Foundation

// MARK: - USDAClient
//
// REST adapter for USDA FoodData Central FDC API v1. Free tier;
// requires an API key (verified 2026-06-04: keyless requests return
// 403 API_KEY_MISSING). Rate limit 1,000 requests/hour per key.
//
// Docs: https://fdc.nal.usda.gov/api-guide.html

public struct USDAClient: Sendable {

    public struct Config: Sendable {
        public let apiKey: String
        public init(apiKey: String) {
            self.apiKey = apiKey
        }
    }

    private let config: Config
    private let session: URLSession

    public init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Search for foods matching the query. Returns the best-ranked
    /// result mapped to a NutritionLookupResult, or nil if no match.
    ///
    /// 2026-06-06 fix: USDA returns four dataTypes:
    ///   - **Foundation** — raw single-ingredient (Lemon, raw → 29 kcal/100g)
    ///   - **Survey (FNDDS)** — composite foods from dietary surveys
    ///   - **SR Legacy** — older standard reference
    ///   - **Branded** — manufacturer products (lemon-pepper seasoning,
    ///     lemonade mix, lemon meringue pie)
    ///
    /// Previously we trusted decoded.foods.first, which for a query like
    /// "lemon" hit a Branded result (founder screenshot: 360 kcal for
    /// 120g lemon — that was a lemon-pepper seasoning entry's 300 kcal/100g
    /// density propagated through CalorieMathService). Branded entries
    /// are correct nutrition for the SPECIFIC product but never what
    /// we want when the LLM identified a raw whole food.
    ///
    /// Two-layer fix:
    ///   1. API-level: dataType=Foundation,SR Legacy,Survey (FNDDS)
    ///      excludes Branded entirely. Branded would only be useful
    ///      when scanning a barcode, which v1.0.7 doesn't do.
    ///   2. Sort-order: within the remaining types, prefer Foundation
    ///      > Survey > SR Legacy so the rawest single-ingredient hit
    ///      wins regardless of USDA's relevance score.
    public func search(_ query: String) async throws -> NutritionLookupResult? {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "10"),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy,Survey (FNDDS)"),
            URLQueryItem(name: "api_key", value: config.apiKey),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NutritionLookupError.networkError(source: .usdaFDC, underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NutritionLookupError.parseError(source: .usdaFDC, detail: "non-HTTP")
        }

        switch http.statusCode {
        case 200:
            break  // fall through to parse
        case 429:
            throw NutritionLookupError.rateLimited(source: .usdaFDC)
        default:
            throw NutritionLookupError.upstreamFailure(source: .usdaFDC, status: http.statusCode)
        }

        let decoded: SearchResponse
        do {
            decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch {
            throw NutritionLookupError.parseError(source: .usdaFDC, detail: String(describing: error))
        }

        // Re-rank within the response: prefer Foundation > Survey
        // (FNDDS) > SR Legacy. The dataType field is decoded from the
        // wire response (added to SearchResponse.Food below).
        let ranked = decoded.foods.sorted { (a, b) in
            Self.dataTypeRank(a.dataType) < Self.dataTypeRank(b.dataType)
        }
        guard let top = ranked.first else { return nil }
        return Self.map(top)
    }

    /// Lower rank = preferred. Unknown types sink to the bottom.
    private static func dataTypeRank(_ type: String?) -> Int {
        switch type {
        case "Foundation":      return 0
        case "Survey (FNDDS)":  return 1
        case "SR Legacy":       return 2
        default:                return 99
        }
    }

    // MARK: - Mapping

    private static func map(_ food: SearchResponse.Food) -> NutritionLookupResult {
        // USDA returns nutrients per 100g for most foods. The nutrient
        // IDs we care about (per USDA's FDC nutrient ID catalog):
        //   1008 = Energy (kcal)
        //   1003 = Protein (g)
        //   1005 = Carbohydrates (g)
        //   1004 = Total lipid (fat) (g)
        //   1079 = Fiber, total dietary (g)
        //   2000 = Sugars, total (g)               ← 2026-06-05 added
        //   1093 = Sodium, Na (mg)                  ← 2026-06-05 added
        //   1258 = Fatty acids, total saturated (g) ← 2026-06-05 added
        var kcal: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var sugar: Double = 0
        var sodiumMg: Double = 0
        var saturatedFat: Double = 0

        for nutrient in food.foodNutrients {
            switch nutrient.nutrientId {
            case 1008: kcal = nutrient.value ?? 0
            case 1003: protein = nutrient.value ?? 0
            case 1005: carbs = nutrient.value ?? 0
            case 1004: fat = nutrient.value ?? 0
            case 1079: fiber = nutrient.value ?? 0
            case 2000: sugar = nutrient.value ?? 0
            case 1093: sodiumMg = nutrient.value ?? 0
            case 1258: saturatedFat = nutrient.value ?? 0
            default: break
            }
        }

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

        return NutritionLookupResult(
            density: density,
            source: .usdaFDC,
            sourceId: String(food.fdcId),
            cachedAt: Date(),
            displayName: food.description
        )
    }
}

// MARK: - Wire types

private struct SearchResponse: Decodable {
    let foods: [Food]

    struct Food: Decodable {
        let fdcId: Int
        let description: String
        let foodNutrients: [Nutrient]
        /// USDA's dataType field — "Foundation" / "Survey (FNDDS)" /
        /// "SR Legacy" / "Branded". Decoded so re-ranking can prefer
        /// raw single-ingredient results over packaged products.
        let dataType: String?
    }

    struct Nutrient: Decodable {
        let nutrientId: Int
        let value: Double?
    }
}
