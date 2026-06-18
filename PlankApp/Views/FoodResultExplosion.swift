import Lottie
import SwiftUI

// MARK: - FoodResultExplosion
//
// v1.0.21 (2026-06-18) — the wow moment after a food scan completes.
// Two Lottie animations (heart + star explosion) play once,
// overlaid above the carousel result mode, then auto-dismiss. The
// founder asked for a magical beat to mark the snap→result moment;
// these are the TikTok / IG-girl-post register that fits the
// JeniFit cohort.
//
// Behavior:
//   - `play()` (via .id() bump) restarts the animations from frame 0
//   - Heart explosion fires first (300ms head start), star explosion
//     trails — sequential layered beats read more cinematic than a
//     single big burst
//   - Both auto-fade at the end so they don't linger past the result
//     card reveal
//   - allowsHitTesting(false) — never blocks the result-mode toolbar
//   - reduce-motion gates straight to invisible

struct FoodResultExplosion: View {

    /// Increment this to retrigger the animation (e.g. on each new
    /// scan result land). The .id() modifier rebuilds the view, so
    /// the Lottie playback restarts from frame 0.
    let triggerId: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // v1.0.22 (2026-06-18) — gate behind `triggerId >= 0` so the
        // LottieView doesn't mount on the initial camera-open
        // (founder bug: explosion fired before the first scan
        // because the view was always mounted and Lottie auto-plays
        // on mount). PlanView initializes the trigger at -1 and
        // bumps to 0 on first onResultLanded.
        if reduceMotion || triggerId < 0 {
            EmptyView()
        } else {
            ZStack {
                // Star fires first (lighter / sparkle), heart layers
                // on top with a small lead. Both scale-to-fit so they
                // fill the camera-frame slot without distortion.
                if let starAnimation {
                    LottieView(animation: starAnimation)
                        .playbackMode(
                            .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
                        )
                        .scaledToFit()
                        .opacity(0.85)
                }
                if let heartAnimation {
                    LottieView(animation: heartAnimation)
                        .playbackMode(
                            .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
                        )
                        .scaledToFit()
                        .opacity(0.95)
                }
            }
            .id(triggerId)  // .id() bump retriggers playback on next land
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private var heartAnimation: LottieAnimation? {
        LottieAnimation.named(
            "result_explosion_heart",
            bundle: .main,
            subdirectory: "lottie"
        )
    }

    private var starAnimation: LottieAnimation? {
        LottieAnimation.named(
            "result_explosion_star",
            bundle: .main,
            subdirectory: "lottie"
        )
    }
}
