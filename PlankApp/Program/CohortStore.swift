import Foundation

// MARK: - CohortStore
//
// App v2 (docs/app_v2/06_DATA_SUPABASE.md §A). The ONE reader of
// cohort-shaped onboarding keys. Before this existed, cohort flags
// were re-derived at 8+ call sites from raw AppStorage strings, and
// the CBT curriculum's `CohortFlags.fromAppStorage` read keys that
// had ZERO writers (`onb_glp1_status`, `onb_stress_level`,
// `onb_prior_attempts_count`, `onb_restrictive_food`, …) — so cohort
// personalization silently ran on defaults for every user.
//
// Rules:
//   - Canonical keys only (the DATA_CONTRACT names). No aliases.
//   - Pure value-type reads; no caching (UserDefaults IS the cache).
//   - Every consumer (prescription engine, brief engine, chat
//     context, curriculum, notifications, paywall copy) reads
//     through these accessors, never raw keys.
//   - Derivations that used to live inline (restrictive-risk from
//     food relationship) live here exactly once.

enum CohortStore {

    private static var d: UserDefaults { .standard }

    // MARK: - Raw canonical reads

    /// `none / considering / past / current / prefer_not_say / ""`
    static var glp1StatusKey: String {
        d.string(forKey: "onboarding_glp1_status") ?? ""
    }

    /// `just_started / few_months / established / prefer_not / ""`
    static var glp1PhaseKey: String {
        d.string(forKey: "onboarding_glp1_phase") ?? ""
    }

    /// `cycling / irregular / postpartum / perimenopause /
    ///  postmenopause / prefer_not_say / ""`
    static var hormonalStageKey: String {
        d.string(forKey: "onboardingHormonalStage") ?? ""
    }

    /// `under5 / five6 / six7 / seven8 / eightPlus / ""`
    static var sleepHoursKey: String {
        d.string(forKey: "onboardingSleepHours") ?? ""
    }

    /// `low / manageable / heavy / overwhelmed / ""`
    static var stressKey: String {
        d.string(forKey: "onboardingStressLevel") ?? ""
    }

    /// `climbing / stable / declining / cycling / ""`
    static var weightTrendKey: String {
        d.string(forKey: "onboarding_weight_trend") ?? ""
    }

    /// `lose / maintain / maintain_kept / recomp / ""`
    static var goalDirectionKey: String {
        d.string(forKey: "onboarding_goal_direction") ?? ""
    }

    /// `loss / maintenance / ""` (written by OV5Store.applyGoalDirection)
    static var programModeKey: String {
        d.string(forKey: "program_mode") ?? ""
    }

    /// `fuel / comfort / love / control / complicated / ""`
    static var foodRelationshipKey: String {
        d.string(forKey: "onboardingFoodRelationship") ?? ""
    }

    /// `none / one_two / three_five / many / ""`
    static var priorAttemptsKey: String {
        d.string(forKey: "onboardingPriorAttempts") ?? ""
    }

    /// `after_shot / late_week / most_days / varies / ""` (GLP-1 current only)
    static var appetiteRhythmKey: String {
        d.string(forKey: "onb_v5_appetite_rhythm") ?? ""
    }

    /// `under3 / three_six / six_twelve / over_year / ""` (GLP-1 past only)
    static var glp1StopWindowKey: String {
        d.string(forKey: "onboarding_glp1_stop_window") ?? ""
    }

    /// `none / insulin_sulf / glp1 / other / prefer_not / ""`
    static var medicationStatusKey: String {
        d.string(forKey: "onboarding_medication_status") ?? ""
    }

    // MARK: - Derived flags (single source of truth)

    /// The four-cohort routing enum shared with notifications.
    static var glp1Cohort: Glp1Cohort { Glp1Cohort.current }

    static var isGLP1Current: Bool {
        ProgramGoalCalculator.isGLP1User(from: glp1StatusKey)
    }

    static var isPostGLP1: Bool { glp1StatusKey == "past" }

    static var isEarlyGLP1: Bool {
        ProgramGoalCalculator.isEarlyGLP1(from: glp1PhaseKey)
    }

    static var isPerimenopausal: Bool {
        ProgramGoalCalculator.isPerimenopausal(from: hormonalStageKey)
    }

    static var isShortSleeper: Bool {
        ProgramGoalCalculator.isShortSleeper(from: sleepHoursKey)
    }

    static var isRegainRisk: Bool {
        ProgramGoalCalculator.isRegainRisk(from: weightTrendKey)
    }

    static var isPostpartum: Bool { hormonalStageKey == "postpartum" }

    /// Maintenance framing: post-GLP-1 keep-it-off, explicit maintain,
    /// or a safety-gate forced maintenance window.
    static var isMaintenanceMode: Bool {
        programModeKey == "maintenance"
            || goalDirectionKey == "maintain"
            || goalDirectionKey == "maintain_kept"
    }

    /// Restriction-risk derivation. `onb_restrictive_food` had no
    /// writer before v2; the live signal is the food-relationship
    /// answer. The bool key is still honored (it becomes writable via
    /// safety surfaces later) but never the only source.
    static var isRestrictiveRisk: Bool {
        if d.bool(forKey: "onb_restrictive_food") { return true }
        let rel = foodRelationshipKey.lowercased()
        return rel == "control" || rel == "complicated"
    }

    /// Safety-gate numeric suppression (ED / pregnancy outputs).
    /// Consumers must drop calorie + weight numerals when true.
    static var isNumericSuppressed: Bool {
        d.bool(forKey: "safety_numeric_suppression")
    }

    static var isHighStress: Bool {
        stressKey == "heavy" || stressKey == "overwhelmed"
    }

    /// `none/one_two` → low, `three_five/many` → high. Used for CBT
    /// self-compassion affinity + comeback framing.
    static var hasManyPriorAttempts: Bool {
        priorAttemptsKey == "three_five" || priorAttemptsKey == "many"
    }

    /// Approximate int for the curriculum's priorAttemptsCount axis.
    static var priorAttemptsApprox: Int {
        switch priorAttemptsKey {
        case "one_two": return 2
        case "three_five": return 4
        case "many": return 6
        default: return 0
        }
    }

    // p54 — the CBT curriculum bridge (`curriculumFlags()` →
    // `CohortFlags`) died with the curriculum it bridged to: the
    // scheduler and both QA hosts were its only callers, all deleted
    // with the corpus. The live cohort reads above are untouched.
}
