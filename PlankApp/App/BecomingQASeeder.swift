#if DEBUG
import Foundation
import PlankFood
import PlankSync
import SwiftData

// MARK: - BecomingQASeeder (pass 74 — BECOMING'S JOB)
//
// Realistic multi-month histories so Becoming can be judged as a
// customer would meet it, at every lens. The FoodBookQASeeder
// discipline: deterministic, idempotent, obviously synthetic,
// device-local (pendingUpsert false everywhere — the sweep must never
// push months of fake history at the dev DB). Personas:
//
//   · weightloss — ~4 months: noisy daily scale movement over a real
//     downward trend, mixed food logging (~70% of days), protein
//     improving, two honest flat weeks mid-record.
//   · glp1 — ~6 months on a weekly injectable with TWO dose
//     increases (0.25 → 0.5 → 1.0): weight responds per era with a
//     late-era stall before the second change, nausea clusters after
//     each increase and fades, food noise returns late in the stalled
//     era, one vacation week with no plates.
//   · sparse — a thin record: six weigh-ins and eight logged days
//     scattered over two months. No basis for sophisticated reads.
//
// Deterministic "noise" comes from a hash fold, never Random — the
// same launch always films the same record.

@MainActor
enum BecomingQASeeder {

    static func seed(variant: String, userId: String, in context: ModelContext) {
        // THE PERSONA IS THE RECORD. This sim is long-lived and every
        // prior pass's seeds stack in the same stores (the E4 "QA
        // cloud pollution" class — filmed here as 3,759 kcal/day from
        // three seeders' plates summing). Wipe the user's food,
        // weigh-ins (sign-up answer kept) and regimen, then seed the
        // persona fresh; deterministic ids make every launch identical.
        FoodLogPersister.deleteAllEntries(userId: userId)
        let w = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.source != "onboarding"
            }
        )
        for row in (try? context.fetch(w)) ?? [] { context.delete(row) }
        let r = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for plan in (try? context.fetch(r)) ?? [] { context.delete(plan) }
        let d = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for event in (try? context.fetch(d)) ?? [] { context.delete(event) }
        try? context.save()

        switch variant {
        case "glp1": seedGlp1(userId: userId, in: context)
        // p79 — the same customer, anchored so TODAY is day 6 of the
        // dose week (span ≡ 5 mod 7 → last slot five days back):
        // the felt-week morning clause can be filmed as she'd meet it.
        case "glp1waning": seedGlp1(userId: userId, in: context, span: 187)
        case "sparse": seedSparse(userId: userId, in: context)
        case "new": break   // the wipe IS the persona: day one
        case "stall": seedStall(userId: userId, in: context)
        // p79 — the learned burn's up-offer customer (below).
        case "fastloss": seedFastloss(userId: userId, in: context)
        default: seedWeightloss(userId: userId, in: context)
        }

        // p79 — A PERSONA OWNS ITS WHOLE BODY. The QA account's
        // device keys rotate with its identity (height swept, cohort
        // stale), so persona walks were nondeterministic: the same
        // launch sometimes had a calorie target and sometimes none
        // (p77 documented the regimen half of this class). Every
        // seeded history now states the body it belongs to.
        if variant != "new" {
            let d = UserDefaults.standard
            let facts: (heightCm: Double, startKg: Double, goalKg: Double,
                        glp1: String) = switch variant {
            case "glp1", "glp1waning": (167.6, 90.7, 72.5, "current")
            case "sparse":             (164.0, 84.2, 75.0, "none")
            case "stall":              (162.5, 80.5, 68.0, "none")
            case "fastloss":           (167.6, 88.0, 74.0, "none")
            default:                   (165.1, 79.4, 66.0, "none")
            }
            d.set(facts.heightCm, forKey: "onboardingHeightCm")
            d.set(facts.startKg, forKey: "onboardingCurrentWeightKg")
            d.set(facts.goalKg, forKey: "onboardingGoalWeightKg")
            d.set("female", forKey: "onboardingGender")
            d.set(34, forKey: "onb_v5_age_years")
            d.set("walks", forKey: "onb_v4_movement_baseline")
            d.set(facts.glp1, forKey: "onboarding_glp1_status")
            d.set("lose", forKey: "onboarding_goal_direction")
        }
    }

    /// p79 — the customer whose record honestly earns the energy
    /// up-offer: logs nearly everything, eats real meals, and loses
    /// faster than the plan's pace — so the weekly read proposes
    /// eating a little more (the direction r1 says adaptive systems
    /// must be able to speak, and the one film can't fake).
    private static func seedFastloss(userId: String, in context: ModelContext) {
        let span = 60
        var points: [(Int, Double)] = []
        for offset in stride(from: span, through: 0, by: -1) {
            guard noise(offset, salt: 2.6) + 0.5 <= 0.8 || offset == 0 else { continue }
            let kg = 88.0 - Double(span - offset) * 0.09
                + noise(offset, salt: 5.2) * 0.35
            points.append((offset, kg))
        }
        seedWeights(points, tag: "fl", userId: userId, in: context)
        seedFood(spanDays: span, keepRate: 0.94, proteinRamp: 0.8,
                 mealsPerDay: 4, richness: 1.18, tag: "fl", userId: userId)
    }

    /// The reassurance state: a real month of loss whose last ~16
    /// days hold flat — the week reads steady, the month is still
    /// down (BecomingStory.steadyContext's exact customer).
    private static func seedStall(userId: String, in context: ModelContext) {
        var points: [(Int, Double)] = []
        for offset in stride(from: 90, through: 0, by: -1) {
            guard noise(offset, salt: 1.3) + 0.5 <= 0.75 || offset == 0 else { continue }
            var kg = 76.2
            if offset >= 16 { kg += Double(offset - 16) * 0.055 }
            kg += noise(offset, salt: 4.1) * 0.5
            points.append((offset, kg))
        }
        seedWeights(points, tag: "st", userId: userId, in: context)
        seedFood(spanDays: 90, keepRate: 0.7, proteinRamp: 0.6,
                 tag: "st", userId: userId)
    }

    // MARK: deterministic noise

    /// [-0.5, 0.5), stable per index — sin-fract, the shader trick.
    private static func noise(_ i: Int, salt: Double = 0) -> Double {
        let v = sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453
        return v - v.rounded(.down) - 0.5
    }

    private static func day(_ offset: Int, cal: Calendar) -> Date {
        cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: .now))
            ?? .now
    }

    private static func at(_ offset: Int, hour: Int, minute: Int, cal: Calendar) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0,
                 of: day(offset, cal: cal)) ?? .now
    }

    // MARK: weight

    /// One weigh-in per kept morning; id is deterministic so re-runs
    /// are no-ops (guarded by the sentinel fetch below).
    private static func seedWeights(
        _ points: [(offset: Int, kg: Double)],
        tag: String, userId: String, in context: ModelContext
    ) {
        let sentinel = "qa-becoming-\(tag)-w0-\(userId.lowercased())"
        var probe = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.id == sentinel }
        )
        probe.fetchLimit = 1
        guard ((try? context.fetch(probe)) ?? []).isEmpty else { return }
        let cal = Calendar.current
        for (i, point) in points.enumerated() {
            let log = WeightLogRecord(
                id: "qa-becoming-\(tag)-w\(i)-\(userId.lowercased())",
                userId: userId,
                weightKg: (point.kg * 10).rounded() / 10,
                loggedAt: at(point.offset, hour: 7, minute: 20 + i % 17, cal: cal),
                source: "qa"
            )
            log.pendingUpsert = false
            context.insert(log)
        }
        try? context.save()
    }

    // MARK: food

    private struct Dish {
        let title: String
        let kcal: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double
        let sugar: Double
        let sodium: Double
    }

    /// A rotating realistic menu — amounts jitter per day so averages
    /// move without any two days matching.
    private static let menu: [Dish] = [
        .init(title: "greek yogurt + berries", kcal: 260, protein: 19, carbs: 28, fat: 7, fiber: 4, sugar: 14, sodium: 90),
        .init(title: "eggs + toast", kcal: 380, protein: 21, carbs: 30, fat: 18, fiber: 3, sugar: 3, sodium: 520),
        .init(title: "chicken salad bowl", kcal: 540, protein: 42, carbs: 31, fat: 26, fiber: 7, sugar: 6, sodium: 620),
        .init(title: "turkey sandwich", kcal: 460, protein: 28, carbs: 46, fat: 16, fiber: 4, sugar: 6, sodium: 890),
        .init(title: "salmon + rice + greens", kcal: 640, protein: 41, carbs: 58, fat: 24, fiber: 5, sugar: 3, sodium: 510),
        .init(title: "beef chili", kcal: 520, protein: 34, carbs: 38, fat: 24, fiber: 9, sugar: 8, sodium: 940),
        .init(title: "protein shake", kcal: 180, protein: 30, carbs: 8, fat: 3, fiber: 1, sugar: 4, sodium: 160),
        .init(title: "cottage cheese + peaches", kcal: 210, protein: 22, carbs: 18, fat: 5, fiber: 2, sugar: 15, sodium: 410),
        .init(title: "pasta with tomatoes", kcal: 580, protein: 18, carbs: 92, fat: 15, fiber: 6, sugar: 11, sodium: 640),
        .init(title: "tofu stir fry", kcal: 430, protein: 24, carbs: 40, fat: 19, fiber: 6, sugar: 9, sodium: 780),
    ]

    /// Seeds plates over `spanDays`, skipping days the hash marks
    /// unlogged (and any offset in `quietDays`). `proteinRamp` lifts
    /// recent protein: 0 = flat, 1 = strong recent improvement.
    private static func seedFood(
        spanDays: Int, keepRate: Double, proteinRamp: Double,
        quietDays: Set<Int> = [],
        // p79 — fastloss levers: a fixed meal count and a portion
        // multiplier (kcal AND macros scale together, so the plates
        // stay internally coherent).
        mealsPerDay: Int? = nil, richness: Double = 1.0,
        tag: String, userId: String
    ) {
        for offset in 0...spanDays {
            if quietDays.contains(offset) { continue }
            // Today stays light (one breakfast) so Home's live day
            // still reads honestly beside the history.
            let logged = noise(offset, salt: 3.7) + 0.5 <= keepRate
            guard logged || offset == 0 else { continue }
            let meals = offset == 0 ? 1
                : (mealsPerDay ?? (noise(offset, salt: 9.1) > 0.15 ? 3 : 2))
            // Recency lifts protein-forward picks: late days lean into
            // the high-protein half of the menu.
            let recency = 1 - Double(offset) / Double(max(1, spanDays))
            for m in 0..<meals {
                let jitter = (1 + noise(offset * 7 + m, salt: 5.5) * 0.22) * richness
                let proteinShift = proteinRamp * recency > 0.35 ? 1 : 0
                let pick = menu[
                    (offset * 3 + m * 2 + proteinShift * 2
                        + Int((noise(offset + m, salt: 2.2) + 0.5) * 4))
                        % menu.count
                ]
                let hour = m == 0 ? 8 : (m == 1 ? 12 : 19)
                FoodLogPersister.debugSeed(
                    id: "qa-becoming-\(tag)-f\(offset)-\(m)-\(userId.lowercased())",
                    userId: userId,
                    loggedAt: at(offset, hour: hour,
                                 minute: 10 + (offset + m) % 40,
                                 cal: Calendar.current),
                    kcal: (pick.kcal * jitter).rounded(),
                    protein: (pick.protein * jitter * (1 + proteinRamp * recency * 0.25)).rounded(),
                    carbs: (pick.carbs * jitter).rounded(),
                    fat: (pick.fat * jitter).rounded(),
                    fiber: (pick.fiber * jitter).rounded(),
                    sugar: (pick.sugar * jitter).rounded(),
                    sodiumMg: (pick.sodium * jitter).rounded(),
                    title: pick.title,
                    source: m == 1 ? "photo" : "words"
                )
            }
        }
    }

    // MARK: persona A — the weight-loss customer, ~4 months

    private static func seedWeightloss(userId: String, in context: ModelContext) {
        let span = 120
        var points: [(Int, Double)] = []
        for offset in stride(from: span, through: 0, by: -1) {
            // ~5 weigh-ins a week.
            guard noise(offset, salt: 1.3) + 0.5 <= 0.72 || offset == 0 else { continue }
            let progressed = Double(span - offset)
            // -0.35 kg/wk baseline; two flat weeks (days 60-46) where
            // the trend honestly holds; scale noise ±0.45 kg.
            var kg = 79.4 - progressed * 0.05
            if offset < 60 && offset >= 46 { kg += Double(60 - offset) * 0.05 * 0.9 }
            kg += noise(offset, salt: 4.9) * 0.9
            points.append((offset, kg))
        }
        seedWeights(points, tag: "wl", userId: userId, in: context)
        seedFood(spanDays: span, keepRate: 0.7, proteinRamp: 1.0,
                 tag: "wl", userId: userId)
    }

    // MARK: persona B — the GLP-1 customer, ~6 months, two increases

    private static func seedGlp1(
        userId: String, in context: ModelContext, span: Int = 183
    ) {
        let cal = Calendar.current
        let eraTwoStart = 127   // 0.5 mg began (days ago)
        let eraThreeStart = 57  // 1.0 mg began (days ago)

        // The regimen chain, through the real chokepoint.
        if RegimenService.activeSelfMedicationPlan(userId: userId, in: context) == nil {
            var spec = RegimenService.SelfRegimenSpec()
            spec.productId = "wegovy"
            spec.displayName = "wegovy"
            spec.route = "injection"
            spec.scheduleRule = "weeklyAnchor"
            spec.anchorWeekday = RegimenService.isoWeekday(day(span, cal: cal))
            spec.timeOfDayMinutes = 18 * 60
            spec.doseValue = 0.25
            spec.reminderEnabled = true
            let v1 = RegimenService.applySelfRegimen(
                spec, userId: userId, now: day(span, cal: cal), in: context
            )
            spec.doseValue = 0.5
            let v2 = RegimenService.applySelfRegimen(
                spec, userId: userId, now: day(eraTwoStart, cal: cal), in: context
            )
            spec.doseValue = 1.0
            let v3 = RegimenService.applySelfRegimen(
                spec, userId: userId, now: day(eraThreeStart, cal: cal), in: context
            )

            // Dose events on the engine's own slots — taken but two
            // travel skips; the current week's slot stays live.
            if let v3 {
                let facts = RegimenService.facts(for: v3)
                let slots = MedicationScheduleEngine.slotDays(
                    through: day(1, cal: cal), lookbackDays: span + 7, facts: facts
                )
                for (i, slotDay) in slots.enumerated() {
                    let offset = cal.dateComponents(
                        [.day], from: cal.startOfDay(for: slotDay),
                        to: cal.startOfDay(for: .now)
                    ).day ?? 0
                    let plan: RegimenPlanRecord? =
                        offset > eraTwoStart ? v1 :
                        offset > eraThreeStart ? v2 : v3
                    guard let plan else { continue }
                    let skipped = i == 6 || i == 17
                    _ = DoseEventStore.upsert(
                        dayKey: MedicationScheduleEngine.dayKey(for: slotDay),
                        scheduledAt: MedicationScheduleEngine.scheduledAt(
                            onDay: slotDay, facts: facts
                        ),
                        status: skipped ? "skipped" : "taken",
                        takenAt: skipped ? nil : MedicationScheduleEngine.scheduledAt(
                            onDay: slotDay, facts: facts
                        ),
                        site: skipped ? nil : InjectionSite.allCases[i % InjectionSite.allCases.count],
                        skipReason: skipped ? "traveling" : nil,
                        source: "sheet", userId: userId, regimenPlanId: plan.id,
                        in: context, sync: false
                    )
                }
            }
        }

        // Weight: era 1 responds (-0.45/wk), era 2 responds then
        // STALLS its last three weeks, era 3 resumes (-0.5/wk).
        var points: [(Int, Double)] = []
        for offset in stride(from: span, through: 0, by: -1) {
            guard noise(offset, salt: 8.8) + 0.5 <= 0.62 || offset == 0 else { continue }
            var kg = 90.7
            let d1 = Double(min(span - eraTwoStart, span - offset))
            kg -= d1 * (0.45 / 7)
            if offset < eraTwoStart {
                let d2 = Double(min(eraTwoStart - eraThreeStart, eraTwoStart - offset))
                let stallStart = 78.0   // last ~3 weeks of era 2 hold
                kg -= min(d2, stallStart - Double(eraThreeStart)) * (0.35 / 7)
            }
            if offset < eraThreeStart {
                let d3 = Double(eraThreeStart - offset)
                kg -= d3 * (0.5 / 7)
            }
            kg += noise(offset, salt: 6.1) * 0.8
            points.append((offset, kg))
        }
        seedWeights(points, tag: "g1", userId: userId, in: context)

        // Symptoms: nausea clusters after each INCREASE and fades;
        // food noise returns across the stalled weeks; one stray
        // headache. Runs every launch (the QA wipe clears
        // observations at startup); ids are deterministic per day.
        for start in [eraTwoStart, eraThreeStart] {
            for (i, lag) in [1, 3, 8, 12].enumerated() {
                _ = SideEffectLog.record(
                    .nausea,
                    severity: i < 2 ? .noticeable : .aTouch,
                    dayKey: MedicationScheduleEngine.dayKey(
                        for: day(start - lag, cal: cal)
                    ),
                    userId: userId, in: context
                )
            }
        }
        for lag in [62, 66, 71] {
            _ = SideEffectLog.record(
                .foodNoise, severity: .noticeable,
                dayKey: MedicationScheduleEngine.dayKey(for: day(lag, cal: cal)),
                userId: userId, in: context
            )
        }
        _ = SideEffectLog.record(
            .headache, severity: .aTouch,
            dayKey: MedicationScheduleEngine.dayKey(for: day(100, cal: cal)),
            userId: userId, in: context
        )

        // Food: six months, one silent vacation week; protein improves.
        seedFood(
            spanDays: span, keepRate: 0.68, proteinRamp: 0.8,
            quietDays: Set(29...35), tag: "g1", userId: userId
        )

        // Device-local, always.
        let d = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for event in (try? context.fetch(d)) ?? [] { event.pendingUpsert = false }
        let r = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for plan in (try? context.fetch(r)) ?? [] { plan.pendingUpsert = false }
        let o = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for record in (try? context.fetch(o)) ?? [] { record.pendingUpsert = false }
        try? context.save()
    }

    // MARK: persona C — the sparse customer

    private static func seedSparse(userId: String, in context: ModelContext) {
        var points: [(Int, Double)] = []
        for offset in [58, 44, 37, 21, 9, 2] {
            points.append((offset, 84.2 - Double(58 - offset) * 0.03
                + noise(offset, salt: 7.7) * 0.7))
        }
        seedWeights(points, tag: "sp", userId: userId, in: context)
        for offset in [55, 49, 40, 33, 26, 14, 6, 1] {
            let pick = menu[offset % menu.count]
            FoodLogPersister.debugSeed(
                id: "qa-becoming-sp-f\(offset)-\(userId.lowercased())",
                userId: userId,
                loggedAt: at(offset, hour: 12, minute: 30, cal: Calendar.current),
                kcal: pick.kcal, protein: pick.protein, carbs: pick.carbs,
                fat: pick.fat, fiber: pick.fiber, sugar: pick.sugar,
                sodiumMg: pick.sodium, title: pick.title, source: "words"
            )
        }
    }
}
#endif
