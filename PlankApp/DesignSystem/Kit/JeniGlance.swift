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
// A hairline track and an ink arc that TRACES in on arrival (charts
// draw — law §4.3), then MORPHS to any new fraction (a landed plate,
// a scope change). Never a second colour; over-window clamps at full
// and the words beside it say the rest (anti-shame, law §11.4).

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
            // The track reads as a full circle on the elevated card —
            // one step above hairline so the remainder is legible.
            Circle()
                .strokeBorder(Palette.textPrimary.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: drawn)
                .stroke(
                    Palette.textPrimary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
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
        withAnimation(JeniMotion.draw) { drawn = target }
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
                            .fill(Palette.hairlineCocoa)
                            .frame(height: 3)
                        Capsule()
                            .fill(Palette.textPrimary)
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
            let w = max(2, min(5, slot * 0.5))
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
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(Palette.textPrimary.opacity(
                                    i == values.count - 1 ? 0.95 : 0.28
                                ))
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
                HStack(spacing: gap) {
                    seg(width: usable * shares.p, ink: 0.92)
                    seg(width: usable * shares.c, ink: 0.5)
                    seg(width: usable * shares.f, ink: 0.26)
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

    private func seg(width: CGFloat, ink: Double) -> some View {
        Capsule()
            .fill(Palette.textPrimary.opacity(ink))
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
                            Circle().fill(Palette.textPrimary)
                            GlanceCheck()
                                .stroke(Palette.textInverse,
                                        style: StrokeStyle(lineWidth: 1.7, lineCap: .round,
                                                           lineJoin: .round))
                                .frame(width: dotSize * 0.38, height: dotSize * 0.38)
                        } else {
                            Circle()
                                .strokeBorder(
                                    Palette.textPrimary.opacity(day.isToday ? 0.42 : 0.14),
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
            JeniChart(
                model: JeniChartModel(form: .bars, series: [
                    .init(values: values, role: .ink)
                ]),
                height: 40
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
                HStack(spacing: 6) {
                    ForEach(0..<insights.count, id: \.self) { i in
                        Circle()
                            .fill(i == page
                                  ? Palette.textPrimary
                                  : Palette.textPrimary.opacity(0.14))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(JeniMotion.morph, value: page)
                .accessibilityHidden(true)
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
