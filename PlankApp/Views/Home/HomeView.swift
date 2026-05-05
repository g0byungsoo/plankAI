import SwiftUI
import SwiftData
import PlankSync
import Auth  // MemberImportVisibility: User.id lives in Supabase's Auth submodule

struct HomeView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("hasCompletedFirstSession") private var hasCompletedFirstSession = false
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("sessionLengthPref") private var sessionLengthPref = 7
    @AppStorage("userExperience") private var userExperience = ""
    @AppStorage("userBaselineSeconds") private var userBaselineSeconds = 15
    @AppStorage("ageRange") private var ageRange = ""
    @AppStorage("activityLevel") private var activityLevel = ""

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

    // Animation
    @State private var msgOpacity: [Double] = [0, 0, 0, 0]
    @State private var msgOffset: [CGFloat] = [16, 16, 16, 16]
    @State private var hasAnimated = false

    // Expand exercise list
    @State private var showAllExercises = false

    // Settings
    @State private var activeSheet: SettingsSheet?

    @AppStorage("voicePreference") private var voicePreference = "encouraging"

    private var currentDay: Int { (dayProgress.first?.programDay ?? 0) + 1 }

    private var currentTrainerPhoto: String {
        switch voicePreference {
        case "encouraging": return "coach-jeni"
        case "balanced": return "coach-matson"
        default: return "coach-kira"
        }
    }

    private var currentTrainerName: String {
        switch voicePreference {
        case "encouraging": return "Jeni"
        case "balanced": return "Matson"
        default: return "Kira"
        }
    }
    private var streakCount: Int {
        let dates = Set(dayProgress.map { Calendar.current.startOfDay(for: $0.date) })
        return StreakCalculator.calculate(activeDates: dates).count
    }

    private var todaysWorkout: WorkoutPreset {
        if let current = currentWorkout { return current }
        let goal = WorkoutGoal(rawValue: userGoal) ?? .fullCore
        let allPresets = WorkoutPreset.presets(for: goal)
        let routineCount = sessionLogs.filter { $0.sessionType == "routine" }.count

        // Match the user's starting difficulty so day-1 workouts fit their fitness signal.
        // Falls back to all presets if the difficulty filter empties the pool.
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

    private var todayHasSession: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return sessionLogs.contains { log in
            log.sessionType == "routine" && Calendar.current.startOfDay(for: log.completedAt) == today
        }
    }

    // Phase 16b — Home scatter (LIGHT treatment, 4 stickers). Anchored
    // to the body ZStack so stickers stay pinned to viewport coords as
    // the inner ScrollView scrolls. Margins only — never overlapping
    // cards. Top-bar covers the y<0.07 band with its own opaque cream
    // background, so all sticker y-values stay below that.
    private static let homePlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.92, y: 0.13),
                         size: 26, rotation: 12, phaseDelay: 0.00),
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.06, y: 0.30),
                         size: 24, rotation: -8, phaseDelay: 0.30),
        StickerPlacement(sticker: .heartGlossy,
                         position: CGPoint(x: 0.94, y: 0.50),
                         size: 28, rotation: -10, phaseDelay: 0.55),
        StickerPlacement(sticker: .gummyBear,
                         position: CGPoint(x: 0.10, y: 0.86),
                         size: 32, rotation: 9, phaseDelay: 0.85),
    ]

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            StickerScatter(placements: Self.homePlacements)

            VStack(spacing: 0) {
                messageTopBar
                Divider().foregroundStyle(Palette.divider)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        jenifitGreeting
                            .opacity(msgOpacity[0]).offset(y: msgOffset[0])

                        jenifitWorkoutCard
                            .opacity(msgOpacity[1]).offset(y: msgOffset[1])

                        jenifitStreakCard
                            .opacity(msgOpacity[2]).offset(y: msgOffset[2])

                        // Benchmark module — Phase 16b restyled as a clean
                        // card matching the workout/streak aesthetic. Avatar
                        // + chat-bubble framing dropped; the kiraBubble
                        // conversational element below it removed entirely.
                        benchmarkCard
                            .opacity(msgOpacity[3]).offset(y: msgOffset[3])
                            .padding(.horizontal, Space.screenPadding)
                    }
                    .padding(.bottom, 100)
                }
                // ScrollView is now transparent so the StickerScatter
                // behind the body ZStack shows through the card gutters.
                // Cards have their own bgElevated fills so they stay
                // crisp on top of the sticker layer.
            }
        }
        .task {
            // Wait for first frame to render before animating.
            // Avoids stutter from debugger attach + SwiftData init.
            try? await Task.sleep(for: .milliseconds(300))
            animateIn()
        }
        .fullScreenCover(isPresented: $showRoutineSession) {
            if let workout = currentWorkout {
                RoutineSessionView(workout: workout) { results, duration in
                    saveRoutineSession(results: results, duration: duration)
                    showRoutineSession = false
                    hasCompletedFirstSession = true
                }
            }
        }
        .fullScreenCover(isPresented: $showPreSession) {
            PreSessionView(exerciseType: "Plank Benchmark", dayNumber: currentDay) {
                showPreSession = false; showSession = true
            } onDismiss: { showPreSession = false }
        }
        .fullScreenCover(isPresented: $showSession) {
            SessionView(exerciseType: "Plank Benchmark", dayNumber: currentDay, targetTime: 60) { holdTime, quality, faults in
                lastHoldTime = holdTime; lastQuality = quality; showSession = false
                saveBenchmarkSession(holdTime: holdTime, quality: quality, faults: faults)
                showPlankPostSession = true
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
        let baseDelay = 0.0
        let delays: [Double] = [0.0, 0.5, 1.0, 1.5]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + delay) {
                Haptics.soft()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    msgOpacity[i] = 1
                    msgOffset[i] = 0
                }
            }
        }
    }

    // MARK: - Top Bar

    private var messageTopBar: some View {
        HStack {
            // Left — overflow menu (existing settings entry points).
            Menu {
                Button { activeSheet = .editProfile } label: { Label("Edit Profile", systemImage: "person") }
                Button { activeSheet = .notifications } label: { Label("Notifications", systemImage: "bell") }
                Button { activeSheet = .account } label: { Label("Account", systemImage: "gearshape") }
                Divider()
                Button { activeSheet = .feedback } label: { Label("Feedback", systemImage: "bubble.left") }
                #if DEBUG
                Divider()
                Button { activeSheet = .debugAuth } label: { Label("Debug Auth", systemImage: "ladybug") }
                #endif
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            // Center — coach photo + name. Tapping opens the trainer
            // settings sheet (parity with the prior layout).
            Button {
                activeSheet = .trainer
            } label: {
                HStack(spacing: 8) {
                    Image(currentTrainerPhoto)
                        .resizable().scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    Text(currentTrainerName)
                        .font(Typo.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.textPrimary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Right — bell icon. Visual only for v1.0 (no notification
            // logic); red dot is gated on hasUnread once that exists.
            Image(systemName: "bell")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.vertical, Space.xs)
        .background(Palette.bgPrimary)
    }

    // MARK: - JeniFit Greeting (Phase 6 typography header)

    private var jenifitGreeting: some View {
        let displayName = userName.isEmpty ? "you" : userName
        return VStack(alignment: .leading, spacing: Space.xs) {
            // Headline — italic accent on the user's name.
            (
                Text("Hey ").font(Typo.title) +
                Text(displayName).font(Typo.titleItalic) +
                Text(".").font(Typo.title)
            )
            .foregroundStyle(Palette.textPrimary)

            // Subhead — italic accent on "your day".
            (
                Text("Today's ").font(Typo.title) +
                Text("your day").font(Typo.titleItalic) +
                Text(".").font(Typo.title)
            )
            .foregroundStyle(Palette.textPrimary)

            Spacer().frame(height: Space.xs)

            Group {
                if todaysWorkout.estimatedDuration > 0 {
                    let phrase = "\(todaysWorkout.estimatedDuration) minutes"
                    ItalicAccentText("Today's \(phrase). Let's go.",
                                     italic: [phrase],
                                     baseFont: Typo.body,
                                     italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
                                     color: Palette.textSecondary,
                                     alignment: .leading)
                } else {
                    Text("Your plan's ready when you are.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.md)
        .padding(.bottom, Space.sm)
    }

    // MARK: - JeniFit Workout Card (Phase 6 editorial)

    private var jenifitWorkoutCard: some View {
        let workout = todaysWorkout
        let visibleCount = showAllExercises ? workout.exercises.count : min(3, workout.exercises.count)
        let hasMore = workout.exercises.count > 3

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Space.sm) {
                // Title row — Fraunces title with the DayBadge as a small
                // leading-trailing pill. The hero EditorialPlaceholder
                // band that used to sit above the card was dropped in
                // Phase 16b; the day signal moves inline so the card
                // matches the streak/benchmark aesthetic.
                HStack(alignment: .top, spacing: Space.sm) {
                    Text(workout.name)
                        .font(Typo.title)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    DayBadge(label: "Day \(currentDay)")
                }

                // Subtitle — preset description tagline if authored,
                // otherwise the goal · level eyebrow as the fallback.
                if let desc = workout.description {
                    Text(desc)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("\(workoutGoalLabel(workout.goal))\u{2009}·\u{2009}\(workoutDifficultyLabel(workout.difficulty))")
                        .font(Typo.eyebrow).tracking(1)
                        .foregroundStyle(Palette.accent)
                }

                // Stats row — duration · count · equipment.
                Text("\(workout.estimatedDuration) MIN\u{2009}·\u{2009}\(workout.exercises.count) EXERCISES\u{2009}·\u{2009}NO EQUIPMENT")
                    .font(Typo.eyebrow).tracking(1)
                    .foregroundStyle(Palette.textSecondary)

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

                // Start CTA — full-card-width cocoa primary.
                Button {
                    guard payment.hasProAccess else {
                        print("[HomeView] session entry blocked: hasProAccess=false (routine)")
                        return
                    }
                    Haptics.vibrate()
                    currentWorkout = workout
                    showRoutineSession = true
                } label: {
                    HStack {
                        Text("START")
                            .font(.system(size: 15, weight: .bold))
                            .tracking(2)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.accent)
                    }
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(Palette.bgInverse, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(Space.md)
        }
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .plankShadow()
        .padding(.horizontal, Space.screenPadding)
    }

    // MARK: - JeniFit Streak Card (Phase 6)

    private var jenifitStreakCard: some View {
        let count = streakCount
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

                Text("\(weeklyCount) session\(weeklyCount == 1 ? "" : "s") this week — keep it up")
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

    // MARK: - Text Bubble

    private func kiraBubble(_ text: String) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            kiraAvatar
            Text(text)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .plankShadow()
            Spacer(minLength: 48)
        }
    }

    private var kiraAvatar: some View {
        Image(currentTrainerPhoto)
            .resizable().scaledToFill()
            .frame(width: 28, height: 28)
            .clipShape(Circle())
    }

    // MARK: - Benchmark Card (Phase 16b — clean card, no chat-bubble)
    //
    // Replaces the avatar + chat-bubble pattern (kiraBenchmarkModule)
    // with a card matching the workout/streak aesthetic. Same data
    // (benchmark prompt, last-hold + days-ago stats, LET'S GO CTA)
    // and same callback into showPreSession.

    private var benchmarkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(benchmarkText)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let last = lastBenchmark, let days = daysSinceLastBenchmark {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.0fs", last.holdTime))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)
                        Text("last hold")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(days)d")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)
                        Text("ago")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }

            Button {
                guard payment.hasProAccess else {
                    print("[HomeView] session entry blocked: hasProAccess=false (plank benchmark)")
                    return
                }
                print("[HomeView] session entry allowed (plank benchmark)")
                Haptics.medium()
                showPreSession = true
            } label: {
                Text("LET'S GO")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Palette.divider, lineWidth: 1.5)
                    )
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .plankShadow()
    }

    // MARK: - Trainer Voice (adapts to selected coach)

    private var greetingText: String {
        let routineCount = sessionLogs.filter { $0.sessionType == "routine" }.count
        let name = userName.isEmpty ? "" : " \(userName)"
        let hour = Calendar.current.component(.hour, from: .now)

        switch voicePreference {
        case "encouraging": // Jeni — warm, reflective, calm
            if routineCount == 0 { return "Hi\(name). I'm Jeni. I made you a gentle start. Let's do this." }
            if todayHasSession { return "Coming back\(name)? I love it." }
            let affirmations = [
                "Today's your day — I can feel it.",
                "You showed up. That's the whole game.",
                "Day \(currentDay). I see you putting in the work.",
                "Steady wins. You're doing this.",
            ]
            return affirmations[currentDay % affirmations.count]

        case "balanced": // Matson — chill, SoCal, playful
            if routineCount == 0 { return "Yo\(name). I'm Matson. I got a workout lined up for you. It's gonna be good." }
            if todayHasSession { return "Back again\(name)? You're an animal." }
            let timeGreeting = hour < 12 ? "Morning\(name)." : hour < 17 ? "What's good\(name)." : "Evening\(name)."
            let affirmations = [
                "You're showing up and that's the hardest part.",
                "Looking stronger every day, not gonna lie.",
                "Your core's getting dialed in.",
                "Day \(currentDay). Still in the game. Respect.",
            ]
            return "\(timeGreeting) \(affirmations[currentDay % affirmations.count])"

        default: // Kira — sassy, real, direct
            if routineCount == 0 { return "Hey\(name). I'm Kira, your coach. I made your first workout. You ready?" }
            if todayHasSession { return "Back for seconds\(name)? I respect that." }
            let timeGreeting = hour < 12 ? "Morning\(name)." : hour < 17 ? "Hey\(name)." : "Evening\(name)."
            let affirmations = [
                "You showed up. That's the whole game.",
                "Consistency looks good on you.",
                "Your core is getting stronger whether you feel it or not.",
                "Day \(currentDay). Still here. That says something.",
            ]
            return "\(timeGreeting) \(affirmations[currentDay % affirmations.count])"
        }
    }

    private var benchmarkText: String {
        if let last = lastBenchmark, let days = daysSinceLastBenchmark {
            switch voicePreference {
            case "encouraging":
                return days >= 7 ? "Time for your plank check-in. I'll guide you through it." : "Last plank was \(Int(last.holdTime))s. Let's see how you've grown."
            case "balanced":
                return days >= 7 ? "Plank time. I'll watch your form, you just hold." : "\(Int(last.holdTime))s last time. Think you can top it?"
            default:
                return days >= 7 ? "Plank check-in. I'll coach your form live." : "Last plank: \(Int(last.holdTime))s. Beat it?"
            }
        }
        switch voicePreference {
        case "encouraging": return "Let's do your first plank together. I'll watch your form and guide you."
        case "balanced": return "Plank check. I'll watch your form, you hold. Easy."
        default: return "Plank check. I watch your form, you hold. Ready?"
        }
    }

    private var statsText: String {
        let count = sessionLogs.filter { $0.sessionType == "routine" }.count
        switch voicePreference {
        case "encouraging":
            if streakCount >= 7 { return "\(streakCount) days in a row. \(count) sessions. You inspire me. ✨" }
            return "\(count) workouts complete. Every one matters."
        case "balanced":
            if streakCount >= 7 { return "\(streakCount) day streak. \(count) sessions. You're on fire. 🔥" }
            return "\(count) workouts in the bag. Keep stacking."
        default:
            if streakCount >= 7 { return "\(streakCount) day streak. \(count) sessions. Locked in. 🔥" }
            return "\(count) workouts done. Keep showing up."
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
            Text(value).font(Typo.title).foregroundStyle(Palette.textPrimary)
            Text(label).font(Typo.caption).foregroundStyle(Palette.textSecondary).tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }
}
