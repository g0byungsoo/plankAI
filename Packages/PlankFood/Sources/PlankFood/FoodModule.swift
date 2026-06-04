import Foundation

// MARK: - FoodModule
//
// Dependency-injection namespace for the food rail. The main app
// (PlankAIApp) configures everything at launch:
//
//   FoodModule.configure(
//       visionService: FoodVisionService(config: ...)
//   )
//
// PhotoCaptureView's FoodCaptureDispatcher then reads from
// FoodModule.visionService at scan time. Mirrors the FoodFlags pattern
// (static config configured once, read everywhere). Avoids importing
// the main app target from PlankFood (cycle).
//
// Per v3 D27: NO `FoodCoordinatorProtocol` or DI container abstraction
// until we have 3+ services that need to coordinate. Right now there's
// vision + nutrition lookup (W2-T4) + estimator (W2 TBD) — that's three,
// but they don't share enough behavior to justify a protocol. Static
// optionals are enough.

@MainActor
public enum FoodModule {

    /// FoodVisionService instance for `.photo` captures. nil until
    /// `configure(visionService:)` runs at app launch — dispatcher
    /// throws notImplemented while nil (safe default).
    public static var visionService: FoodVisionService?

    /// One-shot setup at app launch. Idempotent — calling again
    /// replaces the service (useful for DEBUG re-configure / hot
    /// reload during dev).
    public static func configure(visionService: FoodVisionService) {
        Self.visionService = visionService
    }

    /// Resets all configured services. Used by tests + by Settings
    /// "sign out" handling if the food rail needs to detach from the
    /// previous user's auth context. Production sign-out doesn't have
    /// to call this — the tokenProvider closure inside FoodVisionService
    /// will simply return nil on the next scan and the user sees the
    /// notAuthenticated copy.
    public static func reset() {
        Self.visionService = nil
    }
}
