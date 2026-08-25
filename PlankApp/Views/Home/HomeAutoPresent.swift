import Foundation

// MARK: - HomeAutoPresent (pass 57, D3)
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
// one winner presents per appear, and a once-flag is stamped only when
// its surface actually presents. A loser keeps its eligibility and
// simply goes next time.
//
// The priority is a product law, stated once:
//   1. reconcile — a clinical confirmation outranks everything.
//   2. letter    — the morning read is the product's daily voice.
//   3. upgrade   — commerce never outranks the read.
enum HomeAutoPresent {

    enum Candidate: Equatable {
        case reconcile
        case letter
        case upgrade
    }

    static func winner(
        reconcileEligible: Bool,
        letterEligible: Bool,
        upgradeEligible: Bool
    ) -> Candidate? {
        if reconcileEligible { return .reconcile }
        if letterEligible { return .letter }
        if upgradeEligible { return .upgrade }
        return nil
    }
}
