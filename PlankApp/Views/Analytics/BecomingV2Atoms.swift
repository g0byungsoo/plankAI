import SwiftUI
import PlankFood
import PlankSync

// MARK: - Becoming v1.2 premium atoms (2026-06-18)
//
// Synthesized from the cohort-research + competitive-scan briefs. The
// dashboard register shifts from "magazine reportage" to "quiet diary
// entry" — written by her future self to her present self, in her own
// voice, with the kindness she can't quite give herself yet.
//
// Three signature design moves are reused across atoms:
//
//   • The 80ms perceptual lag (Whoop): number-rolls start `Motion.
//     perceptualLag` after the visual primary lands. Cause precedes
//     effect.
//   • The eased-final-20% number-roll (Apple Fitness+ Wrapped):
//     `Motion.easedFinal` cubic-bezier-(0.22, 1.0, 0.36, 1.0) over
//     1.6s — last 20% of the count is ~6× slower than the first 20%.
//   • The breathing text shadow (Calm): 3s ease-in-out indefinite
//     pulse on hero italics. Connects masthead + insight line via
//     shared ambient motion → reads as one breath.
//
// Voice: lowercase casual, italic-Fraunces on numerals + identity
// punch words only, hearts as terminal punctuation on the warmest
// beats. No "AI," no "crush," no "deficit," no calendar heatmap, no
// red bars, no fire emoji.

// MARK: - BecomingDiaryHero
//
// Page-opening: spelled-out day number with the breathing serif glow,
// supporting meta line, and a one-sentence diary entry from her own
// data. Replaces the previous folio masthead — same data, warmer
// register, signature breathing pulse on the serif numeral.
//
// Per cohort brief: "she opens the app when her boyfriend is sleeping,
// when she's spiraling in the bathroom mirror. The dashboard's job is
// to interrupt the rumination loop with evidence of self."

struct BecomingDiaryHero: View {
    let dayNumber: Int
    let totalDays: Int?
    let dateRange: String?
    let showedUpCount: Int   // engagedDates across the entire program/year
    let identityLine: String
    let identityItalic: [String]

    private var dayWord: String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: dayNumber)) ?? "\(dayNumber)"
    }

    private var showedUpWord: String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: showedUpCount)) ?? "\(showedUpCount)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Day count — italic-Fraunces punch word IS the day word;
            // breathing shadow gives the numeral a quiet pulse so the
            // top of the page reads "alive" before the user scrolls.
            (Text("day ").font(Typo.heroHeadline)
             + Text(dayWord).font(Typo.heroHeadlineItalic))
                .foregroundStyle(Palette.textPrimary)
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)
                .breathingShadow()

            // Meta row — program horizon + date range when available,
            // engagement framing otherwise. Same compact DM Sans body
            // as the prior folio.
            HStack(spacing: 6) {
                if let totalDays {
                    Text("of \(totalDays) days")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    Text("of showing up")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
                if let dateRange {
                    Text("·").foregroundStyle(Palette.divider)
                    Text(dateRange)
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            // Diary line — *the* cohort-specified move. Self-narration
            // beats outcome-tracking (Annesi 2011) on 90-day adherence;
            // the line says what she did without asking her to log
            // anything. Hidden when she has nothing to say yet (a
            // session-1 user lands on the identity line below alone).
            if showedUpCount > 0 {
                (Text("you've shown up ")
                    .font(.custom("DMSans-Regular", size: 14))
                + Text(showedUpWord)
                    .font(.custom("JeniHeroSerif-Italic", size: 15))
                + Text(" times \u{2661}")
                    .font(.custom("DMSans-Regular", size: 14)))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 6)
            }

            // Identity line — derived `becomingStateWord` from existing
            // logic. Stays the closing punctuation of the hero block.
            ItalicAccentText(
                identityLine,
                italic: identityItalic,
                baseFont: Typo.body,
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
                color: Palette.textPrimary,
                alignment: .leading
            )
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - BecomingDeedsCounter
//
// The signature cumulative-deeds module — "X plates kept · Y lessons
// read · Z hours of food noise quieted." Net-positive register, not
// daily pressure. Robinhood number-roll: counts up from 0 every time
// the screen mounts → ritualizes return. Each open re-earns the
// number.
//
// Per cohort brief: "Strava's 'lifetime miles' is the most-screenshot-
// shared Strava UI element. Cumulative-positive = identity scaffold."

struct BecomingDeedsCounter: View {
    let plates: Int
    let lessons: Int
    let breathMinutes: Int   // optional — pass 0 to hide

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Eyebrow — quiet diary-page header. Lowercase, DM Sans.
            Text("you've kept ")
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundStyle(Palette.textSecondary)
            + Text("count")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                .foregroundStyle(Palette.textSecondary)

            // Deeds — 3 lines, italic-Fraunces numeral + DM Sans noun.
            // The 80ms perceptual lag between rows reads as a cascade
            // arriving, not a list animating.
            VStack(alignment: .leading, spacing: 6) {
                deedRow(value: plates, label: "plates kept", delay: 0.0)
                if lessons > 0 {
                    deedRow(value: lessons, label: lessons == 1 ? "lesson read" : "lessons read", delay: 0.06)
                }
                if breathMinutes > 0 {
                    deedRow(
                        value: breathMinutes,
                        label: breathMinutes == 1 ? "minute of breath" : "minutes of breath",
                        delay: 0.12
                    )
                }
            }

            // Closing diary punctuation — the "food noise quieted" line
            // when she has reads + breaths logged. Per cohort brief:
            // "food noise" is whitespace; no competitor surfaces it.
            // Conservative formula: lessons × 10min + breath × 5min ÷ 60.
            if foodNoiseHours > 0 {
                Text(foodNoiseLine)
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    private var foodNoiseHours: Int {
        let minutes = lessons * 10 + (breathMinutes / 12)
        return minutes / 60
    }

    private var foodNoiseLine: AttributedString {
        var prefix = AttributedString("food noise: ")
        prefix.font = .custom("DMSans-Regular", size: 13)
        var punch = AttributedString("\(foodNoiseHours) hours quieted")
        punch.font = .custom("Fraunces72pt-SemiBoldItalic", size: 14)
        return prefix + punch
    }

    private var a11yLabel: String {
        var parts: [String] = ["\(plates) plates kept"]
        if lessons > 0 { parts.append("\(lessons) lessons read") }
        if breathMinutes > 0 { parts.append("\(breathMinutes) minutes of breath") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func deedRow(value: Int, label: String, delay: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            CountUpNumber(
                target: value,
                fontName: "JeniHeroSerif-Regular",
                italicFontName: "JeniHeroSerif-Italic",
                size: 28,
                color: Palette.textPrimary,
                rollDuration: 0.9 + delay,    // longer roll on later rows
                curtsyDelay: 0.95 + delay,    // curtsy after the cascade settles
                curtsyIn: 0.14,
                curtsyHold: 0.06,
                curtsyOut: 0.18
            )
            .frame(minWidth: 56, alignment: .leading)
            Text(label)
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

// MARK: - BecomingTrendCanvas
//
// The hero chart, rebuilt from stock SwiftUI `Chart` to custom Canvas
// so the trend line can be a flowing gradient stroke (cocoa → accent
// → cocoa) that draws in left-to-right over 1.2s on appearance, then
// shimmers gently while idle.
//
// The y-axis numbers stay hidden by default — per cohort brief, hidden
// y-axis lets the trend SHAPE land first, defusing scale-anxiety. The
// headline weight floats above the chart on the left, italic-Fraunces.
//
// Tap-and-drag along the canvas reveals a vertical scrub line + the
// data point under the finger; the headline number rolls to match,
// monospacedDigit, with a soft haptic per data-point traversal.

struct BecomingTrendCanvas: View {
    let logs: [WeightLogRecord]
    let goalWeightKg: Double?
    var unit: WeightUnit = .lb
    var height: CGFloat = 168

    @State private var drawProgress: Double = 0     // 0...1 — line trace-in
    @State private var shimmerPhase: Double = 0     // 0...1 — idle gradient flow
    @State private var scrubFraction: Double? = nil // 0...1 — drag position
    @State private var lastHapticIndex: Int = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var points: [WeightTrendChart.EMAPoint] {
        WeightTrendChart.computeEMA(logs: logs)
    }

    private func toDisplay(_ kg: Double) -> Double { unit.display(fromKg: kg) }

    /// The currently-visible weight number — either the scrubbed
    /// point or the most-recent EMA.
    private var headlineWeightLb: Double {
        if let frac = scrubFraction, !points.isEmpty {
            let idx = min(points.count - 1, max(0, Int(Double(points.count - 1) * frac)))
            return toDisplay(points[idx].emaKg)
        }
        return toDisplay(points.last?.emaKg ?? 0)
    }

    private var headlineDateLabel: String? {
        guard let frac = scrubFraction, !points.isEmpty else { return nil }
        let idx = min(points.count - 1, max(0, Int(Double(points.count - 1) * frac)))
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: points[idx].date).lowercased()
    }

    var body: some View {
        if points.count < 2 {
            // Cold-start placeholder — never an empty chart.
            placeholder
        } else {
            VStack(alignment: .leading, spacing: 8) {
                headline
                trendCanvas
                xAxisLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Headline

    @ViewBuilder private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text("your trend")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(Palette.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", headlineWeightLb))
                        .font(.custom("JeniHeroSerif-Regular", size: 48))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: headlineWeightLb)
                    Text(unit.label)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                        .foregroundStyle(Palette.textSecondary)
                        .baselineOffset(6)
                }
            }
            Spacer()
            if let scrubDate = headlineDateLabel {
                Text(scrubDate)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    .foregroundStyle(Palette.accent)
                    .transition(.opacity)
            } else if !points.isEmpty,
                      let firstDate = points.first?.date,
                      let lastDate = points.last?.date,
                      let days = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day,
                      days > 0 {
                Text("\(days) days")
                    .font(.custom("DMSans-Medium", size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    // MARK: - Canvas chart

    @ViewBuilder private var trendCanvas: some View {
        // Canvas's closure receives the actual drawing-region size, so
        // we sidestep GeometryReader's layout-race entirely. TimelineView
        // pumps a fresh phase value at 30fps for the idle shimmer; the
        // Canvas re-renders against the latest drawProgress @State.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            Canvas { ctx, canvasSize in
                let yDom = yDomain
                let mapped = points.enumerated().map { (i, p) -> CGPoint in
                    let x = CGFloat(i) / CGFloat(max(1, points.count - 1)) * canvasSize.width
                    let yVal = toDisplay(p.emaKg)
                    let y = canvasSize.height
                        - CGFloat((yVal - yDom.lowerBound) / max(0.0001, yDom.upperBound - yDom.lowerBound))
                        * canvasSize.height
                    return CGPoint(x: x, y: y)
                }
                let phase = reduceMotion
                    ? 0.5
                    : (context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6.0) / 6.0)
                drawLine(ctx: ctx, points: mapped, size: canvasSize, phase: phase, progress: drawProgress)
                drawScrubMarker(ctx: ctx, points: mapped, size: canvasSize)
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .contentShape(Rectangle())
        .gesture(scrubGesture)
        .task {
            // Use task instead of onAppear so the animation block runs
            // on the MainActor after the view actually mounts. onAppear
            // was firing before SwiftUI's animation transaction was
            // ready in the TimelineView wrapper, leaving drawProgress
            // stuck at 0.
            try? await Task.sleep(nanoseconds: UInt64(Motion.perceptualLag * 1_000_000_000))
            if reduceMotion {
                drawProgress = 1
            } else {
                withAnimation(Motion.trendDrawIn) {
                    drawProgress = 1
                }
            }
        }
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Map x to fraction.
                let width = max(1.0, UIScreen.main.bounds.width - 48) // outer padding aware fallback
                let frac = min(1.0, max(0.0, value.location.x / width))
                scrubFraction = frac
                let idx = min(points.count - 1, max(0, Int(Double(points.count - 1) * frac)))
                if idx != lastHapticIndex {
                    lastHapticIndex = idx
                    let gen = UIImpactFeedbackGenerator(style: .soft)
                    gen.impactOccurred(intensity: 0.4)
                }
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.32)) {
                    scrubFraction = nil
                }
                lastHapticIndex = -1
            }
    }

    @ViewBuilder private var xAxisLabel: some View {
        if !points.isEmpty,
           let first = points.first?.date,
           let last = points.last?.date {
            HStack {
                Text(monthDayLabel(first))
                    .font(.custom("DMSans-Regular", size: 10))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(monthDayLabel(last))
                    .font(.custom("DMSans-Regular", size: 10))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private func monthDayLabel(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: d).lowercased()
    }

    // MARK: - Placeholder

    @ViewBuilder private var placeholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("your trend")
                .font(.custom("DMSans-Medium", size: 12))
                .foregroundStyle(Palette.textSecondary)
            (Text("a line takes ")
                .font(.custom("JeniHeroSerif-Regular", size: 24))
            + Text("two")
                .font(.custom("JeniHeroSerif-Italic", size: 24))
            + Text(" points.")
                .font(.custom("JeniHeroSerif-Regular", size: 24)))
                .foregroundStyle(Palette.textPrimary)
                .lineSpacing(Typo.heroHeadlineLineGap)
            Text("log a few more days — your trend draws itself.")
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Drawing

    private func drawLine(
        ctx: GraphicsContext,
        points: [CGPoint],
        size: CGSize,
        phase: Double,
        progress: Double
    ) {
        guard points.count >= 2 else { return }

        let visibleCount = max(2, Int(Double(points.count) * progress))
        let visible = Array(points.prefix(visibleCount))

        // Soft fill underneath — fades to nothing at the baseline.
        var fillPath = Path()
        fillPath.move(to: CGPoint(x: visible.first?.x ?? 0, y: size.height))
        for p in visible { fillPath.addLine(to: p) }
        fillPath.addLine(to: CGPoint(x: visible.last?.x ?? 0, y: size.height))
        fillPath.closeSubpath()
        let fillGradient = Gradient(stops: [
            .init(color: Palette.accent.opacity(0.18), location: 0.0),
            .init(color: Palette.accent.opacity(0.02), location: 0.85),
            .init(color: Palette.accent.opacity(0.00), location: 1.0),
        ])
        ctx.fill(
            fillPath,
            with: .linearGradient(
                fillGradient,
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        // Trend line — moving gradient stroke. Hue migrates with phase
        // so the line "breathes" while idle. Catmull-rom style curve.
        var path = Path()
        path.move(to: visible[0])
        for i in 1..<visible.count {
            let p0 = visible[max(0, i - 1)]
            let p1 = visible[i]
            let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            if i == 1 {
                path.addLine(to: mid)
            } else {
                path.addQuadCurve(to: mid, control: p0)
            }
        }
        if let last = visible.last { path.addLine(to: last) }

        // Phase-driven gradient stops give the line a flowing highlight
        // that drifts cocoa → accent → cocoa over a 6-second loop.
        let gradient = Gradient(stops: [
            .init(color: Palette.cocoaPrimary.opacity(0.85), location: 0.0),
            .init(
                color: Palette.accent,
                location: CGFloat(max(0.05, min(0.95, phase)))
            ),
            .init(color: Palette.cocoaPrimary.opacity(0.85), location: 1.0),
        ])
        ctx.stroke(
            path,
            with: .linearGradient(
                gradient,
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: 0)
            ),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        )

        // Goal reference (subtle dashed) — only when set + only after
        // the line has finished tracing in.
        if let goal = goalWeightKg, goal > 0, progress > 0.9 {
            let yDom = yDomain
            let goalY = size.height
                - CGFloat((toDisplay(goal) - yDom.lowerBound) / max(0.0001, yDom.upperBound - yDom.lowerBound))
                * size.height
            var goalPath = Path()
            goalPath.move(to: CGPoint(x: 0, y: goalY))
            goalPath.addLine(to: CGPoint(x: size.width, y: goalY))
            ctx.stroke(
                goalPath,
                with: .color(Palette.stateGood.opacity(0.40)),
                style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
            )
        }
    }

    private func drawScrubMarker(
        ctx: GraphicsContext,
        points: [CGPoint],
        size: CGSize
    ) {
        guard let frac = scrubFraction, !points.isEmpty else { return }
        let idx = min(points.count - 1, max(0, Int(Double(points.count - 1) * frac)))
        let pt = points[idx]
        var line = Path()
        line.move(to: CGPoint(x: pt.x, y: 0))
        line.addLine(to: CGPoint(x: pt.x, y: size.height))
        ctx.stroke(line, with: .color(Palette.cocoaPrimary.opacity(0.22)), lineWidth: 0.75)

        let dot = Path(ellipseIn: CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10))
        ctx.fill(dot, with: .color(Palette.accent))
        let halo = Path(ellipseIn: CGRect(x: pt.x - 10, y: pt.y - 10, width: 20, height: 20))
        ctx.stroke(halo, with: .color(Palette.accent.opacity(0.45)), lineWidth: 1.0)
    }

    /// Y domain padded by ~12% above + below, includes goal when set.
    private var yDomain: ClosedRange<Double> {
        let weightsKg = points.map(\.emaKg) + points.compactMap(\.rawKg)
        var lo = weightsKg.min() ?? 0
        var hi = weightsKg.max() ?? 0
        if let goal = goalWeightKg, goal > 0 {
            lo = min(lo, goal)
            hi = max(hi, goal)
        }
        let dLo = toDisplay(lo)
        let dHi = toDisplay(hi)
        let pad = max(0.6, (dHi - dLo) * 0.12)
        return (dLo - pad)...(dHi + pad)
    }
}
