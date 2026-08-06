import Foundation

// MARK: - TonightPlan (app v4, docs/app_v4/03_FEATURES.md §5)
//
// THE TONIGHT PLAN — a 15-second, chip-assembled if-then plan for
// the evening's one predictable moment (the kitchen calling).
// Evidence: implementation intentions carry d≈0.65 on goal
// attainment and MENU-PICKED plans work as well as self-written
// ones (Armitage; docs/app_v4/research/INTERACTIVE_METHOD.md) — a
// closed set of four kept-simple moves is evidence-defensible.
// Placement is the feature (buried craving tools go unfound):
// the evening close offers it in the flow, and the next morning's
// reading closes the loop by naming it back.
//
// Storage: device-local, identity-scoped ("plan." prefix rides the
// sign-out sweep). No hold-tracking in v4 — the reading references
// the plan she made (provenance-true), never grades whether it held.

enum TonightPlan {

    struct Option: Equatable, Identifiable {
        let key: String
        /// The chip label ("ride the wave").
        let label: String
        /// The if-then sentence the pick completes.
        let plan: String

        var id: String { key }
    }

    /// The closed set — one move per lane: surf, delay, structure,
    /// exit. Every option is an ADD or a RIDE, never a suppression.
    static let options: [Option] = [
        Option(key: "wave",
               label: "wait 60 seconds",
               plan: "if a craving hits, i wait 60 seconds before deciding."),
        Option(key: "tea",
               label: "tea first",
               plan: "if a craving hits, something warm comes first."),
        Option(key: "plate",
               label: "plate it properly",
               plan: "if i eat tonight, it goes on a plate at the table."),
        Option(key: "night",
               label: "an early night",
               plan: "if the evening drags, i go to bed early."),
    ]

    static func option(for key: String) -> Option? {
        options.first { $0.key == key }
    }

    private static func storageKey(_ dayKey: String) -> String {
        "plan.tonight.\(dayKey)"
    }

    /// Tonight's plan for a given day, if she set one.
    static func planned(
        dayKey: String, _ d: UserDefaults = .standard
    ) -> Option? {
        guard let key = d.string(forKey: storageKey(dayKey)) else { return nil }
        return option(for: key)
    }

    static func set(
        _ key: String, dayKey: String, _ d: UserDefaults = .standard
    ) {
        d.set(key, forKey: storageKey(dayKey))
    }
}
