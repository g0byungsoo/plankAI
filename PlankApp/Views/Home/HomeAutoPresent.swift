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

// MARK: - BecomingAutoPresent (pass 62)
//
// Becoming was the second, unreformed director: the weekly read
// scheduled itself from `refresh()` — which runs on every plate log,
// body-scan change and scope tap — stamped its once-per-week flag AT
// SCHEDULE TIME, and its +0.7s closure checked only its own cover
// binding. Open THE BOOK (or any of its four sibling covers) and the
// read died against the one-modal rule with its week already burned:
// the exact defect class p57/p61 removed from Home, shipping one tab
// over. And a plain tab switch INTO becoming scheduled nothing at
// all, so a due read routinely greeted nobody.
//
// The law, mirrored from HomeAutoPresent: eligibility is computed
// without stamping; the read presents only at an ARRIVAL at becoming
// (tab arrival · appear · foreground while visible); the flag stamps
// when the cover actually presents; a loser keeps its eligibility and
// the BODY card's "read the whole week" stays its mid-session door.
enum BecomingAutoPresent {

    /// Arrival-time decision. Stamps nothing.
    static func shouldOffer(
        dueWeekIndex: Int?,
        offeredWeek: Int?,
        onBecoming: Bool
    ) -> Bool {
        guard onBecoming, let due = dueWeekIndex else { return false }
        return offeredWeek != due
    }

    /// Present-time recheck, one settle beat later. The caller stamps
    /// the offered week iff this returns true — never earlier.
    static func mayPresent(
        stillDueWeekIndex: Int?,
        scheduledWeekIndex: Int,
        siblingSurfaceUp: Bool,
        onBecoming: Bool,
        gateOccupied: Bool
    ) -> Bool {
        guard let due = stillDueWeekIndex, due == scheduledWeekIndex,
              onBecoming, !siblingSurfaceUp, !gateOccupied
        else { return false }
        return true
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
// p62 — the gate becomes an owner SET. Becoming's five covers (THE
// BOOK, the weigh-in ledger, the body timeline, the visit packet, the
// weekly read) and the scan chooser occupied the same slot invisibly:
// a reconcile arriving while THE BOOK was open burned its
// once-per-session flag into an occupied window. Every cover owner
// raises the gate; every director asks "is anyone up besides me?" —
// its own surfaces it already reads directly. A blocked winner loses
// nothing: eligibility survives and it goes on the next arrival.
@MainActor
@Observable
final class PresentationGate {
    static let shared = PresentationGate()
    private init() {}

    enum Owner: Hashable {
        case shell      // reauth · post-purchase · the scan chooser
        case home       // Home's covers, sheets and moments
        case becoming   // the five record covers + the weekly read
    }

    private(set) var up: Set<Owner> = []

    func set(_ owner: Owner, up isUp: Bool) {
        if isUp { up.insert(owner) } else { up.remove(owner) }
    }

    /// Is any owner's surface up, other than the asker's own? A
    /// director always knows its own flags; the gate answers for
    /// everyone else's.
    func occupied(besides owner: Owner? = nil) -> Bool {
        var others = up
        if let owner { others.remove(owner) }
        return !others.isEmpty
    }
}

extension Notification.Name {
    /// Posted by RootView once the launch ATT request settles (asked
    /// and answered, or not needed). Home re-runs its director on it.
    static let attPromptSettled = Notification.Name("attPromptSettled")
}
