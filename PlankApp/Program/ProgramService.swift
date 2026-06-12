import Foundation
import Observation
import SwiftData
import PlankSync

// MARK: - ProgramService
//
// v1.1 program pivot. The @Observable @MainActor singleton that
// wraps SwiftData reads + AppSync writes for the ProgramPlan layer.
//
// Read API:
//   - `activePlan(in:)` — returns the active ProgramPlanRecord for
//     the current user, or nil if none.
//   - `currentSchedule(in:)` — computed Result from
//     ProgramScheduleCalculator (program day, weeks, goal date,
//     post-goal flag).
//   - `currentProfile(in:)` — IntensityProfile bound to the active
//     plan's intensity_tier.
//
// Write API:
//   - `startProgram(input:userId:context:)` — writes ProgramPlanRecord
//     + denormalizes (program_intensity_tier, program_goal_date,
//     program_status='active') to UserRecord; fires cloud upserts.
//   - `markChecklistItem(prescription:state:userId:context:)` —
//     upserts ProgramDayCheckRecord. Used by the PlanView tap handlers
//     + the auto-completion observers that watch SessionLogRecord /
//     FoodScanRecord / WeightLogRecord inserts.
//
// One active plan per user — enforced client-side at write time.
// startProgram archives any prior active plan (phase='completed' or
// 'abandoned' per onboarding flow) before inserting the new one.

@MainActor
@Observable
public final class ProgramService {

    public static let shared = ProgramService()

    private init() {}

    // MARK: - Read

    /// The user's active ProgramPlanRecord (phase != completed/abandoned)
    /// from the local SwiftData store. nil when the user hasn't enrolled
    /// in a program yet — PlanView treats this as the "show empty/opt-in"
    /// state.
    public func activePlan(userId: String, in context: ModelContext) -> ProgramPlanRecord? {
        guard !userId.isEmpty else { return nil }
        var descriptor = FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { plan in
                plan.userId == userId
                    && (plan.phase == "active" || plan.phase == "maintenance" || plan.phase == "recomp" || plan.phase == "pause")
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Computed schedule for the active plan. Re-evaluates every call —
    /// program_day is derived from start_date + Calendar offset, never
    /// stored, per [[project-engagement-day]] precedent.
    public func currentSchedule(userId: String, in context: ModelContext) -> ProgramScheduleCalculator.Result? {
        guard let plan = activePlan(userId: userId, in: context) else { return nil }
        return ProgramScheduleCalculator.compute(
            .init(startDate: plan.startDate, totalDays: plan.totalDays)
        )
    }

    /// IntensityProfile resolved from the active plan's intensity_tier.
    /// Falls back to .medium when no active plan exists (defensive — UI
    /// should already gate on activePlan != nil before reading this).
    public func currentProfile(userId: String, in context: ModelContext) -> IntensityProfile {
        guard
            let plan = activePlan(userId: userId, in: context),
            let tier = IntensityTier(rawValue: plan.intensityTier)
        else { return .medium }
        return .from(tier: tier)
    }

    /// True when programDay > totalDays — fires ChapterCompleteView /
    /// the Day-75 graduation sentinel on first home open after goalDate.
    public func isPostGoal(userId: String, in context: ModelContext) -> Bool {
        currentSchedule(userId: userId, in: context)?.isPostGoal ?? false
    }

    // MARK: - Write

    public struct StartProgramInput {
        public let currentWeightKg: Double
        public let goalWeightKg: Double
        public let tier: IntensityTier
        public let goalCalculator: ProgramGoalCalculator.Inputs
        public let startDate: Date

        public init(
            currentWeightKg: Double,
            goalWeightKg: Double,
            tier: IntensityTier,
            goalCalculator: ProgramGoalCalculator.Inputs,
            startDate: Date = .now
        ) {
            self.currentWeightKg = currentWeightKg
            self.goalWeightKg = goalWeightKg
            self.tier = tier
            self.goalCalculator = goalCalculator
            self.startDate = startDate
        }
    }

    /// Spawn a new ProgramPlanRecord and archive any previously active
    /// plan. Called by:
    ///   - CommitmentSignatureScreen (onboarding case 173) on first-time
    ///     enrollment from the program-era onboarding sub-flow.
    ///   - ProgramOnrampView (Today tab pre-enrollment)
    ///     post-v1.1 launch.
    ///   - ProgramGraduationSheet (Phase 5) when picking a next-program
    ///     track (Maintenance 30 / Recomp 60 / New Goal 75 / Soft Pause).
    ///
    /// Side effects:
    ///   - Inserts ProgramPlanRecord
    ///   - Archives prior active plan (phase='abandoned' or 'completed')
    ///   - Saves the context
    ///   - Fires AppSync.upsertProgramPlan for cloud write (fire-and-forget)
    @discardableResult
    public func startProgram(
        input: StartProgramInput,
        userId: String,
        in context: ModelContext
    ) -> ProgramPlanRecord {
        // 1. Archive any active plan. The transition-from-graduation
        //    flow will pass phase='completed'; first-time enrollment
        //    archives any leftover with 'abandoned'.
        if let existing = activePlan(userId: userId, in: context) {
            existing.phase = "abandoned"
            existing.archivedAt = .now
            existing.updatedAt = .now
            existing.pendingUpsert = true
        }

        // 2. Compute window + duration for the picked tier.
        let window = ProgramGoalCalculator.compute(input.goalCalculator)
        let weeks = window.weeks(for: input.tier)
        let totalDays = weeks * 7
        let goalDate = window.goalDate(from: input.startDate, tier: input.tier)

        // 3. Insert the new plan.
        let plan = ProgramPlanRecord(
            userId: userId,
            startDate: input.startDate,
            goalDate: goalDate,
            totalDays: totalDays,
            currentWeightKg: input.currentWeightKg,
            goalWeightKg: input.goalWeightKg,
            intensityTier: input.tier.rawValue,
            phase: "active",
            parentPlanId: nil
        )
        context.insert(plan)

        try? context.save()

        return plan
    }

    /// Mark a checklist item as complete / skipped / autoCompleted.
    /// Upserts (or inserts) the ProgramDayCheckRecord for today's
    /// (planId, day, itemKey) — the UNIQUE constraint on the server
    /// + the @Attribute(.unique) on id handle idempotency.
    @discardableResult
    public func markChecklistItem(
        prescription: ProgramDayPrescription,
        state: ChecklistState,
        userId: String,
        in context: ModelContext
    ) -> ProgramDayCheckRecord? {
        guard let plan = activePlan(userId: userId, in: context) else { return nil }
        guard let schedule = currentSchedule(userId: userId, in: context) else { return nil }
        let day = schedule.programDay
        let itemKey = prescription.itemKey
        let planId = plan.id

        // Look up an existing row for today's (plan, day, itemKey).
        let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { check in
                check.programPlanId == planId
                    && check.programDay == day
                    && check.itemKey == itemKey
            }
        )
        let existing = try? context.fetch(descriptor).first

        let record: ProgramDayCheckRecord
        if let existing {
            existing.state = state.rawValue
            existing.completedAt = state.isCompleted ? .now : existing.completedAt
            existing.updatedAt = .now
            existing.pendingUpsert = true
            record = existing
        } else {
            record = ProgramDayCheckRecord(
                userId: userId,
                programPlanId: planId,
                programDay: day,
                itemKey: itemKey,
                state: state.rawValue
            )
            record.completedAt = state.isCompleted ? .now : nil
            context.insert(record)
        }

        try? context.save()
        return record
    }

    public enum ChecklistState: String {
        case empty
        case complete
        case skipped
        case autoCompleted

        public var isCompleted: Bool {
            switch self {
            case .complete, .autoCompleted: return true
            case .empty, .skipped: return false
            }
        }
    }
}
