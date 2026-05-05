import SwiftUI
import SwiftData
import PlankSync
import Auth  // MemberImportVisibility: User.id lives in Supabase's Auth submodule

struct AnalyticsView: View {
    @AppStorage("userName") private var userName = ""
    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var allSessionLogs: [SessionLogRecord]
    @Query(sort: \DayProgressRecord.programDay, order: .reverse) private var allDayProgress: [DayProgressRecord]
    @Query(sort: \SessionRatingRecord.createdAt, order: .reverse) private var allRatings: [SessionRatingRecord]
    @State private var auth = AuthService.shared

    /// User-scoped views over the raw @Query results. SessionRatingRecord
    /// has no userId column locally (cloud schema added it later), so we
    /// scope ratings transitively through the user's session_log ids.
    private var sessionLogs: [SessionLogRecord] {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return [] }
        return allSessionLogs.filter { $0.userId == userId }
    }

    private var dayProgress: [DayProgressRecord] {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return [] }
        return allDayProgress.filter { $0.userId == userId }
    }

    private var ratings: [SessionRatingRecord] {
        let sessionIds = Set(sessionLogs.map(\.id))
        return allRatings.filter { sessionIds.contains($0.sessionLogId) }
    }

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

    private var activeDates: Set<Date> {
        Set(dayProgress.map { Calendar.current.startOfDay(for: $0.date) })
    }

    private var streak: StreakCalculator.Result {
        StreakCalculator.calculate(activeDates: activeDates)
    }

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

    private var isEmpty: Bool { sessionLogs.isEmpty }

    // Grouped sessions
    private var thisWeekSessions: [SessionLogRecord] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return sessionLogs.filter { $0.completedAt >= weekAgo }
    }

    private var earlierSessions: [SessionLogRecord] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return Array(sessionLogs.filter { $0.completedAt < weekAgo }.prefix(12))
    }

    // Animation state
    @State private var sectionOpacity: [Double] = [0, 0, 0, 0, 0]
    @State private var sectionOffset: [CGFloat] = [20, 20, 20, 20, 20]
    @State private var hasAnimated = false
    @State private var streakPulse = false
    @State private var calendarScale: CGFloat = 0.95

    // Phase 16c — Logs scatter (LIGHT, 3 stickers, line-art-heavy).
    // Data surface should feel like a dashboard with light touches,
    // not decorated — 2 line-art + 1 small painterly, all 24–26pt.
    //
    // Same placement strategy as Home: stickers live in the top +
    // bottom horizontal bands where stats cards / activity calendar /
    // recent sessions list don't extend, so they never overlap data
    // content regardless of screen width. cherries lands the warmth
    // touch in one corner; hearts_lineart + star_lineart anchor the
    // line-art accents in the other two.
    private static let logsPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.92, y: 0.13),
                         size: 24, rotation: 12, phaseDelay: 0.00),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.08, y: 0.86),
                         size: 26, rotation: -10, phaseDelay: 0.40),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.92, y: 0.89),
                         size: 24, rotation: 14, phaseDelay: 0.80),
    ]

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            StickerScatter(placements: Self.logsPlacements)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                        .padding(.top, Space.md)
                        .opacity(sectionOpacity[0])
                        .offset(y: sectionOffset[0])

                    if isEmpty {
                        emptyState
                    } else {
                        heroStats
                            .opacity(sectionOpacity[1])
                            .offset(y: sectionOffset[1])

                        activityCalendar
                            .opacity(sectionOpacity[2])
                            .offset(y: sectionOffset[2])
                            .scaleEffect(calendarScale, anchor: .top)

                        if benchmarkCount > 0 {
                            plankCard
                                .opacity(sectionOpacity[3])
                                .offset(y: sectionOffset[3])
                        }

                        recentSessions
                            .opacity(sectionOpacity[4])
                            .offset(y: sectionOffset[4])
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, 100)
            }
        }
        .onAppear { animateIn() }
    }

    // MARK: - Animation

    private func animateIn() {
        guard !hasAnimated else { return }
        hasAnimated = true

        let delays: [Double] = [0.1, 0.25, 0.45, 0.65, 0.8]
        for (i, delay) in delays.enumerated() {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(delay)) {
                sectionOpacity[i] = 1
                sectionOffset[i] = 0
            }
        }

        // Calendar scale pop
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
            calendarScale = 1.0
        }

        // Streak number pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.3)) {
                streakPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    streakPulse = false
                }
            }
        }
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

    // MARK: - Hero Stats

    private var heroStats: some View {
        HStack(spacing: 10) {
            // Streak card with pulse
            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.accent)
                Text("\(streak.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .scaleEffect(streakPulse ? 1.15 : 1.0)
                Text(streak.frozenDates.isEmpty ? "day streak" : "streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .plankShadow()

            heroStat(value: "\(routineCount)", label: "workouts", icon: "checkmark.circle.fill")
            heroStat(value: "\(totalMinutes)", label: "min total", icon: "clock.fill")
        }
    }

    private func heroStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Palette.textSecondary)
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

    // MARK: - Activity Calendar (with freeze icons)

    private var activityCalendar: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let frozenDates = streak.frozenDates
        let weekday = cal.component(.weekday, from: today)
        let todayOffset = (weekday + 5) % 7  // Monday = 0
        let totalDays = 28 + todayOffset

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                // Legend
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3).fill(Palette.accent).frame(width: 10, height: 10)
                        Text("active").font(.system(size: 10)).foregroundStyle(Palette.textSecondary)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "#7BBBE5"))
                        Text("frozen").font(.system(size: 10)).foregroundStyle(Palette.textSecondary)
                    }
                }
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
                    let date = cal.date(byAdding: .day, value: -daysAgo, to: today)!
                    let isActive = activeDates.contains(date)
                    let isFrozen = frozenDates.contains(date)
                    let isToday = date == today
                    let isFuture = date > today

                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                isFuture ? Color.clear :
                                isActive ? Palette.accent :
                                isFrozen ? Palette.frozenDay :
                                Palette.divider.opacity(0.4)
                            )
                            .aspectRatio(1, contentMode: .fit)

                        // Ice icon for frozen days
                        if isFrozen {
                            Image(systemName: "snowflake")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(hex: "#7BBBE5"))
                        }

                        // Today outline
                        if isToday {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Palette.accent, lineWidth: 1.5)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
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
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", latestPlankHold))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                    Text("latest (s)")
                        .font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Palette.divider).frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text(String(format: "%.0f", bestPlankHold))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.accent)
                    Text("best (s)")
                        .font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle().fill(Palette.divider).frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text(averageRating > 0 ? String(format: "%.1f", averageRating) : "--")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                    Text("avg rating")
                        .font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .plankShadow()
    }

    // MARK: - Recent Sessions (grouped)

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !thisWeekSessions.isEmpty {
                sectionHeader("This Week")
                ForEach(Array(thisWeekSessions.enumerated()), id: \.element.id) { i, log in
                    sessionRow(log)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85).delay(Double(i) * 0.08), value: sectionOpacity[4])
                }
            }

            if !earlierSessions.isEmpty {
                sectionHeader("Earlier")
                ForEach(Array(earlierSessions.enumerated()), id: \.element.id) { i, log in
                    sessionRow(log)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85).delay(Double(i) * 0.06), value: sectionOpacity[4])
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, 4)
    }

    private func sessionRow(_ log: SessionLogRecord) -> some View {
        HStack(spacing: 12) {
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
            } else {
                let duration = log.totalDuration ?? 0
                Text(duration > 0 ? formatDuration(duration) : "--")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
            }
        }
        .padding(12)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .plankShadow()
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}
