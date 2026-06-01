import Foundation

// MARK: - RevenueCat configuration
//
// The iOS API key below is intentionally checked into source. It is safe to
// expose in client code: RevenueCat treats it as a public client identifier
// and authenticates purchases through Apple's StoreKit + App Store receipts,
// not through the key itself. Server-side webhook secrets must NEVER appear
// here — those stay in your dashboard / secrets manager only.
//
// Mirrors the SupabaseConfig.swift pattern: enum with static constants, no
// instances. All payment code references RevenueCatConfig.* — never inline
// strings.

enum RevenueCatConfig {
    /// Public iOS SDK key. Found in RevenueCat dashboard → Project settings
    /// → API keys → Public app-specific API key for the iOS app.
    static let apiKey = "appl_TEIuDMAvszcpVlmlJAvvXViohnJ"

    /// The single entitlement gating Pro access across the app. Configured
    /// in RevenueCat dashboard → Entitlements.
    static let entitlementID = "pro"

    /// Default offering identifier. The current offering returned by
    /// `Purchases.shared.offerings()` will be the one named here (or the
    /// dashboard-marked default if this changes).
    static let offeringID = "default"

    /// Downsell offering identifier. Presented by DownsellPaywallView when
    /// the user dismisses the main paywall for the first time per install.
    /// Configure in RevenueCat dashboard → Offerings: create an offering
    /// named `discount` containing a single annual Package that maps to
    /// `ProductID.yearlyDiscount` below.
    static let discountOfferingID = "discount"

    /// DEBUG-only preview offering for v1.0.7 paywall verification. Lets
    /// the founder use a separate RC offering (with the new 3-tier
    /// packages) without touching the production `default` offering —
    /// so existing v1.0.6 users keep seeing the legacy 2-tier offering
    /// while the founder's debug build sees the new 3-tier layout.
    /// PaywallView.loadOfferings() prefers this when available in
    /// DEBUG; release builds always use `offeringID`.
    ///
    /// 2026-05-31: renamed `v1_0_7_preview` → `v1_0_7` after the founder
    /// rebuilt the offering with a cleaner identifier. The original
    /// preview offering was deleted in the rebuild.
    static let previewOfferingID = "v1_0_7"

    /// App Store Connect product identifiers. Must match the SKU strings
    /// configured in App Store Connect → Subscriptions exactly.
    ///
    /// 2026-05-30 (epic #1 child #3): the ACTIVE constants below still
    /// point at v1.0.6 legacy IDs so existing users + the current ASC
    /// offering keep working. The `V2` nested enum scaffolds the new
    /// 3-tier pricing IDs (annual $47.99 + quarterly $24.99 + weekly
    /// $5.99) for the v1.0.7 migration. Migration steps when ready:
    ///   1. Founder creates 6 new products in App Store Connect:
    ///      jenifit_yearly_v2 / jenifit_quarterly / jenifit_weekly_v2
    ///      + 3 *_discount variants. Sets "preserve current price for
    ///      existing subscribers" on the 3 legacy products to grandfather
    ///      v1.0 cohort at original price forever.
    ///   2. Founder reconfigures RC `default` + `discount` offerings to
    ///      point at the new product IDs.
    ///   3. Swap `weekly`, `yearly`, `yearlyDiscount` below to use the
    ///      `V2.*` values. The PaywallView 3-tier rendering + goal-aware
    ///      default selection logic activates simultaneously.
    enum ProductID {
        /// $4.99/week, no introductory offer (v1.0.6 active).
        static let weekly = "absmaxxing_weekly"
        /// $69.99/year with a 3-day free trial introductory offer
        /// (v1.0.6 active).
        static let yearly = "absmaxxing_yearly"
        /// $34.99/year — 50% off the standard yearly, no trial
        /// (v1.0.6 active; downsell offering).
        static let yearlyDiscount = "jenifit_yearly_discount"

        /// 2026-05-30: quarterly + tier-specific discount product IDs
        /// pre-activated for the v1.0.7 paywall redesign. These point
        /// directly at the new App Store Connect SKUs (no V2 indirection)
        /// because they have no legacy equivalents — they're net-new
        /// tiers introduced in v1.0.7. Self-gating: if the RC offering
        /// doesn't contain a package with these product IDs, the
        /// PaywallView's `quarterlyPackage` (etc.) returns nil and the
        /// corresponding card simply doesn't render. So shipping these
        /// constants is safe BEFORE Apple approves the SKUs + RC
        /// reconfigures the default + discount offerings.
        static let quarterly = "jenifit_quarterly"
        static let quarterlyDiscount = "jenifit_quarterly_discount"
        static let weeklyDiscount = "jenifit_weekly_discount"

        /// v1.0.7 pre-staged product IDs. Scaffolded but NOT yet
        /// referenced by the active code paths — those still resolve
        /// against the legacy constants above. Activated by swapping
        /// the active constants when the corresponding SKUs exist in
        /// App Store Connect (founder action). The PaywallView 3-tier
        /// rendering already accepts a `quarterly` package without
        /// crashing; it just won't render the third card until both
        /// the SKU + the RC offering reconfig are live.
        enum V2 {
            static let weekly         = "jenifit_weekly_v2"
            static let quarterly      = "jenifit_quarterly"
            static let yearly         = "jenifit_yearly_v2"
            static let weeklyDiscount    = "jenifit_weekly_discount"
            static let quarterlyDiscount = "jenifit_quarterly_discount"
            static let yearlyDiscount    = "jenifit_yearly_discount_v2"
        }
    }
}
