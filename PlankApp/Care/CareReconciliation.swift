import Foundation
import SwiftData
import PlankSync

// MARK: - CareReconciliation (app v8 S4 — FR2)
//
// The state machine behind the reconciliation moment. Derived, not
// stored: a care-team plan that the patient hasn't acknowledged is
// `needsConfirmation`; her acknowledgment is a user-scoped careEvent
// observation (deterministic id per plan) so it survives sign-out
// and never leaks across accounts. No silent overwrite, no deletion,
// no double-active ambiguity — the active-plan resolver already
// prefers care_team; confirming simply retires the self plan.

@MainActor
enum CareReconciliation {

    enum State: Equatable {
        case none                                   // no care-team plan
        case needsConfirmation(RegimenPlanRecord)   // assigned, not yet acknowledged
        case reconciled
    }

    private static func ackId(userId: String, planId: String) -> String {
        "\(userId.lowercased())-reconciled-\(planId)"
    }

    static func state(userId: String, in context: ModelContext) -> State {
        guard let plan = RegimenService.activeCareTeamMedicationPlan(userId: userId, in: context)
        else { return .none }
        let acked = ObservationStore.fetch(
            id: ackId(userId: userId, planId: plan.id), in: context
        ) != nil
        return acked ? .reconciled : .needsConfirmation(plan)
    }

    /// The self plan whose rhythm this care-team plan likely
    /// supersedes (for the "your earlier records stay" line + the
    /// retire-on-confirm). nil when she had none.
    static func priorSelfPlan(userId: String, in context: ModelContext) -> RegimenPlanRecord? {
        RegimenService.activeSelfMedicationPlan(userId: userId, in: context)
    }

    /// "looks right": mark acknowledged locally, end the self plan
    /// (history intact — endedAt only), and record the confirmation
    /// server-side (audited). Future dose marks already join the
    /// care-team id via the resolver.
    static func confirm(
        plan: RegimenPlanRecord, userId: String, in context: ModelContext
    ) {
        let prior = priorSelfPlan(userId: userId, in: context)
        let dayKey = ObservationStore.record(
            .careEvent, valueText: "reconciled",
            payload: try? JSONSerialization.data(withJSONObject: [
                "careTeamPlanId": plan.id,
                "priorSelfPlanId": prior?.id as Any,
            ]),
            dayKey: todayKey(), userId: userId, source: "manual",
            in: context, sync: true, id: ackId(userId: userId, planId: plan.id)
        )
        _ = dayKey

        if let prior {
            prior.endedAt = .now
            prior.updatedAt = .now
            prior.pendingUpsert = true
            try? context.save()
            let toSync = prior
            Task { await AppSync.shared.upsertRegimenPlan(toSync) }
        }

        let planId = plan.id
        let priorId = prior?.id
        Task {
            try? await CareConnectionService.confirmReconciliation(
                planId: planId, action: "confirmed", priorSelfPlanId: priorId
            )
        }
    }

    /// "something's off": acknowledge so the sheet stops re-offering,
    /// but the plan stays flagged-not-confirmed until the clinic
    /// resolves the correction. The care-team plan still composes
    /// (a disputed plan is flagged, never deleted).
    static func markFlagged(
        plan: RegimenPlanRecord, userId: String, in context: ModelContext
    ) {
        _ = ObservationStore.record(
            .careEvent, valueText: "flagged",
            payload: try? JSONSerialization.data(withJSONObject: ["careTeamPlanId": plan.id]),
            dayKey: todayKey(), userId: userId, source: "manual",
            in: context, sync: true, id: ackId(userId: userId, planId: plan.id)
        )
        let planId = plan.id
        Task {
            try? await CareConnectionService.confirmReconciliation(
                planId: planId, action: "flagged", priorSelfPlanId: nil
            )
        }
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}
