import Foundation

// MARK: - JENI MOVE (v25 E8.1)
//
// ─── WHAT IT USED TO BE ─────────────────────────────────────────────
//
// Two unrelated things. A workout feature — ~128 `woman-doing-X` Lottie
// animations behind a generator — and a steps sheet showing a ring, a
// seven-dot rhythm band, and one line. Between them they answered
// "did you walk 7,500 steps" and "here is an exercise video", and
// nothing else.
//
// Meanwhile `MovementService` has been reading FOUR MORE SIGNALS out of
// HealthKit the whole time and every one of them was dropped before it
// reached a screen: active energy, distance, workout minutes, and
// strength-shaped sessions. This is the same defect shape E7 found in
// food (USDA micronutrients parsed since v1.0.9 and discarded at a
// struct boundary) — the expensive part was already done.
//
// ─── WHAT IT IS NOW ─────────────────────────────────────────────────
//
// The movement record, answering three questions in this order:
//
//   WHAT HAPPENED  today and this week, from her own devices
//   WHAT MATTERS   strength, twice a week, because that is the lever
//                  that decides what the weight loss is made of
//   WHAT NEXT      one line, from her own baseline
//
// Not another Apple Fitness. No second ring, no Jeni activity score, no
// closing anything. Above all: MOVEMENT IS NOT REPAYMENT FOR FOOD. The
// product refuses "you ate 500, burn 500" as a matter of law — it is on
// the post-Ozempic kill list ("earn", "burn", "deficit") and it is the
// single fastest way to teach a person to compensate.
//
// ─── WHY STRENGTH IS THE HEADLINE ───────────────────────────────────
//
// Lean mass accounts for roughly 25% to 39% of the weight lost on
// tirzepatide and semaglutide in the published trials, and the absolute
// amount is larger than in older interventions because the total loss
// is larger. The 2025/26 consensus pairs protein (1.2-1.6 g/kg, spread
// across meals) with resistance work at least twice weekly, and the
// reason is mechanical rather than motivational: protein supplies the
// material, loading is the signal to keep it. Steps are good for a
// hundred other things and are not that signal.
//
// So Move's one judgement is strength frequency, and it is a COUNT of
// what already happened, never a plan.

// MARK: - Provenance

/// WHERE A NUMBER CAME FROM. Rendered next to every value, always,
/// because a sensor reading and a model output must never look alike.
enum MoveProvenance: String, Equatable, Sendable {
    /// Apple Health handed this over. Her device measured it.
    case measured
    /// She typed it. A fact she stated, not a measurement.
    case entered
    /// Jeni computed it from something else. Always labelled.
    case estimated

    var word: String {
        switch self {
        case .measured:  return "from health"
        case .entered:   return "you recorded this"
        case .estimated: return "estimated"
        }
    }
}

/// One value with its provenance attached. There is no constructor that
/// produces a number without one.
struct MoveValue: Equatable, Sendable {
    let amount: Double
    let provenance: MoveProvenance
}

// MARK: - The record

/// Everything Move renders, already resolved. A field is nil when the
/// product genuinely does not know — never zero, because zero is a
/// measurement and absence is not.
struct MoveRecord: Equatable, Sendable {

    // ── what happened ──
    var stepsToday: Int?
    var stepsGoal: Int
    /// Her own 28-day mean, for comparing her to herself.
    var stepsBaseline: Int?
    var weeklySteps: [Int]
    /// HealthKit active energy. Never estimated from steps: a step count
    /// times a body weight is a guess wearing a sensor's clothes, and the
    /// old steps sheet printed exactly that as a fact.
    var activeEnergy: MoveValue?
    var distanceKm: MoveValue?
    var workoutMinutesToday: Int?

    // ── what matters ──
    var strengthSessionsLast7: Int
    /// Sessions she recorded by hand this week, which Health could not
    /// see. Counted separately so the strength total stays honest about
    /// its mixed provenance.
    var enteredSessionsLast7: Int

    static let strengthTargetPerWeek = 2

    var totalStrengthLast7: Int { strengthSessionsLast7 + enteredSessionsLast7 }
    var strengthMet: Bool { totalStrengthLast7 >= Self.strengthTargetPerWeek }

    /// WHY A ZERO-STEP DAY IS `nil` AND NOT `0`.
    ///
    /// `stepsToday` is optional so the record can hold "a measured zero"
    /// separately from "unknown" — and that distinction is right. But
    /// THIS APP CANNOT OBTAIN A MEASURED ZERO. `StepsService.todayCount`
    /// is a non-optional `Int` that reads 0 both when HealthKit returned
    /// no samples and when it returned samples summing to zero, and the
    /// two are not the same fact: no samples before 8am, or on a day her
    /// phone sat on a desk, is a measurement of WHERE HER PHONE WAS, not
    /// of what her body did.
    ///
    /// So the sheet rendered `steps 0 · from health` — a sensor's
    /// clothes on an absence, which is the same defect shape this file
    /// already refuses for energy (§2 of the contract below). Absence
    /// is the honest reading, and `todayBlock`'s own copy ("nothing has
    /// come through from health today.") is already the right sentence
    /// for it.
    static func resolvedStepsToday(authorized: Bool, count: Int) -> Int? {
        guard authorized, count > 0 else { return nil }
        return count
    }

    /// True when nothing at all is known — the honest empty state, which
    /// is different from "she did not move".
    var isEmpty: Bool {
        stepsToday == nil && activeEnergy == nil && distanceKm == nil
            && totalStrengthLast7 == 0 && weeklySteps.allSatisfy { $0 == 0 }
    }
}

// MARK: - MoveEnergy — the estimation rules, in one place
//
// THE CONTRACT:
//
//   1. Where Apple Health supplies active energy, that value is used and
//      labelled `measured`. Nothing overrides it, nothing "corrects" it.
//   2. Where it does not, Move shows NO energy figure. It does not
//      reconstruct one from steps. The old steps sheet did (`StepsEnergy`
//      = steps × weight × a constant) and rendered the result in the same
//      typeface as everything else.
//   3. The ONLY estimated energy in Move comes from an activity SHE
//      entered, because there the alternative is nothing at all and she
//      already knows it is an estimate — she just told us what she did.
//      It is labelled `estimated` at every render site.
//   4. An estimate needs her weight. Without a weight on file there is no
//      number, because the model has no scale.
//
// The model is METs: kcal ≈ MET × 3.5 × kg / 200 × minutes, the
// standard compendium form. MET values are the compendium's broad
// category midpoints, deliberately at the CONSERVATIVE end of each
// range: an over-estimate of energy out is the error that leads someone
// to eat it back.
enum MoveEnergy {

    /// A closed set. Every entry has a published MET value; "something
    /// else" carries the lowest, because an unknown activity must not be
    /// the most generous one.
    enum ManualKind: String, CaseIterable, Equatable, Sendable, Codable {
        case walk
        case strength
        case cycle
        case swim
        case classOrStudio = "class"
        case other

        var label: String {
            switch self {
            case .walk:          return "a walk"
            case .strength:      return "something heavy"
            case .cycle:         return "cycling"
            case .swim:          return "swimming"
            case .classOrStudio: return "a class"
            case .other:         return "something else"
            }
        }

        /// Compendium midpoints, rounded down.
        var met: Double {
            switch self {
            case .walk:          return 3.5   // brisk, level
            case .strength:      return 3.5   // resistance, general
            case .cycle:         return 6.0   // moderate effort
            case .swim:          return 6.0   // freestyle, light/moderate
            case .classOrStudio: return 5.0   // general conditioning
            case .other:         return 3.0
            }
        }

        /// Whether this counts toward the two-a-week strength signal.
        /// Only the thing that actually loads muscle does, because a
        /// generous definition here would quietly retire the one
        /// judgement Move makes.
        var countsAsStrength: Bool { self == .strength }
    }

    /// p63 — the receipt for a manual session, composed from facts
    /// already on hand at the moment "record it" lands. Strength
    /// sessions answer against the two-a-week ask (the one judgement
    /// Move makes); everything else is counted, never graded against
    /// a target it does not serve. No praise, no verdict — the
    /// PlateAnswerEngine refusals, in Move's own words.
    static func receipt(
        kind: ManualKind, strengthThisWeekBefore: Int
    ) -> (line: String, italic: [String], sub: String) {
        guard kind.countsAsStrength else {
            return ("on the record", [], "counted, alongside what health sees.")
        }
        let after = max(0, strengthThisWeekBefore) + 1
        switch after {
        case 1:
            return ("on the record", [],
                    "first heavy session this week. one more is the whole ask.")
        case 2:
            return ("that's twice this week", ["twice"],
                    "the whole ask. what keeps the muscle while the weight moves.")
        default:
            return ("kept", [], "\(after) heavy sessions this week.")
        }
    }

    /// kcal for a manual entry, or nil when there is no weight to scale
    /// it by. Rounded to 5 kcal: printing 187 would claim a precision no
    /// MET model has.
    static func estimatedKcal(
        kind: ManualKind, minutes: Int, weightKg: Double?
    ) -> Int? {
        guard let weightKg, weightKg > 20, minutes > 0 else { return nil }
        let kcal = kind.met * 3.5 * weightKg / 200.0 * Double(minutes)
        guard kcal >= 5 else { return nil }
        return Int((kcal / 5).rounded()) * 5
    }

    // MARK: - The headline
    //
    // A COUNT IS A HERO ONLY WHEN THERE IS SOMETHING TO COUNT.
    //
    // Move opened on `0 of 2` set in 44pt serif: the largest thing on
    // the surface was a zero, under an eyebrow reading "what your body
    // did". Every other instrument in this product already refuses
    // that — the protein hero drops its denominator once met (E7,
    // because "123 of 90 g" read as a typo), `FirstPlateReadingEngine`
    // renders NO floor when there is no weight on file, and
    // `PlateAnswerEngine` turns a number it cannot ground into coarse
    // words. The same law, arriving late on the one surface that had
    // nothing to enlarge: at zero the reading is a SENTENCE, and the
    // numeral appears the moment a session does.
    //
    // This is not softening the judgement. Strength stays the headline
    // — the evidence for it is in the file header, and it is the one
    // call Move makes. What changes is that a week which has not
    // happened yet is stated in words instead of being set in type
    // three times the size of anything she actually did.

    enum StrengthHeadline: Equatable {
        /// A real count. `of` is nil once the guidance is met, because a
        /// met ratio stops being the interesting fact.
        case count(done: Int, of: Int?)
        /// No session on file this week, so there is no number to make
        /// large. Never a verdict, never a reprimand.
        case nothingYet(String)
    }

    static func strengthHeadline(_ record: MoveRecord) -> StrengthHeadline {
        let done = record.totalStrengthLast7
        guard done > 0 else {
            return .nothingYet("nothing heavy yet this week.")
        }
        return .count(
            done: done,
            of: record.strengthMet ? nil : MoveRecord.strengthTargetPerWeek
        )
    }

    /// What Move says under the record. One line, and never arithmetic
    /// against food.
    ///
    /// Order is the product's priorities, not the numbers' sizes:
    /// strength first (the lever), then her own baseline, then the
    /// day. Silence when there is nothing true to say.
    ///
    /// The zero branch USED to live here as well as in the caption
    /// above the fold, so Move said "twice a week" twice, three inches
    /// apart, on the state where it was least welcome. The zero is the
    /// headline now (`strengthHeadline`) and its teaching rides with
    /// it; this returns nil there rather than saying it a second time
    /// (E4's prose/ledger de-dup law).
    static func nextLine(_ record: MoveRecord) -> String? {
        if !record.strengthMet {
            let done = record.totalStrengthLast7
            if done == 0 { return nil }
            return "one session in. a second is what the week is actually asking for."
        }
        if let today = record.stepsToday, let baseline = record.stepsBaseline,
           baseline >= 1_000, today < baseline / 2 {
            return "a quiet day against your own usual. quiet days still count, and they do not need paying back."
        }
        if record.strengthMet {
            // No numeral. The count is already the hero three inches
            // above, and hardcoding "two" made the line contradict a
            // week with three in it — caught by filming.
            return "the heavy work is on file this week. that is the part that decides what the weight loss is made of."
        }
        return nil
    }
}
