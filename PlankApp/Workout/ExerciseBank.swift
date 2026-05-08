import Foundation

// MARK: - Taxonomy

enum TargetArea: String, Codable, CaseIterable {
    case abs
    case obliques
    case lowerBack
    case glutes
    case quads
    case hamstrings
    case hipFlexors
    case calves
    case upperBody
    case fullBody
}

enum ExerciseType: String, Codable, CaseIterable {
    case cardio
    case strength
    case core
    case mobility
    case balance
}

enum Impact: String, Codable, CaseIterable {
    case low
    case med
    case high
}

enum Symmetry: String, Codable, CaseIterable {
    /// Both sides simultaneously (squat, plank).
    case bilateral
    /// Alternates sides within the set (bicycle crunch, jumping lunges).
    case alternating
    /// One side at a time. Engine pairs left + right across slots.
    case unilateral
}

enum Side: String, Codable, CaseIterable {
    case left
    case right
}

/// Stillness-dominant vs movement-dominant. Drives audio cue selection.
enum Pace: String, Codable, CaseIterable {
    case hold
    case rep
}

/// Body orientation for the exercise. Drives block-based ordering in
/// `WorkoutGenerator` so a session reads as standing → quadruped → plank →
/// prone → side-lying → supine → seated rather than a random shuffle —
/// matching how Pamela Reif / growingannanas sequence their videos.
enum ExercisePosition: String, Codable, CaseIterable {
    case standing
    case quadruped
    case plank
    case prone
    case sideLying
    case supine
    case seated
}

// MARK: - Exercise

struct Exercise: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let lottieId: Int
    let lottieURL: String
    let targetAreas: [TargetArea]
    let type: ExerciseType
    let impact: Impact
    let difficulty: Int          // 1...5
    let met: Double              // Metabolic equivalent (Compendium of Physical Activities)
    let symmetry: Symmetry
    let defaultSide: Side?       // Which side the source Lottie animates (only set for .unilateral).
    let pace: Pace
    let position: ExercisePosition
    let lottieFile: String       // Filename stem under PlankApp/Resources/lottie/, no extension.
    let defaultDurationSec: Int
    let restAfterSec: Int
    let note: String

    /// First listed area, used as the headline label on UI.
    var primaryArea: TargetArea { targetAreas.first ?? .fullBody }

    /// kcal/min for a given body weight using `kcal/min = MET × kg / 60`.
    func kcalPerMinute(bodyWeightKg: Double) -> Double {
        met * bodyWeightKg / 60.0
    }

    /// Bundle URL of the Lottie JSON. `nil` if the asset isn't bundled.
    var lottieBundleURL: URL? {
        Bundle.main.url(forResource: "lottie/\(lottieFile)", withExtension: "json")
            ?? Bundle.main.url(forResource: lottieFile, withExtension: "json", subdirectory: "lottie")
    }

    static func == (lhs: Exercise, rhs: Exercise) -> Bool { lhs.id == rhs.id }
}

// MARK: - Bank (read-only)

enum ExerciseBank {

    static let all: [Exercise] = ExerciseBankData.all

    private static let index: [String: Exercise] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    static func exercise(id: String) -> Exercise? { index[id] }

    static func exercises(targeting area: TargetArea) -> [Exercise] {
        all.filter { $0.targetAreas.contains(area) }
    }

    static func exercises(type: ExerciseType) -> [Exercise] {
        all.filter { $0.type == type }
    }

    static func exercises(maxDifficulty: Int) -> [Exercise] {
        all.filter { $0.difficulty <= maxDifficulty }
    }
}
