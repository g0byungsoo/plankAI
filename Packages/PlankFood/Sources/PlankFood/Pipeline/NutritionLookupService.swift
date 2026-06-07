import Foundation

// MARK: - NutritionLookupService
//
// Protocol abstraction over the per-item nutrition density lookup.
// Concrete implementation in `AppSideNutritionLookup` (Option A per
// W2-T4 architect decision). When migration triggers fire in the
// future (USDA error rate >2% / 7d, P75 latency >1.2s / 7d, or paid
// users >2k), a second `EdgeFunctionNutritionLookup` implementation
// drops in here without touching call sites.
//
// Contract: take an array of search queries (one per CapturedItem),
// return the same length array of optional NutritionLookupResult
// (nil = no source could resolve this item, UI shows "couldn't ID
// this" placeholder).

public protocol NutritionLookupService: Sendable {
    /// Look up nutrition density for a batch of items in parallel.
    /// Returns an array the same length as `queries`; index alignment
    /// is the call-site contract (queries[i] -> results[i]).
    /// Failures per item are isolated — one item's USDA timeout
    /// doesn't fail the whole batch.
    func lookup(_ queries: [NutritionQuery]) async -> [NutritionLookupResult?]
}

// MARK: - NutritionQuery

/// What a CapturedItem hands to the lookup service. Multiple search
/// terms ordered specific → generic (e.g. ["oat milk matcha latte",
/// "matcha latte", "green tea latte"]) lets the resolver try each
/// against each source.
public struct NutritionQuery: Sendable, Equatable {
    public let itemName: String
    public let usdaSearchTerms: [String]
    public let cuisineHint: String?

    public init(
        itemName: String,
        usdaSearchTerms: [String],
        cuisineHint: String? = nil
    ) {
        self.itemName = itemName
        self.usdaSearchTerms = usdaSearchTerms
        self.cuisineHint = cuisineHint
    }
}

// MARK: - NutritionLookupResult
//
// LOAD-BEARING SHAPE per architect's review. These fields ship in
// food_log_items table rows from v1.0.7 onward. Adding fields is
// fine; renaming or removing requires a migration.
//
// Fields:
//   - density: per-100g math inputs (consumed by CalorieMathService.compute)
//   - source: which DB answered (drives the "fix something" UI affordance)
//   - sourceId: the upstream ID (USDA fdcId, OFF barcode, pantry UUID)
//   - cachedAt: when this entry was first fetched (drives stale-while-
//     revalidate refresh logic)
//   - displayName: the canonical matched food name (USDA's "Latte, with
//     whole milk" or OFF's "Matcha Latte" — preserved so the UI can
//     show what we matched against)

public struct NutritionLookupResult: Sendable, Codable, Equatable {
    public let density: CalorieMathService.NutritionDensity
    public let source: NutritionSource
    public let sourceId: String
    public let cachedAt: Date
    public let displayName: String

    public init(
        density: CalorieMathService.NutritionDensity,
        source: NutritionSource,
        sourceId: String,
        cachedAt: Date,
        displayName: String
    ) {
        self.density = density
        self.source = source
        self.sourceId = sourceId
        self.cachedAt = cachedAt
        self.displayName = displayName
    }

    /// Per architect: stale-while-revalidate TTLs by source.
    ///   - canonical_pantry: infinite (we curate it, so it can't go stale)
    ///   - USDA FDC: 90 days (USDA updates are infrequent + the data is
    ///     stable for whole-food entries)
    ///   - Open Food Facts: 30 days (community-edited, more drift)
    ///   - rule-based estimate: 1 day (cuisine map changes more often
    ///     than once a season but rarely)
    public var ttl: TimeInterval {
        switch source {
        case .canonicalPantry:     return .infinity
        case .usdaFDC:             return 90 * 86_400
        case .openFoodFacts:       return 30 * 86_400
        case .ruleBasedEstimate:   return 1 * 86_400
        // LLM-produced sources never round-trip through this cache
        // (NutritionLookupResult is only built by lookup services),
        // but the compiler demands exhaustivity. Treat as 1-day
        // if they ever do leak in via tests/fixtures.
        case .llmDirect, .usdaCalibrated, .usdaOverride:
            return 1 * 86_400
        }
    }

    /// True if cachedAt + ttl is in the past. Drives the stale-while-
    /// revalidate logic: return immediately, refresh in background.
    public func isStale(now: Date = Date()) -> Bool {
        guard ttl.isFinite else { return false }
        return now.timeIntervalSince(cachedAt) > ttl
    }
}

// MARK: - NutritionLookupError

public enum NutritionLookupError: Error, Sendable {
    case rateLimited(source: NutritionSource)
    case upstreamFailure(source: NutritionSource, status: Int)
    case networkError(source: NutritionSource, underlying: Error)
    case parseError(source: NutritionSource, detail: String)
    case noMatch  // every source returned no result for this query
}

