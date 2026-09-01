import Foundation
import SwiftUI

// MARK: - HomeAutoPresent (pass 57 D3, widened p61)
//
// Home used to schedule up to four spontaneous surfaces on one appear
// (reconcile +0.6s, the letter +0.7s, the body intro +0.6s, the
// upgrade after a network round-trip), each through its own modifier,
// each guarding against a different subset of the others — and two of
// them burned their once-flags AT SCHEDULE TIME. SwiftUI presents one
// modal per moment; the losers failed silently. The concrete customer
// cost: on the body intro's first eligible morning it won the slot,
// the letter's attempt died against the one-modal rule, and her
// morning read was marked delivered but never shown.
//
// One arbiter now: eligibility is computed without stamping, exactly
// one winner presents per ARRIVAL (appear · foreground · day change),
// and a once-flag is stamped only when its surface actually presents.
// A loser keeps its eligibility and simply goes next time.
//
// p61 — the evening close joins the arbiter. It used to schedule
// itself from `refresh()`, which runs on every tab switch, plate log,
// sheet dismissal and foreground: it bypassed the priority law, could
// collide with the letter 200ms apart on the same modal slot, and
// re-armed all evening because its day-key stamps on dismiss. The
// close now speaks only at an arrival moment — "the first time Home
// is seen after the evening turns", which was always its own stated
// intent — and mid-session the invitation row is its door.
//
// The priority is a product law, stated once:
//   1. reconcile — a clinical confirmation outranks everything.
//   2. evening close — in the evening, the day's own voice. The
//      MORNING read never fires in the evening; its day-key stays
//      unburned, and tomorrow morning it speaks as itself. Two
//      takeovers in one arrival is the machine-gun feel this file
//      exists to end.
//   3. letter — the morning read is the product's daily voice.
//   4. upgrade — commerce never outranks the read.
enum HomeAutoPresent {

    /// ONE settle beat for every self-presenting surface. Three
    /// different constants (0.6 / 0.7 / 0.9) used to make the same
    /// gesture at three speeds.
    static let settleBeat: TimeInterval = 0.6

    enum Candidate: Equatable {
        case reconcile
        case eveningClose
        case letter
        case upgrade
    }

    static func winner(
        reconcileEligible: Bool,
        eveningEligible: Bool = false,
        letterEligible: Bool,
        upgradeEligible: Bool,
        isEvening: Bool = false
    ) -> Candidate? {
        if reconcileEligible { return .reconcile }
        if isEvening {
            if eveningEligible { return .eveningClose }
            // The morning read stands down for the whole evening — an
            // 8pm first open gets the close tonight and the letter
            // tomorrow, never both in one arrival.
            if upgradeEligible { return .upgrade }
            return nil
        }
        if letterEligible { return .letter }
        if upgradeEligible { return .upgrade }
        return nil
    }
}

// MARK: - PresentationGate
//
// The one-modal-slot truth, visible ACROSS owners. `nothingPresented`
// used to read only HomeView's own five flags, while MainShell's
// reauth sheet and post-purchase cover occupied the same slot
// invisibly — so an arbiter winner could fire into an occupied window
// and die silently, the exact D3 failure class one level up.
//
// MainShell raises the gate while a shell surface is up; HomeView's
// presenters check it alongside their own flags. A blocked winner
// loses nothing: eligibility survives and it goes on the next arrival.
@MainActor
@Observable
final class PresentationGate {
    static let shared = PresentationGate()
    private init() {}

    /// True while MainShell has a surface up (reauth · post-purchase).
    var shellSurfaceUp = false
}

extension Notification.Name {
    /// Posted by RootView once the launch ATT request settles (asked
    /// and answered, or not needed). Home re-runs its director on it.
    static let attPromptSettled = Notification.Name("attPromptSettled")
}
