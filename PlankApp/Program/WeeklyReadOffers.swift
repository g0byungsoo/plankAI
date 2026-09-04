import Foundation
import SwiftData
import PlankSync

// MARK: - WeeklyReadOffers (E1 THE SPINE — B2)
//
// docs/app_v25/05_E1_SPINE.md §2. The read's ONE offer: the v4
// closed set leads (WeeklyReview.propose delegation preserves its
// laws + tests verbatim); the spine adds the step-goal recalc (the
// walking action's consented onboarding + weekly recalibration) and
// the sparse-week logging lighten (the day-29 décrescendo's first
// face). Declined kinds cool down for two weeks (the caller reads
// the cooldown from WeeklyReadRecords). Consent applies through
// ProgramFactStore — never a silent write.

enum WeeklyReadOffer: Equatable {
    case v4(ReviewProposal)
    case stepGoalRecalc(newGoal: Int, reason: String)
    case loggingLighten(reason: String)
    /// p79 — THE LEARNED BURN reaches the plan: a bounded, explained,
    /// declinable step toward the target her own record implies.
    /// `newAdjustKcal` is the device knob value an accept writes
    /// (WeeklyReview.energyAdjustKey); `newTargetKcal` is what the
    /// resolver will publish after it — carried so the offer can say
    /// the number she'll actually see.
    case energyRecalc(newTargetKcal: Int, newAdjustKcal: Int, reason: String)

    var key: String {
        switch self {
        case .v4(let p): return p.key
        case .stepGoalRecalc: return "step_goal_recalc"
        case .loggingLighten: return "logging_lighten"
        case .energyRecalc: return "energy_recalc"
        }
    }

    var title: String {
        switch self {
        case .v4(let p): return p.title
        case .stepGoalRecalc(let goal, _):
            let f = NumberFormatter()
            f.numberStyle = .decimal
            let n = f.string(from: NSNumber(value: goal)) ?? "\(goal)"
            return "a walking goal: \(n) a day"
        case .loggingLighten:
            return "lighter logging days"
        case .energyRecalc(let target, _, _):
            let f = NumberFormatter()
            f.numberStyle = .decimal
            let n = f.string(from: NSNumber(value: target)) ?? "\(target)"
            return "daily energy: \(n)"
        }
    }

    var reason: String {
        switch self {
        case .v4(let p): return p.reason
        case .stepGoalRecalc(_, let r): return r
        case .loggingLighten(let r): return r
        case .energyRecalc(_, _, let r): return r
        }
    }

    /// The consent door's label: a change is TRIED, a hold is KEPT.
    var acceptLabel: String {
        key == "hold_steady" ? "keep it" : "let's try it"
    }

    /// The signed stamp (the journey renders it; the record keeps it).
    var stampLine: String {
        switch self {
        case .v4(let p):
            switch p {
            case .holdSteady: return "the plan held steady"
            case .proteinEase(let g, _), .proteinFirm(let g, _):
                return "protein goal → \(g)g"
            case .movesEase(let n, _):
                return n == 1 ? "one move a week" : "\(n) moves a week"
            case .weighSoften: return "one weigh-in a week"
            case .intentPick: return "next week: your pick"
            }
        case .stepGoalRecalc(let goal, _):
            // No arrow: the serif ligates "→" into a slashed glyph
            // (frame-caught on the signed stamp).
            let f = NumberFormatter()
            f.numberStyle = .decimal
            let n = f.string(from: NSNumber(value: goal)) ?? "\(goal)"
            return "your walking goal: \(n) a day"
        case .loggingLighten:
            return "lighter days, on"
        case .energyRecalc(let target, _, _):
            let f = NumberFormatter()
            f.numberStyle = .decimal
            let n = f.string(from: NSNumber(value: target)) ?? "\(target)"
            return "daily energy: \(n)"
        }
    }
}

enum WeeklyReadOffers {

    struct SpineInputs: Equatable {
        var currentStepGoal: Int?
        var stepGoalRecommendation: Int?
        var loggingModeWord: String?
        var recentlyDeclinedKinds: Set<String> = []
        /// p79 — the learned burn's proposal inputs (nil = the read
        /// has nothing to say this week; the offer stands down).
        var energy: EnergyInputs? = nil
    }

    /// p79 — what the energy proposal needs to decide, and nothing
    /// else. All record-derived; assembled beside the other spine
    /// inputs in JourneyModel.
    struct EnergyInputs: Equatable {
        /// The learned burn (nil / silent / holding stand the offer
        /// down — only an established read may move the plan).
        var read: ExpenditureRead.Read?
        /// The target the resolver publishes today (adjust included).
        var currentTargetKcal: Int?
        /// The plan's loss pace (fraction of body mass per week);
        /// nil or 0 = maintenance/unknown, no proposal.
        var planRatePctPerWeek: Double?
        var currentWeightKg: Double?
        /// The count-up cohort (p53): a LOWER target is never
        /// proposed to someone on medication.
        var isOnMedication: Bool
        /// The knob's current value (cumulative, clamped ±400).
        var currentAdjustKcal: Int = 0
    }

    /// THE LEARNED BURN'S ONE MOVE (pure, pinned):
    /// implied target = observed burn − the deficit her own pace
    /// implies; the offer walks toward it in bounded steps (≤150
    /// kcal/week, cumulative ±400), each step consented at the read.
    ///
    /// The down direction carries two extra refusals (r1's inversion
    /// law): never for the medicated cohort, and never when her
    /// logged intake already sits under the current target — a lower
    /// ceiling for someone under the ceiling is a ratchet, not a fit.
    static func energyRecalc(_ e: EnergyInputs) -> WeeklyReadOffer? {
        guard case .read(let est) = e.read,
              let target = e.currentTargetKcal,
              let rate = e.planRatePctPerWeek, rate > 0,
              let kg = e.currentWeightKg, kg > 30
        else { return nil }

        let dailyDeficit = rate * kg * ExpenditureRead.kcalPerKg / 7.0
        let implied = Double(est.centerKcal) - dailyDeficit
        let gap = implied - Double(target)

        // Bounded step, 25-kcal granularity, material or silent.
        let step = Int((min(max(gap, -150), 150) / 25).rounded()) * 25
        guard abs(step) >= 75 else { return nil }

        if step < 0 {
            guard !e.isOnMedication else { return nil }
            guard est.intakeMeanKcal >= target - 100 else { return nil }
        }

        let newAdjust = max(-400, min(400, e.currentAdjustKcal + step))
        guard newAdjust != e.currentAdjustKcal else { return nil }
        let newTarget = target + (newAdjust - e.currentAdjustKcal)

        let reason = step > 0
            ? "your record reads your burn higher than the plan assumed. eating a little more still holds the pace you picked."
            : "your record reads your burn a little under the plan's guess. this keeps the pace you picked honest."
        return .energyRecalc(
            newTargetKcal: newTarget, newAdjustKcal: newAdjust, reason: reason
        )
    }

    static func propose(
        v4 v4Inputs: WeeklyReview.ProposalInputs,
        spine: SpineInputs
    ) -> WeeklyReadOffer {
        let declined = spine.recentlyDeclinedKinds
        let base = WeeklyReview.propose(v4Inputs)

        // The v4 clinical rules lead — a non-default proposal passes
        // through unless she declined its kind within the cooldown.
        if base.key != "hold_steady", !declined.contains(base.key) {
            return .v4(base)
        }

        // p79 — the learned burn's move outranks the step recalc:
        // energy is the plan's central number, and this offer is the
        // rarest by construction (established read + material gap).
        if !declined.contains("energy_recalc"),
           let energy = spine.energy,
           let offer = energyRecalc(energy) {
            return offer
        }

        // The step-goal recalc: the walking action's consented
        // onboarding (no goal yet) or its weekly recalibration
        // (moves ≥250 or it stays quiet — a 50-step wobble is not
        // an offer).
        if !declined.contains("step_goal_recalc"),
           let rec = spine.stepGoalRecommendation {
            if let current = spine.currentStepGoal {
                if abs(rec - current) >= 250 {
                    let reason = rec < current
                        ? "your days ran nearer \(formatted(rec)). the goal can come down to match."
                        : "you cleared \(formatted(current)) most days. \(formatted(rec)) fits now."
                    return .stepGoalRecalc(newGoal: rec, reason: reason)
                }
            } else {
                return .stepGoalRecalc(
                    newGoal: rec,
                    reason: "fit to your own last two weeks, not a number off a poster."
                )
            }
        }

        // The sparse-week answer: lighter logging beats silence
        // (median logging life is ~a month — the décrescendo is
        // designed, not accidental).
        if !declined.contains("logging_lighten"),
           spine.loggingModeWord != "lighter",
           v4Inputs.plateLoggedDays <= 2,
           v4Inputs.elapsedDays >= 5 {
            return .loggingLighten(
                reason: "a quiet logging week. a quick photo a day is enough to keep things going."
            )
        }

        // The default hold (its honest v4 reason) — unless the hold
        // itself was a cooled-down kind, which cannot happen, but a
        // declined non-hold base must not resurface here.
        if declined.contains(base.key) {
            // p70 — the hold's title already says the plan holds; the
            // reason says only what's true underneath it.
            return .v4(.holdSteady(reason: "nothing needs to change this week."))
        }
        return .v4(base)
    }

    @MainActor
    @discardableResult
    static func applyAccepted(
        _ offer: WeeklyReadOffer,
        userId: String,
        now: Date = .now,
        in context: ModelContext,
        legacyDefaults: UserDefaults = .standard
    ) -> ProgramFactRecord? {
        var written: ProgramFactRecord?
        func applyFact(_ kind: ProgramFactKind, _ value: ProgramFactValue) {
            written = ProgramFactStore.apply(
                kind, value: value, authority: .recommended,
                basis: .inferred, source: "weekly_read", acceptedAt: now,
                userId: userId, now: now, in: context,
                legacyDefaults: legacyDefaults
            )
        }
        func currentAdjust(_ kind: ProgramFactKind, knobKey: String) -> Int {
            ProgramFactStore.headValue(kind, userId: userId, in: context)?.intValue
                ?? legacyDefaults.integer(forKey: knobKey)
        }

        switch offer {
        case .energyRecalc(_, let newAdjust, _):
            // DEVICE KNOB, deliberately not a ProgramFactKind: the
            // server's kind CHECK would refuse a new kind until a
            // founder-applied migration, and the knob re-derives —
            // a sweep loses at most one accepted step, which the
            // next read re-proposes from the same record. Registered
            // in the sign-out sweep (AppSync) like every plan knob.
            legacyDefaults.set(newAdjust, forKey: WeeklyReview.energyAdjustKey)
        case .stepGoalRecalc(let newGoal, _):
            applyFact(.stepGoal, .int(newGoal))
        case .loggingLighten:
            applyFact(.loggingMode, .word("lighter"))
        case .v4(let proposal):
            switch proposal {
            case .holdSteady:
                break
            case .proteinEase:
                applyFact(.proteinAdjust, .int(
                    currentAdjust(.proteinAdjust, knobKey: WeeklyReview.proteinAdjustKey) - 5
                ))
            case .proteinFirm:
                applyFact(.proteinAdjust, .int(
                    currentAdjust(.proteinAdjust, knobKey: WeeklyReview.proteinAdjustKey) + 5
                ))
            case .movesEase:
                applyFact(.movesAdjust, .int(
                    currentAdjust(.movesAdjust, knobKey: WeeklyReview.sessionsAdjustKey) - 1
                ))
            case .weighSoften:
                applyFact(.weighCadence, .word("softened"))
            case .intentPick:
                // Week-scoped, deliberately NOT a fact kind — the
                // surface routes the chosen key through
                // WeeklyReview.apply (the v4 knob) directly.
                break
            }
        }
        return written
    }

    private static func formatted(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
