import Foundation
import PlankSync
import SwiftData

// MARK: - CohortIdentity (v25 E2 — B1, the kill/redirect trigger)
//
// The decision doc's blind spot, closed: Jeni cannot currently state
// what share of its users are medicated — Glp1Cohort drives branching
// everywhere and never reaches analytics. These are the CATEGORICAL
// person properties (07_NEXT_ERA_DECISION §risk 4) that make cohort a
// PostHog person filter: glp1_cohort, medicated, med_route,
// med_cadence, med_authority. Never a product name, never a dose,
// never a schedule detail beyond cadence class (hygiene law).
//
// refresh() is fingerprint-deduped: properties re-send only when the
// derived identity actually changed (launch, regimen create/change/
// end, care plan arrival).

@MainActor
enum CohortIdentity {

    static let fingerprintKey = "analytics.cohortIdentity.fingerprint"

    /// Pure derivation — primitives in, person properties out.
    /// `route`/`cadence`/`authority` nil means no active regimen.
    nonisolated static func properties(
        cohortWord: String,
        route: String?,
        cadence: String?,
        authority: String?
    ) -> [String: Any] {
        let medicated = authority != nil
        return [
            "glp1_cohort": cohortWord,
            "medicated": medicated,
            "med_route": medicated ? (route ?? "unknown") : "none",
            "med_cadence": medicated ? (cadence ?? "unknown") : "none",
            "med_authority": authority ?? "none",
        ]
    }

    nonisolated static func fingerprint(of properties: [String: Any]) -> String {
        properties.keys.sorted()
            .map { "\($0)=\(properties[$0].map(String.init(describing:)) ?? "")" }
            .joined(separator: "|")
    }

    /// Derive from live state and send when changed. Call sites:
    /// Home refresh (launch + foreground), applySelfRegimen,
    /// endMedicationPlan, CareReconciliation.confirm, onboarding
    /// completion.
    static func refresh(
        userId: String,
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        guard !userId.isEmpty else { return }
        let plan = RegimenService.activeMedicationPlan(userId: userId, in: context)
        let props = properties(
            cohortWord: cohortWord(Glp1Cohort.current),
            route: plan?.route,
            cadence: plan?.scheduleRule,
            authority: plan.map {
                RegimenService.isManagedByCareTeam($0) ? "care_team" : "self"
            }
        )
        let print = fingerprint(of: props)
        guard defaults.string(forKey: fingerprintKey) != print else { return }
        defaults.set(print, forKey: fingerprintKey)
        Analytics.setPersonProperties(props)
    }

    nonisolated static func cohortWord(_ cohort: Glp1Cohort) -> String {
        switch cohort {
        case .onGlp1: "on_glp1"
        case .postGlp1: "post_glp1"
        case .considering: "considering_glp1"
        case .generalWL: "general"
        }
    }
}
