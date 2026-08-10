#if DEBUG
import Foundation
import PlankFood
import PlankSync
import SwiftData

// MARK: - ClinicDemoSeeder (the demo clinic loop — scripts/demo/)
//
// ONE patient's ten weeks, written through the real stores so the
// record a clinician reads is composed by the real projection. This
// is the only seeder in the app whose rows SYNC: every other QA
// seeder deliberately sets pendingUpsert = false so synthetic data
// can never reach the consumer project. This one runs exclusively
// against the local demo stack (`--demo-backend`), where synthetic
// data is the entire point — and it refuses to run anywhere else.
//
// THE STORY (docs/demo/00_DEMO.md §3), and why it is the right one:
// a clinic already knows what it prescribed and what the scale said
// at the last visit. What it cannot see is the shape of the weeks in
// between. Maya escalated three weeks ago, has taken every dose since
// but one, and has logged nausea in the two days after each of the
// last three. Her protein has fallen with her appetite. Nothing here
// is an emergency; all of it is exactly what a clinician would want
// in hand before deciding whether to escalate again.
//
// Deterministic: every id is derived, every date is an offset from
// today, and re-running changes nothing. Idempotent by construction.

@MainActor
enum ClinicDemoSeeder {

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("--demo-patient")
    }

    private static let cal = Calendar.current

    private static func daysAgo(_ n: Int) -> Date {
        cal.date(byAdding: .day, value: -n, to: cal.startOfDay(for: .now)) ?? .now
    }

    private static func dayKey(_ n: Int) -> String {
        TodayStateService.dayKey(for: daysAgo(n))
    }

    // The dose rhythm: ten weekly slots, most recent first. Anchor is
    // whatever weekday sits 7 days back, so the demo never opens on a
    // due-today dose it has to explain.
    private static let doseWeeksAgo = Array(1...10)

    static func seed(userId: String, in context: ModelContext) {
        guard SupabaseConfig.isDemoBackend else {
            // A demo seed that syncs must never point at production.
            print("[ClinicDemoSeeder] refusing: --demo-patient requires --demo-backend")
            return
        }
        guard !userId.isEmpty else { return }
        guard !UserDefaults.standard.bool(forKey: seededKey(userId)) else { return }

        seedIdentity()
        seedProgram(userId: userId, in: context)
        let plans = seedRegimenEras(userId: userId, in: context)
        seedDoses(userId: userId, plans: plans, in: context)
        seedSymptoms(userId: userId, in: context)
        seedWeights(userId: userId, in: context)
        seedFood(userId: userId, in: context)
        seedMovement(userId: userId, in: context)
        seedSitChecks(userId: userId, in: context)

        UserDefaults.standard.set(true, forKey: seededKey(userId))
        try? context.save()
    }

    private static func seededKey(_ userId: String) -> String {
        "demo.clinic.seeded.\(userId.lowercased())"
    }

    // MARK: identity

    private static func seedIdentity() {
        let d = UserDefaults.standard
        d.set(true, forKey: "hasCompletedOnboarding")
        d.set(true, forKey: "programEraEnabled")
        d.set(true, forKey: "hasEnrolledInProgram")
        d.set("maya", forKey: "userName")
        d.set(92.0, forKey: "onboardingCurrentWeightKg")
        d.set(78.0, forKey: "onboardingGoalWeightKg")
        d.set(168.0, forKey: "onboardingHeightCm")
        d.set(34, forKey: "onb_v5_age_years")
        d.set("female", forKey: "onboardingGender")
        d.set("walks", forKey: "onb_v4_movement_baseline")
        d.set("current", forKey: "onboarding_glp1_status")
        d.set("lb", forKey: "weightUnit")
        if (d.string(forKey: "appV2SeenAt") ?? "").isEmpty {
            d.set(ISO8601DateFormatter().string(from: .now), forKey: "appV2SeenAt")
        }
    }

    // MARK: the program
    //
    // Six weeks into Jeni, ten weeks into the medication. That gap is
    // deliberate and true to the market: patients arrive already
    // medicated, and the clinic adopts Jeni around them.

    private static let programDay = 42

    private static func seedProgram(userId: String, in context: ModelContext) {
        if ProgramService.shared.activePlan(userId: userId, in: context) == nil {
            _ = ProgramService.shared.startProgram(
                input: ProgramService.StartProgramInput(
                    currentWeightKg: 92.0,
                    goalWeightKg: 78.0,
                    tier: .medium,
                    goalCalculator: ProgramGoalCalculator.Inputs(
                        currentWeightKg: 92.0,
                        goalWeightKg: 78.0,
                        sex: .female,
                        age: 34
                    )
                ),
                userId: userId,
                in: context
            )
        }
        guard let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        else { return }
        let target = daysAgo(programDay - 1)
        if !cal.isDate(plan.startDate, inSameDayAs: target) {
            plan.startDate = target
            plan.updatedAt = .now
            plan.pendingUpsert = true
            try? context.save()
            Task { await AppSync.shared.upsertProgramPlan(plan) }
        }
    }

    // MARK: the regimen eras
    //
    // She started on her own — the clinic's plan arrives later, live,
    // when she enters the code. That ordering is the truthful one:
    // her history predates the connection, and reconciliation is what
    // joins them without rewriting either.

    private struct Eras {
        let early: RegimenPlanRecord      // 0.5 mg, weeks 10–4
        let current: RegimenPlanRecord    // 1.0 mg, week 3 onward
    }

    private static func seedRegimenEras(
        userId: String, in context: ModelContext
    ) -> Eras? {
        if let existing = RegimenService.activeSelfMedicationPlan(userId: userId, in: context),
           let prior = priorPlan(of: existing, userId: userId, in: context) {
            return Eras(early: prior, current: existing)
        }
        let anchor = RegimenService.isoWeekday(daysAgo(7))

        var spec = RegimenService.SelfRegimenSpec()
        spec.productId = "wegovy"
        spec.displayName = "wegovy"
        spec.route = "injection"
        spec.scheduleRule = "weeklyAnchor"
        spec.anchorWeekday = anchor
        spec.timeOfDayMinutes = 19 * 60
        spec.doseValue = 0.5
        spec.reminderEnabled = true
        guard let early = RegimenService.applySelfRegimen(
            spec, userId: userId, now: daysAgo(70), in: context
        ) else { return nil }

        // The era seam: escalated three weeks ago.
        spec.doseValue = 1.0
        guard let current = RegimenService.applySelfRegimen(
            spec, userId: userId, now: daysAgo(21), in: context
        ) else { return nil }

        return Eras(early: early, current: current)
    }

    private static func priorPlan(
        of plan: RegimenPlanRecord, userId: String, in context: ModelContext
    ) -> RegimenPlanRecord? {
        guard let previousId = plan.previousPlanId else { return nil }
        let d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.id == previousId }
        )
        return try? context.fetch(d).first
    }

    // MARK: doses — nine of ten taken, one skipped while travelling

    private static func seedDoses(
        userId: String, plans: Eras?, in context: ModelContext
    ) {
        guard let plans else { return }
        let sites: [InjectionSite] = [
            .leftAbdomen, .rightAbdomen, .leftThigh, .rightThigh, .leftArm, .rightArm,
        ]
        for (index, weeksAgo) in doseWeeksAgo.enumerated() {
            let slot = daysAgo(weeksAgo * 7)
            let key = TodayStateService.dayKey(for: slot)
            let escalated = weeksAgo <= 3
            let plan = escalated ? plans.current : plans.early
            let facts = RegimenService.facts(for: plan)
            let skipped = weeksAgo == 6      // the week she travelled

            _ = DoseEventStore.upsert(
                dayKey: key,
                scheduledAt: MedicationScheduleEngine.scheduledAt(onDay: slot, facts: facts),
                status: skipped ? "skipped" : "taken",
                takenAt: skipped ? nil
                    : MedicationScheduleEngine.scheduledAt(onDay: slot, facts: facts),
                site: skipped ? nil : sites[index % sites.count],
                skipReason: skipped ? "traveling" : nil,
                source: "sheet", userId: userId, regimenPlanId: plan.id,
                in: context
            )
            // The observation is what the packet actually counts.
            ObservationStore.record(
                .doseTaken, valueText: skipped ? "skipped" : "yes",
                payload: ObservationStore.regimenPayload(plan.id),
                dayKey: key, userId: userId, in: context
            )
            UserDefaults.standard.set(
                skipped ? "skipped" : "yes", forKey: "day.dose.\(key)"
            )
        }
    }

    // MARK: symptoms — the signal that earns the clinician's attention
    //
    // Nausea in the two days after each of the last three doses (all
    // of them after the escalation), plus food noise returning late
    // in each cycle. Three qualifying records is what makes the
    // packet's timing rule fire — and the rule states timing, never
    // causality.

    private static func seedSymptoms(userId: String, in context: ModelContext) {
        for weeksAgo in [1, 2, 3] {
            let dayAfterDose = weeksAgo * 7 - 1
            SideEffectLog.record(
                .nausea, severity: weeksAgo == 1 ? .rough : .noticeable,
                dayKey: dayKey(dayAfterDose), userId: userId, in: context
            )
        }
        // Appetite returning on day 5 of each recent cycle.
        for weeksAgo in [1, 2, 3] {
            SideEffectLog.record(
                .foodNoise, severity: .noticeable,
                dayKey: dayKey(weeksAgo * 7 - 5), userId: userId, in: context
            )
        }
        // One unrelated entry, long before the change — the record is
        // not a curated highlight reel.
        SideEffectLog.record(
            .headache, severity: .aTouch, dayKey: dayKey(45),
            userId: userId, in: context
        )
    }

    // MARK: weights — steady easing, then faster after the change

    private static func seedWeights(userId: String, in context: ModelContext) {
        // kg by days-ago. Roughly 0.4 kg/wk before the escalation and
        // 0.7 kg/wk after it — a real, unremarkable acceleration that
        // is still inside a sane band.
        let series: [(Int, Double)] = [
            (70, 92.0), (63, 91.6), (56, 91.1), (49, 90.8), (42, 90.3),
            (35, 89.9), (28, 89.4), (24, 89.2), (21, 89.0), (17, 88.6),
            (14, 88.2), (10, 87.9), (7, 87.4), (4, 87.1), (1, 86.8),
        ]
        for (ago, kg) in series {
            let id = "demo-weight-\(ago)-\(userId.lowercased())"
            let d = FetchDescriptor<WeightLogRecord>(predicate: #Predicate { $0.id == id })
            if (try? context.fetch(d).first) != nil { continue }
            let log = WeightLogRecord(
                id: id, userId: userId, weightKg: kg,
                loggedAt: daysAgo(ago).addingTimeInterval(8 * 3600), source: "manual"
            )
            context.insert(log)
            Task { await AppSync.shared.upsertWeightLog(log) }
        }
    }

    // MARK: food — logged most days; protein falls after the change

    private static func seedFood(userId: String, in context: ModelContext) {
        // Her protein floor is ~140 g. Before the escalation she ate
        // three meals and cleared it most days; after it, appetite
        // dropped, the third meal went, and she stopped clearing it.
        // That arc is the whole point — so the meals have to carry
        // enough protein to actually cross the floor on the good
        // days, or the packet reports "0 of 22" and reads as broken
        // data rather than as a change worth discussing.
        let meals: [(String, Double, Double, Double, Double, Double)] = [
            ("greek yogurt, berries, walnuts", 380, 34, 28, 14, 5),
            ("chicken salad, olive oil", 520, 52, 14, 28, 6),
            ("salmon, rice, broccoli", 610, 48, 48, 22, 7),
            ("eggs, cottage cheese, toast", 470, 41, 30, 19, 8),
            ("turkey chili", 540, 46, 42, 18, 11),
            ("cottage cheese, peach", 260, 32, 18, 5, 2),
            ("tofu stir fry, edamame", 500, 39, 46, 17, 9),
        ]
        // Today, up to the early afternoon: breakfast and lunch are
        // in, dinner is not. The day is alive but unfinished, which
        // is what an afternoon actually looks like.
        FoodLogPersister.debugSeed(
            id: "demo-food-0-0-\(userId.lowercased())", userId: userId,
            loggedAt: cal.startOfDay(for: .now).addingTimeInterval(8 * 3600),
            kcal: 320, protein: 26, carbs: 28, fat: 12, fiber: 5,
            sugar: 9, sodiumMg: 180, title: "greek yogurt, berries, walnuts",
            source: "demo"
        )
        FoodLogPersister.debugSeed(
            id: "demo-food-0-1-\(userId.lowercased())", userId: userId,
            loggedAt: cal.startOfDay(for: .now).addingTimeInterval(13 * 3600),
            kcal: 460, protein: 41, carbs: 14, fat: 26, fiber: 6,
            sugar: 4, sodiumMg: 610, title: "chicken salad, olive oil",
            source: "demo"
        )

        // The day's shape is chosen explicitly rather than left to a
        // modulo over the meal list — the whole signal is "she used
        // to clear her protein floor and now she doesn't", and that
        // has to be true of the numbers, not approximately true.
        //
        //   before the change  breakfast + lunch + dinner  ≈ 146 g   ✓ over 140
        //   after the change   breakfast + lunch           ≈  86 g   ✗
        //   the roughest days  one meal                    ≈  32 g   ✗
        let fullDay = [1, 2, 4]        // yogurt + salad + salmon = 34+52+48
        let shortDay = [0, 3]          // yogurt + eggs           = 34+41
        let roughDay = [5]             // cottage cheese          = 32

        for ago in 1...34 {
            // She misses roughly one day in six.
            if ago % 6 == 0 { continue }
            let escalated = ago <= 21
            let slots: [Int] = escalated
                ? (ago % 4 == 0 ? roughDay : shortDay)
                : fullDay
            for (position, index) in slots.enumerated() {
                let m = meals[index]
                let hour = [8, 13, 19][min(position, 2)]
                FoodLogPersister.debugSeed(
                    id: "demo-food-\(ago)-\(position)-\(userId.lowercased())",
                    userId: userId,
                    loggedAt: daysAgo(ago).addingTimeInterval(Double(hour) * 3600),
                    kcal: m.1, protein: m.2, carbs: m.3, fat: m.4, fiber: m.5,
                    sugar: 6, sodiumMg: 520, title: m.0, source: "demo"
                )
            }
        }
    }

    /// The step history is in-memory (HealthKit stands in for it on a
    /// device), so unlike every other stream it has to be restored on
    /// EVERY launch — not once behind the seeded-already guard.
    static func restoreStepsIfNeeded() {
        guard isRequested, SupabaseConfig.isDemoBackend else { return }
        let history: [Int] = (0..<28).map { i in
            let ago = 27 - i
            let nearDose = [1, 2, 8, 9, 15, 16].contains(ago)
            return nearDose ? 3_900 + (ago % 3) * 220 : 6_800 + (ago % 5) * 340
        }
        StepsService.shared.seedForQA(
            weekly: Array(history.suffix(7)),
            today: 4_120,                 // mid-afternoon, below the goal
            history28: history
        )
    }

    // MARK: movement — walked most days; the clinic's step goal lands
    // on a real baseline rather than on nothing

    private static func seedMovement(userId: String, in context: ModelContext) {
        guard let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        else { return }
        // The move checks the packet counts.
        for ago in 1...27 where ago % 4 != 0 {
            let programDay = Self.programDay - ago
            guard programDay > 0 else { continue }
            let id = "demo-move-\(ago)-\(userId.lowercased())"
            let d = FetchDescriptor<ProgramDayCheckRecord>(predicate: #Predicate { $0.id == id })
            if (try? context.fetch(d).first) != nil { continue }
            let check = ProgramDayCheckRecord(
                id: id, userId: userId, programPlanId: plan.id,
                programDay: programDay, itemKey: "move", state: "complete"
            )
            check.completedAt = daysAgo(ago).addingTimeInterval(18 * 3600)
            check.pendingUpsert = false
            context.insert(check)
        }
    }

    // MARK: sit-checks — how meals sat, in her own words

    private static func seedSitChecks(userId: String, in context: ModelContext) {
        // "heavy" clusters in the days after the recent doses; "fine"
        // on the quiet days. The packet aggregates, never narrates.
        let heavyDays = [6, 13, 20, 5, 12]
        let fineDays = [2, 3, 9, 10, 16, 17, 23, 24]
        for ago in heavyDays {
            ObservationStore.record(
                .sitCheck, valueText: "heavy", dayKey: dayKey(ago),
                userId: userId, in: context
            )
        }
        for ago in fineDays {
            ObservationStore.record(
                .sitCheck, valueText: "fine", dayKey: dayKey(ago),
                userId: userId, in: context
            )
        }
    }
}
#endif
