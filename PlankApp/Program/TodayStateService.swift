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
    /// Which single fact is stopping `targets.kcal` from existing. nil
    /// when a target IS publishable — including a maintenance target,
    /// which is a real number and not an absence. Carried on the snapshot
    /// so the surface that draws the empty denominator can also name the
    /// repair without a second resolve.
    var missingEnergyInput: TargetsService.MissingEnergyInput? = nil

    /// True when the published kcal is her MAINTENANCE estimate rather
    /// than a loss target. A maintenance number and a loss target are the
    /// same glyph and opposite instructions — the 2026-08-13 report is
    /// what happens when a surface does not distinguish them. Home says
    /// which one it is drawing.
    var energyIsMaintenance: Bool = false

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
    /// p54 — the cycle's own length rides beside the day (7 weekly,
    /// N for interval rhythms, nil when no honest cycle exists). The
    /// Method's late-cycle gate reads the pair through the engine's
    /// own band law instead of assuming every rhythm is a week.
    var doseCycleLength: Int? = nil
    /// p54 — CycleSignal's read is `.menstrual` right now (her own
    /// recorded starts, irregularity stand-downs applied, never
    /// perimenopausal). Derived ONCE beside the brief's seasonPhase
    /// so the Method and the morning letter can never disagree about
    /// the same phase.
    var cycleSeasonIsMenstrual: Bool = false
    var openLateSlotDayKey: String? = nil
    /// An active regimen exists (the evening ask's pre-anchor
    /// window keys off its absence).
    var hasMedicationRegimen: Bool = false
    /// 2026-08-13 — where she is in the dose week, as one sentence.
    /// nil for everyone without a scheduled medication, so a surface
    /// that draws it draws NOTHING for a non-medicated user.
    var doseStanding: DoseStanding.Standing? = nil
    /// 2026-08-13 — the whole distance: start, now, and the goal she
    /// named in onboarding. nil until the record can support the claim.
    var weightJourney: WeightJourney? = nil

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

    /// v25 E8.1 — THE MEDICATION ADEQUACY NET, in one place.
    ///
    /// "did you eat enough? a gentle plate still counts" — the care line
    /// that owns the very-light day. Three surfaces now have to know
    /// whether it is speaking (the evening close, the protein close, and
    /// the Method), because none of them may count grams at someone the
    /// net is about to speak to gently. It lived as a private computed
    /// property on HomeEvening; a second copy in the Method builder is
    /// exactly the two-derivations-of-one-fact shape that produced the
    /// `source`/`entryMethod` defect, so it moved here instead.
    var showsAdequacyNet: Bool {
        guard chapter == .onMedication || CohortStore.isRestrictiveRisk
        else { return false }
        let floor = (targets.proteinG ?? 80) / 2
        return proteinEatenG < floor && plates.count <= 1
    }

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

    /// Day key in the user's local TIME ZONE, Gregorian, ASCII
    /// ("2026-07-03").
    ///
    /// v25 pass 51 — this is IDENTITY, not display: it is the tail of
    /// every deterministic id ("<uid>-dose-<dayKey>",
    /// "<uid>-symptom-…", the weight-day tombstone), a server column
    /// (`day_key`), and a UserDefaults key suffix. It used to be a
    /// bare `DateFormatter` with `calendar = .current` and no locale,
    /// so a device preferring Arabic-Indic numerals or a non-Gregorian
    /// calendar minted keys its ten POSIX/Gregorian-pinned readers
    /// could not parse (measured under ar_SA: the producer said
    /// `1448-03-05`, the reader round-tripped it to year 0851) —
    /// forking dose-slot ids and zeroing the clinician packet's
    /// adherence loop. Component arithmetic over a pinned Gregorian
    /// calendar is locale-immune; only the TIME ZONE (which day it is
    /// where she stands) follows the device.
    static func dayKey(for date: Date = .now) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0
        )
    }

    /// E8.2 — tomorrow's key, for things set tonight that pay out in
    /// the morning (the close's drafted intention).
    static func tomorrowDayKey() -> String {
        dayKey(for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
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
        // p55 — the two remaining fast-fold interpretations converge
        // on the canonical fold: ONE loss rate (BodyStateService's,
        // band-gated) and ONE flat-weeks count (the trend authority's
        // own), so the arc's "bend" can never name a plateau the
        // Method and the weekly read refuse.
        let canonicalLossRate = body.weight?.weeklyLossRate
        let arcFlatWeeks: Int = body.weight.map {
            $0.trendEstablished
                ? min(3, WeightWeekReadEngine.flatWeeks(trend: $0.canonicalTrendSeries))
                : 0
        } ?? 0

        // THE WHOLE DISTANCE (2026-08-13). `weight_logged` is the
        // second most-used action in this product and until now the
        // app could not answer "how much have I lost?" — the goal she
        // named in onboarding was stored, fed to the calorie target,
        // and never shown to her again. Composed here, at the one
        // chokepoint that already holds the body read.
        let weightJourney: WeightJourney? = {
            guard let w = body.weight,
                  let startKg = w.earliestKg, let startedAt = w.earliestAt
            else { return nil }
            let goal = UserDefaults.standard
                .double(forKey: "onboardingGoalWeightKg")
            return WeightJourney.from(
                startKg: startKg,
                startedAt: startedAt,
                trend: w.canonicalTrendSeries,
                trendEstablished: w.trendEstablished,
                goalKg: goal > 0 ? goal : nil
            )
        }()

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

        // p53 — THE FALSIFICATION LOOP, finally called. Every shown
        // Method note pre-registered a proximal outcome; this settles
        // the ones whose window closed, against the same reads this
        // snapshot is already making. One-way, idempotent, and the
        // emission is once per settled entry — the JITAI measures
        // itself or it is a vibe.
        MethodLedger.settleFollowUps(
            plateLoggedToday: !plates.isEmpty,
            proteinFloorMetToday: targets.proteinG
                .map { macros.protein >= Double($0) } ?? false,
            lastWeighInDaysAgo: body.weight?.lastWeighInDaysAgo,
            movementRecordedDaysAgo: {
                var days: [Int] = []
                if let last = MoveManualStore.all().first?.at,
                   let ago = Calendar.current.dateComponents(
                    [.day], from: Calendar.current.startOfDay(for: last),
                    to: todayStart
                   ).day {
                    days.append(max(0, ago))
                }
                if MovementService.shared.workoutMinutesToday >= 10 {
                    days.append(0)
                }
                return days.min()
            }(),
            relogUsedDaysAgo: FoodLogPersister.allEntries(userId: userId)
                .first { $0.source == EntryMethod.again.rawValue }
                .flatMap {
                    Calendar.current.dateComponents(
                        [.day],
                        from: Calendar.current.startOfDay(for: $0.loggedAt),
                        to: todayStart
                    ).day
                }
        )

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
                    emaFlatWeeks: arcFlatWeeks
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
        // v6.2 / p54 — the cycle phase, derived ONCE for every
        // consumer of this snapshot (the brief's seasonPhase and the
        // Method's menses gate). Passed only when it may speak:
        // luteal/menstrual, cycle data present and plausible after
        // `CycleSignal`'s stand-downs, never perimenopausal.
        let cycleSeason: String? = {
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
        }()

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
            lossRatePctPerWeek: canonicalLossRate,
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
            // E8.2 — the intention she set in last night's close, keyed
            // to TODAY. Read once and it expires with the day.
            morningIntention: d.string(forKey: "day.intention.text.\(dayKey())"),
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
            seasonPhase: cycleSeason,
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
                emaFlatWeeks: arcFlatWeeks
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
        // One slot-event fetch feeds the dose-day gate, the standing,
        // the cycle and the late door (interval chains need events to
        // answer "is today a dose day" at all).
        let medicationSlotEvents: [MedicationScheduleEngine.SlotEvent] =
            medicationFacts == nil ? [] : DoseEventStore.slotEvents(
                userId: userId, limit: 30, in: context
            )
        let isDoseDay = medicationFacts.map {
            MedicationScheduleEngine.isDoseDay(
                .now, facts: $0, events: medicationSlotEvents
            )
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
        var doseCycleLength: Int? = nil
        var openLateSlotDayKey: String? = nil
        var openLateSlotWeekday: String? = nil
        // THE STANDING (2026-08-13) — where she is in the dose week, as
        // one sentence. Derived at the same chokepoint that already
        // resolves the regimen, so no surface re-fetches and no second
        // truth about the same slot can exist. nil for every user
        // without a scheduled medication, by construction.
        var doseStanding: DoseStanding.Standing? = nil
        if let medicationFacts, medicationFacts.scheduleRule != "asNeeded" {
            let slotEvents = medicationSlotEvents
            doseStanding = DoseStanding.standing(
                now: .now, facts: medicationFacts, events: slotEvents
            )
            // p53: interval rhythms have a cycle and a late door too
            // (the engine gates internally — split rhythms refuse a
            // cycle, daily has no late window).
            let position = MedicationScheduleEngine.cyclePosition(
                now: .now, facts: medicationFacts, events: slotEvents
            )
            dayInDoseWeek = position?.day
            doseCycleLength = position?.length
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
            p.strengthSessions7 = MethodInputBuilder.preservationStrength(
                everRequested: MovementService.shared.everRequested,
                healthKit: MovementService.shared.strengthSessionsLast7,
                entered: MoveManualStore.strengthLastWeek()
            )
            let active = StepsService.shared.weeklyCounts.filter { $0 > 0 }.count
            p.stepsActiveDays7 = active > 0 ? active : nil
            p.lossRatePctPerWeek = body.weight?.weeklyLossRate
            return WeeklyBodyReview.preservation(p)?.state == .atRisk
        }()
        // p54 — ONE plateau arithmetic. This read a raw 14-day min/max
        // span (`WeightAnalytics.isStalled`) while the Method counted
        // flat weeks and the weekly read consulted the canonical band —
        // three definitions that could disagree on one morning. The
        // day composer now uses the trend authority's own flat-weeks
        // count, with the Method's logging gate: a flat line over an
        // unlogged stretch is an unlogged stretch, not a plateau.
        let isPlateauWeek = (body.weight.map { w in
            w.trendEstablished && WeightWeekReadEngine.flatWeeks(
                trend: w.canonicalTrendSeries
            ) >= MethodEngine.flatWeeksNeeded
        } ?? false) && loggedDays7 >= 3

        // Pass 57 — Body Snap's plan invitation is retired with its
        // other entrances; the engine input keeps its defaulted false
        // fields so nothing downstream moves. No store fetch remains
        // on the snapshot path.
        let hasAnyScan = false
        let isScanDay = false

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
            lossRatePctPerWeek: canonicalLossRate,
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
            // v25 E8 — the goal WITH the app's default anchor behind it,
            // so the standing steps row renders for someone who never
            // consented to an adaptive goal. E1's adaptive ask still
            // reads `stepGoal` and stays consent-gated.
            resolvedStepGoal: TargetsService.stepGoalResolved(
                userId: userId, plan: plan, in: context
            ),
            // E8.1 — AppClock is the one hour source; Home's `isEvening`
            // now reads the same value, so `--uitest-force-hour 20` puts
            // the whole app in one coherent evening.
            hourOfDay: AppClock.hourOfDay,
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
            doseCycleLength: doseCycleLength,
            doseCadence: medicationFacts.map { MedicationScheduleEngine.cadence($0) },
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
            missingEnergyInput: targets.kcal == nil && !targets.numericsSuppressed
                ? TargetsService.missingEnergyInput(
                    plan: plan,
                    latestWeightKg: TargetsService.resolvedWeightKg(
                        userId: userId, plan: plan, in: context),
                    careProtocol: CareProtocolStore.current)
                : nil,
            energyIsMaintenance: targets.kcal != nil
                && TargetsService.energyBasis(
                    plan: plan,
                    fallbackWeightKg: TargetsService.resolvedWeightKg(
                        userId: userId, plan: plan, in: context) ?? 0,
                    careProtocol: CareProtocolStore.current) == .maintenance,
            brief: brief,
            daysSinceLastOpen: gap,
            doseCadenceIsDaily: doseCadenceIsDaily,
            doseRouteIsOral: doseRouteIsOral,
            isDoseDay: isDoseDay,
            dayInDoseWeek: dayInDoseWeek,
            doseCycleLength: doseCycleLength,
            cycleSeasonIsMenstrual: cycleSeason == "menstrual",
            openLateSlotDayKey: openLateSlotDayKey,
            hasMedicationRegimen: medicationFacts != nil,
            doseStanding: doseStanding,
            weightJourney: weightJourney,
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

    // p55 — `emaDelta7d`, `emaFlatWeeks` and `sustainedLossRate`
    // (three fast-fold interpretations) deleted: their consumers all
    // read the canonical fold now, and a second definition with no
    // reader is how the next fork starts.

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
