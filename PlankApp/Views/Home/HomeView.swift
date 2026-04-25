import SwiftUI
import SwiftData
import PlankSync

/// The home screen. Two CTAs: daily routine (primary) and plank benchmark (secondary).
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

        // Pick based on how many routine sessions completed
        let routineCount = sessionLogs.filter { $0.sessionType == "routine" }.count
        let presetIndex = routineCount % presets.count
        return presets[presetIndex]
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    header
                    routineCard
                    benchmarkCard
                    if hasCompletedFirstSession {
                        statsSection
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.top, Space.xl)
            }
            .background(Palette.bgPrimary)
            // Routine flow
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
            // Plank benchmark flow
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
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if hasCompletedFirstSession {
                Text("Hey, \(userName.isEmpty ? "there" : userName).")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                HStack(spacing: Space.xs) {
                    Text("Day")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                    Text("\(currentDay)")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .fontWeight(.bold)
                    Text("· Let's work.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }
            } else {
                Text("Welcome, \(userName.isEmpty ? "there" : userName).")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                Text("Your first workout is ready.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    // MARK: - Daily Routine Card (Primary CTA)

    private var routineCard: some View {
        let workout = todaysWorkout
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text("TODAY'S ROUTINE")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            Text(workout.name)
                .font(Typo.heading)
                .foregroundStyle(Palette.textPrimary)

            HStack(spacing: Space.sm) {
                Label("\(workout.estimatedDuration) min", systemImage: "clock")
                Label("\(workout.exercises.count) exercises", systemImage: "flame")
                Label(workout.difficulty.rawValue.capitalized, systemImage: "chart.bar")
            }
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)

            Button {
                Haptics.medium()
                currentWorkout = workout
                showRoutineSession = true
            } label: {
                Text("START WORKOUT")
                    .font(Typo.body)
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: Space.minTapTarget + 12)
                    .background(Palette.bgInverse)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .padding(.top, Space.sm)
        }
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }

    // MARK: - Plank Benchmark Card (Secondary)

    private var benchmarkCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("PLANK BENCHMARK")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .tracking(2)

                Spacer()

                if benchmarkDue {
                    Text("DUE")
                        .font(Typo.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, Space.xs)
                        .background(Palette.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if let last = lastBenchmark {
                HStack(spacing: Space.md) {
                    VStack(alignment: .leading) {
                        Text(String(format: "%.0fs", last.holdTime))
                            .font(Typo.heading)
                            .foregroundStyle(Palette.textPrimary)
                        Text("Last hold")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }

                    if let days = daysSinceLastBenchmark {
                        VStack(alignment: .leading) {
                            Text("\(days)d ago")
                                .font(Typo.heading)
                                .foregroundStyle(Palette.textPrimary)
                            Text("Last check-in")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }
            } else {
                Text("Track your plank form with camera coaching")
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
                    .frame(height: Space.minTapTarget + 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .stroke(Palette.divider, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .padding(.top, Space.xs)
        }
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: Space.sm) {
            StatCard(value: "\(streakCount)", label: "STREAK")
            let routineCount = sessionLogs.filter { $0.sessionType == "routine" }.count
            StatCard(value: "\(routineCount)", label: "WORKOUTS")
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

        // Save rating if provided
        if lastSessionRating > 0 {
            let rating = SessionRatingRecord(
                sessionLogId: session.id,
                rating: lastSessionRating,
                tags: lastSessionTags
            )
            modelContext.insert(rating)
        }

        // Update DayProgress
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

// MARK: - Stat Card

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
