import Foundation

// MARK: - PlatePriors (v25 E4 — THE PLATE'S MEMORY)
//
// The corrections flywheel, finally written. Six comments across this
// package described "corrections as priors"; nothing wrote one. This
// engine reads the user's own accepted record and applies it to a new
// recognition of the SAME dish — deterministically, client-side, with
// provenance and a one-tap revert. Zero server changes.
//
// The law:
// - A prior exists only for a dish she CORRECTED (fix-with-words) and
//   then logged. Merely-accepted plates are weak evidence the model
//   was right, not that she knows better.
// - Matching is exact on a normalized title. Fuzzy matching invents
//   memories; a near-miss is a different dish.
// - Application is a uniform scale of the model's plate to her
//   accepted kcal — portions and macros ride the same factor so the
//   plate stays internally coherent (the PlateEditSession math).
// - The model gets to agree: within ±15% of her number, nothing is
//   touched (no noise, no revert chip for a rounding echo).
// - Barcode and label plates are never touched (printed truth), and
//   neither are described plates. PHOTO ONLY, and this is the load-
//   bearing exclusion in the engine, so here is the whole argument:
//
//   This engine keys on the dish TITLE and applies a UNIFORM SCALE.
//   On a photograph that is exactly right — the portion came from the
//   MODEL sizing an image, so her prior is a correction to the model's
//   sizing and the scale means "your usual bowl is bigger than it
//   guessed".
//
//   Through the words door the portion came from HER. "half a turkey
//   sandwich" normalizes to the same title as the whole one she
//   corrected last week, so the prior would scale her HALF up to a
//   WHOLE — silently, and past the ±3× clamp, which cannot see a 2×
//   error. "a few bites of pizza" is the same defect at 8×.
//
//   **A prior must never overrule a portion the user stated herself.**
//   The words door is the one door where she states it, which is why
//   the door E7 made the front door is the door this engine may not
//   touch. That is not a gap in the flywheel; it is the flywheel
//   refusing to overwrite its own source.
//
//   The `.text` pipeline also carries every fix-with-words correction
//   (SnapRefine dispatches through it), so a prior there would fight
//   the correction it came from.
//
//   Pinned by `PlatePriorsWordsDoorTests`, which exists because a
//   later pass read a stale doc comment on the dispatcher, believed
//   this was a missing feature, and nearly built it.
// - Every application is visible ("your numbers · you fixed this
//   dish before") and reversible in one tap. A silent override of
//   the model would be a silent override of HER next correction.

public enum PlatePriors {

    /// One row of the user's record, as the engine sees it.
    public struct Observation: Sendable, Equatable {
        public let title: String
        public let kcal: Double
        public let proteinG: Double
        public let corrected: Bool
        public let at: Date

        public init(title: String, kcal: Double, proteinG: Double,
                    corrected: Bool, at: Date) {
            self.title = title
            self.kcal = kcal
            self.proteinG = proteinG
            self.corrected = corrected
            self.at = at
        }
    }

    /// Her accepted numbers for one normalized dish.
    public struct DishPrior: Sendable, Equatable {
        public let normalizedTitle: String
        public let kcal: Double
        public let proteinG: Double
        public let timesCorrected: Int
        public let lastAt: Date
    }

    /// What `apply` did, carried on the plate for the reading's
    /// provenance line + revert.
    public struct Applied: Sendable, Equatable {
        public let dishTitle: String
        public let priorLastAt: Date
        /// The model's original plate kcal (revert target).
        public let modelKcal: Double
        /// Uniform factor applied to every item (her kcal / model's).
        public let factor: Double
    }

    /// "Grilled Chicken Bowl + 2 more" → "grilled chicken bowl".
    /// Strips the persister's "+ N more" suffix, case, whitespace and
    /// terminal punctuation — nothing smarter, by design.
    public static func normalize(_ title: String) -> String {
        var t = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = t.range(of: #" \+ \d+ more$"#, options: .regularExpression) {
            t.removeSubrange(range)
        }
        while let last = t.last, ".,!".contains(last) { t.removeLast() }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Fold the record into per-dish priors. Only corrected rows
    /// build priors; the LATEST correction wins (she refines over
    /// time and the newest number is the one she accepted last).
    public static func index(_ observations: [Observation]) -> [String: DishPrior] {
        var out: [String: DishPrior] = [:]
        for obs in observations where obs.corrected && obs.kcal > 0 {
            let key = normalize(obs.title)
            guard !key.isEmpty else { continue }
            if let existing = out[key] {
                out[key] = DishPrior(
                    normalizedTitle: key,
                    kcal: obs.at > existing.lastAt ? obs.kcal : existing.kcal,
                    proteinG: obs.at > existing.lastAt ? obs.proteinG : existing.proteinG,
                    timesCorrected: existing.timesCorrected + 1,
                    lastAt: max(obs.at, existing.lastAt)
                )
            } else {
                out[key] = DishPrior(
                    normalizedTitle: key,
                    kcal: obs.kcal,
                    proteinG: obs.proteinG,
                    timesCorrected: 1,
                    lastAt: obs.at
                )
            }
        }
        return out
    }

    /// The model agrees within this band → leave the plate alone.
    public static let agreementBand: Double = 0.15

    /// Sanity clamp: a prior more than 3× / less than ⅓ of the model's
    /// read is a different portion of the same name (family-size vs
    /// single) — refuse rather than distort.
    static let factorFloor: Double = 1.0 / 3.0
    static let factorCeiling: Double = 3.0

    /// Apply her record to a fresh recognition. Returns the plate
    /// unchanged when no prior speaks.
    public static func apply(
        to food: CapturedFood,
        index: [String: DishPrior]
    ) -> CapturedFood {
        // Printed truth is never overridden; a re-application would
        // compound (guard on existing provenance). Label plates are
        // excluded at the dispatcher (they arrive as .photo with the
        // label hint — the dispatcher knows, this type does not).
        guard food.priorApplied == nil, food.source != .barcode
        else { return food }
        guard let first = food.items.first else { return food }
        let title: String = {
            let more = food.items.count - 1
            return more > 0 ? "\(first.name) + \(more) more" : first.name
        }()
        guard let prior = index[normalize(title)] else { return food }
        guard let modelKcal = food.totalKcal, modelKcal > 0 else { return food }
        let drift = abs(prior.kcal - modelKcal) / modelKcal
        guard drift > agreementBand else { return food }
        let factor = prior.kcal / modelKcal
        guard factor >= factorFloor, factor <= factorCeiling else { return food }

        var scaled = scale(food, by: factor)
        scaled.priorApplied = Applied(
            dishTitle: normalize(title),
            priorLastAt: prior.lastAt,
            modelKcal: modelKcal,
            factor: factor
        )
        return scaled
    }

    /// One-tap revert: the model's plate, exactly restored.
    public static func revert(_ food: CapturedFood) -> CapturedFood {
        guard let applied = food.priorApplied, applied.factor != 0 else { return food }
        var restored = scale(food, by: 1.0 / applied.factor)
        restored.priorApplied = nil
        return restored
    }

    /// Uniform plate scale — portions, kcal, every macro and the
    /// micronutrients ride the same factor so the plate stays coherent
    /// (dropping micros here once made a grounded plate go silent the
    /// moment her own prior improved it — the record getting POORER
    /// for having been corrected). One arithmetic, owned by
    /// `CapturedItem.scalingNutrition`; this used to carry a second
    /// hand-written copy of it, which is the field-drop shape pass 51
    /// closed (see `FieldPreservationTests`).
    static func scale(_ food: CapturedFood, by factor: Double) -> CapturedFood {
        var out = food
        out.items = food.items.map { $0.scalingNutrition(by: factor) }
        out.kcalLow = food.kcalLow.map { $0 * factor }
        out.kcalHigh = food.kcalHigh.map { $0 * factor }
        return out
    }
}
