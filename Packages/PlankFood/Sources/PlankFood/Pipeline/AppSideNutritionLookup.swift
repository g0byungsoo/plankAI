import Foundation
import PostHog

// MARK: - AppSideNutritionLookup
//
// Option A per W2-T4 architect decision. Concrete NutritionLookupService
// that runs entirely on-device. Hits USDA FDC + Open Food Facts +
// canonical_pantry in parallel via `withTaskGroup`, picks the
// highest-priority result that resolved (pantry > USDA > OFF), caches
// via NutritionCache (NSCache hot tier).
//
// Migration triggers (move to Option B / Edge Function variant when
// any one fires — per architect):
//   1. USDA error rate (rate-limit or 5xx) > 2% over 7-day window
//   2. P75 lookup latency > 1.2s over 7-day window
//   3. Paid user count > 2,000
//
// PostHog instruments three events from day one (per architect's
// "corrections-as-moat starts here" stance) — `nutrition_lookup_*`
// events with full source/sourceId provenance so the v1.0.8
// correction flywheel has a year of baseline data to bootstrap from.

public final class AppSideNutritionLookup: NutritionLookupService {

    private let usda: USDAClient?
    private let off: OpenFoodFactsClient
    private let pantry: CanonicalPantryClient?
    private let cache: NutritionCache

    public init(
        usda: USDAClient?,
        off: OpenFoodFactsClient = OpenFoodFactsClient(),
        pantry: CanonicalPantryClient?,
        cache: NutritionCache = NutritionCache()
    ) {
        self.usda = usda
        self.off = off
        self.pantry = pantry
        self.cache = cache
    }

    // MARK: - NutritionLookupService

    public func lookup(_ queries: [NutritionQuery]) async -> [NutritionLookupResult?] {
        // Parallel fan-out — one Task per query. withTaskGroup keeps
        // result ordering aligned with input ordering (we collect into
        // an indexed dictionary then read back in order).
        await withTaskGroup(of: (Int, NutritionLookupResult?).self) { group in
            for (index, query) in queries.enumerated() {
                group.addTask { [weak self] in
                    guard let self else { return (index, nil) }
                    let result = await self.lookupOne(query)
                    return (index, result)
                }
            }

            var ordered = [Int: NutritionLookupResult?]()
            for await (index, result) in group {
                ordered[index] = result
            }
            return queries.indices.map { ordered[$0] ?? nil }
        }
    }

    // MARK: - Single-query resolver

    private func lookupOne(_ query: NutritionQuery) async -> NutritionLookupResult? {
        let start = Date()

        // Per-source parallel fan-out within a single query (architect:
        // "Query all three in parallel; pick canonical_pantry > USDA >
        // OFF when multiple return"). withTaskGroup again for
        // structured concurrency + automatic cancellation.
        let results = await withTaskGroup(
            of: (NutritionSource, NutritionLookupResult?).self
        ) { group -> [NutritionSource: NutritionLookupResult] in

            // 1. canonical_pantry (highest priority)
            if let pantry = self.pantry {
                group.addTask {
                    let r = try? await pantry.search(query.usdaSearchTerms)
                    return (.canonicalPantry, r)
                }
            }

            // 2. USDA FDC (second priority)
            if let usda = self.usda, let firstTerm = query.usdaSearchTerms.first {
                group.addTask {
                    let r = try? await usda.search(firstTerm)
                    return (.usdaFDC, r)
                }
            }

            // 3. Open Food Facts (third priority)
            if let firstTerm = query.usdaSearchTerms.first {
                let off = self.off
                group.addTask {
                    let r = try? await off.search(firstTerm)
                    return (.openFoodFacts, r)
                }
            }

            var found = [NutritionSource: NutritionLookupResult]()
            for await (source, result) in group {
                if let result {
                    found[source] = result
                }
            }
            return found
        }

        // Resolver priority: pantry > USDA > OFF.
        let resolved = results[.canonicalPantry]
            ?? results[.usdaFDC]
            ?? results[.openFoodFacts]

        // Cache the winner under its source's key. Future calls hit
        // the hot cache first (in-session).
        if let resolved {
            switch resolved.source {
            case .canonicalPantry:
                cache.set(NutritionCache.pantryKey(slug: resolved.sourceId), resolved)
            case .usdaFDC:
                if let id = Int(resolved.sourceId) {
                    cache.set(NutritionCache.usdaKey(fdcId: id), resolved)
                }
            case .openFoodFacts:
                cache.set(NutritionCache.offKey(barcodeOrHash: resolved.sourceId), resolved)
            case .ruleBasedEstimate:
                break  // not produced by this lookup path
            }
        }

        // Telemetry — three events per architect's stance on
        // corrections-as-moat baseline data. Fire-and-forget; never
        // block the user-facing return on PostHog.
        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        Self.logTelemetry(
            query: query,
            result: resolved,
            attemptedSources: Array(results.keys),
            durationMs: durationMs
        )

        return resolved
    }

    // MARK: - PostHog telemetry
    //
    // Per architect: log every lookup with full source provenance so
    // the v1.0.8 correction UI can start from a year of baseline
    // data instead of zero. Three events:
    //   - nutrition_lookup_completed (every lookup, success or null)
    //   - nutrition_lookup_failed (any source errored — partial fail)
    //   - nutrition_density_resolved (a density was returned, with
    //     source + sourceId for the correction flywheel)

    private static func logTelemetry(
        query: NutritionQuery,
        result: NutritionLookupResult?,
        attemptedSources: [NutritionSource],
        durationMs: Int
    ) {
        let baseProps: [String: Any] = [
            "item_name": query.itemName,
            "search_terms_count": query.usdaSearchTerms.count,
            "cuisine_hint": query.cuisineHint ?? "none",
            "attempted_sources": attemptedSources.map { $0.rawValue },
            "duration_ms": durationMs,
        ]

        PostHogSDK.shared.capture("nutrition_lookup_completed", properties: baseProps)

        if let result {
            var resolvedProps = baseProps
            resolvedProps["source"] = result.source.rawValue
            resolvedProps["source_id"] = result.sourceId
            resolvedProps["kcal_per_100g"] = result.density.kcalPer100g
            resolvedProps["display_name"] = result.displayName
            PostHogSDK.shared.capture("nutrition_density_resolved", properties: resolvedProps)
        } else {
            var failProps = baseProps
            failProps["reason"] = "no_match"
            PostHogSDK.shared.capture("nutrition_lookup_failed", properties: failProps)
        }
    }
}
