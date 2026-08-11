import Foundation

// MARK: - JeniAffirmations
//
// The launch loader's 7-line dayOfYear rotation. Extracted from
// PlanView.swift at its v2.6 retirement — the loader outlives the
// legacy screen that hosted this.

// MARK: - JeniAffirmations
//
// Single source of truth for the her75 affirmation pool + the
// time-of-day greeting. Shared by the launch `AffirmationLoaderScreen`
// and the `DailyReturnRitual` so the same calendar day shows the SAME
// line in both — the loader's quick beat is a deliberate callback to
// the ritual's fuller moment, never a second unrelated line. dayOfYear-
// indexed so the line feels chosen, never random.
enum JeniAffirmations {
    struct Line {
        let leading: String   // regular roman
        let italic: String    // JeniHeroSerif-Italic punch word
        let trailing: String  // regular roman
        /// Full sentence as one string (for ItalicAccentText).
        var base: String { leading + italic + trailing }
        var italicWords: [String] { [italic] }
    }

    // The Jeni release voice pass (1.2.0): the pool speaks product
    // truths in the calm register — clear, precise, quietly
    // confident. The old-brand poetics ("becoming yourself", "soft is
    // strong") retired with the rebrand; every line that remains is
    // something the app can stand behind literally.
    static let all: [Line] = [
        Line(leading: "your ",     italic: "timeline", trailing: " is yours."),
        Line(leading: "begin ",    italic: "again",    trailing: ", anytime."),
        Line(leading: "small ",    italic: "choices",  trailing: " stack."),
        Line(leading: "the ",      italic: "trend",    trailing: " matters. the day doesn't."),
        Line(leading: "",          italic: "steady",   trailing: " is a pace."),
        Line(leading: "it adds up ", italic: "quietly", trailing: "."),
        Line(leading: "built for ", italic: "real",    trailing: " days."),
    ]

    /// Same line for the whole calendar day — intentional, not random.
    static func today(_ date: Date = Date()) -> Line {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let idx = (day - 1) % all.count
        return all[max(0, idx)]
    }

    /// Time-of-day greeting. The late-night bucket is deliberately
    /// non-judgmental ("still here,") — anti-shame voice, never "up late?".
    static func greeting(for date: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12:  return "good morning,"
        case 12..<17: return "good afternoon,"
        case 17..<22: return "good evening,"
        default:      return "still here,"
        }
    }
}
