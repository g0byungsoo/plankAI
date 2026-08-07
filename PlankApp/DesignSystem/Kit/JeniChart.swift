import SwiftUI

// MARK: - JeniChart (v11 T2 renderer · v12 chart craft pass)
//
// One engine for every chart in the app. Ink on paper, no gridlines,
// no legends, no axis boxes — two end labels maximum
// (docs/app_v11/00_REBIRTH.md §5).
//
// v12 (founder: "charts look sketched, not designed"): the marks
// matured to the Health-app register —
//   · lines are MONOTONE-CUBIC smooth (no overshoot — a smoothed
//     vertex never invents a value the data doesn't hold), 2.2pt,
//     round caps;
//   · the area wash is 10% ink under the smooth curve;
//   · bars are confident marks: rounded data-end, SQUARE at the
//     baseline, grown from one hairline baseline that grounds them;
//   · `emphasizeLast` renders the week receded and TODAY in full ink
//     (the R2 face read);
//   · the end-dot is ≥8pt with a surface ring so it stays legible
//     over its own line.
//
// Motion (L12): the line draws left→right; bars land one at a time,
// each landing ticking JeniHaptic. The phase self-drives from `.task`
// — NEVER withAnimation-over-@State inside Canvas (v10.1 law).

struct JeniChart: View {
    let model: JeniChartModel
    var height: CGFloat
    var endLabels: (String, String)? = nil
    var scrubbable: Bool = false
    /// v11.5 — a soft area beneath the ink line. The founder found the
    /// bare hairline unpretty; a filled slope reads as designed rather
    /// than sketched. Weight KEEPS the line (a bar implies a zero
    /// baseline, and weight has none — that would be a lying chart).
    var filled: Bool = false
    /// v12 — bar charts: the week recedes, today reads full ink.
    var emphasizeLast: Bool = false
    /// Formats the scrub readout for a detent value.
    var valueFormat: (Double) -> String = { String(format: "%.0f", $0) }
    /// Spoken summary for VoiceOver (L11) — call sites pass the read
    /// in words; a chart is never left as an unlabeled image.
    var accessibilityText: String? = nil

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Double = 0
    @State private var landedCount: Int = 0
    @State private var scrubIndex: Int? = nil
    /// v12 — charts draw where the eye is (the visibility gate); a
    /// below-fold chart holds its ink until she reaches it.
    @State private var seen = false
    /// Bars tick their landings on the FIRST trace only — a scope
    /// change re-traces silently (haptics ride actions, not re-renders).
    @State private var tracedOnce = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                Canvas { ctx, size in
                    draw(in: ctx, size: size)
                }
                .contentShape(Rectangle())
                .gesture(scrubGesture(width: geo.size.width))
            }
            .frame(height: height)

            if let endLabels {
                HStack {
                    Text(endLabels.0)
                    Spacer()
                    Text(endLabels.1)
                }
                .font(Typo.numeralMeta)
                .foregroundStyle(Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText ?? ""))
        .jeniArmOnVisible($seen)
        // Re-keyed data re-traces (§4.5): a scope change or a landed
        // plate draws the new shape in — never a silent swap.
        .task(id: ChartArmKey(armed: arrived && seen, model: model)) {
            guard arrived, seen else { return }
            phase = 0
            landedCount = 0
            await drive()
        }
    }

    // MARK: - the self-driven phase

    private func drive() async {
        if reduceMotion {
            phase = 1
            landedCount = model.slotCount
            tracedOnce = true
            return
        }
        // ~0.72s draw (JeniMotion.draw's clock), ease-out applied to
        // t. The phase is plain @State advanced from .task — Canvas
        // redraws per step.
        let steps = 43
        let total = model.slotCount
        for s in 1...steps {
            guard !Task.isCancelled else { return }
            let t = Double(s) / Double(steps)
            phase = 1 - pow(1 - t, 3)
            if model.form == .bars {
                let real = model.series.first?.values.compactMap { $0 }.count ?? 0
                let landed = model.revealCount(phase: phase, total: max(1, real))
                if landed > landedCount {
                    landedCount = landed
                    if !tracedOnce { JeniHaptic.tick() }
                }
            }
            try? await Task.sleep(nanoseconds: 16_600_000)
        }
        phase = 1
        tracedOnce = true
    }

    // MARK: - drawing

    private func draw(in ctx: GraphicsContext, size: CGSize) {
        guard !model.isEmpty else { return }
        switch model.form {
        case .line, .spark:
            drawLines(in: ctx, size: size)
        case .band:
            drawBand(in: ctx, size: size)
            drawLines(in: ctx, size: size)
        case .bars:
            drawBars(in: ctx, size: size)
        }
        if let scrubIndex {
            drawScrub(at: scrubIndex, in: ctx, size: size)
        }
    }

    private func strokeStyle(for role: JeniChartModel.Series.Role) -> (Color, CGFloat) {
        switch role {
        case .ink:
            return (Palette.textPrimary, model.form == .spark ? 2.0 : 2.2)
        case .context:
            return (Palette.textPrimary.opacity(0.20), 1.5)
        }
    }

    /// Monotone-cubic interpolation (Fritsch–Carlson). Smooth without
    /// overshoot: the curve never rises above or dips below the real
    /// measurements it connects — smoothing that cannot lie (L8).
    private func smoothPath(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        guard pts.count > 2 else {
            if pts.count == 2 { path.addLine(to: pts[1]) }
            return path
        }
        let n = pts.count
        var d = [CGFloat]()
        d.reserveCapacity(n - 1)
        for i in 0..<(n - 1) {
            let dx = pts[i + 1].x - pts[i].x
            d.append(dx == 0 ? 0 : (pts[i + 1].y - pts[i].y) / dx)
        }
        var m = [CGFloat](repeating: 0, count: n)
        m[0] = d[0]
        m[n - 1] = d[n - 2]
        for i in 1..<(n - 1) {
            m[i] = d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2
        }
        for i in 0..<(n - 1) {
            guard d[i] != 0 else { m[i] = 0; m[i + 1] = 0; continue }
            let a = m[i] / d[i], b = m[i + 1] / d[i]
            let s = a * a + b * b
            if s > 9 {
                let t = 3 / s.squareRoot()
                m[i] = t * a * d[i]
                m[i + 1] = t * b * d[i]
            }
        }
        for i in 0..<(n - 1) {
            let dx = pts[i + 1].x - pts[i].x
            path.addCurve(
                to: pts[i + 1],
                control1: CGPoint(x: pts[i].x + dx / 3, y: pts[i].y + m[i] * dx / 3),
                control2: CGPoint(x: pts[i + 1].x - dx / 3, y: pts[i + 1].y - m[i + 1] * dx / 3)
            )
        }
        return path
    }

    private func drawLines(in ctx: GraphicsContext, size: CGSize) {
        for (i, series) in model.series.enumerated() {
            let (color, width) = strokeStyle(for: series.role)
            let segments = model.points(seriesIndex: i, in: size)

            // Sequential draw across gaps: the stroke hands off left →
            // right, each segment owning a phase window sized by its
            // share of the points (a gap pauses the pen, it doesn't
            // fork it). Context series draw complete — the past does
            // not animate, only the present does.
            let totalPoints = segments.reduce(0) { $0 + max(1, $1.count) }
            var consumed = 0

            for segment in segments {
                let share = Double(max(1, segment.count)) / Double(max(1, totalPoints))
                let start = Double(consumed) / Double(max(1, totalPoints))
                consumed += max(1, segment.count)
                let localPhase = series.role == .ink
                    ? max(0, min(1, (phase - start) / share))
                    : 1

                guard localPhase > 0 else { continue }

                // The area under the ink, drawn before the stroke so
                // the line always sits on top of its own wash.
                if filled, series.role == .ink, segment.count > 1, localPhase > 0 {
                    var area = smoothPath(segment)
                    area.addLine(to: CGPoint(x: segment.last!.x, y: size.height))
                    area.addLine(to: CGPoint(x: segment[0].x, y: size.height))
                    area.closeSubpath()
                    ctx.fill(
                        area,
                        with: .linearGradient(
                            Gradient(colors: [
                                Palette.textPrimary.opacity(0.10 * localPhase),
                                Palette.textPrimary.opacity(0.0)
                            ]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )
                }

                guard segment.count > 1 else {
                    // A lone point still shows itself — a 4pt ink dot.
                    if let p = segment.first {
                        let dot = CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)
                        ctx.fill(Path(ellipseIn: dot),
                                 with: .color(color.opacity(localPhase)))
                    }
                    continue
                }
                let path = smoothPath(segment)
                let drawn = localPhase < 1
                    ? path.trimmedPath(from: 0, to: max(0.001, localPhase))
                    : path
                ctx.stroke(drawn, with: .color(color),
                           style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }

            // The "now" dot — the ink series ends in an 8pt point with
            // a 2pt surface ring (the mark law: the ring keeps it
            // legible over its own line). Fades in as the draw lands.
            if series.role == .ink, model.form != .spark, phase > 0.9,
               let last = segments.last?.last {
                let a = (phase - 0.9) / 0.1
                // Clamped inside the canvas: at the right edge the
                // ring was being sliced in half (frame-caught).
                let cx = min(max(last.x, 6), size.width - 6)
                let cy = min(max(last.y, 6), size.height - 6)
                let ring = CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12)
                ctx.fill(Path(ellipseIn: ring),
                         with: .color(Palette.bgElevated.opacity(a)))
                let dot = CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8)
                ctx.fill(Path(ellipseIn: dot), with: .color(color.opacity(a)))
            }
        }
    }

    private func drawBand(in ctx: GraphicsContext, size: CGSize) {
        // A band fills between the first two series (hi, lo).
        guard model.series.count >= 2 else { return }
        let hi = model.points(seriesIndex: 0, in: size).flatMap { $0 }
        let lo = model.points(seriesIndex: 1, in: size).flatMap { $0 }
        guard hi.count > 1, hi.count == lo.count else { return }
        var path = Path()
        path.move(to: hi[0])
        for p in hi.dropFirst() { path.addLine(to: p) }
        for p in lo.reversed() { path.addLine(to: p) }
        path.closeSubpath()
        ctx.fill(path, with: .color(Palette.textPrimary.opacity(0.06 * phase)))
    }

    private func drawBars(in ctx: GraphicsContext, size: CGSize) {
        // One hairline baseline grounds the bars (solid, recessive).
        var base = Path()
        base.move(to: CGPoint(x: 0, y: size.height - 0.25))
        base.addLine(to: CGPoint(x: size.width, y: size.height - 0.25))
        ctx.stroke(base, with: .color(Palette.hairlineCocoa), lineWidth: 0.5)

        let rects = model.barRects(in: size, gap: 2)
        // The landing clock runs over REAL bars, not slots — in a
        // sparse wide window the data would otherwise land in the
        // trace's last breath while empty slots ate the phase.
        var ordinal = -1
        let realTotal = max(1, rects.compactMap { $0 }.count)
        for (i, rect) in rects.enumerated() {
            guard let rect else { continue }
            ordinal += 1
            let p = model.barPhase(index: ordinal, phase: phase, total: realTotal)
            guard p > 0 else { continue }
            let eased = 1 - pow(1 - p, 3)
            // A bar grows from its baseline to full height.
            let grown = CGRect(
                x: rect.minX,
                y: rect.maxY - rect.height * CGFloat(eased),
                width: rect.width,
                height: rect.height * CGFloat(eased)
            )
            // Rounded data-end, square at the baseline (the mark law).
            let r = min(4, grown.width / 2, grown.height / 2)
            let path = Path(
                roundedRect: grown,
                cornerRadii: RectangleCornerRadii(
                    topLeading: r, bottomLeading: 0,
                    bottomTrailing: 0, topTrailing: r
                )
            )
            ctx.fill(path, with: .color(Palette.textPrimary.opacity(barInk(i))))
        }
    }

    /// The bar's ink weight: the scrub's held bar always wins; in
    /// emphasize mode the week recedes and "now" reads full; plain
    /// charts weigh every day the same.
    private func barInk(_ index: Int) -> Double {
        if let scrubIndex {
            return index == scrubIndex ? 1 : 0.25
        }
        if emphasizeLast {
            return index == model.lastRealIndex ? 1 : 0.28
        }
        return 0.85
    }

    private func drawScrub(at index: Int, in ctx: GraphicsContext, size: CGSize) {
        let n = model.slotCount
        guard n > 0 else { return }
        let x = n > 1 ? size.width * CGFloat(index) / CGFloat(n - 1) : size.width / 2

        if model.form != .bars {
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            ctx.stroke(line, with: .color(Palette.textPrimary.opacity(0.18)),
                       style: StrokeStyle(lineWidth: 1))
        }

        if let value = model.value(at: index) {
            let label = Text(valueFormat(value))
                .font(Typo.numeralMeta)
                .foregroundStyle(Palette.textPrimary)
            let resolved = ctx.resolve(label)
            let labelSize = resolved.measure(in: size)
            // Inside the canvas, top-anchored — Canvas clips its bounds.
            let lx = min(max(0, x - labelSize.width / 2), size.width - labelSize.width)
            ctx.draw(resolved, at: CGPoint(x: lx + labelSize.width / 2, y: 2), anchor: .top)
        }
    }

    // MARK: - scrub

    /// The trace task's identity: re-runs when the chart arms OR when
    /// its data changes shape.
    private struct ChartArmKey: Equatable {
        let armed: Bool
        let model: JeniChartModel
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                guard scrubbable else { return }
                let idx = model.detent(forX: g.location.x, width: width)
                if idx != scrubIndex {
                    scrubIndex = idx
                    JeniHaptic.tick()
                }
            }
            .onEnded { _ in
                scrubIndex = nil
            }
    }
}
