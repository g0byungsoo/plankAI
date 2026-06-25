import Foundation
import PostHog

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

        case .photo(let imageData):
            // W2-T3 ✓ — route to FoodVisionService (POSTs to the
            // food-vision Edge Function, decodes the strict JSON
            // response, maps to CapturedFood). USDA join lands in
            // W2-T4 (NutritionLookupService); items[].kcal stays nil
            // until then and the result card shows a loading state.
            //
            // D54 (2026-06-05): the pre-eat / just-ate mode parameter
            // was removed — see docs/food_rail_plan.md §Delta v6.
            // The unified result card carries permission framing via
            // Jeni's copy line instead of UI chrome.
            guard let visionService = FoodModule.visionService else {
                throw FoodCaptureError.notImplemented(
                    ticket: "W2-T3",
                    message: "FoodModule.configure(visionService:) never ran",
                    context: .photo(byteCount: imageData.count)
                )
            }
            let identified: CapturedFood
            do {
                identified = try await visionService.scan(
                    imageData: imageData,
                    cuisineProfile: cuisineProfile
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

        case .text(let description, let cuisineProfile):
            // v1.0.9 D1 — free-text quick-add. Same FoodVisionService
            // EF endpoint as the photo path, just routed through
            // scanText. Same JSON schema, same CapturedFood result,
            // same error handling. Cost: ~5× cheaper than vision
            // since no image tokens.
            guard let visionService = FoodModule.visionService else {
                throw FoodCaptureError.notImplemented(
                    ticket: "v1.0.9-D1",
                    message: "FoodModule.configure(visionService:) never ran",
                    context: .photo(byteCount: description.utf8.count)
                )
            }
            do {
                let identified = try await visionService.scanText(
                    description,
                    cuisineProfile: cuisineProfile
                )
                return await Self.enrich(identified, using: FoodModule.nutritionLookup)
            } catch let visionError as VisionError {
                throw FoodCaptureError.pipeline(underlying: visionError)
            }

        case .imOutTonight(let cuisine):
            // D14 LOCKED — rule-based cuisine → (kcalLow, kcalHigh)
            // map. NO LLM call (cost saver per v3 §architecture-
            // simplification + D14 laziness principle). The narrow
            // range (±150 kcal around the cuisine center) is wide
            // enough to acknowledge "rough estimate" honestly without
            // making the bar feel uselessly broad.
            //
            // Centers are from ImOutTonightView's documented map:
            //   mexican 600 · italian 850 · asian 750 · american 700
            //   · pizza 900 · other 700 · (no cuisine) 700
            return Self.restaurantEstimate(cuisine: cuisine)
        }
    }

    /// Build a CapturedFood for the .imOutTonight path. Range
    /// fields drive RestaurantRangeBar in the result card; items is
    /// intentionally empty (no per-item rows — restaurants don't
    /// have a per-ingredient story).
    static func restaurantEstimate(cuisine: CuisineChip?) -> CapturedFood {
        let center: Double
        switch cuisine {
        // v1.0.7 QA: Mexican bumped 600→750 — cohort Chipotle/Tex-Mex
        // dinners (bowl + chips-and-guac, or 2-taco combo with rice
        // and beans) avg 750-900 kcal published. 600±150 under-
        // reported the upper end users actually hit.
        case .mexican:  center = 750
        case .italian:  center = 850
        case .asian:    center = 750
        case .american: center = 700
        case .pizza:    center = 900
        case .other, .none: center = 700
        }
        let halfRange: Double = 150
        return CapturedFood(
            items: [],
            plateType: .restaurantRange,
            source: .restaurantEstimate,
            confidence: nil,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: center - halfRange,
            kcalHigh: center + halfRange
        )
    }
}

// MARK: - Enrich

extension FoodCaptureDispatcher {

    /// Confidence threshold under which an LLM-direct kcal is
    /// considered ambiguous enough to warrant a USDA sanity check.
    /// Threshold picked from GPT-5 vision JFB benchmark: at
    /// confidence ≥0.5, mean absolute % error sits at ~12% (well
    /// inside the rounding bucket); below 0.5, MAPE jumps to >25%
    /// where USDA Foundation can usefully overlay.
    static let calibrationConfidenceThreshold: Double = 0.5

    /// Maximum kcal drift (as fraction of LLM kcal) the USDA
    /// calibration sweep tolerates before USDA wins. 30% picked
    /// against the rounding-bucket scheme: a 50-kcal bucket on a
    /// 200-kcal item is already 25%, so anything tighter would
    /// fire on rounding noise.
    static let calibrationDriftThreshold: Double = 0.30

    /// Three-path enrichment for LLM-identified items:
    ///
    /// 1. **High-confidence + LLM kcal present** (the new common
    ///    path post-v1.0.7 direct-kcal rewrite) — keep LLM numbers
    ///    as-is, tag `.llmDirect`. No USDA round-trip; fastest.
    ///
    /// 2. **Low-confidence + LLM kcal present** — run USDA lookup
    ///    as a sanity check. If USDA agrees within ±30%, keep LLM
    ///    kcal but tag `.usdaCalibrated` for telemetry. If drift
    ///    exceeds ±30%, USDA wins — replace kcal + macros, tag
    ///    `.usdaOverride`, log the override for the v1.0.8
    ///    correction flywheel.
    ///
    /// 3. **LLM kcal missing** (legacy fallback — gpt-4o secret
    ///    override, schema mid-flight migration, partial response)
    ///    — full USDA join. Same as the pre-v1.0.7 path.
    ///
    /// Items where USDA lookup returns nil keep their existing LLM
    /// numbers (path 1 or 2 fallback) or stay kcal-nil (path 3
    /// fallback) so the result card surfaces the "couldn't ID this"
    /// placeholder.
    static func enrich(
        _ identified: CapturedFood,
        using lookup: NutritionLookupService?
    ) async -> CapturedFood {
        guard !identified.items.isEmpty else { return identified }

        // Determine which items need a USDA round-trip. Skip-eligible
        // items (high-confidence LLM-direct) take the fast path and
        // never touch the network. Lookup-eligible items go through
        // either calibration or legacy enrichment.
        let needsLookup: [Bool] = identified.items.map { item in
            shouldRunUSDA(for: item)
        }

        // If no lookup service configured OR no items need lookup,
        // return as-is. The all-high-confidence case is the v1.0.7
        // happy path — every item kept LLM kcal with no network cost.
        guard let lookup, needsLookup.contains(true) else {
            return identified
        }

        // Build queries only for the items that need them; map back
        // to the original item indices so we can slot results in.
        var queryIndices: [Int] = []
        var queries: [NutritionQuery] = []
        for (index, item) in identified.items.enumerated() where needsLookup[index] {
            queryIndices.append(index)
            queries.append(
                NutritionQuery(
                    itemName: item.name,
                    usdaSearchTerms: item.usdaSearchTerms,
                    cuisineHint: item.cuisineHint
                )
            )
        }
        let results = await lookup.lookup(queries)

        // Build an index → lookup-result map for the items we queried.
        var lookupByIndex: [Int: NutritionLookupResult?] = [:]
        for (i, queryIndex) in queryIndices.enumerated() {
            lookupByIndex[queryIndex] = results[i]
        }

        let enriched: [CapturedItem] = identified.items.enumerated().map { index, item in
            if !needsLookup[index] {
                // Path 1 — high-confidence LLM-direct, no work to do.
                return item
            }
            guard let result = lookupByIndex[index] ?? nil else {
                // Lookup ran but returned nil. Keep whatever the LLM
                // gave us — path 2 falls back to LLM kcal as-is,
                // path 3 stays kcal-nil.
                return item
            }
            if item.kcal != nil {
                // Path 2 — LLM kcal present, low confidence → calibrate.
                return calibrate(item: item, against: result)
            } else {
                // Path 3 — LLM kcal missing → full USDA join.
                return enrichFromUSDA(item: item, with: result)
            }
        }

        return CapturedFood(
            items: enriched,
            plateType: identified.plateType,
            source: identified.source,
            confidence: identified.confidence,
            needsSecondPhoto: identified.needsSecondPhoto,
            secondPhotoHint: identified.secondPhotoHint,
            // Re-derive plate totals from enriched items if any item's
            // kcal changed via calibration/override. If every item kept
            // its LLM value, the original totals carry through.
            kcalLow: derivedKcalLow(items: enriched, fallback: identified.kcalLow),
            kcalHigh: derivedKcalHigh(items: enriched, fallback: identified.kcalHigh)
        )
    }

    /// True when this item needs a USDA round-trip. Two cases:
    /// LLM didn't return kcal (path 3), or LLM did but flagged
    /// itself low-confidence (path 2 calibration). High-confidence
    /// LLM-direct items skip USDA entirely.
    private static func shouldRunUSDA(for item: CapturedItem) -> Bool {
        if item.kcal == nil { return true }
        let conf = item.confidence ?? 1.0
        return conf < calibrationConfidenceThreshold
    }

    /// Path 2 — LLM returned kcal but flagged low confidence. Run
    /// USDA as a sanity check. Within ±30% drift → keep LLM, tag
    /// `.usdaCalibrated`. Exceeds ±30% → USDA wins, tag
    /// `.usdaOverride`. The override case also writes USDA macros
    /// since they're the calibrated source.
    private static func calibrate(
        item: CapturedItem,
        against result: NutritionLookupResult
    ) -> CapturedItem {
        guard let llmKcal = item.kcal, llmKcal > 0 else {
            // Defensive: caller gates on kcal != nil, but the > 0
            // check protects the drift denominator from divide-by-zero.
            return enrichFromUSDA(item: item, with: result)
        }
        let usdaMath = CalorieMathService.compute(
            portionGrams: item.portionGrams,
            portionGramsLow: item.portionGramsLow,
            portionGramsHigh: item.portionGramsHigh,
            density: result.density
        )
        let drift = abs(usdaMath.kcal - llmKcal) / llmKcal
        logCalibrationTelemetry(
            item: item,
            llmKcal: llmKcal,
            usdaKcal: usdaMath.kcal,
            drift: drift,
            override: drift > calibrationDriftThreshold,
            source: result.source
        )
        if drift <= calibrationDriftThreshold {
            // USDA agrees within tolerance — keep LLM numbers, mark
            // the source so cohort analyst can see the check ran.
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
                kcal: item.kcal,
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                fiberG: item.fiberG,
                nutritionSource: .usdaCalibrated,
                sugarG: item.sugarG,
                sodiumMg: item.sodiumMg,
                saturatedFatG: item.saturatedFatG,
                // 2026-06-23 — carry the accuracy fields through the USDA
                // sweep so low-confidence items don't lose their count /
                // native-name gloss / shared-serving data.
                englishName: item.englishName,
                count: item.count,
                unit: item.unit,
                servingsInDish: item.servingsInDish,
                isShareable: item.isShareable
            )
        }
        // USDA disagrees by more than tolerance — USDA wins. Replace
        // kcal + macros with the USDA-derived numbers and mark the
        // source for the correction flywheel.
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
            kcal: usdaMath.kcal,
            proteinG: usdaMath.proteinG,
            carbsG: usdaMath.carbsG,
            fatG: usdaMath.fatG,
            fiberG: usdaMath.fiberG,
            nutritionSource: .usdaOverride,
            sugarG: usdaMath.sugarG,
            sodiumMg: usdaMath.sodiumMg,
            saturatedFatG: usdaMath.saturatedFatG,
            englishName: item.englishName,
            count: item.count,
            unit: item.unit,
            servingsInDish: item.servingsInDish,
            isShareable: item.isShareable
        )
    }

    /// Path 3 — LLM didn't return kcal at all (legacy gpt-4o
    /// fallback or schema mid-flight). Full USDA join, tag the
    /// source as returned by the lookup service.
    private static func enrichFromUSDA(
        item: CapturedItem,
        with result: NutritionLookupResult
    ) -> CapturedItem {
        let nutrition = CalorieMathService.compute(
            portionGrams: item.portionGrams,
            portionGramsLow: item.portionGramsLow,
            portionGramsHigh: item.portionGramsHigh,
            density: result.density
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
            nutritionSource: result.source,
            sugarG: nutrition.sugarG,
            sodiumMg: nutrition.sodiumMg,
            saturatedFatG: nutrition.saturatedFatG,
            englishName: item.englishName,
            count: item.count,
            unit: item.unit,
            servingsInDish: item.servingsInDish,
            isShareable: item.isShareable
        )
    }

    /// Plate totals re-derivation when items' kcal may have changed
    /// via calibration. Returns nil when any item is missing kcal —
    /// matches CapturedFood.totalKcal's "nil means loading state"
    /// contract. Falls back to the original LLM-direct totals when
    /// no item was touched (path 1 happy path).
    /// PostHog telemetry for the v1.0.8 correction flywheel. One
    /// event per calibration check (path 2 only — path 1 skips
    /// USDA entirely and path 3 logs via the existing
    /// `nutrition_lookup_*` events in AppSideNutritionLookup).
    /// Fire-and-forget; never blocks the result card.
    private static func logCalibrationTelemetry(
        item: CapturedItem,
        llmKcal: Double,
        usdaKcal: Double,
        drift: Double,
        override: Bool,
        source: NutritionSource
    ) {
        let props: [String: Any] = [
            "item_name": item.name,
            "confidence": item.confidence ?? -1,
            "llm_kcal": Int(llmKcal.rounded()),
            "usda_kcal": Int(usdaKcal.rounded()),
            "drift_pct": Int((drift * 100).rounded()),
            "override": override,
            "usda_source": source.rawValue,
            "cuisine_hint": item.cuisineHint ?? "none",
        ]
        let event = override
            ? "nutrition_calibration_overrode"
            : "nutrition_calibration_agreed"
        PostHogSDK.shared.capture(event, properties: props)
    }

    private static func derivedKcalLow(items: [CapturedItem], fallback: Double?) -> Double? {
        guard items.contains(where: { $0.nutritionSource == .usdaOverride }) else {
            return fallback
        }
        let kcals = items.compactMap { $0.kcal }
        guard kcals.count == items.count else { return nil }
        return kcals.reduce(0, +)
    }

    private static func derivedKcalHigh(items: [CapturedItem], fallback: Double?) -> Double? {
        guard items.contains(where: { $0.nutritionSource == .usdaOverride }) else {
            return fallback
        }
        let kcals = items.compactMap { $0.kcal }
        guard kcals.count == items.count else { return nil }
        return kcals.reduce(0, +)
    }
}

// MARK: - FoodCaptureError

public enum FoodCaptureError: Error, LocalizedError, Sendable {
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

    /// User-facing error description per LocalizedError conformance.
    /// Without this, NSError bridging produces "(PlankFood
    /// .FoodCaptureError error N.)" which leaks the internal type
    /// name. The PhotoCaptureView catch still pattern-matches on
    /// each case for the best-fit copy; this is the fallback when
    /// the error escapes into a generic catch or banner.
    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "give us a few hours. we're catching our breath."
        case .invalidInput:
            return "something looked off with the photo. try once more?"
        case .pipeline(let underlying):
            // If the underlying error has its own user-facing
            // description (VisionError now does), use that. Otherwise
            // a generic gentle line.
            if let vision = underlying as? VisionError {
                return vision.userFacingCopy
            }
            if let localized = (underlying as? LocalizedError)?.errorDescription {
                return localized
            }
            return "couldn't read your plate just now. try again?"
        }
    }
}

/// Carries the case-specific payload through a notImplemented error so
/// telemetry can distinguish which capture path tried to fire before
/// its pipeline landed.
public enum NotImplementedContext: Sendable {
    case photo(byteCount: Int)
    case quickAdd(pantryItemID: PantryItemID)
    case imOutTonight(cuisine: CuisineChip?)
}
