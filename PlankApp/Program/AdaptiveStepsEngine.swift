import Foundation

// MARK: - AdaptiveStepsEngine (E1 THE SPINE — B3)
//
// docs/app_v25/05_E1_SPINE.md §3. The Adams 2017 adaptive-goal
// recipe: the recommendation is the 60th percentile of her OWN
// recent recorded days, moved conservatively (±15% per recalc — the
// relief law: goals breathe DOWN), then clamped to the evidence band
// through the ONE clamp law (ProgramFacts). Pure and deterministic;
// the weekly read offers the result — nothing applies silently.

enum AdaptiveStepsEngine {

    static func recommendedGoal(
        recentDailySteps: [Int],
        currentGoal: Int?
    ) -> Int? {
        // A day ≤500 steps reads "the phone didn't come along", not
        // zero effort — it never drags the percentile.
        let recorded = recentDailySteps.filter { $0 > 500 }
        // Fewer than 5 recorded days = not enough history to say
        // anything honest. No recommendation, never a guess.
        guard recorded.count >= 5 else { return nil }

        // Nearest-rank 60th percentile of her own days.
        let sorted = recorded.sorted()
        let rank = Int((0.6 * Double(sorted.count)).rounded(.up))
        var goal = Double(sorted[max(0, rank - 1)])

        // Conservative movement: one recalc moves at most ±15% from
        // the goal she holds — rises stay reachable, and relief is
        // structural (the goal breathes DOWN after hard weeks).
        if let currentGoal, currentGoal > 0 {
            let lo = Double(currentGoal) * 0.85
            let hi = Double(currentGoal) * 1.15
            goal = min(hi, max(lo, goal))
        }

        // The ONE clamp law (evidence band 2,500-8,000, round-50) —
        // shared with every other writer of this fact kind.
        return ProgramFacts.clamped(
            .int(Int(goal.rounded())), kind: .stepGoal, authority: .recommended
        ).intValue
    }
}
