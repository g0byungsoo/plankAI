import Foundation

// MARK: - AppPhase
//
// App v2 (docs/app_v2/07_GATING.md). The route-level phase machine
// that replaces the paywall-cover-over-content model. Exactly one
// phase is mounted at a time; unpaid and expired users never have
// main-app content in the hierarchy at all.
//
// `derive` is PURE — a total function over Inputs — so the entire
// gate is table-testable (AppPhaseTests). RootView assembles Inputs
// from the live observables each body pass; @Observable tracking
// keeps it current.

/// v25 E5 — where a new user stands with THE FIRST PLATE. Persisted
/// once and never re-offered (`FirstPlateState`).
enum FirstPlateOutcome: String, Equatable {
    /// Never offered, or offered and still open.
    case none
    /// Declined the beat. The wall shows the face it always showed.
    case skipped
    /// Logged a real plate. The wall opens knowing it.
    case logged
}

enum AppPhase: Equatable {
    case booting
    case onboarding
    /// v25 E5 THE FIRST PLATE — the one real thing Jeni does before she
    /// asks for money. Bounded: one capture, one reading, one saved
    /// record, then the wall. See docs/app_v25/17_E5_DECISION.md.
    case proof
    case wall(WallReason)
    /// Existing users (legacy footprint) meeting v2 for the first time.
    case migration
    case main

    enum WallReason: Equatable {
        /// Completed onboarding, never held the entitlement.
        case fresh
        /// Held it once; not active now. Gets the welcome-back wall.
        case expired
        /// v25 E5 — arrived here having just logged a real first plate.
        /// Same wall, same prices, same controls; it opens by naming
        /// what she just did instead of asking cold.
        case afterProof
    }
}

enum AppPhaseMachine {

    struct Inputs: Equatable {
        var hasCompletedOnboarding: Bool
        var authReady: Bool
        var entitlementReady: Bool
        var loaderHoldDone: Bool
        var hasPro: Bool
        /// v8 THE DOOR: a live clinic connection entitles the app
        /// without the subscription wall (the provider carries the
        /// relationship). Server-verified at sync; revocation clears
        /// it. B2C stays hard-walled.
        var hasCareEntitlement: Bool = false
        var isInAuthTransition: Bool
        var wasEverEntitled: Bool
        var appV2Seen: Bool
        var hasLegacyFootprint: Bool
        /// The phase we last showed while stable — held through auth
        /// transitions so a sign-in never flashes the wall (the old
        /// model's ≤500ms uncovered window, inverted: we hold the
        /// PREVIOUS phase instead of unmounting the gate).
        var lastStablePhase: AppPhase?
        /// v25 E5 D6 — the era's kill switch. False restores the exact
        /// pre-E5 gate (asserted in AppPhaseTests).
        var firstPlateEnabled: Bool = false
        /// Where this user stands with the proof beat.
        var firstPlateOutcome: FirstPlateOutcome = .none
    }

    static func derive(_ i: Inputs) -> AppPhase {
        // Pre-onboarding launches wait on auth + the splash floor
        // only (entitlement is meaningless before an account exists).
        guard i.hasCompletedOnboarding else {
            if !i.authReady || !i.loaderHoldDone { return .booting }
            return .onboarding
        }

        // Completed onboarding: the gate needs the full boot set —
        // except that a care-entitled user doesn't wait on the
        // subscription stream (their entitlement isn't RevenueCat's).
        if !i.authReady || !i.loaderHoldDone {
            return .booting
        }
        if !i.entitlementReady && !i.hasCareEntitlement {
            return .booting
        }

        // Auth transition: RevenueCat is mid-identity-swap and its
        // transient not-entitled emit is a lie. Hold the last stable
        // phase; fall back to booting when there is none. Care-
        // entitled users don't ride the subscription stream, so the
        // hold never applies to them (a fresh clinic patient's
        // identity swap can dangle on a virgin install — the blank
        // .main entry the walker filmed).
        if i.isInAuthTransition && !i.hasPro && !i.hasCareEntitlement {
            return i.lastStablePhase ?? .booting
        }

        guard i.hasPro || i.hasCareEntitlement else {
            // v25 E5 THE FIRST PLATE. Unentitled, and the wall is where
            // 90-94% of everyone who finishes onboarding has always
            // ended (17_E5_DECISION §1.1). A genuinely NEW user gets one
            // real plate first. The closed set of exclusions:
            //   · already resolved it (offered exactly once)
            //   · ever held the entitlement (a lapsed payer gets the
            //     welcome-back wall, never a freebie)
            //   · a legacy footprint (they already had the app)
            //   · the flag is off (D6 — one line restores the old gate)
            if i.firstPlateEnabled,
               i.firstPlateOutcome == .none,
               !i.wasEverEntitled,
               !i.hasLegacyFootprint {
                return .proof
            }
            if i.wasEverEntitled { return .wall(.expired) }
            return .wall(i.firstPlateOutcome == .logged ? .afterProof : .fresh)
        }

        // Entitled. Existing users see the one-time v2 welcome first.
        if !i.appV2Seen && i.hasLegacyFootprint {
            return .migration
        }

        return .main
    }

    /// Phases worth remembering for transition-hold. Booting isn't
    /// (holding a splash is meaningless) and wall isn't (holding a
    /// wall through sign-in would flash it over a paid account).
    /// `.proof` IS stable: an identity swap mid-capture must not yank
    /// the camera out from under someone's lunch.
    static func isStable(_ phase: AppPhase) -> Bool {
        switch phase {
        case .main, .migration, .onboarding, .proof: return true
        case .booting, .wall: return false
        }
    }
}
