import Foundation

// MARK: - IntensityProfile
//
// v1.1 program pivot. The 3-stop intensity dial that the goal-date
// slider snaps to: Soft / Medium / Hard. Each tier is a pure value
// type bundling the downstream parameters that every program rail
// reads — kcal deficit floor, workout sessions/week, steps/day,
// lesson cadence, plank progression, breathwork frequency.
//
// Founder decision 2026-06-09: Hard tier is VISIBLE-BUT-LOCKED for
// users where it's unsafe (GLP-1 = yes OR perimenopause = yes OR
// age ≥ 40 OR activity < light). They see the pill with a padlock
// + soft "unlock in settings" sheet on tap. Not exclusionary; just
// the doctor's-recommended floor surfaced inline.
//
// Numbers sourced from PM agent brief (docs/program_pivot_v1_1_plan_2026_06_09.md
// §"Goal-date math") and the founder-locked plan; ACSM 0.5-1%/wk
// band is the bedrock.

public enum IntensityTier: String, Codable, CaseIterable, Sendable {
    case soft
    case medium
    case hard
}

public struct IntensityProfile: Sendable, Equatable {
    public let tier: IntensityTier

    /// Target weight-loss rate as % of current body weight per week.
    /// Soft = 0.5%, Medium = 0.75%, Hard = 1.0%. ACSM band: anything
    /// faster than 1%/wk triggers compensatory NEAT collapse + lean
    /// mass loss (Pontzer Constrained Energy, Wing & Phelan 2005).
    public let lossRatePctPerWeek: Double

    /// Daily kcal deficit floor (negative = below maintenance). NOT
    /// a calorie target — JeniFit doesn't prescribe calories per the
    /// post-Ozempic vocabulary rule. Used only by IntensityProfile
    /// itself for ramp logic + downstream auditing.
    public let deficitKcalFloor: Int

    /// Workout sessions per week. Drives ProgramScheduler's per-day
    /// prescription cadence (5 sessions = ~5 of 7 days workout-on).
    public let sessionsPerWeek: Int

    /// Daily step goal. Auto-completes via HealthKit StepsService.
    public let stepsDailyGoal: Int

    /// JeniMethod lesson cadence — how often the lesson row appears
    /// on PlanView.
    public let lessonCadence: LessonCadence

    public enum LessonCadence: String, Codable, Sendable {
        /// 2x/wk on Tue/Sat (Soft tier).
        case twiceWeek
        /// Every day (Medium tier).
        case daily
        /// Every day + Sunday evening recap (Hard tier).
        case dailyPlusEvening

        public var perWeekCount: Int {
            switch self {
            case .twiceWeek: return 2
            case .daily: return 7
            case .dailyPlusEvening: return 8
            }
        }
    }

    /// Workout minutes per session by program week. Soft ramps slowest
    /// (7→10→15), Medium (10→15→15→20), Hard (15→20→30). Capped at
    /// week 12.
    public func workoutMinutes(forProgramWeek week: Int) -> Int {
        let safeWeek = max(1, min(week, 12))
        switch tier {
        case .soft:
            return [7, 7, 10, 10, 15, 15, 15, 15, 15, 15, 15, 15][safeWeek - 1]
        case .medium:
            return [10, 10, 15, 15, 15, 20, 20, 20, 20, 20, 20, 20][safeWeek - 1]
        case .hard:
            return [15, 15, 20, 20, 30, 30, 30, 30, 30, 30, 30, 30][safeWeek - 1]
        }
    }

    // MARK: - Statics

    public static let soft = IntensityProfile(
        tier: .soft,
        lossRatePctPerWeek: 0.005,
        deficitKcalFloor: -300,
        sessionsPerWeek: 3,
        stepsDailyGoal: 6000,
        lessonCadence: .twiceWeek
    )

    public static let medium = IntensityProfile(
        tier: .medium,
        lossRatePctPerWeek: 0.0075,
        deficitKcalFloor: -500,
        sessionsPerWeek: 4,
        stepsDailyGoal: 7500,
        lessonCadence: .daily
    )

    public static let hard = IntensityProfile(
        tier: .hard,
        lossRatePctPerWeek: 0.01,
        deficitKcalFloor: -750,
        sessionsPerWeek: 5,
        stepsDailyGoal: 9000,
        lessonCadence: .dailyPlusEvening
    )

    public static func from(tier: IntensityTier) -> IntensityProfile {
        switch tier {
        case .soft: return .soft
        case .medium: return .medium
        case .hard: return .hard
        }
    }
}

// MARK: - Hard-tier safety gate
//
// Founder decision 2026-06-09: visible-but-locked. The gate
// computes whether Hard is safe to expose. If false, the
// IntensityPickerView still renders the Hard pill but with a
// padlock icon + "we hid Hard for your safety" tap sheet that
// explains why and offers an "I understand, unlock anyway"
// override (routed to settings, not inline — minor friction).

public struct HardTierGate {
    /// User cohort signals that determine whether Hard intensity
    /// should be exposed without the safety lock.
    public struct Inputs {
        public let isGLP1User: Bool
        public let isPerimenopausal: Bool
        public let age: Int?
        public let activityLevel: ActivityLevel

        public init(
            isGLP1User: Bool,
            isPerimenopausal: Bool,
            age: Int?,
            activityLevel: ActivityLevel
        ) {
            self.isGLP1User = isGLP1User
            self.isPerimenopausal = isPerimenopausal
            self.age = age
            self.activityLevel = activityLevel
        }

        public enum ActivityLevel: String, Codable, Sendable {
            case sedentary
            case light
            case moderate
            case active
            case veryActive
        }
    }

    /// Returns true when Hard tier should be exposed without a
    /// safety lock. Conservative defaults: any missing signal
    /// (e.g. age nil) locks Hard.
    public static func isUnlocked(_ inputs: Inputs) -> Bool {
        guard inputs.isGLP1User == false else { return false }
        guard inputs.isPerimenopausal == false else { return false }
        guard let age = inputs.age, age < 40 else { return false }
        switch inputs.activityLevel {
        case .sedentary: return false
        case .light, .moderate, .active, .veryActive: return true
        }
    }

    /// Copy for the lock sheet. Surfaced when user taps the locked
    /// Hard pill. Keeps voice anti-shame + evidence-honest.
    public static func lockReason(_ inputs: Inputs) -> String {
        if inputs.isGLP1User {
            return "we hid Hard while you're on a GLP-1. your metabolism is already in a deficit. Soft or Medium pairs better."
        }
        if inputs.isPerimenopausal {
            return "we hid Hard for perimenopause. sleep + stress + cycle changes mean a slower glide tends to actually finish."
        }
        if let age = inputs.age, age >= 40 {
            return "we hid Hard past 40. recovery is the new lever. Soft or Medium gets there without the wall."
        }
        if case .sedentary = inputs.activityLevel {
            return "we hid Hard while you're starting out. week 1 of Hard is meant for someone already moving most days. Soft or Medium first, then unlock."
        }
        return "we recommend Soft or Medium to start. you can unlock Hard in settings anytime."
    }
}
