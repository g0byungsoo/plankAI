import Foundation

// Feature flag for "The JeniFit Method" post-purchase ritual flow.
// Default ON now (Phase 1 of the onboarding conversion pass). The
// onboarding flow previews this feature on case 250 before the paywall,
// so the flag MUST be on or the preview lies about what the user is
// buying. UserDefaults-backed so the debug menu can still toggle off
// for testing — `object(forKey:)` returns nil when never set, which
// preserves the true default; an explicit `false` write wins.
enum JeniMethodFeatureFlag {
    private static let key = "jenimethod.feature_enabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: key)
    }
}
