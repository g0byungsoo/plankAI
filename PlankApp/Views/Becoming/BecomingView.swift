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
    /// Trailing-7 completed checks by itemKey (breath / lesson /
    /// weigh_in …) — the week receipt's provenance for "what helped."
    @State private var weekChecks: [String: Int] = [:]
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

                    // v3 field report (07_SOUL_PASS): interpretation
                    // first — ONE authored note, then the week's
                    // receipt, then the line itself, then the journey.
                    fieldNote
                        .padding(.top, Space.lg)
                        .jkBeat2()

                    theWeekHeld
                        .padding(.top, Space.section)
                        .jkBeat2(extraDelay: 0.08)

                    sundayReceipt
                        .padding(.top, Space.section)

                    theLine
                        .padding(.top, Space.section)
                        .jkBeat2(extraDelay: 0.15)

                    methodJourney
                        .padding(.top, Space.section)
                        .jkBeat2(extraDelay: 0.22)

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
            JKWeightRitual(
                startingFromKg: week?.weightLogs.first?.weightKg ?? 65,
                priorLoggedCount: week?.weightLogs.count ?? 0,
                isUpdatingToday: hasLoggedToday,
                onSave: { kg in
                    WeightLogWriter.persist(kg: kg, userId: userId, in: modelContext)
                    refresh()
                },
                onDone: { showLogWeight = false },
                onCancel: { showLogWeight = false }
            )
            .presentationDetents([.fraction(0.7)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)
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
                onDismiss: { showJournal = false },
                // v3 — each day remembers the quiet stretch that
                // preceded it (hard-gated inside QuietHours).
                dayNote: { [userId] day in
                    QuietHours.overnightForDay(userId: userId, day: day)
                        .map { "began after about \(Int($0.rounded())) quiet hours \u{2665}\u{FE0E}" }
                }
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

    // MARK: - The field note (ONE authored insight)

    /// The week, interpreted: the trend story's line leads; the top
    /// pattern's detail rides as its mechanism when the story has
    /// none. One voice, one ask — the insight-card stack is gone.
    @ViewBuilder private var fieldNote: some View {
        if let story = insights?.trendStory {
            VStack(alignment: .leading, spacing: 8) {
                JKCoachLine(
                    text: story.line,
                    italic: story.italic,
                    onOpenChat: { router.openChat(seed: story.chatSeed) }
                )
                if let mechanism = story.detail ?? insights?.cards.first?.detail {
                    Text(mechanism)
                        .font(Typo.caption)
                        .lineSpacing(3)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Space.lg)
        } else if let top = insights?.cards.first {
            VStack(alignment: .leading, spacing: 8) {
                JKCoachLine(
                    text: top.line,
                    italic: top.italic,
                    onOpenChat: { router.openChat(seed: top.chatSeed) }
                )
                if let detail = top.detail {
                    Text(detail)
                        .font(Typo.caption)
                        .lineSpacing(3)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Space.lg)
        }
    }

    // MARK: - The line (the data, one scroll deeper than the words)

    @ViewBuilder private var theLine: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if let week, week.weightLogs.count >= 2 {
                Text("the line")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.horizontal, Space.lg)

                BecomingTrendCanvas(
                    logs: week.weightLogs,
                    goalWeightKg: snapshot?.plan?.goalWeightKg,
                    unit: weightUnit,
                    bandSettleKg: snapshot?.chapter == .keeping
                        ? BandModel.settleWeightKg(plan: snapshot?.plan)
                        : nil
                )
                .padding(.horizontal, Space.lg)

                if snapshot?.chapter == .keeping,
                   BandModel.settleWeightKg(plan: snapshot?.plan) != nil {
                    Text("the tinted field is home. the line living there is the win.")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .padding(.horizontal, Space.lg)
                }
            } else if let firstLog = week?.weightLogs.first {
                // v2.9 — the single-weight state. A trend LINE needs
                // two points, but she HAS started — the old code
                // dropped her back into "log the first", which read as
                // "nothing done" the moment after she logged her first
                // morning. Acknowledge the weight, show it, and name
                // the one thing left.
                singleWeightStarted(firstLog)
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

    @ViewBuilder
    private func singleWeightStarted(_ log: WeightLogRecord) -> some View {
        VStack(spacing: 10) {
            Text("first morning, logged \u{2665}\u{FE0E}")
                .font(Typo.captionTracked)
                .kerning(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "%.1f", weightUnit.display(fromKg: log.weightKg)))
                    .font(.custom("JeniHeroSerif-Regular", size: 46))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .monospacedDigit()
                Text(weightUnit.label)
                    .font(.custom("JeniHeroSerif-Italic", size: 20))
                    .foregroundStyle(Palette.accent)
                    .baselineOffset(5)
            }

            (Text("one more morning and your ")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
             + Text("line begins")
                .font(.custom("JeniHeroSerif-Italic", size: 16))
                .foregroundStyle(Palette.cocoaSecondary)
             + Text(".")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.xl)
    }

    private var hasLoggedToday: Bool {
        guard let last = week?.weightLogs.first?.loggedAt else { return false }
        return Calendar.current.isDateInToday(last)
    }

    // MARK: - The week, held (the receipt — marks, not metrics)

    /// What held, what drifted, what helped — provenance rows only,
    /// each led by its ritual mark. Replaces the week dot-strip, the
    /// insight-card stack, and the wins block (their truths merged;
    /// their chrome retired).
    @ViewBuilder private var theWeekHeld: some View {
        let rows = weekHeldRows()
        // Sundays the artifact block IS the week's receipt — the held
        // rows yield rather than stack two receipt grammars.
        if !rows.isEmpty, !isReceiptDay {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("the week, held")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)

                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                        VStack(spacing: 0) {
                            if idx > 0 {
                                Rectangle()
                                    .fill(Palette.hairlineCocoa)
                                    .frame(height: 0.5)
                            }
                            heldRow(row)
                        }
                    }
                }

                JKChainLine(
                    lead: "open",
                    suggestion: "her food journal",
                    italic: ["journal"],
                    action: { showJournal = true }
                )
            }
            .padding(.horizontal, Space.lg)
        }
    }

    private struct HeldRow {
        let mark: JKMarkKind?
        let lead: String
        let punch: String
        let punchItalic: [String]
    }

    private func heldRow(_ row: HeldRow) -> some View {
        HStack(spacing: 12) {
            if let mark = row.mark {
                JKMark(kind: mark, size: 16,
                       color: Palette.cocoaSecondary.opacity(0.85))
                    .frame(width: 18)
            } else {
                Text("\u{2665}\u{FE0E}")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 18)
            }
            Text(row.lead)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 8)
            ItalicAccentText(
                row.punch,
                italic: row.punchItalic,
                baseFont: .custom("DMSans-Medium", size: 14, relativeTo: .footnote),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 15, relativeTo: .footnote),
                color: Palette.textPrimary,
                alignment: .trailing
            )
        }
        .padding(.vertical, 12)
    }

    /// The week's rows, chapter-aware, provenance-gated: up to two
    /// HELD, at most one DRIFTED (gentle, only when real), at most
    /// one HELPED. Quiet weeks earn the presence row, never blanks.
    private func weekHeldRows() -> [HeldRow] {
        guard let week else { return [] }
        var held: [HeldRow] = []
        var drifted: [HeldRow] = []
        var helped: [HeldRow] = []

        // — held
        if week.proteinDaysHit >= 3 {
            held.append(HeldRow(
                mark: .plate, lead: "protein",
                punch: "landed \(week.proteinDaysHit) of 7 days",
                punchItalic: ["landed"]
            ))
        }
        let goal = week.stepsGoal
        let goalDays = week.last7.compactMap(\.steps).filter { $0 >= goal }.count
        if goalDays >= 2 {
            held.append(HeldRow(
                mark: .path, lead: "her legs",
                punch: "covered the gap on \(goalDays) days",
                punchItalic: ["covered"]
            ))
        }
        let weighs = weekChecks["weigh_in", default: 0]
        if held.count < 2, weighs >= 1 {
            held.append(HeldRow(
                mark: .line, lead: "the line",
                punch: weighs == 1 ? "checked, zero verdicts" : "checked \(weighs) times, zero verdicts",
                punchItalic: ["checked"]
            ))
        }
        // The quiet hours — zero-input rhythm from her plate times
        // (hard-gated inside QuietHours for restriction-risk).
        let quietNights = QuietHours.liveQuietNights(userId: userId)
        if held.count < 2, quietNights >= 3 {
            held.append(HeldRow(
                mark: .moon, lead: "quiet hours",
                punch: "the kitchen slept well, \(quietNights) nights",
                punchItalic: ["slept well"]
            ))
        }

        // — drifted (one, gentle, only when real)
        if snapshot?.chapter == .keeping,
           let zone = snapshot?.bandZone, zone != BandZone.steady.rawValue {
            drifted.append(HeldRow(
                mark: .line, lead: "the band",
                punch: zone == BandZone.reset.rawValue
                    ? "a reset week, held together"
                    : "a steadying week",
                punchItalic: [zone == BandZone.reset.rawValue ? "held" : "steadying"]
            ))
        } else if week.loggedDays7 >= 3, let target = week.proteinTargetG,
                  target > 0, week.avgProtein7 < Int(Double(target) * 0.75),
                  week.proteinDaysHit < 3 {
            drifted.append(HeldRow(
                mark: .plate, lead: "protein",
                punch: "ran quiet. gently, more",
                punchItalic: ["gently"]
            ))
        }

        // — helped
        let breaths = weekChecks["breath", default: 0]
        let reps = weekChecks["lesson", default: 0]
        if breaths >= 1 {
            helped.append(HeldRow(
                mark: .breath, lead: "resets",
                punch: breaths == 1 ? "one this week" : "\(breaths) this week",
                punchItalic: []
            ))
        } else if reps >= 2 {
            helped.append(HeldRow(
                mark: .door, lead: "the method",
                punch: "\(reps) reps kept",
                punchItalic: ["kept"]
            ))
        }

        var rows = Array(held.prefix(2)) + Array(drifted.prefix(1)) + Array(helped.prefix(1))
        if rows.isEmpty {
            // The quiet-week floor: presence, never a blank.
            let presentDays = week.last7.filter { $0.plates > 0 }.count
                + weekChecks.values.reduce(0, +)
            if presentDays > 0 {
                rows.append(HeldRow(
                    mark: nil, lead: "you showed up",
                    punch: "the week is young",
                    punchItalic: ["young"]
                ))
            }
        }
        return rows
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
        // v3: ONE resolver (journey fallback keeps the card alive on
        // non-lesson days); cohort variants finally resolve through
        // CohortStore instead of the zero-writer fromAppStorage keys.
        MethodResolver.resolve(
            plan: snapshot.plan,
            programDay: snapshot.programDay,
            journeyFallback: true
        )?.ref
    }

    private func journeyFraction(_ snapshot: TodaySnapshot) -> Double {
        guard snapshot.totalDays > 0 else { return 0 }
        return min(1, Double(snapshot.programDay) / Double(snapshot.totalDays))
    }

    private func journeyCaption(_ snapshot: TodaySnapshot) -> String {
        // v3 deep pass — the practice has a MEMORY: lifetime kept
        // reps ride the caption (identity evidence, not a streak;
        // the count never resets).
        let kept = lifetimeRepsKept
        let base = lessonDoneToday(snapshot)
            ? "today's rep, kept \u{2665}\u{FE0E}"
            : "half a minute of practice"
        guard kept >= 3 else { return base }
        return "\(base) · \(kept) kept so far"
    }

    /// Lifetime completed method moments (reps/reads) for the active
    /// plan — fetched once per refresh alongside the week's checks.
    @State private var lifetimeRepsKept = 0

    private static func fetchLifetimeRepsKept(
        userId: String, planId: String?, in context: ModelContext
    ) -> Int {
        guard let planId else { return 0 }
        let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate {
                $0.userId == userId
                && $0.programPlanId == planId
                && $0.itemKey == "lesson"
            }
        )
        let checks = (try? context.fetch(descriptor)) ?? []
        return checks.filter {
            $0.state == "complete" || $0.state == "autoCompleted"
        }.count
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
        weekChecks = Self.fetchWeekChecks(
            userId: userId,
            planId: snap.plan?.id,
            programDay: snap.programDay,
            in: modelContext
        )
        lifetimeRepsKept = Self.fetchLifetimeRepsKept(
            userId: userId, planId: snap.plan?.id, in: modelContext
        )
    }

    /// Completed checks in the trailing week, grouped by itemKey —
    /// the same 7-day frame WeekState reads.
    private static func fetchWeekChecks(
        userId: String, planId: String?, programDay: Int,
        in context: ModelContext
    ) -> [String: Int] {
        guard let planId, programDay > 0 else { return [:] }
        let lo = max(1, programDay - 6)
        let hi = programDay
        let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate {
                $0.userId == userId
                && $0.programPlanId == planId
                && $0.programDay >= lo
                && $0.programDay <= hi
            }
        )
        let checks = (try? context.fetch(descriptor)) ?? []
        var counts: [String: Int] = [:]
        for check in checks
        where check.state == "complete" || check.state == "autoCompleted" {
            counts[check.itemKey, default: 0] += 1
        }
        return counts
    }
}
