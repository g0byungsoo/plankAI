import Foundation

// MARK: - BuildChannel (v25 E8 — THE MERGE)
//
// Which build is this, at RUNTIME.
//
// Why this exists: until E8 the environment stamp was a COMPILE-time
// split — `#if DEBUG` → "debug", everything else → "production".
// TestFlight builds compile as RELEASE. So every internal tester, every
// device walk and every founder session landed in PostHog wearing the
// same clothes as a paying App Store customer, on both the event and
// the person profile.
//
// That is not a cosmetic problem. E5's finding — "105 of 160
// `main_tab_appeared` users never purchased on a hard-gated app" — is
// only explicable if the denominator contained builds that skip the
// wall. E6 then concluded from numbers like these that "production data
// cannot currently discriminate between in-app features". The data was
// not mute; it was contaminated, and nothing in the pipeline could say
// so.
//
// The mechanism is Apple's own: an App Store receipt is named
// `receipt`; a TestFlight or locally-installed build gets
// `sandboxReceipt`. No network call, no SDK, no async — readable on the
// first frame, which is where the super-property has to be registered.
//
// Deliberately NOT done here:
//   - No attempt to reclassify history. Events emitted before this
//     build carry the old two-value stamp and cannot be repaired;
//     pretending otherwise would invent precision that does not exist.
//     Cohort reads should be dated from the first release carrying
//     `environment == "testflight"`.
//   - No device/user identifiers beyond what DEBUG already registered.
//     The channel is categorical by construction (three values), so it
//     satisfies AnalyticsHygiene without an allowlist exception.

enum BuildChannel: String {

    /// Built and run from Xcode (simulator or attached device).
    case debug      = "debug"
    /// Signed release installed through TestFlight — an internal tester.
    case testflight = "testflight"
    /// Shipped through the App Store — a real customer.
    case appStore   = "production"

    // MARK: - Detection

    /// The pure core, so the classification is testable without a
    /// bundle. `receiptName` is the last path component of
    /// `Bundle.main.appStoreReceiptURL` (nil when no receipt exists —
    /// a fresh App Store install before the first receipt refresh, and
    /// every simulator run).
    ///
    /// `isDebugBuild` is passed in rather than read from `#if DEBUG` so
    /// both branches are reachable from a test running in a debug
    /// process.
    static func resolve(receiptName: String?, isDebugBuild: Bool) -> BuildChannel {
        if isDebugBuild { return .debug }
        // Apple names the sandbox receipt `sandboxReceipt`; the App
        // Store one is `receipt`. Case-insensitive because the exact
        // casing is a documented-by-convention detail, not a contract.
        if let name = receiptName,
           name.lowercased().contains("sandbox") {
            return .testflight
        }
        // No receipt at all: a release build that has never talked to
        // the store. Treating it as App Store is the conservative call
        // — the alternative would quietly relabel real customers as
        // testers and shrink the very denominator this fix protects.
        return .appStore
    }

    /// The live value for this process. Resolved once — the receipt URL
    /// does not change within a launch, and this is read on the launch
    /// path.
    static let current: BuildChannel = {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        return resolve(
            receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent,
            isDebugBuild: isDebug
        )
    }()

    // MARK: - What analytics does with it

    /// The `environment` stamp. `appStore` keeps the historical string
    /// "production" so every existing insight, funnel and cohort filter
    /// keeps resolving — this change SPLITS a value, it does not rename
    /// one.
    var environmentValue: String { rawValue }

    /// Feeds PostHog's native "Internal & test accounts" filter. Both
    /// non-store channels are internal traffic.
    var isTestUser: Bool {
        switch self {
        case .debug, .testflight: return true
        case .appStore:           return false
        }
    }
}
