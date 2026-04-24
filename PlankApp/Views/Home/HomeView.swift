import SwiftUI
import SwiftData
import PlankSync

/// The home screen. Adapts between first-time (launchpad) and returning-user (dashboard).
struct HomeView: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("hasCompletedFirstSession") private var hasCompletedFirstSession = false

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var sessionLogs: [SessionLogRecord]
    @Query(sort: \DayProgressRecord.programDay, order: .reverse) private var dayProgress: [DayProgressRecord]

    @State private var showPreSession = false
    @State private var showSession = false
    @State private var lastHoldTime: TimeInterval = 0
    @State private var lastQuality: Double = 0
    @State private var showPostSession = false

    private var currentDay: Int {
        (dayProgress.first?.programDay ?? 0) + 1
    }

    private var streakCount: Int {
        // Count consecutive days with sessions (simplified)
        dayProgress.count
    }

    private var coreScore: Double {
        sessionLogs.first?.qualityScore ?? 0
    }

    private var previousScore: Double? {
        guard sessionLogs.count >= 2 else { return nil }
        return sessionLogs[1].qualityScore
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    if hasCompletedFirstSession {
                        returningUserHeader
                    } else {
                        firstTimeHeader
                    }

                    todaySessionCard

                    if hasCompletedFirstSession {
                        statsSection
                    }

                    programPath
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.top, Space.xl)
            }
            .background(Palette.bgPrimary)
            .fullScreenCover(isPresented: $showPreSession) {
                PreSessionView(
                    exerciseType: "Standard Plank",
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
                    exerciseType: "Standard Plank",
                    dayNumber: currentDay,
                    targetTime: 60
                ) { holdTime, quality, faults in
                    lastHoldTime = holdTime
                    lastQuality = quality
                    showSession = false
                    hasCompletedFirstSession = true

                    // Persist session to SwiftData
                    saveSession(holdTime: holdTime, quality: quality, faults: faults)

                    showPostSession = true
                }
            }
            .fullScreenCover(isPresented: $showPostSession) {
                PostSessionView(
                    holdTime: lastHoldTime,
                    qualityScore: lastQuality,
                    dayNumber: currentDay,
                    streakCount: streakCount,
                    previousScore: previousScore,
                    playedLines: []
                ) {
                    showPostSession = false
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveSession(holdTime: Double, quality: Double, faults: Int) {
        let userId = "local-user" // placeholder until auth

        // 1. Append SessionLog
        let session = SessionLogRecord(
            userId: userId,
            exerciseType: "plank",
            holdTime: holdTime,
            targetTime: 60,
            qualityScore: quality,
            formFaultsCount: faults
        )
        modelContext.insert(session)

        // 2. Update/insert DayProgress
        let day = currentDay
        let compositeKey = "\(userId):\(day)"
        let descriptor = FetchDescriptor<DayProgressRecord>(
            predicate: #Predicate { $0.compositeKey == compositeKey }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.primarySessionId = session.id
            existing.primaryQualityScore = quality
            existing.primaryHoldTime = holdTime
            existing.updatedAt = .now
        } else {
            let progress = DayProgressRecord(
                userId: userId,
                programDay: day,
                primarySessionId: session.id,
                primaryQualityScore: quality,
                primaryHoldTime: holdTime
            )
            modelContext.insert(progress)
        }

        try? modelContext.save()
    }

    // MARK: - First-Time Header (Launchpad)

    private var firstTimeHeader: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Welcome, \(userName.isEmpty ? "there" : userName).")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)

            Text("Your plan's ready.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    // MARK: - Returning User Header

    private var returningUserHeader: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Hey.")
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
                Text("of 30. Don't blow it.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    // MARK: - Today's Session Card

    private var todaySessionCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("TODAY'S SESSION")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            Text("Plank Hold")
                .font(Typo.heading)
                .foregroundStyle(Palette.textPrimary)

            Text("60 sec target · Level \(min(currentDay / 7 + 1, 5))")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)

            Button {
                Haptics.medium()
                showPreSession = true
            } label: {
                Text(hasCompletedFirstSession ? "START SESSION" : "START YOUR FIRST PLANK")
                    .font(Typo.body)
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: Space.minTapTarget + 12)
                    .background(Palette.bgInverse)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
            .padding(.top, Space.sm)

            if !hasCompletedFirstSession {
                Text("First, we'll help you set up your camera.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
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
            StatCard(value: String(format: "%.1f", coreScore), label: "CORE SCORE")
        }
    }

    // MARK: - 30-Day Program Path

    private var programPath: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("YOUR CORE PROGRAM")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            ForEach(exercises, id: \.type) { exercise in
                HStack {
                    Text(exercise.name)
                        .font(Typo.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Palette.textPrimary)

                    Spacer()

                    if currentDay >= exercise.unlockDay {
                        Text("Active")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.stateGood)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, Space.xs)
                            .background(Palette.stateGood.opacity(0.1))
                            .clipShape(Capsule())
                    } else {
                        Text("Day \(exercise.unlockDay)")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(Space.cardPadding)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .plankShadow()
            }
        }
    }

    private var exercises: [(type: String, name: String, unlockDay: Int)] {
        [
            ("plank", "Plank Hold", 1),
            ("deadBug", "Dead Bug", 8),
            ("sidePlank", "Side Plank", 15),
            ("hollowHold", "Hollow Hold", 22),
            ("birdDog", "Bird Dog", 22),
        ]
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
