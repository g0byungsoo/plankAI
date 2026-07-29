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
        var d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == "medication" && $0.endedAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        d.fetchLimit = 1
        return try? context.fetch(d).first
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

    // MARK: - Write

    /// Create or update the medication plan's shot-day anchor.
    /// One field, changeable anytime; name stays optional and hers.
    @discardableResult
    static func setShotDay(
        _ isoWeekday: Int, userId: String, in context: ModelContext
    ) -> RegimenPlanRecord? {
        guard (1...7).contains(isoWeekday), !userId.isEmpty else { return nil }
        let plan: RegimenPlanRecord
        if let existing = activeMedicationPlan(userId: userId, in: context) {
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

    /// End the medication plan (she stopped / removed it). Records
    /// keep their history; the engines simply stop composing dose
    /// days.
    static func endMedicationPlan(userId: String, in context: ModelContext) {
        guard let plan = activeMedicationPlan(userId: userId, in: context) else { return }
        plan.endedAt = .now
        plan.updatedAt = .now
        plan.pendingUpsert = true
        try? context.save()
        let toSync = plan
        Task { await AppSync.shared.upsertRegimenPlan(toSync) }
    }

    // MARK: - Pure date math (unit-tested)

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
