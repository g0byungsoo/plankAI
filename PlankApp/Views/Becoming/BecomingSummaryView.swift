import SwiftUI
import SwiftData
import PlankFood
import PlankSync
import Auth

// MARK: - BecomingSummaryView (v11 T4 — BECOMING, chart-driven)
//
// docs/app_v11/00_REBIRTH.md §7: Apple Fitness Summary's information
// architecture in paper and ink. Becoming answers "am I changing?"
// and "why?" — the hero body read leads, eight provenance-backed
// tiles carry live sparks, BODY PROGRESS holds the plates and the
// compare scrub, and the care doors stay reachable.
//
// The journal (cover → chapters → page-turn) died with this file's
// arrival; the compare physics survives inside BodyTimelineView.

struct BecomingSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService.shared

    @State private var snapshot: TodaySnapshot?
    @State private var bodyScans: [BodyScanRecord] = []
    @State private var review: WeeklyBodyReview.Read?
    @State private var sleepRecaps: [SleepService.NightRecap] = []
    @State private var tiles: [BecomingTile] = []
    @State private var firstPlate: UIImage?
    @State private var latestPlate: UIImage?

    /// v11.5 — the expansion: a tile morphs in-tree into its page
    /// (matched geometry inside ONE view tree; iOS 17-true).
    @State private var expandedTile: BecomingTile?
    @State private var expandDrag: CGFloat = 0
    /// The chart waits for the morph to land. Drawing a 54-step phase
    /// into a Canvas that is being resized every frame is the visible
    /// jank behind "the chart flickers".
    @State private var contentReady = false
    @Namespace private var tileNS
    @State private var showCompare = false
    @State private var showCheckIn = false
    @State private var showVisitPacket = false
    // v4's re-signing (the weekly consented adaptation) — the engine
    // (JourneyModel) survived the journal; the doors live here now.
    @State private var dueReview: JourneyModel.DueReview?
    @State private var presentedReview: JourneyModel.DueReview?
    @State private var autoOfferedReviewWeek: Int? = nil
    @State private var router = AppRouter.shared

    @State private var arrived = false

    private var userId: String {
        auth.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        ZStack {
        ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // The page title block (JeniPage's grammar, composed
                // locally so refresh() can own the arrival flag).
                VStack(alignment: .leading, spacing: 6) {
                    Text("becoming")
                        .font(Typo.questionHero)
                        .foregroundStyle(Palette.textPrimary)
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).lowercased())
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }
                .jeniArrive(arrived, index: 0)
                .padding(.top, Space.hero)
                .accessibilityAddTraits(.isHeader)

                heroCard
                    .padding(.top, Space.sectionGap)
                    .jeniArrive(arrived, index: 1)

                tileGrid
                    .padding(.top, Space.blockGap)
                    .jeniArrive(arrived, index: 2)

                bodyProgress
                    .jeniArrive(arrived, index: 3)

                careSection
                    .jeniArrive(arrived, index: 4)

                Spacer(minLength: 120)
                    .id("becoming.bottom")
            }
            .padding(.horizontal, Space.gutter)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .environment(\.jeniArrived, arrived)
        .refreshable { refresh() }
        .onAppear {
            #if DEBUG
            // QA: capture the lower half (simctl can't scroll) — the
            // today-bottom pattern, mirrored.
            if ProcessInfo.processInfo.arguments.contains("--uitest-becoming-bottom") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(nil) {
                        proxy.scrollTo("becoming.bottom", anchor: .bottom)
                    }
                }
            }
            #endif
        }
        .task {
            refresh()
            sleepRecaps = await SleepService.shared.nightHistory()
            composeReview()
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
            arrived = true
        }
        .onReceive(NotificationCenter.default.publisher(for: BodyScanStore.didChange)) { _ in
            refresh()
        }
        .onReceive(FoodLogPersister.changeNotifier) { _ in refresh() }
        .scrollDisabled(expandedTile != nil)
        .fullScreenCover(isPresented: $showCompare) {
            BodyTimelineView(
                userId: userId,
                onClose: { showCompare = false },
                changeLine: changeLine
            )
        }
        .fullScreenCover(isPresented: $showCheckIn) {
            BodyScanFlowView(userId: userId, onClose: {
                showCheckIn = false
                refresh()
            })
        }
        .sheet(isPresented: $showVisitPacket) {
            VisitPacketView(userId: userId, onClose: { showVisitPacket = false })
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
        }

        // ── THE EXPANSION (v11.5) — the selected tile, morphed into
        // its page inside the same tree. Drag down to let it go.
        if let tile = expandedTile {
            expandedLayer(tile)
        }
        }
        .toolbar(expandedTile == nil ? .visible : .hidden, for: .tabBar)
    }

    // MARK: - The expanded tile

    @ViewBuilder
    private func expandedLayer(_ tile: BecomingTile) -> some View {
        let dragProgress: CGFloat = min(1, max(0, expandDrag / 300))

        ZStack(alignment: .top) {
            // The scrim — paper thickening, never a gray veil.
            // Only the SCRIM fades. The card itself is carried by the
            // geometry match — fading it too made it cross-dissolve
            // against its own moving copy, which is the flicker.
            Palette.bgPrimary
                .opacity(Double(0.97 * (1.0 - dragProgress * 0.6)))
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { collapse() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    JeniSurface(radius: 28) {
                        VStack(alignment: .leading, spacing: Space.blockGap) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(tile.title)
                                    .font(Typo.questionHero)
                                    .foregroundStyle(Palette.textPrimary)
                                    .matchedGeometryEffect(id: "title.\(tile.id)", in: tileNS)
                                Spacer()
                                Button("done") { collapse() }
                                    .font(Typo.caption)
                                    .foregroundStyle(Palette.textSecondary)
                                    .accessibilityIdentifier("becoming.tile.done")
                                    .accessibilityLabel("done. closes \(tile.title)")
                            }

                            if contentReady, tile.meetsFloor, !tile.chart.isEmpty {
                                if tile.chart.form == .bars {
                                    // The founder's reference draws
                                    // rounded PILLS with the current
                                    // column filled — far prettier at
                                    // a glance than a 3pt comb.
                                    JeniPillBars(
                                        values: tile.chart.series.first?.values ?? [],
                                        labels: weekLabels,
                                        height: 150
                                    )
                                    .accessibilityLabel(Text(tile.read))
                                } else {
                                    JeniChart(
                                        model: tile.chart,
                                        height: 150,
                                        endLabels: expandedChartLabels(tile),
                                        scrubbable: true,
                                        accessibilityText: tile.read
                                    )
                                }
                            }

                            JeniHeadline(tile.read, italic: tile.readItalic)
                            if let mechanism = tile.mechanism {
                                Text(mechanism)
                                    .font(Typo.body)
                                    .foregroundStyle(Palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(tile.provenance)
                                .font(Typo.statLabel)
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                    }
                    .matchedGeometryEffect(id: "card.\(tile.id)", in: tileNS)
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.hero)

                    Spacer(minLength: 120)
                }
            }
            .scaleEffect(1.0 - dragProgress * 0.06, anchor: .top)
            .offset(y: expandDrag > 0 ? expandDrag * 0.6 : 0)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { g in
                        guard g.translation.height > 0 else { return }
                        expandDrag = g.translation.height
                    }
                    .onEnded { g in
                        if g.translation.height > 120 {
                            collapse()
                        } else {
                            withAnimation(JeniMotion.settle) { expandDrag = 0 }
                        }
                    }
            )
        }
        .zIndex(2)
    }

    /// Opening: a firm mark as the card takes the page, then the
    /// chart draws once the geometry has settled.
    private func expand(_ tile: BecomingTile) {
        JeniHaptic.land()
        contentReady = false
        withAnimation(JeniMotion.morph) { expandedTile = tile }
        Task {
            // The morph's spring settles well inside 380ms; the chart
            // begins after it, never during.
            try? await Task.sleep(nanoseconds: 380_000_000)
            guard expandedTile != nil else { return }
            withAnimation(.easeOut(duration: 0.24)) { contentReady = true }
        }
    }

    /// Letting go: the lighter mark, and the chart is torn down first
    /// so no Canvas is mid-phase while the card travels home.
    private func collapse() {
        JeniHaptic.tick()
        contentReady = false
        withAnimation(JeniMotion.morph) {
            expandedTile = nil
            expandDrag = 0
        }
    }

    /// Seven short weekday letters ending on today — the reference's
    /// labelled columns, in her own week.
    private var weekLabels: [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        return (0..<7).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset - 6, to: today)
            else { return nil }
            return names[cal.component(.weekday, from: day) - 1]
        }
    }

    private func expandedChartLabels(_ tile: BecomingTile) -> (String, String)? {
        switch tile.kind {
        case .weight: return ("\(tile.spanLabel ?? "4 weeks") ago", "today")
        case .movement, .waist, .bodyFat: return nil
        default: return ("a week ago", "today")
        }
    }

    // MARK: - BODY (the hero read)

    private var heroCard: some View {
        JeniCard {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("BODY")
                    .font(.custom("DMSans-SemiBold", size: 11, relativeTo: .caption2))
                    .tracking(1.6)
                    .foregroundStyle(Palette.cocoaTertiary)

                JeniHeadline(heroLine.text, italic: heroLine.italic)

                ForEach(review?.mechanisms ?? [], id: \.self) { line in
                    Text(line)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }

                if let preservation = review?.preservation {
                    Text(preservation.line)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }

                if let weight = tiles.first(where: { $0.kind == .weight }),
                   !weight.chart.isEmpty {
                    JeniChart(
                        model: weight.chart,
                        height: 78,
                        endLabels: ("\(weight.spanLabel ?? "4 weeks") ago", "today"),
                        filled: true,
                        accessibilityText: "weight, \(weight.spanLabel ?? "four weeks")"
                    )
                    .padding(.top, Space.sm)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var heroLine: (text: String, italic: [String]) {
        if let review { return (review.outcome, review.outcomeItalic) }
        // The floor truth — never a fake trend (L8).
        if bodyScans.isEmpty {
            return ("your record starts with one check-in.", ["record"])
        }
        return ("your record is building.", ["building."])
    }

    private var changeLine: String? {
        BodyChangeRead.line(
            scans: bodyScans.map {
                .init(capturedAt: $0.capturedAt, poseQuality: $0.poseQuality)
            },
            trendEstablished: snapshot?.trendIsEstablished ?? false,
            trendDeltaKg: snapshot?.emaDelta7dKg
        )
    }

    // MARK: - The tiles

    private var tileGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Space.md),
                      GridItem(.flexible(), spacing: Space.md)],
            spacing: Space.md
        ) {
            ForEach(tiles) { tile in
                BecomingTileView(
                    tile: tile,
                    namespace: tileNS,
                    isExpanded: expandedTile?.id == tile.id
                ) {
                    expand(tile)
                }
            }
        }
    }

    // MARK: - BODY PROGRESS

    private var bodyProgress: some View {
        VStack(alignment: .leading, spacing: 0) {
            JeniSectionHeader("body progress")

            if let first = firstPlate, let latest = latestPlate {
                Button { showCompare = true } label: {
                    HStack(spacing: Space.md) {
                        platePair(first, label: "first")
                        platePair(latest, label: "latest")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
                .accessibilityLabel("your first and latest check-ins. opens the compare")
            } else if let latest = latestPlate {
                Button { showCompare = true } label: {
                    platePair(latest, label: "your record · one check-in")
                        .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
            }

            if bodyScans.count >= 2 {
                JeniRow("compare across your record", trailing: .chevron,
                        action: { showCompare = true })
            }
            JeniRow("new check-in",
                    detail: bodyScans.isEmpty ? "a few seconds · stays on your phone" : nil,
                    action: { showCheckIn = true })
        }
    }

    /// V13 law: ink renders frameless at its own aspect on the paper;
    /// only PHOTOS get a mat. Never a filled crop — a waist plate
    /// clipped to a tall box reads as a black void, not a record.
    private func platePair(_ image: UIImage, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                // ONE fixed-height frame — scaledToFit sizes within
                // it; stacked max-frames let the image overflow (the
                // black-void bug, caught twice on film).
                .frame(height: 96, alignment: .bottom)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(label)
                .font(Typo.statLabel)
                .foregroundStyle(Palette.cocoaTertiary)
        }
    }

    // MARK: - Care doors (rehomed from the journal)

    private var careSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            JeniSectionHeader("your record")
            if let due = dueReview {
                JeniRow("the week's receipt is ready",
                        detail: "read it back, sign next week",
                        trailing: .chevron,
                        action: { presentedReview = due })
            }
            JeniRow("visit packet", detail: "for your clinician, when you choose",
                    trailing: .chevron, action: { showVisitPacket = true })
        }
    }

    // MARK: - Refresh

    private func refresh() {
        guard !userId.isEmpty else { return }
        let snap = TodayStateService.snapshot(userId: userId, in: modelContext)
        snapshot = snap
        bodyScans = BodyScanStore.all(userId: userId, in: modelContext)
        loadPlates()
        tiles = BecomingTileBuilder.build(
            userId: userId,
            snapshot: snap,
            sleepRecaps: sleepRecaps,
            scans: bodyScans,
            in: modelContext
        )
        composeReview()

        // The re-signing offer (v4 law, walker-hardened): auto-present
        // once per due week, only while becoming is the visible tab.
        let journey = JourneyModel.load(userId: userId, snapshot: snap, in: modelContext)
        dueReview = journey.dueReview
        if let due = journey.dueReview,
           router.tab == .becoming,
           autoOfferedReviewWeek != due.weekIndex {
            autoOfferedReviewWeek = due.weekIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if presentedReview == nil, router.tab == .becoming,
                   let stillDue = dueReview {
                    presentedReview = stillDue
                }
            }
        }
    }

    private func loadPlates() {
        // Oldest and newest keeps — BodyScanStore returns newest first.
        if let latest = bodyScans.first {
            latestPlate = BodyScanPhotoStore.image(
                scanId: latest.id, preferring: latest.renderMode
            )
        } else {
            latestPlate = nil
        }
        if let first = bodyScans.last, bodyScans.count > 1 {
            firstPlate = BodyScanPhotoStore.image(
                scanId: first.id, preferring: first.renderMode
            )
        } else {
            firstPlate = nil
        }
    }

    /// v9 P3's assembly, ported from the journal — every field traces
    /// to a collected store. The move stays on Home (three-questions
    /// law: Becoming answers "am I changing / why", never "do this").
    private func composeReview() {
        guard let snap = snapshot else { return }
        var input = WeeklyBodyReview.Input()
        let week = WeekState.load(userId: userId, in: modelContext)
        let insights = InsightEngine.insights(week: week, snapshot: snap)
        input.trendLine = insights.trendStory?.line
        input.trendItalic = insights.trendStory?.italic ?? []
        input.trendDeltaKg = snap.emaDelta7dKg
        input.trendEstablished = snap.trendIsEstablished
        input.scans = bodyScans.map {
            .init(capturedAt: $0.capturedAt, poseQuality: $0.poseQuality)
        }
        if let target = snap.targets.proteinG {
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
        let windowWeek = KitchenSignal.liveWeekStory(userId: userId)
        input.fastAvgHours = windowWeek?.averageHours
        input.fastNights = windowWeek?.narratedCount ?? 0
        input.sweetDirection = Sweetness.liveStory(userId: userId)?.direction
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
            input.leanLine = "your scale reads \(Int(lean.rounded())) kg lean"
        }
        review = WeeklyBodyReview.compose(input)
    }
}
