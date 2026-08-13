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
            isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(
                from: d.string(forKey: "onboardingHormonalStage") ?? ""),
            isShortSleeper: ProgramGoalCalculator.isShortSleeper(
                from: d.string(forKey: "onboardingSleepHours") ?? ""),
            weightTrendKey: d.string(forKey: "onboarding_weight_trend") ?? "",
            glp1PhaseKey: d.string(forKey: "onboarding_glp1_phase") ?? "",
            paceCapPctPerWeek: safetyCap(d)
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

    private static func safetyCap(_ d: UserDefaults) -> Double? {
        guard d.object(forKey: "safety_pace_cap") != nil else { return nil }
        let cap = d.double(forKey: "safety_pace_cap")
        return cap >= 0 ? cap : nil
    }
}
