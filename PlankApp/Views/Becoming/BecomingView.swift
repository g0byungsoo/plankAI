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
    /// v7 — the drill-in path (the pager's pageIndex died with it).
    @State private var path: [StoryPage] = []
    /// v7.1 (founder: "i loved the carousel") — inside the drill-in
    /// the pages are a swipeable carousel again; this is its stage.
    @State private var carouselPage: StoryPage = .line
    /// The page set, CAPTURED at push time: storyPages recomputes as
    /// stories load/refresh, and a transiently-missing page made the
    /// folio lie ("i" over page iv — frame audit). The carousel
    /// browses the set she entered with; it never shifts under her.
    @State private var pushedPages: [StoryPage] = []

    // v6 — the passive-signal stories (docs/app_v6/00_RESEARCH.md).
    @State private var windowWeek: KitchenSignal.WeekStory?
    @State private var sweetStory: Sweetness.Story?
    /// v6.5 — the coach's one-move synthesis over the signal week.
    @State private var coachSummary: CoachSummary.Output?
    @State private var rhythmStory: WeekRhythm.Story?
    @State private var sleepRecaps: [SleepService.NightRecap] = []
    @State private var pacingStory: ProteinPacing.Story?
    @State private var seasonRead: CycleSignal.Read?

    @State private var showLogWeight = false
    @State private var showProfileHub = false
    @State private var showJournal = false
    /// The plate whose detail sheet is open (from the plates page).
    @State private var detailPlate: FoodLogPersister.FoodLogEntry?
    @State private var showTimeline = false
    @State private var openedWeek: JourneyModel.WeekEntry?
    @State private var presentedReview: JourneyModel.DueReview?
    @State private var autoOfferedReviewWeek: Int? = nil

    /// The story's page order — cohort pages join when their data is
    /// real (the band page needs a keeping chapter).
    private enum StoryPage: Int, Identifiable {
        case line, food, plates, window, movement, plan, band, reflection
        // v6 — the passive-signal pages (appended so raw ids stay stable).
        case sweetness, sleep, rhythm, pacing, season
        // v6.5 — the coach's one-move synthesis closing the signals.
        case summary
        var id: Int { rawValue }
    }

    private var storyPages: [StoryPage] {
        var pages: [StoryPage] = [.line, .food]
        // Today's plates, relocated off Home (founder 1.1.5): the photo
        // log becomes its own page right after the food read — but only
        // once there's a plate to show, so it's never an empty filler
        // page. Restrictive-risk cohorts skip the plate-count surface.
        if !CohortStore.isRestrictiveRisk, !todaysPlates.isEmpty {
            pages.append(.plates)
        }
        // v6.1 — PROTEIN PACING: when protein arrives (Leidy: a
        // protein-forward morning quiets evening snacking).
        if pacingStory != nil {
            pages.append(.pacing)
        }
        // v6 — SWEETNESS: when sugar lands, observation only.
        // liveStory carries its own gates (restrictive-risk +
        // suppressed off; 3 sugar-days floor).
        if sweetStory != nil {
            pages.append(.sweetness)
        }
        // THE OVERNIGHT WINDOW — a rhythm insight, cohort-gated: the
        // on-medication chapter runs adequacy-first (under-eating is
        // the documented risk) and restrictive-risk identities never
        // see a fasting frame. Renders only when QuietHours can
        // narrate honestly (its own 8–20h gates).
        if overnightHours != nil || windowWeek != nil,
           snapshot?.chapter != .onMedication,
           !CohortStore.isRestrictiveRisk {
            pages.append(.window)
        }
        // v6 — NIGHTS: sleep → appetite, needs 3 mornings of data.
        if sleepRecaps.count >= 3 {
            pages.append(.sleep)
        }
        pages.append(.movement)
        // v6 — RHYTHM: cadence receipts (weigh days + first plates).
        if let rhythm = rhythmStory,
           rhythm.weighDayCount >= 2 || rhythm.firstPlateMedianMinutes != nil {
            pages.append(.rhythm)
        }
        // v6.1 — YOUR SEASON: cycle-phase appetite context. Never for
        // perimenopausal identities (phase math misleads).
        if seasonRead != nil, !CohortStore.isPerimenopausal {
            pages.append(.season)
        }
        pages.append(.plan)
        if snapshot?.chapter == .keeping { pages.append(.band) }
        // v7: JENI'S COACHING left the index — the landing section
        // carries the read now (docs/app_v7 §2), so a page here
        // would duplicate it.
        pages.append(.reflection)
        return pages
    }

    private var overnightHours: Double? {
        #if DEBUG
        // QA determinism: the live read depends on wall-clock vs
        // plate times (a 2am run has no "morning" yet).
        //   --uitest-force-window 13
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "--uitest-force-window"),
           idx + 1 < args.count, let h = Double(args[idx + 1]) {
            return h
        }
        #endif
        return QuietHours.liveOvernight(userId: userId)
    }

    /// v7.1: inside the drill-in carousel, the page on stage draws in
    /// on arrival and re-arms as she swipes — the liveliness the
    /// founder loved about the pager, now behind a map instead of
    /// instead of one.
    private func isArmed(_ page: StoryPage) -> Bool {
        path.isEmpty || carouselPage == page
    }

    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    private var userId: String { auth.currentUser?.id.uuidString ?? "" }

    var body: some View {
        // v7 (docs/app_v7 §2): the 12-14-page serial pager retired.
        // becoming is overview → drill-in: jeni's read of the week
        // lands first, a vertical index of signal cards follows, and
        // each card PUSHES its full story page (back-swipe, platform
        // muscle memory). The pages themselves survive intact — only
        // their access grammar changed.
        NavigationStack(path: $path) {
            JKScreenChrome {
                VStack(alignment: .leading, spacing: 0) {
                    if snapshot?.isEnrolled == false {
                        masthead
                            .padding(.top, Space.hero)
                            .jkBeat1()
                        JKEmptyState(
                            line: "your story starts on day one",
                            italic: ["day one"],
                            actionLabel: "open today",
                            action: { router.tab = .today }
                        )
                        .padding(.top, Space.xl)
                        Spacer(minLength: 0)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                masthead
                                    .padding(.top, Space.hero)
                                    .jkBeat1()

                                coachReadSection
                                    .padding(.horizontal, Space.lg)
                                    .padding(.top, Space.lg)
                                    .jkBeat2()

                                signalIndex
                                    .padding(.horizontal, Space.lg)
                                    .padding(.top, Space.section)
                                    .jkBeat2(extraDelay: 0.12)

                                Spacer(minLength: 96)
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .navigationDestination(for: StoryPage.self) { page in
                pushedStory(page)
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
                // v7: the ordinal now pushes that story card.
                // 2.4s: past the landing's refresh so the captured
                // page set includes the data-gated stories.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    let pages = storyPages
                    let clamped = min(max(0, page), pages.count - 1)
                    pushedPages = pages
                    carouselPage = pages[clamped]
                    withAnimation(nil) { path = [pages[clamped]] }
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
        .sheet(item: $detailPlate) { plate in
            PlateDetailSheet(
                entry: plate,
                userId: userId,
                onDismiss: { detailPlate = nil }
            )
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

    // MARK: - v7 landing: jeni's read + the signal index

    /// The week's read leads the page (docs/app_v7 §2) — the
    /// CoachSummary synthesis that was buried on pager page ~11.
    /// Under 2 signal stories it stays silent (its own data floor)
    /// and the index leads.
    @ViewBuilder
    private var coachReadSection: some View {
        if let read = coachSummary {
            // Mission 2 (02_VISUAL.md §2): the COVER LINE — the
            // week's read at hero scale. The kicker died (the
            // masthead's eyebrow is this screen's one caps event);
            // the chat door is a ghost italic line, not a caps link.
            VStack(alignment: .leading, spacing: 12) {
                ItalicAccentText(
                    read.headline,
                    italic: read.italic,
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .kerning(-0.4)
                .fixedSize(horizontal: false, vertical: true)

                Text(read.why)
                    .font(.custom("DMSans-Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let season = read.seasonNote {
                    Text(season)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.jeweledRose)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Haptics.soft()
                    router.openChat(seed: read.chatSeed)
                } label: {
                    Text("talk it through \u{2197}")
                        .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .callout))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
                .padding(.top, 2)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// The vertical index: every live signal as one glanceable row —
    /// kicker, its current one-line read, and the push into the full
    /// story page. Hairlines, not cards (one gesture per surface).
    /// Mission 2: the CONTENTS — a magazine's table of contents, not
    /// a settings table. The seam header, "tap to open," and every
    /// chevron are dead; the lines themselves are the doors, pitched
    /// loose, opening on a single hairline.
    private var signalIndex: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(height: 0.5)
                .padding(.bottom, 4)

            ForEach(Array(storyPages.enumerated()), id: \.element.id) { _, page in
                Button {
                    // Stage the carousel BEFORE the push so the
                    // destination opens on the tapped story, over
                    // a page set frozen for the browse.
                    pushedPages = storyPages
                    carouselPage = page
                    Haptics.soft()
                    path.append(page)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(indexKicker(for: page))
                            .font(Typo.captionTracked)
                            .kerning(1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text(indexLine(for: page))
                            .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .body))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
                .accessibilityLabel("\(indexKicker(for: page)). \(indexLine(for: page))")
                .accessibilityHint("opens the full story")
            }
        }
    }

    private func indexKicker(for page: StoryPage) -> String {
        switch page {
        case .line: return "weight"
        case .food: return "food"
        case .plates: return "today's plates"
        case .window: return "the overnight fast"
        case .movement: return "movement"
        case .plan: return "this week"
        case .band: return "the band"
        case .reflection: return "from jeni"
        case .sweetness: return "sugar intake"
        case .sleep: return "sleep"
        case .rhythm: return "consistency"
        case .pacing: return "protein timing"
        case .season: return "your cycle"
        case .summary: return "jeni's coaching"
        }
    }

    /// Each row's one-line current read — the same generators the
    /// full pages use, so the index and the page never disagree.
    private func indexLine(for page: StoryPage) -> String {
        switch page {
        case .line:
            return insights?.trendStory?.line ?? "2 weigh-ins start your trend line"
        case .food:
            return foodHeadline
        case .plates:
            let n = todaysPlates.count
            return n == 1 ? "1 plate, kept." : "\(n) plates, kept."
        case .window:
            if let story = windowWeek { return windowWeekHeadline(story).0 }
            if let hours = overnightHours {
                return "about \(Int(hours.rounded())) hours last night."
            }
            return "starts with tonight's dinner."
        case .movement:
            let goal = snapshot?.targets.steps ?? 7500
            let goalDays = StepsService.shared.weeklyCounts.filter { $0 >= goal }.count
            return goalDays >= 1
                ? "\(goalDays) of 7 days reached \(goal.formatted())."
                : "the easiest lever is just walking."
        case .plan:
            if let intent = snapshot?.weekIntent {
                return "\(intent.name) · week \(snapshot?.programWeek ?? 1)"
            }
            return "your week, named"
        case .band:
            switch snapshot?.bandZone {
            case BandZone.steady.rawValue: return "inside your band."
            case BandZone.drifting.rawValue: return "drifting · a steadying week."
            case BandZone.reset.rawValue: return "a reset week, held."
            default: return "your keeping band"
            }
        case .reflection:
            return "close the week in one line"
        case .sweetness:
            if let story = sweetStory { return sweetHeadline(story).0 }
            return "when sugar lands in your day"
        case .sleep:
            let hours = sleepRecaps.map(\.hours)
            guard !hours.isEmpty else { return "your nights, noticed" }
            let avg = hours.reduce(0, +) / Double(hours.count)
            return "about \(SleepSignal.durationWord(avg * 3600)) a night."
        case .rhythm:
            if let story = rhythmStory { return rhythmHeadline(story).0 }
            return "consistency, kept as receipts"
        case .pacing:
            if let story = pacingStory { return pacingHeadline(story).0 }
            return "when protein arrives"
        case .season:
            if let season = seasonRead { return seasonHeadline(season).0 }
            return "cycle context"
        case .summary:
            return coachSummary?.headline ?? "jeni's read of your week"
        }
    }

    /// v7.1 (founder: "i loved the carousel") — the drill-in is the
    /// full-bleed CAROUSEL again: enter at the tapped story, swipe
    /// left/right through the spreads, the roman folio tracks the
    /// place. The index remains the map; the carousel is the read.
    @ViewBuilder
    private func pushedStory(_ page: StoryPage) -> some View {
        let pages = pushedPages.isEmpty ? storyPages : pushedPages
        JKScreenChrome {
            VStack(spacing: 0) {
                // The paging ScrollView, not TabView: page-style
                // TabView publishes its first REALIZED child back
                // into the selection during lazy mount (the folio
                // lied "i" over page iv — frame audit), and no
                // re-assert timing reliably outlives it.
                // scrollPosition(id:) initializes at the staged page
                // and never writes back a default.
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(pages) { p in
                                ScrollView {
                                    storyPage(p)
                                        .containerRelativeFrame(.vertical) { length, _ in
                                            length
                                        }
                                }
                                .scrollIndicators(.hidden)
                                .containerRelativeFrame(.horizontal)
                                .id(p)
                                // The page on stage is the one whose
                                // leading edge sits at ~0 in carousel
                                // space — geometry is the ONE source
                                // of truth (every selection-binding
                                // arrangement raced the lazy mount;
                                // the audit kept catching the folio
                                // lying "i" over page iv).
                                .background(GeometryReader { g in
                                    Color.clear.preference(
                                        key: JKCarouselOffsetKey.self,
                                        value: [p.rawValue: g.frame(in: .named("jk.carousel")).minX]
                                    )
                                })
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollIndicators(.hidden)
                    .coordinateSpace(name: "jk.carousel")
                    .onPreferenceChange(JKCarouselOffsetKey.self) { offsets in
                        guard let nearest = offsets.min(by: {
                            abs($0.value) < abs($1.value)
                        }), let p = StoryPage(rawValue: nearest.key),
                        carouselPage != p
                        else { return }
                        carouselPage = p
                        Haptics.soft()
                    }
                    // The lazy stack doesn't honor a far initial
                    // position on its own — jump to the staged story
                    // once, unanimated, at mount; geometry reporting
                    // then keeps the folio honest from there.
                    .onAppear {
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) {
                            proxy.scrollTo(page, anchor: .leading)
                        }
                    }
                }

                // THE FORE-EDGE (02_VISUAL.md §4): the roman folio is
                // dead. Position is the leaves of a held magazine —
                // read leaves inked, the open leaf rose and taller,
                // sliding as she flips. No numerals anywhere.
                foreEdge(current: carouselPage, pushed: page, in: pages)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Space.sm)
                    .accessibilityLabel(
                        "story \((pages.firstIndex(of: carouselPage) ?? 0) + 1) of \(pages.count)"
                    )
            }
        }
        .toolbarBackground(Palette.bgPrimary, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { carouselPage = page }
    }

    /// The weight page's ledger row (label whisper left, serif value
    /// right — beat-19 grammar).
    @ViewBuilder
    private func weightLedgerRow(
        _ label: String, _ value: String, rule: Bool = true
    ) -> some View {
        VStack(spacing: 0) {
            if rule {
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.5)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: 16)
                Text(value)
                    .font(.custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(.vertical, 11)
        }
    }

    /// THE FORE-EDGE: one hairline leaf per page. Read leaves at 40%
    /// cocoa, unread at 15%, the open leaf rose and slightly taller.
    /// Geometry truth (carouselPage) drives it; the pushed page is
    /// the fallback so the rail never misplaces during mount.
    @ViewBuilder
    private func foreEdge(
        current: StoryPage, pushed: StoryPage, in pages: [StoryPage]
    ) -> some View {
        let index = pages.firstIndex(of: current)
            ?? pages.firstIndex(of: pushed)
            ?? 0
        HStack(spacing: 6) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { i, _ in
                Capsule()
                    .fill(
                        i == index
                            ? Palette.jeweledRose
                            : Palette.cocoaPrimary.opacity(i < index ? 0.4 : 0.15)
                    )
                    .frame(width: 14, height: i == index ? 3 : 1)
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
    }

    // MARK: - The story pages

    @ViewBuilder
    private func storyPage(_ page: StoryPage) -> some View {
        switch page {
        case .line: linePage
        case .food: foodPage
        case .plates: platesPage
        case .window: windowPage
        case .movement: movementPage
        case .plan: planPage
        case .band: bandPage
        case .reflection: reflectionPage
        case .sweetness: sweetnessPage
        case .summary: summaryPage
        case .sleep: sleepPage
        case .rhythm: rhythmPage
        case .pacing: pacingPage
        case .season: seasonPage
        }
    }

    /// The overnight window — meal-timing rhythm as an insight.
    /// Evidence-honest: overnight stretch consistency supports
    /// adherence; framed as her own pattern, never a fasting rule or
    /// a fat-burn claim (the same honesty stance as breathwork).
    /// v6: the week of nights leads (JKWindowWeekBand); a single
    /// narratable night falls back to the ring.
    @ViewBuilder private var windowPage: some View {
        if let weekStory = windowWeek {
            JKStoryPage(
                eyebrow: "the overnight fast",
                headline: windowWeekHeadline(weekStory).0,
                headlineItalic: windowWeekHeadline(weekStory).1,
                caption: "a steady 12 to 14 hour overnight fast trims intake and stores less. gentle beats forced, always \u{2665}\u{FE0E}"
            ) {
                VStack(spacing: Space.lg) {
                    JKWindowWeekBand(nights: weekStory.nights, armed: isArmed(.window))
                    JKStatTriplet(items: windowStats(weekStory))
                        .jkStagedReveal(armed: isArmed(.window), delay: 0.55)
                    if let line = BodyLine.window(
                        avgHours: weekStory.averageHours,
                        narratedCount: weekStory.narratedCount,
                        easedDisplay: easedDeltaDisplay
                    ) {
                        JKBodyLine(text: line)
                            .jkStagedReveal(armed: isArmed(.window), delay: 0.8)
                    }
                }
            } doors: {
                EmptyView()
            }
        } else {
            let hours = overnightHours ?? 0
            JKStoryPage(
                eyebrow: "the overnight fast",
                headline: hours >= 12
                    ? "you fasted about \(Int(hours.rounded())) hours last night, without trying."
                    : "you fasted about \(Int(hours.rounded())) hours last night.",
                headlineItalic: ["fasted"],
                caption: "a steady 12 to 14 hour overnight fast supports the loss. a pattern, not a rule \u{2665}\u{FE0E}"
            ) {
                JKNightWindowRing(hours: hours, armed: isArmed(.window))
            } doors: {
                EmptyView()
            }
        }
    }

    private func windowStats(_ story: KitchenSignal.WeekStory) -> [JKStatTriplet.Item] {
        var items: [JKStatTriplet.Item] = []
        if let avg = story.averageHours {
            items.append(.init(value: "\(Int(avg.rounded()))h", label: "a night"))
        }
        if let median = story.medianCloseMinutes {
            items.append(.init(value: clockWord(minutes: median), label: "usual last plate"))
        }
        items.append(.init(value: "\(story.narratedCount)", label: "nights"))
        return items
    }

    /// The week's window headline — care first (a 16h+ average never
    /// reads as achievement), then the strongest true pattern.
    private func windowWeekHeadline(_ story: KitchenSignal.WeekStory) -> (String, [String]) {
        // v6.4 direct register (founder call): the fast is named.
        if let avg = story.averageHours, avg >= 16 {
            return ("your fasts are running long. make sure you're eating enough.", ["enough"])
        }
        if let median = story.medianCloseMinutes,
           let spread = story.closeSpreadMinutes, spread <= 90 {
            return ("your fast starts near \(clockWord(minutes: median)) most nights.", ["starts"])
        }
        if let avg = story.averageHours {
            return ("you fasted about \(Int(avg.rounded())) hours a night this week.", ["fasted"])
        }
        return ("your overnight fast varies night to night.", ["varies"])
    }

    // MARK: v6 — the passive-signal pages

    /// SWEETNESS — when sugar lands and which way it's moving.
    /// Observation only: no verdicts, no gram budget, no red.
    @ViewBuilder private var sweetnessPage: some View {
        if let story = sweetStory {
            JKStoryPage(
                eyebrow: "sugar intake",
                headline: sweetHeadline(story).0,
                headlineItalic: sweetHeadline(story).1,
                caption: "no food is banned here. sugar is just the easiest place to trim \u{2665}\u{FE0E}"
            ) {
                VStack(spacing: Space.lg) {
                    // Mission 2: the values ride the mounds — the
                    // triplet that duplicated the axis labels died.
                    JKMomentMounds(
                        morning: story.morningShare,
                        afternoon: story.afternoonShare,
                        evening: story.eveningShare,
                        tint: .rose,
                        substance: "sugar",
                        armed: isArmed(.sweetness),
                        values: moundValues(
                            story.morningShare, story.afternoonShare, story.eveningShare
                        )
                    )
                    if let line = BodyLine.sweetness(
                        direction: story.direction, easedDisplay: easedDeltaDisplay
                    ) {
                        JKBodyLine(text: line)
                            .jkStagedReveal(armed: isArmed(.sweetness), delay: 0.8)
                    }
                }
            } doors: {
                EmptyView()
            }
        }
    }

    private func sweetStats(_ story: Sweetness.Story) -> [JKStatTriplet.Item] {
        var items: [JKStatTriplet.Item] = []
        if snapshot?.targets.numericsSuppressed != true {
            items.append(.init(value: "\(story.averageG)g", label: "a day, average"))
        }
        items.append(.init(value: story.dominantMoment, label: "mostly"))
        if let direction = story.direction {
            let word = switch direction {
            case .easing: "down"
            case .steady: "steady"
            case .rising: "up"
            }
            items.append(.init(value: word, label: "vs last week"))
        }
        return items
    }

    /// PROTEIN PACING — the arc answers "enough?"; this answers
    /// "early enough?" (Leidy RCTs: 35g mornings cut evening
    /// snacking). Observation, never a meal plan.
    @ViewBuilder private var pacingPage: some View {
        if let story = pacingStory {
            JKStoryPage(
                eyebrow: "protein timing",
                headline: pacingHeadline(story).0,
                headlineItalic: pacingHeadline(story).1,
                // Mission 2: the caption died — it restated the
                // BodyLine's advice word for word (the twice-printed
                // sentence the panel flagged).
                caption: nil
            ) {
                VStack(spacing: Space.lg) {
                    // Mission 2: the values ride the mounds — the
                    // triplet that duplicated the axis labels died.
                    JKMomentMounds(
                        morning: story.morningShare,
                        afternoon: story.afternoonShare,
                        evening: story.eveningShare,
                        tint: .cocoa,
                        substance: "protein",
                        armed: isArmed(.pacing),
                        values: snapshot?.targets.numericsSuppressed != true
                            ? moundValues(
                                story.morningShare, story.afternoonShare, story.eveningShare
                            )
                            : nil
                    )
                    if let line = BodyLine.pacing(story: story) {
                        JKBodyLine(text: line)
                            .jkStagedReveal(armed: isArmed(.pacing), delay: 0.8)
                    }
                }
            } doors: {
                EmptyView()
            }
        }
    }

    /// The mounds' per-bar value captions ("14%") — one row, on the
    /// figure itself.
    private func moundValues(_ m: Double, _ a: Double, _ e: Double) -> [String] {
        [m, a, e].map { "\(Int(($0 * 100).rounded()))%" }
    }

    private func pacingHeadline(_ story: ProteinPacing.Story) -> (String, [String]) {
        if story.morningLeads {
            return ("your protein starts early in the day.", ["early"])
        }
        if story.eveningHeavy {
            return ("most of your protein comes at night.", ["night"])
        }
        return ("your protein is spread evenly across the day.", ["evenly"])
    }

    /// YOUR SEASON — cycle-phase appetite context (meta-analysis:
    /// ~168 kcal/day higher intake in the luteal phase while resting
    /// burn also rises). Forgiveness + planning; never prediction.
    @ViewBuilder private var seasonPage: some View {
        if let season = seasonRead {
            JKStoryPage(
                eyebrow: "your cycle",
                headline: seasonHeadline(season).0,
                headlineItalic: seasonHeadline(season).1,
                caption: seasonCaption(season)
            ) {
                VStack(spacing: Space.xl) {
                    JKSeasonBand(
                        phase: season.phase,
                        position: Double(season.dayOfCycle)
                            / Double(max(season.cycleLengthDays, 1)),
                        armed: isArmed(.season)
                    )
                    .padding(.horizontal, Space.sm)
                    if let line = BodyLine.season(phase: season.phase) {
                        JKBodyLine(text: line)
                            .jkStagedReveal(armed: isArmed(.season), delay: 0.55)
                    }
                }
            } doors: {
                EmptyView()
            }
        }
    }

    private func seasonHeadline(_ season: CycleSignal.Read) -> (String, [String]) {
        switch season.phase {
        case .luteal: return ("the hungrier week of your cycle is here.", ["hungrier"])
        case .menstrual: return ("period days. plan smaller, expect noise.", ["smaller"])
        case .follicular: return ("the easiest appetite week of your cycle.", ["easiest"])
        }
    }

    private func seasonCaption(_ season: CycleSignal.Read) -> String {
        switch season.phase {
        case .luteal:
            return "appetite and calorie burn both rise before a period. chemistry, not a failure of will \u{2665}\u{FE0E}"
        case .menstrual:
            return "appetite usually settles as your period passes \u{2665}\u{FE0E}"
        case .follicular:
            return "cravings run lowest now. a good week for the harder habits \u{2665}\u{FE0E}"
        }
    }

    /// JENI'S COACHING — the pager's closing synthesis: the whole
    /// signal week reduced to ONE next move (CoachSummary's fixed
    /// clinical priority), backed by the receipts it was picked from.
    @ViewBuilder private var summaryPage: some View {
        if let summary = coachSummary {
            JKStoryPage(
                eyebrow: "jeni's coaching",
                headline: summary.headline,
                headlineItalic: summary.italic,
                caption: summary.seasonNote
            ) {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(spacing: 0) {
                        ForEach(Array(summaryReceipt.enumerated()), id: \.offset) { idx, row in
                            if idx > 0 {
                                Rectangle()
                                    .fill(Palette.hairlineCocoa)
                                    .frame(height: 0.66)
                            }
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.0)
                                    .font(Typo.caption)
                                    .foregroundStyle(Palette.textSecondary)
                                Spacer(minLength: 12)
                                Text(row.1)
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.textPrimary)
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .jkStagedReveal(armed: isArmed(.summary), delay: 0.55)

                    JKBodyLine(text: summary.why)
                        .jkStagedReveal(armed: isArmed(.summary), delay: 0.8)
                }
            } doors: {
                JKJourneyDoor(
                    lead: "talk it",
                    punch: "through with jeni",
                    italic: ["jeni"],
                    action: { router.openChat(seed: summary.chatSeed) }
                )
            }
        }
    }

    /// The facts the pick was made from — one row per story that
    /// exists this week. Provenance-only: no story, no row.
    private var summaryReceipt: [(String, String)] {
        var rows: [(String, String)] = []
        if let week = windowWeek, let avg = week.averageHours {
            rows.append(("overnight fast", "about \(Int(avg.rounded()))h a night"))
        }
        if !sleepRecaps.isEmpty {
            let avg = sleepRecaps.map(\.hours).reduce(0, +) / Double(sleepRecaps.count)
            rows.append(("sleep", "\(SleepSignal.durationWord(avg * 3600)) a night"))
        }
        if let pacing = pacingStory {
            rows.append(("protein", "\(Int((pacing.eveningShare * 100).rounded()))% in the evening"))
        }
        if let direction = sweetStory?.direction {
            let word = switch direction {
            case .easing: "down vs last week"
            case .steady: "steady vs last week"
            case .rising: "up vs last week"
            }
            rows.append(("sugar", word))
        }
        if let rhythm = rhythmStory, rhythm.plateDayCount >= 3 {
            rows.append(("weigh-ins", "\(rhythm.weighDayCount) in two weeks"))
        }
        return rows
    }

    /// The stories, reduced to CoachSummary's input. Weigh cadence
    /// only joins once plates show real engagement — the scale is
    /// never the FIRST thing the coach asks of her.
    private func composeCoachSummary() {
        var input = CoachSummary.Input()
        input.fastAvgHours = windowWeek?.averageHours
        input.fastNights = windowWeek?.narratedCount ?? 0
        if !sleepRecaps.isEmpty {
            let hours = sleepRecaps.map(\.hours)
            input.sleepAvgHours = hours.reduce(0, +) / Double(hours.count)
            input.shortNights = hours.filter { $0 < 6 }.count
        }
        input.pacing = pacingStory
        input.sweetDirection = sweetStory?.direction
        if let rhythm = rhythmStory, rhythm.plateDayCount >= 3 {
            input.weighDays14 = rhythm.weighDayCount
        }
        input.lutealNow = seasonRead?.phase == .luteal
        coachSummary = CoachSummary.compose(input)
    }

    private func sweetHeadline(_ story: Sweetness.Story) -> (String, [String]) {
        switch story.direction {
        case .easing: return ("your sugar intake came down this week.", ["down"])
        case .rising: return ("your sugar intake went up this week.", ["up"])
        default:
            return ("your sugar shows up mostly in the \(story.dominantMoment).", [story.dominantMoment])
        }
    }

    /// NIGHTS — sleep spoken as appetite context (Tasali 2022),
    /// never as bedtime homework.
    @ViewBuilder private var sleepPage: some View {
        let hours = sleepRecaps.map(\.hours)
        let avg = hours.isEmpty ? 0 : hours.reduce(0, +) / Double(hours.count)
        let shortNights = hours.filter { $0 < 6 }.count
        JKStoryPage(
            eyebrow: "sleep",
            headline: shortNights >= 4
                ? "short nights outnumbered full ones this week."
                : "you slept about \(SleepSignal.durationWord(avg * 3600)) a night.",
            headlineItalic: shortNights >= 4 ? ["short"] : ["slept"],
            caption: "short sleep raises next-day hunger hormones. plan for hungrier days \u{2665}\u{FE0E}"
        ) {
            VStack(spacing: Space.lg) {
                JKSleepBars(nights: sleepWeekHours, armed: isArmed(.sleep))
                JKStatTriplet(items: sleepStats)
                    .jkStagedReveal(armed: isArmed(.sleep), delay: 0.55)
                if let line = BodyLine.sleep(
                    avgHours: hours.isEmpty ? nil : avg,
                    shortNights: shortNights,
                    easedDisplay: easedDeltaDisplay
                ) {
                    JKBodyLine(text: line)
                        .jkStagedReveal(armed: isArmed(.sleep), delay: 0.8)
                }
            }
        } doors: {
            EmptyView()
        }
    }

    private var sleepStats: [JKStatTriplet.Item] {
        let hours = sleepRecaps.map(\.hours)
        guard !hours.isEmpty else { return [] }
        let avg = hours.reduce(0, +) / Double(hours.count)
        let best = hours.max() ?? 0
        return [
            .init(value: SleepSignal.durationWord(avg * 3600), label: "a night"),
            .init(value: SleepSignal.durationWord(best * 3600), label: "best"),
            .init(value: "\(hours.count)", label: "nights"),
        ]
    }

    /// oldest → today, 7 slots; mornings without data stay nil.
    private var sleepWeekHours: [Double?] {
        var slots: [Double?] = Array(repeating: nil, count: 7)
        for recap in sleepRecaps where recap.daysAgo < 7 {
            slots[6 - recap.daysAgo] = recap.hours
        }
        return slots
    }

    /// RHYTHM — cadence receipts: consistency beats intensity
    /// (Zheng 2015). Never a streak, never a lapse.
    @ViewBuilder private var rhythmPage: some View {
        if let story = rhythmStory {
            JKStoryPage(
                eyebrow: "consistency",
                headline: rhythmHeadline(story).0,
                headlineItalic: rhythmHeadline(story).1,
                caption: rhythmCaption(story)
            ) {
                VStack(spacing: Space.lg) {
                    JKCadenceDots(flags: story.weighDayFlags, armed: isArmed(.rhythm))
                    JKStatTriplet(items: rhythmStats(story))
                        .jkStagedReveal(armed: isArmed(.rhythm), delay: 0.55)
                    if let line = BodyLine.rhythm(
                        weighDayCount: story.weighDayCount,
                        easedDisplay: easedDeltaDisplay
                    ) {
                        JKBodyLine(text: line)
                            .jkStagedReveal(armed: isArmed(.rhythm), delay: 0.8)
                    }
                }
            } doors: {
                EmptyView()
            }
        }
    }

    private func rhythmStats(_ story: WeekRhythm.Story) -> [JKStatTriplet.Item] {
        var items: [JKStatTriplet.Item] = [
            .init(value: "\(story.weighDayCount)", label: "weigh-ins"),
        ]
        if let median = story.firstPlateMedianMinutes {
            items.append(.init(value: clockWord(minutes: median), label: "first plate"))
        }
        items.append(.init(value: "\(story.plateDayCount)", label: "logged days"))
        return items
    }

    private func rhythmHeadline(_ story: WeekRhythm.Story) -> (String, [String]) {
        if let word = WeekRhythm.cadenceWord(weighDayCount: story.weighDayCount) {
            return ("your weigh-in cadence: \(word).", [word])
        }
        return ("you're logging on a steady schedule.", ["steady"])
    }

    private func rhythmCaption(_ story: WeekRhythm.Story) -> String {
        // The triplet + body line carry the numbers now; the caption
        // holds the register in one clean sentence.
        "consistency beats intensity. the habit is the result \u{2665}\u{FE0E}"
    }

    /// Minutes-of-day → the house clock word ("8:41pm").
    private func clockWord(minutes: Int) -> String {
        var comps = DateComponents()
        comps.hour = (minutes / 60) % 24
        comps.minute = minutes % 60
        guard let date = Calendar.current.date(from: comps) else { return "" }
        return JKWindowHorizon.clockWord(date)
    }

    /// v6.2 — the trend fact the body lines may borrow: established
    /// (3+ weigh-ins over 5+ days), genuinely eased, never under
    /// suppression. Preformatted in her display unit.
    private var easedDeltaDisplay: String? {
        guard let snapshot, !snapshot.targets.numericsSuppressed,
              let logs = week?.weightLogs, logs.count >= 3,
              let newest = logs.first?.loggedAt,
              let oldest = logs.last?.loggedAt
        else { return nil }
        let span = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: oldest),
            to: Calendar.current.startOfDay(for: newest)
        ).day ?? 0
        guard span >= 5,
              let delta = BodyLine.easedDelta(
                  established: true, emaDelta7dKg: snapshot.emaDelta7dKg
              )
        else { return nil }
        return String(
            format: "%.1f %@",
            abs(weightUnit.display(fromKg: delta)), weightUnit.label
        )
    }

    /// Page 1 — the line. The trend canvas as hero; the insight
    /// sentence as the headline.
    private var lineCaption: String? {
        if let detail = insights?.trendStory?.detail { return detail }
        if snapshot?.chapter == .keeping,
           BandModel.settleWeightKg(plan: snapshot?.plan) != nil {
            return "the tinted band is the target. keep the line inside it."
        }
        return nil
    }

    @ViewBuilder private var linePage: some View {
        let story = insights?.trendStory
        JKStoryPage(
            eyebrow: "weight",
            headline: story?.line ?? "2 weigh-ins start your trend line",
            headlineItalic: story?.italic ?? ["2 weigh-ins"],
            caption: lineCaption
        ) {
            if let week, week.weightLogs.count >= 2 {
                VStack(spacing: Space.lg) {
                    BecomingTrendCanvas(
                        logs: week.weightLogs,
                        goalWeightKg: snapshot?.plan?.goalWeightKg,
                        unit: weightUnit,
                        bandSettleKg: snapshot?.chapter == .keeping
                            ? BandModel.settleWeightKg(plan: snapshot?.plan)
                            : nil,
                        height: 190,
                        chromeless: true,
                        armed: isArmed(.line)
                    )
                    // Mission 2 (02_VISUAL.md §1.8): the stat
                    // triptych dissolved into the ledger the
                    // onboarding taught — label left, serif value
                    // right, hairlines between.
                    if let startKg = snapshot?.plan?.currentWeightKg,
                       let nowKg = week.weightLogs.first?.weightKg,
                       let goalKg = snapshot?.plan?.goalWeightKg {
                        VStack(spacing: 0) {
                            weightLedgerRow("started", weightWord(startKg), rule: false)
                            weightLedgerRow("now", weightWord(nowKg))
                            weightLedgerRow("goal", weightWord(goalKg))
                        }
                    }
                }
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
            Text("2 weigh-ins draw the line")
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
                        diameter: 164,
                        armed: isArmed(.food)
                    )
                    if let week {
                        JKProteinWeekBand(
                            days: week.last7.map { ($0.proteinG, $0.plates > 0) },
                            targetG: target
                        )
                    }
                    // v5 nutrition visibility: calorie fulfillment as
                    // a bar, then the rest of today's plate chemistry
                    // the pipeline already reads — carbs, fat, fiber
                    // (vitamins/minerals aren't in the vision
                    // contract yet; nothing invented).
                    if let snapshot, snapshot.kcalEaten > 0 {
                        if let kcalTarget = snapshot.targets.kcal {
                            JKKcalBar(
                                kcal: snapshot.kcalEaten,
                                target: kcalTarget,
                                armed: isArmed(.food)
                            )
                            .padding(.top, Space.xs)
                        }
                        HStack(spacing: 0) {
                            chemistryColumn("\(snapshot.carbsEatenG)g", "carbs")
                            chemistryColumn("\(snapshot.fatEatenG)g", "fat")
                            chemistryColumn("\(snapshot.fiberEatenG)g", "fiber")
                            // v1.1.5 — sugar joins the row when the day's
                            // plates carried it (silent otherwise, so we
                            // never show a fabricated 0g).
                            if snapshot.sugarEatenG >= 1 {
                                chemistryColumn("\(snapshot.sugarEatenG)g", "sugar")
                            }
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

    /// Today's logged plates, newest first (snapshot.plates carries the
    /// retained window; the plates page + its count are today-only).
    private var todaysPlates: [FoodLogPersister.FoodLogEntry] {
        (snapshot?.plates ?? [])
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    /// Page — today's plates, moved off Home. The day's photos as a fan
    /// of polaroids; tapping one opens its detail, the door opens the
    /// full archive.
    @ViewBuilder private var platesPage: some View {
        let plates = todaysPlates
        let cards = plates.map { entry in
            JKPlatesGallery.Plate(
                id: entry.id,
                time: entry.loggedAt.formatted(date: .omitted, time: .shortened).lowercased(),
                title: entry.title.isEmpty ? "a plate" : entry.title,
                kcal: Int(entry.kcal.rounded()),
                image: FoodPhotoStore.photo(entryId: entry.id)
            )
        }
        JKStoryPage(
            eyebrow: "today's plates",
            headline: cards.count == 1 ? "one plate, kept." : "\(cards.count) plates, kept.",
            headlineItalic: ["kept."],
            caption: cards.count > 3
                ? "the newest three · open her plates for all \(cards.count)"
                : "tap a plate to read it."
        ) {
            JKPlatesGallery(
                plates: cards,
                armed: isArmed(.plates),
                onTap: { id in detailPlate = plates.first { $0.id == id } },
                onSnap: { router.open(.snap) }
            )
        } doors: {
            JKJourneyDoor(
                lead: "open",
                punch: "her plates",
                italic: ["plates"],
                action: { showJournal = true }
            )
        }
    }

    private func weightWord(_ kg: Double) -> String {
        String(format: "%.1f %@", weightUnit.display(fromKg: kg), weightUnit.label)
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
        // The kcal bar above owns today's calorie sentence — the
        // caption only speaks when the bar can't render.
        if snapshot.kcalEaten > 0, snapshot.targets.kcal != nil {
            return nil
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
                    ? "benefits start near 4,000 steps. \(goal.formatted()) is the target."
                    : "auto-tracked, no logging."
            }()
        ) {
            if StepsService.shared.authStatus == .authorized {
                JKStepsBarChart(
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
                case .steady: return "inside your band this week."
                case .drifting: return "a steadying week: trend is 3-5 lb over."
                case .reset: return "reset arc: working back inside."
                }
            }(),
            headlineItalic: [zone == .steady ? "inside" : (zone == .drifting ? "steadying" : "reset")],
            caption: "your band: about 3 lb around your settle weight."
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
                Text("days you showed up. not a streak.")
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
        let line = card?.line ?? snapshot?.brief.line ?? "today's note, from your data."
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

        // v6 — the passive-signal stories. Pure reads over stores the
        // app already holds; each carries its own cohort gates and
        // data floors, so a nil here simply means "that page doesn't
        // exist this week."
        windowWeek = KitchenSignal.liveWeekStory(userId: userId)
        sweetStory = Sweetness.liveStory(userId: userId)
        rhythmStory = WeekRhythm.story(
            weighDates: wk.weightLogs.map(\.loggedAt),
            plateTimes: FoodLogPersister.allEntries(userId: userId).map(\.loggedAt)
        )
        pacingStory = ProteinPacing.liveStory(userId: userId)
        seasonRead = CohortStore.isPerimenopausal
            ? nil
            : CycleSignal.read(periodStarts: CycleService.shared.periodStarts)

        var liveHealthReads = true
        #if DEBUG
        // The forced samples below must not be clobbered by async
        // HealthKit reads landing after them.
        liveHealthReads = !ProcessInfo.processInfo.arguments
            .contains("--uitest-force-signals")
        #endif
        if liveHealthReads {
            Task {
                sleepRecaps = await SleepService.shared.nightHistory()
                await CycleService.shared.bootstrap()
                if !CohortStore.isPerimenopausal {
                    seasonRead = CycleSignal.read(
                        periodStarts: CycleService.shared.periodStarts
                    )
                }
                // Sleep + season may change the coach's pick.
                composeCoachSummary()
            }
        }

        #if DEBUG
        // QA determinism for the signal pages:
        //   --uitest-force-signals
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-signals") {
            windowWeek = WindowSheet.sampleWeek()
            sweetStory = Sweetness.Story(
                dayGrams: [18, 24, nil, 31, 22, 27, 24],
                sugarDayCount: 6, averageG: 24,
                morningShare: 0.18, afternoonShare: 0.30, eveningShare: 0.52,
                direction: .easing
            )
            rhythmStory = WeekRhythm.Story(
                weighDayCount: 5,
                weighDayFlags: [true, false, false, true, false, false, true,
                                false, true, false, false, false, false, true],
                plateDayCount: 6,
                firstPlateMedianMinutes: 9 * 60 + 15
            )
            let sampleNights: [Double] = [6.2, 7.4, 5.8, 0, 7.1, 6.7, 8.0]
            sleepRecaps = sampleNights.enumerated().compactMap { idx, h in
                h > 0 ? SleepService.NightRecap(daysAgo: idx, asleepDuration: h * 3600) : nil
            }
            pacingStory = ProteinPacing.Story(
                morningShare: 0.14, afternoonShare: 0.28, eveningShare: 0.58,
                proteinDayCount: 6
            )
            seasonRead = CycleSignal.Read(
                phase: .luteal, dayOfCycle: 22, cycleLengthDays: 28
            )
        }
        #endif

        // v6.5 — the coach's one move, composed from whatever stories
        // exist right now (recomposed when async health reads land).
        composeCoachSummary()

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

// MARK: - JKCarouselOffsetKey (v7.1 carousel — geometry truth)

/// Realized carousel pages report their leading-edge offset in the
/// carousel's space; the smallest magnitude is the page on stage.
struct JKCarouselOffsetKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}
