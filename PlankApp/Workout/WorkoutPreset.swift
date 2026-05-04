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

    var exercise: Exercise? {
        ExerciseBank.exercise(id: exerciseId)
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
        name: "21 Days · Iron Core",
        description: "Anti-rotation core work that locks in posture and power. Built for strength that holds up everywhere else.",
        goal: .strength,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "hollow_body_hold", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "russian_twists", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_hold", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bear_crawl_hold", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "leg_raises", duration: 40, restAfter: 10),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let strength2 = WorkoutPreset(
        id: "strength_2",
        name: "30 Days · Locked In",
        description: "Advanced isometric holds and rotational stability. Your most committed core work yet.",
        goal: .strength,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "plank_shoulder_taps", duration: 45, restAfter: 15),
            ExerciseSlot(exerciseId: "v_ups", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_pulses", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "hollow_body_hold", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "bear_crawl_hold", duration: 45, restAfter: 15),
        ],
        estimatedDuration: 8,
        isGenerated: false
    )

    static let strength3 = WorkoutPreset(
        id: "strength_3",
        name: "14 Days · Core Foundations",
        description: "Two weeks to dial in the basics. Build the base everything else stacks on.",
        goal: .strength,
        difficulty: .beginner,
        exercises: [
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "plank_shoulder_taps", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "superman_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bear_crawl_hold", duration: 30, restAfter: 15),
        ],
        estimatedDuration: 5,
        isGenerated: false
    )

    static let strength4 = WorkoutPreset(
        id: "strength_4",
        name: "21 Days · Hold the Line",
        description: "Endurance-led plank progressions. Train the slow burn that pays off in every other workout.",
        goal: .strength,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "bear_crawl_hold", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 35, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge_marches", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 35, restAfter: 10),
            ExerciseSlot(exerciseId: "hollow_body_hold", duration: 35, restAfter: 15),
            ExerciseSlot(exerciseId: "superman_hold", duration: 40, restAfter: 10),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let strength5 = WorkoutPreset(
        id: "strength_5",
        name: "30 Days · Pure Power",
        description: "Advanced full-tension training. The library's heaviest work — go when you're ready.",
        goal: .strength,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "hollow_body_hold", duration: 45, restAfter: 15),
            ExerciseSlot(exerciseId: "woodchoppers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_pulses", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "v_ups", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "bear_crawl_hold", duration: 45, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "plank_shoulder_taps", duration: 45, restAfter: 15),
        ],
        estimatedDuration: 10,
        isGenerated: false
    )

    // MARK: Abs Definition (5)

    static let definition1 = WorkoutPreset(
        id: "definition_1",
        name: "21 Days · Flat Belly Burn",
        description: "Sweaty cardio + core work that hits the abs from every angle. Direct route to definition.",
        goal: .definition,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "bicycle_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "russian_twists", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "leg_raises", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_right", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "toe_touches", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let definition2 = WorkoutPreset(
        id: "definition_2",
        name: "14 Days · Flat Belly Reset",
        description: "A two-week core reset for re-entry days. Gentle re-engagement, no shame.",
        goal: .definition,
        difficulty: .beginner,
        exercises: [
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_right", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "reverse_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 5,
        isGenerated: false
    )

    static let definition3 = WorkoutPreset(
        id: "definition_3",
        name: "30 Days · Become Her",
        description: "The signature transformation routine. Sculpt every zone with progressive daily work.",
        goal: .definition,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "v_ups", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "russian_twists", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "leg_raises", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_pulses", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bicycle_crunch", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "woodchoppers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "hollow_body_hold", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "toe_touches", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 9,
        isGenerated: false
    )

    static let definition4 = WorkoutPreset(
        id: "definition_4",
        name: "21 Days · Tight & Toned",
        description: "Three weeks to a tighter, leaner, more confident you. Fast-paced and full of payoff.",
        goal: .definition,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "reverse_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "toe_touches", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_right", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let definition5 = WorkoutPreset(
        id: "definition_5",
        name: "14 Days · Lower Belly Reset",
        description: "Targeted lower-ab work. The zone everyone asks about — handled.",
        goal: .definition,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "leg_raises", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "russian_twists", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "reverse_crunch", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge_marches", duration: 30, restAfter: 10),
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
        name: "21 Days · Sweat & Sculpt",
        description: "HIIT-style core that doubles as cardio. Heat in, definition out.",
        goal: .sculpting,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "russian_twists", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 35, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 35, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "inchworms", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_right", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let sculpting2 = WorkoutPreset(
        id: "sculpting_2",
        name: "14 Days · Waist Reset",
        description: "Two weeks of oblique-led toning. Smooth lines, narrower waist.",
        goal: .sculpting,
        difficulty: .beginner,
        exercises: [
            ExerciseSlot(exerciseId: "oblique_crunch_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_right", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "russian_twists", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 5,
        isGenerated: false
    )

    static let sculpting3 = WorkoutPreset(
        id: "sculpting_3",
        name: "30 Days · Sculpt the Curve",
        description: "Advanced rotation + isolation work. Build the silhouette you want.",
        goal: .sculpting,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "woodchoppers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "hollow_body_hold", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "russian_twists", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_pulses", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_right", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 9,
        isGenerated: false
    )

    static let sculpting4 = WorkoutPreset(
        id: "sculpting_4",
        name: "21 Days · Twist & Tone",
        description: "Rotational flow that defines the obliques. Move through every angle.",
        goal: .sculpting,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "russian_twists", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bicycle_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "woodchoppers", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "plank_shoulder_taps", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 6,
        isGenerated: false
    )

    static let sculpting5 = WorkoutPreset(
        id: "sculpting_5",
        name: "30 Days · Glow Up",
        description: "Advanced sculpt sessions with a finisher kick. The full-body before/after.",
        goal: .sculpting,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "woodchoppers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "leg_raises", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_pulses", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "russian_twists", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "bear_crawl_hold", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "oblique_crunch_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_right", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "v_ups", duration: 30, restAfter: 15),
        ],
        estimatedDuration: 10,
        isGenerated: false
    )

    // MARK: Full Core (5)

    static let fullCore1 = WorkoutPreset(
        id: "full_core_1",
        name: "21 Days · Body Reset",
        description: "Three weeks to re-anchor your routine. Balanced, sustainable, undefeated.",
        goal: .fullCore,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "russian_twists", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bicycle_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 7,
        isGenerated: false
    )

    static let fullCore2 = WorkoutPreset(
        id: "full_core_2",
        name: "14 Days · Pilates Princess",
        description: "Pilates-inspired flow with no equipment needed. Long lines, controlled work.",
        goal: .fullCore,
        difficulty: .beginner,
        exercises: [
            ExerciseSlot(exerciseId: "dead_bug", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_left", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "oblique_crunch_right", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "toe_touches", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 5,
        isGenerated: false
    )

    static let fullCore3 = WorkoutPreset(
        id: "full_core_3",
        name: "30 Days · Total Sculpt",
        description: "Advanced full-body sculpt. Hits every zone, leaves nothing behind.",
        goal: .fullCore,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "hollow_body_hold", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "woodchoppers", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_pulses", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "v_ups", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "leg_raises", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "bear_crawl_hold", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "plank_shoulder_taps", duration: 40, restAfter: 10),
        ],
        estimatedDuration: 10,
        isGenerated: false
    )

    static let fullCore4 = WorkoutPreset(
        id: "full_core_4",
        name: "21 Days · Lazy Girl Routine",
        description: "Low-key but consistent. The bare minimum that still moves the needle.",
        goal: .fullCore,
        difficulty: .intermediate,
        exercises: [
            ExerciseSlot(exerciseId: "bird_dog", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "bicycle_crunch", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "glute_bridge_marches", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "russian_twists", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_hold", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "flutter_kicks", duration: 30, restAfter: 10),
            ExerciseSlot(exerciseId: "inchworms", duration: 30, restAfter: 10),
        ],
        estimatedDuration: 6,
        isGenerated: false
    )

    static let fullCore5 = WorkoutPreset(
        id: "full_core_5",
        name: "30 Days · The Gauntlet",
        description: "Ten exercises, advanced throughout. The library's most demanding session.",
        goal: .fullCore,
        difficulty: .advanced,
        exercises: [
            ExerciseSlot(exerciseId: "mountain_climbers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "side_plank_left", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "v_ups", duration: 30, restAfter: 15),
            ExerciseSlot(exerciseId: "side_plank_right", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "superman_pulses", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "hollow_body_hold", duration: 40, restAfter: 15),
            ExerciseSlot(exerciseId: "woodchoppers", duration: 45, restAfter: 10),
            ExerciseSlot(exerciseId: "bear_crawl_hold", duration: 45, restAfter: 15),
            ExerciseSlot(exerciseId: "leg_raises", duration: 40, restAfter: 10),
            ExerciseSlot(exerciseId: "plank_shoulder_taps", duration: 45, restAfter: 10),
        ],
        estimatedDuration: 10,
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
        // Sculpting
        .sculpting1, .sculpting2, .sculpting3, .sculpting4, .sculpting5,
        // Full Core
        .fullCore1, .fullCore2, .fullCore3, .fullCore4, .fullCore5,
    ]

    static func presets(for goal: WorkoutGoal) -> [WorkoutPreset] {
        allPresets.filter { $0.goal == goal }
    }
}
