import Foundation

// MARK: - PrescriptionEngineV2
//
// App v2 (docs/app_v2/04_DAILY_PROGRAM.md). The day composer that
// makes archetypes REAL. v1 rendered the same six rows every day and
// let the archetype reorder one; v2 selects 3-5 beats per day and
// finally consumes the tier capability that shipped dormant in
// IntensityProfile since v1.1:
//
//   - workouts appear sessionsPerWeek times (3/4/5), never on rest
//   - lessons follow lessonCadence (2x/wk on soft — mapped so the
//     curriculum arc stays COMPLETE, see lessonOrdinal)
//   - weigh-in is a cadence (Mon/Thu default; weekly for GLP-1 and
//     restriction-risk; Sunday for maintenance), not a daily row
//   - breath is the rest-day hero and joins heavy-stress days
//
// Pure + deterministic: same (day, plan, cohort) → same beats. No
// I/O; callers resolve context. Unit-tested via the day-table test.

enum PrescriptionEngineV2 {

    // MARK: - Context

    struct Context: Equatable {
        var glp1Status: String
        var restrictiveRisk: Bool
        var maintenanceMode: Bool
        var highStress: Bool
        /// Days since the last weigh-in; nil = never weighed.
        var lastWeighInDaysAgo: Int?
        /// Days since the last snap; drives nothing today (snap is
        /// always present) but reserved for copy selection.
        var lastSnapDaysAgo: Int?
        /// v4 re-signing knobs (docs/app_v4/01_PROGRAM.md §0): a
        /// consented workout-count adjustment (−1...+1) and the
        /// softened weigh cadence. Both default off so every
        /// pre-v4 call site composes identically.
        var sessionsAdjust: Int = 0
        var weighSoftened: Bool = false

        static func live(lastWeighInDaysAgo: Int?, lastSnapDaysAgo: Int?) -> Context {
            Context(
                glp1Status: CohortStore.glp1StatusKey,
                restrictiveRisk: CohortStore.isRestrictiveRisk,
                maintenanceMode: CohortStore.isMaintenanceMode,
                highStress: CohortStore.isHighStress,
                lastWeighInDaysAgo: lastWeighInDaysAgo,
                lastSnapDaysAgo: lastSnapDaysAgo,
                sessionsAdjust: max(-1, min(1, UserDefaults.standard.integer(
                    forKey: WeeklyReview.sessionsAdjustKey))),
                weighSoftened: UserDefaults.standard.bool(
                    forKey: WeeklyReview.weighSoftenedKey)
            )
        }
    }

    struct Day: Equatable {
        let archetype: ProgramDayArchetype
        let beats: [ProgramDayPrescription]
        /// True when today's weigh-in beat exists only because the
        /// last log went stale (>7 days), not because it's a cadence
        /// day — copy softens accordingly.
        let weighInIsStaleFallback: Bool
        /// v6.3 — the day ordinal, so the one-thing can steer the
        /// first-session ask (days 1-2 lead with the snap: logging
        /// food is the 3.1x D1 behavior and only 17% ever reach it).
        var programDay: Int = 0
    }

    // MARK: - Compose

    static func compose(
        programDay: Int,
        totalDays: Int,
        profile: IntensityProfile,
        context: Context,
        careProtocol: CareProtocol = .default
    ) -> Day {
        let archetype = ProgramDayArchetype.archetype(
            forProgramDay: programDay,
            glp1Status: context.glp1Status,
            restrictiveFoodRelationship: context.restrictiveRisk
        )
        let slot = dayInWeek(programDay)

        var beats: [ProgramDayPrescription] = []

        // 1. The hero beat leads (archetype anchor).
        // 2. Assembly order below is base order; hero is moved to
        //    index 0 at the end.

        // Snap — the food anchor, present every day.
        beats.append(.snapMeal)

        // Workout — placement by sessionsPerWeek, bent by the
        // re-signing's consented adjustment (a plan you keep beats
        // a plan you dodge).
        let week = programWeek(programDay)
        let sessions = max(1, min(6, profile.sessionsPerWeek + context.sessionsAdjust))
        if workoutSlots(sessionsPerWeek: sessions,
                        programDay: programDay,
                        context: context).contains(slot) {
            beats.append(.workout(
                tier: profile.tier,
                minutes: profile.workoutMinutes(forProgramWeek: week),
                bodyFocus: nil   // module re-reads focus at open (v1 behavior)
            ))
        }

        // Lesson — cadence-aware, arc-complete.
        if lessonOrdinal(programDay: programDay, cadence: profile.lessonCadence) != nil {
            beats.append(.lesson(lessonId: nil))
        }

        // Steps — the everyday anchor (auto-completes, renders live).
        beats.append(.steps(goal: profile.stepsDailyGoal))

        // Weigh-in — cadence or stale fallback.
        let cadenceDay = weighInSlots(context: context, careProtocol: careProtocol).contains(slot)
        let stale = (context.lastWeighInDaysAgo ?? Int.max)
            > careProtocol.cadence.weighStaleFallbackDays && !cadenceDay
        if cadenceDay || stale {
            beats.append(.weighIn)
        }

        // Breath — rest-day hero; heavy-stress companion on balanced days.
        let isRest = archetype == .rest
        if isRest || (context.highStress && archetype == .balanced) {
            beats.append(.breath(minutes: 1, style: eveningLeaning(slot) ? .calming : .energizing))
        }

        // Cap at 5: on over-full days the stress-breath yields first,
        // then the lesson defers on weigh-in days for soft cadence.
        if beats.count > 5, let idx = beats.lastIndex(where: {
            if case .breath = $0 { return !isRest } else { return false }
        }) {
            beats.remove(at: idx)
        }
        if beats.count > 5, let idx = beats.lastIndex(where: {
            if case .lesson = $0 { return profile.lessonCadence == .twiceWeek } else { return false }
        }) {
            beats.remove(at: idx)
        }

        // Hero to the front.
        let ordered = heroFirst(beats, archetype: archetype)

        return Day(
            archetype: archetype,
            beats: ordered,
            weighInIsStaleFallback: stale && !cadenceDay,
            programDay: programDay
        )
    }

    // MARK: - Placement tables

    static func dayInWeek(_ programDay: Int) -> Int { (programDay - 1) % 7 }
    static func programWeek(_ programDay: Int) -> Int { ((programDay - 1) / 7) + 1 }

    /// Which rotation slots carry a workout. Movement day (slot 1)
    /// always; protein days fill next (0, 2, 4), then balanced
    /// (3, 5). Rest (6) never. GLP-1-current profiles derive an
    /// all-protein rotation, so the fill order is effectively
    /// "movement day then earliest days" — stable + deterministic.
    static func workoutSlots(sessionsPerWeek: Int, programDay: Int, context: Context) -> Set<Int> {
        let fillOrder = [1, 0, 2, 4, 3, 5]
        let count = max(0, min(sessionsPerWeek, fillOrder.count))
        return Set(fillOrder.prefix(count))
    }

    /// Weigh-in cadence slots (SCIENCE.md §3: regular self-weighing
    /// tracks with outcomes; this brand caps it below daily to stay
    /// anti-scale-anxiety).
    ///   default            Mon + Thu   (slots 0, 3)
    ///   GLP-1 current      Mon         (loss is pharmacological;
    ///                                    daily noise is anti-signal)
    ///   restriction-risk   Mon         (weekly, softened copy)
    ///   maintenance/post   Sun         (the weekly "trend check")
    static func weighInSlots(
        context: Context, careProtocol: CareProtocol = .default
    ) -> Set<Int> {
        let c = careProtocol.cadence
        if context.maintenanceMode { return Set(c.weighSlotsMaintenance) }
        if context.glp1Status == "current" { return Set(c.weighSlotsGLP1Current) }
        if context.restrictiveRisk { return Set(c.weighSlotsRestrictiveRisk) }
        // The re-signing's softened cadence: one gentle check-in.
        if context.weighSoftened { return Set(c.weighSlotsSoftened) }
        return Set(c.weighSlotsDefault)
    }

    /// Lesson-day ordinal for cadence-aware curriculum mapping.
    /// Returns nil when today carries no lesson. For daily cadences
    /// the ordinal IS the program day. For twiceWeek (slots 1 + 5:
    /// the original Tue/Sat spec) the ordinal counts lesson-days
    /// elapsed, so the scheduler can be asked for slot N-of-M and
    /// the 84-lesson arc compresses INTO the lesson days instead of
    /// being skipped over (a soft-tier user still meets the whole
    /// curriculum, just twice a week).
    static func lessonOrdinal(programDay: Int, cadence: IntensityProfile.LessonCadence) -> Int? {
        switch cadence {
        case .daily, .dailyPlusEvening:
            return programDay
        case .twiceWeek:
            let slot = dayInWeek(programDay)
            guard slot == 1 || slot == 5 else { return nil }
            let fullWeeks = (programDay - 1) / 7
            let inWeek = slot == 1 ? 1 : 2
            return fullWeeks * 2 + inWeek
        }
    }

    /// Total lesson-days across the plan for the cadence — the
    /// `totalDays` the curriculum scheduler should compress into.
    static func totalLessonDays(totalDays: Int, cadence: IntensityProfile.LessonCadence) -> Int {
        switch cadence {
        case .daily, .dailyPlusEvening:
            return totalDays
        case .twiceWeek:
            let weeks = totalDays / 7
            let remainder = totalDays % 7
            var extra = 0
            if remainder >= 2 { extra += 1 }   // slot 1 reached
            if remainder >= 6 { extra += 1 }   // slot 5 reached
            return max(weeks * 2 + extra, 1)
        }
    }

    private static func eveningLeaning(_ slot: Int) -> Bool {
        // Balanced-day stress breath leans calming (evening use);
        // rest-day breath is the hero and stays calming too. Slots
        // don't change style today — reserved hook.
        true
    }

    private static func heroFirst(
        _ beats: [ProgramDayPrescription],
        archetype: ProgramDayArchetype
    ) -> [ProgramDayPrescription] {
        var out = beats
        func promote(_ matches: (ProgramDayPrescription) -> Bool) {
            if let i = out.firstIndex(where: matches), i != 0 {
                let beat = out.remove(at: i)
                out.insert(beat, at: 0)
            }
        }
        switch archetype {
        case .protein:
            promote { if case .snapMeal = $0 { return true } else { return false } }
        case .movement:
            promote { if case .workout = $0 { return true } else { return false } }
        case .rest:
            promote { if case .breath = $0 { return true } else { return false } }
        case .balanced:
            promote { if case .lesson = $0 { return true } else { return false } }
        }
        return out
    }
}
