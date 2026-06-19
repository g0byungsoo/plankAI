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

    /// v1.0.10 — "permission week" rotation. Every 4th program week
    /// swaps the standard rotation for this 1P-4B-1M-1R variant
    /// (movement + rest preserved at their usual indices; 2 protein
    /// days become balanced). Operationalizes the 2024 Sundfor
    /// systematic review (8 RCTs, 796 participants) + MATADOR (Byrne
    /// 2018) Level-1 evidence that planned maintenance breaks ≈
    /// continuous restriction for weight loss without adherence
    /// penalty AND blunt the resting-metabolic-rate decline.
    ///
    /// Voice register: branded in-app as "permission week" — never
    /// "diet break" or "refeed" (post-Ozempic vocab lock per
    /// [[feedback-post-ozempic-vocabulary]]). The anchor protein day
    /// stays mid-week as the cohort's identity touchpoint so the week
    /// still feels JeniFit-shaped, not a different program.
    static let resetRotation: [ProgramDayArchetype] = [
        .balanced,   // 0 (was .protein)
        .movement,   // 1 — preserved
        .balanced,   // 2 (was .protein)
        .balanced,   // 3 — preserved
        .protein,    // 4 — the one protein anchor
        .balanced,   // 5 — preserved
        .rest,       // 6 — preserved
    ]

    /// Derive today's archetype for a given program day + cohort
    /// flags.
    ///
    /// Cohort routing (priority high → low):
    ///
    /// 1. **`.current` GLP-1** → always `.protein` (joint advisory
    ///    1.2–2.0 g/kg/d protein floor, every day).
    /// 2. **Restrictive food relationship** → always the standard
    ///    rotation. No reset weeks, no phase shifts, no rotation
    ///    variation. Per WM physician 2026-06-17 brief: phasing
    ///    re-triggers restrict/binge cognition. Override beats every
    ///    other consideration including reset-week scheduling.
    /// 3. **Reset week** (every 4th program week, weeks 4 / 8 / 12 /
    ///    …) → `.resetRotation` (1P-4B-1M-1R). Evidence-anchored to
    ///    Sundfor 2024 + MATADOR 2018.
    /// 4. **Default** → `.standardRotation` (3P-2B-1M-1R).
    static func archetype(
        forProgramDay programDay: Int,
        glp1Status: String,
        restrictiveFoodRelationship: Bool = false
    ) -> ProgramDayArchetype {
        if glp1Status == "current" { return .protein }
        let n = max(1, programDay)
        let week = ((n - 1) / 7) + 1
        let dayInWeek = (n - 1) % standardRotation.count
        // Restrictive override: never apply reset-week phasing.
        if restrictiveFoodRelationship {
            return standardRotation[dayInWeek]
        }
        // Reset week every 4 weeks per Sundfor 2024 systematic review.
        if week % 4 == 0 {
            return resetRotation[dayInWeek]
        }
        return standardRotation[dayInWeek]
    }

    /// True when the given program day falls inside a reset / permission
    /// week. Surface-layer callers (Plan tab, Becoming strip) read this
    /// to render a small "permission week" eyebrow above the archetype
    /// pill. Restrictive cohorts never see a reset week — the helper
    /// returns false for them regardless of program day.
    static func isResetWeek(
        programDay: Int,
        restrictiveFoodRelationship: Bool = false
    ) -> Bool {
        guard !restrictiveFoodRelationship else { return false }
        let n = max(1, programDay)
        let week = ((n - 1) / 7) + 1
        return week % 4 == 0
    }
}

// MARK: - PillarId archetype affinity
//
// Phase 3 of the archetype build (2026-06-17). Each curriculum pillar
// has an implicit nutrition / register affinity — P2 (hunger / satiety
// / urge surfing) lands hardest on a protein day; P3 (all-or-nothing /
// self-compassion) lands hardest on a rest day; P5 (sleep / stress /
// emotional regulation) lands hardest on a movement day. P1 (food
// noise), P4 (body image), P6 (maintenance) are universal — they
// don't have a single archetype that maps cleanly.
//
// Surface use: the lesson reader's footer folio shows the day
// archetype + lesson pillar together so the user sees the
// intentionality of the pairing. Future phase-4 work may consume
// this in the CBTCurriculumScheduler to bias slot ordering when the
// invariant chain allows it (anti-adjacency + act order still rule).

public extension PillarId {
    var archetypeAffinity: ProgramDayArchetype? {
        switch self {
        case .P2: return .protein
        case .P3: return .rest
        case .P5: return .movement
        case .P1, .P4, .P6: return nil
        }
    }
}

// MARK: - Home-screen rendering helpers (Phase 1 home redesign, 2026-06-19)
//
// Per the 4-expert panel synthesis (her75 typographer / Gen-Z aesthetic /
// WL iOS / GLP-1 RD). Archetype expressiveness on Home arrives through:
//   1. A serif sentence above the checklist card (Panel 3 + 1: framing)
//   2. Row reordering — the day's "anchor" prescription floats to row 1
//   3. A 2pt vertical hairline accent in the archetype's sticky pastel
//      at the anchor row's leading edge (Panel 2: the typographic mark)
// NO color-coded badges. NO Duolingo path-coding. NO row decoration
// beyond the single anchor mark.

public extension ProgramDayArchetype {

    /// The serif framing sentence that lands above the checklist card.
    /// Lowercase, italic-Fraunces on the archetype keyword, period-
    /// punctuation. Drives `HomeArchetypeHeader`.
    var headerSentence: (prefix: String, italic: String, suffix: String) {
        switch self {
        case .protein:  return ("today is a ",  "protein",  " day.")
        case .balanced: return ("today is ",    "balanced", ".")
        case .movement: return ("today is a ",  "movement", " day.")
        case .rest:     return ("today is ",    "gentle",   ".")
        }
    }

    /// Lightweight discriminant of the prescription that anchors this
    /// archetype's day. The PlanView's reorder helper matches a row
    /// against this tag rather than against a fully-parametrized
    /// prescription (the engine's per-day minutes/tier values would
    /// otherwise drive false negatives).
    enum AnchorTag {
        case snapMeal, workout, breath
    }

    /// The prescription tag that should be promoted to row 1 in the
    /// checklist when this archetype is the day's frame. The reorder
    /// is the invisible-as-typography differentiation — protein day
    /// opens with snapMeal, movement day with workout, etc.
    ///
    /// Balanced returns nil — absence of reorder IS the balance signal
    /// (per Panel 2 + 4: most days are balanced; the brand-default
    /// state is a stable order).
    var anchorTag: AnchorTag? {
        switch self {
        case .protein:  return .snapMeal
        case .movement: return .workout
        case .rest:     return .breath
        case .balanced: return nil
        }
    }

    /// Locked-palette pastel for the 2pt vertical hairline accent at
    /// the anchor row's leading edge. Pulls from `Palette.sticky*`
    /// — same family the ProgramStickyNote chrome uses, so the
    /// accent reads as part of the scrapbook register, not a foreign
    /// brand color. Returns nil for balanced (no accent, no signal).
    ///
    /// The mapping is intentional: butter (protein) matches the snap-
    /// meal sticky color, olive (movement) matches workout. The
    /// pairing is recognized at a glance by the cohort who has the
    /// sticky-color affordance memorized.
    var anchorAccentColorName: String? {
        switch self {
        case .protein:  return "stickyButter"
        case .movement: return "stickyOlive"
        case .rest:     return "stickyMint"
        case .balanced: return nil
        }
    }

    /// Snap-meal subtitle ENHANCEMENT for the cohort-routed protein
    /// day. Only fires on `glp1Status == "current"` AND archetype ==
    /// `.protein`. Returns nil otherwise so the default prescription
    /// subtitle stays. Per Panel 4 GLP-1 RD: appetite-suppressed
    /// users routinely under-eat protein; the lean-mass-protection
    /// frame (Wilding NEJM 2022; Conte JCEM 2024) earns the salience.
    func glp1ProteinNudge(glp1Status: String) -> String? {
        guard self == .protein, glp1Status == "current" else { return nil }
        return "aim for 80g+ today \u{2661}"
    }
}
