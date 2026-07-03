import Foundation
import UserNotifications

// MARK: - NotificationOrchestrator (v2.6 — per-day anchor laddering)
//
// docs/app_v2/24_NOTIFICATION_ORCHESTRATOR.md. The daily anchor is a
// LADDER of seven one-shot notifications (ids anchor_d1..anchor_d7),
// each carrying THAT morning's line for the day it fires — tomorrow's
// archetype, her name, the program's voice. Rebuilt once per day from
// Today's refresh, so:
//   - a user away for a week hears seven DIFFERENT fresh lines, not
//     one stale repeat (v2.5's staleness bound removed);
//   - past day 7 of silence the ladder simply ends — no zombie nags
//     (the winback push is a different intent with its own budget).
//
// Surgical-removal discipline: ONLY the ladder ids + the legacy
// repeating ids are ever removed. Trial-end, day-1 promise, day-2
// engagement, and day-5 anti-refund pushes are never touched.

enum NotificationOrchestrator {

    /// Once-per-day guard so Today's refresh loop doesn't thrash
    /// the notification center.
    private static let lastRefreshKey = "orchestrator.anchorRefreshDayKey"

    static let ladderIds: [String] = (1...7).map { "anchor_d\($0)" }
    static let legacyIds: [String] = ["daily_reminder", "daily-plank"]

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
                scheduleLadder(programDay: programDay, totalDays: totalDays)
                d.set(todayKey, forKey: lastRefreshKey)
            }
        }
    }

    @MainActor
    private static func scheduleLadder(programDay: Int, totalDays: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ladderIds + legacyIds)

        let hour = NotificationTimeBucket.userPreferred.hour(for: .reminder) ?? 9
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let who = name.isEmpty ? "" : "\(name), "
        let cal = Calendar.current

        for offset in 1...7 {
            let targetProgramDay = programDay + offset
            guard targetProgramDay <= totalDays else { break }
            guard let fireDay = cal.date(byAdding: .day, value: offset, to: .now) else { continue }

            var comps = cal.dateComponents([.year, .month, .day], from: fireDay)
            comps.hour = hour
            comps.minute = 0

            let archetype = ProgramDayArchetype.archetype(
                forProgramDay: targetProgramDay,
                glp1Status: CohortStore.glp1StatusKey,
                restrictiveFoodRelationship: CohortStore.isRestrictiveRisk
            )

            let content = UNMutableNotificationContent()
            content.title = "day \(targetProgramDay) is ready"
            content.body = anchorLine(archetype, who: who, offset: offset)
            content.sound = .default
            content.userInfo = ["deeplink": "jenifit://today"]

            center.add(UNNotificationRequest(
                identifier: "anchor_d\(offset)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            ))
        }
    }

    /// The day's line — archetype voice, with the later rungs easing
    /// into begin-again register (day 3+ of silence is a comeback
    /// moment, not a reminder moment).
    private static func anchorLine(_ archetype: ProgramDayArchetype, who: String, offset: Int) -> String {
        if offset >= 3 {
            return "\(who)the plan kept your place. begin again, anytime \u{2665}"
        }
        switch archetype {
        case .protein:  return "\(who)today is a protein day. one strong plate at a time \u{2665}"
        case .movement: return "\(who)today is a movement day. small counts fully."
        case .balanced: return "\(who)today asks for steady, not perfect."
        case .rest:     return "\(who)today is a rest day. nothing heavy \u{2665}"
        }
    }
}
