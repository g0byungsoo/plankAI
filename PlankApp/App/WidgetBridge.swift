import Foundation
import SwiftData
import WidgetKit

// MARK: - WidgetBridge (app v25 pass 58)
//
// The ONLY writer of the widget's snapshot. Publishes from the same
// launch/foreground chokepoint that refreshes cohort identity (Home's
// refresh — the moment a TodaySnapshot is already in hand), and from
// the scene-background transition so a session's records reach the
// Home Screen the moment she leaves. Costs no widget budget while the
// app is foreground (Apple's stated exemption).
//
// Retirement is part of the contract: the sign-out sweep calls
// `retire()` so the NEXT account on this phone can never glance the
// previous one's protein — the same cross-account isolation law every
// other user-scoped store obeys.

@MainActor
enum WidgetBridge {

    static func publish(userId: String, in context: ModelContext) {
        guard !userId.isEmpty else { return }
        publish(from: TodayStateService.snapshot(userId: userId, in: context))
    }

    /// The zero-extra-queries path: callers who already hold a fresh
    /// TodaySnapshot hand it over.
    static func publish(from snap: TodaySnapshot) {
        JeniWidgetSnapshot(
            dayKey: TodayStateService.dayKey(),
            generatedAt: .now,
            proteinEatenG: snap.proteinEatenG,
            proteinFloorG: snap.targets.proteinG,
            kcalEaten: snap.kcalEaten,
            kcalTarget: snap.targets.kcal,
            plateCount: snap.plates.count,
            countUpOnly: snap.chapter == .onMedication,
            isMaintenance: snap.energyIsMaintenance,
            numericsSuppressed: snap.targets.numericsSuppressed,
            doseLine: doseLine(snap.doseStanding)
        ).write()
        WidgetCenter.shared.reloadTimelines(ofKind: "JeniTodayWidget")
    }

    /// The sweep's half: clear the shared store and let the widget
    /// fall back to its begin face.
    static func retire() {
        JeniWidgetSnapshot.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: "JeniTodayWidget")
    }

    /// DoseStanding's discretion, tightened for the most public
    /// surface the product has: never a product name, never an
    /// amount, and a skipped day stays HER business (silence).
    static func doseLine(_ standing: DoseStanding.Standing?) -> String? {
        switch standing {
        case .dueToday:
            return "shot today"
        case .late:
            return "a shot open to mark"
        case .doneToday:
            return "shot · done"
        case .skippedToday, .none:
            return nil
        case .upcoming(let days, let weekday):
            return days == 1 ? "shot tomorrow" : "next shot \(weekday)"
        }
    }
}
