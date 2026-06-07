import Foundation

// MARK: - TikTok Business SDK configuration
//
// Wires the TikTok Business SDK for app-install attribution from
// TikTok ads (Ads Manager) to TestFlight/App Store installs of
// JeniFit. Three values feed into TikTokConfig at SDK init:
//
//   - tiktokAppId:   given by TikTok Events Manager (NOT secret)
//   - appleAppId:    the numeric App Store ID, public once shipped
//   - appSecret:     TikTok-issued, kept here but lands in the
//                    iOS binary — same accepted constraint as
//                    PostHogAppConfig.apiKey + RevenueCatConfig.apiKey
//
// Where to find each value (founder reference):
//
//   tiktokAppId: TikTok Ads Manager → Assets → Events → App Events
//                → your app → Properties → "TikTok App ID"
//   appleAppId:  App Store Connect → My Apps → JeniFit → App
//                Information → "Apple ID" (numeric, e.g. 6443456789)
//   appSecret:   TikTok Ads Manager → Assets → Events → App Events
//                → your app → Settings → "App Secret"
//                (TikTok says "for verification" — the SDK uses it
//                to sign requests from the device)
//
// Mirrors the PostHogAppConfig.swift pattern: enum with static
// constants, no instances. The PlankAIApp.init() init code reads
// `TikTokAppConfig.makeSdkConfig()` and short-circuits SDK init if
// `isConfigured` is false (i.e. placeholders are still in place),
// so the build keeps working in DEBUG until the founder drops in
// production values.
//
// Linker flags reminder: TikTok Business SDK requires `-ObjC` and
// `-lc++` in the iOS target's Other Linker Flags (Xcode → target →
// Build Settings → Linking → Other Linker Flags). Without them,
// the app crashes on launch in `+[TikTokBusiness initializeSdk:]`
// with a missing-selector error.

import TikTokBusinessSDK

enum TikTokAppConfig {

    /// TikTok Events Manager → App → Properties → "TikTok App ID".
    /// Hardcoded — given by TikTok in the integration brief
    /// (2026-06-07 onboarding). Not secret.
    static let tiktokAppId = "7647803278667087893"

    /// App Store Connect → My Apps → JeniFit: Lose Weight → App
    /// Information → "Apple ID" (numeric). NOT the bundle ID
    /// (`com.bk.plankAI`) and NOT the SKU.
    ///
    /// TODO(founder): drop the numeric Apple App Store ID in here
    /// once the App Store Connect record is finalized.
    static let appleAppId = ""

    /// TikTok Ads Manager → App Events → Settings → "App Secret".
    /// Ships in the iOS binary — that's the accepted constraint for
    /// every iOS attribution SDK (same as PostHogAppConfig.apiKey,
    /// RevenueCatConfig.apiKey). The truly-sensitive personal API
    /// key for the TikTok Ads Manager dashboard NEVER goes here;
    /// that stays in your TikTok dashboard / secrets manager.
    ///
    /// TODO(founder): drop the App Secret here.
    static let appSecret = ""

    /// All three values present + non-empty. SDK init short-circuits
    /// when this is false so DEBUG builds keep compiling + running
    /// with the placeholders in place.
    static var isConfigured: Bool {
        !appleAppId.isEmpty && !appSecret.isEmpty && !tiktokAppId.isEmpty
    }

    /// Build the SDK config. Returns nil when any required value is
    /// still a placeholder — the caller skips init in that case.
    /// All auto-tracking events stay enabled (Install + Launch +
    /// 2DRetention + Purchase) since those ARE the optimization
    /// signal TikTok's CPI bidder wants. SKAdNetwork support also
    /// stays enabled because JeniFit doesn't use a third-party MMP
    /// (Adjust / AppsFlyer / Branch) to own the SKAN postback chain.
    static func makeSdkConfig() -> TikTokConfig? {
        guard isConfigured else { return nil }
        return TikTokConfig(
            accessToken: appSecret,
            appId: appleAppId,
            tiktokAppId: tiktokAppId
        )
    }
}
