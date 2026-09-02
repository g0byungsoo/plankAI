import Foundation
import SwiftUI

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
        /// p57 — the on-medication chapter counts UP (p53's cohort
        /// grammar): under stays spoken, "over" is never said. Home
        /// has refused the word for this cohort since p53; the
        /// reading's day line follows the same law now.
        public let countUpOnly: Bool
        public init(kcalEatenToday: Int, kcalTarget: Int?, countUpOnly: Bool = false) {
            self.kcalEatenToday = kcalEatenToday
            self.kcalTarget = kcalTarget
            self.countUpOnly = countUpOnly
        }
    }

    /// The reading's one-sentence day position, pure so the law is
    /// testable: room left after this plate, in Home's own voice.
    /// nil = no honest sentence (no target, or an over-position for a
    /// count-up cohort — the same silence Home keeps).
    nonisolated public static func dayLine(
        context: SnapDayContext, plateKcal: Int
    ) -> (prefix: String, punch: String, suffix: String)? {
        guard let target = context.kcalTarget, target > 0 else { return nil }
        let after = context.kcalEatenToday + plateKcal
        let room = target - after
        if room >= 150 {
            // Nearest 50 — "about 600", never "612".
            let rounded = (room / 50) * 50
            return ("", "\(rounded) left", " today after this")
        }
        if room >= -60 {
            // Under ~150 the honest read isn't a number, it's "you've
            // arrived" — a 50-kcal remainder is not an invitation.
            return ("", "right at", " your target today")
        }
        // p53's cohort grammar, now on BOTH surfaces that render the
        // position: the on-medication chapter never hears "over" —
        // the medication is already doing the deficit, and the word
        // is the market's named harm for this cohort. Silence, the
        // same answer Home gives.
        if context.countUpOnly { return nil }
        return ("a little ", "over", " today")
    }
    public static var dayContextProvider: (@MainActor () -> SnapDayContext?)?

    /// p61 — the safety gate's numeric suppression, threaded to the
    /// package's HISTORY surfaces. The reading already suppresses
    /// through its providers (a suppressed cohort gets a nil kcal
    /// target and the answer engine's words-only face), but the BOOK
    /// and the again rail rendered "540 kcal" to cohorts every other
    /// surface protects. False when the app never registers it.
    public static var numericsSuppressedProvider: (@MainActor () -> Bool)?

    @MainActor
    static var numericsSuppressed: Bool {
        numericsSuppressedProvider?() ?? false
    }

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
        /// p63 — true when this plate carried the day across its
        /// protein floor: the reading's confirm speaks the crest
        /// haptic instead of the stock success. Composed app-side;
        /// the package never learns why a plate crested.
        public let crest: Bool
        /// p64 — the celebration the answer carries, decided app-side
        /// ("spark" | "crest" | "moment"; nil = none). The package
        /// renders whatever view `burstOverlay` returns for the word
        /// and picks the matching haptic; it never learns what earned
        /// the moment.
        public let burst: String?
        public init(
            text: String, punch: String, crest: Bool = false,
            burst: String? = nil
        ) {
            self.text = text
            self.punch = punch
            self.crest = crest
            self.burst = burst
        }
    }
    public static var plateAnswerProvider: (@MainActor (Int) -> PlateAnswer?)?

    /// p63 — the crest haptic, injected by the app (the package owns
    /// no haptic grammar). Fired only for an answer whose `crest` is
    /// true; nil falls back to the stock success confirm.
    public static var crestHaptic: (@MainActor () -> Void)?

    /// p64 — the spark haptic (a SMALL celebration's tactile half),
    /// injected like the crest. Fired for an answer whose `burst` is
    /// "spark" when `crest` is false; nil falls back to the stock
    /// success confirm.
    public static var sparkHaptic: (@MainActor () -> Void)?

    /// p64 — the celebration visual, injected by the app: given the
    /// answer's `burst` word, returns the particle view mounted over
    /// the answer sentence (JeniBurst app-side; the package owns no
    /// particle engine). The view must be non-hit-testing and play
    /// on appear. nil = the words and haptic carry the moment alone.
    public static var burstOverlay: (@MainActor (String) -> AnyView)?

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
