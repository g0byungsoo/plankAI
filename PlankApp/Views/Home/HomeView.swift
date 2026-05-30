import SwiftUI
import SwiftData
import PlankSync
import Auth  // MemberImportVisibility: User.id lives in Supabase's Auth submodule

struct HomeView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("hasCompletedFirstSession") private var hasCompletedFirstSession = false
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("bodyFocus") private var bodyFocusValue = ""
    @AppStorage("sessionLengthPref") private var sessionLengthPref = 7
    @AppStorage("userExperience") private var userExperience = ""
    /// CSV of onboarding barrier keys (one of: time, motivation, boring,
    /// dontKnow, injury). Phase D reads this to bias the mindful-subtitle
    /// rotation toward lines that address the user's stated friction —
    /// Rhodes & de Bruijn 2013: pre-identifying barriers + addressing
    /// them closes ~50% of the intention-behavior gap.
    @AppStorage("userBarriers") private var userBarriersCSV = ""
    @AppStorage("userBaselineSeconds") private var userBaselineSeconds = 15
    @AppStorage("ageRange") private var ageRange = ""
    @AppStorage("activityLevel") private var activityLevel = ""
    /// Phase 9.19 — set by PlankAIApp / DebugAuthView when the
    /// post-paywall ritual's CTA fires. HomeView observes via
    /// .onChange (NOT .task, which only fires once per lifecycle and
    /// can't see a write that happens while HomeView is the
    /// background view under a covering ritual). On true → launch
    /// today's workout, clear the flag.
    @AppStorage("pendingPostRitualWorkoutLaunch") private var pendingPostRitualWorkoutLaunch = false
    /// Phase 9.24 — shared with JeniMethodRitualView. When true, both
    /// views render the same RitualToWorkoutSplash on top of their
    /// content, hiding the cover-dismiss + cover-present animations
    /// between the ritual ending and the routine session beginning.
    @AppStorage("ritualToWorkoutTransition") private var ritualToWorkoutTransition = false
    /// Daily workout-shuffle counter. Caps at `dailyRefreshLimit` so the
    /// home card can't be re-rolled indefinitely. Resets when `refreshDate`
    /// no longer matches today.
    @AppStorage("dailyRefreshCount") private var dailyRefreshCount = 0
    @AppStorage("dailyRefreshDate") private var dailyRefreshDate = ""

    /// Persistent baseline level (-1 gentle · 0 steady · +1 a little more),
    /// set in "my plan" and nudged by the post-session feedback loop. The
    /// source of truth that survives across days.
    @AppStorage("workoutLevel") private var workoutLevel = 0
    /// Per-session "today's energy" (-1/0/+1) from the card sheet — resets
    /// each calendar day so it never silently sticks. Generator effort
    /// offset = workoutLevel + todaysEnergy.
    @AppStorage("todaysEnergy") private var todaysEnergy = 0
    @AppStorage("todaysEnergyDate") private var todaysEnergyDate = ""

    // The JeniFit Method (Phase 3). The @AppStorage here observes the
    // same key JeniMethodState writes when a lesson completes — so the
    // home card auto-hides the moment the user finishes today's lesson
    // from the sheet, without a manual refresh trigger.
    @AppStorage("jenimethod.last_lesson_completed_id") private var jeniMethodLastCompletedId = 0
    // Default true to match JeniMethodFeatureFlag.isEnabled (?? true). The
    // key is never written in the normal flow, so a false default here
    // silently suppressed the lesson card even though the feature is ON
    // everywhere else (the onboarding case-250 preview promises it).
    @AppStorage("jenimethod.feature_enabled") private var jeniMethodFlagEnabled = true
    @State private var presentedJeniMethodLesson: LessonID? = nil
    /// A completed lesson opened from the journey pager — presented as a
    /// re-read (no progress tracking, no workout handoff).
    @State private var presentedReReadLesson: LessonID? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var allSessionLogs: [SessionLogRecord]
    @Query(sort: \DayProgressRecord.programDay, order: .reverse) private var allDayProgress: [DayProgressRecord]
    @State private var auth = AuthService.shared
    @State private var payment = PaymentService.shared

    /// User-scoped session logs. After sign-in/sign-out cycles, SwiftData
    /// holds rows for every user_id this device has authenticated as. The
    /// filter prevents the previous account's sessions from leaking into
    /// the current view. Returns [] when auth isn't ready — safer than
    /// showing all rows.
    private var sessionLogs: [SessionLogRecord] {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return [] }
        return allSessionLogs.filter { $0.userId == userId }
    }

    /// Same scope guarantee for day progress. Drives `currentDay` and the
    /// active-dates set, so a leak here would reset the wrong streak.
    private var dayProgress: [DayProgressRecord] {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return [] }
        return allDayProgress.filter { $0.userId == userId }
    }

    @State private var showPreSession = false
    @State private var showSession = false
    @State private var lastHoldTime: TimeInterval = 0
    @State private var lastQuality: Double = 0
    @State private var showPlankPostSession = false
    @State private var showRoutineSession = false
    @State private var currentWorkout: WorkoutPreset?
    @State private var showBrowse = false
    /// Difficulty-override sheet, opened by the quiet card link.
    @State private var showEnergySheet = false
    /// Profile/settings hub open state. Drives the menu-mark ☰↔X morph and
    /// the hub's slide-in over the content (no modal sheet).
    @State private var hubOpen = false
    /// Phase A: tapped FutureRailRow chip surfaces its explainer sheet.
    /// `nil` = no sheet presented; tap on a card sets it to the rail.
    @State private var presentedFutureRail: FutureRail? = nil
    /// Two-step routine flow: PreRoutineView (info card) → RoutineSessionView
    /// (live session). Both share `showRoutineSession` so we use a single
    /// fullScreenCover; switching `routineFlow` swaps the content.
    @State private var routineFlow: RoutineFlowStep = .preRoutine

    enum RoutineFlowStep { case preRoutine, session }

    // Animation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var msgOpacity: [Double] = [0, 0, 0, 0]
    @State private var msgOffset: [CGFloat] = [16, 16, 16, 16]
    // One signature touch: the hero greeting line resolves from a soft blur
    // into focus as it fades up (editorial blur-fade). Only the greeting
    // carries it, so the entrance stays calm, not busy.
    @State private var greetingBlur: CGFloat = 6
    @State private var hasAnimated = false

    // Expand exercise list
    @State private var showAllExercises = false

    // Settings
    @State private var activeSheet: SettingsSheet?

    /// Day-progress record for today's calendar day (if a session
    /// already landed today). Used to keep `currentDay` and the save
    /// path consistent — multiple sessions in the same day belong to
    /// the same `programDay` slot.
    private var todayProgress: DayProgressRecord? {
        let cal = Calendar.current
        return dayProgress.first { cal.isDate($0.date, inSameDayAs: .now) }
    }

    /// Phase 10: whether this user is in the JeniFit Method (goal-gated +
    /// flag on). Gates the engagement-day strip + the lesson card so
    /// non-enrolled users (e.g. growGlutes) never see "day N of 14" framing.
    private var jeniMethodEnrolled: Bool {
        guard jeniMethodFlagEnabled else { return false }
        return JeniMethodState.shouldEnroll(for: UserDefaults.standard.string(forKey: "userMotivation"))
    }

    /// Phase A: today's "from jeni" note. Composed from observable
    /// signals (sessions today, last session date, identity feeling).
    /// Nil = the card hides itself per JenisNoteCard's contract.
    private var jenisNoteForToday: JenisNote? {
        let cal = Calendar.current
        let sessionsToday = sessionLogs.filter {
            cal.isDate($0.completedAt, inSameDayAs: .now)
        }.count
        let lastSessionDate = sessionLogs.map(\.completedAt).max()
        let identityFeeling = UserDefaults.standard.string(forKey: "identityFeeling") ?? ""
        return JenisNoteTemplate.compose(
            name: userName,
            sessionsToday: sessionsToday,
            lastSessionDate: lastSessionDate,
            identityFeeling: identityFeeling
        )
    }

    /// The user's current program day. If they've already started today,
    /// returns today's `programDay` (so additional same-day sessions
    /// stay on the same number). Otherwise returns the next-day-to-do
    /// (highest existing programDay + 1).
    private var currentDay: Int {
        if let today = todayProgress { return today.programDay }
        return (dayProgress.first?.programDay ?? 0) + 1
    }

    private var streakResult: StreakCalculator.Result {
        let dates = Set(dayProgress.map { Calendar.current.startOfDay(for: $0.date) })
        return StreakCalculator.calculate(activeDates: dates)
    }

    private var streakCount: Int { streakResult.count }

    /// Sessions logged in the current week. Drives the home momentum
    /// strip's weekly rhythm (was the "this week" stat chip pre-redesign).
    private var weeklyCount: Int {
        sessionLogs.filter { log in
            log.sessionType == "routine" &&
            Calendar.current.isDate(log.completedAt, equalTo: .now, toGranularity: .weekOfYear)
        }.count
    }

    /// Generated daily workout, cached in state so multiple reads during a
    /// single render don't pull a different (random) result each time.
    /// Populated by `.task` on view appearance. While unset, `todaysWorkout`
    /// falls back to a deterministic preset cycle so the card never renders
    /// empty.
    @State private var dailyWorkout: WorkoutPreset?

    private var todaysWorkout: WorkoutPreset {
        if let current = currentWorkout { return current }
        if let daily = dailyWorkout { return daily }
        return fallbackPreset()
    }

    /// Used while the generator hasn't filled `dailyWorkout` yet, or as a
    /// safety net if the engine returns an empty session.
    private func fallbackPreset() -> WorkoutPreset {
        let goal = WorkoutGoal(rawValue: userGoal) ?? .fullCore
        let allPresets = WorkoutPreset.presets(for: goal)
        let routineCount = sessionLogs.filter { $0.sessionType == "routine" }.count
        let startingDifficulty = WorkoutGenerator.startingDifficulty(
            experience: userExperience,
            baselineSeconds: userBaselineSeconds,
            activityLevel: activityLevel,
            ageRange: ageRange
        )
        let matched = allPresets.filter { $0.difficulty == startingDifficulty }
        let pool = matched.isEmpty ? allPresets : matched
        return pool[routineCount % pool.count]
    }

    private static let dailyRefreshLimit = 3

    /// Cached YYYY-MM-DD formatter — DateFormatter init is ~10ms, and this
    /// is read transitively by the refresh button's disabled-state on every
    /// body recompute.
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Today as YYYY-MM-DD in the user's local calendar. Used to gate
    /// the refresh counter so it resets at midnight.
    private var todayKey: String {
        Self.dayKeyFormatter.string(from: Date())
    }

    /// Number of refreshes already used today (auto-resets at midnight).
    private var refreshesRemaining: Int {
        let used = (dailyRefreshDate == todayKey) ? dailyRefreshCount : 0
        return max(0, Self.dailyRefreshLimit - used)
    }

    private var canRefreshWorkout: Bool {
        currentWorkout == nil && !isRefreshing
    }

    /// True while a refresh is mid-flight. Drives the spinning icon on the
    /// refresh button and the magical-loading overlay on the workout card.
    @State private var isRefreshing = false

    /// Stage of the refresh loading animation, drives the rotating copy
    /// in the overlay so it feels like the engine is actually thinking.
    @State private var refreshStage = 0
    private static let refreshStages: [String] = [
        "shuffling moves",
        "matching your focus",
        "balancing the set",
        "almost ready",
    ]

    /// Multi-line affirmation pool for the magical refresh overlay. Each
    /// entry is 3 lines, separated by `\n`, that types out letter-by-letter
    /// so the wait reads as a personal moment, not a spinner. One is
    /// picked at random per refresh so consecutive shuffles feel fresh.
    private static let refreshAffirmations: [String] = [
        "you showed up.\nthat's the whole game.\nshuffling your plan…",
        "take a breath.\nyour body remembers.\nmatching your focus…",
        "today's your day.\nlet's go again.\nbalancing the set…",
        "consistency, not perfection.\nshe gets it.\ncrafting fresh moves…",
    ]
    @State private var currentAffirmation: String = ""

    private static let refreshTotalDurationSec: Double = 2.4

    /// Re-roll today's daily workout. Penalizes the current workout's
    /// exercise IDs so the new workout actually feels different
    /// (otherwise the engine often reselects the same exercises from a
    /// tight focus pool). The 1.6s artificial beat is what makes the
    /// regenerate feel like a real "crafting" moment, not a slot-machine
    /// re-roll. Unlimited refreshes — the magic is in the wait, not the
    /// scarcity.
    private func refreshDailyWorkout() {
        guard canRefreshWorkout else { return }

        Haptics.light()
        let previousIds = dailyWorkout?.exercises.map { $0.exerciseId } ?? []
        // Pick a fresh affirmation per refresh — substituting the user's
        // name into any line that supports it isn't done here; the pool
        // is generic so the typewriter doesn't have to re-resolve mid-type.
        currentAffirmation = Self.refreshAffirmations.randomElement()
            ?? Self.refreshAffirmations[0]
        isRefreshing = true
        refreshStage = 0

        // Cycle stage copy every ~400ms so the overlay text reads like
        // the engine is moving through steps, not stuck.
        let stageInterval: Double = Self.refreshTotalDurationSec / Double(Self.refreshStages.count)
        for i in 1..<Self.refreshStages.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + stageInterval * Double(i)) {
                guard isRefreshing else { return }
                withAnimation(Motion.crossFade) {
                    refreshStage = i
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.refreshTotalDurationSec) {
            let newWorkout = generateDailyWorkout(avoiding: previousIds)
            withAnimation(Motion.gentleSpring) {
                dailyWorkout = newWorkout
                isRefreshing = false
            }
            Haptics.success()
        }
    }

    /// Generate a new daily workout via the v2 engine. Pure, no side effects.
    /// `avoiding` lets the caller penalize exercises that just appeared
    /// (used by the refresh button so back-to-back rolls feel different).
    /// Phase 9.19 — central handler for the post-ritual workout
    /// launch. Called from both `.task` (initial check) and
    /// `.onChange` (live flag flip during session). Clears the flag
    /// immediately so an in-flight launch can't re-trigger; gives
    /// the dismissing cover 400ms to fully animate out before
    /// presenting the routine cover (avoids the iOS dismiss-then-
    /// present race).
    private func launchPostRitualWorkout() {
        pendingPostRitualWorkoutLaunch = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if dailyWorkout == nil {
                dailyWorkout = generateDailyWorkout()
            }
            guard let workout = dailyWorkout else {
                // No workout to launch — still clear the splash flag
                // so the user isn't stuck staring at "getting ready."
                ritualToWorkoutTransition = false
                return
            }
            currentWorkout = workout
            routineFlow = .preRoutine
            // Present in place with NO slide. Transaction.disablesAnimations
            // is unreliable for fullScreenCover (the slide-up leaked through);
            // UIView.setAnimationsEnabled is the pattern that actually kills
            // it (same as the lesson-cover present). The pink splash is
            // already opaque on top, so this swap is invisible.
            UIView.setAnimationsEnabled(false)
            showRoutineSession = true
            DispatchQueue.main.async {
                UIView.setAnimationsEnabled(true)
            }
            // Let the workout cover mount under the splash, then fade the
            // splash out (0.3s) so the workout is gently revealed. Total
            // pink bridge: ~0.3s in → swap → ~0.3s out, no bubble, no slide.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                ritualToWorkoutTransition = false
            }
        }
    }

    private func generateDailyWorkout(avoiding avoidIds: [String] = []) -> WorkoutPreset {
        let focus: [BodyFocus] = BodyFocus(rawValue: bodyFocusValue).map { [$0] } ?? [.fullBody]
        return WorkoutGenerator.generate(from: WorkoutGenerator.Input(
            bodyFocus: focus,
            lengthMinutes: sessionLengthPref,
            recentSessionExerciseIds: avoidIds.isEmpty ? [] : [avoidIds],
            recentRatings: [],
            startingTier: WorkoutGenerator.startingTier(
                experience: userExperience,
                baselineSeconds: userBaselineSeconds,
                activityLevel: activityLevel,
                ageRange: ageRange
            ),
            intensityOffset: workoutLevel + todaysEnergy
        ))
    }

    private var lastBenchmark: SessionLogRecord? {
        sessionLogs.first { $0.sessionType == "plank_benchmark" }
    }

    private var daysSinceLastBenchmark: Int? {
        guard let last = lastBenchmark else { return nil }
        return Calendar.current.dateComponents([.day], from: last.completedAt, to: .now).day
    }

    /// True when the user has prior sessions but the most recent one is
    /// ≥7 days old. Drives the workout-card eyebrow into a softer
    /// "restart gently" register instead of the default "picked for today."
    /// Soft framing, not punitive — comeback is the highest-leverage
    /// retention moment in the women's weight-loss audience.
    private var isReturningAfterInactivity: Bool {
        guard let last = sessionLogs.first?.completedAt else { return false }
        return Date().timeIntervalSince(last) >= 7 * 24 * 60 * 60
    }

    /// Eyebrow shown above the workout card title. Three states:
    ///   • fresh user (no sessions yet)          → "today's short session"
    ///   • returning after ≥7 days off           → "restart gently"
    ///   • any active user (recent session)      → "picked for today"
    /// Read in `jenifitWorkoutCard` only. Stays lowercase + uppercase-eyebrow-
    /// styled (Typo.eyebrow) to fit the existing scrapbook chrome.
    private var workoutCardEyebrow: String {
        if sessionLogs.isEmpty { return "today's short session" }
        if isReturningAfterInactivity { return "restart gently" }
        return "today's pick"
    }

    private var benchmarkDue: Bool {
        guard let days = daysSinceLastBenchmark else { return true }
        return days >= 7
    }

    /// Lesson ID the card should surface, or nil when the card should be
    /// hidden. Returns nil for: flag off, non-allowlisted goal, not yet
    /// enrolled or today's session is already done. Engagement-based: the
    /// lesson follows `currentDay` (derived from the @Query day-progress
    /// records), so the body re-evaluates the instant a session is saved —
    /// no manual refresh trigger needed.
    private var jeniMethodCardLessonId: Int? {
        // Card shows for any flag-on user — the Method is foundational
        // content that should always be reachable. Per user direction, no
        // longer gated on goal (was: shouldEnroll set excluding growGlutes)
        // or on today's-session-done. The day-N-of-14 momentum strip stays
        // separately goal-gated via jeniMethodEnrolled.
        guard jeniMethodFlagEnabled else { return nil }
        // Lazy enroll: stamp enrolledAt on first card-eligible render so
        // existing/test users who never went through the post-purchase
        // Lesson 1 trigger get anchored. Idempotent: re-calls preserve the
        // original timestamp.
        if JeniMethodState.enrolledAt() == nil { JeniMethodState.markEnrolled() }
        return JeniMethodState.lessonForCard(currentDay: currentDay)?.rawValue
    }

    var body: some View {
        ZStack {
            // Phase 18b — second-pass redesign after first-pass user feedback:
            //   - streak moved UP (was below the workout card)
            //   - benchmark + browse pulled OUT of the overflow menu and onto
            //     visible quick-action tiles
            //   - fat hero band replaced with a small inline Lottie thumbnail
            //     (we have 128 bundled, none of them were showing on home)
            //   - native TabView in MainTabView gives the liquid-glass nav
            //   - multi-tone stat chips (cocoa / rose / sage) provide the
            //     color highlights the monochrome layout was missing
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                homeTopBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Space.md) {
                        // Phase 10 cohesion pass — ONE coach voice + ONE
                        // daily action + ONE day count. Order: coach line
                        // (replaces the old greeting + note box) → HERO
                        // session → momentum strip → (escape-hatch workout)
                        // → demoted stats/actions → data rails.

                        // ONE coach voice at the top: Jeni avatar + the
                        // daily templated line (which already carries the
                        // time-of-day greeting). Voice-only / chrome-light
                        // so the hero below stays the single visual hero.
                        JenisNoteCard(note: jenisNoteForToday)
                            .padding(.horizontal, Space.screenPadding)
                            .opacity(msgOpacity[0]).offset(y: msgOffset[0])
                            .blur(radius: greetingBlur)

                        // HERO — the single daily action. When a lesson is
                        // due it IS the hero (one tap → lesson → workout);
                        // otherwise today's workout card is the hero.
                        if let lessonId = jeniMethodCardLessonId,
                           let lesson = LessonID(rawValue: lessonId) {
                            if currentDay <= 14 {
                                // The 14-day arc → swipeable journey: today's
                                // lesson centered, past re-readable, future a
                                // locked glimpse. Spans full width so paging
                                // works (pages inset themselves).
                                JeniMethodJourneyCard(currentDay: currentDay) { tapped, isReread in
                                    Analytics.track(.lessonCardTapped, properties: [
                                        "lesson_id": tapped.rawValue, "day": currentDay, "reread": isReread
                                    ])
                                    UIView.setAnimationsEnabled(false)
                                    if isReread { presentedReReadLesson = tapped }
                                    else { presentedJeniMethodLesson = tapped }
                                    DispatchQueue.main.async {
                                        UIView.setAnimationsEnabled(true)
                                    }
                                }
                                .opacity(msgOpacity[1]).offset(y: msgOffset[1])
                            } else {
                                // Day 15+ generic check-in — no arc to page,
                                // so the single card stays.
                                JeniMethodTodayCard(
                                    teaser: lesson.headline,
                                    onTap: {
                                        Analytics.track(.lessonCardTapped, properties: [
                                            "lesson_id": lessonId, "day": currentDay
                                        ])
                                        UIView.setAnimationsEnabled(false)
                                        presentedJeniMethodLesson = lesson
                                        DispatchQueue.main.async {
                                            UIView.setAnimationsEnabled(true)
                                        }
                                    }
                                )
                                .padding(.horizontal, Space.screenPadding)
                                .opacity(msgOpacity[1]).offset(y: msgOffset[1])
                            }
                        } else {
                            jenifitWorkoutCard
                                .opacity(msgOpacity[1]).offset(y: msgOffset[1])
                        }

                        // Momentum — one soft, flat signal (no flame, no
                        // streak: direction §5.3). Enrolled users see the
                        // "day N of 14" method arc; everyone else sees this
                        // week's showing-up rhythm. Nurturing "shown up N
                        // times" tenure only; the single home for the count.
                        WeekProgressStrip(
                            mode: jeniMethodEnrolled
                                ? .method(currentDay: currentDay)
                                : .weekly(sessionsThisWeek: weeklyCount),
                            sessionsShownUp: dayProgress.count
                        )
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(msgOpacity[2]).offset(y: msgOffset[2])

                        // Escape hatch — when the lesson is the hero, the
                        // workout is still one tap away for anyone who'd
                        // rather just move today.
                        if jeniMethodCardLessonId != nil {
                            jenifitWorkoutCard
                                .opacity(msgOpacity[2]).offset(y: msgOffset[2])
                        }

                        quickActions
                            .opacity(msgOpacity[2]).offset(y: msgOffset[2])
                            .padding(.horizontal, Space.screenPadding)

                        // Future data features (vision: food log, weekly
                        // check-in). One quiet line, not two stub cards —
                        // still fires future_rail_tapped per rail so we keep
                        // the Phase B/C demand signal (§8.5) without clutter.
                        FutureRailRow(rails: [.foodLog, .stepCounter, .weeklyCheckIn]) { rail in
                            presentedFutureRail = rail
                        }
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(msgOpacity[3]).offset(y: msgOffset[3])
                    }
                    .padding(.top, Space.sm)
                    .padding(.bottom, 100)
                }
            }
        }
        .toolbar(hubOpen ? .hidden : .visible, for: .tabBar)
        // Profile/settings hub — a full-screen layer that covers the home top
        // bar (so its wordmark never leaks into the menus) and fades in slowly
        // (mindful motion, no abrupt slide). The hub owns its back + close.
        .overlay {
            if hubOpen {
                ProfileHubView(onClose: { withAnimation(.easeInOut(duration: 0.5)) { hubOpen = false } })
                    .background(Palette.bgPrimary.ignoresSafeArea())
                    .transition(.opacity)
            }
        }
        .overlay {
            // Phase 9.25 — splash bridge slowed to ~0.9s fade in/out
            // so the visual reads as the ritual's bloom slowly
            // settling rather than an interstitial loading screen.
            // The actual cover-swap happens instantly underneath via
            // Transaction.disablesAnimations — user sees: ritual →
            // slow bloom-fade → workout, with no cover-slide motion
            // visible at any point.
            if ritualToWorkoutTransition {
                RitualToWorkoutSplash()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: ritualToWorkoutTransition)
        .task {
            // Reset per-session "today's energy" at the start of each calendar
            // day so a one-off "push it / ease in" never silently sticks; the
            // persistent baseline is `workoutLevel`.
            if todaysEnergyDate != todayKey {
                todaysEnergy = 0
                todaysEnergyDate = todayKey
            }
            // Generate today's workout once per HomeView lifecycle. Pure
            // (random selection bound by user signals) — re-running on every
            // render would flicker the card; .task fires once on appearance.
            if dailyWorkout == nil {
                dailyWorkout = generateDailyWorkout()
            }
            // Wait for first frame to render before animating.
            // Avoids stutter from debugger attach + SwiftData init.
            try? await Task.sleep(for: .milliseconds(300))
            animateIn()

            // Phase 9.19 — initial flag check covers the rare edge
            // case of the app being relaunched with the flag still
            // set (mid-ritual crash). Live updates while HomeView
            // is mounted go through the .onChange handler below.
            if pendingPostRitualWorkoutLaunch {
                launchPostRitualWorkout()
            }

            // Phase 9.21 — auto-present today's ritual once per
            // calendar day. Day 1 is normally served by PlankAIApp's
            // post-paywall trigger; this handles Day 2 onward (every
            // first-of-day return to home) AND the generic Day 6+
            // check-in. Skip-ahead: missed days don't backlog —
            // ritualForToday returns whatever maps to today's
            // calendar-days-since-enrolled index.
            if presentedJeniMethodLesson == nil,
               let lesson = JeniMethodState.ritualForToday(currentDay: currentDay) {
                // Wait a beat so HomeView's appear animation lands
                // before the cover lifts on top of it.
                try? await Task.sleep(for: .milliseconds(600))
                // Phase 9.27 — kill cover slide; RitualView fades in.
                UIView.setAnimationsEnabled(false)
                presentedJeniMethodLesson = lesson
                DispatchQueue.main.async {
                    UIView.setAnimationsEnabled(true)
                }
            }
        }
        .onChange(of: todaysEnergy) { _, _ in
            // Re-roll today's card at the new effort (only when not mid-session).
            guard currentWorkout == nil else { return }
            withAnimation(Motion.gentleSpring) {
                dailyWorkout = generateDailyWorkout()
            }
        }
        .onChange(of: workoutLevel) { _, _ in
            guard currentWorkout == nil else { return }
            withAnimation(Motion.gentleSpring) {
                dailyWorkout = generateDailyWorkout()
            }
        }
        .onChange(of: pendingPostRitualWorkoutLaunch) { _, newValue in
            if newValue {
                launchPostRitualWorkout()
            }
        }
        // Regenerate when the user changes a signal that affects what the
        // daily workout looks like. Without this, dailyWorkout stays stale
        // — e.g., user picks "5 min" in EditProfile but the home card
        // keeps showing the 15-min generation from before the change.
        .onChange(of: sessionLengthPref) { _, _ in
            dailyWorkout = generateDailyWorkout()
        }
        .onChange(of: bodyFocusValue) { _, _ in
            dailyWorkout = generateDailyWorkout()
        }
        // The JeniFit Method (Phase 3, restyled). FullScreenCover —
        // matches the post-purchase Lesson 1 treatment + the pre-paywall
        // onboarding visual feel the user asked for. Dismissable via
        // the X close button in the lesson's top bar (not drag-down,
        // since fullScreenCovers don't drag). onSkip + onComplete both
        // clear the binding; markLessonCompleted is invoked inside the
        // lesson view itself on the Preview screen's "done for today" tap.
        .fullScreenCover(item: $presentedJeniMethodLesson) { lesson in
            // Phase 9.19 — migrated to the JeniMethodRitualView. Day 1
            // ends with a workoutHandoff beat whose CTA launches the
            // user's daily workout. Hand-off pattern mirrors Browse:
            // dismiss the cover, wait one runloop tick to avoid the
            // dismiss-then-present race iOS sometimes drops, then set
            // currentWorkout + showRoutineSession.
            JeniMethodRitualView(
                lesson: lesson,
                user: .fromAppStorage(),
                onComplete: { presentedJeniMethodLesson = nil },
                onSkip:     { _ in presentedJeniMethodLesson = nil },
                onCompleteAndStartWorkout: {
                    // Phase 9.24 — instant dismiss with Transaction so
                    // the cover slide-down doesn't show on top of the
                    // splash. The splash is already opaque at this
                    // point (CTA button waited 0.4s for the fade-in).
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        presentedJeniMethodLesson = nil
                    }
                    pendingPostRitualWorkoutLaunch = true
                }
            )
            // Phase 9.32 — cream modal bg; no black flash during cover swap.
            .presentationBackground(Palette.bgPrimary)
        }
        // Re-read a completed lesson from the journey pager — no progress
        // tracking, no workout handoff (mirrors JeniMethodReReadView).
        .fullScreenCover(item: $presentedReReadLesson) { lesson in
            JeniMethodRitualView(
                lesson: lesson,
                user: .fromAppStorage(),
                isReread: true,
                onComplete: { presentedReReadLesson = nil },
                onSkip:     { _ in presentedReReadLesson = nil }
            )
            .presentationBackground(Palette.bgPrimary)
        }
        .fullScreenCover(isPresented: $showBrowse) {
            BrowseWorkoutsView(
                onSelect: { workout in
                    // Hand off to the existing pre-session → session flow.
                    // Save logic stays in this view's onDismiss callback.
                    currentWorkout = workout
                    routineFlow = .preRoutine
                    showBrowse = false
                    // Show the routine cover on the next runloop to avoid
                    // the dismiss-then-present race iOS sometimes drops.
                    // Phase 9.26 — disable cover-present slide; PreRouteView
                    // fades its content in via contentOpacity instead.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) {
                            showRoutineSession = true
                        }
                    }
                },
                onCancel: { showBrowse = false },
                bodyFocus: BodyFocus(rawValue: bodyFocusValue).map { [$0] } ?? [.fullBody],
                defaultLengthMinutes: sessionLengthPref,
                startingTier: WorkoutGenerator.startingTier(
                    experience: userExperience,
                    baselineSeconds: userBaselineSeconds,
                    activityLevel: activityLevel,
                    ageRange: ageRange
                ),
                recentSessionExerciseIds: [],
                recentRatings: []
            )
        }
        .fullScreenCover(isPresented: $showRoutineSession) {
            // Group wrap — `.presentationBackground` was being applied to
            // the `if let workout` branch (Optional<View>), which the
            // SwiftUI compiler can't resolve as a `View` type. Wrapping
            // in Group gives the modifier a concrete View to attach to.
            // Fixed 2026-05-26 to unblock the audio-clip build.
            Group {
                if let workout = currentWorkout {
                    if routineFlow == .preRoutine {
                        PreRoutineView(workout: workout) {
                            // User tapped Start in pre-session. Single
                            // chokepoint for all start paths (home, browse,
                            // post-ritual) — fires on every workout, unlike
                            // the activation-only first_workout_start.
                            Analytics.track(.workoutStart, properties: [
                                "workout_name": workout.name,
                                "duration_min": workout.estimatedDuration
                            ])
                            withAnimation(Motion.crossFade) {
                                routineFlow = .session
                            }
                        } onCancel: {
                            showRoutineSession = false
                            routineFlow = .preRoutine
                        }
                        .transition(.opacity)
                    } else {
                        RoutineSessionView(workout: workout) { results, duration in
                            let didMeet = SessionCompletion.didMeetThreshold(results)
                            let wasFirstSession = !hasCompletedFirstSession
                            // Funnel beats — only fire on first complete
                            // session (≥70% threshold). _start is logged
                            // *here* (post-finish) instead of on view mount
                            // so we don't count users who bailed in the
                            // first second.
                            if didMeet && wasFirstSession {
                                Analytics.track(.firstWorkoutStart, properties: [
                                    "workout_name": workout.name
                                ])
                                Analytics.track(.firstWorkoutComplete, properties: [
                                    "workout_name": workout.name,
                                    "duration_seconds": Int(duration)
                                ])
                            }
                            if didMeet {
                                Analytics.track(.workoutComplete, properties: [
                                    "workout_name": workout.name,
                                    "duration_seconds": Int(duration)
                                ])
                                saveRoutineSession(results: results, duration: duration)
                                hasCompletedFirstSession = true
                            }
                            // Below the 70% threshold: nothing recorded, day stays put,
                            // streak doesn't advance. The PostRoutineView shows
                            // matching copy via its didMeetThreshold flag.
                            showRoutineSession = false
                            routineFlow = .preRoutine    // reset for next launch
                            // Clear so the home card falls back to the daily
                            // generated workout next render — important when the
                            // session was launched from Browse.
                            currentWorkout = nil
                        }
                        .transition(.opacity)
                    }
                }
            }
            // Phase 9.32 — cream modal bg behind PreRoutine/RoutineSession.
            .presentationBackground(Palette.bgPrimary)
        }
        .fullScreenCover(isPresented: $showPreSession) {
            PreSessionView(
                exerciseType: "Plank Benchmark",
                dayNumber: currentDay,
                lastBenchmarkSeconds: lastBenchmark.map { Int($0.holdTime) }
            ) {
                showPreSession = false; showSession = true
            } onDismiss: { showPreSession = false }
            // Cream backdrop + blur-into-focus entrance so the plank cover
            // resolves like the home greeting / tab bloom instead of the
            // default system fullScreenCover (which flashed black).
            .presentationBackground(Palette.bgPrimary)
            .modifier(PlankCoverBlur())
        }
        .fullScreenCover(isPresented: $showSession) {
            SessionView(exerciseType: "Plank Benchmark", dayNumber: currentDay, targetTime: 60) { holdTime, quality, faults in
                showSession = false
                // Quit-before-plank: holdTime == 0 means user tapped End
                // before reaching plank position. Don't pollute benchmark
                // history with a 0s record and don't show the celebration
                // PostSessionView. Anything ≥ 5s counts as a real attempt.
                let didAttempt = holdTime >= 5
                if didAttempt {
                    lastHoldTime = holdTime; lastQuality = quality
                    saveBenchmarkSession(holdTime: holdTime, quality: quality, faults: faults)
                    showPlankPostSession = true
                }
            }
            .presentationBackground(Palette.bgPrimary)
            .modifier(PlankCoverBlur())
        }
        .fullScreenCover(isPresented: $showPlankPostSession) {
            PostSessionView(holdTime: lastHoldTime, qualityScore: lastQuality, dayNumber: currentDay,
                          streakCount: streakCount, previousScore: nil, playedLines: []) {
                showPlankPostSession = false
            }
            // No blur here — the celebration phase animations own the
            // entrance; just the cream backdrop to kill the black.
            .presentationBackground(Palette.bgPrimary)
        }
        .sheet(item: $activeSheet) { sheet in
            SettingsView(sheet: sheet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $presentedFutureRail) { rail in
            // Phase A: explainer for the locked Phase B/C rails.
            // Tapping "got it" or dismissing the sheet clears the
            // state; tap event already fired from the card itself.
            FutureRailExplainerSheet(rail: rail) {
                presentedFutureRail = nil
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEnergySheet) {
            energySheet
        }
        .onAppear {
            #if DEBUG
            print("[FUNNEL] home_appeared | hasProAccess=\(payment.hasProAccess) | effectiveHasProAccess=\(payment.effectiveHasProAccess) | isEntitlementReady=\(payment.isEntitlementReady) | isInAuthTransition=\(payment.isInAuthTransition)")
            #endif
        }
    }

    // MARK: - Animation (slower, smoother)

    private func animateIn() {
        guard !hasAnimated else { return }
        hasAnimated = true
        // Reduce-motion path: snap to final state immediately. Skip
        // the stagger + spring entirely — content is identical, just
        // no movement. Honors `accessibilityReduceMotion` per HIG.
        if reduceMotion {
            for i in 0..<4 {
                msgOpacity[i] = 1
                msgOffset[i] = 0
            }
            greetingBlur = 0
            return
        }
        // Phase 20a: replaces 0.5s-stagger × 0.6s-spring (last element
        // landed at ~2.0s — read as laggy on cold launch). Motion.stagger
        // (0.10s between elements) + Motion.gentleSpring keeps the
        // cascade calm without dragging. Last element now lands ~0.85s
        // after appear, which preserves the editorial feel without the
        // wait.
        for i in 0..<4 {
            let delay = Double(i) * Motion.stagger
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Haptics.soft()
                withAnimation(Motion.gentleSpring) {
                    msgOpacity[i] = 1
                    msgOffset[i] = 0
                }
                // Greeting blur resolves a touch slower than its fade so the
                // line reads as "coming into focus" — the one signature beat.
                if i == 0 {
                    withAnimation(.easeOut(duration: 0.6)) { greetingBlur = 0 }
                }
            }
        }
    }

    // MARK: - Top Bar

    // MARK: - Home top bar (Phase 18b)
    //
    // Wordmark left, single profile/settings icon right. The benchmark
    // dot indicator moved to the dedicated quick-action tile below — no
    // need for it here.

    private var homeTopBar: some View {
        HStack(alignment: .center) {
            (
                Text("jeni").font(.custom("Fraunces72pt-SemiBold", size: 20)) +
                Text("·").font(.custom("Fraunces72pt-SemiBold", size: 14))
                    .foregroundColor(Palette.accent) +
                Text("fit").font(.custom("Fraunces72pt-SemiBoldItalic", size: 20))
            )
            .foregroundStyle(Palette.textPrimary)

            Spacer()
            // Clean three-line mark → opens the hub. Lives in the HStack so it
            // aligns with the wordmark; fades with the bar when the hub opens.
            Button {
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.5)) { hubOpen = true }
            } label: {
                VStack(spacing: 5) {
                    Capsule().frame(width: 22, height: 1.5)
                    Capsule().frame(width: 22, height: 1.5)
                    Capsule().frame(width: 22, height: 1.5)
                }
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("menu, profile and settings")
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xs)
        .background(Palette.bgPrimary)
        .opacity(hubOpen ? 0 : 1)
    }

    // MARK: - Quick actions (Phase 18b)
    //
    // Two visible tiles for the surfaces the user said don't belong in
    // settings. Plank check-in goes prominent (rose) when it's been ≥ 7
    // days; muted otherwise. Library is always available.

    private var quickActions: some View {
        HStack(spacing: Space.sm) {
            quickActionTile(
                title: "plank check-in",
                subtitle: benchmarkDue ? "it's time" : "how's your hold?",
                bg: benchmarkDue ? Palette.accentSubtle : Palette.bgElevated,
                accentColor: benchmarkDue ? Palette.accent : Palette.textSecondary,
                showDot: benchmarkDue,
                action: {
                    // Pro-access enforcement is the paywall cover's job in
                    // PlankAIApp. A silent guard here used to mask race
                    // conditions where the cover's binding hadn't caught
                    // up after a fresh purchase — the user would tap and
                    // nothing would happen. Trust the cover, surface the
                    // tap.
                    #if DEBUG
                    print("[FUNNEL] plank_checkin_tapped | hasProAccess=\(payment.hasProAccess)")
                    #endif
                    Analytics.track(.plankCheckinStarted, properties: ["due": benchmarkDue])
                    Haptics.medium()
                    // Phase 9.26 — disable cover-present slide; the
                    // plank-form view fades its content in instead.
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        showPreSession = true
                    }
                }
            )
            quickActionTile(
                title: "library",
                subtitle: "browse more workouts",
                bg: Palette.bgElevated,
                accentColor: Palette.textSecondary,
                showDot: false,
                action: {
                    Haptics.light()
                    // Phase 9.26 — disable cover-present slide; Browse
                    // fades its content in instead.
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        showBrowse = true
                    }
                }
            )
        }
        // Sticker accent — heart-glossy hangs off the bottom-right
        // corner of the quick-action row. The single sticker punctuation
        // down here, matching the cocoa CTA on the workout card above.
        .overlay(alignment: .bottomTrailing) {
            Image(StickerName.heartGlossy.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-14))
                .offset(x: 8, y: 16)
                .opacity(StickerName.heartGlossy.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Text-led utility tile — no icon-in-box (that chrome read as a
    /// generic iOS settings row). Title carries the action; the subtitle
    /// turns rose via `accentColor` (with the dot) when the surface wants
    /// attention. The row's single heart sticker is the only ornament.
    private func quickActionTile(
        title: String,
        subtitle: String,
        bg: Color,
        accentColor: Color,
        showDot: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(Typo.body).fontWeight(.semibold)
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                    if showDot {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 7, height: 7)
                    }
                }
                Text(subtitle)
                    .font(Typo.caption)
                    .foregroundStyle(accentColor)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .padding(Space.md)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Refresh Button

    /// Circular shuffle button that re-rolls today's generated workout.
    /// Capped at `dailyRefreshLimit` (3) per local-day; the count badge
    /// shows the remaining rolls so the user has expectations.
    @State private var refreshIconRotation: Double = 0

    private var refreshButton: some View {
        Button(action: refreshDailyWorkout) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(canRefreshWorkout ? Palette.accent : Palette.divider)
                .rotationEffect(.degrees(refreshIconRotation))
                .frame(width: 32, height: 32)
                .background(Palette.bgElevated)
                .clipShape(Circle())
                .tappableArea()
        }
        .disabled(!canRefreshWorkout)
        .onChange(of: isRefreshing) { _, refreshing in
            // Reduce-motion: skip the 720° spin. The refreshing state
            // is already communicated by the loader overlay above the
            // workout card; the icon rotation is purely decorative.
            guard refreshing && !reduceMotion else { return }
            withAnimation(.linear(duration: Self.refreshTotalDurationSec).repeatCount(1, autoreverses: false)) {
                refreshIconRotation += 720   // two full spins over the 1.6s loading window
            }
        }
        .accessibilityLabel(isRefreshing ? "Crafting workout" : "Shuffle workout")
    }

    // MARK: - JeniFit Workout Card (Phase 19 — anti-design / scrapbook)
    //
    // No more inline Lottie — the user said "small + left-aligned + ugly
    // pink box around it". Replaced with a sticker accent (`flower3D`)
    // tucked into the top-right corner, rotated and hanging slightly off
    // the card edge so the composition reads loose/handmade.
    //
    // Card visual treatment per the trend research:
    //   - 24pt corner radius (was 16pt)
    //   - 1.5pt accent-rose border (no drop shadow — those read 2021)
    //   - Hard offset shadow: a cream-darker rect 4pt down + 4pt right
    //   - Lowercase title and stats line (italic Fraunces SemiBoldItalic)
    //   - START button: 2pt black outline, pill, no fill gradient

    // MARK: - Today's-energy sheet
    //
    // Difficulty override lives behind ONE quiet link on the card (Freeletics
    // "adapt session" pattern), not a persistent 3-button segment. Feeling
    // words, never RPE/numbers — beginners can't self-rate exertion. Writes
    // `todaysEnergy` (-1/0/+1, today only) which the generator adds to the
    // persistent `workoutLevel` baseline. The post-session "how'd that feel?"
    // loop nudges the baseline; this sheet only changes today.
    @ViewBuilder
    private var energySheet: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("today's energy")
                    .font(Typo.eyebrow).tracking(2)
                    .foregroundStyle(Palette.accent)
                (
                    Text("how much have you got ") +
                    Text("today").font(.custom("Fraunces72pt-SemiBoldItalic", size: 28)) +
                    Text("?")
                )
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
            }

            VStack(spacing: Space.sm) {
                energyPill("ease in", value: -1, note: "i'll keep it gentle")
                energyPill("steady", value: 0, note: "today's plan, as planned")
                energyPill("push it", value: 1, note: "give me a little more", italic: true)
            }

            Spacer()
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.bgPrimary)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func energyPill(_ label: String, value: Int, note: String, italic: Bool = false) -> some View {
        let selected = todaysEnergy == value
        return Button {
            Haptics.light()
            todaysEnergy = value
            todaysEnergyDate = todayKey
            Analytics.track(.workoutEnergyChanged, properties: ["value": value, "scope": "today"])
            showEnergySheet = false
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(italic
                              ? .custom("Fraunces72pt-SemiBoldItalic", size: 18)
                              : Typo.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                    Text(note)
                        .font(Typo.caption)
                        .foregroundStyle(selected ? Palette.textInverse.opacity(0.8) : Palette.textSecondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.textInverse)
                }
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? Palette.accent : Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Color.clear : Palette.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var jenifitWorkoutCard: some View {
        let workout = todaysWorkout
        let visibleCount = showAllExercises ? workout.exercises.count : min(3, workout.exercises.count)
        let hasMore = workout.exercises.count > 3

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Space.sm) {
                // Header — eyebrow paired with the quiet refresh control on
                // one row, so the card top has two anchors instead of a lone
                // icon floating in an empty row (the orphaned-control dead
                // zone). Day count lives once, in the momentum strip.
                // Eyebrow copy: "restart gently" on ≥7-day return, else
                // "picked for today."
                HStack(alignment: .center) {
                    Text(workoutCardEyebrow)
                        .font(Typo.eyebrow).tracking(2)
                        .foregroundStyle(Palette.accent)
                    Spacer()
                    refreshButton
                }

                // Meta line — lowercase, secondary. "easy to finish" only
                // surfaces on ≤10-min sessions; on 20–30 min workouts it
                // would read patronizing or inaccurate. "no equipment" stays
                // because the women's weight-loss audience reads it as a
                // no-friction signal, not jargon.
                Text(workout.estimatedDuration <= 10
                     ? "\(workout.estimatedDuration) min · no equipment · easy to finish"
                     : "\(workout.estimatedDuration) min · no equipment")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)

                // Title — italic Fraunces lowercase. The italic carries
                // the brand personality, the lowercase carries the rawness.
                Text(workout.name.lowercased())
                    .font(Typo.titleItalic)
                    .tracking(-0.5)   // tighten the Fraunces display so it reads intentional
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let desc = workout.description {
                    Text(desc)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer().frame(height: Space.xs)

                // Exercise list preview — first 3, with expand-to-all.
                VStack(spacing: Space.xs) {
                    ForEach(Array(workout.exercises.prefix(visibleCount).enumerated()), id: \.offset) { i, slot in
                        if let ex = slot.exercise {
                            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                                Text("\(i + 1).")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Palette.textSecondary)
                                    .frame(width: 22, alignment: .leading)
                                Text(ex.name)
                                    .font(Typo.body)
                                    .foregroundStyle(Palette.textPrimary)
                                Spacer()
                            }
                        }
                    }

                    if hasMore {
                        Button {
                            Haptics.light()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                showAllExercises.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(showAllExercises ? "show less" : "+\(workout.exercises.count - 3) more")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: showAllExercises ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Palette.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Space.xs)
                        }
                    }
                }

                // Quiet difficulty override — Jeni offering flexibility, not
                // a control panel (Freeletics "adapt session" pattern). Opens
                // the energy sheet; the post-session loop is the primary tuner.
                Button {
                    Haptics.light()
                    showEnergySheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("feeling it differently today?")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Space.sm)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 20)   // loose gap: CTA is a separate unit

                // Start CTA — pill, 2pt cocoa outline, no shadow, no
                // gradient (per trend research). Springy press handled
                // by the implicit Button style on a custom label.
                Button {
                    // Pro-access enforcement lives in the paywall cover
                    // (PlankAIApp). The inner `guard payment.hasProAccess`
                    // that used to live here was masking race conditions
                    // — after a fresh purchase, hasProAccess could lag the
                    // cover dismiss by a few hundred ms, and the silent
                    // guard would no-op the user's first tap. Trust the
                    // cover; surface the tap.
                    #if DEBUG
                    print("[FUNNEL] start_button_tapped | hasProAccess=\(payment.hasProAccess)")
                    #endif
                    Haptics.vibrate()
                    currentWorkout = workout
                    // Present in place — no slide-up, no black-window flash.
                    // Transaction.disablesAnimations didn't reliably kill the
                    // fullScreenCover slide (which revealed black mid-present);
                    // setAnimationsEnabled does. PreRoutineView fades its own
                    // content in, so it reads as appearing over the cream bg.
                    UIView.setAnimationsEnabled(false)
                    showRoutineSession = true
                    DispatchQueue.main.async {
                        UIView.setAnimationsEnabled(true)
                    }
                } label: {
                    HStack {
                        Text("start")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, 22)
                    .frame(height: 60)
                    .background(Palette.bgInverse)
                    .clipShape(Capsule())
                }
            }
            .padding(20)   // hero card breathes more than the default card padding
        }
        .background(
            // Hard offset shadow first (sits behind the card body), then
            // the cream card surface with accent-rose 1.5pt border.
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
        // Sticker accent — top-LEFT corner so it never covers the refresh
        // button (which is anchored top-right of the card content). Pushed
        // far enough up + out that it's mostly past the card edge —
        // scrapbook idiom, doesn't compete with content for space.
        .overlay(alignment: .topLeading) {
            Image(StickerName.flower3D.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(-12))
                .offset(x: -18, y: -28)
                .opacity(StickerName.flower3D.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.sm)        // breathing room for the overhanging sticker
        // Trigger a SwiftUI transition when the underlying workout changes.
        // Without this the body re-renders in place — visually identical
        // for similar generated workouts, which is what the user perceived
        // as "refresh isn't doing anything".
        .id(workout.id)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.97)),
            removal: .opacity
        ))
        // Magical refresh overlay (Phase 19) — replaces the corporate
        // "CRAFTING…" pill. Sticker stamp burst (sparkle / heart / star)
        // springs in over the cream-elevated cover, italic Fraunces
        // headline types out letter-by-letter, success haptic at the
        // end. ~1.6s. Built off the trend research's "letter-by-letter
        // reveal + sticker stamp burst" recommendation; skips spinners,
        // skeleton shimmers, and confetti — those read as 2021 corporate.
        .overlay {
            if isRefreshing {
                magicalRefreshOverlay
                    .padding(.horizontal, Space.screenPadding)
                    .transition(.opacity)
            }
        }
        .animation(Motion.crossFade, value: isRefreshing)
    }

    @ViewBuilder
    private var magicalRefreshOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.bgElevated)

            // Sticker stamp burst — three stickers spring in at fixed
            // anchors with slight rotation per the anti-design idiom.
            StickerStampView(
                sticker: .sparkleGlossy, anchor: .init(x: 0.18, y: 0.22),
                size: 42, rotation: -12, delay: 0.05
            )
            StickerStampView(
                sticker: .heartGlossy, anchor: .init(x: 0.82, y: 0.32),
                size: 36, rotation: 8, delay: 0.18
            )
            StickerStampView(
                sticker: .starLineart, anchor: .init(x: 0.74, y: 0.80),
                size: 30, rotation: -6, delay: 0.30
            )

            // Multi-line affirmation. Three lines (with the third being
            // the action verb so the user sees what's happening) type
            // out letter-by-letter over ~2.2s. Picked at random per
            // refresh so back-to-back shuffles aren't repetitive.
            TypewriterText(
                text: currentAffirmation,
                charInterval: 0.030
            )
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
            .foregroundStyle(Palette.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.lg)
        }
    }

    // MARK: - Workout Lottie thumbnail (Phase 18b)
    //
    // Plays the first exercise of today's workout as an inline 96pt
    // square. Looping animation = motion + illustration without taking
    // over the card. Falls back to a soft accent-rose square with the
    // primary-area icon if Lottie isn't bundled or fails to load.

    private func workoutLottieThumbnail(workout: WorkoutPreset) -> some View {
        let firstSlot = workout.exercises.first
        let exercise = firstSlot?.exercise

        return ZStack {
            // Soft accent-rose backdrop. Subtle gradient = highlight without
            // being a "fat chunk".
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Palette.accentSubtle,
                            Palette.accentSubtle.opacity(0.6),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let exercise {
                LottieExerciseView(
                    rendering: ExerciseMirror.rendering(for: exercise, side: nil)
                )
                .padding(8)
            } else {
                Image(systemName: "figure.core.training")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Palette.accent)
            }
        }
        .frame(width: 96, height: 96)
    }

    private func workoutGoalLabel(_ goal: WorkoutGoal) -> String {
        switch goal {
        case .strength:    return "STRENGTH"
        case .definition:  return "DEFINITION"
        case .sculpting:   return "SCULPTING"
        case .fullCore:    return "FULL CORE"
        }
    }

    private func workoutDifficultyLabel(_ d: WorkoutDifficulty) -> String {
        switch d {
        case .beginner:    return "LEVEL 1"
        case .intermediate: return "LEVEL 2"
        case .advanced:    return "LEVEL 3"
        }
    }

    // MARK: - Persistence

    private func saveRoutineSession(results: [ExerciseResultEntry], duration: TimeInterval) {
        // userId comes from AuthService — anonymous-bootstrap guarantees a
        // non-nil id. Empty-string fallback keeps the local SwiftData write
        // working in the unlikely case bootstrap hasn't happened yet.
        let userId = AppSync.shared.currentUserId ?? ""
        let resultsData = try? JSONEncoder().encode(results)
        let session = SessionLogRecord(
            userId: userId, exerciseType: "routine", holdTime: 0, targetTime: 0,
            qualityScore: 0, sessionType: "routine",
            presetId: currentWorkout?.id, exerciseResults: resultsData,
            totalDuration: duration
        )
        modelContext.insert(session)
        // Look up today's progress record by calendar date — NOT by
        // composite key. `currentDay` advances after each save, so a
        // composite-key lookup would miss the same-day record and
        // create a duplicate programDay slot. Date-based lookup keeps
        // multiple same-day sessions on the same programDay number.
        let progressRecord: DayProgressRecord
        if let existing = todayProgress {
            existing.primarySessionId = session.id
            var ids = existing.sessionLogIds ?? []; ids.append(session.id); existing.sessionLogIds = ids
            existing.updatedAt = .now
            progressRecord = existing
        } else {
            let nextDay = (dayProgress.first?.programDay ?? 0) + 1
            let progress = DayProgressRecord(userId: userId, programDay: nextDay, primarySessionId: session.id,
                                            primaryQualityScore: 0, primaryHoldTime: 0)
            progress.sessionLogIds = [session.id]; modelContext.insert(progress)
            progressRecord = progress
            // New engagement day → stamp the shown-up count + maybe celebrate.
            RetentionNotifications.recordShownUpDay(count: nextDay)
        }
        try? modelContext.save()
        // Re-arm the win-back nudge from now — completing a session pushes
        // the "we miss you" reminder back out, so it only fires on a lapse.
        RetentionNotifications.markSessionCompleted()

        // Fire-and-forget Supabase upserts. SyncService will skip if userId
        // is empty and clear pendingUpsert on success.
        Task {
            await AppSync.shared.upsertSessionLog(session)
            await AppSync.shared.upsertDayProgress(progressRecord)
        }
    }

    private func saveBenchmarkSession(holdTime: Double, quality: Double, faults: Int) {
        let userId = AppSync.shared.currentUserId ?? ""
        let session = SessionLogRecord(
            userId: userId, exerciseType: "plank", holdTime: holdTime, targetTime: 60,
            qualityScore: quality, formFaultsCount: faults, sessionType: "plank_benchmark",
            plankHoldTime: holdTime, plankFormScore: quality
        )
        modelContext.insert(session)
        // Date-based lookup (see saveSession comment): keeps multiple
        // same-day sessions on the same programDay number.
        let progressRecord: DayProgressRecord
        if let existing = todayProgress {
            var ids = existing.sessionLogIds ?? []; ids.append(session.id); existing.sessionLogIds = ids
            existing.updatedAt = .now
            progressRecord = existing
        } else {
            let nextDay = (dayProgress.first?.programDay ?? 0) + 1
            let progress = DayProgressRecord(userId: userId, programDay: nextDay, primarySessionId: session.id,
                                            primaryQualityScore: quality, primaryHoldTime: holdTime)
            progress.sessionLogIds = [session.id]; modelContext.insert(progress)
            progressRecord = progress
            // New engagement day → stamp the shown-up count + maybe celebrate.
            RetentionNotifications.recordShownUpDay(count: nextDay)
        }
        try? modelContext.save(); hasCompletedFirstSession = true
        RetentionNotifications.markSessionCompleted()

        Task {
            await AppSync.shared.upsertSessionLog(session)
            await AppSync.shared.upsertDayProgress(progressRecord)
        }
    }
}

// MARK: - Stat Card (Log tab)

struct StatCard: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: Space.xs) {
            Text(value)
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(Palette.textPrimary)
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.accent.opacity(0.15))
                    .offset(x: 4, y: 4)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        )
    }
}

/// Blur-into-focus entrance for the plank check-in covers (PreSession +
/// Session). Matches the home greeting + tab bloom motion voice instead of
/// the default system fullScreenCover transition which flashed black on
/// arrival. Reduce-motion snaps clear.
private struct PlankCoverBlur: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blur: CGFloat = 7

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .onAppear {
                guard !reduceMotion else { blur = 0; return }
                withAnimation(.easeOut(duration: 0.5)) { blur = 0 }
            }
    }
}


