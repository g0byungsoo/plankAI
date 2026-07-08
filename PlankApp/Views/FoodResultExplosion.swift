import Lottie
import SwiftUI

// MARK: - FoodResultExplosion
//
// v1.0.21 (2026-06-18) — the wow moment after a food scan completes.
// v1.2 (2026-07-02) — founder swap: the heart + star explosion pair
// retires for the Sparkling burst (13 concave four-point stars popping
// in a staggered round, founder-supplied lottie). Two layered plays —
// a full-frame burst and a mirrored, smaller echo 260ms behind — keep
// the sequential-beats cinematography the old pair had.
//
// The lottie ships hot-raspberry; both fills and strokes are retinted
// live to the locked palette (rose body, light-pink rim) via value
// providers so the asset can't drift the brand.
//
// Behavior:
//   - `triggerId` bump (via .id()) restarts playback from frame 0
//   - allowsHitTesting(false) — never blocks the result-mode toolbar
//   - reduce-motion gates straight to invisible

struct FoodResultExplosion: View {

    /// Increment this to retrigger the animation (e.g. on each new
    /// scan result land). The .id() modifier rebuilds the view, so
    /// the Lottie playback restarts from frame 0.
    let triggerId: Int

    @State private var echoFired = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Gate behind `triggerId >= 0` so the LottieView doesn't mount
        // on the initial camera-open (founder bug: explosion fired
        // before the first scan). PlanView initializes the trigger at
        // -1 and bumps to 0 on first onResultLanded.
        if reduceMotion || triggerId < 0 {
            EmptyView()
        } else {
            ZStack {
                if let sparkleAnimation {
                    burst(sparkleAnimation)
                        .opacity(0.95)
                    if echoFired {
                        burst(sparkleAnimation)
                            .scaleEffect(x: -0.62, y: 0.62)
                            .opacity(0.8)
                    }
                }
            }
            .id(triggerId)  // .id() bump retriggers playback on next land
            .allowsHitTesting(false)
            .transition(.opacity)
            .onAppear {
                echoFired = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    echoFired = true
                }
            }
        }
    }

    private func burst(_ animation: LottieAnimation) -> some View {
        LottieView(animation: animation)
            .playbackMode(
                .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
            )
            .valueProvider(
                ColorValueProvider(Self.sparkleFill),
                for: AnimationKeypath(keypath: "**.Fill 1.Color")
            )
            .valueProvider(
                ColorValueProvider(Self.sparkleStroke),
                for: AnimationKeypath(keypath: "**.Stroke 1.Color")
            )
            .scaledToFit()
    }

    /// Locked palette: rose body (#C4677A), light-pink rim (#F5D5D8).
    private static let sparkleFill = LottieColor(r: 0.769, g: 0.404, b: 0.478, a: 1)
    private static let sparkleStroke = LottieColor(r: 0.961, g: 0.835, b: 0.847, a: 1)

    private var sparkleAnimation: LottieAnimation? {
        LottieAnimation.named(
            "result_explosion_sparkle",
            bundle: .main,
            subdirectory: "lottie"
        )
    }
}
