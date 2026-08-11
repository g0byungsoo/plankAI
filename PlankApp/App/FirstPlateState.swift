import Foundation

// MARK: - FirstPlateState (v25 E5 — THE FIRST PLATE)
//
// The one piece of memory the proof beat needs: has this person been
// offered their first plate, and what did they do about it.
//
// Why this exists at all — docs/app_v25/17_E5_DECISION.md §1.1. Across
// three shipping builds, 6-10% of everyone who finishes onboarding ever
// reaches one screen of the product. Every era since E1 built
// intelligence for a population of roughly twenty people per release.
// This state is the switch that lets a person meet Jeni before Jeni
// asks them for money.
//
// Deliberately NOT a store, a table, or a synced entity: it is one
// local fact about one device's first run. If it is lost, the worst
// case is that a never-entitled user is offered one more plate.

@MainActor
enum FirstPlateState {

    private static let outcomeKey = "e5.firstPlate.outcome"

    // MARK: - The production flag (founder steer, 2026-08-11)
    //
    // THE FIRST PLATE IS OFF IN PRODUCTION AND SHIPS OFF.
    //
    // The hard-paywall funnel is under an active production test, and
    // proof-before-paywall is a different experiment. Mixing them would
    // contaminate both: any movement in the purchase rate could be
    // attributed to either change, and neither would be measurable. So
    // the era stays built, tested and dormant until it can run as a
    // clean experiment on its own.
    //
    // Production order is therefore unchanged and remains:
    //   onboarding → hard paywall → purchase/entitlement → jeni
    //
    // The flag is an EXPLICIT ENABLE, not a kill switch. An enable that
    // defaults false cannot be left on by an unset key, a wiped
    // UserDefaults, a fresh install or a restored backup — the failure
    // mode of a `disabled` key is "the experiment silently ships", and
    // that is the one outcome this steer forbids.
    //
    // To run the experiment later: set `e5.firstPlate.enabled` true
    // (remotely or in a build) and nothing else changes — every path
    // below is already built, walked and pinned.
    private static let enabledKey = "e5.firstPlate.enabled"

    static var isEnabled: Bool {
        #if DEBUG
        // QA walks BOTH states; the walkers force the on-state.
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-first-plate") {
            return true
        }
        #endif
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var outcome: FirstPlateOutcome {
        let raw = UserDefaults.standard.string(forKey: outcomeKey) ?? ""
        return FirstPlateOutcome(rawValue: raw) ?? .none
    }

    #if DEBUG
    /// `--uitest-force-first-plate` re-opens the beat on a device that
    /// already resolved it. It CLEARS the stored outcome once at launch
    /// rather than overriding the getter — the first cut overrode the
    /// getter, which meant the flow could never resolve and the walker's
    /// decline leg silently proved nothing (frame-caught: the capture
    /// declined and the invite came straight back).
    static func applyQAOverridesAtLaunch() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--uitest-force-first-plate") else { return }
        if args.contains("--uitest-first-plate-done") {
            UserDefaults.standard.set(
                FirstPlateOutcome.logged.rawValue, forKey: outcomeKey
            )
        } else {
            reset()
        }
    }
    #endif

    /// She logged a real plate. Stamped once; a later relaunch must not
    /// re-offer the beat, and the wall it hands off to opens knowing.
    static func markLogged() {
        guard outcome == .none else { return }
        UserDefaults.standard.set(
            FirstPlateOutcome.logged.rawValue, forKey: outcomeKey
        )
    }

    /// She passed. Recorded, respected, never asked again — the same
    /// law every other declined offer in the product lives under.
    static func markSkipped() {
        guard outcome == .none else { return }
        UserDefaults.standard.set(
            FirstPlateOutcome.skipped.rawValue, forKey: outcomeKey
        )
    }

    private static let attemptsKey = "e5.firstPlate.attempts"

    /// The capture closed with no plate on the record. That is usually a
    /// decline — but on a first run it is also what a dropped network,
    /// a denied camera permission, or a mistap looks like, and the vision
    /// call is the one step here that can fail through no fault of hers.
    ///
    /// So the FIRST empty return leaves the beat open (she lands back on
    /// the invite, which always carries "not right now"); the second
    /// resolves it. One retry, never a loop.
    ///
    /// - Returns: true when the beat resolved, false when it stays open.
    @discardableResult
    static func markCaptureClosedWithoutAPlate() -> Bool {
        guard outcome == .none else { return true }
        let attempts = UserDefaults.standard.integer(forKey: attemptsKey) + 1
        UserDefaults.standard.set(attempts, forKey: attemptsKey)
        guard attempts >= 2 else { return false }
        markSkipped()
        return true
    }

    /// Sign-out sweeps user-scoped state; the proof beat is per-person,
    /// not per-device, so a fresh account earns its own first plate.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: outcomeKey)
        UserDefaults.standard.removeObject(forKey: attemptsKey)
    }
}
