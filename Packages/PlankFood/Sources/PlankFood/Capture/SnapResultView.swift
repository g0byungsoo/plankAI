#if canImport(UIKit)
import SwiftUI

// MARK: - SnapResultView
//
// v23 THE STILL LIFE §5 — THE READING. One page in reading order on
// the two-detent panel; the carousel died (navigation was spending
// the screen's one idea). The photograph stays the hero above:
//
//   context line (time · meal) → the name → THE NUMERAL (counted
//   kcal + the ± band) → PROTEIN (the one collected floor) → THE
//   SPLIT (what the plate's energy was made of) → THE LEDGER
//   (carbs · fat · fiber · sugar · sodium as hairline rows — no
//   bars: no collected denominator) → THE ITEMS (editable, portion
//   steppers, the refine composers) → THE FRACTION → WHAT JENI
//   NOTICED (the note came home to the page) → the footer ("add it").
//
// The share composer is an overlay state over the same steady photo
// (`page == 2` — the host's chrome contract unchanged).
//
// All mutation routes through PlateEditSession (SnapResultMath.swift);
// this file is presentation + choreography only. One grammar for
// every source: photo, barcode, label, described (S3).

public struct SnapResultView: View {
    var userId: String = ""

    let initialFood: CapturedFood
    let mealLabel: String
    let dishName: String
    let onLog: (CapturedFood) -> Void
    let onRetake: () -> Void
    /// Fired on every committed edit with the rebuilt plate so the
    /// host's mirror (persist + share) stays in sync.
    let onEdited: (CapturedFood) -> Void
    /// The natural-language refine pipeline ("fix it with words" +
    /// "+ add something"). nil hides both affordances (previews).
    let refine: ((SnapRefineRequest) async throws -> SnapRefineOutcome)?
    /// Page state (0 reading · 2 share overlay). Host-owned so the
    /// floating chrome can swap with it and debug args can jump.
    @Binding var page: Int
    /// v23 pass 2 — a chip tapped on the photograph hands its item id
    /// down; the reading expands and flashes the row. Host-owned.
    @Binding var highlightID: String?

    @State private var session: PlateEditSession
    /// The row currently flashing blush (chip → row).
    @State private var flashedRowID: String?
    @State private var flashTask: Task<Void, Never>?
    @State private var revealed: Int = 0
    @State private var expanded: Bool = false
    @State private var editingItemID: String? = nil
    /// Rise-in on arrival — the panel owns its entrance (spring from
    /// 44pt below + fade) so the host stage can stay a plain
    /// cross-dissolve. Content cascade runs on top of this.
    @State private var risen: Bool = false
    @GestureState private var dragTranslation: CGFloat = 0

    /// Inline composer for the two natural-language affordances. One
    /// at a time; the field expands in place of its trigger row.
    private enum Composer { case addItem, fixWords }
    @State private var composer: Composer? = nil
    @State private var composerText: String = ""
    @State private var refining: Bool = false
    @State private var refineErrorLine: String? = nil
    /// v25 E7 SAY IT — non-nil the moment "add it" lands: the reading
    /// resolves to one sentence in the grid's place, then files.
    @State private var answer: FoodModule.PlateAnswer? = nil
    /// Second phase of the same beat — see `fileIt()`.
    @State private var answerVisible = false
    @FocusState private var composerFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("onboardingCurrentWeightKg") private var currentWeightKg: Double = 0
    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""
    @AppStorage("foodDailyTarget") private var foodDailyTarget: Double = 0

    var loggedAt: Date = Date()

    /// v23 — the share composer needs a photograph to render; the
    /// described path passes false and the footer stays two verbs.
    var allowsShare: Bool = true
    /// p53 — set when the reading came from her own record (a usual);
    /// the banner's "count it fresh" runs the estimate she skipped.
    var onEstimateFresh: (() -> Void)? = nil

    public init(
        userId: String = "",
        food: CapturedFood,
        mealLabel: String,
        dishName: String,
        page: Binding<Int>,
        highlightID: Binding<String?> = .constant(nil),
        allowsShare: Bool = true,
        onLog: @escaping (CapturedFood) -> Void,
        onRetake: @escaping () -> Void,
        onEdited: @escaping (CapturedFood) -> Void,
        refine: ((SnapRefineRequest) async throws -> SnapRefineOutcome)? = nil,
        onEstimateFresh: (() -> Void)? = nil
    ) {
        self.userId = userId
        self.initialFood = food
        self.mealLabel = mealLabel
        self.dishName = dishName
        _page = page
        _highlightID = highlightID
        self.allowsShare = allowsShare
        self.onLog = onLog
        self.onRetake = onRetake
        self.onEdited = onEdited
        self.refine = refine
        self.onEstimateFresh = onEstimateFresh
        _session = State(initialValue: PlateEditSession(food: food))
    }

    /// p53 — the usual banner's middle words.
    private func usualNote(_ usual: CapturedFood.UsualApplied) -> String {
        var note = usual.timesLogged == 1
            ? " · from your record"
            : " · logged \(usual.timesLogged) times"
        if usual.verified { note += " · with your fixes" }
        return note
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            // v25 E7 — the peek was 0.62 of the screen, sized for the
            // old 2×2 grid. The reading now carries a protein lead, a
            // split, fiber/sugar/sodium AND the micronutrients the
            // founder asked to see, and every one of those sat below
            // the fold at rest. Two thirds, matching the app-wide
            // JeniSheetHeight standard set in the same era.
            let peekHeight = min(geo.size.height * 0.72, 660)
            // Full detent leaves ~120pt of photo so the floating X stays
            // on the photo, never stranded over the cream card.
            let fullHeight = min(geo.size.height * 0.92, geo.size.height - 120)
            let baseHeight = expanded ? fullHeight : peekHeight
            let liveHeight = rubberBanded(
                baseHeight - dragTranslation,
                lo: peekHeight, hi: fullHeight
            )

            // v23 — one page. The share composer overlays the same
            // steady photo when asked (page == 2); the dots died with
            // the carousel.
            ZStack(alignment: .top) {
                if page == 2 {
                    shareSlide
                        .transition(.opacity)
                } else {
                    panelSlide(liveHeight: liveHeight, peek: peekHeight, full: fullHeight) {
                        platePage
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: page == 2)
        }
        .onChange(of: page) { _, _ in
            // A page swap shouldn't strand the composer keyboard over
            // the share overlay.
            composerFocused = false
        }
        // v23 pass 2 — chip → row: the reading expands and the row
        // flashes blush once, then the channel clears for the next tap.
        .onChange(of: highlightID) { _, id in
            guard let id else { return }
            setExpanded(true)
            flashTask?.cancel()
            withAnimation(.easeOut(duration: 0.2)) { flashedRowID = id }
            flashTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.5)) { flashedRowID = nil }
                highlightID = nil
            }
        }
        .onAppear {
            if reduceMotion {
                risen = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    risen = true
                }
            }
            runCascade()
            #if DEBUG
            // v25 E7 — film THE ANSWER (simctl cannot tap the pill).
            if filmTheAnswer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { fileIt() }
            }
            if ProcessInfo.processInfo.arguments.contains("--debug-result-expanded") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        expanded = true
                    }
                }
            }
            // Sim QA: auto-open a composer for screenshot capture.
            if ProcessInfo.processInfo.arguments.contains("--debug-composer-fix") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    openComposer(.fixWords)
                }
            } else if ProcessInfo.processInfo.arguments.contains("--debug-composer-add") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    openComposer(.addItem)
                }
            }
            #endif
            #if DEBUG
            // Sim QA: `--debug-edit-sheet` auto-opens the editor on the
            // first item so the harness can screenshot it without taps.
            if ProcessInfo.processInfo.arguments.contains("--debug-edit-sheet"),
               let first = session.effectiveItems.first,
               editingItemID == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    editingItemID = first.id
                }
            }
            #endif
        }
        .sheet(item: editingBinding) { box in
            IngredientEditorSheet(
                original: box.item,
                scanBaseline: session.baselineItem(box.item.id),
                onSave: { updated in
                    commit { $0.replace(updated) }
                    editingItemID = nil
                },
                onRemove: {
                    commit { $0.remove(box.item.id) }
                    editingItemID = nil
                },
                onCancel: { editingItemID = nil }
            )
            // .medium folds the carbs/fat row under the pinned action
            // bar; 0.72 shows the full number grid with the keyboard
            // still able to push to .large.
            .presentationDetents([.fraction(0.72), .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Carousel slides

    /// The shared two-detent panel chrome. Slides 1-2 each wrap their
    /// content in this so the whole panel carousels TikTok-style (card
    /// slides as one object); the detent state is shared, so a swap
    /// mid-expanded keeps the height.
    @ViewBuilder
    private func panelSlide<Content: View>(
        liveHeight: CGFloat, peek: CGFloat, full: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            header
                .contentShape(Rectangle())
                .gesture(detentDrag(peek: peek, full: full))

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    content()
                }
                .padding(.horizontal, 22)
                .padding(.top, 2)
                // The footer floats over this scroll view with a paper
                // fade; 18pt left the last row (fiber · sugar intake ·
                // sodium) sheared in half behind it at the peek
                // detent. Frame-caught.
                .padding(.bottom, 74)
            }
            .scrollDismissesKeyboard(.interactively)
            // v25 E7 — the reading is taller than the peek detent by
            // design, but at rest its last row (fiber · sugar intake ·
            // sodium) came to rest sheared exactly in half against the
            // scroll view's own clip. A soft bottom edge dissolves the
            // overflow instead, so "there is more below" reads as an
            // invitation rather than a rendering fault. Frame-caught.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.9),
                        .init(color: .black.opacity(0), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )

            footer
        }
        .frame(height: liveHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(cardChrome)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .offset(y: risen ? 0 : 44)
        .opacity(risen ? 1 : 0)
        .animation(
            reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.86),
            value: expanded
        )
    }

    /// THE READING (§5) — one page in reading order: the numbers,
    /// the plate's items, the honest portion, the correction levers,
    /// then what jeni noticed. Nothing to swipe for.
    @ViewBuilder private var platePage: some View {
        heroBlock.cascade(1, revealed)
        // v25 E7 — while the plate files, everything below the answer
        // steps back so the sentence is the only thing on the page.
        // Not removed: removal would collapse the sheet's height and
        // the panel would shrink under her thumb mid-read.
        Group {
            hairline.cascade(2, revealed)
            ledger.cascade(2, revealed)
            fractionChips.cascade(3, revealed)
            if refine != nil {
                composerBlock.cascade(4, revealed)
            }
            hairline.cascade(5, revealed)
            noteBlock.cascade(5, revealed)
        }
        .opacity(answer == nil ? 1 : 0)
        .allowsHitTesting(answer == nil)
        .animation(.easeOut(duration: 0.28), value: answer == nil)
    }

    /// Slide 3 — the on-photo share composer. SnapShareSlide draws
    /// overlay-only (embedsPhoto: false down the stack), so the host's
    /// steady photo backdrop shows through and the swipe reads as the
    /// composer chrome sliding in over the plate.
    private var shareSlide: some View {
        SnapShareSlide(
            photo: nil,
            mealLabel: mealLabel,
            dishName: dishTitleText,
            itemNames: session.effectiveItems.map { $0.name },
            totals: shareTotals()
        )
    }

    private func shareTotals() -> (carbs: Int, protein: Int, fat: Int, fiber: Int, kcal: Int) {
        let food = session.rebuiltFood()
        return (
            carbs: Int(food.items.compactMap { $0.carbsG }.reduce(0, +).rounded()),
            protein: Int(food.items.compactMap { $0.proteinG }.reduce(0, +).rounded()),
            fat: Int(food.items.compactMap { $0.fatG }.reduce(0, +).rounded()),
            fiber: Int(food.items.compactMap { $0.fiberG }.reduce(0, +).rounded()),
            kcal: displayKcal(session.totals)
        )
    }

    // MARK: - Edit plumbing

    private struct EditingBox: Identifiable {
        let item: CapturedItem
        var id: String { item.id }
    }

    private var editingBinding: Binding<EditingBox?> {
        Binding(
            get: {
                guard let id = editingItemID,
                      let item = session.item(id) else { return nil }
                return EditingBox(item: item)
            },
            set: { editingItemID = $0?.item.id }
        )
    }

    /// Single funnel for every mutation: apply, then hand the rebuilt
    /// plate up so the host mirror stays true.
    ///
    /// Release audit 2026-08-08: the correction signal died with the
    /// old Result/ subtree — every portion step, add, remove, and edit
    /// on THE READING went analytics-dark exactly when the pipeline
    /// changed (the corrections-as-moat metric flatlined). This funnel
    /// is the one seam every mutation crosses, so the event lives here.
    private func commit(_ mutate: (inout PlateEditSession) -> Void) {
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.28)) {
            mutate(&session)
        }
        FoodAnalytics.track(.scanCorrectionSaved, properties: ["surface": "reading"])
        onEdited(session.rebuiltFood())
    }

    /// v25 E4 — one-tap revert of an applied prior: the model's
    /// original plate, exactly restored (its own analytics event, not
    /// a correction).
    private func revertPrior() {
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.28)) {
            session.rebase(on: PlatePriors.revert(session.rebuiltFood()))
        }
        FoodAnalytics.track(.priorApplied, properties: [
            "kind": "dish_numbers", "action": "reverted",
        ])
        onEdited(session.rebuiltFood())
    }

    // MARK: - Detent drag

    private func detentDrag(peek: CGFloat, full: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.height
                if projected < -40 {
                    setExpanded(true)
                } else if projected > 40 {
                    setExpanded(false)
                }
            }
    }

    private func setExpanded(_ value: Bool) {
        guard expanded != value else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        expanded = value
    }

    /// Soft clamp with 0.22 resistance past the detent bounds so the
    /// card breathes at the edges instead of hitting a wall.
    private func rubberBanded(_ x: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        if x < lo { return lo - (lo - x) * 0.22 }
        if x > hi { return hi + (x - hi) * 0.22 }
        return x
    }

    // MARK: - Chrome

    private var cardChrome: some View {
        // v23 — the page is PAPER (the token, not a bespoke cream),
        // separated from the photograph by fill + one soft shadow.
        // The stroke overlay died with the border law (§6.1).
        UnevenRoundedRectangle(
            topLeadingRadius: 28, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 28,
            style: .continuous
        )
        .fill(FoodTheme.bgPrimary)
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: -8)
        .ignoresSafeArea(edges: .bottom)
    }

    private var hairline: some View {
        Rectangle()
            .fill(FoodTheme.textPrimary.opacity(0.10))
            .frame(height: 0.5)
    }

    // MARK: - Header (grabber + meta + dish title)

    @ViewBuilder private var header: some View {
        // v23 pass 5 (founder) — minimal words, instruments first:
        // the meal tag + time lead, the name and THE PLATE STEPPER
        // share one row (the reference's serving control position).
        // The confidence word retired — the fix affordances carry it.
        VStack(alignment: .leading, spacing: 8) {
            Capsule()
                .fill(FoodTheme.textPrimary.opacity(0.18))
                .frame(width: 36, height: 4.5)
                .frame(maxWidth: .infinity)
                .padding(.top, 9)
                .padding(.bottom, 3)

            HStack(spacing: 8) {
                Text(mealLabel.isEmpty ? "today" : mealLabel.lowercased())
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(FoodTheme.textPrimary.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(FoodTheme.accentSubtle.opacity(0.6)))
                Text(timeLabel)
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(FoodTheme.textSecondary)
                Spacer(minLength: 0)
            }

            // At accessibility sizes the stepper and the title cannot
            // share a row: filmed at AX5, "pepperoni pizza" came back as
            // "pepp / ero…" while the stepper held half the width for
            // "1,08…". Both were truncated to make room for each other.
            // Stacking is the same fix the last pass made in
            // `JKSheetChrome` — give the words their wrapped height
            // rather than hiding them to preserve a horizontal layout
            // that no longer fits.
            if dynamicTypeSize.isAccessibilitySize {
                dishTitle
                HStack { plateStepper; Spacer(minLength: 0) }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    dishTitle
                    Spacer(minLength: 8)
                    plateStepper
                }
            }

            // WHAT THE NUMBERS ARE OF, BEFORE THEY ARE STATED.
            //
            // Found by filming, not by reading code. In the collapsed
            // detent — the state the reading opens in — a whole 12-inch
            // pizza said "96 g of 90 g today" with the protein floor met
            // and a full bar, "2,200 kcal", and "a little over today".
            // Every one of those is a claim about a dish for eight, and
            // the only thing that could say so was the ladder's caption,
            // below the fold.
            //
            // A subject belongs before its predicate. It sits under the
            // dish name, where the plate stepper already establishes
            // scale, so no number on this surface is read before the
            // thing it describes is named.
            if let note = PlateShare.wholeDishNote(for: session.sourceFood) {
                Text(note)
                    .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                    .foregroundStyle(FoodTheme.textPrimary.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 9)
        .cascade(0, revealed)
        .accessibilityAddTraits(.isHeader)
    }

    private var timeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: loggedAt).lowercased()
    }

    @ViewBuilder private var dishTitle: some View {
        let text = dishTitleText
        if !text.isEmpty {
            Button {
                guard let first = session.effectiveItems.first else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                editingItemID = first.id
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(text)
                        .font(.custom("JeniHeroSerif-Italic", size: 20))
                        .foregroundStyle(FoodTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FoodTheme.accent.opacity(0.6))
                        .baselineOffset(2)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .disabled(session.effectiveItems.isEmpty)
            .accessibilityLabel("\(text), tap to edit")
        }
    }

    private var dishTitleText: String {
        let name = dishName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name.foodNameCleaned.lowercased() }
        return session.effectiveItems.prefix(2)
            .map { $0.name.foodNameCleaned.lowercased() }
            .joined(separator: ", ")
    }

    // MARK: - THE METRIC GRID (v23 pass 5 — chart-driven, few words)

    /// v25 E7 SAY IT — PROTEIN LEADS.
    ///
    /// This grid used to open on CALORIES: top-left, the largest
    /// numeral, the only ring, captioned "37% of today". The product's
    /// own law says the opposite. `00_THE_SYSTEM` §9: "protein floor +
    /// fiber lead the glance layer; kcal quiet" — because §7.6's
    /// literature review found exactly two proven GLP-1 content
    /// pillars, and protein 1.2-2.0 g/kg is one of them (lean mass is
    /// 25-40% of drug-induced loss). For someone eating 1,100 kcal on
    /// an appetite suppressant, the calorie count is the fact she
    /// needs least and the one most likely to be read as a grade.
    ///
    /// So: protein takes the full width and the largest numeral, with
    /// the day's floor as its denominator — the number that decides
    /// whether the weight coming off is fat or muscle. Calories, carbs
    /// and fat become one quiet row of three. The kcal RING is deleted
    /// rather than moved: a ring is the loudest object this system
    /// owns, and "37% of today" was a percentage of a budget on a
    /// surface that is not allowed to grade her.
    @ViewBuilder private var heroBlock: some View {
        // v25 E7 — the grid IS the sentence's origin: when the plate
        // files, the four figures collapse and one line rises in the
        // space they occupied.
        // TWO PHASES, never a cross-fade. Frame review caught the
        // single-swap version rendering the sentence ON TOP of the
        // half-faded grid for ~80ms — two type sizes of the same words
        // overlapping, which is exactly the "pop" this era set out to
        // hunt. The grid leaves first; the sentence arrives into the
        // space it vacated.
        ZStack(alignment: .topLeading) {
            if !answerVisible {
                heroGrid
                    .opacity(answer == nil ? 1 : 0)
                    .scaleEffect(
                        answer == nil || reduceMotion ? 1 : 0.96,
                        anchor: .center
                    )
            }
            if answerVisible, let answer {
                answerBlock(answer)
                    .transition(.asymmetric(
                        insertion: reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .offset(y: 12)),
                        removal: .opacity
                    ))
            }
        }
    }

    @ViewBuilder private var heroGrid: some View {
        let totals = session.totals
        VStack(alignment: .leading, spacing: 8) {
            let p = totals.protein * 4, c = totals.carbs * 4, f = totals.fat * 9
            let energy = max(1, p + c + f)
            let proteinTarget = FoodModule.proteinTargetProvider?()

            proteinLead(totals: totals, target: proteinTarget)

            // THE SPLIT (founder steer 2026-08-11: "maybe use pie
            // chart instead of bar charts ... to utilize the space
            // better"). One donut replaces FOUR objects — three
            // per-cell bars plus the full-width split bar — and the
            // legend beside it carries the grams the bars only implied.
            // Half the height, more information, one shape.
            splitBlock(totals: totals, c: c, f: f, p: p, energy: energy)

            chemistryBlock
                .padding(.top, 2)

            // v25 E4 — THE PLATE'S MEMORY provenance: when her own
            // corrected record rewrote this scan, the reading says so
            // and offers the scan back in one tap. A silent override
            // would be a silent override of her next correction.
            if session.sourceFood.priorApplied != nil {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(FoodTheme.textSecondary)
                        .accessibilityHidden(true)
                    (Text("your numbers")
                        .font(.custom("JeniHeroSerif-Italic", size: 13))
                        .foregroundColor(FoodTheme.textPrimary)
                    + Text(" · you fixed this dish before")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundColor(FoodTheme.textSecondary))
                    Spacer(minLength: 8)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        revertPrior()
                    } label: {
                        Text("use the scan")
                            .font(.custom("DMSans-Medium", size: 12))
                            .foregroundColor(FoodTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().stroke(
                                    FoodTheme.textPrimary.opacity(0.22),
                                    lineWidth: 0.8
                                )
                            )
                    }
                    .accessibilityLabel("use the scan's numbers instead")
                }
                .padding(.top, 6)
            }

            // p53 — THE ANSWERING RECORD provenance: this reading is
            // her own filed plate answering the same words (or the
            // same package). Named, never silent; the fresh estimate
            // stays one tap away.
            if let usual = session.sourceFood.usualApplied {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(FoodTheme.textSecondary)
                        .accessibilityHidden(true)
                    (Text("your usual")
                        .font(.custom("JeniHeroSerif-Italic", size: 13))
                        .foregroundColor(FoodTheme.textPrimary)
                    + Text(usualNote(usual))
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundColor(FoodTheme.textSecondary))
                    Spacer(minLength: 8)
                    if let onEstimateFresh {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onEstimateFresh()
                        } label: {
                            Text(usual.via == .barcode
                                 ? "use the package" : "count it fresh")
                                .font(.custom("DMSans-Medium", size: 12))
                                .foregroundColor(FoodTheme.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().stroke(
                                        FoodTheme.textPrimary.opacity(0.22),
                                        lineWidth: 0.8
                                    )
                                )
                        }
                        .accessibilityLabel(usual.via == .barcode
                            ? "use the package's numbers instead"
                            : "estimate it fresh instead")
                    }
                }
                .padding(.top, 6)
            }

            // p53 — the physics line: when the plate's energy and its
            // own macros disagree by more than a quarter, say so once,
            // quietly. Report, never grade; her call what to do.
            if SnapResultMath.plateDisagrees(session.rebuiltFood()) {
                Text("these numbers disagree with each other — worth a look")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundColor(FoodTheme.textSecondary)
                    .padding(.top, 6)
                    .accessibilityLabel("the calories and macros disagree with each other. worth a look.")
            }

            // THE DAY LINE — short and gain-framed; target-less users
            // never see it.
            if let day = dayLine(totals) {
                (Text(day.prefix)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(FoodTheme.textSecondary)
                + Text(day.punch)
                    .font(.custom("JeniHeroSerif-Italic", size: 15))
                    .foregroundColor(FoodTheme.textPrimary)
                + Text(day.suffix)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(FoodTheme.textSecondary))
                    .padding(.top, 2)
                    .accessibilityLabel("\(day.prefix)\(day.punch)\(day.suffix)")
            }
        }
    }

    // MARK: - The protein lead
    //
    // Full width, the largest numeral on the page, and the ONLY cell
    // that carries a denominator — because it is the only one whose
    // denominator was collected rather than computed. No floor on file
    // (no weight) → no denominator and no bar, per the provenance
    // rule; the grams still render, because those are hers.

    @ViewBuilder
    private func proteinLead(totals: PlateTotals, target: Int?) -> some View {
        let grams = Int(totals.protein.rounded())
        VStack(alignment: .leading, spacing: 6) {
            Text("PROTEIN")
                .font(.custom("DMSans-Medium", size: 10))
                .kerning(1.0)
                .foregroundStyle(FoodTheme.textSecondary.opacity(0.85))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                CountUpNumber(
                    target: grams,
                    fontName: "JeniHeroSerif-Regular",
                    italicFontName: "JeniHeroSerif-Italic",
                    size: 38,
                    color: FoodTheme.textPrimary
                )
                Text("g")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
                if let target, target > 0 {
                    Spacer(minLength: 8)
                    Text("of \(target) g today")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(FoodTheme.textSecondary)
                        .monospacedDigit()
                }
            }
            if let target, target > 0 {
                shareBar(fraction: totals.protein / Double(target), fullAtOne: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            target.map { "protein, \(grams) grams of \($0) today" }
                ?? "protein, \(grams) grams"
        )
    }

    // MARK: - THE SPLIT (donut + legend)
    //
    // The denominator is the PLATE's own energy, never a daily budget:
    // this object answers "what is this made of", and the protein lead
    // above it already answered "where does the day stand". Keeping
    // those two questions in separate objects is what stops the
    // reading becoming a scorecard.
    //
    // Rose ramp only (berry · dusty · blush), so the chart speaks the
    // same language as every other instrument in the app.

    @ViewBuilder
    private func splitBlock(
        totals: PlateTotals, c: Double, f: Double, p: Double, energy: Double
    ) -> some View {
        HStack(spacing: 16) {
            MacroDonut(
                protein: p / energy,
                carbs: c / energy,
                fat: f / energy,
                centerTop: "\(displayKcal(totals))",
                centerBottom: kcalRangeLabel ?? "kcal"
            )
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 7) {
                legendRow("protein", Int(totals.protein.rounded()), "g", FoodTheme.roseBerry)
                legendRow("carbs", Int(totals.carbs.rounded()), "g", FoodTheme.accent)
                legendRow("fat", Int(totals.fat.rounded()), "g", FoodTheme.roseBlush)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(displayKcal(totals)) calories. protein \(Int(totals.protein.rounded())) grams, carbs \(Int(totals.carbs.rounded())) grams, fat \(Int(totals.fat.rounded())) grams"
        )
    }

    @ViewBuilder
    private func legendRow(_ label: String, _ value: Int, _ unit: String, _ swatch: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(swatch).frame(width: 7, height: 7)
            Text(label)
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(FoodTheme.textSecondary)
            Spacer(minLength: 10)
            Text("\(value)")
                .font(.custom("DMSans-SemiBold", size: 15))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(FoodTheme.textPrimary)
            Text(unit)
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .frame(maxWidth: 168)
    }


    /// A quiet landing bar: protein vs its floor (berry at the
    /// floor), or a macro's share of the plate's energy.
    @ViewBuilder
    private func shareBar(fraction: Double, fullAtOne: Bool) -> some View {
        let frac = min(1, max(0, fraction))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(FoodTheme.accentSubtle)
                Capsule()
                    .fill(fullAtOne && frac >= 1 ? FoodTheme.roseBerry : FoodTheme.accent)
                    .frame(width: max(4, geo.size.width * frac))
                    .animation(.easeOut(duration: 0.45), value: frac)
            }
        }
        .frame(height: 5)
        .padding(.vertical, 10)
    }

    // MARK: - THE CHEMISTRY (fiber · sugar · sodium · the ten)
    //
    // Founder steer 2026-08-11: "want to see fiber + sugar + sodium
    // info + vitamin / mineral info as well."
    //
    // fiber/sugar/sodium were already computed and were being sheared
    // in half by the footer. The vitamins and minerals were a genuine
    // find: `USDAClient` has parsed ten of them since v1.0.9 and
    // `CalorieMathService.compute` dropped them on the floor, so a
    // USDA-grounded plate knew its own vitamin C and could never say
    // so. E7 carries them through (`CapturedItem.micros`).
    //
    // THE HONESTY RULES, because this is where a nutrition app usually
    // starts lying:
    //   - zero means UNKNOWN, not "none". A source that does not
    //     publish potassium renders no potassium row.
    //   - a described meal that never touched USDA has no panel at all.
    //   - no percentages (`00_THE_SYSTEM` §12). The daily value picks
    //     which few are worth naming and turns the amount into a
    //     coarse word; the GRAMS are what render.
    //   - never a verdict. "some", "a good amount" — never "low",
    //     never "deficient", never red.

    @ViewBuilder private var chemistryBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            triStatRow
            microRow
        }
    }

    /// The four most-carried of the ten, by share of a day's value —
    /// so the panel names what this plate actually brought rather than
    /// listing ten rows of mostly nothing.
    @ViewBuilder private var microRow: some View {
        let named = Self.namedMicros(session.rebuiltFood().items)
        if !named.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(FoodTheme.textPrimary.opacity(0.07))
                    .frame(height: 0.5)
                HStack(spacing: 0) {
                    ForEach(Array(named.enumerated()), id: \.element.label) { idx, m in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.label)
                                .font(.custom("DMSans-Regular", size: 11))
                                .foregroundStyle(FoodTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(m.amount)
                                .font(.custom("DMSans-SemiBold", size: 14))
                                .monospacedDigit()
                                .foregroundStyle(FoodTheme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if idx < named.count - 1 {
                            Rectangle()
                                .fill(FoodTheme.textPrimary.opacity(0.07))
                                .frame(width: 0.5, height: 26)
                                .padding(.trailing, 10)
                        }
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "also carries " + named.map { "\($0.label) \($0.amount)" }
                    .joined(separator: ", ")
            )
        }
    }

    /// Picks up to four micronutrients worth naming: present (> 0),
    /// ranked by share of the adult daily value, and only when that
    /// share clears 5% — below which the number is noise dressed as
    /// nutrition. The share ranks; it never renders.
    static func namedMicros(
        _ items: [CapturedItem]
    ) -> [(label: String, amount: String)] {
        // A PARTIAL SUM IS NOT A PLATE'S NUTRITION.
        //
        // This summed whatever micros happened to be present and
        // labelled the result as what the plate carries. Micros arrive
        // from exactly ONE source — USDA FDC — and only for items the
        // dispatcher sent there, which is items the model flagged
        // low-confidence (< 0.5) or could not price at all. Every other
        // path publishes none: `llm_direct` (the default since v1.0.7,
        // so most items), OpenFoodFacts (the barcode door — its client
        // parses no micronutrients), `canonical_pantry` (no micro
        // columns) and the rule-based restaurant estimate.
        //
        // So on a four-item plate where one mystery item hit USDA, this
        // printed that ONE item's potassium as the plate's. E7's own
        // stated rule — "a described meal that never touched USDA has
        // no panel at all" — was written per-ITEM and enforced per-
        // PLATE by a `compactMap`, which silently accepts the mixed
        // case. This is the estimate-dressed-as-measurement defect the
        // provenance law exists to prevent, and it is why the panel is
        // gated on the PLATE being fully grounded rather than on any
        // number being non-zero.
        //
        // The QA harness hid it: `PlankAIApp.mockItems` hand-attaches
        // micros to `.llmDirect` items "so the panel renders in the
        // harness the way it does over a real lookup". A real
        // `.llmDirect` lookup returns none, so two eras reviewed this
        // panel against a state the pipeline cannot produce.
        guard !items.isEmpty, items.allSatisfy(\.publishesMicros) else { return [] }
        let totals = items.compactMap(\.micros)
            .reduce(CalorieMathService.Micronutrients(), +)
        guard !totals.isEmpty else { return [] }
        let dv = CalorieMathService.Micronutrients.dailyValues

        let all: [(String, Double, Double, String)] = [
            ("vitamin a",  totals.vitaminAUg,   dv.vitaminAUg,   "µg"),
            ("vitamin c",  totals.vitaminCMg,   dv.vitaminCMg,   "mg"),
            ("vitamin d",  totals.vitaminDUg,   dv.vitaminDUg,   "µg"),
            ("vitamin e",  totals.vitaminEMg,   dv.vitaminEMg,   "mg"),
            ("b12",        totals.vitaminB12Ug, dv.vitaminB12Ug, "µg"),
            ("calcium",    totals.calciumMg,    dv.calciumMg,    "mg"),
            ("iron",       totals.ironMg,       dv.ironMg,       "mg"),
            ("magnesium",  totals.magnesiumMg,  dv.magnesiumMg,  "mg"),
            ("potassium",  totals.potassiumMg,  dv.potassiumMg,  "mg"),
            ("zinc",       totals.zincMg,       dv.zincMg,       "mg"),
        ]
        return all
            .filter { $0.1 > 0 && $0.2 > 0 && ($0.1 / $0.2) >= 0.05 }
            .sorted { ($0.1 / $0.2) > ($1.1 / $1.2) }
            .prefix(4)
            .map { (label: $0.0, amount: Self.microAmount($0.1, $0.3)) }
    }

    /// One significant figure below 10, whole numbers above — a plate
    /// that carries "1.2 mg" of iron says so; one that carries "310
    /// mg" of potassium does not pretend to know "310.4".
    static func microAmount(_ value: Double, _ unit: String) -> String {
        if value < 10 {
            return String(format: "%.1f", value) + " " + unit
        }
        // Grouped, like every other number in the product — the plate
        // sheet three tiers up renders "2,300 dv" and Move renders
        // "5,460". This was raw interpolation, so a potassium reading
        // over 999 mg was the one four-digit figure in the app that
        // arrived as "1400". Same class as the ship pass's one gram
        // grammar: a number formatted two ways is two numbers.
        return "\(Int(value.rounded()).formatted()) \(unit)"
    }

    /// fiber · sugar intake · sodium — one quiet row, no invented
    /// denominators. Uncollected stays silent.
    @ViewBuilder private var triStatRow: some View {
        let items = session.rebuiltFood().items
        let totals = session.totals
        let sugar = items.compactMap { $0.sugarG }.reduce(0, +)
        let sodium = items.compactMap { $0.sodiumMg }.reduce(0, +)
        let cells: [(String, String)] = [
            ("fiber", totals.fiber >= 1 ? "\(Int(totals.fiber.rounded())) g" : ""),
            ("sugar intake", sugar >= 1 ? "\(Int(sugar.rounded())) g" : ""),
            ("sodium", sodium >= 1 ? "\(Int(sodium.rounded()).formatted())mg" : ""),
        ].filter { !$0.1.isEmpty }

        if !cells.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.element.0) { idx, cell in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cell.0)
                            .font(.custom("DMSans-Regular", size: 11))
                            .foregroundStyle(FoodTheme.textSecondary)
                        Text(cell.1)
                            .font(.custom("DMSans-SemiBold", size: 14))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(FoodTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if idx < cells.count - 1 {
                        Rectangle()
                            .fill(FoodTheme.textPrimary.opacity(0.07))
                            .frame(width: 0.5, height: 26)
                            .padding(.trailing, 12)
                    }
                }
            }
            .animation(.easeOut(duration: 0.4), value: cells.map(\.1))
            .accessibilityElement(children: .combine)
        }
    }

    /// "carbs 45 · fat 17 · fiber 7" — grams, nonzero components only.
    private func chemistryLine(_ totals: PlateTotals) -> String? {
        var parts: [String] = []
        if totals.carbs >= 1 { parts.append("carbs \(Int(totals.carbs.rounded())) g") }
        if totals.fat >= 1 { parts.append("fat \(Int(totals.fat.rounded())) g") }
        if totals.fiber >= 1 { parts.append("fiber \(Int(totals.fiber.rounded())) g") }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "  \u{00B7}  ")
    }

    /// One sentence answering "and my day?" — room left after this
    /// plate, in Home's own voice. nil when there is no honest number
    /// to speak (no target, suppressed cohort, no provider).
    private func dayLine(_ totals: PlateTotals) -> (prefix: String, punch: String, suffix: String)? {
        guard
            let ctx = FoodModule.dayContextProvider?(),
            let target = ctx.kcalTarget, target > 0
        else { return nil }
        let after = ctx.kcalEatenToday + displayKcal(totals)
        let room = target - after
        if room >= 150 {
            // Nearest 50 — "about 600", never "612".
            let rounded = (room / 50) * 50
            return ("", "\(rounded) left", " today after this")
        }
        if room >= -60 {
            // Under ~150 the honest read isn't a number, it's "you've
            // arrived" — a 50-kcal remainder is not an invitation.
            return ("", "right at", " your target today")
        }
        return ("a little ", "over", " today")
    }

    private func displayKcal(_ totals: PlateTotals) -> Int {
        let raw: Double = totals.kcal > 0
            ? totals.kcal
            : ((initialFood.kcalLow ?? 0) + (initialFood.kcalHigh ?? 0)) / 2
        // Round to the nearest 5 — precision theater is dishonest at
        // ±15-20% model accuracy; the range label carries the truth.
        return Int((raw / 5).rounded()) * 5
    }

    private var kcalRangeLabel: String? {
        let food = session.rebuiltFood()
        guard let lo = food.kcalLow, let hi = food.kcalHigh, hi > lo else { return nil }
        let band = Int(((hi - lo) / 2).rounded())
        guard band >= 20 else { return nil }
        return "\u{00B1} \(band)"
    }

    private var isGlp1Cohort: Bool {
        let n = glp1Status.lowercased()
        return n.contains("current") || n.contains("on_glp1") || n == "on"
            || n == "post" || n.contains("triedoff") || n.contains("tried_off")
    }

    // MARK: - Fraction chips ("how much of it")

    /// The rungs come from the DISH now, not from a constant. A solo
    /// plate gets the ladder it always had; a dish the model says is
    /// meant to be divided gets rungs that can express one slice of it.
    /// See `PlateShare`.
    private var shareLadder: [PlateShare.Rung] {
        PlateShare.ladder(for: session.sourceFood)
    }

    @ViewBuilder private var fractionChips: some View {
        VStack(alignment: .leading, spacing: 9) {
            // The note that explains these rungs lives in the HEADER, not
            // here — filming showed the reading opens in a detent where
            // this row is below the fold, so the caption arrived after
            // every number it qualifies. The ladder is the control; the
            // header states the subject.
            //
            // WRAPS, because it must. The shipped row was a fixed HStack
            // of `.fixedSize()` chips reading "¾ / half / bites"; the
            // share rungs are words ("2 slices"), and at AX5 four of them
            // overflow the sheet at every device width. A control that
            // runs off the edge is a control she does not have.
            FoodChipFlow(spacing: 7) {
                ForEach(shareLadder) { f in
                    fractionChip(f)
                }
            }
        }
    }

    @ViewBuilder
    private func fractionChip(_ f: PlateShare.Rung) -> some View {
        let isOn = abs(session.fraction - f.value) < 0.01
        Button {
            guard !isOn else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            commit { $0.setFraction(f.value) }
        } label: {
            (Text(f.label)
                .font(.custom("DMSans-Medium", size: 12))
            + Text(f.punch)
                .font(.custom("JeniHeroSerif-Italic", size: 13)))
                .foregroundStyle(isOn ? FoodTheme.bgPrimary : FoodTheme.textPrimary.opacity(0.75))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 11)
                .frame(height: 33)
                .background(
                    Capsule().fill(isOn ? FoodTheme.textPrimary : Color.white.opacity(0.55))
                )
                .overlay(
                    Capsule().stroke(
                        FoodTheme.textPrimary.opacity(isOn ? 0 : 0.12),
                        lineWidth: 0.75
                    )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.22), value: isOn)
        .accessibilityLabel(f.voiceLabel)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Ledger

    @ViewBuilder private var ledger: some View {
        let items = session.effectiveItems
        VStack(alignment: .leading, spacing: 0) {
            // v23 pass 5 — the header word retired (minimal); the
            // plate stepper moved beside the title. The rows speak
            // for themselves under their hairline.

            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                ledgerRow(item)
                if idx < items.count - 1 {
                    Rectangle()
                        .fill(FoodTheme.textPrimary.opacity(0.07))
                        .frame(height: 0.5)
                }
            }
        }
    }

    /// The whole plate's − grams + — a serving adjustment that needs
    /// no navigation. Disabled ends dim; grams rolls numerically.
    @ViewBuilder private var plateStepper: some View {
        HStack(spacing: 0) {
            stepperButton("minus", enabled: canStepPlate(up: false)) {
                stepPlate(up: false)
            }
            Text("\(Int(session.totals.grams.rounded())) g")
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundStyle(FoodTheme.textPrimary.opacity(0.80))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.4), value: Int(session.totals.grams.rounded()))
                .frame(minWidth: 56)
            stepperButton("plus", enabled: canStepPlate(up: true)) {
                stepPlate(up: true)
            }
        }
        .background(Capsule().fill(Color.white.opacity(0.55)))
        .overlay(Capsule().stroke(FoodTheme.textPrimary.opacity(0.10), lineWidth: 0.75))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("adjust the whole plate")
    }

    private func canStepPlate(up: Bool) -> Bool {
        session.items.contains { session.canStepPortion($0.id, up: up) }
    }

    private func stepPlate(up: Bool) {
        commit { s in
            for item in s.items where s.canStepPortion(item.id, up: up) {
                s.stepPortion(item.id, up: up)
            }
        }
    }

    @ViewBuilder private func ledgerRow(_ item: CapturedItem) -> some View {
        let edited = session.isEdited(item.id)
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    editingItemID = item.id
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.name.foodNameCleaned.lowercased())
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundStyle(FoodTheme.textPrimary)
                            .lineLimit(1)
                        if let gloss = item.englishName?.foodNameCleaned.lowercased() {
                            Text(gloss)
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundStyle(FoodTheme.textSecondary.opacity(0.8))
                                .lineLimit(1)
                        }
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(FoodTheme.textPrimary.opacity(0.28))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.name), tap to edit")

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    if edited {
                        Circle()
                            .fill(FoodTheme.accent.opacity(0.8))
                            .frame(width: 4.5, height: 4.5)
                            .accessibilityLabel("edited by you")
                    }
                    Text("\(Int((item.kcal ?? 0).rounded())) cal")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(FoodTheme.textPrimary.opacity(0.75))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.4), value: Int((item.kcal ?? 0).rounded()))
                }
            }

            portionStepper(item)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 8)
        .background(
            // chip → row: one blush flash, then quiet again.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FoodTheme.accentSubtle.opacity(
                    flashedRowID == item.id ? 0.55 : 0
                ))
        )
        .padding(.horizontal, -8)
    }

    /// Inline − grams + stepper: the zero-navigation portion fix. Ticks
    /// move over the quarter-of-the-scan grid in PlateEditSession.
    @ViewBuilder private func portionStepper(_ item: CapturedItem) -> some View {
        HStack(spacing: 0) {
            stepperButton("minus", enabled: session.canStepPortion(item.id, up: false)) {
                commit { $0.stepPortion(item.id, up: false) }
            }
            Text("\(Int(item.portionGrams.rounded())) g")
                .font(.custom("DMSans-Medium", size: 13))
                .foregroundStyle(FoodTheme.textPrimary.opacity(0.80))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.32), value: Int(item.portionGrams.rounded()))
                .frame(minWidth: 56)
            stepperButton("plus", enabled: session.canStepPortion(item.id, up: true)) {
                commit { $0.stepPortion(item.id, up: true) }
            }
        }
        .background(Capsule().fill(Color.white.opacity(0.55)))
        .overlay(Capsule().stroke(FoodTheme.textPrimary.opacity(0.10), lineWidth: 0.75))
    }

    @ViewBuilder
    private func stepperButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FoodTheme.textPrimary.opacity(enabled ? 0.70 : 0.22))
                .frame(width: 34, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "plus" ? "more" : "less")
    }

    // MARK: - Composer (fix it with words · + add something)

    /// Pass 52 — the correction taught AT the first result, once ever.
    /// Cal AI's unsticky corrections teach users to STOP correcting
    /// (50 §5's evidence); one sentence at reading #1 converts the
    /// correction moat into a first-session lesson. The flag is
    /// device-scoped like the consent flags beside it. Latched into
    /// @State at mount so the line holds steady through this reading's
    /// own re-renders and is gone on the next.
    static let fixTaughtKey = "food.firstReadingFixTaughtV1"
    @State private var teachesFix =
        !UserDefaults.standard.bool(forKey: SnapResultView.fixTaughtKey)

    @ViewBuilder private var composerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if refining {
                refiningLine
            } else if let composer {
                composerField(composer)
            } else {
                composerTriggers
                if teachesFix {
                    Text("off? your fix is kept, and the next reading starts from it.")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(FoodTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .onAppear {
                            UserDefaults.standard.set(true, forKey: Self.fixTaughtKey)
                        }
                }
            }
            if let line = refineErrorLine, !refining {
                (Text(line)
                    .font(.custom("DMSans-Regular", size: 12))
                + Text("")
                    .font(.custom("DMSans-Regular", size: 11)))
                    .foregroundStyle(FoodTheme.accent.opacity(0.85))
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.24), value: refining)
        .animation(.easeOut(duration: 0.24), value: composer != nil)
    }

    /// The two quiet trigger rows, side by side: additions on the
    /// left (a ledger continuation), corrections on the right.
    @ViewBuilder private var composerTriggers: some View {
        HStack(alignment: .firstTextBaseline) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openComposer(.addItem)
            } label: {
                (Text("+ add ")
                    .font(.custom("DMSans-Medium", size: 13))
                + Text("something")
                    .font(.custom("JeniHeroSerif-Italic", size: 14)))
                    .foregroundStyle(FoodTheme.textPrimary.opacity(0.65))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("add something to this plate")

            Spacer(minLength: 12)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openComposer(.fixWords)
            } label: {
                (Text("off? ")
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundColor(FoodTheme.textSecondary)
                + Text("fix it with ")
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundColor(FoodTheme.accent)
                + Text("words")
                    .font(.custom("JeniHeroSerif-Italic", size: 14))
                    .foregroundColor(FoodTheme.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("fix the estimate with words")
        }
        .padding(.vertical, 2)
    }

    private func openComposer(_ mode: Composer) {
        refineErrorLine = nil
        composerText = ""
        withAnimation(.easeOut(duration: 0.24)) { composer = mode }
        // Focus after the field mounts.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            composerFocused = true
        }
    }

    @ViewBuilder private func composerField(_ mode: Composer) -> some View {
        let placeholder = mode == .addItem
            ? "a splash of olive oil, a side of kimchi…"
            : "tell jeni what's off…"
        HStack(spacing: 8) {
            TextField(placeholder, text: $composerText, axis: .vertical)
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundStyle(FoodTheme.textPrimary)
                .lineLimit(1...3)
                .focused($composerFocused)
                .submitLabel(.send)
                .onSubmit { submitComposer(mode) }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FoodTheme.accent.opacity(0.35), lineWidth: 0.75)
                )

            Button {
                submitComposer(mode)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(
                            composerText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? FoodTheme.textPrimary.opacity(0.25)
                                : FoodTheme.textPrimary
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(composerText.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("send")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                composerFocused = false
                withAnimation(.easeOut(duration: 0.2)) {
                    composer = nil
                    refineErrorLine = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.8))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("cancel")
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// The in-flight line — italic serif with a slow breathe, no
    /// spinner (progress theater reads clinical against this card).
    @ViewBuilder private var refiningLine: some View {
        let phrase = composer == .addItem
            ? (lead: "adding it ", punch: "in", tail: "…")
            : (lead: "rereading your ", punch: "plate", tail: "…")
        RefiningBreatheText(lead: phrase.lead, punch: phrase.punch, tail: phrase.tail)
            .padding(.vertical, 4)
    }

    private func submitComposer(_ mode: Composer) {
        let note = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty, let refine, !refining else { return }
        composerFocused = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.24)) {
            refining = true
            refineErrorLine = nil
        }
        let request: SnapRefineRequest = mode == .addItem
            ? .addItem(note: note)
            : .fixWords(current: session.rebuiltFood(), note: note)
        Task { @MainActor in
            do {
                let outcome = try await refine(request)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeOut(duration: 0.4)) {
                    switch outcome {
                    case .rebased(let food):
                        session.rebase(on: food)
                    case .added(let items):
                        session.append(items)
                    }
                    refining = false
                    composer = nil
                    composerText = ""
                }
                onEdited(session.rebuiltFood())
            } catch {
                withAnimation(.easeOut(duration: 0.24)) {
                    refining = false
                    refineErrorLine = "didn't catch that. one more try?"
                }
            }
        }
    }

    // MARK: - Jeni section

    private var detailCopy: ResultDetailCopy {
        ResultDetailCopy(
            food: session.rebuiltFood(),
            ctx: ResultDetailContext(
                proteinTargetG: proteinTargetG,
                todayLoggedProtein: Int(
                    (userId.isEmpty
                        ? FoodLogPersister.todayMacros()
                        : FoodLogPersister.todayMacros(userId: userId)
                    ).protein.rounded()
                ),
                // v5.1 — the canonical target (TargetsService via the
                // day-context provider) so the note's day-fit speaks
                // the same number as Home's kcal bar; the legacy
                // AppStorage value only backstops provider-less runs
                // (previews, package tests).
                kcalTarget: FoodModule.dayContextProvider?()?.kcalTarget
                    ?? Int(foodDailyTarget),
                isGlp1: isGlp1Cohort,
                hour: Calendar.current.component(.hour, from: loggedAt)
            )
        )
    }

    private var proteinTargetG: Int {
        // App v2: the app injects the canonical target (TargetsService,
        // 1.2/1.6 g/kg by cohort) so this number matches Today +
        // Becoming exactly. Package-local fallback only when the
        // provider is absent (previews, package tests).
        if let provided = FoodModule.proteinTargetProvider?() {
            return provided
        }
        let kg = currentWeightKg
        let raw = kg > 30 ? 1.2 * kg : 0
        return max(70, min(130, Int(raw.rounded())))
    }

    /// v23 §5.9 — the note came home to the page: the reading closes
    /// in jeni's voice, quiet, at the end of the scroll. The sparkle
    /// theater retired with the carousel — restraint is the note.
    @ViewBuilder private var noteBlock: some View {
        let copy = detailCopy
        VStack(alignment: .leading, spacing: 10) {
            Text("JENI'S NOTE")
                .font(.custom("DMSans-Medium", size: 10.5))
                .kerning(1.2)
                .foregroundStyle(FoodTheme.textSecondary.opacity(0.85))
                .padding(.top, 2)

            jeniNoteText(copy.jeniNote)

            dayFitText(copy.dayFit)

            if let proteinRow = copy.details.first(where: { $0.progress != nil }) {
                proteinTodayRow(proteinRow)
                    .padding(.top, 2)
            }

            if let p = copy.provenance {
                Text(p)
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.7))
            }
        }
        .padding(.bottom, 6)
    }

    private func jeniNoteText(_ n: PunchLine) -> some View {
        (Text(n.prefix)
            .font(.custom("JeniHeroSerif-Regular", size: 19))
        + Text(n.punch)
            .font(.custom("JeniHeroSerif-Italic", size: 19))
        + Text(n.suffix)
            .font(.custom("JeniHeroSerif-Regular", size: 19)))
            .foregroundStyle(FoodTheme.textPrimary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func dayFitText(_ l: PunchLine) -> some View {
        (Text(l.prefix)
            .font(.custom("DMSans-Regular", size: 13))
        + Text(l.punch)
            .font(.custom("JeniHeroSerif-Italic", size: 14))
        + Text(l.suffix)
            .font(.custom("DMSans-Regular", size: 13)))
            .foregroundStyle(FoodTheme.textSecondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func proteinTodayRow(_ row: DetailRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.label)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(FoodTheme.textSecondary)
                Spacer(minLength: 8)
                Text(row.value)
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .monospacedDigit()
            }
            if let p = row.progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(FoodTheme.accentSubtle)
                        Capsule()
                            .fill(p >= 1 ? FoodTheme.roseBerry : FoodTheme.accent)
                            .frame(width: max(4, geo.size.width * min(1, p)))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    // MARK: - Footer (retake · log it · share)

    @ViewBuilder private var footer: some View {
        HStack(spacing: 12) {
            footerCircle("arrow.uturn.backward", label: "retake") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onRetake()
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                fileIt()
            } label: {
                // v23 — the verb of the era: the idle caption taught
                // "add it before you eat"; the pill keeps the word.
                Text("add it")
                    .font(.custom("DMSans-SemiBold", size: 16))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(FoodTheme.textPrimary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("add it")

            if allowsShare {
                footerCircle("square.and.arrow.up", label: "share") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    // The composer overlays the same steady photo.
                    withAnimation(.easeOut(duration: 0.3)) { page = 2 }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 10)
        // v25 E7 — once the plate is filing, the chrome goes with the
        // rest: the deed is done and a live primary action beneath a
        // finished sentence invites a second tap. Frame review caught
        // the first cut greying the pill instead, which read as a
        // failure state on the exact beat that is meant to feel like
        // completion.
        .opacity(answer == nil ? 1 : 0)
        .allowsHitTesting(answer == nil)
        .animation(.easeOut(duration: 0.22), value: answer == nil)
        .background(
            // A soft paper fade so scrolled content dissolves under
            // the footer instead of shearing against it (token paper,
            // not a bespoke cream).
            //
            // v25 E7 — the fade used to start 30pt up and reach full
            // paper only at the footer's own top edge, so the last row
            // of the reading (fiber · sugar intake · sodium) came to
            // rest sheared exactly in half. A longer reach with an
            // earlier full stop dissolves it instead. Frame-caught.
            LinearGradient(
                stops: [
                    .init(color: FoodTheme.bgPrimary.opacity(0), location: 0),
                    .init(color: FoodTheme.bgPrimary.opacity(0.92), location: 0.45),
                    .init(color: FoodTheme.bgPrimary, location: 0.7),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .padding(.top, -64)
            .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private func footerCircle(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FoodTheme.textPrimary.opacity(0.8))
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white.opacity(0.65)))
                .overlay(Circle().stroke(FoodTheme.textPrimary.opacity(0.12), lineWidth: 0.75))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - THE ANSWER (v25 E7 — SAY IT)
    //
    // "add it" used to dismiss the sheet and return her to Home. Every
    // intelligence this branch built paid out later — the morning read
    // on day N+1, the desk's line the next time she opened the chat —
    // and a payer's median life is 2.0 active days, so most people were
    // being paid in a currency they would not be there to spend.
    //
    // Now the grid she is reading BECOMES the sentence, in its own
    // real estate, before the plate files. The motion is the argument:
    // four numbers collapse toward the middle and one true line rises
    // out of them. That is what "this became part of the record" looks
    // like, and it costs no new screen, no toast and no destination.
    //
    // Reduce Motion gets a cross-fade at the same pace. The engine is
    // app-side (PlateAnswerEngine); absent provider → the old
    // behaviour exactly, so the package still works alone.

    #if DEBUG
    /// v25 E7 film door — simctl cannot tap "add it", and the answer
    /// morph is the era's whole argument, so it has to be recordable.
    /// Fires the SAME path the button fires, never a mock.
    private var filmTheAnswer: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-file-plate")
    }
    #endif

    private func fileIt() {
        guard answer == nil else { return }
        let food = session.rebuiltFood()
        let proteinG = Int(session.totals.protein.rounded())

        guard let composed = FoodModule.plateAnswerProvider?(proteinG) else {
            onLog(food)
            return
        }

        // Phase one: the grid steps back and everything under it goes.
        withAnimation(.easeOut(duration: 0.22)) { answer = composed }
        // Phase two: the sentence arrives into the space it vacated.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(
                reduceMotion
                ? .easeOut(duration: 0.24)
                : .spring(response: 0.42, dampingFraction: 0.84)
            ) {
                answerVisible = true
            }
            // The haptic lands with the WORDS, not with the tap, so
            // the mark reads as "recorded" rather than "pressed".
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        // Long enough to read one short sentence, short enough not to
        // feel like a wait.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            onLog(food)
        }
    }

    /// The sentence, in the grid's place. Left-aligned on the same
    /// baseline the grid started from so nothing jumps sideways.
    @ViewBuilder
    private func answerBlock(_ a: FoodModule.PlateAnswer) -> some View {
        let split = Self.split(a)
        VStack(alignment: .leading, spacing: 0) {
            (Text(split.prefix)
                .font(.custom("JeniHeroSerif-Regular", size: 25))
             + Text(split.punch)
                .font(.custom("JeniHeroSerif-Italic", size: 25))
             + Text(split.suffix)
                .font(.custom("JeniHeroSerif-Regular", size: 25)))
                .foregroundStyle(FoodTheme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .accessibilityLabel(a.text)
    }

    /// Splits the sentence around its punch. The engine guarantees the
    /// punch is a substring (pinned by PlateAnswerEngineTests); this
    /// degrades to flat prose rather than trusting that at runtime.
    private static func split(
        _ a: FoodModule.PlateAnswer
    ) -> (prefix: String, punch: String, suffix: String) {
        guard let r = a.text.range(of: a.punch), !a.punch.isEmpty else {
            return ("", a.text, "")
        }
        return (String(a.text[a.text.startIndex..<r.lowerBound]),
                a.punch,
                String(a.text[r.upperBound...]))
    }

    // MARK: - Cascade

    private func runCascade() {
        if reduceMotion { revealed = 6; return }
        revealed = 0
        for i in 0...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07 * Double(i)) {
                withAnimation(.easeOut(duration: 0.42)) { revealed = max(revealed, i) }
            }
        }
    }
}

// MARK: - Cascade modifier

private extension View {
    func cascade(_ step: Int, _ revealed: Int) -> some View {
        modifier(SnapCascadeStep(step: step, revealed: revealed))
    }
}

private struct SnapCascadeStep: ViewModifier {
    let step: Int
    let revealed: Int
    func body(content: Content) -> some View {
        content
            .opacity(revealed >= step ? 1 : 0)
            .offset(y: revealed >= step ? 0 : 10)
    }
}

// MARK: - RefiningBreatheText
//
// The composer's in-flight state: an italic-punch serif line that
// breathes (opacity 0.55 ↔ 1.0) while the correction round-trips.
// Reduce-motion holds it steady.

private struct RefiningBreatheText: View {
    let lead: String
    let punch: String
    let tail: String

    @State private var bright = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        (Text(lead)
            .font(.custom("JeniHeroSerif-Regular", size: 16))
        + Text(punch)
            .font(.custom("JeniHeroSerif-Italic", size: 16))
        + Text(tail)
            .font(.custom("JeniHeroSerif-Regular", size: 16)))
            .foregroundStyle(FoodTheme.textPrimary.opacity(bright ? 1.0 : 0.55))
            .onAppear {
                guard !reduceMotion else { bright = true; return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
            .accessibilityLabel("working on it")
    }
}

#endif

// MARK: - MacroDonut (v25 E7)
//
// The plate's composition as one object. Founder steer: a pie instead
// of bars, "to utilize the space better" — three stacked bars plus a
// full-width split bar cost ~150pt and said less than this 96pt ring.
//
// Rules it keeps:
//   - the rose ramp only (berry · dusty · blush), never a new palette
//   - the DENOMINATOR IS THE PLATE, never a daily budget: this answers
//     "what is it made of", not "how did you do"
//   - no labels inside the ring and no percentages anywhere; the
//     legend beside it carries the grams
//   - it draws itself once on arrival and never re-animates on scroll
private struct MacroDonut: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    let centerTop: String
    let centerBottom: String

    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Normalised, guarded against a plate whose macros are all zero
    /// (a drink, a scan that resolved to nothing) — that renders an
    /// empty track rather than a divide-by-zero wedge.
    private var slices: [(Double, Color)] {
        let sum = protein + carbs + fat
        guard sum > 0 else { return [] }
        return [
            (protein / sum, FoodTheme.roseBerry),
            (carbs / sum, FoodTheme.accent),
            (fat / sum, FoodTheme.roseBlush),
        ]
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(FoodTheme.textPrimary.opacity(0.06), lineWidth: 13)

            let s = slices
            ForEach(Array(s.enumerated()), id: \.offset) { idx, slice in
                let start = s.prefix(idx).reduce(0.0) { $0 + $1.0 }
                Circle()
                    .trim(from: start, to: drawn ? start + slice.0 : start)
                    .stroke(
                        slice.1,
                        style: StrokeStyle(lineWidth: 13, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 0) {
                Text(centerTop)
                    .font(.custom("JeniHeroSerif-Regular", size: 21))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(centerBottom)
                    .font(.custom("DMSans-Regular", size: 9.5))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 18)
        }
        .onAppear {
            guard !drawn else { return }
            if reduceMotion {
                drawn = true
            } else {
                withAnimation(.easeOut(duration: 0.62).delay(0.08)) { drawn = true }
            }
        }
        .accessibilityHidden(true)
    }
}
