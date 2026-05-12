import Lottie
import SwiftUI

/// Plays the exercise's bundled Lottie animation. Mirrors horizontally when
/// the rendering's `mirrorHorizontally` flag is set (used for the opposite
/// side of unilateral exercises). Falls back to an SF Symbol if the JSON
/// asset isn't bundled.
///
/// `isPaused` freezes the animation at its current frame when the user
/// pauses the session — restarting it on resume picks up where the
/// animation left off rather than restarting from frame zero.
struct LottieExerciseView: View {
    let rendering: ExerciseRendering
    let isPaused: Bool
    private let animation: LottieAnimation?

    /// Resolved at init so body doesn't re-hit the Lottie cache + reattach
    /// LottieView on every recompute. Exercise Lotties are 100KB+ each and
    /// the session view re-renders frequently during the duration timer.
    init(rendering: ExerciseRendering, isPaused: Bool = false) {
        self.rendering = rendering
        self.isPaused = isPaused
        self.animation = LottieAnimation.named(
            rendering.exercise.lottieFile,
            bundle: .main,
            subdirectory: "lottie"
        )
    }

    var body: some View {
        Group {
            if let animation {
                LottieView(animation: animation)
                    .playbackMode(isPaused ? .paused : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)))
                    .resizable()
                    .scaleEffect(x: rendering.mirrorHorizontally ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(rendering.exercise.lottieRotation))
            } else {
                fallback
            }
        }
    }

    private var fallback: some View {
        Image(systemName: "figure.core.training")
            .font(.system(size: 56, weight: .regular))
            .foregroundStyle(Palette.accent)
    }
}
