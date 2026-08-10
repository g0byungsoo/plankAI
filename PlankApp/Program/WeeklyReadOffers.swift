import Foundation
import SwiftData

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

    var key: String {
        switch self {
        case .v4(let p): return p.key
        case .stepGoalRecalc: return "step_goal_recalc"
        case .loggingLighten: return "logging_lighten"
        }
    }
}

enum WeeklyReadOffers {

    struct SpineInputs: Equatable {
        var currentStepGoal: Int?
        var stepGoalRecommendation: Int?
        var loggingModeWord: String?
        var recentlyDeclinedKinds: Set<String> = []
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

        // The step-goal recalc: the walking action's consented
        // onboarding (no goal yet) or its weekly recalibration
        // (moves ≥250 or it stays quiet — a 50-step wobble is not
        // an offer).
        if !declined.contains("step_goal_recalc"),
           let rec = spine.stepGoalRecommendation {
            if let current = spine.currentStepGoal {
                if abs(rec - current) >= 250 {
                    let reason = rec < current
                        ? "your days ran nearer \(formatted(rec)). the goal can breathe down."
                        : "you cleared \(formatted(current)) most days. \(formatted(rec)) fits now."
                    return .stepGoalRecalc(newGoal: rec, reason: reason)
                }
            } else {
                return .stepGoalRecalc(
                    newGoal: rec,
                    reason: "fit to your own last two weeks, not a slogan number."
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
                reason: "a quiet logging week. lighter days — a photo counts — keep the record alive."
            )
        }

        // The default hold (its honest v4 reason) — unless the hold
        // itself was a cooled-down kind, which cannot happen, but a
        // declined non-hold base must not resurface here.
        if declined.contains(base.key) {
            return .v4(.holdSteady(reason: "the plan holds this week."))
        }
        return .v4(base)
    }

    @MainActor
    static func applyAccepted(
        _ offer: WeeklyReadOffer,
        userId: String,
        now: Date = .now,
        in context: ModelContext,
        legacyDefaults: UserDefaults = .standard
    ) {
        func applyFact(_ kind: ProgramFactKind, _ value: ProgramFactValue) {
            ProgramFactStore.apply(
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
    }

    private static func formatted(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
