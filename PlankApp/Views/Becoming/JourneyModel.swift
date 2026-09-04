import Foundation
import SwiftData
import PlankSync

// MARK: - JourneyModel (app v4, docs/app_v4/02_JOURNEY.md)
//
// The ledger's loader: assembles week entries (slice + name + story
// + signed record) for the visible window, the current week, and
// next week's shape. Views stay dumb; everything here reads through
// the pure engines so the past is reconstructable and the future is
// shape, never a locked list.

struct JourneyModel {

    struct WeekEntry: Identifiable {
        let weekIndex: Int
        let slice: ProgramWeekSlice
        let name: String
        /// The intent sentence (current week only renders it).
        let intentLine: String?
        let story: String
        let record: ReviewRecord?
        /// v5 — the week's trend movement as a quiet receipt total
        /// ("−0.9 lb" / "steady"), EMA-sourced, nil under 3 in-week
        /// points (same trust floor as the reading).
        var weightDeltaLine: String? = nil

        var id: Int { weekIndex }
    }


    let currentWeek: WeekEntry?
    /// Newest-first past weeks in the loaded window.
    let pastWeeks: [WeekEntry]
    /// Weeks older than the window, compressed ("the first N weeks").
    let earlierWeekCount: Int
    let nextWeekName: String?
    let nextWeekShape: String?
    /// A re-signing is due — the journey offers the received moment.
    let dueReview: DueReview?

    struct DueReview: Identifiable {
        let weekIndex: Int
        let slice: ProgramWeekSlice
        let proposal: ReviewProposal
        let weekName: String
        let story: String
        /// v25 E1 — the read's anchor resolution + composed model.
        /// The surface renders the model; `proposal` remains the v4
        /// face of `model.offer` where applicable (intent picks).
        let resolution: WeeklyReadAnchor.Resolution
        let model: WeeklyReadModel

        /// Item-identity for the full-screen cover: the presented
        /// copy must survive a journey reload mid-presentation (a
        /// signed review resolves dueReview to nil behind the cover;
        /// an isPresented cover would blank out — the walker caught
        /// exactly that as a white screen).
        var id: String { resolution.windowStartDay }
    }

    /// How many past weeks the ledger loads eagerly.
    static let windowWeeks = 4

    // MARK: - Load

    @MainActor
    static func load(
        userId: String,
        snapshot: TodaySnapshot,
        in context: ModelContext,
        now: Date = .now
    ) -> JourneyModel {
        guard let plan = snapshot.plan, snapshot.programDay >= 1 else {
            return JourneyModel(
                currentWeek: nil, pastWeeks: [], earlierWeekCount: 0,
                nextWeekName: nil, nextWeekShape: nil, dueReview: nil
            )
        }

        let week = max(snapshot.programWeek, 1)
        let records = Dictionary(
            uniqueKeysWithValues: WeeklyReview.records(userId: userId)
                .map { ($0.weekIndex, $0) }
        )
        let flags = WeekIntent.Flags.live
        let zone = snapshot.bandZone.flatMap(BandZone.init(rawValue:))
        let d = UserDefaults.standard

        // Pass 51 — ONE weight story. The delta line used to run its
        // own fetch (sign-up self-report INCLUDED, latest-of-day)
        // through the fast EMA while the week-read sentence three
        // screens later ran rows-minus-onboarding, earliest-of-day,
        // through the τ-fold — the same record telling two stories
        // inside one tab. Every card now reads the canonical series
        // through THE trend authority.
        let emaPoints: [WeightWeekReadEngine.TrendPoint] =
            WeightWeekReadEngine.trendSeries(
                samples: WeightSeries.samples(userId: userId, in: context),
                now: now
            )
        let unitRaw = d.string(forKey: "weightUnit") ?? "lb"
        let unit = WeightUnit(rawValue: unitRaw) ?? .lb

        func deltaLine(for slice: ProgramWeekSlice) -> String? {
            guard let first = slice.days.first?.date,
                  let last = slice.days.last?.date else { return nil }
            let cal = Calendar.current
            let start = cal.startOfDay(for: first)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: last)) ?? last
            let inWeek = emaPoints.filter { $0.day >= start && $0.day < end }
            guard inWeek.count >= 3,
                  let a = inWeek.first?.trendKg, let b = inWeek.last?.trendKg
            else { return nil }
            let deltaKg = b - a
            guard abs(deltaKg) >= 0.1 else { return "steady" }
            let display = abs(unit.display(fromKg: abs(deltaKg)))
            return String(format: "%@%.1f %@", deltaKg < 0 ? "−" : "+", display, unit.label)
        }

        func entry(for weekIndex: Int, isCurrent: Bool) -> WeekEntry {
            let slice = WeeklyReview.weekSlice(
                weekIndex: weekIndex, userId: userId, plan: plan,
                in: context, now: now
            )
            let record = records[weekIndex]
            let phase = ProgramArc.phase(
                week: weekIndex,
                totalWeeks: snapshot.totalWeeks,
                chapter: snapshot.chapter
            )
            let intent = WeekIntent.intent(
                week: weekIndex,
                chapter: snapshot.chapter,
                phase: phase,
                flags: flags,
                zone: isCurrent ? zone : nil,
                pickedKey: d.string(forKey: WeeklyReview.intentPickKey(week: weekIndex))
            )
            // A signed week keeps its frozen name (a drifting week
            // stays "the steadying week" in memory even after the
            // zone recovers).
            let name = record?.weekName ?? intent.name
            return WeekEntry(
                weekIndex: weekIndex,
                slice: slice,
                name: name,
                intentLine: isCurrent ? intent.line : nil,
                story: WeeklyReview.weekStory(slice: slice, chapter: snapshot.chapter),
                record: record,
                weightDeltaLine: deltaLine(for: slice)
            )
        }

        let current = entry(for: week, isCurrent: true)

        let oldestLoaded = max(1, week - windowWeeks)
        var past: [WeekEntry] = []
        if week > 1 {
            for idx in stride(from: week - 1, through: oldestLoaded, by: -1) {
                past.append(entry(for: idx, isCurrent: false))
            }
        }

        // Next week: shape, never a list.
        let nextIndex = week + 1
        var nextName: String?
        var nextShape: String?
        let withinPlan = snapshot.chapter != .losing
            || nextIndex <= snapshot.totalWeeks
        if withinPlan {
            let nextPhase = ProgramArc.phase(
                week: nextIndex,
                totalWeeks: snapshot.totalWeeks,
                chapter: snapshot.chapter
            )
            let nextIntent = WeekIntent.intent(
                week: nextIndex,
                chapter: snapshot.chapter,
                phase: nextPhase,
                flags: flags,
                zone: nil,
                pickedKey: d.string(forKey: WeeklyReview.intentPickKey(week: nextIndex))
            )
            nextName = nextIntent.name
            nextShape = weekShapeLine(
                weekIndex: nextIndex, plan: plan, snapshot: snapshot
            )
        }

        // v25 E1 — THE WEEKLY READ, if due (the anchor ladder:
        // preference › dose-day › enrollment; the v4 law rides the
        // enrollment rung). QA: --uitest-force-read-day arms a due
        // window for films + walkers.
        var due: DueReview?
        var forceRead = false
        #if DEBUG
        forceRead = ProcessInfo.processInfo.arguments
            .contains("--uitest-force-read-day")
        #endif
        let anchorWord = ProgramFactStore.headValue(
            .readAnchor, userId: userId, in: context
        )?.wordValue
        let medPlan = RegimenService.activeMedicationPlan(userId: userId, in: context)
        let weeklyMedAnchor = medPlan?.scheduleRule == "weeklyAnchor"
            ? medPlan?.anchorWeekday : nil
        let signedWindows = WeeklyReadStore.signedWindows(userId: userId, in: context)
            .union(WeeklyReview.signedWindowStartDays(userId: userId, plan: plan))
        var resolution = WeeklyReadAnchor.dueResolution(
            now: now,
            readAnchorWord: anchorWord,
            regimenAnchorWeekday: weeklyMedAnchor,
            programDay: snapshot.programDay,
            signedWindowStartDays: signedWindows,
            breakActive: snapshot.isOnBreak
        )
        #if DEBUG
        if forceRead, resolution == nil {
            let cal = Calendar.current
            let start = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now))!
            resolution = WeeklyReadAnchor.Resolution(
                kind: weeklyMedAnchor != nil ? .doseDay : .enrollment,
                windowStartDay: TodayStateService.dayKey(for: start),
                dueSince: cal.startOfDay(for: now)
            )
        }
        #endif
        if let resolution {
            let windowSlice = WeeklyReview.windowSlice(
                windowStartDay: resolution.windowStartDay,
                userId: userId, plan: plan, in: context, now: now
            )
            // The v4 honesty floor holds for every anchor: fewer
            // than 3 elapsed days is a stub, not a week.
            if windowSlice.elapsedDays.count >= 3 || forceRead {
                let model = readModel(
                    resolution: resolution, slice: windowSlice,
                    snapshot: snapshot, plan: plan,
                    medPlan: medPlan, userId: userId,
                    in: context, now: now
                )
                let isEnrollment = resolution.kind == .enrollment
                let dueEntry = isEnrollment && windowSlice.weekIndex == week
                    ? current
                    : past.first(where: { $0.weekIndex == windowSlice.weekIndex })
                let v4Face: ReviewProposal
                if case .v4(let p) = model.offer { v4Face = p }
                else { v4Face = .holdSteady(reason: model.offer.reason) }
                due = DueReview(
                    weekIndex: windowSlice.weekIndex,
                    slice: windowSlice,
                    proposal: v4Face,
                    weekName: dueEntry?.name ?? "your week",
                    story: dueEntry?.story
                        ?? WeeklyReview.weekStory(slice: windowSlice, chapter: snapshot.chapter),
                    resolution: resolution,
                    model: model
                )
            }
        }

        return JourneyModel(
            currentWeek: current,
            pastWeeks: past,
            earlierWeekCount: max(0, oldestLoaded - 1),
            nextWeekName: nextName,
            nextWeekShape: nextShape,
            dueReview: due
        )
    }

    // MARK: - v25 E1 — the read model assembly (live → pure)

    @MainActor
    private static func readModel(
        resolution: WeeklyReadAnchor.Resolution,
        slice: ProgramWeekSlice,
        snapshot: TodaySnapshot,
        plan: ProgramPlanRecord,
        medPlan: RegimenPlanRecord?,
        userId: String,
        in context: ModelContext,
        now: Date
    ) -> WeeklyReadModel {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let counts = StepsService.shared.dailyCounts28

        func steps(forDaysAgo range: ClosedRange<Int>) -> [Int] {
            range.compactMap { daysAgo in
                let idx = 27 - daysAgo
                return counts.indices.contains(idx) ? counts[idx] : nil
            }
        }
        let windowStart = slice.days.first?.date ?? today
        let windowStartDaysAgo = max(
            cal.dateComponents([.day], from: windowStart, to: today).day ?? 6, 0
        )
        let windowEndDaysAgo = max(windowStartDaysAgo - 6, 0)
        let stepsThisWeek = steps(forDaysAgo: windowEndDaysAgo...windowStartDaysAgo)
        let trailingStart = min(windowStartDaysAgo + 21, 27)
        let stepsTrailing = windowStartDaysAgo + 1 <= trailingStart
            ? steps(forDaysAgo: (windowStartDaysAgo + 1)...trailingStart) : []

        // Doses in the window (medication users only; zero leakage
        // otherwise).
        var dosesResolved: Int? = nil
        var dosesExpected: Int? = nil
        if let medPlan {
            let startKey = slice.days.first?.dayKey ?? resolution.windowStartDay
            let endKey = slice.days.last?.dayKey ?? startKey
            let events = (try? context.fetch(FetchDescriptor<DoseEventRecord>(
                predicate: #Predicate {
                    $0.userId == userId
                    && $0.dayKey >= startKey && $0.dayKey <= endKey
                }
            ))) ?? []
            dosesResolved = events.filter {
                $0.status == "taken" || $0.status == "skipped"
            }.count
            // p53: the denominator comes from the ENGINE's slots, so
            // an every-10-days week can honestly expect zero and a
            // split week expects two (the old line said 1 or 7).
            let facts = RegimenService.facts(for: medPlan)
            if let windowEnd = slice.days.last?.date {
                let slotEvents = DoseEventStore.slotEvents(
                    userId: userId, limit: 30, in: context
                )
                dosesExpected = MedicationScheduleEngine.slotDays(
                    through: windowEnd, lookbackDays: slice.days.count,
                    facts: facts, events: slotEvents
                ).count
            } else {
                dosesExpected = 0
            }
        }

        // v25 E2 — THE MEDICATED WEEK: the slot's own story, the
        // cycle position, and era recency (single-dose rhythms only
        // — weekly and every-N; nil everywhere else, zero leakage;
        // a SPLIT rhythm's overlapping doses have no one-slot story).
        var doseWeek: WeeklyReadComposer.Inputs.DoseWeekState? = nil
        var cycleDay: Int? = nil
        var cycleLength: Int? = nil
        var eraChangedRecently = false
        let medCadence = medPlan.map {
            MedicationScheduleEngine.cadence(RegimenService.facts(for: $0))
        }
        let hasSingleDoseRhythm: Bool = {
            switch medCadence {
            case .weekly, .everyNDays: return true
            default: return false
            }
        }()
        if let medPlan, hasSingleDoseRhythm {
            let facts = RegimenService.facts(for: medPlan)
            let slotEvents = DoseEventStore.slotEvents(
                userId: userId, limit: 30, in: context
            )
            if let slotDate = slice.days.map(\.date).first(where: {
                MedicationScheduleEngine.isDoseDay(
                    $0, facts: facts, events: slotEvents
                )
            }) {
                let slotKey = MedicationScheduleEngine.dayKey(for: slotDate)
                let event = DoseEventStore.event(
                    dayKey: slotKey, userId: userId, in: context
                )
                switch event?.status {
                case "taken":
                    let takenKey = event?.takenAt.map {
                        MedicationScheduleEngine.dayKey(for: $0)
                    }
                    doseWeek = (takenKey == nil || takenKey == slotKey)
                        ? .takenOnDay : .takenLate
                case "skipped":
                    doseWeek = .skipped
                case "missed":
                    doseWeek = .missed
                default:
                    doseWeek = now < MedicationScheduleEngine.lateWindowEnd(
                        slotDay: slotDate, facts: facts
                    ) ? .open : .missed
                }
            }
            let position = MedicationScheduleEngine.cyclePosition(
                now: now, facts: facts,
                events: DoseEventStore.slotEvents(
                    userId: userId, limit: 30, in: context
                )
            )
            cycleDay = position?.day
            cycleLength = position?.length
            // A settled dose/medication change restarts startedAt
            // (schedule tweaks inherit it) — recency = a real era
            // seam inside ~2 weeks.
            let history = RegimenService.medicationHistory(
                userId: userId, in: context
            )
            if history.count >= 2,
               let days = cal.dateComponents(
                   [.day], from: medPlan.startedAt, to: now
               ).day, (0...14).contains(days) {
                eraChangedRecently = true
            }
        }

        // v25 E2 — THE WEIGHT SIGNAL (suppression-honoring; the
        // engine's floors decide whether a band renders at all).
        var weightSignal: WeeklyReadComposer.Inputs.WeightSignal? = nil
        if !snapshot.targets.numericsSuppressed {
            // Pass 51 — the canonical series (one fetch rule, one
            // per-day reduction) instead of a hand-rolled sibling of it.
            let samples = WeightSeries.samples(
                userId: userId, in: context, calendar: cal
            )
            if !samples.isEmpty {
                let read = WeightWeekReadEngine.read(
                    samples: samples, now: now, calendar: cal
                )
                let unit = WeightUnit.current
                weightSignal = .init(
                    band: read.band?.rawValue,
                    sufficiency: read.sufficiency.rawValue,
                    deltaText: read.weeklyDeltaKg.map {
                        String(
                            format: "%.1f %@",
                            unit.display(fromKg: abs($0)), unit.label
                        )
                    }
                )
            }
        }

        let currentStepGoal = ProgramFactStore.headValue(
            .stepGoal, userId: userId, in: context
        )?.intValue
        let offer = WeeklyReadOffers.propose(
            v4: v4Inputs(for: slice, snapshot: snapshot, plan: plan),
            spine: .init(
                currentStepGoal: currentStepGoal,
                stepGoalRecommendation: AdaptiveStepsEngine.recommendedGoal(
                    recentDailySteps: Array(counts.suffix(10)),
                    currentGoal: currentStepGoal
                ),
                loggingModeWord: ProgramFactStore.headValue(
                    .loggingMode, userId: userId, in: context
                )?.wordValue,
                recentlyDeclinedKinds: {
                    var declined = WeeklyReadStore.recentlyDeclinedKinds(
                        userId: userId, now: now, in: context
                    )
                    #if DEBUG
                    // QA: surface the spine offers by treating the v4
                    // clinical kinds as cooled down (the real
                    // mechanism, not a bypass).
                    if ProcessInfo.processInfo.arguments
                        .contains("--uitest-read-prefer-steps") {
                        declined.formUnion(["protein_firm", "protein_ease",
                                            "moves_ease", "weigh_soften"])
                    }
                    #endif
                    return declined
                }(),
                // p79 — THE LEARNED BURN's proposal inputs. The read
                // is silent for most records (established fold + 14
                // usable logged days + weigh-in density); when it
                // speaks and the gap is material, the energy offer
                // outranks the step recalc in WeeklyReadOffers.
                energy: .init(
                    read: ExpenditureReadAssembler.current(
                        userId: userId, in: context, now: now, calendar: cal
                    ),
                    currentTargetKcal: snapshot.targets.kcal,
                    planRatePctPerWeek: TargetsService.planImpliedRate(
                        plan: plan,
                        fallbackWeightKg: TargetsService.resolvedWeightKg(
                            userId: userId, plan: plan, in: context
                        ) ?? 0
                    ),
                    currentWeightKg: TargetsService.resolvedWeightKg(
                        userId: userId, plan: plan, in: context
                    ),
                    isOnMedication: CohortStore.isOnMedication(
                        userId: userId, in: context
                    ),
                    currentAdjustKcal: UserDefaults.standard.integer(
                        forKey: WeeklyReview.energyAdjustKey
                    )
                )
            )
        )

        // p54 — WHAT ACTUALLY MATTERED THIS WEEK (§9): the prior
        // week's floor count (a real prior week only), the strength
        // pillar, the weekend energy shape, and the Method's settled
        // follow-through — each from a store the surfaces already
        // read, none derived twice.
        let priorProteinDaysMet: Int? = {
            guard let windowStart = slice.days.first?.date,
                  let priorStart = cal.date(
                      byAdding: .day, value: -7, to: windowStart
                  ) else { return nil }
            let prior = WeeklyReview.windowSlice(
                windowStartDay: TodayStateService.dayKey(for: priorStart),
                userId: userId, plan: plan, in: context, now: now
            )
            guard prior.elapsedDays.count >= 5 else { return nil }
            return prior.proteinDaysMet(targetG: snapshot.targets.proteinG)
        }()
        let strengthSessions7 = MethodInputBuilder.strengthLast7(
            healthKitCount: MovementService.shared.strengthSessionsLast7
        )
        let weekendKcalDelta: Int? = {
            guard !snapshot.targets.numericsSuppressed,
                  !CohortStore.isRestrictiveRisk else { return nil }
            let logged = slice.elapsedDays.filter { $0.plateCount > 0 }
            let weekend = logged.filter { cal.isDateInWeekend($0.date) }
            let weekdays = logged.filter { !cal.isDateInWeekend($0.date) }
            guard weekend.count >= 2, weekdays.count >= 3 else { return nil }
            let wAvg = weekend.map(\.kcal).reduce(0, +) / Double(weekend.count)
            let dAvg = weekdays.map(\.kcal).reduce(0, +) / Double(weekdays.count)
            let delta = wAvg - dAvg
            guard delta >= 150 else { return nil }
            return Int((delta / 50).rounded() * 50)
        }()
        let methodFollowUps: (met: Int, settled: Int)? = {
            guard let windowStart = slice.days.first?.date else { return nil }
            let settled = MethodLedger.entries().filter {
                $0.shownAt >= windowStart && $0.followUpMet != nil
            }
            guard !settled.isEmpty else { return nil }
            return (settled.filter { $0.followUpMet == true }.count, settled.count)
        }()
        let treatmentMonths = MedicationScheduleEngine.treatmentMonths(
            startedOn: medPlan?.treatmentStartedOn
        )

        return WeeklyReadComposer.compose(.init(
            windowStartDay: resolution.windowStartDay,
            anchorKind: resolution.kind,
            stepsThisWeek: stepsThisWeek,
            stepsTrailing: stepsTrailing,
            plateDays: slice.elapsedDays.filter { $0.plateCount > 0 }.count,
            plateCount: slice.plateCount,
            proteinDaysMet: slice.proteinDaysMet(targetG: snapshot.targets.proteinG),
            elapsedDays: slice.elapsedDays.count,
            dosesResolved: dosesResolved,
            dosesExpected: dosesExpected,
            offer: offer,
            doseWeek: doseWeek,
            cycleDay: cycleDay,
            cycleLength: cycleLength,
            eraChangedRecently: eraChangedRecently,
            treatmentMonths: treatmentMonths,
            priorProteinDaysMet: priorProteinDaysMet,
            strengthSessions7: strengthSessions7,
            weekendKcalDelta: weekendKcalDelta,
            methodFollowUpsMet: methodFollowUps?.met,
            methodFollowUpsSettled: methodFollowUps?.settled,
            programWeek: slice.weekIndex,
            saidPriorAttempts: CohortStore.saidPriorAttempts,
            weight: weightSignal
        ))
    }

    // MARK: - Proposal assembly (live inputs → pure rules)

    @MainActor
    private static func v4Inputs(
        for slice: ProgramWeekSlice,
        snapshot: TodaySnapshot,
        plan: ProgramPlanRecord
    ) -> WeeklyReview.ProposalInputs {
        let d = UserDefaults.standard
        let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium
        let profile = IntensityProfile.from(tier: tier)
        let phase = ProgramArc.phase(
            week: slice.weekIndex,
            totalWeeks: snapshot.totalWeeks,
            chapter: snapshot.chapter
        )
        // Prior week's weigh count feeds the two-quiet-weeks rule.
        let priorWeighs: Int? = slice.weekIndex > 1
            ? nil   // loaded lazily only when the current week is quiet
            : nil

        return .init(
            chapter: snapshot.chapter,
            phaseKey: phase.key,
            zone: snapshot.bandZone.flatMap(BandZone.init(rawValue:)),
            numericsSuppressed: snapshot.targets.numericsSuppressed,
            restrictiveRisk: CohortStore.isRestrictiveRisk,
            proteinTargetG: snapshot.targets.proteinG,
            proteinAdjustG: d.integer(forKey: WeeklyReview.proteinAdjustKey),
            sessionsPlanned: max(1, min(6, profile.sessionsPerWeek
                + d.integer(forKey: WeeklyReview.sessionsAdjustKey))),
            sessionsAdjust: d.integer(forKey: WeeklyReview.sessionsAdjustKey),
            movedDays: movedDays(slice: slice),
            weighCount: slice.weighCount,
            priorWeekWeighCount: priorWeighs,
            proteinDaysMet: slice.proteinDaysMet(targetG: snapshot.targets.proteinG),
            plateLoggedDays: slice.elapsedDays.filter { $0.plateCount > 0 }.count,
            keptCount: slice.keptCount,
            elapsedDays: slice.elapsedDays.count
        )
    }

    private static func movedDays(slice: ProgramWeekSlice) -> Int {
        // A moved day = the day's one thing was a workout that landed
        // OR any completed count ≥ 1 on a workout day. The slice
        // carries completed counts; workout-specific checks ride the
        // one-thing derivation upstream. Conservative: use kept +
        // partial days with any completion as the floor.
        slice.elapsedDays.filter { $0.completedCount >= 1 && $0.oneThingDone }.count
    }

    // MARK: - The future's shape line

    /// One sentence of rhythm for a coming week — counted from the
    /// pure engine, spoken as shape ("3 moves · 2 reads · one trend
    /// check"), never a day-by-day list.
    @MainActor
    static func weekShapeLine(
        weekIndex: Int,
        plan: ProgramPlanRecord,
        snapshot: TodaySnapshot
    ) -> String {
        let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium
        let profile = IntensityProfile.from(tier: tier)
        let firstDay = (weekIndex - 1) * 7 + 1
        let lastDay = min(weekIndex * 7, plan.totalDays)
        guard firstDay <= lastDay else { return "coming up" }

        var moves = 0, reads = 0, weighs = 0, breaths = 0
        for day in firstDay...lastDay {
            let composed = PrescriptionEngineV2.compose(
                programDay: day,
                totalDays: plan.totalDays,
                profile: profile,
                context: .live(lastWeighInDaysAgo: 0, lastSnapDaysAgo: nil)
            )
            for beat in composed.beats {
                switch beat {
                case .workout: moves += 1
                case .lesson: reads += 1
                case .weighIn: weighs += 1
                case .breath: breaths += 1
                default: break
                }
            }
        }

        var parts: [String] = []
        if moves > 0 { parts.append(moves == 1 ? "1 move" : "\(moves) moves") }
        // Daily-cadence lessons compress to their rhythm.
        if reads >= 5 { parts.append("a daily lesson") }
        else if reads > 0 { parts.append(reads == 1 ? "1 lesson" : "\(reads) lessons") }
        if weighs > 0 { parts.append(weighs == 1 ? "1 weigh-in" : "\(weighs) weigh-ins") }
        if breaths > 0 { parts.append("a rest-day breath") }
        if parts.isEmpty { return "a light week" }
        return parts.joined(separator: " · ")
    }
}
