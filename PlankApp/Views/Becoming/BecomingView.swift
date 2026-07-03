import SwiftUI
import SwiftData
import PlankSync
import PlankFood
import Auth

// MARK: - BecomingView
//
// App v2.1 (docs/app_v2/12_BECOMING_V2.md). Becoming stops being a
// dashboard and becomes the insight layer — the part of jenifit
// where she gets smarter about her own body. Three jobs, in order:
//
//   UNDERSTAND — the trend told as a coach's story with a mechanism
//                ("the line eased down 400g. protein landed 5 of 7
//                days — that's the mechanism, not magic.")
//   LEARN      — the method as a JOURNEY (her act, her next lesson),
//                not a lesson shelf.
//   BELIEVE    — the wins receipt: shown-up count, plates seen,
//                lessons kept. identity evidence.
//
// Max two pattern insights at a time (ranked by InsightEngine);
// everything carries an ask-jeni seed so a card is never a dead end.
// AnalyticsView survives behind --legacy-becoming until the sweep.

struct BecomingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth = AuthService.shared
    @State private var router = AppRouter.shared

    @State private var snapshot: TodaySnapshot?
    @State private var week: WeekState?
    @State private var insights: InsightEngine.Output?
    @State private var showLogWeight = false
    @State private var showProfileHub = false
    @State private var showJournal = false
    /// v2.6 — the weekly receipt artifact export (Sunday block).
    private struct ReceiptShareItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    @State private var receiptShare: ReceiptShareItem? = nil

    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    private var userId: String { auth.currentUser?.id.uuidString ?? "" }

    var body: some View {
        JKScreenChrome {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    masthead
                        .padding(.top, Space.hero)
                        .jkBeat1()

                    if snapshot?.isEnrolled == false {
                        // v2.5 — the fresh-user state is designed, not
                        // hidden sections: one line, one action.
                        JKEmptyState(
                            line: "your story starts on day one",
                            italic: ["day one"],
                            actionLabel: "open today",
                            action: { router.tab = .today }
                        )
                        .padding(.top, Space.xl)
                    }

                    trendStory
                        .padding(.top, Space.lg)
                        .jkBeat2()

                    weekStrip
                        .padding(.top, Space.section)
                        .jkBeat2(extraDelay: 0.08)

                    sundayReceipt
                        .padding(.top, Space.section)

                    insightCards
                        .padding(.top, Space.section)

                    methodJourney
                        .padding(.top, Space.section)
                        .jkBeat2(extraDelay: 0.2)

                    winsBlock
                        .padding(.top, Space.section)
                        .jkBeat2(extraDelay: 0.25)

                    Spacer(minLength: 96)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { refresh() }
        }
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weightLogDidChange)) { _ in
            refresh()
        }
        .onReceive(FoodLogPersister.changeNotifier) { _ in refresh() }
        .sheet(isPresented: $showLogWeight) {
            LogWeightSheet(
                startingFromKg: week?.weightLogs.first?.weightKg ?? 65,
                isUpdatingToday: hasLoggedToday,
                onSave: { kg in
                    WeightLogWriter.persist(kg: kg, userId: userId, in: modelContext)
                    showLogWeight = false
                    refresh()
                },
                onCancel: { showLogWeight = false }
            )
            .presentationDetents([.fraction(0.55)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgElevated)
        }
        .sheet(isPresented: $showProfileHub) {
            ProfileHubView(onClose: { showProfileHub = false })
                .presentationDetents([.large])
                .presentationBackground(Palette.bgPrimary)
        }
        .sheet(item: $receiptShare) { item in
            LessonQuoteShareSheet(items: [item.image], onComplete: { receiptShare = nil })
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showJournal) {
            FoodLogTimelineView(
                userId: userId,
                dailyTarget: Double(snapshot?.targets.kcal ?? 0),
                archetypeHint: snapshot?.day?.archetype.rawValue,
                onAddTapped: {
                    showJournal = false
                    router.open(.snap)
                },
                onDismiss: { showJournal = false }
            )
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        JKMasthead(
            lead: .title("becoming", italic: ["becoming"]),
            eyebrow: journeyEyebrow,
            marks: [
                JKMastheadMark(systemName: "line.3.horizontal", label: "settings") {
                    showProfileHub = true
                },
            ]
        )
    }

    private var journeyEyebrow: String? {
        guard let snapshot, snapshot.isEnrolled else { return nil }
        let week = ((snapshot.programDay - 1) / 7) + 1
        return "week \(spelled(week)) · day \(snapshot.programDay) of \(snapshot.totalDays)"
    }

    private func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: - The trend story (hero)

    @ViewBuilder private var trendStory: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if let story = insights?.trendStory {
                JKCoachLine(
                    text: story.line,
                    italic: story.italic,
                    onOpenChat: { router.openChat(seed: story.chatSeed) }
                )
                .padding(.horizontal, Space.lg)
            }

            if let week, week.weightLogs.count >= 2 {
                BecomingTrendCanvas(
                    logs: week.weightLogs,
                    goalWeightKg: snapshot?.plan?.goalWeightKg,
                    unit: weightUnit
                )
                .padding(.horizontal, Space.lg)

                if let detail = insights?.trendStory?.detail {
                    Text(detail)
                        .font(Typo.caption)
                        .lineSpacing(3)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.lg)
                }
            } else {
                JKEmptyState(
                    line: "your trend line starts with two mornings",
                    italic: ["two mornings"],
                    actionLabel: "log the first",
                    action: { showLogWeight = true }
                )
            }
        }
    }

    private var hasLoggedToday: Bool {
        guard let last = week?.weightLogs.first?.loggedAt else { return false }
        return Calendar.current.isDateInToday(last)
    }

    // MARK: - This week (receipt strip)

    @ViewBuilder private var weekStrip: some View {
        if let week {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("this week")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)

                HStack(spacing: 8) {
                    ForEach(Array(week.last7.enumerated()), id: \.offset) { _, day in
                        Circle()
                            .fill(day.plates > 0 ? Palette.accent : Palette.accentSubtle.opacity(0.6))
                            .frame(width: 7, height: 7)
                    }
                    Spacer(minLength: 12)
                    Text(weekReceiptLine(week))
                        .font(Typo.numeralMeta)
                        .kerning(0.1)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.horizontal, Space.lg)
        }
    }

    private func weekReceiptLine(_ week: WeekState) -> String {
        var parts: [String] = []
        let plates = week.last7.map(\.plates).reduce(0, +)
        if plates > 0 { parts.append("\(plates) plates") }
        if let target = week.proteinTargetG, target > 0, week.proteinDaysHit > 0 {
            parts.append("\(week.proteinDaysHit) protein days")
        }
        let steps = week.last7.compactMap(\.steps).reduce(0, +)
        if steps > 0 { parts.append("\(Int((Double(steps) / 1000).rounded()))k steps") }
        return parts.isEmpty ? "the week is young" : parts.joined(separator: " · ")
    }

    // MARK: - Insight cards (max 2, ranked)

    @ViewBuilder private var insightCards: some View {
        if let cards = insights?.cards, !cards.isEmpty {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("what your week says")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.horizontal, Space.lg)

                VStack(spacing: Space.optionGap) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { idx, insight in
                        insightCard(insight)
                            .jkBeat2(extraDelay: 0.12 + Double(idx) * Motion.revealStagger)
                    }
                }
                .padding(.horizontal, Space.lg)
            }
        }
    }

    private func insightCard(_ insight: Insight) -> some View {
        Button {
            Haptics.soft()
            router.openChat(seed: insight.chatSeed)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ItalicAccentText(
                    insight.line,
                    italic: insight.italic,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 20),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 20),
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(-2)
                .kerning(-0.2)
                .fixedSize(horizontal: false, vertical: true)

                if let detail = insight.detail {
                    Text(detail)
                        .font(Typo.caption)
                        .lineSpacing(3)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 5) {
                    Text("ask jeni")
                        .font(Typo.captionTracked)
                        .kerning(1.4)
                        .textCase(.uppercase)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
            )
            .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(JKPress())
    }

    // MARK: - The method journey

    private static let actTitles = [
        1: "deconstruct the diet brain",
        2: "build the skills",
        3: "rewire the identity",
        4: "maintain for life",
    ]

    @ViewBuilder private var methodJourney: some View {
        if let snapshot, snapshot.isEnrolled, let ref = resolvedLesson(snapshot) {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("the method")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.horizontal, Space.lg)

                Button {
                    Haptics.light()
                    router.open(.lesson)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("act \(spelled(ref.scheduled.act)) · \(Self.actTitles[ref.scheduled.act] ?? "")")
                            .font(Typo.captionTracked)
                            .kerning(1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.accent)

                        Text(cleanTitle(ref.slot.workingTitle))
                            .font(.custom("JeniHeroSerif-Regular", size: 22))
                            .foregroundStyle(Palette.textPrimary)
                            .lineSpacing(-2)
                            .kerning(-0.2)
                            .fixedSize(horizontal: false, vertical: true)

                        // Act progress: a hairline that fills.
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Palette.hairlineCocoa)
                                Capsule()
                                    .fill(Palette.cocoaPrimary)
                                    .frame(width: geo.size.width * journeyFraction(snapshot))
                            }
                        }
                        .frame(height: 2)

                        HStack {
                            Text(journeyCaption(snapshot))
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Text(lessonDoneToday(snapshot) ? "read again" : "read it")
                                    .font(.custom("DMSans-SemiBold", size: 13))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(Palette.textPrimary)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Palette.bgElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(JKPress())
                .padding(.horizontal, Space.lg)
            }
        }
    }

    private func resolvedLesson(_ snapshot: TodaySnapshot) -> ResolvedLessonRef? {
        guard let plan = snapshot.plan else { return nil }
        let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium
        let cadence = IntensityProfile.from(tier: tier).lessonCadence
        let ordinal = PrescriptionEngineV2.lessonOrdinal(
            programDay: snapshot.programDay, cadence: cadence
        ) ?? max(1, PrescriptionEngineV2.totalLessonDays(
            totalDays: min(snapshot.programDay, plan.totalDays), cadence: cadence
        ))
        let total = PrescriptionEngineV2.totalLessonDays(
            totalDays: plan.totalDays, cadence: cadence
        )
        return CBTCurriculumService.shared.lesson(
            forProgramDay: ordinal,
            totalDays: total,
            cohort: CohortFlags.fromAppStorage()
        )
    }

    private func journeyFraction(_ snapshot: TodaySnapshot) -> Double {
        guard snapshot.totalDays > 0 else { return 0 }
        return min(1, Double(snapshot.programDay) / Double(snapshot.totalDays))
    }

    private func journeyCaption(_ snapshot: TodaySnapshot) -> String {
        lessonDoneToday(snapshot)
            ? "today's read, kept \u{2665}\u{FE0E}"
            : "a 2-minute read"
    }

    private func lessonDoneToday(_ snapshot: TodaySnapshot) -> Bool {
        let s = snapshot.checkStates["lesson"] ?? "empty"
        return s == "complete" || s == "autoCompleted"
    }

    private func cleanTitle(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "*", with: "")
            .lowercased()
    }

    // MARK: - Wins

    @ViewBuilder private var winsBlock: some View {
        let showedUp = UserDefaults.standard.integer(forKey: "stats.shown_up_count")
        let plates = FoodLogPersister.allEntries(userId: userId).count
        if showedUp > 0 || plates > 0 {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("kept so far")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)

                VStack(spacing: 0) {
                    if showedUp > 0 {
                        JKReceiptRow(
                            lead: "you showed up",
                            punch: "\(showedUp) times \u{2665}\u{FE0E}",
                            punchItalic: [],
                            showsRule: false
                        )
                    }
                    if plates > 0 {
                        JKReceiptRow(
                            lead: "plates seen",
                            punch: "\(plates)",
                            punchItalic: [],
                            showsRule: showedUp > 0
                        )
                    }
                    JKChainLine(
                        lead: "open",
                        suggestion: "her food journal",
                        italic: ["journal"],
                        action: { showJournal = true }
                    )
                }
            }
            .padding(.horizontal, Space.lg)
        }
    }

    // MARK: - Sunday receipt (v2.5 — the week, kept)

    @ViewBuilder private var sundayReceipt: some View {
        if isReceiptDay,
           let week, week.loggedDays7 + week.last7.compactMap(\.steps).filter({ $0 > 0 }).count > 0 {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("the week, kept")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)

                VStack(spacing: 0) {
                    if week.loggedDays7 > 0 {
                        JKReceiptRow(
                            lead: "plates seen",
                            punch: plateWeekPunch(week),
                            punchItalic: [],
                            showsRule: false
                        )
                    }
                    if let target = week.proteinTargetG, target > 0, week.proteinDaysHit > 0 {
                        JKReceiptRow(
                            lead: "protein landed",
                            punch: "\(week.proteinDaysHit) of 7 days",
                            punchItalic: ["landed"]
                        )
                    }
                    if let delta = week.emaDelta7dKg, abs(delta) >= 0.1,
                       snapshot?.targets.numericsSuppressed == false {
                        JKReceiptRow(
                            lead: "the line",
                            punch: delta < 0
                                ? "eased down about \(roundedGrams(delta))g"
                                : "held its ground",
                            punchItalic: [delta < 0 ? "eased down" : "held"]
                        )
                    }
                }

                JKChainLine(
                    lead: "keep it",
                    suggestion: "save the week as a card",
                    italic: ["card"],
                    action: {
                        if let model = receiptModel(),
                           let image = WeeklyReceiptRenderer.render(model) {
                            Haptics.soft()
                            receiptShare = ReceiptShareItem(image: image)
                        }
                    }
                )
                .padding(.top, Space.xs)
            }
            .padding(.horizontal, Space.lg)
            .jkBeat2(extraDelay: 0.1)
        }
    }

    private func plateWeekPunch(_ week: WeekState) -> String {
        let plates = week.last7.map(\.plates).reduce(0, +)
        let days = week.loggedDays7
        let dayWord = days == 1 ? "day" : "days"
        return "\(plates), across \(days) \(dayWord)"
    }

    /// Nearest 50g with "about" — the same honesty register the
    /// trend story uses (photo-and-scale data doesn't earn 1g).
    private func roundedGrams(_ deltaKg: Double) -> Int {
        let g = abs(deltaKg) * 1000
        return max(50, Int((g / 50).rounded()) * 50)
    }

    private var isReceiptDay: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-receipt") {
            return true
        }
        #endif
        return Calendar.current.component(.weekday, from: .now) == 1
    }

    /// The artifact's numbers — same WeekState the on-screen block
    /// reads (provenance rule: nothing on the card she didn't live).
    private func receiptModel() -> WeeklyReceiptCard.Model? {
        guard let week else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d"
        let start = Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
        let range = "\(fmt.string(from: start).lowercased()) to \(fmt.string(from: .now).lowercased())"
        let stepsTotal = week.last7.compactMap(\.steps).reduce(0, +)
        var trendLine: String? = nil
        if let delta = week.emaDelta7dKg, abs(delta) >= 0.1,
           snapshot?.targets.numericsSuppressed == false {
            trendLine = delta < 0
                ? "eased down about \(roundedGrams(delta))g"
                : "held its ground"
        }
        return WeeklyReceiptCard.Model(
            weekRange: range,
            plates: week.last7.map(\.plates).reduce(0, +),
            loggedDays: week.loggedDays7,
            proteinDaysHit: week.proteinDaysHit,
            stepsTotal: stepsTotal > 0 ? stepsTotal : nil,
            trendLine: trendLine,
            resets: 0,   // breath-per-day not in WeekState yet; row hides at 0 (doc 25)
            jeniLine: "seven days, kept the way you keep things now \u{2665}\u{FE0E}"
        )
    }

    // MARK: - Refresh

    private func refresh() {
        guard !userId.isEmpty else { return }
        let snap = TodayStateService.snapshot(userId: userId, in: modelContext)
        let wk = WeekState.load(userId: userId, in: modelContext)
        snapshot = snap
        week = wk
        insights = InsightEngine.insights(week: wk, snapshot: snap)
    }
}
