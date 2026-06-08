import Foundation

// MARK: - FoodVisionService
//
// HTTP client for the food-vision Supabase Edge Function. POSTs the
// captured JPEG + cuisine profile, gets back structured food data
// matching `FOOD_VISION_SCHEMA` from supabase/functions/food-vision/
// index.ts. Maps the response into the in-app `CapturedFood` shape.
//
// v1.0.7 direct-kcal rewrite (2026-06-07): the Edge Function now
// returns kcal + macros directly per item, plus plate-level total
// bounds. The Honesty Doctrine — which had this service return only
// portion grams + USDA search terms, with kcal filled in by a USDA
// join later — is retired. `CapturedItem.kcal` is populated inline
// from the LLM response and tagged `.llmDirect`. The USDA fallback
// path still exists for legacy responses where `kcal == nil` and
// for the low-confidence calibration sweep in `FoodCaptureDispatcher
// .enrich` (items with confidence < 0.5 get a USDA sanity check).
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
        session: URLSession? = nil
    ) {
        self.config = config
        self.session = session ?? Self.defaultVisionSession
    }

    /// v1.0.8 Phase R.8 (2026-06-08) — dedicated URLSession for the
    /// food-vision EF call. URLSession.shared has a 60s
    /// timeoutIntervalForRequest that the per-request timeoutInterval
    /// can't override reliably on iOS — the founder's logs showed
    /// chronic -1001 timeouts at ~37s even with request.timeoutInterval
    /// set to 90s.
    ///
    /// This session sets a 180s request + resource timeout to give
    /// the EF a real budget (Gemini pre-filter → GPT-5 vision → USDA
    /// join can chain into 60-90s under load; cold-start adds more).
    /// waitsForConnectivity = true also defers requests gracefully if
    /// the device drops to no-network momentarily (common on TikTok
    /// → app handoff with weak signal).
    private static let defaultVisionSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 180
        cfg.timeoutIntervalForResource = 180
        cfg.waitsForConnectivity = true
        cfg.allowsCellularAccess = true
        return URLSession(configuration: cfg)
    }()

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
        // 2026-06-06 — bumped 30s → 90s.
        // 2026-06-08 (Phase R.8) — bumped 90s → 180s + matched to the
        // dedicated visionSession's `timeoutIntervalForRequest`. The
        // request-level value alone doesn't override URLSession.shared
        // on iOS reliably; both have to match. See `defaultVisionSession`.
        request.timeoutInterval = 180
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
        let items = response.items.map { item -> CapturedItem in
            // v1.0.7 direct-kcal: trust LLM output. The hybrid
            // calibration sweep in FoodCaptureDispatcher.enrich
            // optionally upgrades low-confidence items to
            // `.usdaCalibrated` / `.usdaOverride`. High-confidence
            // items stay `.llmDirect` and skip the USDA round-trip.
            //
            // Legacy fallback: if the EF returns kcal == nil (e.g.
            // FOOD_VISION_MODEL secret was rolled back to gpt-4o
            // mid-flight or the model under-filled the schema), the
            // dispatcher's enrich path runs the full USDA join.

            // Hoist Optional<Int> → Optional<Double> conversions out
            // of the init call — Swift's type checker times out on
            // 6+ chained `.map { Double($0) }` calls inside a single
            // expression.
            let kcalDouble: Double? = item.kcal.map(Double.init)
            let proteinDouble: Double? = item.protein_g.map(Double.init)
            let carbsDouble: Double? = item.carbs_g.map(Double.init)
            let fatDouble: Double? = item.fat_g.map(Double.init)
            let fiberDouble: Double? = item.fiber_g.map(Double.init)
            let source: NutritionSource? = (kcalDouble != nil) ? .llmDirect : nil

            // EF no longer requires usda_search_terms (dropped from
            // the schema in the direct-kcal rewrite). Fall back to
            // [item.name] so the calibration sweep has a search seed
            // when confidence < 0.5.
            let searchTerms: [String] = item.usda_search_terms
                ?? (item.name.isEmpty ? [] : [item.name])

            return CapturedItem(
                id: UUID().uuidString,
                name: item.name,
                portionGrams: item.portion_grams,
                portionGramsLow: item.portion_grams_low,
                portionGramsHigh: item.portion_grams_high,
                usdaSearchTerms: searchTerms,
                preparation: item.preparation.isEmpty ? nil : item.preparation,
                cuisineHint: item.cuisine_hint.isEmpty ? nil : item.cuisine_hint,
                confidence: item.confidence,
                notes: item.notes.isEmpty ? nil : item.notes,
                kcal: kcalDouble,
                proteinG: proteinDouble,
                carbsG: carbsDouble,
                fatG: fatDouble,
                fiberG: fiberDouble,
                nutritionSource: source
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
            kcalLow: response.total_kcal_low.map { Double($0) },
            kcalHigh: response.total_kcal_high.map { Double($0) }
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
/// supabase/functions/food-vision/index.ts.
///
/// v1.0.7 (2026-06-07): direct-kcal rewrite. The schema added kcal +
/// macros at the item level and total_kcal_low/high at the plate
/// level, and dropped usda_search_terms from the required item
/// fields. To keep iOS backwards-compatible with legacy responses
/// (gpt-4o secret override, partial rollback, mid-flight model swap
/// where the EF gets re-deployed before the iOS bundle does), every
/// new field is Optional and the dropped field stays Optional.
/// JSONDecoder will accept either schema shape.
private struct VisionResponse: Decodable {
    let items: [Item]
    let plate_type: String
    let needs_second_photo: Bool
    let second_photo_hint: String
    /// v1.0.7 plate-level total bounds. Optional for backwards
    /// compatibility with the legacy Honesty Doctrine schema.
    let total_kcal_low: Int?
    let total_kcal_high: Int?
    let _meta: Meta?

    struct Item: Decodable {
        let name: String
        /// Optional in v1.0.7+ (LLM direct-kcal path doesn't need
        /// it). Used by the FoodCaptureDispatcher.enrich
        /// calibration sweep for low-confidence items; falls back
        /// to [name] when absent.
        let usda_search_terms: [String]?
        let preparation: String
        let cuisine_hint: String
        let portion_grams: Double
        let portion_grams_low: Double
        let portion_grams_high: Double
        /// v1.0.7+ direct-kcal fields. All Optional so iOS can keep
        /// decoding legacy gpt-4o-style responses that omit them.
        let kcal: Int?
        let kcal_low: Int?
        let kcal_high: Int?
        let protein_g: Int?
        let carbs_g: Int?
        let fat_g: Int?
        let fiber_g: Int?
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

public enum VisionError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case rateLimited(copy: String)                                    // 429 PER_USER_LIMIT
    case budgetCapped(copy: String)                                    // 429 DAILY_BUDGET
    case invalidRequest(reason: String)                                // 400
    case upstreamFailure(status: Int, detail: String?, code: String?) // 5xx or unexpected
    case parseError(detail: String)
    case networkError(underlying: Error)

    /// LocalizedError bridge — uses the voice-locked userFacingCopy
    /// for system bridging so NSError.localizedDescription returns
    /// friendly copy instead of "(PlankFood.VisionError error N.)".
    public var errorDescription: String? { userFacingCopy }

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
