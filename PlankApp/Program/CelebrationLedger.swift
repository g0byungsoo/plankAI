import Foundation

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
}

// MARK: - PlateCelebration (the answer's celebration, claimed once)
//
// Maps a composed plate answer to the burst it carries, in priority
// order — one celebration per commit, the biggest fact wins:
//
//   first plate EVER  → "moment"  (once per lifetime by derivation)
//   the floor CROSSING → "crest"  (once per day by construction)
//   first plate TODAY  → "spark"  (once per day via the ledger —
//                        the words repeat with the fact, the burst
//                        does not; delete-all-then-relog answers
//                        with the sentence alone)
//
// `claim` STAMPS the ledger when it grants the spark — call it once
// per commit, at compose time (the same instant the p63 crest is
// decided). A claim spent on a plate whose persist later fails is a
// known, accepted edge (the p63 first-ever sentence shares it).

enum PlateCelebration {
    static func claim(
        answer: PlateAnswerEngine.Answer,
        isFirstEver: Bool,
        dayKey: String,
        defaults: UserDefaults = .standard
    ) -> String? {
        if isFirstEver { return "moment" }
        if answer.floorCrossed { return "crest" }
        if answer.firstPlateOfDay,
           CelebrationLedger.shouldCelebrate(
               .firstPlateToday, dayKey: dayKey, defaults: defaults
           ) {
            CelebrationLedger.recordCelebrated(
                .firstPlateToday, dayKey: dayKey, defaults: defaults
            )
            return "spark"
        }
        return nil
    }
}
