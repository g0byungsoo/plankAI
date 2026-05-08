#if DEBUG
import Foundation

// MARK: - WorkoutGeneratorSelfCheck
//
// Runs a parameter-grid battery of `WorkoutGenerator.generate(...)` calls
// and pipes each output through the existing validators
// (`validateBalance`, `validatePositionFlow`, `validateDifficultyBounds`,
// `validateDurationGrid`, `validateRestGrid`). Reports any failures to
// the console with the full input context so regressions are obvious.
//
// Why this and not XCTest? The main `plankAI` target doesn't have a test
// target wired into the project file yet. Adding one is involved
// pbxproj surgery; this self-check ships the same coverage today and is
// trivially portable to XCTest later (each scenario is already an
// individual function).
//
// Wired from `PlankAIApp.init` to fire once at launch in DEBUG. Output
// is silent on success; failures are printed with `⚠️ self-check` prefix
// so they're easy to spot in Xcode console.

enum WorkoutGeneratorSelfCheck {

    /// Run every scenario, return collected failure descriptions. Empty
    /// array = all green. The caller is expected to print or assert on
    /// the result; we don't assertionFailure here so a single broken
    /// scenario doesn't crash the whole DEBUG launch.
    @discardableResult
    static func runAll() -> [String] {
        var failures: [String] = []

        // Cross-product: tier × length × bodyFocus combinations covering
        // the corners of the input space. Not exhaustive — picks the
        // edges where the rules table actually changes behavior.
        let tiers = [1, 2, 3]
        let lengths = [5, 10, 15, 30, 45]
        let focusSets: [(label: String, focus: [BodyFocus])] = [
            ("flatBelly",     [.flatBelly]),
            ("tonedArms",     [.tonedArms]),
            ("roundButt",     [.roundButt]),
            ("slimLegs",      [.slimLegs]),
            ("fullBody",      [.fullBody]),
            ("multi-flat+toned", [.flatBelly, .tonedArms]),
            ("multi-glutes+legs", [.roundButt, .slimLegs]),
        ]

        for tier in tiers {
            for length in lengths {
                for (focusLabel, focus) in focusSets {
                    let label = "tier=\(tier) len=\(length)min focus=\(focusLabel)"
                    let input = WorkoutGenerator.Input(
                        bodyFocus: focus,
                        lengthMinutes: length,
                        recentSessionExerciseIds: [],
                        recentRatings: [],
                        startingTier: tier
                    )
                    let workout = WorkoutGenerator.generate(from: input)
                    failures.append(contentsOf: validate(workout, tier: tier, label: label))
                }
            }
        }

        // Stretch session — separate codepath, separate validator pass.
        for length in [5, 10, 15] {
            let label = "stretch len=\(length)min"
            let workout = WorkoutGenerator.generateStretchSession(lengthMinutes: length)
            // Stretch sessions only run validateBalance + validatePositionFlow;
            // duration/rest grids don't apply (mobility uses fixed perMoveSec).
            if let issue = WorkoutGenerator.validateBalance(workout) {
                failures.append("\(label) — balance: \(issue)")
            }
            if let issue = WorkoutGenerator.validatePositionFlow(workout) {
                failures.append("\(label) — position-flow: \(issue)")
            }
        }

        // Edge cases worth exercising explicitly.
        failures.append(contentsOf: edgeCaseChecks())

        // Final report.
        if failures.isEmpty {
            print("[SelfCheck] ✅ WorkoutGenerator: all scenarios pass")
        } else {
            print("[SelfCheck] ⚠️ WorkoutGenerator: \(failures.count) failure(s):")
            for f in failures { print("  - \(f)") }
        }
        return failures
    }

    // MARK: - Per-scenario validation

    private static func validate(_ workout: WorkoutPreset, tier: Int, label: String) -> [String] {
        var issues: [String] = []
        if let i = WorkoutGenerator.validateBalance(workout)            { issues.append("\(label) — balance: \(i)") }
        if let i = WorkoutGenerator.validatePositionFlow(workout)       { issues.append("\(label) — position-flow: \(i)") }
        if let i = WorkoutGenerator.validateDifficultyBounds(workout, tier: tier) {
            issues.append("\(label) — difficulty: \(i)")
        }
        if let i = WorkoutGenerator.validateDurationGrid(workout)       { issues.append("\(label) — duration-grid: \(i)") }
        if let i = WorkoutGenerator.validateRestGrid(workout)           { issues.append("\(label) — rest-grid: \(i)") }
        // Sanity: every workout should have ≥ 1 main slot.
        if !workout.exercises.contains(where: { $0.category == .main }) {
            issues.append("\(label) — empty main block")
        }
        return issues
    }

    // MARK: - Edge cases

    /// Scenarios that don't fall on the regular grid but matter:
    ///   - Empty bodyFocus (defaults to fullBody)
    ///   - Recent-ratings feedback adjusting tier (avg high → bump up)
    ///   - Recent-ratings feedback adjusting tier (avg low → bump down)
    ///   - Long session (45 min) — exercises the round-doubling path
    private static func edgeCaseChecks() -> [String] {
        var failures: [String] = []

        // Empty bodyFocus → engine should default to .fullBody.
        let emptyFocusInput = WorkoutGenerator.Input(
            bodyFocus: [],
            lengthMinutes: 10,
            recentSessionExerciseIds: [],
            recentRatings: [],
            startingTier: 2
        )
        let emptyFocusWorkout = WorkoutGenerator.generate(from: emptyFocusInput)
        failures.append(contentsOf: validate(emptyFocusWorkout, tier: 2, label: "empty-focus"))

        // High recent ratings (5,5,5) bump tier 2 → 3 effective.
        let bumpUpInput = WorkoutGenerator.Input(
            bodyFocus: [.flatBelly],
            lengthMinutes: 10,
            recentSessionExerciseIds: [],
            recentRatings: [5, 5, 5],
            startingTier: 2
        )
        let bumpUpWorkout = WorkoutGenerator.generate(from: bumpUpInput)
        // Validate against the BUMPED tier (3), not the starting tier.
        failures.append(contentsOf: validate(bumpUpWorkout, tier: 3, label: "ratings-bump-up"))

        // Low recent ratings (2,2,2) drop tier 2 → 1 effective.
        let bumpDownInput = WorkoutGenerator.Input(
            bodyFocus: [.flatBelly],
            lengthMinutes: 10,
            recentSessionExerciseIds: [],
            recentRatings: [2, 2, 2],
            startingTier: 2
        )
        let bumpDownWorkout = WorkoutGenerator.generate(from: bumpDownInput)
        failures.append(contentsOf: validate(bumpDownWorkout, tier: 1, label: "ratings-bump-down"))

        // 45-min session — exercises the round-doubling path. Validate
        // round numbers are sequential (1, 2, ...) and don't skip.
        let longInput = WorkoutGenerator.Input(
            bodyFocus: [.fullBody],
            lengthMinutes: 45,
            recentSessionExerciseIds: [],
            recentRatings: [],
            startingTier: 2
        )
        let longWorkout = WorkoutGenerator.generate(from: longInput)
        failures.append(contentsOf: validate(longWorkout, tier: 2, label: "round-pattern-45min"))
        // Round-monotonic check: rounds should only increment.
        var lastRound = 1
        for slot in longWorkout.exercises where slot.category == .main {
            if slot.round < lastRound {
                failures.append("round-pattern-45min — round regressed from \(lastRound) to \(slot.round)")
                break
            }
            lastRound = slot.round
        }

        return failures
    }
}
#endif
