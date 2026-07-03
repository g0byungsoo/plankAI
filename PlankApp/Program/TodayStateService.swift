import Foundation
import SwiftData
import PlankFood
import PlankSync

// MARK: - TodayStateService
//
// App v2 (docs/app_v2/06_DATA_SUPABASE.md §F). ONE snapshot of "her
// day right now" that Today, the brief engine, and the chat context
// assembler all read — before v2, three near-identical "today's
// food" tiles each re-derived this from different sources.
//
// Stateless by design: `snapshot(userId:in:)` performs the reads and
// returns a value. Views own refresh timing (onAppear + the food
// changeNotifier + steps observation); chat assembles a fresh one
// per turn. No caching layer to go stale.

struct TodaySnapshot {
    // program
    let plan: ProgramPlanRecord?
    let programDay: Int
    let totalDays: Int
    let day: PrescriptionEngineV2.Day?
    /// itemKey → state ("empty"/"complete"/"skipped"/"autoCompleted")
    let checkStates: [String: String]

    // food
    let kcalEaten: Int
    let proteinEatenG: Int
    let plates: [FoodLogPersister.FoodLogEntry]

    // movement
    let steps: Int

    // weight
    let latestWeightKg: Double?
    let emaDelta7dKg: Double?
    let lastWeighInDaysAgo: Int?

    // targets
    let targets: TargetsService.Targets

    // narrative
    let brief: DailyBriefEngine.Brief
    let daysSinceLastOpen: Int

    var isEnrolled: Bool { plan != nil }

    /// Completion fraction over binary beats (steps auto-tracks live
    /// and weigh-in counts when done) — drives the day receipt.
    var completedBeatCount: Int {
        guard let day else { return 0 }
        return day.beats.filter { beat in
            let s = checkStates[beat.itemKey] ?? "empty"
            return s == "complete" || s == "autoCompleted"
        }.count
    }
}

enum TodayStateService {

    /// Day key in the user's local calendar ("2026-07-03").
    static func dayKey(for date: Date = .now) -> String {
        let f = DateFormatter()
        f.calendar = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    @MainActor
    static func snapshot(userId: String, in context: ModelContext) -> TodaySnapshot {
        let plan = ProgramService.shared.activePlan(userId: userId, in: context)

        // — program day + beats
        var programDay = 0
        var totalDays = 0
        var day: PrescriptionEngineV2.Day?
        var checkStates: [String: String] = [:]

        // — weight
        let weightLogs = fetchWeightLogs(userId: userId, in: context)
        let latestKg = weightLogs.first?.weightKg
        let lastWeighDaysAgo: Int? = weightLogs.first.map {
            Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: $0.loggedAt),
                to: Calendar.current.startOfDay(for: .now)
            ).day ?? 0
        }
        let ema = WeightTrendChart.computeEMA(logs: weightLogs)
        let emaDelta = emaDelta7d(ema)

        if let plan {
            let schedule = ProgramScheduleCalculator.compute(
                ProgramScheduleCalculator.Inputs(
                    startDate: plan.startDate,
                    totalDays: plan.totalDays
                )
            )
            programDay = schedule.programDay
            totalDays = plan.totalDays

            let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium
            let profile = IntensityProfile.from(tier: tier)
            day = PrescriptionEngineV2.compose(
                programDay: programDay,
                totalDays: plan.totalDays,
                profile: profile,
                context: .live(
                    lastWeighInDaysAgo: lastWeighDaysAgo,
                    lastSnapDaysAgo: nil
                )
            )
            checkStates = fetchCheckStates(
                userId: userId, planId: plan.id, programDay: programDay, in: context
            )
        }

        // — food (device-local store)
        let macros = FoodLogPersister.todayMacros()
        let todayStart = Calendar.current.startOfDay(for: .now)
        let plates = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= todayStart }
            .sorted { $0.loggedAt < $1.loggedAt }

        // — targets
        let targets = TargetsService.current(userId: userId, in: context)

        // — return-gap tracking (the brief's comeback thread)
        let gap = consumeOpenGap()

        // — brief
        let d = UserDefaults.standard
        let promiseKept = programDay <= 2
            && !(d.string(forKey: "day1PromiseAction") ?? "").isEmpty
            && !plates.isEmpty
        let brief = DailyBriefEngine.brief(for: .init(
            name: d.string(forKey: "userName"),
            programDay: programDay,
            archetype: day?.archetype ?? .balanced,
            isWeighInDay: day?.beats.contains(where: {
                if case .weighIn = $0 { return true } else { return false }
            }) ?? false,
            weighInIsStaleFallback: day?.weighInIsStaleFallback ?? false,
            emaDelta7dKg: emaDelta,
            lossRatePctPerWeek: sustainedLossRate(ema: ema, weightKg: latestKg),
            showedUpCount: d.integer(forKey: "stats.shown_up_count"),
            daysSinceLastOpen: gap,
            promiseJustKept: promiseKept,
            proteinTargetG: targets.proteinG,
            maintenanceMode: CohortStore.isMaintenanceMode,
            glp1Cohort: CohortStore.glp1Cohort,
            dayKey: dayKey()
        ))

        return TodaySnapshot(
            plan: plan,
            programDay: programDay,
            totalDays: totalDays,
            day: day,
            checkStates: checkStates,
            kcalEaten: Int(macros.kcal.rounded()),
            proteinEatenG: Int(macros.protein.rounded()),
            plates: plates,
            steps: StepsService.shared.todayCount,
            latestWeightKg: latestKg,
            emaDelta7dKg: emaDelta,
            lastWeighInDaysAgo: lastWeighDaysAgo,
            targets: targets,
            brief: brief,
            daysSinceLastOpen: gap
        )
    }

    // MARK: - Fetches

    @MainActor
    private static func fetchWeightLogs(userId: String, in context: ModelContext) -> [WeightLogRecord] {
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func fetchCheckStates(
        userId: String, planId: String, programDay: Int, in context: ModelContext
    ) -> [String: String] {
        let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate {
                $0.userId == userId
                && $0.programPlanId == planId
                && $0.programDay == programDay
            }
        )
        let checks = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: checks.map { ($0.itemKey, $0.state) })
    }

    // MARK: - Derived metrics

    /// 7-day EMA delta (today's EMA minus the EMA 7 points back).
    static func emaDelta7d(_ ema: [WeightTrendChart.EMAPoint]) -> Double? {
        guard ema.count >= 8 else { return nil }
        let latest = ema[ema.count - 1].emaKg
        let prior = ema[ema.count - 8].emaKg
        return latest - prior
    }

    /// Sustained loss rate as %/wk from the EMA (14-point span so a
    /// single sharp week doesn't trip the care line alone). nil when
    /// the series is too short. Positive value = losing.
    static func sustainedLossRate(ema: [WeightTrendChart.EMAPoint], weightKg: Double?) -> Double? {
        guard ema.count >= 15, let weightKg, weightKg > 30 else { return nil }
        let latest = ema[ema.count - 1].emaKg
        let prior = ema[ema.count - 15].emaKg
        let lostKg = prior - latest
        guard lostKg > 0 else { return nil }
        return (lostKg / 2.0) / weightKg   // per-week fraction
    }

    // MARK: - Open-gap tracking

    /// Reads + updates the "last open day" marker. Returns the number
    /// of calendar days since the previous open (0 = same day). The
    /// marker updates at most once per snapshot day so multiple
    /// snapshots within a day report the same gap.
    static func consumeOpenGap(_ d: UserDefaults = .standard, now: Date = .now) -> Int {
        let todayKey = dayKey(for: now)
        let lastKey = d.string(forKey: "app.lastOpenDayKey")
        let gapAtFirstOpen = d.integer(forKey: "app.todayOpenGap")

        if lastKey == todayKey {
            return gapAtFirstOpen
        }

        var gap = 0
        if let lastKey {
            let f = DateFormatter()
            f.calendar = .current
            f.dateFormat = "yyyy-MM-dd"
            if let lastDate = f.date(from: lastKey) {
                gap = Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: lastDate),
                    to: Calendar.current.startOfDay(for: now)
                ).day ?? 0
            }
        }
        d.set(todayKey, forKey: "app.lastOpenDayKey")
        d.set(gap, forKey: "app.todayOpenGap")
        return gap
    }
}
