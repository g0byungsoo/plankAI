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
    /// v1.1 (2026-06-11) — 4-7-8 for the sleepy occasion, now that
    /// BreathCircle supports a hold phase. Evidence grade MODERATE
    /// per docs/breathwork_evidence_review_2026_06_11.md: claims the
    /// slow-breathing sleep literature, never a 4-7-8-specific
    /// promise. (Box breathing intentionally NOT added — it lost the
    /// Balban head-to-head to cyclic sighing for the stress occasion.)
    case windDown

    var id: String { rawValue }

    /// Display title — lowercase, italic-Fraunces-friendly.
    var title: String {
        switch self {
        case .calming:    return "calming"
        case .coherent:   return "coherent"
        case .energizing: return "energizing"
        case .windDown:   return "wind-down"
        }
    }

    /// Sub-headline / promise.
    var subtitle: String {
        switch self {
        case .calming:    return "lower your cortisol"
        case .coherent:   return "find your balance"
        case .energizing: return "wake the body up"
        case .windDown:   return "tell the day it's over"
        }
    }

    /// Display pattern, e.g. "4 in · 6 out".
    var patternLabel: String {
        switch self {
        case .calming:    return "4 in · 6 out"
        case .coherent:   return "5 in · 5 out"
        case .energizing: return "4 in · 4 out"
        case .windDown:   return "4 in · 7 hold · 8 out"
        }
    }

    /// Inhale seconds (used by BreathCircle.State.cycling).
    var inhaleSec: Int {
        switch self {
        case .calming: return 4
        case .coherent: return 5
        case .energizing: return 4
        case .windDown: return 4
        }
    }

    /// Hold-at-apex seconds. 0 = no hold phase.
    var holdSec: Int {
        switch self {
        case .windDown: return 7
        default:        return 0
        }
    }

    /// Exhale seconds.
    var exhaleSec: Int {
        switch self {
        case .calming: return 6
        case .coherent: return 5
        case .energizing: return 4
        case .windDown: return 8
        }
    }

    /// Number of cycles. Total session time ≈ (inhale + hold + exhale) × repeats.
    var repeats: Int {
        switch self {
        case .calming:    return 6  // 60s
        case .coherent:   return 6  // 60s
        case .energizing: return 8  // 64s — slightly longer because the
                                    // sympathetic shift needs more reps
        case .windDown:   return 3  // 57s — a 4-7-8 cycle is 19s
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
            return ["feeling wired", "stress eating moments", "cravings that aren't hunger"]
        case .coherent:
            return ["sitting to focus", "between meetings", "racing mind"]
        case .energizing:
            return ["before meals", "before you move", "3pm slump"]
        case .windDown:
            return ["in bed", "after the last scroll", "mind won't stop"]
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
        case .windDown:
            return "the long exhale is the day-is-done signal."
        }
    }

    /// Words inside `whyHeadline` to italicize (passed to ItalicAccentText).
    /// Case-sensitive match — keep lowercase to match the headline.
    var whyItalicWords: [String] {
        switch self {
        case .calming:    return ["parasympathetic"]
        case .coherent:   return ["hrv", "resonant rhythm"]
        case .energizing: return ["sympathetic"]
        case .windDown:   return ["day-is-done"]
        }
    }

    /// Compact citation line under the why headline — author + venue +
    /// year + n if available. Reads as receipts, not a footnote dump.
    var citation: String {
        switch self {
        case .calming:    return "balban et al. · stanford 2023 · n=111"
        case .coherent:   return "lehrer 2014 · resonant-frequency breathing"
        case .energizing: return "sato et al. · biomed res 2010 · n=40 women"
        case .windDown:   return "slow-breathing sleep literature · 15-study review 2025"
        }
    }

    /// Coquette sticker accent for the picker card + the session bloom.
    var sticker: StickerName {
        switch self {
        case .calming:    return .heartGlossy
        case .coherent:   return .butterflyRing
        case .energizing: return .sparkleGlossy
        case .windDown:   return .flower3D
        }
    }

    /// End-screen ("the receipt") mechanism line — what just happened
    /// in her body, in language the evidence supports. Never metabolic
    /// claims per docs/breathwork_evidence_review_2026_06_11.md.
    var receiptLine: String {
        switch self {
        case .calming:    return "your long exhale just slowed your heart rate. that's the brake pedal."
        case .coherent:   return "your heart and breath found the same rhythm. that's the balance signal."
        case .energizing: return "your breath just woke the system back up. gently."
        case .windDown:   return "your nervous system got the day-is-done signal. let it carry you."
        }
    }
}

// MARK: - BreathOccasion
//
// v1.1 module-experience pass (2026-06-11): the intro screen asks
// "how do you want to feel?" — feeling-first selection (Othership
// pattern, per docs/breathwork_apps_teardown_2026_06_11.md) mapped
// onto the existing 3 protocols. Occasions are doorways, not new
// pacing engines.

enum BreathOccasion: String, CaseIterable, Identifiable {
    case settled   // acute stress reset — the default
    case sleepy    // evening wind-down
    case steady    // focus / racing mind
    case awake     // morning / slump

    var id: String { rawValue }

    var chipLabel: String {
        switch self {
        case .settled: return "settled"
        case .sleepy:  return "sleepy"
        case .steady:  return "steady"
        case .awake:   return "awake"
        }
    }

    var techProtocol: BreathworkProtocol {
        switch self {
        case .settled: return .calming
        case .sleepy:  return .windDown   // 4-7-8 now that holds render
        case .steady:  return .coherent
        case .awake:   return .energizing
        }
    }

    /// One quiet line under the protocol card naming the occasion's
    /// honest value. Evidence grades per the review doc — the
    /// before-bed line claims the slow-breathing sleep literature,
    /// never a 4-7-8-specific promise.
    var occasionLine: String {
        switch self {
        case .settled: return "five minutes of this lifted mood more than meditation in stanford's trial."
        case .sleepy:  return "a long exhale tells your body the day is over. slower breath before bed is linked to falling asleep faster."
        case .steady:  return "your heart and breath sync into one rhythm. racing mind slows to match."
        case .awake:   return "short equal breaths wake the system back up. before the day starts asking."
        }
    }
}
