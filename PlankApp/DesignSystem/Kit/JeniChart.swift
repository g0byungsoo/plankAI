import SwiftUI

// MARK: - JeniChart (v11 T2 — the renderer)
//
// One hand-drawn engine for every chart in the app. Hairline strokes,
// ink on paper, no gridlines, no legends, no axis boxes — two end
// labels maximum (docs/app_v11/00_REBIRTH.md §5).
//
// Motion (L12): the line draws left→right; bars land one at a time,
// each landing ticking JeniHaptic. The phase self-drives from `.task`
// — NEVER withAnimation-over-@State inside Canvas (v10.1 law).

struct JeniChart: View {
    let model: JeniChartModel
    var height: CGFloat
    var endLabels: (String, String)? = nil
    var scrubbable: Bool = false
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
        .task(id: arrived) {
            guard arrived, phase < 1 else { return }
            await drive()
        }
    }

    // MARK: - the self-driven phase

    private func drive() async {
        if reduceMotion {
            phase = 1
            landedCount = model.slotCount
            return
        }
        // 0.9s draw at ~60 steps, ease-out applied to t. The phase is
        // plain @State advanced from .task — Canvas redraws per step.
        let steps = 54
        let total = model.slotCount
        for s in 1...steps {
            let t = Double(s) / Double(steps)
            phase = 1 - pow(1 - t, 3)
            if model.form == .bars {
                let landed = model.revealCount(phase: phase, total: total)
                if landed > landedCount {
                    landedCount = landed
                    JeniHaptic.tick()
                }
            }
            try? await Task.sleep(nanoseconds: 16_600_000)
        }
        phase = 1
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
            return (Palette.textPrimary, model.form == .spark ? 1.2 : 1.4)
        case .context:
            return (Palette.textPrimary.opacity(0.22), 1.0)
        }
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

                guard segment.count > 1 else {
                    // A lone point still shows itself — a 3pt ink dot.
                    if let p = segment.first {
                        let dot = CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)
                        ctx.fill(Path(ellipseIn: dot),
                                 with: .color(color.opacity(localPhase)))
                    }
                    continue
                }
                var path = Path()
                path.move(to: segment[0])
                for p in segment.dropFirst() { path.addLine(to: p) }
                let drawn = localPhase < 1
                    ? path.trimmedPath(from: 0, to: max(0.001, localPhase))
                    : path
                ctx.stroke(drawn, with: .color(color),
                           style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }

            // The "now" dot — the ink series ends in a 3.5pt point that
            // fades in as the draw completes. The eye lands where she is.
            if series.role == .ink, model.form != .spark, phase > 0.9,
               let last = segments.last?.last {
                let a = (phase - 0.9) / 0.1
                let dot = CGRect(x: last.x - 1.75, y: last.y - 1.75, width: 3.5, height: 3.5)
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
        let rects = model.barRects(in: size, gap: 2)
        let total = rects.count
        for (i, rect) in rects.enumerated() {
            guard let rect else { continue }
            let p = model.barPhase(index: i, phase: phase, total: total)
            guard p > 0 else { continue }
            let eased = 1 - pow(1 - p, 3)
            // A bar grows from its baseline to full height.
            let grown = CGRect(
                x: rect.minX,
                y: rect.maxY - rect.height * CGFloat(eased),
                width: rect.width,
                height: rect.height * CGFloat(eased)
            )
            let radius = min(grown.width / 2, 2)
            ctx.fill(Path(roundedRect: grown, cornerRadius: radius),
                     with: .color(Palette.textPrimary.opacity(scrubDim(i))))
        }
    }

    /// While scrubbing, the held bar keeps full ink; the rest recede.
    private func scrubDim(_ index: Int) -> Double {
        guard let scrubIndex else { return 1 }
        return index == scrubIndex ? 1 : 0.35
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
