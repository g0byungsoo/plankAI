import Foundation
import SwiftUI

// MARK: - AnalyticsManager
//
// Lightweight wrapper for funnel + onboarding event tracking. Designed
// so we can wire PostHog, RevenueCat custom events, or any other provider
// later without touching every call site. For now: console logging in
// DEBUG and a fire-and-forget no-op in release. Never blocks the UI;
// all sinks are dispatched off the main thread.
//
// Usage:
//   Analytics.track(.onboardingStart)
//   Analytics.track(.onboardingStepViewed, properties: ["step_id": 132])
//
// To add a real backend later: append a Sink to `Analytics.sinks` at
// app launch in PlankAIApp.swift. The wrapper guarantees:
//   - never crashes the app if a provider fails
//   - never blocks the calling thread
//   - de-dupes high-frequency repeats (same event + same coalesce key
//     within a short window) so onAppear loops don't fire 50x
//
// No persistence, no schema changes. Provider-side persistence is the
// provider's job.

enum AnalyticsEvent: String {
    // ── Onboarding funnel ────────────────────────────────────────
    case onboardingStart            = "onboarding_start"
    case onboardingStepViewed       = "onboarding_step_viewed"
    case onboardingStepCompleted    = "onboarding_step_completed"
    case onboardingExitStep         = "onboarding_exit_step"
    case onboardingComplete         = "onboarding_complete"

    // ── Plan loader (replaces single loading carousel) ───────────
    case planLoaderStarted          = "plan_loader_started"
    case planLoaderStageViewed      = "plan_loader_stage_viewed"
    case planLoaderCompleted        = "plan_loader_completed"

    // ── Affirmation beats ────────────────────────────────────────
    case affirmationViewed          = "affirmation_viewed"

    // ── Reveal sequence ──────────────────────────────────────────
    case projectionChartViewed              = "projection_chart_viewed"
    case projectionChartAnimationCompleted  = "projection_chart_animation_completed"
    case planRevealViewed                   = "plan_reveal_viewed"
    case planRevealContinueTapped           = "plan_reveal_continue_tapped"

    // ── Paywall + monetization ───────────────────────────────────
    case paywallView                = "paywall_view"
    case trialStart                 = "trial_start"
    case purchaseCompleted          = "purchase_completed"

    // ── Paywall diagnostic events (issue #2) ─────────────────────
    // Wired May 2026 after the Day-2 zero-trial bug: 54 paywall views
    // on May 29 produced 0 trial_start events with no failure visible
    // anywhere. The three events below close that observability gap by
    // splitting the intent → StoreKit handoff into discrete steps so a
    // future regression like that is catchable by funnel diff alone.
    // Property `plan` is the user-selected tier (yearly / quarterly /
    // weekly). `time_on_paywall_ms` is the millisecond delta between
    // PaywallView .onAppear and the event firing.
    case paywallCtaTapped           = "paywall_cta_tapped"
    case purchaseSheetShown         = "purchase_sheet_shown"
    case paywallDismissAttempted    = "paywall_dismiss_attempted"

    /// 2026-05-30 (epic #1 child #4): user tapped Subscribe → Apple
    /// purchase sheet appeared → user cancelled. The high-intent
    /// abandon moment that triggers the downsell offer (once per
    /// install). Property: `plan` (yearly/quarterly/weekly).
    case paywallTransactionAbandoned = "paywall_transaction_abandoned"

    // ── First activation ─────────────────────────────────────────
    case firstWorkoutStart          = "first_workout_start"
    case firstWorkoutComplete       = "first_workout_complete"

    // ── Notification permission (post-first-workout) ─────────────
    case notificationPrepromptViewed    = "notification_preprompt_viewed"
    case notificationPrepromptAccepted  = "notification_preprompt_accepted"
    case notificationPrepromptDismissed = "notification_preprompt_dismissed"
    case notificationPromptShown        = "notification_prompt_shown"
    case notificationPermissionResult   = "notification_permission_result"

    // ── Rating prompt (post-first-workout) ───────────────────────
    case ratingPromptShown          = "rating_prompt_shown"
    case ratingPromptResult         = "rating_prompt_result"

    // ── Consent ritual (case 240) — pinky-promise long-press ─────
    // SUPERSEDED 2026-05-30: case 240 reframed to brand-promises flow
    // (issue #5). Old events kept emitting in parallel for 14 days so
    // funnel reports during the transition window don't break. Remove
    // after 2026-06-13.
    case consentRitualViewed        = "consent_ritual_viewed"
    case consentRitualSigned        = "consent_ritual_signed"
    case consentRitualSkipped       = "consent_ritual_skipped"
    case consentRitualAbandoned     = "consent_ritual_abandoned"

    // ── Attribution (epic #1 child #7, 2026-05-30) ────────────────
    // "How did you hear about jenifit?" answer. Property `source` is
    // one of "tiktok"|"instagram"|"friend"|"app_store"|"google"|"other".
    // JeniFit is $0 CAC organic TikTok — this is the only signal we'll
    // have for which creator/post is converting (no analytics tool
    // gives this accurately without explicit user attribution).
    case acquisitionSourceAnswered  = "acquisition_source_answered"

    // ── Brand promises (case 240, post-2026-05-30 reframe) ────────
    // Replaces consent_ritual_* per epic #1 child #5. Three single-tap
    // promise screens (no signature, no skip path) immediately after
    // plan reveal. brand_promises_completed fires on the third tap.
    // Properties on completed: tap_count (always 3), total_duration_ms.
    // Properties on abandoned: last_promise_index (0..2), time_to_abandon_ms.
    case brandPromisesStarted       = "brand_promises_started"
    case brandPromisesCompleted     = "brand_promises_completed"
    case brandPromisesAbandoned     = "brand_promises_abandoned"

    // ── Method preview (case 250) — pre-paywall ritual tease ─────
    // Phase 1 of the Noom-research-led onboarding conversion pass.
    // Surfaces the JeniMethod ritual (the only post-purchase feature)
    // immediately after plan reveal so users know what they're buying.
    case methodPreviewViewed        = "method_preview_viewed"
    case methodPreviewContinued     = "method_preview_continued"
    case methodPreviewAudioPlayed   = "method_preview_audio_played"

    // ── Phase 3 conversion beats (comparison + tier ladder) ──────
    // case 142 reframed: past-attempts vs steady-you comparison.
    // case 260 new: tier-ladder identity preview (week 1 / 3 / 8).
    case comparisonChartViewed      = "comparison_chart_viewed"
    case tierLadderViewed           = "tier_ladder_viewed"

    // ── Phase 4 education-as-quiz (case 270, habit window) ───────
    // Properties: quiz_id (string), selected_index (int), correct (bool).
    // Lets the funnel surface whether quizzes are improving downstream
    // conversion vs. plain edu screens.
    case quizViewed                 = "quiz_viewed"
    case quizAnswered               = "quiz_answered"

    // ── Video demo (case 145, epic #1 child #8, 2026-05-30) ──────
    // Auto-activated 10-15s loop of the actual plank session. Slot is
    // post-comparison-chart so the user has just seen the JeniFit-vs-
    // generic frame, then sees the real product moving. "Nobody reads
    // features. Everyone watches them." (200+ app teardown research.)
    // Property: `placement: "post_comparison"`, `video_id: "jeni_session_demo"`.
    case onboardingVideoDemoViewed  = "onboarding_video_demo_viewed"

    // ── The JeniFit Method (post-purchase diet education) ───────
    // Phase 6 of docs/diet_education_plan.md. Properties spec is at
    // plan §7. No numeric body data on any of these per §5.3 — the
    // helpers in JeniMethodAnalytics enforce that contract.
    case dietEducationStarted         = "diet_education_started"
    case dietEducationLessonViewed    = "diet_education_lesson_viewed"
    case dietEducationActionCompleted = "diet_education_action_completed"
    case dietEducationCompleted       = "diet_education_completed"
    case dietEducationSkipped         = "diet_education_skipped"

    // ── Coach intro (Phase A — post-purchase Jeni welcome) ──────
    // Per docs/product_direction_2026.md §8.1. Replaces the
    // 6-minute ritual gate with a ~60-90s personalized coach intro
    // (text v1, audio v2). Fires `coachIntroAudioPlayed` only when
    // the existing method_preview audio asset for the user's
    // voicePreference loads successfully.
    case coachIntroViewed             = "coach_intro_viewed"
    case coachIntroContinued          = "coach_intro_continued"
    case coachIntroAudioPlayed        = "coach_intro_audio_played"

    // ── Home program surfaces (Phase A — daily Jeni presence) ──
    // Per §8.2-8.5. WeekProgressStrip is passive (no event).
    // JenisNoteCard is deduped per calendar day. FutureRailCard tap
    // captures intent signal for prioritizing Phase B/C feature
    // builds (food log vs body scan).
    case jenisNoteViewed              = "jenis_note_viewed"
    case futureRailTapped             = "future_rail_tapped"
    case lessonCardTapped             = "lesson_card_tapped"

    // ── Core engagement (recurring — fire on EVERY occurrence) ──
    // The first_workout_* events above are activation-funnel-specific
    // (first session only). These fire every time so retention + habit
    // cohorts are measurable. weight_logged carries no body-data value
    // (unit only) per the §5.3 no-numeric-body-data contract.
    case workoutStart                 = "workout_start"
    case workoutComplete              = "workout_complete"
    case plankCheckinStarted          = "plank_checkin_started"
    case weightLogged                 = "weight_logged"
    case coachChanged                 = "coach_changed"

    // ── Settings hub + workout intensity controller ──
    case settingsHubOpened            = "settings_hub_opened"
    case workoutEnergyChanged         = "workout_energy_changed"
    case sessionFeedbackGiven         = "session_feedback_given"
    case feedbackSubmitted            = "feedback_submitted"

    // ── Steps (Apple Health) ──
    // First connect after the user taps the pulse tile's CTA; "viewed"
    // beats per surface so we can split read engagement on the daily
    // anchor vs. the deeper weekly tile. Goal hit fires once per
    // calendar day the count crosses StepsService.dailyGoal — see the
    // home pulse tile for the day-key gate.
    case stepsConnected               = "steps_connected"
    case stepsViewedHome              = "steps_viewed_home"
    case stepsViewedBecoming          = "steps_viewed_becoming"
    case stepsGoalHit                 = "steps_goal_hit"

    // ── Breathwork re-entry (home + becoming) ──
    // The existing breathwork_session_* events fire from inside the
    // session view regardless of entry point. This event captures the
    // *entry* — taps on the home BreathworkHomeCard — so the funnel can
    // measure home-driven engagement vs. the Day-1 post-purchase path.
    // Property `mode` = "unfamiliar" / "invitation" / "completed" matches
    // the card's three states.
    case breathworkCardTapped         = "breathwork_card_tapped"

    // ── Food rail home engagement (delta v7 D56 rollback guardrail) ──
    // Fires on tap of any entry point that opens CaptureFlowView from
    // Home or tab bar. Property `source` = "home_food_card" /
    // "home_food_intro_tile" / "tab_bar_fab" / "force_first_action" so
    // we can attribute entries by surface. Load-bearing for the diet-
    // first pivot's rollback rule: if lesson engagement drops >15%
    // within 14 days of D56 ship AND food_card_tapped < 1.5/user, revert.
    case foodCardTapped               = "food_card_tapped"
    /// Fired when the user taps "let's begin" on a BreathLibraryView
    /// protocol card. Property `protocol_id` = calming / coherent /
    /// energizing. Lets the funnel measure which technique the audience
    /// gravitates toward + which drives repeat engagement.
    case breathworkProtocolSelected   = "breathwork_protocol_selected"

    // ── Post-purchase breathwork (Phase A — first actionable beat) ──
    // Inserted between CoachIntroView and the first workout. Breathwork
    // is a lower-friction completed action than a workout (can be done
    // anywhere), and it's the Day-0 aha moment per the retention
    // research. The primer educates (honest stress-regulation claim);
    // the session is a ~2.5min guided slow-breath; completion offers a
    // choice (workout now vs later). Funnel reads: did the user breathe,
    // and did breathing → workout or → home?
    case breathworkPrimerViewed       = "breathwork_primer_viewed"
    case breathworkPrimerContinued    = "breathwork_primer_continued"
    case breathworkPrimerSkipped      = "breathwork_primer_skipped"
    case breathworkSessionStarted     = "breathwork_session_started"
    case breathworkSessionCompleted   = "breathwork_session_completed"
    case breathworkSessionDismissed   = "breathwork_session_dismissed"

    // ── Food rail funnel + per-scan (W5-T3) ──
    // Fires from inside PlankFood via the FoodAnalytics closure-sink
    // pattern (PlankAIApp registers a closure at launch that wraps
    // Analytics.track). Every food event gets the cuisine_profile +
    // meal_slot + confidence_min + glp1_status + paid_status props
    // attached by the sink so funnel queries don't need joins.
    case foodAIConsentShown           = "food_ai_consent_shown"
    case foodAIConsentAccepted        = "food_ai_consent_accepted"
    case foodAIConsentDeclined        = "food_ai_consent_declined"
    case foodFirstScanStarted         = "food_first_scan_started"
    case foodFirstScanCompleted       = "food_first_scan_completed"
    case foodFirstLogSaved            = "food_first_log_saved"
    case foodScanStarted              = "food_scan_started"
    case foodScanCompleted            = "food_scan_completed"
    case foodScanFallbackFired        = "food_scan_fallback_fired"
    case foodScanCorrectionOpened     = "food_scan_correction_opened"
    case foodScanCorrectionSaved      = "food_scan_correction_saved"
    case foodLogSaved                 = "food_log_saved"
    case foodQuickAddTapped           = "food_quick_add_tapped"
    case foodQuickAddLogged           = "food_quick_add_logged"
    case foodImOutUsed                = "food_im_out_used"
    case foodImOutLogged              = "food_im_out_logged"
    // Cost telemetry — fires per scan with model + estimated tokens so
    // the daily budget cap can be tracked from PostHog without server-
    // side aggregation. Properties: model (gpt-5 / opus-4.7 / gemini-flash),
    // tokens_in, tokens_out, estimated_cost_usd, paid_status.
    case foodScanCost                 = "food_scan_cost"
    case foodBudgetCapHit             = "food_budget_cap_hit"
    case foodRateLimitHit             = "food_rate_limit_hit"
}

/// Sink protocol for pluggable backends. Add an implementation and
/// append it to `Analytics.sinks` to start sending events somewhere.
///
/// `sendScreen` is required so dispatch goes through the witness table
/// (not protocol-extension static dispatch) — the concrete sink's
/// override must actually fire when called via the `[AnalyticsSink]`
/// array. Conforming types that don't have a richer screen concept can
/// rely on the default extension implementation.
protocol AnalyticsSink {
    func send(event: String, properties: [String: Any])
    func sendScreen(name: String)
}

/// Console sink — DEBUG only. Logs every event as `[ANALYTICS] event { … }`
/// so the funnel is visible while developing without needing a backend.
struct ConsoleAnalyticsSink: AnalyticsSink {
    func send(event: String, properties: [String: Any]) {
        #if DEBUG
        let propsString = properties.isEmpty ? "" : " \(properties)"
        print("[ANALYTICS] \(event)\(propsString)")
        #endif
    }
}

enum Analytics {
    /// Mutable so PlankAIApp can append a real provider sink at launch
    /// (PostHog, RevenueCat, etc.) without changing call sites.
    nonisolated(unsafe) static var sinks: [AnalyticsSink] = [ConsoleAnalyticsSink()]

    /// App version, stamped on every event. Lets funnel queries split
    /// by build without each call site passing it.
    private static let appVersion: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }()

    /// Background queue so analytics never blocks UI. Serial so the
    /// sink list isn't read while being mutated mid-track.
    private static let queue = DispatchQueue(label: "ai.jenifit.analytics", qos: .utility)

    /// Coalesce window for de-duping rapid repeats of the same event
    /// (e.g. SwiftUI onAppear firing more than once on the same screen).
    private static let coalesceWindow: TimeInterval = 0.5
    nonisolated(unsafe) private static var lastFired: [String: Date] = [:]

    static func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        track(event.rawValue, properties: properties)
    }

    /// Free-form variant for events that aren't in the enum yet — keeps
    /// us unblocked during prototyping. Prefer the enum form.
    static func track(_ event: String, properties: [String: Any] = [:]) {
        let coalesceKey = makeCoalesceKey(event: event, properties: properties)
        let now = Date()
        if let last = lastFired[coalesceKey], now.timeIntervalSince(last) < coalesceWindow {
            return
        }
        lastFired[coalesceKey] = now

        var merged = properties
        merged["app_version"] = appVersion
        merged["timestamp"]   = ISO8601DateFormatter().string(from: now)
        // Environment stamp so PostHog (and any other sink) can split
        // dev traffic from real users. The PostHog setup additionally
        // registers `is_test_user: true` as a super-property in DEBUG
        // so PostHog's native "Internal & test accounts" filter sees
        // the test traffic — see bootstrapAnalytics in PlankAIApp.
        #if DEBUG
        merged["environment"]  = "debug"
        merged["is_test_user"] = true
        #else
        merged["environment"]  = "production"
        #endif

        queue.async {
            for sink in sinks {
                sink.send(event: event, properties: merged)
            }
        }
    }

    /// Reset coalesce state — only used by tests. Production never
    /// needs this since lastFired entries are tiny and self-expire
    /// via the window check.
    static func _resetForTests() {
        lastFired.removeAll()
    }

    /// Capture a handled Swift error to PostHog Error Tracking. Fires the
    /// `$exception` event so it groups alongside the SDK's native crash
    /// auto-capture. `context` is a short string identifying the call site
    /// (e.g. "payment.offerings_load") so the same error type from
    /// different code paths stays distinguishable. Additional properties
    /// (user id, product id, etc.) flow through `properties`.
    static func trackException(_ error: Error, context: String, properties: [String: Any] = [:]) {
        var merged = properties
        merged["$exception_message"] = String(describing: error)
        merged["$exception_type"]    = String(reflecting: type(of: error))
        merged["error_context"]      = context
        track("$exception", properties: merged)
    }

    private static func makeCoalesceKey(event: String, properties: [String: Any]) -> String {
        // Step-level events de-dupe by step_id so the same step doesn't
        // fire twice from a back-nav remount within the window. Other
        // events de-dupe by name only.
        if let stepId = properties["step_id"] {
            return "\(event):\(stepId)"
        }
        if let stage = properties["stage_index"] {
            return "\(event):\(stage)"
        }
        return event
    }
}

// MARK: - Screen attribution

/// SwiftUI modifier that emits a PostHog `$screen` event on appear so
/// rageclicks, paths, and other implicit events get attributed to a
/// named surface instead of the generic UIHostingController.
private struct PostHogScreenModifier: ViewModifier {
    let name: String
    func body(content: Content) -> some View {
        content.onAppear {
            Analytics.captureScreen(name)
        }
    }
}

extension View {
    /// Tag the receiver as a named screen for analytics. Apply to the
    /// top-level view of each major surface (Home, Paywall, individual
    /// onboarding steps, workout session, settings hub, etc).
    func posthogScreen(_ name: String) -> some View {
        modifier(PostHogScreenModifier(name: name))
    }
}

extension Analytics {
    /// Notify analytics sinks of a screen transition. PostHog's native
    /// `screen(_:)` API registers the screen as a session-current value,
    /// so subsequent `$rageclick` / `$autocapture` / custom events get
    /// auto-tagged with the screen name — the whole point of this
    /// attribution pass. Sinks that don't have a screen concept fall
    /// back to a regular `$screen` event so DEBUG console transitions
    /// stay visible in Xcode.
    static func captureScreen(_ name: String) {
        // Coalesce within 0.5s so SwiftUI onAppear double-fires on a single
        // navigation don't surface twice. Implemented at the sink-routing
        // layer here since `track(...)`'s coalesce keys on event+stepId.
        let key = "$screen:\(name)"
        let now = Date()
        if let last = screenLastFired[key], now.timeIntervalSince(last) < coalesceWindow {
            return
        }
        screenLastFired[key] = now
        queue.async {
            for sink in sinks {
                sink.sendScreen(name: name)
            }
        }
    }

    nonisolated(unsafe) private static var screenLastFired: [String: Date] = [:]
}

/// Default screen-transition handling for sinks. Override in a sink
/// that has a richer screen concept (PostHog's `screen(_:)` API
/// registers the value as a session-current property so subsequent
/// implicit events get tagged with it).
extension AnalyticsSink {
    func sendScreen(name: String) {
        send(event: "$screen", properties: ["$screen_name": name])
    }

    private static func makeCoalesceKey(event: String, properties: [String: Any]) -> String {
        // Step-level events de-dupe by step_id so the same step doesn't
        // fire twice from a back-nav remount within the window. Other
        // events de-dupe by name only.
        if let stepId = properties["step_id"] {
            return "\(event):\(stepId)"
        }
        if let stage = properties["stage_index"] {
            return "\(event):\(stage)"
        }
        return event
    }
}
