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
    /// Mission 2.1 (founder: "carousel type of full screen report" +
    /// the no-scroll law): becoming IS the issue — THE COVER as the
    /// non-scrolling first page, the spreads behind it, nothing
    /// vertical. One page enum covers both.
    private enum IssuePage: Hashable, Identifiable {
        case cover
        case story(StoryPage)
        var id: Int {
            switch self {
            case .cover: return -1
            case .story(let s): return s.rawValue
            }
        }
    }

    @State private var carouselPage: IssuePage = .cover
    /// v10.1 — the journal's push stack (chapters open as pages).
    @State private var journalPath: [StoryPage] = []
    /// The issue's page set, frozen per refresh (stories load
    /// async; the set never shifts under her mid-browse).
    @State private var issuePages: [IssuePage] = [.cover]
    /// A programmatic jump request (fore-edge tap, QA hook) consumed
    /// where the scroll proxy lives.
    @State private var pendingJump: IssuePage?

    // v6 — the passive-signal stories (docs/app_v6/00_RESEARCH.md).
    @State private var windowWeek: KitchenSignal.WeekStory?
    @State private var sweetStory: Sweetness.Story?
    /// v6.5 — the coach's one-move synthesis over the signal week.
    @State private var coachSummary: CoachSummary.Output?
    /// v9 P3 — the unified weekly read (outcome → mechanisms →
    /// preservation → the move); coachSummary stays its move half.
    @State private var bodyReview: WeeklyBodyReview.Read?
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
    // v9 P2 — Body Vision's page state (loaded in refresh; photo IO
    // stays out of body).
    @State private var bodyScans: [BodyScanRecord] = []
    @State private var bodyChangeLine: String?
    @State private var bodyFace: UIImage?
    @State private var showBodyTimeline = false
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
        // v8 S3 — the visit-prep packet's page (the record's home).
        case visitPrep
        // v9 P2 — Body Vision's page (appended; raw ids stay stable).
        case body
        var id: Int { rawValue }
    }

    private var storyPages: [StoryPage] {
        var pages: [StoryPage] = [.line, .food]
        // v10 (V4/V7): when the landing leads with her figure, a
        // separate body page would duplicate it — the record's door
        // lives on the landing. The page survives only for the
        // opted-out path (her figure stays one swipe away).
        if !bodyScans.isEmpty, !landingFigure {
            pages.insert(.body, at: 1)
        }
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
        // v8 S3 — always present: an empty packet explains itself.
        pages.append(.visitPrep)
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

    /// The page on stage draws in on arrival and re-arms as she
    /// swipes — the liveliness the founder loved about the pager.
    private func isArmed(_ page: StoryPage) -> Bool {
        // v10.1: the push path is the authoritative on-stage truth —
        // appear/disappear timing through a navigation transition
        // proved unreliable (the trend trace-in froze un-armed).
        journalPath.last == page || carouselPage == .story(page)
    }

    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    /// v10 (V7): the landing leads with her figure once a record
    /// exists — the journal opens on her. Default ON (the brief:
    /// her body is the hero); the record sheet keeps the one-tap
    /// door off, and the old body page returns for that choice.
    @AppStorage("bodyScan.landingFigure") private var landingFigure = true

    private var userId: String { auth.currentUser?.id.uuidString ?? "" }

    var body: some View {
        // v10.1 (01_REINVENTION §2c): becoming IS the journal — the
        // cover spread, her record, the chapters as contents; each
        // chapter opens as its own page. The masthead lives inside
        // the stack so a pushed chapter owns the whole page (one
        // kicker, no double running head).
        JKScreenChrome {
            Group {
                if snapshot?.isEnrolled == false {
                    VStack(alignment: .leading, spacing: 0) {
                        mastheadBlock
                        JKEmptyState(
                            line: "your story starts on day one",
                            italic: ["day one"],
                            actionLabel: "open today",
                            action: { router.tab = .today }
                        )
                        .padding(.top, Space.xl)
                        Spacer(minLength: 0)
                    }
                } else {
                    journal
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
                // 2.4s: past the refresh so the frozen issue includes
                // the data-gated stories.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    let stories = storyPages
                    let clamped = min(max(0, page), stories.count - 1)
                    pendingJump = .story(stories[clamped])
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
        .onReceive(NotificationCenter.default.publisher(for: BodyScanStore.didChange)) { _ in
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

    /// The masthead with its mounted sheets + QA door — one block
    /// both the journal root and the empty state share.
    private var mastheadBlock: some View {
        masthead
            // v8 S3 — the packet sheet mounts here (the masthead is
            // always mounted; the page's door only flips the flag)
            // + the QA capture door.
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("--uitest-open-visit-packet") {
                    showVisitPacket = true
                }
            }
            .sheet(isPresented: $showBodyTimeline) {
                BodyTimelineView(
                    userId: userId,
                    onClose: { showBodyTimeline = false },
                    changeLine: bodyChangeLine
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bgPrimary)
                .onDisappear { refresh() }   // cover door may have flipped
            }
            .sheet(isPresented: $showVisitPacket) {
                VisitPacketView(userId: userId, onClose: { showVisitPacket = false })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Palette.bgPrimary)
                    // v8 S4 — opening her packet re-publishes it to
                    // any connected clinic that holds the packet
                    // scope (RLS enforces the rest).
                    .task {
                        await VisitPacketPublisher.publishIfConnected(
                            userId: userId, in: modelContext
                        )
                    }
            }
            .padding(.top, Space.hero)
    }

    private var masthead: some View {
        // Mission 3 (03_EDITORIAL.md §4): the fixed running head —
        // the wordmark + ONE caps line whose content turns with the
        // page (the arc line on the cover, the spread's kicker
        // inside). The hamburger died with Home's chrome; the
        // wordmark itself is the door (tap = back to the cover,
        // long-press = settings — the dateline grammar).
        JKMasthead(
            lead: .title("becoming", italic: ["becoming"]),
            eyebrow: runningHeadLine,
            marks: []
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard carouselPage != .cover else { return }
            Haptics.soft()
            pendingJump = .cover
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            Haptics.soft()
            showProfileHub = true
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("returns to the cover")
        .accessibilityAction(named: "settings") { showProfileHub = true }
    }

    /// The running head's one caps line: position on the cover, the
    /// page's own kicker on a spread (one caps event per screen).
    private var runningHeadLine: String? {
        switch carouselPage {
        case .cover: return arcEyebrow
        case .story(let page): return indexKicker(for: page)
        }
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

    // MARK: - v10.1: THE JOURNAL (01_REINVENTION §2c; the carousel
    // retired — V9)

    /// Becoming reads like a journal now: the cover spread, then
    /// HER RECORD (the scans, week by week), then the chapters as
    /// an editorial table of contents. Each chapter opens as its
    /// own page (a push); the shipped page views render unchanged.
    private var journal: some View {
        NavigationStack(path: $journalPath) {
            VStack(alignment: .leading, spacing: 0) {
                mastheadBlock
                    .jkBeat1()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        coverPage
                            .frame(height: coverSpreadHeight)

                        if !bodyScans.isEmpty {
                            recordStrip
                                .padding(.top, Space.lg)
                        }

                        contentsBlock
                            .padding(.top, Space.xl)

                        Spacer(minLength: 96)
                    }
                }
                .jkBeat2()
            }
            .navigationDestination(for: StoryPage.self) { page in
                journalChapter(page)
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(Palette.bgPrimary.ignoresSafeArea())
        }
        // The stack paints system background otherwise — one paper.
        .background(Palette.bgPrimary.ignoresSafeArea())
        .onChange(of: pendingJump) { _, jump in
            guard let jump else { return }
            pendingJump = nil
            switch jump {
            case .cover:
                journalPath = []
            case .story(let s):
                journalPath = [s]
            }
        }
    }

    /// The cover fills the first viewport under the masthead — the
    /// journal opens on her; the record strip peeks beneath.
    private var coverSpreadHeight: CGFloat {
        UIScreen.main.bounds.height * 0.60
    }

    /// HER RECORD — the scans as plates in the book, oldest to
    /// newest; the room (the compare) is one tap away.
    private var recordStrip: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("YOUR RECORD")
                .font(Typo.kicker)
                .kerning(2.0)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.horizontal, Space.lg)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(Array(bodyScans.reversed()), id: \.id) { scan in
                        if let face = BodyScanPhotoStore.image(
                            scanId: scan.id, preferring: scan.renderMode
                        ) {
                            BodyMat(image: face)
                                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                .frame(height: 96)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, 4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.soft()
                showBodyTimeline = true
            }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("your record, \(bodyScans.count) scans")
            .accessibilityHint("opens the compare")
        }
    }

    /// THE CONTENTS — every chapter the week has earned, one quiet
    /// row each: the kicker names the chapter, the line speaks its
    /// current read. Structure is information (the journal's TOC).
    private var contentsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THE CHAPTERS")
                .font(Typo.kicker)
                .kerning(2.0)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.horizontal, Space.lg)
                .padding(.bottom, 6)
            ForEach(storyPages, id: \.self) { page in
                NavigationLink(value: page) {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(Palette.hairlineCocoa)
                            .frame(height: 0.5)
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(indexKicker(for: page).uppercased())
                                    .font(Typo.statLabel)
                                    .kerning(0.9)
                                    .foregroundStyle(Palette.cocoaTertiary)
                                Text(indexLine(for: page))
                                    .font(.custom("JeniHeroSerif-Regular", size: 20, relativeTo: .title3))
                                    .kerning(-0.3)
                                    .foregroundStyle(Palette.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 10)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Palette.cocoaTertiary.opacity(0.7))
                        }
                        .padding(.vertical, 13)
                    }
                    .padding(.horizontal, Space.lg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
                .accessibilityLabel("\(indexKicker(for: page)). \(indexLine(for: page))")
            }
        }
    }

    /// A chapter, opened: a quiet top bar (back + the kicker), then
    /// the shipped page view unchanged; accessibility sizes scroll.
    private func journalChapter(_ page: StoryPage) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    Haptics.soft()
                    journalPath = []
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Palette.bgElevated.opacity(0.9)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("back to the journal")
                Text(indexKicker(for: page).uppercased())
                    .font(Typo.kicker)
                    .kerning(2.0)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer()
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.sm)

            ScrollView {
                storyPage(page)
                    .frame(width: UIScreen.main.bounds.width)
                    .containerRelativeFrame(.vertical) { length, _ in
                        length
                    }
            }
            .scrollIndicators(.hidden)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    /// THE COVER — the issue's first page, composed to fit ONE
    /// screen, never scrolling. Mission 3 (03_EDITORIAL.md §4): the
    /// cover earns cover art — her most recent plate photograph of
    /// the week runs full-bleed through the top, un-beautified (the
    /// crafted object carries the story), cream rises from its foot,
    /// and the thesis lands on the lower cream. Photo-less weeks
    /// keep the type poster.
    @ViewBuilder
    private var coverPage: some View {
        if landingFigure, let face = bodyFace {
            recordCover(face)
        } else if let art = coverArt {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: art)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height * 0.56)
                        .clipped()
                        .overlay(alignment: .bottom) {
                            LinearGradient(
                                colors: [Palette.bgPrimary.opacity(0), Palette.bgPrimary],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 120)
                        }
                        .frame(
                            width: geo.size.width, height: geo.size.height,
                            alignment: .top
                        )
                        .accessibilityHidden(true)

                    coverReadBlock
                        .padding(.horizontal, Space.lg)
                        .padding(.bottom, Space.xl)
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            coverTypePoster
        }
    }

    /// v10 (V4): THE RECORD COVER — when a record exists, opening
    /// the journal means seeing yourself: her figure matted at the
    /// top (the mirror's face — silhouette or photo, her standing
    /// choice), the weekly read beneath. Tap the mat = the record.
    /// The old separate body page retired into this landing.
    private func recordCover(_ face: UIImage) -> some View {
        // One-screen composition; large type scrolls as overflow so
        // the read is never squeezed into truncation.
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        Haptics.soft()
                        showBodyTimeline = true
                    } label: {
                        BodyMat(image: face)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .frame(height: min(geo.size.height * 0.46, 360))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(JKPress())
                    .accessibilityLabel(
                        "your latest scan" + (bodyChangeLine.map { ". \($0)" } ?? "")
                    )
                    .accessibilityHint("opens your record")

                    Spacer(minLength: Space.md)

                    coverReadBlock
                        .padding(.bottom, Space.lg)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
    }

    /// Her most recent plate photograph from the trailing week —
    /// loaded once per refresh (photo IO stays out of body).
    @State private var coverArt: UIImage?

    private func loadCoverArt() {
        // v10 (V7): the landing-figure default replaced the D2-era
        // full-bleed silhouette cover; plate art remains the cover
        // for zero-scan weeks and the opted-out path.
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        coverArt = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= weekAgo }
            .sorted { $0.loggedAt > $1.loggedAt }
            .lazy
            .compactMap { FoodPhotoStore.photo(entryId: $0.id) }
            .first
    }

    /// v9 P3 — the preservation caption (state + inline evidence;
    /// the chip form lives with the full read later, the cover
    /// carries the fact).
    private func preservationCoverLine(_ p: WeeklyBodyReview.Preservation) -> String {
        p.citation.map { "\(p.line) · \($0)" } ?? p.line
    }

    private func preservationTint(_ state: WeeklyBodyReview.Preservation.State) -> Color {
        switch state {
        case .protected: return Palette.stateGood
        case .watch: return Palette.cocoaSecondary
        case .atRisk: return Palette.accent
        case .unknown: return Palette.cocoaTertiary
        }
    }

    /// The photo-less cover — the type poster (the pre-art layout,
    /// unchanged).
    private var coverTypePoster: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverReadBlock
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .accessibilityElement(children: .combine)
    }

    /// The cover's words — shared by the art cover (lower cream) and
    /// the type poster (top-led). v9 P3: the unified weekly read
    /// leads with the body OUTCOME, lays the mechanisms beside it,
    /// speaks preservation, then hands to the one move — one
    /// narrative spine, two engines underneath.
    private var coverReadBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let review = bodyReview {
                ItalicAccentText(
                    review.outcome,
                    italic: review.outcomeItalic,
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .kerning(-0.4)
                .lineLimit(4)
                .minimumScaleFactor(0.75)

                if !review.mechanisms.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(review.mechanisms, id: \.self) { line in
                            Text(line)
                                .font(.custom("DMSans-Regular", size: 14, relativeTo: .footnote))
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                }

                if let p = review.preservation, p.state != .unknown {
                    Text(preservationCoverLine(p))
                        .font(Typo.caption)
                        .foregroundStyle(preservationTint(p.state))
                        .lineLimit(2)
                }
                if review.preservation?.connectDoor == true {
                    Button {
                        Haptics.light()
                        Task {
                            await MovementService.shared.requestAccess()
                            refresh()
                        }
                    } label: {
                        Text("connect workouts — the muscle read needs them")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }

                if let move = review.move {
                    ItalicAccentText(
                        move.headline,
                        italic: move.italic,
                        baseFont: .custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 21, relativeTo: .title3),
                        color: Palette.cocoaPrimary,
                        alignment: .leading
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 2)

                    if let season = move.seasonNote {
                        Text(season)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.jeweledRose)
                            .lineLimit(3)
                    }

                    Button {
                        Haptics.soft()
                        router.openChat(seed: move.chatSeed)
                    } label: {
                        HStack(spacing: 5) {
                            Text("talk it through")
                                .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .callout))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Palette.cocoaSecondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(JKPress())
                    .padding(.top, 2)
                }
            } else if let read = coachSummary {
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
                .lineLimit(5)
                .minimumScaleFactor(0.75)

                Text(read.why)
                    .font(.custom("DMSans-Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(4)

                if let season = read.seasonNote {
                    Text(season)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.jeweledRose)
                        .lineLimit(3)
                }

                Button {
                    Haptics.soft()
                    router.openChat(seed: read.chatSeed)
                } label: {
                    HStack(spacing: 5) {
                        Text("talk it through")
                            .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .callout))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Palette.cocoaSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
                .padding(.top, 2)
            } else {
                ItalicAccentText(
                    indexLine(for: .line),
                    italic: [],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .kerning(-0.4)
                .lineLimit(4)
                .minimumScaleFactor(0.75)
            }
        }
    }

    /// Each story's section name (the fore-edge leaves speak them to
    /// VoiceOver) and its one-line current read (the cover fallback)
    /// — the same generators the full pages use.
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
        case .visitPrep: return "for your next visit"
        case .body: return "your body"
        }
    }

    private func indexLine(for page: StoryPage) -> String {
        switch page {
        case .line:
            return insights?.trendStory?.line ?? "2 weigh-ins start your trend line"
        case .body:
            return bodyChangeLine ?? indexKicker(for: page)
        default:
            return indexKicker(for: page)
        }
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

    // MARK: - The story pages

    @ViewBuilder
    private func storyPage(_ page: StoryPage) -> some View {
        switch page {
        case .line: linePage
        case .body: bodyPage
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
        case .visitPrep: visitPrepPage
        }
    }

    // MARK: - v8 S3: the visit-prep page (clinical register — the
    // one quiet spread; the packet itself opens as a sheet).

    @State private var showVisitPacket = false

    @ViewBuilder private var visitPrepPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("FOR YOUR NEXT VISIT")
                .font(Typo.caption)
                .kerning(1.6)
                .foregroundStyle(Palette.cocoaTertiary)
            Text("four weeks,\non one page.")
                .font(.custom("JeniHeroSerif-Regular", size: 33, relativeTo: .largeTitle))
                .foregroundStyle(Palette.textPrimary)
                .lineSpacing(-2)
                .padding(.top, 8)
            Text("what you recorded, what changed, and the questions worth bringing — from your own records, nothing invented.")
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            Button {
                Haptics.light()
                showVisitPacket = true
            } label: {
                VStack(spacing: 0) {
                    HStack {
                        Text("open your packet")
                            .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .accessibilityLabel("open your visit packet")
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Space.xl)
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
                headline: windowWeekHeadline(weekStory).0,
                headlineItalic: windowWeekHeadline(weekStory).1,
                caption: "a steady 12 to 14 hour overnight fast trims intake and stores less. gentle beats forced, always"
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
                headline: hours >= 12
                    ? "your overnight fast ran about \(Int(hours.rounded())) hours last night, without trying."
                    : "you fasted about \(Int(hours.rounded())) hours last night.",
                headlineItalic: ["fasted"],
                caption: "a steady 12 to 14 hour overnight fast supports the loss. a pattern, not a rule"
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
            return ("your overnight fasts are running long. make sure you're eating enough.", ["enough"])
        }
        if let median = story.medianCloseMinutes,
           let spread = story.closeSpreadMinutes, spread <= 90 {
            return ("your fast starts near \(clockWord(minutes: median)) most nights.", ["starts"])
        }
        if let avg = story.averageHours {
            return ("your overnight fast averaged \(Int(avg.rounded())) hours a night this week.", ["averaged"])
        }
        return ("your overnight fast varies night to night.", ["varies"])
    }

    // MARK: v6 — the passive-signal pages

    /// SWEETNESS — when sugar lands and which way it's moving.
    /// Observation only: no verdicts, no gram budget, no red.
    @ViewBuilder private var sweetnessPage: some View {
        if let story = sweetStory {
            JKStoryPage(
                headline: sweetHeadline(story).0,
                headlineItalic: sweetHeadline(story).1,
                caption: "no food is banned here. sugar is just the easiest place to trim"
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
            return "appetite and energy use both rise before a period. chemistry, not a failure of will"
        case .menstrual:
            return "appetite usually settles as your period passes"
        case .follicular:
            return "cravings run lowest now. a good week for the harder habits"
        }
    }

    /// JENI'S COACHING — the pager's closing synthesis: the whole
    /// signal week reduced to ONE next move (CoachSummary's fixed
    /// clinical priority), backed by the receipts it was picked from.
    @ViewBuilder private var summaryPage: some View {
        if let summary = coachSummary {
            JKStoryPage(
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
        composeWeeklyBodyReview()
    }

    /// v9 P3 — every field traces to a collected store; the engine's
    /// tests pin the floors (the provenance audit).
    private func composeWeeklyBodyReview() {
        var input = WeeklyBodyReview.Input()
        input.trendLine = insights?.trendStory?.line
        input.trendItalic = insights?.trendStory?.italic ?? []
        input.trendDeltaKg = snapshot?.emaDelta7dKg
        input.trendEstablished = snapshot?.trendIsEstablished ?? false
        input.scans = bodyScans.map {
            .init(capturedAt: $0.capturedAt, poseQuality: $0.poseQuality)
        }
        // Trailing-7 protein presence (the TodayStateService math).
        if let target = snapshot?.targets.proteinG {
            let todayStart = Calendar.current.startOfDay(for: .now)
            let weekStart = Calendar.current.date(
                byAdding: .day, value: -6, to: todayStart) ?? todayStart
            var proteinByDay: [String: Double] = [:]
            for entry in FoodLogPersister.allEntries(userId: userId)
            where entry.loggedAt >= weekStart {
                proteinByDay[
                    TodayStateService.dayKey(for: entry.loggedAt), default: 0
                ] += entry.protein
            }
            input.loggedDays7 = proteinByDay.count
            input.proteinDaysMet7 = proteinByDay.values
                .filter { $0 >= Double(target) }.count
        }
        input.strengthSessions7 = MovementService.shared.everRequested
            ? MovementService.shared.strengthSessionsLast7 : nil
        let activeDays = StepsService.shared.weeklyCounts.filter { $0 > 0 }.count
        input.stepsActiveDays7 = activeDays > 0 ? activeDays : nil
        input.sleepNightsCounted = sleepRecaps.count
        input.shortNights7 = sleepRecaps.map(\.hours).filter { $0 < 6 }.count
        input.fastAvgHours = windowWeek?.averageHours
        input.fastNights = windowWeek?.narratedCount ?? 0
        input.sweetDirection = sweetStory?.direction
        if RegimenService.activeMedicationPlan(userId: userId, in: modelContext) != nil {
            input.doseScheduled7 = 1
            input.doseTaken7 = ObservationStore.countMatching(
                .doseTaken, values: ["yes"], lastDays: 7,
                userId: userId, in: modelContext
            )
        }
        input.hrvLatest = VitalsService.shared.read.hrv7d
        input.hrvBaseline = VitalsService.shared.read.hrvBaseline
        input.lossRatePctPerWeek = BodyStateService
            .current(userId: userId, in: modelContext).weight?.weeklyLossRate
        if let lean = VitalsService.shared.read.leanMassKg {
            input.leanLine = "your scale reads \(weightWord(lean)) lean"
        }
        input.move = coachSummary
        bodyReview = WeeklyBodyReview.compose(input)
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
            headline: shortNights >= 4
                ? "short nights outnumbered full ones this week."
                : "you slept about \(SleepSignal.durationWord(avg * 3600)) a night.",
            headlineItalic: shortNights >= 4 ? ["short"] : ["slept"],
            caption: "short sleep raises next-day hunger hormones. plan for hungrier days"
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
        "consistency beats intensity. the habit is the result"
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
        var parts: [String] = []
        if let detail = insights?.trendStory?.detail {
            parts.append(detail)
        } else if snapshot?.chapter == .keeping,
                  BandModel.settleWeightKg(plan: snapshot?.plan) != nil {
            parts.append("the tinted band is the target. keep the line inside it.")
        }
        // 04_CLINICAL_CHECKLIST §4 #5 — body composition from her
        // own scale, passively (the muscle-preservation stream).
        // Provenance caption only: displayed, never interpreted.
        let vitals = VitalsService.shared.read
        if let fat = vitals.bodyFatPct, let lean = vitals.leanMassKg {
            parts.append(String(
                format: "your scale reads %.1f%% body fat · %@ lean",
                fat, weightWord(lean)
            ))
        } else if let lean = vitals.leanMassKg {
            parts.append("your scale reads \(weightWord(lean)) lean mass")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// v9 P2 — THE BODY PAGE: the mirror's evidence beside the
    /// scale's. Her latest scan matted, the floor-gated change line
    /// as the headline, and the whole page opens her record (the
    /// timeline + compare). No number here ever came from a photo.
    @ViewBuilder private var bodyPage: some View {
        JKStoryPage(
            headline: bodyChangeLine ?? "your record, kept.",
            headlineItalic: [],
            caption: nil
        ) {
            if let face = bodyFace {
                Button {
                    Haptics.soft()
                    showBodyTimeline = true
                } label: {
                    Image(uiImage: face)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Palette.bgElevated)
                                .shadow(color: Palette.cocoaPrimary.opacity(0.07),
                                        radius: 18, x: 0, y: 6)
                        )
                        .opacity(isArmed(.body) ? 1 : 0)
                        .animation(Motion.entrance, value: isArmed(.body))
                }
                .buttonStyle(JKPress())
                .accessibilityLabel("your latest scan")
                .accessibilityHint("opens your record")
            }
        } doors: {
            Button {
                Haptics.soft()
                showBodyTimeline = true
            } label: {
                HStack(spacing: 6) {
                    Text("open your record")
                        .font(Typo.caption)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Palette.cocoaSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityHint("the timeline and the compare")
        }
    }

    @ViewBuilder private var linePage: some View {
        let story = insights?.trendStory
        JKStoryPage(
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
                    punch: "weigh in",
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

    /// v9 P5 — the weekly food-quality read (bands, never a score);
    /// composed once per refresh from the plates the week holds.
    private var foodWeekRead: FoodWeekRead.Read? {
        guard !(snapshot?.targets.numericsSuppressed ?? false) else { return nil }
        return FoodWeekRead.compose(
            plates: FoodLogPersister.allEntries(userId: userId).map {
                .init(loggedAt: $0.loggedAt, kcal: $0.kcal, protein: $0.protein)
            },
            proteinTargetG: snapshot?.targets.proteinG
        )
    }

    private var foodHeadline: String {
        let suppressed = snapshot?.targets.numericsSuppressed ?? false
        // v9 P5 — the band leads when its floors pass (≥4 logged
        // days); the older per-fact lines remain the sparse-week
        // fallback.
        if let read = foodWeekRead { return read.line }
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
        if let read = foodWeekRead { return read.italic }
        return foodHeadline.contains("protein") ? ["protein"]
            : (foodHeadline.contains("starts") ? ["starts"] : ["plates"])
    }

    private var foodCaption: String? {
        guard let snapshot else { return nil }
        if snapshot.targets.numericsSuppressed {
            return "protein is what matters today"
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
            Text("first morning, logged")
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
            ? "today's rep, kept"
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


    #if DEBUG
    /// QA fixture (rehomed from the retired WindowSheet): eight
    /// staged nights so the window pages render deterministically
    /// under --uitest-force-signals.
    private static func sampleWindowWeek() -> KitchenSignal.WeekStory? {
        var plates: [Date] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let closes: [Double] = [20.5, 21.25, 19.9, 22.0, 20.75, 21.5, 20.25, 20.6]
        let opens: [Double] = [8.5, 9.25, 8.0, 10.5, 9.0, 9.75, 8.25, 9.1]
        for d in 0...7 {
            guard let day = cal.date(byAdding: .day, value: -d, to: today) else { continue }
            plates.append(day.addingTimeInterval(opens[d] * 3600))
            plates.append(day.addingTimeInterval(closes[d] * 3600))
        }
        return KitchenSignal.weekStory(plateTimes: plates)
    }
    #endif

    private func refresh() {
        guard !userId.isEmpty else { return }
        let snap = TodayStateService.snapshot(userId: userId, in: modelContext)
        let wk = WeekState.load(userId: userId, in: modelContext)
        snapshot = snap
        week = wk
        // v9 P2 — the body page's reads (records + one image fetch,
        // out of body; the change line runs the L3 floors).
        bodyScans = BodyScanStore.all(userId: userId, in: modelContext)
        bodyFace = bodyScans.first.flatMap {
            BodyScanPhotoStore.image(scanId: $0.id, preferring: $0.renderMode)
        }
        bodyChangeLine = BodyChangeRead.line(
            scans: bodyScans.map {
                .init(capturedAt: $0.capturedAt, poseQuality: $0.poseQuality)
            },
            trendEstablished: snap.trendIsEstablished,
            trendDeltaKg: snap.emaDelta7dKg
        )
        loadCoverArt()
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
                // Late-landing health reads may add pages; re-freeze
                // (the guard keeps her place valid).
                issuePages = [.cover] + storyPages.map(IssuePage.story)
                if !issuePages.contains(carouselPage) { carouselPage = .cover }
            }
        }

        #if DEBUG
        // QA determinism for the signal pages:
        //   --uitest-force-signals
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-signals") {
            windowWeek = Self.sampleWindowWeek()
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

        // Mission 2.1 — freeze the issue for this browse: the page
        // set updates on refresh (tab arrival / scene active), never
        // mid-swipe under her thumb.
        issuePages = [.cover] + storyPages.map(IssuePage.story)
        if !issuePages.contains(carouselPage) { carouselPage = .cover }

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

