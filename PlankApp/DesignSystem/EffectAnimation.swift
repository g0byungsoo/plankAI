import Foundation
import SwiftUI
import Lottie

// MARK: - EffectAnimation
//
// Type-safe handle for the 6 effect Lotties bundled at
// PlankApp/Resources/animations/. These are short, decorative
// motion clips for celebratory / interaction moments — different
// from the 128 exercise Lotties at PlankApp/Resources/lottie/ which
// are looping demonstrations.
//
// Usage:
//   LottieEffectView(.fireworks, loop: false)
//     .frame(width: 240, height: 240)

enum EffectAnimation: String, CaseIterable {
    /// Celebratory burst — session-done, milestone reached.
    case fireworks
    /// Continuous loader — alternative to the sticker-stamp loading
    /// burst; use when the action takes longer and a steady-state
    /// loop reads better than a one-shot.
    case pinkBubbleLoader = "pink-bubble-loader"
    /// Tiny accent — punctuation on small wins. Looping by default.
    case scribbleTwirly = "scribble-twirly"
    /// Tiny accent — close/dismiss / gentle rejection.
    case scribbleX = "scribble-x"
    /// Affection / heart-felt moment. Use sparingly.
    case sparklingHearts = "sparkling-hearts"
    /// Bonded / gentle moment — paired with cherub, heart-lock, or
    /// the connection-themed copy.
    case twoHeartsBeingDrawn = "two-hearts-being-drawn"

    /// Filename stem under PlankApp/Resources/animations/.
    var filename: String { rawValue }
}

// MARK: - LottieEffectView
//
// Plays one of the bundled effect animations. Defaults to playing
// once (one-shot — celebratory bursts shouldn't loop forever).
// Pass `loop: true` for steady-state loaders / decorations.

struct LottieEffectView: View {
    let lottie: LottieAnimation?
    let loop: Bool
    let speed: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Resolved at init so body doesn't re-hit the Lottie cache on every
    /// recompute. The asset is small (a few hundred KB JSON), but
    /// LottieView() has to reattach when re-materialized.
    init(_ animation: EffectAnimation, loop: Bool = false, speed: CGFloat = 1.0) {
        self.lottie = LottieAnimation.named(
            animation.filename,
            bundle: .main,
            subdirectory: "animations"
        )
        self.loop = loop
        self.speed = speed
    }

    var body: some View {
        if reduceMotion {
            // Decorative-only — celebrations should respect the user's
            // motion preference. Layout-preserving Color.clear so the
            // parent's .frame still applies.
            Color.clear
        } else if let lottie {
            LottieView(animation: lottie)
                .playing(loopMode: loop ? .loop : .playOnce)
                .animationSpeed(speed)
                .resizable()
        } else {
            // Fallback — never crash on a missing asset, render
            // transparent so downstream layout is unchanged.
            Color.clear
        }
    }
}
