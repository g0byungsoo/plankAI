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

    /// NutritionLookupService instance for the per-item density join
    /// after FoodVisionService identifies items. nil = dispatcher
    /// returns items with kcal-nil and the result card shows
    /// "couldn't ID this" per item (safe default).
    public static var nutritionLookup: NutritionLookupService?

    /// App v2 — the canonical protein target, injected by the app so
    /// the package renders the SAME number as Today/Becoming/chat
    /// (pre-v2 the snap result computed its own 1.0 g/kg while the
    /// app showed 1.2/1.6 — contradictory targets, audit defect #1).
    /// nil provider or nil result → package-local fallback formula.
    public static var proteinTargetProvider: (@MainActor () -> Int?)?

    /// v5.1 — today's food state at scan time, injected by the app so
    /// the result card can answer "how does this land in my day?"
    /// with the SAME provenance as Home's kcal bar (TargetsService +
    /// todayMacros). kcalTarget nil = suppressed cohort or no plan:
    /// the day line simply doesn't render. nil provider = same.
    public struct SnapDayContext: Equatable, Sendable {
        public let kcalEatenToday: Int
        public let kcalTarget: Int?
        public init(kcalEatenToday: Int, kcalTarget: Int?) {
            self.kcalEatenToday = kcalEatenToday
            self.kcalTarget = kcalTarget
        }
    }
    public static var dayContextProvider: (@MainActor () -> SnapDayContext?)?

    /// v25 E7 SAY IT — the sentence the reading resolves to when a
    /// plate files. Composed app-side by `PlateAnswerEngine` (the same
    /// engine the capture surface's standing line uses) so the package
    /// never learns about targets, cohorts or the safety gate; it just
    /// asks "this plate has N grams of protein — what is true now?"
    ///
    /// `punch` is guaranteed to be a substring of `text` and carries
    /// the italic serif inside otherwise flat prose. nil provider →
    /// the reading files exactly as it did before this era.
    public struct PlateAnswer: Equatable, Sendable {
        public let text: String
        public let punch: String
        public init(text: String, punch: String) {
            self.text = text
            self.punch = punch
        }
    }
    public static var plateAnswerProvider: (@MainActor (Int) -> PlateAnswer?)?

    /// One-shot setup at app launch. Idempotent — calling again
    /// replaces services (useful for DEBUG re-configure / hot reload).
    public static func configure(
        visionService: FoodVisionService? = nil,
        nutritionLookup: NutritionLookupService? = nil,
        proteinTargetProvider: (@MainActor () -> Int?)? = nil,
        dayContextProvider: (@MainActor () -> SnapDayContext?)? = nil
    ) {
        if let visionService { Self.visionService = visionService }
        if let nutritionLookup { Self.nutritionLookup = nutritionLookup }
        if let proteinTargetProvider { Self.proteinTargetProvider = proteinTargetProvider }
        if let dayContextProvider { Self.dayContextProvider = dayContextProvider }
    }

    /// Resets all configured services. Used by tests + by Settings
    /// "sign out" handling if the food rail needs to detach from the
    /// previous user's auth context. Production sign-out doesn't have
    /// to call this — the tokenProvider closures will simply return
    /// nil on the next scan/lookup.
    public static func reset() {
        Self.visionService = nil
        Self.nutritionLookup = nil
    }
}
