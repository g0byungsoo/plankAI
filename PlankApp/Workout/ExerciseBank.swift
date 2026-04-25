import Foundation

// MARK: - Target Area

enum TargetArea: String, Codable, CaseIterable {
    case frontCore
    case obliques
    case lowerBack
    case fullCore
}

// MARK: - Exercise Type

enum ExerciseType: String, Codable {
    case `static`
    case dynamic
}

// MARK: - Exercise Definition

struct Exercise: Identifiable, Equatable {
    let id: String
    let name: String
    let targetArea: TargetArea
    let type: ExerciseType
    let difficultyTier: Int          // 1-3
    let defaultDuration: Int         // seconds (30/40/45)
    let restAfter: Int               // seconds (10/15)
    let animationAsset: String       // Lottie JSON filename
    let incompatibleWith: [String]   // exercise IDs that shouldn't be consecutive
    let cameraTracked: Bool

    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Exercise Bank (static, read-only)

enum ExerciseBank {

    static let all: [Exercise] = [
        // --- Front Core (abs) ---
        Exercise(
            id: "bicycle_crunch",
            name: "Bicycle Crunches",
            targetArea: .frontCore,
            type: .dynamic,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "bicycle_crunch",
            incompatibleWith: ["toe_touches"],
            cameraTracked: false
        ),
        Exercise(
            id: "reverse_crunch",
            name: "Reverse Crunches",
            targetArea: .frontCore,
            type: .dynamic,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "reverse_crunch",
            incompatibleWith: ["leg_raises"],
            cameraTracked: false
        ),
        Exercise(
            id: "leg_raises",
            name: "Leg Raises",
            targetArea: .frontCore,
            type: .dynamic,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "leg_raises",
            incompatibleWith: ["reverse_crunch", "flutter_kicks"],
            cameraTracked: false
        ),
        Exercise(
            id: "flutter_kicks",
            name: "Flutter Kicks",
            targetArea: .frontCore,
            type: .dynamic,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "flutter_kicks",
            incompatibleWith: ["leg_raises"],
            cameraTracked: false
        ),
        Exercise(
            id: "toe_touches",
            name: "Toe Touches",
            targetArea: .frontCore,
            type: .dynamic,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "toe_touches",
            incompatibleWith: ["bicycle_crunch"],
            cameraTracked: false
        ),
        Exercise(
            id: "v_ups",
            name: "V-Ups",
            targetArea: .frontCore,
            type: .dynamic,
            difficultyTier: 3,
            defaultDuration: 30,
            restAfter: 15,
            animationAsset: "v_ups",
            incompatibleWith: [],
            cameraTracked: false
        ),
        Exercise(
            id: "dead_bug",
            name: "Dead Bug",
            targetArea: .frontCore,
            type: .dynamic,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "dead_bug",
            incompatibleWith: [],
            cameraTracked: false
        ),
        Exercise(
            id: "hollow_body_hold",
            name: "Hollow Body Hold",
            targetArea: .frontCore,
            type: .static,
            difficultyTier: 3,
            defaultDuration: 30,
            restAfter: 15,
            animationAsset: "hollow_body_hold",
            incompatibleWith: [],
            cameraTracked: false
        ),

        // --- Obliques ---
        Exercise(
            id: "russian_twists",
            name: "Russian Twists",
            targetArea: .obliques,
            type: .dynamic,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "russian_twists",
            incompatibleWith: ["woodchoppers"],
            cameraTracked: false
        ),
        Exercise(
            id: "side_plank_left",
            name: "Side Plank (Left)",
            targetArea: .obliques,
            type: .static,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "side_plank_left",
            incompatibleWith: [],
            cameraTracked: false
        ),
        Exercise(
            id: "side_plank_right",
            name: "Side Plank (Right)",
            targetArea: .obliques,
            type: .static,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "side_plank_right",
            incompatibleWith: [],
            cameraTracked: false
        ),
        Exercise(
            id: "oblique_crunch_left",
            name: "Oblique Crunch (Left)",
            targetArea: .obliques,
            type: .dynamic,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "oblique_crunch_left",
            incompatibleWith: [],
            cameraTracked: false
        ),
        Exercise(
            id: "oblique_crunch_right",
            name: "Oblique Crunch (Right)",
            targetArea: .obliques,
            type: .dynamic,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "oblique_crunch_right",
            incompatibleWith: [],
            cameraTracked: false
        ),
        Exercise(
            id: "woodchoppers",
            name: "Woodchoppers",
            targetArea: .obliques,
            type: .dynamic,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "woodchoppers",
            incompatibleWith: ["russian_twists"],
            cameraTracked: false
        ),

        // --- Lower Back / Posterior Chain ---
        Exercise(
            id: "superman_hold",
            name: "Superman Hold",
            targetArea: .lowerBack,
            type: .static,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "superman_hold",
            incompatibleWith: ["superman_pulses"],
            cameraTracked: false
        ),
        Exercise(
            id: "superman_pulses",
            name: "Superman Pulses",
            targetArea: .lowerBack,
            type: .dynamic,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "superman_pulses",
            incompatibleWith: ["superman_hold"],
            cameraTracked: false
        ),
        Exercise(
            id: "bird_dog",
            name: "Bird Dog",
            targetArea: .lowerBack,
            type: .dynamic,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "bird_dog",
            incompatibleWith: [],
            cameraTracked: false
        ),
        Exercise(
            id: "glute_bridge_hold",
            name: "Glute Bridge Hold",
            targetArea: .lowerBack,
            type: .static,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "glute_bridge_hold",
            incompatibleWith: ["glute_bridge_marches"],
            cameraTracked: false
        ),
        Exercise(
            id: "glute_bridge_marches",
            name: "Glute Bridge Marches",
            targetArea: .lowerBack,
            type: .dynamic,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "glute_bridge_marches",
            incompatibleWith: ["glute_bridge_hold"],
            cameraTracked: false
        ),

        // --- Full Core / Compound ---
        Exercise(
            id: "mountain_climbers",
            name: "Mountain Climbers",
            targetArea: .fullCore,
            type: .dynamic,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 15,
            animationAsset: "mountain_climbers",
            incompatibleWith: ["high_knees"],
            cameraTracked: false
        ),
        Exercise(
            id: "plank",
            name: "Plank",
            targetArea: .fullCore,
            type: .static,
            difficultyTier: 1,
            defaultDuration: 45,
            restAfter: 15,
            animationAsset: "plank",
            incompatibleWith: [],
            cameraTracked: true
        ),
        Exercise(
            id: "plank_shoulder_taps",
            name: "Plank Shoulder Taps",
            targetArea: .fullCore,
            type: .dynamic,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "plank_shoulder_taps",
            incompatibleWith: [],
            cameraTracked: false
        ),
        Exercise(
            id: "bear_crawl_hold",
            name: "Bear Crawl Hold",
            targetArea: .fullCore,
            type: .static,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 15,
            animationAsset: "bear_crawl_hold",
            incompatibleWith: [],
            cameraTracked: false
        ),
        Exercise(
            id: "inchworms",
            name: "Inchworms",
            targetArea: .fullCore,
            type: .dynamic,
            difficultyTier: 2,
            defaultDuration: 30,
            restAfter: 10,
            animationAsset: "inchworms",
            incompatibleWith: [],
            cameraTracked: false
        ),
        Exercise(
            id: "high_knees",
            name: "High Knees",
            targetArea: .fullCore,
            type: .dynamic,
            difficultyTier: 1,
            defaultDuration: 30,
            restAfter: 15,
            animationAsset: "high_knees",
            incompatibleWith: ["mountain_climbers"],
            cameraTracked: false
        ),
    ]

    // MARK: - Lookup

    private static let index: [String: Exercise] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    static func exercise(id: String) -> Exercise? {
        index[id]
    }

    static func exercises(for area: TargetArea) -> [Exercise] {
        all.filter { $0.targetArea == area }
    }

    static func exercises(tier: Int) -> [Exercise] {
        all.filter { $0.difficultyTier == tier }
    }
}
