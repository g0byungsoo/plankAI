import Foundation

// MARK: - FoodAnalytics
//
// Closure-based analytics sink for the food rail. PlankFood is a leaf
// SPM package and can't import the main app's AnalyticsManager (would
// create a cycle). Instead, the main app registers a single closure at
// launch via FoodAnalytics.register(...) that wraps Analytics.track.
// PlankFood views call FoodAnalytics.track(...) which invokes the
// registered closure on a background queue.
//
// Event vocabulary mirrors the main-app AnalyticsEvent enum so funnel
// queries can target either side. The raw String values must match
// exactly; if you add an event here, add the matching case to
// AnalyticsManager.AnalyticsEvent and route the registration in
// PlankAIApp.swift.

public enum FoodAnalytics {

    /// Funnel + per-scan + cost events. Raw values mirror the main-app
    /// AnalyticsEvent enum — keep these strings in sync with
    /// PlankApp/Analytics/AnalyticsManager.swift.
    public enum Event: String {
        // Funnel
        case aiConsentShown        = "food_ai_consent_shown"
        case aiConsentAccepted     = "food_ai_consent_accepted"
        case aiConsentDeclined     = "food_ai_consent_declined"
        case firstScanStarted      = "food_first_scan_started"
        case firstScanCompleted    = "food_first_scan_completed"
        case firstLogSaved         = "food_first_log_saved"
        // Per-scan
        case scanStarted           = "food_scan_started"
        case scanCompleted         = "food_scan_completed"
        case scanFallbackFired     = "food_scan_fallback_fired"
        case scanCorrectionSaved   = "food_scan_correction_saved"
        /// v1.0.8 Phase E — quick-correction pill tap. Properties:
        /// correction (sauce / bigger), multiplier, add_kcal.
        case scanCorrectionApplied = "food_scan_correction_applied"
        /// Sprint A (2026-06-15) — satiety pill tap on the result card.
        /// The vocabulary-loop anchor at the daily-loop layer. Properties:
        /// state (hungry / meh).
        case satietyMarked         = "food_satiety_marked"
        case logSaved              = "food_log_saved"
        /// p61 — a persist that threw. The user was already given the
        /// success haptic and the answer sentence, so this is the one
        /// event that says "we told her it worked and it did not".
        /// Categorical only (the door), never a food name.
        case logSaveFailed         = "food_log_save_failed"
        // Mode-specific
        case quickAddTapped        = "food_quick_add_tapped"
        case quickAddLogged        = "food_quick_add_logged"
        case imOutUsed             = "food_im_out_used"
        case imOutLogged           = "food_im_out_logged"
        // v25 E4 — the plate's memory
        case priorApplied          = "food_prior_applied"
        case relogUsed             = "food_relog_used"
        // p61 — nutrition-pipeline telemetry, previously fired
        // straight at PostHogSDK from inside the package with the
        // item's NAME and the database's display name in the payload —
        // both banned by the hygiene law ("never a product name or
        // free text") and both bypassing the one boundary this file's
        // own header declares. Categorical + numeric only now, through
        // the sink like everything else.
        case lookupCompleted       = "nutrition_lookup_completed"
        case lookupFailed          = "nutrition_lookup_failed"
        case densityResolved       = "nutrition_density_resolved"
        case calibrationAgreed     = "nutrition_calibration_agreed"
        case calibrationOverrode   = "nutrition_calibration_overrode"
        // Cost
        case scanCost              = "food_scan_cost"
        case budgetCapHit          = "food_budget_cap_hit"
        case rateLimitHit          = "food_rate_limit_hit"
    }

    /// Registered by the main app at launch. PlankFood never reads or
    /// writes any analytics provider directly — this closure is the
    /// boundary. Nil-safe: events fired before registration are
    /// silently dropped (intentional — onboarding/launch ordering).
    nonisolated(unsafe) private static var sink: (@Sendable (String, [String: Any]) -> Void)?

    /// Called once at app launch from PlankAIApp.swift. Idempotent —
    /// repeated calls just replace the closure (useful in DEBUG / hot
    /// reload scenarios).
    public static func register(_ handler: @escaping @Sendable (String, [String: Any]) -> Void) {
        sink = handler
    }

    /// Fire-and-forget tracking. Properties dictionary is merged with
    /// the empty default — callers pass anything cohort-relevant for
    /// the specific event (cuisine_profile, meal_slot, confidence_min,
    /// etc.). The main-app sink wraps this call and stamps the global
    /// user-state properties (paid_status, glp1_status) before
    /// forwarding to PostHog.
    public static func track(_ event: Event, properties: [String: Any] = [:]) {
        sink?(event.rawValue, properties)
    }

    // MARK: - First-time gated events
    //
    // Funnel events that fire ONCE per user lifetime. UserDefaults flags
    // back the idempotency check so the event can be analyzed as a
    // single-fire metric (without coalesce window quirks). Keys are
    // namespaced under `food_analytics.first_*` so the flags don't
    // collide with other app-side AppStorage values.

    private enum FirstFiredKey {
        static let scanStarted   = "food_analytics.first_scan_started_fired"
        static let scanCompleted = "food_analytics.first_scan_completed_fired"
        static let logSaved      = "food_analytics.first_log_saved_fired"
    }

    public static func firstScanStartedIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: FirstFiredKey.scanStarted) else { return }
        UserDefaults.standard.set(true, forKey: FirstFiredKey.scanStarted)
        track(.firstScanStarted)
    }

    public static func firstScanCompletedIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: FirstFiredKey.scanCompleted) else { return }
        UserDefaults.standard.set(true, forKey: FirstFiredKey.scanCompleted)
        track(.firstScanCompleted)
    }

    public static func firstLogSavedIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: FirstFiredKey.logSaved) else { return }
        UserDefaults.standard.set(true, forKey: FirstFiredKey.logSaved)
        track(.firstLogSaved)
    }
}
