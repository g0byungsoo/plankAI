import SwiftUI
import SwiftData
import PlankSync
import PlankFood
import Auth

// MARK: - BecomingView
//
// App v5 re-steer (docs/app_v5/00_DIRECTION.md §6). Becoming is a
// swipeable insight story — a horizontal pager of near-full-screen
// pages, one idea each, jeni walking her through her own body and
// plan: the line → food → movement → this week → (the band, keeping
// only) → from jeni. Plan history lives one level in ("her weeks"
// timeline behind the plan page); the vertical ledger is gone from
// the top surface.
//
// The re-signing (WeeklyReview) still presents here as a received
// full-screen moment when due; the plan page's due card re-offers.

struct BecomingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth = AuthService.shared
    @State private var router = AppRouter.shared

    @State private var snapshot: TodaySnapshot?
    @State private var week: WeekState?
    @State private var insights: InsightEngine.Output?
    @State private var journey: JourneyModel?
    @State private var pageIndex = 0

    @State private var showLogWeight = false
    @State private var showProfileHub = false
    @State private var showJournal = false
    @State private var showTimeline = false
    @State private var openedWeek: JourneyModel.WeekEntry?
    @State private var presentedReview: JourneyModel.DueReview?
    @State private var autoOfferedReviewWeek: Int? = nil

    /// The story's page order — cohort pages join when their data is
    /// real (the band page needs a keeping chapter).
    private enum StoryPage: Int, Identifiable {
        case line, food, movement, plan, band, reflection
        var id: Int { rawValue }
    }

    private var storyPages: [StoryPage] {
        var pages: [StoryPage] = [.line, .food, .movement, .plan]
        if snapshot?.chapter == .keeping { pages.append(.band) }
        pages.append(.reflection)
        return pages
    }

    /// Whether a page is the one on stage — its visual draws in on
    /// arrival and re-arms when she swipes back.
    private func isArmed(_ page: StoryPage) -> Bool {
        storyPages.firstIndex(of: page).map { $0 == pageIndex } ?? true
    }

    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    private var userId: String { auth.currentUser?.id.uuidString ?? "" }

    var body: some View {
        JKScreenChrome {
            VStack(alignment: .leading, spacing: 0) {
                masthead
                    .padding(.top, Space.hero)
                    .jkBeat1()

                if snapshot?.isEnrolled == false {
                    JKEmptyState(
                        line: "your story starts on day one",
                        italic: ["day one"],
                        actionLabel: "open today",
                        action: { router.tab = .today }
                    )
                    .padding(.top, Space.xl)
                    Spacer(minLength: 0)
                } else {
                    // The story: one insight per page, swiped.
                    TabView(selection: $pageIndex) {
                        ForEach(Array(storyPages.enumerated()), id: \.element.id) { idx, page in
                            storyPage(page)
                                .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .jkBeat2()
                    .onChange(of: pageIndex) { _, _ in
                        Haptics.soft()
                    }

                    JKPageDots(count: storyPages.count, index: pageIndex)
                        .padding(.bottom, 92)
                        .jkBeat2(extraDelay: 0.1)
                }
            }
        }
        .onAppear {
            refresh()
            #if DEBUG
            // QA: land on a specific story page.
            //   --uitest-becoming-page 3
            let args = ProcessInfo.processInfo.arguments
            if let idx = args.firstIndex(of: "--uitest-becoming-page"),
               idx + 1 < args.count, let page = Int(args[idx + 1]) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(nil) { pageIndex = min(max(0, page), storyPages.count - 1) }
                }
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onChange(of: router.tab) { _, tab in
            // Arriving at the journey re-evaluates the re-signing
            // offer (the auto-present is gated to THIS tab being
            // visible — all trees stay mounted, and an offer fired
            // from the hidden tree covers whatever tab she's on).
            if tab == .becoming { refresh() }
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
        .sheet(item: $openedWeek) { entry in
            JourneyWeekPage(
                entry: entry,
                snapshot: snapshot ?? placeholderSnapshot,
                userId: userId,
                onAskJeni: { seed in
                    openedWeek = nil
                    router.openChat(seed: seed)
                },
                onDismiss: { openedWeek = nil }
            )
            .presentationDetents([.large])
            .presentationBackground(Palette.bgPrimary)
        }
        .fullScreenCover(item: $presentedReview) { due in
            ReSigningView(
                due: due,
                userId: userId,
                onSigned: { _ in refresh() },
                onClose: { presentedReview = nil }
            )
        }
        .fullScreenCover(isPresented: $showJournal) {
            // v4: the archive page in the journey's grammar — the v1
            // journal interior (FoodLogTimelineView) is retired here.
            JourneyPlatesPage(
                userId: userId,
                onSnap: {
                    showJournal = false
                    router.open(.snap)
                },
                onDismiss: { showJournal = false }
            )
        }
        .fullScreenCover(isPresented: $showTimeline) {
            // v5 re-steer: plan history one level in — the story
            // stays up front, the record is here when she wants it.
            if let journey {
                JourneyTimelineView(
                    journey: journey,
                    onOpenWeek: { entry in
                        showTimeline = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            openedWeek = entry
                        }
                    },
                    onDismiss: { showTimeline = false }
                )
            }
        }
    }

    /// Sheet-content fallback only (the sheet can't present without a
    /// loaded snapshot in practice).
    private var placeholderSnapshot: TodaySnapshot {
        TodayStateService.snapshot(userId: userId, in: modelContext)
    }

    // MARK: - Masthead + the arc

    private var masthead: some View {
        JKMasthead(
            lead: .title("becoming", italic: ["becoming"]),
            eyebrow: arcEyebrow,
            marks: [
                JKMastheadMark(systemName: "line.3.horizontal", label: "settings") {
                    showProfileHub = true
                },
            ]
        )
    }

    // v5: ONE header object. The eyebrow carries position + phase
    // name ("week 2 of 20 · finding steady"); the big repeated phase
    // title below it died (the phase name showed three times on one
    // screen). Past the midpoint the eyebrow counts down instead —
    // the Koo & Fishbach framing flip, now in the position line.
    private var arcEyebrow: String? {
        guard let snapshot, snapshot.isEnrolled else { return nil }
        var parts: [String] = [ProgramArc.ordinalLine(
            week: snapshot.programWeek,
            totalWeeks: snapshot.totalWeeks,
            chapter: snapshot.chapter
        )]
        if let phase = snapshot.arcPhase { parts.append(phase.name) }
        if snapshot.chapter == .losing, snapshot.totalDays > 0,
           snapshot.programDay * 2 > snapshot.totalDays {
            let togo = max(snapshot.totalDays - snapshot.programDay, 0)
            parts.append("\(togo) \(togo == 1 ? "day" : "days") to go")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - The story pages

    @ViewBuilder
    private func storyPage(_ page: StoryPage) -> some View {
        switch page {
        case .line: linePage
        case .food: foodPage
        case .movement: movementPage
        case .plan: planPage
        case .band: bandPage
        case .reflection: reflectionPage
        }
    }

    /// Page 1 — the line. The trend canvas as hero; the insight
    /// sentence as the headline.
    private var lineCaption: String? {
        if let detail = insights?.trendStory?.detail { return detail }
        if snapshot?.chapter == .keeping,
           BandModel.settleWeightKg(plan: snapshot?.plan) != nil {
            return "the tinted field is home. the line living there is the win."
        }
        return nil
    }

    @ViewBuilder private var linePage: some View {
        let story = insights?.trendStory
        JKStoryPage(
            eyebrow: "weight",
            headline: story?.line ?? "your trend line starts with two mornings",
            headlineItalic: story?.italic ?? ["two mornings"],
            caption: lineCaption
        ) {
            if let week, week.weightLogs.count >= 2 {
                BecomingTrendCanvas(
                    logs: week.weightLogs,
                    goalWeightKg: snapshot?.plan?.goalWeightKg,
                    unit: weightUnit,
                    bandSettleKg: snapshot?.chapter == .keeping
                        ? BandModel.settleWeightKg(plan: snapshot?.plan)
                        : nil,
                    height: 170,
                    chromeless: true,
                    armed: isArmed(.line)
                )
            } else if let firstLog = week?.weightLogs.first {
                singleWeightStarted(firstLog)
            } else {
                emptyLineVisual
            }
        } doors: {
            if hasLoggedToday {
                EmptyView()
            } else {
                JKJourneyDoor(
                    lead: "thirty seconds",
                    punch: "log a weigh-in",
                    italic: ["weigh-in"],
                    action: { showLogWeight = true }
                )
            }
        }
    }

    /// The zero-state visual: a dotted ghost of the line to come.
    private var emptyLineVisual: some View {
        VStack(spacing: Space.md) {
            Canvas { ctx, size in
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height * 0.55))
                path.addCurve(
                    to: CGPoint(x: size.width, y: size.height * 0.4),
                    control1: CGPoint(x: size.width * 0.35, y: size.height * 0.7),
                    control2: CGPoint(x: size.width * 0.7, y: size.height * 0.28)
                )
                ctx.stroke(
                    path,
                    with: .color(Palette.cocoaTertiary.opacity(0.35)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 7])
                )
            }
            .frame(height: 90)
            Text("two mornings on the scale and it draws itself")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    /// Page 2 — food. One big protein arc; the week's protein fact.
    @ViewBuilder private var foodPage: some View {
        let suppressed = snapshot?.targets.numericsSuppressed ?? false
        let target = snapshot?.targets.proteinG
        JKStoryPage(
            eyebrow: "food",
            headline: foodHeadline,
            headlineItalic: foodHeadlineItalic,
            caption: foodCaption
        ) {
            VStack(spacing: Space.lg) {
                if !suppressed, let target {
                    JKProteinArc(
                        grams: snapshot?.proteinEatenG ?? 0,
                        targetG: target,
                        note: snapshot?.targets.proteinNote,
                        diameter: 148,
                        armed: isArmed(.food)
                    )
                    if let week {
                        JKProteinWeekBand(
                            days: week.last7.map { ($0.proteinG, $0.plates > 0) },
                            targetG: target
                        )
                    }
                    // v5 nutrition visibility: the rest of today's
                    // plate chemistry the pipeline already reads —
                    // carbs, fat, fiber (vitamins/minerals aren't in
                    // the vision contract yet; nothing invented).
                    if let snapshot, snapshot.kcalEaten > 0 {
                        HStack(spacing: 0) {
                            chemistryColumn("\(snapshot.kcalEaten)", "kcal")
                            chemistryColumn("\(snapshot.carbsEatenG)g", "carbs")
                            chemistryColumn("\(snapshot.fatEatenG)g", "fat")
                            chemistryColumn("\(snapshot.fiberEatenG)g", "fiber")
                        }
                        .padding(.top, Space.xs)
                    }
                } else if let week {
                    // Suppressed cohorts: presence, zero numerals.
                    JKProteinWeekBand(
                        days: week.last7.map { ($0.proteinG, $0.plates > 0) },
                        targetG: nil
                    )
                    .scaleEffect(1.4)
                }
            }
        } doors: {
            JKJourneyDoor(
                lead: "open",
                punch: "her plates",
                italic: ["plates"],
                action: { showJournal = true }
            )
        }
    }

    private func chemistryColumn(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.custom("DMSans-Medium", size: 15, relativeTo: .footnote))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
            Text(label)
                .font(Typo.statLabel)
                .kerning(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var foodHeadline: String {
        let suppressed = snapshot?.targets.numericsSuppressed ?? false
        guard let week else { return "the food story starts with plates." }
        if suppressed {
            return week.loggedDays7 >= 3
                ? "the plates were there \(week.loggedDays7) of 7 days."
                : "the plates tell the story, gently."
        }
        if week.proteinDaysHit >= 1, snapshot?.targets.proteinG != nil {
            return "protein landed \(week.proteinDaysHit) of 7 days."
        }
        if week.loggedDays7 >= 3 {
            return "plates logged on \(week.loggedDays7) of 7 days."
        }
        // A thin week but a live day: speak today (the arc beside a
        // "starts with plates" line read as a contradiction).
        if let g = snapshot?.proteinEatenG, g > 0 {
            return "\(g)g of protein so far today."
        }
        return "the food story starts with plates."
    }

    private var foodHeadlineItalic: [String] {
        foodHeadline.contains("protein") ? ["protein"]
            : (foodHeadline.contains("starts") ? ["starts"] : ["plates"])
    }

    private var foodCaption: String? {
        guard let snapshot else { return nil }
        if snapshot.targets.numericsSuppressed {
            return "protein is what matters today \u{2665}\u{FE0E}"
        }
        if snapshot.kcalEaten > 0, let target = snapshot.targets.kcal {
            let room = Int((Double(max(0, target - snapshot.kcalEaten)) / 50).rounded() * 50)
            return "today: \(snapshot.kcalEaten) of ~\(target.formatted()) · room for about \(room)"
        }
        if snapshot.chapter == .onMedication, let g = snapshot.targets.proteinG {
            return "the floor is \(g)g. small plates count double."
        }
        return "the count starts with your first plate."
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

    /// Page 3 — movement. The week's step rhythm, large.
    @ViewBuilder private var movementPage: some View {
        let goal = snapshot?.targets.steps ?? 7500
        let counts = StepsService.shared.weeklyCounts
        let goalDays = counts.filter { $0 >= goal }.count
        let walkedDays = counts.filter { $0 >= goal / 2 }.count
        JKStoryPage(
            eyebrow: "movement",
            headline: {
                if StepsService.shared.authStatus != .authorized {
                    return "your steps can count themselves."
                }
                if goalDays >= 2 { return "\(goalDays) of 7 days reached \(goal.formatted())." }
                if walkedDays >= 3 { return "real walks on \(walkedDays) days this week." }
                return "the easiest lever is just walking."
            }(),
            headlineItalic: goalDays >= 2 ? ["\(goal.formatted())"]
                : (walkedDays >= 3 ? ["real"] : ["walking"]),
            caption: {
                if StepsService.shared.authStatus != .authorized { return nil }
                return goalDays < 2 && walkedDays < 3
                    ? "the benefit starts far below 10k. that number was marketing."
                    : "counted for you, no logging."
            }()
        ) {
            if StepsService.shared.authStatus == .authorized {
                JKStepsRhythmVisual(
                    todayCount: StepsService.shared.todayCount,
                    weeklyCounts: counts,
                    goal: goal,
                    letters: trailingWeekLetters(count: counts.count),
                    armed: isArmed(.movement)
                )
            } else {
                // Not connected: seven quiet dashes, no ghost zero.
                HStack(spacing: 16) {
                    ForEach(0..<7, id: \.self) { _ in
                        Capsule()
                            .fill(Palette.hairlineCocoa)
                            .frame(width: 12, height: 2.5)
                    }
                }
                .accessibilityHidden(true)
            }
        } doors: {
            if StepsService.shared.authStatus == .notDetermined {
                JKJourneyDoor(
                    lead: "connect",
                    punch: "apple health",
                    italic: ["health"],
                    action: { Task { await StepsService.shared.requestAccess() } }
                )
            } else {
                EmptyView()
            }
        }
    }

    /// Page 4 — this week (the plan). The week's name, the days at
    /// stage size, the arc's position, the signed record, the doors.
    @ViewBuilder private var planPage: some View {
        JKStoryPage(
            eyebrow: "this week",
            headline: "\(journey?.currentWeek?.name ?? snapshot?.weekIntent?.name ?? "your week").",
            headlineItalic: [],
            caption: journey?.currentWeek?.intentLine ?? snapshot?.weekIntent?.line
        ) {
            VStack(spacing: Space.lg) {
                if let current = journey?.currentWeek {
                    Button {
                        Haptics.light()
                        openedWeek = current
                    } label: {
                        VStack(spacing: Space.md) {
                            JKWeekDotsVisual(
                                days: current.dotDays,
                                letters: weekLetters(current),
                                armed: isArmed(.plan)
                            )
                            if let delta = current.weightDeltaLine {
                                Text(delta)
                                    .font(.custom("DMSans-Medium", size: 13, relativeTo: .caption))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.cocoaSecondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(JKPress())
                    .accessibilityLabel("this week, day by day. opens the week")
                }

                // The ribbon speaks position; the week's intent line
                // is the page caption (two intent-toned sentences on
                // one page read as filler).
                if let snapshot, snapshot.arcPhase != nil {
                    JKArcRibbon(
                        phases: ProgramArc.phases(
                            totalWeeks: snapshot.totalWeeks,
                            chapter: snapshot.chapter
                        ),
                        currentWeek: snapshot.programWeek,
                        totalWeeks: snapshot.totalWeeks
                    )
                }
            }
        } doors: {
            VStack(spacing: 0) {
                if let record = journey?.currentWeek?.record {
                    HStack(spacing: 7) {
                        JKMark(kind: .door, size: 11, color: Palette.accent)
                        (Text("signed · ")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                        + Text(record.stampLine)
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .caption))
                            .foregroundStyle(Palette.cocoaSecondary))
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, Space.sm)
                }
                if let due = journey?.dueReview {
                    dueCard(due)
                        .padding(.bottom, Space.sm)
                }
                JKJourneyDoor(
                    lead: "open",
                    punch: "her weeks",
                    italic: ["weeks"],
                    action: { showTimeline = true }
                )
            }
        }
    }

    private func weekLetters(_ entry: JourneyModel.WeekEntry) -> [String] {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEEE"
        return entry.slice.days.map { fmt.string(from: $0.date).lowercased() }
    }

    /// Weekday letters for a trailing window ending today (the steps
    /// rhythm's axis).
    private func trailingWeekLetters(count: Int) -> [String] {
        guard count > 0 else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEEE"
        let cal = Calendar.current
        return (0..<count).map { i in
            let date = cal.date(byAdding: .day, value: i - (count - 1), to: .now) ?? .now
            return fmt.string(from: date).lowercased()
        }
    }

    /// Page 5 (keeping only) — the band. Maintenance as its own page.
    @ViewBuilder private var bandPage: some View {
        let zone = snapshot?.bandZone.flatMap(BandZone.init(rawValue:)) ?? .steady
        JKStoryPage(
            eyebrow: "the band",
            headline: {
                switch zone {
                case .steady: return "the band holds. so do you."
                case .drifting: return "a steadying week. the line comes home."
                case .reset: return "a reset arc, held with you."
                }
            }(),
            headlineItalic: [zone == .steady ? "holds" : (zone == .drifting ? "steadying" : "held")],
            caption: "keeping is quieter than losing. it counts more."
        ) {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(min(PresenceLedger.keptDays, max(snapshot?.programDay ?? 0, 0)))")
                        .font(.custom("JeniHeroSerif-Regular", size: 56, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.cocoaPrimary)
                        .monospacedDigit()
                    Text("kept days")
                        .font(.custom("JeniHeroSerif-Italic", size: 20, relativeTo: .title3))
                        .foregroundStyle(Palette.accent)
                        .baselineOffset(4)
                }
                Text("presence, counted. never a streak.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        } doors: {
            EmptyView()
        }
    }

    /// Page 6 — from jeni. The reflection letter + the practice.
    @ViewBuilder private var reflectionPage: some View {
        let card = insights?.cards.first
        let line = card?.line ?? snapshot?.brief.line ?? "the day writes; i read."
        let italic = card?.italic ?? snapshot?.brief.italic ?? []
        JKStoryPage(
            eyebrow: "from jeni",
            headline: line,
            headlineItalic: italic,
            caption: card?.detail ?? snapshot?.brief.mechanism
        ) {
            if let snapshot, snapshot.isEnrolled, let ref = resolvedLesson(snapshot) {
                practiceCard(ref, snapshot: snapshot)
            }
        } doors: {
            JKJourneyDoor(
                lead: "talk it",
                punch: "through with jeni",
                italic: ["jeni"],
                action: {
                    router.openChat(seed: card?.chatSeed ?? snapshot?.brief.chatSeed)
                }
            )
        }
    }

    private func dueCard(_ due: JourneyModel.DueReview) -> some View {
        Button {
            Haptics.soft()
            presentedReview = due
        } label: {
            HStack(spacing: 10) {
                JKMark(kind: .door, size: 14, color: Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("the week's receipt is ready")
                        .font(.custom("JeniHeroSerif-Regular", size: 16, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                    Text("read it back, sign next week")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.accentSubtle.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.accent.opacity(0.35), lineWidth: 0.8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("the week's receipt is ready. opens your weekly review")
    }

    // MARK: - The practice card (rides the reflection page)

    private static let actTitles = [
        1: "deconstruct the diet brain",
        2: "build the skills",
        3: "rewire the identity",
        4: "maintain for life",
    ]

    @ViewBuilder
    private func practiceCard(_ ref: ResolvedLessonRef, snapshot: TodaySnapshot) -> some View {
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
                            Text(practiceCaption(snapshot))
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
    }

    private func resolvedLesson(_ snapshot: TodaySnapshot) -> ResolvedLessonRef? {
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

    private func practiceCaption(_ snapshot: TodaySnapshot) -> String {
        let kept = lifetimeRepsKept
        let base = lessonDoneToday(snapshot)
            ? "today's rep, kept \u{2665}\u{FE0E}"
            : "half a minute of practice"
        guard kept >= 3 else { return base }
        return "\(base) · \(kept) kept so far"
    }

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

    private func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: - Refresh

    private func refresh() {
        guard !userId.isEmpty else { return }
        let snap = TodayStateService.snapshot(userId: userId, in: modelContext)
        let wk = WeekState.load(userId: userId, in: modelContext)
        snapshot = snap
        week = wk
        insights = InsightEngine.insights(week: wk, snapshot: snap)
        lifetimeRepsKept = Self.fetchLifetimeRepsKept(
            userId: userId, planId: snap.plan?.id, in: modelContext
        )
        let model = JourneyModel.load(userId: userId, snapshot: snap, in: modelContext)
        journey = model

        // The re-signing offers itself ONCE per due week per visit —
        // and ONLY while the journey is the visible tab. All three
        // trees stay mounted; an offer fired from the hidden tree
        // would cover Today mid-scroll (walker-caught).
        if let due = model.dueReview,
           router.tab == .becoming,
           autoOfferedReviewWeek != due.weekIndex {
            autoOfferedReviewWeek = due.weekIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if let stillDue = journey?.dueReview,
                   presentedReview == nil,
                   router.tab == .becoming {
                    presentedReview = stillDue
                }
            }
        }

        #if DEBUG
        // QA: open a week page directly (gesture-hunting a card
        // inside a scroll of tappables is walker-hostile; the tap
        // path is exercised by hand + the press style is shared).
        //   --uitest-open-week 3
        let args = ProcessInfo.processInfo.arguments
        if openedWeek == nil, model.dueReview == nil,
           let idx = args.firstIndex(of: "--uitest-open-week"),
           idx + 1 < args.count, let weekIdx = Int(args[idx + 1]) {
            let entry = weekIdx == model.currentWeek?.weekIndex
                ? model.currentWeek
                : model.pastWeeks.first(where: { $0.weekIndex == weekIdx })
            if let entry {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    openedWeek = entry
                }
            }
        }
        #endif
    }
}
