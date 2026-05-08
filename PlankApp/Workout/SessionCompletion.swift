import Foundation
import PlankSync

/// Session completion gate. A session counts as "complete" only when the
/// user has actually trained for at least `threshold` of the planned work.
/// Partial sessions don't count toward streaks, day advance, or first-session
/// gates — see `docs/workout_engine_research.md` (planned Phase 7 add).
///
/// Threshold of **0.70** (70%) sits in the middle of the spec proposal
/// (50%/70%/80%): tight enough to require real effort, lenient enough that
/// a single skipped exercise mid-session still counts.
enum SessionCompletion {

    static let threshold: Double = 0.70

    /// Fraction of planned session time the user actually completed.
    /// Returns 0 for an empty results array (no exercise was reached).
    static func fraction(for results: [ExerciseResultEntry]) -> Double {
        let planned = results.reduce(0) { $0 + $1.duration }
        let completed = results.reduce(0) { $0 + $1.completedDuration }
        guard planned > 0 else { return 0 }
        return Double(completed) / Double(planned)
    }

    /// `true` when the user did at least `threshold` of the planned work.
    static func didMeetThreshold(_ results: [ExerciseResultEntry]) -> Bool {
        fraction(for: results) >= threshold
    }
}
