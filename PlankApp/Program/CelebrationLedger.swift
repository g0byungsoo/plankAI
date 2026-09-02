import Foundation
import PlankFood

// MARK: - CelebrationLedger (p64 — THE DELIGHT LAYER)
//
// The eligibility half of the celebration system: WHETHER a moment
// celebrates is domain logic, decided here, once — never an `if
// firstMeal { confetti = true }` scattered through views.
//
// The contract:
//   · a celebration corresponds to a MEANINGFUL EVENT, not to a
//     SwiftUI render. Every moment latches once per civil day; undo
//     then redo inside one day answers with the quiet settle, never
//     a second burst (adversarial: double-tap, unmark/remark,
//     delete-all-then-log-again all land here).
//   · the ledger gates the CELEBRATION (burst + spark haptic), never
//     the words — facts are repeatable, delight is rationed.
//   · keys live under the "celebration." prefix and are swept at
//     sign-out with the other same-day surface gates (§38 — A's
//     spent spark must not eat B's first one).
//
// Pure over an injected UserDefaults so the rules are testable.

enum CelebrationMoment: String, CaseIterable {
    /// Water marked done on Home (explicit tap).
    case waterDone = "water_done"
    /// The step goal crossed while she watched (automatic fact,
    /// visual acknowledgment only — a passive event never vibrates).
    case stepsGoal = "steps_goal"
    /// The day's first plate landing (explicit commit).
    case firstPlateToday = "first_plate_today"
    /// The move record meeting the weekly strength ask.
    case moveAskMet = "move_ask_met"
    /// p65 — the record's first plate EVER (once per lifetime; a
    /// LIFETIME latch, so deleting every plate and re-logging repeats
    /// the sentence — a fact — never the moment page).
    case firstPlateEver = "first_plate_ever"
}

enum CelebrationLedger {
    static let keyPrefix = "celebration."

    static func key(_ moment: CelebrationMoment) -> String {
        keyPrefix + moment.rawValue + ".dayKey"
    }

    /// True when this moment has not yet celebrated today.
    static func shouldCelebrate(
        _ moment: CelebrationMoment,
        dayKey: String,
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.string(forKey: key(moment)) != dayKey
    }

    /// Stamp the moment as celebrated for the day. Call at the
    /// instant the celebration actually plays.
    static func recordCelebrated(
        _ moment: CelebrationMoment,
        dayKey: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(dayKey, forKey: key(moment))
    }

    // p65 — the LIFETIME latch (first plate ever). Same swept
    // `celebration.` prefix, so account B's first moment is never
    // eaten by account A's — and a returning account's hydrate makes
    // the derivation false anyway (the record is no longer empty).

    static func shouldCelebrateOnce(
        _ moment: CelebrationMoment,
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.string(forKey: key(moment)) == nil
    }

    static func recordCelebratedOnce(
        _ moment: CelebrationMoment,
        defaults: UserDefaults = .standard
    ) {
        defaults.set("lifetime", forKey: key(moment))
    }
}

// MARK: - PlateMomentClaim (p65 — THE MOMENT SYSTEM)
//
// Maps a filed plate's answer to the full-page moment it earned, in
// priority order — ONE moment per commit, the biggest fact wins:
//
//   first plate EVER   → "moment" tier (once per LIFETIME — latched,
//                        so delete-all-then-relog repeats the
//                        sentence, never the page)
//   the floor CROSSING → "crest" tier  (once per day by construction)
//   first plate TODAY  → "spark" tier  (once per day via the ledger)
//
// Called AFTER the persist succeeded (p65's reorder — a celebration
// may never outrun the record) and STAMPS its latch at claim time,
// which is now the same breath as presentation.
//
// The page's words are the engine's own answer, re-seated: the
// headline is the sentence's lead, the fact is the rest. One sentence
// authority — the splits are pinned against the engine's shapes by
// DelightTests, so a copy edit there fails here instead of drifting.
//
// NEVER a moment (the standing boundary): eating less, calories
// left, weight numbers, streaks, suppressed-cohort numerals, dose.
// An ordinary later plate keeps its in-place receipt.

enum PlateMomentClaim {

    static func claim(
        answer: PlateAnswerEngine.Answer,
        isFirstEver: Bool,
        dayKey: String,
        defaults: UserDefaults = .standard
    ) -> FoodModule.PlateMoment? {
        if isFirstEver,
           CelebrationLedger.shouldCelebrateOnce(.firstPlateEver, defaults: defaults) {
            CelebrationLedger.recordCelebratedOnce(.firstPlateEver, defaults: defaults)
            return FoodModule.PlateMoment(
                occasion: CelebrationMoment.firstPlateEver.rawValue,
                eyebrow: nil,
                headline: "nice. your first plate, logged.",
                punch: "first plate",
                fact: strippingLead("nice. your first plate, logged.", from: answer.text),
                tier: "moment"
            )
        }
        if answer.floorCrossed {
            // p67 — the crest is the day's one peak, and it carries
            // the day's one line of praise (once a day by the
            // crossing's own construction, so it stays meant).
            // p68 — said the way a person would say it: "protein goal
            // hit." + "23 g of protein. that's 122 of 120 g. nice
            // work." read as three number clauses in a row. The
            // headline is a sentence now, and the fact states the DAY
            // (the plate's own grams were just read on the result
            // page).
            return FoodModule.PlateMoment(
                occasion: "floor_crossing",
                eyebrow: nil,
                headline: "you hit your protein goal.",
                punch: "protein goal",
                fact: crestFact(from: answer.text),
                tier: "crest"
            )
        }
        if answer.firstPlateOfDay,
           CelebrationLedger.shouldCelebrate(
               .firstPlateToday, dayKey: dayKey, defaults: defaults
           ) {
            CelebrationLedger.recordCelebrated(
                .firstPlateToday, dayKey: dayKey, defaults: defaults
            )
            return FoodModule.PlateMoment(
                occasion: CelebrationMoment.firstPlateToday.rawValue,
                eyebrow: nil,
                headline: "today's first plate.",
                punch: "first plate",
                fact: strippingLead("today's first plate.", from: answer.text),
                tier: "spark"
            )
        }
        return nil
    }

    /// The answer minus the lead the headline already speaks
    /// ("nice. your first plate, logged. 34 of 120 g." →
    /// "34 of 120 g."). nil when nothing but the lead was said.
    static func strippingLead(_ lead: String, from text: String) -> String? {
        guard text.hasPrefix(lead) else { return text }
        let rest = text.dropFirst(lead.count)
            .trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? nil : rest
    }

    /// The answer minus its crossing clause — the headline speaks it
    /// ("23 g of protein. that's 122 of 120 g, goal hit." →
    /// "23 g of protein. that's 122 of 120 g.").
    static func strippingCrossingClause(from text: String) -> String? {
        let rest = text.replacingOccurrences(of: ", goal hit.", with: ".")
        return rest.isEmpty ? nil : rest
    }

    /// p68 — the crest page's fact states where the DAY landed, in one
    /// clause ("122 of 120 g today. nice work."). A first plate that
    /// crosses keeps both facts on the one page (the p65 law); any
    /// unexpected shape falls back to the stripped sentence so the
    /// page never goes silent.
    static func crestFact(from text: String) -> String? {
        if text.hasPrefix("today's first plate.") {
            return strippingCrossingClause(from: text).map { $0 + " nice work." }
        }
        if let r = text.range(
            of: #"that's \d+ of \d+ g, goal hit\."#,
            options: .regularExpression
        ) {
            let clause = String(text[r])
                .replacingOccurrences(of: "that's ", with: "")
                .replacingOccurrences(of: ", goal hit.", with: "")
            return "\(clause) today. nice work."
        }
        return strippingCrossingClause(from: text).map { $0 + " nice work." }
    }
}
