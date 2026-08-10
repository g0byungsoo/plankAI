import Foundation
import PlankSync
import SwiftData
import UserNotifications

// MARK: - MedicationReminders (app v24 THE REGIMEN)
//
// docs/app_v24/00_REGIMEN.md §4 — the dose reminder engine, and the
// app's FIRST actionable notification category. Laws it carries:
//
// - NEVER the medication's name in a payload (the RegimenSheet
//   privacy line, verbatim since v8: "never named in notifications").
//   Copy speaks "your shot" / "your pill".
// - Actions are taken · in an hour · log later. NO lock-screen skip
//   (an accident magnet); skipping lives in the sheet with reasons.
// - Calendar triggers are WALL CLOCK: iOS re-evaluates them when
//   the timezone changes, so travel never moves her reminder hour —
//   the same anchoring law as the schedule engine.
// - Medication reminders are her explicit per-regimen opt-in
//   (reminderEnabled) under the master notifications toggle. They
//   are her medical rhythm, not engagement: they SURVIVE breaks
//   (BreakState kills the anchor ladder, not these) and are not
//   gated by the day-2 first-days consent.
// - Surgical pending-removal: every refresh replaces the family,
//   never stacks. One follow-up per open slot, never a ladder.

@MainActor
enum MedicationReminders {

    // Identifiers (the family the sweeps remove).
    static let reminderId = "med_dose_reminder"
    static let snoozeId = "med_dose_snooze"
    static let openFollowUpId = "med_dose_open"
    static let allIds = [reminderId, snoozeId, openFollowUpId]

    // The category + its actions.
    static let categoryId = "MED_DOSE"
    static let actionTaken = "MED_TAKEN"
    static let actionSnooze = "MED_SNOOZE"
    static let actionLogLater = "MED_LOG_LATER"

    /// P3 assigns the container-bound handler that marks the dose
    /// (NotificationDelegate stays storage-free). Nil = actions
    /// fall back to opening the app.
    static var onTakenAction: (@MainActor () -> Void)?

    // MARK: Category registration (called from install())

    static func registerCategories() {
        let taken = UNNotificationAction(
            identifier: actionTaken,
            title: "taken",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: actionSnooze,
            title: "in an hour",
            options: []
        )
        let logLater = UNNotificationAction(
            identifier: actionLogLater,
            title: "log later",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryId,
            actions: [taken, snooze, logLater],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: Refresh (the one scheduler)

    /// Re-derive the reminder family from the active regimen.
    /// Called from launch, regimen mutations, dose marks and the
    /// significant-time-change observer. Removes everything first —
    /// replace, never stack.
    static func refresh(userId: String, in context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIds)

        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        guard let plan = RegimenService.activeMedicationPlan(userId: userId, in: context),
              plan.reminderEnabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional else { return }

        let facts = RegimenService.facts(for: plan)
        let minutes = facts.resolvedMinutes
        let isOral = facts.isOral
        let emptyStomach = MedicationCatalog.product(id: plan.productId)?.emptyStomach ?? false

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = categoryId
        content.userInfo = ["deeplink": "jenifit://today"]

        var trigger: UNCalendarNotificationTrigger?
        switch facts.scheduleRule {
        case "weeklyAnchor":
            guard let iso = facts.anchorWeekday else { break }
            content.title = "today's your shot day."
            content.body = "mark it when it's taken. one tap here works too."
            var components = DateComponents()
            components.weekday = iso == 7 ? 1 : iso + 1
            components.hour = minutes / 60
            components.minute = minutes % 60
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case "daily":
            if isOral && emptyStomach {
                content.title = "your pill, before breakfast."
                content.body = "water only, then a quiet half hour. mark it when it's taken."
            } else if isOral {
                content.title = "today's pill."
                content.body = "mark it when it's taken. one tap here works too."
            } else {
                content.title = "today's dose."
                content.body = "mark it when it's taken. one tap here works too."
            }
            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        default:
            break
        }

        if let trigger {
            try? await center.add(UNNotificationRequest(
                identifier: reminderId, content: content, trigger: trigger
            ))
        }

        scheduleOpenFollowUpIfNeeded(
            plan: plan, facts: facts, userId: userId, in: context, center: center
        )
    }

    /// One gentle next-morning line when a WEEKLY slot went
    /// unmarked (its late window is open; daily windows close at
    /// midnight — tomorrow's reminder is the next touch). Scheduled
    /// ahead for the next slot; cancelled by a mark.
    private static func scheduleOpenFollowUpIfNeeded(
        plan: RegimenPlanRecord,
        facts: MedicationScheduleEngine.RegimenFacts,
        userId: String,
        in context: ModelContext,
        center: UNUserNotificationCenter
    ) {
        guard facts.scheduleRule == "weeklyAnchor" else { return }
        let events = DoseEventStore.slotEvents(userId: userId, in: context)
        guard let next = MedicationScheduleEngine.nextDoseDate(
            after: .now, facts: facts, events: events
        ) else { return }

        // The morning after the next slot, 9:30 wall clock.
        let calendar = Calendar.current
        guard let dayAfter = calendar.date(byAdding: .day, value: 1, to: next),
              let fireDate = calendar.date(
                bySettingHour: 9, minute: 30, second: 0, of: dayAfter
              ), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "yesterday's shot is still open."
        content.body = "log it late, or let it go. both are fine."
        content.sound = .default
        content.userInfo = ["deeplink": "jenifit://today"]

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        center.add(UNNotificationRequest(
            identifier: openFollowUpId,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
    }

    // MARK: Actions

    /// Route a category action. Returns true when handled.
    static func handleAction(_ actionIdentifier: String) -> Bool {
        switch actionIdentifier {
        case actionTaken:
            // Cancel the follow-up + snooze immediately; the
            // container-bound mark (assigned at launch) lands the
            // dose event + observation + checklist state.
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(
                    withIdentifiers: [snoozeId, openFollowUpId]
                )
            onTakenAction?()
            return true
        case actionSnooze:
            scheduleSnooze()
            return true
        case actionLogLater:
            // .foreground action — the tap opens the app; the
            // deeplink in userInfo lands her on Today where the
            // dose row waits.
            return true
        default:
            return false
        }
    }

    private static func scheduleSnooze() {
        let content = UNMutableNotificationContent()
        content.title = "your dose, again."
        content.body = "whenever you're ready. mark it when it's taken."
        content.sound = .default
        content.categoryIdentifier = categoryId
        content.userInfo = ["deeplink": "jenifit://today"]
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: snoozeId,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3_600, repeats: false)
        ))
    }

    /// A mark landed (any surface) — the day's reminders retire.
    static func onDoseMarked() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [snoozeId, openFollowUpId]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [reminderId, snoozeId]
        )
    }

    /// The master-toggle sweep (NotificationSettingsView off).
    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: allIds
        )
    }
}
