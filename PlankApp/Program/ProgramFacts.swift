import Foundation

// MARK: - ProgramFacts (E1 THE SPINE — pure core)
//
// docs/app_v25/05_E1_SPINE.md §1. The program's memory vocabulary:
// closed fact kinds, the authority ladder, value encoding, clamps,
// and head resolution. Pure and deterministic — the SwiftData store
// wraps these laws; engines never re-derive them.
//
// Laws:
//   - One active chain per (kind, authority); supersede within a
//     chain only. A prescription never ENDS a preference — it
//     out-renders it; ending the prescription RESUMES the
//     preference (no-silent-overwrite, structural).
//   - Render precedence: prescribed › preferred › recommended ›
//     defaulted. A recommendation resolves ONLY once accepted.
//   - Clamps are authority-aware: recommendations ride the safe
//     band; preferences get sanity bounds only; prescriptions pass
//     through wide sanity rails (clinician authority renders
//     verbatim, like the b2b regimen face). proteinAdjust rides the
//     advisory-band clamp for EVERY authority — it is a safety law,
//     not a taste.

enum ProgramFactKind: String, CaseIterable, Codable {
    case stepGoal
    case proteinAdjust
    case movesAdjust
    case weighCadence
    case loggingMode
    case notificationPosture
    case walkTiming
    case readAnchor

    /// Kinds whose values are words, with their closed vocabulary.
    /// Int kinds return nil.
    var wordVocabulary: [String]? {
        switch self {
        case .weighCadence: return ["standard", "softened"]
        case .loggingMode: return ["standard", "lighter"]
        case .notificationPosture: return ["standard", "quieter"]
        case .walkTiming: return ["afterMeals", "anytime", "off"]
        case .readAnchor: return nil   // validated structurally below
        case .stepGoal, .proteinAdjust, .movesAdjust: return nil
        }
    }

    var isWordKind: Bool {
        switch self {
        case .weighCadence, .loggingMode, .notificationPosture,
             .walkTiming, .readAnchor:
            return true
        case .stepGoal, .proteinAdjust, .movesAdjust:
            return false
        }
    }
}

enum ProgramFactAuthority: String, CaseIterable, Codable {
    case prescribed
    case preferred
    case recommended
    case defaulted

    /// Render precedence — higher wins (docs/app_v25/00_THE_SYSTEM §2).
    var precedence: Int {
        switch self {
        case .prescribed: return 3
        case .preferred: return 2
        case .recommended: return 1
        case .defaulted: return 0
        }
    }
}

enum ProgramFactBasis: String, CaseIterable, Codable {
    case assigned
    case stated
    case inferred
    case defaulted
}

enum ProgramFactValue: Equatable {
    case int(Int)
    case word(String)

    /// Canonical string encoding ("i:5150" / "w:softened") — the
    /// persisted + synced form. Round-trip pinned in tests.
    var encoded: String {
        switch self {
        case .int(let v): return "i:\(v)"
        case .word(let w): return "w:\(w)"
        }
    }

    static func decode(_ raw: String) -> ProgramFactValue? {
        if raw.hasPrefix("i:") {
            guard let v = Int(raw.dropFirst(2)) else { return nil }
            return .int(v)
        }
        if raw.hasPrefix("w:") {
            let w = String(raw.dropFirst(2))
            guard !w.isEmpty else { return nil }
            return .word(w)
        }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    var wordValue: String? {
        if case .word(let w) = self { return w }
        return nil
    }
}

enum ProgramFacts {

    /// Lightweight value view of a fact row — the pure resolution
    /// input (the store maps records onto these).
    struct Row: Equatable {
        let kind: ProgramFactKind
        let value: ProgramFactValue
        let authority: ProgramFactAuthority
        let endedAt: Date?
        let acceptedAt: Date?
        let createdAt: Date
    }

    // MARK: - Resolution

    /// The head: among ACTIVE rows of `kind` (endedAt nil; a
    /// recommendation counts only once accepted), the row of the
    /// highest-precedence authority; latest createdAt breaks ties
    /// inside one authority (a coalescing anomaly stays
    /// deterministic). nil = no fact in force — callers fall back to
    /// their legacy defaults.
    static func head(of rows: [Row], kind: ProgramFactKind) -> Row? {
        rows
            .filter { row in
                row.kind == kind
                    && row.endedAt == nil
                    && (row.authority != .recommended || row.acceptedAt != nil)
            }
            .max { a, b in
                if a.authority.precedence != b.authority.precedence {
                    return a.authority.precedence < b.authority.precedence
                }
                return a.createdAt < b.createdAt
            }
    }

    // MARK: - Clamps (kind × authority)

    /// The safe-band law. Int kinds clamp by authority; word kinds
    /// pass through (validity is `isValidWord`'s job).
    static func clamped(
        _ value: ProgramFactValue,
        kind: ProgramFactKind,
        authority: ProgramFactAuthority
    ) -> ProgramFactValue {
        guard case .int(let raw) = value else { return value }
        switch kind {
        case .stepGoal:
            switch authority {
            case .recommended, .defaulted:
                // The evidence band (r4: floor 2,500 / ceiling
                // 8,000), rounded to friendly 50s.
                let banded = min(8_000, max(2_500, raw))
                return .int(Int((Double(banded) / 50.0).rounded()) * 50)
            case .preferred:
                // Her body, her call — sanity rails only.
                return .int(min(30_000, max(1_000, raw)))
            case .prescribed:
                // Clinician authority passes through wide rails.
                return .int(min(50_000, max(500, raw)))
            }
        case .proteinAdjust:
            // The v4 advisory-band clamp is a safety law for EVERY
            // authority: the adjust rides the formula, and the
            // formula's band must hold downstream regardless of who
            // asked.
            return .int(min(10, max(-10, raw)))
        case .movesAdjust:
            return .int(min(1, max(-1, raw)))
        case .weighCadence, .loggingMode, .notificationPosture,
             .walkTiming, .readAnchor:
            return value
        }
    }

    // MARK: - Word validation

    static func isValidWord(_ word: String, kind: ProgramFactKind) -> Bool {
        if let vocab = kind.wordVocabulary {
            return vocab.contains(word)
        }
        if kind == .readAnchor {
            if word == "auto" { return true }
            if word.hasPrefix("weekday:"),
               let day = Int(word.dropFirst("weekday:".count)),
               (1...7).contains(day) {
                return true
            }
            return false
        }
        return false
    }
}
