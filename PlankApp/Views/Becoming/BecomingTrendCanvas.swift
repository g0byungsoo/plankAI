import SwiftUI
import PlankSync

// MARK: - BecomingTrendCanvas
//
// v4 extraction (2026-07-06): moved verbatim out of the legacy
// Views/Analytics/BecomingV2Atoms.swift during the app-v4 dead-code
// sweep — the rest of that file (diary hero, energy/protein tiles,
// macro row, moved strip, plate timeline, deeds counter) died with
// the legacy Becoming dashboard, but the trend canvas is THE LINE on
// the live BecomingView (docs/app_v2/14_V21_NOTES.md: "BecomingTrendCanvas
// is KEPT — it moved"). Depends on WeightTrendChart.computeEMA
// (Views/Analytics/WeightTrendChart.swift), BandModel, TodayStateService,
// and the luxuryCard modifier in DesignSystem/Tokens.swift.
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
    /// v3 keeping chapter: her settle weight (kg). When present the
    /// canvas draws THE BAND — tinted home field (settle → +1.4kg)
    /// and watch strip (+1.4 → +2.3kg) behind the line. Zones tint
    /// the FIELD, never the number (02_DESIGN_LANGUAGE.md).
    var bandSettleKg: Double? = nil
    // v1.3 (2026-06-18) — compressed per her75 typographer panel:
    // Apple Health charts ride at ~120pt on the Summary surface; her75
    // photo modules at ~100-120pt. 110pt lands the chart on register
    // and frees ~60pt below for an insight line or stat row.
    var height: CGFloat = 110

    @State private var drawProgress: Double = 0     // 0...1 — line trace-in
    @State private var shimmerPhase: Double = 0     // 0...1 — idle gradient flow
    @State private var scrubFraction: Double? = nil // 0...1 — drag position
    @State private var lastHapticIndex: Int = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Phase 4 Day-2 (2026-06-19) — window cycle on double-tap.
    /// Modes cycle 60d → 90d → nil (all) → 60d. Lets her see the
    /// long arc without a segmented control; the gesture IS the
    /// picker. Panel 4: a 90-day frame defuses Ozempic-anxiety.
    @State private var windowDays: Int? = 60
    /// Harness-only initial window override for screenshot capture.
    var debugInitialWindowDays: Int?? = nil

    private var filteredLogs: [WeightLogRecord] {
        guard let n = windowDays else { return logs }
        let cutoff = Date.now.addingTimeInterval(-Double(n) * 86400)
        return logs.filter { $0.loggedAt >= cutoff }
    }

    private var points: [WeightTrendChart.EMAPoint] {
        WeightTrendChart.computeEMA(logs: filteredLogs)
    }

    private func toDisplay(_ kg: Double) -> Double { unit.display(fromKg: kg) }

    /// The currently-visible weight number.
    ///
    /// - Scrubbing: shows the smoothed EMA at the scrubbed point —
    ///   that's where the LINE is, so the digit aligns with the
    ///   marker the finger lands on.
    /// - Idle: shows the user's MOST RECENT RAW weigh-in (not the
    ///   EMA). The EMA absorbs single new readings — alpha is 0.25
    ///   on a 7-day window, so adding one 58kg entry after weeks
    ///   of 60kg only pulls the EMA from 60 → 59.5. Users read the
    ///   chart as "broken" when the headline doesn't reflect what
    ///   they just entered. The LINE still shows the smoothed
    ///   trend (that's its job — defuse fluctuation anxiety per
    ///   Helander 2014); the headline speaks to the latest input.
    private var headlineWeightLb: Double {
        if let frac = scrubFraction, !points.isEmpty {
            let idx = min(points.count - 1, max(0, Int(Double(points.count - 1) * frac)))
            return toDisplay(points[idx].emaKg)
        }
        // Find the most recent point whose rawKg is non-nil — that
        // is the user's last actual weigh-in. Fall back to the
        // latest EMA if no raw point exists in the window (e.g.
        // their last log was older than the windowDays cutoff and
        // the chart is showing seeded EMA history only).
        if let latestRaw = filteredLogs.first?.weightKg {
            return toDisplay(latestRaw)
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
            placeholder
        } else {
            VStack(alignment: .leading, spacing: 8) {
                eyebrow
                headline
                trendCanvas
                xAxisLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .luxuryCard()
        }
    }

    @ViewBuilder private var eyebrow: some View {
        let windowWord: String = {
            switch windowDays {
            case 60?: return "sixty"
            case 90?: return "ninety"
            case nil: return "all"
            default:  return "trend"
            }
        }()
        (Text("trend · ")
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
        + Text(windowWord)
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
            .foregroundColor(Palette.cocoaSecondary))
            .foregroundStyle(Palette.cocoaTertiary)
            .id(windowDays ?? -1)
            .transition(.opacity)
    }

    // MARK: - Headline

    @ViewBuilder private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // v3: the LINE is the hero; the raw number is a quiet
                // companion (trend > number is the app's own doctrine —
                // a 40pt raw numeral was the loudest thing on Becoming).
                Text(String(format: "%.1f", headlineWeightLb))
                    .font(.custom("JeniHeroSerif-Regular", size: 22))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: headlineWeightLb)
                Text(unit.label)
                    .font(.custom("JeniHeroSerif-Italic", size: 13))
                    .foregroundStyle(Palette.accent)
                    .baselineOffset(2)
            }
            Spacer()
            if let scrubDate = headlineDateLabel {
                Text(scrubDate)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    .foregroundStyle(Palette.accent)
                    .transition(.opacity)
            } else if let word = trendDirectionWord {
                Text(word.text)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    .foregroundStyle(word.tint)
            }
        }
    }

    /// The ONE-STORY law (docs/app_v4/03_FEATURES.md §2): the canvas
    /// used to badge a raw 7-day delta ("−2.2 lb this week") while
    /// the field note above spoke the EMA's story ("eased down about
    /// 500g") — two numbers, two windows, one screen. The badge is
    /// now a DIRECTION word derived from the same EMA-7 source the
    /// story reads; numbers appear once, in the story.
    private var trendDirectionWord: (text: String, tint: Color)? {
        guard let delta = TodayStateService.emaDelta7d(points) else { return nil }
        if delta <= -0.1 { return ("easing", Palette.stateGood) }
        if delta >= 0.1 { return ("drifting up, gently", Palette.cocoaSecondary) }
        return ("steady", Palette.cocoaSecondary)
    }

    /// v3 keeping: the band field. Home (settle → +1.4kg) in a soft
    /// accent wash; the watch strip (+1.4 → +2.3) fainter; a hairline
    /// at settle. Clamped to the canvas; off-domain zones simply
    /// don't render.
    private func drawBandField(
        ctx: GraphicsContext, size: CGSize,
        yDom: ClosedRange<Double>, settleKg: Double
    ) {
        func y(_ kg: Double) -> CGFloat {
            let v = toDisplay(kg)
            let raw = size.height
                - CGFloat((v - yDom.lowerBound) / max(0.0001, yDom.upperBound - yDom.lowerBound))
                * size.height
            return min(max(raw, 0), size.height)
        }
        let settleY = y(settleKg)
        let driftY = y(settleKg + BandModel.driftingAtKg)
        let resetY = y(settleKg + BandModel.resetAtKg)

        // Home: between settle and the drift line (drift sits ABOVE
        // settle in weight, so its y is smaller).
        if settleY - driftY > 1 {
            ctx.fill(
                Path(CGRect(x: 0, y: driftY, width: size.width, height: settleY - driftY)),
                with: .color(Palette.accentSubtle.opacity(0.30))
            )
        }
        // Watch strip.
        if driftY - resetY > 1 {
            ctx.fill(
                Path(CGRect(x: 0, y: resetY, width: size.width, height: driftY - resetY)),
                with: .color(Palette.accentSubtle.opacity(0.14))
            )
        }
        // Settle hairline.
        if settleY > 0, settleY < size.height {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: settleY))
            line.addLine(to: CGPoint(x: size.width, y: settleY))
            ctx.stroke(line, with: .color(Palette.cocoaPrimary.opacity(0.18)),
                       style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))
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
                if let settle = bandSettleKg {
                    drawBandField(ctx: ctx, size: canvasSize, yDom: yDom, settleKg: settle)
                }
                drawLine(ctx: ctx, points: mapped, size: canvasSize, phase: phase, progress: drawProgress)
                drawScrubMarker(ctx: ctx, points: mapped, size: canvasSize)
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            Haptics.soft()
            withAnimation(Motion.crossFade) {
                windowDays = nextWindow(after: windowDays)
            }
            // Re-trigger the draw-in animation so the cycle lands
            // with a visual beat, not a hard cut.
            drawProgress = 0
            if reduceMotion {
                drawProgress = 1
            } else {
                withAnimation(Motion.trendDrawIn) {
                    drawProgress = 1
                }
            }
        }
        .gesture(scrubGesture)
        .onAppear {
            if let override = debugInitialWindowDays {
                windowDays = override
            }
        }
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

    /// Phase 4 Day-2 — cycle 60d → 90d → all → 60d. Stays under 4
    /// modes so the gesture stays predictable; her75 panel rejected
    /// "everything plus 7d" as too many stops for a double-tap.
    private func nextWindow(after current: Int?) -> Int? {
        switch current {
        case 60?: return 90
        case 90?: return nil
        case nil: return 60
        default:  return 60
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
            Text("log a few more days. your trend draws itself.")
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
            style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round)
        )

        // Accent rose tip dot — Robinhood-coded "latest point" marker.
        // Soft halo at 0.4 opacity, solid core at 100%; appears only
        // when the trace-in has fully landed.
        if progress > 0.95, let last = visible.last {
            let halo = Path(ellipseIn: CGRect(x: last.x - 8, y: last.y - 8, width: 16, height: 16))
            ctx.fill(halo, with: .color(Palette.accent.opacity(0.18)))
            let core = Path(ellipseIn: CGRect(x: last.x - 3.5, y: last.y - 3.5, width: 7, height: 7))
            ctx.fill(core, with: .color(Palette.accent))
        }

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
        // v4 (HONEST_GAPS #8): the keeping chapter's band always fits
        // the frame — a line living far from settle used to push the
        // band partially offscreen, unmooring the zones it narrates.
        if let settle = bandSettleKg {
            lo = min(lo, settle)
            hi = max(hi, settle + BandModel.resetAtKg)
        }
        let dLo = toDisplay(lo)
        let dHi = toDisplay(hi)
        let pad = max(0.6, (dHi - dLo) * 0.12)
        return (dLo - pad)...(dHi + pad)
    }
}
