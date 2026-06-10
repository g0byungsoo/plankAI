import SwiftUI
import SwiftData
import PlankSync

// MARK: - ProgressGridView
//
// v1.1 program pivot. The Becoming tab redesign — BetterMe-style
// 2x3 stat grid replacing AnalyticsView's vertical bento stack.
// Each tile = one progress signal: numeralHero value + statLabel
// eyebrow + cocoaSecondary subtitle + (Phase 2) MiniSparkline.
//
// Gated upstream — MainTabView swaps in AnalyticsView when
// progressGridEnabled flag is false. So existing users see no
// change until the flag flips.
//
// Phase 1 tile set (5 working + 1 opt-in):
//   - STEPS — HealthKit via StepsService.shared.todayCount
//   - WEIGHT — latest WeightLogRecord, kg or lb per user pref
//   - WORKOUTS — SessionLogRecord this week count
//   - PLANK PR — max plankHoldTime across all sessions
//   - PROGRAM DAY — derived from ProgramService.currentSchedule
//   - + 1 add measurements opt-in (Phase 2 ships body_measurements)

struct ProgressGridView: View {

    @Environment(\.modelContext) private var modelContext
    @AppStorage("weightUnit") private var weightUnit: String = "lb"

    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var allSessionLogs: [SessionLogRecord]
    @Query(sort: \WeightLogRecord.loggedAt, order: .reverse) private var allWeightLogs: [WeightLogRecord]

    @State private var userId: String = ""
    @State private var animateIn: Bool = false

    // v6 audit: settings entry parity with PlanView.
    @State private var showProfileHub: Bool = false

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            // v6: same pink background as PlanView for program-tab cohesion.
            Palette.programBgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    header
                    grid
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
            ProfileHubView(onClose: {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { showProfileHub = false }
            })
            .presentationDetents([.large])
            .presentationBackground(Palette.programBgPrimary)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            // v6 audit: settings ellipsis right-aligned in the eyebrow
            // row, parity with PlanView.
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

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ProgressTile(
                label: "steps",
                value: stepsValue,
                subtitle: stepsSubtitle,
                isAvailable: true,
                emphasis: .live   // today's data → pink accent
            )
            .modernEntrance(animateIn, delay: 0.06)

            ProgressTile(
                label: "weight",
                value: weightValue,
                subtitle: weightSubtitle,
                isAvailable: !allWeightLogs.isEmpty,
                emphasis: .live
            )
            .modernEntrance(animateIn, delay: 0.12)

            ProgressTile(
                label: "workouts",
                value: workoutsValue,
                subtitle: "this week",
                isAvailable: true,
                emphasis: .historical   // historical → cocoa
            )
            .modernEntrance(animateIn, delay: 0.18)

            ProgressTile(
                label: "plank pr",
                value: plankPRValue,
                subtitle: plankPRSubtitle,
                isAvailable: plankPRSeconds > 0,
                emphasis: .historical
            )
            .modernEntrance(animateIn, delay: 0.24)

            ProgressTile(
                label: "program day",
                value: programDayValue,
                subtitle: programDaySubtitle,
                isAvailable: programDayValue != "—",
                emphasis: .live
            )
            .modernEntrance(animateIn, delay: 0.30)

            measurementsOptInTile
                .modernEntrance(animateIn, delay: 0.36)
        }
    }

    // MARK: - Tile data

    private var stepsValue: String {
        let count = StepsService.shared.todayCount
        return count.formatted(.number.grouping(.automatic))
    }

    private var stepsSubtitle: String {
        let goal = ProgramService.shared.currentProfile(userId: userId, in: modelContext).stepsDailyGoal
        return "goal \(goal.formatted(.number.grouping(.automatic)))"
    }

    private var weightValue: String {
        guard let latest = allWeightLogs.first else { return "—" }
        if weightUnit == "kg" {
            return String(format: "%.1f", latest.weightKg)
        }
        let lb = latest.weightKg * 2.20462
        return String(format: "%.1f", lb)
    }

    private var weightSubtitle: String {
        guard !allWeightLogs.isEmpty else { return "tap to log" }
        return weightUnit
    }

    private var workoutsValue: String {
        let calendar = Calendar(identifier: .gregorian)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let count = allSessionLogs.filter { $0.completedAt >= startOfWeek }.count
        return "\(count)"
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

    private var plankPRSubtitle: String {
        plankPRSeconds > 0 ? "your best" : "no PR yet"
    }

    private var programDayValue: String {
        guard let schedule = ProgramService.shared.currentSchedule(userId: userId, in: modelContext) else {
            return "—"
        }
        return "\(schedule.programDay)"
    }

    private var programDaySubtitle: String {
        guard let schedule = ProgramService.shared.currentSchedule(userId: userId, in: modelContext) else {
            return "no program yet"
        }
        return "of \(schedule.totalDays)"
    }

    // MARK: - Measurements opt-in

    private var measurementsOptInTile: some View {
        Button {
            // Phase 2 ships body_measurements + LogMeasurementsSheet.
            // Phase 1 surfaces the slot so the user knows it's coming.
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
                Text("add measurements")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .multilineTextAlignment(.leading)
                Text("soon")
                    .font(Typo.eyebrow)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.hairlineCocoa))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Radius.programCard)
                    .fill(Palette.programCard)
            )
            .programPaperShadow()
            .opacity(0.78)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add body measurements, coming soon")
    }
}

// MARK: - ProgressTile

struct ProgressTile: View {

    let label: String
    let value: String
    let subtitle: String
    let isAvailable: Bool
    /// .live = today's number, value renders in accent rose (pink
    /// brand pop). .historical = past data, value stays cocoa.
    /// Founder direction 2026-06-09: keep JeniFit pink identity
    /// visible on data tiles, not just on chrome.
    var emphasis: ProgressTile.Emphasis = .historical

    enum Emphasis {
        case live
        case historical
    }

    private var valueColor: Color {
        guard isAvailable else { return Palette.cocoaTertiary }
        return emphasis == .live ? Palette.accent : Palette.cocoaPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Typo.statLabel)
                .foregroundStyle(Palette.cocoaTertiary)
                .kerning(0.66)
            Text(value)
                .font(.custom("Fraunces72pt-Light", size: 32, relativeTo: .title))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            Text(subtitle)
                .font(Typo.numeralMeta)
                .foregroundStyle(Palette.cocoaSecondary)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Radius.programCard)
                .fill(Palette.programCard)
        )
        .programPaperShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value), \(subtitle)")
    }
}
