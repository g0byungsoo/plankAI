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

    /// App Store Connect product identifiers. Must match the SKU strings
    /// configured in App Store Connect → Subscriptions exactly.
    enum ProductID {
        /// $4.99/week, no introductory offer.
        static let weekly = "absmaxxing_weekly"
        /// $69.99/year with a 3-day free trial introductory offer.
        static let yearly = "absmaxxing_yearly"
        /// $34.99/year — 50% off the standard yearly, no trial. Create in
        /// App Store Connect as a new auto-renewable subscription in the
        /// SAME subscription group as the yearly above so users who claim
        /// the downsell can later upgrade/downgrade without leaving the
        /// group. No introductory offer (trial-stacking with the standard
        /// yearly's 3-day trial would require additional StoreKit nuance).
        static let yearlyDiscount = "jenifit_yearly_discount"
    }
}
