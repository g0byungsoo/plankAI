import Foundation
import PostHog

// MARK: - FoodFlagsEntitlementProvider

/// Abstracts the paywall entitlement check so PlankFood doesn't have to
/// import the main app target (which would cycle: app -> PlankFood,
/// PlankFood -> app). The main app provides conformance via an extension
/// on PaymentService — `hasProAccess` already matches the protocol shape.
@MainActor
public protocol FoodFlagsEntitlementProvider: AnyObject {
    var hasProAccess: Bool { get }
}

// MARK: - FoodFlags

/// 3-layer feature flag stack per v3 §Architecture + v5 D26.
///
/// Layers, evaluated in order:
///
/// 1. **DEBUG** — `UserDefaults` `food_rail_dev_override` Bool. If true,
///    short-circuits to `isEnabled == true` regardless of other layers.
///    Set via DebugAuthView toggle. Compiled out of Release builds.
/// 2. **Paid gate** — `entitlement.hasProAccess` must be true (RevenueCat
///    `pro` entitlement). Non-paying users see no food UI at all
///    (or `FoodRailComingSoonCard` if surfaced from main app code).
/// 3. **PostHog rollout** — `food_rail_v1` flag must be on for the
///    current user's distinct_id. Lets us ramp 0% -> 10% -> 50% -> 100%
///    via PostHog dashboard without an app deploy.
///
/// Set `entitlement` once at app launch (PlankAIApp init / first task).
/// PostHog must be configured (`PostHogSDK.shared.setup(...)`) before
/// any `isEnabled` read; the layer #3 check returns false on missing
/// PostHog config which is the safe default.
@MainActor
public enum FoodFlags {

    /// Provider for the paid-entitlement check (layer #2). nil until
    /// `configure(entitlement:)` runs at app launch; isEnabled returns
    /// false while nil — also the safe default.
    public static var entitlement: FoodFlagsEntitlementProvider?

    public static let postHogFlagName = "food_rail_v1"

    /// UserDefaults key for the DEBUG-only force-on toggle. Surfaced in
    /// DebugAuthView. Compiled out of Release via `#if DEBUG`.
    public static let devOverrideKey = "food_rail_dev_override"

    /// Configure the flag stack at app launch.
    /// - Parameter entitlement: the PaymentService (or other conformer).
    public static func configure(entitlement: FoodFlagsEntitlementProvider) {
        Self.entitlement = entitlement
    }

    /// Whether the food rail UI should render for the current user.
    /// Three layers must clear (DEBUG short-circuit aside): configured +
    /// paid + PostHog flag on.
    public static var isEnabled: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: devOverrideKey) {
            return true
        }
        #endif
        guard let entitlement, entitlement.hasProAccess else {
            return false
        }
        return PostHogSDK.shared.isFeatureEnabled(postHogFlagName)
    }

    /// Force PostHog to refresh feature flags. Call after auth state
    /// changes (sign in / sign out / anon-to-Apple upgrade) so the
    /// user's distinct_id is fresh on the next isEnabled read.
    public static func reloadFlags() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            PostHogSDK.shared.reloadFeatureFlags {
                continuation.resume()
            }
        }
    }
}
