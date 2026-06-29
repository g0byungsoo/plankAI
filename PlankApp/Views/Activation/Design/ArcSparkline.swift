import SwiftUI

// MARK: - ArcSparkline
//
// A thin cocoa "arrival arc": a hairline curved Path drawn in a Canvas
// that rises gently from a small "today" dot on the left to an "arrival"
// dot on the right. The clinical-but-warm signal for "you are on a line
// toward somewhere," used as the quiet hero ornament on activation
// screens.
//
// Choreography on appear (animate == true):
//   1. The stroke DRAWS ON left-to-right (trim 0 -> 1, ~700ms easeOut).
//   2. A faint highlight travels once along the stroke just after it
//      finishes drawing (a moving bright node, fades at both ends).
//   3. The arrival endpoint BLOOMS, a soft expanding ring plus a
//      filled dot that springs in.
//
// Reduce Motion: renders fully drawn with a static arrival dot, no
// draw-on, no travel, no bloom.
//
// Usage:
//
//   ArcSparkline(animate: appeared, endpointLabel: "arrival")
//       .frame(height: 96)
//
// `animate` is a Bool the caller flips (e.g. in `.onAppear`) so the
// parent controls when the draw-on fires; pass `true` immediately for
// an always-animated instance.
struct ArcSparkline: View {
    /// Flip to true to run the draw-on + bloom. While false the arc is
    /// invisible (trim 0) so the caller can stage the reveal.
    var animate: Bool

    /// Optional caps under each endpoint. `nil` hides that label.
    var startLabel: String? = nil
    var endpointLabel: String? = nil

    /// Hairline weight + tint. Defaults to the clinical cocoa hairline.
    var lineWidth: CGFloat = 1.0
    var stroke: Color = Palette.cocoaSecondary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drawProgress: CGFloat = 0
    @State private var travel: CGFloat = 0
    @State private var bloom: CGFloat = 0

    private let drawDuration: Double = 0.7

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in
                draw(in: &ctx, size: size)
            }
            .frame(maxWidth: .infinity)

            if startLabel != nil || endpointLabel != nil {
                HStack {
                    labelView(startLabel)
                    Spacer(minLength: 0)
                    labelView(endpointLabel)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
        .onAppear { runIfNeeded() }
        .onChange(of: animate) { _, _ in runIfNeeded() }
    }

    // MARK: Drawing

    private func draw(in ctx: inout GraphicsContext, size: CGSize) {
        let inset: CGFloat = 10
        let start = CGPoint(x: inset, y: size.height * 0.80)
        let end = CGPoint(x: size.width - inset, y: size.height * 0.26)
        // Single quadratic bezier: a soft, confident rise. The control
        // point pulled up + slightly left gives an ease-into-flatten
        // shape (steeper early, calmer near arrival).
        let control = CGPoint(x: size.width * 0.44, y: size.height * 0.40)

        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)

        // Stroke the drawn portion.
        let drawn = path.trimmedPath(from: 0, to: max(0.0001, drawProgress))
        ctx.stroke(
            drawn,
            with: .color(stroke),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )

        // Today dot (left): a small filled node, present once the draw
        // begins so the line reads as leaving "now".
        if drawProgress > 0.01 {
            let r: CGFloat = 3
            ctx.fill(
                Path(ellipseIn: CGRect(x: start.x - r, y: start.y - r, width: r * 2, height: r * 2)),
                with: .color(stroke)
            )
        }

        // Traveling highlight: a brighter node sliding along the stroke
        // once after the draw lands. Fades in/out at the ends so it
        // reads as a gleam, not a loader.
        if travel > 0.001 && travel < 0.999 {
            let p = pointOnCurve(t: travel, start: start, control: control, end: end)
            let edgeFade = sin(travel * .pi)            // 0 at ends, 1 mid
            let glow: CGFloat = 5
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - glow, y: p.y - glow, width: glow * 2, height: glow * 2)),
                with: .color(Palette.cocoaPrimary.opacity(0.18 * edgeFade))
            )
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - 1.6, y: p.y - 1.6, width: 3.2, height: 3.2)),
                with: .color(Palette.cocoaPrimary.opacity(0.85 * edgeFade))
            )
        }

        // Arrival bloom: expanding ring + a filled dot that springs in.
        if drawProgress > 0.985 {
            let ringR = 4 + bloom * 13
            let ringOpacity = Double(1 - bloom) * 0.5
            ctx.stroke(
                Path(ellipseIn: CGRect(x: end.x - ringR, y: end.y - ringR, width: ringR * 2, height: ringR * 2)),
                with: .color(Palette.accent.opacity(ringOpacity)),
                lineWidth: 1
            )
            let dotR: CGFloat = 3.2 * (0.4 + 0.6 * bloom)
            ctx.fill(
                Path(ellipseIn: CGRect(x: end.x - dotR, y: end.y - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(Palette.accent)
            )
        }
    }

    /// Point on a quadratic bezier at parameter t in [0, 1].
    private func pointOnCurve(t: CGFloat, start: CGPoint, control: CGPoint, end: CGPoint) -> CGPoint {
        let mt = 1 - t
        let x = mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x
        let y = mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }

    // MARK: Labels

    @ViewBuilder
    private func labelView(_ text: String?) -> some View {
        if let text {
            Text(text.uppercased())
                .font(Typo.statLabel)
                .kerning(0.06 * 11)
                .foregroundStyle(Palette.cocoaTertiary)
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }

    private var accessibilityText: String {
        let from = startLabel ?? "today"
        let to = endpointLabel ?? "arrival"
        return "a rising line from \(from) to \(to)"
    }

    // MARK: Choreography

    private func runIfNeeded() {
        guard animate else {
            // Staged-but-not-yet: keep hidden until the caller flips it.
            if !reduceMotion { return }
            // (reduceMotion still wants the static final state below.)
            renderFinalStatic()
            return
        }

        if reduceMotion {
            renderFinalStatic()
            return
        }

        // 1. Draw on.
        drawProgress = 0
        travel = 0
        bloom = 0
        withAnimation(.easeOut(duration: drawDuration)) {
            drawProgress = 1
        }
        // 2. Travel highlight, just after the draw lands.
        withAnimation(.easeInOut(duration: 0.55).delay(drawDuration + 0.04)) {
            travel = 1
        }
        // 3. Arrival bloom, overlapping the end of the draw.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(drawDuration - 0.05)) {
            bloom = 1
        }
    }

    private func renderFinalStatic() {
        drawProgress = 1
        travel = 0          // no gleam
        bloom = 1           // dot present, ring already faded (opacity 0)
    }
}

#if DEBUG
#Preview("ArcSparkline") {
    struct Demo: View {
        @State private var go = false
        var body: some View {
            ZStack {
                GrainfieldBackground()
                VStack(spacing: 40) {
                    ArcSparkline(animate: go, startLabel: "today", endpointLabel: "arrival")
                        .frame(height: 110)
                        .padding(.horizontal, 32)
                    Button("replay") { go = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { go = true } }
                }
            }
            .onAppear { go = true }
        }
    }
    return Demo()
}
#endif
