import Foundation

// MARK: - ProgramGoalCalculator
//
// v1.1 program pivot. Pure function: given the user's current
// weight, goal weight, sex, age, activity baseline, and cohort
// flags, return a realistic duration WINDOW (min/max weeks) and
// the per-intensity duration that maps to ACSM 0.5-1%/wk band.
//
// Founder constraint: NEVER expose a free-form date picker. The
// goal date is DERIVED from the picked intensity, never picked
// directly. Soft = 0.5%/wk = max-weeks. Hard = 1.0%/wk = min-weeks.
// Medium = 0.75%/wk = midpoint.
//
// Sources:
// - ACSM Position Stand 2009 (Donnelly et al.) — 0.5-1.0%/wk
//   safe + sustainable band.
// - Wing & Phelan 2005 NWCR — 0.5%/wk floor for women.
// - Hall et al. 2012 Lancet — kcal deficit ramp model.
// - For GLP-1 + perimenopause: 0.3%/wk floor (clinical guidance,
//   slower glide for those cohorts).

public enum ProgramGoalCalculator {

    public struct Inputs {
        public let currentWeightKg: Double
        public let goalWeightKg: Double
        public let sex: Sex
        public let age: Int?
        public let isGLP1User: Bool
        public let isPerimenopausal: Bool
        /// v3 P11.2 (2026-06-10) — short-sleep flag (<6h habitual).
        /// Nedeltcheva 2010 (Annals of Internal Med, n=10 RCT crossover):
        /// 5.5h sleep vs 8.5h sleep on the same kcal deficit cuts
        /// fat-loss rate by ~55% while keeping total weight loss the
        /// same — extra loss comes from lean mass, exactly what
        /// JeniFit's voice promises to protect. So short-sleep users
        /// get a wider window (slower expected pace) to keep the goal
        /// date honest.
        public let isShortSleeper: Bool

        public init(
            currentWeightKg: Double,
            goalWeightKg: Double,
            sex: Sex,
            age: Int?,
            isGLP1User: Bool = false,
            isPerimenopausal: Bool = false,
            isShortSleeper: Bool = false
        ) {
            self.currentWeightKg = currentWeightKg
            self.goalWeightKg = goalWeightKg
            self.sex = sex
            self.age = age
            self.isGLP1User = isGLP1User
            self.isPerimenopausal = isPerimenopausal
            self.isShortSleeper = isShortSleeper
        }

        public enum Sex: String, Codable, Sendable {
            case female
            case male
            case unspecified
        }
    }

    public struct Window {
        /// Total kg the user is trying to lose. Positive = lose;
        /// zero or negative = goal already met (calculator returns
        /// `.maintenance` flag).
        public let deltaKg: Double

        /// Minimum number of weeks (= 1.0%/wk = Hard). Clamped
        /// to ≥ 4 weeks (program-shape floor).
        public let minWeeks: Int

        /// Maximum number of weeks (= 0.5%/wk = Soft, or 0.3%/wk
        /// for GLP-1/perimenopause cohort). Clamped to ≤ 52 weeks
        /// per program-shape ceiling (longer deltas need sequential
        /// programs per the founder-locked plan).
        public let maxWeeks: Int

        /// Effective floor rate used for the maxWeeks calculation.
        /// 0.005 default, 0.003 for GLP-1/perimenopause cohort.
        public let lossRateFloor: Double

        /// True when goal ≥ current — user is already at or below
        /// goal. Switch to maintenance copy in UI.
        public let isMaintenance: Bool

        /// Duration for a specific intensity tier. Bridges the
        /// window to the picked IntensityProfile so the UI shows
        /// "Day 75 → April 12" the moment the pill is selected.
        public func weeks(for tier: IntensityTier) -> Int {
            guard !isMaintenance else { return 30 }
            switch tier {
            case .hard:    return minWeeks
            case .medium:  return (minWeeks + maxWeeks) / 2
            case .soft:    return maxWeeks
            }
        }

        public func goalDate(from startDate: Date, tier: IntensityTier) -> Date {
            let weeks = weeks(for: tier)
            let days = weeks * 7
            return Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: startDate) ?? startDate
        }
    }

    /// Hard program-shape floor — never under 4 weeks even if math
    /// allows. Crash diets aren't a thing in JeniFit.
    private static let absoluteMinWeeks = 4

    /// Hard program-shape ceiling — sequential programs handle
    /// longer journeys. 52 = a year, which is the BMI-band-recovery
    /// horizon for sustained loss before re-evaluating.
    private static let absoluteMaxWeeks = 52

    /// Default 0.5%/wk floor (general adult population, Wing &
    /// Phelan NWCR).
    private static let defaultLossRateFloor = 0.005

    /// Cautious 0.3%/wk floor for GLP-1 + perimenopause cohorts.
    /// Slower glide preserves lean mass + reduces sleep/stress
    /// compensation.
    private static let cautiousLossRateFloor = 0.003

    /// v3 P11.2 (2026-06-10) — middle-tier 0.4%/wk floor for short
    /// sleepers (<6h). Between default 0.5% and cautious 0.3% —
    /// reflects the Nedeltcheva 2010 fat-loss penalty without
    /// over-correcting into the GLP-1/peri band. Stacks with the
    /// cautious floor: a short-sleeping GLP-1 user gets the slower
    /// 0.3% rate (already maximally cautious).
    private static let shortSleeperLossRateFloor = 0.004

    /// Top of the ACSM band — used for minWeeks (Hard tier).
    private static let maxLossRate = 0.01

    public static func compute(_ inputs: Inputs) -> Window {
        let delta = inputs.currentWeightKg - inputs.goalWeightKg
        guard delta > 0 else {
            return Window(
                deltaKg: 0,
                minWeeks: absoluteMinWeeks,
                maxWeeks: 30,  // maintenance default
                lossRateFloor: defaultLossRateFloor,
                isMaintenance: true
            )
        }

        // Pick floor rate based on cohort flags. Cohort cascade:
        //   GLP-1 / perimenopause → 0.3%/wk (cautious)
        //   short sleeper (no GLP-1/peri) → 0.4%/wk (Nedeltcheva 2010)
        //   default → 0.5%/wk (Wing & Phelan NWCR)
        // GLP-1/peri wins over short-sleep when both are true — the
        // physiological reason for slowness is the dominant one.
        let floor: Double = {
            if inputs.isGLP1User || inputs.isPerimenopausal {
                return cautiousLossRateFloor
            }
            if inputs.isShortSleeper {
                return shortSleeperLossRateFloor
            }
            return defaultLossRateFloor
        }()

        // weeks = delta / (current * rate_per_week)
        // minWeeks uses MAX rate (1%/wk = fastest sustainable).
        // maxWeeks uses MIN rate (0.5% or 0.3%/wk = slowest, gentlest).
        let rawMin = delta / (inputs.currentWeightKg * maxLossRate)
        let rawMax = delta / (inputs.currentWeightKg * floor)

        let minWeeks = clampWeeks(Int(rawMin.rounded(.up)))
        let maxWeeks = clampWeeks(Int(rawMax.rounded(.up)))

        return Window(
            deltaKg: delta,
            minWeeks: minWeeks,
            maxWeeks: max(minWeeks, maxWeeks),  // safety: max >= min
            lossRateFloor: floor,
            isMaintenance: false
        )
    }

    private static func clampWeeks(_ raw: Int) -> Int {
        max(absoluteMinWeeks, min(absoluteMaxWeeks, raw))
    }

    // MARK: - Display helpers
    //
    // Helpers for the dynamic in-page reframe (BetterMe pattern #4)
    // on GoalDateRevealScreen — shows "you'll lose X% of your weight"
    // + benefit stack + safety chip per picked goal.

    /// Percent of current weight the user is trying to lose. Used
    /// in the "challenging choice · you will lose 48.6% of your
    /// weight" copy line. Returns 0 if maintenance / goal ≥ current.
    public static func pctOfBodyWeight(_ inputs: Inputs) -> Double {
        guard inputs.currentWeightKg > 0 else { return 0 }
        let delta = max(0, inputs.currentWeightKg - inputs.goalWeightKg)
        return (delta / inputs.currentWeightKg) * 100.0
    }

    /// Rough BMI estimate when height is available. Used to flag
    /// "your target BMI is too low" warning at the goal-weight
    /// picker (BetterMe pattern). Height must be in cm.
    public static func bmi(weightKg: Double, heightCm: Double) -> Double {
        guard heightCm > 0 else { return 0 }
        let m = heightCm / 100.0
        return weightKg / (m * m)
    }

    /// BMI safety classification for inline warning cards. AHA
    /// 2021 bands. JeniFit voice = anti-shame; "underweight" copy
    /// is care, not judgement.
    public enum BMIClass {
        case underweight   // < 18.5 — surface a warning chip
        case healthy       // 18.5 – 24.9
        case overweight    // 25.0 – 29.9
        case obese         // ≥ 30
    }

    public static func bmiClass(_ bmi: Double) -> BMIClass {
        switch bmi {
        case ..<18.5: return .underweight
        case 18.5..<25: return .healthy
        case 25..<30: return .overweight
        default: return .obese
        }
    }

    // MARK: - AppStorage value mappers
    //
    // Thin helpers that translate raw onboarding AppStorage strings
    // into the boolean cohort flags `Inputs` expects. Call sites read
    // the AppStorage value + pass it through these so the option-key
    // → flag mapping stays in ONE place and changes to onboarding
    // option keys only break one site instead of N.

    /// v3 P11.2 (2026-06-10) — case 158 (sleep hours) options:
    /// under5 / five6 / six7 / seven8 / eightPlus / (empty). Short
    /// sleeper = the two lower buckets, which clinical literature
    /// (Nedeltcheva 2010, Walker 2017) classifies as habitually
    /// sleep-restricted with measurable fat-loss penalty.
    public static func isShortSleeper(from sleepHoursKey: String) -> Bool {
        sleepHoursKey == "under5" || sleepHoursKey == "five6"
    }

    /// v3 P11.2 (2026-06-10) — case 164 (GLP-1 status) option keys:
    /// none / considering / past / current / prefer_not_say. Only
    /// `current` triggers the cautious 0.3%/wk floor; `past` users
    /// are post-meds and back to default rate. Replaces 4 bug-prone
    /// `glp1Status == "current"` literals (formerly `"current_user"`)
    /// scattered across PacePicker + Paywall + ProgramSetup.
    public static func isGLP1User(from glp1StatusKey: String) -> Bool {
        glp1StatusKey == "current"
    }

    /// v3 P11.2 (2026-06-10) — case 163 (hormonal stage) option key.
    /// Only `perimenopause` triggers the cautious floor; postpartum
    /// + postmenopause have different cohort handling (postpartum
    /// gets duty-of-care plank gating; postmenopause is essentially
    /// default rate per the literature).
    public static func isPerimenopausal(from hormonalStageKey: String) -> Bool {
        hormonalStageKey == "perimenopause"
    }
}
