import SwiftUI

/// The home screen. Adapts between first-time (launchpad) and returning-user (dashboard).
struct HomeView: View {
    @State private var currentDay = 1
    @State private var streakCount = 0
    @State private var coreScore = 0.0
    @State private var userName = ""
    @State private var hasCompletedFirstSession = false
    @State private var showSession = false
    @State private var programPhase = "foundations"

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
            .fullScreenCover(isPresented: $showSession) {
                SessionView(
                    exerciseType: "Standard Plank",
                    dayNumber: currentDay,
                    targetTime: 60
                ) { holdTime, quality, faults in
                    showSession = false
                    hasCompletedFirstSession = true
                    coreScore = quality
                    streakCount += 1
                    // Save session via PlankSync
                }
            }
        }
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
                Text("of \(programPhase == "foundations" ? "30" : "∞"). Don't blow it.")
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
                showSession = true
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

    // MARK: - Stats (post first session)

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
