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
        name: "Core Lockdown",
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
        name: "Foundation Builder",
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
        name: "Hold the Line",
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
        name: "Max Tension",
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
        name: "Ab Burner",
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
        name: "Sculpt & Burn",
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
        name: "Six Pack Express",
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
        name: "Crunch Time",
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
        name: "Lower Ab Focus",
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
        name: "Oblique Overload",
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
        name: "Waist Whittler",
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
        name: "Twist & Shout",
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
        name: "Core Rotation",
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
        name: "Oblique Finisher",
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
        name: "Total Core",
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
        name: "Core Essentials",
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
        name: "360 Core",
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
        name: "Core Balance",
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
        name: "Core Gauntlet",
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
