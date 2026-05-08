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
    /// Daily workout-shuffle counter. Caps at `dailyRefreshLimit` so the
    /// home card can't be re-rolled indefinitely. Resets when `refreshDate`
    /// no longer matches today.
    @AppStorage("dailyRefreshCount") private var dailyRefreshCount = 0
    @AppStorage("dailyRefreshDate") private var dailyRefreshDate = ""

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
    /// Two-step routine flow: PreRoutineView (info card) → RoutineSessionView
    /// (live session). Both share `showRoutineSession` so we use a single
    /// fullScreenCover; switching `routineFlow` swaps the content.
    @State private var routineFlow: RoutineFlowStep = .preRoutine

    enum RoutineFlowStep { case preRoutine, session }

    // Animation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var msgOpacity: [Double] = [0, 0, 0, 0]
    @State private var msgOffset: [CGFloat] = [16, 16, 16, 16]
    @State private var hasAnimated = false

    // Expand exercise list
    @State private var showAllExercises = false

    // Settings
    @State private var activeSheet: SettingsSheet?

    private var currentDay: Int { (dayProgress.first?.programDay ?? 0) + 1 }

    private var streakResult: StreakCalculator.Result {
        let dates = Set(dayProgress.map { Calendar.current.startOfDay(for: $0.date) })
        return StreakCalculator.calculate(activeDates: dates)
    }

    private var streakCount: Int { streakResult.count }

    /// Subline copy under the streak header. When a freeze has saved a
    /// missed day, surface that — both because it's a "win" moment and so
    /// the user understands what just happened (otherwise auto-freezes feel
    /// magical and unexplained).
    private func streakSubline(weeklyCount: Int, frozen: Int) -> String {
        if frozen > 0 {
            let s = frozen == 1 ? "" : "s"
            return "\(frozen) freeze\(s) saved your streak\u{2009}·\u{2009}\(weeklyCount) this week"
        }
        return "\(weeklyCount) session\(weeklyCount == 1 ? "" : "s") this week — keep it up"
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
            )
        ))
    }

    private var lastBenchmark: SessionLogRecord? {
        sessionLogs.first { $0.sessionType == "plank_benchmark" }
    }

    private var daysSinceLastBenchmark: Int? {
        guard let last = lastBenchmark else { return nil }
        return Calendar.current.dateComponents([.day], from: last.completedAt, to: .now).day
    }

    private var benchmarkDue: Bool {
        guard let days = daysSinceLastBenchmark else { return true }
        return days >= 7
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
                        jenifitGreeting
                            .opacity(msgOpacity[0]).offset(y: msgOffset[0])

                        statStrip
                            .opacity(msgOpacity[1]).offset(y: msgOffset[1])
                            .padding(.horizontal, Space.screenPadding)

                        jenifitWorkoutCard
                            .opacity(msgOpacity[2]).offset(y: msgOffset[2])

                        quickActions
                            .opacity(msgOpacity[2]).offset(y: msgOffset[2])
                            .padding(.horizontal, Space.screenPadding)
                    }
                    .padding(.top, Space.sm)
                    .padding(.bottom, 100)
                }
            }
        }
        .task {
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        showRoutineSession = true
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
            if let workout = currentWorkout {
                if routineFlow == .preRoutine {
                    PreRoutineView(workout: workout) {
                        // User tapped Start in pre-session.
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
                        if didMeet {
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
        .fullScreenCover(isPresented: $showPreSession) {
            PreSessionView(
                exerciseType: "Plank Benchmark",
                dayNumber: currentDay,
                lastBenchmarkSeconds: lastBenchmark.map { Int($0.holdTime) }
            ) {
                showPreSession = false; showSession = true
            } onDismiss: { showPreSession = false }
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
        }
        .fullScreenCover(isPresented: $showPlankPostSession) {
            PostSessionView(holdTime: lastHoldTime, qualityScore: lastQuality, dayNumber: currentDay,
                          streakCount: streakCount, previousScore: nil, playedLines: []) {
                showPlankPostSession = false
            }
        }
        .sheet(item: $activeSheet) { sheet in
            SettingsView(sheet: sheet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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

            Menu {
                Button { activeSheet = .editProfile } label: { Label("Edit Profile", systemImage: "person") }
                Button { activeSheet = .trainer } label: { Label("Coach", systemImage: "person.wave.2") }
                Button { activeSheet = .notifications } label: { Label("Notifications", systemImage: "bell") }
                Button { activeSheet = .account } label: { Label("Account", systemImage: "gearshape") }
                Divider()
                Button { activeSheet = .feedback } label: { Label("Feedback", systemImage: "bubble.left") }
                #if DEBUG
                Divider()
                Button { activeSheet = .debugAuth } label: { Label("Debug Auth", systemImage: "ladybug") }
                #endif
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.vertical, Space.xs)
        .background(Palette.bgPrimary)
    }

    // MARK: - Stat strip (Phase 18b — multi-tone chips)
    //
    // Three chips, three different accents so the home actually has color
    // highlights instead of one cream wash. Streak → cocoa (identity);
    // this-week → rose (progress); freeze → sage (preservation), only
    // shown when freezes are actually saving the streak.

    private var statStrip: some View {
        let result = streakResult
        let weeklyCount = sessionLogs.filter { log in
            log.sessionType == "routine" &&
            Calendar.current.isDate(log.completedAt, equalTo: .now, toGranularity: .weekOfYear)
        }.count

        return HStack(spacing: Space.sm) {
            statChip(
                value: "\(result.count)",
                label: "day streak",
                icon: "flame.fill",
                bg: Palette.bgInverse,
                fg: Palette.textInverse,
                iconColor: Palette.accent,
                shadowColor: Palette.bgInverse.opacity(0.25),
                rotation: -1.5
            )
            statChip(
                value: "\(weeklyCount)",
                label: "this week",
                icon: "figure.run",
                bg: Palette.accent,
                fg: Palette.textInverse,
                iconColor: Palette.textInverse,
                shadowColor: Palette.accent.opacity(0.30),
                rotation: 1
            )
            if result.frozenDates.count > 0 {
                statChip(
                    value: "\(result.frozenDates.count)",
                    label: "frozen",
                    icon: "snowflake",
                    bg: Palette.stateGood.opacity(0.18),
                    fg: Palette.stateGood,
                    iconColor: Palette.stateGood,
                    shadowColor: Palette.stateGood.opacity(0.25),
                    rotation: -2
                )
            }
        }
    }

    /// Stat chip — vertical layout so the big Fraunces numeral can carry
    /// the visual weight per the trend research's "big condensed display
    /// numerals" recommendation. Hard offset shadow + slight rotation per
    /// chip = scrapbook idiom; multi-tone fills (cocoa/rose/sage) keep the
    /// color highlights the previous monochrome layout was missing.
    private func statChip(
        value: String,
        label: String,
        icon: String,
        bg: Color,
        fg: Color,
        iconColor: Color,
        shadowColor: Color,
        rotation: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.custom("Fraunces72pt-SemiBold", size: 36))
                .foregroundStyle(fg)
                .contentTransition(.numericText())

            Text(label)
                .font(Typo.caption)
                .foregroundStyle(fg.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.sm + 4)
        .padding(.vertical, Space.sm + 2)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(shadowColor)
                    .offset(x: 4, y: 4)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(bg)
            }
        )
        .rotationEffect(.degrees(rotation))
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
                subtitle: benchmarkDue ? "due — see your progress" : "how's your hold?",
                icon: "figure.core.training",
                bg: benchmarkDue ? Palette.accentSubtle : Palette.bgElevated,
                accentColor: benchmarkDue ? Palette.accent : Palette.textSecondary,
                showDot: benchmarkDue,
                action: {
                    guard payment.hasProAccess else { return }
                    Haptics.medium()
                    showPreSession = true
                }
            )
            quickActionTile(
                title: "library",
                subtitle: "browse more workouts",
                icon: "square.grid.2x2",
                bg: Palette.bgElevated,
                accentColor: Palette.textSecondary,
                showDot: false,
                action: {
                    Haptics.light()
                    showBrowse = true
                }
            )
        }
        // Sticker accent — heart-glossy hangs off the bottom-right
        // corner of the quick-action row. Closes the home composition
        // with a warm beat (matches the warmth of the streak metric
        // above and the cocoa CTA on the workout card).
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

    private func quickActionTile(
        title: String,
        subtitle: String,
        icon: String,
        bg: Color,
        accentColor: Color,
        showDot: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.xs) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(accentColor)
                        .frame(width: 36, height: 36)
                        .background(Palette.bgPrimary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if showDot {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 7, height: 7)
                            .offset(x: 4, y: -4)
                    }
                }

                Spacer().frame(height: Space.xs)

                Text(title)
                    .font(Typo.body).fontWeight(.semibold)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.md)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - JeniFit Greeting (Phase 18 — compact bubble)
    //
    // One headline + one one-line subtitle. The previous layout stacked
    // three Fraunces lines (Hey [name]. / Today's your day. / Today's X
    // minutes. Let's go.) which read as three competing brand statements.
    // The v1 mockup is a single-line greeting + one body subtitle tying
    // it to today's session.

    private var jenifitGreeting: some View {
        let displayName = userName.isEmpty ? "you" : userName.lowercased()
        return VStack(alignment: .leading, spacing: Space.xs) {
            (
                Text("hey \(displayName). ").font(Typo.title) +
                Text("today's your day.").font(Typo.titleItalic)
            )
            .foregroundStyle(Palette.textPrimary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)

            // Subtitle — rotates through evidence-backed lines drawn from
            // weight-loss adherence research (Teixeira 2012 autonomous
            // motivation, Clear/Oyserman identity-based habits, Linardon
            // 2021 process > outcome framing, Neff self-compassion, Dweck
            // growth mindset). Replaces "your plan's ready when you are"
            // which was generic and added no value for users motivated by
            // weight loss. Stays calm, lowercase, no body-shaming.
            mindfulSubtitle
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xs)
        // Sticker accent — gummy bear. Playful, soft, on-brand without
        // implying a food rule (ice cream / strawberry both leaned into
        // diet-coded territory; gummy is just a cute object).
        .overlay(alignment: .topTrailing) {
            Image(StickerName.gummyBear.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(14))
                .offset(x: -2, y: -10)
                .opacity(StickerName.gummyBear.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Mindful subtitle (research-backed weight-loss messaging)
    //
    // Pulls one line per local-day from a curated rotation. Picking by
    // day-of-year means the user sees the same line all day (no
    // distracting reshuffles between renders) but a fresh one tomorrow.
    // Each line is annotated with the research principle in code so
    // future copy edits keep the evidence base in mind.

    /// 10 subtitle options. The asterisked words render in italic Fraunces
    /// via `ItalicAccentText` — matches the "italic = the punch" pattern
    /// established in Phases 17/18. Each line is tagged so Phase D's
    /// adaptive picker can bias toward lines that address the user's
    /// stated barriers ("time", "consistency", "boring", "gaveUp"). All
    /// lines tagged "general" stay in the rotation for users without a
    /// matching barrier — ensures we never empty the pool.
    private static let mindfulSubtitles: [(line: String, italics: [String], tags: Set<String>)] = [
        // process > outcome (Linardon 2021, Annesi)
        ("today counts more than perfect.", ["today"], ["general"]),
        // identity-based habit (Clear, Oyserman 2015)
        ("you're someone who shows up. that's the whole thing.", ["shows up"], ["general", "consistency"]),
        // autonomous motivation (Teixeira 2012)
        ("small kept promises, to yourself.", ["kept"], ["general", "consistency"]),
        // growth mindset (Dweck, Burnette 2013)
        ("becoming her, one ordinary day at a time.", ["becoming"], ["general"]),
        // self-compassion (Neff)
        ("yesterday isn't the assignment. today is.", ["today"], ["general", "consistency"]),
        // anti-shame (Tylka intuitive eating)
        ("you don't have to earn rest. or movement.", ["rest", "movement"], ["general"]),
        // Phase D — barrier-tagged additions
        // time barrier (ACSM 2018: dose-response is linear, even small bouts count)
        ("five minutes is enough.", ["enough"], ["time"]),
        // time barrier (Rhodes & de Bruijn 2013 — implementation intentions)
        ("short sessions count. all of them count.", ["count"], ["time"]),
        // consistency / gaveUp (Lally 2010 — habit formation tolerates lapses)
        ("missed days don't reset you. they're noise in a long signal.", ["don't reset"], ["consistency", "gaveUp"]),
        // boring barrier (variety as the antidote — engineered into refresh)
        ("variety is the antidote. your plan reshuffles.", ["antidote"], ["boring"]),
    ]

    /// Set of onboarding barriers, parsed from the CSV AppStorage mirror.
    /// Empty when the user picked nothing or onboarded under a legacy
    /// flow before barriers existed.
    private var userBarriersSet: Set<String> {
        Set(userBarriersCSV.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    /// Tags to bias the subtitle rotation toward. Always includes
    /// "general" so the pool can never be empty. Adds barrier-specific
    /// tags only when the user actually picked them — no defensive
    /// over-tagging that would dilute the bias.
    private var preferredSubtitleTags: Set<String> {
        var tags: Set<String> = ["general"]
        if userBarriersSet.contains("time")       { tags.insert("time") }
        if userBarriersSet.contains("motivation") { tags.insert("consistency") }
        if userBarriersSet.contains("boring")     { tags.insert("boring") }
        if userExperience == "gaveUp"             { tags.insert("gaveUp") }
        return tags
    }

    @ViewBuilder
    private var mindfulSubtitle: some View {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        // Pool = lines whose tags overlap with the user's preferred set.
        // Falls back to the full rotation if the filter empties (defensive
        // — shouldn't happen because every line carries at least one tag
        // and "general" is always preferred).
        let pool = Self.mindfulSubtitles.filter { !$0.tags.isDisjoint(with: preferredSubtitleTags) }
        let candidates = pool.isEmpty ? Self.mindfulSubtitles : pool
        let pick = candidates[day % candidates.count]
        ItalicAccentText(
            pick.line,
            italic: pick.italics,
            baseFont: Typo.body,
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
            color: Palette.textSecondary
        )
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

    private var jenifitWorkoutCard: some View {
        let workout = todaysWorkout
        let visibleCount = showAllExercises ? workout.exercises.count : min(3, workout.exercises.count)
        let hasMore = workout.exercises.count > 3

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(alignment: .top) {
                    DayBadge(label: "day \(currentDay)")
                    Spacer()
                    refreshButton
                }

                Spacer().frame(height: Space.xs)

                // Stats — lowercase, accent. Reads more "raw" than uppercase
                // tracked eyebrow text.
                Text("\(workout.estimatedDuration) min · \(workout.exercises.count) exercises · no equipment")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.accent)

                // Title — italic Fraunces lowercase. The italic carries
                // the brand personality, the lowercase carries the rawness.
                Text(workout.name.lowercased())
                    .font(Typo.titleItalic)
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

                Spacer().frame(height: Space.sm)

                // Start CTA — pill, 2pt cocoa outline, no shadow, no
                // gradient (per trend research). Springy press handled
                // by the implicit Button style on a custom label.
                Button {
                    guard payment.hasProAccess else {
                        #if DEBUG
                        print("[HomeView] session entry blocked: hasProAccess=false (routine)")
                        #endif
                        return
                    }
                    Haptics.vibrate()
                    currentWorkout = workout
                    showRoutineSession = true
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
            .padding(Space.md)
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

    // MARK: - JeniFit Streak Card (Phase 6)

    private var jenifitStreakCard: some View {
        let result = streakResult
        let count = result.count
        let frozen = result.frozenDates.count
        let weeklyCount = sessionLogs.filter { log in
            log.sessionType == "routine" &&
            Calendar.current.isDate(log.completedAt, equalTo: .now, toGranularity: .weekOfYear)
        }.count

        return HStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Palette.accentSubtle)
                    .frame(width: 44, height: 44)
                Text("\(count)")
                    .font(.custom("Fraunces72pt-SemiBold", size: 20))
                    .foregroundStyle(Palette.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                (
                    Text("Day ").font(Typo.body) +
                    Text("\(count)").font(.custom("Fraunces72pt-SemiBoldItalic", size: 16)) +
                    Text(" · streak going").font(Typo.body)
                )
                .foregroundStyle(Palette.textPrimary)

                Text(streakSubline(weeklyCount: weeklyCount, frozen: frozen))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)

                // 7-day mini-row — accent for sessions logged this week,
                // divider for upcoming days.
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { d in
                        Circle()
                            .fill(d < weeklyCount ? Palette.accent : Palette.divider)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(Space.md)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .plankShadow()
        .padding(.horizontal, Space.screenPadding)
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
        let compositeKey = "\(userId):\(currentDay)"
        let descriptor = FetchDescriptor<DayProgressRecord>(predicate: #Predicate { $0.compositeKey == compositeKey })
        let progressRecord: DayProgressRecord
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.primarySessionId = session.id
            var ids = existing.sessionLogIds ?? []; ids.append(session.id); existing.sessionLogIds = ids
            existing.updatedAt = .now
            progressRecord = existing
        } else {
            let progress = DayProgressRecord(userId: userId, programDay: currentDay, primarySessionId: session.id,
                                            primaryQualityScore: 0, primaryHoldTime: 0)
            progress.sessionLogIds = [session.id]; modelContext.insert(progress)
            progressRecord = progress
        }
        try? modelContext.save()

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
        let compositeKey = "\(userId):\(currentDay)"
        let descriptor = FetchDescriptor<DayProgressRecord>(predicate: #Predicate { $0.compositeKey == compositeKey })
        let progressRecord: DayProgressRecord
        if let existing = try? modelContext.fetch(descriptor).first {
            var ids = existing.sessionLogIds ?? []; ids.append(session.id); existing.sessionLogIds = ids
            existing.updatedAt = .now
            progressRecord = existing
        } else {
            let progress = DayProgressRecord(userId: userId, programDay: currentDay, primarySessionId: session.id,
                                            primaryQualityScore: quality, primaryHoldTime: holdTime)
            progress.sessionLogIds = [session.id]; modelContext.insert(progress)
            progressRecord = progress
        }
        try? modelContext.save(); hasCompletedFirstSession = true

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
