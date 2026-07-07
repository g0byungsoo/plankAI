import SwiftUI
import SwiftData
import PlankSync
import PlankFood
import Auth

// MARK: - BecomingView
//
// App v4 (docs/app_v4/02_JOURNEY.md). Becoming IS the journey — the
// place where time is visible. Top to bottom: the arc (named phase +
// ribbon), THE LINE (one-story trend + band), THIS WEEK (the open
// chapter), THE WEEKS (the ledger: receipt cards, signed adaptation
// stamps, quiet seams — absence never renders), THE FUTURE (shape,
// dotted, never locked), the practice, and the archive doors.
//
// The re-signing (WeeklyReview) presents here as a received full-
// screen moment when due; a due card in the ledger re-offers it.

struct BecomingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth = AuthService.shared
    @State private var router = AppRouter.shared

    @State private var snapshot: TodaySnapshot?
    @State private var week: WeekState?
    @State private var insights: InsightEngine.Output?
    @State private var journey: JourneyModel?
    @State private var showEarlierWeeks = false

    @State private var showLogWeight = false
    @State private var showProfileHub = false
    @State private var showJournal = false
    @State private var openedWeek: JourneyModel.WeekEntry?
    @State private var presentedReview: JourneyModel.DueReview?
    @State private var autoOfferedReviewWeek: Int? = nil

    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    private var userId: String { auth.currentUser?.id.uuidString ?? "" }

    var body: some View {
        JKScreenChrome {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    masthead
                        .padding(.top, Space.hero)
                        .jkBeat1()
                        .onAppear {
                            #if DEBUG
                            if ProcessInfo.processInfo.arguments.contains("--uitest-becoming-bottom") {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                    withAnimation(nil) {
                                        proxy.scrollTo("becoming.bottom", anchor: .bottom)
                                    }
                                }
                            }
                            #endif
                        }

                    if snapshot?.isEnrolled == false {
                        JKEmptyState(
                            line: "your story starts on day one",
                            italic: ["day one"],
                            actionLabel: "open today",
                            action: { router.tab = .today }
                        )
                        .padding(.top, Space.xl)
                    } else {
                        arcHeader
                            .padding(.top, Space.lg)
                            .jkBeat2()

                        theLine
                            .padding(.top, Space.section)
                            .jkBeat2(extraDelay: 0.08)

                        thisWeek
                            .padding(.top, Space.section)
                            .jkBeat2(extraDelay: 0.15)

                        theWeeks
                            .padding(.top, Space.section)
                            .jkBeat2(extraDelay: 0.22)

                        theFuture
                            .padding(.top, Space.section)

                        thePractice
                            .padding(.top, Space.section)

                        doors
                            .padding(.top, Space.section)
                            .padding(.horizontal, Space.lg)
                    }

                    Spacer(minLength: 96)
                        .id("becoming.bottom")
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { refresh() }
            }
        }
        .onAppear { refresh() }
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

    private var arcEyebrow: String? {
        guard let snapshot, snapshot.isEnrolled else { return nil }
        var parts: [String] = []
        if let lead = snapshot.arcLead { parts.append(lead) }
        parts.append(ProgramArc.ordinalLine(
            week: snapshot.programWeek,
            totalWeeks: snapshot.totalWeeks,
            chapter: snapshot.chapter
        ))
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var arcHeader: some View {
        if let snapshot, let phase = snapshot.arcPhase {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(phase.name)
                        .font(.custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title3))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: 8)
                }
                JKArcRibbon(
                    phases: ProgramArc.phases(
                        totalWeeks: snapshot.totalWeeks,
                        chapter: snapshot.chapter
                    ),
                    currentWeek: snapshot.programWeek,
                    totalWeeks: snapshot.totalWeeks
                )
                Text(phase.line)
                    .font(Typo.caption)
                    .lineSpacing(2)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.lg)
        }
    }

    // MARK: - The line (interpretation above the data, ONE story)

    @ViewBuilder private var theLine: some View {
        VStack(alignment: .leading, spacing: Space.md) {
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
                }
                .padding(.horizontal, Space.lg)
            }

            if let week, week.weightLogs.count >= 2 {
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

    // MARK: - This week (the open chapter)

    @ViewBuilder private var thisWeek: some View {
        if let journey, let current = journey.currentWeek {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("this week")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)

                JKWeekCard(
                    entry: currentWithToday(current),
                    isCurrent: true,
                    onOpen: { openedWeek = current }
                )

                if let due = journey.dueReview {
                    dueCard(due)
                }
            }
            .padding(.horizontal, Space.lg)
        }
    }

    /// Marks today's dot inside the current week's card.
    private func currentWithToday(_ entry: JourneyModel.WeekEntry) -> JourneyModel.WeekEntry {
        entry
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
                    Text("read it back, sign the next step")
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
        .accessibilityLabel("the week's receipt is ready. opens the re-signing")
    }

    // MARK: - The weeks (the ledger)

    @ViewBuilder private var theWeeks: some View {
        if let journey, !journey.pastWeeks.isEmpty {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("the weeks")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)

                VStack(spacing: Space.md) {
                    ForEach(journey.pastWeeks) { entry in
                        if entry.slice.elapsedDays.isEmpty
                            || (entry.slice.keptCount == 0
                                && entry.slice.plateCount == 0
                                && entry.slice.weighCount == 0
                                && entry.record == nil) {
                            // Quiet weeks compress to a seam.
                            JKQuietSeam(line: "week \(entry.weekIndex) passed quietly")
                                .padding(.vertical, 2)
                        } else {
                            JKWeekCard(
                                entry: entry,
                                isCurrent: false,
                                onOpen: { openedWeek = entry }
                            )
                        }
                    }
                }

                if journey.earlierWeekCount > 0 {
                    JKQuietSeam(line: showEarlierWeeks
                        ? "the beginning"
                        : "\(journey.earlierWeekCount) earlier \(journey.earlierWeekCount == 1 ? "week" : "weeks")")
                        .padding(.vertical, 2)
                        .onTapGesture {
                            // Earlier weeks load on demand (v4.1) —
                            // the seam names them so the past is never
                            // silently truncated.
                        }
                }
            }
            .padding(.horizontal, Space.lg)
        }
    }

    // MARK: - The future (shape, never a list)

    @ViewBuilder private var theFuture: some View {
        if let journey, let name = journey.nextWeekName,
           let shape = journey.nextWeekShape {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("ahead")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                JKFutureShapeCard(name: name, shapeLine: shape)
            }
            .padding(.horizontal, Space.lg)
        }
    }

    // MARK: - The practice (the method's journey memory)

    private static let actTitles = [
        1: "deconstruct the diet brain",
        2: "build the skills",
        3: "rewire the identity",
        4: "maintain for life",
    ]

    @ViewBuilder private var thePractice: some View {
        if let snapshot, snapshot.isEnrolled, let ref = resolvedLesson(snapshot) {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("the practice")
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
                .padding(.horizontal, Space.lg)
            }
        }
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

    // MARK: - Doors (the archive)

    private var doors: some View {
        VStack(spacing: 0) {
            JKJourneyDoor(
                lead: "open",
                punch: "her plates",
                italic: ["plates"],
                showsRule: true,
                action: { showJournal = true }
            )
            JKJourneyDoor(
                lead: "open",
                punch: "her file",
                italic: ["file"],
                action: { router.tab = .jeni }
            )
        }
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
