import Foundation
// Note: this file references StickerName from the same module (PlankApp);
// no import needed since the design system + protocols ship as one target.

// MARK: - BreathworkProtocol
//
// The library of breath techniques JeniFit ships. Three protocols for v1,
// all expressible with BreathCircle's native inhale/exhale phases (no
// hold-phase support yet — 4-7-8 and box-breath would need BreathCircle
// extended; reserved for a future pass).
//
// Each technique answers four questions for the user before they start:
//   1. WHAT it is (title + pattern)
//   2. WHEN to use it (whenToUse)
//   3. WHY it works (mechanism — anchored to a real citation, not vibes)
//   4. HOW LONG it takes (durationLabel)
//
// Science notes (per the project memory on the breathwork module):
//  - .calming → Balban et al. 2023, Stanford. Long exhale > inhale is the
//    parasympathetic switch; lowers cortisol; the JeniFit default.
//  - .coherent → resonant-frequency breathing (Lehrer 2014). HRV rises into
//    its resonant band ~5.5-6 breaths/min when inhale = exhale = 5s.
//  - .energizing → Senobi-inspired. Sato et al. 2010 found short, equal
//    breaths before meals restored blunted sympathetic activity in women
//    and supported body-fat loss across a month. Small study, cited as
//    supporting (not headline) — see [[project-breathwork-module]] memory.

enum BreathworkProtocol: String, CaseIterable, Identifiable {
    case calming
    case coherent
    case energizing

    var id: String { rawValue }

    /// Display title — lowercase, italic-Fraunces-friendly.
    var title: String {
        switch self {
        case .calming:    return "calming"
        case .coherent:   return "coherent"
        case .energizing: return "energizing"
        }
    }

    /// Sub-headline / promise.
    var subtitle: String {
        switch self {
        case .calming:    return "lower your cortisol"
        case .coherent:   return "find your balance"
        case .energizing: return "wake the body up"
        }
    }

    /// Display pattern, e.g. "4 in · 6 out".
    var patternLabel: String {
        switch self {
        case .calming:    return "4 in · 6 out"
        case .coherent:   return "5 in · 5 out"
        case .energizing: return "4 in · 4 out"
        }
    }

    /// Inhale seconds (used by BreathCircle.State.cycling).
    var inhaleSec: Int {
        switch self {
        case .calming: return 4
        case .coherent: return 5
        case .energizing: return 4
        }
    }

    /// Exhale seconds.
    var exhaleSec: Int {
        switch self {
        case .calming: return 6
        case .coherent: return 5
        case .energizing: return 4
        }
    }

    /// Number of cycles. Total session time ≈ (inhale + exhale) × repeats.
    var repeats: Int {
        switch self {
        case .calming:    return 6  // 60s
        case .coherent:   return 6  // 60s
        case .energizing: return 8  // 64s — slightly longer because the
                                    // sympathetic shift needs more reps
        }
    }

    /// Total session duration label.
    var durationLabel: String { "1 minute" }

    /// Three short, scannable "when to use" tags. Rendered dot-separated
    /// in the expansion, no chip chrome — clean/luxury bar prefers the
    /// text over decorated containers. Each tag is 2-4 words.
    var whenSituations: [String] {
        switch self {
        case .calming:
            return ["feeling wired", "before bed", "cravings that aren't hunger"]
        case .coherent:
            return ["sitting to focus", "between meetings", "racing mind"]
        case .energizing:
            return ["before meals", "before you move", "3pm slump"]
        }
    }

    /// Single-sentence pull quote that names the mechanism. Read as the
    /// italic-Fraunces accent on the science word, lowercase casual on
    /// the rest. Pairs with `whyItalicWords` for the italic emphasis.
    var whyHeadline: String {
        switch self {
        case .calming:
            return "the parasympathetic switch. cortisol settles."
        case .coherent:
            return "your hrv climbs to its resonant rhythm."
        case .energizing:
            return "wakes the sympathetic system back up."
        }
    }

    /// Words inside `whyHeadline` to italicize (passed to ItalicAccentText).
    /// Case-sensitive match — keep lowercase to match the headline.
    var whyItalicWords: [String] {
        switch self {
        case .calming:    return ["parasympathetic"]
        case .coherent:   return ["hrv", "resonant rhythm"]
        case .energizing: return ["sympathetic"]
        }
    }

    /// Compact citation line under the why headline — author + venue +
    /// year + n if available. Reads as receipts, not a footnote dump.
    var citation: String {
        switch self {
        case .calming:    return "balban et al. · stanford 2023 · n=111"
        case .coherent:   return "lehrer 2014 · resonant-frequency breathing"
        case .energizing: return "sato et al. · biomed res 2010 · n=40 women"
        }
    }

    /// Coquette sticker accent for the picker card + the session bloom.
    var sticker: StickerName {
        switch self {
        case .calming:    return .heartGlossy
        case .coherent:   return .butterflyRing
        case .energizing: return .sparkleGlossy
        }
    }
}
