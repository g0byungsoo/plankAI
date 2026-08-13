import Foundation

// MARK: - JeniDeskAwareness (v25 E6 — THE DESK)
//
// The desk's resting state used to say "your coach, day to day." — a
// CLAIM, in the one place a person looks before deciding whether jeni
// is worth talking to. E3 gave her eight read tools over the same
// engines every surface renders from; the desk exposed none of it at
// rest, so the most capable thing about her was invisible until you
// typed something.
//
// This replaces the claim with a PROOF, in the same real estate: one
// line of what she already has on file. No new buttons, no card, no
// information dumped into a message. The smallest interaction model
// that makes jeni feel aware of the rest of the product.
//
// Honesty rules (the reason this is an engine and not a string in a
// view):
//   · nothing on file → the claim, never invented proof
//   · every number traces to a collected field (provenance law)
//   · a gap is stated warmly and never as a reprimand — guilt
//     re-engagement is a named banned anti-loop (00_THE_SYSTEM §12)
//   · lowercase register, no em-dash, no hearts

struct JeniAwarenessLine: Equatable {
    let text: String
    /// True when the line is drawn from her record. False = the
    /// fallback claim, which is all the desk may say on an empty day.
    let isProof: Bool
}

enum JeniDeskAwareness {

    struct Input: Equatable {
        var plates: Int = 0
        var proteinEatenG: Int = 0
        var weighedToday: Bool = false
        var daysSinceLastOpen: Int = 0
        var isCareConnected: Bool = false
        /// YESTERDAY, because a record does not begin at midnight.
        var yesterdayPlates: Int = 0
        var yesterdayProteinG: Int = 0
        /// Distinct days with at least one plate, all-time. The record's
        /// depth, which is the one thing about it that only grows.
        var daysOnFile: Int = 0
    }

    static func compose(_ i: Input) -> JeniAwarenessLine {

        // A return after a gap outranks the day's contents: it is the
        // most true thing about this moment, and saying it plainly is
        // what keeps it from being a guilt trip.
        if i.daysSinceLastOpen >= 2, i.plates == 0, !i.weighedToday {
            return JeniAwarenessLine(
                text: "it's been \(i.daysSinceLastOpen) days. your record is where you left it.",
                isProof: true
            )
        }

        if i.plates > 0 {
            let plateWord = i.plates == 1 ? "1 plate" : "\(i.plates) plates"
            // Protein only speaks when it is a real reading. A plate
            // logged with no macro detail must not render "0 g".
            if i.proteinEatenG > 0 {
                return JeniAwarenessLine(
                    text: "\(plateWord) and \(i.proteinEatenG) g of protein, on file.",
                    isProof: true
                )
            }
            return JeniAwarenessLine(
                text: "\(plateWord) on file today.",
                isProof: true
            )
        }

        if i.weighedToday {
            return JeniAwarenessLine(
                text: "your weigh-in is on file today.",
                isProof: true
            )
        }

        // THE RECORD DOES NOT BEGIN AT MIDNIGHT.
        //
        // E6 replaced the desk's tagline with proof, and scoped the
        // proof to TODAY — which is the one window most likely to be
        // empty at the moment somebody opens the app. So a payer with a
        // twelve-day record who opened jeni at 9am read "your coach, day
        // to day.": the same sentence as a person who has never logged
        // anything. Every morning, the most capable thing about her
        // reset to a claim.
        //
        // Yesterday first — the most recent thing that is true — then
        // the record's depth. Both come off the same store the reads
        // use, and both are silent when there is genuinely nothing.
        if i.yesterdayPlates > 0 {
            let plateWord = i.yesterdayPlates == 1
                ? "1 plate" : "\(i.yesterdayPlates) plates"
            if i.yesterdayProteinG > 0 {
                return JeniAwarenessLine(
                    text: "yesterday: \(plateWord) and \(i.yesterdayProteinG) g of protein.",
                    isProof: true
                )
            }
            return JeniAwarenessLine(
                text: "yesterday: \(plateWord) on file.",
                isProof: true
            )
        }

        // A single logged day is not depth, so the line waits for two.
        if i.daysOnFile >= 2 {
            return JeniAwarenessLine(
                text: "your record has \(i.daysOnFile) days in it.",
                isProof: true
            )
        }

        // Nothing on the record yet. The claim, unchanged — including
        // the E4 G9 care gate ("between visits" implies clinician
        // visits, true only for connected patients).
        return JeniAwarenessLine(
            text: i.isCareConnected
                ? "your coach between visits."
                : "your coach, day to day.",
            isProof: false
        )
    }
}
