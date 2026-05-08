import Foundation

/// User-facing body-focus goals (multi-select on onboarding + settings).
/// Maps to muscle-group target areas per `docs/workout_engine_research.md`.
enum BodyFocus: String, Codable, CaseIterable {
    case flatBelly
    case tonedArms
    case roundButt
    case slimLegs
    case fullBody

    /// Primary areas — the engine pulls 70% of main-block slots from here.
    var primaryAreas: [TargetArea] {
        switch self {
        case .flatBelly:  return [.abs, .obliques]
        case .tonedArms:  return [.upperBody]
        case .roundButt:  return [.glutes]
        case .slimLegs:   return [.quads, .hamstrings, .calves]
        case .fullBody:   return [.fullBody, .glutes, .upperBody, .abs]
        }
    }

    /// Secondary areas — the remaining 30% of main slots, for symmetry,
    /// posture, and overall caloric expenditure.
    var secondaryAreas: [TargetArea] {
        switch self {
        case .flatBelly:  return [.lowerBack, .glutes, .hipFlexors]
        case .tonedArms:  return [.abs, .lowerBack]
        case .roundButt:  return [.hamstrings, .lowerBack, .quads]
        case .slimLegs:   return [.glutes, .abs]
        case .fullBody:   return [.lowerBack, .hamstrings]
        }
    }
}

extension Array where Element == BodyFocus {

    /// Union of primary areas across all selected focuses, deduplicated.
    var combinedPrimaryAreas: Set<TargetArea> {
        Set(flatMap { $0.primaryAreas })
    }

    /// Union of secondary areas across all selected focuses, minus anything
    /// already in primary (so an area is never double-counted).
    func combinedSecondaryAreas(excludingPrimary primary: Set<TargetArea>) -> Set<TargetArea> {
        Set(flatMap { $0.secondaryAreas }).subtracting(primary)
    }

    /// Parse from the raw strings stored on UserRecord.onboardingBodyFocus.
    static func parse(_ raw: [String]) -> [BodyFocus] {
        raw.compactMap { BodyFocus(rawValue: $0) }
    }
}
