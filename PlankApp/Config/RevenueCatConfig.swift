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

    /// App Store Connect product identifiers. Must match the SKU strings
    /// configured in App Store Connect → Subscriptions exactly.
    enum ProductID {
        /// $4.99/week, no introductory offer.
        static let weekly = "absmaxxing_weekly"
        /// $29.99/year with a 3-day free trial introductory offer.
        static let yearly = "absmaxxing_yearly"
    }
}
