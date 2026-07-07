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
    /// programDay → completed-check count for the strip's visible
    /// window (today ±10 days) — the day strip reads this.
    let completionWindow: [Int: Int]

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

    // v3 spine
    let chapter: Chapter
    let isOnBreak: Bool
    /// Keeping chapter: today's band zone (BandZone.rawValue); nil
    /// outside the chapter or before a settle weight exists.
    let bandZone: String?

    // v4 arc (docs/app_v4/01_PROGRAM.md) — the program as an object.
    let programWeek: Int
    let totalWeeks: Int
    let arcPhase: ArcPhase?
    let weekIntent: WeekIntentSpec?
    /// Masthead lead ("12 kept" / "44 to go") — presence early,
    /// distance past the midpoint.
    let arcLead: String?

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
        // v3 presence self-heal (one-time, flag-guarded): adopt the
        // any-action definition of shown-up days for existing users.
        PresenceLedger.migrateIfNeeded(userId: userId, in: context)

        let plan = ProgramService.shared.activePlan(userId: userId, in: context)

        // — program day + beats
        var programDay = 0
        var totalDays = 0
        var day: PrescriptionEngineV2.Day?
        var checkStates: [String: String] = [:]
        var completionWindow: [Int: Int] = [:]

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
            completionWindow = fetchCompletionWindow(
                userId: userId, planId: plan.id, around: programDay, in: context
            )
        }

        // — food (device-local store)
        let macros = FoodLogPersister.todayMacros(userId: userId)
        let todayStart = Calendar.current.startOfDay(for: .now)
        let plates = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= todayStart }
            .sorted { $0.loggedAt < $1.loggedAt }

        // — targets
        let targets = TargetsService.current(userId: userId, in: context)

        // — return-gap tracking (the brief's comeback thread)
        let gap = consumeOpenGap()

        // — band zone (keeping chapter; the same value feeds the
        //   reading, the chat envelope, and — later — notifications)
        let bandZone: String? = {
            guard CohortStore.chapter == .keeping,
                  let settle = BandModel.settleWeightKg(plan: plan),
                  let emaLatest = ema.last?.emaKg
            else { return nil }
            return BandModel.zone(emaKg: emaLatest, settleKg: settle).rawValue
        }()

        // — trailing-7 food days (the reading's mechanism provenance;
        //   same thresholds as InsightEngine.WeekState)
        var loggedDays7 = 0
        var proteinDays7 = 0
        if let target = targets.proteinG {
            var proteinByDay: [String: Double] = [:]
            let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
            for entry in FoodLogPersister.allEntries(userId: userId)
            where entry.loggedAt >= weekStart {
                proteinByDay[dayKey(for: entry.loggedAt), default: 0] += entry.protein
            }
            loggedDays7 = proteinByDay.count
            proteinDays7 = proteinByDay.values.filter { $0 >= Double(target) }.count
        }

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
            yesterdayStepsHitGoal: {
                let weekly = StepsService.shared.weeklyCounts
                guard weekly.count >= 2 else { return false }
                return weekly[weekly.count - 2] >= targets.steps
            }(),
            maintenanceMode: CohortStore.isMaintenanceMode,
            glp1Cohort: CohortStore.glp1Cohort,
            dayKey: dayKey(),
            chapter: CohortStore.chapter,
            isOnBreak: BreakState.isActive,
            loggedDays7: loggedDays7,
            proteinDays7: proteinDays7,
            weekday: Calendar.current.component(.weekday, from: .now),
            bandZone: bandZone,
            yesterdaySat: {
                guard let yesterday = Calendar.current.date(
                    byAdding: .day, value: -1, to: .now
                ) else { return nil }
                return d.string(forKey: "day.sit.\(dayKey(for: yesterday))")
            }(),
            overnightQuietHours: QuietHours.liveOvernight(userId: userId)
        ))

        // — the arc (v4): phase + week intent, derived, provenance-only
        let chapter = CohortStore.chapter
        var programWeek = 0
        var totalWeeks = 0
        var arcPhase: ArcPhase?
        var weekIntent: WeekIntentSpec?
        var arcLead: String?
        if plan != nil, programDay >= 1 {
            programWeek = PrescriptionEngineV2.programWeek(programDay)
            totalWeeks = ProgramArc.totalWeeks(totalDays: totalDays)
            let phase = ProgramArc.phase(
                week: programWeek,
                totalWeeks: totalWeeks,
                chapter: chapter,
                emaFlatWeeks: emaFlatWeeks(ema)
            )
            arcPhase = phase
            weekIntent = WeekIntent.intent(
                week: programWeek,
                chapter: chapter,
                phase: phase,
                flags: .live,
                zone: bandZone.flatMap(BandZone.init(rawValue:)),
                pickedKey: d.string(
                    forKey: WeeklyReview.intentPickKey(week: programWeek))
            )
            arcLead = ProgramArc.leadLine(
                programDay: programDay,
                totalDays: totalDays,
                chapter: chapter,
                keptDays: PresenceLedger.keptDays
            )
        }

        return TodaySnapshot(
            plan: plan,
            programDay: programDay,
            totalDays: totalDays,
            day: day,
            checkStates: checkStates,
            completionWindow: completionWindow,
            kcalEaten: Int(macros.kcal.rounded()),
            proteinEatenG: Int(macros.protein.rounded()),
            plates: plates,
            steps: StepsService.shared.todayCount,
            latestWeightKg: latestKg,
            emaDelta7dKg: emaDelta,
            lastWeighInDaysAgo: lastWeighDaysAgo,
            targets: targets,
            brief: brief,
            daysSinceLastOpen: gap,
            chapter: chapter,
            isOnBreak: BreakState.isActive,
            bandZone: bandZone,
            programWeek: programWeek,
            totalWeeks: totalWeeks,
            arcPhase: arcPhase,
            weekIntent: weekIntent,
            arcLead: arcLead
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

    /// Completed-check counts for the strip window (±10 days around
    /// today) — bounded, unlike the v1 all-days hydrate.
    @MainActor
    private static func fetchCompletionWindow(
        userId: String, planId: String, around programDay: Int, in context: ModelContext
    ) -> [Int: Int] {
        let lo = programDay - 10, hi = programDay + 10
        let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate {
                $0.userId == userId
                && $0.programPlanId == planId
                && $0.programDay >= lo
                && $0.programDay <= hi
            }
        )
        let checks = (try? context.fetch(descriptor)) ?? []
        var counts: [Int: Int] = [:]
        for check in checks where check.state == "complete" || check.state == "autoCompleted" {
            counts[check.programDay, default: 0] += 1
        }
        return counts
    }

    // MARK: - Derived metrics

    /// 7-day EMA delta (today's EMA minus the EMA 7 points back).
    static func emaDelta7d(_ ema: [WeightTrendChart.EMAPoint]) -> Double? {
        guard ema.count >= 8 else { return nil }
        let latest = ema[ema.count - 1].emaKg
        let prior = ema[ema.count - 8].emaKg
        return latest - prior
    }

    /// Weeks the EMA has run flat (≥3 triggers the arc's data-bend —
    /// the plateau named early, as support). "Flat" = the EMA moved
    /// less than 0.15 kg over each trailing 7-point span; counts up
    /// to 3 (the overlay's threshold; more adds nothing).
    static func emaFlatWeeks(_ ema: [WeightTrendChart.EMAPoint]) -> Int {
        var weeks = 0
        var end = ema.count - 1
        while weeks < 3, end - 7 >= 0 {
            let delta = abs(ema[end].emaKg - ema[end - 7].emaKg)
            guard delta < 0.15 else { break }
            weeks += 1
            end -= 7
        }
        return weeks
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
