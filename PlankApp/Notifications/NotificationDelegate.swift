import Foundation
import UserNotifications

// MARK: - NotificationDelegate
//
// App v2 (docs/app_v2/09_NOTIFICATIONS.md §Deep links). Pre-v2 there
// was no UNUserNotificationCenterDelegate at all — a tap just opened
// the app wherever it last was. Taps now route through AppRouter:
// the route is stored as pending state, and pending state is only
// CONSUMED by surfaces that exist in the .main phase — so a push
// tapped by an expired user resolves at the wall, never inside.
//
// Known notification ids map to destinations here; new categories
// can also carry an explicit `deeplink` in userInfo ("jenifit://…").

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func install() {
        UNUserNotificationCenter.current().delegate = self
        // v24 — the medication dose category (the app's first
        // actionable one) registers with the delegate so actions
        // exist before any reminder can fire.
        Task { @MainActor in
            MedicationReminders.registerCategories()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        let actionId = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            // v25 E1 — any interaction is engagement: the brain's
            // ignore streak resets for the send's category.
            NotificationBrain.recordEngaged(Self.brainCategory(forId: id))
            Analytics.track(.notifDelivered, properties: [
                "category": Self.brainCategory(forId: id).rawValue,
                "actioned": actionId != UNNotificationDefaultActionIdentifier,
            ])
            // v24 — category actions resolve WITHOUT opening a
            // surface ("taken" and "in an hour" are the whole
            // interaction; "log later" is a .foreground action and
            // falls through to the deeplink).
            if MedicationReminders.handleAction(actionId),
               actionId != MedicationReminders.actionLogLater {
                completionHandler()
                return
            }
            if
                let raw = userInfo["deeplink"] as? String,
                let url = URL(string: raw)
            {
                AppRouter.shared.handle(url: url)
            } else if let url = Self.destination(forNotificationId: id) {
                AppRouter.shared.handle(url: url)
            }
            completionHandler()
        }
    }

    /// v25 E1 — id → brain category (the engage/ignore ledger's key).
    static func brainCategory(forId id: String) -> NotificationBrain.Category {
        if id.hasPrefix("med_dose") { return .medication }
        if id == NotificationOrchestrator.reSigningKnockId { return .weeklyRead }
        if id.hasPrefix("winback") || id.hasPrefix("affirmation_drop") {
            return .reengagement
        }
        return .support
    }

    /// Foreground arrivals stay quiet — the app IS the notification
    /// when she's inside it (no banner-over-content noise).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    /// Existing id space → destinations. Prefix matching covers the
    /// indexed families (affirmation_drop_N, milestone_N).
    static func destination(forNotificationId id: String) -> URL? {
        let route: String?
        switch true {
        case id == "day1_promise":
            route = "jenifit://snap"
        // Release audit 2026-08-08 — the evening review promises "a
        // soft look back" but landed in the CAPTURE CAMERA; v23 made
        // the book (becoming) the look-back surface, so the push lands
        // there now. The first-log nudge stays a capture invitation.
        // v25 E4 — deeper still: the becoming ROOT left her one
        // scroll above the plates. jenifit://plates opens THE BOOK.
        case id == "evening_plate_review":
            route = "jenifit://plates"
        case id == "food_first_log_nudge":
            route = "jenifit://snap"
        case id == "becoming.sunday.recap":
            route = "jenifit://becoming"
        case id == "lapse_support":
            route = "jenifit://breath"   // the ping offers the brake
        case id == "daily_reminder",
             id == "winback_lapse",
             id == "day1_morning",
             id == "day5_anti_refund",
             id == "keeping_zone",
             id == "keeping_line_quiet",
             id.hasPrefix("milestone_"),
             id.hasPrefix("affirmation_drop_"):
            route = "jenifit://today"
        case id.contains("trial"):
            route = nil   // trial-end lands wherever the wall/phase says
        default:
            route = nil
        }
        return route.flatMap { URL(string: $0) }
    }
}
