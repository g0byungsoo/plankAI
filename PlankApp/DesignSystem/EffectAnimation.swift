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

    // v1.6 (2026-06-26) — founder-supplied line-art pink celebration
    // set. Editorial register (rough-lined / smoke, not glossy confetti),
    // so they suit the her75 restraint while still rewarding a peak.
    /// Rough-lined pink fireworks burst — a peak reward (plan ready,
    /// graduation, big milestone).
    case fireworksLined = "fireworks-lined"
    /// Pink fireworks that shoot UP then burst — the "ta-da, it's ready"
    /// reveal beat (plan-build complete).
    case fireworksRise = "fireworks-rise"
    /// Soft pink smoke puff — a gentler reward (a quiet win / commit).
    case smokePuff = "smoke-puff"
    /// Pink smoke rising — a soft upward flourish.
    case smokeRise = "smoke-rise"

    // v1.6b (2026-06-26) — founder confetti set. Tasteful (stars / lines /
    // soft), warmer than a generic shower; for the big earned peaks.
    /// Star confetti burst — a celebratory peak (graduation, streak milestone).
    case confettiStars = "confetti-stars"
    /// "Congratulations" confetti lines/streamers — a graduation-grade beat.
    case confettiLines = "confetti-lines"
    /// Simple confetti shower — a standard reward.
    case confetti
    /// A softer, lighter confetti — a gentle daily reward.
    case confettiSoft = "confetti-soft"

    /// Filename stem under PlankApp/Resources/animations/.
    var filename: String { rawValue }

    /// Warm the Lottie cache OFF the main thread so a heavier animation
    /// (e.g. the 120KB fireworks) has zero parse hitch when it first
    /// appears. Call this ahead of the moment — e.g. while a loader is up.
    /// `LottieAnimation.named` caches by name globally, so the later
    /// on-main render hits the warm cache instantly.
    func preload() {
        let name = filename
        Task.detached(priority: .utility) {
            _ = LottieAnimation.named(name, bundle: .main, subdirectory: "animations")
        }
    }
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
