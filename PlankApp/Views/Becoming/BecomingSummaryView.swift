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
    /// v12 — the dashboard's time scope. The grid re-keys; nothing
    /// reloads (§4.5).
    @State private var scope: JeniScope = .week
    /// v12 C5 — the week's reads, carousel-paged.
    @State private var insights: [JeniInsight] = []
    @State private var firstPlate: UIImage?
    @State private var latestPlate: UIImage?

    /// v11.5 — the expansion: a tile morphs in-tree into its page
    /// (matched geometry inside ONE view tree; iOS 17-true).
    @State private var expandedTile: BecomingTile?
    /// v19 — the sheet's live drag (positive = pulled UP) and its
    /// rest detent.
    @State private var sheetDrag: CGFloat = 0
    @State private var detent: SheetDetent = .medium
    /// The head (eyebrow + hero value) rides the growing surface.
    @State private var contentReady = false
    /// v15 — everything BELOW the head waits for the landing: a chart
    /// drawn into a Canvas that is still being resized is the visible
    /// jank behind "the chart flickers".
    @State private var landed = false
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
    /// v25 E4 — the compressed new-user zero state's disclosure.
    @State private var showAllWaiting = false
    // v4's re-signing (the weekly consented adaptation) — the engine
    // (JourneyModel) survived the journal; the doors live here now.
    @State private var dueReview: JourneyModel.DueReview?
    @State private var presentedReview: JourneyModel.DueReview?
    @State private var autoOfferedReviewWeek: Int? = nil
    @State private var router = AppRouter.shared

    @State private var arrived = false

    /// v12 C8 — care-connected patients read a different PRIORITY,
    /// same architecture: the care doors lead, the register stays
    /// clinical (v8 law). Mirrors AppPhaseMachine's care input.
    @AppStorage("care_entitlement_active") private var careEntitlementActive = false

    private var careActive: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-care-mode") {
            return true
        }
        #endif
        return careEntitlementActive
    }

    /// v12 film door — the insight pager's scope-walk auto-advance.
    /// Debug builds only; constant false in Release.
    private var walkScopeTour: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--uitest-walk-scope")
        #else
        return false
        #endif
    }

    private var userId: String {
        auth.currentUser?.id.uuidString ?? ""
    }

    /// Consecutive kept days ending today or yesterday (the insight
    /// carousel's consistency read; same math as Home's greeting).
    private var keptRun: Int {
        guard !userId.isEmpty else { return 0 }
        let cal = Calendar.current
        let kept = ProgramService.shared.keptDayStarts(userId: userId, in: modelContext)
        guard !kept.isEmpty else { return 0 }
        var day = cal.startOfDay(for: .now)
        if !kept.contains(day) {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var run = 0
        while kept.contains(day) {
            run += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return run
    }

    var body: some View {
        ZStack {
        ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // v21 — the masthead compressed to a dashboard header:
                // the page is instruments, not a magazine cover. One
                // line, the date beside it in the quiet ink.
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    Text("becoming")
                        .font(.custom("JeniHeroSerif-Regular", size: 28,
                                      relativeTo: .title2))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: Space.sm)
                    Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).lowercased())
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .jeniArrive(arrived, index: 0)
                .padding(.top, Space.md)
                .accessibilityAddTraits(.isHeader)

                heroCard
                    .padding(.top, Space.bandGap)
                    .jeniArrive(arrived, index: 1)

                // C8 — for a care-connected patient the care doors
                // LEAD: her clinician's loop is why she is here.
                if careActive {
                    careSection
                        .jeniArrive(arrived, index: 2)
                }

                if !insights.isEmpty {
                    // v14: the carousel is its own editorial band —
                    // the "THIS WEEK" header died (each card's eyebrow
                    // names its topic; its sentence names the week;
                    // two stacked caps labels were hierarchy noise).
                    JeniSurface(radius: Radius.card, padding: 14) {
                        JeniInsightPager(
                            insights: insights,
                            height: 132,
                            tourAutoAdvance: walkScopeTour
                        )
                    }
                    .padding(.top, Space.bandRow)
                    .jeniArrive(arrived, index: 2)
                }

                VStack(alignment: .leading, spacing: 0) {
                    // v21 — the "your numbers" header died (v17's law:
                    // a band that names itself needs none; a grid of
                    // numerals is self-naming). The scope bar IS the
                    // section's head.
                    JeniScopeBar(scope: $scope)
                        .padding(.top, Space.bandGap)
                        .padding(.bottom, Space.md)
                    tileGrid
                }
                .jeniArrive(arrived, index: 3)
                .id("becoming.grid")

                bodyProgress
                    .jeniArrive(arrived, index: 4)

                if !careActive {
                    careSection
                        .jeniArrive(arrived, index: 5)
                }

                Spacer(minLength: 120)
                    .id("becoming.bottom")
            }
            .padding(.horizontal, Space.gutter)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .environment(\.jeniArrived, arrived)
        .refreshable { refresh() }
        .jeniTopScrollEdge()
        // The masthead scrim (Home's floor, mirrored): scrolled serif
        // fades before the clock instead of colliding with it.
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Palette.bgPrimary, Palette.bgPrimary.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 54)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
        .onAppear {
            #if DEBUG
            // QA: capture the lower half (simctl can't scroll) — the
            // today-bottom pattern, mirrored.
            // QA: open the food journal without a scroll + tap.
            // v12 film door — the scope morph on camera: scroll to the
            // grid, then week → month → 3 months → week, values
            // re-counting, charts re-tracing.
            if ProcessInfo.processInfo.arguments.contains("--uitest-walk-scope") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation(.easeInOut(duration: 0.9)) {
                        proxy.scrollTo("becoming.grid", anchor: .top)
                    }
                }
                for (i, s) in [JeniScope.month, .threeMonths, .week].enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 7.2 + Double(i) * 2.4) {
                        JeniHaptic.tick()
                        withAnimation(JeniMotion.morph) { scope = s }
                    }
                }
            }
            if ProcessInfo.processInfo.arguments.contains("--uitest-open-food-journal") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    #if DEBUG
                    // v23 — the book films against a photogenic week.
                    if ProcessInfo.processInfo.arguments.contains("--uitest-seed-week") {
                        FoodBookQASeeder.seedWeek(userId: userId)
                    }
                    #endif
                    showFoodJournal = true
                }
            }
            // v12 film door — expand one tile's page deterministically.
            //
            // v15 correction: the door MUST scroll the grid into view
            // first. A LazyVGrid never builds its below-fold cells, so
            // the tile reported no frame, the layer fell back to
            // "start = target", and the morph didn't happen at all —
            // the films were of a page appearing, not a tile growing.
            // A leg that doesn't reproduce the real gesture is a leg
            // that lies.
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "--uitest-open-tile"),
               i + 1 < ProcessInfo.processInfo.arguments.count {
                let kind = ProcessInfo.processInfo.arguments[i + 1]
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        proxy.scrollTo("becoming.grid", anchor: .top)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
                    guard let tile = tiles.first(where: { $0.id == kind }),
                          let frame = tileFrames[tile.id], frame != .zero
                    else { return }
                    expand(tile, from: frame)
                }
                // v19 — the detents on film. Synthesized drags cannot
                // drive a gesture on this sim runtime (probe-proven),
                // so the door walks the rest states the finger would
                // reach: medium → full → medium.
                if ProcessInfo.processInfo.arguments.contains("--uitest-walk-sheet") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                        JeniHaptic.tick()
                        withAnimation(JeniMotion.settle) { detent = .full }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 11.0) {
                        JeniHaptic.tick()
                        withAnimation(JeniMotion.settle) { detent = .medium }
                    }
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
        .onChange(of: scope) {
            // The scope bar already morphed its capsule; the grid's
            // values re-count and its charts re-trace from the same
            // transaction — a morph, never a reload (§4.5).
            withAnimation(JeniMotion.morph) { refresh() }
        }
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
        // v25 E4 — becoming consumes its own routes. The always-
        // mounted Today tab used to grab pendingRoute and swallow
        // .trend/.weeklyRead with a bare break, so the chat's "show
        // me the weekly read" switched tabs and did nothing.
        .onChange(of: router.pendingRoute) { _, route in
            consumeBecomingRoute(route)
        }
        .onAppear { consumeBecomingRoute(router.pendingRoute) }
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

    // MARK: - The expanded tile — A DETENTED SHEET WITH PHYSICS
    //
    // v19. The founder asked four times for detents, interactive
    // dismissal and rubber-band physics, and each earlier pass gave
    // only the morph. Both are possible: the surface still GROWS out
    // of its tile (the shared element survives — a native `.sheet`
    // would have cost it), and it now behaves like a sheet once it
    // lands.
    //
    //   · two rest heights — MEDIUM (the read) and FULL (the record)
    //   · the drag follows the finger 1:1 between them
    //   · past FULL it RUBBER-BANDS (resistance ∝ distance)
    //   · release settles by VELOCITY, not just position, so a flick
    //     dismisses from anywhere and a slow drag returns
    //   · a tick at each detent crossing, a land on dismissal
    //
    // The gesture lives on the header (grabber + hero), not on the
    // whole sheet, so the ScrollView beneath keeps its own scrolling.

    private enum SheetDetent {
        case medium, full
        /// Share of the available height this detent rests at.
        var fraction: CGFloat { self == .medium ? 0.60 : 0.95 }
    }

    @ViewBuilder
    private func expandedLayer(_ tile: BecomingTile) -> some View {
        GeometryReader { geo in
            let total = geo.size.height + geo.safeAreaInsets.top
            let restHeight = total * detent.fraction
            // The live height: the drag pulls the top edge. Downward
            // shrinks 1:1; upward past FULL meets resistance.
            let raw = restHeight - sheetDrag
            let ceiling = total * SheetDetent.full.fraction
            let height = raw > ceiling
                ? ceiling + (raw - ceiling) * 0.22      // rubber band
                : max(120, raw)
            let p = expandProgress
            let from = sourceRect == .zero
                ? CGRect(x: 0, y: total - height, width: geo.size.width, height: height)
                : sourceRect
            let target = CGRect(x: 0, y: total - height,
                                width: geo.size.width, height: height)
            let rect = CGRect(
                x: from.minX + (target.minX - from.minX) * p,
                y: from.minY + (target.minY - from.minY) * p,
                width: from.width + (target.width - from.width) * p,
                height: from.height + (target.height - from.height) * p
            )
            let dim = Double(p) * Double(min(1, height / max(1, restHeight)))

            ZStack(alignment: .topLeading) {
                Palette.bgPrimary
                    .opacity(0.96 * dim)
                    .ignoresSafeArea()
                    .onTapGesture { collapse() }

                UnevenRoundedRectangle(
                    topLeadingRadius: 18 + 16 * p,
                    bottomLeadingRadius: 18 * (1 - p),
                    bottomTrailingRadius: 18 * (1 - p),
                    topTrailingRadius: 18 + 16 * p,
                    style: .continuous
                )
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.textPrimary.opacity(0.10 * Double(p)),
                            radius: 30, y: -3)
                    .overlay(alignment: .topLeading) {
                        // THE SHARED ELEMENT, without matched geometry
                        // (which cannot survive a LazyVGrid — proven
                        // twice): the content is laid out at its FINAL
                        // width and scaled by the surface's own growth
                        // ratio, top-left anchored, so at the start of
                        // the flight the hero renders at exactly the
                        // tile's value size in the tile's position.
                        VStack(spacing: 0) {
                            grabber
                            expandedContent(tile)
                        }
                        .padding(.horizontal, Space.gutter)
                        .padding(.top, 10)
                        .frame(width: target.width, alignment: .topLeading)
                        .scaleEffect(
                            max(0.05, rect.width / max(1, target.width)),
                            anchor: .topLeading
                        )
                        .opacity(contentReady ? 1 : 0)
                    }
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY - geo.safeAreaInsets.top)
            }
            .ignoresSafeArea()
        }
        .zIndex(3)
    }

    /// The sheet's handle — and the ONLY drag surface, so the content
    /// beneath keeps its own scrolling (the classic conflict).
    private var grabber: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Palette.textPrimary.opacity(0.18))
                .frame(width: 36, height: 5)
                .padding(.vertical, 7)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(sheetDragGesture)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("drag to resize or dismiss")
        .accessibilityAction { collapse() }
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { g in
                sheetDrag = -g.translation.height
            }
            .onEnded { g in
                let velocity = -g.predictedEndTranslation.height + g.translation.height
                let travelled = -g.translation.height
                sheetDrag = 0
                // Velocity decides first — a flick beats position, so
                // a fast downward throw dismisses from either detent.
                if velocity < -260 || travelled < -170 {
                    if detent == .full {
                        JeniHaptic.tick()
                        withAnimation(JeniMotion.settle) { detent = .medium }
                    } else {
                        collapse()
                    }
                } else if velocity > 260 || travelled > 90 {
                    if detent == .medium {
                        JeniHaptic.tick()
                        withAnimation(JeniMotion.settle) { detent = .full }
                    } else {
                        withAnimation(JeniMotion.settle) { }
                    }
                } else {
                    withAnimation(JeniMotion.settle) { }
                }
            }
    }

    /// v14 — the detail as an EDITORIAL INSIGHT (founder: "the weakest
    /// part… nothing should resemble a form"): a quiet eyebrow names
    /// the metric, the HERO value stands large with its movement word
    /// beneath, the chart breathes on its own stage, then the read,
    /// the ledger, the plan's stance and the provenance close the
    /// page. Blocks arrive in sequence — the eye is led, never
    /// flooded.
    @ViewBuilder
    private func expandedContent(_ tile: BecomingTile) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text(tile.title.uppercased())
                        .font(Typo.statLabel)
                        .kerning(1.4)
                        .foregroundStyle(Palette.cocoaTertiary)
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
                // The HEAD — no arrival of its own: it is the tile's
                // face, carried up by the surface (see the overlay's
                // scale note).

                VStack(alignment: .leading, spacing: 6) {
                    Text(tile.value)
                        .font(.custom("JeniHeroSerif-Regular", size: 44,
                                      relativeTo: .largeTitle))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    if let delta = tile.deltaWord {
                        Text(delta)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .opacity(landed ? 1 : 0)
                    }
                }
                .padding(.top, Space.md)

                if tile.meetsFloor, !tile.chart.isEmpty {
                    JeniChart(
                        model: tile.chart,
                        height: 200,
                        endLabels: expandedChartLabels(tile),
                        scrubbable: true,
                        filled: tile.chart.form == .line,
                        accessibilityText: tile.read
                    )
                    .padding(.top, Space.sectionGap)
                    .jeniArrive(landed, index: 0)
                }

                // v21 — the staged reveal, finished: headline, then
                // the ledger, then the stance, then provenance — each
                // its own breath (0.055s apart), so the page assembles
                // top-to-bottom the way the eye reads it.
                JeniHeadline(tile.read, italic: tile.readItalic)
                    .padding(.top, Space.sectionGap)
                    .jeniArrive(landed, index: 1)

                // C6 — the comparison ledger (a table of facts earns
                // its hairlines, §7.2).
                if !tile.summaryPairs.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(tile.summaryPairs) { pair in
                            HStack(alignment: .firstTextBaseline) {
                                Text(pair.label)
                                    .font(Typo.caption)
                                    .foregroundStyle(Palette.textSecondary)
                                Spacer(minLength: Space.md)
                                Text(pair.value)
                                    .font(.custom("DMSans-Medium", size: 14,
                                                  relativeTo: .subheadline))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.textPrimary.opacity(0.9))
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 10)
                            if pair.id != tile.summaryPairs.last?.id {
                                Rectangle()
                                    .fill(Palette.hairlineCocoa)
                                    .frame(height: 0.5)
                            }
                        }
                    }
                    .padding(.top, Space.blockGap)
                    .accessibilityElement(children: .combine)
                    .jeniArrive(landed, index: 2)
                }

                // v13: three tracked-caps labels over one-sentence
                // content were headers explaining headers. The
                // sentences stand on their own now, grouped by air:
                // the plan's stance, the mechanism, then provenance
                // as the page's quiet last word.
                VStack(alignment: .leading, spacing: Space.md) {
                    if let plan = tile.planLine {
                        Text(plan)
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let mechanism = tile.mechanism {
                        Text(mechanism)
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, Space.blockGap)
                .jeniArrive(landed, index: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tile.provenance)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                    if careActive {
                        // C8 — the care boundary, stated plainly
                        // (consent is hers; the packet is the door).
                        Text("shared with your care team only when you choose.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                }
                .padding(.top, Space.blockGap)
                .jeniArrive(landed, index: 4)

                // Clears the floating tab bar (frame-caught: the
                // provenance block hid beneath it).
                Spacer(minLength: 120)
            }
        }
    }

    /// Opening: a firm mark as the surface takes the page, then the
    /// content builds in while it is still travelling.
    ///
    /// v15 — the old 420ms gate was the "generic" tell: a white box
    /// slid up and THEN text appeared. Content now arms at 130ms, so
    /// the eyebrow and the hero value ride the surface upward and the
    /// page reads as the tile growing — she never left. The chart
    /// still waits (its own visibility gate + delay) so nothing draws
    /// into a rect that is still resizing.
    private func expand(_ tile: BecomingTile, from rect: CGRect) {
        JeniHaptic.land()
        contentReady = false
        landed = false
        sourceRect = rect
        expandProgress = 0
        sheetDrag = 0
        detent = .medium
        expandedTile = tile
        // One spring, ours, on a plain CGFloat — no matching, no
        // implicit animation, nothing else to fight with.
        withAnimation(.spring(response: 0.46, dampingFraction: 0.88)) {
            expandProgress = 1
        }
        Task {
            // One layout pass, then the head is ON the surface for the
            // whole flight.
            try? await Task.sleep(nanoseconds: 30_000_000)
            guard expandedTile != nil else { return }
            contentReady = true
            // The beat between the head landing and the page filling.
            // 400ms read as a pause on film; 270 reads as a breath.
            try? await Task.sleep(nanoseconds: 270_000_000)
            guard expandedTile != nil else { return }
            landed = true
        }
    }

    /// Letting go: the lighter mark, and the chart is torn down first
    /// so no Canvas is mid-phase while the card travels home.
    private func collapse() {
        JeniHaptic.tick()
        // v15 — the reading matter goes first (no Canvas mid-phase in
        // flight), but the HEAD rides the surface all the way home so
        // the page shrinks back into the tile it came from.
        landed = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            expandProgress = 0
            sheetDrag = 0
        }
        Task {
            try? await Task.sleep(nanoseconds: 430_000_000)
            contentReady = false
            expandedTile = nil
        }
    }

    private func expandedChartLabels(_ tile: BecomingTile) -> (String, String)? {
        switch tile.kind {
        case .weight: return ("\(tile.spanLabel ?? "4 weeks") ago", "today")
        case .movement, .waist, .bodyFat: return nil
        default:
            // The left label speaks the scoped span honestly (§1.6).
            let span = tile.spanLabel ?? "last 7 days"
            if span.hasPrefix("last 7") { return ("a week ago", "today") }
            if span.hasPrefix("last 30") { return ("a month ago", "today") }
            if span.hasPrefix("13 weeks") { return ("3 months ago", "today") }
            if span.hasPrefix("the last year") { return ("a year ago", "today") }
            if span.hasPrefix("your whole record") { return ("the start", "today") }
            return ("a week ago", "today")
        }
    }

    // MARK: - BODY (the hero read)

    private var heroCard: some View {
        // v11.5: the hero opens through a ROW rather than by wrapping
        // the whole card in a Button — a full-card button inside a
        // ScrollView swallowed the vertical drag (leg-caught).
        // v18.2: that row moved INSIDE the panel. It was the only bare
        // element between two cards and it broke the dashboard's
        // rhythm; a panel carries its own door.
        heroFace
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

    /// v13: the hero left its card — the page's one hero is
    /// typography and a chart ON the paper, the way the consult
    /// opens. Requirement-explanations ("needs 4 logged days…") left
    /// the face for the expanded read: a hero states, it never
    /// apologizes.
    /// v18.1 — the hero, MEASURED. It was the airiest band left in
    /// the app: a 26pt read, two support lines, a 44pt chart and a
    /// separate door row — ~166pt to say one thing. A dashboard's
    /// lead band states the body in one line, shows the trend beside
    /// it, and carries its own door. ~96pt for the same job.
    private var heroFace: some View {
        // v18.2 — on a DASHBOARD every module is a panel. v21 — the
        // panel leads with the NUMBER: the weight numeral is the
        // page's biggest fact, the weekly read demotes to its caption,
        // and the trajectory gets a real stage (56pt, blush wash,
        // berry now-dot). Words second, by law.
        JeniSurface(radius: Radius.card, padding: 14) {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("BODY")
                    .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                    .kerning(1.2)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: Space.sm)
                if let weight = weightTile, weight.meetsFloor,
                   let span = weight.spanLabel {
                    Text(span)
                        .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }

            if let weight = weightTile, weight.meetsFloor {
                Text(weight.value)
                    .font(.custom("JeniHeroSerif-Regular", size: 34,
                                  relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                    .animation(JeniMotion.morph, value: weight.value)
                ItalicAccentText(
                    heroLine.text,
                    italic: heroLine.italic,
                    baseFont: .custom("DMSans-Regular", size: 12.5, relativeTo: .caption),
                    italicFont: .custom("DMSans-Medium", size: 12.5, relativeTo: .caption)
                )
                .fixedSize(horizontal: false, vertical: true)
            } else {
                ItalicAccentText(
                    heroLine.text,
                    italic: heroLine.italic,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title3),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 22, relativeTo: .title3)
                )
                .fixedSize(horizontal: false, vertical: true)
                if let first = heroSupportLines.first {
                    Text(first)
                        .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
            }

            if let weight = weightTile, !weight.chart.isEmpty {
                JeniChart(
                    model: weight.chart,
                    height: 56,
                    filled: true,
                    accessibilityText: "weight, \(weight.spanLabel ?? "four weeks")"
                )
                .padding(.top, 4)
            }

            Button { expand(bodyTile, from: heroFrame) } label: {
                HStack(spacing: 5) {
                    Text("read the whole week")
                        .font(.custom("DMSans-Medium", size: 12.5, relativeTo: .caption))
                        .foregroundStyle(Palette.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .padding(.top, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .accessibilityLabel("read the whole week")
        }
        }
        .accessibilityElement(children: .contain)
    }

    private var weightTile: BecomingTile? {
        tiles.first(where: { $0.kind == .weight })
    }

    /// The face's supporting lines: real observations only, at most
    /// two. Anything explaining what's MISSING waits for the page.
    private var heroSupportLines: [String] {
        var lines = review?.mechanisms ?? []
        if let preservation = review?.preservation {
            lines.append(preservation.line)
        }
        return Array(lines.filter { !$0.contains("needs") }.prefix(1))
    }

    /// THE WHOLE DISTANCE (2026-08-13) — the number people screenshot,
    /// and the one this card could not draw.
    ///
    /// The caption under the weight numeral read the WEEKLY outcome
    /// ("down about 1 lb this week"), which on a twelve-day record is
    /// the least motivating true sentence available and is already
    /// drawn, larger, by the chart six points below it. The distance
    /// since she started was in none of it — and the goal she named in
    /// onboarding appeared nowhere in the product after the screen
    /// that collected it.
    ///
    /// This is a SWAP, not an addition: the card gains no height, the
    /// week keeps its own door ("read the whole week"), and when the
    /// record is too thin to claim a distance the previous line stands
    /// exactly as it did.
    private var heroLine: (text: String, italic: [String]) {
        if let journey = snapshot?.weightJourney {
            let change = journey.changeLine()
            if let goal = journey.goalLine() {
                return ("\(change). \(goal).", [journey.isDown ? "down" : "up"])
            }
            return ("\(change).", [journey.isDown ? "down" : "up"])
        }
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

    /// Design law §12.9 + §1.7: a metric with nothing to say does not
    /// earn a tile. Eleven identical squares — five of them repeating
    /// "logging · 0 of 3 days" — was the uniform-card-grid tell the
    /// law hunts by name. Metrics that READ keep the grid; metrics
    /// still waiting collapse into canonical rows that open the same
    /// page from the same morph.
    private var gridBody: some View {
        // v18.3 — TWO columns maximum, and the grid is not filled just
        // because it exists. Only metrics that answer "am I changing?"
        // at a glance take a tile; every other live metric is a row
        // carrying the same number and the same shape at ~46pt instead
        // of ~104. Waiting metrics keep their honest standing rows.
        let live = tiles.filter(\.meetsFloor)
        let leads = live.filter(\.isPrimary)
        let rest = live.filter { !$0.isPrimary }
        let waiting = tiles.filter { !$0.meetsFloor }

        return VStack(alignment: .leading, spacing: 0) {
            if !leads.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                   count: 2),
                    spacing: 10
                ) {
                    ForEach(Array(leads.enumerated()), id: \.element.id) { i, tile in
                        BecomingTileView(
                            tile: tile,
                            isExpanded: expandedTile?.id == tile.id,
                            chartDelay: Double(i) * 0.12
                        ) {
                            expand(tile, from: tileFrames[tile.id] ?? .zero)
                        }
                        .background(tileFrameReporter(tile))
                    }
                }
            }

            if !rest.isEmpty {
                VStack(spacing: 0) {
                    ForEach(rest) { tile in
                        BecomingMetricRow(tile: tile) {
                            expand(tile, from: tileFrames[tile.id] ?? .zero)
                        }
                        .opacity(expandedTile?.id == tile.id ? 0 : 1)
                        .background(tileFrameReporter(tile))
                    }
                }
                .padding(.top, Space.md)
            }

            if !waiting.isEmpty {
                if live.isEmpty {
                    // v25 E4 (frame-caught): a brand-new user met a
                    // WALL of thirteen "not enough to read yet" rows
                    // — honest, and demoralizing. When nothing is
                    // readable yet, one sentence carries the truth
                    // and the enumeration waits behind a quiet door.
                    JeniSurface(radius: Radius.card) {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            ItalicAccentText(
                                "your reads open as the record grows.",
                                italic: ["open"],
                                baseFont: .custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title3),
                                italicFont: .custom("JeniHeroSerif-Italic", size: 22, relativeTo: .title3),
                                color: Palette.textPrimary,
                                alignment: .leading
                            )
                            Text("plates and weigh-ins feed them. the first reads arrive after about three logged days.")
                                .font(Typo.body)
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, Space.bandGap)
                    JeniRow(
                        "what's coming",
                        detail: showAllWaiting ? "fold it away" : "\(waiting.count) reads",
                        trailing: .chevron,
                        action: {
                            withAnimation(JeniMotion.morph) {
                                showAllWaiting.toggle()
                            }
                        }
                    )
                    if showAllWaiting {
                        waitingRows(waiting)
                    }
                } else {
                    // Honest for every row underneath: weight may HAVE a
                    // number but not yet a trend; movement isn't connected;
                    // the nutrients need more logged days (§1.6).
                    JeniSectionHeader("not enough to read yet", topAir: Space.bandGap)
                    waitingRows(waiting)
                }
            }
        }
    }

    /// The waiting rows, shared by the compressed (new-user) and
    /// standard renders.
    private func waitingRows(_ waiting: [BecomingTile]) -> some View {
        VStack(spacing: 0) {
            ForEach(waiting) { tile in
                JeniRow(
                    tile.title.lowercased(),
                    detail: tile.value,
                    trailing: .chevron,
                    action: { expand(tile, from: tileFrames[tile.id] ?? .zero) }
                )
                .opacity(expandedTile?.id == tile.id ? 0 : 1)
                .background(tileFrameReporter(tile))
            }
        }
    }

    /// Each tile reports where it actually sits, so the expansion can
    /// start exactly there. GeometryReader in a background never
    /// affects layout.
    private func tileFrameReporter(_ tile: BecomingTile) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: TileFrameKey.self,
                value: [tile.id: geo.frame(in: .global)]
            )
        }
    }

    // MARK: - BODY PROGRESS

    private var bodyProgress: some View {
        // v19 — the header only appears when the section has a RECORD
        // to show. With no check-ins yet it was a section title over a
        // single door; that door now sits in "your record" with the
        // other doors, and the header returns the moment there are
        // plates to compare.
        VStack(alignment: .leading, spacing: 0) {
            if firstPlate != nil || latestPlate != nil {
                JeniSectionHeader("body progress", topAir: Space.bandGap)

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
            }
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
            // C8: for care patients the section leads and speaks
            // clinically; consumers keep the record framing.
            JeniSectionHeader(careActive ? "your care" : "your record", topAir: Space.bandGap)
            if careActive {
                JeniRow("visit packet",
                        detail: "your last 28 days, ready for your clinician",
                        trailing: .chevron, action: { showVisitPacket = true })
            }
            // v11.5: the food journal was orphaned when the journal
            // corpus went (JourneyPlatesPage died in T4 and was never
            // rehomed), leaving no way to see what she had eaten.
            JeniRow("new check-in",
                    detail: bodyScans.isEmpty ? "a few seconds · stays on your phone" : nil,
                    trailing: .chevron, action: { showCheckIn = true })
            JeniRow("your plates", detail: "every meal, with its photo",
                    trailing: .chevron, action: { showFoodJournal = true })
            if let due = dueReview {
                JeniRow("the week's receipt is ready",
                        detail: "read it back, sign next week",
                        trailing: .chevron,
                        action: { presentedReview = due })
            }
            if !careActive {
                JeniRow("visit packet", detail: "for your clinician, when you choose",
                        trailing: .chevron, action: { showVisitPacket = true })
            }
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
            scope: scope,
            in: modelContext
        )
        insights = BecomingInsightBuilder.build(
            userId: userId,
            snapshot: snap,
            scans: bodyScans,
            keptRun: keptRun
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

    /// v25 E4 — the becoming-destined routes, consumed here: the
    /// book opens directly (the evening push's promise), the weekly
    /// read presents when one is due (and quietly shows the record
    /// when none is — the tool's note already tells jeni not to
    /// promise one), the trend simply lands (the body card leads
    /// with it).
    private func consumeBecomingRoute(_ route: AppRouter.Route?) {
        guard router.tab == .becoming, let route else { return }
        switch route {
        case .plates:
            router.pendingRoute = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showFoodJournal = true
            }
        case .weeklyRead:
            router.pendingRoute = nil
            if let due = dueReview, presentedReview == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    presentedReview = due
                }
            }
        case .trend:
            router.pendingRoute = nil
        default:
            break
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
