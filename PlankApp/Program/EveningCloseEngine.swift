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
            tomorrow: ProgramDayArchetype = .balanced
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
        }
    }

    /// Two sentences. `punch` marks the words the moment sets in italic.
    struct Line: Equatable {
        let text: String
        let punch: [String]
    }

    struct Close: Equatable {
        let today: Line
        let tomorrow: Line
    }

    // MARK: - The engine

    static func close(_ input: Input) -> Close {
        Close(
            today: todayLine(input),
            tomorrow: proteinCloseLine(input) ?? tomorrowLine(input)
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
            // The floor landed. Say why it mattered, once, without praise.
            return Line(
                text: "protein landed. that is the part that holds the muscle while the weight moves.",
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

    // MARK: - Line 1: what today actually was

    static func todayLine(_ input: Input) -> Line {
        let name = input.name
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        // Suppression: words only, never a numeral.
        if input.numericsSuppressed {
            return input.plateCount > 0 || input.beatsDone > 0
                ? Line(text: "today is on file.", punch: ["file."])
                : quietDay(name)
        }

        let protein = proteinPhrase(input)
        let plates = platePhrase(input)

        // Protein leads whenever it can speak.
        if let protein {
            if let plates {
                return Line(text: "\(plates) \(protein)", punch: [protein])
            }
            return Line(text: protein, punch: [protein])
        }

        // No protein detail — the plates still happened.
        if let plates {
            return Line(text: plates, punch: [plates])
        }

        // No food at all. The plan may still have carried the day.
        if input.beatsDone > 0 {
            let word = "\(input.beatsDone) of \(input.beatsTotal) done."
            return Line(text: "the plan: \(word)", punch: [word])
        }

        if input.weighedInToday {
            return Line(text: "you weighed in. that's the day's record.",
                        punch: ["weighed in."])
        }

        return quietDay(name)
    }

    /// Nothing on file. Stated warmly, never as a reprimand, and never
    /// with a fabricated number. E6's gap law.
    private static func quietDay(_ name: String) -> Line {
        name.isEmpty
            ? Line(text: "a quiet day. it still counts.", punch: ["quiet day."])
            : Line(text: "a quiet day, \(name). it still counts.",
                   punch: ["quiet day,"])
    }

    /// "96 g of protein." · "72 of 90 g of protein." · nil when there is
    /// nothing honest to say. Never "0 g".
    private static func proteinPhrase(_ input: Input) -> String? {
        let g = input.proteinEatenG
        guard g > 0 else { return nil }
        // A denominator needs a floor on file, and stops being the
        // interesting fact once the floor is met.
        if let floor = input.proteinFloorG, floor > 0, g < floor {
            return "\(g) of \(floor) g of protein."
        }
        return "\(g) g of protein."
    }

    /// "3 plates." · "one plate." · nil at zero.
    private static func platePhrase(_ input: Input) -> String? {
        switch input.plateCount {
        case ..<1: return nil
        case 1:    return "one plate."
        default:   return "\(input.plateCount) plates."
        }
    }

    // MARK: - Line 2: what tomorrow asks, and why

    /// The archetype alone was a label. It carries its reason now — the
    /// reason is the only part that is worth reading twice, and it is
    /// the product's own mechanism, not a slogan.
    static func tomorrowLine(_ input: Input) -> Line {
        switch input.tomorrow {
        case .protein:
            return Line(
                text: "tomorrow leads with protein. it holds the muscle while the weight moves.",
                punch: ["protein."]
            )
        case .movement:
            return Line(
                text: "tomorrow leans on movement. a walk after a meal does the most.",
                punch: ["movement."]
            )
        case .balanced:
            return Line(
                text: "tomorrow is a balanced day. protein first, then whatever else.",
                punch: ["balanced day."]
            )
        case .rest:
            return Line(
                text: "tomorrow is a rest day. eating well still counts as the work.",
                punch: ["rest day."]
            )
        }
    }
}
