import Foundation

/// One playback unit for the session player: an exercise + which side to render
/// (when unilateral) and whether the source Lottie should be flipped.
struct ExerciseRendering: Equatable {
    let exercise: Exercise
    let side: Side?

    /// `true` when the engine wants the side opposite to the one the source
    /// Lottie animates. The view layer mirrors the animation horizontally to
    /// produce the matching side.
    var mirrorHorizontally: Bool {
        guard let side, let defaultSide = exercise.defaultSide else { return false }
        return side != defaultSide
    }
}

enum ExerciseMirror {

    /// Build the renderings for one logical "exercise pick".
    /// - bilateral / alternating → 1 rendering, `side = nil`
    /// - unilateral              → 2 renderings, left then right
    static func renderings(for exercise: Exercise) -> [ExerciseRendering] {
        switch exercise.symmetry {
        case .bilateral, .alternating:
            return [ExerciseRendering(exercise: exercise, side: nil)]
        case .unilateral:
            return [
                ExerciseRendering(exercise: exercise, side: .left),
                ExerciseRendering(exercise: exercise, side: .right),
            ]
        }
    }

    /// Single-side rendering (e.g. when a preset slot has explicitly chosen one side).
    static func rendering(for exercise: Exercise, side: Side?) -> ExerciseRendering {
        let resolvedSide: Side?
        switch exercise.symmetry {
        case .unilateral:
            resolvedSide = side ?? exercise.defaultSide ?? .left
        case .bilateral, .alternating:
            resolvedSide = nil
        }
        return ExerciseRendering(exercise: exercise, side: resolvedSide)
    }
}
