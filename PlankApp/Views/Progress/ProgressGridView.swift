import SwiftUI
import SwiftData
import PlankSync

// MARK: - ProgressGridView
//
// v9 P9.5 — REBUILT from the 2x3 stat grid to a trajectory-first
// dashboard per her75 designer audit. Pillar: "show the trend, not
// the day" (MacroFactor's lever, anti-pattern to Cal AI/BetterMe's
// daily-stat trap that trains users to feel bad on bad days).
//
// Module stack (top → bottom):
//   1. TRAJECTORY RING HERO — day N of plan.totalDays, italic Fraunces
//      day number center, goal-date eyebrow. THIS is the program-day
//      anchor; no separate tile.
//   2. WEIGHT TREND CARD — latest weight, mini sparkline across all
//      logs, pace meta line ("X.X kg from goal · on pace").
//   3. THIS WEEK CARD — 7-dot Mon-Sun row showing session completion,
//      "{N} of {scheduled} this week", streak (>0 only) per
//      [[feedback-no-checkbox-circle]] (streak lives here, NOT on
//      Today/PlanView).
//   4. PR STRIP — horizontal scroll of plank PR + total workouts +
//      total minutes. Consolidates 3 prior tiles into 1 strip.
//   5. MEASUREMENTS opt-in card — unchanged, hidden until enrolled.
//
// Struct name + public API kept as ProgressGridView so MainTabView's
// `progressGridEnabled` gate keeps working without ripple.

struct ProgressGridView: View {

    @Environment(\.modelContext) private var modelContext
    @AppStorage("weightUnit") private var weightUnit: String = "lb"

    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var allSessionLogs: [SessionLogRecord]
    @Query(sort: \WeightLogRecord.loggedAt, order: .reverse) private var allWeightLogs: [WeightLogRecord]

    @State private var userId: String = ""
    @State private var animateIn: Bool = false
    @State private var showProfileHub: Bool = false

    var body: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Space.section) {
                    header
                    trajectoryHero.modernEntrance(animateIn, delay: 0.04)
                    weightTrendCard.modernEntrance(animateIn, delay: 0.12)
                    thisWeekCard.modernEntrance(animateIn, delay: 0.20)
                    movementCard.modernEntrance(animateIn, delay: 0.26)
                    prStrip.modernEntrance(animateIn, delay: 0.32)
                    measurementsOptIn.modernEntrance(animateIn, delay: 0.40)
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.hero)
            }
        }
        .onAppear {
            userId = AppSync.shared.currentUserId ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                animateIn = true
            }
        }
        .sheet(isPresented: $showProfileHub) {
            // v1.1 fix (2026-06-24): animated slide-down close. The
            // disablesAnimations transaction made the drawer close as an
            // instant cut (no exit motion) — inconsistent with every other
            // transition. A plain binding mutation lets the system animate
            // the dismiss. See PlanView for the full rationale.
            ProfileHubView(onClose: { showProfileHub = false })
            .presentationDetents([.large])
            .presentationBackground(Palette.programBgPrimary)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("the journey")
                    .font(Typo.editorialEyebrow)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .textCase(.uppercase)
                    .kerning(0.66)
                Spacer()
                Button {
                    Haptics.light()
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { showProfileHub = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .frame(width: 44, height: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }

            VStack(alignment: .leading, spacing: Typo.programHeroLineGap) {
                Text("you,")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
                (
                    Text("becoming")
                        .font(Typo.programHeroItalic)
                        .foregroundStyle(Palette.cocoaPrimary)
                    +
                    Text(".")
                        .font(Typo.programHeroDisplay)
                        .foregroundStyle(Palette.cocoaPrimary)
                )
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .modernEntrance(animateIn)
    }

    // MARK: - 1. Trajectory ring hero

    private var schedule: ProgramScheduleCalculator.Result? {
        ProgramService.shared.currentSchedule(userId: userId, in: modelContext)
    }

    private var activePlan: ProgramPlanRecord? {
        ProgramService.shared.activePlan(userId: userId, in: modelContext)
    }

    private var trajectoryHero: some View {
        VStack(spacing: 16) {
            if let schedule {
                ZStack {
                    Circle()
                        .stroke(Palette.cocoaPrimary.opacity(0.10), lineWidth: 8)
                        .frame(width: 220, height: 220)
                    Circle()
                        .trim(from: 0, to: progressFraction(schedule: schedule))
                        .stroke(
                            Palette.accent,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(Motion.entrance, value: schedule.programDay)

                    VStack(spacing: 4) {
                        Text("\(schedule.programDay)")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 64, relativeTo: .largeTitle))
                            .foregroundStyle(Palette.cocoaPrimary)
                            .monospacedDigit()
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        Text("of \(schedule.totalDays)")
                            .font(Typo.eyebrow)
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                }
                Text(goalEyebrow(schedule: schedule))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .multilineTextAlignment(.center)
            } else {
                // Pre-enrollment fallback (no active plan yet). Shows
                // empty-state ring so the slot doesn't collapse.
                ZStack {
                    Circle()
                        .stroke(Palette.cocoaPrimary.opacity(0.10), lineWidth: 8)
                        .frame(width: 220, height: 220)
                    VStack(spacing: 4) {
                        Text("—")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 64))
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text("no program yet")
                            .font(Typo.eyebrow)
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func progressFraction(schedule: ProgramScheduleCalculator.Result) -> CGFloat {
        guard schedule.totalDays > 0 else { return 0 }
        return min(1, max(0, CGFloat(schedule.programDay) / CGFloat(schedule.totalDays)))
    }

    private func goalEyebrow(schedule: ProgramScheduleCalculator.Result) -> String {
        guard let plan = activePlan else { return "" }
        let goalDate = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: plan.totalDays, to: plan.startDate) ?? plan.startDate
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "goal · \(f.string(from: goalDate).lowercased())"
    }

    // MARK: - 2. Weight trend card

    private var weightTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("weight")
                    .font(Typo.statLabel)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .kerning(0.66)
                Spacer()
                Text(paceMeta)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(latestWeightDisplay)
                    .font(.custom("Fraunces72pt-Light", size: 40, relativeTo: .title))
                    .foregroundStyle(Palette.accent)
                    .monospacedDigit()
                Text(weightUnit)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            WeightSparkline(points: sparklinePoints)
                .frame(height: 56)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrapbookCard()
    }

    private var latestWeightDisplay: String {
        guard let latest = allWeightLogs.first else { return "—" }
        return weightUnit == "kg"
            ? String(format: "%.1f", latest.weightKg)
            : String(format: "%.1f", latest.weightKg * 2.20462)
    }

    private var paceMeta: String {
        guard let plan = activePlan,
              let goalKg = plan.goalWeightKg,
              let latest = allWeightLogs.first else { return "tap to log" }
        let remainingKg = latest.weightKg - goalKg
        guard remainingKg > 0.1 else { return "at goal" }
        let displayRemaining = weightUnit == "kg"
            ? String(format: "%.1f kg", remainingKg)
            : String(format: "%.1f lb", remainingKg * 2.20462)
        return "\(displayRemaining) from goal"
    }

    private var sparklinePoints: [Double] {
        // Reversed so oldest → newest reads left → right.
        Array(allWeightLogs.reversed().map { $0.weightKg })
    }

    // MARK: - 3. This week card (7-dot row + streak)

    private var thisWeekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("this week")
                    .font(Typo.statLabel)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .kerning(0.66)
                Spacer()
                if currentStreak > 0 {
                    Text("\(currentStreak)-day streak")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.accent)
                }
            }
            Text("\(thisWeekCount) of \(weeklyTarget) sessions")
                .font(Typo.heading)
                .foregroundStyle(Palette.cocoaPrimary)
            HStack(spacing: 8) {
                ForEach(0..<7) { idx in
                    weekDot(weekdayIndex: idx)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrapbookCard()
    }

    private var thisWeekCount: Int {
        let cal = Calendar(identifier: .gregorian)
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return allSessionLogs.filter { $0.completedAt >= startOfWeek }.count
    }

    /// Sessions per week per IntensityProfile. Defaults to 3 (Soft)
    /// pre-enrollment so the row still renders honestly.
    private var weeklyTarget: Int {
        guard let plan = activePlan,
              let tier = IntensityTier(rawValue: plan.intensityTier) else { return 3 }
        switch tier {
        case .soft:   return 3
        case .medium: return 4
        case .hard:   return 5
        }
    }

    private var sessionWeekdaysCompleted: Set<Int> {
        let cal = Calendar(identifier: .gregorian)
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeekLogs = allSessionLogs.filter { $0.completedAt >= startOfWeek }
        // weekday in Cal: Sun=1, Mon=2, ... Sat=7. Convert to Mon=0..Sun=6.
        return Set(thisWeekLogs.map { (cal.component(.weekday, from: $0.completedAt) + 5) % 7 })
    }

    private var todayIndex: Int {
        let cal = Calendar(identifier: .gregorian)
        return (cal.component(.weekday, from: .now) + 5) % 7
    }

    private var currentStreak: Int {
        let activeDates = Set(allSessionLogs.map {
            Calendar(identifier: .gregorian).startOfDay(for: $0.completedAt)
        })
        return StreakCalculator.calculate(activeDates: activeDates).count
    }

    private func weekDot(weekdayIndex: Int) -> some View {
        let labels = ["m", "t", "w", "t", "f", "s", "s"]
        let isToday = weekdayIndex == todayIndex
        let isComplete = sessionWeekdaysCompleted.contains(weekdayIndex)
        return VStack(spacing: 6) {
            Circle()
                .fill(isComplete ? Palette.accent : Palette.cocoaPrimary.opacity(0.10))
                .frame(width: isToday ? 18 : 14, height: isToday ? 18 : 14)
                .overlay(
                    Circle()
                        .stroke(isToday ? Palette.accent : Color.clear, lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                )
            Text(labels[weekdayIndex])
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isToday ? Palette.accent : Palette.cocoaTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 4. Movement card (steps trend)
    //
    // 7-day rolling steps. Shows the bar chart on a 7,500 daily-goal
    // baseline + week-over-week delta vs last week. Reads live from
    // StepsService.shared.weeklyCounts (populated by refresh() on app
    // launch + HK observer). Falls back to a quiet empty state when
    // permission has not been granted yet (no fake numbers per
    // [[feedback-data-provenance]]).

    @State private var steps = StepsService.shared

    private var movementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("movement")
                    .font(Typo.statLabel)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .kerning(0.66)
                Spacer()
                Text(weekDeltaMeta)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(stepsAverageDisplay)
                    .font(.custom("Fraunces72pt-Light", size: 40, relativeTo: .title))
                    .foregroundStyle(Palette.accent)
                    .monospacedDigit()
                Text("avg / day")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            stepsBarRow
                .frame(height: 56)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrapbookCard()
        .task { await steps.refresh() }
    }

    private var stepsAverageDisplay: String {
        let counts = steps.weeklyCounts
        guard !counts.isEmpty else { return "—" }
        let avg = counts.reduce(0, +) / counts.count
        return avg.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
    }

    /// Week-over-week meta. Honest when HK permission missing — no
    /// "0 vs 0" trap that reads as regression. Uses the on-program
    /// 7,500 anchor from StepsService.dailyGoal so the comparison
    /// frame stays consistent across rails.
    private var weekDeltaMeta: String {
        let counts = steps.weeklyCounts
        guard counts.count == 7, counts.contains(where: { $0 > 0 }) else {
            return "tap to enable"
        }
        let avg = Double(counts.reduce(0, +)) / Double(counts.count)
        let goal = Double(StepsService.dailyGoal)
        let pctOfGoal = Int((avg / goal * 100).rounded())
        return "\(pctOfGoal)% of goal"
    }

    /// 7 bars (Mon-style oldest-to-newest), each scaled against the
    /// daily-goal anchor so the chart reads against a stable baseline
    /// regardless of which week she's having. Bars beyond goal cap at
    /// 100% height with a darker accent tip so the over-achievement
    /// reads without distorting the chart proportions.
    private var stepsBarRow: some View {
        GeometryReader { geo in
            let counts = steps.weeklyCounts.isEmpty
                ? Array(repeating: 0, count: 7)
                : steps.weeklyCounts
            let goal = Double(StepsService.dailyGoal)
            let barWidth = (geo.size.width - CGFloat(counts.count - 1) * 6) / CGFloat(counts.count)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(counts.indices, id: \.self) { i in
                    let raw = Double(counts[i])
                    let pct = min(1, raw / goal)
                    let h = max(2, geo.size.height * CGFloat(pct))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(raw == 0
                              ? Palette.cocoaPrimary.opacity(0.08)
                              : Palette.accent.opacity(0.85))
                        .frame(width: barWidth, height: h)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: - 5. PR strip (consolidated historical stats)

    private var prStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                prTile(label: "plank pr", value: plankPRValue)
                prTile(label: "total sessions", value: "\(allSessionLogs.count)")
                prTile(label: "total min", value: "\(totalMinutes)")
                prTile(label: "longest streak", value: "\(longestStreak)")
            }
            .padding(.horizontal, Space.lg)
        }
        .padding(.horizontal, -Space.lg)
    }

    private var plankPRSeconds: Double {
        allSessionLogs.compactMap { $0.plankHoldTime }.max() ?? 0
    }

    private var plankPRValue: String {
        let s = plankPRSeconds
        guard s > 0 else { return "—" }
        let secs = Int(s.rounded())
        if secs >= 60 {
            return "\(secs / 60):\(String(format: "%02d", secs % 60))"
        }
        return "\(secs)s"
    }

    private var totalMinutes: Int {
        // totalDuration is seconds, full-routine sessions only. plankHoldTime
        // covers the plank-only sessions. Sum both then convert to minutes.
        let routineSec = allSessionLogs.compactMap { $0.totalDuration }.reduce(0, +)
        let plankSec = allSessionLogs
            .filter { $0.totalDuration == nil }
            .map { $0.holdTime }
            .reduce(0, +)
        return Int((routineSec + plankSec) / 60)
    }

    /// Longest in-history streak — designer spec calls for this as a
    /// separate PR tile alongside the current streak. Walks the active-
    /// date set day-by-day and tracks the max consecutive run. Lighter
    /// than rebuilding StreakCalculator for a second pass.
    private var longestStreak: Int {
        let cal = Calendar(identifier: .gregorian)
        let dates = Set(allSessionLogs.map { cal.startOfDay(for: $0.completedAt) })
        guard !dates.isEmpty else { return 0 }
        let sorted = dates.sorted()
        var best = 1
        var run = 1
        for i in 1..<sorted.count {
            if let prev = cal.date(byAdding: .day, value: 1, to: sorted[i - 1]),
               cal.isDate(prev, inSameDayAs: sorted[i]) {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    private func prTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typo.eyebrow)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(value)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 24))
                .foregroundStyle(Palette.cocoaPrimary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 130, height: 92, alignment: .topLeading)
        .scrapbookCard()
    }

    // MARK: - 5. Measurements opt-in (Phase 2 ships body_measurements)

    private var measurementsOptIn: some View {
        Button {
            Haptics.light()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("measure")
                    .font(Typo.statLabel)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .kerning(0.66)
                Spacer()
                Image(systemName: "plus.circle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Palette.cocoaSecondary)
                Text("add body measurements")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .multilineTextAlignment(.leading)
                Text("soon")
                    .font(Typo.eyebrow)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.accentSubtle.opacity(0.4)))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .scrapbookCard()
            .opacity(0.78)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add body measurements, coming soon")
    }
}

// MARK: - WeightSparkline
//
// Compact sparkline for the weight trend card. Spans the card width;
// scales the data range to leave 12% headroom top + bottom so the
// curve never touches the edge. Renders nothing on <2 points.

struct WeightSparkline: View {
    let points: [Double]

    var body: some View {
        GeometryReader { geo in
            if points.count >= 2,
               let lo = points.min(),
               let hi = points.max(),
               hi > lo {
                let pad: CGFloat = geo.size.height * 0.12
                let span = hi - lo
                let xs = (0..<points.count).map { CGFloat($0) / CGFloat(points.count - 1) * geo.size.width }
                let ys = points.map { p -> CGFloat in
                    let norm = (p - lo) / span
                    return pad + (1 - CGFloat(norm)) * (geo.size.height - 2 * pad)
                }
                Path { path in
                    path.move(to: CGPoint(x: xs[0], y: ys[0]))
                    for i in 1..<xs.count {
                        path.addLine(to: CGPoint(x: xs[i], y: ys[i]))
                    }
                }
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else {
                Rectangle().fill(Color.clear)
            }
        }
    }
}
