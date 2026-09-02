import Foundation

// MARK: - FirstPlateReading (v25 E5 — THE FIRST PLATE)
//
// The one true thing Jeni says about a stranger's first plate.
//
// This is the era's whole value proposition compressed into three
// strings, so it is a PURE engine with a table test (FirstPlateReading
// Tests) rather than copy inlined in a view. What it may say is bounded
// by the standing laws:
//
//   · protein leads, kcal stays quiet (00_THE_SYSTEM §9) — protein is
//     also the single most evidence-backed lever for this cohort
//     (r3/r4: 1.2-2.0 g/kg, lean mass is 25-40% of drug-induced loss)
//   · no floor without a weight on file (data-provenance law: every
//     number traces to a collected field)
//   · fractions render in coarse WORDS, never a percentage — the vision
//     pipeline is ±30% (r2) and a percent claims precision it does not
//     have
//   · no score, no colour, no verdict (design law)
//
// The floor itself is NOT computed here. It comes from
// TargetsService.proteinTargetG — the same formula Today, Becoming, the
// reading and chat all render. One formula, four surfaces.

struct FirstPlateReading: Equatable {
    /// The plate's own fact. Always present — she logged something.
    let headline: String
    /// What it means against her floor. Nil when the record is too thin
    /// to mean anything; silence is the honest answer.
    let meaning: String?
    /// The same fact with the sentence furniture off, for a receipt row
    /// that already carries its own label ("against your floor →").
    /// Composed here rather than trimmed at the call site: the first cut
    /// did string surgery in the view and it was one copy edit away from
    /// rendering a fragment.
    let meaningShort: String?
    /// Where the floor came from. Nil whenever `meaning` is.
    let provenance: String?
    let hasFloor: Bool
}

enum FirstPlateReadingEngine {

    /// Grams below this are noise, not a fact worth a headline.
    private static let proteinNoiseFloorG = 1.0

    static func compose(
        proteinG: Double?,
        kcal: Double?,
        floorG: Int?
    ) -> FirstPlateReading {

        let protein = (proteinG ?? 0) >= proteinNoiseFloorG ? proteinG : nil

        // 1. The headline: her plate's own strongest honest fact.
        let headline: String
        if let protein {
            headline = "\(Int(protein.rounded())) g of protein"
        } else if let kcal, kcal > 0 {
            // Rounded to 10 — the band is ±30%, so a unit digit lies.
            headline = "about \(Int((kcal / 10).rounded()) * 10) calories"
        } else {
            headline = "logged"
        }

        // 2. The meaning: only when BOTH a protein reading and a floor
        //    exist. No weight on file → no floor → no sentence.
        guard let protein, let floorG, floorG > 0 else {
            return FirstPlateReading(
                headline: headline, meaning: nil, meaningShort: nil,
                provenance: nil, hasFloor: false
            )
        }

        let share = protein / Double(floorG)
        let short: String
        switch share {
        case ..<0.15:  short = "a start on it"
        case ..<0.30:  short = "about a quarter of your day"
        case ..<0.45:  short = "about a third of your day"
        case ..<0.60:  short = "about half your day"
        case ..<0.85:  short = "most of your day"
        default:       short = "your whole day, in one plate"
        }
        let meaning = share < 0.15
            ? "a start on your day's protein."
            : (share >= 0.85 ? "\(short)." : "\(short), in one plate.")

        return FirstPlateReading(
            headline: headline,
            meaning: meaning,
            meaningShort: short,
            provenance: "your protein goal is about \(floorG) g, from the weight you gave jeni.",
            hasFloor: true
        )
    }
}
