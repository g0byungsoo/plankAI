import Foundation

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
    case consentRitualViewed        = "consent_ritual_viewed"
    case consentRitualSigned        = "consent_ritual_signed"
    case consentRitualSkipped       = "consent_ritual_skipped"
    case consentRitualAbandoned     = "consent_ritual_abandoned"

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
}

/// Sink protocol for pluggable backends. Add an implementation and
/// append it to `Analytics.sinks` to start sending events somewhere.
protocol AnalyticsSink {
    func send(event: String, properties: [String: Any])
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
