import Foundation

/// Which slot in a session this exercise is filling.
/// See `docs/workout_engine_research.md` §3.
enum ExerciseCategory: String, Codable, CaseIterable {
    case warmup
    case main
    case cooldown
}

/// Per-length structure: how many warmup / main / cooldown slots and what
/// duration to use for each. All numbers grounded in the research doc.
///
/// Warmup fills with `type == .mobility` AND `difficulty <= 2`.
/// Cooldown fills with `type == .mobility` AND `pace == .hold`
/// (static stretches: child's pose, quad stretch, etc.).
struct SessionStructure {
    let lengthMinutes: Int
    let warmupCount: Int
    let mainCount: Int
    let cooldownCount: Int
    let warmupDurationSec: Int    // per move
    let cooldownDurationSec: Int  // per move

    /// Lookup by length. Defaults to the closest defined bucket.
    static func forLength(_ minutes: Int) -> SessionStructure {
        switch minutes {
        case ...5:  return .min5
        case 6...7: return .min7
        case 8...10: return .min10
        case 11...15: return .min15
        case 16...30: return .min30
        default:    return .min45
        }
    }

    static let min5  = SessionStructure(lengthMinutes: 5,  warmupCount: 2, mainCount: 6,  cooldownCount: 1, warmupDurationSec: 30, cooldownDurationSec: 30)
    static let min7  = SessionStructure(lengthMinutes: 7,  warmupCount: 2, mainCount: 8,  cooldownCount: 2, warmupDurationSec: 30, cooldownDurationSec: 25)
    static let min10 = SessionStructure(lengthMinutes: 10, warmupCount: 3, mainCount: 10, cooldownCount: 2, warmupDurationSec: 30, cooldownDurationSec: 30)
    static let min15 = SessionStructure(lengthMinutes: 15, warmupCount: 4, mainCount: 14, cooldownCount: 3, warmupDurationSec: 30, cooldownDurationSec: 30)
    static let min30 = SessionStructure(lengthMinutes: 30, warmupCount: 6, mainCount: 24, cooldownCount: 6, warmupDurationSec: 35, cooldownDurationSec: 30)
    static let min45 = SessionStructure(lengthMinutes: 45, warmupCount: 6, mainCount: 36, cooldownCount: 8, warmupDurationSec: 40, cooldownDurationSec: 30)
}
