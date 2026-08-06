import Foundation

// MARK: - BodyFatEstimate (v10.4 — the supporting number)
//
// The result screen's second panel, deliberately subordinate to Body
// Progress. It answers "roughly where am I?" without ever pretending
// to clinical precision, and it keeps the promise her consent sheet
// made: NO NUMBER IS EVER READ FROM A PHOTOGRAPH (L3). The photo is
// evidence of shape; the number comes from measurements she gave us.
//
// A provenance ladder, most-honest first:
//  1. MEASURED — her own smart scale wrote a body-fat percent to
//     Apple Health. That is a real reading; it renders as one, with
//     its source named.
//  2. ESTIMATED — a range computed from weight, height, age and sex
//     (Deurenberg et al. 1991, Br J Nutr: %BF = 1.20·BMI + 0.23·age
//     − 10.8·sex − 5.4, standard error ≈ 4 points). It renders as a
//     BAND, never a single figure, because a single figure would
//     claim an accuracy this method does not have.
//  3. NOTHING — inputs missing means no panel. We never guess a
//     body from a blank.
//
// Copy is a D10 draft. The house voice never says "AI" in user copy,
// so the honesty lands as provenance ("estimated from your height
// and weight") rather than as a technology claim.

enum BodyFatEstimate {

    enum Source: Equatable {
        /// A real reading from a device she owns.
        case measured(String)
        /// Computed from her measurements — a band, not a point.
        case estimated
    }

    struct Read: Equatable {
        /// Whole percents. low == high for a measured reading.
        let low: Int
        let high: Int
        let source: Source

        var isMeasured: Bool { if case .measured = source { return true }; return false }

        /// What the eye reads first.
        var value: String {
            isMeasured ? "\(low)%" : "\(low)–\(high)%"
        }

        /// Where it came from — always rendered with the value.
        var provenance: String {
            switch source {
            case .measured(let device): return "measured · \(device)"
            case .estimated: return "estimated from your height, weight and age"
            }
        }

        /// The honesty line. Never absent.
        var caveat: String {
            isMeasured
                ? "a scale reading moves with hydration. the direction matters more than the day."
                : "an estimate, not a measurement. never read from your photo."
        }
    }

    /// Deurenberg's standard error, carried into the band the user
    /// sees (±3 points reads honest without becoming meaningless).
    static let estimateBand = 3

    /// The ladder. `healthPct` is Apple Health's latest body-fat
    /// percent (her scale); the rest are her profile answers.
    static func read(
        healthPct: Double?,
        healthSource: String = "apple health",
        weightKg: Double?,
        heightCm: Double?,
        ageYears: Int?,
        isFemale: Bool?
    ) -> Read? {
        if let measured = healthPct, measured > 3, measured < 75 {
            let whole = Int(measured.rounded())
            return Read(low: whole, high: whole, source: .measured(healthSource))
        }
        guard let weightKg, weightKg > 25,
              let heightCm, heightCm > 100,
              let ageYears, ageYears >= 18, ageYears < 100,
              let isFemale else { return nil }

        let heightM = heightCm / 100
        let bmi = weightKg / (heightM * heightM)
        let sexTerm = isFemale ? 0.0 : 10.8
        let percent = 1.20 * bmi + 0.23 * Double(ageYears) - sexTerm - 5.4
        // Physiology, not arithmetic, bounds the answer: essential
        // fat sits near 10% (female) / 3% (male) and the formula
        // drifts at the extremes.
        let floor = isFemale ? 12.0 : 5.0
        let clamped = min(max(percent, floor), 60)
        let mid = Int(clamped.rounded())
        return Read(
            low: max(Int(floor.rounded()), mid - estimateBand),
            high: mid + estimateBand,
            source: .estimated
        )
    }
}
