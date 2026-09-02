import Foundation

// MARK: - PlateAnswerEngine (v25 E7 — SAY IT)
//
// THE PROBLEM THIS SOLVES
//
// A payer's median life is 2.0 active days (18_E5_EVIDENCE, n=151).
// Every intelligence E1-E6 built pays out later: the morning read on
// day N+1, the desk's line the next time she opens the chat tab. The
// one moment guaranteed to exist for every payer is the moment right
// after she puts something in — and that moment returned a receipt and
// a dismissal.
//
// This engine composes ONE sentence for that moment, from what the
// product already knows. It is the same sentence at both ends of the
// loop: the capture surface stands it under "what did you eat?" so the
// question has context, and the reading resolves to it when the plate
// files. Ask and answer in the same words.
//
// WHY PROTEIN
//
// 00_THE_SYSTEM §7.6 — of everything the literature review found,
// exactly two GLP-1 content pillars are proven: protein 1.2-2.0 g/kg
// and resistance training. Lean mass is 25-40% of drug-induced loss.
// §9 turns that into law: "protein floor + fiber lead the glance
// layer; kcal quiet." Calories are the number a user on an appetite
// suppressant needs least.
//
// THE HONESTY TABLE (each row is a unit test)
//
//   nothing on file, no floor      → nil. Never invent a start.
//   nothing on file, floor known   → the floor, stated as a fact
//   something on file, no floor    → what is on file, no denominator
//   something on file, floor known → position, and what is left
//   floor already met              → said plainly, no praise
//   this plate carried no protein  → the DAY still answers; the plate
//                                    never renders "0 g"
//
// THE REFUSALS (`00_THE_SYSTEM` §12, `docs/app_v9/00_MISSION.md` L2)
//
//   - no verdict. Never "good", "great", "too much", "not enough".
//   - no percentage. Coarse words, or the two real numbers.
//   - no number she never gave us. No weight on file → no floor →
//     no denominator, ever. TargetsService owns the floor; this engine
//     only reads it.
//   - no reprimand. A day behind its floor is stated, not scolded.
//   - lowercase, no em-dash between words, no heart, no exclamation.
//
// PURE. No stores, no clock beyond the day totals it is handed, no
// SwiftUI. Everything arrives in `Input` so the table is walkable.

enum PlateAnswerEngine {

    // MARK: - Input

    struct Input: Equatable {
        /// Grams of protein already on today's record BEFORE this
        /// plate. Callers pass the day total they render everywhere
        /// else (FoodLogPersister.todayMacros).
        var proteinOnFileG: Int = 0
        /// Grams this plate adds. nil = no plate in hand (the capture
        /// surface, standing before the question).
        var plateProteinG: Int?
        /// The resolved floor from TargetsService. nil = no weight on
        /// file, so there is no honest denominator and none renders.
        var proteinFloorG: Int?
        /// Plates already on today's record before this one.
        var platesOnFile: Int = 0
        /// The safety gate. When numerics are suppressed for this
        /// cohort no figure may render anywhere, so the engine stays
        /// silent rather than finding a wording around it.
        var numericsSuppressed: Bool = false
        /// p63 — true when the record holds NO plate at all, ever.
        /// The first thing she ever files is the record's own
        /// beginning, and the sentence marks it. A lifetime fact, so
        /// the caller reads the store, not the day.
        var isFirstPlateEver: Bool = false
    }

    // MARK: - Output

    struct Answer: Equatable {
        /// The whole sentence, for accessibility and for anywhere that
        /// wants it plain.
        var text: String
        /// The clause that carries the punch, rendered in the italic
        /// serif. Always a substring of `text`; empty = render flat.
        var punch: String
        /// p63 — true only when THIS plate carried the day across the
        /// floor (before < floor ≤ after). The one crossing a day can
        /// have; the crest haptic rides it. Restating an already-met
        /// floor is not a crossing, and a suppressed cohort (shown no
        /// floor) never crosses one.
        var floorCrossed: Bool = false
        /// p64 — true when this plate is the DAY's first (and not the
        /// record's first ever, which outranks it). The spark rides
        /// it; the sentence leads with the fact.
        var firstPlateOfDay: Bool = false
    }

    // MARK: - Before the plate (the capture surface's standing line)

    /// What today looks like BEFORE she says anything. Stands under
    /// "what did you eat?" so the question is asked in context rather
    /// than into a void. nil = there is nothing true to say yet, and
    /// nothing renders (an empty day is not "0 g").
    static func standing(_ i: Input) -> Answer? {
        guard !i.numericsSuppressed else { return nil }
        let on = max(0, i.proteinOnFileG)

        switch (on > 0, i.proteinFloorG) {
        case (false, nil):
            // No record and no floor: there is genuinely nothing to
            // say. The claim-free empty state.
            return nil
        case (false, .some(let floor)) where floor > 0:
            return Answer(
                text: "\(floor) g of protein today. nothing on the record yet.",
                punch: "\(floor) g of protein"
            )
        case (false, .some):
            return nil
        case (true, nil):
            return Answer(
                text: "\(on) g of protein so far.",
                punch: "\(on) g"
            )
        case (true, .some(let floor)) where floor > 0 && on >= floor:
            // Frame-caught: below the floor "71 of 123 g" reads as a
            // position, but at or above it "123 of 90 g" reads as a
            // typo. Once it is covered the ratio has stopped being the
            // interesting fact, so it stops being said.
            return Answer(
                text: "\(on) g of protein today, floor covered.",
                punch: "floor covered"
            )
        case (true, .some(let floor)) where floor > 0:
            return Answer(
                text: "\(on) of \(floor) g of protein so far.",
                punch: "\(on) of \(floor) g"
            )
        case (true, .some):
            return Answer(text: "\(on) g of protein so far.", punch: "\(on) g")
        }
    }

    // MARK: - After the plate (the reading's last word)

    /// What just changed. Composed the moment "add it" is tapped, in
    /// the reading's own real estate, before the plate files.
    ///
    /// Never nil: she performed an act, so something true is always
    /// available — at minimum that it is on the record.
    static func afterPlate(_ i: Input) -> Answer {
        let plate = max(0, i.plateProteinG ?? 0)
        let before = max(0, i.proteinOnFileG)
        let after = before + plate

        // p63 — the one crossing a day can have: THIS plate carried
        // the total from under the floor to at-or-over it. Restating
        // an already-met floor is not a crossing, a plate with no
        // protein cannot cross, and a suppressed cohort — shown no
        // floor — never receives a floor's celebration (§8: the
        // haptic confirms what happened visually).
        let floorG = i.proteinFloorG ?? 0
        let crossed = !i.numericsSuppressed
            && plate > 0 && floorG > 0
            && before < floorG && after >= floorG

        // p63 — the first plate EVER is the record's own beginning.
        // The sentence marks the start, then states what is true:
        // never a zero, never a numeral under suppression. Handled
        // before the suppression guard so the start is still spoken.
        if i.isFirstPlateEver {
            if i.numericsSuppressed || plate == 0 {
                return Answer(text: "your record starts here.", punch: "starts here")
            }
            if floorG > 0 {
                if after >= floorG {
                    return Answer(
                        text: "your record starts here. \(after) of \(floorG) g, floor covered.",
                        punch: "starts here",
                        floorCrossed: crossed
                    )
                }
                return Answer(
                    text: "your record starts here. \(after) of \(floorG) g of protein.",
                    punch: "starts here"
                )
            }
            return Answer(
                text: "your record starts here. \(after) g of protein.",
                punch: "starts here"
            )
        }

        // p64 — the DAY's first plate leads its answer (the founder's
        // delight brief: beginning the day is worth saying). The lead
        // is a FACT, so it repeats with the fact — the ledger rations
        // the celebration, never the words. First-ever outranks it
        // (handled above); the sentence stays numeral-free under
        // suppression and never renders a zero.
        if i.platesOnFile == 0 {
            let lead = "today's first plate."
            if i.numericsSuppressed || plate == 0 {
                return Answer(
                    text: "\(lead) on the record.",
                    punch: "first plate",
                    firstPlateOfDay: true
                )
            }
            if let floor = i.proteinFloorG, floor > 0 {
                if after >= floor {
                    return Answer(
                        text: "\(lead) \(after) of \(floor) g, floor covered.",
                        punch: "floor covered",
                        floorCrossed: crossed,
                        firstPlateOfDay: true
                    )
                }
                return Answer(
                    text: "\(lead) \(after) of \(floor) g of protein.",
                    punch: "first plate",
                    firstPlateOfDay: true
                )
            }
            return Answer(
                text: "\(lead) \(after) g of protein.",
                punch: "first plate",
                firstPlateOfDay: true
            )
        }

        // The safety gate outranks everything: no figure renders.
        guard !i.numericsSuppressed else {
            return Answer(text: "on the record.", punch: "on the record")
        }

        // A plate with no macro detail (a described drink, a scan that
        // could not resolve). Never "0 g" — the day answers instead.
        guard plate > 0 else {
            if let floor = i.proteinFloorG, floor > 0, before > 0 {
                return Answer(
                    text: "on the record. \(before) of \(floor) g of protein today.",
                    punch: "\(before) of \(floor) g"
                )
            }
            if before > 0 {
                return Answer(
                    text: "on the record. \(before) g of protein today.",
                    punch: "\(before) g"
                )
            }
            return Answer(text: "on the record.", punch: "on the record")
        }

        // No floor on file: state the two numbers we actually have.
        guard let floor = i.proteinFloorG, floor > 0 else {
            if before > 0 {
                return Answer(
                    text: "\(plate) g of protein. \(after) g today.",
                    punch: "\(plate) g of protein"
                )
            }
            return Answer(
                text: "\(plate) g of protein, on the record.",
                punch: "\(plate) g of protein"
            )
        }

        // The floor is known. Position, then what is left — stated,
        // never graded.
        if after >= floor {
            // Met. Said once, plainly. No praise, no exclamation: the
            // number is the whole point and congratulation would make
            // the next day's shortfall a failure by contrast. The
            // CROSSING itself is marked so the crest haptic can ride
            // this exact plate — words stay level, the hand feels it.
            return Answer(
                text: "\(plate) g of protein. that's \(after) of \(floor) g, floor covered.",
                punch: "floor covered",
                floorCrossed: crossed
            )
        }

        let left = floor - after
        // "one more plate" only when a plate this size would close it —
        // otherwise it is a promise the arithmetic does not support.
        if plate >= left {
            return Answer(
                text: "\(plate) g of protein. \(after) of \(floor) g. one more like that closes it.",
                punch: "one more like that closes it"
            )
        }
        return Answer(
            text: "\(plate) g of protein. \(after) of \(floor) g, \(left) g to go.",
            punch: "\(left) g to go"
        )
    }

    // MARK: - The refusal set (pinned by tests, not by hope)
    //
    // Every word this engine may never emit. `banned` is asserted
    // against the full cross-product of the honesty table, so a future
    // copy edit that reaches for praise or blame fails the suite
    // rather than shipping.

    static let bannedWords: [String] = [
        // verdicts, warm and cold alike
        "good", "great", "amazing", "perfect", "well done", "nice",
        "bad", "poor", "terrible", "wrong", "failed", "failure",
        // grades and shame
        "should", "shouldn't", "too much", "too many", "not enough",
        "over", "behind", "missed", "slipped", "guilty", "cheat",
        // the banned register
        "burn", "earn", "deficit", "shred", "crush",
        // never a claim we cannot back
        "%", "percent",
    ]
}
