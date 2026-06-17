import Foundation

// MARK: - ProgramDayArchetype
//
// v1.0.10 (2026-06-17) — per-day nutrition / register archetype that
// tags every day in the program with one of four themes:
//
//   .protein   — protein-led day (3×/wk on the standard rotation,
//                7×/wk for `.current` GLP-1 users per the May 2025
//                joint advisory: 1.2–2.0 g/kg adjusted body weight)
//   .balanced  — variety day (2×/wk), no macro prioritization
//   .movement  — workout / higher-output day (1×/wk on standard)
//   .rest      — softer, listen-to-body day (1×/wk, Sundays)
//
// SCOPE / INTENT
//
// The Glow Diet "no-carb / balance / workout day" structure is
// psychologically effective (gives the day an identity, reduces
// decision fatigue) but its science layer is weak — and for the
// GLP-1 cohort, no-carb days are actively contraindicated. JeniFit's
// archetype map borrows the structural win without the bad science:
// protein-led anchors replace "no-carb" days; the rest of the
// rotation echoes Glow Diet's pattern. Evidence anchors:
//
//   - GLP-1 nutrition advisory (ACLM/ASN/OMA/Obesity Society, May
//     2025) — protein priority, balanced carbs/fat, resistance work.
//   - Carb cycling RCT base — weak, no long-term superiority over
//     matched continuous diets. We do NOT promise a metabolic edge.
//   - Intermittent energy restriction — some women's-cohort body-
//     composition benefit; informs the Movement day's slight uplift.
//
// Phase 1 of the program-quality pivot (founder approved 2026-06-17):
// ship the archetype derivation + a Plan-tab pill. Future phases:
// Snap Food chip re-rank, JeniMethod scheduler bias, Becoming
// archetype strip.

public enum ProgramDayArchetype: String, Codable, Equatable, Hashable, Sendable {
    case protein
    case balanced
    case movement
    case rest

    /// Header pill copy — italic Fraunces punch word on the archetype
    /// keyword. Voice-locked per [[feedback-voice-signals]]:
    /// lowercase casual, hearts terminal-only.
    public var pillCopy: (text: String, italic: String) {
        switch self {
        case .protein:  return ("a protein day \u{2661}", "protein")
        case .balanced: return ("a balanced day",          "balanced")
        case .movement: return ("a movement day",          "movement")
        case .rest:     return ("a rest day \u{2661}",    "rest")
        }
    }

    /// SF Symbol glyph used as a quiet mark next to the pill. The
    /// archetype is communicated by the *word*; the glyph is a
    /// secondary signal that helps users orient at a glance.
    public var glyphName: String {
        switch self {
        case .protein:  return "fork.knife.circle"
        case .balanced: return "circle.lefthalf.filled"
        case .movement: return "figure.run.circle"
        case .rest:     return "moon.stars"
        }
    }
}

public extension ProgramDayArchetype {

    /// The standard 7-day rotation — Mon → Sun, 1-indexed weekday so
    /// it lines up with the user's program-day modulo 7. Pattern is
    /// P-M-P-B-P-B-R: 3 protein anchors (M/W/F), 2 balanced (T/Sat),
    /// 1 movement (Tu), 1 rest (Sun). Mirrors the Glow Diet weekly
    /// cadence the founder referenced, swapping no-carb → protein.
    ///
    /// Day index 0 means "today is the start of the week" — for the
    /// program-day path we use `programDay % 7` so a Day 1 user
    /// always lands on Protein no matter what calendar day it is.
    /// That keeps the program's narrative anchor consistent.
    static let standardRotation: [ProgramDayArchetype] = [
        .protein,    // 0 (Mon equivalent in program time)
        .movement,   // 1
        .protein,    // 2
        .balanced,   // 3
        .protein,    // 4
        .balanced,   // 5
        .rest,       // 6
    ]

    /// Derive today's archetype for a given program day + cohort
    /// flags. Cohort override is intentionally narrow: only the
    /// `.current` GLP-1 cohort is fully overridden (every day reads
    /// as `.protein` because the medication's appetite suppression +
    /// the joint advisory's protein floor both push the same way).
    /// The `.triedOff` and `.considering` cohorts get the standard
    /// rotation today; phase-2 may add cohort-specific weekly
    /// patterns (`.triedOff` quarterly refeed days, etc.).
    static func archetype(
        forProgramDay programDay: Int,
        glp1Status: String
    ) -> ProgramDayArchetype {
        if glp1Status == "current" { return .protein }
        let n = max(1, programDay)
        let index = (n - 1) % standardRotation.count
        return standardRotation[index]
    }
}
