import SwiftUI
import SwiftData
import PlankSync
import Auth  // MemberImportVisibility: User.id lives in Supabase's Auth submodule

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

    private var routineCount: Int {
        sessionLogs.filter { $0.sessionType == "routine" }.count
    }

    private var benchmarkCount: Int {
        sessionLogs.filter { $0.sessionType == "plank_benchmark" }.count
    }

    private var totalMinutes: Int {
        let totalSeconds = sessionLogs.reduce(0.0) { $0 + ($1.totalDuration ?? $1.holdTime) }
        return Int(totalSeconds) / 60
    }

    /// Minutes of activity in the trailing 7-day window (today included).
    /// Sums `totalDuration` from session_logs scoped to the user. Source
    /// of truth for the WHO Activity Dose Ring.
    private var weeklyMinutes: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let totalSeconds = sessionLogs
            .filter { $0.completedAt >= cutoff }
            .reduce(0.0) { $0 + ($1.totalDuration ?? $1.holdTime) }
        return Int(totalSeconds) / 60
    }

    /// Adaptive WHO target. WHO 2020 + ACSM 2018 set 150 min/wk for
    /// general health; ACSM progression principle says low-baseline
    /// users should ramp from a smaller initial. Drops to 90 for users
    /// who self-reported `commitmentDays ≤ 3` AND `activityLevel ∈
    /// {sedentary, light}` — both fields stored on UserRecord. Avoids
    /// the demoralization of showing a 19/150 ring on day one.
    private var weeklyMinutesTarget: Int {
        let record = currentUserRecord
        let lowCommit = (record?.onboardingCommitmentDaysPerWeek ?? 0) <= 3
        let sedentary = ["sedentary", "light"].contains(record?.onboardingActivityLevel ?? "")
        return (lowCommit && sedentary) ? 90 : 150
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

    /// ACSM 2009 (Donnelly et al.) position stand: 0.5–1% body weight
    /// per week is the clinically-significant + sustainable rate. We
    /// surface this as a guardrail, not a target — users losing faster
    /// get a "ease back, sustainability wins" cue (Wing & Phelan 2005).
    private var acsmRecommendedKgPerWeekRange: ClosedRange<Double>? {
        guard let current = latestWeightKg, current > 0 else { return nil }
        return (0.005 * current)...(0.01 * current)
    }

    /// User's height in metres (from onboardingHeightCm). Returns nil
    /// when the field is unset or implausible. AnalyticsView reads this
    /// via UserRecord, not @AppStorage — height has no AppStorage mirror.
    private var heightMeters: Double? {
        guard let cm = currentUserRecord?.onboardingHeightCm, cm > 50 else { return nil }
        return cm / 100.0
    }

    /// BMI = kg / m^2. AHA 2021 banding is rendered by the consumer view
    /// (band table is small enough to inline). Returns nil when either
    /// height or current weight is missing — never fabricate.
    private var currentBMI: Double? {
        guard let m = heightMeters, let kg = latestWeightKg else { return nil }
        return kg / (m * m)
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
    @State private var sectionOpacity: [Double] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    @State private var sectionOffset: [CGFloat] = [20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20]
    @State private var hasAnimated = false
    @State private var showLogWeight = false
    @State private var presentedFutureRail: FutureRail? = nil
    @State private var streakPulse = false
    @State private var calendarScale: CGFloat = 0.95

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
                    // Weight-loss-first order (research-led reframe): identity
                    // hero → adaptive coach read → trend-weight hero → support
                    // (bmi/stats) → movement → wins → recent. Every module
                    // self-gates on collected data; a fresh user still sees the
                    // identity hero, the coach read, the seeded weight card,
                    // BMI (if height set), and barriers (if picked).
                    header
                        .padding(.top, Space.md)
                        .opacity(sectionOpacity[0])
                        .offset(y: sectionOffset[0])

                    // The one module that changes week to week — research's
                    // top retention lever ("deliver new info, not the same
                    // dashboard"). Coach-voiced, anti-shame, data-traced.
                    adaptiveInsight
                        .opacity(sectionOpacity[1])
                        .offset(y: sectionOffset[1])

                    // Trend-weight hero — the smoothed trajectory leads.
                    weightCard
                        .opacity(sectionOpacity[2])
                        .offset(y: sectionOffset[2])

                    if currentBMI != nil && !hideWeightStats {
                        bmiCard
                            .opacity(sectionOpacity[3])
                            .offset(y: sectionOffset[3])
                    }

                    heroStats
                        .opacity(sectionOpacity[4])
                        .offset(y: sectionOffset[4])

                    activityRing
                        .opacity(sectionOpacity[5])
                        .offset(y: sectionOffset[5])

                    activityCalendar
                        .opacity(sectionOpacity[6])
                        .offset(y: sectionOffset[6])
                        .scaleEffect(calendarScale, anchor: .top)

                    if !onboardingBarriers.isEmpty {
                        barrierCard
                            .opacity(sectionOpacity[7])
                            .offset(y: sectionOffset[7])
                    }

                    if benchmarkCount > 0 {
                        plankCard
                            .opacity(sectionOpacity[8])
                            .offset(y: sectionOffset[8])
                    }

                    recentSessions
                        .opacity(sectionOpacity[9])
                        .offset(y: sectionOffset[9])

                    // What's coming — scaffolds the weight-loss shift
                    // (calorie photo, steps, body scan). Quiet "coming soon"
                    // rails that fire the demand signal; no DB, no new
                    // surface to maintain (reuses the home idiom).
                    FutureRailRow(rails: [.foodLog, .stepCounter, .bodyScan]) { rail in
                        presentedFutureRail = rail
                    }
                    .opacity(sectionOpacity[10])
                    .offset(y: sectionOffset[10])
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, 100)
            }
        }
        .onAppear { animateIn() }
        .sheet(item: $presentedFutureRail) { rail in
            FutureRailExplainerSheet(rail: rail, onClose: { presentedFutureRail = nil })
                .presentationDetents([.medium])
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
            return
        }

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

        // Streak number pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.3)) {
                streakPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    streakPulse = false
                }
            }
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
    private var adaptiveInsight: some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(CoachAsset.imageName(for: voicePreference))
                .resizable().scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(Circle().stroke(Palette.accentSubtle, lineWidth: 1.5))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("this week")
                    .font(Typo.eyebrow).tracking(2)
                    .foregroundStyle(Palette.accent)
                Text(insightLine)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.accent.opacity(0.18))
                    .offset(x: 5, y: 5)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.accentSubtle)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week from your coach: \(insightLine)")
    }

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

    // MARK: - Empty State

    // MARK: - Hero Stats

    private var heroStats: some View {
        HStack(spacing: 10) {
            // Streak card with pulse
            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.accent)
                Text("\(streak.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .scaleEffect(streakPulse ? 1.15 : 1.0)
                Text(streak.frozenDates.isEmpty ? "day streak" : "streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .plankShadow()

            heroStat(value: "\(routineCount)", label: "workouts", icon: "checkmark.circle.fill")
            heroStat(value: "\(totalMinutes)", label: "min total", icon: "clock.fill")
        }
    }

    private func heroStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .plankShadow()
        // Hero stat = single semantic unit. VoiceOver reads "12 workouts"
        // as one phrase, not "icon, 12, workouts" three steps.
        .accessibilityElement(children: .combine)
    }

    // MARK: - WHO Activity Dose Ring (Phase B)
    //
    // Shows trailing-7-day session minutes against the WHO 2020 / ACSM
    // 2018 target of 150 min/wk moderate activity (or an adaptive 90-min
    // initial target for low-baseline users — see weeklyMinutesTarget).
    // Donnelly et al. 2009 ACSM position stand: 150-300 min/wk is the
    // dose-response window for clinically significant weight loss.
    //
    // Pulls only from already-collected data:
    //   - session_logs.totalDuration (in-app)
    //   - UserRecord.onboardingCommitmentDaysPerWeek (onboarding)
    //   - UserRecord.onboardingActivityLevel (onboarding)

    private var activityRing: some View {
        let minutes = weeklyMinutes
        let target = weeklyMinutesTarget
        let progress = min(1.0, Double(minutes) / Double(target))
        let pct = Int((progress * 100).rounded())

        return HStack(alignment: .center, spacing: Space.lg) {
            ZStack {
                Circle()
                    .stroke(Palette.accent.opacity(0.15), lineWidth: 12)
                    .frame(width: 96, height: 96)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.7), value: progress)
                VStack(spacing: 0) {
                    Text("\(pct)%")
                        .font(.custom("Fraunces72pt-SemiBold", size: 22))
                        .foregroundStyle(Palette.textPrimary)
                    Text("of target")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .tracking(1)
                }
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("this week")
                    .font(Typo.eyebrow).tracking(2)
                    .foregroundStyle(Palette.accent)
                (
                    Text("\(minutes)").font(.custom("Fraunces72pt-SemiBold", size: 28)) +
                    Text(" / \(target) min").font(Typo.body).foregroundColor(Palette.textSecondary)
                )
                .foregroundStyle(Palette.textPrimary)

                Text(activityRingCaption(minutes: minutes, target: target))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scrapbookCardChrome())
    }

    /// Caption under the ring. Three states keyed off progress + the
    /// user's adaptive target so the copy never moralizes a 0%-week
    /// (Neff self-compassion). Citation kept short — full source in
    /// docs/analytics_research.md (Phase B).
    private func activityRingCaption(minutes: Int, target: Int) -> String {
        let remaining = max(0, target - minutes)
        if minutes == 0 {
            return target == 90
                ? "WHO sets 150 min/wk for general health. you're starting at 90 — research says ramp, don't sprint."
                : "WHO sets 150 min/wk for general health. one session puts you on the board."
        }
        if remaining == 0 {
            return target == 150
                ? "you hit the WHO target. dose-response keeps going up to 300 min/wk."
                : "you hit your starting target. ready to move it up?"
        }
        return "\(remaining) min to your weekly target. one short session usually closes it."
    }

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

    // MARK: - Goal Pace Projection (Phase C, inline in weightCard)
    //
    // Surfaces weeks-to-goal at the user's trailing-14-day pace, with an
    // ACSM 2009 (Donnelly) sustainability check overlaid: the safe rate
    // is 0.5–1% body weight per week. Faster = soften, encourage easing.
    // Slower = the realistic-pace literature (Wing 2006) supports it.
    // No-pace = neutral copy. Returns nil for users without enough data.

    private var goalPaceLine: String? {
        guard onboardingGoalWeightKg > 0,
              let pace = paceTowardGoal,
              let current = latestWeightKg else { return nil }

        // No goal direction OR essentially at goal — quiet return.
        let remaining = abs(current - onboardingGoalWeightKg)
        // Threshold is 0.5 kg in storage; surface it in the user's unit
        // so "within X" reads naturally regardless of preference.
        let nearThresholdKg = 0.5
        guard remaining > nearThresholdKg else {
            let displayThresh = weightUnit.display(fromKg: nearThresholdKg)
            return "you're within \(String(format: "%.1f", displayThresh)) \(weightUnit.label) of goal."
        }

        // Pace too small to meaningfully project (under 50g/wk either
        // direction) — reads as "stable" not "stuck", per Linde 2004.
        guard abs(pace) >= 0.05 else {
            return "your weight's been steady this fortnight. consistency is the work."
        }

        // Moving away from goal — neutral framing, no shame language.
        if pace <= 0 {
            return "trend's moved away from goal recently. one week doesn't define the curve."
        }

        // Moving toward goal. Project weeks remaining at current pace.
        let weeks = Int((remaining / pace).rounded())
        let weeksLabel = weeks == 1 ? "1 week" : "\(weeks) weeks"

        // ACSM check — pace too fast (>1% body weight/wk) gets a soften.
        if let safe = acsmRecommendedKgPerWeekRange, pace > safe.upperBound {
            return "at this pace, ~\(weeksLabel) to goal. ACSM caps sustainable loss around 1%/wk — easing slightly compounds long-term."
        }

        return "at your trailing pace, ~\(weeksLabel) to goal."
    }

    // MARK: - BMI Card (Phase C)
    //
    // AHA 2021 BMI banding rendered as a horizontal range bar with a
    // marker for the user's current BMI. BMI is a screening tool not a
    // diagnosis — copy never moralizes the band; we just label it.
    // Renders only when both heightCm (UserRecord) and a current weight
    // log exist, and respects the hideWeightStats ED-safe toggle (gated
    // at the body call site).

    private var bmiCard: some View {
        guard let bmi = currentBMI else {
            return AnyView(EmptyView())
        }
        let band = bmiBand(for: bmi)

        return AnyView(
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Text("body mass index")
                        .font(Typo.eyebrow).tracking(3)
                        .foregroundStyle(Palette.accent)
                    Spacer()
                    Text("AHA 2021")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%.1f", bmi))
                        .font(.custom("Fraunces72pt-SemiBold", size: 36))
                        .foregroundStyle(Palette.textPrimary)
                    // Label de-emphasized — uses textSecondary instead of
                    // band.color so the word ("overweight"/"obese") doesn't
                    // shout. Range bar below still color-codes for
                    // orientation. Anti-shame: keep the screening info,
                    // remove the visual weight from the verdict.
                    Text(band.label)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                        .foregroundStyle(Palette.textSecondary)
                }

                bmiRangeBar(currentBMI: bmi)

                Text(bmiCaption)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(scrapbookCardChrome())
            // Compound BMI card — single semantic unit. The range bar
            // is decorative for VoiceOver users; the number + band
            // label + caption carry the meaning.
            .accessibilityElement(children: .combine)
            .accessibilityLabel("BMI \(String(format: "%.1f", bmi)), \(band.label). \(Self.bmiCaptionText)")
        )
    }

    /// Static text — kept as a constant so the accessibilityLabel
    /// composition above doesn't allocate a new string each render.
    private static let bmiCaptionText =
        "BMI is a screening tool, not a diagnosis. Your trend matters more than the number."

    /// Caption shown beneath the BMI number. Default is the standard
    /// screening-tool disclaimer (anti-shame, research-grounded). When
    /// the user has had ≥4 weight logs and all of them fall in the same
    /// AHA band, switches to a "steady in [band]" reframe — the trend-
    /// matters narrative applied to a flat trend, so a long stable run
    /// reads as success, not failure.
    private var bmiCaption: String {
        if let stableBand = stableBMIBand {
            return "steady in \(stableBand) range these past few logs. the trend matters more than the label."
        }
        return "BMI is a screening tool, not a diagnosis. it doesn't account for muscle vs. fat — your trend matters more than the number."
    }

    /// Returns the AHA band label when the most recent 4 weight logs all
    /// fall in the same band; nil otherwise (including when there are
    /// fewer than 4 logs or no heightMeters). Used by `bmiCaption` to
    /// reframe stable BMI as evidence of consistency, not stagnation.
    private var stableBMIBand: String? {
        guard let m = heightMeters, weightLogs.count >= 4 else { return nil }
        let bands = weightLogs.prefix(4).map { bmiBand(for: $0.weightKg / (m * m)).label }
        return Set(bands).count == 1 ? bands.first : nil
    }

    /// AHA 2021 banding. Returns label + color tuple for a given BMI.
    /// Color choice: stateGood for normal, stateWarn for overweight,
    /// stateBad for obese, divider for underweight (neutral, not red).
    private func bmiBand(for bmi: Double) -> (label: String, color: Color) {
        switch bmi {
        case ..<18.5: return ("underweight", Palette.textSecondary)
        case 18.5..<25: return ("normal range", Palette.stateGood)
        case 25..<30: return ("overweight", Palette.stateWarn)
        default: return ("obese", Palette.stateBad)
        }
    }

    /// Horizontal range bar showing the four AHA bands (proportional
    /// widths) with a vertical marker at the user's current BMI. Marker
    /// position is clamped to [15, 40] so extreme outliers still render.
    private func bmiRangeBar(currentBMI: Double) -> some View {
        // Bands: 15-18.5-25-30-40 → widths normalized to that 25-unit window
        let span = 25.0  // 15..40
        let underWidth = (18.5 - 15.0) / span
        let normalWidth = (25.0 - 18.5) / span
        let overWidth = (30.0 - 25.0) / span
        let obeseWidth = (40.0 - 30.0) / span
        let clamped = max(15.0, min(40.0, currentBMI))
        let markerFrac = (clamped - 15.0) / span

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Rectangle().fill(Palette.divider.opacity(0.7))
                        .frame(width: geo.size.width * underWidth)
                    Rectangle().fill(Palette.stateGood.opacity(0.8))
                        .frame(width: geo.size.width * normalWidth)
                    Rectangle().fill(Palette.stateWarn.opacity(0.8))
                        .frame(width: geo.size.width * overWidth)
                    Rectangle().fill(Palette.stateBad.opacity(0.8))
                        .frame(width: geo.size.width * obeseWidth)
                }
                .clipShape(Capsule())
                .frame(height: 8)

                // Marker triangle pointing down, sitting on the bar
                Triangle()
                    .fill(Palette.textPrimary)
                    .frame(width: 10, height: 8)
                    .offset(x: geo.size.width * markerFrac - 5, y: -10)
            }
        }
        .frame(height: 22)
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

    /// Inverted triangle marker for the BMI range bar. Pointing-down
    /// glyph reads as "you are here" — small enough that it doesn't
    /// dominate the band when rendered at 10×8.

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

    // MARK: - Weight Card (Phase 7a/7b)
    //
    // Stacked layout:
    //   - Eyebrow + headline weight + LOG pill (top row)
    //   - Identity-framed subtitle (Carraça 2018) — softens loss copy on
    //     normal days, surfaces a pre-written reframe on plateau weeks
    //     (Linde 2004, Thomas 2014)
    //   - Swift Charts 7-day EMA trend (Helander 2014) — only when ≥ 2 logs
    //   - Goal progress bar capped at 10% bodyweight (Wing & Phelan 2005)
    //
    // See `docs/weight_loss_analytics_research.md`.

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            weightHeader

            Text(weightSubtitle)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !hideWeightStats, weightLogs.count >= 2 {
                WeightTrendChart(
                    logs: weightLogs,
                    goalWeightKg: onboardingGoalWeightKg > 0 ? onboardingGoalWeightKg : nil,
                    unit: weightUnit
                )
                .padding(.top, 4)
                .transition(.opacity)
            }

            if !hideWeightStats, let progress = weightGoalProgress {
                goalProgressRow(progress: progress)
                    .padding(.top, 2)
                    .transition(.opacity)
            }

            if !hideWeightStats, let line = goalPaceLine {
                Text(line)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
        .padding(Space.md)
        .animation(.easeInOut(duration: 0.25), value: hideWeightStats)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Phase 19d-2 — scrapbook chrome: 24pt corners, 1.5pt accent
        // border, hard offset shadow. Drops `plankShadow()` per the
        // anti-design idiom (drop shadows date the screen).
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.accent.opacity(0.18))
                    .offset(x: 5, y: 5)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        )
        // Sticker corner accent — butterfly ring. Reads as transformation
        // / progress (the metric we're tracking) without veering into
        // feminine-vanity territory. Pushed up + out so it overhangs the
        // top-right edge.
        .overlay(alignment: .topTrailing) {
            Image(StickerName.butterflyRing.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(12))
                .offset(x: 16, y: -22)
                .opacity(StickerName.butterflyRing.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(.top, Space.sm)   // breathing room for the overhanging sticker
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
        .task {
            seedFirstWeightLogIfNeeded()
        }
    }

    private var weightHeader: some View {
        HStack(alignment: .top, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("weight")
                    .font(Typo.eyebrow).tracking(2)
                    .foregroundStyle(Palette.textSecondary)

                if hideWeightStats {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("—")  // voice-lint:allow — visual placeholder for hidden weight value
                            .font(.custom("Fraunces72pt-SemiBold", size: 27))
                            .foregroundStyle(Palette.textSecondary)
                        Text("hidden")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                } else if let latest = latestWeightKg {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        // Demoted from 36pt → 27pt: the smoothed trend chart
                        // below is the hero now, not the raw daily number
                        // (research: the number triggers shame; the trend
                        // gives peace of mind).
                        Text("\(weightUnit.display(fromKg: latest), specifier: "%.1f")")
                            .font(.custom("Fraunces72pt-SemiBold", size: 27))
                            .foregroundStyle(Palette.textPrimary)
                            .contentTransition(.numericText())
                        Text(weightUnit.label)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                } else {
                    Text("track to see your trend.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer()

            // Eye toggle — hides numeric weight display while preserving
            // the LOG path (you can still record silently).
            Button {
                Haptics.light()
                hideWeightStats.toggle()
            } label: {
                Image(systemName: hideWeightStats ? "eye.slash" : "eye")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Palette.bgPrimary)
                    .clipShape(Circle())
                    .tappableArea()
            }
            .accessibilityLabel(hideWeightStats ? "Show weight stats" : "Hide weight stats")

            Button {
                Haptics.light()
                showLogWeight = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("log")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                }
                .foregroundStyle(Palette.textInverse)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Palette.bgInverse)
                .clipShape(Capsule())
            }
            .accessibilityLabel("Log weight")
        }
    }

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

    private func goalProgressRow(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("progress to goal")
                    .font(Typo.eyebrow).tracking(1)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    .foregroundStyle(Palette.accent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.divider)
                        .frame(height: 6)
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: max(6, geo.size.width * progress), height: 6)
                        .animation(.easeInOut(duration: 0.45), value: progress)
                }
            }
            .frame(height: 6)
        }
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

    // MARK: - Activity Calendar (with freeze icons)

    private var activityCalendar: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let frozenDates = streak.frozenDates
        let weekday = cal.component(.weekday, from: today)
        let todayOffset = (weekday + 5) % 7  // Monday = 0
        let totalDays = 28 + todayOffset

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                // "your repeats" reframes the grid from a completion board
                // (failure-coded when sparse) to show-up proof (identity-
                // coded). Same data, calmer reading — one square is enough
                // to start.
                Text("your repeats")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
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
            }

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

            // Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(0..<totalDays, id: \.self) { i in
                    let daysAgo = totalDays - 1 - i
                    let date = cal.date(byAdding: .day, value: -daysAgo, to: today)!
                    let isActive = activeDates.contains(date)
                    let isFrozen = frozenDates.contains(date)
                    let isToday = date == today
                    let isFuture = date > today

                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                isFuture ? Color.clear :
                                isActive ? Palette.accent :
                                isFrozen ? Palette.frozenDay :
                                Palette.divider.opacity(0.4)
                            )
                            .aspectRatio(1, contentMode: .fit)

                        // Ice icon for frozen days
                        if isFrozen {
                            Image(systemName: "snowflake")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(hex: "#7BBBE5"))
                        }

                        // Today outline
                        if isToday {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Palette.accent, lineWidth: 1.5)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .plankShadow()
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

/// Inverted-triangle "you are here" marker for the BMI range bar.
/// Inlined here to avoid polluting DesignSystem with a one-shot shape.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
