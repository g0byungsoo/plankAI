#if DEBUG
import Foundation
import PlankSync
import SwiftData

// MARK: - MedicationQASeeder (app v24 THE REGIMEN)
//
// The FoodBookQASeeder discipline: deterministic, idempotent,
// obviously-synthetic. Variants:
//   · injectable — ozempic 0.5 mg, weekly, anchored TODAY (the
//     dose sheet is due, the row leads).
//   · oral — rybelsus 7 mg, daily morning (the pill row rides as
//     support; empty-stomach line renders).
//   · b2b — a clinician-shaped plan (authority care_team, local-
//     only: pendingUpsert false so RLS never sees a client-forged
//     care row) — read-only faces + confirm provenance render.
//   · history — the injectable plus 9 weeks of regimen + events:
//     a dose change three weeks in (era seam), rotating sites,
//     one traveled skip — the becoming tile + ledger render real.

@MainActor
enum MedicationQASeeder {

    static func seed(variant: String, userId: String, in context: ModelContext) {
        switch variant {
        case "oral": seedOral(userId: userId, in: context)
        case "b2b": seedCareTeam(userId: userId, in: context)
        case "history": seedHistory(userId: userId, in: context)
        default: seedInjectable(userId: userId, in: context)
        }
    }

    // MARK: variants

    private static func seedInjectable(userId: String, in context: ModelContext) {
        guard RegimenService.activeSelfMedicationPlan(userId: userId, in: context) == nil
        else { reanchorToToday(userId: userId, in: context); return }
        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = "ozempic"
        spec.displayName = "ozempic"
        spec.route = "injection"
        spec.scheduleRule = "weeklyAnchor"
        spec.anchorWeekday = RegimenService.isoWeekday(.now)
        spec.timeOfDayMinutes = 18 * 60
        spec.doseValue = 0.5
        spec.reminderEnabled = true
        _ = RegimenService.applySelfRegimen(spec, userId: userId, in: context)
    }

    private static func seedOral(userId: String, in context: ModelContext) {
        guard RegimenService.activeSelfMedicationPlan(userId: userId, in: context) == nil
        else { return }
        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = "rybelsus"
        spec.displayName = "rybelsus"
        spec.route = "oral"
        spec.scheduleRule = "daily"
        spec.timeOfDayMinutes = 8 * 60
        spec.doseValue = 7
        spec.reminderEnabled = true
        _ = RegimenService.applySelfRegimen(spec, userId: userId, in: context)
    }

    private static func seedCareTeam(userId: String, in context: ModelContext) {
        let existing = RegimenService.activeCareTeamMedicationPlan(
            userId: userId, in: context
        )
        guard existing == nil else { return }
        let plan = RegimenPlanRecord(
            id: "qa-med-care-\(userId.lowercased())",
            userId: userId,
            kind: "medication",
            displayName: "Wegovy",
            scheduleRule: "weeklyAnchor",
            anchorWeekday: RegimenService.isoWeekday(.now),
            timeOfDayMinutes: 18 * 60
        )
        plan.authority = "care_team"
        plan.strengthValue = 1.0
        plan.strengthUnit = "mg"
        plan.instruction = "evening. thigh or abdomen is fine."
        plan.route = "injection"
        plan.productId = "wegovy"
        plan.pendingUpsert = false   // local-only; RLS owns real care rows
        context.insert(plan)
        try? context.save()
    }

    private static func seedHistory(userId: String, in context: ModelContext) {
        guard RegimenService.activeSelfMedicationPlan(userId: userId, in: context) == nil
        else { return }
        let cal = Calendar.current
        let anchor = RegimenService.isoWeekday(.now)
        func weeksAgo(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: -7 * n, to: .now) ?? .now
        }

        // v1: 0.25 mg, nine weeks ago.
        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = "ozempic"
        spec.displayName = "ozempic"
        spec.route = "injection"
        spec.scheduleRule = "weeklyAnchor"
        spec.anchorWeekday = anchor
        spec.timeOfDayMinutes = 18 * 60
        spec.doseValue = 0.25
        spec.reminderEnabled = true
        guard let v1 = RegimenService.applySelfRegimen(
            spec, userId: userId, now: weeksAgo(9), in: context
        ) else { return }

        // v2: 0.5 mg, three weeks ago (the era seam).
        spec.doseValue = 0.5
        guard let v2 = RegimenService.applySelfRegimen(
            spec, userId: userId, now: weeksAgo(3), in: context
        ) else { return }

        // Events: weeks 9…1 ago (today's slot stays due). Sites
        // rotate; week 5 traveled.
        let sites: [InjectionSite] = [
            .leftAbdomen, .rightAbdomen, .leftThigh, .rightThigh, .leftArm, .rightArm,
        ]
        for week in stride(from: 9, through: 1, by: -1) {
            let slotDay = weeksAgo(week)
            let key = MedicationScheduleEngine.dayKey(for: slotDay)
            let planId = week > 3 ? v1.id : v2.id
            let facts = RegimenService.facts(for: week > 3 ? v1 : v2)
            if week == 5 {
                _ = DoseEventStore.upsert(
                    dayKey: key,
                    scheduledAt: MedicationScheduleEngine.scheduledAt(onDay: slotDay, facts: facts),
                    status: "skipped", skipReason: "traveling",
                    source: "sheet", userId: userId, regimenPlanId: planId,
                    in: context, sync: false
                )
            } else {
                _ = DoseEventStore.upsert(
                    dayKey: key,
                    scheduledAt: MedicationScheduleEngine.scheduledAt(onDay: slotDay, facts: facts),
                    status: "taken",
                    takenAt: MedicationScheduleEngine.scheduledAt(onDay: slotDay, facts: facts),
                    site: sites[(9 - week) % sites.count],
                    source: "sheet", userId: userId, regimenPlanId: planId,
                    in: context, sync: false
                )
            }
        }

        // Weekly weigh-ins declining across the span (the dose-era
        // read draws from these) — obviously synthetic, source qa.
        for week in stride(from: 9, through: 0, by: -1) {
            let at = weeksAgo(week)
            let kg = 92.0 - Double(9 - week) * 0.55
            let log = WeightLogRecord(
                id: "qa-med-weight-\(week)-\(userId.lowercased())",
                userId: userId, weightKg: kg, loggedAt: at, source: "qa"
            )
            log.pendingUpsert = false
            context.insert(log)
        }

        // Keep the whole seed device-local (the sweep must never
        // push synthetic history to the dev DB).
        let d = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for event in (try? context.fetch(d)) ?? [] { event.pendingUpsert = false }
        let r = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for plan in (try? context.fetch(r)) ?? [] { plan.pendingUpsert = false }
        try? context.save()
    }

    private static func reanchorToToday(userId: String, in context: ModelContext) {
        if let plan = RegimenService.activeSelfMedicationPlan(userId: userId, in: context),
           plan.anchorWeekday != RegimenService.isoWeekday(.now) {
            _ = RegimenService.setShotDay(
                RegimenService.isoWeekday(.now), userId: userId, in: context
            )
        }
    }
}
#endif
