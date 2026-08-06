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
    /// v11.5 — matchedGeometryEffect is GONE from this surface. Inside
    /// a LazyVGrid its anchors are recycled with the cells, and the
    /// tab-bar and scroll toggles forced extra layout passes mid-
    /// animation; together they produced a ghost edge no amount of
    /// tuning removed. The expansion now interpolates an explicit
    /// rect from the tapped tile to the page, driven by ONE spring we
    /// own end to end.
    @State private var sourceRect: CGRect = .zero
    @State private var expandProgress: CGFloat = 0
    @State private var tileFrames: [String: CGRect] = [:]
    @State private var showCompare = false
    @State private var showCheckIn = false
    @State private var showVisitPacket = false
    @State private var showFoodJournal = false
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
            // QA: open the food journal without a scroll + tap.
            if ProcessInfo.processInfo.arguments.contains("--uitest-open-food-journal") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showFoodJournal = true
                }
            }
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
        .fullScreenCover(isPresented: $showFoodJournal) {
            FoodJournalView(userId: userId, onClose: { showFoodJournal = false })
        }
        .sheet(isPresented: $showVisitPacket) {
            VisitPacketView(userId: userId, onClose: { showVisitPacket = false })
                .presentationDetents([.large])
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)
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
    }

    // MARK: - The expanded tile

    @ViewBuilder
    private func expandedLayer(_ tile: BecomingTile) -> some View {
        GeometryReader { geo in
            let dragProgress: CGFloat = min(1, max(0, expandDrag / 320))
            // The page it grows INTO: near-full-screen, as the founder
            // asked, with just enough inset that it still reads as a
            // card rather than a new screen.
            let target = CGRect(
                x: 10,
                y: geo.safeAreaInsets.top + 8,
                width: geo.size.width - 20,
                height: geo.size.height + geo.safeAreaInsets.top - 24
            )
            let from = sourceRect == .zero ? target : sourceRect
            let p = expandProgress
            let rect = CGRect(
                x: from.minX + (target.minX - from.minX) * p,
                y: from.minY + (target.minY - from.minY) * p,
                width: from.width + (target.width - from.width) * p,
                height: from.height + (target.height - from.height) * p
            )

            ZStack(alignment: .topLeading) {
                Palette.bgPrimary
                    .opacity(Double(0.96 * p * (1 - dragProgress * 0.6)))
                    .ignoresSafeArea()
                    .onTapGesture { collapse() }

                RoundedRectangle(cornerRadius: 20 + 12 * p, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.textPrimary.opacity(0.06 * Double(p)),
                            radius: 24, y: 10)
                    .overlay(alignment: .topLeading) {
                        // The content fades in only once the card has
                        // arrived; nothing re-lays out while it moves.
                        expandedContent(tile)
                            .opacity(contentReady ? 1 : 0)
                            .padding(.horizontal, Space.gutter)
                            .padding(.top, Space.blockGap)
                    }
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY - geo.safeAreaInsets.top)
                    .scaleEffect(1 - dragProgress * 0.05, anchor: .top)
                    .offset(y: expandDrag > 0 ? expandDrag * 0.5 : 0)
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onChanged { g in
                                guard g.translation.height > 0 else { return }
                                expandDrag = g.translation.height
                            }
                            .onEnded { g in
                                if g.translation.height > 130 {
                                    collapse()
                                } else {
                                    withAnimation(JeniMotion.settle) { expandDrag = 0 }
                                }
                            }
                    )
            }
            .ignoresSafeArea()
        }
        .zIndex(3)
    }

    /// The detail itself — fuller than the old sheet: the read, the
    /// chart, the mechanism, and where every number came from.
    @ViewBuilder
    private func expandedContent(_ tile: BecomingTile) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.blockGap) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tile.title)
                        .font(Typo.questionHero)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Button {
                        collapse()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.cocoaSecondary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Palette.textPrimary.opacity(0.05)))
                    }
                    .buttonStyle(JeniPressable())
                    .accessibilityIdentifier("becoming.tile.done")
                    .accessibilityLabel("done. closes \(tile.title)")
                }

                Text(tile.value)
                    .font(.custom("JeniHeroSerif-Regular", size: 34, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.textPrimary)

                if tile.meetsFloor, !tile.chart.isEmpty {
                    if tile.chart.form == .bars {
                        JeniPillBars(
                            values: tile.chart.series.first?.values ?? [],
                            labels: weekLabels,
                            height: 190
                        )
                        .accessibilityLabel(Text(tile.read))
                    } else {
                        JeniChart(
                            model: tile.chart,
                            height: 190,
                            endLabels: expandedChartLabels(tile),
                            scrubbable: true,
                            filled: true,
                            accessibilityText: tile.read
                        )
                    }
                }

                JeniHeadline(tile.read, italic: tile.readItalic)

                if let mechanism = tile.mechanism {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WHY IT MATTERS")
                            .font(Typo.statLabel)
                            .kerning(1.2)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text(mechanism)
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Space.sm)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("WHERE THIS COMES FROM")
                        .font(Typo.statLabel)
                        .kerning(1.2)
                        .foregroundStyle(Palette.cocoaTertiary)
                    Text(tile.provenance)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }

                Spacer(minLength: Space.heroGap)
            }
        }
    }

    /// Opening: a firm mark as the card takes the page, then the
    /// chart draws once the geometry has settled.
    private func expand(_ tile: BecomingTile, from rect: CGRect) {
        JeniHaptic.land()
        contentReady = false
        sourceRect = rect
        expandProgress = 0
        expandedTile = tile
        // One spring, ours, on a plain CGFloat — no matching, no
        // implicit animation, nothing else to fight with.
        withAnimation(.spring(response: 0.46, dampingFraction: 0.88)) {
            expandProgress = 1
        }
        Task {
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard expandedTile != nil else { return }
            withAnimation(.easeOut(duration: 0.22)) { contentReady = true }
        }
    }

    /// Letting go: the lighter mark, and the chart is torn down first
    /// so no Canvas is mid-phase while the card travels home.
    private func collapse() {
        JeniHaptic.tick()
        // Content first, so no Canvas is mid-phase while it travels.
        contentReady = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            expandProgress = 0
            expandDrag = 0
        }
        Task {
            try? await Task.sleep(nanoseconds: 430_000_000)
            expandedTile = nil
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
        // v11.5: the hero opens through a ROW beneath it rather than
        // by wrapping the whole card in a Button. A full-card button
        // inside a ScrollView swallowed the vertical drag, so the page
        // stopped scrolling past it (leg-caught: "BODY PROGRESS never
        // offered the compare" — the walker could not reach it).
        VStack(alignment: .leading, spacing: 0) {
            heroFace
            JeniRow("read the whole week", trailing: .chevron) {
                expand(bodyTile, from: heroFrame)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: TileFrameKey.self,
                    value: ["__hero": geo.frame(in: .global)]
                )
            }
        )
    }

    private var heroFrame: CGRect { tileFrames["__hero"] ?? .zero }

    /// The hero as a TILE, so it opens through the same expansion
    /// every other module uses (the founder: every module clickable).
    private var bodyTile: BecomingTile {
        let weight = tiles.first(where: { $0.kind == .weight })
        return BecomingTile(
            kind: .weight,
            title: "your week",
            value: heroLine.text,
            meetsFloor: weight?.meetsFloor ?? false,
            chart: weight?.chart ?? JeniChartModel(form: .line, series: []),
            read: heroLine.text,
            readItalic: heroLine.italic,
            mechanism: (review?.mechanisms.isEmpty == false)
                ? review!.mechanisms.joined(separator: ". ") + "."
                : review?.preservation?.line,
            provenance: "from your weigh-ins, plates and phone · this week",
            spanLabel: weight?.spanLabel
        )
    }

    private var heroFace: some View {
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
        gridBody
            .onPreferenceChange(TileFrameKey.self) { frames in
                tileFrames.merge(frames) { _, new in new }
            }
    }

    private var gridBody: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Space.md),
                      GridItem(.flexible(), spacing: Space.md)],
            spacing: Space.md
        ) {
            ForEach(tiles) { tile in
                BecomingTileView(
                    tile: tile,
                    isExpanded: expandedTile?.id == tile.id
                ) {
                    expand(tile, from: tileFrames[tile.id] ?? .zero)
                }
                .background(
                    // Each tile reports where it actually sits, so the
                    // expansion can start exactly there. GeometryReader
                    // in a background never affects layout.
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: TileFrameKey.self,
                            value: [tile.id: geo.frame(in: .global)]
                        )
                    }
                )
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
            // v11.5: the food journal was orphaned when the journal
            // corpus went (JourneyPlatesPage died in T4 and was never
            // rehomed), leaving no way to see what she had eaten.
            JeniRow("your plates", detail: "every meal, with its photo",
                    trailing: .chevron, action: { showFoodJournal = true })
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


// MARK: - TileFrameKey
//
// Each tile publishes where it actually sits so the expansion can
// begin exactly there — the explicit replacement for the matched
// geometry that could not survive a LazyVGrid.

private struct TileFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
