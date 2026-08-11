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
    /// v7 — the day recomposed from state (docs/app_v7 §4): tone,
    /// lead, supporting, offered. Today's receipt counts THESE
    /// beats, not the prescription's slot output.
    let carePlan: CarePlanEngine.Plan
    /// itemKey → state ("empty"/"complete"/"skipped"/"autoCompleted")
    let checkStates: [String: String]
    /// programDay → completed-check count for the strip's visible
    /// window (today ±10 days) — the day strip reads this.
    let completionWindow: [Int: Int]

    // food
    let kcalEaten: Int
    let proteinEatenG: Int
    /// v5 nutrition visibility: the rest of the plate chemistry the
    /// pipeline already stores (vision + edits persist these; only
    /// protein/kcal ever surfaced before).
    var carbsEatenG: Int = 0
    var fatEatenG: Int = 0
    var fiberEatenG: Int = 0
    /// v1.1.5 — today's sugar; 0 (silent) when no plate carried a value.
    var sugarEatenG: Int = 0
    let plates: [FoodLogPersister.FoodLogEntry]

    // movement
    let steps: Int

    // weight
    let latestWeightKg: Double?
    let emaDelta7dKg: Double?
    let lastWeighInDaysAgo: Int?
    /// v9 P2 — the v5 trust floor, surfaced (BodyStateService).
    var trendIsEstablished: Bool = false

    // targets
    let targets: TargetsService.Targets

    // narrative
    let brief: DailyBriefEngine.Brief
    let daysSinceLastOpen: Int

    // v24 — the regimen's shape reaches the surfaces (row nouns,
    // sheet vocabulary). Defaults keep old constructors compiling.
    var doseCadenceIsDaily: Bool = false
    var doseRouteIsOral: Bool = false
    // v25 E2 — the view layer can finally reason about the cycle:
    // today's dose-day flag, her cycle position (1…7 weekly, honest
    // positions only), and the open late slot's dayKey (the dose
    // row's tap + the evening ask route to THE SLOT, never blindly
    // to today).
    var isDoseDay: Bool = false
    var dayInDoseWeek: Int? = nil
    var openLateSlotDayKey: String? = nil
    /// An active regimen exists (the evening ask's pre-anchor
    /// window keys off its absence).
    var hasMedicationRegimen: Bool = false

    /// v25 E2 — the evening "medication day?" ask renders only when
    /// a dose is actually in play tonight: a daily cadence, a weekly
    /// dose day, an open late slot, or the pre-regimen window (the
    /// v8 shot-day anchor still needs its collection moment). A
    /// weekly injector's other five evenings stay quiet.
    var eveningDoseAskRelevant: Bool {
        Self.eveningDoseAskRelevant(
            cadenceIsDaily: doseCadenceIsDaily,
            isDoseDay: isDoseDay,
            openLateSlotDayKey: openLateSlotDayKey,
            hasRegimen: hasMedicationRegimen
        )
    }

    /// Pure form (unit-pinned; the sim's anon-auth identity races
    /// make multi-launch film proofs unreliable — the law lives here).
    static func eveningDoseAskRelevant(
        cadenceIsDaily: Bool, isDoseDay: Bool,
        openLateSlotDayKey: String?, hasRegimen: Bool
    ) -> Bool {
        cadenceIsDaily || isDoseDay
            || openLateSlotDayKey != nil || !hasRegimen
    }

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

    var isEnrolled: Bool { plan != nil }

    /// Completion over TODAY'S CARE PLAN (v7): the lead + supporting
    /// moves are the day's asks; offered rows and observations are
    /// never debt, so they never count.
    var completedBeatCount: Int {
        carePlan.actionableBeats.filter { beat in
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

        // — weight (v9 P0: ONE aggregate; equivalence pinned by
        //   BodyStateServiceTests + the full suite)
        let body = BodyStateService.current(userId: userId, in: context)
        let latestKg = body.weight?.latestKg
        let lastWeighDaysAgo = body.weight?.lastWeighInDaysAgo
        let ema = body.weight?.emaSeries ?? []
        let emaDelta = body.weight?.emaDelta7dKg

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
                ),
                careProtocol: CareProtocolStore.current
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
        // v7 — yesterday's close reaches the morning (docs/app_v7
        // §3): the feeling chip she gave the evening close, and
        // yesterday's protein when yesterday was a real logged day
        // (2+ plates — an unlogged day is absence, not deficit).
        let yesterdayFeeling: String? = Calendar.current.date(
            byAdding: .day, value: -1, to: .now
        ).flatMap { yesterday in
            let key = dayKey(for: yesterday)
            // v8 — the chart reads first; the legacy string covers
            // pre-backfill cold starts (graceful, never both-nil
            // when either holds an answer).
            return ObservationStore.valueText(
                .feeling, dayKey: key, userId: userId, in: context
            ) ?? d.string(forKey: "day.reflection.\(key)")
        }
        // v25 E4 — yesterday's plates, computed once: the RECEIPT sums
        // from the first plate (a receipt states what's on file); the
        // PROMOTION gate keeps its ≥2-plate floor (a judgment needs
        // more — an unlogged day is absence, not deficit).
        let yesterdayEntries: [FoodLogPersister.FoodLogEntry] = {
            guard let yesterday = Calendar.current.date(
                byAdding: .day, value: -1, to: todayStart
            ) else { return [] }
            return FoodLogPersister.allEntries(userId: userId)
                .filter { $0.loggedAt >= yesterday && $0.loggedAt < todayStart }
        }()
        let yesterdayProteinG: Int? = yesterdayEntries.count >= 2
            ? Int(yesterdayEntries.reduce(0) { $0 + $1.protein }.rounded())
            : nil
        let yesterdayReceiptProteinG: Int? = yesterdayEntries.isEmpty
            ? nil
            : Int(yesterdayEntries.reduce(0) { $0 + $1.protein }.rounded())
        let yesterdayReceiptKcal: Int? = yesterdayEntries.isEmpty
            ? nil
            : Int(yesterdayEntries.reduce(0) { $0 + $1.kcal }.rounded())
        // Manual weigh-ins only — the onboarding seed is not a morning
        // she gave the product (L5: the first REAL weigh-in must be
        // acknowledged the next day, honestly).
        let manualWeighIns: [Date] = {
            let descriptor = FetchDescriptor<WeightLogRecord>(
                predicate: #Predicate {
                    $0.userId == userId && $0.source != "onboarding"
                }
            )
            return ((try? context.fetch(descriptor)) ?? []).map(\.loggedAt)
        }()
        let yesterdayWeighedIn = manualWeighIns.contains {
            guard let yesterday = Calendar.current.date(
                byAdding: .day, value: -1, to: todayStart
            ) else { return false }
            return $0 >= yesterday && $0 < todayStart
        }
        // v7 phase 3 — the letter's memory. The watched fact: steps
        // that accrued during a 4-13 day away stretch (3+ real days
        // or silence). And the once-ever first down week, keyed by
        // the day it fired so the line holds all day, then retires.
        let gapStepsDailyAvg: Int? = {
            guard gap >= 4, gap <= 13 else { return nil }
            let counts = StepsService.shared.weeklyCounts.filter { $0 > 0 }
            guard counts.count >= 3 else { return nil }
            return counts.reduce(0, +) / counts.count
        }()

        // The once-ever first down week (day-keyed so the letter and
        // the celebration hold all day, then retire) — shared by the
        // brief and the closing acts.
        var firstDownWeek = false

        // v5 trust floor, shared by the brief and the care plan
        // (v9 P0: the floor lives in BodyStateService.weightRead).
        let trendEstablished = body.weight?.trendEstablished ?? false

        firstDownWeek = {
            let key = "wins.firstDownWeek.dayKey"
            let today = dayKey()
            if let seen = d.string(forKey: key) { return seen == today }
            guard trendEstablished, let delta = emaDelta, delta <= -0.2
            else { return false }
            d.set(today, forKey: key)
            return true
        }()
        // v4 — the named week reaches the reading ONLY on its opening
        // day (the fresh-page moment); other days the ribbon carries it.
        let briefWeekIntent: WeekIntentSpec? = {
            guard plan != nil, programDay >= 1,
                  PrescriptionEngineV2.dayInWeek(programDay) == 0
            else { return nil }
            let week = PrescriptionEngineV2.programWeek(programDay)
            let chapter = CohortStore.chapter
            return WeekIntent.intent(
                week: week,
                chapter: chapter,
                phase: ProgramArc.phase(
                    week: week,
                    totalWeeks: ProgramArc.totalWeeks(totalDays: totalDays),
                    chapter: chapter,
                    emaFlatWeeks: emaFlatWeeks(ema)
                ),
                flags: .live,
                zone: bandZone.flatMap(BandZone.init(rawValue:)),
                pickedKey: d.string(forKey: WeeklyReview.intentPickKey(week: week))
            )
        }()
        // v25 E4 (L1 fix): the letter presents before she logs, so
        // day-2 morning must read YESTERDAY's plates — the promise
        // was kept the moment any plate landed in the first two days.
        let promiseKept = programDay <= 2
            && !(d.string(forKey: "day1PromiseAction") ?? "").isEmpty
            && (!plates.isEmpty || !yesterdayEntries.isEmpty)
        let brief = DailyBriefEngine.brief(for: .init(
            name: d.string(forKey: "userName"),
            programDay: programDay,
            archetype: day?.archetype ?? .balanced,
            isWeighInDay: day?.beats.contains(where: {
                if case .weighIn = $0 { return true } else { return false }
            }) ?? false,
            weighInIsStaleFallback: day?.weighInIsStaleFallback ?? false,
            emaDelta7dKg: emaDelta,
            trendIsEstablished: trendEstablished,
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
                let key = dayKey(for: yesterday)
                return ObservationStore.valueText(
                    .sitCheck, dayKey: key, userId: userId, in: context
                ) ?? d.string(forKey: "day.sit.\(key)")
            }(),
            overnightQuietHours: QuietHours.liveOvernight(userId: userId),
            lastNightPlan: {
                guard let yesterday = Calendar.current.date(
                    byAdding: .day, value: -1, to: .now
                ) else { return nil }
                return TonightPlan.planned(dayKey: dayKey(for: yesterday))?.label
            }(),
            weekOpensName: briefWeekIntent?.name,
            weekOpensLine: briefWeekIntent?.line,
            weekOrdinal: programDay >= 1 ? PrescriptionEngineV2.programWeek(programDay) : 0,
            // v6.2 — the passive layer reaches the reading. Sleep is
            // the cached last-night read; the season phase is passed
            // only when it may speak (luteal/menstrual, cycle data
            // present, never perimenopausal).
            sleepHoursLastNight: SleepService.shared.lastNight
                .map { $0.asleepDuration / 3600 },
            seasonPhase: {
                guard !CohortStore.isPerimenopausal,
                      let read = CycleSignal.read(
                          periodStarts: CycleService.shared.periodStarts
                      )
                else { return nil }
                switch read.phase {
                case .luteal: return "luteal"
                case .menstrual: return "menstrual"
                case .follicular: return nil
                }
            }(),
            gapStepsDailyAvg: gapStepsDailyAvg,
            isFirstDownWeekEver: firstDownWeek,
            yesterdayFeeling: yesterdayFeeling,
            // v25 E4 — DAY TWO: yesterday reaches the morning.
            yesterdayPlateCount: yesterdayEntries.count,
            yesterdayProteinG: yesterdayReceiptProteinG,
            yesterdayKcal: yesterdayReceiptKcal,
            yesterdayWeighedIn: yesterdayWeighedIn,
            yesterdayKeptBeats: completionWindow[programDay - 1] ?? 0,
            weighInCount: manualWeighIns.count,
            numericSuppressed: CohortStore.isNumericSuppressed
        ))

        // — the arc (v4): phase + week intent, derived, provenance-only
        let chapter = CohortStore.chapter
        var programWeek = 0
        var totalWeeks = 0
        var arcPhase: ArcPhase?
        var weekIntent: WeekIntentSpec?
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
        }

        // — v8: her regimen (docs/app_v8/03_ARCHITECTURE.md §3c;
        //   v24 §4) — the schedule engine answers dose-day for
        //   EVERY cadence (weekly anchor, daily pill, daily
        //   injectable). Absent plan = absent fields (provenance).
        let medicationPlan = RegimenService.activeMedicationPlan(
            userId: userId, in: context
        )
        let medicationFacts = medicationPlan.map(RegimenService.facts(for:))
        let isDoseDay = medicationFacts.map {
            MedicationScheduleEngine.isDoseDay(.now, facts: $0)
        } ?? false
        let doseCadenceIsDaily = medicationFacts?.scheduleRule == "daily"
        let doseRouteIsOral = medicationFacts?.isOral ?? false
        let titrationActive = RegimenService.titrationWindowActive(
            .now, startedAt: medicationPlan?.startedAt,
            careProtocol: CareProtocolStore.current
        )
        // v25 E2 — the cycle position + the open late slot (weekly
        // injectors only; both nil for every other user by
        // construction). One slot-event fetch feeds both.
        var dayInDoseWeek: Int? = nil
        var openLateSlotDayKey: String? = nil
        var openLateSlotWeekday: String? = nil
        if let medicationFacts, medicationFacts.scheduleRule == "weeklyAnchor" {
            let slotEvents = DoseEventStore.slotEvents(
                userId: userId, limit: 30, in: context
            )
            dayInDoseWeek = MedicationScheduleEngine.cyclePosition(
                now: .now, facts: medicationFacts, events: slotEvents
            )?.day
            if let openSlot = MedicationScheduleEngine.openLateSlot(
                now: .now, facts: medicationFacts, events: slotEvents
            ) {
                openLateSlotDayKey = MedicationScheduleEngine.dayKey(for: openSlot)
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = "EEEE"
                openLateSlotWeekday = f.string(from: openSlot).lowercased()
            }
        }

        // — v9 P4: the body-outcome axis reaches the daily lead
        //   (the P3 preservation ladder's daily echo + the plateau
        //   week as support).
        let preservationAtRisk: Bool = {
            var p = WeeklyBodyReview.Input()
            p.loggedDays7 = loggedDays7
            p.proteinDaysMet7 = proteinDays7
            p.strengthSessions7 = MovementService.shared.everRequested
                ? MovementService.shared.strengthSessionsLast7 : nil
            let active = StepsService.shared.weeklyCounts.filter { $0 > 0 }.count
            p.stepsActiveDays7 = active > 0 ? active : nil
            p.lossRatePctPerWeek = body.weight?.weeklyLossRate
            return WeeklyBodyReview.preservation(p)?.state == .atRisk
        }()
        let isPlateauWeek = body.weight?.isStalled ?? false

        // — v9 P1: the weekly scan invitation (offered, never debt).
        //   Anchored to the weekday she actually scans; Sunday until
        //   a first scan exists; silent once today's scan is kept.
        let scans = BodyScanStore.all(userId: userId, in: context)
        let hasAnyScan = !scans.isEmpty
        let isScanDay: Bool = {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitest-force-scan-day") {
                return true
            }
            #endif
            let todayKey = dayKey()
            guard !scans.contains(where: { $0.dayKey == todayKey }) else { return false }
            let todayWeekday = Calendar.current.component(.weekday, from: .now)
            let anchor = BodyScanStore.anchorWeekday(userId: userId, in: context) ?? 1
            return todayWeekday == anchor   // Calendar weekday 1 = Sunday
        }()

        // — v7: the care plan (docs/app_v7/00_THESIS.md §4). The
        //   day recomposed from state; today's receipt arithmetic
        //   follows it.
        let servedProtocol = CareProtocolStore.current
        let carePlan = CarePlanEngine.compose(.init(
            day: day,
            chapter: chapter,
            programDay: programDay,
            yesterdayFeeling: yesterdayFeeling,
            sleepHoursLastNight: SleepService.shared.lastNight
                .map { $0.asleepDuration / 3600 },
            daysSinceLastOpen: gap,
            yesterdayProteinG: yesterdayProteinG,
            proteinTargetG: targets.proteinG,
            lossRatePctPerWeek: sustainedLossRate(ema: ema, weightKg: latestKg),
            trendIsEstablished: trendEstablished,
            weighInIsStale: day?.weighInIsStaleFallback ?? false,
            isCelebrationDay: firstDownWeek,
            isDoseDay: isDoseDay,
            doseCadenceIsDaily: doseCadenceIsDaily,
            doseRouteIsOral: doseRouteIsOral,
            titrationWindowActive: titrationActive,
            isScanDay: isScanDay,
            hasAnyScan: hasAnyScan,
            preservationAtRisk: preservationAtRisk,
            isPlateauWeek: isPlateauWeek,
            // v25 E1 — the walking action's facts. The goal is
            // supplied ONLY when a program fact is in force (the
            // consent-true rollout: no fact, no walk — days change
            // only after she accepts a goal at the read or sets a
            // preference). Steps come from the connected service;
            // the meal window reads today's real plates.
            stepsToday: StepsService.shared.todayCount > 0
                ? StepsService.shared.todayCount : nil,
            stepGoal: ProgramFactStore.headValue(
                .stepGoal, userId: userId, in: context
            )?.intValue,
            hourOfDay: {
                #if DEBUG
                if let idx = ProcessInfo.processInfo.arguments
                    .firstIndex(of: "--uitest-force-hour"),
                   idx + 1 < ProcessInfo.processInfo.arguments.count,
                   let h = Int(ProcessInfo.processInfo.arguments[idx + 1]) {
                    return h
                }
                #endif
                return Calendar.current.component(.hour, from: .now)
            }(),
            externalWorkoutToday:
                MovementService.shared.workoutMinutesToday >= 10,
            largeMealLoggedRecently: plates.contains { plate in
                plate.kcal >= 400
                    && plate.loggedAt >= Date.now.addingTimeInterval(-7_200)
                    && plate.loggedAt <= Date.now.addingTimeInterval(-3_600)
            },
            walkTimingWord: ProgramFactStore.headValue(
                .walkTiming, userId: userId, in: context
            )?.wordValue,
            dayInDoseWeek: dayInDoseWeek,
            openLateSlotWeekday: openLateSlotWeekday
        ), careProtocol: servedProtocol)

        // v25 E2 B1 — the walking action's visibility, once per day
        // (the snapshot recomposes many times; the funnel wants the
        // first surfacing).
        let hasWalkMove = carePlan.actionableBeats.contains {
            if case .steps = $0 { return true } else { return false }
        }
        if hasWalkMove {
            let stampKey = "analytics.walkShown.day"
            let today = Self.dayKey()
            if UserDefaults.standard.string(forKey: stampKey) != today {
                UserDefaults.standard.set(today, forKey: stampKey)
                Analytics.track(.walkActionShown)
            }
        }

        return TodaySnapshot(
            plan: plan,
            programDay: programDay,
            totalDays: totalDays,
            day: day,
            carePlan: carePlan,
            checkStates: checkStates,
            completionWindow: completionWindow,
            kcalEaten: Int(macros.kcal.rounded()),
            proteinEatenG: Int(macros.protein.rounded()),
            carbsEatenG: Int(macros.carbs.rounded()),
            fatEatenG: Int(macros.fat.rounded()),
            fiberEatenG: Int(macros.fiber.rounded()),
            sugarEatenG: Int(macros.sugar.rounded()),
            plates: plates,
            steps: StepsService.shared.todayCount,
            latestWeightKg: latestKg,
            emaDelta7dKg: emaDelta,
            lastWeighInDaysAgo: lastWeighDaysAgo,
            trendIsEstablished: trendEstablished,
            targets: targets,
            brief: brief,
            daysSinceLastOpen: gap,
            doseCadenceIsDaily: doseCadenceIsDaily,
            doseRouteIsOral: doseRouteIsOral,
            isDoseDay: isDoseDay,
            dayInDoseWeek: dayInDoseWeek,
            openLateSlotDayKey: openLateSlotDayKey,
            hasMedicationRegimen: medicationFacts != nil,
            chapter: chapter,
            isOnBreak: BreakState.isActive,
            bandZone: bandZone,
            programWeek: programWeek,
            totalWeeks: totalWeeks,
            arcPhase: arcPhase,
            weekIntent: weekIntent
        )
    }

    // MARK: - Fetches

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

    /// 7-day EMA delta — canonical math lives in BodyStateService
    /// (v9 P0); kept as a forward for existing callers.
    static func emaDelta7d(_ ema: [WeightTrendChart.EMAPoint]) -> Double? {
        BodyStateService.emaDelta7d(ema)
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
        #if DEBUG
        // QA: force the return gap ("--uitest-open-gap 0|6|10") —
        // simctl defaults writes can't reach the app container's
        // prefs, so the comeback tiers need a launch-arg door.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--uitest-open-gap"),
           i + 1 < args.count, let forced = Int(args[i + 1]) {
            return forced
        }
        #endif
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
