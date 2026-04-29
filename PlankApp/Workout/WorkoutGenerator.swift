import Foundation

/// Pure workout generator. No instance state, no SwiftData, no Supabase.
/// All inputs via arguments, output returned.
struct WorkoutGenerator {

    struct Input {
        let goal: WorkoutGoal
        let sessionLengthMinutes: Int              // 5, 7, or 10
        let recentSessionExerciseIds: [[String]]   // last 7 days, each day's exercise IDs
        let lastPlankHoldTime: Double?             // latest benchmark, seconds
        let recentRatings: [Int]                   // last N session ratings (1-5)
        let startingTier: Int                      // 1/2/3 from onboarding inputs
    }

    /// Generate a workout session. Returns a WorkoutPreset-shaped result.
    static func generate(from input: Input) -> WorkoutPreset {
        let exerciseCount = exerciseCount(for: input.sessionLengthMinutes)
        let ratedTier = targetDifficultyTier(from: input.recentRatings)
        // Until the user has 3+ ratings, pin to startingTier so day-1 difficulty
        // matches the fitness signal from age/activity/baseline.
        let targetTier = input.recentRatings.count >= 3 ? ratedTier : input.startingTier
        let pool = candidatePool(goal: input.goal, tier: targetTier)
        let recentFlat = Set(input.recentSessionExerciseIds.flatMap { $0 })

        var selected: [Exercise] = []
        var usedIds: Set<String> = []

        for _ in 0..<exerciseCount {
            guard let next = pickNext(
                from: pool,
                selected: selected,
                usedIds: usedIds,
                recentIds: recentFlat,
                exerciseCount: exerciseCount,
                currentIndex: selected.count
            ) else { break }

            selected.append(next)
            usedIds.insert(next.id)
        }

        let slots = selected.map { exercise in
            ExerciseSlot(
                exerciseId: exercise.id,
                duration: duration(for: exercise, tier: targetTier),
                restAfter: exercise.restAfter
            )
        }

        return WorkoutPreset(
            id: "gen_\(UUID().uuidString.prefix(8))",
            name: generatedName(goal: input.goal),
            goal: input.goal,
            difficulty: difficulty(from: targetTier),
            exercises: slots,
            estimatedDuration: input.sessionLengthMinutes,
            isGenerated: true
        )
    }

    // MARK: - Exercise Count

    /// 5min = 6, 7min = 8, 10min = 10
    private static func exerciseCount(for minutes: Int) -> Int {
        switch minutes {
        case ...5: return 6
        case 6...7: return 8
        default: return 10
        }
    }

    // MARK: - Difficulty Adjustment

    /// If last 3 ratings average > 4, bump tier. If < 2.5, lower.
    private static func targetDifficultyTier(from ratings: [Int]) -> Int {
        guard ratings.count >= 3 else { return 1 }
        let recent = ratings.suffix(3)
        let avg = Double(recent.reduce(0, +)) / Double(recent.count)
        if avg >= 4.0 { return 3 }
        if avg <= 2.5 { return 1 }
        return 2
    }

    // MARK: - Candidate Pool

    private static func candidatePool(goal: WorkoutGoal, tier: Int) -> [Exercise] {
        let goalExercises: [Exercise]
        switch goal {
        case .strength:
            goalExercises = ExerciseBank.all.filter {
                $0.targetArea == .frontCore || $0.targetArea == .fullCore
            }
        case .definition:
            goalExercises = ExerciseBank.all.filter {
                $0.targetArea == .frontCore
            }
        case .sculpting:
            goalExercises = ExerciseBank.all.filter {
                $0.targetArea == .obliques
            }
        case .fullCore:
            goalExercises = ExerciseBank.all
        }

        // Include exercises from other areas for variety (always need balance)
        let otherExercises = ExerciseBank.all.filter { exercise in
            !goalExercises.contains(where: { $0.id == exercise.id })
        }

        // Primary pool: goal exercises at or below target tier
        // Secondary pool: other exercises at or below target tier
        let primary = goalExercises.filter { $0.difficultyTier <= tier + 1 }
        let secondary = otherExercises.filter { $0.difficultyTier <= tier + 1 }

        return primary + secondary
    }

    // MARK: - Exercise Selection

    private static func pickNext(
        from pool: [Exercise],
        selected: [Exercise],
        usedIds: Set<String>,
        recentIds: Set<String>,
        exerciseCount: Int,
        currentIndex: Int
    ) -> Exercise? {
        let lastArea = selected.last?.targetArea
        let lastType = selected.last?.type
        let lastIncompat = selected.last.map { Set($0.incompatibleWith) } ?? []

        // Score each candidate
        var scored: [(Exercise, Double)] = []

        for exercise in pool {
            guard !usedIds.contains(exercise.id) else { continue }
            guard !exercise.cameraTracked else { continue }  // no camera exercises in routines

            var score = 10.0

            // Rule 1: No consecutive same target area
            if exercise.targetArea == lastArea {
                score -= 8
            }

            // Rule 2: Prefer alternating static/dynamic
            if exercise.type == lastType {
                score -= 2
            }

            // Rule 3: Recovery curve — intensity peaks at 3-5, tapers at end
            let intensityMultiplier = intensityCurve(index: currentIndex, total: exerciseCount)
            let tierMatch = abs(Double(exercise.difficultyTier) - intensityMultiplier * 3.0)
            score -= tierMatch

            // Rule 4: Cross-session variety — penalize recent exercises
            if recentIds.contains(exercise.id) {
                score -= 3
            }

            // Rule 5: Incompatibility
            if lastIncompat.contains(exercise.id) {
                score -= 6
            }

            // Pair side exercises (left always before right)
            if exercise.id.hasSuffix("_right") {
                let leftId = exercise.id.replacingOccurrences(of: "_right", with: "_left")
                if let lastSelected = selected.last, lastSelected.id == leftId {
                    score += 5  // strongly prefer right after left
                } else if !usedIds.contains(leftId) {
                    score -= 10  // don't pick right if left hasn't been done
                }
            }
            if exercise.id.hasSuffix("_left") {
                // Check if we have room for the right side too
                let rightId = exercise.id.replacingOccurrences(of: "_left", with: "_right")
                if currentIndex + 1 >= exerciseCount && !usedIds.contains(rightId) {
                    score -= 5  // don't start left if no room for right
                }
            }

            scored.append((exercise, score))
        }

        // Pick the highest-scored candidate, with some randomness in the top tier
        scored.sort { $0.1 > $1.1 }
        let topScore = scored.first?.1 ?? 0
        let candidates = scored.filter { $0.1 >= topScore - 1.0 }

        guard !candidates.isEmpty else {
            // Relaxed fallback: just pick anything unused
            return pool.first { !usedIds.contains($0.id) && !$0.cameraTracked }
        }

        return candidates.randomElement()?.0
    }

    /// Recovery curve: 0.0 at start, peaks ~0.8 at index 3-5, tapers to 0.4 at end.
    private static func intensityCurve(index: Int, total: Int) -> Double {
        guard total > 1 else { return 0.5 }
        let normalized = Double(index) / Double(total - 1)
        // Bell-ish curve peaking around 0.4 of the session
        let peak = 0.4
        let spread = 0.3
        let intensity = exp(-pow(normalized - peak, 2) / (2 * spread * spread))
        return intensity * 0.8 + 0.2  // range 0.2...1.0
    }

    // MARK: - Duration Scaling

    private static func duration(for exercise: Exercise, tier: Int) -> Int {
        switch tier {
        case 1: return exercise.defaultDuration
        case 2: return exercise.defaultDuration + 5
        default: return exercise.defaultDuration + 10
        }
    }

    // MARK: - Naming

    private static func generatedName(goal: WorkoutGoal) -> String {
        let names: [WorkoutGoal: [String]] = [
            .strength: ["Power Core", "Steel Abs", "Core Crusher", "Solid Foundation", "Core Forge"],
            .definition: ["Ab Sculptor", "Definition Day", "Chisel Session", "Cut & Tone", "Ab Attack"],
            .sculpting: ["Waist Work", "Oblique Focus", "Side Sculptor", "Core Twist", "Waist Burner"],
            .fullCore: ["Full Send", "360 Session", "Core Mix", "Complete Core", "All-Around"],
        ]
        return names[goal]?.randomElement() ?? "Custom Workout"
    }

    private static func difficulty(from tier: Int) -> WorkoutDifficulty {
        switch tier {
        case 1: return .beginner
        case 2: return .intermediate
        default: return .advanced
        }
    }

    // MARK: - Starting Tier (from onboarding signals)

    /// Compute a starting difficulty tier (1/2/3) from onboarding inputs.
    /// Used for day-1 workouts before recent ratings exist.
    static func startingTier(
        experience: String,
        baselineSeconds: Int,
        activityLevel: String,
        ageRange: String
    ) -> Int {
        // Hard pin to beginner for clear "I'm new" signals
        if experience == "never" || experience == "gaveUp" { return 1 }

        // Otherwise score from baseline + activity, lightly modified by age
        var score = 0
        if baselineSeconds >= 60 { score += 2 }
        else if baselineSeconds >= 30 { score += 1 }

        switch activityLevel {
        case "athlete": score += 2
        case "active": score += 1
        case "moderate": score += 0
        case "light", "sedentary": score -= 1
        default: break
        }

        // Older / younger users get a gentler start; doesn't override clear signals
        if ageRange == "55plus" || ageRange == "under18" { score -= 1 }

        if score >= 3 { return 3 }
        if score >= 1 { return 2 }
        return 1
    }

    /// WorkoutDifficulty equivalent of startingTier — for picking presets.
    static func startingDifficulty(
        experience: String,
        baselineSeconds: Int,
        activityLevel: String,
        ageRange: String
    ) -> WorkoutDifficulty {
        difficulty(from: startingTier(
            experience: experience,
            baselineSeconds: baselineSeconds,
            activityLevel: activityLevel,
            ageRange: ageRange
        ))
    }
}
