import SwiftUI
import SwiftData
import PlankSync

/// Chat-style home screen. Kira presents your daily workout as chat bubbles.
struct HomeView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("hasCompletedFirstSession") private var hasCompletedFirstSession = false
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("sessionLengthPref") private var sessionLengthPref = 7

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var sessionLogs: [SessionLogRecord]
    @Query(sort: \DayProgressRecord.programDay, order: .reverse) private var dayProgress: [DayProgressRecord]

    // Plank benchmark flow
    @State private var showPreSession = false
    @State private var showSession = false
    @State private var lastHoldTime: TimeInterval = 0
    @State private var lastQuality: Double = 0
    @State private var showPlankPostSession = false

    // Routine flow
    @State private var showRoutineSession = false
    @State private var showPostRoutine = false
    @State private var routineExerciseResults: [ExerciseResultEntry] = []
    @State private var routineTotalDuration: TimeInterval = 0
    @State private var currentWorkout: WorkoutPreset?
    @State private var lastSessionRating: Int = 0
    @State private var lastSessionTags: [String] = []

    // Chat animation state
    @State private var visibleBubbles: Int = 0
    @State private var showTyping = false
    @State private var hasAnimated = false

    private var currentDay: Int {
        (dayProgress.first?.programDay ?? 0) + 1
    }

    private var streakCount: Int {
        dayProgress.count
    }

    private var todaysWorkout: WorkoutPreset {
        if let current = currentWorkout { return current }
        let goal = WorkoutGoal(rawValue: userGoal) ?? .fullCore
        let presets = WorkoutPreset.presets(for: goal)
        let routineCount = sessionLogs.filter { $0.sessionType == "routine" }.count
        return presets[routineCount % presets.count]
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

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with profile menu
            chatTopBar

            // Chat area
            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.md) {
                    // Kira profile header
                    kiraHeader
                        .padding(.top, Space.md)

                    // Chat bubbles — appear sequentially
                    if visibleBubbles >= 1 {
                        greetingBubble
                            .transition(.chatBubble)
                    }

                    if visibleBubbles >= 2 {
                        workoutBubble
                            .transition(.chatBubble)
                    }

                    if visibleBubbles >= 3 {
                        benchmarkBubble
                            .transition(.chatBubble)
                    }

                    if visibleBubbles >= 4 && hasCompletedFirstSession {
                        statsBubble
                            .transition(.chatBubble)
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, 80)
            }
            .background(Palette.bgPrimary)
        }
        .onAppear { startChatAnimation() }
        // Session fullscreen covers
        .fullScreenCover(isPresented: $showRoutineSession) {
            if let workout = currentWorkout {
                RoutineSessionView(workout: workout) { results, duration in
                    routineExerciseResults = results
                    routineTotalDuration = duration
                    showRoutineSession = false
                    showPostRoutine = true
                }
            }
        }
        .fullScreenCover(isPresented: $showPostRoutine) {
            PostRoutineView(
                exerciseResults: routineExerciseResults,
                totalDuration: routineTotalDuration,
                workoutName: currentWorkout?.name ?? "Workout",
                streakCount: todayHasSession ? streakCount : streakCount + 1,
                isFirstWorkoutToday: !todayHasSession
            ) { rating, tags in
                lastSessionRating = rating
                lastSessionTags = tags
            } onDone: {
                saveRoutineSession()
                showPostRoutine = false
                hasCompletedFirstSession = true
            }
        }
        .fullScreenCover(isPresented: $showPreSession) {
            PreSessionView(
                exerciseType: "Plank Benchmark",
                dayNumber: currentDay
            ) {
                showPreSession = false
                showSession = true
            } onDismiss: {
                showPreSession = false
            }
        }
        .fullScreenCover(isPresented: $showSession) {
            SessionView(
                exerciseType: "Plank Benchmark",
                dayNumber: currentDay,
                targetTime: 60
            ) { holdTime, quality, faults in
                lastHoldTime = holdTime
                lastQuality = quality
                showSession = false
                saveBenchmarkSession(holdTime: holdTime, quality: quality, faults: faults)
                showPlankPostSession = true
            }
        }
        .fullScreenCover(isPresented: $showPlankPostSession) {
            PostSessionView(
                holdTime: lastHoldTime,
                qualityScore: lastQuality,
                dayNumber: currentDay,
                streakCount: streakCount,
                previousScore: nil,
                playedLines: []
            ) {
                showPlankPostSession = false
            }
        }
    }

    // MARK: - Chat Animation

    private func startChatAnimation() {
        guard !hasAnimated else { return }
        hasAnimated = true

        // Typing indicator, then bubbles appear one by one
        showTyping = true
        let delays: [Double] = [0.6, 1.4, 2.2, 3.0]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if i > 0 { showTyping = false }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    visibleBubbles = i + 1
                }
                Haptics.soft()
                // Show typing before next bubble
                if i < delays.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showTyping = true
                    }
                } else {
                    showTyping = false
                }
            }
        }
    }

    // MARK: - Top Bar

    private var chatTopBar: some View {
        HStack {
            Spacer()

            // Profile menu
            Menu {
                Button { } label: { Label("Edit Profile", systemImage: "person") }
                Button { } label: { Label("Notifications", systemImage: "bell") }
                Button { } label: { Label("Account", systemImage: "gearshape") }
                Divider()
                Button { } label: { Label("Feedback", systemImage: "bubble.left") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Palette.bgElevated)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.xs)
        .background(Palette.bgPrimary)
    }

    // MARK: - Kira Header (profile pic + name)

    private var kiraHeader: some View {
        VStack(spacing: Space.sm) {
            Image("coach-kira")
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Palette.accent.opacity(0.3), lineWidth: 2)
                )

            Text("Kira")
                .font(Typo.heading)
                .foregroundStyle(Palette.textPrimary)

            Text("Your Coach")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)

            // Typing indicator
            if showTyping {
                typingIndicator
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Palette.textSecondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .offset(y: typingBounce(index: i))
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(Palette.bgElevated)
        .clipShape(Capsule())
    }

    @State private var typingBouncePhase = false

    private func typingBounce(index: Int) -> CGFloat {
        // Simple staggered bounce
        return typingBouncePhase ? -3 : 0
    }

    // MARK: - Chat Bubbles

    private var greetingBubble: some View {
        ChatBubble {
            Text(greetingMessage)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var greetingMessage: String {
        let routineCount = sessionLogs.filter { $0.sessionType == "routine" }.count
        if routineCount == 0 { return "I picked your first workout. Let's see what you got." }
        if todayHasSession { return "Back for more? I respect that. Here's another one." }
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Morning. I got something for you." }
        if hour < 17 { return "Afternoon session. No excuses today." }
        return "End of day. Let's finish strong."
    }

    // MARK: - Workout Bubble (main CTA)

    private var workoutBubble: some View {
        let workout = todaysWorkout
        return ChatBubble {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("TODAY'S CORE")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(2)

                Text(workout.name)
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textPrimary)

                HStack(spacing: Space.md) {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("\(workout.estimatedDuration) min")
                    }
                    HStack(spacing: Space.xs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                        Text("\(workout.exercises.count) exercises")
                    }
                }
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)

                // Exercise preview pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.xs) {
                        ForEach(workout.exercises.prefix(5), id: \.exerciseId) { slot in
                            if let ex = slot.exercise {
                                Text(ex.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Palette.textSecondary)
                                    .padding(.horizontal, Space.sm)
                                    .padding(.vertical, Space.xs)
                                    .background(Palette.bgPrimary)
                                    .clipShape(Capsule())
                            }
                        }
                        if workout.exercises.count > 5 {
                            Text("+\(workout.exercises.count - 5)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                                .padding(.horizontal, Space.sm)
                                .padding(.vertical, Space.xs)
                                .background(Palette.bgPrimary)
                                .clipShape(Capsule())
                        }
                    }
                }

                Button {
                    Haptics.vibrate()
                    currentWorkout = workout
                    showRoutineSession = true
                } label: {
                    Text("START")
                        .font(Typo.body)
                        .fontWeight(.bold)
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: Space.minTapTarget + 8)
                        .background(Palette.bgInverse)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                }
                .padding(.top, Space.xs)
            }
        }
    }

    // MARK: - Benchmark Bubble

    private var benchmarkBubble: some View {
        ChatBubble {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Text("PLANK BENCHMARK")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .tracking(2)
                    Spacer()
                    if benchmarkDue {
                        Text("DUE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, 3)
                            .background(Palette.accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                if let last = lastBenchmark, let days = daysSinceLastBenchmark {
                    HStack(spacing: Space.lg) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.0fs", last.holdTime))
                                .font(Typo.heading)
                                .foregroundStyle(Palette.textPrimary)
                            Text("last hold")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(days)d ago")
                                .font(Typo.heading)
                                .foregroundStyle(Palette.textPrimary)
                            Text("last check-in")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                } else {
                    Text("Camera tracks your form. Let's get a baseline.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }

                Button {
                    Haptics.medium()
                    showPreSession = true
                } label: {
                    Text(benchmarkDue ? "CHECK IN" : "BENCHMARK")
                        .font(Typo.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Space.minTapTarget)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(Palette.divider, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Stats Bubble

    private var statsBubble: some View {
        ChatBubble {
            HStack(spacing: Space.md) {
                VStack(spacing: Space.xs) {
                    Text("\(streakCount)")
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textPrimary)
                    Text("streak")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Palette.divider)
                    .frame(width: 1, height: 32)

                VStack(spacing: Space.xs) {
                    let count = sessionLogs.filter { $0.sessionType == "routine" }.count
                    Text("\(count)")
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textPrimary)
                    Text("workouts")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Palette.divider)
                    .frame(width: 1, height: 32)

                VStack(spacing: Space.xs) {
                    Text("Day \(currentDay)")
                        .font(Typo.heading)
                        .foregroundStyle(Palette.accent)
                    Text("today")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Persistence

    private func saveRoutineSession() {
        let userId = "local-user"
        let results = routineExerciseResults
        let resultsData = try? JSONEncoder().encode(results)

        let session = SessionLogRecord(
            userId: userId,
            exerciseType: "routine",
            holdTime: 0,
            targetTime: 0,
            qualityScore: Double(lastSessionRating) * 2.0,
            sessionType: "routine",
            presetId: currentWorkout?.id,
            exerciseResults: resultsData,
            totalDuration: routineTotalDuration
        )
        modelContext.insert(session)

        if lastSessionRating > 0 {
            let rating = SessionRatingRecord(
                sessionLogId: session.id,
                rating: lastSessionRating,
                tags: lastSessionTags
            )
            modelContext.insert(rating)
        }

        let day = currentDay
        let compositeKey = "\(userId):\(day)"
        let descriptor = FetchDescriptor<DayProgressRecord>(
            predicate: #Predicate { $0.compositeKey == compositeKey }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.primarySessionId = session.id
            existing.primaryQualityScore = Double(lastSessionRating) * 2.0
            existing.primaryHoldTime = 0
            var ids = existing.sessionLogIds ?? []
            ids.append(session.id)
            existing.sessionLogIds = ids
            existing.updatedAt = .now
        } else {
            let progress = DayProgressRecord(
                userId: userId,
                programDay: day,
                primarySessionId: session.id,
                primaryQualityScore: Double(lastSessionRating) * 2.0,
                primaryHoldTime: 0
            )
            progress.sessionLogIds = [session.id]
            modelContext.insert(progress)
        }

        try? modelContext.save()
        hasCompletedFirstSession = true
    }

    private func saveBenchmarkSession(holdTime: Double, quality: Double, faults: Int) {
        let userId = "local-user"

        let session = SessionLogRecord(
            userId: userId,
            exerciseType: "plank",
            holdTime: holdTime,
            targetTime: 60,
            qualityScore: quality,
            formFaultsCount: faults,
            sessionType: "plank_benchmark",
            plankHoldTime: holdTime,
            plankFormScore: quality
        )
        modelContext.insert(session)

        let day = currentDay
        let compositeKey = "\(userId):\(day)"
        let descriptor = FetchDescriptor<DayProgressRecord>(
            predicate: #Predicate { $0.compositeKey == compositeKey }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            var ids = existing.sessionLogIds ?? []
            ids.append(session.id)
            existing.sessionLogIds = ids
            existing.updatedAt = .now
        } else {
            let progress = DayProgressRecord(
                userId: userId,
                programDay: day,
                primarySessionId: session.id,
                primaryQualityScore: quality,
                primaryHoldTime: holdTime
            )
            progress.sessionLogIds = [session.id]
            modelContext.insert(progress)
        }

        try? modelContext.save()
        hasCompletedFirstSession = true
    }
}

// MARK: - Chat Bubble Component

struct ChatBubble<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }
}

// MARK: - Chat Bubble Transition

extension AnyTransition {
    static var chatBubble: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.95, anchor: .top))
                .combined(with: .offset(y: 8)),
            removal: .opacity
        )
    }
}

// MARK: - Stat Card (kept for Analytics)

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Space.xs) {
            Text(value)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }
}
