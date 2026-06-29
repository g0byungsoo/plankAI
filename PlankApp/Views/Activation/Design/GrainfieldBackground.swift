import SwiftUI

// MARK: - GrainfieldBackground
//
// The premium "alive surface" background for every activation screen.
// Cream `bgPrimary` with the `activationGrainfield` Metal shader layered
// on top: a faint upper-center light bloom + a breathing closed-form
// film grain. So subtle it reads as paper and light depth, never busy.
//
// Drive: a `TimelineView(.animation)` feeds a `time` uniform (seconds)
// to the shader. Reduce Motion freezes `time = 0`, yielding a static
// bloom + static grain that still renders identically minus the breath.
//
// Cheap: the shader is texture-free + branch-light (see
// ActivationShaders.metal). It runs on the cream rect itself, so any
// content placed above it is untouched.
//
// Usage — outermost layer of an activation screen:
//
//   ZStack {
//       GrainfieldBackground()
//       content
//   }
//
// Tune `intensity` up for a slightly more present surface (paywall
// hero) or down toward 0.03 for dense data screens. `base` overrides
// the cream if a screen ever needs a warmer stock.
struct GrainfieldBackground: View {
    /// Combined drive for bloom strength + grain amplitude. 0.05 is the
    /// calibrated "whisper of light" default; 0.03 is near-invisible,
    /// 0.08 is the most present the surface should ever get.
    var intensity: Float = 0.05

    /// Base fill. Defaults to the locked cream `bgPrimary` — the only
    /// background token. Override only for a deliberate warmer stock.
    var base: Color = Palette.bgPrimary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
                let t: Float = reduceMotion
                    ? 0
                    : Float(ctx.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 600))
                Rectangle()
                    .fill(base)
                    .colorEffect(ShaderLibrary.activationGrainfield(
                        .float(t),
                        .float(intensity),
                        .float2(Float(geo.size.width), Float(geo.size.height))
                    ))
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Grainfield") {
    ZStack {
        GrainfieldBackground()
        Text("alive surface")
            .font(Typo.heroHeadline)
            .foregroundStyle(Palette.textPrimary)
    }
}
#endif
