import Foundation

// MARK: - CanonicalPantryClient
//
// Queries the `public.canonical_pantry` table in Supabase via the
// PostgREST API. We hand-curate this table with ~100 cohort-specific
// entries (matcha latte, oat milk latte, brown sugar boba, etc.)
// that USDA / Open Food Facts miss or get wrong. This source ranks
// highest in the parallel resolver — pantry > USDA > OFF.
//
// PostgREST query syntax:
//   ?search_terms=ov.{matcha,latte}  → row's search_terms array
//                                       overlaps with [matcha, latte]
//
// Two headers required:
//   apikey: <anon_key>            — publishable Supabase key
//   Authorization: Bearer <jwt>   — current user's session
//
// Edge case: a query like "creamy carbonara" probably misses every
// pantry entry. That's by design — pantry is the cohort-fit safety
// net for staples (boba, matcha, oat milk lattes), not a complete
// food DB. Missed queries fall through to USDA / OFF.

public struct CanonicalPantryClient: Sendable {

    public struct Config: Sendable {
        public let supabaseURL: URL
        public let anonKey: String
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

    public init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Look up a single canonical_pantry row matching the LLM's search
    /// terms. Returns nil if no row overlaps with any term.
    public func search(_ terms: [String]) async throws -> NutritionLookupResult? {
        guard !terms.isEmpty else { return nil }
        guard let token = await config.tokenProvider() else {
            // No auth = no row reads via RLS-gated table. Silent nil
            // is the safe fallback; lookup falls through to USDA.
            return nil
        }

        // PostgREST array-overlap syntax: ?search_terms=ov.{a,b,c}
        // Quote each term to handle spaces.
        let formatted = terms
            .map { $0.replacingOccurrences(of: ",", with: "") }
            .map { "\"\($0)\"" }
            .joined(separator: ",")

        var components = URLComponents(
            url: config.supabaseURL.appendingPathComponent("rest/v1/canonical_pantry"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: "ov.{\(formatted)}"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit", value: "1"),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NutritionLookupError.networkError(
                source: .canonicalPantry,
                underlying: error
            )
        }

        guard let http = response as? HTTPURLResponse else {
            throw NutritionLookupError.parseError(source: .canonicalPantry, detail: "non-HTTP")
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            // Auth issues — treat as no match (silent), don't error.
            // The user is probably in a transient auth state; USDA
            // and OFF will still serve.
            return nil
        default:
            throw NutritionLookupError.upstreamFailure(
                source: .canonicalPantry,
                status: http.statusCode
            )
        }

        let decoded: [PantryRow]
        do {
            decoded = try JSONDecoder().decode([PantryRow].self, from: data)
        } catch {
            throw NutritionLookupError.parseError(
                source: .canonicalPantry,
                detail: String(describing: error)
            )
        }

        guard let row = decoded.first else { return nil }

        let density = CalorieMathService.NutritionDensity(
            kcalPer100g: row.kcal_per_100g,
            proteinPer100g: row.protein_per_100g,
            carbsPer100g: row.carbs_per_100g,
            fatPer100g: row.fat_per_100g,
            fiberPer100g: row.fiber_per_100g ?? 0
        )

        return NutritionLookupResult(
            density: density,
            source: .canonicalPantry,
            sourceId: row.id,
            cachedAt: Date(),
            displayName: row.name
        )
    }
}

// MARK: - Wire types

private struct PantryRow: Decodable {
    let id: String
    let name: String
    let kcal_per_100g: Double
    let protein_per_100g: Double
    let carbs_per_100g: Double
    let fat_per_100g: Double
    let fiber_per_100g: Double?
}
