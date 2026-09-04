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
    // p73 — the lens pins only where the viewport can afford it;
    // at accessibility sizes it joins the scroll (§5.2's escape).
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var showVisitPacket = false
    @State private var showFoodJournal = false
    @State private var showWeighIns = false
    /// p74 — the weight page's own range (initialized from the page
    /// lens at open; local to the page, deliberately: exploring a
    /// range inside a detail must not yank the page she returns to).
    @State private var detailScope: JeniScope = .week
    /// p74 — THE WHOLE DISTANCE (the ink scene).
    @State private var showDistance = false
    /// p74 film door — drives the detail's scroll (DEBUG walks).
    @State private var detailScrollBottomTick = 0
    /// Days between her first real weigh-in and today (gates the
    /// distance door — a young record has no distance to stand in).
    @State private var recordSpanDays = 0
    /// v25 E4 — the compressed new-user zero state's disclosure.
    @State private var showAllWaiting = false
    // v4's re-signing (the weekly consented adaptation) — the engine
    // (JourneyModel) survived the journal; the doors live here now.
    @State private var dueReview: JourneyModel.DueReview?
    @State private var presentedReview: JourneyModel.DueReview?
    @State private var autoOfferedReviewWeek: Int? = nil
    @State private var router = AppRouter.shared
    @Environment(\.scenePhase) private var scenePhase

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

    var body: some View {
        ZStack {
        ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
            // p73 — THE LENS PINS. The time filter was mid-page
            // content (between the carousel and the grid), 13pt gray
            // words nobody read as a control — the walker itself
            // failed to hit "month". It is the page's one view-level
            // control now: directly under the masthead, pinned while
            // she scrolls, every range a hairline chip. At
            // accessibility sizes the bar JOINS the scroll instead
            // (the §5.2 escape — a pinned band at AX5 spends the
            // viewport the content needs).
            LazyVStack(
                alignment: .leading, spacing: 0,
                pinnedViews: typeSize.isAccessibilitySize ? [] : [.sectionHeaders]
            ) {
                // v21 — the masthead compressed to a dashboard header:
                // the page is instruments, not a magazine cover. One
                // line, the date beside it in the quiet ink.
                // p73 — the masthead is a COMPOSITION at AX sizes
                // (title-beside-date wrapped "thu, / sep 3" into a
                // right-hanging orphan, SE·AX5 filmed): the date
                // stacks under the title, leading-aligned.
                mastheadPair
                .padding(.horizontal, Space.gutter)
                .jeniArrive(arrived, index: 0)
                .padding(.top, Space.md)
                .accessibilityAddTraits(.isHeader)
                // p73 — VoiceOver order: masthead → the lens → the
                // page. A pinned section header lands LAST in the
                // tree, so a VO user heard the whole page before
                // discovering the time-range control (tree-caught).
                .accessibilitySortPriority(2)

                Section {
                heroCard
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.sm)
                    .jeniArrive(arrived, index: 2)

                // p74 — THE DOSE SEAT. For a medicated customer the
                // dose period is the organizing context of the whole
                // story (research: weight-per-dose-era is the
                // category's most-asked read), so it sits with the
                // hero it contextualizes — never a separate medical
                // dashboard. Absent regimen = absent seat.
                if let med = tiles.first(where: { $0.kind == .medication }) {
                    doseSeatCard(med)
                        .padding(.horizontal, Space.gutter)
                        .padding(.top, 10)
                        .jeniArrive(arrived, index: 2)
                }

                // C8 — for a care-connected patient the care doors
                // LEAD: her clinician's loop is why she is here.
                if careActive {
                    careSection
                        .padding(.horizontal, Space.gutter)
                        .jeniArrive(arrived, index: 3)
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
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.bandRow)
                    .jeniArrive(arrived, index: 3)
                }

                tileGrid
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.bandRow)
                    .jeniArrive(arrived, index: 4)
                    .id("becoming.grid")

                bodyProgress
                    .padding(.horizontal, Space.gutter)
                    .jeniArrive(arrived, index: 5)

                if !careActive {
                    careSection
                        .padding(.horizontal, Space.gutter)
                        .jeniArrive(arrived, index: 6)
                }

                Spacer(minLength: 120)
                    .id("becoming.bottom")
                } header: {
                    // The lens: paper-grounded so scrolled content
                    // dissolves under it; at rest the fade is
                    // invisible (paper on paper).
                    VStack(alignment: .leading, spacing: 0) {
                        JeniScopeBar(scope: $scope, scopes: JeniScope.becomingLenses)
                            .padding(.horizontal, Space.gutter)
                            .padding(.top, 10)
                            .padding(.bottom, 6)
                            // While pinned the bar touches the safe
                            // area, so the paper extends through the
                            // status bar — the scrim's fade zone
                            // otherwise ghosts scrolled content in
                            // the 13pt between its solid stop and
                            // the pin (film-caught).
                            .background {
                                Palette.bgPrimary.ignoresSafeArea(edges: .top)
                            }
                        LinearGradient(
                            colors: [Palette.bgPrimary, Palette.bgPrimary.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 10)
                        .allowsHitTesting(false)
                    }
                    .jeniArrive(arrived, index: 1)
                    .accessibilitySortPriority(1)
                }
            }
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .environment(\.jeniArrived, arrived)
        .refreshable { refresh() }
        .jeniTopScrollEdge()
        // The masthead scrim — the kit's one law (p62).
        .jeniMastheadScrim()
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
            // p74 film doors — the walker's synthesized drags cannot
            // scroll the expansion's inner ScrollView on this sim
            // runtime (the v12 class: tours film what walkers
            // cannot). The doors open the weight page, walk it to
            // its ledger, and open THE WHOLE DISTANCE.
            if ProcessInfo.processInfo.arguments.contains("--uitest-open-weight-detail") {
                if let i = ProcessInfo.processInfo.arguments.firstIndex(
                    of: "--uitest-weight-detail-scope"
                ), i + 1 < ProcessInfo.processInfo.arguments.count,
                   let s = JeniScope(rawValue: ProcessInfo.processInfo.arguments[i + 1]) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
                        scope = s
                        refresh()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    expand(bodyTile, from: tileFrames["__hero"] ?? .zero)
                }
                if ProcessInfo.processInfo.arguments.contains("--uitest-weight-detail-bottom") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                        detailScrollBottomTick += 1
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--uitest-open-distance") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                        withAnimation(.easeInOut(duration: 0.55)) {
                            showDistance = true
                        }
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
            runAutoPresent()
            // p76 — TWO conductor laws, both filmed:
            //   · The arrival flip is NEVER sequenced behind data
            //     work. It used to wait for the sleep query below;
            //     when HealthKit stalled, the whole page stood at
            //     opacity 0 — every element in the tree, nothing on
            //     the screen, "time range" and all four record rows
            //     hittable and invisible.
            //   · This tree mounts at app launch behind the today
            //     tab, so flipping here meant becoming's one arrival
            //     always played to a covered stage (the p75 class).
            //     The flip now belongs to the first actual VISIT.
            if router.tab == .becoming { armArrival() }
            sleepRecaps = await SleepService.shared.nightHistory()
            composeReview()
        }
        // p62 — a tab switch INTO becoming is this surface's arrival
        // (the tree stays mounted, so .task fired at launch, not per
        // visit): a due weekly read used to greet nobody until she
        // pulled to refresh or a plate landed while she watched.
        .onChange(of: router.tab) { _, tab in
            guard tab == .becoming else { return }
            refresh()
            runAutoPresent()
            armArrival()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, router.tab == .becoming else { return }
            refresh()
            runAutoPresent()
        }
        // Publish the slot occupancy so Home's reconcile never burns
        // its once-flag into an open BOOK, and vice versa.
        .onChange(of: anyBecomingSurfaceUp) { _, isUp in
            PresentationGate.shared.set(.becoming, up: isUp)
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
        // p74 — the weight page's own range chips: the tile rebuilds
        // for the chosen window (sentence, chart, ledger together).
        // Local to the page — the lens she left stays where she left
        // it.
        .onChange(of: detailScope) { _, newScope in
            guard expandedTile?.kind == .weight,
                  expandedTile?.meetsFloor == true,
                  let snap = snapshot else { return }
            withAnimation(JeniMotion.morph) {
                expandedTile = dressedWeightTile(
                    BecomingTileBuilder.weightTile(
                        userId: userId, snapshot: snap,
                        scope: newScope, in: modelContext
                    ),
                    for: newScope
                )
            }
        }
        .jeniCover(isPresented: $showCompare) {
            BodyTimelineView(
                userId: userId,
                onClose: { showCompare = false },
                changeLine: changeLine
            )
        }
        .jeniCover(isPresented: $showWeighIns) {
            // A DESTINATION, not a quick action (§17): it carries the
            // whole record and an editor, so it takes the page — the
            // same call `your plates` makes one line above.
            WeighInLedgerSheet(userId: userId, onClose: {
                showWeighIns = false
                refresh()
            })
        }
        .jeniCover(isPresented: $showFoodJournal) {
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
        // Pass 57 (D6) — the packet takes the PAGE. It was the one
        // record row in this list presented as a sheet: the densest
        // record surface (the clinician PDF source) arriving as a
        // partial vessel while its siblings — the weigh-in ledger, THE
        // BOOK, the body timeline — are covers. Sibling destinations
        // from one list take one style.
        .jeniCover(isPresented: $showVisitPacket) {
            VisitPacketView(userId: userId, onClose: { showVisitPacket = false })
        }
        .jeniCover(item: $presentedReview) { due in
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

        // ── THE WHOLE DISTANCE (p74) — Becoming's one ink scene.
        // The §4.8 grammar: a whole-surface CROSSFADE to ink, never
        // a slide (the first cut arrived as a cover and film caught
        // the slide seam). Reduce Motion arrives whole.
        if showDistance {
            BecomingDistanceView(
                userId: userId,
                onClose: {
                    withAnimation(
                        reduceMotion ? nil : .easeInOut(duration: 0.4)
                    ) { showDistance = false }
                }
            )
            .transition(.opacity)
            .zIndex(4)
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

    /// p73 — a page holds the height its job needs (§6.1). A tile
    /// with no drawable chart and no comparison ledger (movement,
    /// waist, body fat, every waiting row) is four sentences; p68's
    /// arrive-at-FULL law existed because a ledger hid below the
    /// medium fold — with nothing below the fold, a full-screen
    /// cover is dead paper (p72 named it on the movement tile).
    private func isThin(_ tile: BecomingTile) -> Bool {
        (!tile.meetsFloor || tile.chart.isEmpty) && tile.summaryPairs.isEmpty
    }

    /// The rest height for the current detent — thin pages rest
    /// lower at medium; a drag up still reaches full.
    private func restFraction(_ tile: BecomingTile) -> CGFloat {
        detent == .full ? SheetDetent.full.fraction
            : (isThin(tile) ? 0.45 : SheetDetent.medium.fraction)
    }

    @ViewBuilder
    private func expandedLayer(_ tile: BecomingTile) -> some View {
        GeometryReader { geo in
            let total = geo.size.height + geo.safeAreaInsets.top
            // p68 — the sheet's top may never cross the status bar:
            // 0.95 of (height + safeTop) put the top edge 13pt above
            // the screen at FULL, so the eyebrow and the X rendered
            // behind the clock (film-caught on the calories tile).
            let cap = total - geo.safeAreaInsets.top - 10
            let restHeight = min(total * restFraction(tile), cap)
            // The live height: the drag pulls the top edge. Downward
            // shrinks 1:1; upward past FULL meets resistance.
            let raw = restHeight - sheetDrag
            let ceiling = min(total * SheetDetent.full.fraction, cap)
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

                let sheetShape = UnevenRoundedRectangle(
                    topLeadingRadius: 18 + 16 * p,
                    bottomLeadingRadius: 18 * (1 - p),
                    bottomTrailingRadius: 18 * (1 - p),
                    topTrailingRadius: 18 + 16 * p,
                    style: .continuous
                )
                // p74 (founder, filmed): the sheet's bottom edge
                // stopped a safe-area's worth short of the screen —
                // a dimmed strip of the page showed through beneath
                // every detent. The detent math governs the TOP edge;
                // the bottom always reaches the screen (the reach
                // rides the flight's progress so the growth from the
                // tile stays seamless).
                let bottomReach = (geo.safeAreaInsets.top
                    + geo.safeAreaInsets.bottom + 4) * p
                sheetShape
                    // p68 (founder steer) — the page LANDS on Jeni's
                    // paper, not card-white: a full page is a page.
                    // The fill blends from the tile's own white during
                    // the flight so the growth stays seamless.
                    .fill(Palette.bgElevated)
                    .overlay(sheetShape.fill(Palette.bgPrimary.opacity(Double(p))))
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
                    .frame(width: rect.width, height: rect.height + bottomReach)
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
        // p68 (founder steer) — the exit is STICKY at the top (§5.2):
        // the eyebrow + X used to live inside the scroll and rode away
        // with the content. Only the record scrolls between the pinned
        // header and the sheet's edge now.
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
                        // p63 — 34pt visible, HIG-floor target.
                        .tappableArea()
                }
                .buttonStyle(JeniPressable())
                .accessibilityIdentifier("becoming.tile.done")
                .accessibilityLabel("done. closes \(tile.title)")
            }
            // The HEAD — no arrival of its own: it is the tile's
            // face, carried up by the surface (see the overlay's
            // scale note).

            // p74 — the weight page carries its own range chips (the
            // lens follows into the page, then the page owns it).
            // Pinned with the header, not scrolled: a range control
            // that rides away with the content is p73's mid-page
            // lens defect reborn.
            if tile.kind == .weight, tile.meetsFloor {
                JeniScopeBar(
                    scope: $detailScope,
                    scopes: JeniScope.becomingLenses,
                    idPrefix: "weight.scope"
                )
                // p76 — the bar must not absorb the header's height
                // proposal (paint-probed: it swallowed ~80pt as dead
                // paper above the numeral and pushed the era ledger
                // under the tab bar). 48 is its natural chip height;
                // accessibility sizes keep the natural measure.
                .frame(height: typeSize.isAccessibilitySize ? nil : 48)
                .padding(.top, 8)
                .padding(.bottom, 2)
            }

            ScrollViewReader { detailProxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
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

                // p74 — the medication page's tally strip is context,
                // not the subject (it drew at full 200pt above the
                // era ledger, filmed): it renders small, after the
                // ledger, below.
                if tile.meetsFloor, !tile.chart.isEmpty,
                   tile.kind != .medication {
                    JeniChart(
                        model: tile.chart,
                        // The weight page is a full-screen chart
                        // surface; it earns the taller stage.
                        height: tile.kind == .weight ? 230 : 200,
                        endLabels: expandedChartLabels(tile),
                        scrubbable: true,
                        filled: tile.chart.form == .line,
                        // p74 — a months-long chart's scrub speaks
                        // the WHEN with the how-much.
                        detentLabel: scrubLabel(tile),
                        accessibilityText: expandedAccessibilityText(tile),
                        // p58 — the dose-era seams render at detail
                        // size only; the face spark stays clean.
                        showMarkers: !tile.chart.markers.isEmpty
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

                // p74 — the medication page's dose strip, small and
                // labeled: rhythm context under the era ledger.
                if tile.kind == .medication, !tile.chart.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        JeniChart(model: tile.chart, height: 40)
                        Text("your last doses, oldest to newest. a gap is a skipped or unmarked dose.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Space.blockGap)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("your recent dose marks")
                    .jeniArrive(landed, index: 2)
                }

                // p74 — THE WHOLE DISTANCE door: the ink scene, for a
                // record old enough to have one (≥ 8 weeks).
                if tile.kind == .weight, tile.meetsFloor,
                   recordSpanDays >= 56,
                   !CohortStore.isNumericSuppressed {
                    Button {
                        JeniHaptic.land()
                        withAnimation(
                            reduceMotion ? nil : .easeInOut(duration: 0.55)
                        ) { showDistance = true }
                    } label: {
                        HStack(alignment: .lastTextBaseline, spacing: 5) {
                            Text("the whole distance")
                                .font(.custom("DMSans-Medium", size: 13.5, relativeTo: .subheadline))
                                .foregroundStyle(Palette.textPrimary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(JKPress())
                    .accessibilityLabel("the whole distance. your record from the start, on one page")
                    .padding(.top, Space.sm)
                    .jeniArrive(landed, index: 3)
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
                    .id("detail.bottom")
                }
            }
            #if DEBUG
            .onChange(of: detailScrollBottomTick) { _, _ in
                withAnimation(.easeInOut(duration: 0.6)) {
                    detailProxy.scrollTo("detail.bottom", anchor: .bottom)
                }
            }
            #endif
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
        // The page opens at the lens she was reading (temporal
        // continuity, p74); its own chips take over from there.
        detailScope = scope
        contentReady = false
        landed = false
        sourceRect = rect
        expandProgress = 0
        sheetDrag = 0
        // p68 — arrive at FULL. The tile itself is the glance (value +
        // mini chart); a tap means "show me more", and the medium rest
        // showed a hero + chart that LOOKED complete while the ledger,
        // the read and provenance hid below with no cue (filmed on the
        // calories tile). Medium survives as the rest stop on the way
        // down; the v19 physics are untouched.
        // p73 — EXCEPT thin pages (no chart, no ledger): four
        // sentences arrive as a modest sheet, not a full-screen
        // cover. A drag up still reaches full.
        detent = isThin(tile) ? .medium : .full
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

    /// p58 — the seams speak (§10.2): VoiceOver hears what the dose
    /// markers draw, in the same factual register — where the dose
    /// changed, never what the change did.
    private func expandedAccessibilityText(_ tile: BecomingTile) -> String {
        let words = tile.chart.markers.compactMap(\.label)
        guard !words.isEmpty else { return tile.read }
        return tile.read
            + " the chart marks where the dose changed: "
            + words.joined(separator: ", ") + "."
    }

    /// p74 — the scrub's words: date + value for the weight line
    /// (its slots are calendar days ending today, so the index maps
    /// straight to a date). Other charts keep the bare value — their
    /// slots may be week/month buckets whose date would lie.
    private func scrubLabel(
        _ tile: BecomingTile
    ) -> ((Int, Double) -> String?)? {
        guard tile.kind == .weight else { return nil }
        let slots = tile.chart.slotCount
        let unit = WeightUnit.current
        return { index, value in
            guard slots > 1,
                  let day = Calendar.current.date(
                      byAdding: .day, value: -(slots - 1 - index),
                      to: Calendar.current.startOfDay(for: .now)
                  ) else { return nil }
            let word = day.formatted(
                .dateTime.month(.abbreviated).day()
            ).lowercased()
            return "\(word) · \(WeightLedger.number(value)) \(unit.label)"
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
    ///
    /// p74 — the hero's page IS the weight page (its tile left the
    /// grid): numeral hero, the period's sentence, the big chart with
    /// its dose seams, the window ledger + era rows. The old page
    /// repeated the hero's own sentence as both value and read
    /// (filmed — a door that rewarded the tap with what she left).
    private var bodyTile: BecomingTile {
        guard let weight = weightTile, weight.meetsFloor else {
            return BecomingTile(
                kind: .weight,
                title: "weight",
                value: heroLine.text,
                meetsFloor: false,
                chart: weightTile?.chart ?? JeniChartModel(form: .line, series: []),
                read: heroLine.text,
                readItalic: heroLine.italic,
                mechanism: review?.preservation?.line,
                provenance: "from your weigh-ins, plates and phone",
                spanLabel: weightTile?.spanLabel
            )
        }
        return dressedWeightTile(weight, for: scope)
    }

    /// The weight page's dressing over a built weight tile: the
    /// period sentence as the read, the whole distance as the quiet
    /// line, the review's mechanisms. Parameterized by scope so the
    /// page's own range chips can rebuild it (the lens follows in).
    private func dressedWeightTile(
        _ weight: BecomingTile, for scope: JeniScope
    ) -> BecomingTile {
        let period: (text: String, italic: [String])
        switch scope {
        case .year, .all:
            period = heroLine
        default:
            var text = weight.read
            if let rate = weight.deltaWord { text += " \(rate)" }
            period = (text, weight.readItalic)
        }
        let distance: String? = {
            guard scope != .year, scope != .all,
                  let journey = snapshot?.weightJourney else { return nil }
            var line = journey.changeLine()
            if let goal = journey.goalLine() { line += ". \(goal)" }
            return line + "."
        }()
        return BecomingTile(
            kind: .weight,
            title: "weight",
            value: weight.value,
            meetsFloor: true,
            chart: weight.chart,
            read: period.text,
            readItalic: period.italic,
            mechanism: (review?.mechanisms.isEmpty == false)
                ? review!.mechanisms.joined(separator: ". ") + "."
                : weight.mechanism,
            provenance: weight.provenance,
            spanLabel: weight.spanLabel,
            deltaWord: distance,
            summaryPairs: weight.summaryPairs,
            planLine: weight.planLine
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
                // p74 — THE LENS OWNS THE SENTENCE: the period's own
                // read leads (week band · month/3-month window +
                // rate · whole distance at year/all), and the
                // distance stands quietly beneath at every other
                // lens — the one number people screenshot never
                // leaves the page.
                ItalicAccentText(
                    heroPeriodLine.text,
                    italic: heroPeriodLine.italic,
                    baseFont: .custom("DMSans-Regular", size: 12.5, relativeTo: .caption),
                    italicFont: .custom("DMSans-Medium", size: 12.5, relativeTo: .caption)
                )
                .fixedSize(horizontal: false, vertical: true)
                if let distance = heroDistanceLine {
                    Text(distance)
                        .font(.custom("DMSans-Regular", size: 11.5, relativeTo: .caption2))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                    accessibilityText: "weight, \(weight.spanLabel ?? "four weeks")",
                    // p74 — the dose seams reach the hero: a change
                    // inside the drawn window is exactly the context
                    // the chart exists to carry (timing, never
                    // causality — the seam says when, nothing else).
                    showMarkers: !weight.chart.markers.isEmpty
                )
                .padding(.top, 4)
            }

            Button { expand(bodyTile, from: heroFrame) } label: {
                // p73 — .lastTextBaseline: when the words wrap at AX
                // sizes the chevron used to float beside the FIRST
                // line's end, mid-air (SE·AX5 filmed).
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    // p74 — the door opens the full weight story
                    // (chart, ledger, eras) at any lens; "read the
                    // whole week" claimed a window the lens may not
                    // be showing. One stable name (the p73 law).
                    Text("the whole story")
                        .font(.custom("DMSans-Medium", size: 12.5, relativeTo: .caption))
                        .foregroundStyle(Palette.textSecondary)
                    // p63 — the disclosure mark was 9pt, smaller than
                    // the word it serves; 12 is the app's chevron
                    // floor (the dose row's own size).
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .contentShape(Rectangle())
                .padding(.bottom, -12)
            }
            .buttonStyle(JKPress())
            .accessibilityLabel("the whole story. opens the weight page")
        }
        }
        .accessibilityElement(children: .contain)
    }

    private var weightTile: BecomingTile? {
        tiles.first(where: { $0.kind == .weight })
    }

    /// p74 — the dose seat's face: dose · weeks at it · the current
    /// era's own standing (a young era says "early to read" right on
    /// the face — the era ledger's first row is always the current
    /// era). Opens the medication page through the same expansion.
    private func doseSeatCard(_ tile: BecomingTile) -> some View {
        Button {
            expand(tile, from: tileFrames[tile.id] ?? .zero)
        } label: {
            JeniSurface(radius: Radius.card, padding: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    // p73's composition law: at AX the eyebrow pair
                    // stacks (side-by-side each wrapped to three
                    // lines, filmed SE·AX5).
                    if typeSize.isAccessibilitySize {
                        Text("YOUR DOSE")
                            .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                            .kerning(1.2)
                            .foregroundStyle(Palette.cocoaTertiary)
                        if let weeks = tile.faceCaption {
                            Text(weeks)
                                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                    } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text("YOUR DOSE")
                            .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                            .kerning(1.2)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Spacer(minLength: Space.sm)
                        if let weeks = tile.faceCaption {
                            Text(weeks)
                                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                    }
                    }
                    // p73 stacking law at AX sizes: the pair becomes
                    // a column so neither side censors itself.
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 3) {
                            doseSeatValue(tile)
                            doseSeatStanding(tile)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                            doseSeatValue(tile)
                            Spacer(minLength: Space.sm)
                            doseSeatStanding(tile)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniPressable())
        .opacity(expandedTile?.id == tile.id ? 0 : 1)
        .background(tileFrameReporter(tile))
        .accessibilityLabel(
            "your dose, \(tile.value)"
            + (tile.faceCaption.map { ", \($0)" } ?? "")
            + ". opens the medication page"
        )
    }

    private func doseSeatValue(_ tile: BecomingTile) -> some View {
        Text(tile.value)
            .font(.custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title3))
            .monospacedDigit()
            .foregroundStyle(Palette.textPrimary)
    }

    @ViewBuilder
    private func doseSeatStanding(_ tile: BecomingTile) -> some View {
        if let row = tile.summaryPairs.first {
            Text(row.value)
                .font(.custom("DMSans-Regular", size: 12.5, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
        }
    }

    /// v21's dashboard header; p73 stacks it at accessibility sizes.
    @ViewBuilder private var mastheadPair: some View {
        let title = Text("becoming")
            .font(.custom("JeniHeroSerif-Regular", size: 28,
                          relativeTo: .title2))
            .foregroundStyle(Palette.textPrimary)
            // p70 — one word must stay one word: at AX5 the serif
            // broke "beco / ming" mid-word (filmed on the SE). Wrap
            // can't help a single word; the scale floor absorbs it —
            // the RegimenSheet title's own p51-D2 law.
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        let date = Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).lowercased())
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                title
                date
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                title
                Spacer(minLength: Space.sm)
                date
            }
        }
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

    /// p74 — the period's own sentence, by lens: the week keeps the
    /// band read, month and 3 months speak their covered window with
    /// the observed rate beside it, year/all speak the whole
    /// distance. The weight tile's read already carries the lens
    /// (BecomingStory.windowRead); this just seats it.
    private var heroPeriodLine: (text: String, italic: [String]) {
        guard let weight = weightTile, weight.meetsFloor else { return heroLine }
        switch scope {
        case .year, .all:
            return heroLine
        default:
            var text = weight.read
            if let rate = weight.deltaWord { text += " \(rate)" }
            return (text, weight.readItalic)
        }
    }

    /// The quiet distance beneath the period read — nil at year/all,
    /// where the distance IS the period read.
    private var heroDistanceLine: String? {
        guard scope != .year, scope != .all,
              weightTile?.meetsFloor == true,
              let journey = snapshot?.weightJourney else { return nil }
        var line = journey.changeLine()
        if let goal = journey.goalLine() { line += ". \(goal)" }
        return line + "."
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
    /// week keeps its own door, and when the record is too thin to
    /// claim a distance the previous line stands exactly as it did.
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
            return ("one check-in is all it takes to start.", ["one check-in"])
        }
        return ("still early. keep logging.", ["keep logging."])
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
        // p74 — weight and medication leave the grid: the hero IS the
        // weight object (its tile was a pixel duplicate directly
        // below, filmed) and the dose seat under the hero carries the
        // medication. The builder still builds both — the hero and
        // the seat render from them.
        let visible = tiles.filter {
            $0.kind != .weight && $0.kind != .medication
        }
        let live = visible.filter(\.meetsFloor)
        let leads = live.filter(\.isPrimary)
        let rest = live.filter { !$0.isPrimary }
        let waiting = visible.filter { !$0.meetsFloor }

        return VStack(alignment: .leading, spacing: 0) {
            if !leads.isEmpty {
                LazyVGrid(
                    // p73 — AX is a composition, not a squeeze: at
                    // accessibility sizes the pair of half-width
                    // tiles crammed "6,831 /" against its own edge
                    // (SE·AX5 filmed). One column, full width.
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                   count: typeSize.isAccessibilitySize ? 1 : 2),
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
                            // p74 — the empty page gets its one
                            // illustration (the doodle law's
                            // canonical site): the scale, drifting.
                            JeniDoodle(name: "doodle-scale", size: 110)
                                .frame(maxWidth: .infinity)
                                .padding(.top, Space.sm)
                            ItalicAccentText(
                                "not enough logged yet to read.",
                                italic: ["yet"],
                                baseFont: .custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title3),
                                italicFont: .custom("JeniHeroSerif-Italic", size: 22, relativeTo: .title3),
                                color: Palette.textPrimary,
                                alignment: .leading
                            )
                            Text("log plates and weigh-ins for about three days and this page starts talking.")
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
                    // p62 — "not enough to read yet" contradicted the
                    // rows beneath it: weight shows 163.6 lb and body
                    // fat shows its band right under a header claiming
                    // there is nothing to read (the header meant "no
                    // TREND yet" — engine language). "still filling
                    // in" is true for every row: a trend needs days,
                    // movement needs a connection, an estimate needs a
                    // measurement.
                    JeniSectionHeader("still filling in", topAir: Space.bandGap)
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
            JeniRow("your plates", detail: "every meal, with its photo",
                    trailing: .chevron, action: { showFoodJournal = true })
            // v25 §34 — the weigh-ins finally have a door.
            //
            // The tile above draws the LINE, which is the right hero and
            // the wrong record: a trend cannot be read for a date and
            // cannot be touched. Every other record in the product has a
            // list you can open and repair (plates here, doses in the
            // regimen home, symptoms as chips) — the one number the
            // daily targets are actually built from did not.
            //
            // Suppressed cohorts get no weight numerals anywhere, so the
            // door itself does not appear for them.
            if !CohortStore.isNumericSuppressed {
                JeniRow("your weigh-ins", detail: "every number, with its date",
                        trailing: .chevron, action: { showWeighIns = true })
            }
            if let due = dueReview {
                JeniRow("your week is ready to read",
                        detail: "takes about a minute",
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

    /// p76 — the page's one arrival, armed at the first actual visit
    /// (never at mount, never behind an await). One brief beat so the
    /// tab switch lands before the assembly begins; runs once per
    /// process. Reduce Motion inherits jeniArrive's own behavior.
    private func armArrival() {
        guard !arrived else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            arrived = true
        }
    }

    private func refresh() {
        guard !userId.isEmpty else { return }
        let snap = TodayStateService.snapshot(userId: userId, in: modelContext)
        snapshot = snap
        bodyScans = BodyScanStore.all(userId: userId, in: modelContext)
        loadPlates()
        let weightDays = WeightSeries.samples(userId: userId, in: modelContext)
            .map(\.day)
        recordSpanDays = weightDays.min().map {
            Calendar.current.dateComponents(
                [.day], from: Calendar.current.startOfDay(for: $0),
                to: Calendar.current.startOfDay(for: .now)
            ).day ?? 0
        } ?? 0
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
            weightSamples: WeightSeries.samples(
                userId: userId, in: modelContext
            ),
            scope: scope
        )
        composeReview()

        // The re-signing offer's ELIGIBILITY only — presentation moved
        // to runAutoPresent() (p62): refresh() runs on every plate
        // log, scan change and scope tap, and scheduling from here
        // stamped the once-per-week flag before anything presented.
        let journey = JourneyModel.load(userId: userId, snapshot: snap, in: modelContext)
        dueReview = journey.dueReview
    }

    /// p62 — becoming's director, the same grammar as Home's: runs
    /// only at an ARRIVAL (tab arrival · appear · foreground while
    /// visible), waits the one settle beat, re-checks against its own
    /// covers AND the shared gate, and stamps the once-per-week flag
    /// only when the read actually presents. A loser keeps its
    /// eligibility; "read the whole week" stays the mid-session door.
    private func runAutoPresent() {
        guard BecomingAutoPresent.shouldOffer(
            dueWeekIndex: dueReview?.weekIndex,
            offeredWeek: autoOfferedReviewWeek,
            onBecoming: router.tab == .becoming
        ), let scheduled = dueReview?.weekIndex else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + HomeAutoPresent.settleBeat) {
            guard BecomingAutoPresent.mayPresent(
                stillDueWeekIndex: dueReview?.weekIndex,
                scheduledWeekIndex: scheduled,
                siblingSurfaceUp: anyBecomingSurfaceUp,
                onBecoming: router.tab == .becoming,
                gateOccupied: PresentationGate.shared.occupied(besides: .becoming)
            ), let due = dueReview else { return }
            autoOfferedReviewWeek = due.weekIndex
            // The cover materializes and the read owns its own
            // motion — one grammar with the letter and the close.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { presentedReview = due }
        }
    }

    /// Becoming's contribution to the one-modal-slot truth: the five
    /// record covers, the weekly read, and the in-tree tile expansion.
    private var anyBecomingSurfaceUp: Bool {
        showCompare || showWeighIns || showFoodJournal || showVisitPacket
            || presentedReview != nil || expandedTile != nil || showDistance
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
            DispatchQueue.main.asyncAfter(deadline: .now() + HomeAutoPresent.settleBeat) {
                showFoodJournal = true
            }
        case .weeklyRead:
            router.pendingRoute = nil
            if let due = dueReview, presentedReview == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + HomeAutoPresent.settleBeat) {
                    // A moment-cover materializes even when she asked
                    // for it — one grammar with the letter's door.
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { presentedReview = due }
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
        // p54 — the trend story speaks from the canonical read (the
        // same fold as the tile beneath it and the delta fields two
        // lines down). Its private fast EMA — the last ungated weight
        // sentence a customer could read — is gone.
        let story = InsightEngine.trendStory(
            read: WeightSeries.read(userId: userId, in: modelContext),
            week: week,
            numericsSuppressed: snap.targets.numericsSuppressed
        )
        input.trendLine = story?.line
        input.trendItalic = story?.italic ?? []
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
        input.strengthSessions7 = MethodInputBuilder.preservationStrength(
            everRequested: MovementService.shared.everRequested,
            healthKit: MovementService.shared.strengthSessionsLast7,
            entered: MoveManualStore.strengthLastWeek()
        )
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
        // p53 — RHR joins the recovery read (the H1 render).
        input.restingHRLatest = VitalsService.shared.read.restingHR7d
        input.restingHRBaseline = VitalsService.shared.read.restingHRBaseline
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
