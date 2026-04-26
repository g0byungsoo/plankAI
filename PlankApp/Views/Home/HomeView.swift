import SwiftUI
import SwiftData
import PlankSync

/// iMessage-style home. Kira texts you your daily workout.
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

    // Chat animation
    @State private var visibleMessages: Int = 0
    @State private var showTyping = false
    @State private var hasAnimated = false

    private var currentDay: Int { (dayProgress.first?.programDay ?? 0) + 1 }
    private var streakCount: Int { dayProgress.count }

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
            // iMessage-style top bar
            messageTopBar

            Divider().foregroundStyle(Palette.divider)

            // Messages area
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: Space.xs) {
                    // Date stamp
                    dateStamp
                        .padding(.top, Space.md)

                    // Messages animate in
                    if visibleMessages >= 1 {
                        kiraMessage(greetingText)
                    }

                    if visibleMessages >= 2 {
                        kiraWorkoutCard
                    }

                    if visibleMessages >= 3 {
                        kiraBenchmarkCard
                    }

                    if visibleMessages >= 4 && hasCompletedFirstSession {
                        kiraMessage(statsText)
                    }

                    // Typing indicator
                    if showTyping {
                        typingBubble
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
                    }
                }
                .padding(.horizontal, Space.sm)
                .padding(.bottom, 80)
            }
            .background(Palette.bgPrimary)
        }
        .onAppear { runChatSequence() }
        // Session covers
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
            PreSessionView(exerciseType: "Plank Benchmark", dayNumber: currentDay) {
                showPreSession = false
                showSession = true
            } onDismiss: { showPreSession = false }
        }
        .fullScreenCover(isPresented: $showSession) {
            SessionView(exerciseType: "Plank Benchmark", dayNumber: currentDay, targetTime: 60) { holdTime, quality, faults in
                lastHoldTime = holdTime
                lastQuality = quality
                showSession = false
                saveBenchmarkSession(holdTime: holdTime, quality: quality, faults: faults)
                showPlankPostSession = true
            }
        }
        .fullScreenCover(isPresented: $showPlankPostSession) {
            PostSessionView(holdTime: lastHoldTime, qualityScore: lastQuality, dayNumber: currentDay, streakCount: streakCount, previousScore: nil, playedLines: []) { showPlankPostSession = false }
        }
    }

    // MARK: - Chat Sequence

    private func runChatSequence() {
        guard !hasAnimated else { return }
        hasAnimated = true

        let delays: [Double] = [0.4, 1.6, 2.8, 3.8]
        for (i, delay) in delays.enumerated() {
            // Show typing before each message
            DispatchQueue.main.asyncAfter(deadline: .now() + (i == 0 ? 0 : delay - 0.8)) {
                withAnimation(.easeInOut(duration: 0.2)) { showTyping = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showTyping = false
                    visibleMessages = i + 1
                }
                Haptics.soft()
            }
        }
    }

    // MARK: - Top Bar (iMessage style)

    private var messageTopBar: some View {
        VStack(spacing: Space.xs) {
            HStack {
                // Settings menu (left)
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
                        .frame(width: 32, height: 32)
                }

                Spacer()

                // Center: Kira profile
                VStack(spacing: 2) {
                    Image("coach-kira")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())

                    Text("Kira")
                        .font(Typo.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Palette.textPrimary)
                }

                Spacer()

                // Right placeholder for symmetry
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, Space.screenPadding)
        }
        .padding(.vertical, Space.xs)
        .background(Palette.bgPrimary)
    }

    // MARK: - Date Stamp

    private var dateStamp: some View {
        Text(Date.now.formatted(.dateTime.weekday(.wide).hour(.defaultDigits(amPM: .abbreviated)).minute()))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.textSecondary)
            .padding(.vertical, Space.sm)
    }

    // MARK: - Kira Text Message (left-aligned, warm bubble)

    private func kiraMessage(_ text: String) -> some View {
        HStack(alignment: .bottom, spacing: Space.xs) {
            // Small profile pic on last message of group
            Image("coach-kira")
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())

            Text(text)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Palette.bgElevated)
                .clipShape(MessageBubbleShape(isFromUser: false))
                .plankShadow()

            Spacer(minLength: 48)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottomLeading)).combined(with: .offset(y: 6)))
    }

    // MARK: - Workout Card (rich message bubble)

    private var kiraWorkoutCard: some View {
        let workout = todaysWorkout
        return HStack(alignment: .bottom, spacing: Space.xs) {
            Image("coach-kira")
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("TODAY'S CORE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(2)

                Text(workout.name)
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textPrimary)

                HStack(spacing: Space.md) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("\(workout.estimatedDuration) min")
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                        Text("\(workout.exercises.count) exercises")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)

                // Exercise pills
                FlowLayout(spacing: 4) {
                    ForEach(workout.exercises.prefix(4), id: \.exerciseId) { slot in
                        if let ex = slot.exercise {
                            Text(ex.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Palette.bgPrimary)
                                .clipShape(Capsule())
                        }
                    }
                    if workout.exercises.count > 4 {
                        Text("+\(workout.exercises.count - 4) more")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Palette.bgPrimary)
                            .clipShape(Capsule())
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
                        .frame(height: Space.minTapTarget + 4)
                        .background(Palette.bgInverse)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
            }
            .padding(12)
            .background(Palette.bgElevated)
            .clipShape(MessageBubbleShape(isFromUser: false))
            .plankShadow()

            Spacer(minLength: 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottomLeading)).combined(with: .offset(y: 6)))
    }

    // MARK: - Benchmark Card (rich message bubble)

    private var kiraBenchmarkCard: some View {
        HStack(alignment: .bottom, spacing: Space.xs) {
            Image("coach-kira")
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Text("PLANK BENCHMARK")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                        .tracking(2)
                    Spacer()
                    if benchmarkDue {
                        Text("DUE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Palette.accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                if let last = lastBenchmark, let days = daysSinceLastBenchmark {
                    HStack(spacing: Space.lg) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(format: "%.0fs", last.holdTime))
                                .font(Typo.heading)
                                .foregroundStyle(Palette.textPrimary)
                            Text("last hold")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(days)d ago")
                                .font(Typo.heading)
                                .foregroundStyle(Palette.textPrimary)
                            Text("last check-in")
                                .font(.system(size: 11))
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
                        .frame(height: Space.minTapTarget - 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(Palette.divider, lineWidth: 1)
                        )
                }
            }
            .padding(12)
            .background(Palette.bgElevated)
            .clipShape(MessageBubbleShape(isFromUser: false))
            .plankShadow()

            Spacer(minLength: 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottomLeading)).combined(with: .offset(y: 6)))
    }

    // MARK: - Stats Text

    private var statsText: String {
        let count = sessionLogs.filter { $0.sessionType == "routine" }.count
        if streakCount >= 7 {
            return "\(streakCount) day streak. \(count) workouts. You're locked in."
        }
        return "Day \(currentDay). \(count) workouts done. Keep showing up."
    }

    // MARK: - Typing Indicator

    private var typingBubble: some View {
        HStack(alignment: .bottom, spacing: Space.xs) {
            Image("coach-kira")
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())

            HStack(spacing: 4) {
                TypingDot(delay: 0)
                TypingDot(delay: 0.15)
                TypingDot(delay: 0.3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Palette.bgElevated)
            .clipShape(MessageBubbleShape(isFromUser: false))
            .plankShadow()

            Spacer()
        }
    }

    // MARK: - Greeting

    private var greetingText: String {
        let routineCount = sessionLogs.filter { $0.sessionType == "routine" }.count
        if routineCount == 0 { return "I picked your first workout. Let's see what you got." }
        if todayHasSession { return "Back for more? I respect that." }
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Morning. I got something for you." }
        if hour < 17 { return "Afternoon session. No excuses." }
        return "End of day. Let's finish strong."
    }

    // MARK: - Persistence

    private func saveRoutineSession() {
        let userId = "local-user"
        let results = routineExerciseResults
        let resultsData = try? JSONEncoder().encode(results)

        let session = SessionLogRecord(
            userId: userId, exerciseType: "routine", holdTime: 0, targetTime: 0,
            qualityScore: Double(lastSessionRating) * 2.0, sessionType: "routine",
            presetId: currentWorkout?.id, exerciseResults: resultsData,
            totalDuration: routineTotalDuration
        )
        modelContext.insert(session)

        if lastSessionRating > 0 {
            modelContext.insert(SessionRatingRecord(
                sessionLogId: session.id, rating: lastSessionRating, tags: lastSessionTags
            ))
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
                userId: userId, programDay: day, primarySessionId: session.id,
                primaryQualityScore: Double(lastSessionRating) * 2.0, primaryHoldTime: 0
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
            userId: userId, exerciseType: "plank", holdTime: holdTime, targetTime: 60,
            qualityScore: quality, formFaultsCount: faults, sessionType: "plank_benchmark",
            plankHoldTime: holdTime, plankFormScore: quality
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
                userId: userId, programDay: day, primarySessionId: session.id,
                primaryQualityScore: quality, primaryHoldTime: holdTime
            )
            progress.sessionLogIds = [session.id]
            modelContext.insert(progress)
        }
        try? modelContext.save()
        hasCompletedFirstSession = true
    }
}

// MARK: - iMessage Bubble Shape

struct MessageBubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6

        var path = Path()

        if isFromUser {
            // Right-aligned bubble with tail on bottom-right
            path.addRoundedRect(in: CGRect(x: 0, y: 0, width: rect.width - tailSize, height: rect.height), cornerSize: CGSize(width: radius, height: radius))
            // Tail
            path.move(to: CGPoint(x: rect.width - tailSize, y: rect.height - 8))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: rect.height),
                control: CGPoint(x: rect.width - 2, y: rect.height - 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.width - tailSize - 4, y: rect.height),
                control: CGPoint(x: rect.width - tailSize, y: rect.height)
            )
        } else {
            // Left-aligned bubble with tail on bottom-left
            path.addRoundedRect(in: CGRect(x: tailSize, y: 0, width: rect.width - tailSize, height: rect.height), cornerSize: CGSize(width: radius, height: radius))
            // Tail
            path.move(to: CGPoint(x: tailSize, y: rect.height - 8))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.height),
                control: CGPoint(x: 2, y: rect.height - 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: tailSize + 4, y: rect.height),
                control: CGPoint(x: tailSize, y: rect.height)
            )
        }

        return path
    }
}

// MARK: - Typing Dot (animated)

struct TypingDot: View {
    let delay: Double
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(Palette.textSecondary.opacity(0.4))
            .frame(width: 8, height: 8)
            .offset(y: animating ? -4 : 2)
            .animation(
                .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: animating
            )
            .onAppear { animating = true }
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
