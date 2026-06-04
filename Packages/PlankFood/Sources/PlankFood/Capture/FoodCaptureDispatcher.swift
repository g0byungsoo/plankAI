import Foundation

// MARK: - FoodCaptureDispatcher
//
// W2-T1. The seam between user input (`FoodCapture`) and the downstream
// pipelines (LLM call, pantry lookup, rule-based estimator). One
// dispatch entry point per food-rail UI surface (camera shutter,
// quick-add tap, "i'm out tonight" tap).
//
// The switch is intentionally exhaustive — when a new FoodCapture case
// lands (e.g. .barcode in v1.0.8), the compiler errors at this site,
// surfacing the implementation gap. Per v3 D27, NO `FoodInputProvider`
// protocol until we have 3+ providers that genuinely share behavior.
//
// Downstream services land in W2-T3 (FoodVisionService for .photo) +
// W2-T4 (NutritionLookupService for .quickAdd) + a TBD W2 ticket for
// the rule-based .imOutTonight estimator. Until they land, dispatch()
// throws `.notImplemented` with the ticket reference so UI code can
// surface the right "give us a few hours" copy.
//
// Why MainActor: the dispatcher reads UI state (Feature Flags, camera
// session, etc.) and writes UI-observable result models. Hopping off
// the main actor for the LLM HTTP call lives inside FoodVisionService.

@MainActor
public final class FoodCaptureDispatcher {

    public init() {}

    /// Route a user capture to the appropriate pipeline. Returns the
    /// normalized `CapturedFood` once the pipeline completes.
    ///
    /// Throws on:
    /// - `.notImplemented` while W2-T3/T4 wire pipelines in
    /// - upstream service errors (network, rate limit, budget cap,
    ///   USDA miss, etc.) once pipelines exist
    /// Optional cuisine profile injected into the LLM system prompt
    /// for `.photo` scans. Comes from the user's
    /// onboarding_cuisine_preference column (Q302 per v5 D40). nil =
    /// fall back to neutral priors per FOOD_VISION_SCHEMA.
    public var cuisineProfile: String?

    public func dispatch(_ capture: FoodCapture) async throws -> CapturedFood {
        switch capture {

        case .photo(let imageData, let mode):
            // W2-T3 ✓ — route to FoodVisionService (POSTs to the
            // food-vision Edge Function, decodes the strict JSON
            // response, maps to CapturedFood). USDA join lands in
            // W2-T4 (NutritionLookupService); items[].kcal stays nil
            // until then and the result card shows a loading state.
            guard let visionService = FoodModule.visionService else {
                throw FoodCaptureError.notImplemented(
                    ticket: "W2-T3",
                    message: "FoodModule.configure(visionService:) never ran",
                    context: .photo(byteCount: imageData.count, mode: mode)
                )
            }
            let identified: CapturedFood
            do {
                identified = try await visionService.scan(
                    imageData: imageData,
                    cuisineProfile: cuisineProfile,
                    mode: mode
                )
            } catch let visionError as VisionError {
                // Wrap so call sites can pattern-match on either
                // FoodCaptureError or unwrap to VisionError for the
                // user-facing copy.
                throw FoodCaptureError.pipeline(underlying: visionError)
            }

            // W2-T4 ✓ — join LLM-identified items with per-100g
            // nutrition density from USDA / Open Food Facts /
            // canonical_pantry (parallel resolver), then compute
            // per-item + plate totals via CalorieMathService.
            //
            // No NutritionLookupService configured = items stay
            // kcal-nil and result card shows "couldn't ID this"
            // placeholder per item. Lookup failures per item are
            // isolated (fail-soft) so one missing density doesn't
            // sink the whole plate.
            return await Self.enrich(identified, using: FoodModule.nutritionLookup)

        case .quickAdd(let pantryItemID):
            // W2-T4 — wire NutritionLookupService.lookupPantry(id)
            //         → returns CapturedFood with kcal/macros already
            //         joined from canonical_pantry (no LLM call,
            //         no USDA lookup needed).
            throw FoodCaptureError.notImplemented(
                ticket: "W2-T4",
                message: "NutritionLookupService not yet wired",
                context: .quickAdd(pantryItemID: pantryItemID)
            )

        case .imOutTonight(let cuisine):
            // W2 TBD — wire RestaurantEstimateService.estimate(cuisine)
            //          → rule-based map of cuisine → (kcalLow, kcalHigh,
            //          centerEstimate). NO LLM call (cost saver; v3
            //          §architecture-simplification).
            throw FoodCaptureError.notImplemented(
                ticket: "W2-TBD",
                message: "RestaurantEstimateService not yet wired",
                context: .imOutTonight(cuisine: cuisine)
            )
        }
    }
}

// MARK: - Enrich

extension FoodCaptureDispatcher {
    /// Join LLM-identified items with nutrition density from the
    /// configured lookup service (Option A: AppSideNutritionLookup
    /// hitting pantry > USDA > OFF in parallel). Items where lookup
    /// returns nil keep their existing nil kcal/macros — UI shows
    /// "couldn't ID this" placeholder.
    static func enrich(
        _ identified: CapturedFood,
        using lookup: NutritionLookupService?
    ) async -> CapturedFood {
        guard let lookup else { return identified }
        guard !identified.items.isEmpty else { return identified }

        let queries = identified.items.map { item in
            NutritionQuery(
                itemName: item.name,
                usdaSearchTerms: item.usdaSearchTerms,
                cuisineHint: item.cuisineHint
            )
        }
        let densities = await lookup.lookup(queries)

        let enriched: [CapturedItem] = zip(identified.items, densities).map { item, lookup in
            guard let lookup else { return item }
            let nutrition = CalorieMathService.compute(
                portionGrams: item.portionGrams,
                portionGramsLow: item.portionGramsLow,
                portionGramsHigh: item.portionGramsHigh,
                density: lookup.density
            )
            return CapturedItem(
                id: item.id,
                name: item.name,
                portionGrams: item.portionGrams,
                portionGramsLow: item.portionGramsLow,
                portionGramsHigh: item.portionGramsHigh,
                usdaSearchTerms: item.usdaSearchTerms,
                preparation: item.preparation,
                cuisineHint: item.cuisineHint,
                confidence: item.confidence,
                notes: item.notes,
                kcal: nutrition.kcal,
                proteinG: nutrition.proteinG,
                carbsG: nutrition.carbsG,
                fatG: nutrition.fatG,
                fiberG: nutrition.fiberG,
                nutritionSource: lookup.source
            )
        }

        return CapturedFood(
            items: enriched,
            plateType: identified.plateType,
            source: identified.source,
            confidence: identified.confidence,
            needsSecondPhoto: identified.needsSecondPhoto,
            secondPhotoHint: identified.secondPhotoHint,
            kcalLow: identified.kcalLow,
            kcalHigh: identified.kcalHigh
        )
    }
}

// MARK: - FoodCaptureError

public enum FoodCaptureError: Error, Sendable {
    /// Pipeline not yet wired. Carries the sprint ticket reference so
    /// the UI can surface developer-facing copy in DEBUG (and
    /// fall-through to "give us a few hours" in Release).
    case notImplemented(ticket: String, message: String, context: NotImplementedContext)

    /// Captured input failed pre-flight validation (empty photo data,
    /// nonexistent pantry id, etc.).
    case invalidInput(reason: String)

    /// Downstream service returned an error. Wraps the underlying
    /// error so call-sites can pattern-match on cause.
    case pipeline(underlying: Error)
}

/// Carries the case-specific payload through a notImplemented error so
/// telemetry can distinguish which capture path tried to fire before
/// its pipeline landed.
public enum NotImplementedContext: Sendable {
    case photo(byteCount: Int, mode: PhotoMode)
    case quickAdd(pantryItemID: PantryItemID)
    case imOutTonight(cuisine: CuisineChip?)
}
