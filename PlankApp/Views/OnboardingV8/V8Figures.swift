import SwiftUI

// MARK: - V8Figure — drawn evidence inside the conversation
//
// The founder's steer: the two jobs (you have a problem / jeni is the
// solution) argue with NUMBERS and CHARTS, animated. Every figure is
// provenance-clean (mechanism illustrations carry their citation on
// the line they ride; the projection uses HER numbers through
// ProjectionMath). Everything draws — nothing appears (L12).

enum V8Figure: Equatable {
    /// Job 1 — the food-noise waveform settling to quiet.
    case noiseWave
    /// Job 1 — the quick-fix rebound curve vs the paced arc.
    case reboundCurve
    /// Job 2 — loss composition: the muscle share protein protects.
    case muscleBar
    /// Job 2 — "about half stop within a year" as a filling dot row.
    case halfDots
    /// Job 2 — HER projection: current → goal at the safe pace.
    case projection(deltaLb: Int, weeks: Int?)
}

struct V8FigureView: View {
    let figure: V8Figure

    var body: some View {
        switch figure {
        case .noiseWave: V8NoiseWave()
        case .reboundCurve: V8ReboundCurve()
        case .muscleBar: V8MuscleBar()
        case .halfDots: V8HalfDots()
        case .projection(let deltaLb, let weeks):
            V8ProjectionCurve(deltaLb: deltaLb, weeks: weeks)
        }
    }
}

// MARK: - Ink-aware tints

private struct V8FigureTint {
    let primary: Color
    let secondary: Color
    let accent: Color
    let accentSoft: Color

    init(onInk: Bool) {
        if onInk {
            primary = Palette.textInverse
            secondary = Palette.textInverse.opacity(0.62)
            accent = Palette.accent
            accentSoft = Palette.accent.opacity(0.34)
        } else {
            primary = Palette.cocoaPrimary
            secondary = Palette.cocoaSecondary
            accent = Palette.accent
            accentSoft = Palette.accentSubtle
        }
    }
}

// MARK: - The noise wave (ported from OV5, ink-aware)

private struct V8NoiseWave: View {
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.v8OnInk) private var onInk

    var body: some View {
        let tint = V8FigureTint(onInk: onInk)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h * 0.52
            ZStack(alignment: .topLeading) {
                wavePath(w: w, h: h)
                    .trim(from: 0, to: progress)
                    .stroke(tint.primary,
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

                Circle()
                    .fill(tint.accent)
                    .frame(width: 6, height: 6)
                    .position(x: w - 4, y: midY)
                    .opacity(progress > 0.97 ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: progress > 0.97)

                Text("the noise")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(tint.secondary)
                    .offset(x: w * 0.02, y: h * 0.02)
                    .opacity(progress > 0.3 ? 1 : 0)
                Text("quieter")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(tint.accent)
                    .offset(x: w * 0.78, y: midY + 12)
                    .opacity(progress > 0.85 ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.3), value: progress > 0.3)
            .animation(.easeOut(duration: 0.3), value: progress > 0.85)
        }
        .frame(height: 84)
        .onAppear {
            if reduceMotion { progress = 1; return }
            withAnimation(.easeOut(duration: 1.1).delay(0.35)) { progress = 1 }
        }
        .accessibilityLabel("A waveform that starts loud and settles into a calm quiet line.")
    }

    private func wavePath(w: CGFloat, h: CGFloat) -> Path {
        var p = Path()
        let midY = h * 0.52
        let steps = 160
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let settle = max(0, min(1, (t - 0.18) / 0.62))
            let envelope = (1 - settle * settle * (3 - 2 * settle)) * 0.92 + 0.06
            let a = h * 0.34 * envelope
            let y = midY
                + a * (sin(t * 29 + 0.8) * 0.55
                       + sin(t * 71 + 2.1) * 0.30
                       + sin(t * 131) * 0.15)
            let pt = CGPoint(x: t * w, y: y)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

// MARK: - The rebound curve (Job 1 — "you know this graph")

private struct V8ReboundCurve: View {
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.v8OnInk) private var onInk

    var body: some View {
        let tint = V8FigureTint(onInk: onInk)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                // the quick fix — sharp drop, rebound past the start
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.42))
                    p.addCurve(
                        to: CGPoint(x: w * 0.42, y: h * 0.82),
                        control1: CGPoint(x: w * 0.13, y: h * 0.46),
                        control2: CGPoint(x: w * 0.26, y: h * 0.84)
                    )
                    p.addCurve(
                        to: CGPoint(x: w, y: h * 0.16),
                        control1: CGPoint(x: w * 0.62, y: h * 0.80),
                        control2: CGPoint(x: w * 0.82, y: h * 0.34)
                    )
                }
                .trim(from: 0, to: progress)
                .stroke(tint.accent.opacity(0.8),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [4, 5]))

                // paced — settles and stays
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.42))
                    p.addCurve(
                        to: CGPoint(x: w * 0.62, y: h * 0.62),
                        control1: CGPoint(x: w * 0.22, y: h * 0.44),
                        control2: CGPoint(x: w * 0.44, y: h * 0.60)
                    )
                    p.addCurve(
                        to: CGPoint(x: w, y: h * 0.63),
                        control1: CGPoint(x: w * 0.78, y: h * 0.64),
                        control2: CGPoint(x: w * 0.9, y: h * 0.63)
                    )
                }
                .trim(from: 0, to: progress)
                .stroke(tint.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                Text("the quick fix")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(tint.accent)
                    .offset(x: w * 0.70, y: h * 0.02)
                    .opacity(progress > 0.85 ? 1 : 0)
                Text("paced, then held")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(tint.secondary)
                    .offset(x: w * 0.60, y: h * 0.70)
                    .opacity(progress > 0.85 ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.3), value: progress > 0.85)
        }
        .frame(height: 92)
        .onAppear {
            if reduceMotion { progress = 1; return }
            withAnimation(.easeOut(duration: 1.2).delay(0.35)) { progress = 1 }
        }
        .accessibilityLabel("Two weight curves: a quick fix that rebounds above where it started, and a paced plan that settles and holds.")
    }
}

// MARK: - The muscle bar (Job 2 — what protein protects)

private struct V8MuscleBar: View {
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.v8OnInk) private var onInk

    /// Visual split only (no % printed): STEP-1 sub-analysis puts the
    /// lean-mass share of GLP-1 loss near 40%.
    private let muscleShare: CGFloat = 0.38

    var body: some View {
        let tint = V8FigureTint(onInk: onInk)
        GeometryReader { geo in
            let w = geo.size.width
            let barH: CGFloat = 26
            let fatW = w * (1 - muscleShare)
            VStack(alignment: .leading, spacing: 8) {
                Text("what the scale loses")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(tint.secondary)
                    .opacity(revealed ? 1 : 0)

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(tint.accentSoft)
                        .frame(width: revealed ? fatW : 0, height: barH)
                    V8HatchedBlock(color: tint.primary)
                        .frame(width: revealed ? w * muscleShare : 0, height: barH)
                }
                .frame(width: w, height: barH, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                HStack(alignment: .firstTextBaseline) {
                    Text("fat")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(tint.secondary)
                    Spacer()
                    Text("muscle · the part we protect")
                        .font(.custom("DMSans-Medium", size: 11))
                        .foregroundStyle(tint.primary)
                }
                .opacity(revealed ? 1 : 0)
            }
        }
        .frame(height: 84)
        .onAppear {
            if reduceMotion { revealed = true; return }
            withAnimation(.easeOut(duration: 0.7).delay(0.4)) { revealed = true }
        }
        .accessibilityLabel("A bar of weight lost: the larger share is fat, and a meaningful share is muscle, the part protein and movement protect.")
    }
}

private struct V8HatchedBlock: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var line = Path()
            let spacing: CGFloat = 6
            var x: CGFloat = -size.height
            while x < size.width {
                line.move(to: CGPoint(x: x, y: size.height))
                line.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            context.stroke(line, with: .color(color.opacity(0.75)), lineWidth: 1.2)
        }
        .background(color.opacity(0.06))
        .accessibilityHidden(true)
    }
}

// MARK: - Half dots ("about half stop within a year" · jama 2025)

private struct V8HalfDots: View {
    @State private var filled = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.v8OnInk) private var onInk

    var body: some View {
        let tint = V8FigureTint(onInk: onInk)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                ForEach(0..<10, id: \.self) { i in
                    Circle()
                        .strokeBorder(tint.primary.opacity(0.45), lineWidth: 1.2)
                        .background(
                            Circle().fill(tint.primary)
                                .scaleEffect(i < filled ? 1 : 0.001)
                        )
                        .frame(width: 13, height: 13)
                        .animation(JeniMotion.morph, value: filled)
                }
            }
            Text("stop within the first year")
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundStyle(tint.secondary)
                .opacity(filled >= 5 ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: filled >= 5)
        }
        .frame(height: 44)
        .onAppear {
            if reduceMotion { filled = 5; return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                for i in 1...5 {
                    filled = i
                    JeniHaptic.tick()
                    try? await Task.sleep(nanoseconds: 140_000_000)
                }
            }
        }
        .accessibilityLabel("Ten dots, five filled: about half of users stop within the first year.")
    }
}

// MARK: - HER projection (Job 2 — the plan, in her numbers)

private struct V8ProjectionCurve: View {
    let deltaLb: Int
    let weeks: Int?

    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.v8OnInk) private var onInk

    var body: some View {
        let tint = V8FigureTint(onInk: onInk)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                // Her line: eases down, flattens into the hold.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.18))
                    p.addCurve(
                        to: CGPoint(x: w * 0.72, y: h * 0.62),
                        control1: CGPoint(x: w * 0.26, y: h * 0.22),
                        control2: CGPoint(x: w * 0.5, y: h * 0.56)
                    )
                    p.addCurve(
                        to: CGPoint(x: w, y: h * 0.66),
                        control1: CGPoint(x: w * 0.84, y: h * 0.66),
                        control2: CGPoint(x: w * 0.93, y: h * 0.66)
                    )
                }
                .trim(from: 0, to: progress)
                .stroke(tint.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                Circle()
                    .fill(tint.accent)
                    .frame(width: 7, height: 7)
                    .position(x: w - 3, y: h * 0.66)
                    .opacity(progress > 0.96 ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: progress > 0.96)

                Text("today")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(tint.secondary)
                    .offset(x: 0, y: h * 0.02)
                Group {
                    if let weeks {
                        Text("about week \(weeks)")
                    } else {
                        Text("the hold")
                    }
                }
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundStyle(tint.primary)
                .offset(x: w * 0.66, y: h * 0.76)
                .opacity(progress > 0.9 ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: progress > 0.9)

                Text("−\(deltaLb) lb")
                    .font(.custom("DMSans-SemiBold", size: 12))
                    .monospacedDigit()
                    .foregroundStyle(tint.accent)
                    .offset(x: w * 0.34, y: h * 0.62)
                    .opacity(progress > 0.6 ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: progress > 0.6)
            }
        }
        .frame(height: 92)
        .onAppear {
            if reduceMotion { progress = 1; return }
            withAnimation(.easeOut(duration: 1.3).delay(0.35)) { progress = 1 }
        }
        .accessibilityLabel("Your projected curve: easing down about \(deltaLb) pounds\(weeks.map { " over roughly \($0) weeks" } ?? ""), then holding.")
    }
}
