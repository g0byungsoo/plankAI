import Foundation
import UserNotifications

// MARK: - RecapNotificationService
//
// v1.1 Becoming P3b — the Sunday recap's push. One-shot (never a
// repeating trigger): it only gets scheduled once the CURRENT week
// has earned a recap (≥2 engaged days), so an empty week never gets
// a push pointing at a recap that won't present. Same-id replacement
// keeps it idempotent; at most one per week lives in the pending
// queue, inside the ≤5/wk research ceiling.
//
// Copy per the notification-voice lock: gentle progress from her own
// data, no labor verbs, no streak threats.

@MainActor
final class RecapNotificationService {
    static let shared = RecapNotificationService()
    private init() {}

    private let identifier = "becoming.sunday.recap"

    /// Schedule the upcoming Sunday 17:00 push when the current ISO
    /// week has earned its recap. Re-calls replace (same id), so the
    /// fire date stays correct as the week progresses. No-op when
    /// notifications aren't authorized or the week hasn't earned it.
    func scheduleIfEarned(engagedDaysThisWeek: Int, now: Date = .now) async {
        guard engagedDaysThisWeek >= 2 else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let cal = Calendar.current
        // Next Sunday 17:00 local (today if it's Sunday before 17:00).
        var target = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 17, minute: 0, weekday: 1),
            matchingPolicy: .nextTime
        )
        if cal.component(.weekday, from: now) == 1,
           cal.component(.hour, from: now) < 17,
           let todayAt5 = cal.date(bySettingHour: 17, minute: 0, second: 0, of: now) {
            target = todayAt5
        }
        guard let fireDate = target else { return }
        // Only schedule within the current ISO week — a push for NEXT
        // week's Sunday would claim a recap next week hasn't earned.
        guard cal.component(.weekOfYear, from: fireDate) == cal.component(.weekOfYear, from: now) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "your week, kept"
        content.body = "the recap is ready. \(engagedDaysThisWeek) days went into it."
        content.sound = .default

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
