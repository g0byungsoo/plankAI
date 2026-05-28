import Foundation

// MARK: - JenisNoteTemplate
//
// Pure-function templating for the daily "from jeni" note on HomeView.
// Per docs/product_direction_2026.md §8.3 — every line is templated
// from already-collected data (no fabricated stats, no AI inference).
// Phase A.0 ships with ~6 cases that read as variety; Phase D swaps the
// internals for an LLM under the hood with the same output surface, so
// the user's mental model of "jeni shows up" never changes.
//
// Returns nil when there's nothing meaningful to say — caller hides the
// card on those days rather than faking warmth.
//
// Voice rules per §4: lowercase casual, italic-Fraunces on punch words
// only, hearts as terminal punctuation only, no em-dashes, no AI tells,
// no Replika-style affirmations. Direction-giving > validation.

struct JenisNote {
    let body: String
    let italicTerms: [String]
}

enum JenisNoteTemplate {

    /// Compose today's note from observable signals. All inputs are
    /// optional/defaulted; the function gracefully degrades.
    ///
    /// - Parameters:
    ///   - name: first name, lowercased on display. May be empty.
    ///   - sessionsToday: count of completed workouts today (already
    ///     filtered to today's calendar day).
    ///   - lastSessionDate: timestamp of the most recent completed
    ///     workout. Nil = never completed one.
    ///   - identityFeeling: the user's Q140 answer (powerful / calm /
    ///     light / strong / radiant / "").
    ///   - now: clock injection for testing.
    static func compose(
        name: String,
        sessionsToday: Int,
        lastSessionDate: Date?,
        identityFeeling: String,
        now: Date = .now
    ) -> JenisNote? {
        let greet = greeting(name: name, now: now)

        // Already did today's workout — celebration note.
        if sessionsToday > 0 {
            return JenisNote(
                body: "\(greet). you already did today's. that's the work.",
                italicTerms: ["you already did today's"]
            )
        }

        let cal = Calendar.current
        let daysSinceLast: Int? = {
            guard let last = lastSessionDate else { return nil }
            let lastDay = cal.startOfDay(for: last)
            let today   = cal.startOfDay(for: now)
            return cal.dateComponents([.day], from: lastDay, to: today).day
        }()

        // First-ever day — no sessions yet. Anchor to identity feeling
        // when present, otherwise stay neutral.
        if daysSinceLast == nil {
            if let phrase = identityPhrase(identityFeeling) {
                return JenisNote(
                    body: "\(greet). day 1. small step today toward \(phrase).",
                    italicTerms: ["day 1", phrase]
                )
            }
            return JenisNote(
                body: "\(greet). day 1. one thing at a time.",
                italicTerms: ["day 1"]
            )
        }

        // Yesterday: continuation note.
        if daysSinceLast == 1 {
            return JenisNote(
                body: "\(greet). yesterday counted. today we keep going.",
                italicTerms: ["yesterday counted"]
            )
        }

        // 2-3 day gap: gentle re-engage.
        if let gap = daysSinceLast, gap >= 2 && gap <= 3 {
            return JenisNote(
                body: "\(greet). been a couple days. let's pick it back up gently.",
                italicTerms: ["gently"]
            )
        }

        // 4+ day gap: warm return, asymmetric care (no shame).
        if let gap = daysSinceLast, gap >= 4 {
            return JenisNote(
                body: "welcome back, \(name.isEmpty ? "you" : name.lowercased()). i saved your spot. ♥",
                italicTerms: ["saved your spot"]
            )
        }

        // Same-day fallback (e.g. opened twice today, before workout).
        return JenisNote(
            body: "\(greet). i'm here when you are.",
            italicTerms: []
        )
    }

    // MARK: - Helpers

    private static func greeting(name: String, now: Date) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let timeOfDay: String
        switch hour {
        case 5..<12:  timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        default:      timeOfDay = "evening"
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? timeOfDay : "\(timeOfDay), \(trimmed.lowercased())"
    }

    /// Maps identityFeeling raw values to a noun phrase that can follow
    /// "toward ___". Returns nil if unset so the caller drops the line.
    private static func identityPhrase(_ feeling: String) -> String? {
        switch feeling {
        case "powerful": return "feeling powerful"
        case "calm":     return "feeling calm"
        case "light":    return "feeling lighter"
        case "strong":   return "feeling strong"
        case "radiant":  return "feeling radiant"
        default:         return nil
        }
    }
}
