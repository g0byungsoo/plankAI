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

    /// D6 — the era's kill switch. The founder can disable THE FIRST
    /// PLATE without a revert: set `e5.firstPlate.disabled` true and the
    /// gate is byte-for-byte the pre-E5 gate (pinned in AppPhaseTests).
    private static let disabledKey = "e5.firstPlate.disabled"

    static var isEnabled: Bool {
        #if DEBUG
        // QA can force the beat back open on an already-resolved device.
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-first-plate") {
            return true
        }
        #endif
        return !UserDefaults.standard.bool(forKey: disabledKey)
    }

    static var outcome: FirstPlateOutcome {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        // `--uitest-first-plate-done` wins: it exists to land on the
        // after-proof wall, which the force-open door would otherwise
        // reset back to the invite.
        if args.contains("--uitest-force-first-plate"),
           !args.contains("--uitest-first-plate-done") {
            return .none
        }
        #endif
        let raw = UserDefaults.standard.string(forKey: outcomeKey) ?? ""
        return FirstPlateOutcome(rawValue: raw) ?? .none
    }

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

    /// Sign-out sweeps user-scoped state; the proof beat is per-person,
    /// not per-device, so a fresh account earns its own first plate.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: outcomeKey)
    }
}
