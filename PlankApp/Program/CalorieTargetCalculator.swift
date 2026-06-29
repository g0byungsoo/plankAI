import Foundation

// MARK: - CalorieTargetCalculator
//
// Pure functions: Mifflin-St Jeor TDEE minus a pace-implied daily deficit
// -> clamped daily calorie target. No side effects, no force-unwraps.
//
// References:
//   Mifflin MD et al. 1990 (J Am Diet Assoc) - Mifflin-St Jeor BMR.
//   Hall KD et al. 2012 (Lancet) - 7700 kcal/kg is a ramp approximation
//     of the energy cost of fat loss; real value drifts as body composition
//     changes, which is why the reveal copy frames the output as a
//     "starting plan, we'll tune yours."
//
// Activity key mapping - accepts the raw onboarding movement-baseline keys
// (onb_v4_movement_baseline, case 8 in OnboardingView.swift):
//   "barely"      -> sedentary  -> 1.2
//   "walks"       -> light      -> 1.375
//   "regular_ish" -> moderate   -> 1.55
//   "very_active" -> active     -> 1.725
// Also accepts the derived activityLevel aliases ("sedentary" / "light" /
// "moderate" / "active") so downstream call sites are forward-compatible.
// Default: 1.375 (light) when the key is empty or unrecognised.

public enum CalorieTargetCalculator {

    // MARK: - Activity factor

    static func activityFactor(for activityKey: String) -> Double {
        switch activityKey {
        case "barely", "sedentary":
            return 1.2
        case "walks", "light", "lightly_active":
            return 1.375
        case "regular_ish", "moderate", "moderately_active":
            return 1.55
        case "very_active", "active":
            return 1.725
        default:
            return 1.375
        }
    }

    // MARK: - BMR (Mifflin-St Jeor)

    /// Raw BMR in kcal/day (floating point, unclamped).
    /// Female:      10w + 6.25h - 5a - 161
    /// Male:        10w + 6.25h - 5a + 5
    /// Unspecified: female formula (conservative for the JeniFit cohort).
    static func bmrRaw(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: ProgramGoalCalculator.Inputs.Sex
    ) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male:
            return base + 5
        case .female, .unspecified:
            return base - 161
        }
    }

    // MARK: - TDEE

    /// Total Daily Energy Expenditure = Mifflin-St Jeor BMR x activity factor.
    /// Returns kcal/day as Int. Clamped to >= 1200.
    public static func tdee(
        currentWeightKg: Double,
        heightCm: Double,
        age: Int,
        sex: ProgramGoalCalculator.Inputs.Sex,
        activityKey: String
    ) -> Int {
        let bmr = bmrRaw(weightKg: currentWeightKg, heightCm: heightCm, age: age, sex: sex)
        let result = bmr * activityFactor(for: activityKey)
        return max(1200, Int(result.rounded()))
    }

    // MARK: - Daily calorie target

    /// TDEE minus the daily deficit implied by `lossRatePctPerWeek`.
    ///
    /// deficit/day = (lossRatePctPerWeek x weightKg) kg/wk x 7700 kcal/kg / 7 days
    ///   (7700 kcal/kg - Hall 2012 ramp approximation for fat-loss energy cost.)
    ///
    /// Clamped:
    ///   floor   >= max(1200, BMR) - never recommends under-fuelling.
    ///   ceiling <= 3500 kcal (above any plausible sedentary TDEE in the cohort).
    ///
    /// No force-unwraps; all inputs are value types.
    public static func dailyTarget(
        currentWeightKg: Double,
        heightCm: Double,
        age: Int,
        sex: ProgramGoalCalculator.Inputs.Sex,
        activityKey: String,
        lossRatePctPerWeek: Double
    ) -> Int {
        let tdeeDouble = Double(tdee(
            currentWeightKg: currentWeightKg,
            heightCm: heightCm,
            age: age,
            sex: sex,
            activityKey: activityKey
        ))
        // Hall 2012: 7700 kcal per kg of fat-loss (ramp approximation).
        let weeklyLossKg  = lossRatePctPerWeek * currentWeightKg
        let dailyDeficit  = weeklyLossKg * 7700.0 / 7.0
        let rawTarget     = tdeeDouble - dailyDeficit
        // Safety floor: never below BMR or 1200 kcal (energy-availability gate).
        let bmrFloor = max(1200.0, bmrRaw(
            weightKg: currentWeightKg,
            heightCm: heightCm,
            age: age,
            sex: sex
        ))
        let ceiling = 3500.0
        return Int(min(ceiling, max(bmrFloor, rawTarget)).rounded())
    }
}
