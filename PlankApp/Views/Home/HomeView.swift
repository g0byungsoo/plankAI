import SwiftUI
import SwiftData
import PlankFood
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

    // W4-T1 — food rail integration. AppStorage flags drive (a) the
    // soft intro tile that appears for existing users on flag-flip
    // day (per v5 §Existing user journey) and (b) the daily target
    // for the food card bar.
    @AppStorage("hasShownFoodRailIntro") private var hasShownFoodRailIntro = false
    @AppStorage("foodRailFlipTimestamp") private var foodRailFlipTimestamp: Double = 0
    /// W4-T2 — set by PostPurchaseFlow's ForceFirstAction picker when
    /// the user picks "log what you're eating." Mirrors the
    /// pendingPostRitualWorkoutLaunch pattern: HomeView reads on
    /// appear, opens CaptureFlowView, clears the flag.
    @AppStorage("pendingFoodScan") private var pendingFoodScan = false
    /// v1.0.7 Phase B — workout card collapsed under "more today" when
    /// the food rail is enabled. Per the retention expert brief
    /// (docs/home_becoming_research_retention_2026_06_06.md): workout
    /// completion is 23% in production today, low enough that demoting
    /// it from a visible slot to a tap-to-reveal disclosure is the
    /// research-backed call. Persists across launches so users who
    /// expanded it once don't have to re-expand every time.
    @AppStorage("homeShowMoreToday") private var showMoreToday: Bool = false
    /// Daily calorie target. Defaults to Mifflin-St Jeor result from
    /// onboarding (W4-T4 Food Settings will expose an editor). 1650
    /// is the cohort median for a 65kg woman with light activity at
    /// a 15% deficit — placeholder until Food Settings ships.
    @AppStorage("foodDailyTarget") private var foodDailyTarget: Double = 1650

    @State private var showCaptureFlow = false

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
    /// Breathwork re-entry from the BreathworkHomeCard. Surfaces the
    /// PrimerView → SessionView flow as a fullScreenCover. `breathworkPhase`
    /// switches the cover's content; both completion paths just dismiss
    /// (no workout handoff here — that's the post-purchase Day-1 flow).
    @State private var showBreathwork = false
    @State private var breathworkPhase: BreathworkCoverPhase = .library
    /// Protocol the user picked in BreathLibraryView. Drives the session
    /// view's inhale/exhale/repeats config. Defaults to `.calming` so a
    /// session that opens without a library tap still has a valid config.
    @State private var selectedBreath: BreathworkProtocol = .calming
    /// Profile/settings hub open state. Drives the menu-mark ☰↔X morph and
    /// the hub's slide-in over the content (no modal sheet).
    @State private var hubOpen = false
    /// Phase A: tapped FutureRailRow chip surfaces its explainer sheet.
    /// `nil` = no sheet presented; tap on a card sets it to the rail.
    @State private var presentedFutureRail: FutureRail? = nil

    /// 2026-05-30 (epic #1 child #6): Day-7 streak review prompt
    /// sentiment sheet. Fires once per install when `streakCount == 7`
    /// — transition detection, NOT `>= 7`, so existing v1.0.6 users
    /// with streaks already past 7 days never retroactively trigger
    /// (they're already retained — the prompt's marginal value is low).
    @State private var showStreakReviewSheet = false
    @Environment(\.openURL) private var openURLForReview
    /// Two-step routine flow: PreRoutineView (info card) → RoutineSessionView
    /// (live session). Both share `showRoutineSession` so we use a single
    /// fullScreenCover; switching `routineFlow` swaps the content.
    @State private var routineFlow: RoutineFlowStep = .preRoutine

    enum RoutineFlowStep { case preRoutine, session }
    /// Phases for the home breathwork cover. v1.0.6 had primer→session;
    /// v1.0.7 inserts the BreathLibraryView between the card tap and the
    /// session so the user can pick a technique (calming/coherent/
    /// energizing). Day-1 PostPurchaseFlowView still routes primer→session
    /// directly with `.calming` default.
    enum BreathworkCoverPhase { case library, session }

    // Animation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Six entrance slots — order locked v1.0.7 per the tiny-habits +
    // parasocial-coach research for the JeniFit audience:
    //   [0] JenisNoteCard           (coach voice, daily greeting)
    //   [1] JeniMethodJourneyCard   (HERO — the daily lesson beat)
    //   [2] jenifitWorkoutCard      (the daily action, second)
    //   [3] WeekProgressStrip       (momentum)
    //   [4] StepsPulseTile + BreathworkHomeCard (anchor row)
    //   [5] quickActions + FutureRailRow         (utility row)
    //
    // Why method first, not workout: the lesson is lower-friction
    // (~90s swipeable beat) and carries the parasocial Jeni reward
    // that anchors retention. The workout is the higher-effort daily
    // commitment. BJ Fogg's tiny-habits ladder says the easier action
    // with stronger emotional reward goes first — the action that's
    // most likely to actually happen, even when motivation is low.
    @State private var msgOpacity: [Double] = [0, 0, 0, 0, 0, 0]
    @State private var msgOffset: [CGFloat] = [16, 16, 16, 16, 16, 16]
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
    /// Engagement day — count of distinct calendar days the user has
    /// completed a qualifying session, on or before today. DERIVED from
    /// the immutable SessionLogRecord set; no longer a stored counter.
    /// This kills the prior "+1 per session" bug class — running the
    /// same calc twice gives the same number, and multiple sessions on
    /// the same day collapse to one day. Existing users whose stored
    /// `programDay` had drifted (e.g. "day 8" after 3 actual days) see
    /// the correct value on the very next render — no migration step.
    /// See `EngagementDayCalculator` for the full rationale.
    private var currentDay: Int {
        EngagementDayCalculator.currentDay(sessionLogs: sessionLogs)
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

    /// Sister pool for the energy-pill change. Same overlay UI as the
    /// shuffle refresh; the copy frames the regeneration as "tuning
    /// to your energy" rather than "shuffling moves" so the user's
    /// intent (I told you how I feel today) is what reads on screen.
    private static let energyAffirmations: [String] = [
        "today's energy: noted.\nyour body knows.\ntuning your moves ♥",
        "shifting with you.\nsmaller can be smarter.\nadjusting your plan…",
        "you said how you feel.\njeni's got you.\nrecalibrating ♥",
        "this is the rhythm.\nyou + jeni.\ndialing in the set…",
    ]
    @State private var currentAffirmation: String = ""

    private static let refreshTotalDurationSec: Double = 2.4

    /// Re-roll today's daily workout. Penalizes the current workout's
    /// exercise IDs so the new workout actually feels different
    /// (otherwise the engine often reselects the same exercises from a
    /// tight focus pool). Unlimited refreshes — the magic is in the
    /// wait, not the scarcity. Wraps `runWorkoutRegenSequence` with the
    /// shuffle affirmation pool + avoid-current-exercises behavior.
    private func refreshDailyWorkout() {
        let previousIds = dailyWorkout?.exercises.map { $0.exerciseId } ?? []
        runWorkoutRegenSequence(
            affirmationPool: Self.refreshAffirmations,
            avoidingIds: previousIds
        )
    }

    /// Same overlay UX as a refresh, but tuned for the energy-pill tap:
    /// no exercise penalization (the user adjusted INTENSITY, not asked
    /// for different moves), and an energy-flavored affirmation pool so
    /// the overlay copy reflects what just happened. The generator picks
    /// up the new `intensityOffset` from `todaysEnergy + workoutLevel`
    /// via `generateDailyWorkout`, so the new workout actually reflects
    /// the chosen energy.
    private func regenerateForEnergyChange() {
        runWorkoutRegenSequence(
            affirmationPool: Self.energyAffirmations,
            avoidingIds: []
        )
    }

    /// Shared loading-overlay sequence used by refresh button + energy
    /// pill. The 2.4s artificial beat is what makes the regenerate feel
    /// like a real "crafting" moment, not a slot-machine re-roll. Pure
    /// timing + state orchestration — the actual workout generation
    /// happens at the end via `generateDailyWorkout(avoiding:)`.
    private func runWorkoutRegenSequence(
        affirmationPool: [String],
        avoidingIds: [String]
    ) {
        guard canRefreshWorkout else { return }

        Haptics.light()
        currentAffirmation = affirmationPool.randomElement() ?? affirmationPool[0]
        isRefreshing = true
        refreshStage = 0

        // Cycle stage copy every ~600ms so the overlay text reads like
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
            let newWorkout = generateDailyWorkout(avoiding: avoidingIds)
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

    /// Lesson ID the card should surface. NEVER returns nil — the Method
    /// card is foundational content shown to every user, on every day,
    /// regardless of flag / enrollment / goal / session state.
    ///
    /// Why the absolute "always non-nil" guarantee: prior versions tied
    /// visibility to several gates (flag, enrollment timestamp, goal
    /// allowlist), and any one going stale silently hid the card. Users
    /// kept reporting they couldn't see it. The IF gate at the call site
    /// is also gone — see the body for the unconditional render slot.
    ///
    /// Engagement-based: lesson follows `currentDay` (derived from
    /// EngagementDayCalculator), so the body re-evaluates the instant a
    /// session is saved. `max(currentDay, 1)` clamps day 0 (fresh user)
    /// to Lesson 1 so they see real content, not an empty state.
    private var jeniMethodLessonForToday: LessonID {
        let day = max(currentDay, 1)
        let lessonId = day <= 14 ? day : LessonID.generic.rawValue
        // LessonID(rawValue:) is total on 1...15 — the math above stays
        // in that band by construction, so the fallback to .day1 only
        // ever fires if the enum is restructured and forgets a case.
        return LessonID(rawValue: lessonId) ?? .day1
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

                        // HERO — food card per delta v7 D56 (2026-06-05).
                        // 2026-06-06: TrendHeroCard moved to Becoming
                        // tab per founder ("trend hero needs to live in
                        // becoming screen"). Becoming = journey/trend
                        // surface; Home = today's action surface. The
                        // semantic split is cleaner with food back as
                        // Home's slot 1 hero. Behavioral expert's
                        // calorie-as-hero concern is real but the
                        // founder's split (calorie hero ONLY on Home,
                        // never on result card after scan) trades the
                        // risk against the action-clarity Home needs.
                        // Gated on FoodFlags.isEnabled so flag-off users
                        // keep the JeniMethod-hero layout.
                        if FoodFlags.isEnabled {
                            foodHeroSection
                                .padding(.horizontal, Space.screenPadding)
                                .opacity(msgOpacity[1]).offset(y: msgOffset[1])
                        }

                        // JeniMethod card — was slot 1 hero pre-pivot,
                        // now slot 2 peer when food rail enabled. Full
                        // scrapbook chrome retained (NOT flat-demoted)
                        // per delta v7 D56 + Brief #4 + Brief #5
                        // recommendation — JeniMethod is the brand
                        // differentiator and must stay first-class.
                        // Order: "decide what to eat" → "learn something
                        // about food today" is the brand-cultural
                        // sequence Cal AI cannot copy.
                        Group {
                            let lesson = jeniMethodLessonForToday
                            let clampedDay = max(currentDay, 1)
                            if clampedDay <= 14 {
                                JeniMethodJourneyCard(currentDay: clampedDay) { tapped, isReread in
                                    Analytics.track(.lessonCardTapped, properties: [
                                        "lesson_id": tapped.rawValue, "day": clampedDay, "reread": isReread
                                    ])
                                    UIView.setAnimationsEnabled(false)
                                    if isReread { presentedReReadLesson = tapped }
                                    else { presentedJeniMethodLesson = tapped }
                                    DispatchQueue.main.async {
                                        UIView.setAnimationsEnabled(true)
                                    }
                                }
                            } else {
                                JeniMethodTodayCard(
                                    teaser: lesson.headline,
                                    onTap: {
                                        Analytics.track(.lessonCardTapped, properties: [
                                            "lesson_id": lesson.rawValue, "day": clampedDay
                                        ])
                                        UIView.setAnimationsEnabled(false)
                                        presentedJeniMethodLesson = lesson
                                        DispatchQueue.main.async {
                                            UIView.setAnimationsEnabled(true)
                                        }
                                    }
                                )
                                .padding(.horizontal, Space.screenPadding)
                            }
                        }
                        .opacity(msgOpacity[1]).offset(y: msgOffset[1])

                        // Daily action — sits BELOW the lesson hero.
                        // v1.0.7 Phase B (2026-06-06): when food rail
                        // is enabled, workout collapses under a "more
                        // today ▾" disclosure per the retention expert
                        // brief. Production workout completion is 23%;
                        // demoting the card from visible slot to
                        // tap-to-reveal preserves it for the users who
                        // want it without crowding the hero stack for
                        // the 77% who don't. Flag-off users keep the
                        // visible workout card (no regression).
                        if FoodFlags.isEnabled {
                            moreTodayDisclosure
                                .padding(.horizontal, Space.screenPadding)
                                .opacity(msgOpacity[2]).offset(y: msgOffset[2])
                        } else {
                            jenifitWorkoutCard
                                .opacity(msgOpacity[2]).offset(y: msgOffset[2])
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
                            // Derived count, not dayProgress.count — the
                            // latter is row-count which inflated under the
                            // prior buggy writer. EngagementDayCalculator
                            // dedups by calendar day so "shown up Nx"
                            // reads honestly for existing users.
                            sessionsShownUp: EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogs)
                        )
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(msgOpacity[3]).offset(y: msgOffset[3])

                        // Movement anchor — HealthKit-backed steps pulse,
                        // positioned RIGHT BELOW the action cluster (hero +
                        // momentum + escape-hatch). 2026 weight-loss app
                        // research (MyFitnessPal Today, Noom, Mealo): the
                        // pattern is daily-action HERO → today's health
                        // anchor(s) → utility nav, NOT the reverse. Steps
                        // is data the user wants glanceable; quickActions
                        // are secondary nav. Also: it's an anchor, not a
                        // CTA, so it shouldn't compete with the workout
                        // start button above. Today's read here; 7-day
                        // trend lives in Becoming (StepsBentoTile). One
                        // source (StepsService.shared), two surfaces.
                        //
                        // When food + body scan land, this single card
                        // becomes a 2–3 ring TodayHealthStrip (see memory
                        // project_steps_feature + the home-architecture
                        // note). Keep the slot; swap the component.
                        //
                        // W4-T1 ✓ — food rail is now the primary anchor when
                        // FoodFlags.isEnabled. Bar not ring per v5 D33.
                        // Steps demotes to a lateral pill below. Per v5
                        // §Home redesign: trend caption, never daily
                        // over/under language.
                        if FoodFlags.isEnabled {
                            todayHealthStrip
                                .padding(.horizontal, Space.screenPadding)
                                .opacity(msgOpacity[4]).offset(y: msgOffset[4])
                        } else {
                            StepsPulseTile(service: StepsService.shared)
                                .padding(.horizontal, Space.screenPadding)
                                .opacity(msgOpacity[4]).offset(y: msgOffset[4])
                        }

                        // Breathwork re-entry — actionable peer to the
                        // passive steps anchor above. Day 1 introduces it
                        // post-purchase (PostPurchaseFlowView); from then
                        // on, this card is how it's discovered again.
                        // Sized smaller than the workout hero so the
                        // workout still wins the eye, but real estate is
                        // enough to carry the science-honest copy in the
                        // .unfamiliar state.
                        //
                        // 2026-06-05: now lives BELOW the food strip
                        // (previously also embedded in todayHealthStrip
                        // as a 50/50 HStack peer — caused per-char text
                        // wrap on real devices). Single render site
                        // either way; consistent across food-flag states.
                        BreathworkHomeCard(state: BreathworkState.shared) {
                            Analytics.track(.breathworkCardTapped, properties: [
                                "mode": BreathworkState.shared.breathedToday
                                        ? "completed"
                                        : BreathworkState.shared.totalCompleted == 0
                                            ? "unfamiliar" : "invitation"
                            ])
                            breathworkPhase = .library
                            // Kill cover slide so the primer fades in on
                            // the cream backdrop — matches the post-
                            // purchase flow's transition idiom.
                            UIView.setAnimationsEnabled(false)
                            showBreathwork = true
                            DispatchQueue.main.async {
                                UIView.setAnimationsEnabled(true)
                            }
                        }
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(msgOpacity[4]).offset(y: msgOffset[4])

                        quickActions
                            .opacity(msgOpacity[5]).offset(y: msgOffset[5])
                            .padding(.horizontal, Space.screenPadding)

                        // Future data features (vision: food log, weekly
                        // check-in). One quiet line, not two stub cards —
                        // still fires future_rail_tapped per rail so we keep
                        // the Phase B/C demand signal (§8.5) without clutter.
                        // .stepCounter dropped from this row — steps shipped
                        // as a real card above, no longer "coming soon".
                        FutureRailRow(rails: [.foodLog, .weeklyCheckIn]) { rail in
                            presentedFutureRail = rail
                        }
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(msgOpacity[5]).offset(y: msgOffset[5])
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
            // JeniMethod enrollment stamp — moved out of the prior
            // computed-property side effect. Idempotent: re-calls keep
            // the original timestamp. Now the day-N-of-14 strip and any
            // surface that reads `JeniMethodState.enrolledAt()` is
            // populated on the first home appearance, regardless of
            // whether the user ever went through the post-purchase
            // Lesson 1 trigger.
            if JeniMethodState.enrolledAt() == nil {
                JeniMethodState.markEnrolled()
            }
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
            // v1.0.7 — energy pill change now triggers the same magical
            // loading overlay as the refresh button (different copy
            // pool — "tuning your moves" instead of "shuffling moves").
            // The silent regenerate was confusing — users picked a new
            // energy, the sheet closed, and the card silently updated
            // underneath, so it wasn't obvious the choice did anything.
            guard currentWorkout == nil else { return }
            regenerateForEnergyChange()
        }
        .onChange(of: workoutLevel) { _, _ in
            // Same loading UX for the persistent baseline change (set
            // from EditProfile, not the energy sheet). Avoids two
            // different update behaviors for "today's intensity" vs
            // "ongoing intensity" — both feel like a deliberate beat.
            guard currentWorkout == nil else { return }
            regenerateForEnergyChange()
        }
        .onChange(of: pendingPostRitualWorkoutLaunch) { _, newValue in
            if newValue {
                launchPostRitualWorkout()
            }
        }
        // W4-T2 — ForceFirstAction picker → "log what you're eating"
        // sets pendingFoodScan via AppStorage. HomeView opens the
        // capture flow + clears the flag so a re-render doesn't
        // re-trigger.
        .onChange(of: pendingFoodScan) { _, newValue in
            if newValue {
                showCaptureFlow = true
                pendingFoodScan = false
            }
        }
        .onAppear {
            // Also handle the case where PostPurchaseFlow set the flag
            // before HomeView mounted (cover dismissal + HomeView
            // appear race condition).
            if pendingFoodScan {
                showCaptureFlow = true
                pendingFoodScan = false
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
        // Breathwork re-entry cover — library → session, both completion
        // paths just dismiss to home (no workout handoff like Day-1
        // PostPurchaseFlowView, since this is a quiet "settle for a
        // minute" beat, not a gateway to the workout). Phase switches
        // are cross-faded inside the ZStack below.
        //
        // v1.0.7: replaced the long Day-1 primer with BreathLibraryView so
        // repeat users land on the technique picker, not the edu screen
        // they've already seen. The session adapts to the picked protocol
        // (.calming / .coherent / .energizing) via `techProtocol`.
        .fullScreenCover(isPresented: $showBreathwork) {
            ZStack {
                Palette.bgPrimary.ignoresSafeArea()
                switch breathworkPhase {
                case .library:
                    BreathLibraryView(
                        onBegin: { proto in
                            selectedBreath = proto
                            withAnimation(.easeInOut(duration: 0.5)) {
                                breathworkPhase = .session
                            }
                        },
                        onClose: { showBreathwork = false }
                    )
                    .transition(.opacity)
                case .session:
                    BreathworkSessionView(
                        // Both completion paths land on home — no workout
                        // handoff here (Day-1 flow owns that beat).
                        onReadyToMove: { showBreathwork = false },
                        onLater:       { showBreathwork = false },
                        onDismiss:     { showBreathwork = false },
                        techProtocol:  selectedBreath
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: breathworkPhase)
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
            Analytics.captureScreen("Home")
            #if DEBUG
            print("[FUNNEL] home_appeared | hasProAccess=\(payment.hasProAccess) | effectiveHasProAccess=\(payment.effectiveHasProAccess) | isEntitlementReady=\(payment.isEntitlementReady) | isInAuthTransition=\(payment.isInAuthTransition)")
            #endif
            // Day-7 streak review prompt (epic #1 child #6). Transition
            // detection via `streakCount == 7` so existing users with
            // longer streaks don't retroactively trigger. Eligibility +
            // 30-day cooldown + per-install lifetime flag come from
            // RatingPromptService.isEligible.
            if streakCount == 7 &&
               RatingPromptService.shared.isEligible(for: .dayStreakSeven) {
                RatingPromptService.shared.markShown(.dayStreakSeven)
                // Delay so the home animation lands first; user is
                // looking at the streak number when the sheet appears.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showStreakReviewSheet = true
                }
            }
        }
        // W4-T1 — food capture flow. Camera → result → log persistence
        // via FoodLogPersister. Cream backdrop matches the rest of the
        // food rail chrome (avoids default fullScreenCover black flash).
        .fullScreenCover(isPresented: $showCaptureFlow) {
            CaptureFlowView(
                userId: AuthService.shared.currentUser?.id.uuidString ?? "",
                cuisineProfile: UserDefaults.standard
                    .string(forKey: "onboardingCuisinePreference"),
                onDismiss: { showCaptureFlow = false }
            )
            .presentationBackground(Palette.bgPrimary)
        }
        .sheet(isPresented: $showStreakReviewSheet) {
            PreReviewSentimentSheet(
                title: "showing up",
                message: "7 days in a row. a quick rating helps other women find us.",
                onYes: {
                    RatingPromptService.shared.trackSentimentResult(
                        trigger: .dayStreakSeven, sentimentYes: true)
                    RatingPromptService.shared.presentSystemReviewSheet()
                },
                onNotYet: {
                    RatingPromptService.shared.trackSentimentResult(
                        trigger: .dayStreakSeven, sentimentYes: false)
                    if let url = URL(string: "mailto:support@jenifit.app?subject=jenifit%20feedback") {
                        openURLForReview(url)
                    }
                },
                onDismiss: { showStreakReviewSheet = false }
            )
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
            for i in 0..<msgOpacity.count {
                msgOpacity[i] = 1
                msgOffset[i] = 0
            }
            greetingBlur = 0
            return
        }

        // v1.0.7 — matched to AnalyticsView's cascade pattern so the
        // Home + Becoming tabs read as the same animation language. Two
        // things changed from the prior asyncAfter-per-slot approach:
        //
        //  1. Single render commit per slot via `withAnimation(...delay)`
        //     instead of `DispatchQueue.main.asyncAfter` scheduling a
        //     separate withAnimation. Letting SwiftUI batch the cascade
        //     into one animation tree is what makes the slots ripple in
        //     as a continuous wave rather than discrete jumps.
        //
        //  2. One soft haptic upfront, no per-slot haptics. The earlier
        //     "first three slots tap" pattern read as buzzy on cold
        //     launch; one breath-in tap (matching the Becoming tab)
        //     reads as the cascade being announced, then the slots
        //     resolve silently.
        //
        // A 0.10s lead delay before slot 0 gives the user's eye a beat
        // to register that the entrance is starting — without it, the
        // first slot fires immediately on appear and the cascade feels
        // less deliberate.

        Haptics.soft()

        // Greeting blur resolves a touch slower than its fade so the
        // line reads as "coming into focus" — the one signature beat
        // of the entrance, kept on the greeting only so the rest of
        // the cascade stays calm.
        withAnimation(.easeOut(duration: 0.6).delay(0.10)) { greetingBlur = 0 }

        // Six-slot ripple. 0.10s lead + 0.10s stagger × 5 = ~0.60s for
        // the last slot to start, + spring resolution ~0.6s → ~1.2s
        // total. Same total feel as the Becoming cascade.
        for i in 0..<msgOpacity.count {
            let delay = 0.10 + Double(i) * Motion.stagger
            withAnimation(Motion.gentleSpring.delay(delay)) {
                msgOpacity[i] = 1
                msgOffset[i] = 0
            }
        }
    }

    // MARK: - Top Bar

    // MARK: - Home top bar (Phase 18b)
    //
    // Wordmark left, single profile/settings icon right. The benchmark
    // dot indicator moved to the dedicated quick-action tile below — no
    // need for it here.

    // MARK: - Food rail (W4-T1)
    //
    // Tier-1 HERO when FoodFlags.isEnabled per delta v7 D56 (2026-06-05
    // diet-first pivot). Hoisted out of todayHealthStrip to its own
    // slot right under the coach note, ABOVE the JeniMethod card.
    // Existing-user intro tile appears on flag-flip day above the
    // food card, dismissible, auto-hides after 7 days.

    // MARK: - More today disclosure (v1.0.7 Phase B)
    //
    // Workout card lives behind a tap-to-reveal disclosure when the
    // food rail is enabled. Per the retention expert brief:
    // production workout completion is 23%, so demoting the visible
    // slot saves vertical space for the 77% who don't engage while
    // preserving the affordance for the 23% who do. State persists
    // across launches via AppStorage so users who expand once stay
    // expanded.

    @ViewBuilder private var moreTodayDisclosure: some View {
        VStack(spacing: showMoreToday ? Space.md : 0) {
            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    showMoreToday.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    (Text("more")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                        .foregroundStyle(Palette.accent)
                     + Text(" today")
                        .font(.custom("Fraunces72pt-Regular", size: 14))
                        .foregroundStyle(Palette.textSecondary))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.accent.opacity(0.7))
                        .rotationEffect(.degrees(showMoreToday ? 90 : 0))
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showMoreToday ? "hide today's workout" : "show today's workout")

            if showMoreToday {
                jenifitWorkoutCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder private var foodHeroSection: some View {
        VStack(spacing: Space.sm) {
            if shouldShowFoodIntroTile {
                HomeFoodIntroTile(
                    onTap: {
                        markFoodIntroSeen()
                        showCaptureFlow = true
                    },
                    onDismiss: { markFoodIntroSeen() }
                )
            }

            HomeFoodCard(
                userId: AuthService.shared.currentUser?.id.uuidString ?? "",
                dailyTarget: foodDailyTarget,
                onTap: {
                    Analytics.track(.foodCardTapped, properties: ["source": "home_food_card"])
                    showCaptureFlow = true
                }
            )
        }
    }

    // Tier-2 health anchor. Steps + (future) weight trend + (future)
    // body scan. Per delta v7 D56: food hoisted out; this strip is now
    // just the passive health-data tile. BreathworkHomeCard remains a
    // peer below, not inside the strip.
    @ViewBuilder private var todayHealthStrip: some View {
        // v1.0.7 Phase B — TodayPathStrip per the 2-expert anxiety
        // review (docs/today_strip_research_*_2026_06_06.md). Replaces
        // the prior StepsPulseTile-only strip with a unified 3-row
        // capsule-bar strip (food + steps + breath) using soft
        // asymptote bars instead of Apple rings. No daily reset
        // semantics — empty state is positive copy, not a 0/3 view.
        TodayPathStrip(
            userId: AuthService.shared.currentUser?.id.uuidString ?? "",
            foodTargetKcal: foodDailyTarget
        )
    }

    /// Gate for the soft intro tile. Show ONCE for existing pre-1.0.7
    /// users on flag-flip day. Untouched dismiss-or-tap = auto-hide
    /// after 7 days.
    private var shouldShowFoodIntroTile: Bool {
        guard FoodFlags.isEnabled else { return false }
        guard !hasShownFoodRailIntro else { return false }
        // Stamp the flip timestamp lazily so we can compute the 7-day
        // window. First read writes the current epoch as flip time.
        if foodRailFlipTimestamp == 0 {
            foodRailFlipTimestamp = Date.now.timeIntervalSince1970
        }
        let flipDate = Date(timeIntervalSince1970: foodRailFlipTimestamp)
        let daysSinceFlip = Date.now.timeIntervalSince(flipDate) / 86_400
        return daysSinceFlip < 7
    }

    private func markFoodIntroSeen() {
        hasShownFoodRailIntro = true
    }

    private var homeTopBar: some View {
        HStack(alignment: .center) {
            (
                Text("jeni").font(.custom("Fraunces72pt-SemiBold", size: 20)) +
                Text("·").font(.custom("Fraunces72pt-SemiBold", size: 14))
                    .foregroundColor(Palette.accent) +
                Text("fit").font(.custom("Fraunces72pt-SemiBoldItalic", size: 20))
            )
            .foregroundStyle(Palette.textPrimary)
            #if DEBUG
            // 2026-06-01: DEBUG-only long-press shortcut to force the
            // paywall on sim/dev without navigating Settings → Debug.
            // Useful for verifying the hard-paywall cover when RC
            // sandbox returns Pro=true for the test account. Not
            // compiled into Release builds.
            .onLongPressGesture(minimumDuration: 1.0) {
                PaymentService.shared.debugForcePaywall.toggle()
                Haptics.success()
            }
            #endif

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

    /// Workout card chrome — branches on whether food rail is hero.
    /// Pre-pivot (FoodFlags off): hero scrapbook chrome (offset shadow
    /// + 1.5pt accent border + flower3D sticker overlay). Post-pivot
    /// (FoodFlags on, delta v7 D59): demoted chrome — subtle border,
    /// no offset shadow, no sticker. Same functionality, less weight,
    /// visually defers to the food hero above.
    @ViewBuilder private var workoutCardChrome: some View {
        if FoodFlags.isEnabled {
            // v1.0.7 aggressive Gen-Z luxury — chrome stripped per
            // docs/aggressive_genz_luxury_2026_06_06.md §2: "Workout
            // card — kill the cocoa border + start button shape.
            // Replace with text-CTA 'begin →'." Workout already lives
            // collapsed under the "more today ▾" disclosure for the
            // food-rail cohort (Phase B); when expanded, the card
            // sits on the cream backdrop with editorial hairlines —
            // no card fill, no border, no shadow. The "begin" CTA
            // pill itself stays cocoa (brand-lock).
            Rectangle().fill(Color.clear)
        } else {
            // Flag-off cohort retains the original scrapbook chrome
            // hero treatment — zero regression for pre-food-rail
            // users who still see workout as the visible primary
            // action.
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.accent.opacity(0.18))
                    .offset(x: 5, y: 5)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        }
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
            .padding(FoodFlags.isEnabled ? 16 : 20)   // demoted: tighter padding when food rail is hero
        }
        .background(workoutCardChrome)
        // Sticker accent only when workout is still the hero (food rail
        // off). With food rail on, workout demotes per delta v7 D59 —
        // chrome simplifies, sticker drops. Workout still present + fully
        // functional; just no longer the visual hero.
        .overlay(alignment: .topLeading) {
            if !FoodFlags.isEnabled {
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
        // programDay is now DERIVED from the SessionLogRecord set, not
        // incremented from a stored counter. The calculator collapses
        // multiple sessions on the same calendar day to a single day —
        // so the "+1 per session" race that produced "day 8 after 3
        // actual days" can't happen anymore. DayProgressRecord stays
        // for the per-day aggregates (sessionLogIds, primary stats) +
        // cross-device sync; programDay is stamped as a cache so the
        // Supabase column stays consistent for queries that need it.
        let derivedDay = EngagementDayCalculator.programDayForNewSession(
            existingLogs: sessionLogs,
            newSessionCompletedAt: session.completedAt
        )
        let progressRecord: DayProgressRecord
        if let existing = todayProgress {
            existing.primarySessionId = session.id
            var ids = existing.sessionLogIds ?? []; ids.append(session.id); existing.sessionLogIds = ids
            // Self-heal stamp: if the existing row carried a stale
            // programDay (from the old buggy writer), overwrite with
            // the derived value. Idempotent.
            existing.programDay = derivedDay
            existing.updatedAt = .now
            progressRecord = existing
        } else {
            let progress = DayProgressRecord(userId: userId, programDay: derivedDay, primarySessionId: session.id,
                                            primaryQualityScore: 0, primaryHoldTime: 0)
            progress.sessionLogIds = [session.id]; modelContext.insert(progress)
            progressRecord = progress
            // New engagement day → stamp the shown-up count + maybe celebrate.
            RetentionNotifications.recordShownUpDay(count: derivedDay)
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
        // Same derived-day write path as `saveSession`. See that method's
        // comment for the rationale.
        let derivedDay = EngagementDayCalculator.programDayForNewSession(
            existingLogs: sessionLogs,
            newSessionCompletedAt: session.completedAt
        )
        let progressRecord: DayProgressRecord
        if let existing = todayProgress {
            var ids = existing.sessionLogIds ?? []; ids.append(session.id); existing.sessionLogIds = ids
            existing.programDay = derivedDay
            existing.updatedAt = .now
            progressRecord = existing
        } else {
            let progress = DayProgressRecord(userId: userId, programDay: derivedDay, primarySessionId: session.id,
                                            primaryQualityScore: quality, primaryHoldTime: holdTime)
            progress.sessionLogIds = [session.id]; modelContext.insert(progress)
            progressRecord = progress
            // New engagement day → stamp the shown-up count + maybe celebrate.
            RetentionNotifications.recordShownUpDay(count: derivedDay)
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


