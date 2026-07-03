import Foundation
import UserNotifications

// MARK: - NotificationOrchestrator (v2.5 — the anchor's voice)
//
// docs/app_v2/09_NOTIFICATIONS.md's core promise, implemented: the
// daily anchor speaks the SAME voice as the app — tomorrow's
// archetype line, at her hour, refreshed on every Today open so
// push and in-app copy never diverge. Same canonical id and the
// same surgical-removal discipline as the legacy scheduler (never
// touches trial-end or the day-1 promise).
//
// Staleness bound: the trigger repeats, so a user away for 2+ days
// hears the last-scheduled line until she returns — acceptable, and
// strictly better than the static line it replaces. Full per-day
// one-shot laddering arrives with the orchestrator consolidation.

enum NotificationOrchestrator {

    /// Once-per-day guard so Today's refresh loop doesn't thrash
    /// the notification center.
    private static let lastRefreshKey = "orchestrator.anchorRefreshDayKey"

    @MainActor
    static func refreshDailyAnchor(programDay: Int, totalDays: Int) {
        let d = UserDefaults.standard
        let todayKey = TodayStateService.dayKey()
        guard d.string(forKey: lastRefreshKey) != todayKey else { return }
        guard d.bool(forKey: "notificationsEnabled") else { return }
        guard programDay > 0, programDay < totalDays else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            Task { @MainActor in
                schedule(programDay: programDay)
                d.set(todayKey, forKey: lastRefreshKey)
            }
        }
    }

    @MainActor
    private static func schedule(programDay: Int) {
        let tomorrow = ProgramDayArchetype.archetype(
            forProgramDay: programDay + 1,
            glp1Status: CohortStore.glp1StatusKey,
            restrictiveFoodRelationship: CohortStore.isRestrictiveRisk
        )

        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let who = name.isEmpty ? "" : "\(name), "
        let body: String
        switch tomorrow {
        case .protein:
            body = "\(who)tomorrow is a protein day. one strong plate at a time \u{2665}"
        case .movement:
            body = "\(who)tomorrow is a movement day. small counts fully."
        case .balanced:
            body = "\(who)tomorrow asks for steady, not perfect."
        case .rest:
            body = "\(who)tomorrow is a rest day. nothing heavy \u{2665}"
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "daily_reminder", "daily-plank",
        ])

        let content = UNMutableNotificationContent()
        content.title = "your plan, tomorrow"
        content.body = body
        content.sound = .default
        content.userInfo = ["deeplink": "jenifit://today"]

        var components = DateComponents()
        components.hour = NotificationTimeBucket.userPreferred.hour(for: .reminder) ?? 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(
            identifier: "daily_reminder",
            content: content,
            trigger: trigger
        ))
    }
}
