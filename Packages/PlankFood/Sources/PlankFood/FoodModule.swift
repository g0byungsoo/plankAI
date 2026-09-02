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
        /// p65 — THE MOMENT SYSTEM. A commit that earned the
        /// full-page celebration carries its payload; nil = the
        /// in-place receipt (the answer sentence) is the whole
        /// acknowledgment. Decided app-side; the package presents
        /// whatever `momentView` builds and never learns what earned
        /// it. (p64's in-sheet burst/crest fields died here — the
        /// founder: a meaningful commit is a moment, not particles
        /// over the sheet it happens to share.)
        public let moment: PlateMoment?
        public init(
            text: String, punch: String, moment: PlateMoment? = nil
        ) {
            self.text = text
            self.punch = punch
            self.moment = moment
        }
    }

    /// p65 — the full-page celebration's payload: semantic cargo the
    /// app composes and the app renders; the package only carries it
    /// across the commit (one celebration language, many moments).
    public struct PlateMoment: Equatable, Sendable {
        /// Closed analytics vocabulary ("first_plate_ever" …).
        public let occasion: String
        /// The whisper above the headline ("on file.") — persistence
        /// stated, because the moment only exists after the save.
        public let eyebrow: String?
        /// The one thing being celebrated ("today's first plate.").
        public let headline: String
        /// The italic run inside the headline (substring, or empty).
        public let punch: String
        /// The record's answer beneath it ("17 of 120 g of protein.").
        public let fact: String?
        /// Intensity: "spark" | "crest" | "moment" (rarity-mapped).
        public let tier: String
        /// The one way out — lands back on the surface she came from.
        public let cta: String
        public init(
            occasion: String, eyebrow: String?, headline: String,
            punch: String, fact: String?, tier: String,
            cta: String = "continue"
        ) {
            self.occasion = occasion
            self.eyebrow = eyebrow
            self.headline = headline
            self.punch = punch
            self.fact = fact
            self.tier = tier
            self.cta = cta
        }
    }

    /// p65 — called AFTER the plate persisted (the p64 provider ran
    /// at compose time, before the save — a celebration could outrun
    /// the record). The app's arithmetic accounts for the plate
    /// already being on file.
    public static var plateAnswerProvider: (@MainActor (Int) -> PlateAnswer?)?

    /// p65 — the full-page celebration surface, injected by the app
    /// (JeniMomentView; the package owns no celebration visual). The
    /// second argument is the continue handler — the host advances
    /// the flow (dismiss → the surface she came from) when called.
    public static var momentView: (@MainActor (PlateMoment, @escaping () -> Void) -> AnyView)?

    /// p58's one commit hand, injected (JeniHaptic.record). Fired
    /// when a plate files WITHOUT a moment — the receipt's tactile
    /// half. nil falls back to the stock success notification.
    public static var recordHaptic: (@MainActor () -> Void)?

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
