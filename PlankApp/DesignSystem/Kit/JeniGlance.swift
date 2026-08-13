import SwiftUI
import UIKit

// MARK: - JeniGlance (v12 — the glance layer)
//
// docs/app_v12/00_CRAFT.md §2.1: the five pieces the craft pass adds
// to the kit. Everything here is ink on paper, token-only, arrival-
// aware (`\.jeniArrived`), Reduce Motion-honest, and colour-free —
// state is fraction and words, never a traffic light (D1).
//
//   JeniRing        — the drawn arc gauge (kcal's fraction at a glance)
//   JeniMetricBar   — labelled micro progress bar (the macro column)
//   JeniWeekDots    — the week dot row (R6's figure, in ink)
//   JeniScopeBar    — the time-scope selector (the ink capsule morphs)
//   JeniInsightPager— the editorial insight carousel (R6's grammar)

// MARK: - The visibility gate
//
// On a long page, `arrived` flips at load — a below-fold chart would
// run its whole choreography invisibly and sit dead when she reaches
// it. Glance pieces arm on `arrived AND first-visible`, so drawing
// happens where the eye is (the Fitness behavior). Above-the-fold
// content is visible at layout time, so page arrivals are unchanged.

private struct JeniVisibilityArm: ViewModifier {
    @Binding var seen: Bool

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Bool.self) { proxy in
                let f = proxy.frame(in: .global)
                return f.minY < UIScreen.main.bounds.height * 0.96 && f.maxY > 0
            } action: { visible in
                if visible { seen = true }
            }
    }
}

extension View {
    /// Latches `seen` the first time the view enters the viewport.
    /// Kit-internal: glance pieces + JeniChart + JeniCountingNumeral.
    func jeniArmOnVisible(_ seen: Binding<Bool>) -> some View {
        modifier(JeniVisibilityArm(seen: seen))
    }
}

// MARK: - The top scroll edge
//
// Law §13: content fading under the clock is chrome's job. iOS 26
// gets the system's soft scroll-edge; every OS keeps the paper
// gradient floor the surfaces already wear.

private struct JeniTopScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

extension View {
    /// Apply to a page's ScrollView: the soft system edge on iOS 26,
    /// nothing extra earlier (the gradient floor stays the floor).
    func jeniTopScrollEdge() -> some View {
        modifier(JeniTopScrollEdge())
    }
}

// MARK: - JeniRing
//
// v21 — THE ROSE RING (docs/app_v21 §4, §6.2). A blush track and a
// dusty→berry arc that TRACES in on the elastic spring (the hero
// shape carries physics — it overshoots ~4% and settles), then
// MORPHS to any new fraction (a landed plate, a scope change). The
// arc's arriving end always lands berry — the gradient's far stop
// rides the drawn fraction, the founder-loved demo's two-tone read.
// Over-window clamps at full and the words say the rest (§11.4).

struct JeniRing: View {
    /// 0…1; values above 1 render full (the words carry "window met").
    let fraction: Double
    var size: CGFloat = 92
    var lineWidth: CGFloat = 6

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: Double = 0
    @State private var seen = false

    private var target: Double { min(1, max(0, fraction)) }

    var body: some View {
        ZStack {
            // The track: the ring's remainder in blush — legible on
            // white and on paper, clearly "still open", never a judge.
            Circle()
                .strokeBorder(Palette.accent.opacity(0.16), lineWidth: lineWidth)
            // v25 E9 — THE PHASE FIX. The gradient carried its own
            // `angle: -90` AND the shape carried `.rotationEffect(-90)`,
            // so the ramp sat a quarter turn behind the arc it was
            // colouring: the arc began mid-ramp, and at a met floor
            // (`drawn == 1`) the ramp's dark end butted against its
            // light start at 9 o'clock as a hard tonal seam. Frame-caught
            // on Home's protein hero at 123 of 90 g. Both rotations now
            // live on the shape, so ramp and arc turn together.
            //
            // A complete ring is drawn as a CIRCLE rather than a full
            // trim: a round cap closing on itself overlaps its own start
            // whatever the colours are, and a met floor is the one state
            // this instrument most needs to render cleanly.
            Group {
                if drawn >= 1 {
                    Circle()
                        .inset(by: lineWidth / 2)
                        .stroke(Palette.roseBerry, lineWidth: lineWidth)
                } else {
                    Circle()
                        .inset(by: lineWidth / 2)
                        .trim(from: 0, to: drawn)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Palette.accent, location: 0),
                                    .init(color: Palette.roseBerry,
                                          location: max(0.001, drawn))
                                ]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                }
            }
            .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)   // the numeral beside it speaks
        .jeniArmOnVisible($seen)
        .onChange(of: arrived) { _, _ in trace() }
        .onChange(of: seen) { _, _ in trace() }
        .onAppear { trace() }
        .onChange(of: fraction) {
            // Re-keyed value: animate TO the new fraction (§4.5).
            withAnimation(reduceMotion ? nil : JeniMotion.morph) {
                drawn = target
            }
        }
    }

    private func trace() {
        guard arrived, seen, drawn == 0 else { return }
        if reduceMotion {
            drawn = target
            return
        }
        withAnimation(JeniMotion.elastic) { drawn = target }
    }
}

// MARK: - JeniMetricBar
//
// The macro column's cell (R3's tri-column): a quiet label, the
// value, and a 3pt bar that lands on the page's stagger. A metric
// without a collected denominator gets NO bar (D2 — a bar with an
// invented target is a lying chart); the column keeps its rhythm
// with a hairline resting line.

struct JeniMetricBar: View {
    let label: String
    let value: String
    /// nil = no collected target → no fill, resting hairline only.
    var fraction: Double? = nil
    /// v18 — THE SHAPE. A metric with no target still deserves a
    /// visual identity: its last seven days, today emphasized. Real
    /// collected values only (nil = a day with nothing logged), so
    /// the shape is evidence, never decoration. When a metric owns a
    /// floor it keeps the bar instead — a target beats a trend.
    var spark: [Double?]? = nil
    /// Position in the page's arrival choreography.
    var index: Int = 0

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var seen = false

    var body: some View {
        // v15 typography: the label recedes into tracked caps (system
        // metadata), the value steps up to 15pt — a hero's macros
        // should be readable at arm's length, not squinted at.
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                .kerning(0.7)
                .foregroundStyle(Palette.cocoaTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.custom("DMSans-Medium", size: 15, relativeTo: .subheadline))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            // v13: no collected target, no track — a resting hairline
            // implied an unmeasured bar (decoration carrying no
            // information). v18: what replaces it is not decoration
            // but the metric's own week.
            if let fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Palette.accent.opacity(0.16))
                            .frame(height: 3)
                        Capsule()
                            // v21: quantities fill rose; a met floor
                            // deepens to berry (emphasis, not verdict).
                            .fill(fraction >= 1 ? Palette.roseBerry : Palette.accent)
                            .frame(
                                width: max(3, geo.size.width * min(1, max(0, fraction)) * (landed ? 1 : 0)),
                                height: 3
                            )
                    }
                }
                .frame(height: 3)
            } else if let spark, spark.contains(where: { $0 != nil }) {
                JeniSparkRow(values: spark, landed: landed)
                    .frame(height: 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label), \(value)"))
        .jeniArmOnVisible($seen)
        .onChange(of: arrived) { _, _ in land() }
        .onChange(of: seen) { _, _ in land() }
        .onAppear { land() }
        .onChange(of: fraction) { landed = true }   // re-keys morph via width
    }

    private func land() {
        guard arrived, seen, !landed else { return }
        if reduceMotion {
            landed = true
            return
        }
        withAnimation(JeniMotion.arrive.delay(Double(index) * JeniMotion.stagger)) {
            landed = true
        }
    }
}

// MARK: - JeniSparkRow (v18 — the metric's own week, at cell scale)
//
// Seven marks, ~14pt tall: today in full ink, the rest receded, an
// unlogged day left as a hairline seat (never a zero — L8). Small
// enough to live inside a metric cell, loud enough that squinting
// tells you the direction. Bars grow on the page's stagger.

struct JeniSparkRow: View {
    let values: [Double?]
    var landed: Bool = true

    private var peak: Double {
        max(values.compactMap { $0 }.max() ?? 1, 0.0001)
    }

    /// The empty seats only earn their ink when most of the week is
    /// logged; on a sparse week a row of dashes reads as noise, not
    /// as absence (frame-caught).
    private var showsSeats: Bool {
        values.compactMap { $0 }.count >= max(3, values.count / 2)
    }

    var body: some View {
        GeometryReader { geo in
            let n = max(1, values.count)
            let slot = geo.size.width / CGFloat(n)
            // v21 (film-caught): capped at 5pt the marks read as
            // sparse dashes once a row got real width. Wider caps let
            // the week read as BARS at any scale.
            let w = max(2, min(9, slot * 0.55))
            HStack(spacing: 0) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    ZStack(alignment: .bottom) {
                        // The seat: where a day would sit if it were
                        // logged.
                        if showsSeats {
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(Palette.textPrimary.opacity(0.07))
                                .frame(width: w, height: 2)
                        }
                        if let v {
                            // A ROUNDED RECT, not a capsule: a capsule
                            // whose height falls under its width
                            // renders as a dot, so a genuinely low day
                            // read as "nothing logged" (frame-caught).
                            // The 3pt floor keeps a logged day visible
                            // as a MARK without misstating its size.
                            // v21: the week wears the ramp — today
                            // berry, the rest blush.
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(
                                    i == values.count - 1
                                        ? Palette.roseBerry : Palette.roseBlush
                                )
                                .frame(
                                    width: w,
                                    height: landed
                                        ? max(3, geo.size.height * CGFloat(v / peak))
                                        : 3
                                )
                        }
                    }
                    .frame(width: slot)
                }
            }
            .frame(height: geo.size.height, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - JeniMacroSplit (v18.1 — one shape for the relationship)
//
// Five independent sparks put 35 marks in a band and read as noise
// (founder-caught). The macros' honest visual isn't five trends —
// it's ONE relationship: how today's energy divides. Segment widths
// are derived from the collected grams (4 kcal/g protein and carbs,
// 9 for fat), so nothing is invented; a 2pt surface gap separates
// them, in the reading order of the columns above.

struct JeniMacroSplit: View {
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    var landed: Bool = true

    private var shares: (p: Double, c: Double, f: Double)? {
        let p = Double(proteinG) * 4, c = Double(carbsG) * 4, f = Double(fatG) * 9
        let total = p + c + f
        guard total > 0 else { return nil }
        return (p / total, c / total, f / total)
    }

    var body: some View {
        GeometryReader { geo in
            if let shares {
                let gap: CGFloat = 2
                let usable = max(0, geo.size.width - gap * 2)
                // v21 D11 — the ramp's depths follow clinical priority
                // (protein owns the floor), never judgment.
                HStack(spacing: gap) {
                    seg(width: usable * shares.p, color: Palette.roseBerry)
                    seg(width: usable * shares.c, color: Palette.accent)
                    seg(width: usable * shares.f, color: Palette.roseBlush)
                }
                .frame(width: geo.size.width, alignment: .leading)
                .opacity(landed ? 1 : 0)
                .animation(JeniMotion.arrive, value: landed)
            }
        }
        .frame(height: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "energy split: protein, carbohydrate, fat"
        ))
    }

    private func seg(width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: max(0, width), height: 5)
    }
}

// MARK: - JeniWeekDots
//
// R6's figure: seven discs, one week. A filled disc is a day that
// happened (its check draws); an empty day is a quiet ring — never a
// mark against her (anti-shame). Today may be emphasized. Dots land
// on a stagger, silently (haptics belong to actions, not ambience).

struct JeniWeekDots: View {
    struct Day: Identifiable {
        let id: Int
        var filled: Bool
        var isToday: Bool = false
        var letter: String? = nil
    }

    let days: [Day]
    var dotSize: CGFloat = 26

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landedCount = 0
    @State private var seen = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    ZStack {
                        if day.filled {
                            // v21: a day that happened is DATA — it
                            // fills from the ramp, not from the ink.
                            Circle().fill(Palette.roseBerry)
                            GlanceCheck()
                                .stroke(Palette.textInverse,
                                        style: StrokeStyle(lineWidth: 1.7, lineCap: .round,
                                                           lineJoin: .round))
                                .frame(width: dotSize * 0.38, height: dotSize * 0.38)
                        } else {
                            Circle()
                                .strokeBorder(
                                    day.isToday
                                        ? Palette.roseBerry.opacity(0.55)
                                        : Palette.textPrimary.opacity(0.14),
                                    lineWidth: day.isToday ? 1.6 : 1.2
                                )
                        }
                    }
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(day.id < landedCount ? 1 : 0.4)
                    .opacity(day.id < landedCount ? 1 : 0)
                    if let letter = day.letter {
                        Text(letter)
                            .font(Typo.statLabel)
                            .foregroundStyle(
                                day.isToday ? Palette.textPrimary : Palette.cocoaTertiary
                            )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(a11yText))
        .jeniArmOnVisible($seen)
        .onChange(of: arrived) { _, _ in land() }
        .onChange(of: seen) { _, _ in land() }
        .onAppear { land() }
    }

    private var a11yText: String {
        let kept = days.filter(\.filled).count
        return "\(kept) of \(days.count) days"
    }

    private func land() {
        guard arrived, seen, landedCount < days.count else { return }
        if reduceMotion {
            landedCount = days.count
            return
        }
        for i in 0..<days.count {
            withAnimation(JeniMotion.arrive.delay(Double(i) * 0.05)) {
                landedCount = max(landedCount, i + 1)
            }
        }
    }
}

/// The kit's check stroke at glance scale (JeniCheck's path, shared).
struct GlanceCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.08))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.1))
        return p
    }
}

// MARK: - JeniScope + JeniScopeBar
//
// The dashboard's time selector. Words, not a segmented control (D6):
// the ink capsule MORPHS between words — the app's one selection
// grammar (law §5.4) — and the content beneath re-keys, never
// reloads (§4.5).

enum JeniScope: String, CaseIterable, Identifiable {
    case today, week, month, threeMonths, year, all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "today"
        case .week: return "week"
        case .month: return "month"
        case .threeMonths: return "3 months"
        case .year: return "year"
        case .all: return "all"
        }
    }

    /// The window this scope reads, in days ending today. nil = the
    /// whole record.
    var windowDays: Int? {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 91
        case .year: return 365
        case .all: return nil
        }
    }

    /// The comparison window's word ("last week") — deltas name their
    /// basis or stay silent.
    var previousWord: String? {
        switch self {
        case .today: return "yesterday"
        case .week: return "last week"
        case .month: return "last month"
        case .threeMonths, .year, .all: return nil
        }
    }
}

struct JeniScopeBar: View {
    @Binding var scope: JeniScope
    /// Scopes a surface offers (Becoming skips none; others may trim).
    var scopes: [JeniScope] = JeniScope.allCases

    @Namespace private var capsuleNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(scopes) { s in
                    let selected = s == scope
                    Button {
                        guard !selected else { return }
                        JeniHaptic.tick()
                        withAnimation(reduceMotion ? nil : JeniMotion.morph) {
                            scope = s
                        }
                    } label: {
                        Text(s.label)
                            .font(.custom(
                                selected ? "DMSans-SemiBold" : "DMSans-Medium",
                                size: 13, relativeTo: .caption
                            ))
                            .foregroundStyle(
                                selected ? Palette.textInverse : Palette.textSecondary
                            )
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(Palette.textPrimary)
                                        .matchedGeometryEffect(id: "scope.capsule", in: capsuleNS)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(s.label))
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - JeniInsight (the model)
//
// One meaningful fact in R6's grammar: eyebrow → the numeral and its
// word → one drawn figure → one plain sentence. Every insight traces
// to a collected store and renders ONLY past its floor (D9) — an
// insight without data is decoration.

struct JeniInsight: Identifiable {
    enum Figure {
        case weekDots([JeniWeekDots.Day])
        case spark([Double?])
        case bars([Double?])
        case none
    }

    let id: String
    /// Tracked-caps whisper ("PROTEIN", "CONSISTENCY").
    let eyebrow: String
    /// The hero value. Counts in when numeric.
    let value: Double?
    /// Rendered value when not a plain number ("down 8%").
    var valueText: String? = nil
    /// The small word beside the numeral ("days", "nights").
    let word: String
    let figure: Figure
    /// Jeni's one sentence about it.
    let sentence: String
    var sentenceItalic: [String] = []
}

// MARK: - JeniInsightCard

struct JeniInsightCard: View {
    let insight: JeniInsight

    // v14 — CHROMELESS (the R6 reference is a page, not a card):
    // the insight sits directly on the paper, typography does all
    // the work, the numeral grows to full editorial scale. Every
    // card should be worth screenshotting.
    var body: some View {
        // v16 — the card HUGS its content. With `maxHeight: .infinity`
        // its Spacers absorbed every spare point of the frame and blew
        // a 60pt void between the eyebrow and the numeral (frame-
        // caught). Fixed gaps, top-aligned: the card is exactly as
        // tall as what it says.
        VStack(alignment: .leading, spacing: 8) {
            Text(insight.eyebrow.uppercased())
                .font(Typo.statLabel)
                .kerning(1.4)
                .foregroundStyle(Palette.cocoaTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let value = insight.value {
                    JeniCountingNumeral(
                        value: value,
                        font: .custom("JeniHeroSerif-Regular", size: 38,
                                      relativeTo: .largeTitle)
                    )
                } else if let text = insight.valueText {
                    Text(text)
                        .font(.custom("JeniHeroSerif-Regular", size: 36,
                                      relativeTo: .title2))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(insight.word)
                    .font(.custom("JeniHeroSerif-Regular", size: 20, relativeTo: .title3))
                    .foregroundStyle(Palette.textPrimary.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            figureView
                .frame(height: 24)

            ItalicAccentText(
                insight.sentence,
                italic: insight.sentenceItalic,
                baseFont: .custom("DMSans-Regular", size: 13, relativeTo: .caption),
                italicFont: .custom("DMSans-Medium", size: 13, relativeTo: .caption)
            )
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(insight.sentence))
    }

    @ViewBuilder private var figureView: some View {
        switch insight.figure {
        case .weekDots(let days):
            JeniWeekDots(days: days, dotSize: 22)
        case .spark(let values):
            JeniChart(
                model: JeniChartModel(form: .spark, series: [
                    .init(values: values, role: .ink)
                ], bridgeGaps: true),
                height: 40
            )
        case .bars(let values):
            // v21 — the figure recedes to blush with "now" in berry;
            // a full-saturation fortnight shouted over its own
            // headline (frame-caught).
            JeniChart(
                model: JeniChartModel(form: .bars, series: [
                    .init(values: values, role: .ink)
                ]),
                height: 40,
                emphasizeLast: true
            )
        case .none:
            Color.clear
        }
    }
}

// MARK: - JeniInsightPager
//
// The carousel: native page snap, ink page dots, a tick per page.
// Cards keep one fixed height so the pager never reflows the page
// beneath it.

struct JeniInsightPager: View {
    let insights: [JeniInsight]
    /// The design height at the default type size. The FRAME must
    /// scale with Dynamic Type or the card clips its own eyebrow and
    /// its last line at XXXL (frame-caught on the accessibility
    /// pass) — a fixed box around scaling type is always a bug.
    var height: CGFloat = 132
    /// DEBUG tours: the pager walks its own pages for the camera.
    var tourAutoAdvance: Bool = false

    @State private var page = 0
    @State private var seen = false
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            TabView(selection: $page) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { idx, insight in
                    JeniInsightCard(insight: insight)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: height * max(1, typeScale / 100))
            .onChange(of: page) { JeniHaptic.tick() }

            if insights.count > 1 {
                JeniPageDots(count: insights.count, current: page)
                    .frame(maxWidth: .infinity)
            }
        }
        .jeniArmOnVisible($seen)
        .task {
            guard tourAutoAdvance, insights.count > 1 else { return }
            while !seen, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            for next in 1..<insights.count {
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(JeniMotion.morph) { page = next }
            }
        }
    }
}

// MARK: - JeniPageDots (v21 — the carousel's index)
//
// One grammar for every pager in the app: blush dots at rest, the
// current page a berry pill that the neighbouring dot MORPHS into.
// Decorative — the pages themselves carry the accessibility story.

struct JeniPageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(i == current ? Palette.roseBerry : Palette.roseBlush)
                    .frame(width: i == current ? 16 : 5, height: 5)
            }
        }
        .animation(JeniMotion.morph, value: current)
        .accessibilityHidden(true)
    }
}

// MARK: - JeniTaskRow (v21 — a task is an OBJECT, not a sentence)
//
// docs/app_v21 §6.3, the Lovi/demo grammar in Jeni's language: a
// white row (radius 18) led by an IDENTITY CHIP (blush seat, berry
// symbol — or the day's real photograph when one exists), the words
// in the middle, the drawn check trailing. Row tap OPENS the module;
// the check quick-marks; long-press raises the mark sheet — all
// three affordances of the v11.5 row survive.
//
// Completion is choreography, not a repaint: the check draws, the
// chip pulses once on the elastic spring, and the row COMPRESSES to
// a 44pt receipt (chip 40→24, note fades) so the list quietly gets
// shorter as the day gets done. An offered row keeps the spine on
// bare paper with a dashed chip seat — an invitation, never debt
// (the sunken law: a tinted fill on a light page reads as disabled).

struct JeniTaskRow: View {
    enum Chip {
        case symbol(String)
        /// A doodle asset from the stationery stroke register (v21 —
        /// the founder's hand-drawn set; template-tinted like a
        /// symbol). §12.6's stated preference, no longer an exception.
        case doodle(String)
        case photo(UIImage)
    }

    let title: String
    var note: String? = nil
    var chip: Chip = .symbol("circle")
    /// Offered rows sit on paper, carry no check, and never compress.
    var offered: Bool = false
    var isDone: Bool = false
    /// The lead reads SemiBold; everything else Medium.
    var emphasized: Bool = false
    /// THE CLINICAL REGISTER (v8 law): medication surfaces carry no
    /// rose and no celebration — the chip seat goes neutral ink, the
    /// glyph goes ink, the pulse stays (it is physics, not ornament).
    var clinical: Bool = false
    /// The promoted lead's dose-dot (D1 grant b — render-only).
    var showsDot: Bool = false
    let onOpen: () -> Void
    /// nil on offered rows — nothing to mark.
    var onQuickMark: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var longPressLatch = false
    @State private var chipPulse = false

    private var chipSize: CGFloat { isDone && !offered ? 24 : 40 }
    /// Accessibility sizes trade the single-line row for a wrapped
    /// one — truncated words are not a checklist (§10.2).
    private var titleLines: Int { typeSize.isAccessibilitySize ? 2 : 1 }

    var body: some View {
        Button {
            if longPressLatch {
                longPressLatch = false
                return
            }
            onOpen()
        } label: {
            HStack(alignment: .center, spacing: 11) {
                chipView
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        if showsDot {
                            Circle()
                                .fill(Palette.accent)
                                .frame(width: 4, height: 4)
                                .accessibilityHidden(true)
                        }
                        Text(title)
                            .font(.custom(
                                emphasized ? "DMSans-SemiBold" : "DMSans-Medium",
                                size: 15, relativeTo: .subheadline
                            ))
                            .foregroundStyle(
                                offered ? Palette.textPrimary.opacity(0.72)
                                    : isDone ? Palette.cocoaTertiary
                                    : Palette.textPrimary
                            )
                            .lineLimit(titleLines)
                            .minimumScaleFactor(0.85)
                    }
                    if let note, !(isDone && !offered) {
                        Text(note)
                            .font(.custom("DMSans-Regular", size: 11.5, relativeTo: .caption2))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(titleLines)
                            .minimumScaleFactor(0.85)
                            .transition(.opacity)
                    }
                }
                Spacer(minLength: Space.sm)
                if !offered, let onQuickMark {
                    JeniCheck(isDone: isDone, size: 22) {
                        onQuickMark()
                    }
                }
            }
            .padding(.vertical, isDone && !offered ? 5 : 10)
            .padding(.horizontal, 12)
            .background {
                if !offered {
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .fill(Palette.bgElevated.opacity(isDone ? 0.55 : 1))
                        .shadow(color: Palette.textPrimary.opacity(isDone ? 0 : 0.035),
                                radius: 8, x: 0, y: 2)
                }
            }
            .contentShape(Rectangle())
            .opacity(isDone && !offered ? 0.8 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.2) : JeniMotion.settle,
                       value: isDone)
        }
        .buttonStyle(JKPress())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                guard let onLongPress else { return }
                longPressLatch = true
                JeniHaptic.land()
                onLongPress()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    longPressLatch = false
                }
            }
        )
        .onChange(of: isDone) { _, done in
            guard done, !offered, !reduceMotion else { return }
            withAnimation(JeniMotion.elastic) { chipPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(JeniMotion.settle) { chipPulse = false }
            }
        }
        .accessibilityLabel(a11yLabel)
        .accessibilityHint(Text(
            offered ? "optional today. double-tap to open."
                : "double-tap to open. long-press to mark."
        ))
    }

    @ViewBuilder private var chipView: some View {
        ZStack {
            if offered {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(Palette.textPrimary.opacity(0.14),
                                  style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            } else {
                RoundedRectangle(cornerRadius: isDone ? 8 : Radius.chip,
                                 style: .continuous)
                    .fill(
                        clinical
                            ? Palette.textPrimary.opacity(0.06)
                            : Palette.accentSubtle.opacity(isDone ? 0.55 : 1)
                    )
            }
            switch chip {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: isDone && !offered ? 11 : 16,
                                  weight: .medium))
                    .foregroundStyle(
                        offered ? Palette.textPrimary.opacity(0.45)
                            : clinical ? Palette.textPrimary.opacity(0.75)
                            : Palette.roseBerry.opacity(isDone ? 0.6 : 1)
                    )
            case .doodle(let name):
                Image(name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: chipSize * 0.56, height: chipSize * 0.56)
                    .foregroundStyle(
                        offered ? Palette.textPrimary.opacity(0.45)
                            : clinical ? Palette.textPrimary.opacity(0.75)
                            : Palette.roseBerry.opacity(isDone ? 0.6 : 1)
                    )
            case .photo(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: chipSize, height: chipSize)
                    .clipShape(RoundedRectangle(
                        cornerRadius: isDone ? 8 : Radius.chip,
                        style: .continuous
                    ))
                    .opacity(isDone ? 0.6 : 1)
            }
        }
        .frame(width: chipSize, height: chipSize)
        .scaleEffect(chipPulse ? 1.07 : 1)
        .accessibilityHidden(true)
    }

    private var a11yLabel: Text {
        var parts = [title]
        if offered { parts.append("optional today") }
        else if isDone { parts.append("done") }
        if let note, !(isDone && !offered) { parts.append(note) }
        return Text(parts.joined(separator: ", "))
    }
}

// MARK: - JeniToolTile (v21 — a destination with an instrument)
//
// docs/app_v21 §6.4: the word and the state line kept their v13 law
// (words carry identity, the state line carries life); what's new is
// the INSTRUMENT — a small live shape on the tile's right that only
// renders what a store produced: the last plate's photograph, the
// week's micro-sparkline, today's step ring. The tile is a place,
// and places show their weather.

struct JeniToolTile<Instrument: View>: View {
    let word: String
    let status: String
    let action: () -> Void
    @ViewBuilder var instrument: () -> Instrument

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button {
            JeniHaptic.tick()
            action()
        } label: {
            JeniSurface(radius: Radius.card, padding: 13) {
                HStack(alignment: .center, spacing: Space.sm) {
                    VStack(alignment: .leading, spacing: 3) {
                        // v25 E9 — one line is right in the two-across
                        // grid (uniform tile heights) and wrong the
                        // moment the reader's type outgrows the column:
                        // XXXL filmed "sna…", "wei…", "bod…". At
                        // accessibility sizes Home gives the grid a
                        // single column, so the word can afford to wrap
                        // rather than truncate.
                        Text(word)
                            .font(.custom("DMSans-SemiBold", size: 14, relativeTo: .footnote))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(status)
                            .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 2)
                    instrument()
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniPressable())
        .accessibilityLabel("\(word). \(status)")
    }
}

// MARK: - PlateEnergySplit (v25 E9 — one relationship, one shape)
//
// v21 grew the 5pt `JeniMacroSplit` whisper into a 14pt instrument for
// Home's plate face. E9 removed that carousel face and the split became
// the ONE shape the day's energy gets — on Home's food band and on the
// plate reading, which is why it moved into the kit instead of staying
// private to Home. Two surfaces drawing the same relationship must draw
// it with the same object.
//
// Same honesty as ever: widths derive from collected grams (4/4/9 kcal
// per gram), nothing invented, and the legend beside it does the
// speaking (the bar itself is accessibility-hidden).

struct PlateEnergySplit: View {
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var seen = false

    private var shares: (p: Double, c: Double, f: Double)? {
        let p = Double(proteinG) * 4, c = Double(carbsG) * 4, f = Double(fatG) * 9
        let total = p + c + f
        guard total > 0 else { return nil }
        return (p / total, c / total, f / total)
    }

    var body: some View {
        GeometryReader { geo in
            if let shares {
                let gap: CGFloat = 3
                let usable = max(0, geo.size.width - gap * 2)
                HStack(spacing: gap) {
                    seg(usable * shares.p, Palette.roseBerry)
                    seg(usable * shares.c, Palette.accent)
                    seg(usable * shares.f, Palette.roseBlush)
                }
                .frame(width: geo.size.width, alignment: .leading)
                .scaleEffect(x: landed ? 1 : 0.001, anchor: .leading)
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)   // the legend beneath speaks
        .jeniArmOnVisible($seen)
        .onChange(of: arrived) { _, _ in land() }
        .onChange(of: seen) { _, _ in land() }
        .onAppear { land() }
    }

    private func seg(_ width: CGFloat, _ color: Color) -> some View {
        Capsule(style: .continuous)
            .fill(color)
            .frame(width: max(0, width), height: 14)
    }

    private func land() {
        guard arrived, seen, !landed else { return }
        if reduceMotion {
            landed = true
            return
        }
        withAnimation(JeniMotion.draw) { landed = true }
    }
}
