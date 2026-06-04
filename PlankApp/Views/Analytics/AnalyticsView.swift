import SwiftUI
import SwiftData
import PlankSync
import Auth  // MemberImportVisibility: User.id lives in Supabase's Auth submodule

// MARK: - Bento metric explainers (progressive disclosure)
//
// Tapping a tile's ⓘ opens one of these — the 2026 health-app pattern:
// a simple number on the tile, the "what it means" + method on a deliberate
// tap. Copy is calm + health-literacy-friendly (women report being
// "overwhelmed by dieting info"), anti-shame, and traces the number to how
// it's computed (data-provenance).
enum BecomingMetric: String, Identifiable {
    case trend, forecast, milestone, goal, cadence, movement, breath
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
        }
    }

    var explainer: String {
        switch self {
        case .trend:
            return "this line is your smoothed trend — it evens out the daily ups and downs from water, food, and hormones so you see the real direction, not the noise. the number up top is today; the line is the truth ♥"
        case .forecast:
            return "at your recent pace, this is about when you'd reach your goal. it moves as your pace moves — a gentle guide, never a promise or a deadline to stress about."
        case .milestone:
            return "we break your goal into small markers, about 5 lb each. small wins are easier to feel — and to celebrate — than one big number that's far away."
        case .goal:
            return "how far you've come toward your goal weight. we show it in healthy steps because slow and steady is what actually lasts, and stays off."
        case .cadence:
            return "how many times you stepped on the scale this week. weighing in a few times a week is the single habit most linked to losing weight — not the number itself, the showing up."
        case .movement:
            return "your steps from apple health, for the last 7 days. the soft line at 7,500 is research-backed — that's where weight tends to stay off, not the old 10k myth. brisk walks count more than slow ones, but every walk counts ♥"
        case .breath:
            return "one slow minute of breath flips on your parasympathetic system — the rest-and-digest mode that brings cortisol down. lower cortisol means fewer cravings that aren't really hunger, and a body less locked into holding on. the dots are the days you breathed this week. balban (stanford 2023, n=111), epel (yale, cortisol & abdominal fat), sato (senobi, biomed res 2010, n=40) ♥"
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

            Button(action: onClose) { Text("got it") }
                .buttonStyle(.ctaPrimary)
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
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

    // Phase 16c — Logs scatter (LIGHT, 3 stickers, line-art-heavy).
    // Data surface should feel like a dashboard with light touches,
    // not decorated — 2 line-art + 1 small painterly, all 24–26pt.
    //
    // Same placement strategy as Home: stickers live in the top +
    // bottom horizontal bands where stats cards / activity calendar /
    // recent sessions list don't extend, so they never overlap data
    // content regardless of screen width. cherries lands the warmth
    // touch in one corner; hearts_lineart + star_lineart anchor the
    // line-art accents in the other two.
    private static let logsPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.92, y: 0.13),
                         size: 24, rotation: 12, phaseDelay: 0.00),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.08, y: 0.86),
                         size: 26, rotation: -10, phaseDelay: 0.40),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.92, y: 0.89),
                         size: 24, rotation: 14, phaseDelay: 0.80),
    ]

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            StickerScatter(placements: Self.logsPlacements)

            ScrollView(showsIndicators: false) {
                // Lazy so sections off-screen on first render don't pay
                // their layout cost up front. Becoming tab now has 9
                // modules + recent-sessions ForEach (potentially many
                // rows for active users) — eager VStack would render
                // and animate them all on appear.
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Bento journey redesign: identity hero → bento grid (the
                    // new weight-loss story: coach read, trend hero, forecast,
                    // milestone, % goal, weigh-in cadence, NSV wins, future
                    // tiles) → kept depth (consistency calendar, barriers,
                    // strength, the log). All from collected data; no DB change.
                    header
                        .padding(.top, Space.md)
                        .opacity(sectionOpacity[0])
                        .offset(y: sectionOffset[0])
                        .blur(radius: headerBlur)

                    bentoJourney
                        .opacity(sectionOpacity[1])
                        .offset(y: sectionOffset[1])

                    activityCalendar
                        .opacity(sectionOpacity[2])
                        .offset(y: sectionOffset[2])
                        .scaleEffect(calendarScale, anchor: .top)

                    if !onboardingBarriers.isEmpty {
                        barrierCard
                            .opacity(sectionOpacity[3])
                            .offset(y: sectionOffset[3])
                    }

                    if benchmarkCount > 0 {
                        plankCard
                            .opacity(sectionOpacity[4])
                            .offset(y: sectionOffset[4])
                    }

                    recentSessions
                        .opacity(sectionOpacity[5])
                        .offset(y: sectionOffset[5])
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            Analytics.captureScreen("Becoming")
            animateIn()
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
            .presentationDetents([.medium])
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

            if let motivationLine {
                Text(motivationLine)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
            return "\(lead)you've moved \(moves) times this week. that's not luck — that's you."
        }
        if moves >= 1 {
            return "\(lead)you showed up this week. that's where all of it starts."
        }
        return "\(lead)this is your page. one small move today writes the next line."
    }

    // MARK: - Bento journey grid (research-led weight-loss redesign)
    //
    // Modular tiles of varying size (2026 bento idiom) telling the weight-
    // loss story: coach read → trend (hero) → forecast + milestone → % goal
    // + weigh-in cadence → NSV wins → future features. All from collected
    // data; calm/low-stimulus per the clean-luxury bar. Animates as one
    // section, so the body indexing stays simple.
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
            nsvTile
            // .stepCounter dropped from this row — steps shipped as a real
            // tile above, no longer a "coming soon" chip.
            FutureRailRow(rails: [.foodLog, .bodyScan]) { presentedFutureRail = $0 }
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
            Text(weighInsThisWeek >= 3 ? "this week — that's the habit ♥" : "this week · a few more helps")
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

    /// Shared scrapbook chrome for Phase B+ analytics modules — 24pt
    /// corners, 1.5pt accent border, hard offset shadow. Matches the
    /// rest of the app (browse, settings, pre-session) instead of the
    /// older Phase 7 plankShadow + 16pt rounded.
    private func scrapbookCardChrome(tint: Color = Palette.accent) -> some View {
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

    // MARK: - Barrier-Resolved Card (Phase C)
    //
    // Surfaces each barrier the user picked in onboarding alongside a
    // counter pulled from real session data — research (Rhodes & de
    // Bruijn 2013): pre-identifying barriers + showing the
    // implementation-intention work closes ~50% of the
    // intention-behavior gap (Gollwitzer & Sheeran 2006). Copy is
    // affirming, not preachy.

    private var barrierCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("you said it'd be hard")
                .font(Typo.eyebrow).tracking(3)
                .foregroundStyle(Palette.accent)
            Text("here's what's actually happening.")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
                .padding(.bottom, 2)

            VStack(spacing: Space.sm) {
                ForEach(orderedBarriers, id: \.self) { key in
                    barrierRow(key: key)
                }
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scrapbookCardChrome())
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
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(pair.title)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
                    .foregroundStyle(Palette.textPrimary)
                Text(pair.detail)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        // Compound row — VoiceOver announces "you said never have time.
        // your sessions average 12 min..." as one phrase rather than
        // walking icon/title/detail separately.
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

    private var plankCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("plank progress")
                    .font(Typo.eyebrow).tracking(3)
                    .foregroundStyle(Palette.accent)
                Spacer()
                Text("\(benchmarkCount) tests")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", latestPlankHold))
                        .font(.custom("Fraunces72pt-SemiBold", size: 32))
                        .foregroundStyle(Palette.textPrimary)
                    Text("latest (s)")
                        .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Palette.divider).frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text(String(format: "%.0f", bestPlankHold))
                        .font(.custom("Fraunces72pt-SemiBold", size: 32))
                        .foregroundStyle(Palette.accent)
                    Text("best (s)")
                        .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Palette.divider).frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text(averageRating > 0 ? String(format: "%.1f", averageRating) : "--")
                        .font(.custom("Fraunces72pt-SemiBold", size: 32))
                        .foregroundStyle(Palette.textPrimary)
                    Text("avg rating")
                        .font(Typo.caption).foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Mastery curve callout — Bandura 1997 / Annesi 2011: showing
            // capability gain (vs. raw number) is the strongest single
            // predictor of weight-loss adherence at 6 months. Pulls
            // baselineHoldSeconds straight from onboarding; renders only
            // when both baseline and a current best exist.
            if plankBaselineSeconds > 0 && bestPlankHold > 0 {
                masteryCurveLine
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scrapbookCardChrome())
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
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(positive ? Palette.stateGood : Palette.textSecondary)
            Text("from \(plankBaselineSeconds)s at start")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
            if positive {
                Text("·")
                    .foregroundStyle(Palette.divider)
                Text("+\(pct)% capability")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    .foregroundStyle(Palette.stateGood)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Recent Sessions (grouped)

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !thisWeekSessions.isEmpty {
                sectionHeader("This Week")
                ForEach(Array(thisWeekSessions.enumerated()), id: \.element.id) { i, log in
                    sessionRow(log)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85).delay(Double(i) * 0.08), value: sectionOpacity[4])
                }
            }

            if !earlierSessions.isEmpty {
                sectionHeader("Earlier")
                ForEach(Array(earlierSessions.enumerated()), id: \.element.id) { i, log in
                    sessionRow(log)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85).delay(Double(i) * 0.06), value: sectionOpacity[4])
                }
            }

            // Fresh-user hint: no sessions yet. Surfaces a positive
            // "what shows up here" rather than leaving the section
            // silently empty (Lally 2010 — habit formation tolerates
            // the long ramp; framing the absence as anticipated is
            // healthier than rendering nothing).
            if thisWeekSessions.isEmpty && earlierSessions.isEmpty {
                firstSessionHint
            }
        }
    }

    /// First-time empty state for the recent-sessions section. Calm
    /// italic Fraunces line + scrapbook chrome, matching the rest of
    /// the becoming tab. Single sticker accent.
    private var firstSessionHint: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("your sessions")
                .font(Typo.eyebrow).tracking(3)
                .foregroundStyle(Palette.accent)
            Text("land here.")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
            Text("finish your first workout and the week lights up. one shows up. the rest stack from there.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scrapbookCardChrome())
        .overlay(alignment: .topTrailing) {
            Image(StickerName.starLineart.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(12))
                .offset(x: 4, y: -8)
                .opacity(StickerName.starLineart.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, 4)
    }

    private func sessionRow(_ log: SessionLogRecord) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(log.sessionType == "routine" ? Palette.accent.opacity(0.12) : Palette.accentSubtle.opacity(0.3))
                    .frame(width: 36, height: 36)
                Image(systemName: log.sessionType == "routine" ? "flame.fill" : "figure.core.training")
                    .font(.system(size: 14))
                    .foregroundStyle(log.sessionType == "routine" ? Palette.accent : Palette.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(log.sessionType == "routine" ? "Core Routine" : "Plank Benchmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                Text(log.completedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute()))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer()

            if log.sessionType == "plank_benchmark" {
                Text(String(format: "%.0fs", log.holdTime))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accent)
            } else {
                let duration = log.totalDuration ?? 0
                Text(duration > 0 ? formatDuration(duration) : "--")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
            }
        }
        .padding(12)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .plankShadow()
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}
