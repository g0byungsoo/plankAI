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
        let totalSeconds = sessionLogs.reduce(0.0) { sum, log in
            sum + (log.totalDuration ?? log.holdTime)
        }
        return Int(totalSeconds) / 60
    }

    private var currentStreak: Int {
        dayProgress.count
    }

    private var bestPlankHold: Double {
        sessionLogs
            .filter { $0.sessionType == "plank_benchmark" }
            .map { $0.holdTime }
            .max() ?? 0
    }

    private var latestPlankHold: Double {
        sessionLogs
            .first { $0.sessionType == "plank_benchmark" }?
            .holdTime ?? 0
    }

    private var averageRating: Double {
        guard !ratings.isEmpty else { return 0 }
        return Double(ratings.map(\.rating).reduce(0, +)) / Double(ratings.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                // Header
                Text("Analytics")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                // Overview stats
                overviewGrid

                // Plank progress
                if benchmarkCount > 0 {
                    plankProgressCard
                }

                // Activity calendar
                activityCalendar

                // Recent sessions
                if !sessionLogs.isEmpty {
                    recentSessions
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
            .padding(.bottom, 80)
        }
        .background(Palette.bgPrimary)
    }

    // MARK: - Overview Grid

    private var overviewGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Space.sm),
            GridItem(.flexible(), spacing: Space.sm),
        ], spacing: Space.sm) {
            miniStat(value: "\(routineCount)", label: "WORKOUTS", icon: "flame")
            miniStat(value: "\(currentStreak)", label: "STREAK", icon: "bolt")
            miniStat(value: "\(totalMinutes)", label: "MINUTES", icon: "clock")
            miniStat(
                value: averageRating > 0 ? String(format: "%.1f", averageRating) : "--",
                label: "AVG RATING",
                icon: "star"
            )
        }
    }

    private func miniStat(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Palette.accent)

            Text(value)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)

            Text(label)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }

    // MARK: - Plank Progress

    private var plankProgressCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("PLANK PROGRESS")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            HStack(spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(String(format: "%.0fs", latestPlankHold))
                        .font(Typo.title)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Latest")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(String(format: "%.0fs", bestPlankHold))
                        .font(Typo.title)
                        .foregroundStyle(Palette.accent)
                    Text("Best")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("\(benchmarkCount)")
                        .font(Typo.title)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Tests")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }

    // MARK: - Activity Calendar (last 4 weeks)

    private var activityCalendar: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("ACTIVITY")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            // Last 28 days grid
            let today = Calendar.current.startOfDay(for: .now)
            let activeDates = Set(dayProgress.map { Calendar.current.startOfDay(for: $0.date) })

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<28, id: \.self) { daysAgo in
                    let date = Calendar.current.date(byAdding: .day, value: -(27 - daysAgo), to: today)!
                    let isActive = activeDates.contains(date)
                    let isToday = date == today

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? Palette.accent : Palette.divider.opacity(0.5))
                        .frame(height: 28)
                        .overlay(
                            isToday
                                ? RoundedRectangle(cornerRadius: 4)
                                    .stroke(Palette.textSecondary, lineWidth: 1)
                                : nil
                        )
                }
            }

            // Day labels
            HStack {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }

    // MARK: - Recent Sessions

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("RECENT")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            ForEach(sessionLogs.prefix(5), id: \.id) { log in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.sessionType == "routine" ? "Routine" : "Plank Benchmark")
                            .font(Typo.body)
                            .fontWeight(.medium)
                            .foregroundStyle(Palette.textPrimary)
                        Text(log.completedAt.formatted(.dateTime.month().day().hour().minute()))
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }

                    Spacer()

                    if log.sessionType == "plank_benchmark" {
                        Text(String(format: "%.0fs", log.holdTime))
                            .font(Typo.heading)
                            .foregroundStyle(Palette.accent)
                    } else if let duration = log.totalDuration {
                        Text(formatDuration(duration))
                            .font(Typo.heading)
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
                .padding(Space.sm + 4)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}
