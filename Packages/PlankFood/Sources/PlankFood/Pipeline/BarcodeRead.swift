import Foundation

// MARK: - BarcodeRead (v23 THE STILL LIFE §8)
//
// The barcode path: a code detected LIVE on the camera's video output
// resolves against Open Food Facts' product endpoint and lands in the
// SAME reading grammar as every other source. No invented nutrition,
// ever — a product without kcal data returns nil and the surface
// hands her to the label mode instead.
//
// Mapping honesty:
//   - per-SERVING values lead when OFF carries them with a serving
//     mass (the label's own portion);
//   - else per-100g with portionGrams = 100 (stated, steppable);
//   - sodium arrives in grams from OFF and converts to mg;
//   - `NutritionSource.openFoodFacts` tags provenance end-to-end.

public enum BarcodeRead {

    /// Fetch + map one barcode. Returns nil when OFF has no usable
    /// product (unknown code, or a product with no kcal data).
    public static func fetch(
        _ code: String,
        session: URLSession = .shared
    ) async throws -> CapturedFood? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json")
        else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("JeniFit-iOS/1.0", forHTTPHeaderField: "User-Agent")

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
        case 200: break
        case 404: return nil
        case 429: throw NutritionLookupError.rateLimited(source: .openFoodFacts)
        default:
            throw NutritionLookupError.upstreamFailure(source: .openFoodFacts, status: http.statusCode)
        }

        return food(fromProductJSON: data, code: trimmed)
    }

    /// Pure mapper — OFF product JSON → CapturedFood. Unit-tested
    /// against fixtures; returns nil rather than fabricating a number.
    public static func food(fromProductJSON data: Data, code: String) -> CapturedFood? {
        guard
            let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            (raw["status"] as? Int) == 1 || raw["product"] != nil,
            let product = raw["product"] as? [String: Any],
            let nutriments = product["nutriments"] as? [String: Any]
        else { return nil }

        let brand = (product["brands"] as? String)?
            .split(separator: ",").first.map(String.init)?
            .trimmingCharacters(in: .whitespaces)
        let baseName = (product["product_name"] as? String)?
            .trimmingCharacters(in: .whitespaces)
        let name: String
        switch (brand, baseName) {
        case let (b?, n?) where !b.isEmpty && !n.isEmpty
            && !n.lowercased().contains(b.lowercased()):
            name = "\(b) \(n)"
        case let (_, n?) where !n.isEmpty:
            name = n
        case let (b?, _) where !b.isEmpty:
            name = b
        default:
            return nil
        }

        // Per-serving leads when the label carries it with a mass.
        let servingQty = doubleValue(product["serving_quantity"])
        let kcalServing = doubleValue(nutriments["energy-kcal_serving"])
        let usePerServing = servingQty > 0 && kcalServing > 0

        func nutrient(_ key: String) -> Double? {
            let v = doubleValue(nutriments["\(key)_\(usePerServing ? "serving" : "100g")"])
            return v > 0 ? v : nil
        }

        let kcal = usePerServing ? kcalServing : doubleValue(nutriments["energy-kcal_100g"])
        guard kcal > 0 else { return nil }

        let grams = usePerServing ? servingQty : 100
        // OFF sodium is grams → mg.
        let sodiumMg = nutrient("sodium").map { $0 * 1000 }

        let item = CapturedItem(
            id: "barcode-\(code)",
            name: name.foodNameCleaned.lowercased(),
            portionGrams: grams,
            portionGramsLow: grams,
            portionGramsHigh: grams,
            usdaSearchTerms: [],
            preparation: nil,
            cuisineHint: nil,
            confidence: 1.0,
            notes: usePerServing ? "one serving, from the label" : "per 100g, from the label",
            kcal: kcal,
            proteinG: nutrient("proteins"),
            carbsG: nutrient("carbohydrates"),
            fatG: nutrient("fat"),
            fiberG: nutrient("fiber"),
            nutritionSource: .openFoodFacts,
            sugarG: nutrient("sugars"),
            sodiumMg: sodiumMg,
            saturatedFatG: nutrient("saturated-fat")
        )

        return CapturedFood(
            items: [item],
            plateType: .single,
            source: .barcode,
            confidence: 1.0,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: nil,
            kcalHigh: nil
        )
    }

    private static func doubleValue(_ raw: Any?) -> Double {
        if let d = raw as? Double { return d }
        if let i = raw as? Int { return Double(i) }
        if let s = raw as? String { return Double(s) ?? 0 }
        return 0
    }
}
