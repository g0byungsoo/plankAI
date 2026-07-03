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
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
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
        case id == "evening_plate_review", id == "food_first_log_nudge":
            route = "jenifit://snap"
        case id == "becoming.sunday.recap":
            route = "jenifit://becoming"
        case id == "daily_reminder",
             id == "winback_lapse",
             id == "day1_morning",
             id == "day5_anti_refund",
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
