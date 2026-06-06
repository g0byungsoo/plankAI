import Foundation

// MARK: - FoodVisionService
//
// HTTP client for the food-vision Supabase Edge Function. POSTs the
// captured JPEG + cuisine profile, gets back structured food data
// matching `FOOD_VISION_SCHEMA` from supabase/functions/food-vision/
// index.ts. Maps the response into the in-app `CapturedFood` shape.
//
// Per v3 §Honesty Doctrine: this service never returns kcal directly.
// `CapturedFood.items[].kcal` lands later when the USDA join completes
// (W2-T4 NutritionLookupService). For now, the result card renders
// item names + portion ranges + Jeni interpretation; kcal shows a
// loading state until the join lands.
//
// Why not in PlankApp: PlankFood owns the food rail pipeline. The
// service takes its config (URL, anon key, JWT provider) at init so
// it doesn't need to import the main app target (would cycle).

public final class FoodVisionService: Sendable {

    // MARK: - Config

    public struct Config: Sendable {
        public let supabaseURL: URL              // e.g. https://<ref>.supabase.co
        public let anonKey: String                // sb_publishable_* publishable key
        public let tokenProvider: @Sendable () async -> String?

        public init(
            supabaseURL: URL,
            anonKey: String,
            tokenProvider: @escaping @Sendable () async -> String?
        ) {
            self.supabaseURL = supabaseURL
            self.anonKey = anonKey
            self.tokenProvider = tokenProvider
        }
    }

    private let config: Config
    private let session: URLSession

    public init(
        config: Config,
        session: URLSession = .shared
    ) {
        self.config = config
        self.session = session
    }

    // MARK: - Scan

    /// POST the JPEG to /functions/v1/food-vision, decode the strict
    /// JSON response, map to CapturedFood.
    public func scan(
        imageData: Data,
        cuisineProfile: String?
    ) async throws -> CapturedFood {
        guard let token = await config.tokenProvider() else {
            throw VisionError.notAuthenticated
        }

        let url = config.supabaseURL.appendingPathComponent("functions/v1/food-vision")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // 2026-06-06 — bumped 30s → 90s. Founder hit chronic -1001
        // timeouts. GPT-5 hi-res image scan is typically 2-4s, but
        // the server-side pipeline may chain: Gemini Flash food-or-not
        // pre-filter → GPT-5 → Opus 4.7 confidence-gated fallback +
        // server-side nutrition lookup. A long chain plus cold-start
        // edge function plus mobile network variance can easily eat
        // the 30s budget. 90s gives the full chain headroom without
        // making the iOS shutter feel broken.
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")

        let body = ScanRequestBody(
            image_base64: imageData.base64EncodedString(),
            cuisine_profile: cuisineProfile
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw VisionError.networkError(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw VisionError.parseError(detail: "non-HTTP response")
        }

        switch http.statusCode {
        case 200:
            // fall through to decode
            break
        case 400:
            throw VisionError.invalidRequest(
                reason: Self.decodeErrorBody(data).message ?? "invalid request"
            )
        case 401:
            throw VisionError.notAuthenticated
        case 429:
            let err = Self.decodeErrorBody(data)
            let copy = err.copy ?? "give us a few hours."
            if err.code == "DAILY_BUDGET" {
                throw VisionError.budgetCapped(copy: copy)
            } else {
                throw VisionError.rateLimited(copy: copy)
            }
        default:
            // Pull the upstream detail out of the Edge Function's
            // error envelope so the iOS banner shows the real OpenAI
            // message (e.g. "insufficient_quota", "model_not_found")
            // instead of a generic 502.
            let err = Self.decodeErrorBody(data)
            throw VisionError.upstreamFailure(
                status: http.statusCode,
                detail: err.detail ?? err.message,
                code: err.code
            )
        }

        do {
            let decoded = try JSONDecoder().decode(VisionResponse.self, from: data)
            return Self.map(decoded)
        } catch {
            throw VisionError.parseError(detail: "decode failed: \(error)")
        }
    }

    // MARK: - Mapping

    private static func map(
        _ response: VisionResponse
    ) -> CapturedFood {
        let items = response.items.map { item in
            CapturedItem(
                id: UUID().uuidString,
                name: item.name,
                portionGrams: item.portion_grams,
                portionGramsLow: item.portion_grams_low,
                portionGramsHigh: item.portion_grams_high,
                usdaSearchTerms: item.usda_search_terms,
                preparation: item.preparation.isEmpty ? nil : item.preparation,
                cuisineHint: item.cuisine_hint.isEmpty ? nil : item.cuisine_hint,
                confidence: item.confidence,
                notes: item.notes.isEmpty ? nil : item.notes,
                // W2-T4 fills these from USDA + Open Food Facts join.
                kcal: nil,
                proteinG: nil,
                carbsG: nil,
                fatG: nil,
                fiberG: nil,
                nutritionSource: nil
            )
        }

        let plateType = PlateType(rawValue: response.plate_type) ?? .single

        // CapturedFood.confidence is the MIN across items (the weakest
        // link drives result-card UX — when one item is uncertain, the
        // whole scan shows the "fix something" affordance).
        let minConfidence = items.compactMap { $0.confidence }.min()

        return CapturedFood(
            items: items,
            plateType: plateType,
            source: .photo,
            confidence: minConfidence,
            needsSecondPhoto: response.needs_second_photo,
            secondPhotoHint: response.needs_second_photo
                ? response.second_photo_hint
                : nil,
            kcalLow: nil,
            kcalHigh: nil
        )
    }

    // MARK: - Error body decoder

    private static func decodeErrorBody(_ data: Data) -> ErrorBody {
        (try? JSONDecoder().decode(ErrorBody.self, from: data)) ?? ErrorBody()
    }
}

// MARK: - Wire types

/// Request body shape. Field names match the Edge Function's expected
/// JSON keys (snake_case for Python/JS interop tradition).
private struct ScanRequestBody: Encodable {
    let image_base64: String
    let cuisine_profile: String?
}

/// Response body shape. Mirrors `FOOD_VISION_SCHEMA` in
/// supabase/functions/food-vision/index.ts. Coding keys match the
/// schema's field names exactly (snake_case). Renaming any field on
/// either side will fail decoding silently — every Decodable field
/// is required, so JSONDecoder throws on missing keys.
private struct VisionResponse: Decodable {
    let items: [Item]
    let plate_type: String
    let needs_second_photo: Bool
    let second_photo_hint: String
    let _meta: Meta?

    struct Item: Decodable {
        let name: String
        let usda_search_terms: [String]
        let preparation: String
        let cuisine_hint: String
        let portion_grams: Double
        let portion_grams_low: Double
        let portion_grams_high: Double
        let confidence: Double
        let notes: String
    }

    struct Meta: Decodable {
        let cost_usd: Double?
        let model: String?
        let duration_ms: Int?
        let scan_id: String?
    }
}

/// Error body shape — the Edge Function's 4xx + 5xx responses all
/// return { error, code?, copy?, detail? } in some combination.
private struct ErrorBody: Decodable {
    var error: String?
    var code: String?
    var copy: String?
    var detail: String?
    var message: String?  // some endpoints use 'message' instead of 'detail'
}

// MARK: - VisionError

public enum VisionError: Error, Sendable {
    case notAuthenticated
    case rateLimited(copy: String)                                    // 429 PER_USER_LIMIT
    case budgetCapped(copy: String)                                    // 429 DAILY_BUDGET
    case invalidRequest(reason: String)                                // 400
    case upstreamFailure(status: Int, detail: String?, code: String?) // 5xx or unexpected
    case parseError(detail: String)
    case networkError(underlying: Error)

    /// User-facing copy following v5 voice locks (lowercase casual,
    /// no diet-culture vocab, anti-shame). Falls through to a generic
    /// soft prompt for unexpected cases.
    public var userFacingCopy: String {
        switch self {
        case .notAuthenticated:
            return "sign in first, then we'll read your plate."
        case .rateLimited(let copy):
            return copy
        case .budgetCapped(let copy):
            return copy
        case .invalidRequest:
            return "something looked off with the photo. try once more?"
        case .upstreamFailure(_, _, let code):
            if code == "openai_quota" {
                return "we've hit our scan limit for now. try again in a few."
            }
            return "couldn't reach us just now. try again in a moment."
        case .parseError:
            return "got a weird answer back. try again?"
        case .networkError:
            return "no signal — give it another try when you're back online."
        }
    }
}
