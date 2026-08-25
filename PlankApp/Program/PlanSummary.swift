import Foundation
import PlankSync

/// THE PLAN — what she is trying to do, stated in her own numbers.
///
/// The post-purchase screen used to say *"we used what you told us in
/// onboarding to build your plan"* over four promises that are
/// identical for every human being alive. She had just answered ~45
/// questions and paid. Nothing on that screen was hers.
///
/// This is the object that screen is made of, and the same object the
/// edit surface writes back into, so "what is my plan" and "change my
/// plan" can never drift apart.
///
/// ## What it refuses
///
/// - **It never invents a goal.** No goal on file resolves to
///   `.goalMissing` and an ask — not to a distance measured from a
///   number we made up, and not to maintenance. The two are different
///   facts and the whole 2026-08-13 customer report lives in the gap
///   between them.
/// - **It never states a distance it cannot compute.** No weight, no
///   goal, or numeric suppression → nil, and the surface draws nothing.
/// - **It says "holding" only when holding was chosen.** Maintenance
///   is an instruction, never a fallback.
/// - **Under numeric suppression it carries no numerals at all** — and
///   never asks a suppressed cohort to name a goal weight.
struct PlanSummary: Equatable {

    enum Intent: Equatable {
        /// A real loss plan, to this goal (kg).
        case losing(goalKg: Double)
        /// She asked to hold where she is, or a safety rule requires it.
        case holding
        /// She asked to lose and we have no usable goal. Ask.
        case goalMissing
        /// Her plan states a HOLD and this device cannot say whether the
        /// hold was asked for — a safety decision, or a goal the old
        /// build lost. Both are erased by an account transition and
        /// nothing on the server tells them apart, so the screen states
        /// what the plan says and asks which it is. Never guessed.
        case directionUnknown
    }

    /// What the energy number MEANS. The label is not decoration: a
    /// maintenance number presented as a loss target is a surplus.
    enum EnergyKind: Equatable {
        case deficit
        case maintenance
    }

    let intent: Intent
    /// The freshest weight the app holds.
    let currentKg: Double?
    /// Distance still ahead. nil when there is no goal, no weight, or
    /// the goal is met.
    let distanceKg: Double?
    /// Weeks at her picked pace, from `ProgramGoalCalculator` — the
    /// same window the pre-purchase reveal computed. Never picked.
    let horizonWeeks: Int?
    let energyKcal: Int?
    let energyKind: EnergyKind?
    let proteinG: Int?
    let stepsGoal: Int
    let numericsSuppressed: Bool

    /// True when the one thing standing between her and a real plan is
    /// a goal weight she has not given us.
    var needsGoal: Bool { !numericsSuppressed && intent == .goalMissing }

    /// True when the one thing standing between her and a real number is
    /// an answer only she can give: is this plan losing or holding.
    var needsDirection: Bool { !numericsSuppressed && intent == .directionUnknown }

    var goalKg: Double? {
        if case .losing(let g) = intent { return g }
        return nil
    }

    // MARK: - Building

    static func build(
        plan: ProgramPlanRecord?,
        latestWeightKg: Double?,
        proteinG: Int?,
        stepsGoal: Int,
        numericsSuppressed: Bool,
        careProtocol: CareProtocol = .default,
        defaults d: UserDefaults = .standard
    ) -> PlanSummary {
        let current = latestWeightKg
            ?? d.double(forKey: "onboardingCurrentWeightKg").positiveOrNil

        if numericsSuppressed {
            // Her plan is real; it just carries no numerals. Steps stay
            // because a step goal is an activity, not a body judgement.
            return PlanSummary(
                intent: .holding, currentKg: current, distanceKg: nil,
                horizonWeeks: nil, energyKcal: nil, energyKind: nil,
                proteinG: nil, stepsGoal: stepsGoal, numericsSuppressed: true
            )
        }

        let basis = TargetsService.energyBasis(
            plan: plan, fallbackWeightKg: current ?? 0,
            careProtocol: careProtocol, defaults: d
        )

        // HER ANSWER FIRST. The goal she typed is the one she can see
        // and edit, so it is the one this screen states — the plan's
        // own goal is only used when she has none on file at all.
        // `TargetsService.energyBasis` resolves the same way, so the
        // number on screen and the number in the math can never be
        // different numbers.
        let storedGoal = d.double(forKey: "onboardingGoalWeightKg").positiveOrNil
        // A plan's goal may only stand IN PLACE OF her answer when it is
        // still a coherent destination for the body in front of us.
        //
        // 2026-08-14: this checked the goal against the PLAN's own start
        // weight, which can be years stale — so a hydrated plan reading
        // "75 kg → 65 kg" was adopted as the goal of a 56 kg woman, and
        // the screen rendered `124 lb → 143.3 lb · you reached your goal`
        // beside a deficit target. Her own weight is the only weight that
        // can tell us whether a destination is ahead of her.
        let planGoal: Double? = {
            guard let plan, let g = plan.goalWeightKg, g > 30,
                  let s = plan.currentWeightKg, s > g,
                  let c = current, g < c else { return nil }
            return g
        }()
        let start = d.double(forKey: "onboardingCurrentWeightKg").positiveOrNil
            ?? plan?.currentWeightKg

        let intent: Intent = {
            if basis == .maintenance { return .holding }
            // The plan holds and we cannot say why. Stating "losing" over
            // a screen with no number would be the screen contradicting
            // itself, which is the defect class this object exists to
            // close.
            if basis == .unknown,
               TargetsService.planHoldsWithUnknownDirection(plan, d) {
                return .directionUnknown
            }
            if let g = storedGoal, let s = start ?? current, s > g {
                return .losing(goalKg: g)
            }
            if storedGoal == nil, let g = planGoal { return .losing(goalKg: g) }
            return .goalMissing
        }()

        var distance: Double? = nil
        var horizon: Int? = nil
        if case .losing(let goal) = intent, let current {
            let remaining = current - goal
            distance = remaining > 0 ? remaining : nil
            horizon = horizonWeeks(currentKg: current, goalKg: goal, defaults: d)
        }

        // The energy number is only published when the basis knows what
        // it means. `.unknown` draws nothing — see EnergyBasis.
        var kcal: Int? = nil
        var kind: EnergyKind? = nil
        switch basis {
        case .deficit, .maintenance:
            kcal = energyTarget(plan: plan, weightKg: current,
                                careProtocol: careProtocol, defaults: d)
            kind = basis == .maintenance ? .maintenance : .deficit
        case .unknown:
            break
        }

        return PlanSummary(
            intent: intent,
            currentKg: current,
            distanceKg: distance,
            horizonWeeks: horizon,
            energyKcal: kcal,
            energyKind: kcal == nil ? nil : kind,
            proteinG: current == nil ? nil : proteinG,
            stepsGoal: stepsGoal,
            numericsSuppressed: false
        )
    }

    private static func energyTarget(
        plan: ProgramPlanRecord?, weightKg: Double?,
        careProtocol: CareProtocol, defaults: UserDefaults
    ) -> Int? {
        MainActor.assumeIsolated {
            TargetsService.calorieTarget(
                plan: plan, latestWeightKg: weightKg,
                careProtocol: careProtocol, defaults: defaults
            )
        }
    }

    /// Weeks at her picked tier, through the same window the reveal
    /// showed her. Never a date she chose.
    private static func horizonWeeks(
        currentKg: Double, goalKg: Double, defaults d: UserDefaults
    ) -> Int? {
        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg,
            sex: ProgramGoalCalculator.sex(
                fromGenderKey: d.string(forKey: "onboardingGender") ?? ""),
            age: nil,
            isGLP1User: ProgramGoalCalculator.isGLP1User(
                from: d.string(forKey: "onboarding_glp1_status") ?? ""),
            hasGentlerPaceStage: ProgramGoalCalculator.gentlerPaceStage(
                from: d.string(forKey: "onboardingHormonalStage") ?? ""),
            isShortSleeper: ProgramGoalCalculator.isShortSleeper(
                from: d.string(forKey: "onboardingSleepHours") ?? ""),
            weightTrendKey: d.string(forKey: "onboarding_weight_trend") ?? "",
            glp1PhaseKey: d.string(forKey: "onboarding_glp1_phase") ?? ""
        ))
        guard !window.isMaintenance else { return nil }
        let tier = IntensityTier(rawValue: d.string(forKey: "onboardingPickedTier") ?? "")
            ?? .medium
        return window.weeks(for: tier)
    }

    // MARK: - Reading

    /// `"14 lb to go"`, or the arrival. nil when there is nothing to
    /// state — the surface then draws no line at all.
    func distanceLine(unit: WeightUnit = .current) -> String? {
        if case .losing = intent, distanceKg == nil, currentKg != nil {
            return "you reached your goal"
        }
        guard let distanceKg else { return nil }
        let magnitude = unit.display(fromKg: distanceKg)
        guard magnitude >= 0.1 else { return "you reached your goal" }
        return "\(Self.formatted(magnitude)) \(unit.label) to go"
    }

    /// `"about 17 weeks at your pace"` — an estimate, said as one.
    var horizonLine: String? {
        guard let horizonWeeks else { return nil }
        return "about \(horizonWeeks) weeks at your pace"
    }

    static func formatted(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value.rounded()))
            : String(format: "%.1f", value)
    }
}

private extension Double {
    var positiveOrNil: Double? { self > 0 ? self : nil }
}
