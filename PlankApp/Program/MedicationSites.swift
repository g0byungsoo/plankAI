import Foundation

// MARK: - Injection sites + rotation (app v24 THE REGIMEN)
//
// docs/app_v24/00_REGIMEN.md §4 — six canonical sites and a pure
// advisor that SUGGESTS the next one. Rotation keeps the skin
// comfortable (label-level guidance); the advisor never insists,
// never scolds, and a nil site is always a valid mark. Sites are
// hers: they render on surfaces she reads, never in notifications,
// never in analytics.

enum InjectionSite: String, CaseIterable, Identifiable, Sendable {
    case leftAbdomen = "left_abdomen"
    case rightAbdomen = "right_abdomen"
    case leftThigh = "left_thigh"
    case rightThigh = "right_thigh"
    case leftArm = "left_arm"
    case rightArm = "right_arm"

    var id: String { rawValue }

    /// "left abdomen" — the sentence word.
    var word: String {
        switch self {
        case .leftAbdomen: return "left abdomen"
        case .rightAbdomen: return "right abdomen"
        case .leftThigh: return "left thigh"
        case .rightThigh: return "right thigh"
        case .leftArm: return "left arm"
        case .rightArm: return "right arm"
        }
    }

    /// The region word ("abdomen") — cells group by region.
    var region: String {
        switch self {
        case .leftAbdomen, .rightAbdomen: return "abdomen"
        case .leftThigh, .rightThigh: return "thigh"
        case .leftArm, .rightArm: return "arm"
        }
    }

    var isLeft: Bool {
        switch self {
        case .leftAbdomen, .leftThigh, .leftArm: return true
        case .rightAbdomen, .rightThigh, .rightArm: return false
        }
    }

    /// The same region's other side — the rotation's first choice.
    var mirrored: InjectionSite {
        switch self {
        case .leftAbdomen: return .rightAbdomen
        case .rightAbdomen: return .leftAbdomen
        case .leftThigh: return .rightThigh
        case .rightThigh: return .leftThigh
        case .leftArm: return .rightArm
        case .rightArm: return .leftArm
        }
    }
}

enum SiteRotationAdvisor {

    /// The suggested next site given recent sites, most recent
    /// first. Deterministic:
    /// 1. no history → left abdomen (the most common first site).
    /// 2. the last site's MIRROR, unless it was itself used within
    ///    the last two doses (same skin too soon).
    /// 3. else the least-recently-used site (never-used wins, in
    ///    canonical order).
    /// A suggestion is a pre-ringed cell, nothing more.
    static func suggestion(recent: [InjectionSite]) -> InjectionSite {
        guard let last = recent.first else { return .leftAbdomen }

        let mirror = last.mirrored
        let lastTwo = recent.prefix(2)
        if !lastTwo.contains(mirror) { return mirror }

        // Least recently used: sites never in `recent` first (in
        // canonical order), else the one whose most-recent use is
        // oldest (deepest index in `recent`).
        var bestSite: InjectionSite?
        var bestDepth = -1
        for site in InjectionSite.allCases {
            guard let depth = recent.firstIndex(of: site) else {
                return site
            }
            if depth > bestDepth {
                bestDepth = depth
                bestSite = site
            }
        }
        return bestSite ?? .leftAbdomen
    }

    /// One quiet sentence for the sheet: why this cell is ringed.
    /// nil when there is nothing worth saying (no history).
    static func line(recent: [InjectionSite], suggested: InjectionSite) -> String? {
        guard let last = recent.first else { return nil }
        if suggested == last.mirrored, suggested.region == last.region {
            return "\(last.word) last time — the \(suggested.isLeft ? "left" : "right") side keeps the rotation."
        }
        return "\(last.word) last time — somewhere fresh keeps the skin comfortable."
    }
}
