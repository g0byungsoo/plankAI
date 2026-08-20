import Foundation

// MARK: - EveningCloseEngine (v25 E8 — THE MERGE)
//
// The evening close used to say this, every night, to everyone:
//
//     "that's the day, maya."
//     "tomorrow: a balanced day."
//
// Two sentences carrying no information. The first is a full stop with
// a name in it. The second is an archetype label computed from
// `programDay + 1` — a fact about the SCHEDULE, not about her.
// Meanwhile the same snapshot three inches below held the plates, the
// protein, the beats and the trend.
//
// This is the defect E6 fixed on the desk ("your coach, day to day." →
// "4 plates and 123 g of protein, on file.") and E7 fixed in the
// reading, still standing on the surface a returning payer meets every
// evening. Same fix, same laws:
//
//   - PROOF, NEVER A CLAIM. Every number comes from her record. Nothing
//     on file produces no proof — it never invents one.
//   - PROTEIN LEADS (`00_THE_SYSTEM` §9), kcal stays quiet.
//   - NO DENOMINATOR WITHOUT A FLOOR (E7). And once the floor is met the
//     ratio stops being the interesting fact, so it stops being said —
//     "123 of 90 g" read as a typo (E7 §6.6).
//   - NEVER "0 g". An absent number is absent, not zero (E6).
//   - NO VERDICT. No praise, no blame, no score. A quiet day is stated
//     warmly and never scolded.
//   - SUPPRESSION HOLDS. `numericsSuppressed` yields words only.
//
// Pure and table-driven so the honesty rules are testable without a
// view, a store or a snapshot.

enum EveningCloseEngine {

    // MARK: - Input

    struct Input {
        var name: String = ""
        /// Protein grams eaten today. 0 means none recorded.
        var proteinEatenG: Int = 0
        /// The day's protein floor, nil when no weight is on file.
        var proteinFloorG: Int?
        var plateCount: Int = 0
        var beatsDone: Int = 0
        var beatsTotal: Int = 0
        var weighedInToday: Bool = false
        var numericsSuppressed: Bool = false
        /// v25 E8 — the medication adequacy net ("did you eat enough? a
        /// gentle plate still counts") already owns the very-light day
        /// with a gentler line. The protein close must not speak over
        /// it: two prompts about the same gap, one of them counting
        /// grams, is exactly the pile-on this cohort must not get.
        var adequacyNetShowing: Bool = false
        var tomorrow: ProgramDayArchetype = .balanced
        /// E8.2 — the anchor inputs: a line about tomorrow renders only
        /// when tomorrow actually holds something of hers.
        var tomorrowIsDoseDay: Bool = false
        var tomorrowIsWeighDay: Bool = false
        /// Weighing is "adopted" once any weigh-in exists — the scale
        /// cue is an invitation to a habit she has shown, never an
        /// assignment to one she hasn't.
        var weighAdopted: Bool = false

        init(
            name: String = "",
            proteinEatenG: Int = 0,
            proteinFloorG: Int? = nil,
            plateCount: Int = 0,
            beatsDone: Int = 0,
            beatsTotal: Int = 0,
            weighedInToday: Bool = false,
            numericsSuppressed: Bool = false,
            adequacyNetShowing: Bool = false,
            tomorrow: ProgramDayArchetype = .balanced,
            tomorrowIsDoseDay: Bool = false,
            tomorrowIsWeighDay: Bool = false,
            weighAdopted: Bool = false
        ) {
            self.name = name
            self.proteinEatenG = proteinEatenG
            self.proteinFloorG = proteinFloorG
            self.plateCount = plateCount
            self.beatsDone = beatsDone
            self.beatsTotal = beatsTotal
            self.weighedInToday = weighedInToday
            self.numericsSuppressed = numericsSuppressed
            self.adequacyNetShowing = adequacyNetShowing
            self.tomorrow = tomorrow
            self.tomorrowIsDoseDay = tomorrowIsDoseDay
            self.tomorrowIsWeighDay = tomorrowIsWeighDay
            self.weighAdopted = weighAdopted
        }
    }

    /// One sentence. `punch` marks the words the moment sets in italic.
    struct Line: Equatable {
        let text: String
        let punch: [String]
    }

    /// E8.2 — the record row: numbers live HERE, never in the prose.
    /// (E8 put the numbers in the prose and de-duped the ledger; the
    /// founder's read of the result — "the text looks ugly and doesn't
    /// add value" — agrees with SMARTER's null on narrating a record
    /// the ledger already states. One place for facts, one for meaning.)
    struct LedgerRow: Equatable {
        let label: String
        let value: String
    }

    /// E8.2 — the drafted tomorrow intention. Implementation intentions
    /// are the strongest replicated lever this screen can hold
    /// (Gollwitzer & Sheeran 2006, d=0.65 overall; ~d=0.33 in dietary
    /// promotion), and the canonical form is if-then specific and
    /// accepted, not composed: one tap, never typed. Drafted ONLY when
    /// tonight's record gives it a reason (a gap night); on a floor-met
    /// night the close asks for nothing.
    struct Intention: Equatable {
        let key: String
        let text: String
        let punch: [String]
    }

    struct Close: Equatable {
        /// The one sentence of meaning: the protein close on a gap
        /// night (the only line that can change TODAY), one quiet
        /// confirmation otherwise. Never education as a fixture.
        let hero: Line
        /// The record, as right-aligned facts. Empty rows never render.
        let ledger: [LedgerRow]
        /// The one-tap tomorrow plan, when tonight earned one.
        let intention: Intention?
        /// Tomorrow's real anchor (dose day > adopted scale morning),
        /// or nothing. A schedule label is not an anchor.
        let anchor: String?
    }

    // MARK: - The engine

    static func close(_ input: Input) -> Close {
        Close(
            hero: heroLine(input),
            ledger: ledger(input),
            intention: intention(input),
            anchor: anchor(input)
        )
    }

    // MARK: - THE PROTEIN CLOSE (v25 E8, expert review)
    //
    // The defect the review named: this screen made up to seven asks and
    // paid out once, and every payout landed on day N+1 — tomorrow's
    // shape, smaller plates tomorrow, fiber tomorrow — on a base whose
    // median payer lives 2.0 active days. E7 named that pattern and
    // fixed it in the reading; the evening is where it survived.
    //
    // This is the only sentence on the screen that can still change
    // TODAY. Two mechanisms, and the second is the one that matters:
    //
    //   1. Feedback that points at the next ACTION beats feedback that
    //      points at the self (Kluger & DeNisi 1996 — a large minority
    //      of feedback interventions make performance WORSE, and
    //      self-directed feedback is the variety that does). The screen
    //      was entirely the self-directed kind.
    //   2. On a GLP-1 the gap is INVISIBLE to her. Ad-lib energy intake
    //      falls sharply on semaglutide, so she is not hungry and has no
    //      internal signal that she is 30 g short. This is the clearest
    //      case in the product for a number a person cannot feel.
    //
    // The named foods are deliberately the cold / soft / low-odor set:
    // delayed gastric emptying makes warm, rich, large food the worst
    // answer for this cohort, and that same list is the nausea-safe one.
    // One list serves the full stomach and the queasy one, so this needs
    // no branching.
    //
    // Guards, all load-bearing: no floor on file → no line at all (E7's
    // law); floor met → no gap, one honest sentence; a very large gap is
    // never named as a demand, because an impossible ask reads as shame;
    // suppression yields words only.
    static func proteinCloseLine(_ input: Input) -> Line? {
        guard !input.adequacyNetShowing else { return nil }
        guard let floor = input.proteinFloorG, floor > 0 else { return nil }
        let gap = floor - input.proteinEatenG

        if input.numericsSuppressed {
            guard gap > 0 else { return nil }
            return Line(text: "there is still time tonight, if you're up for something.",
                        punch: ["still time tonight,"])
        }

        guard gap > 0 else {
            // The floor landed. One quiet confirmation — the education
            // tail this used to carry ("…holds the muscle while the
            // weight moves") is a MethodNote's job, delivered once with
            // provenance, not a fixture recited every met night
            // (education appears in 5 of 35 weight JITAIs; nightly
            // commentary on a good record added nothing in SMARTER).
            return Line(
                text: "protein landed. the day is on file.",
                punch: ["protein landed."]
            )
        }

        switch gap {
        case ...25:
            return Line(
                text: "there is still time tonight. \(gap) g would close it, and a cup of greek yogurt is about that.",
                punch: ["still time tonight."]
            )
        case 26...40:
            return Line(
                text: "there is still time tonight. a shake or a cup of cottage cheese is about half of what's left.",
                punch: ["still time tonight."]
            )
        default:
            // Never name the whole number here. At this size the gap is
            // not a target, it is a rebuke.
            return Line(
                text: "there is still time tonight. anything with protein in it helps, even something small.",
                punch: ["still time tonight."]
            )
        }
    }

    // MARK: - The hero: one sentence of meaning

    static func heroLine(_ input: Input) -> Line {
        let name = input.name
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        // The adequacy net owns the very-light medicated day with its
        // own gentler question in the view; the hero stays soft and
        // never counts grams at her.
        if input.adequacyNetShowing {
            return Line(text: "a light day. what's on file still counts.",
                        punch: ["light day."])
        }

        // The protein close (gap) or its met confirmation.
        if let close = proteinCloseLine(input) { return close }

        // No floor on file. The record still closes.
        if input.plateCount > 0 || input.proteinEatenG > 0 {
            return Line(text: "the day is on file.", punch: ["on file."])
        }
        if input.beatsDone > 0 {
            return Line(text: "the plan carried the day.", punch: ["carried"])
        }
        if input.weighedInToday {
            return Line(text: "you weighed in. that's the day's record.",
                        punch: ["weighed in."])
        }
        return quietDay(name)
    }

    /// Nothing on file. Stated warmly, never as a reprimand, and never
    /// with a fabricated number. E6's gap law. Rough-night register per
    /// the self-compassion evidence (Adams & Leary 2007): the goal
    /// survives the day, the day is not a verdict on it.
    private static func quietDay(_ name: String) -> Line {
        name.isEmpty
            ? Line(text: "a quiet day. it still counts.", punch: ["quiet day."])
            : Line(text: "a quiet day, \(name). it still counts.",
                   punch: ["quiet day,"])
    }

    // MARK: - The ledger: the record as facts

    static func ledger(_ input: Input) -> [LedgerRow] {
        var rows: [LedgerRow] = []
        // Suppression: no gram or body numerals, ever. Plan counts are
        // behavioral and stay.
        if !input.numericsSuppressed {
            switch input.plateCount {
            case ..<1: break
            case 1:    rows.append(LedgerRow(label: "plates", value: "one"))
            default:   rows.append(LedgerRow(label: "plates", value: "\(input.plateCount)"))
            }
            let g = input.proteinEatenG
            if g > 0 {
                if let floor = input.proteinFloorG, floor > 0 {
                    rows.append(LedgerRow(
                        label: "protein",
                        value: g >= floor ? "\(g) g · floor met" : "\(g) of \(floor) g"
                    ))
                } else {
                    rows.append(LedgerRow(label: "protein", value: "\(g) g"))
                }
            }
        }
        if input.beatsTotal > 0, input.beatsDone > 0 {
            rows.append(LedgerRow(
                label: "the plan",
                value: "\(input.beatsDone) of \(input.beatsTotal)"
            ))
        }
        if input.weighedInToday {
            rows.append(LedgerRow(label: "weigh-in", value: "on file"))
        }
        return rows
    }

    // MARK: - The intention: tomorrow, drafted tonight

    static func intention(_ input: Input) -> Intention? {
        guard !input.adequacyNetShowing,
              let floor = input.proteinFloorG, floor > 0,
              input.proteinEatenG < floor
        else { return nil }
        if input.numericsSuppressed {
            return Intention(
                key: "breakfast_protein",
                text: "tomorrow at breakfast: protein first, before anything else.",
                punch: ["protein first,"]
            )
        }
        // The per-meal dose, from her own floor spread across three
        // meals (the 2025 GLP-1 advisory's 0.3-0.4 g/kg per meal lands
        // in the same band), clamped to a breakfast a person can eat.
        let mealG = max(20, min(40, floor / 3))
        return Intention(
            key: "breakfast_protein",
            text: "tomorrow at breakfast: \(mealG) g of protein, before anything else.",
            punch: ["\(mealG) g of protein,"]
        )
    }

    // MARK: - The anchor: tomorrow, only when it holds something

    static func anchor(_ input: Input) -> String? {
        if input.tomorrowIsDoseDay {
            return "tomorrow is your dose day. the week starts there."
        }
        if input.tomorrowIsWeighDay, input.weighAdopted,
           !input.numericsSuppressed {
            return "a scale morning, if you want it. it reads the week, not one night."
        }
        return nil
    }

    // MARK: - The sit-check acknowledgment (p54: out of the view body)
    //
    // Clinical register (founder refinement): the symptom stream
    // acknowledges as fact — no hearts, no reward vocabulary. v25 E8
    // (expert review): every one of these used to end in "tomorrow",
    // at the exact moment she said she felt bad; GI symptoms are the
    // leading reason people stop these medicines, and the moment of
    // the complaint is the only moment the help is wanted.
    //
    // p54 — moved here from `HomeEvening`'s body (the §36 law: advice
    // in a view body is a rule nothing can test), and the queasy line
    // rewritten on the evidence: "cold and plain sits easier than
    // warm and rich" was the pregnancy-nausea odor folklore wearing a
    // clinical voice — the 2025 joint advisory's actual guidance is
    // smaller, plainer, lower-fat meals. The backed-up line stands:
    // fluid with fiber and movement are consensus first-line, and no
    // volume is named (the E9 law).
    static func sitAck(_ word: String) -> String {
        switch word {
        case "heavy": return "noted. staying upright a while tends to help"
        case "queasy": return "noted. small, plain and low-fat tends to sit easier"
        case "backed up": return "noted. water tonight. fiber and a walk tomorrow"
        default: return "noted"
        }
    }
}
