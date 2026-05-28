import Foundation

// MARK: - PostHog configuration
//
// PostHog project tokens (`phc_…`) are write-only public client keys by
// design — safe to ship in source, same stance as `RevenueCatConfig.apiKey`
// (Apple-only client key, validated server-side via App Store receipts).
// Server-side personal API keys (`phx_…`) must NEVER appear here; those
// stay in the PostHog dashboard / your secrets manager.
//
// Mirrors the RevenueCatConfig.swift pattern: enum with static constants,
// no instances. All analytics-bootstrap code references PostHogAppConfig.*
// — never inline strings. The "App" suffix avoids a collision with the
// `PostHogConfig` type exported by the posthog-ios SDK itself.
//
// Values come from your .env (POSTHOG_PROJECT_TOKEN, POSTHOG_PROJECT_REGION).
// .env is not read at runtime on iOS; we inline the values here instead.

enum PostHogAppConfig {
    /// Project API key. PostHog → Project settings → Project API key.
    static let apiKey = "phc_oVaZWs7kvCzR8ZfHAMCJBBHH8ppofiSYVxD3jaLEMNmd"

    /// Ingest host. US Cloud = us.i.posthog.com, EU Cloud = eu.i.posthog.com.
    /// The PROJECT_REGION value from .env ("US Cloud") maps to this URL.
    static let host = "https://us.i.posthog.com"

    /// Whether to start a session replay recording. Off for v1 — replay
    /// requires explicit user opt-in for App Store privacy declarations.
    /// Enable later from PostHog dashboard + privacy disclosure update.
    static let sessionReplayEnabled = false

    /// Capture app lifecycle events ($app_opened, $app_backgrounded) +
    /// screen views automatically. Manual events (Analytics.track) still
    /// fire alongside these — the two streams coexist in PostHog.
    static let captureApplicationLifecycleEvents = true

    /// Disable automatic deep-link capture — JeniFit doesn't use deep
    /// links in v1, and the auto-capture adds noise to the funnel.
    static let captureDeepLinks = false
}
