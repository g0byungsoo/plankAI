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
    @State private var expandDrag: CGFloat = 0
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
                    JeniInsightPager(
                        insights: insights,
                        tourAutoAdvance: ProcessInfo.processInfo.arguments
                            .contains("--uitest-walk-scope")
                    )
                    .padding(.top, Space.sectionGap)
                    .jeniArrive(arrived, index: 2)
                }

                VStack(alignment: .leading, spacing: 0) {
                    JeniSectionHeader("your numbers")
                    JeniScopeBar(scope: $scope)
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
            // v15 — the landing is a SHEET, not a floating card: the
            // surface rises to full bleed and stops just under the
            // status bar, the way Apple's sheets do. A 10pt inset all
            // round read as "a big card someone forgot to finish";
            // full width + a single top radius reads as a place.
            let target = CGRect(
                x: 0,
                y: geo.safeAreaInsets.top + 6,
                width: geo.size.width,
                height: geo.size.height + geo.safeAreaInsets.top - 6
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

                UnevenRoundedRectangle(
                    topLeadingRadius: 20 + 18 * p,
                    bottomLeadingRadius: 20 * (1 - p),
                    bottomTrailingRadius: 20 * (1 - p),
                    topTrailingRadius: 20 + 18 * p,
                    style: .continuous
                )
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.textPrimary.opacity(0.08 * Double(p)),
                            radius: 28, y: -2)
                    .overlay(alignment: .topLeading) {
                        // v15 — THE SHARED ELEMENT, without matched
                        // geometry. The page's content is laid out at
                        // its FINAL width and scaled by the surface's
                        // own growth ratio, top-left anchored. At the
                        // start of the flight that scale renders the
                        // 44pt hero at ~19pt — exactly the tile's
                        // value size, in exactly the tile's position,
                        // under exactly the tile's caps label. So the
                        // tile's words BECOME the page's headline and
                        // nothing reflows en route. (The old build
                        // gated content behind the whole spring and
                        // showed ~0.4s of white void — frame-caught.)
                        expandedContent(tile)
                            .padding(.horizontal, Space.gutter)
                            .padding(.top, Space.xl)
                            .frame(width: target.width, alignment: .topLeading)
                            .scaleEffect(
                                max(0.05, rect.width / max(1, target.width)),
                                anchor: .topLeading
                            )
                            .opacity(contentReady ? 1 : 0)
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

                Group {
                JeniHeadline(tile.read, italic: tile.readItalic)
                    .padding(.top, Space.sectionGap)

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
                }
                .jeniArrive(landed, index: 1)

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
            expandDrag = 0
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

    /// v13: the hero left its card — the page's one hero is
    /// typography and a chart ON the paper, the way the consult
    /// opens. Requirement-explanations ("needs 4 logged days…") left
    /// the face for the expanded read: a hero states, it never
    /// apologizes.
    private var heroFace: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("BODY")
                .font(.custom("DMSans-SemiBold", size: 11, relativeTo: .caption2))
                .tracking(1.6)
                .foregroundStyle(Palette.cocoaTertiary)

            JeniHeadline(heroLine.text, italic: heroLine.italic)

            ForEach(heroSupportLines, id: \.self) { line in
                Text(line)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            if let weight = tiles.first(where: { $0.kind == .weight }),
               !weight.chart.isEmpty {
                JeniChart(
                    model: weight.chart,
                    height: 84,
                    endLabels: ("\(weight.spanLabel ?? "4 weeks") ago", "today"),
                    filled: true,
                    accessibilityText: "weight, \(weight.spanLabel ?? "four weeks")"
                )
                .padding(.top, Space.md)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The face's supporting lines: real observations only, at most
    /// two. Anything explaining what's MISSING waits for the page.
    private var heroSupportLines: [String] {
        var lines = review?.mechanisms ?? []
        if let preservation = review?.preservation {
            lines.append(preservation.line)
        }
        return Array(lines.filter { !$0.contains("needs") }.prefix(2))
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

    /// Design law §12.9 + §1.7: a metric with nothing to say does not
    /// earn a tile. Eleven identical squares — five of them repeating
    /// "logging · 0 of 3 days" — was the uniform-card-grid tell the
    /// law hunts by name. Metrics that READ keep the grid; metrics
    /// still waiting collapse into canonical rows that open the same
    /// page from the same morph.
    private var gridBody: some View {
        let live = tiles.filter(\.meetsFloor)
        let waiting = tiles.filter { !$0.meetsFloor }

        return VStack(alignment: .leading, spacing: 0) {
            if !live.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: Space.md),
                              GridItem(.flexible(), spacing: Space.md)],
                    spacing: Space.md
                ) {
                    ForEach(Array(live.enumerated()), id: \.element.id) { i, tile in
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

            if !waiting.isEmpty {
                // Honest for every row underneath: weight may HAVE a
                // number but not yet a trend; movement isn't connected;
                // the nutrients need more logged days. All of them are
                // short of what it takes to read (§1.6).
                JeniSectionHeader("not enough to read yet")
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
            // C8: for care patients the section leads and speaks
            // clinically; consumers keep the record framing.
            JeniSectionHeader(careActive ? "your care" : "your record")
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
