import Foundation
import SwiftData
import PlankSync

/// THE ONE WRITER for the goal weight, after onboarding.
///
/// Until 2026-08-13 there wasn't one. `EditProfileView` is titled
/// "your pace." and edits `workoutLevel`; nothing in Settings, Home,
/// Becoming or the plan could change a goal weight, a height or a
/// start weight. A user who mis-set her goal during onboarding had one
/// repair available to her: delete the account and start over. For a
/// weight-loss product that is not a missing feature, it is a missing
/// floor.
///
/// Writing the goal in one place matters because the goal lives in
/// three: the stored answer every surface reads, the plan record the
/// energy target is derived from, and the `UserRecord` that survives a
/// sign-out. An edit that moved only the first would be cosmetic.
///
/// ## What it will not do
///
/// - **It never restarts her program.** The active plan is mutated in
///   place; `startDate` and the plan id are untouched. Minting a fresh
///   plan resets the day count — the documented incident at
///   `AppSync.swift:520`.
/// - **It never touches the start weight.** Goal and current weight are
///   different facts, and the customer report of 2026-08-13 is what it
///   looks like when they collapse into each other.
/// - **It never quietly accepts an unhealthy goal.** Below BMI 18.5 it
///   clamps to the floor and says so, so the caller can tell her.
enum GoalWeightStore {

    struct Result: Equatable {
        /// What was actually stored, after the healthy-weight clamp.
        let storedKg: Double
        /// True when her number was below BMI 18.5 for her height and
        /// the floor was used instead. The surface must say so.
        let wasClampedToHealthyFloor: Bool
        /// True when the goal is at or above her current weight, so the
        /// plan is now a maintenance rhythm rather than a loss plan.
        let isMaintenance: Bool
    }

    @discardableResult
    @MainActor
    static func setGoalWeightKg(
        _ requestedKg: Double,
        userId: String,
        in context: ModelContext,
        defaults d: UserDefaults = .standard
    ) -> Result {
        let heightCm = d.double(forKey: "onboardingHeightCm")
        let floor = ProgramGoalCalculator.minimumGoalWeightKg(heightCm: heightCm)
        let clamped = floor > 0 ? max(requestedKg, floor) : requestedKg
        let wasClamped = floor > 0 && requestedKg < floor - 0.01

        let currentKg = TargetsService.latestWeightKg(userId: userId, in: context)
            ?? d.double(forKey: "onboardingCurrentWeightKg")
        let isMaintenance = currentKg > 0 && clamped >= currentKg - 0.01

        d.set(clamped, forKey: "onboardingGoalWeightKg")
        // The direction is recorded EXPLICITLY rather than inferred at
        // each read. "goal equals current" means two different things
        // depending on whether she asked for it, and no downstream
        // reader should have to guess which.
        d.set(isMaintenance ? "maintain" : "lose", forKey: "onboarding_goal_direction")
        d.set(isMaintenance ? "maintenance" : "loss", forKey: "program_mode")

        mirrorToUserRecord(clamped, userId: userId, in: context)
        repairActivePlan(goalKg: clamped, userId: userId, in: context, defaults: d)

        return Result(storedKg: clamped,
                      wasClampedToHealthyFloor: wasClamped,
                      isMaintenance: isMaintenance)
    }

    /// **THE ANSWER THE ACCOUNT TRANSITION LOST.**
    ///
    /// `program_mode` and `onboarding_goal_direction` are swept on
    /// sign-out and nothing restores them, so a woman on a new phone can
    /// hold a plan that says HOLD with no way for the app to tell
    /// whether a safety decision put it there or the old build lost her
    /// goal. `TargetsService.planHoldsWithUnknownDirection` refuses to
    /// guess; this is the only way out, and it is her own answer.
    ///
    /// It writes the two keys and NOTHING ELSE — not the goal weight,
    /// not the plan, not the start weight, not a single day of history.
    /// "Holding" is therefore always reversible through the goal ritual,
    /// which is the writer that owns those numbers.
    @MainActor
    static func setDirection(
        holding: Bool,
        defaults d: UserDefaults = .standard
    ) {
        d.set(holding ? "maintain" : "lose", forKey: "onboarding_goal_direction")
        d.set(holding ? "maintenance" : "loss", forKey: "program_mode")
    }

    // MARK: - The three homes

    /// So a sign-out → sign-in round trip brings it back (see
    /// `AppSync.restoreBodyDefaults`).
    @MainActor
    private static func mirrorToUserRecord(
        _ goalKg: Double, userId: String, in context: ModelContext
    ) {
        let descriptor = FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == userId }
        )
        guard let record = try? context.fetch(descriptor).first else { return }
        record.onboardingGoalWeightKg = goalKg
        record.pendingUpsert = true
        try? context.save()
        Task { await AppSync.shared.upsertUser(record) }
    }

    /// The plan she is LIVING IN moves its finish line. Same plan, same
    /// start date, same day count — a new horizon.
    @MainActor
    private static func repairActivePlan(
        goalKg: Double, userId: String, in context: ModelContext, defaults d: UserDefaults
    ) {
        guard let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        else { return }

        let startWeight = plan.currentWeightKg
            ?? d.double(forKey: "onboardingCurrentWeightKg")
        guard startWeight > 30 else { return }

        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: startWeight,
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
            glp1PhaseKey: d.string(forKey: "onboarding_glp1_phase") ?? "",
            paceCapPctPerWeek: safetyCap(d, userId: userId, in: context)
        ))
        let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium

        plan.goalWeightKg = goalKg
        plan.totalDays = window.weeks(for: tier) * 7
        plan.goalDate = window.goalDate(from: plan.startDate, tier: tier)
        plan.updatedAt = .now
        plan.pendingUpsert = true
        try? context.save()
        Task { await AppSync.shared.upsertProgramPlan(plan) }
    }

    // MARK: - Pace
    //
    // THE PACE TIER lives here, not in a store of its own, because
    // changing it recomputes `plan.totalDays` + `plan.goalDate` — and a
    // second writer of those two fields is precisely the drift this
    // whole line of work exists to stop.
    //
    // `ProgramSetupSubflow` prints **"pick the rhythm. you can change it
    // later."** on the pace screen. Until 2026-08-14 there was no later:
    // nothing in the app could change `onboardingPickedTier` or
    // `plan.intensityTier` once the plan was built. That is the second
    // written promise this pass found the product unable to keep.
    //
    // Changing pace changes the HORIZON, never the history. Same plan id,
    // same start date, same start weight, same goal, same logs, same
    // medication. The safety cap and the care protocol clamp the result
    // exactly as they clamp it at build time, because it is the same
    // calculator call.

    struct PaceResult: Equatable {
        let tier: IntensityTier
        /// Weeks the plan now runs for. nil when there is no active plan
        /// to move (the preference is still recorded for the next one).
        let weeks: Int?
        /// True when the tier she asked for is not the tier she got —
        /// `HardTierGate` keeps its lock, and the surface must say so.
        let wasRefused: Bool
    }

    @discardableResult
    @MainActor
    static func setPaceTier(
        _ requested: IntensityTier,
        userId: String,
        in context: ModelContext,
        defaults d: UserDefaults = .standard
    ) -> PaceResult {
        let allowed = requested == .hard && !hardIsUnlocked(d) ? IntensityTier.medium : requested
        let refused = allowed != requested

        // The preference is stored whether or not a plan exists: the
        // reveal, the onramp and `TargetsService.onboardingImpliedRate`
        // all read it, so a pace change with no plan yet still means
        // something.
        d.set(allowed.rawValue, forKey: "onboardingPickedTier")

        guard let plan = ProgramService.shared.activePlan(userId: userId, in: context) else {
            return PaceResult(tier: allowed, weeks: nil, wasRefused: refused)
        }
        let startWeight = plan.currentWeightKg
            ?? d.double(forKey: "onboardingCurrentWeightKg")
        let goalKg = d.double(forKey: "onboardingGoalWeightKg").positiveOrNil
            ?? plan.goalWeightKg ?? 0
        guard startWeight > 30, goalKg > 30 else {
            return PaceResult(tier: allowed, weeks: nil, wasRefused: refused)
        }

        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: startWeight,
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
            glp1PhaseKey: d.string(forKey: "onboarding_glp1_phase") ?? "",
            paceCapPctPerWeek: safetyCap(d, userId: userId, in: context)
        ))
        let weeks = window.weeks(for: allowed)

        plan.intensityTier = allowed.rawValue
        plan.totalDays = weeks * 7
        plan.goalDate = window.goalDate(from: plan.startDate, tier: allowed)
        plan.updatedAt = .now
        plan.pendingUpsert = true
        try? context.save()
        Task { await AppSync.shared.upsertProgramPlan(plan) }

        return PaceResult(tier: allowed, weeks: weeks, wasRefused: refused)
    }

    /// The SAME gate `ProgramSetupSubflow` puts on the pace screen. An
    /// editor that could unlock Hard where the picker locks it would be a
    /// safety gate with a back door.
    @MainActor
    static func hardIsUnlocked(_ d: UserDefaults = .standard) -> Bool {
        HardTierGate.isUnlocked(.init(
            isGLP1User: ProgramGoalCalculator.isGLP1User(
                from: d.string(forKey: "onboarding_glp1_status") ?? ""),
            hasGentlerPaceStage: ProgramGoalCalculator.gentlerPaceStage(
                from: d.string(forKey: "onboardingHormonalStage") ?? ""),
            age: TargetsService.knownAge(d),
            activityLevel: hardGateActivity(TargetsService.activityKey(d))
        ))
    }

    static func hardGateActivity(_ raw: String) -> HardTierGate.Inputs.ActivityLevel {
        switch raw.lowercased() {
        case "barely", "sedentary": return .sedentary
        case "walks", "lightly_active", "light", "lightly active": return .light
        case "regular_ish", "moderate", "moderately_active": return .moderate
        case "active", "very_active": return .active
        case "athlete", "very active": return .veryActive
        default: return .light  // gentle default — won't gate Hard for missing data
        }
    }

    /// THE SAME CAP THE TARGET USES, and for the same reason: an editor
    /// that recomputes a horizon without the clamp the plan was BUILT
    /// with is a safety gate with a back door — the argument
    /// `testThePaceEditorCannotUnlockHardWhereThePickerLocksIt` already
    /// makes for Hard.
    ///
    /// 2026-08-14: this read `safety_pace_cap` directly, so after a
    /// sign-out (which sweeps the whole `safety_` family) a goal or pace
    /// edit recomputed an under-18's or an underweight user's window
    /// with no cap at all. It resolves through `TargetsService` now,
    /// which falls back to the derivable half of the gate's own
    /// arithmetic when the stored answer is gone.
    @MainActor
    private static func safetyCap(
        _ d: UserDefaults, userId: String, in context: ModelContext
    ) -> Double? {
        let current = TargetsService.latestWeightKg(userId: userId, in: context)
            ?? d.double(forKey: "onboardingCurrentWeightKg").positiveOrNil
        return TargetsService.resolvedSafetyCap(currentWeightKg: current, d)
    }
}

private extension Double {
    var positiveOrNil: Double? { self > 0 ? self : nil }
}
