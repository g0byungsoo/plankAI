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
        case "late": seedLate(userId: userId, in: context)
        case "next": seedBetweenDoses(userId: userId, in: context)
        default: seedInjectable(userId: userId, in: context)
        }
    }

    /// 2026-08-13 — BETWEEN DOSES, the state a weekly injector is in
    /// five days out of seven and the one no door could reach: every
    /// other variant anchors the dose to today, so `DoseStanding`'s
    /// `.upcoming` branch — the only thing Home has ever said about
    /// medication on a non-dose day — was unfilmable.
    ///
    /// Her recent slots are TAKEN, which is the point: an unresolved
    /// one correctly outranks the countdown (`seedLate` films that).
    private static func seedBetweenDoses(userId: String, in context: ModelContext) {
        guard RegimenService.activeSelfMedicationPlan(userId: userId, in: context) == nil
        else { return }
        let cal = Calendar.current
        // Four days ago, so the next anchor is three days out and the
        // last slot sits comfortably inside its resolved history.
        let lastSlot = cal.date(byAdding: .day, value: -4, to: .now) ?? .now
        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = "ozempic"
        spec.displayName = "ozempic"
        spec.route = "injection"
        spec.scheduleRule = "weeklyAnchor"
        spec.anchorWeekday = RegimenService.isoWeekday(lastSlot)
        spec.timeOfDayMinutes = 18 * 60
        spec.doseValue = 0.5
        spec.reminderEnabled = true
        guard let plan = RegimenService.applySelfRegimen(
            spec, userId: userId,
            now: cal.date(byAdding: .day, value: -32, to: .now) ?? .now,
            in: context
        ) else { return }
        let facts = RegimenService.facts(for: plan)
        // Resolve the slots the ENGINE sees, not fixed day offsets.
        // The first draft wrote "taken" at -4/-11/-18/-25 assuming the
        // anchor landed exactly four days back; it did not, so every
        // event missed its slot, the real one stayed unresolved, and
        // the standing correctly read `.late` instead of `.upcoming`.
        // The engine was right and the fixture was wrong — the same
        // lesson the unit tests recorded an hour earlier.
        for day in MedicationScheduleEngine.slotDays(
            through: .now, lookbackDays: 30, facts: facts
        ) {
            _ = DoseEventStore.upsert(
                dayKey: MedicationScheduleEngine.dayKey(for: day),
                scheduledAt: MedicationScheduleEngine.scheduledAt(onDay: day, facts: facts),
                status: "taken",
                takenAt: MedicationScheduleEngine.scheduledAt(onDay: day, facts: facts),
                site: .leftAbdomen,
                source: "sheet", userId: userId, regimenPlanId: plan.id,
                in: context, sync: false
            )
        }
        let d = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for event in (try? context.fetch(d)) ?? [] { event.pendingUpsert = false }
        let r = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for p in (try? context.fetch(r)) ?? [] { p.pendingUpsert = false }
        try? context.save()
    }

    /// v25 E2 — the open late slot: a weekly regimen whose dose day
    /// was three days ago and whose slot is still unresolved. The
    /// dose row returns as the late support; the dose sheet opens
    /// the late face with the label-facts card.
    private static func seedLate(userId: String, in context: ModelContext) {
        guard RegimenService.activeSelfMedicationPlan(userId: userId, in: context) == nil
        else { return }
        let cal = Calendar.current
        let slotDay = cal.date(byAdding: .day, value: -3, to: .now) ?? .now
        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = "wegovy"
        spec.displayName = "wegovy"
        spec.route = "injection"
        spec.scheduleRule = "weeklyAnchor"
        spec.anchorWeekday = RegimenService.isoWeekday(slotDay)
        spec.timeOfDayMinutes = 18 * 60
        spec.doseValue = 1.0
        spec.reminderEnabled = true
        guard let plan = RegimenService.applySelfRegimen(
            spec, userId: userId,
            now: cal.date(byAdding: .day, value: -31, to: .now) ?? .now,
            in: context
        ) else { return }
        let facts = RegimenService.facts(for: plan)
        // Prior weeks taken on their day; THIS week's slot stays
        // open (and one week further back missed — the wegovy
        // interruption line needs ≥2 consecutive unresolved to
        // render, so it must NOT appear here with just one).
        for daysBack in [10, 17, 24] {
            let day = cal.date(byAdding: .day, value: -daysBack, to: .now) ?? .now
            _ = DoseEventStore.upsert(
                dayKey: MedicationScheduleEngine.dayKey(for: day),
                scheduledAt: MedicationScheduleEngine.scheduledAt(onDay: day, facts: facts),
                status: "taken",
                takenAt: MedicationScheduleEngine.scheduledAt(onDay: day, facts: facts),
                site: .leftAbdomen,
                source: "sheet", userId: userId, regimenPlanId: plan.id,
                in: context, sync: false
            )
        }
        let d = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for event in (try? context.fetch(d)) ?? [] { event.pendingUpsert = false }
        let r = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for p in (try? context.fetch(r)) ?? [] { p.pendingUpsert = false }
        try? context.save()
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

        // The pattern proof: queasiness the day after each of the
        // last three shots (all post-change) + one unrelated
        // headache — the engine's after-change AND after-dose
        // reads both fire, deterministically.
        for week in [3, 2, 1] {
            let dayAfter = cal.date(byAdding: .day, value: 1, to: weeksAgo(week)) ?? .now
            _ = SideEffectLog.record(
                .nausea, severity: .noticeable,
                dayKey: MedicationScheduleEngine.dayKey(for: dayAfter),
                userId: userId, in: context
            )
        }
        if let scattered = cal.date(byAdding: .day, value: -4, to: weeksAgo(6)) {
            _ = SideEffectLog.record(
                .headache, severity: .aTouch,
                dayKey: MedicationScheduleEngine.dayKey(for: scattered),
                userId: userId, in: context
            )
        }

        // v25 E2 — the signature series: food noise returning on
        // day 5 of each of the last three cycles (the pattern
        // engine's cross-cycle read fires deterministically).
        for week in [3, 2, 1] {
            if let day5 = cal.date(byAdding: .day, value: 4, to: weeksAgo(week)) {
                _ = SideEffectLog.record(
                    .foodNoise, severity: .noticeable,
                    dayKey: MedicationScheduleEngine.dayKey(for: day5),
                    userId: userId, in: context
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
        let o = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.userId == userId && $0.kind == "symptom" }
        )
        for record in (try? context.fetch(o)) ?? [] { record.pendingUpsert = false }
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
