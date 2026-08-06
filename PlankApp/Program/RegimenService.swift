import Foundation
import SwiftData
import PlankSync

// MARK: - RegimenService
//
// App v8 (docs/app_v8/03_ARCHITECTURE.md §3c) — her medication /
// supplement plans, resolved. The shot-day anchor is the one field
// the clinic panel named transformative: with it the engines know
// WHERE in the medication week her body is. Pure date math lives in
// static funcs (unit-tested); the resolver wraps SwiftData.
//
// Laws: the app never authors dosing content; displayName renders
// only where SHE reads it; dose-day composition rides CareProtocol.

@MainActor
enum RegimenService {

    // MARK: - Resolve

    static func activeMedicationPlan(
        userId: String, in context: ModelContext
    ) -> RegimenPlanRecord? {
        guard !userId.isEmpty else { return nil }
        let d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == "medication" && $0.endedAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let active = (try? context.fetch(d)) ?? []
        // S4: when a care-team plan and a self plan are both active
        // (the window between assignment and the patient's
        // reconciliation), the clinician plan leads — deterministic,
        // never an ambiguous double-active. Dose marks stamp its id
        // (provenance follows the resolver). The self plan stays in
        // the chart until she confirms; then it ends.
        return active.first { $0.authority == "care_team" } ?? active.first
    }

    /// The active SELF-managed plan, if any — the reconciliation
    /// moment needs it to retire it once she confirms the clinician's.
    static func activeSelfMedicationPlan(
        userId: String, in context: ModelContext
    ) -> RegimenPlanRecord? {
        guard !userId.isEmpty else { return nil }
        let d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == "medication"
                    && $0.endedAt == nil && $0.authority == "self"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(d)).flatMap { $0.first }
    }

    /// The active CARE-TEAM plan, if any (the reconciliation subject).
    static func activeCareTeamMedicationPlan(
        userId: String, in context: ModelContext
    ) -> RegimenPlanRecord? {
        guard !userId.isEmpty else { return nil }
        let d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == "medication"
                    && $0.endedAt == nil && $0.authority == "care_team"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(d)).flatMap { $0.first }
    }

    static func supplementPlans(
        userId: String, in context: ModelContext
    ) -> [RegimenPlanRecord] {
        guard !userId.isEmpty else { return [] }
        let d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == "supplement" && $0.endedAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? context.fetch(d)) ?? []
    }

    // MARK: - Authority (founder refinement 2026-07-28)

    /// The future source of truth for medication is the CLINICIAN.
    /// A plan whose authority is the care team (or that carries the
    /// org/protocol seam — belt and braces) is clinician-managed:
    /// the patient app renders it faithfully and only marks doses /
    /// reports symptoms — it NEVER silently modifies it. Self-
    /// created plans stay hers to edit. Enforced here at the
    /// service so no future surface can forget.
    static func isManagedByCareTeam(_ plan: RegimenPlanRecord) -> Bool {
        plan.authority == "care_team"
            || plan.orgId != nil
            || plan.sourceProtocolId != nil
    }

    /// The active medication plan's id, for stamping dose-mark and
    /// symptom observations with their regimen provenance (the
    /// clinician-portal join key).
    static func activeMedicationPlanId(
        userId: String, in context: ModelContext
    ) -> String? {
        activeMedicationPlan(userId: userId, in: context)?.id
    }

    // MARK: - Write (self-managed plans only)

    /// Create or update the SELF-managed medication plan's shot-day
    /// anchor. One field, changeable anytime; name stays optional
    /// and hers. A clinician-managed plan is returned unchanged —
    /// its schedule belongs to the care team.
    @discardableResult
    static func setShotDay(
        _ isoWeekday: Int, userId: String, in context: ModelContext
    ) -> RegimenPlanRecord? {
        guard (1...7).contains(isoWeekday), !userId.isEmpty else { return nil }
        let plan: RegimenPlanRecord
        if let existing = activeMedicationPlan(userId: userId, in: context) {
            guard !isManagedByCareTeam(existing) else { return existing }
            existing.anchorWeekday = isoWeekday
            existing.scheduleRule = "weeklyAnchor"
            existing.updatedAt = .now
            existing.pendingUpsert = true
            plan = existing
        } else {
            plan = RegimenPlanRecord(
                userId: userId,
                kind: "medication",
                displayName: "",
                scheduleRule: "weeklyAnchor",
                anchorWeekday: isoWeekday
            )
            context.insert(plan)
        }
        try? context.save()
        let toSync = plan
        Task { await AppSync.shared.upsertRegimenPlan(toSync) }
        return plan
    }

    /// End the SELF-managed medication plan (she stopped / removed
    /// it). Records keep their history; the engines simply stop
    /// composing dose days. Clinician-managed plans end only
    /// through the care team.
    static func endMedicationPlan(userId: String, in context: ModelContext) {
        guard let plan = activeMedicationPlan(userId: userId, in: context),
              !isManagedByCareTeam(plan) else { return }
        plan.endedAt = .now
        plan.updatedAt = .now
        plan.pendingUpsert = true
        try? context.save()
        let toSync = plan
        Task { await AppSync.shared.upsertRegimenPlan(toSync) }
    }

    // MARK: - Pure date math (unit-tested)

    /// Stage A intake words → ISO weekday. nil for empty/unknown
    /// (a skipped ask writes nothing).
    nonisolated static func isoWeekday(fromWord word: String?) -> Int? {
        switch word {
        case "mon": return 1
        case "tue": return 2
        case "wed": return 3
        case "thu": return 4
        case "fri": return 5
        case "sat": return 6
        case "sun": return 7
        default: return nil
        }
    }

    /// ISO weekday for a date: 1 = Monday … 7 = Sunday.
    nonisolated static func isoWeekday(
        _ date: Date, calendar: Calendar = .current
    ) -> Int {
        let apple = calendar.component(.weekday, from: date)  // 1 = Sun
        return apple == 1 ? 7 : apple - 1
    }

    /// Whether `date` is a dose day for a weekly anchor.
    nonisolated static func isDoseDay(
        _ date: Date, anchorWeekday: Int?, calendar: Calendar = .current
    ) -> Bool {
        guard let anchorWeekday else { return false }
        return isoWeekday(date, calendar: calendar) == anchorWeekday
    }

    /// 0 = shot day, 1 = day after … 6 = the day before the next
    /// shot. nil without an anchor. The waveform position the
    /// briefs + sit-check correlation read (v8 next passes).
    nonisolated static func dayInMedicationWeek(
        _ date: Date, anchorWeekday: Int?, calendar: Calendar = .current
    ) -> Int? {
        guard let anchorWeekday else { return nil }
        return (isoWeekday(date, calendar: calendar) - anchorWeekday + 7) % 7
    }

    /// The titration-support window: weeks since the plan started,
    /// against the protocol's window. (S1 approximation — a later
    /// pass keys off dose-stage changes when she records them.)
    nonisolated static func titrationWindowActive(
        _ date: Date, startedAt: Date?,
        careProtocol: CareProtocol = .default,
        calendar: Calendar = .current
    ) -> Bool {
        guard let startedAt else { return false }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: startedAt),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return days >= 0 && days < careProtocol.regimen.titrationSupportWeeks * 7
    }
}
