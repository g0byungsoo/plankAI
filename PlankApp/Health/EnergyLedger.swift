import Foundation
import PlankFood
import PlankSync

// MARK: - EnergyLedger
//
// v1.1 "lighter days" (2026-06-11) — the founder's deficit insight,
// shipped per the evidence-honest spec in
// docs/becoming_deficit_insight_program_2026_06_11.md:
//
//   spent  = Mifflin-St Jeor BMR (caller-supplied, sex-aware) +
//            steps kcal + session kcal
//   gained = day's logged plates (conservative high-side ×1.2, since
//            entries store range midpoints and photo-AI intake error
//            runs 20-30% with a low bias)
//
// A day earns the "lighter" mark ONLY when every gate clears:
//   - coverage: ≥2 logged meals spanning ≥5h (thin logging days are
//     unclassifiable, never failures)
//   - plausibility: intake ≥ 0.6 × BMR (a 400-kcal logged day is a
//     logging gap, not a deficit)
//   - energy-availability floor: intake ≥ max(1200, BMR) — the counter
//     can never reward under-eating. BMR (Mifflin) ≈ 30 kcal/kg fat-free
//     mass for women, the clinical energy-availability target; the old
//     flat 1200 sat below the safe minimum for active/larger/lactating
//     women (v1.2 medical-grade, 2026-06-25)
//   - buffer: spent − gainedHigh ≥ max(300, 0.2 × gained) — combined
//     estimate error is ±350-500 kcal/day biased toward over-awarding,
//     so a filled dot must survive the worst case
//
// Vocabulary: the user-facing word is NEVER "deficit" (post-Ozempic
// kill-list). Days that don't earn the mark render identically to
// days that haven't happened — the mark is the only statement.
// Classification runs on CLOSED days only (never live today).

enum EnergyLedger {

    // MARK: BMR

    /// v25 E8.1 — `bmrFemale` DELETED, and it was hiding two things.
    ///
    /// It was Mifflin-St Jeor with the female constant (−161) hardcoded,
    /// under the comment "the cohort is exclusively women". That comment
    /// stopped being true when the product went unisex, and the male
    /// constant is +5, so a male user's basal rate was understated by
    /// about 166 kcal a day. A unisex defect in arithmetic rather than in
    /// copy, which is the kind that survives a copy sweep.
    ///
    /// It was also DEAD. Nothing called it. The live calorie path goes
    /// through `CalorieTargetCalculator.dailyTarget(sex:)`, which has been
    /// sex-aware all along — so the only thing this function could do was
    /// be revived by someone who trusted its comment.
    ///
    /// `spentKcal` and `isLighterDay` below have no callers either: the
    /// v1.1 "lighter days" mark is not currently rendered anywhere. They
    /// are LEFT IN PLACE rather than deleted, because removing a whole
    /// designed feature's engine is a product decision and this is a
    /// convergence release. Recorded as debt. Note that `spentKcal` takes
    /// `bmr` as an INPUT, so whoever revives it supplies a sex-aware value
    /// or none at all.

    /// 2026-08-14 — this was a SECOND copy of `representativeAge`, and
    /// the two disagreed in two places: `55plus` (60 here, 58 there) and
    /// the no-band default (30 here, 32 there). The pre-purchase reveal
    /// quotes a calorie target through this function and the app computes
    /// the daily target through the other one, so an over-55 user was
    /// quoted a number the product would then decline to reproduce. Same
    /// glyph, two arithmetics. It delegates now; the hyphen/plus aliases
    /// stay because legacy rows still carry them.
    static func ageMidpoint(fromRange range: String) -> Int {
        let canonical: String
        switch range {
        case "18-24": canonical = "18to24"
        case "25-34": canonical = "25to34"
        case "35-44": canonical = "35to44"
        case "45-54": canonical = "45to54"
        case "55+":   canonical = "55plus"
        default:      canonical = range
        }
        return TargetsService.representativeAge(band: canonical)
    }

    // MARK: Day classification

    struct DayInputs {
        let entries: [FoodLogPersister.FoodLogEntry]  // that day's logs
        let stepsCount: Int
        let sessionSeconds: Double
        let bmr: Double
        let isGLP1: Bool
    }

    static func spentKcal(_ inputs: DayInputs) -> Double {
        inputs.bmr
            + Double(inputs.stepsCount) * 0.04
            + (inputs.sessionSeconds / 60.0) * 5.0
        // breathwork intentionally contributes ZERO kcal (science-
        // honest lock: cortisol mechanism, not energy expenditure).
    }

    /// True when the day earns the lighter mark. False means
    /// "no statement", never "failure".
    static func isLighterDay(_ inputs: DayInputs) -> Bool {
        let entries = inputs.entries
        guard entries.count >= 2 else { return false }

        let times = entries.map(\.loggedAt)
        guard let first = times.min(), let last = times.max(),
              last.timeIntervalSince(first) >= 5 * 3600 else { return false }

        let gained = entries.reduce(0.0) { $0 + $1.kcal }
        let bmr = inputs.bmr
        guard bmr > 0 else { return false }

        // Plausibility + energy-availability floor.
        // v1.2 medical-grade (2026-06-25): the old flat ~1200 floor
        // (max(1200, BMR − 750) collapsed to 1200 for almost everyone) was
        // below the safe minimum for active/larger/lactating women, and
        // rewarding a sub-RMR day is exactly the under-eating trap this
        // counter must never fall into. We anchor the floor to the user's
        // own BMR — which for women is ~30 kcal/kg fat-free mass, the
        // clinical energy-availability target — with 1200 as a hard
        // absolute backstop. GLP-1 appetite suppression is addressed by
        // protein / muscle-preservation nudges elsewhere, never by
        // lowering this floor (that would reward the muscle-loss path).
        guard gained >= 0.6 * bmr else { return false }
        let floorKcal = max(1200, bmr)
        guard gained >= floorKcal else { return false }

        // Conservative high-side intake vs spent, with buffer.
        let gainedHigh = gained * 1.2
        let spent = spentKcal(inputs)
        return spent - gainedHigh >= max(300, 0.2 * gained)
    }
}

// MARK: - ClinicalTargets
//
// Medical-grade Phase 2.3 (2026-06-26) — the lean-mass-protection target the
// obesity + GLP-1 MDs flagged as the flagship clinical differentiator (the
// sarcopenia guardrail + the strongest pharma hook). Pure, deterministic,
// unit-tested. Wiring is flag-gated (`protein_hero_enabled`, default off) so
// existing customers see no change until the founder signs off.
enum ClinicalTargets {

    /// Daily protein floor (g) for lean-mass protection during weight loss.
    ///
    /// Phillips IJSNEM 2016 + Conte JCEM 2024 baseline is 1.2 g/kg; GLP-1
    /// cohorts get the protective top of the 1.2–1.6 g/kg band (1.6) — the
    /// appetite-suppression + rapid-loss path carries the highest sarcopenia
    /// risk, so it needs the most protein. Clamped to a plausible,
    /// non-alarming 80–160 g/day for women.
    ///
    /// `weightKg` is CURRENT body mass, not goal: using current weight keeps
    /// the floor protective for higher-BMI users instead of under-prescribing
    /// toward a distant goal (a "floors only raise" safety choice). Callers
    /// guard the no-weight case and render nothing rather than invent a body
    /// mass (data-provenance).
    static func proteinFloorGrams(weightKg: Double, isGLP1: Bool) -> Int {
        let perKg = isGLP1 ? 1.6 : 1.2
        return max(80, min(160, Int((perKg * weightKg).rounded())))
    }
}
