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

    /// Search for foods matching the query. Returns the highest-score
    /// result mapped to a NutritionLookupResult, or nil if no match.
    public func search(_ query: String) async throws -> NutritionLookupResult? {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "5"),
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

        guard let top = decoded.foods.first else { return nil }
        return Self.map(top)
    }

    // MARK: - Mapping

    private static func map(_ food: SearchResponse.Food) -> NutritionLookupResult {
        // USDA returns nutrients per 100g for most foods. The nutrient
        // IDs we care about:
        //   1008 = Energy (kcal)
        //   1003 = Protein (g)
        //   1005 = Carbohydrates (g)
        //   1004 = Total lipid (fat) (g)
        //   1079 = Fiber, total dietary (g)
        var kcal: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0

        for nutrient in food.foodNutrients {
            switch nutrient.nutrientId {
            case 1008: kcal = nutrient.value ?? 0
            case 1003: protein = nutrient.value ?? 0
            case 1005: carbs = nutrient.value ?? 0
            case 1004: fat = nutrient.value ?? 0
            case 1079: fiber = nutrient.value ?? 0
            default: break
            }
        }

        let density = CalorieMathService.NutritionDensity(
            kcalPer100g: kcal,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            fiberPer100g: fiber
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
    }

    struct Nutrient: Decodable {
        let nutrientId: Int
        let value: Double?
    }
}
