import Foundation

// MARK: - Goal

enum WorkoutGoal: String, Codable, CaseIterable {
    case strength
    case definition
    case sculpting
    case fullCore
}

// MARK: - Difficulty

enum WorkoutDifficulty: String, Codable {
    case beginner
    case intermediate
    case advanced
}

// MARK: - Exercise Slot

struct ExerciseSlot: Equatable {
    let exerciseId: String
    let duration: Int      // override, seconds
    let restAfter: Int     // override, seconds
    /// For unilateral exercises, the engine emits two slots (one per side).
    /// `nil` for bilateral / alternating exercises.
    var side: Side? = nil
    /// Where this slot sits in the session: warmup / main / cooldown.
    /// Existing presets default to `.main`; the generator labels each slot
    /// according to `SessionStructure`.
    var category: ExerciseCategory = .main
    /// Round number for repeat-pattern sessions (Pamela Reif convention,
    /// see docs/workout_session_rules.md §4). 1 for normal sessions and
    /// for the first pass of a 2-round session; 2 for the second pass.
    /// Used by PreRoutineView to insert "Round N" dividers and by the
    /// session view to show progress within the round.
    var round: Int = 1

    var exercise: Exercise? {
        ExerciseBank.exercise(id: exerciseId)
    }

    /// Pre-resolved rendering (handles mirroring of unilateral exercises).
    var rendering: ExerciseRendering? {
        guard let exercise else { return nil }
        return ExerciseMirror.rendering(for: exercise, side: side)
    }
}

// MARK: - Workout Preset

struct WorkoutPreset: Identifiable, Equatable {
    let id: String
    let name: String
    /// One-line tagline used on the workout card + plan reveal. Kept
    /// optional so legacy generated presets that don't author copy
    /// don't have to set it. JeniFit voice: aspirational, direct, no AI.
    var description: String? = nil
    let goal: WorkoutGoal
    let difficulty: WorkoutDifficulty
    let exercises: [ExerciseSlot]
    let estimatedDuration: Int   // minutes
    let isGenerated: Bool

    static func == (lhs: WorkoutPreset, rhs: WorkoutPreset) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 20 Hand-Designed Presets

extension WorkoutPreset {

    // MARK: Core Strength (5)

    static let strength1 = WorkoutPreset(
        id: "strength_1",
        name: "Iron Core",
        description: "Anti-rotation core work that locks in posture and power. Built for strength that holds up everywhere else.",
        goal: .strength,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "boat_flutters", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_hold", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "side_plank", duration: 30, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "tabletop_hold_knee_lift", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "leg_raise", duration: 40, restAfter: 10),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let strength2 = WorkoutPreset(
        id: "strength_2",
        name: "Locked In",
        description: "Advanced isometric holds and rotational stability. Your most committed core work yet.",
        goal: .strength,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "kneeling_shoulder_tap", duration: 45, restAfter: 15),
            ExerciseSlot(exerciseId: "v_up", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank", duration: 40, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "alternating_superman", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 40, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "boat_flutters", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "tabletop_hold_knee_lift", duration: 45, restAfter: 15),
        ],
        estimatedDuration: 8,
        isGenerated: false
    )

    static let strength3 = WorkoutPreset(
        id: "strength_3",
        name: "Core Foundations",
        description: "Two weeks to dial in the basics. Build the base everything else stacks on.",
        goal: .strength,
        difficulty: .beginner,
        exercises: [
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "kneeling_shoulder_tap", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "superman_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "tabletop_hold_knee_lift", duration: 30, restAfter: 15),
        ],
        estimatedDuration: 5,
        isGenerated: false
    )

    static let strength4 = WorkoutPreset(
        id: "strength_4",
        name: "Hold the Line",
        description: "Endurance-led plank progressions. Train the slow burn that pays off in every other workout.",
        goal: .strength,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "tabletop_hold_knee_lift", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 35, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "glute_bridge_march", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 35, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "boat_flutters", duration: 35, restAfter: 15),
            ExerciseSlot(exerciseId: "superman_hold", duration: 40, restAfter: 10),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let strength5 = WorkoutPreset(
        id: "strength_5",
        name: "Pure Power",
        description: "Advanced full-tension training. The library's heaviest work — go when you're ready.",
        goal: .strength,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "boat_flutters", duration: 45, restAfter: 15),
            ExerciseSlot(exerciseId: "boat_bicycle", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "alternating_superman", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "v_up", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "tabletop_hold_knee_lift", duration: 45, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank", duration: 40, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 40, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "kneeling_shoulder_tap", duration: 45, restAfter: 15),
        ],
        estimatedDuration: 10,
        isGenerated: false
    )

    // MARK: Abs Definition (5)

    static let definition1 = WorkoutPreset(
        id: "definition_1",
        name: "Flat Belly Focus",
        description: "Cardio + core work that hits the abs from every angle. Direct route to definition.",
        goal: .definition,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "bicycle_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "leg_raise", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "cocoon_crunch", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let definition2 = WorkoutPreset(
        id: "definition_2",
        name: "Flat Belly Reset",
        description: "A two-week core reset for re-entry days. Gentle re-engagement, no shame.",
        goal: .definition,
        difficulty: .beginner,
        exercises: [
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "glute_bridge", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "reverse_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 5,
        isGenerated: false
    )

    static let definition3 = WorkoutPreset(
        id: "definition_3",
        name: "Become Her",
        description: "The signature transformation routine. Sculpt every zone with progressive daily work.",
        goal: .definition,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "v_up", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "leg_raise", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "alternating_superman", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bicycle_crunch", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "boat_bicycle", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "boat_flutters", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "cocoon_crunch", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 9,
        isGenerated: false
    )

    static let definition4 = WorkoutPreset(
        id: "definition_4",
        name: "Tight & Toned",
        description: "Three weeks to a tighter, leaner, more confident you. Fast-paced and full of payoff.",
        goal: .definition,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "reverse_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "cocoon_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 30, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .right),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let definition5 = WorkoutPreset(
        id: "definition_5",
        name: "Lower Belly Reset",
        description: "Targeted lower-ab work. The zone everyone asks about — handled.",
        goal: .definition,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "leg_raise", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "reverse_crunch", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge_march", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 30, restAfter: 15),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    // MARK: Waist Sculpting (5)

    static let sculpting1 = WorkoutPreset(
        id: "sculpting_1",
        name: "Sweat & Sculpt",
        description: "HIIT-style core that doubles as cardio. Heat in, definition out.",
        goal: .sculpting,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 35, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "superman_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 35, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "downward_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .right),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let sculpting2 = WorkoutPreset(
        id: "sculpting_2",
        name: "Waist Reset",
        description: "Two weeks of oblique-led toning. Smooth lines, narrower waist.",
        goal: .sculpting,
        difficulty: .beginner,
        exercises: [
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "glute_bridge", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 5,
        isGenerated: false
    )

    static let sculpting3 = WorkoutPreset(
        id: "sculpting_3",
        name: "Sculpt the Curve",
        description: "Advanced rotation + isolation work. Build the silhouette you want.",
        goal: .sculpting,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "boat_bicycle", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "boat_flutters", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank", duration: 40, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 40, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "alternating_superman", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .right),
        ],
        estimatedDuration: 9,
        isGenerated: false
    )

    static let sculpting4 = WorkoutPreset(
        id: "sculpting_4",
        name: "Twist & Tone",
        description: "Rotational flow that defines the obliques. Move through every angle.",
        goal: .sculpting,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bicycle_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 30, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "boat_bicycle", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "kneeling_shoulder_tap", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 6,
        isGenerated: false
    )

    static let sculpting5 = WorkoutPreset(
        id: "sculpting_5",
        name: "Glow Up",
        description: "Advanced sculpt sessions with a finisher kick. The full-body before/after.",
        goal: .sculpting,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "boat_bicycle", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "leg_raise", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 45, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "alternating_superman", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 45, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "tabletop_hold_knee_lift", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "v_up", duration: 30, restAfter: 15),
        ],
        estimatedDuration: 10,
        isGenerated: false
    )

    // MARK: Full Core (5)

    static let fullCore1 = WorkoutPreset(
        id: "full_core_1",
        name: "Body Reset",
        description: "Three weeks to re-anchor your routine. Balanced, sustainable, undefeated.",
        goal: .fullCore,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bicycle_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "side_plank", duration: 30, restAfter: 10, side: .right),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let fullCore2 = WorkoutPreset(
        id: "full_core_2",
        name: "Pilates Princess",
        description: "Pilates-inspired flow with no equipment needed. Long lines, controlled work.",
        goal: .fullCore,
        difficulty: .beginner,
        exercises: [
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_crunch", duration: 30, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "glute_bridge", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "cocoon_crunch", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 5,
        isGenerated: false
    )

    static let fullCore3 = WorkoutPreset(
        id: "full_core_3",
        name: "Total Sculpt",
        description: "Advanced full-body sculpt. Hits every zone, leaves nothing behind.",
        goal: .fullCore,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "boat_flutters", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "boat_bicycle", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "alternating_superman", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "v_up", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank", duration: 40, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 40, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "leg_raise", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "tabletop_hold_knee_lift", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "kneeling_shoulder_tap", duration: 40, restAfter: 10),
        ],
        estimatedDuration: 10,
        isGenerated: false
    )

    static let fullCore4 = WorkoutPreset(
        id: "full_core_4",
        name: "Lazy Girl Routine",
        description: "Low-key but consistent. The bare minimum that still moves the needle.",
        goal: .fullCore,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bicycle_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge_march", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "windshield_wipers", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "downward_dog", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 6,
        isGenerated: false
    )

    static let fullCore5 = WorkoutPreset(
        id: "full_core_5",
        name: "The Gauntlet",
        description: "Ten exercises, advanced throughout. The library's most demanding session.",
        goal: .fullCore,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank", duration: 40, restAfter: 10, side: .left),
            ExerciseSlot(exerciseId: "v_up", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank", duration: 40, restAfter: 10, side: .right),
            ExerciseSlot(exerciseId: "alternating_superman", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "boat_flutters", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "boat_bicycle", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "tabletop_hold_knee_lift", duration: 45, restAfter: 15),
            ExerciseSlot(exerciseId: "leg_raise", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "kneeling_shoulder_tap", duration: 45, restAfter: 10),
        ],
        estimatedDuration: 10,
        isGenerated: false
    )

    // MARK: Phase 4b — Body-area presets (added 2026-05-07)
    //
    // The original 20 presets are core-focused (carry-over from when the
    // bank was abs/plank only). Phase 4b expands coverage to glutes,
    // upper body, lower body, and a full-body cardio mix — using the
    // 128-exercise bank and the position-block ordering convention. Each
    // preset's slot list is written in standing → quadruped → plank →
    // prone → side-lying → supine → seated order so the fallback
    // experience matches what the generator now emits.

    /// Glutes — standing → quadruped (donkey kick / fire hydrant pairs)
    /// → supine (single-leg + bilateral bridges). Mid-difficulty so the
    /// fallback hits day-1 users in the right zone for "round butt" focus.
    static let glutes1 = WorkoutPreset(
        id: "glutes_1",
        name: "Lift & Lengthen",
        description: "Posterior-chain shaping that posture loves. Build the curve through every angle.",
        goal: .sculpting,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "standing_hip_abduction", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "donkey_kick", duration: 30, restAfter: 5, side: .left),
            ExerciseSlot(exerciseId: "donkey_kick", duration: 30, restAfter: 12, side: .right),
            ExerciseSlot(exerciseId: "fire_hydrant", duration: 30, restAfter: 5, side: .left),
            ExerciseSlot(exerciseId: "fire_hydrant", duration: 30, restAfter: 12, side: .right),
            ExerciseSlot(exerciseId: "glute_bridge", duration: 40, restAfter: 12),
            ExerciseSlot(exerciseId: "single_leg_glute_bridge", duration: 30, restAfter: 5, side: .left),
            ExerciseSlot(exerciseId: "single_leg_glute_bridge", duration: 30, restAfter: 12, side: .right),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    /// Upper body — quadruped → plank → prone → seated. Hits shoulders,
    /// arms, and posterior delts via plank variants and back raises. No
    /// pushup-volume so beginners with weaker upper body still finish it.
    static let upper1 = WorkoutPreset(
        id: "upper_1",
        name: "Strong Arms",
        description: "Shoulders, arms, posture. The upper-body work most home routines skip.",
        goal: .fullCore,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "kneeling_shoulder_tap", duration: 35, restAfter: 12),
            ExerciseSlot(exerciseId: "plank_saw", duration: 30, restAfter: 12),
            ExerciseSlot(exerciseId: "plank_jacks", duration: 30, restAfter: 12),
            ExerciseSlot(exerciseId: "w_raise", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "y_raise", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "floor_dip", duration: 35, restAfter: 12),
        ],
        estimatedDuration: 6,
        isGenerated: false
    )

    /// Lower body — standing block (squats + side lunge) into one supine
    /// glute bridge to round out the posterior chain. All bilateral or
    /// alternating except side_lunge, which is paired L/R.
    static let lower1 = WorkoutPreset(
        id: "lower_1",
        name: "Long Legs",
        description: "Squats, lunges, calves. Lean lines through the lower body.",
        goal: .sculpting,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "air_squat", duration: 35, restAfter: 12),
            ExerciseSlot(exerciseId: "sumo_squat", duration: 35, restAfter: 12),
            ExerciseSlot(exerciseId: "side_lunge", duration: 30, restAfter: 5, side: .left),
            ExerciseSlot(exerciseId: "side_lunge", duration: 30, restAfter: 12, side: .right),
            ExerciseSlot(exerciseId: "calf_raise", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge", duration: 40, restAfter: 10),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    /// Full-body cardio mix — beginner-friendly, low-equipment-feel. Six
    /// exercises in standing → plank → supine flow; reads as "move
    /// everything" rather than a core grind.
    static let fullBody1 = WorkoutPreset(
        id: "full_body_1",
        name: "Move Everything",
        description: "Cardio + strength in one quick lap. Wake the whole body up.",
        goal: .fullCore,
        difficulty: .beginner,
        exercises: [
            ExerciseSlot(exerciseId: "jumping_jacks", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "high_knees", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "butt_kicks", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 30, restAfter: 12),
            ExerciseSlot(exerciseId: "plank_jacks", duration: 30, restAfter: 12),
            ExerciseSlot(exerciseId: "glute_bridge", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 6,
        isGenerated: false
    )
}

// MARK: - All Presets

extension WorkoutPreset {

    static let allPresets: [WorkoutPreset] = [
        // Strength
        .strength1, .strength2, .strength3, .strength4, .strength5,
        // Definition
        .definition1, .definition2, .definition3, .definition4, .definition5,
        // Sculpting (incl. Phase 4b body-area additions: glutes, lower body)
        .sculpting1, .sculpting2, .sculpting3, .sculpting4, .sculpting5,
        .glutes1, .lower1,
        // Full Core (incl. Phase 4b body-area additions: upper body, full body)
        .fullCore1, .fullCore2, .fullCore3, .fullCore4, .fullCore5,
        .upper1, .fullBody1,
    ]

    static func presets(for goal: WorkoutGoal) -> [WorkoutPreset] {
        allPresets.filter { $0.goal == goal }
    }
}
