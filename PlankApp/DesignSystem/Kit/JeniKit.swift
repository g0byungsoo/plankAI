import SwiftUI

// MARK: - JeniKit (v11 — the editorial kit)
//
// The seven primitives. Nothing else may appear on a v11 surface
// (docs/app_v11/00_REBIRTH.md §4). The kit is the onboarding's
// register promoted in-app: typography carries hierarchy (L1),
// whitespace is the divider (L2), rows carry words not icons (L3),
// one ink action per screen (L4), no borders or shadows (L5).

// p66 — JeniPage deleted: zero shipping screens ever adopted the
// shell (Home, Becoming, the ledger and the journal each own their
// arrival flag directly via `.environment(\.jeniArrived, _)`), so the
// kit's gallery was its only consumer. The arrival-flag environment
// lives on in JeniMotion.

// MARK: - JeniSectionHeader
//
// THE only separator in the app (L2). Air above, a letterspaced
// whisper, then the section's content.
//
// ARRIVAL GRAMMAR (L12, learned from the frames): the arrival unit
// is the SECTION — wrap header + content together in ONE
// `.jeniArrive(index:)`. A header must never be left unindexed; it
// would render instantly and float on empty paper like a skeleton
// screen while its content is still arriving.

struct JeniSectionHeader: View {
    let label: String
    /// v15 — rhythm is COMPOSED, not uniform. A page that separates
    /// every movement by the same 44pt reads as a list of equals;
    /// editorial pages compress what belongs together and breathe
    /// hard before what matters. Pass `topAir` to score the page.
    var topAir: CGFloat = Space.sectionGap

    init(_ label: String, topAir: CGFloat = Space.sectionGap) {
        self.label = label
        self.topAir = topAir
    }

    var body: some View {
        Text(label.uppercased())
            .font(.custom("DMSans-SemiBold", size: 11, relativeTo: .caption2))
            .tracking(1.6)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, topAir)
            .padding(.bottom, Space.sm)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - JeniHeadline
//
// The serif line with the italic punch, in three registers. Wraps
// `ItalicAccentText` — the punch is composition, never `*markers*`.

struct JeniHeadline: View {
    enum Register {
        case page   // 34pt — screen titles
        case hero   // 38pt — the moment a screen leads with
        case band   // 26pt — a section's leading line
        /// v16 — 22pt: the day's ask on a dashboard. It still leads
        /// its list in Jeni's voice, but a control center's lead is
        /// read at a glance, not admired.
        case lead

        var fonts: (base: Font, italic: Font) {
            switch self {
            case .page: return (Typo.questionHero, Typo.questionHeroItalic)
            case .hero: return (Typo.displayHero, Typo.displayHeroItalic)
            case .band: return (
                .custom("JeniHeroSerif-Regular", size: 26, relativeTo: .title2),
                .custom("JeniHeroSerif-Italic", size: 26, relativeTo: .title2)
            )
            case .lead: return (
                .custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title3),
                .custom("JeniHeroSerif-Italic", size: 22, relativeTo: .title3)
            )
            }
        }
    }

    let base: String
    var italic: [String] = []
    var register: Register = .band

    init(_ base: String, italic: [String] = [], register: Register = .band) {
        self.base = base
        self.italic = italic
        self.register = register
    }

    var body: some View {
        ItalicAccentText(
            base,
            italic: italic,
            baseFont: register.fonts.base,
            italicFont: register.fonts.italic
        )
    }
}

// MARK: - JeniRow
//
// The universal list row. 60pt, borderless, dividerless, iconless.
// Tap enters the module; the trailing state is render-only; the
// optional long-press is the override (never a tap target).

struct JeniRow: View {
    enum Trailing {
        case none
        case done
        case count(String)
        case chevron
    }

    let title: String
    var detail: String? = nil
    var trailing: Trailing = .none
    let action: () -> Void
    var onLongPress: (() -> Void)? = nil

    init(_ title: String,
         detail: String? = nil,
         trailing: Trailing = .none,
         action: @escaping () -> Void,
         onLongPress: (() -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.trailing = trailing
        self.action = action
        self.onLongPress = onLongPress
    }

    /// Long-press latch (the JKTapWithLongPress pattern): a Button
    /// fires on touch-up, so without the latch a completed hold ALSO
    /// taps — the override sheet raced the module cover (walker-caught).
    @State private var longPressJustFired = false

    var body: some View {
        Button {
            if longPressJustFired {
                longPressJustFired = false
                return
            }
            action()
        } label: {
            HStack(alignment: .center, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("DMSans-Regular", size: 17, relativeTo: .body))
                        // Done rows dim; the trailing dot confirms. One
                        // state, two quiet signals — never a strike.
                        .foregroundStyle(done ? Palette.cocoaTertiary : Palette.textPrimary)
                    if let detail {
                        Text(detail)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer(minLength: Space.sm)
                trailingView
            }
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniRowPressStyle())
        .simultaneousGesture(
            onLongPress.map { press in
                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    longPressJustFired = true
                    JeniHaptic.land()
                    press()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        longPressJustFired = false
                    }
                }
            }
        )
        .accessibilityHint(onLongPress != nil ? Text("double-tap to open. long-press to mark.") : Text(""))
    }

    private var done: Bool {
        if case .done = trailing { return true }
        return false
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .none:
            EmptyView()
        case .done:
            Circle()
                .fill(Palette.textPrimary)
                .frame(width: 7, height: 7)
                .accessibilityLabel(Text("done"))
        case .count(let text):
            Text(text)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.cocoaTertiary)
        }
    }
}

/// The row's press acknowledgment — a settle, not a highlight box.
private struct JeniRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(JeniMotion.settle, value: configuration.isPressed)
    }
}

// MARK: - JeniPrimaryButton
//
// The ONE ink pill (L4). Promotes JFContinueButton so onboarding and
// the app share a single button — same capsule, same haptic, same
// scale-not-ellipsize contract.

struct JeniPrimaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        JFContinueButton(label: title, action: action)
    }
}

// MARK: - JeniSheetHeight (v25 E7 — founder steer 2026-08-11)
//
// "many pop ups like this ... are out of space and should be scrolled
// or full screened."
//
// The system had been reaching for `.medium` — a system detent pinned
// at HALF the screen — as its default resting height. Half a screen is
// enough for a confirm and not enough for anything with a list, a
// severity picker and a note field in it, so a dozen sheets opened
// already scrolled with their primary action below the fold.
//
// One token instead of a dozen hand-picked fractions:
//
//   .tall   0.68  the new resting height for a sheet that carries a
//                 body of content. Roughly two thirds — enough for a
//                 heading, its content and its one action, while the
//                 page underneath still reads as the place she came
//                 from (which is the entire reason a sheet is not a
//                 push).
//   .brief  0.42  genuinely short surfaces: one question, one answer.
//                 Smaller than `.medium` on purpose — a half-screen
//                 sheet holding two lines is its own kind of wrong.
//
// Sheets whose content is a full page (THE BOOK, the regimen home,
// the reader, the plate detail, JENI MOVE) stay `.large` and are not
// listed here.
//
// A NOTE ON `tallFixed`, because it has been mis-picked once. Fixed
// means "cannot be dragged taller", and the only reason to want that
// is a picker or a canvas that needs the room it has (the weight
// ritual's wheel). It is NOT the token for "this sheet's header kept
// clipping" — a ScrollView fixes that. Move sat on it for two eras and
// opened already scrolled with no grabber and no second detent.

enum JeniSheetHeight {
    /// A sheet with a body of content. Two thirds, expandable.
    static let tall: Set<PresentationDetent> = [.fraction(0.68), .large]
    /// A sheet with one question in it.
    static let brief: Set<PresentationDetent> = [.fraction(0.42), .large]
    /// A sheet with a body of content that must not be dragged taller
    /// (a camera or a canvas underneath needs the room it has).
    static let tallFixed: Set<PresentationDetent> = [.fraction(0.68)]
    /// A sheet whose content is a full page (THE BOOK's plate detail,
    /// the regimen home, JENI MOVE, settings).
    static let full: Set<PresentationDetent> = [.large]
}

// MARK: - jeniSheet / jeniCover — THE PRESENTATION GRAMMAR
//
// Pass 57: these are the ONLY legal presenters in PlankApp.
// `PresentationGrammarTests` sweeps the source tree and fails any bare
// `.sheet(` / `.fullScreenCover(` outside this file (system-controller
// wrappers exempted by name, with reasons). The drift that produced a
// 0.42 sheet with no scroll, no grabber and its button below the fold
// (MoveRecordSheet), and `.large` sheets with no visible exit at all
// (JENI MOVE, the plate detail), came from every call site hand-rolling
// three or four presentation modifiers. One authority, so a wrong
// combination can no longer be typed.
//
// The grammar:
//   sheet — paper, 28pt radius, tall-first, and the system grabber is
//     ALWAYS visible. One affordance language: if it is a sheet, you
//     can see that it drags. (JKSheetChrome used to hide the grabber
//     per-surface; two `.large` sheets ended up with no exit anywhere.)
//   cover — a full page. Its content must supply exactly one named
//     exit (an X or a done); a cover with no exit is a trap, and a
//     cover pretending to be a sheet is a lie about where she is.
//
// `brief` and `tall` both carry a `.large` escape so content can never
// be pinned under a fixed fraction; `tallFixed` remains the documented
// canvas exception (a ruler needs the room it has).

extension View {
    func jeniSheet<C: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = JeniSheetHeight.tall,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .presentationDetents(detents)
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bgPrimary)
        }
    }

    func jeniSheet<Item: Identifiable, C: View>(
        item: Binding<Item?>,
        detents: Set<PresentationDetent> = JeniSheetHeight.tall,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> C
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { value in
            content(value)
                .presentationDetents(detents)
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bgPrimary)
        }
    }

    /// Item-driven with per-item heights, for a polymorphic host (the
    /// Today host presents ten different sheets through one slot). The
    /// closure keeps the choice next to the case, and the detents are
    /// resolved from the item inside the sheet body so a dismissal
    /// animation never re-measures against a nil case.
    func jeniSheet<Item: Identifiable, C: View>(
        item: Binding<Item?>,
        detents: @escaping (Item) -> Set<PresentationDetent>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> C
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { value in
            content(value)
                .presentationDetents(detents(value))
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bgPrimary)
        }
    }

    /// A full page over the current one. Content supplies its exit.
    func jeniCover<C: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }

    func jeniCover<Item: Identifiable, C: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> C
    ) -> some View {
        fullScreenCover(item: item, onDismiss: onDismiss, content: content)
    }
}

/// THE SCROLL LAW, as a body wrapper (p54 wrote it for the read; p57
/// makes it a primitive): a sheet body scrolls when content exceeds
/// the viewport and sits still when it does not. Pin the primary
/// action with `.safeAreaInset(edge: .bottom)` OUTSIDE this wrapper so
/// the exit is reachable at every type size.
struct JeniScrollingSheetBody: ViewModifier {
    func body(content: Content) -> some View {
        ScrollView {
            content
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - JeniReceiptBeat (p63 — the receipt, named)
//
// The written acknowledgment of a FACT that just entered the record:
// one serif line, an honest sub-line a beat later, dwelling
// `JeniMotion.receiptDwell` before the surface excuses itself. p62
// named the DWELL; this names the VIEW — extracted verbatim from the
// weight ritual's kept beat (the reference receipt since p53) so the
// move record and any future commit speak one receipt instead of
// hand-rolling a sibling. The call site owns the haptic
// (`JeniHaptic.record()`) and the dismissal timer; this view owns
// only the composition.

struct JeniReceiptBeat: View {
    let line: String
    var italic: [String] = []
    var sub: String? = nil
    /// Flip to true to play the beat. The view must be MOUNTED before
    /// the flip (opacity 0) or the animation has no edge to ride.
    let shown: Bool

    var body: some View {
        VStack(spacing: 10) {
            ItalicAccentText(
                line,
                italic: italic,
                baseFont: .custom("JeniHeroSerif-Regular", size: 26),
                italicFont: .custom("JeniHeroSerif-Italic", size: 26),
                color: Palette.textPrimary,
                alignment: .center
            )
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .animation(.easeOut(duration: 0.45), value: shown)

            if let sub {
                Text(sub)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, Space.xl)
                    .opacity(shown ? 1 : 0)
                    .animation(.easeOut(duration: 0.45).delay(0.3), value: shown)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// p66 — JeniCard deleted: JeniSurface won everywhere real (21 call
// sites to zero); a thin alias with a law of its own was a second
// name for one material.

// MARK: - Gallery (DEBUG)

#if DEBUG
/// `--debug-v11-gallery` — every primitive on one page, the arrival
/// choreography restartable by tapping the title (for THE LOOP's
/// frame captures).
struct JeniKitGallery: View {
    @State private var run = 0
    @State private var sheetUp = false
    @State private var scope: JeniScope = .week

    /// `--debug-gallery-tour`: the page walks itself for the camera —
    /// scrolls to each glance section, cycles the scope, lets the
    /// pager page. Synthesized XCUI drags cannot scroll this sim
    /// runtime (probe-proven), so the tour is how THE LOOP films
    /// below-the-fold arrivals.
    private var isTour: Bool {
        ProcessInfo.processInfo.arguments.contains("--debug-gallery-tour")
    }

    var body: some View {
        galleryShell {
            ScrollViewReader { proxy in
            Group {
            // The arrival unit is the section: header + content, one index.
            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("headlines")
                VStack(alignment: .leading, spacing: Space.blockGap) {
                    JeniHeadline("down 2.1 lb, and your waist reads narrower.",
                                 italic: ["narrower."], register: .hero)
                    JeniHeadline("what the week actually did", italic: ["actually"],
                                 register: .band)
                }
            }
            .jeniArrive(index: 1)

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("the chart draws")
                JeniChart(
                    model: JeniChartModel(form: .line, series: [
                        .init(values: [166.8, 166.2, nil, 165.4, 165.9, 164.8, 164.2],
                              role: .ink),
                        .init(values: [166.5, 166.1, 165.8, 165.5, 165.3, 165.0, 164.7],
                              role: .context),
                    ]),
                    height: 72,
                    endLabels: ("4 weeks ago", "today"),
                    scrubbable: true,
                    accessibilityText: "weight, four weeks, trending down"
                )
            }
            .jeniArrive(index: 2)

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("the bars land")
                JeniChart(
                    model: JeniChartModel(form: .bars, series: [
                        .init(values: [82, 96, nil, 104, 88, 112, 91, 76, nil, 98,
                                       118, 84, 102, 95],
                              role: .ink),
                    ]),
                    height: 56,
                    endLabels: ("two weeks of protein", "g / day"),
                    scrubbable: true,
                    accessibilityText: "protein, two weeks of daily grams"
                )
            }
            .jeniArrive(index: 3)

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("numerals count")
                JeniCountingNumeral(value: 1240, unit: "of 2,060 kcal")
            }
            .jeniArrive(index: 4)

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("today")
                JeniRow("add protein before noon", detail: "about 30 g to go",
                        action: {}, onLongPress: {})
                JeniRow("10 min movement", trailing: .count("in the evening"),
                        action: {})
                JeniRow("body check-in", trailing: .done, action: {})
                JeniRow("this week, in words", trailing: .chevron,
                        action: { sheetUp = true })
            }
            .jeniArrive(index: 5)

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("the card")
                JeniSurface(radius: 20) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        JeniHeadline("sodium ran high thursday.", italic: ["thursday."])
                        Text("the scale follows for a day or two. water, not fat.")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .jeniArrive(index: 6)

            // ── v12 glance layer (docs/app_v12/00_CRAFT.md §2.1)

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("the ring traces")
                HStack(spacing: Space.blockGap) {
                    JeniRing(fraction: 0.58)
                    VStack(alignment: .leading, spacing: 2) {
                        JeniCountingNumeral(value: 860, unit: "of 1,473 kcal")
                        Text("613 left")
                            .font(Typo.numeralMeta)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .jeniArrive(index: 7)
            .id("tour.ring")

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("the bars land")
                HStack(alignment: .top, spacing: Space.blockGap) {
                    JeniMetricBar(label: "protein", value: "62 / 90 g",
                                  fraction: 62.0 / 90.0, index: 0)
                    JeniMetricBar(label: "carbs", value: "90 g", index: 1)
                    JeniMetricBar(label: "fat", value: "28 g", index: 2)
                }
            }
            .jeniArrive(index: 8)
            .id("tour.bars")

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("the week, dotted")
                JeniWeekDots(days: [
                    .init(id: 0, filled: true, letter: "s"),
                    .init(id: 1, filled: true, letter: "m"),
                    .init(id: 2, filled: false, letter: "t"),
                    .init(id: 3, filled: true, letter: "w"),
                    .init(id: 4, filled: true, isToday: true, letter: "t"),
                    .init(id: 5, filled: false, letter: "f"),
                    .init(id: 6, filled: false, letter: "s"),
                ])
            }
            .jeniArrive(index: 9)
            .id("tour.dots")

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("the scope morphs")
                JeniScopeBar(scope: $scope)
            }
            .jeniArrive(index: 10)
            .id("tour.scope")

            VStack(alignment: .leading, spacing: 0) {
                JeniSectionHeader("insights page")
                JeniInsightPager(insights: [
                    JeniInsight(
                        id: "protein", eyebrow: "protein", value: 5, word: "of 7 days",
                        figure: .weekDots([
                            .init(id: 0, filled: true), .init(id: 1, filled: true),
                            .init(id: 2, filled: false), .init(id: 3, filled: true),
                            .init(id: 4, filled: true), .init(id: 5, filled: true),
                            .init(id: 6, filled: false),
                        ]),
                        sentence: "you reached your protein floor 5 days this week.",
                        sentenceItalic: ["5 days"]
                    ),
                    JeniInsight(
                        id: "sodium", eyebrow: "sodium", value: nil,
                        valueText: "down 22%", word: "vs last week",
                        figure: .bars([2900, 2400, nil, 2100, 1900, 2200, 1800]),
                        sentence: "less held water. the scale reads truer.",
                        sentenceItalic: ["truer."]
                    ),
                    JeniInsight(
                        id: "run", eyebrow: "consistency", value: 18, word: "days",
                        figure: .none,
                        sentence: "18 days of showing up, unbroken.",
                        sentenceItalic: ["unbroken."]
                    ),
                ], tourAutoAdvance: isTour)
            }
            .jeniArrive(index: 11)
            .id("tour.pager")

            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: Space.sectionGap)
                JeniPrimaryButton("continue") {}
            }
            .jeniArrive(index: 12)
            }
            .task { await runTour(proxy) }
            }
        }
        .id(run)
        // v12: the page-level double-tap died — a tap-count gesture on
        // the whole page swallowed every synthesized drag (the probe
        // leg's three scroll mechanisms all failed against it).
        // Restart the choreography by relaunching.
        .jeniSheet(isPresented: $sheetUp) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("the sheet")
                        .font(Typo.questionHero)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, Space.hero)
                        .padding(.bottom, Space.sm)
                    JeniSectionHeader("grammar")
                    Text("a sheet composes the same primitives as a page.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                    Color.clear.frame(height: Space.sectionGap)
                    JeniPrimaryButton("done") { sheetUp = false }
                }
                .padding(.horizontal, Space.gutter)
            }
            .background(Palette.bgPrimary.ignoresSafeArea())
        }
    }

    /// The dead JeniPage shell, inlined for the gallery alone: paper,
    /// gutter, a title at index 0, one arrival flag.
    @State private var shellArrived = false
    private func galleryShell(@ViewBuilder content: @escaping () -> some View) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("the kit")
                        .font(Typo.questionHero)
                        .foregroundStyle(Palette.textPrimary)
                    Text("v11 · every primitive, arriving")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }
                .jeniArrive(index: 0)
                .padding(.top, Space.hero)
                .padding(.bottom, Space.sm)
                content()
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.heroGap)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .environment(\.jeniArrived, shellArrived)
        .task {
            guard !shellArrived else { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
            shellArrived = true
        }
    }

    private func runTour(_ proxy: ScrollViewProxy) async {
        guard isTour else { return }
        try? await Task.sleep(nanoseconds: 3_800_000_000)
        await tourStep(proxy, "tour.ring", dwell: 2.6)
        await tourStep(proxy, "tour.bars", dwell: 2.4)
        await tourStep(proxy, "tour.dots", dwell: 2.4)
        await tourStep(proxy, "tour.scope", dwell: 0.9)
        for s in [JeniScope.month, .threeMonths, .week] {
            withAnimation(JeniMotion.morph) { scope = s }
            try? await Task.sleep(nanoseconds: 900_000_000)
        }
        await tourStep(proxy, "tour.pager", dwell: 8.5)
    }

    private func tourStep(_ proxy: ScrollViewProxy, _ id: String, dwell: Double) async {
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.9)) {
            proxy.scrollTo(id, anchor: .center)
        }
        try? await Task.sleep(nanoseconds: UInt64(dwell * 1_000_000_000))
    }
}
#endif

// MARK: - JeniSurface (v14 — contrast, not glow)
//
// The card matured (founder: "the shadows feel artificial…
// everything feels like one giant blob. luxury comes from restraint
// and contrast"): pure white fill, a DRAWN 0.5pt hairline edge, and
// one barely-there contact shadow that grounds without glowing. The
// neumorphic top-highlight died. Edges are the luxury — Chanel and
// Muji separate with a line, not a halo. (Amends law §12.4 for this
// material: the hairline + contact pair IS the v14 elevation.)

struct JeniSurface<Content: View>: View {
    var radius: CGFloat = 24
    var padding: CGFloat = Space.blockGap
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.bgElevated)
                    // v20 — NO BORDER. The card is legible because the
                    // paper is a step below white; the shadow only
                    // grounds it. A line around a card is the tell.
                    .shadow(color: Palette.textPrimary.opacity(0.04),
                            radius: 10, x: 0, y: 3)
            )
    }
}

extension View {
    /// p62 — the §6.1 contact shadow as a callable law. Nine shadow
    /// recipes had accreted across the tree; every raised paper
    /// surface grounds with THIS one (JeniSurface's own values). A
    /// new recipe is a design decision, not a keystroke.
    func jeniContactShadow() -> some View {
        shadow(color: Palette.textPrimary.opacity(0.04),
               radius: 10, x: 0, y: 3)
    }
}

/// The press acknowledgment for cards: a soft compression, no dim box.
struct JeniPressable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(JeniMotion.press, value: configuration.isPressed)
    }
}

// MARK: - JeniCheck (v11.5 — the drawn check)
//
// The card's quick-mark circle (the Lovi grammar, founder-pointed):
// tap marks, the check draws itself on a spring, the land haptic
// confirms. The card body still enters the module; the long-press
// override sheet still exists. 44pt target around a 26pt mark.

struct JeniCheck: View {
    let isDone: Bool
    /// v17 — the mark's drawn size. 26 is the card register; a dense
    /// checklist row reads at 22 (the target frame stays ≥40).
    var size: CGFloat = 26
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 1

    var body: some View {
        Button {
            JeniHaptic.land()
            action()
        } label: {
            ZStack {
                // p64 — 0.16 was a hairline DECORATION weight on a
                // CONTROL: on an offered row's bare paper (water)
                // the open circle all but vanished (frame-caught).
                // 0.28 ink reads as "waiting to be tapped" while the
                // drawn state stays the loud half.
                Circle()
                    .strokeBorder(Palette.textPrimary.opacity(isDone ? 0 : 0.28),
                                  lineWidth: 1.5)
                Circle()
                    .fill(Palette.textPrimary)
                    .scaleEffect(isDone ? 1 : 0.001)
                CheckMark()
                    .trim(from: 0, to: isDone ? drawn : 0)
                    .stroke(Palette.textInverse,
                            style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                    .frame(width: size * 0.42, height: size * 0.42)
            }
            .frame(width: size, height: size)
            .frame(width: max(40, size + 14), height: max(40, size + 14))
            .contentShape(Circle())
            .animation(reduceMotion ? nil : JeniMotion.morph, value: isDone)
        }
        // p63 — the check answers the finger like every other object
        // (it was the one control inside a pressable row that stayed
        // rigid under the thumb).
        .buttonStyle(JeniPressable())
        .accessibilityLabel(Text(isDone ? "done. double-tap to unmark" : "mark done"))
    }
}

/// The check stroke, drawn tip-to-tail.
private struct CheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.08))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.1))
        return p
    }
}
