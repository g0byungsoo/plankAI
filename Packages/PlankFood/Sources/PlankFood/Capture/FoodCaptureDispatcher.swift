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
    public func dispatch(_ capture: FoodCapture) async throws -> CapturedFood {
        switch capture {

        case .photo(let imageData, let mode):
            // W2-T3 — wire FoodVisionService.scan(imageData, mode,
            //         cuisineProfile) → returns CapturedFood with
            //         items[].usdaSearchTerms populated; USDA join
            //         happens in a follow-on step (W2-T4).
            throw FoodCaptureError.notImplemented(
                ticket: "W2-T3",
                message: "FoodVisionService not yet wired",
                context: .photo(byteCount: imageData.count, mode: mode)
            )

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
