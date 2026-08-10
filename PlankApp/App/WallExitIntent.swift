import Foundation

// MARK: - WallExitIntent
//
// App Store 5.6 fix (2026-08-10). Review of 1.1.7 (28) rejected the
// wall: "the (X) button was unresponsive." It was.
//
// The old WallView.triggerExitIntent walked a three-rung ladder —
// save sheet → discounted year → winback — each rung gated by its own
// once-flag, and FELL THROUGH to nothing once all three were spent.
// Two of those flags are @AppStorage, so from the second launch
// onward the X was a live button wired to a no-op, on a phase that
// mounts nothing else (AppPhase.wall is a destination). There was no
// way off the buy surface at all: tap, tap, nothing.
//
// The law now: at most ONE offer per install, tier-matched, and after
// that the X always stands the wall down. Every press produces a
// visible response; no press ever dead-ends. Pure and total so the
// whole rule is table-testable, the same shape AppPhaseMachine.derive
// gave the gate itself.

enum WallExitIntent {

    /// What an X press (or an Apple-sheet cancel) does next. There is
    /// deliberately no "do nothing" case — that absence IS the fix.
    enum Action: Equatable {
        /// The week — the commitment objection's smallest door.
        case smallerStep
        /// The year at a discount, tier-matched to a yearly abandon.
        case discountedYear
        /// No offer left to make: leave the buy surface.
        case standDown
    }

    struct Inputs: Equatable {
        /// Which tier's Apple sheet was cancelled, when the exit came
        /// from one. nil for a plain X press.
        var abandonedPlan: String?
        /// @AppStorage("smallerStepShownOnce") — persists per install.
        var smallerStepShownOnce: Bool
        /// @AppStorage("downsellShownOnce") — persists per install.
        var downsellShownOnce: Bool
    }

    /// Total function over Inputs. Every state maps to something the
    /// user can see happen.
    static func next(_ i: Inputs) -> Action {
        // One offer per install, counted across both rungs. A user who
        // has already been shown either door is done being asked; the
        // X is now purely an exit. This is the 5.6 line: an offer is a
        // recovery, a repeated offer is pressure.
        if i.smallerStepShownOnce || i.downsellShownOnce {
            return .standDown
        }
        // Tier-matched: someone who balked at the year gets the year
        // cheaper, not a downgrade to the week.
        if i.abandonedPlan == "yearly" {
            return .discountedYear
        }
        return .smallerStep
    }
}
