import SwiftUI
import SwiftData
import PlankSync

struct AnalyticsView: View {
    @AppStorage("userName") private var userName = ""
    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var sessionLogs: [SessionLogRecord]
    @Query(sort: \DayProgressRecord.programDay, order: .reverse) private var dayProgress: [DayProgressRecord]
    @Query(sort: \SessionRatingRecord.createdAt, order: .reverse) private var ratings: [SessionRatingRecord]

    private var routineCount: Int {
        sessionLogs.filter { $0.sessionType == "routine" }.count
    }

    private var benchmarkCount: Int {
        sessionLogs.filter { $0.sessionType == "plank_benchmark" }.count
    }

    private var totalMinutes: Int {
        let totalSeconds = sessionLogs.reduce(0.0) { $0 + ($1.totalDuration ?? $1.holdTime) }
        return Int(totalSeconds) / 60
    }

    private var currentStreak: Int { dayProgress.count }

    private var bestPlankHold: Double {
        sessionLogs.filter { $0.sessionType == "plank_benchmark" }.map(\.holdTime).max() ?? 0
    }

    private var latestPlankHold: Double {
        sessionLogs.first { $0.sessionType == "plank_benchmark" }?.holdTime ?? 0
    }

    private var averageRating: Double {
        guard !ratings.isEmpty else { return 0 }
        return Double(ratings.map(\.rating).reduce(0, +)) / Double(ratings.count)
    }

    // Empty state
    private var isEmpty: Bool { sessionLogs.isEmpty }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                    .padding(.top, Space.md)

                if isEmpty {
                    emptyState
                } else {
                    heroStats
                    activityCalendar
                    if benchmarkCount > 0 {
                        plankCard
                    }
                    recentSessions
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, 100)
        }
        .background(Palette.bgPrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Log")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)
                Text("\(userName.isEmpty ? "Your" : userName + "'s") progress")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Space.lg) {
            Spacer().frame(height: 40)
            Image(systemName: "figure.core.training")
                .font(.system(size: 48))
                .foregroundStyle(Palette.divider)
            Text("No sessions yet")
                .font(Typo.heading)
                .foregroundStyle(Palette.textPrimary)
            Text("Complete your first workout\nand it'll show up here.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }

    // MARK: - Hero Stats (top row)

    private var heroStats: some View {
        HStack(spacing: 10) {
            heroStat(
                value: "\(currentStreak)",
                label: "day streak",
                icon: "flame.fill",
                accent: true
            )
            heroStat(
                value: "\(routineCount)",
                label: "workouts",
                icon: "checkmark.circle.fill",
                accent: false
            )
            heroStat(
                value: "\(totalMinutes)",
                label: "min total",
                icon: "clock.fill",
                accent: false
            )
        }
    }

    private func heroStat(value: String, label: String, icon: String, accent: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(accent ? Palette.accent : Palette.textSecondary)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.textPrimary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .plankShadow()
    }

    // MARK: - Activity Calendar

    private var activityCalendar: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let activeDates = Set(dayProgress.map { Calendar.current.startOfDay(for: $0.date) })
        let weekday = Calendar.current.component(.weekday, from: today)
        // Adjust so Monday = 0
        let todayOffset = (weekday + 5) % 7
        let totalDays = 28 + todayOffset  // fill complete weeks

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("4 weeks")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }

            // Day labels
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            // Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(0..<totalDays, id: \.self) { i in
                    let daysAgo = totalDays - 1 - i
                    let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
                    let isActive = activeDates.contains(date)
                    let isToday = date == today
                    let isFuture = date > today

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            isFuture ? Color.clear :
                            isActive ? Palette.accent :
                            Palette.divider.opacity(0.4)
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Group {
                                if isToday {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Palette.accent, lineWidth: 1.5)
                                }
                            }
                        )
                }
            }
        }
        .padding(16)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .plankShadow()
    }

    // MARK: - Plank Progress

    private var plankCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plank Progress")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("\(benchmarkCount) tests")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }

            HStack(spacing: 0) {
                // Latest
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", latestPlankHold))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                    Text("latest (s)")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(Palette.divider)
                    .frame(width: 1, height: 40)

                // Best
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", bestPlankHold))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.accent)
                    Text("best (s)")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(Palette.divider)
                    .frame(width: 1, height: 40)

                // Rating
                VStack(spacing: 4) {
                    Text(averageRating > 0 ? String(format: "%.1f", averageRating) : "--")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                    Text("avg rating")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .plankShadow()
    }

    // MARK: - Recent Sessions

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)

            ForEach(sessionLogs.prefix(8), id: \.id) { log in
                HStack(spacing: 12) {
                    // Type icon
                    ZStack {
                        Circle()
                            .fill(log.sessionType == "routine" ? Palette.accent.opacity(0.12) : Palette.accentSubtle.opacity(0.3))
                            .frame(width: 36, height: 36)
                        Image(systemName: log.sessionType == "routine" ? "flame.fill" : "figure.core.training")
                            .font(.system(size: 14))
                            .foregroundStyle(log.sessionType == "routine" ? Palette.accent : Palette.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.sessionType == "routine" ? "Core Routine" : "Plank Benchmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Text(log.completedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute()))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textSecondary)
                    }

                    Spacer()

                    if log.sessionType == "plank_benchmark" {
                        Text(String(format: "%.0fs", log.holdTime))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.accent)
                    } else if let duration = log.totalDuration {
                        Text(formatDuration(duration))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
                .padding(12)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .plankShadow()
            }
        }
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}
