import Foundation

/// Pure workout generator. No instance state, no SwiftData, no Supabase.
///
/// Inputs are user signals + intent; output is a `WorkoutPreset` with three
/// labeled phases (warmup → main → cooldown), all constraints applied:
///
///   - Stratified by area: 70% primary focus, 30% secondary (bias × research).
///   - L/R balance: unilateral picks emit a left+right pair.
///   - No-consecutive-same-primary-area, alternate hold↔rep, intensity curve.
///   - Difficulty cap from `startingTier` so beginners never see hard moves.
///   - Cross-session variety: penalize exercises seen in last 7 days.
///
/// Design source-of-truth: `docs/workout_engine_research.md`.
struct WorkoutGenerator {

    struct Input {
        let bodyFocus: [BodyFocus]                 // multi-select, may be empty (defaults to fullBody)
        let lengthMinutes: Int                     // 5/7/10/15/30/45 (closest match used)
        let recentSessionExerciseIds: [[String]]   // last 7 days, each day's exercise IDs
        let recentRatings: [Int]                   // last N session ratings (1-5)
        let startingTier: Int                      // 1/2/3 from onboarding signals
        /// Manual "today's energy" knob: -1 ease in, 0 steady, +1 push it.
        /// Nudges the effective tier ±1 (clamped 1–3) so it flows through
        /// the existing rest / duration / difficulty machinery coherently —
        /// and stays consistent with the DEBUG validators, which key off the
        /// same effective tier.
        var intensityOffset: Int = 0
    }

    static func generate(from input: Input) -> WorkoutPreset {
        let structure = SessionStructure.forLength(input.lengthMinutes)
        let tier = effectiveTier(input: input)
        let cap = maxDifficulty(tier: tier)
        let floor = minDifficulty(tier: tier)

        let focus = input.bodyFocus.isEmpty ? [BodyFocus.fullBody] : input.bodyFocus
        let primaryAreas = focus.combinedPrimaryAreas
        let secondaryAreas = focus.combinedSecondaryAreas(excludingPrimary: primaryAreas)
        let recentFlat = Set(input.recentSessionExerciseIds.flatMap { $0 })
        let goal = legacyGoal(for: focus)

        var slots: [ExerciseSlot] = []

        // 1. Warmup — type=mobility, difficulty <= 2, dynamic-feel preferred
        slots.append(contentsOf: pickWarmup(
            count: structure.warmupCount,
            duration: structure.warmupDurationSec,
            recent: recentFlat
        ))

        // 2. Main block — stratified, all constraints applied
        slots.append(contentsOf: pickMain(
            count: structure.mainCount,
            primaryAreas: primaryAreas,
            secondaryAreas: secondaryAreas,
            difficultyCap: cap,
            difficultyFloor: floor,
            tier: tier,
            goal: goal,
            lengthMinutes: input.lengthMinutes,
            recent: recentFlat
        ))

        // 3. Cooldown — type=mobility, pace=hold (static stretches)
        slots.append(contentsOf: pickCooldown(
            count: structure.cooldownCount,
            duration: structure.cooldownDurationSec,
            recent: recentFlat,
            // Bias toward stretching the areas we just trained.
            preferAreas: primaryAreas.union(secondaryAreas)
        ))

        let workout = WorkoutPreset(
            id: "gen_\(UUID().uuidString.prefix(8))",
            name: generatedName(for: focus),
            description: nil,
            goal: legacyGoal(for: focus),
            difficulty: difficulty(from: tier),
            exercises: slots,
            estimatedDuration: input.lengthMinutes,
            isGenerated: true
        )

        // Sanity checks per docs/workout_session_rules.md §9. All
        // DEBUG-only — production never asserts (the engine should
        // always return *something*, even if degraded). Issues print
        // with ⚠️ and a short tag so they surface in Xcode console
        // when running locally.
        #if DEBUG
        if let issue = validateBalance(workout) {
            print("[WorkoutGenerator] ⚠️ unbalanced: \(issue)")
        }
        if let issue = validatePositionFlow(workout) {
            print("[WorkoutGenerator] ⚠️ position-flow: \(issue)")
        }
        if let issue = validateDifficultyBounds(workout, tier: tier) {
            print("[WorkoutGenerator] ⚠️ difficulty-bounds: \(issue)")
        }
        if let issue = validateDurationGrid(workout) {
            print("[WorkoutGenerator] ⚠️ duration-grid: \(issue)")
        }
        if let issue = validateRestGrid(workout) {
            print("[WorkoutGenerator] ⚠️ rest-grid: \(issue)")
        }
        #endif
        return workout
    }

    /// Walks every slot and confirms unilateral exercises have balanced
    /// L/R pairing within each category. Returns the first imbalance
    /// found (as a description) or nil if everything is paired.
    static func validateBalance(_ workout: WorkoutPreset) -> String? {
        // Group: "exerciseId|category" → (left, right, none)
        var counts: [String: (l: Int, r: Int, none: Int)] = [:]
        for slot in workout.exercises {
            guard let ex = slot.exercise else { continue }
            guard ex.symmetry == .unilateral else { continue }
            let key = "\(slot.exerciseId)|\(slot.category.rawValue)"
            var t = counts[key] ?? (0, 0, 0)
            switch slot.side {
            case .left:  t.l += 1
            case .right: t.r += 1
            case nil:    t.none += 1
            }
            counts[key] = t
        }
        for (key, t) in counts where t.l != t.r {
            return "\(key) — L=\(t.l) R=\(t.r) none=\(t.none)"
        }
        return nil
    }

    /// Confirms position blocks are monotonic within each category.
    /// "Monotonic" = once we leave a block, we don't re-enter it.
    /// E.g., standing → quadruped → standing is illegal because the
    /// user has to stand back up after getting on hands and knees.
    /// Returns the first transgression or nil. Per rules §2.1.
    static func validatePositionFlow(_ workout: WorkoutPreset) -> String? {
        let blockOrder: [ExercisePosition] = [
            .standing, .quadruped, .plank, .prone, .sideLying, .supine, .seated
        ]
        let blockIdx: [ExercisePosition: Int] = Dictionary(
            uniqueKeysWithValues: blockOrder.enumerated().map { ($1, $0) }
        )

        // Per rules §2.1, position-block ordering applies to the main
        // block only. Warmup + cooldown are mobility flows ordered by
        // area variety, not position monotonicity. Multi-round main
        // blocks legitimately replay the same exercises in Round 2+,
        // so each round is validated independently.
        let mainSlotsByRound = Dictionary(grouping: workout.exercises.filter { $0.category == .main },
                                          by: { $0.round })
        for round in mainSlotsByRound.keys.sorted() {
            guard let slots = mainSlotsByRound[round] else { continue }
            var lastSeenIdx = -1
            var visited: Set<Int> = []
            for slot in slots {
                guard let pos = slot.exercise?.position else { continue }
                let idx = blockIdx[pos] ?? -1
                if idx == lastSeenIdx { continue }   // same block, fine
                if visited.contains(idx) {
                    return "main round \(round): re-entered \(pos.rawValue) after leaving"
                }
                visited.insert(idx)
                lastSeenIdx = idx
            }
        }
        return nil
    }

    /// Confirms every main-block slot's exercise has difficulty within
    /// the user's tier window (see `minDifficulty` / `maxDifficulty`).
    /// Warmup and cooldown are exempt — they're mobility-only and the
    /// difficulty-2 cap on the warmup pool already gates them.
    /// Returns first violator or nil. Per rules §1.
    static func validateDifficultyBounds(_ workout: WorkoutPreset, tier: Int) -> String? {
        let lo = minDifficulty(tier: tier)
        let hi = maxDifficulty(tier: tier)
        for slot in workout.exercises where slot.category == .main {
            guard let ex = slot.exercise else { continue }
            if ex.difficulty < lo || ex.difficulty > hi {
                return "\(ex.id) difficulty=\(ex.difficulty) out of [\(lo)…\(hi)] for tier \(tier)"
            }
        }
        return nil
    }

    /// Confirms every main-block slot's duration is on the {30, 35, 40,
    /// 45, 50, 55, 60} grid. Off-grid durations would mean a
    /// snap-to-grid bug downstream. Per rules §3.
    static func validateDurationGrid(_ workout: WorkoutPreset) -> String? {
        let grid: Set<Int> = [30, 35, 40, 45, 50, 55, 60]
        for slot in workout.exercises where slot.category == .main {
            if !grid.contains(slot.duration) {
                return "\(slot.exerciseId) duration=\(slot.duration)s off grid"
            }
        }
        return nil
    }

    /// Confirms every main-block slot's rest is on the {5, 10, 15, 20}
    /// grid. Switch-side rests (the L→R hop on unilaterals) snap to
    /// the same grid via `snapRestToGrid`. Per rules §3.
    static func validateRestGrid(_ workout: WorkoutPreset) -> String? {
        let grid: Set<Int> = [5, 10, 15, 20]
        for slot in workout.exercises where slot.category == .main {
            if !grid.contains(slot.restAfter) {
                return "\(slot.exerciseId) rest=\(slot.restAfter)s off grid"
            }
        }
        return nil
    }

    // MARK: - Tier + Difficulty

    /// Use the input tier on cold start; once 3+ ratings exist, let user
    /// feedback nudge the tier up or down.
    private static func effectiveTier(input: Input) -> Int {
        var base = input.startingTier
        if input.recentRatings.count >= 3 {
            let recent = input.recentRatings.suffix(3)
            let avg = Double(recent.reduce(0, +)) / Double(recent.count)
            if avg >= 4.0 { base = min(3, input.startingTier + 1) }
            else if avg <= 2.5 { base = max(1, input.startingTier - 1) }
        }
        // Manual "today's energy" knob nudges the (rating-adjusted) tier ±1.
        return min(3, max(1, base + input.intensityOffset))
    }

    /// Tier 1 → ≤2, tier 2 → ≤4, tier 3 → ≤5 on the 1-5 scale.
    /// See `docs/workout_session_rules.md` §1 for the full table.
    private static func maxDifficulty(tier: Int) -> Int {
        switch tier {
        case ...1: return 2
        case 2:    return 4
        default:   return 5
        }
    }

    /// Tier 1 → ≥1, tier 2 → ≥2, tier 3 → ≥3 on the 1-5 scale. Floor
    /// prevents an advanced user from getting served foundational
    /// difficulty-1 filler when the bank has plenty of harder options.
    /// Mirror of `maxDifficulty`; together they bound each tier's pool.
    private static func minDifficulty(tier: Int) -> Int {
        switch tier {
        case ...1: return 1
        case 2:    return 2
        default:   return 3
        }
    }

    private static func difficulty(from tier: Int) -> WorkoutDifficulty {
        switch tier {
        case 1: return .beginner
        case 2: return .intermediate
        default: return .advanced
        }
    }

    // MARK: - Warmup

    private static func pickWarmup(
        count: Int,
        duration: Int,
        recent: Set<String>
    ) -> [ExerciseSlot] {
        guard count > 0 else { return [] }

        let pool = ExerciseBank.all.filter {
            $0.type == .mobility && $0.difficulty <= 2
        }

        var picked: [Exercise] = []
        var used: Set<String> = []
        var lastArea: TargetArea? = nil
        var emittedSlots = 0     // unilaterals consume 2 slots each

        while emittedSlots < count {
            let remaining = count - emittedSlots
            let candidate = pool
                .filter { ex in
                    !used.contains(ex.id) &&
                    // Skip unilaterals when there's no room to pair both sides.
                    !(ex.symmetry == .unilateral && remaining < 2)
                }
                .max { lhs, rhs in
                    score(warmup: lhs, lastArea: lastArea, recent: recent)
                    < score(warmup: rhs, lastArea: lastArea, recent: recent)
                }
            guard let next = candidate else { break }
            picked.append(next)
            used.insert(next.id)
            lastArea = next.primaryArea
            emittedSlots += (next.symmetry == .unilateral) ? 2 : 1
        }

        // flatMap so unilaterals emit BOTH .left and .right slots — no
        // more "only stretches the right hamstring" warmups.
        return picked.flatMap { ex -> [ExerciseSlot] in
            switch ex.symmetry {
            case .unilateral:
                return [
                    ExerciseSlot(exerciseId: ex.id, duration: duration, restAfter: 3, side: .left,  category: .warmup),
                    ExerciseSlot(exerciseId: ex.id, duration: duration, restAfter: 3, side: .right, category: .warmup),
                ]
            case .bilateral, .alternating:
                return [ExerciseSlot(exerciseId: ex.id, duration: duration, restAfter: 3, side: ex.defaultSide, category: .warmup)]
            }
        }
    }

    private static func score(warmup ex: Exercise, lastArea: TargetArea?, recent: Set<String>) -> Double {
        var s = 10.0
        if ex.primaryArea == lastArea { s -= 4 }
        if recent.contains(ex.id) { s -= 2 }
        // Slight preference for whole-body warmups (cat-cow, downward dog)
        if ex.targetAreas.contains(.fullBody) { s += 1 }
        s += Double.random(in: 0...0.5)
        return s
    }

    // MARK: - Main

    private static func pickMain(
        count: Int,
        primaryAreas: Set<TargetArea>,
        secondaryAreas: Set<TargetArea>,
        difficultyCap: Int,
        difficultyFloor: Int,
        tier: Int,
        goal: WorkoutGoal,
        lengthMinutes: Int,
        recent: Set<String>
    ) -> [ExerciseSlot] {
        guard count > 0 else { return [] }

        // Decide round structure first — long sessions repeat the same
        // unique block rather than picking 30+ distinct exercises. We
        // pick `uniqueCount` moves and emit them N rounds, totaling ≈
        // `count`. See docs/workout_session_rules.md §4.
        let roundCount = roundsForSession(lengthMinutes: lengthMinutes, totalSlots: count)
        // Picker target = unique slots per round. Emitting N rounds
        // multiplies it back up to ≈ count. Min of 4 unique so a
        // misconfigured threshold can't produce a 1-move round.
        let uniqueTarget = max(4, count / roundCount)

        // Pool eligibility = non-mobility AND difficulty inside the
        // tier window (floor + cap). Floor prevents advanced users from
        // seeing easy filler; cap prevents beginners from seeing hard
        // moves. See docs/workout_session_rules.md §1.
        //
        // Defensive: if the floor empties the pool (e.g., advanced user
        // with a niche bodyFocus that has only easy moves), fall back to
        // the cap-only filter. Beats showing an empty session.
        func filtered(targeting areas: Set<TargetArea>, withinPrimary: Bool) -> [Exercise] {
            ExerciseBank.all.filter { ex in
                ex.type != .mobility &&
                ex.difficulty <= difficultyCap &&
                ex.difficulty >= difficultyFloor &&
                !Set(ex.targetAreas).isDisjoint(with: areas) &&
                (withinPrimary || Set(ex.targetAreas).isDisjoint(with: primaryAreas))
            }
        }
        var primaryPool = filtered(targeting: primaryAreas, withinPrimary: true)
        if primaryPool.isEmpty {
            // Floor too restrictive — relax to cap only for primary.
            primaryPool = ExerciseBank.all.filter {
                $0.type != .mobility &&
                $0.difficulty <= difficultyCap &&
                !Set($0.targetAreas).isDisjoint(with: primaryAreas)
            }
        }
        let secondaryPool = filtered(targeting: secondaryAreas, withinPrimary: false)

        var selected: [Exercise] = []
        var used: Set<String> = []
        var emitted = 0

        // 70/30 split — every 10th slot is secondary. Loop hits
        // uniqueTarget so we end up with ~count/roundCount unique
        // exercises; the round emit loop later multiplies the slot
        // count back up.
        while emitted < uniqueTarget {
            let remaining = uniqueTarget - emitted
            let preferPrimary = Int.random(in: 1...10) <= 7
            let pool = preferPrimary ? primaryPool : secondaryPool
            let fallback = preferPrimary ? secondaryPool : primaryPool

            let chosen = pickNext(
                from: pool,
                fallback: fallback,
                selected: selected,
                used: used,
                recent: recent,
                emitted: emitted,
                total: uniqueTarget,
                remainingSlots: remaining
            )
            guard let exercise = chosen else { break }

            selected.append(exercise)
            used.insert(exercise.id)
            emitted += (exercise.symmetry == .unilateral) ? 2 : 1
        }

        // Selection is now done. Re-order by position block so the session
        // reads as standing → quadruped → plank → prone → side-lying →
        // supine → seated rather than a position-thrashing shuffle. This
        // is the Pamela Reif / growingannanas convention — minimize
        // up-down transitions, batch by body orientation.
        let ordered = orderByPositionBlock(selected)

        // Emit one round at a time so each slot carries the correct
        // round number. Rounds 2+ replay the same exercises, same
        // ordering — Pamela Reif's "and now repeat" structure (rules §4).
        var allSlots: [ExerciseSlot] = []
        for round in 1...roundCount {
            let roundSlots = emitMainSlots(
                ordered,
                tier: tier,
                goal: goal,
                lengthMinutes: lengthMinutes,
                round: round
            )
            allSlots.append(contentsOf: roundSlots)
        }
        return allSlots
    }

    /// Decide how many rounds to emit. Long sessions repeat the same
    /// 8-12 unique moves rather than picking 30+ unique exercises —
    /// reads as "Round 1 / Round 2" the way Pamela Reif structures her
    /// 10-min booty + arms routines. Threshold: sessions whose total
    /// slot budget is meaningfully larger than what an 8-move block
    /// can fill (15+ min) get 2 rounds; very long (30+ min) get 3.
    /// See docs/workout_session_rules.md §4.
    private static func roundsForSession(lengthMinutes: Int, totalSlots: Int) -> Int {
        // For repeat structure to feel like a Pamela Reif round, each
        // round needs ≥6 unique moves (smaller and it reads as filler).
        // We keep round count = 1 unless the session is long enough that
        // splitting still leaves a meaningful round size.
        switch lengthMinutes {
        case ..<15: return 1                  // ≤10 min: single pass, all unique
        case 15..<30: return totalSlots >= 12 ? 2 : 1
        default: return totalSlots >= 18 ? 3 : 2  // 30+ min: 2-3 rounds
        }
    }

    /// Movement-family inference. Derived from the exercise id rather
    /// than a new schema column so we don't have to re-emit the bank for
    /// this rule. The order of the substring checks matters — "side_lunge"
    /// must match "side_lunge" before falling through to "lunge".
    /// Per docs/workout_session_rules.md §4: clustering family members
    /// (squat → sumo squat → split squat → side lunge) reads as
    /// progressive variation, not a random shuffle.
    private static func family(of ex: Exercise) -> String {
        let id = ex.id
        // Prone / quadruped families
        if id.contains("donkey")          { return "donkey_kick" }
        if id.contains("fire_hydrant")    { return "fire_hydrant" }
        if id.contains("superman")        { return "superman" }
        if id.contains("bird_dog")        { return "bird_dog" }
        if id.contains("cat_") || id.contains("cow_") { return "cat_cow" }
        // Plank family — keep plank variants together (saw, jacks, run, frog…)
        if id.contains("plank")           { return "plank" }
        // Standing leg families
        if id.contains("sumo")            { return "sumo_squat" }
        if id.contains("squat")           { return "squat" }
        if id.contains("lunge")           { return "lunge" }
        if id.contains("calf")            { return "calf_raise" }
        if id.contains("burpee")          { return "burpee" }
        if id.contains("jump") || id.contains("jacks") { return "jumps" }
        if id.contains("kicks") || id.contains("knees") { return "cardio_steps" }
        // Glute family
        if id.contains("glute_bridge") || id.contains("hip_lift") { return "glute_bridge" }
        if id.contains("hip_abduction")   { return "hip_abduction" }
        if id.contains("good_morning") || id.contains("rdl") || id.contains("deadlift") {
            return "hinge"
        }
        // Core families
        if id.contains("bicycle") || id.contains("boat_bicycle") { return "bicycle" }
        if id.contains("v_up") || id.contains("sit_up")          { return "vup_situp" }
        if id.contains("flutter")                                 { return "flutter" }
        if id.contains("windshield")                              { return "windshield" }
        if id.contains("dead_bug")                                { return "dead_bug" }
        if id.contains("leg_raise") || id.contains("leg_lower")   { return "leg_raise" }
        if id.contains("crunch")                                  { return "crunch" }
        if id.contains("boat")                                    { return "boat" }
        if id.contains("tabletop")                                { return "tabletop" }
        if id.contains("side_bend") || id.contains("side_tilt")   { return "side_bend" }
        if id.contains("punch")                                   { return "punches" }
        // Upper-body raises
        if id.contains("raise") && (id.contains("w_") || id.contains("y_")) { return "rear_delt_raise" }
        if id.contains("dip")                                     { return "dip" }
        if id.contains("shoulder_tap")                            { return "shoulder_tap" }
        // Mobility / stretch families (used by warmup + cooldown)
        if id.contains("forward_fold") || id.contains("forward_bend") { return "forward_fold" }
        if id.contains("hamstring_stretch")                       { return "hamstring_stretch" }
        if id.contains("hip_flexor")                              { return "hip_flexor" }
        if id.contains("quad_stretch")                            { return "quad_stretch" }
        if id.contains("knee_to_chest") || id.contains("knee_hug") { return "knee_to_chest" }
        if id.contains("cobra") || id.contains("upward_dog") || id.contains("backbend") {
            return "extension"
        }
        if id.contains("downward_dog") || id.contains("puppy")    { return "downward_dog" }
        if id.contains("childs_pose")                             { return "childs_pose" }
        // Default — primary area as the family. Stable bucket so equal-area
        // moves still cluster, even if the family-keyword fallthrough missed.
        return "area_\(ex.primaryArea.rawValue)"
    }

    /// Position-block ordering with same-area secondary grouping.
    ///
    /// Sort priority (highest → lowest):
    ///   1. Position block — standing → quadruped → plank → prone →
    ///      side-lying → supine → seated. Hard constraint per
    ///      docs/workout_session_rules.md §2.1.
    ///   2. Same primary area within block — abs-plank moves cluster
    ///      together before shoulder-plank moves. Soft preference per §2.2.
    ///   3. Compound (≥2 target areas) before single-area.
    ///   4. Bilateral → alternating → unilateral.
    ///   5. Reps before holds (isometric finishers land last).
    ///   6. Stable fallback on original pick order.
    private static func orderByPositionBlock(_ exercises: [Exercise]) -> [Exercise] {
        let blockOrder: [ExercisePosition] = [
            .standing, .quadruped, .plank, .prone, .sideLying, .supine, .seated
        ]
        let blockIndex: [ExercisePosition: Int] = Dictionary(
            uniqueKeysWithValues: blockOrder.enumerated().map { ($1, $0) }
        )
        let symRank: (Symmetry) -> Int = { sym in
            switch sym {
            case .bilateral:   return 0
            case .alternating: return 1
            case .unilateral:  return 2
            }
        }
        // Stable per-area + per-family indices so the tie-breakers don't
        // flicker between renders. Built from the input order (which
        // carries the picker's intentional 70/30 primary/secondary
        // distribution + variety scoring).
        var firstAreaIndex: [TargetArea: Int] = [:]
        for (idx, ex) in exercises.enumerated() where firstAreaIndex[ex.primaryArea] == nil {
            firstAreaIndex[ex.primaryArea] = idx
        }
        var firstFamilyIndex: [String: Int] = [:]
        let exerciseFamily: [String: String] = Dictionary(
            uniqueKeysWithValues: exercises.map { ($0.id, family(of: $0)) }
        )
        for (idx, ex) in exercises.enumerated() {
            let fam = exerciseFamily[ex.id] ?? ""
            if firstFamilyIndex[fam] == nil {
                firstFamilyIndex[fam] = idx
            }
        }

        return exercises.enumerated().sorted { (lhs, rhs) -> Bool in
            let a = lhs.element, b = rhs.element
            let aBlock = blockIndex[a.position] ?? 99
            let bBlock = blockIndex[b.position] ?? 99
            if aBlock != bBlock { return aBlock < bBlock }

            // Same-area grouping — within the position block, cluster by
            // primaryArea so abs-plank moves come together before
            // shoulder-plank moves. Order between areas follows the area's
            // first appearance in the picked list (stable signal).
            if a.primaryArea != b.primaryArea {
                let aArea = firstAreaIndex[a.primaryArea] ?? Int.max
                let bArea = firstAreaIndex[b.primaryArea] ?? Int.max
                if aArea != bArea { return aArea < bArea }
            }

            // Same-family grouping — squat → sumo squat → split squat
            // reads as a progression rather than three random standing
            // moves. Lower priority than position + area; family is the
            // softest sort. See docs/workout_session_rules.md §4.
            let aFam = exerciseFamily[a.id] ?? ""
            let bFam = exerciseFamily[b.id] ?? ""
            if aFam != bFam {
                let aIdx = firstFamilyIndex[aFam] ?? Int.max
                let bIdx = firstFamilyIndex[bFam] ?? Int.max
                if aIdx != bIdx { return aIdx < bIdx }
            }

            // Compound (≥2 target areas) before single-area moves.
            let aCompound = a.targetAreas.count > 1
            let bCompound = b.targetAreas.count > 1
            if aCompound != bCompound { return aCompound }

            // Bilateral > alternating > unilateral within block.
            if symRank(a.symmetry) != symRank(b.symmetry) {
                return symRank(a.symmetry) < symRank(b.symmetry)
            }

            // Reps before holds — isometric finishers land naturally last.
            if a.pace != b.pace { return a.pace == .rep }

            // Stable fallback on original pick order.
            return lhs.offset < rhs.offset
        }.map { $0.element }
    }

    /// Walks the ordered list and emits slots. For a contiguous run of
    /// side-lying unilaterals, batches all left slots first, then all
    /// right — so the user lies on one side for the whole block instead
    /// of flipping every exercise. For other unilaterals, keeps the
    /// per-exercise L→R pattern (standing/quadruped switches are cheap).
    private static func emitMainSlots(
        _ ordered: [Exercise],
        tier: Int,
        goal: WorkoutGoal,
        lengthMinutes: Int,
        round: Int = 1
    ) -> [ExerciseSlot] {
        var result: [ExerciseSlot] = []
        var i = 0
        while i < ordered.count {
            let ex = ordered[i]

            if ex.position == .sideLying && ex.symmetry == .unilateral {
                // Find the contiguous run of side-lying unilaterals.
                var j = i
                while j < ordered.count,
                      ordered[j].position == .sideLying,
                      ordered[j].symmetry == .unilateral {
                    j += 1
                }
                let run = Array(ordered[i..<j])

                // All left slots first (all moves on one side), then flip.
                for (idx, runEx) in run.enumerated() {
                    let dur = mainDuration(for: runEx, tier: tier, goal: goal, lengthMinutes: lengthMinutes)
                    let rest = mainRest(tier: tier, exercise: runEx, goal: goal)
                    // Within the same side, intra-exercise rest is short;
                    // last-of-run (just before side flip) gets full rest.
                    let restAfter = (idx == run.count - 1) ? rest : max(5, snapRestToGrid(rest / 2))
                    result.append(ExerciseSlot(
                        exerciseId: runEx.id, duration: dur,
                        restAfter: restAfter, side: .left, category: .main, round: round
                    ))
                }
                for (idx, runEx) in run.enumerated() {
                    let dur = mainDuration(for: runEx, tier: tier, goal: goal, lengthMinutes: lengthMinutes)
                    let rest = mainRest(tier: tier, exercise: runEx, goal: goal)
                    let restAfter = (idx == run.count - 1) ? rest : max(5, snapRestToGrid(rest / 2))
                    result.append(ExerciseSlot(
                        exerciseId: runEx.id, duration: dur,
                        restAfter: restAfter, side: .right, category: .main, round: round
                    ))
                }
                i = j
            } else {
                let dur = mainDuration(for: ex, tier: tier, goal: goal, lengthMinutes: lengthMinutes)
                let rest = mainRest(tier: tier, exercise: ex, goal: goal)
                switch ex.symmetry {
                case .unilateral:
                    // Same-exercise L→R hop is "switch sides", not a full
                    // rest. Halve for the hop, full rest after R.
                    let switchRest = max(5, snapRestToGrid(rest / 2))
                    result.append(ExerciseSlot(exerciseId: ex.id, duration: dur, restAfter: switchRest, side: .left, category: .main, round: round))
                    result.append(ExerciseSlot(exerciseId: ex.id, duration: dur, restAfter: rest, side: .right, category: .main, round: round))
                case .bilateral, .alternating:
                    result.append(ExerciseSlot(exerciseId: ex.id, duration: dur, restAfter: rest, side: ex.defaultSide, category: .main, round: round))
                }
                i += 1
            }
        }
        return result
    }

    /// Goal- + tier- + exercise-aware rest after a main-block exercise.
    /// Range is the {5, 10, 15, 20} grid from
    /// docs/workout_session_rules.md §3.
    ///
    /// Layered offsets (each small — none dominates):
    ///   - **Goal base**: cardio (definition) short, strength long.
    ///   - **Tier offset**: fitter users recover faster.
    ///   - **Pace offset**: holds < reps (lower cardio load).
    ///   - **Exercise offset**: high-impact / cardio moves (jump squats,
    ///     burpees) get more rest; mobility / low-impact stretches get
    ///     less. Stacks with the others rather than replacing them.
    ///   - **Difficulty offset**: hard moves (4-5) get a small bump for
    ///     real recovery between work bouts.
    private static func mainRest(tier: Int, exercise: Exercise, goal: WorkoutGoal) -> Int {
        // Base rest by goal — sets the band before per-slot adjustments.
        let goalBase: Int
        switch goal {
        case .definition: goalBase = 10  // cardio-leaning, shorter rest
        case .fullCore:   goalBase = 12
        case .sculpting:  goalBase = 15
        case .strength:   goalBase = 18  // strength-leaning, longer rest
        }
        // Tier offset — fitter users tolerate shorter rest.
        let tierOffset: Int
        switch tier {
        case ...1: tierOffset = +3
        case 2:    tierOffset = 0
        default:   tierOffset = -3
        }
        // Hold offset — isometric work needs less recovery than reps.
        let paceOffset = (exercise.pace == .hold) ? -3 : 0
        // Per-exercise impact / type offset — the "stretch needs less,
        // jump squat needs more" mini factor. Small magnitudes so the
        // goal base still dominates the band.
        let exerciseOffset = exerciseRestOffset(exercise)
        let raw = goalBase + tierOffset + paceOffset + exerciseOffset
        return snapRestToGrid(raw)
    }

    /// Mini factor on top of the goal/tier/pace base. Adds rest for
    /// high-effort cardio bouts (burpees, jump squats — both .high
    /// impact AND .cardio type) and removes it for low-effort mobility
    /// (stretches, balance moves). Difficulty piggybacks: a difficulty-5
    /// move gets a small extra second beyond what its impact would
    /// suggest. Total offset capped at ±5s so this stays a tweak, not
    /// a dominant factor.
    private static func exerciseRestOffset(_ ex: Exercise) -> Int {
        var offset = 0

        // Impact band — the strongest of the three sub-signals.
        switch ex.impact {
        case .low:  offset -= 2
        case .med:  offset += 0
        case .high: offset += 3
        }

        // Type — mobility/balance moves coast; cardio + strength need
        // a touch more recovery beyond what impact alone captures.
        switch ex.type {
        case .mobility, .balance: offset -= 2
        case .core:               offset += 0
        case .strength:           offset += 1
        case .cardio:             offset += 1
        }

        // Difficulty — the hardest moves earn a tiny extra beat.
        if ex.difficulty >= 4 { offset += 1 }
        if ex.difficulty <= 2 { offset -= 1 }

        // Clamp so this stays a "mini factor" — the goal base + tier
        // should still drive most of the rest decision.
        return max(-5, min(5, offset))
    }

    /// Snap to {5, 10, 15, 20} so on-screen rest readouts match the
    /// rules grid. Sub-5 floors to 5; over-20 ceils to 20.
    private static func snapRestToGrid(_ seconds: Int) -> Int {
        let clamped = max(5, min(20, seconds))
        // Round to nearest 5.
        return Int((Double(clamped) / 5.0).rounded()) * 5
    }

    private static func pickNext(
        from pool: [Exercise],
        fallback: [Exercise],
        selected: [Exercise],
        used: Set<String>,
        recent: Set<String>,
        emitted: Int,
        total: Int,
        remainingSlots: Int
    ) -> Exercise? {
        let lastArea = selected.last?.primaryArea
        let lastPace = selected.last?.pace
        let curve = intensityCurve(index: emitted, total: total)
        let targetDifficulty = 1.0 + curve * 4.0   // map [0..1] → [1..5]

        func scored(_ candidates: [Exercise]) -> [(Exercise, Double)] {
            candidates
                .filter { ex in
                    !used.contains(ex.id) &&
                    !(ex.symmetry == .unilateral && remainingSlots < 2)
                }
                .map { ex -> (Exercise, Double) in
                    var s = 10.0
                    if ex.primaryArea == lastArea { s -= 8 }
                    if ex.pace == lastPace { s -= 2 }
                    s -= abs(Double(ex.difficulty) - targetDifficulty)
                    if recent.contains(ex.id) { s -= 3 }
                    return (ex, s)
                }
        }

        let primaryScored = scored(pool)
        if let best = bestRandomTopTier(primaryScored) { return best }

        let fallbackScored = scored(fallback)
        if let best = bestRandomTopTier(fallbackScored) { return best }

        // Last-resort: any unused, slot-fitting exercise (covers very small
        // pools or edge case where every primary is recently-used).
        return pool.first { ex in
            !used.contains(ex.id) &&
            !(ex.symmetry == .unilateral && remainingSlots < 2)
        }
    }

    private static func bestRandomTopTier(_ scored: [(Exercise, Double)]) -> Exercise? {
        guard !scored.isEmpty else { return nil }
        let sorted = scored.sorted { $0.1 > $1.1 }
        let top = sorted.first!.1
        let candidates = sorted.filter { $0.1 >= top - 1.0 }
        return candidates.randomElement()?.0
    }

    /// Bell-shaped curve peaking at ~40% of the session, range [0.2, 1.0].
    private static func intensityCurve(index: Int, total: Int) -> Double {
        guard total > 1 else { return 0.5 }
        let normalized = Double(index) / Double(total - 1)
        let peak = 0.4
        let spread = 0.3
        let intensity = exp(-pow(normalized - peak, 2) / (2 * spread * spread))
        return intensity * 0.8 + 0.2
    }

    /// Per-slot duration on the {30, 35, 40, 45, 50, 55, 60} grid from
    /// docs/workout_session_rules.md §3. Inputs:
    ///   - exercise's authored default (research-grounded baseline)
    ///   - tier (fitter users tolerate longer holds + reps)
    ///   - session length (long sessions favor longer slots so 40-min
    ///     workouts don't end up with 60+ moves)
    ///   - exercise pace (holds shorter than reps at same difficulty)
    private static func mainDuration(
        for ex: Exercise,
        tier: Int,
        goal: WorkoutGoal,
        lengthMinutes: Int
    ) -> Int {
        // Start from the authored default (already a grid-friendly 30-60).
        var dur = ex.defaultDurationSec

        // Tier offset — fitter users get longer slots.
        switch tier {
        case ...1: dur += 0
        case 2:    dur += 5
        default:   dur += 10
        }

        // Session-length bias — long sessions favor 50-60s, short
        // sessions stick around 30-40s. Threshold at 15 min: under
        // that, no upward pressure; over that, +5; over 30 min, +10.
        if lengthMinutes >= 30 {
            dur += 10
        } else if lengthMinutes >= 15 {
            dur += 5
        }

        // Pace offset — holds shorter than reps at same difficulty.
        if ex.pace == .hold {
            dur -= 5
        }

        return snapDurationToGrid(dur)
    }

    /// Snap to {30, 35, 40, 45, 50, 55, 60}. Sub-30 floors to 30;
    /// over-60 ceils to 60. Round-to-nearest-5 in between.
    private static func snapDurationToGrid(_ seconds: Int) -> Int {
        let clamped = max(30, min(60, seconds))
        return Int((Double(clamped) / 5.0).rounded()) * 5
    }

    // MARK: - Cooldown

    private static func pickCooldown(
        count: Int,
        duration: Int,
        recent: Set<String>,
        preferAreas: Set<TargetArea>
    ) -> [ExerciseSlot] {
        guard count > 0 else { return [] }

        let pool = ExerciseBank.all.filter {
            $0.type == .mobility && $0.pace == .hold
        }

        var picked: [Exercise] = []
        var used: Set<String> = []
        var lastArea: TargetArea? = nil
        var emittedSlots = 0     // unilaterals consume 2 slots each

        while emittedSlots < count {
            let remaining = count - emittedSlots
            let candidate = pool
                .filter { ex in
                    !used.contains(ex.id) &&
                    !(ex.symmetry == .unilateral && remaining < 2)
                }
                .max { lhs, rhs in
                    score(cooldown: lhs, lastArea: lastArea, recent: recent, preferAreas: preferAreas)
                    < score(cooldown: rhs, lastArea: lastArea, recent: recent, preferAreas: preferAreas)
                }
            guard let next = candidate else { break }
            picked.append(next)
            used.insert(next.id)
            lastArea = next.primaryArea
            emittedSlots += (next.symmetry == .unilateral) ? 2 : 1
        }

        // Order by anatomical/position flow before emitting slots — same
        // helper the dedicated stretch session uses, so warmup work flows
        // top-down into the wind-down (standing → seated → supine).
        let ordered = orderStretchAnatomically(picked)

        // flatMap so unilateral stretches (lying hamstring, deep hip
        // flexor, etc.) emit BOTH sides — asymmetric flexibility is a
        // real injury risk; the previous .map only stretched one side.
        return ordered.flatMap { ex -> [ExerciseSlot] in
            switch ex.symmetry {
            case .unilateral:
                return [
                    ExerciseSlot(exerciseId: ex.id, duration: duration, restAfter: 3, side: .left,  category: .cooldown),
                    ExerciseSlot(exerciseId: ex.id, duration: duration, restAfter: 3, side: .right, category: .cooldown),
                ]
            case .bilateral, .alternating:
                return [ExerciseSlot(exerciseId: ex.id, duration: duration, restAfter: 3, side: ex.defaultSide, category: .cooldown)]
            }
        }
    }

    private static func score(
        cooldown ex: Exercise,
        lastArea: TargetArea?,
        recent: Set<String>,
        preferAreas: Set<TargetArea>
    ) -> Double {
        var s = 10.0
        if ex.primaryArea == lastArea { s -= 3 }
        if recent.contains(ex.id) { s -= 1 }
        // Stretch what was trained: if exercise targets one of the trained
        // areas, prefer it strongly.
        if !Set(ex.targetAreas).isDisjoint(with:preferAreas) { s += 4 }
        s += Double.random(in: 0...0.5)
        return s
    }

    // MARK: - Naming

    private static func generatedName(for focus: [BodyFocus]) -> String {
        // Post-Ozempic vocabulary pass (2026-06-11): the old pool leaned
        // on 2010s diet-culture labor verbs (Burn / Pump / Full Send).
        // Names read as outcomes and rituals now, never as labor.
        if focus.count > 1 { return "Custom Mix" }
        switch focus.first ?? .fullBody {
        case .flatBelly: return ["Core Reset", "Center Hold", "Quiet Core"].randomElement()!
        case .tonedArms: return ["Toned Arms", "Upper Glow", "Carry Easy"].randomElement()!
        case .roundButt: return ["Round & Strong", "The Curve", "Glute Foundations"].randomElement()!
        case .slimLegs:  return ["Lean Legs", "Long & Strong", "Light Legs"].randomElement()!
        case .fullBody:  return ["Move Everything", "Total Reset", "All of You"].randomElement()!
        }
    }

    /// Best-fit legacy `WorkoutGoal` for any code paths still tagging by it.
    /// Phase 4b will retire this once preset categorization is bodyFocus-native.
    private static func legacyGoal(for focus: [BodyFocus]) -> WorkoutGoal {
        if focus.contains(.flatBelly) { return .definition }
        if focus.contains(.fullBody) { return .fullCore }
        if focus.contains(.roundButt) || focus.contains(.slimLegs) { return .sculpting }
        return .strength
    }

    // MARK: - Stretch / Recovery session
    //
    // Mobility-only session — no warmup/main split, every slot is a held
    // stretch. Sized by `lengthMinutes`; stratifies across body parts so
    // the user moves through neck/shoulders/back/hips/legs rather than
    // hammering one area.

    static func generateStretchSession(lengthMinutes: Int) -> WorkoutPreset {
        let perMoveSec = 30
        let restSec = 3
        let totalBudgetSec = lengthMinutes * 60
        let approxCount = max(4, totalBudgetSec / (perMoveSec + restSec))

        let pool = ExerciseBank.all.filter { $0.type == .mobility }
        var selected: [Exercise] = []
        var used: Set<String> = []
        var lastArea: TargetArea? = nil
        var emitted = 0

        while emitted < approxCount {
            let remaining = approxCount - emitted
            let candidates = pool
                .filter { ex in
                    !used.contains(ex.id) &&
                    !(ex.symmetry == .unilateral && remaining < 2)
                }
                .map { ex -> (Exercise, Double) in
                    var s = 10.0
                    if ex.primaryArea == lastArea { s -= 6 }
                    s += Double.random(in: 0...0.5)
                    return (ex, s)
                }
                .sorted { $0.1 > $1.1 }

            guard let pick = candidates.first?.0 else { break }
            selected.append(pick)
            used.insert(pick.id)
            lastArea = pick.primaryArea
            emitted += (pick.symmetry == .unilateral) ? 2 : 1
        }

        // Anatomical top-down ordering: standing/dynamic first (warm the
        // body), seated/floor stretches in the middle, supine relaxers
        // last (wind-down). Within position, sort by body region head →
        // toe so the user feels the flow rather than a random scramble.
        let ordered = orderStretchAnatomically(selected)

        let slots = ordered.flatMap { ex -> [ExerciseSlot] in
            switch ex.symmetry {
            case .unilateral:
                return [
                    ExerciseSlot(exerciseId: ex.id, duration: perMoveSec, restAfter: restSec, side: .left, category: .main),
                    ExerciseSlot(exerciseId: ex.id, duration: perMoveSec, restAfter: restSec, side: .right, category: .main),
                ]
            case .bilateral, .alternating:
                return [ExerciseSlot(exerciseId: ex.id, duration: perMoveSec, restAfter: restSec, category: .main)]
            }
        }

        return WorkoutPreset(
            id: "gen_stretch_\(UUID().uuidString.prefix(8))",
            name: "Stretch & Recover",
            description: nil,
            goal: .fullCore,
            difficulty: .beginner,
            exercises: slots,
            estimatedDuration: lengthMinutes,
            isGenerated: true
        )
    }

    /// Stretch-session ordering: position blocks (standing → seated →
    /// supine) front-load active mobility and end on wind-down lying
    /// stretches; within a block, head-to-toe by body region so the
    /// session reads as a coherent flow.
    private static func orderStretchAnatomically(_ exercises: [Exercise]) -> [Exercise] {
        // Block order tuned for stretch flow (different from main: seated
        // before supine since seated stretches transition into the floor;
        // supine is the wind-down). Plank/prone are uncommon for mobility
        // but ordered logically if present.
        let blockOrder: [ExercisePosition] = [
            .standing, .quadruped, .plank, .prone, .sideLying, .seated, .supine
        ]
        let blockIndex: [ExercisePosition: Int] = Dictionary(
            uniqueKeysWithValues: blockOrder.enumerated().map { ($1, $0) }
        )
        // Anatomical rank: head → toe.
        let regionRank: (TargetArea) -> Int = { area in
            switch area {
            case .upperBody:    return 0  // neck, shoulders, arms
            case .fullBody:     return 1  // spine, whole-body openers
            case .lowerBack:    return 2
            case .abs:          return 3
            case .obliques:     return 4
            case .glutes:       return 5
            case .hipFlexors:   return 6
            case .hamstrings:   return 7
            case .quads:        return 8
            case .calves:       return 9
            }
        }
        return exercises.enumerated().sorted { (lhs, rhs) -> Bool in
            let a = lhs.element, b = rhs.element
            let aBlock = blockIndex[a.position] ?? 99
            let bBlock = blockIndex[b.position] ?? 99
            if aBlock != bBlock { return aBlock < bBlock }
            let aRank = regionRank(a.primaryArea)
            let bRank = regionRank(b.primaryArea)
            if aRank != bRank { return aRank < bRank }
            return lhs.offset < rhs.offset
        }.map { $0.element }
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
        if experience == "never" || experience == "gaveUp" { return 1 }

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

        if ageRange == "55plus" || ageRange == "under18" { score -= 1 }

        if score >= 3 { return 3 }
        if score >= 1 { return 2 }
        return 1
    }

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

    /// Derive the starting-strength seed (`baselineSeconds`) from the
    /// onboarding movement-fit answer (case 8, `movementBaseline`) rather
    /// than an explicit plank-hold question. The "how long can you hold a
    /// plank?" screen was cut (it read as a workout-app tell to the
    /// diet-first cohort), so the difficulty engine now reads a strength
    /// proxy off how movement already fits the user's life. Movement
    /// frequency is a sound, low-friction proxy for baseline core
    /// endurance. Keys map to the case-8 option keys.
    static func baselineSeconds(forMovementBaseline movement: String) -> Int {
        switch movement {
        case "barely":      return 20
        case "walks":       return 30
        case "regular_ish": return 45
        case "very_active": return 60
        default:            return 20
        }
    }
}
