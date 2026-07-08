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

enum AppPhase: Equatable {
    case booting
    case onboarding
    case wall(WallReason)
    /// Existing users (legacy footprint) meeting v2 for the first time.
    case migration
    case main

    enum WallReason: Equatable {
        /// Completed onboarding, never held the entitlement.
        case fresh
        /// Held it once; not active now. Gets the welcome-back wall.
        case expired
    }
}

enum AppPhaseMachine {

    struct Inputs: Equatable {
        var hasCompletedOnboarding: Bool
        var authReady: Bool
        var entitlementReady: Bool
        var loaderHoldDone: Bool
        var hasPro: Bool
        var isInAuthTransition: Bool
        var wasEverEntitled: Bool
        var appV2Seen: Bool
        var hasLegacyFootprint: Bool
        /// The phase we last showed while stable — held through auth
        /// transitions so a sign-in never flashes the wall (the old
        /// model's ≤500ms uncovered window, inverted: we hold the
        /// PREVIOUS phase instead of unmounting the gate).
        var lastStablePhase: AppPhase?
    }

    static func derive(_ i: Inputs) -> AppPhase {
        // Pre-onboarding launches wait on auth + the splash floor
        // only (entitlement is meaningless before an account exists).
        guard i.hasCompletedOnboarding else {
            if !i.authReady || !i.loaderHoldDone { return .booting }
            return .onboarding
        }

        // Completed onboarding: the gate needs the full boot set.
        if !i.authReady || !i.entitlementReady || !i.loaderHoldDone {
            return .booting
        }

        // Auth transition: RevenueCat is mid-identity-swap and its
        // transient not-entitled emit is a lie. Hold the last stable
        // phase; fall back to booting when there is none.
        if i.isInAuthTransition && !i.hasPro {
            return i.lastStablePhase ?? .booting
        }

        guard i.hasPro else {
            return .wall(i.wasEverEntitled ? .expired : .fresh)
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
    static func isStable(_ phase: AppPhase) -> Bool {
        switch phase {
        case .main, .migration, .onboarding: return true
        case .booting, .wall: return false
        }
    }
}
