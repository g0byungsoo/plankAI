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
    /// Position in the page's arrival choreography.
    var index: Int = 0

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var seen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(Typo.statLabel)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(value)
                .font(.custom("DMSans-Medium", size: 13, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary.opacity(0.85))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 3)
                    if let fraction {
                        Capsule()
                            .fill(Palette.textPrimary)
                            .frame(
                                width: max(3, geo.size.width * min(1, max(0, fraction)) * (landed ? 1 : 0)),
                                height: 3
                            )
                    }
                }
            }
            .frame(height: 3)
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

    var body: some View {
        JeniSurface {
            VStack(alignment: .leading, spacing: 0) {
                Text(insight.eyebrow.uppercased())
                    .font(Typo.statLabel)
                    .kerning(1.2)
                    .foregroundStyle(Palette.cocoaTertiary)

                Spacer(minLength: Space.sm)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let value = insight.value {
                        JeniCountingNumeral(
                            value: value,
                            font: .custom("JeniHeroSerif-Regular", size: 58,
                                          relativeTo: .largeTitle)
                        )
                    } else if let text = insight.valueText {
                        Text(text)
                            .font(.custom("JeniHeroSerif-Regular", size: 40,
                                          relativeTo: .largeTitle))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Text(insight.word)
                        .font(.custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title2))
                        .foregroundStyle(Palette.textPrimary.opacity(0.55))
                }

                Spacer(minLength: Space.sm)

                figureView
                    .frame(height: 44)

                Spacer(minLength: Space.md)

                ItalicAccentText(
                    insight.sentence,
                    italic: insight.sentenceItalic,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 19, relativeTo: .title3)
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
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
    var height: CGFloat = 264
    /// DEBUG tours: the pager walks its own pages for the camera.
    var tourAutoAdvance: Bool = false

    @State private var page = 0
    @State private var seen = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            TabView(selection: $page) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { idx, insight in
                    JeniInsightCard(insight: insight)
                        .tag(idx)
                        // Air for JeniSurface's diffuse shadow — a page
                        // clips at its own bounds.
                        .padding(.bottom, 14)
                        .padding(.horizontal, 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: height)
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
