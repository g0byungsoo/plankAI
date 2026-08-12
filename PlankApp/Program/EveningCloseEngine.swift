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
        Close(today: todayLine(input), tomorrow: tomorrowLine(input))
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
