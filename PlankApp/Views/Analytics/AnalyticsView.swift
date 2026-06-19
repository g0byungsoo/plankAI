import SwiftUI
import SwiftData
import UIKit  // UIImage for the P3 day-card render
import PlankSync
import PlankFood
import Auth  // MemberImportVisibility: User.id lives in Supabase's Auth submodule

// MARK: - Bento metric explainers (progressive disclosure)
//
// Tapping a tile's ⓘ opens one of these — the 2026 health-app pattern:
// a simple number on the tile, the "what it means" + method on a deliberate
// tap. Copy is calm + health-literacy-friendly (women report being
// "overwhelmed by dieting info"), anti-shame, and traces the number to how
// it's computed (data-provenance).
enum BecomingMetric: String, Identifiable {
    case trend, forecast, milestone, goal, cadence, movement, breath, plate
    var id: String { rawValue }

    var sticker: StickerName {
        switch self {
        case .trend:     return .butterflyRing
        case .forecast:  return .sparkleGlossy
        case .milestone: return .starLineart
        case .goal:      return .flower3D
        case .cadence:   return .heartGlossy
        case .movement:  return .shoeIridescent
        case .breath:    return .heartGlossy
        case .plate:     return .cherries
        }
    }

    var title: String {
        switch self {
        case .trend:     return "your weight trend"
        case .forecast:  return "your forecast"
        case .milestone: return "your next marker"
        case .goal:      return "progress to goal"
        case .cadence:   return "your weigh-in rhythm"
        case .movement:  return "your moving"
        case .breath:    return "your breath"
        case .plate:     return "your plate"
        }
    }

    var explainer: String {
        switch self {
        case .trend:
            return "this line is your smoothed trend. it evens out the daily ups and downs from water, food, and hormones so you see the real direction, not the noise. the number up top is today; the line is the truth ♥"
        case .forecast:
            return "at your recent pace, this is about when you'd reach your goal. it moves as your pace moves. a gentle guide, never a promise or a deadline to stress about."
        case .milestone:
            return "we break your goal into small markers, about 5 lb each. small wins are easier to feel and to celebrate than one big number that's far away."
        case .goal:
            return "how far you've come toward your goal weight. we show it in healthy steps because slow and steady is what actually lasts, and stays off."
        case .cadence:
            return "how many times you stepped on the scale this week. weighing in a few times a week is the single habit most linked to losing weight. not the number itself, the showing up."
        case .movement:
            return "your steps from apple health, for the last 7 days. the soft line at 7,500 is research-backed. that's where weight tends to stay off, not the old 10k myth. brisk walks count more than slow ones, but every walk counts ♥"
        case .breath:
            return "one slow minute of breath flips on your parasympathetic system. the rest-and-digest mode that brings cortisol down. lower cortisol means fewer cravings that aren't really hunger, and a body less locked into holding on. the dots are the days you breathed this week. balban (stanford 2023, n=111), epel (yale, cortisol & abdominal fat), sato (senobi, biomed res 2010, n=40) ♥"
        case .plate:
            return "the bars are your last 7 days. the number up top is your daily average. only the days you logged. days you didn't log don't count against you; this is rhythm, not surveillance. snapping a plate adds it; editing fixes the ai when it's off ♥"
        }
    }
}

// MARK: - MetricExplainerSheet

struct MetricExplainerSheet: View {
    let metric: BecomingMetric
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: Space.lg) {
            // Sticker hero. The earlier `Spacer().frame(height: Space.xl)`
            // got compressed by long-content explainers (.breath has the
            // longest body — 4 citations), AND the system drag indicator
            // overlay was eating into whatever pad the spacer did hold,
            // landing the sticker right against the sheet chrome. Moved
            // the inset to an explicit `.padding(.top, 56)` on the VStack
            // — non-compressible, and sits BELOW the drag-indicator area
            // so the sticker always has a real breathing margin.
            ZStack {
                Circle().fill(Palette.accentSubtle).frame(width: 72, height: 72)
                Image(metric.sticker.assetName)
                    .resizable().scaledToFit().frame(width: 40, height: 40)
                    .opacity(metric.sticker.style.opacity)
            }
            .accessibilityHidden(true)

            Text(metric.title)
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            // Long-content safety net: ScrollView around the explainer
            // text so .breath's longer paragraph never crashes the layout
            // when the sheet is at .medium. ScrollIndicator hidden for the
            // clean register. Short explainers don't trigger a scroll —
            // ScrollView only scrolls when content exceeds its frame.
            ScrollView(showsIndicators: false) {
                Text(metric.explainer)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            JFContinueButton(label: "got it", action: onClose)
        }
        .padding(.top, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bgPrimary)
    }
}

struct AnalyticsView: View {
    @AppStorage("userName") private var userName = ""
    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var allSessionLogs: [SessionLogRecord]
    @Query(sort: \DayProgressRecord.programDay, order: .reverse) private var allDayProgress: [DayProgressRecord]
    @Query(sort: \SessionRatingRecord.createdAt, order: .reverse) private var allRatings: [SessionRatingRecord]
    @Query(sort: \WeightLogRecord.loggedAt, order: .reverse) private var allWeightLogs: [WeightLogRecord]
    /// UserRecord row for the current auth user — source of truth for the
    /// 13 onboarding fields that don't have AppStorage mirrors (motivation,
    /// identityFeeling, heightCm, etc.). Phase A reads `motivation` and
    /// `identityFeeling` for the hero; later phases pull more.
    @Query private var allUserRecords: [UserRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService.shared
    @AppStorage("onboardingCurrentWeightKg") private var onboardingCurrentWeightKg: Double = 0
    @AppStorage("onboardingGoalWeightKg") private var onboardingGoalWeightKg: Double = 0
    /// ED-safe opt-out: when on, weight numbers + chart + goal progress
    /// hide. Logging still works so the user can keep tracking silently.
    /// Per Linardon 2021 (Int J Eat Disord), opt-out reduced ED-symptom
    /// escalation in app users by ~22%. Eye toggle lives directly on the
    /// weight card so it's always one tap away — no settings dive.
    @AppStorage("hideWeightStats") private var hideWeightStats = false
    /// Display unit for weight surfaces. Storage stays kg. Default lb.
    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }
    /// Drives the coach avatar on the adaptive insight (same mapping the
    /// home note + reminders use).
    @AppStorage("voicePreference") private var voicePreference = "encouraging"
    /// GLP-1 status (onboarding v2) — gates the cohort protein line.
    @AppStorage("onboarding_glp1_status") private var glp1Status = ""
    /// Restriction-risk cohort flags — hide the lighter-days counter
    /// (the journal stays fully available).
    @AppStorage("onboardingFoodRelationship") private var foodRelationshipKey = ""
    @AppStorage("onboardingPriorAttempts") private var priorAttemptsKey = ""
    /// v1.0.10 — boolean restrictive flag set by onboarding v4 alongside
    /// the legacy string `onboardingFoodRelationship`. Either source
    /// being truthy disables reset-week phasing on the archetype
    /// rotation per the 2026-06-17 WM physician brief.
    @AppStorage("onb_restrictive_food") private var restrictiveFoodFlag: Bool = false

    /// Same derivation PlanView + LessonReaderView use, so all three
    /// surfaces apply the override identically. Pure read; the rotation
    /// decision lives in ProgramDayArchetype.archetype itself.
    private var isRestrictiveCohort: Bool {
        if restrictiveFoodFlag { return true }
        return ["control", "complicated"].contains(foodRelationshipKey.lowercased())
    }

    /// User-scoped views over the raw @Query results. SessionRatingRecord
    /// has no userId column locally (cloud schema added it later), so we
    /// scope ratings transitively through the user's session_log ids.
    /// Current-user UserRecord, scoped via auth.currentUser.id. Returns nil
    /// for legacy users whose row predates Phase 4 columns (motivation /
    /// identityFeeling fall back to empty strings via the call sites).
    private var currentUserRecord: UserRecord? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return nil }
        return allUserRecords.first { $0.id == userId }
    }

    private var sessionLogs: [SessionLogRecord] {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return [] }
        return allSessionLogs.filter { $0.userId == userId }
    }

    private var weightLogs: [WeightLogRecord] {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return [] }
        return allWeightLogs.filter { $0.userId == userId }
    }

    /// v1.2 Becoming (2026-06-18) — onboarding goal weight in kg, or
    /// nil when unset. Passed to BecomingTrendCanvas so the dashed
    /// goal hairline can render after the trend line traces in.
    private var goalWeightKg: Double? {
        onboardingGoalWeightKg > 0 ? onboardingGoalWeightKg : nil
    }

    /// v1.2 Becoming — lifetime cumulative deeds for the Strava-coded
    /// "you've kept count" counter. Derived from real sources:
    ///   - plates: `FoodLogPersister.allEntries(userId).count`
    ///   - lessons: `JeniMethodState.lastCompletedLessonId`
    ///   - breaths: `BreathworkState.shared.totalCompleted`
    /// Phase 4 Day-2 (2026-06-19) — refreshes HealthKit-backed today
    /// data on pull-down. Steps re-syncs from HealthKit; the rest
    /// (sessions, food logs) is SwiftData @Query and auto-updates,
    /// but a defensive 0.5s breath lets the refresh spinner feel
    /// intentional even when the data is already current.
    @MainActor
    private func refreshBecomingData() async {
        await StepsService.shared.refresh()
        try? await Task.sleep(for: .milliseconds(500))
    }

    /// Phase 4 Day-2 (2026-06-19) — 7-day series per moved-strip stat
    /// for the tap-reveal micro-bar. Oldest → today.
    /// Steps: StepsService.last7Counts.
    /// Plank/workout: minutes of routine + plank_benchmark sessions
    /// per day.
    /// Breath: minutes of breath sessions per day, capped via
    /// completed_at presence on the session log.
    private var movedWeekSeries: (steps: [Int], plank: [Int], breath: [Int]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days: [Date] = (0..<7).compactMap {
            cal.date(byAdding: .day, value: $0 - 6, to: today)
        }

        let steps = StepsService.shared.weeklyCounts

        var plank: [Int] = Array(repeating: 0, count: 7)
        var breath: [Int] = Array(repeating: 0, count: 7)
        for log in sessionLogs {
            for (idx, day) in days.enumerated() {
                let next = cal.date(byAdding: .day, value: 1, to: day) ?? day
                if log.completedAt >= day, log.completedAt < next {
                    let minutes = max(1, Int((log.holdTime / 60).rounded()))
                    if log.sessionType == "breathwork" {
                        breath[idx] += minutes
                    } else {
                        plank[idx] += minutes
                    }
                }
            }
        }
        return (steps: steps, plank: plank, breath: breath)
    }

    /// Phase 4 Day-2 — first-engagement dates per deeds cell. Drives
    /// the long-press "since *date*" reveal on BecomingDeedsCounter.
    /// nil per cell when nothing of that kind has happened yet.
    private var deedsSinceDates: (plates: Date?, lessons: Date?, breath: Date?) {
        var plates: Date? = nil
        if FoodFlags.isEnabled,
           let userId = auth.currentUser?.id.uuidString, !userId.isEmpty {
            plates = FoodLogPersister.allEntries(userId: userId)
                .map(\.loggedAt)
                .min()
        }
        let lessons = sessionLogs
            .filter { $0.sessionType == "lesson" }
            .map(\.completedAt)
            .min()
        let breath = sessionLogs
            .filter { $0.sessionType == "breathwork" }
            .map(\.completedAt)
            .min()
        return (plates: plates, lessons: lessons, breath: breath)
    }

    /// Breath minutes ≈ breaths × 4 (typical session length); the
    /// derived "food noise quieted hours" combines lessons + breath
    /// minutes in BecomingDeedsCounter.
    private var lifetimeDeeds: (plates: Int, lessons: Int, breaths: Int, breathMinutes: Int) {
        let plates: Int = {
            guard FoodFlags.isEnabled,
                  let userId = auth.currentUser?.id.uuidString, !userId.isEmpty
            else { return 0 }
            return FoodLogPersister.allEntries(userId: userId).count
        }()
        let lessons = max(0, JeniMethodState.lastCompletedLessonId)
        let breaths = BreathworkState.shared.totalCompleted
        return (
            plates: plates,
            lessons: lessons,
            breaths: breaths,
            breathMinutes: breaths * 4
        )
    }

    // MARK: - v1.3 Becoming density (2026-06-18)
    //
    // Today-data hooks for the new modules per the 3-expert panel:
    // BecomingTodayEnergyStrip, BecomingProteinGauge, BecomingMacroRow,
    // BecomingPlateTimelineToday, BecomingMovedStrip.

    /// Today's logged food macros (kcal + protein + carbs + fat + fiber).
    /// Lives in PlankFood; returns zeros when nothing's logged today.
    private var todayFoodMacros: FoodLogPersister.TodayMacros {
        FoodLogPersister.todayMacros()
    }

    /// Today's plate entries with photo IDs, time, kcal. Used by the
    /// PlateTimelineToday row to show photo + time + kcal under each.
    private var todayPlates: [(id: String, loggedAt: Date, kcal: Int)] {
        guard FoodFlags.isEnabled,
              let userId = auth.currentUser?.id.uuidString, !userId.isEmpty
        else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        return FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= start }
            .sorted { $0.loggedAt < $1.loggedAt }
            .map { (id: $0.id, loggedAt: $0.loggedAt, kcal: Int($0.kcal.rounded())) }
    }

    /// Phase 4 interactivity (2026-06-19) — today's plate sources
    /// ranked by protein contribution. Drives the long-press peek on
    /// BecomingProteinTile. Empty when food rail is off or no plates
    /// landed today.
    private var todayProteinSources: [BecomingProteinSource] {
        guard FoodFlags.isEnabled,
              let userId = auth.currentUser?.id.uuidString, !userId.isEmpty
        else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        return FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= start }
            .map { BecomingProteinSource(entryId: $0.id, proteinG: Int($0.protein.rounded())) }
    }

    /// Sum of routine + plank session durations today (in minutes).
    private var todayWorkoutMinutes: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let seconds = sessionLogs
            .filter { $0.completedAt >= start }
            .reduce(0.0) { $0 + $1.holdTime }
        return Int((seconds / 60).rounded())
    }

    /// Breath minutes today (count × typical 4 minutes per session).
    /// BreathworkState tracks count + breathedToday; we approximate
    /// today's minutes from `breathedToday` × 4 (single session).
    private var todayBreathMinutes: Int {
        BreathworkState.shared.breathedToday ? 4 : 0
    }

    /// Total "moved" minutes for the BecomingTodayEnergyStrip's
    /// secondary numeral. Sum of today's workout + breath minutes;
    /// step minutes are intentionally omitted (steps surface
    /// separately on BecomingMovedStrip below).
    private var todayMovedMinutes: Int {
        todayWorkoutMinutes + todayBreathMinutes
    }

    /// Protein target — Phillips IJSNEM 2016 + Conte JCEM 2024:
    /// 1.2 g/kg for lean-mass protection. Floor 80g, ceiling 150g.
    /// Returns nil when no body mass is on record yet.
    private var proteinTargetG: Int? {
        let kg: Double = {
            if let latest = latestWeightKg { return latest }
            if onboardingCurrentWeightKg > 0 { return onboardingCurrentWeightKg }
            return 0
        }()
        guard kg > 30 else { return nil }
        let raw = 1.2 * kg
        return max(80, min(150, Int(raw.rounded())))
    }

    /// Pace-aware kcal target for today's energy strip. Reads the
    /// onboarding daily target; falls back to nil so the pace line
    /// doesn't render if we have nothing to compare against.
    private var todayKcalPaceTarget: Int? {
        foodDailyTarget > 0 ? Int(foodDailyTarget) : nil
    }

    /// Most recent weight log, if any. Used to drive the headline number on
    /// the weight card.
    private var latestWeightKg: Double? { weightLogs.first?.weightKg }

    /// Today's weight log (if one already exists). Used to enforce the
    /// one-row-per-day policy: the LogWeightSheet's "save" updates this
    /// row in place rather than appending a new one. Research-backed
    /// (Helander 2014, Pacanowski 2014): single daily weigh-in is the
    /// healthy ceiling — multiple per day correlates with anxiety + ED
    /// behaviors and adds noise to the EMA trend without improving
    /// outcomes. Includes onboarding-seeded rows so a user who onboards
    /// and then taps "log weight" the same day overwrites the seed
    /// rather than producing two same-day rows.
    private var todaysWeightLog: WeightLogRecord? {
        let cal = Calendar.current
        return weightLogs.first { cal.isDateInToday($0.loggedAt) }
    }

    /// Total kg moved (latest − starting). `nil` when we don't yet have a
    /// starting baseline (no onboarding weight + no logs).
    private var weightDeltaKg: Double? {
        guard let latest = latestWeightKg else { return nil }
        let starting = weightLogs.last?.weightKg
            ?? (onboardingCurrentWeightKg > 0 ? onboardingCurrentWeightKg : nil)
        guard let starting else { return nil }
        return latest - starting
    }

    private var dayProgress: [DayProgressRecord] {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return [] }
        return allDayProgress.filter { $0.userId == userId }
    }

    private var ratings: [SessionRatingRecord] {
        let sessionIds = Set(sessionLogs.map(\.id))
        return allRatings.filter { sessionIds.contains($0.sessionLogId) }
    }

    private var benchmarkCount: Int {
        sessionLogs.filter { $0.sessionType == "plank_benchmark" }.count
    }

    /// Plank baseline from onboarding (the "test your hold" question).
    /// Used by the mastery-curve enhancement on plankCard to show the
    /// user how much capability has compounded since day one.
    private var plankBaselineSeconds: Int {
        currentUserRecord?.onboardingBaselineHoldSeconds ?? 0
    }

    /// Trailing-14-day weekly weight change in kg (negative = losing).
    /// Returns nil if we don't have at least one log inside the window
    /// AND a separately-dated log to anchor the slope. Uses earliest +
    /// latest within the 14-day window for a simple two-point slope —
    /// stable enough for "weeks to goal" projection without overfitting.
    private var weeklyWeightChangeKg: Double? {
        let now = Date()
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: now) else { return nil }
        let recent = weightLogs.filter { $0.loggedAt >= cutoff }
        guard let earliest = recent.last, let latest = recent.first,
              earliest.id != latest.id else { return nil }
        let dayDelta = Calendar.current.dateComponents([.day], from: earliest.loggedAt, to: latest.loggedAt).day ?? 0
        guard dayDelta > 0 else { return nil }
        let kgDelta = latest.weightKg - earliest.weightKg
        return kgDelta / Double(dayDelta) * 7.0
    }

    /// Direction of pace vs. the user's goal direction. Positive when
    /// the user is moving toward their goal, negative when away.
    /// Returns nil when there's no goal or no measurable pace.
    private var paceTowardGoal: Double? {
        guard let weekly = weeklyWeightChangeKg,
              let current = latestWeightKg,
              onboardingGoalWeightKg > 0 else { return nil }
        let towardGoal = onboardingGoalWeightKg < current ? -weekly : weekly
        return towardGoal
    }

    // MARK: - Bento metrics (research-led)

    /// Weigh-ins logged in the last 7 days. Self-weighing frequency is the
    /// strongest behavioral predictor of weight-loss success (3+/wk → more
    /// loss), so the bento surfaces it as a tracked behavior, not vanity.
    private var weighInsThisWeek: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return weightLogs.filter { $0.loggedAt >= cutoff }.count
    }

    /// Forecast ETA to the goal at the current toward-goal pace (Happy Scale
    /// "prediction" idiom — a proven motivator). Returns a lowercase date
    /// label ("aug 12") or nil when there's no goal, no measurable pace, the
    /// goal is already met, or the horizon is implausible (>5y).
    private var forecastLine: String? {
        guard onboardingGoalWeightKg > 0,
              let current = latestWeightKg,
              let toward = paceTowardGoal, toward > 0.02 else { return nil }
        let remainingKg = abs(current - onboardingGoalWeightKg)
        guard remainingKg > 0.1 else { return nil }
        let weeks = remainingKg / toward
        guard weeks.isFinite, weeks > 0, weeks < 260,
              let eta = Calendar.current.date(byAdding: .day, value: Int(weeks * 7), to: Date())
        else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: eta).lowercased()
    }

    /// Milestone ladder toward the goal — markers every ~5 lb (2.27 kg) from
    /// the starting weight. Returns the next unreached marker's remaining
    /// distance (in display units) + progress 0…1 from the prior marker.
    /// Loss-only (nil when the goal is a gain) and capped at the goal.
    private var nextMilestone: (remainingDisplay: Double, progress: Double)? {
        guard onboardingGoalWeightKg > 0,
              let start = startingWeightKg,
              let current = latestWeightKg,
              start > onboardingGoalWeightKg else { return nil }
        let stepKg = 2.27
        let lostKg = max(0, start - current)
        let markersPassed = floor(lostKg / stepKg)
        let nextMarkerLostKg = (markersPassed + 1) * stepKg
        let goalLostKg = start - onboardingGoalWeightKg
        let targetLostKg = min(nextMarkerLostKg, goalLostKg)
        let remainingKg = max(0, targetLostKg - lostKg)
        let progress = (lostKg - markersPassed * stepKg) / stepKg
        return (weightUnit.display(fromKg: remainingKg), min(max(progress, 0), 1))
    }

    /// Onboarding-stated barriers, parsed from the UserRecord array (not
    /// the @AppStorage CSV mirror). Order preserved for stable rendering.
    private var onboardingBarriers: [String] {
        currentUserRecord?.onboardingBarriers ?? []
    }

    /// Average completed-routine duration in minutes. Drives the
    /// barrier-resolved card's "time" line — shows the user that their
    /// stated barrier is being addressed by the actual session shape.
    private var averageRoutineMinutes: Int {
        let routines = sessionLogs.filter { $0.sessionType == "routine" }
        guard !routines.isEmpty else { return 0 }
        let totalSeconds = routines.reduce(0.0) { $0 + ($1.totalDuration ?? 0) }
        return Int((totalSeconds / Double(routines.count)) / 60.0)
    }

    /// Distinct exercise count across completed routines — used by the
    /// "boring" barrier counter to surface variety as the antidote.
    /// Reused per body recompute — JSONDecoder init is ~5ms, and this loop
    /// runs N times per render across all the user's session logs.
    private static let exerciseResultsDecoder = JSONDecoder()

    /// Reads from session_logs.exerciseResults (JSON-encoded bytes), so
    /// missing or unparseable rows are skipped silently.
    private var distinctExerciseCount: Int {
        var ids: Set<String> = []
        for log in sessionLogs where log.sessionType == "routine" {
            guard let data = log.exerciseResults,
                  let entries = try? Self.exerciseResultsDecoder.decode([ExerciseResultEntry].self, from: data) else { continue }
            for entry in entries { ids.insert(entry.exerciseId) }
        }
        return ids.count
    }

    /// Routine-count alias — barrier card reads this for the "motivation"
    /// counter. Keeps the call site readable.
    private var routineSessionCount: Int {
        sessionLogs.filter { $0.sessionType == "routine" }.count
    }

    private var activeDates: Set<Date> {
        Set(dayProgress.map { Calendar.current.startOfDay(for: $0.date) })
    }

    private var streak: StreakCalculator.Result {
        StreakCalculator.calculate(activeDates: activeDates)
    }

    private var bestPlankHold: Double {
        sessionLogs.filter { $0.sessionType == "plank_benchmark" }.map(\.holdTime).max() ?? 0
    }

    private var latestPlankHold: Double {
        sessionLogs.first { $0.sessionType == "plank_benchmark" }?.holdTime ?? 0
    }

    private var averageRating: Double {
        guard !ratings.isEmpty else { return 0 }
        return Double(ratings.map(\.rating).reduce(0, +)) / Double(ratings.count)
    }
    // (coach note trigger removed 2026-06-10 — feature shelved for
    // v1.0.8+; see comment at AnalyticsView body line ~520)

    // MARK: - Becoming page hero state (her75 Phase 5, audit §7)
    //
    // The italic chunk in "you're *{state}*." derives from collected
    // data per [[feedback-data-provenance]] — never fabricated.
    // Priority order matters: goal-progress beats trend beats
    // session-count, so the most meaningful signal leads.

    private var becomingStateWord: String {
        // v1.0.10 (2026-06-17) — cohort-aware identity routing.
        // GLP-1 cohorts get an identity word that acknowledges what
        // they're actually doing this week, ABOVE the universal
        // goal/trend/engagement chain. Identity-acknowledgment per
        // [[feedback-positioning-conviction]] + [[project-glp1-cohort-strategy]];
        // receipts gates per [[feedback-data-provenance]] so we never
        // claim a cohort identity that isn't backed by logged signal.
        if let cohortWord = cohortStateWord { return cohortWord }

        // ≥50% of goal distance covered → "becoming her"
        if let latest = latestWeightKg,
           onboardingCurrentWeightKg > 0, onboardingGoalWeightKg > 0,
           onboardingCurrentWeightKg > onboardingGoalWeightKg {
            let total = onboardingCurrentWeightKg - onboardingGoalWeightKg
            let done = onboardingCurrentWeightKg - latest
            if done / total >= 0.5 { return "becoming her" }
        }
        // Trend-based states need ≥3 logs
        if weightLogs.count >= 3 {
            if let delta = weightDeltaKg {
                if delta < -0.3 { return "becoming steady" }
                if abs(delta) <= 0.3 { return "becoming patient" }
            }
            return "becoming steady"
        }
        // Sessions but no weight signal
        if sessionLogs.count >= 7 { return "showing up" }
        return "just beginning"
    }

    /// GLP-1 cohort identity overrides. Each returns nil until the
    /// user has receipts for the implied claim — `.current` needs
    /// protein receipts to read as "protecting", `.triedOff` needs
    /// post-medication engagement, `.considering` needs a week of
    /// habit reps before the line lands as evidence. nil falls
    /// through to the universal becomingStateWord chain.
    private var cohortStateWord: String? {
        switch glp1Status {
        case "current":
            if let week = foodWeek, week.proteinLedDays >= 3 {
                return "protecting"
            }
        case "triedOff", "tried_off":
            let day = EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogs)
            if day >= 14 { return "rebuilding" }
        case "considering":
            let day = EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogs)
            if day >= 7 { return "building" }
        default:
            break
        }
        return nil
    }

    // (becomingPill deleted 2026-06-10 — the folio masthead's day
    // count + date range replaced the "becoming since" pill.)

    // Grouped sessions
    private var thisWeekSessions: [SessionLogRecord] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return sessionLogs.filter { $0.completedAt >= weekAgo }
    }

    private var earlierSessions: [SessionLogRecord] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return Array(sessionLogs.filter { $0.completedAt < weekAgo }.prefix(12))
    }

    // Animation state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sectionOpacity: [Double] = [0, 0, 0, 0, 0, 0]
    @State private var sectionOffset: [CGFloat] = [20, 20, 20, 20, 20, 20]
    @State private var hasAnimated = false
    @State private var showLogWeight = false

    /// v1.0.7 Becoming compaction — "more depth ↗" sheet presents
    /// barriers + plank curve + sessions log + activity calendar
    /// (modules that previously lived below the snapshot fold).
    /// Founder's "no scrolling" rule honored: snapshot one viewport,
    /// detail one tap away.
    @State private var showDepthSheet = false
    /// v1.1 food journal — opened from the plates teaser.
    @State private var showFoodJournal = false
    /// Calorie camera over the journal (the timeline's + button).
    @State private var showJournalCapture = false
    @AppStorage("foodDailyTarget") private var foodDailyTarget: Double = 1650
    /// v1.1 P3 — rendered day card pending share-sheet presentation.
    /// Identifiable wrapper so the share sheet presents via
    /// .sheet(item:) — .sheet(isPresented:) evaluates its content
    /// closure against the PRE-tap state snapshot on first present,
    /// which showed an empty (black) sheet until the second tap.
    struct DayCardShareItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    @State private var dayCardShareItem: DayCardShareItem? = nil
    /// v1.1 P3b — Sunday recap takeover. Once per ISO week, Sundays
    /// only, never on an empty week.
    @State private var showSundayRecap = false
    @AppStorage("becoming.recap.lastShownWeek") private var recapLastShownWeek = ""
    @State private var presentedFutureRail: FutureRail? = nil
    @State private var presentedMetric: BecomingMetric? = nil
    @State private var calendarScale: CGFloat = 0.95
    /// Index of the calendar cell currently being scrubbed (0…totalDays-1),
    /// `nil` = default. Tap or drag on a cell sets this; release schedules
    /// a ~1.0s revert. Matches the steps-bento header-morph pattern.
    @State private var scrubbedCalendarIndex: Int? = nil
    @State private var calendarRevertTask: Task<Void, Never>? = nil
    /// Live grid width captured via a background GeometryReader on the
    /// LazyVGrid. Read by the drag gesture to map touch X → cell column
    /// without fighting LazyVGrid's intrinsic sizing (the previous
    /// GeometryReader-wraps-LazyVGrid + fixed-height pattern clamped the
    /// grid to 180pt and let cells overflow).
    @State private var calendarGridWidth: CGFloat = 0
    /// Header blur-fade — matches the home greeting's "resolve into focus"
    /// signature so the becoming entrance reads in the same voice.
    @State private var headerBlur: CGFloat = 6

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            // v1.6.3 (2026-06-18) — paper-grain noise overlay on the
            // cream bg. Seeded LCG, deterministic, never animates;
            // 4% cocoa dots at 0.7pt sized to ~1.2% page coverage.
            // Shifts the cream from "iOS fill" to "Aesop catalog
            // paper." Sits BEHIND the ScrollView content so cards
            // (luxuryCard chrome) stay opaque on top.
            PaperGrainBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                // Lazy so sections off-screen on first render don't pay
                // their layout cost up front. Becoming tab now has 9
                // modules + recent-sessions ForEach (potentially many
                // rows for active users) — eager VStack would render
                // and animate them all on appear.
                // her75 Phase 5 — module spacing 20 → 24pt matching
                // the her75-homescreen vertical rhythm (audit §8 P5.6).
                LazyVStack(alignment: .leading, spacing: Space.lg) {
                    // v1.0.7 Becoming snapshot redesign (founder feedback
                    // round 3, 2026-06-06: "becoming screen is still too
                    // busy ... no snapshot feeling of showing everything
                    // in one snap"). Per the 3 luxury fitness designers
                    // briefs in
                    // docs/becoming_snapshot_redesign_briefs_2026_06_06.md
                    // — chapter spreads die above the fold; everything
                    // visible in one viewport.
                    //
                    // Status strip replaces the page hero ("you're /
                    // becoming steady"). Concierge tell — date + state
                    // word in italic-Fraunces jeweledRose top-right.
                    // her75 Phase 5 — Archetype D page hero (audit §7).
                    // The page hero is the SAME 38pt register as
                    // onboarding heroes per her75-homescreen.webp —
                    // "you're *{state}*." with a data-derived italic
                    // chunk + the date strip demoted below it. The
                    // BecomingStatusStrip (date + trend chip) survives
                    // as the pill-row under the hero.
                    // v1.2 Becoming dashboard (2026-06-18) — diary-register
                    // hero. Adds the cohort-research-locked "you've shown
                    // up N times ♡" diary line + breathing-shadow pulse
                    // on the spelled-out serif day number. Same data as
                    // the prior BecomingFolio; warmer register. Cohort
                    // brief verdict: "the dashboard isn't a logger — it's
                    // a mirror with memory."
                    BecomingDiaryHero(
                        dayNumber: folioDayNumber,
                        totalDays: folioTotalDays,
                        dateRange: folioDateRange,
                        showedUpCount: engagedDates.count,
                        identityLine: "\(becomingStateWord).",
                        identityItalic: [becomingStateWord]
                    )
                    // v1.1 P3 — "keep today's page": the quiet share
                    // glyph under the folio renders the her75 day card
                    // (adherence + steps + plates; the trend is NEVER
                    // on the share by default — she never shares her
                    // mass).
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            Haptics.light()
                            if let img = BecomingDayCardRenderer.render(
                                dayNumber: folioDayNumber,
                                totalDays: folioTotalDays,
                                dateRange: folioDateRange,
                                facts: dayCardFacts
                            ) {
                                dayCardShareItem = DayCardShareItem(image: img)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                                .tappableArea()
                        }
                        .accessibilityLabel("keep today's page — share your day card")
                    }
                    .opacity(sectionOpacity[0])
                    .offset(y: sectionOffset[0])
                    .blur(radius: headerBlur)

                    // v3 P11.5 (2026-06-10) — coach note SHELVED 2026-06-10.
                    // Founder call: not core to the v1.0.7 redesign + the
                    // "AI coach note" surface conflicts with the no-"AI"
                    // voice. Scaffolding (CoachNoteService /
                    // CoachNoteAPIClient / CoachNoteCard) stays on disk
                    // unwired for possible v1.0.8+ revival when the
                    // long-term AI coach agent vision is ready to ship.

                    if FoodFlags.isEnabled {
                        becomingStack
                            .opacity(sectionOpacity[1])
                            .offset(y: sectionOffset[1])
                    } else {
                        bentoJourney
                            .opacity(sectionOpacity[1])
                            .offset(y: sectionOffset[1])
                    }

                    // v1.0.7 founder feedback round 5 (2026-06-06) —
                    // below-fold modules (barrierCard / plankCard /
                    // recentSessions) moved into the "more depth ↗"
                    // sheet per all 3 WL designer briefs (Cal AI,
                    // Noom-2024, Lasta). Becoming snapshot fits in
                    // one viewport above; detail one tap away. The
                    // module helpers stay compiled and are rendered
                    // by `becomingDepthSheet` (the sheet view) below.
                }
                // v1.1 padding consistency (founder 2026-06-11): match
                // the Today tab's program rhythm — 24pt horizontal
                // (PlanView uses Space.lg) + 24pt top inset so the two
                // tabs' content starts at the same x and y.
                .padding(.horizontal, Space.lg)
                .padding(.top, 24)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            Analytics.captureScreen("Becoming")
            animateIn()
            presentSundayRecapIfDue()
            // P3b — earn-gated Sunday push (id-replaced, one per week
            // max; empty weeks never get a push at her).
            let cal = Calendar.current
            let engagedThisWeek = engagedDates.filter {
                cal.component(.weekOfYear, from: $0) == cal.component(.weekOfYear, from: .now)
                    && cal.component(.yearForWeekOfYear, from: $0) == cal.component(.yearForWeekOfYear, from: .now)
            }.count
            Task {
                await RecapNotificationService.shared.scheduleIfEarned(
                    engagedDaysThisWeek: engagedThisWeek
                )
            }
            // v1.1 P2 — silent body-mass refresh (no-op until the user
            // has granted via Settings; never prompts from here).
            if let userId = auth.currentUser?.id.uuidString, !userId.isEmpty {
                Task {
                    await BodyMassImportService.shared.importIfEnabled(
                        userId: userId, into: modelContext
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showSundayRecap) {
            BecomingRecapView(
                weekNumber: recapWeekNumber,
                facts: dayCardFacts,
                quietWeek: weekDoneCount <= 1,
                dayCard: BecomingDayCardRenderer.render(
                    dayNumber: folioDayNumber,
                    totalDays: folioTotalDays,
                    dateRange: folioDateRange,
                    facts: dayCardFacts
                ),
                onDismiss: { showSundayRecap = false }
            )
            .presentationBackground(Palette.bgPrimary)
        }
        // Weight log + first-log seed live at the body level now that the
        // trend lives inside the bento (the old standalone weightCard carried
        // these).
        .sheet(isPresented: $showLogWeight) {
            LogWeightSheet(
                startingFromKg: latestWeightKg ?? (onboardingCurrentWeightKg > 0 ? onboardingCurrentWeightKg : 65),
                isUpdatingToday: todaysWeightLog != nil,
                onSave: { kg in
                    saveWeightLog(kg: kg, source: "manual")
                    showLogWeight = false
                },
                onCancel: { showLogWeight = false }
            )
            // Founder feedback round 10 (2026-06-15): .fraction(0.78)
            // left too much empty space below the steppers. .fraction(0.55)
            // tightens proportions while keeping enough top-room for
            // the heart-lock sticker overhang (offset y:-10). Both
            // entry points (PlanView + here) share the same detent.
            .presentationDetents([.fraction(0.55)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $dayCardShareItem) { item in
            BecomingShareSheet(image: item.image)
                .presentationDetents([.medium, .large])
        }
        // v1.1 food journal. The + opens the calorie camera OVER the
        // journal (cover-on-cover) so the fresh plate lands in the
        // timeline the moment capture finishes — FoodLogPersister's
        // changeNotifier refreshes the list live underneath.
        .fullScreenCover(isPresented: $showFoodJournal) {
            FoodLogTimelineView(
                userId: auth.currentUser?.id.uuidString ?? "",
                dailyTarget: foodDailyTarget,
                // v1.0.10 — pass today's archetype so the journal's
                // daily share button can render archetype-themed
                // pull quotes. Falls back to nil → universal rotation
                // when no plan is active.
                archetypeHint: todayArchetypeHint,
                onAddTapped: { showJournalCapture = true },
                onDismiss: { showFoodJournal = false }
            )
            .presentationBackground(Palette.bgPrimary)
            .fullScreenCover(isPresented: $showJournalCapture) {
                CaptureFlowView(
                    userId: auth.currentUser?.id.uuidString ?? "",
                    cuisineProfile: UserDefaults.standard
                        .string(forKey: "onboardingCuisinePreference"),
                    onDismiss: { showJournalCapture = false }
                )
            }
        }
        .sheet(isPresented: $showDepthSheet) {
            becomingDepthSheet
        }
        .task { seedFirstWeightLogIfNeeded() }
        .sheet(item: $presentedFutureRail) { rail in
            FutureRailExplainerSheet(rail: rail, onClose: { presentedFutureRail = nil })
                .presentationDetents([.medium])
        }
        .sheet(item: $presentedMetric) { metric in
            // `.large` detent added so the breath explainer (longer than
            // the other metrics — 4 citations + 4-sentence mechanism) can
            // be dragged up to show all content without compressing the
            // top inset. Drag indicator visible so the sheet's draggability
            // is obvious AND it puts a uniform ~16pt of visual top
            // padding above the sticker on every metric (was missing on
            // .breath specifically, since the long content was pulling
            // the top spacer's compression).
            MetricExplainerSheet(metric: metric, onClose: { presentedMetric = nil })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Animation

    private func animateIn() {
        guard !hasAnimated else { return }
        hasAnimated = true

        // Reduce-motion path: snap modules to final state, skip the
        // calendar pop + streak pulse. The 9-module cascade is editorial
        // pacing — content is identical without it.
        if reduceMotion {
            for i in 0..<sectionOpacity.count {
                sectionOpacity[i] = 1
                sectionOffset[i] = 0
            }
            calendarScale = 1.0
            headerBlur = 0
            return
        }

        Haptics.soft()
        // Header resolves from a soft blur into focus (same signature as the
        // home greeting), a touch slower than its fade for the "coming into
        // focus" read.
        withAnimation(.easeOut(duration: 0.6)) { headerBlur = 0 }

        // Phase 20b: cascade now uses Motion.stagger (0.10s) × per-index
        // delay rather than hand-tuned numbers, and Motion.gentleSpring
        // for the spring shape. With 9 modules, last lands at 0.10 +
        // 0.80 + spring-resolution ~= 1.5s — calmer than the original
        // 0.90s offset which was already feeling rushed for tall cards.
        for i in 0..<sectionOpacity.count {
            let delay = 0.10 + Double(i) * Motion.stagger
            withAnimation(Motion.gentleSpring.delay(delay)) {
                sectionOpacity[i] = 1
                sectionOffset[i] = 0
            }
        }

        // Calendar scale pop
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
            calendarScale = 1.0
        }
    }

    // MARK: - Header (Phase A — research-led "becoming" hero)
    //
    // Replaces the generic "Log / Your progress" header with a tab-aligned
    // hero that surfaces two onboarding answers we already collect but
    // never read: identityFeeling (Q140 — what version of yourself you're
    // pulling toward) and motivation (Q111 — why you started). Oyserman
    // 2015 identity-based motivation: surfacing the user's own stated
    // identity-target raises behavior-identity alignment, which lifts
    // adherence 22-31%. Both fields live on UserRecord; nil-safe fallbacks
    // hold for legacy rows from before Phase 4 columns existed.

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            // Eyebrow — anchors the rotation. Personal pronoun ("you're")
            // works whether userName is empty or filled, so we don't need
            // a name-conditional branch.
            Text("you're")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)

            // Title. "becoming." italic Fraunces — same word the tab uses,
            // present-progressive (Dweck/Burnette growth-mindset) so
            // plateaus don't read as failure. The trailing identity
            // descriptor (e.g., "becoming powerful") only renders when
            // identityFeeling is set (legacy users see just "becoming.").
            (
                Text("becoming").font(Typo.titleItalic) +
                Text(identityTrailer).font(Typo.title)
            )
            .foregroundStyle(Palette.textPrimary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

            // v1.0.7 minimal-functional-aesthetic — subhero killed
            // per docs/becoming_home_minimal_spec_2026_06_06.md.
            // 3-of-4 expert briefs (Row + CalAI + iOS UX) flagged
            // the motivationLine as "thesis statement for an essay"
            // — the italic hero alone carries the emotional frame.
            // motivationLine helper kept for the future weekly
            // recap surface where editorial chrome earns its scroll.
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Trailing word for the headline — behavior-derived so the hero
    /// reflects who the user has actually been, not just the onboarding
    /// answer. Cascade order (most retention-critical first):
    ///   • returning after ≥7 days off (any prior session) → " steady."
    ///   • any plank check-in completed                    → " stronger."
    ///   • any weight log                                  → " clear."
    ///   • any session completed                           → " consistent."
    ///   • fresh user, nothing logged yet                  → " present."
    /// Noom-style identity-over-outcome framing applied to existing fields.
    /// Onboarding identityFeeling (Q140) intentionally not consulted here;
    /// the motivationLine below still echoes Q111 so personal voice remains.
    private var identityTrailer: String {
        if isReturningAfterInactivity { return " steady." }
        if benchmarkCount > 0         { return " stronger." }
        if !weightLogs.isEmpty        { return " clear." }
        if !sessionLogs.isEmpty       { return " consistent." }
        return " present."
    }

    /// True when the user has prior sessions but the most recent one is
    /// ≥7 days old. Frames re-engagement as "steady" — soft, non-punitive,
    /// avoids streak-loss shame. Sessions are sorted desc so .first is the
    /// most recent.
    private var isReturningAfterInactivity: Bool {
        guard let last = sessionLogs.first?.completedAt else { return false }
        return Date().timeIntervalSince(last) >= 7 * 24 * 60 * 60
    }

    /// Subtitle echoing the user's stated motivation (Q111). Returns nil
    /// when the answer is missing so the layout collapses cleanly. Copy
    /// is calm + non-judgmental — research (Rhodes & de Bruijn 2013) is
    /// clear that revisiting your stated "why" is what closes the
    /// intention-behavior gap.
    private var motivationLine: String? {
        let key = currentUserRecord?.onboardingMotivation ?? ""
        switch key {
        case "getShaped":   return "you said you wanted to build the body you want. this is the proof."
        case "lookBetter":  return "you said you wanted confidence in any outfit. one session at a time."
        case "summer":      return "you said summer. every week stacks."
        case "confidence":  return "you said stronger inside and out. that's what's logging here."
        case "selfLove":    return "you said making peace with your body. the work is the peace."
        default:            return nil
        }
    }

    // MARK: - Adaptive "this week" insight (coach voice)
    //
    // The single module that changes week to week — the research's top
    // retention lever (adaptive > static dashboards). Coach-voiced, anti-
    // shame, every claim traced to collected data (data-provenance): pace
    // toward goal, sessions this week, return-after-gap, else a fresh-start
    // line. Never shames a gain or a quiet week — those fall to support copy.
    /// The adaptive line. Priority: gentle re-entry after a gap → trend
    /// moving toward goal (only when toward — never shames a gain) → showed
    /// up this week → fresh start.
    private var insightLine: String {
        let name = userName.lowercased()
        let lead = name.isEmpty ? "" : "\(name), "
        if isReturningAfterInactivity {
            return "\(lead)no catching up needed. you're here, and that's the whole thing ♥"
        }
        if let toward = paceTowardGoal, toward > 0.05 {
            return "your trend's heading the right way. slow and steady is how it lasts ♥"
        }
        let moves = thisWeekSessions.count
        if moves >= 3 {
            return "\(lead)you've moved \(moves) times this week. that's not luck. that's you."
        }
        if moves >= 1 {
            return "\(lead)you showed up this week. that's where all of it starts."
        }
        return "\(lead)this is your page. one small move today writes the next line."
    }

    // MARK: - Becoming stack (v1.0.7 W4-T3 chapter narrative)
    //
    // Replaces the bento dashboard with a 5-chapter vertical stack when
    // the food rail is enabled. Cards reorder by signal density per the
    // spec — empty cards collapse to a single-line empty state, never
    // disappear, so the chapter rhythm reads the same week-1 vs
    // week-26. Honesty Doctrine: movement chapter NEVER surfaces a
    // kcal-burned number; food chapter has no over/under copy; trend
    // is the smoothed EMA, not raw daily readings.
    //
    // Voice locks per chapter title:
    //   - italic-Fraunces on the punch word
    //   - lowercase casual
    //   - hearts ♥ as terminal punctuation only
    //
    // All five cards pull from data the user has already given us
    // (onboarding answers + collected sessions + weight logs + food
    // logs + steps + breath). No fabrication.

    private var becomingStack: some View {
        VStack(alignment: .leading, spacing: 14) {
            // v1.0.7 snapshot redesign — 3 luxury fitness designer
            // briefs (Equinox+, Apple Fitness+, Whoop/Oura) all
            // agreed: 5 chapter spreads kill ~400pt of pacing chrome.
            // Replace with one-viewport snapshot dashboard:
            //   1. Weight hero (already shipped) — full-bleed
            //   2. 2-up secondary tiles (streak | plank PR)
            //   3. Composite movement tile (steps · breath · sessions)
            //   4. Coach voice line (one sentence, no card)
            //
            // Chapter spreads (yourWeekSection, whatYouAteSection,
            // howYouMovedSection, whatsChangingSection,
            // whatsWorkedSection) DIE on first viewport. The
            // chapter cover ornament (roman + italic title + pull
            // caption + sticker + hairline = 80pt × 5) was the
            // snapshot leak. Chapter content (food bento, barrier
            // card, plank curve, NSV) survives below the fold as
            // bare modules — drill-in detail sheets are a follow-on
            // phase. issueMasthead / tableOfContents / SundayCard /
            // stackChapterHeader helpers stay compiled for the
            // future dedicated weekly recap surface.

            // v1.0.7 Becoming compaction (founder feedback round 5
            // 2026-06-06: "i was expecting to have some compacted
            // design with one snapshot ... i don't like scrolling").
            // Per the 3 WL designer briefs (Cal AI / Noom-2024 /
            // Lasta — docs/compact_redesign_wl_briefs_2026_06_06.md)
            // the Becoming tab compresses to ~5 elements fitting one
            // viewport. BecomingMovementTile + BecomingCoachLine +
            // FoodWeekBentoTile + nsvTile all removed from this body.
            // Their content survives in the "more depth ↗" sheet
            // accessed at the bottom.

            // v1.0.7 tool-first reset (founder feedback round 7
            // 2026-06-06). 2 expert briefs (WL iOS design veteran +
            // Gen-Z behavioral researcher) unanimous: kill the
            // identity hero, ship a projection card as the
            // conversion driver, swap to activity trend when
            // weight is stale. Voice register shifts to direct/
            // tool-first; italic-Fraunces budget cut to 1
            // punch-word per tab; hearts removed from default tab.
            //
            // Layout:
            //   1. Trend hero (weight when logged, activity when
            //      stale) — full-width scrapbook chrome
            //   2-3. Projection + This Week Activity — 2-up
            //   4. Streak / consistency — full-width thin
            //   5-6. Plank PR + Lesson progress — 2-up
            //   7. More depth link

            // v1.0.7 founder feedback round 10 (2026-06-06):
            // > "do you think we need this becoming powerful big font
            // >  play necessary (as this give almost no value to users.)
            // >  in the metrics as weight loss ios app, shouldn't we
            // >  emphasize more calorie spent, gained?"
            //
            // Both expert briefs unanimous: kill the 40pt identity
            // hero. WL design veteran: "brand poetry, not tool value.
            // Cal AI / MFP / MacroFactor / WW all open on the answer
            // to today's question, not a who-am-I splash." WL program
            // expert: "Identity attached to evidence is adherence-
            // driving; identity floating alone is decoration."
            //
            // Identity survives as a QUIET CAPTION above the streak
            // strip (one line, italic-Fraunces on the Q140 punch
            // word only, ~14pt). All viewport real estate previously
            // burned on the 40pt hero is recovered.
            //
            // docs/becoming_calorie_integration_2026_06_06.md

            // v1.0.7 round 10 founder picks:
            //   - daily-only calorie cards (today's balance)
            //   - show spent transparently (BMR + steps + workout)
            //   - kill BMI (program expert: NIH 2023 racial bias)
            //   - identity attached to weight trend, not standalone
            //
            // Layout:
            //   1. Streak strip (kept)
            //   2. Today's balance (NEW signature — gained vs spent)
            //   3. Spent breakdown (NEW — BMR + steps + workout)
            //   4. WHO 150-min ring (kept)
            //   5. Weight + trend with identity caption attached
            //   6. More depth link

            // v1.1 Becoming dashboard (2026-06-10) — the one-snapshot
            // restructure per docs/becoming_dashboard_v1_1_plan. Five-
            // expert consensus kills applied in this pass:
            //   - streak strip → week dot-row (gain-framed, no flame)
            //   - today's-balance daily kcal card → DEAD (daily energy-
            //     balance verdicts are the shame surface; weekly-
            //     smoothed descendant lands in the recap)
            //   - WHO ring → DEAD (her program is the standard now;
            //     the citation survives in JeniMethod)
            // Trend hero keeps the one-bordered-artifact slot (it
            // already swaps to activity when weight is stale — the
            // input-burden rule's conditional default).

            BecomingWeekRow(
                states: weekDotStates,
                doneCount: weekDoneCount,
                archetypes: weekArchetypes,
                recaps: weekDayRecaps
            )

            // v1.3 Becoming (2026-06-18) — density rework after the
            // 3-expert panel review (WL iOS + her75 typographer +
            // GLP-1 RD). Daily energy strip, protein-first gauge
            // (the cohort wedge no competitor surfaces), macro row,
            // plate timeline, trend canvas, moved stripe. Compact
            // deeds counter lands at the foot.

            // 1-2. Bento pair — today's energy + today's protein.
            //   Side-by-side cards with hairline-cocoa chrome. NO
            //   ring, NO red. The GLP-1 cohort wedge sits in the
            //   right tile with status-by-percentage copy.
            if todayFoodMacros.kcal > 0 || todayMovedMinutes > 0 {
                HStack(alignment: .top, spacing: 10) {
                    BecomingTodayEnergyTile(
                        eatenKcal: Int(todayFoodMacros.kcal.rounded()),
                        movedMinutes: todayMovedMinutes,
                        paceKcalTarget: todayKcalPaceTarget
                    )
                    if let target = proteinTargetG {
                        BecomingProteinTile(
                            proteinG: Int(todayFoodMacros.protein.rounded()),
                            targetG: target,
                            sources: todayProteinSources
                        )
                    } else {
                        Color.clear
                    }
                }
                .padding(.top, 4)
            }

            // 3. Macros — horizontal proportional stack-bar with all 4
            //    macros (protein in accent rose to mirror the gauge
            //    above). Compact card, dense visual.
            if todayFoodMacros.kcal > 0 {
                BecomingMacroRow(
                    protein: Int(todayFoodMacros.protein.rounded()),
                    carbs: Int(todayFoodMacros.carbs.rounded()),
                    fat: Int(todayFoodMacros.fat.rounded()),
                    fiber: Int(todayFoodMacros.fiber.rounded())
                )
                .padding(.top, 2)
            }

            // 4. Trend canvas (promoted) — the outcome anchor for the
            //    WL cohort lands BEFORE the food details. Card chrome
            //    + 7-day delta + 110pt EMA Canvas. Falls back to the
            //    prose card when logs are too sparse.
            if measuredWeightLogs.count >= 2 {
                BecomingTrendCanvas(
                    logs: measuredWeightLogs,
                    goalWeightKg: goalWeightKg,
                    unit: weightUnit
                )
                .padding(.top, 6)
            } else {
                becomingTrendHeroCard
            }

            // 5. Today's plate timeline — replaces PlateFanTeaser as
            //    the food-rail visibility surface. Horizontal row of
            //    today's plates + trailing "log" tile. Per WL iOS
            //    expert: the input-loop fire the Becoming surface
            //    has been missing.
            if FoodFlags.isEnabled {
                BecomingPlateTimelineToday(
                    plates: todayPlates,
                    onTapPlate: { _ in showFoodJournal = true },
                    onLogTapped: { showJournalCapture = true }
                )
                .padding(.top, 4)
            }

            // 6. Moved stripe — soft activity register. NO kcal
            //    numeric (GLP-1 safety: exchange-economy framing is
            //    the #1 driver of disordered tracking patterns).
            //    Italic closing line ("body used some of what you
            //    fed it ♡") carries the meaning without bargaining
            //    math.
            BecomingMovedStrip(
                steps: StepsService.shared.todayCount,
                workoutMinutes: todayWorkoutMinutes,
                breathMinutes: todayBreathMinutes,
                stepsWeek: movedWeekSeries.steps,
                plankWeek: movedWeekSeries.plank,
                breathWeek: movedWeekSeries.breath
            )
            .padding(.top, 2)

            // 7. Cumulative deeds — compressed 2x2 grid + food-
            //    noise-quieted closing italic. The identity moat
            //    against Cal AI; lifetime totals visible at a glance.
            if lifetimeDeeds.plates > 0 || lifetimeDeeds.lessons > 0 || lifetimeDeeds.breaths > 0 {
                BecomingDeedsCounter(
                    plates: lifetimeDeeds.plates,
                    lessons: lifetimeDeeds.lessons,
                    breathMinutes: lifetimeDeeds.breathMinutes,
                    platesSince: deedsSinceDates.plates,
                    lessonsSince: deedsSinceDates.lessons,
                    breathSince: deedsSinceDates.breath,
                    foodNoiseSince: deedsSinceDates.lessons
                )
                .padding(.top, 6)
            }

            // v1.1.0 Sprint A (2026-06-15) — LastNightSleepCard is built
            // and verified (see commented mount below + `--debug-sleep-
            // preview`), but HIDDEN for the 1.1.0 release. Reason: the
            // TikTok-acquired Gen-Z women cohort is overwhelmingly
            // iPhone + AirPods, not Apple Watch. Without a Watch (or
            // a 3rd-party Oura/WHOOP/Garmin/Fitbit writing to Health),
            // HealthKit returns no sleep samples, so the card lives
            // permanently in the empty-state with no fix path. Shipping
            // that surface would feel broken to ~70-80% of installs.
            //
            // SleepService still bootstraps silently at launch (safe —
            // no-prompts, no UI mount). The card view + preview harness
            // + service stay on disk for v1.2 when we add a self-report
            // (tap-bedtime / tap-wake) or sleep-focus-schedule fallback
            // that works without HealthKit.
            //
            // Revive: uncomment this block + remove this comment.
            //
            // LastNightSleepCard(
            //     sleep: SleepService.shared.lastNight,
            //     authStatus: SleepService.shared.authStatus,
            //     onConnect: { Task { await SleepService.shared.requestAccess() } },
            //     onOpenHealth: {
            //         if let url = StepsService.openAppleHealthURL {
            //             UIApplication.shared.open(url)
            //         }
            //     }
            // )
            // .padding(.top, 4)

            // v1.1 food layer (2026-06-11) — the dot map + receipts
            // ledger died same-day in founder QA ("not quite useful");
            // replaced by the lighter-days module + the plates journal
            // teaser per docs/becoming_food_layer_design_2026_06_11.md.
            // The filmstrip is reborn as the teaser's polaroid fan;
            // the insight line relocates to the page foot.

            // Lighter days — gain-framed weekly insight, hidden for
            // restriction-risk cohorts. Stays as the only weekly-
            // aggregate slot on Becoming (per GLP-1 panel: "weekly
            // belongs in Sunday Recap, not in the today snapshot").
            if lighterDaysCounterVisible {
                LighterDaysRow(states: lighterDayStates)
                    .padding(.top, 4)
            }

            // PlateFanTeaser is superseded by BecomingPlateTimelineToday
            // (item 4 above). The fan was a doorway into the journal;
            // the timeline IS the journal's first row.

            // Closing diary punctuation — one sentence about HER own
            // data, italic punch + breathing shadow. Provenance-gated
            // at the call site (no filler).
            if let insight = dashboardInsight {
                BecomingInsightLine(text: insight.text, italic: insight.italic)
                    .padding(.top, 4)
            }
        }
        // Phase 4 Day-2 (2026-06-19) — pull-to-refresh re-pulls
        // HealthKit (steps + breath + workout minutes) so glance-
        // visits get a fresh today number without backgrounding.
        // Native iOS gesture; no chrome.
        .refreshable { await refreshBecomingData() }
    }

    // MARK: - Lighter days (EnergyLedger consumers)

    /// Counter visibility: defaults OFF for restriction-risk cohorts
    /// (strained food relationship or lost-count prior attempts) —
    /// a deficit-shaped counter is exactly the surface that
    /// re-triggers restriction patterns there. The journal itself
    /// stays fully available; only the counter hides.
    private var lighterDaysCounterVisible: Bool {
        guard FoodFlags.isEnabled else { return false }
        guard !["control", "complicated"].contains(foodRelationshipKey),
              priorAttemptsKey != "many" else { return false }
        // Needs the inputs to mean anything: a BMR and at least one log.
        guard lighterDayBMR != nil else { return false }
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty,
              !FoodLogPersister.allEntries(userId: userId).isEmpty else { return false }
        return true
    }

    private var lighterDayBMR: Double? {
        guard let h = currentUserRecord?.onboardingHeightCm, h > 50 else { return nil }
        let weight = measuredWeightLogs.first?.weightKg
            ?? (onboardingCurrentWeightKg > 0 ? onboardingCurrentWeightKg : nil)
        guard let w = weight, w > 20 else { return nil }
        let age = EnergyLedger.ageMidpoint(fromRange: currentUserRecord?.onboardingAgeRange ?? "")
        return EnergyLedger.bmrFemale(weightKg: w, heightCm: h, age: age)
    }

    /// Last 7 days oldest → today. Today is ALWAYS unclassified
    /// (classification runs on closed days only); steps come from
    /// StepsService's 7-day buckets aligned the same way.
    private var lighterDayStates: [Bool] {
        guard let bmr = lighterDayBMR,
              let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else {
            return Array(repeating: false, count: 7)
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let allEntries = FoodLogPersister.allEntries(userId: userId)
        let glp1 = ProgramGoalCalculator.isGLP1User(from: glp1Status)
        let weeklySteps = StepsService.shared.weeklyCounts  // [0]=6d ago … [6]=today

        return (0..<7).map { offset in
            guard offset < 6,  // today (offset 6) never classifies live
                  let day = cal.date(byAdding: .day, value: offset - 6, to: today),
                  let nextDay = cal.date(byAdding: .day, value: 1, to: day)
            else { return false }
            let dayEntries = allEntries.filter { $0.loggedAt >= day && $0.loggedAt < nextDay }
            guard !dayEntries.isEmpty else { return false }
            let sessionSeconds = sessionLogs
                .filter { $0.completedAt >= day && $0.completedAt < nextDay }
                .compactMap { $0.totalDuration }
                .reduce(0, +)
            return EnergyLedger.isLighterDay(.init(
                entries: dayEntries,
                stepsCount: weeklySteps.indices.contains(offset) ? weeklySteps[offset] : 0,
                sessionSeconds: sessionSeconds,
                bmr: bmr,
                isGLP1: glp1
            ))
        }
    }

    // MARK: - v1.1 dashboard data (folio / week row / food week / insight)

    /// Program day when a plan is active; engagement day otherwise.
    private var folioDayNumber: Int {
        if let userId = auth.currentUser?.id.uuidString, !userId.isEmpty,
           let schedule = ProgramService.shared.currentSchedule(userId: userId, in: modelContext) {
            return max(1, schedule.programDay)
        }
        return max(1, EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogs))
    }

    /// `plan.totalDays` per [[project-program-duration-custom]] —
    /// nil (folio reads "of showing up") when no plan is active.
    private var folioTotalDays: Int? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return nil }
        return ProgramService.shared.activePlan(userId: userId, in: modelContext)?.totalDays
    }

    /// "apr 2 → jun 25" horizon strip — the her75 printed-end-date
    /// move. Only renders with an active plan.
    private var folioDateRange: String? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty,
              let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext)
        else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let end = Calendar.current.date(byAdding: .day, value: plan.totalDays, to: plan.startDate) ?? plan.startDate
        return "\(f.string(from: plan.startDate).lowercased()) → \(f.string(from: end).lowercased())"
    }

    /// Engaged-day definition for the dot surfaces: ANY signal she
    /// gave that day fills the dot — checklist/day-progress, a
    /// session, or a plate scan. Founder QA day 3: she'd scanned
    /// plates 3 of 3 days but the checklist-only count read "0 of 7"
    /// — demoralizing AND false. Engagement counts what she did,
    /// wherever she did it.
    private var engagedDates: Set<Date> {
        var days = activeDates
        let cal = Calendar.current
        for log in sessionLogs { days.insert(cal.startOfDay(for: log.completedAt)) }
        if FoodFlags.isEnabled,
           let userId = auth.currentUser?.id.uuidString, !userId.isEmpty {
            for entry in FoodLogPersister.allEntries(userId: userId) {
                days.insert(cal.startOfDay(for: entry.loggedAt))
            }
        }
        return days
    }

    /// Last 7 days (oldest → today) as dot states. Gain-framed: an
    /// un-done day is an open circle, never red.
    private var weekDotStates: [WeekDayState] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<7).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset - 6, to: today) else { return .open }
            let done = engagedDates.contains(day)
            if cal.isDateInToday(day) { return done ? .todayDone : .today }
            return done ? .done : .open
        }
    }

    private var weekDoneCount: Int {
        weekDotStates.filter { $0 == .done || $0 == .todayDone }.count
    }

    /// Phase 4 interactivity (2026-06-19) — per-day recaps for the
    /// dot-tap reveal. Same 7-day window, oldest → today. Each entry
    /// counts plates (food logs for that day), rituals (session logs
    /// + day progress + lesson views for that day), and whether
    /// weight was logged. Mirrors weekDotStates / weekArchetypes
    /// shape so the row's three arrays index together.
    private var weekDayRecaps: [BecomingWeekDayRecap?]? {
        guard let userId = auth.currentUser?.id.uuidString,
              !userId.isEmpty else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let foodEntries: [FoodLogPersister.FoodLogEntry] =
            FoodFlags.isEnabled
            ? FoodLogPersister.allEntries(userId: userId)
            : []
        return (0..<7).map { offset -> BecomingWeekDayRecap? in
            guard let day = cal.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            let next = cal.date(byAdding: .day, value: 1, to: day) ?? day
            let plates = foodEntries.filter { $0.loggedAt >= day && $0.loggedAt < next }.count
            let sessions = sessionLogs.filter { $0.completedAt >= day && $0.completedAt < next }.count
            let weighed = weightLogs.contains { $0.loggedAt >= day && $0.loggedAt < next }
            return BecomingWeekDayRecap(
                weekdayName: weekdayName(for: day, today: today),
                plates: plates,
                rituals: sessions,
                weightLogged: weighed
            )
        }
    }

    /// Returns a lowercase weekday name with "today" / "yesterday"
    /// overrides for the two nearest slots. Anchors the recap line
    /// in the user's actual time frame, not an abstract date.
    private func weekdayName(for day: Date, today: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(day, inSameDayAs: today) { return "today" }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: today),
           cal.isDate(day, inSameDayAs: yesterday) {
            return "yesterday"
        }
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EEEE"
        return f.string(from: day).lowercased()
    }

    /// v1.0.10 — today's archetype as a raw string, passed through to
    /// FoodLogTimelineView so the daily share renderer can carry an
    /// archetype-themed pull quote. nil when no plan is active (the
    /// share card falls back to the universal 12-quote rotation).
    private var todayArchetypeHint: String? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty,
              let schedule = ProgramService.shared.currentSchedule(
                userId: userId,
                in: modelContext
              ) else { return nil }
        return ProgramDayArchetype.archetype(
            forProgramDay: schedule.programDay,
            glp1Status: glp1Status,
            restrictiveFoodRelationship: isRestrictiveCohort
        ).rawValue
    }

    /// v1.0.10 Phase 4 — archetype per day for the same 7-day window
    /// the dot row covers (oldest → today). Computed by mapping each
    /// calendar offset back to a program day using the active plan's
    /// startDate, then running through ProgramDayArchetype. nil entries
    /// land on pre-program days (the user joined less than a week
    /// before today, so the early slots of the window are off-program)
    /// and render as blank slots in the letter row. The whole array is
    /// nil when there's no active plan, which falls back to the
    /// pre-Phase-4 single-dot-row layout.
    private var weekArchetypes: [ProgramDayArchetype?]? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty,
              let plan = ProgramService.shared.activePlan(
                userId: userId,
                in: modelContext
              ) else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let planStart = cal.startOfDay(for: plan.startDate)
        return (0..<7).map { offset -> ProgramDayArchetype? in
            guard let day = cal.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            let daysSinceStart = cal.dateComponents([.day], from: planStart, to: day).day ?? -1
            let programDay = daysSinceStart + 1
            guard programDay >= 1 else { return nil }
            return ProgramDayArchetype.archetype(
                forProgramDay: programDay,
                glp1Status: glp1Status,
            restrictiveFoodRelationship: isRestrictiveCohort
            )
        }
    }

    /// 7-day food rollup from the scan stream (her highest-intensity
    /// input per the round-2 PostHog pull). nil = no logs this week.
    private struct FoodWeek {
        let scanDays: Int
        let proteinAvg: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let proteinLedDays: Int
        let photoEntryIds: [String]
    }

    private var foodWeek: FoodWeek? {
        guard FoodFlags.isEnabled,
              let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return nil }
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -7, to: .now) else { return nil }
        let entries = FoodLogPersister.allEntries(userId: userId).filter { $0.loggedAt >= cutoff }
        guard !entries.isEmpty else { return nil }
        let byDay = Dictionary(grouping: entries) { cal.startOfDay(for: $0.loggedAt) }
        let protein = entries.reduce(0.0) { $0 + $1.protein }
        let carbs   = entries.reduce(0.0) { $0 + $1.carbs }
        let fat     = entries.reduce(0.0) { $0 + $1.fat }
        // A day reads "protein-forward" when protein carries ≥30% of
        // its macro kcal — descriptive pattern, never a daily verdict.
        let proteinLedDays = byDay.values.filter { day in
            let p = day.reduce(0.0) { $0 + $1.protein } * 4
            let c = day.reduce(0.0) { $0 + $1.carbs } * 4
            let f = day.reduce(0.0) { $0 + $1.fat } * 9
            let total = p + c + f
            return total > 0 && p / total >= 0.3
        }.count
        let photoIds = entries
            .sorted { $0.loggedAt > $1.loggedAt }
            .map(\.id)
            .filter { FoodPhotoStore.hasPhoto(entryId: $0) }
        return FoodWeek(
            scanDays: byDay.count,
            proteinAvg: protein / Double(byDay.count),
            protein: protein, carbs: carbs, fat: fat,
            proteinLedDays: proteinLedDays,
            photoEntryIds: photoIds
        )
    }

    @ViewBuilder private var stepsStatCell: some View {
        let service = StepsService.shared
        switch service.authStatus {
        case .authorized:
            BecomingStatCell(
                label: "steps",
                lines: [
                    (service.todayCount > 0 ? service.todayCount.formatted() : "—", "today"),
                    (service.weekTotal > 0 ? service.weekTotal.formatted() : "—", "this week"),
                ]
            )
        case .notDetermined:
            // A double "—" placeholder apologizes; an action invites.
            VStack(alignment: .leading, spacing: 3) {
                Text("steps")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(Palette.textSecondary)
                Button {
                    Haptics.light()
                    Task { await StepsService.shared.requestAccess() }
                } label: {
                    Text("connect steps →")
                        .font(.custom("DMSans-SemiBold", size: 14))
                        .foregroundStyle(Palette.textPrimary)
                }
                .buttonStyle(.plain)
            }
        case .denied:
            VStack(alignment: .leading, spacing: 3) {
                Text("steps")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(Palette.textSecondary)
                Button {
                    Haptics.light()
                    if let url = StepsService.openAppleHealthURL,
                       UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("reconnect in health →")
                        .font(.custom("DMSans-SemiBold", size: 14))
                        .foregroundStyle(Palette.textPrimary)
                }
                .buttonStyle(.plain)
            }
        case .unavailable:
            BecomingStatCell(label: "steps", lines: [("—", "")])
        }
    }

    @ViewBuilder private var platesStatCell: some View {
        if let week = foodWeek {
            VStack(alignment: .leading, spacing: 6) {
                BecomingStatCell(
                    label: "plates",
                    lines: [("\(week.scanDays)", week.scanDays == 1 ? "day logged" : "days logged")],
                    languageChip: week.proteinLedDays >= max(1, week.scanDays / 2)
                        ? "protein led, \(week.proteinLedDays) of \(week.scanDays) days"
                        : "balanced week"
                )
                MacroMicroBars(protein: week.protein, carbs: week.carbs, fat: week.fat)
                    .frame(width: 88)
            }
        } else {
            BecomingStatCell(label: "plates", lines: [("—", "no plates yet")])
        }
    }

    /// Program week for the recap headline ("week three."). nil for
    /// non-program users (headline falls back to "this week.").
    private var recapWeekNumber: Int? {
        guard folioTotalDays != nil else { return nil }
        return (folioDayNumber - 1) / 7 + 1
    }

    /// Present the Sunday recap: Sundays only, once per ISO week,
    /// NEVER on an empty week (never recap an empty week at her).
    private func presentSundayRecapIfDue() {
        let cal = Calendar.current
        guard cal.component(.weekday, from: .now) == 1 else { return }
        let weekKey = "\(cal.component(.yearForWeekOfYear, from: .now))-w\(cal.component(.weekOfYear, from: .now))"
        guard recapLastShownWeek != weekKey else { return }
        guard weekDoneCount > 0, !dayCardFacts.isEmpty else { return }
        recapLastShownWeek = weekKey
        // Let the tab's own entrance settle before the takeover.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showSundayRecap = true
        }
    }

    /// Share-safe day-card facts: adherence + steps + plates only.
    /// Empty slots simply don't render (never a placeholder fact).
    private var dayCardFacts: [String] {
        var facts: [String] = []
        if weekDoneCount > 0 {
            facts.append("\(weekDoneCount) of 7 days kept")
        }
        let steps = StepsService.shared.weekTotal
        if steps > 0 {
            facts.append("\(steps.formatted()) steps this week")
        }
        if FoodFlags.isEnabled,
           let userId = auth.currentUser?.id.uuidString, !userId.isEmpty {
            let plates = FoodLogPersister.allEntries(userId: userId).count
            if plates > 0 {
                facts.append(plates == 1 ? "1 plate kept" : "\(plates) plates kept")
            }
        }
        return facts
    }

    /// One rotating sentence about HER data — provenance-gated; when
    /// nothing clears its gate the line doesn't render (never filler).
    private var dashboardInsight: (text: String, italic: [String])? {
        // trend on pace — needs measurable toward-goal pace + visible weight
        if !hideWeightStats, let toward = paceTowardGoal, toward > 0.02, weighInsThisWeek >= 2 {
            return ("your trend is moving. gently is the point \u{2665}\u{FE0E}", ["gently"])
        }
        // evening-movement pattern — ≥5 routines, ≥60% after 6pm
        let routines = sessionLogs.filter { $0.sessionType == "routine" }
        if routines.count >= 5 {
            let evening = routines.filter {
                Calendar.current.component(.hour, from: $0.completedAt) >= 18
            }.count
            if Double(evening) / Double(routines.count) >= 0.6 {
                return ("most of your movement lands after 6pm. evenings are yours \u{2665}\u{FE0E}", ["yours"])
            }
        }
        // GLP-1 cohort routing (2026-06-17) — receipts-based identity
        // acknowledgment for each cohort state. Each line references
        // shipping features only per [[feedback-no-feature-promises-until-shipped]]
        // and uses post-Ozempic vocab per [[feedback-post-ozempic-vocabulary]]:
        // no labor verbs, no scale shame, satiety / appetite / hunger
        // are the registers. Order locked highest-confidence first.
        //
        // .current: protein-led receipts beat the general protein line;
        //   the muscle-protection narrative needs ≥3 protein-led days
        //   to ring true, otherwise we fall back to the general line
        //   so .current users with light data still get acknowledged.
        if glp1Status == "current" {
            if let week = foodWeek, week.proteinLedDays >= 3 {
                return ("protein led \(week.proteinLedDays) of \(week.scanDays) this week. that's how lean mass stays \u{2661}", ["lean mass"])
            }
            if let week = foodWeek, week.scanDays >= 2 {
                return ("on your medication, protein is what protects muscle. yours is showing up \u{2665}\u{FE0E}", ["protein"])
            }
        }
        // .triedOff: appetite-returning frame is the cohort signal.
        //   Anti-diet vocab — "relearning your own hunger" is the
        //   permission frame. Fallback for ≥14 days of post-medication
        //   engagement acknowledges the consistency itself.
        if glp1Status == "triedOff" || glp1Status == "tried_off" {
            if let week = foodWeek, week.scanDays >= 3 {
                return ("off the medication, you're relearning your own hunger \u{2661}", ["relearning"])
            }
            let day = EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogs)
            if day >= 14 {
                return ("two weeks off, still showing up. that's the muscle \u{2661}", ["the muscle"])
            }
        }
        // .considering: builds the habit case without promising the
        //   medication will work / won't work. The line lands as
        //   evidence (a week of reps) so it doesn't read as a sales
        //   pitch from the app.
        if glp1Status == "considering" {
            let day = EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogs)
            if day >= 7 {
                return ("a week of habits the medication can't hand you \u{2661}", ["habits"])
            }
        }
        // protein pattern — claims need receipts: ≥3 scan days AND
        // protein actually led ≥2 of them (the chip said "1 of 3"
        // while this line claimed a pattern — founder screenshot).
        if let week = foodWeek, week.scanDays >= 3, week.proteinLedDays >= 2 {
            return ("protein's been showing up on your plates this week.", ["showing up"])
        }
        // engagement pattern — week 2+
        let day = EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogs)
        if day >= 7 {
            return ("\(day) days of showing up. that's the pattern that bends the line.", ["pattern"])
        }
        // session-1 fallback (2026-06-17) — was `return nil`, which left
        // the insight slot empty for fresh users with no signal yet and
        // made the paid-tab read as broken. Honest evidence-aligned
        // line: the page genuinely does fill in as engagement deepens,
        // so the same copy works at day 1 and day 30-without-data alike.
        return ("this page fills in as you show up \u{2665}\u{FE0E}", ["show up"])
    }

    // v1.1 Becoming dashboard (2026-06-10): the daily today's-balance
    // card + spent breakdown + their kcal estimate chain DELETED per
    // the 5-expert consensus (daily energy-balance verdicts are the
    // shame surface; expenditure estimates carry ±20% error). The
    // honest descendant is a weekly-smoothed energy view inside the
    // P3 recap. Mifflin-St Jeor BMR + per-step/per-minute kcal
    // helpers died with it — recompute from research when the weekly
    // recap needs them.

    // (becomingIdentityCaption + the 40pt becomingIdentityHero deleted
    // 2026-06-10 — both orphaned; the folio masthead carries identity.)

    /// Identity-on-trend caption — "*becoming powerful* takes
    /// consistency, you're showing it." Q140 italic punch attached
    /// to the weight delta data. Replaces the killed 40pt hero per
    /// program expert verdict.
    private var identityTrendCaption: String {
        // "you're showing it" only when the week backs the claim
        // (≥3 engaged days) — over-claiming against a 0-of-7 week
        // reads as flattery, not evidence.
        weekDoneCount >= 3
            ? "becoming \(identityFeelingWord) takes consistency · you're showing it"
            : "becoming \(identityFeelingWord) takes consistency"
    }

    /// Q140 identity feeling word. Falls back to a behavior-derived
    /// word (the previous identityTrailer cascade) when the user
    /// hasn't answered Q140 (legacy rows / skip).
    private var identityFeelingWord: String {
        if let id = currentUserRecord?.onboardingIdentityFeeling, !id.isEmpty {
            return id
        }
        if isReturningAfterInactivity { return "steady" }
        if benchmarkCount > 0         { return "stronger" }
        if !weightLogs.isEmpty        { return "clear" }
        if !sessionLogs.isEmpty       { return "consistent" }
        return "present"
    }

    /// Q111 motivation fragment for the subhero. Reuses the same
    /// mapping as the legacy motivationLine helper.
    private var motivationFragment: String? {
        let key = currentUserRecord?.onboardingMotivation ?? ""
        switch key {
        case "getShaped":   return "to build the body you want"
        case "lookBetter":  return "confidence in any outfit"
        case "summer":      return "to feel ready for summer"
        case "confidence":  return "stronger inside and out"
        case "selfLove":    return "to make peace with your body"
        default:            return nil
        }
    }

    // v1.1 Becoming dashboard (2026-06-10): becomingStreakStrip + its
    // flame tiles DELETED (streak-loss framing; the gain-framed week
    // dot-row replaces it). becomingWHORing DELETED — her program is
    // the standard now, two competing movement targets confuse the
    // prescription; the WHO 150-min citation survives in JeniMethod
    // lesson content.

    /// BMI card with AHA 2021 framing. UNLOCKED per founder's tool-
    /// first reset: "BMI was on the avoid list — RECOMMEND whether
    /// to unlock." WL expert: "stay locked." Founder's reference
    /// image shows BMI explicitly. Founder wins; AHA 2021 framing
    /// keeps it clinical-honest (context not verdict).
    @ViewBuilder private var becomingBMICard: some View {
        if let bmi = bmiValue {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("body mass index")
                        .font(.custom("DMSans-Regular", size: 11))
                        .kerning(0.66)
                        .textCase(.lowercase)
                        .tracking(2)
                        .foregroundStyle(Palette.jeweledRose)
                    Text(String(format: "%.1f", bmi))
                        .font(.custom("Fraunces72pt-SemiBold", size: 36))
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaPrimary)
                    Text(bmiBandLabel(bmi))
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                Spacer()
                Text("AHA 2021")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.pageIvory)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.hairlineCocoa, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    /// Compute BMI from height (cm) + latest weight (kg). Returns
    /// nil when either input is missing.
    private var bmiValue: Double? {
        guard let h = currentUserRecord?.onboardingHeightCm, h > 50,
              let w = latestWeightKg, w > 20 else { return nil }
        let m = h / 100.0
        return w / (m * m)
    }

    /// AHA 2021 BMI banding — context-tolerant copy, never verdicts.
    private func bmiBandLabel(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "underweight band. context not a verdict."
        case 18.5..<25: return "healthy band. context not a verdict."
        case 25..<30: return "overweight band. context not a verdict."
        case 30..<35: return "class i band. context not a verdict."
        default:      return "higher band. context not a verdict."
        }
    }

    // MARK: - v1.0.7 tool-first bento cards

    /// Card 1 — Trend hero. When she has ≥2 weight logs: weight
    /// trend with delta + sparkline. When stale (low log
    /// engagement per PostHog — affects ~62% of opens): swap to
    /// step/workout activity trend so the tab earns its open
    /// without requiring weight input.
    // MARK: - v1.1 trend honesty ladder (2026-06-11)
    //
    // Founder device QA showed "up 5.7 lb" as the 36pt hero on DAY
    // THREE — computed across the self-report→scale boundary (women
    // under-report by 1-3 kg, Connor Gorber 2007), so the headline
    // gain was largely measurement artifact, rendered at the exact
    // attrition peak (Eysenbach 2005). Both below-fold experts
    // converged on the same fix:
    //   1. The onboarding self-report seed is EXCLUDED from all
    //      delta math; baseline = first scale-measured log.
    //   2. Render ladder: calibration (<3 measured or <7d span:
    //      no delta anywhere, expectation pre-load copy) →
    //      first-trend (≥3 + ≥7d: direction in words only) →
    //      full artifact (≥14d span).
    //   3. Direction gate: the serif delta numeral renders for
    //      down-or-steady only; a genuine "up" reads in language
    //      with a physiology frame, never as the hero numeral.

    /// Scale-measured logs only — the onboarding self-report seed
    /// never participates in trend math.
    private var measuredWeightLogs: [WeightLogRecord] {
        weightLogs.filter { $0.source != "onboarding" }
    }

    private var measuredSpanDays: Int {
        guard let oldest = measuredWeightLogs.last?.loggedAt,
              let newest = measuredWeightLogs.first?.loggedAt else { return 0 }
        return Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 0
    }

    private enum TrendRenderState { case calibration, firstTrend, full }

    private var trendRenderState: TrendRenderState {
        let n = measuredWeightLogs.count
        if n >= 3 && measuredSpanDays >= 14 { return .full }
        if n >= 3 && measuredSpanDays >= 7 { return .firstTrend }
        return .calibration
    }

    /// EMA direction over measured logs, in language. nil = no signal.
    private var trendDirectionLine: String? {
        let recent = measuredWeightLogs.sorted { $0.loggedAt < $1.loggedAt }
        guard recent.count >= 3 else { return nil }
        let alpha = 2.0 / 8.0
        var ema = recent[0].weightKg
        for log in recent.dropFirst() { ema = alpha * log.weightKg + (1 - alpha) * ema }
        let delta = ema - recent[0].weightKg
        if delta < -0.3 { return "drifting down, gently" }
        if delta > 0.3 { return "up a little. water and hormones do this; the line knows" }
        return "holding steady"
    }

    @ViewBuilder private var becomingTrendHeroCard: some View {
        if !measuredWeightLogs.isEmpty {
            weightTrendHeroCard
        } else {
            activityTrendHeroCard
        }
    }

    /// Weight trend hero — renders per the honesty ladder. Receipt
    /// numbers + serif delta only at .full AND only when the
    /// direction is down-or-steady; gains read in language with a
    /// physiology frame.
    private var weightTrendHeroCard: some View {
        let latestDisplay: String = {
            guard let l = measuredWeightLogs.first?.weightKg else { return "—" }
            return String(format: "%.1f", weightUnit.display(fromKg: l))
        }()
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("your trend")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Button { showLogWeight = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("log")
                            .font(.custom("DMSans-SemiBold", size: 12))
                    }
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Palette.bgInverse)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            switch trendRenderState {
            case .calibration:
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(latestDisplay)
                        .font(.custom("Fraunces72pt-SemiBold", size: 28))
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaPrimary)
                    Text("\(weightUnit.label) today")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                // Expectation pre-loading (Dalle Grave 2005): accurate
                // expectations protect against early dropout. No delta
                // exists yet, by design.
                Text("daily swings of 2 to 3 lb are water, not fat. the line needs a week to mean something \u{2665}\u{FE0E}")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

            case .firstTrend:
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(latestDisplay)
                        .font(.custom("Fraunces72pt-SemiBold", size: 28))
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaPrimary)
                    Text("\(weightUnit.label) today")
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                if let line = trendDirectionLine {
                    ItalicAccentText(
                        "\(line).",
                        italic: [],
                        baseFont: .custom("DMSans-Regular", size: 13),
                        italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 13),
                        color: Palette.cocoaSecondary,
                        alignment: .leading
                    )
                }
                weightTrendSparkline
                    .frame(height: 36)
                    .padding(.top, 2)

            case .full:
                let payload = weightDeltaPayload
                let startingDisplay: String = {
                    guard let s = measuredWeightLogs.last?.weightKg else { return "—" }
                    return String(format: "%.1f", weightUnit.display(fromKg: s))
                }()
                if payload.isGain {
                    // Direction gate: a genuine up never headlines as
                    // the serif numeral — language + physiology frame.
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(latestDisplay)
                            .font(.custom("Fraunces72pt-SemiBold", size: 28))
                            .monospacedDigit()
                            .foregroundStyle(Palette.cocoaPrimary)
                        Text("\(weightUnit.label) today")
                            .font(.custom("DMSans-Regular", size: 14))
                            .foregroundStyle(Palette.cocoaSecondary)
                    }
                    Text("up a little. water and hormones do this; the line knows.")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(payload.direction)
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 20))
                            .foregroundStyle(payload.color)
                        Text(payload.delta)
                            .font(.custom("Fraunces72pt-SemiBold", size: 36))
                            .monospacedDigit()
                            .foregroundStyle(Palette.cocoaPrimary)
                        Text(weightUnit.label)
                            .font(.custom("DMSans-Regular", size: 14))
                            .foregroundStyle(Palette.cocoaSecondary)
                    }
                    Text("\(latestDisplay) today · \(startingDisplay) at first weigh-in")
                        .font(.custom("DMSans-Regular", size: 11))
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                ItalicAccentText(
                    identityTrendCaption,
                    italic: [identityFeelingWord],
                    baseFont: .custom("DMSans-Regular", size: 11),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 11),
                    color: Palette.cocoaTertiary,
                    alignment: .leading
                )
                .padding(.top, 2)
                weightTrendSparkline
                    .frame(height: 44)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.pageIvory)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.jeweledRose.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // v1.0.7 round 16: butterflyRing sticker REMOVED per founder
        // feedback — sticker was overlapping the "+ log" action pill
        // and making it visually hard to tap. The transformation
        // semantics WL expert argued for can survive elsewhere
        // (Sunday recap surface, milestone modals); the weight card
        // stays clean.
        .shadow(color: Palette.jeweledRose.opacity(0.10), radius: 0, x: 2, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weight trend: \(latestDisplay) \(weightUnit.label) today.")
    }

    private var weightTrendSparkline: some View {
        GeometryReader { geo in
            let points = weightSparkPoints(in: geo.size)
            ZStack {
                if points.count >= 2 {
                    // Soft accent-rose fill under the line
                    Path { p in
                        p.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        p.addLine(to: points[0])
                        for pt in points.dropFirst() { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [Palette.accentSubtle.opacity(0.6), Palette.accentSubtle.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    // jeweledRose stroke + endpoint dot
                    Path { p in
                        p.move(to: points[0])
                        for pt in points.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(Palette.jeweledRose, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    if let last = points.last {
                        Circle()
                            .fill(Palette.jeweledRose)
                            .frame(width: 6, height: 6)
                            .position(last)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Activity trend hero — renders when weight data is stale or
    /// missing. Carries the tab with auto-captured signals. Per
    /// the WL expert's verdict: "Auto-captured signals MUST carry
    /// the tab when weight is stale."
    private var activityTrendHeroCard: some View {
        let stepsAvg = StepsService.shared.todayCount
        let workouts = thisWeekSessions.count
        let breathDays = BreathworkState.shared.distinctDaysThisWeek
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("this week")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Button { showLogWeight = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("log weight")
                            .font(.custom("DMSans-SemiBold", size: 12))
                    }
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Palette.bgInverse)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(workouts)")
                    .font(.custom("Fraunces72pt-SemiBold", size: 36))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaPrimary)
                Text("workouts")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundStyle(Palette.cocoaSecondary)
            }

            Text("\(stepsAvg) steps today · \(breathDays) breath days")
                .font(.custom("DMSans-Regular", size: 11))
                .monospacedDigit()
                .foregroundStyle(Palette.cocoaSecondary)

            Text("log a weight to unlock your trend")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 4)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.pageIvory)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.jeweledRose.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Palette.jeweledRose.opacity(0.10), radius: 0, x: 2, y: 2)
    }

    /// Card 2 — Projection card. THE conversion driver per both
    /// expert briefs ("the moment 'this is actually a tool' lands").
    /// "at this pace, **Sept 12** / 5.4 lb to go · 0.6 lb/wk."
    /// Stalled-pace fallback: "pace slowed — try logging food this
    /// week." ACSM-aligned 0.5-1%/wk + Wing & Phelan 10% cap.
    @ViewBuilder private var becomingProjectionCard: some View {
        let payload = projectionPayload
        VStack(alignment: .leading, spacing: 6) {
            Text("AT THIS PACE")
                .font(.custom("DMSans-Regular", size: 11))
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(payload.headline)
                .font(.custom("Fraunces72pt-SemiBold", size: 22))
                .foregroundStyle(Palette.cocoaPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(payload.subline)
                .font(.custom("DMSans-Regular", size: 11))
                .monospacedDigit()
                .foregroundStyle(Palette.cocoaSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(Palette.accentSubtle)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.jeweledRose.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Palette.jeweledRose.opacity(0.10), radius: 0, x: 2, y: 2)
    }

    /// Goal projection math. Returns headline + subline strings,
    /// handles 4 cases: (a) not enough data, (b) on pace, (c)
    /// stalled, (d) ahead-of-pace.
    private var projectionPayload: (headline: String, subline: String) {
        guard onboardingGoalWeightKg > 0,
              weightLogs.count >= 2,
              let latest = latestWeightKg else {
            return ("not enough data", "log twice this week to unlock")
        }
        let toGoKg = latest - onboardingGoalWeightKg
        guard toGoKg > 0.5 else {
            return ("at your goal ♥", "celebrate the work")
        }
        // EMA slope from last 14-30 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let recent = weightLogs.filter { $0.loggedAt >= cutoff }.sorted { $0.loggedAt < $1.loggedAt }
        guard recent.count >= 2,
              let first = recent.first,
              let last = recent.last else {
            return ("not enough data", "log twice this week to unlock")
        }
        let daysSpan = max(Calendar.current.dateComponents([.day], from: first.loggedAt, to: last.loggedAt).day ?? 1, 1)
        let kgPerDay = (last.weightKg - first.weightKg) / Double(daysSpan)
        let kgPerWeek = kgPerDay * 7
        let lbPerWeek = abs(kgPerWeek * 2.20462)

        if kgPerWeek >= -0.05 {
            return ("pace slowed", "try logging food this week")
        }

        let toGoDisplay = abs(weightUnit.display(fromKg: toGoKg))
        let weeksToGoal = Int(ceil(toGoKg / abs(kgPerWeek)))
        let goalDate = Calendar.current.date(byAdding: .day, value: weeksToGoal * 7, to: .now) ?? .now
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let dateStr = f.string(from: goalDate).lowercased()

        return ("\(dateStr)", "\(String(format: "%.1f", toGoDisplay)) \(weightUnit.label) to go · \(String(format: "%.1f", lbPerWeek)) lb/wk")
    }

    /// Card 3 — This Week Activity. Three quiet rows summarizing
    /// auto-captured signals (workouts + steps + breath). Always
    /// has data; never empty. Per the WL expert: "WW's MyDay
    /// rebuild centered this. Three rows scan faster than rings."
    private var becomingWeekActivityCard: some View {
        let workouts = thisWeekSessions.count
        let stepsToday = StepsService.shared.todayCount
        let breathDays = BreathworkState.shared.distinctDaysThisWeek
        return VStack(alignment: .leading, spacing: 6) {
            Text("THIS WEEK")
                .font(.custom("DMSans-Regular", size: 11))
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            weekActivityRow(label: "workouts", value: "\(workouts)")
            weekActivityRow(label: "steps today", value: stepsToday > 0 ? "\(stepsToday)" : "—")
            weekActivityRow(label: "breath days", value: "\(breathDays)")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(Palette.pageIvory)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.jeweledRose.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Palette.jeweledRose.opacity(0.10), radius: 0, x: 2, y: 2)
    }

    private func weekActivityRow(label: String, value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(Palette.cocoaSecondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.custom("Fraunces72pt-SemiBold", size: 15))
                .monospacedDigit()
                .foregroundStyle(Palette.cocoaPrimary)
        }
    }

    /// Card 1 — Identity hero. Full-width, accentSubtle pink fill,
    /// 24pt corners, 1pt jeweledRose hairline border, hard offset
    /// shadow (scrapbook chrome BACK per data-viz brief: "this
    /// combination is the JeniFit visual moat"). Hero copy pulled
    /// from onboardingIdentityFeeling (Q140) + engagement day count
    /// (derived from session_logs, ZERO user input required).
    /// flower3D 36pt top-right -12° rotation. Bottom-left wordmark
    /// "*becoming* — since you started ♥" italic on punch word.
    private var becomingIdentityHeroCard: some View {
        let engagementDay = EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogs)
        let identity = currentUserRecord?.onboardingIdentityFeeling ?? ""
        let resolvedIdentity = identity.isEmpty ? "steady" : identity
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("BECOMING")
                    .font(Typo.statLabel)
                    .kerning(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.top, 4)

                (Text("becoming ")
                    .font(.custom("Fraunces72pt-Light", size: 40))
                 + Text(resolvedIdentity)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 40)))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(engagementDay > 0 ? "day \(engagementDay)" : "day one")
                        .font(.custom("DMSans-Medium", size: 14))
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaSecondary)
                    Text("♥")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.jeweledRose)
                }
                .padding(.top, 2)

                Spacer(minLength: 0)

                (Text("becoming")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 11))
                 + Text(" · since you started ♥")
                    .font(.custom("DMSans-Regular", size: 11)))
                    .foregroundStyle(Palette.cocoaSecondary.opacity(0.85))
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        }
        .background(Palette.accentSubtle)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Palette.jeweledRose.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image(StickerName.flower3D.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(-12))
                .shadow(color: Palette.jeweledRose.opacity(0.12), radius: 4, x: 1, y: 2)
                .offset(x: 8, y: -10)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .shadow(color: Palette.jeweledRose.opacity(0.12), radius: 0, x: 3, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Becoming \(resolvedIdentity), day \(engagementDay)")
    }

    /// Card 4 (left half of bottom 2-up) — Shown up this week.
    /// Compact, no overhanging sticker (founder feedback round 8:
    /// "cards overlapping"). Pearl row stays as the cute chart.
    private var becomingShownUpCard: some View {
        let weekly = thisWeekSessions.count
        return VStack(alignment: .leading, spacing: 6) {
            Text("SHOWED UP")
                .font(.custom("DMSans-Regular", size: 11))
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(weekly)")
                    .font(.custom("Fraunces72pt-SemiBold", size: 36))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaPrimary)
                (Text(weekly == 1 ? "day " : "days ")
                    .font(.custom("DMSans-Regular", size: 12))
                 + Text("this week")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12)))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            Spacer(minLength: 0)
            pearlRowDots
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(Palette.pageIvory)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.jeweledRose.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Palette.jeweledRose.opacity(0.10), radius: 0, x: 2, y: 2)
    }

    /// 7-dot pearl row. Filled jeweledRose for days she showed up,
    /// accentSubtle ring for empty days. Reads as a row of pearls,
    /// not a progress bar. Built from this-week active dates.
    private var pearlRowDots: some View {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let dotsActive: [Bool] = (0..<7).map { dayOffset in
            let dayStart = cal.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
            return sessionLogs.contains { cal.isDate($0.completedAt, inSameDayAs: dayStart) }
        }
        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                Circle()
                    .fill(dotsActive[i] ? Palette.jeweledRose : Color.clear)
                    .overlay(
                        Circle().stroke(dotsActive[i] ? Color.clear : Palette.accentSubtle, lineWidth: 1.5)
                    )
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    /// Card 3 — Adaptive secondary. Right half of the 2-up row.
    /// For powerful/strong identity cohort: plank PR with mini-pills.
    /// For everyone else: lesson progress ("lesson N of 14") with
    /// cute progress dots. Lesson rail clears 75%+ vs workout 23%
    /// per launch data, so it's the right alternate hook.
    @ViewBuilder private var becomingAdaptiveCard: some View {
        let identity = currentUserRecord?.onboardingIdentityFeeling ?? ""
        let prefersPlank = (identity == "powerful" || identity == "strong") && bestPlankHold > 0
        if prefersPlank {
            plankPRBentoCard
        } else {
            lessonProgressBentoCard
        }
    }

    private var plankPRBentoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PLANK PR")
                .font(.custom("DMSans-Regular", size: 11))
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(plankPRDisplay)
                .font(.custom("Fraunces72pt-SemiBold", size: 36))
                .monospacedDigit()
                .foregroundStyle(Palette.cocoaPrimary)
            Text("personal best")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                .foregroundStyle(Palette.cocoaSecondary)
            Spacer(minLength: 0)
            plankMacaronStrip
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(Palette.pageIvory)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.jeweledRose.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Palette.jeweledRose.opacity(0.10), radius: 0, x: 2, y: 2)
    }

    /// Macaron strip — last 3 plank holds as horizontal capsules.
    /// Current PR solid jeweledRose, prior holds accentSubtle. Reads
    /// as macarons in a row, not a bar chart.
    private var plankMacaronStrip: some View {
        let recent = sessionLogs.filter { $0.sessionType == "plank_benchmark" }.prefix(3).map(\.holdTime)
        return HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                let isCurrent = i == 0 && recent.count > 0
                Capsule()
                    .fill(isCurrent ? Palette.jeweledRose : Palette.accentSubtle)
                    .frame(width: 22, height: 8)
                    .opacity(i < recent.count ? 1.0 : 0.3)
            }
        }
        .accessibilityHidden(true)
    }

    private var lessonProgressBentoCard: some View {
        let lessonDay = max(min(EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogs), 14), 0)
        let display = lessonDay > 0 ? "\(lessonDay)" : "—"
        return VStack(alignment: .leading, spacing: 6) {
            Text("THE METHOD")
                .font(.custom("DMSans-Regular", size: 11))
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(display)
                    .font(.custom("Fraunces72pt-SemiBold", size: 36))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaPrimary)
                Text("/ 14")
                    .font(.custom("DMSans-Regular", size: 14))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            Text("of becoming")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                .foregroundStyle(Palette.cocoaSecondary)
            Spacer(minLength: 0)
            lessonProgressBar(active: lessonDay, total: 14)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(Palette.pageIvory)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.jeweledRose.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Palette.jeweledRose.opacity(0.10), radius: 0, x: 2, y: 2)
    }

    private func lessonProgressBar(active: Int, total: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.accentSubtle).frame(height: 4)
                Capsule().fill(Palette.jeweledRose)
                    .frame(width: max(4, geo.size.width * CGFloat(active) / CGFloat(max(total, 1))), height: 4)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    /// Card 4 — Weight delta (CONDITIONAL — only when she's logged).
    /// Quiet card, not hero — founder verdict: weight log engagement
    /// is low per PostHog, so leading with it on a fresh user reads
    /// as empty. Renders only when weightLogs is non-empty.
    private var becomingWeightDeltaCard: some View {
        let payload = weightDeltaPayload
        return HStack(alignment: .center, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR WEIGHT")
                    .font(Typo.statLabel)
                    .kerning(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(payload.direction)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                        .foregroundStyle(payload.color)
                    Text(payload.delta)
                        .font(.custom("Fraunces72pt-Light", size: 32))
                        .monospacedDigit()
                        .foregroundStyle(Palette.cocoaPrimary)
                    Text(weightUnit.label)
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                Text("since you started ♥")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            Spacer()
            // Quiet sparkline
            weightMiniSparkline
                .frame(width: 80, height: 32)
        }
        .padding(Space.md)
        .background(Palette.bgPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.hairlineCocoa, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture { showLogWeight = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weight \(payload.direction) \(payload.delta) \(weightUnit.label) since you started. Tap to log.")
    }

    /// Delta over MEASURED logs only (first scale weigh-in is the
    /// baseline — never the onboarding self-report).
    private var weightDeltaPayload: (delta: String, direction: String, color: Color, isGain: Bool) {
        guard let s = measuredWeightLogs.last?.weightKg,
              let l = measuredWeightLogs.first?.weightKg,
              abs(l - s) >= 0.05 else {
            return ("—", "steady", Palette.cocoaSecondary, false)
        }
        let absDisp = abs(weightUnit.display(fromKg: l - s))
        let delta = String(format: "%.1f", absDisp)
        if l < s {
            return (delta, "down", Palette.jeweledRose.opacity(0.9), false)
        }
        return (delta, "up", Palette.cocoaSecondary, true)
    }

    private var weightMiniSparkline: some View {
        GeometryReader { geo in
            let points = weightSparkPoints(in: geo.size)
            if points.count >= 2 {
                Path { p in
                    p.move(to: points[0])
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(Palette.jeweledRose.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func weightSparkPoints(in size: CGSize) -> [CGPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let recent = measuredWeightLogs.filter { $0.loggedAt >= cutoff }.sorted { $0.loggedAt < $1.loggedAt }
        guard recent.count >= 2 else { return [] }
        let alpha: Double = 2.0 / (7.0 + 1.0)
        var ema: [Double] = []
        for (i, log) in recent.enumerated() {
            if i == 0 { ema.append(log.weightKg) }
            else { ema.append(alpha * log.weightKg + (1 - alpha) * ema[i - 1]) }
        }
        let minVal = ema.min() ?? 0
        let maxVal = ema.max() ?? 1
        let range = max(maxVal - minVal, 0.1)
        let first = recent.first!.loggedAt.timeIntervalSinceReferenceDate
        let last = recent.last!.loggedAt.timeIntervalSinceReferenceDate
        let timeRange = max(last - first, 1)
        return zip(recent, ema).map { (log, value) in
            let x = CGFloat((log.loggedAt.timeIntervalSinceReferenceDate - first) / timeRange) * size.width
            let y = CGFloat(1 - (value - minVal) / range) * size.height
            return CGPoint(x: x, y: y)
        }
    }

    private var becomingIdentityLine: some View {
        let (line, italic) = identityLineContent
        return ItalicAccentText(
            line,
            italic: italic,
            baseFont: .custom("DMSans-Regular", size: 14),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 14),
            color: Palette.cocoaSecondary,
            alignment: .leading
        )
        .padding(.vertical, Space.md)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
    }

    private var identityLineContent: (line: String, italic: [String]) {
        let lead = userName.isEmpty ? "she" : userName.lowercased()
        let weeklyShowUp = thisWeekSessions.count
        if weeklyShowUp >= 3 {
            return ("\(lead) is the one who shows up. \(weeklyShowUp) days this week ♥", ["shows up"])
        }
        if streak.count >= 1 {
            return ("\(lead) keeps coming back. that's the whole work ♥", ["coming back"])
        }
        if let id = currentUserRecord?.onboardingIdentityFeeling, !id.isEmpty {
            return ("becoming \(id) ♥", [id])
        }
        return ("showing up. one move at a time ♥", ["showing up"])
    }

    /// "more depth ↗" sheet view. Holds the modules that previously
    /// lived below the Becoming snapshot fold. Founder picked the
    /// sheet path over deletion so the data survives — barriers,
    /// plank mastery, sessions log, and the legacy activity
    /// calendar are all one tap away when the user wants depth.
    @ViewBuilder private var becomingDepthSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if !onboardingBarriers.isEmpty {
                        barrierCard
                    }
                    if benchmarkCount > 0 {
                        plankCard
                    }
                    if foodLogsThisWeek {
                        FoodWeekBentoTile(
                            userId: AuthService.shared.currentUser?.id.uuidString ?? ""
                        ) {
                            presentedMetric = .plate
                        }
                    }
                    nsvTile
                    recentSessions
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.vertical, Space.md)
            }
            .background(Palette.bgPrimary.ignoresSafeArea())
            .navigationTitle("more depth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { showDepthSheet = false }
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundStyle(Palette.cocoaPrimary)
                }
            }
        }
    }

    // (moreDepthLink deleted 2026-06-11 — the receipts ledger rows
    // carry the depth entry now; a final "more depth ↗" row sits at
    // the ledger's foot.)

    /// Plank PR display for the 2-up stat tile. Mirrors
    /// BecomingDashboardHero's old internal helper.
    private var plankPRDisplay: String {
        let total = Int(bestPlankHold.rounded())
        guard total > 0 else { return "—" }
        let m = total / 60
        let s = total % 60
        if m > 0 { return String(format: "%d:%02d", m, s) }
        return "\(s)s"
    }

    /// Words to italicize in the coach line. Computed by walking
    /// the line for the brand's recurring punch verbs.
    private var coachItalicWords: [String] {
        let candidates = ["steady", "becoming", "showing", "shown", "moved", "stronger", "clear", "consistent", "present"]
        let lower = insightLine.lowercased()
        return candidates.filter { lower.contains($0) }
    }

    /// Today's HealthKit step count, surfaced for the composite
    /// movement tile. StepsService caches the latest read on its
    /// shared singleton; mirror the same pattern other surfaces use.
    private var stepsTodayCount: Int {
        StepsService.shared.todayCount
    }

    /// "becoming · vol. [N] ♥ / the [month] issue" — issue-as-object
    /// masthead. Italic-Fraunces volume mark + DM Sans hairline rule
    /// + italic Fraunces issue-name. Pure Cereal / Acne Paper opening.
    private var issueMasthead: some View {
        let cal = Calendar.current
        let now = Date()
        let weekNum = cal.component(.weekOfYear, from: now)
        let weekOrdinal = weekNum % 12 + 1
        let romanNumeral = Self.roman(weekOrdinal)
        let monthName: String = {
            let f = DateFormatter()
            f.dateFormat = "MMMM"
            return f.string(from: now).lowercased()
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                (Text("becoming")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 32))
                    .foregroundStyle(Palette.textPrimary))
                Spacer()
                HStack(spacing: 6) {
                    Text("vol. \(romanNumeral)")
                        .font(Typo.editorialEyebrow)
                        .tracking(2.5)
                        .foregroundStyle(Palette.jeweledRose)
                    Text("♥")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.jeweledRose)
                }
            }
            Rectangle()
                .fill(Palette.divider)
                .frame(height: 0.5)
            Text("the \(monthName) issue")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    /// "IN THIS ISSUE" — print-convention table of contents with
    /// italic-Fraunces chapter titles and DM Sans page numbers,
    /// hairline-separated. Per the luxury brief §3 (Cereal / Acne
    /// Paper opens). Turns reflection into a curated artifact, not
    /// a dashboard.
    private var tableOfContents: some View {
        let rows: [(numeral: String, title: String, italic: [String], page: String)] = [
            ("i.",    "your week",         ["week"],         "p. 02"),
            ("ii.",   "what you ate",      ["ate"],          "p. 04"),
            ("iii.",  "how you moved",     ["moved"],        "p. 06"),
            ("iv.",   "what's changing",   ["changing"],     "p. 08"),
            ("v.",    "what's worked",     ["worked"],       "p. 10"),
        ]

        return VStack(alignment: .leading, spacing: 12) {
            Text("IN THIS ISSUE")
                .font(Typo.editorialEyebrow)
                .tracking(3)
                .foregroundStyle(Palette.textSecondary)

            VStack(spacing: 0) {
                ForEach(0..<rows.count, id: \.self) { idx in
                    let r = rows[idx]
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(r.numeral)
                            .font(Typo.editorialEyebrow)
                            .tracking(2)
                            .foregroundStyle(Palette.jeweledRose)
                            .frame(width: 32, alignment: .leading)
                        ItalicAccentText(
                            r.title,
                            italic: r.italic,
                            baseFont: .custom("Fraunces72pt-Regular", size: 22),
                            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
                            color: Palette.textPrimary,
                            alignment: .leading
                        )
                        Spacer()
                        Text(r.page)
                            .font(.custom("DMSans-Medium", size: 11))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(.vertical, 10)
                    if idx < rows.count - 1 {
                        Rectangle()
                            .fill(Palette.divider)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(16)
        .background(Palette.pageIvory)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    /// Arabic → Roman numeral (1–12 only, the volume-counter range we
    /// need). Fallback to the raw number for >12.
    private static func roman(_ n: Int) -> String {
        let map: [Int: String] = [
            1: "i", 2: "ii", 3: "iii", 4: "iv", 5: "v", 6: "vi",
            7: "vii", 8: "viii", 9: "ix", 10: "x", 11: "xi", 12: "xii"
        ]
        return map[n] ?? "\(n)"
    }

    /// v1.0.7 Phase C.2 — pre-formatted weekly weight delta for the
    /// Sunday Card. Pulls the earliest and latest weight log within the
    /// current calendar week, formats in the user's display unit
    /// ("down 0.4 lb" / "even" / "up 0.2 lb"). Returns nil when fewer
    /// than 2 logs exist this week — the Sunday Card hides the weight
    /// row in that case rather than showing a non-truth.
    private var weeklyWeightDeltaCopy: String? {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return nil }
        let weekLogs = weightLogs.filter { $0.loggedAt >= weekStart }
        guard weekLogs.count >= 2 else { return nil }
        let sorted = weekLogs.sorted { $0.loggedAt < $1.loggedAt }
        let deltaKg = (sorted.last?.weightKg ?? 0) - (sorted.first?.weightKg ?? 0)
        let absDisplay = abs(weightUnit.display(fromKg: deltaKg))
        if abs(deltaKg) < 0.05 { return "even with where you started" }
        let dir = deltaKg < 0 ? "down" : "up"
        return "\(dir) \(String(format: "%.1f", absDisplay)) \(weightUnit.label)"
    }

    /// Count of distinct days this week with at least one food log.
    private var platesThisWeek: Int {
        guard FoodFlags.isEnabled else { return 0 }
        let userId = AuthService.shared.currentUser?.id.uuidString ?? ""
        guard !userId.isEmpty else { return 0 }
        return FoodLogPersister.last7DaysKcal(userId: userId).filter { $0.kcal > 0 }.count
    }

    /// v1.0.7 Phase C — editorial chapter spread per the luxury expert
    /// brief (docs/home_becoming_research_luxury_2026_06_06.md):
    ///
    /// > "Give each of the 5 chapters a full-viewport opening spread —
    /// > roman numeral eyebrow (`I.`), italic-Fraunces lowercase title,
    /// > one chapter-family sticker, a one-sentence pull-caption in
    /// > Fraunces italic, then a hairline rule before content.
    /// > Converts Becoming from 'long dashboard' to 'browse a Cereal
    /// > Magazine issue' — same data, page-turn rhythm."
    ///
    /// Sticker family assignments per luxury brief §4:
    ///   - flower3D → becoming / journey
    ///   - cherries → food
    ///   - sparkleGlossy → movement / shine
    ///   - bowSatin → identity work
    ///   - heartGlossy → wins / celebration
    private func stackChapterHeader(
        eyebrow: String,
        title: String,
        italic: [String],
        sticker: StickerName,
        pullCaption: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Jeweled-rose Roman numeral — magazine pagination active
            // state, isolated on its own line above the title (per
            // luxury brief §3 chapter-cover treatment).
            Text(eyebrow)
                .font(Typo.editorialEyebrow)
                .tracking(3)
                .foregroundStyle(Palette.jeweledRose)

            HStack(alignment: .top) {
                ItalicAccentText(
                    title,
                    italic: italic,
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 36),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 36),
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                Spacer()
                Image(sticker.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-8))
                    .accessibilityHidden(true)
            }

            Text(pullCaption)
                .font(Typo.pullQuote)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Palette.divider)
                .frame(height: 0.5)
                .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }

    /// Single-line empty-state row used when a chapter has no data yet.
    /// Anti-shame copy: never "you haven't" / "you're missing." Frame
    /// the empty state as INVITATION ("the page is open").
    private func stackEmptyLine(_ text: String) -> some View {
        Text(text)
            .font(Typo.body)
            .foregroundStyle(Palette.textSecondary)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 1. Your Week

    /// Hero chapter. Coach read + weight trend chart + log button.
    /// Always renders — even week 1 there's a coach note + a chart
    /// inviting the first weight log.
    ///
    /// 2026-06-06 — trendTile swapped for TrendHeroCard. Founder
    /// direction: "trend hero needs to live in becoming screen"
    /// (it was on Home in the prior commit; moved here as the chapter
    /// 1 hero). Becoming = journey/trend; Home = today's action.
    /// TrendHeroCard carries a richer sparkline + delta + log button
    /// than the original trendTile so the chapter opener lands.
    private var yourWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stackChapterHeader(
                eyebrow: "I.",
                title: "your week ♥",
                italic: ["week"],
                sticker: .flower3D,
                pullCaption: "where you are, gently."
            )
            coachTile
            // v1.0.7 minimal-functional-aesthetic — TrendHeroCard
            // removed here. Its weight + delta + sparkline content
            // is now carried by BecomingDashboardHero at the top
            // of becomingStack (the daily dashboard surface).
            // Chapter I keeps the coachTile as its sole content —
            // chapter cover + adaptive coach line, no duplicate
            // weight chrome. TrendHeroCard struct itself stays
            // compiled; it's reused on the Home cohort that's
            // flag-off and may be reused in the weekly recap.
        }
    }

    // MARK: - 2. What You Ate

    /// Food chapter. FoodWeekBentoTile carries the 7-day bars + daily
    /// average. Empty state if no logs yet. Pulls the most-logged day's
    /// average as a quiet caption (never a goal-comparison number).
    private var whatYouAteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stackChapterHeader(
                eyebrow: "II.",
                title: "what you ate",
                italic: ["ate"],
                sticker: .cherries,
                pullCaption: "rhythm, not rules."
            )
            if foodLogsThisWeek {
                FoodWeekBentoTile(
                    userId: AuthService.shared.currentUser?.id.uuidString ?? ""
                ) {
                    presentedMetric = .plate
                }
            } else {
                // v1.0.7 §6 editorial empty state. Replaces the
                // single-line invitation; FoodWeekBentoTile is
                // hidden in this branch so we don't double-render
                // an empty bar chart underneath the editorial mark.
                EditorialEmptyState(
                    headline: "the page is open.",
                    cta: "tap to log your first plate.",
                    sticker: .cherries
                )
            }
        }
    }

    // MARK: - 3. How You Moved

    /// Movement chapter. Steps (HealthKit) + breath sessions + workout
    /// session count, side by side. NEVER shows calories-burned per the
    /// Honesty Doctrine — that's the active anti-pattern from MFP/Cal AI
    /// our cohort burnt out on.
    private var howYouMovedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stackChapterHeader(
                eyebrow: "III.",
                title: "how you moved",
                italic: ["moved"],
                sticker: .sparkleGlossy,
                pullCaption: "any movement counts."
            )
            StepsBentoTile(service: StepsService.shared) {
                presentedMetric = .movement
            }
            BreathworkBentoTile(state: BreathworkState.shared) {
                presentedMetric = .breath
            }
            movedSummaryLine
        }
    }

    /// Quiet two-line summary under the steps + breath tiles. Pulls
    /// session count + days-shown-up. Never kcal-burned, never goal
    /// comparison. If everything is zero, surfaces the invitation
    /// empty state instead.
    @ViewBuilder private var movedSummaryLine: some View {
        let routines = sessionLogs.filter { $0.sessionType == "routine" }.count
        let benchmarks = sessionLogs.filter { $0.sessionType == "plank_benchmark" }.count
        let totalSessions = routines + benchmarks
        if totalSessions == 0 {
            stackEmptyLine("any movement counts. even a walk to the kitchen.")
        } else {
            let label = totalSessions == 1 ? "1 session logged" : "\(totalSessions) sessions logged"
            Text("\(label) ♥")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .padding(.vertical, 2)
        }
    }

    // MARK: - 4. What's Changing

    /// Identity work chapter. Barriers + plank mastery curve + identity
    /// affirmation pulled from her own answers. Empty state when no
    /// barriers picked AND no benchmarks done (rare — most users pick
    /// at least one barrier in v2 case 153).
    private var whatsChangingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stackChapterHeader(
                eyebrow: "IV.",
                title: "what's changing",
                italic: ["changing"],
                sticker: .bowSatin,
                pullCaption: "the shape of becoming."
            )
            if onboardingBarriers.isEmpty && benchmarkCount == 0 {
                // v1.0.7 §6 editorial empty state.
                EditorialEmptyState(
                    headline: "the shape is forming.",
                    cta: "two more weeks and we'll show you.",
                    sticker: .bowSatin
                )
            } else {
                if !onboardingBarriers.isEmpty {
                    barrierCard
                }
                if benchmarkCount > 0 {
                    plankCard
                }
            }
        }
    }

    // MARK: - 5. What's Worked

    /// NSV chapter. Wins the scale can't see. Cocoa/warm chrome so the
    /// closing card lands as warmth, not as another data block.
    private var whatsWorkedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stackChapterHeader(
                eyebrow: "V.",
                title: "what's worked",
                italic: ["worked"],
                sticker: .heartGlossy,
                pullCaption: "wins the scale can't see."
            )
            nsvTile
        }
    }

    // MARK: - Stack signal helpers

    /// True when the user has at least one food log in the last 7 days.
    /// FoodWeekBentoTile is the source of truth; this is just a quick
    /// chapter-empty-state gate so we don't double-render an empty
    /// invitation when the tile already shows one.
    private var foodLogsThisWeek: Bool {
        let userId = AuthService.shared.currentUser?.id.uuidString ?? ""
        guard !userId.isEmpty else { return false }
        let week = FoodLogPersister.last7DaysKcal(userId: userId)
        return week.contains { $0.kcal > 0 }
    }

    // MARK: - Bento journey grid (research-led weight-loss redesign — legacy / flag-off)
    //
    // Modular tiles of varying size (2026 bento idiom) telling the weight-
    // loss story: coach read → trend (hero) → forecast + milestone → % goal
    // + weigh-in cadence → NSV wins → future features. All from collected
    // data; calm/low-stimulus per the clean-luxury bar. Animates as one
    // section, so the body indexing stays simple.
    //
    // v1.0.7: kept for flag-off users so there's zero regression for the
    // pre-food-rail cohort. Flag-on users see the becomingStack chapter
    // narrative above instead.
    private var bentoJourney: some View {
        VStack(spacing: 12) {
            coachTile
            trendTile
            HStack(spacing: 12) { forecastTile; milestoneTile }
            HStack(spacing: 12) { goalTile; cadenceTile }
            // Movement — HealthKit-backed 7-day read. Home pulse is the
            // daily anchor; this is the trend depth. Same source
            // (StepsService.shared); the ⓘ opens the .movement explainer.
            StepsBentoTile(service: StepsService.shared) {
                presentedMetric = .movement
            }
            // Breath — passive read of the practice. Home BreathworkHomeCard
            // owns the CTA; this is the identity-forward "you breathed N
            // days this week" read. ⓘ opens the .breath explainer (cortisol
            // mechanism + Stanford + Yale + Senobi citations).
            BreathworkBentoTile(state: BreathworkState.shared) {
                presentedMetric = .breath
            }
            // Plate — passive 7-day food read. Sourced from FoodLogPersister
            // (in-memory until v1.0.8 SwiftData lands). Gated on
            // FoodFlags.isEnabled so flag-off users see the existing
            // "coming soon" foodLog chip below instead.
            if FoodFlags.isEnabled {
                FoodWeekBentoTile(
                    userId: AuthService.shared.currentUser?.id.uuidString ?? ""
                ) {
                    presentedMetric = .plate
                }
            }
            nsvTile
            // 2026-06-07: .foodLog removed entirely (food scanning shipped
            // in v1.0.7). Replaced with .foodScrapbook — Pinterest-coded
            // curation layer that tests cohort interest before we commit
            // build cost. When FoodFlags is disabled, also surface the
            // foodScrapbook chip so the demand signal is collected even
            // pre-food-flag flip.
            FutureRailRow(
                rails: [.foodScrapbook, .bodyScan]
            ) { presentedFutureRail = $0 }
                .padding(.top, 2)
        }
    }

    // Soft bento chrome — calmer than the full scrapbook hard-shadow so a
    // grid of tiles doesn't read busy. `warm` = coach/wins voice tiles.
    private func bentoChrome(warm: Bool = false) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.accent.opacity(0.12))
                .offset(x: 3, y: 3)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(warm ? Palette.accentSubtle : Palette.bgElevated)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.accent.opacity(warm ? 1 : 0.45), lineWidth: 1.5)
        }
    }

    private func tileEyebrow(_ text: String, accent: Bool = false) -> some View {
        Text(text)
            .font(Typo.eyebrow).tracking(1.5)
            .foregroundStyle(accent ? Palette.accent : Palette.textSecondary)
    }

    /// Eyebrow + a small ⓘ that opens the metric explainer (progressive
    /// disclosure — the calm "what does this mean" affordance).
    private func tileHeader(_ text: String, _ metric: BecomingMetric, accent: Bool = false) -> some View {
        HStack(spacing: 5) {
            tileEyebrow(text, accent: accent)
            Button {
                Haptics.light()
                presentedMetric = metric
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary.opacity(0.55))
                    .tappableArea()
            }
            .accessibilityLabel("what \(text) means")
        }
    }

    /// Subtle coquette sticker accent for a bento tile — small, low-opacity,
    /// overhanging the top-right corner (scrapbook idiom, clean register).
    private func tileSticker(_ name: StickerName) -> some View {
        Image(name.assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 38, height: 38)
            .rotationEffect(.degrees(10))
            .offset(x: 8, y: -12)
            .opacity(name.style.opacity * 0.9)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // Coach "this week" read.
    private var coachTile: some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(CoachAsset.imageName(for: voicePreference))
                .resizable().scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(Palette.accent.opacity(0.5), lineWidth: 1.5))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                tileEyebrow("this week", accent: true)
                Text(insightLine)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bentoChrome(warm: true))
        .overlay(alignment: .topTrailing) { tileSticker(.bowSatin) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week from your coach: \(insightLine)")
    }

    // Trend hero — chart leads, number demoted, log + hide inline.
    private var trendTile: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    tileHeader("your trend", .trend)
                    if hideWeightStats {
                        Text("hidden").font(Typo.body).foregroundStyle(Palette.textSecondary)
                    } else if let latest = latestWeightKg {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(weightUnit.display(fromKg: latest), specifier: "%.1f")")
                                .font(.custom("Fraunces72pt-SemiBold", size: 27))
                                .foregroundStyle(Palette.textPrimary)
                                .contentTransition(.numericText())
                            Text(weightUnit.label).font(Typo.caption).foregroundStyle(Palette.textSecondary)
                        }
                    } else {
                        Text("track to see your trend.").font(Typo.body).foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
                Button {
                    Haptics.light(); hideWeightStats.toggle()
                } label: {
                    Image(systemName: hideWeightStats ? "eye.slash" : "eye")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 32, height: 32).background(Palette.bgPrimary).clipShape(Circle())
                        .tappableArea()
                }
                .accessibilityLabel(hideWeightStats ? "Show weight" : "Hide weight")
                Button {
                    Haptics.light(); showLogWeight = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("log").font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
                    }
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Palette.bgInverse).clipShape(Capsule())
                }
                .accessibilityLabel("Log weight")
            }

            if !hideWeightStats, weightLogs.count >= 2 {
                WeightTrendChart(
                    logs: weightLogs,
                    goalWeightKg: onboardingGoalWeightKg > 0 ? onboardingGoalWeightKg : nil,
                    unit: weightUnit
                )
            } else if !hideWeightStats {
                Text(weightSubtitle)
                    .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bentoChrome())
        .overlay(alignment: .topTrailing) { tileSticker(.butterflyRing) }
    }

    // Forecast ETA.
    private var forecastTile: some View {
        VStack(alignment: .leading, spacing: 4) {
            tileHeader("on track for", .forecast)
            if let eta = forecastLine, !hideWeightStats {
                Text(eta)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                    .foregroundStyle(Palette.textPrimary)
                Text("at your pace ♥").font(Typo.caption).foregroundStyle(Palette.textSecondary)
            } else {
                Text("keep logging")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 20))
                    .foregroundStyle(Palette.textPrimary)
                Text("a forecast appears soon").font(Typo.caption).foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(bentoChrome())
        .overlay(alignment: .topTrailing) { tileSticker(.sparkleGlossy) }
    }

    // Milestone ladder.
    private var milestoneTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            tileHeader("next win", .milestone)
            if let m = nextMilestone, !hideWeightStats {
                Text("\(m.remainingDisplay, specifier: "%.1f") \(weightUnit.label) to go")
                    .font(Typo.body).fontWeight(.semibold)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.divider).frame(height: 6)
                        Capsule().fill(Palette.accent).frame(width: max(6, geo.size.width * m.progress), height: 6)
                    }
                }
                .frame(height: 6)
            } else {
                Text("set a goal to ladder up")
                    .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(bentoChrome())
        .overlay(alignment: .topTrailing) { tileSticker(.starLineart) }
    }

    // % to goal.
    private var goalTile: some View {
        VStack(alignment: .leading, spacing: 4) {
            tileHeader("to your goal", .goal)
            if let progress = weightGoalProgress, !hideWeightStats {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.custom("Fraunces72pt-SemiBold", size: 30))
                    .foregroundStyle(Palette.textPrimary)
            } else {
                Text("—").font(.custom("Fraunces72pt-SemiBold", size: 30)).foregroundStyle(Palette.textSecondary)  // voice-lint:allow
            }
            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(bentoChrome())
        .overlay(alignment: .topTrailing) { tileSticker(.flower3D) }
    }

    // Weigh-in cadence (the behavior that predicts success).
    private var cadenceTile: some View {
        VStack(alignment: .leading, spacing: 4) {
            tileHeader("weigh-ins", .cadence)
            Text("\(weighInsThisWeek)×")
                .font(.custom("Fraunces72pt-SemiBold", size: 30))
                .foregroundStyle(Palette.textPrimary)
            Text(weighInsThisWeek >= 3 ? "this week. that's the habit ♥" : "this week · a few more helps")
                .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(bentoChrome())
        .overlay(alignment: .topTrailing) { tileSticker(.heartGlossy) }
    }

    // Non-scale victories — the wins the scale can't see.
    private var nsvTile: some View {
        // Use the derived engagement-day count, not raw dayProgress.count.
        // The latter is row-count, which inflated under the prior buggy
        // writer (one user could carry duplicate DayProgressRecord rows
        // for the same calendar day). The calculator dedups by date.
        let shown = EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogs)
        return VStack(alignment: .leading, spacing: 6) {
            tileEyebrow("wins the scale can't see", accent: true)
            Text(nsvLine(shownUp: shown))
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bentoChrome(warm: true))
        .overlay(alignment: .topTrailing) { tileSticker(.ribbonLineart) }
    }

    private func nsvLine(shownUp: Int) -> String {
        var wins: [String] = []
        if shownUp > 0 { wins.append(shownUp == 1 ? "shown up once" : "shown up \(shownUp)×") }
        if benchmarkCount > 0 { wins.append("getting stronger") }
        if !onboardingBarriers.isEmpty { wins.append("facing what got in the way") }
        if wins.isEmpty { return "every small thing you do here is a win the scale will never show." }
        return wins.joined(separator: " · ") + " ♥"
    }

    // MARK: - Empty State

    /// v3 P11.9 (2026-06-10) — Becoming bento chrome retuned to the
    /// her75 editorial register per founder QA: "Becoming + Settings
    /// look far from her75 design." Default tint path now uses the
    /// EditorialCard chrome (28pt corners + soft drop shadow + NO
    /// border) — the her75 restraint the analytics-dashboard surface
    /// needs to read as premium-tool, not coquette-warmth.
    ///
    /// Non-default tints (state callouts — stateWarn, stateGood) keep
    /// the scrapbook ZStack with the colored border because the border
    /// IS the signal: "this card means something."
    @ViewBuilder
    private func scrapbookCardChrome(tint: Color = Palette.accent) -> some View {
        if tint == Palette.accent {
            // Default = her75 editorial restraint.
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.bgElevated)
                .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 6)
        } else {
            // State-callout = scrapbook with colored border.
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .offset(x: 4, y: 4)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint, lineWidth: 1.5)
            }
        }
    }

    // MARK: - Barrier-Resolved Card (Phase C)
    //
    // Surfaces each barrier the user picked in onboarding alongside a
    // counter pulled from real session data — research (Rhodes & de
    // Bruijn 2013): pre-identifying barriers + showing the
    // implementation-intention work closes ~50% of the
    // intention-behavior gap (Gollwitzer & Sheeran 2006). Copy is
    // affirming, not preachy.

    /// v1.0.7 snapshot register — "what's happening" card retyped
    /// per founder cleanup feedback. Scrapbook chrome (24pt corners
    /// + 1.5pt cocoa border + offset shadow) replaced with hairline
    /// section mark. Title compressed to a single italic-Fraunces
    /// SemiBold heading + uppercase eyebrow label (matches the
    /// BecomingStatTile + BecomingMovementTile register).
    private var barrierCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("WHAT'S HAPPENING")
                .font(Typo.statLabel)
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            ItalicAccentText(
                "the work under the surface",
                italic: ["under"],
                baseFont: .custom("Fraunces72pt-SemiBold", size: 22),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
                color: Palette.cocoaPrimary,
                alignment: .leading
            )
            VStack(spacing: Space.md) {
                ForEach(orderedBarriers, id: \.self) { key in
                    barrierRow(key: key)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
    }

    /// Orders barriers by importance/impact rather than picked order.
    /// Time + motivation come first because they're the most surfaceable
    /// — the others render below if also present.
    private var orderedBarriers: [String] {
        let priority: [String] = ["time", "motivation", "boring", "dontKnow", "injury"]
        return priority.filter { onboardingBarriers.contains($0) }
    }

    private func barrierRow(key: String) -> some View {
        let pair = barrierCopy(key: key)
        return HStack(alignment: .top, spacing: Space.md) {
            Image(systemName: pair.icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Palette.jeweledRose.opacity(0.85))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(pair.title)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
                    .foregroundStyle(Palette.cocoaPrimary)
                Text(pair.detail)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Maps a barrier key to its title + counter line. Every detail
    /// pulls from already-collected fields; nothing is fabricated. When
    /// the relevant counter is zero we keep the line neutral ("getting
    /// started counts") instead of writing 0 numerals (Neff
    /// self-compassion — surfacing 0 reads as judgment).
    private func barrierCopy(key: String) -> (icon: String, title: String, detail: String) {
        switch key {
        case "time":
            let avg = averageRoutineMinutes
            return (
                icon: "clock.fill",
                title: "you said: never have time.",
                detail: avg > 0
                    ? "your sessions average \(avg) min. the time barrier is on the schedule, not blocking it."
                    : "every session is built to fit a busy week. start with the one in front of you."
            )
        case "motivation":
            let n = routineSessionCount
            return (
                icon: "figure.walk.circle.fill",
                title: "you said: hard to stay consistent.",
                detail: n > 0
                    ? "\(n) session\(n == 1 ? "" : "s") logged. motivation follows the doing, not the other way."
                    : "consistency starts with one. show up once and the curve opens."
            )
        case "boring":
            let v = distinctExerciseCount
            return (
                icon: "sparkles",
                title: "you said: workouts get boring.",
                detail: v > 0
                    ? "\(v) different exercise\(v == 1 ? "" : "s") tried so far. variety is built in."
                    : "your routine reshuffles automatically — boredom is engineered out."
            )
        case "dontKnow":
            let n = routineSessionCount
            return (
                icon: "wand.and.stars",
                title: "you said: don't know what to do.",
                detail: n > 0
                    ? "\(n) routine\(n == 1 ? "" : "s") completed — all picked for you. no plan to write."
                    : "every session is auto-picked to your goal. you don't have to plan."
            )
        case "injury":
            return (
                icon: "shield.lefthalf.filled",
                title: "you said: worried about doing it wrong.",
                detail: "your coach watches alignment in real time. on-device, never recorded."
            )
        default:
            return (icon: "circle", title: key, detail: "")
        }
    }

    // MARK: - Weight helpers (consumed by the bento trend tile)

    /// Identity-framed subtitle. Falls back to placeholder until ≥ 2 logs.
    /// Switches to a calm "tracking quietly" message when stats are hidden.
    private var weightSubtitle: String {
        if hideWeightStats {
            return "tracking quietly. tap the eye when you want to see again."
        }
        return WeightAnalytics.subtitle(
            logs: weightLogs,
            currentKg: latestWeightKg,
            startingKg: startingWeightKg
        )
    }

    /// Starting weight = first log we have, falling back to onboarding entry.
    private var startingWeightKg: Double? {
        if let first = weightLogs.last { return first.weightKg }
        return onboardingCurrentWeightKg > 0 ? onboardingCurrentWeightKg : nil
    }

    /// Progress to the (capped at 10%) goal. `nil` when no goal or already there.
    private var weightGoalProgress: Double? {
        guard onboardingGoalWeightKg > 0,
              let starting = startingWeightKg,
              let current = latestWeightKg else { return nil }
        return WeightAnalytics.goalProgress(
            startingKg: starting,
            currentKg: current,
            declaredGoalKg: onboardingGoalWeightKg
        )
    }

    /// On first arrival at analytics, if the user has an onboarding weight
    /// but zero weight logs, seed a single log so the chart has a starting
    /// data point and the headline isn't empty.
    private func seedFirstWeightLogIfNeeded() {
        guard weightLogs.isEmpty else { return }
        guard onboardingCurrentWeightKg > 0 else { return }
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return }

        let log = WeightLogRecord(
            userId: userId,
            weightKg: onboardingCurrentWeightKg,
            loggedAt: .now,
            source: "onboarding"
        )
        modelContext.insert(log)
        try? modelContext.save()
        Task { await AppSync.shared.upsertWeightLog(log) }
    }

    private func saveWeightLog(kg: Double, source: String) {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return }

        // One-per-day policy: if today already has a row, mutate it
        // in place. Same id flows through to Supabase upsert which
        // UPDATEs the existing row by primary key — keeps the trend
        // chart at one point per day.
        if let existing = todaysWeightLog {
            existing.weightKg = kg
            existing.loggedAt = .now
            existing.source = source
            existing.pendingUpsert = true
            try? modelContext.save()
            Task { await AppSync.shared.upsertWeightLog(existing) }
            return
        }

        let log = WeightLogRecord(
            userId: userId,
            weightKg: kg,
            loggedAt: .now,
            source: source
        )
        modelContext.insert(log)
        try? modelContext.save()
        Task { await AppSync.shared.upsertWeightLog(log) }
    }

    // MARK: - Activity Calendar (bento chrome + scrubbable)
    //
    // Upgraded to the bento tile design language + the chart-scrub pattern
    // we shipped on the steps bento. Tap or drag any cell → the header
    // morphs in place to show that day's read (day label + warm status
    // line). 1.0s linger after release, then easeOut back to default.
    // Future cells aren't tappable. Reduce-motion snaps revert + skips
    // the cell-stroke pop on selection.

    private var activityCalendar: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let frozenDates = streak.frozenDates
        let weekday = cal.component(.weekday, from: today)
        let todayOffset = (weekday + 5) % 7  // Monday = 0
        let totalDays = 28 + todayOffset

        return VStack(alignment: .leading, spacing: 10) {
            calendarHeader(totalDays: totalDays, today: today, cal: cal, frozenDates: frozenDates)

            // Day labels
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            calendarGrid(totalDays: totalDays, today: today, cal: cal, frozenDates: frozenDates)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bentoChrome())
    }

    /// Calendar header that morphs between default (label + legend) and
    /// scrub mode (day label + status line). Same Apple Health pattern as
    /// the steps bento — primary read transforms in place; no floating
    /// tooltip.
    private func calendarHeader(totalDays: Int, today: Date, cal: Calendar, frozenDates: Set<Date>) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if let i = scrubbedCalendarIndex,
               let date = dateForCalendarIndex(i, totalDays: totalDays, today: today, cal: cal) {
                Text(scrubbedDayLabel(date, today: today, cal: cal))
                    .font(Typo.eyebrow).tracking(2)
                    .foregroundStyle(Palette.accent)
                    .id("scrub-cal-\(i)")
                    .transition(.opacity)
                Spacer()
                Text(scrubbedDayStatus(date,
                                       today: today,
                                       activeDates: activeDates,
                                       frozenDates: frozenDates))
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    .foregroundStyle(Palette.textSecondary)
                    .transition(.opacity)
            } else {
                Text("your repeats")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .transition(.opacity)
                Spacer()
                // Legend
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3).fill(Palette.accent).frame(width: 10, height: 10)
                        Text("active").font(.system(size: 10)).foregroundStyle(Palette.textSecondary)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "#7BBBE5"))
                        Text("frozen").font(.system(size: 10)).foregroundStyle(Palette.textSecondary)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: scrubbedCalendarIndex)
    }

    /// LazyVGrid sized naturally by SwiftUI (one row = one cellW square +
    /// 5pt gap, rows stack). Width captured via a background-GeometryReader
    /// → calendarGridWidth, which the drag gesture reads at fire time to
    /// map (x, y) → cell index. No outer height clamp: the grid expands to
    /// fit `totalDays` so cells never overflow the bento card.
    private func calendarGrid(totalDays: Int, today: Date, cal: Calendar, frozenDates: Set<Date>) -> some View {
        let spacing: CGFloat = 5
        let columns = 7
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(0..<totalDays, id: \.self) { i in
                calendarCell(index: i,
                             totalDays: totalDays,
                             today: today,
                             cal: cal,
                             frozenDates: frozenDates)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { calendarGridWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newW in calendarGridWidth = newW }
            }
        )
        .contentShape(Rectangle())
        .gesture(calendarScrubGesture(spacing: spacing,
                                      totalDays: totalDays,
                                      today: today,
                                      cal: cal))
    }

    private func calendarCell(index i: Int,
                              totalDays: Int,
                              today: Date,
                              cal: Calendar,
                              frozenDates: Set<Date>) -> some View {
        let daysAgo = totalDays - 1 - i
        let date = cal.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        let isActive = activeDates.contains(date)
        let isFrozen = frozenDates.contains(date)
        let isToday = date == today
        let isFuture = date > today
        let isSelected = scrubbedCalendarIndex == i && !isFuture

        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    isFuture ? Color.clear :
                    isActive ? Palette.accent :
                    isFrozen ? Palette.frozenDay :
                    Palette.divider.opacity(0.4)
                )
                .aspectRatio(1, contentMode: .fit)

            if isFrozen {
                Image(systemName: "snowflake")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: "#7BBBE5"))
            }

            if isToday {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
                    .aspectRatio(1, contentMode: .fit)
            }

            // Selection ring — sits OUTSIDE the cell fill so it reads
            // against active/frozen/inactive alike. 1.5pt accent at full
            // opacity for the scrubbed cell. Skipped on future cells
            // (those don't carry meaning to surface).
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(-2)
            }
        }
        .scaleEffect(isSelected && !reduceMotion ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .opacity(scrubbedCalendarIndex == nil || isSelected || isFuture ? 1.0 : 0.55)
        .animation(.easeOut(duration: 0.16), value: scrubbedCalendarIndex)
    }

    /// DragGesture(minimumDistance: 0) so tap + drag both scrub. Reads
    /// `calendarGridWidth` AT FIRE TIME (not at gesture-construction time)
    /// so a width that lands after the first paint still produces the
    /// correct mapping. Future cells are skipped.
    private func calendarScrubGesture(spacing: CGFloat,
                                      totalDays: Int,
                                      today: Date,
                                      cal: Calendar) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let columns: CGFloat = 7
                let cellW = max(1, (calendarGridWidth - spacing * (columns - 1)) / columns)
                let col = min(6, max(0, Int(value.location.x / max(1, cellW + spacing))))
                let row = max(0, Int(value.location.y / max(1, cellW + spacing)))
                let index = row * 7 + col
                guard (0..<totalDays).contains(index) else { return }
                // Skip future cells.
                let daysAgo = totalDays - 1 - index
                if let date = cal.date(byAdding: .day, value: -daysAgo, to: today), date > today {
                    return
                }
                if scrubbedCalendarIndex != index {
                    scrubbedCalendarIndex = index
                    Haptics.tick()
                }
                calendarRevertTask?.cancel()
                calendarRevertTask = nil
            }
            .onEnded { _ in
                scheduleCalendarRevert()
            }
    }

    private func scheduleCalendarRevert() {
        calendarRevertTask?.cancel()
        if reduceMotion {
            scrubbedCalendarIndex = nil
            return
        }
        calendarRevertTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                scrubbedCalendarIndex = nil
            }
        }
    }

    // MARK: - Calendar scrub copy

    private func dateForCalendarIndex(_ i: Int, totalDays: Int, today: Date, cal: Calendar) -> Date? {
        let daysAgo = totalDays - 1 - i
        return cal.date(byAdding: .day, value: -daysAgo, to: today)
    }

    /// Eyebrow label for the scrubbed day: today / yesterday / "fri may 23".
    /// Lowercase, no comma — matches the existing voice signal.
    private func scrubbedDayLabel(_ date: Date, today: Date, cal: Calendar) -> String {
        if date == today { return "TODAY" }
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        if date == yesterday { return "YESTERDAY" }
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: date).uppercased()
    }

    /// Status line for the scrubbed cell. Five branches, all anti-shame —
    /// the inactive past day is "a quiet day ♥" (never "missed"); frozen
    /// is framed as the system holding the streak open, not a free pass.
    private func scrubbedDayStatus(_ date: Date,
                                   today: Date,
                                   activeDates: Set<Date>,
                                   frozenDates: Set<Date>) -> String {
        let isActive = activeDates.contains(date)
        let isFrozen = frozenDates.contains(date)
        if date == today {
            return isActive ? "already moving ♥" : "still open ♥"
        }
        if isActive { return "you showed up ♥" }
        if isFrozen { return "jeni held it ♥" }
        return "a quiet day ♥"
    }

    // MARK: - Plank Progress

    /// v1.0.7 snapshot register — plank progress card retyped. Scrapbook
    /// chrome stripped, 1pt internal dividers → 0.5pt cocoa-12 hairlines,
    /// SemiBold 32pt numerals → Fraunces Light 32pt (no italic on
    /// numerals — voice lock). The "+25% capability" gain readout
    /// stays in italic-Fraunces because "capability" is a copy punch
    /// word and the percent is part of an editorial brag line, not a
    /// data-row numeral — call-site editorial moment.
    private var plankCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("PLANK PROGRESS")
                    .font(Typo.statLabel)
                    .kerning(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer()
                Text("\(benchmarkCount) tests")
                    .font(.custom("DMSans-Regular", size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaSecondary)
            }

            HStack(spacing: 0) {
                plankStatColumn(value: String(format: "%.0f", latestPlankHold), label: "latest (s)", tint: Palette.cocoaPrimary)
                hairlineColumnDivider
                plankStatColumn(value: String(format: "%.0f", bestPlankHold), label: "best (s)", tint: Palette.jeweledRose)
                hairlineColumnDivider
                plankStatColumn(value: averageRating > 0 ? String(format: "%.1f", averageRating) : "—", label: "avg rating", tint: Palette.cocoaPrimary)
            }

            if plankBaselineSeconds > 0 && bestPlankHold > 0 {
                masteryCurveLine
            }
        }
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
    }

    private func plankStatColumn(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.custom("Fraunces72pt-Light", size: 32))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label)
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundStyle(Palette.cocoaTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var hairlineColumnDivider: some View {
        Rectangle()
            .fill(Palette.hairlineCocoa)
            .frame(width: 0.5, height: 32)
    }

    /// Inline "from baseline" delta. Shows current best vs. onboarding
    /// baseline as both an absolute "from Ns at start" and a percentage
    /// gain. Fully derivable from collected data — no fabrication.
    private var masteryCurveLine: some View {
        let baseline = Double(plankBaselineSeconds)
        let best = bestPlankHold
        let delta = best - baseline
        let pct = baseline > 0 ? Int((delta / baseline * 100).rounded()) : 0
        let positive = delta > 0
        return HStack(spacing: 6) {
            Image(systemName: positive ? "arrow.up.right" : "minus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(positive ? Palette.jeweledRose.opacity(0.85) : Palette.cocoaTertiary)
            Text("from \(plankBaselineSeconds)s at start")
                .font(.custom("DMSans-Regular", size: 12))
                .monospacedDigit()
                .foregroundStyle(Palette.cocoaSecondary)
            if positive {
                Text("·")
                    .foregroundStyle(Palette.cocoaTertiary)
                (Text("+\(pct)% ")
                    .font(.custom("DMSans-Medium", size: 12))
                    .monospacedDigit()
                 + Text("capability")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12)))
                    .foregroundStyle(Palette.jeweledRose)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Recent Sessions (grouped)

    /// v1.0.7 snapshot register — sessions list retyped. Per-row
    /// card chrome (RoundedRectangle 14pt + plankShadow) stripped;
    /// rows now read as a clean editorial log with 0.5pt cocoa-12
    /// row dividers. Section eyebrow uppercase + tracked label.
    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("SESSIONS")
                .font(Typo.statLabel)
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)

            if !thisWeekSessions.isEmpty {
                sectionHeader("this week")
                VStack(spacing: 0) {
                    ForEach(Array(thisWeekSessions.enumerated()), id: \.element.id) { i, log in
                        sessionRow(log)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                            .animation(.spring(response: 0.4, dampingFraction: 0.85).delay(Double(i) * 0.08), value: sectionOpacity[4])
                        if i < thisWeekSessions.count - 1 {
                            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                        }
                    }
                }
            }

            if !earlierSessions.isEmpty {
                sectionHeader("earlier")
                VStack(spacing: 0) {
                    ForEach(Array(earlierSessions.enumerated()), id: \.element.id) { i, log in
                        sessionRow(log)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                            .animation(.spring(response: 0.4, dampingFraction: 0.85).delay(Double(i) * 0.06), value: sectionOpacity[4])
                        if i < earlierSessions.count - 1 {
                            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                        }
                    }
                }
            }

            if thisWeekSessions.isEmpty && earlierSessions.isEmpty {
                firstSessionHint
            }
        }
        .padding(.vertical, Space.md)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
    }

    /// First-time empty state for the recent-sessions section. Calm
    /// italic Fraunces line + scrapbook chrome, matching the rest of
    /// the becoming tab. Single sticker accent.
    /// v1.0.7 snapshot register — first-session empty state retyped.
    /// Routes through EditorialEmptyState for consistency with the
    /// rest of the chapter empty surfaces. sparkleGlossy at 14pt
    /// inline-only per the §6 sticker curation (signature 5).
    private var firstSessionHint: some View {
        EditorialEmptyState(
            headline: "your sessions land here.",
            cta: "finish one and the week lights up.",
            sticker: .sparkleGlossy
        )
    }

    /// her75 Phase 2 (2026-06-10) — converted from italic-Fraunces
    /// section label to the tracked editorial eyebrow per the audit
    /// §7: "render an editorial-eyebrow inside the FIRST card of each
    /// group, not a separate section divider row." her75-homescreen
    /// has zero mid-page section labels; when grouping matters, the
    /// 11pt tracked-caps eyebrow is the quietest possible mark.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Typo.captionTracked)
            .kerning(1.98)
            .textCase(.uppercase)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, 4)
    }

    /// v1.0.7 snapshot register — session row retyped. Bento card
    /// chrome (RoundedRectangle 14pt corners + plankShadow) stripped.
    /// Rows now sit flush in the recentSessions list, separated by
    /// 0.5pt cocoa-12 hairlines drawn from the caller. Icon glyph
    /// quieted from circle-tinted to inline cocoa-tertiary, the
    /// editorial register the snapshot tiles share.
    private func sessionRow(_ log: SessionLogRecord) -> some View {
        HStack(spacing: Space.md) {
            Image(systemName: log.sessionType == "routine" ? "flame" : "figure.core.training")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Palette.cocoaTertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.sessionType == "routine" ? "core routine" : "plank benchmark")
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundStyle(Palette.cocoaPrimary)
                Text(log.completedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute()))
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.cocoaTertiary)
            }

            Spacer()

            if log.sessionType == "plank_benchmark" {
                Text(String(format: "%.0fs", log.holdTime))
                    .font(.custom("Fraunces72pt-Light", size: 20))
                    .monospacedDigit()
                    .foregroundStyle(Palette.jeweledRose)
            } else {
                let duration = log.totalDuration ?? 0
                Text(duration > 0 ? formatDuration(duration) : "—")
                    .font(.custom("Fraunces72pt-Light", size: 20))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaPrimary)
            }
        }
        .padding(.vertical, Space.sm)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}
