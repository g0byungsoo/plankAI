import SwiftUI
import SwiftData
import PlankSync

struct HomeView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("hasCompletedFirstSession") private var hasCompletedFirstSession = false
    @AppStorage("userGoal") private var userGoal = ""
    @AppStorage("sessionLengthPref") private var sessionLengthPref = 7

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var sessionLogs: [SessionLogRecord]
    @Query(sort: \DayProgressRecord.programDay, order: .reverse) private var dayProgress: [DayProgressRecord]

    @State private var showPreSession = false
    @State private var showSession = false
    @State private var lastHoldTime: TimeInterval = 0
    @State private var lastQuality: Double = 0
    @State private var showPlankPostSession = false
    @State private var showRoutineSession = false
    @State private var showPostRoutine = false
    @State private var routineExerciseResults: [ExerciseResultEntry] = []
    @State private var routineTotalDuration: TimeInterval = 0
    @State private var currentWorkout: WorkoutPreset?
    @State private var lastSessionRating: Int = 0
    @State private var lastSessionTags: [String] = []

    // Animation
    @State private var msgOpacity: [Double] = [0, 0, 0, 0]
    @State private var msgOffset: [CGFloat] = [16, 16, 16, 16]
    @State private var hasAnimated = false

    // Expand exercise list
    @State private var showAllExercises = false

    // Settings
    @State private var activeSheet: SettingsSheet?

    @AppStorage("voicePreference") private var voicePreference = "keepItReal"

    private var currentDay: Int { (dayProgress.first?.programDay ?? 0) + 1 }

    private var currentTrainerPhoto: String {
        switch voicePreference {
        case "encouraging": return "coach-sarah"
        case "balanced": return "coach-matson"
        default: return "coach-kira"
        }
    }

    private var currentTrainerName: String {
        switch voicePreference {
        case "encouraging": return "Sarah"
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
            messageTopBar
            Divider().foregroundStyle(Palette.divider)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    dateStamp.padding(.top, Space.sm)

                    kiraBubble(greetingText)
                        .opacity(msgOpacity[0]).offset(y: msgOffset[0])

                    kiraWorkoutModule
                        .opacity(msgOpacity[1]).offset(y: msgOffset[1])

                    kiraBenchmarkModule
                        .opacity(msgOpacity[2]).offset(y: msgOffset[2])

                    if hasCompletedFirstSession {
                        kiraBubble(statsText)
                            .opacity(msgOpacity[3]).offset(y: msgOffset[3])
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 100)
            }
            .background(Palette.bgPrimary)
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
                    routineExerciseResults = results
                    routineTotalDuration = duration
                    showRoutineSession = false
                    showPostRoutine = true
                }
            }
        }
        .fullScreenCover(isPresented: $showPostRoutine) {
            PostRoutineView(
                exerciseResults: routineExerciseResults, totalDuration: routineTotalDuration,
                workoutName: currentWorkout?.name ?? "Workout",
                streakCount: todayHasSession ? streakCount : streakCount + 1,
                isFirstWorkoutToday: !todayHasSession
            ) { rating, tags in
                lastSessionRating = rating; lastSessionTags = tags
            } onDone: {
                saveRoutineSession(); showPostRoutine = false; hasCompletedFirstSession = true
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
            Menu {
                Button { activeSheet = .editProfile } label: { Label("Edit Profile", systemImage: "person") }
                Button { activeSheet = .notifications } label: { Label("Notifications", systemImage: "bell") }
                Button { activeSheet = .account } label: { Label("Account", systemImage: "gearshape") }
                Divider()
                Button { activeSheet = .feedback } label: { Label("Feedback", systemImage: "bubble.left") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
            }
            Spacer()
            Button {
                activeSheet = .trainer
            } label: {
                VStack(spacing: 2) {
                    Image(currentTrainerPhoto)
                        .resizable().scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    Text(currentTrainerName)
                        .font(Typo.caption).fontWeight(.medium)
                        .foregroundStyle(Palette.textPrimary)
                }
            }
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, Space.screenPadding)
        .padding(.vertical, Space.xs)
        .background(Palette.bgPrimary)
    }

    // MARK: - Date Stamp

    private var dateStamp: some View {
        Text(Date.now.formatted(.dateTime.weekday(.wide).hour(.defaultDigits(amPM: .abbreviated)).minute()))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.textSecondary)
            .padding(.vertical, Space.xs)
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

    // MARK: - Workout Module (expandable)

    private var kiraWorkoutModule: some View {
        let workout = todaysWorkout
        let visibleCount = showAllExercises ? workout.exercises.count : min(4, workout.exercises.count)
        let hasMore = workout.exercises.count > 4

        return HStack(alignment: .bottom, spacing: 6) {
            kiraAvatar

            VStack(alignment: .leading, spacing: 0) {
                // Kira intro + workout info
                VStack(alignment: .leading, spacing: 6) {
                    Text(workoutIntroText)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)

                    HStack(spacing: 12) {
                        Label("\(workout.estimatedDuration) min", systemImage: "clock")
                        Label("\(workout.exercises.count) exercises", systemImage: "flame.fill")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // Exercise list
                VStack(spacing: 0) {
                    ForEach(Array(workout.exercises.prefix(visibleCount).enumerated()), id: \.offset) { i, slot in
                        if let ex = slot.exercise {
                            HStack(spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Palette.textSecondary)
                                    .frame(width: 18)

                                Text(ex.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Palette.textPrimary)

                                Spacer()

                                Text("\(slot.duration)s")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)

                            if i < visibleCount - 1 {
                                Divider().padding(.leading, 42)
                            }
                        }
                    }

                    // Expand/collapse
                    if hasMore {
                        Button {
                            Haptics.light()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                showAllExercises.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(showAllExercises ? "show less" : "+\(workout.exercises.count - 4) more")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: showAllExercises ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(Palette.accent)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .background(Palette.bgPrimary.opacity(0.5))

                // Start button
                Button {
                    Haptics.vibrate()
                    currentWorkout = workout
                    showRoutineSession = true
                } label: {
                    Text("START")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Palette.bgInverse)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(10)
            }
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .plankShadow()

            Spacer(minLength: 16)
        }
    }

    // MARK: - Benchmark Module (trainer voice)

    private var kiraBenchmarkModule: some View {
        HStack(alignment: .bottom, spacing: 6) {
            kiraAvatar

            VStack(alignment: .leading, spacing: 10) {
                Text(benchmarkText)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)

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
            .padding(14)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .plankShadow()

            Spacer(minLength: 16)
        }
    }

    // MARK: - Kira's Voice

    private var greetingText: String {
        let routineCount = sessionLogs.filter { $0.sessionType == "routine" }.count
        let name = userName.isEmpty ? "" : " \(userName)"
        let hour = Calendar.current.component(.hour, from: .now)

        if routineCount == 0 {
            return "Hey\(name). I'm Kira, your coach. I made your first workout. You ready?"
        }
        if todayHasSession {
            return "Back for seconds\(name)? I respect that."
        }

        let timeGreeting = hour < 12 ? "Morning\(name)." : hour < 17 ? "Hey\(name)." : "Evening\(name)."
        let affirmations = [
            "You showed up. That's the whole game.",
            "Consistency looks good on you.",
            "Your core is getting stronger whether you feel it or not.",
            "Day \(currentDay). Still here. That says something.",
        ]
        return "\(timeGreeting) \(affirmations[currentDay % affirmations.count])"
    }

    private var workoutIntroText: String {
        let workout = todaysWorkout
        let routineCount = sessionLogs.filter { $0.sessionType == "routine" }.count
        if routineCount == 0 { return "Here's your first one. \(workout.name)." }
        return "Today's plan. \(workout.name)."
    }

    private var benchmarkText: String {
        if let last = lastBenchmark, let days = daysSinceLastBenchmark {
            if days >= 7 { return "Plank check-in. I'll coach your form live." }
            return "Last plank: \(Int(last.holdTime))s. Beat it?"
        }
        return "Plank check. I watch your form, you hold. Ready?"
    }

    private var statsText: String {
        let count = sessionLogs.filter { $0.sessionType == "routine" }.count
        if streakCount >= 7 { return "\(streakCount) day streak. \(count) sessions. Locked in. 🔥" }
        return "\(count) workouts done. Keep showing up."
    }

    // MARK: - Persistence

    private func saveRoutineSession() {
        let userId = "local-user"
        let resultsData = try? JSONEncoder().encode(routineExerciseResults)
        let session = SessionLogRecord(
            userId: userId, exerciseType: "routine", holdTime: 0, targetTime: 0,
            qualityScore: Double(lastSessionRating) * 2.0, sessionType: "routine",
            presetId: currentWorkout?.id, exerciseResults: resultsData,
            totalDuration: routineTotalDuration
        )
        modelContext.insert(session)
        if lastSessionRating > 0 {
            modelContext.insert(SessionRatingRecord(sessionLogId: session.id, rating: lastSessionRating, tags: lastSessionTags))
        }
        let compositeKey = "\(userId):\(currentDay)"
        let descriptor = FetchDescriptor<DayProgressRecord>(predicate: #Predicate { $0.compositeKey == compositeKey })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.primarySessionId = session.id
            existing.primaryQualityScore = Double(lastSessionRating) * 2.0
            existing.primaryHoldTime = 0
            var ids = existing.sessionLogIds ?? []; ids.append(session.id); existing.sessionLogIds = ids
            existing.updatedAt = .now
        } else {
            let progress = DayProgressRecord(userId: userId, programDay: currentDay, primarySessionId: session.id,
                                            primaryQualityScore: Double(lastSessionRating) * 2.0, primaryHoldTime: 0)
            progress.sessionLogIds = [session.id]; modelContext.insert(progress)
        }
        try? modelContext.save(); hasCompletedFirstSession = true
    }

    private func saveBenchmarkSession(holdTime: Double, quality: Double, faults: Int) {
        let userId = "local-user"
        let session = SessionLogRecord(
            userId: userId, exerciseType: "plank", holdTime: holdTime, targetTime: 60,
            qualityScore: quality, formFaultsCount: faults, sessionType: "plank_benchmark",
            plankHoldTime: holdTime, plankFormScore: quality
        )
        modelContext.insert(session)
        let compositeKey = "\(userId):\(currentDay)"
        let descriptor = FetchDescriptor<DayProgressRecord>(predicate: #Predicate { $0.compositeKey == compositeKey })
        if let existing = try? modelContext.fetch(descriptor).first {
            var ids = existing.sessionLogIds ?? []; ids.append(session.id); existing.sessionLogIds = ids
            existing.updatedAt = .now
        } else {
            let progress = DayProgressRecord(userId: userId, programDay: currentDay, primarySessionId: session.id,
                                            primaryQualityScore: quality, primaryHoldTime: holdTime)
            progress.sessionLogIds = [session.id]; modelContext.insert(progress)
        }
        try? modelContext.save(); hasCompletedFirstSession = true
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
