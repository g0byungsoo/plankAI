import Foundation
import PostHog

// MARK: - PostHogSink
//
// Adapts the AnalyticsSink protocol to PostHog's iOS SDK. Append an
// instance to `Analytics.sinks` after `PostHogSDK.shared.setup(...)`
// has been called (see PlankAIApp). Every existing
// `Analytics.track(...)` call flows through to PostHog without any
// call-site changes.
//
// Why a thin wrapper instead of calling PostHogSDK directly from each
// site: keeps the option open to swap providers, plug in a second
// sink (e.g. send the same events to RevenueCat or a debug overlay)
// without touching the 30+ track calls scattered through the app.

struct PostHogSink: AnalyticsSink {
    func send(event: String, properties: [String: Any]) {
        // PostHog's capture signature accepts `[String: Any]` directly.
        // app_version / timestamp are already stamped by the Analytics
        // wrapper, so we pass `properties` through untouched.
        PostHogSDK.shared.capture(event, properties: properties)
    }
}
