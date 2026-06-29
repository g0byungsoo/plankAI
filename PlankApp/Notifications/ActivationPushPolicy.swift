import Foundation

// Activation-state push policy for D0-D3 onboarding nudges.
// Pure value type - no side effects, no UserDefaults, no UNUserNotificationCenter.
// Safe to unit-test in isolation.
//
// Design rationale
// - D0 anchor was cut in v2 (2026-06-16): fired into onboarding euphoria and
//   half of installs hadn't granted permission yet.
// - D1 morning push is the only activation nudge currently scheduled.
// - D2 and D3 slots are reserved for future activation nudges; the cap
//   (alreadyScheduled < 3) ensures they never stack above 3 total.
// - The engaged re-arm path (v1.1.2 "you already started") is a CONTINUATION
//   nudge, not an activation nudge - it bypasses this policy at the call site
//   in scheduleDay1Morning(now:engaged:).
//
// Voice constraints enforced upstream (copy lives in Glp1Cohort):
// - No scale-shame, no deficit language, no streak threats.

enum ActivationPushPolicy {

    // D0-D3 activation nudges: only for not-yet-activated users, hard cap 3.
    //
    // Parameters
    // - dayIndex:         which day slot (1, 2, or 3 - D0 was cut in v2)
    // - hasEverActed:     true if the user has EVER completed a core action
    //                     (session save or food log); activation nudges are
    //                     suppressed for anyone already activated. Derive from
    //                     shownUpCount > 0 at the call site.
    // - alreadyScheduled: total activation-category pushes already queued
    //                     this install (tracked separately from the engaged
    //                     re-arm to avoid double-counting).
    //
    // Returns true only when all three guards pass:
    //   1. dayIndex is within the D0-D3 window
    //   2. user has NEVER acted (hasEverActed is false)
    //   3. fewer than 3 activation pushes have already been scheduled
    static func shouldSchedule(
        dayIndex: Int,
        hasEverActed: Bool,
        alreadyScheduled: Int
    ) -> Bool {
        guard dayIndex >= 1, dayIndex <= 3 else { return false }
        guard !hasEverActed else { return false }
        return alreadyScheduled < 3
    }
}
