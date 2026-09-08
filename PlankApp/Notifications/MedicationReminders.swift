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
    static let allIds = [
        reminderId, reminderId + ".second", snoozeId, openFollowUpId,
    ]

    // The category + its actions.
    static let categoryId = "MED_DOSE"
    static let actionTaken = "MED_TAKEN"
    static let actionSnooze = "MED_SNOOZE"
    static let actionLogLater = "MED_LOG_LATER"

    /// P3 assigns the container-bound handler that marks the dose
    /// (NotificationDelegate stays storage-free). Nil = actions
    /// fall back to opening the app.
    /// p82 — carries the slot day the action resolves (the reminder's
    /// own delivery day, see `actionSlotDayKey`).
    static var onTakenAction: (@MainActor (String) -> Void)?

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

    // p82 — the standing reminder's SHAPE, pure and pinnable. The
    // repeating calendar triggers (weekly, twice-weekly, daily) have
    // no resolved-today awareness, so a dose marked in the morning
    // still got "mark it when it's taken" at her reminder hour that
    // evening. The plan derives the honest shape from the same engine
    // arithmetic the interval branch always used.
    struct PlannedRequest: Equatable {
        enum Trigger: Equatable {
            /// A standing weekday rhythm (weekly / twice-weekly).
            case repeatingWeekday(DateComponents)
            /// A standing daily rhythm.
            case repeatingDaily(DateComponents)
            /// One fire at an exact instant (interval chains; a
            /// resolved slot's next occurrence).
            case oneShot(Date)
        }
        var id: String
        var title: String
        var body: String
        var trigger: Trigger
    }

    /// The standing reminder requests the current regimen earns.
    /// Pure over facts + events so the resolved-slot behavior is
    /// testable without the notification center.
    static func plannedStandingRequests(
        facts: MedicationScheduleEngine.RegimenFacts,
        events: [MedicationScheduleEngine.SlotEvent],
        isOral: Bool,
        emptyStomach: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [PlannedRequest] {
        let minutes = facts.resolvedMinutes
        let shotTitle = "today's your shot day."
        let markBody = "mark it when it's taken. one tap here works too."

        // p82 — a RESOLVED slot never re-fires its own reminder: when
        // today is a dose day and its event is already on the record,
        // the repeating trigger (which would still fire at her hour
        // tonight) is downgraded to a ONE-SHOT at the next unresolved
        // occurrence — the same engine arithmetic the interval branch
        // always used. Any later refresh (launch, mark, the reminder's
        // own "taken" action, a regimen edit) restores the repeating
        // rhythm, so the standing cadence survives everything except
        // total dormancy — where a single correct fire beats a stale
        // "mark it when it's taken" about a dose already logged.
        let todayKey = MedicationScheduleEngine.dayKey(for: now, calendar: calendar)
        let resolvedToday = events.contains {
            $0.dayKey == todayKey && $0.isResolved
        }
        let todayIsDoseDay = MedicationScheduleEngine.isDoseDay(
            now, facts: facts, events: [], calendar: calendar
        )
        func resolvedSlotOneShot(title: String, body: String) -> [PlannedRequest] {
            guard let next = MedicationScheduleEngine.nextDoseDate(
                after: now, facts: facts, events: events, calendar: calendar
            ), next > now else { return [] }
            return [.init(
                id: reminderId, title: title, body: body,
                trigger: .oneShot(next)
            )]
        }

        switch facts.scheduleRule {
        case "weeklyAnchor":
            guard let iso = facts.anchorWeekday else { return [] }
            if todayIsDoseDay, resolvedToday {
                return resolvedSlotOneShot(title: shotTitle, body: markBody)
            }
            var planned: [PlannedRequest] = []
            if let second = facts.weeklyAnchors.dropFirst().first {
                var extra = DateComponents()
                extra.weekday = second == 7 ? 1 : second + 1
                extra.hour = minutes / 60
                extra.minute = minutes % 60
                planned.append(.init(
                    id: reminderId + ".second", title: shotTitle,
                    body: markBody, trigger: .repeatingWeekday(extra)
                ))
            }
            var components = DateComponents()
            components.weekday = iso == 7 ? 1 : iso + 1
            components.hour = minutes / 60
            components.minute = minutes % 60
            planned.append(.init(
                id: reminderId, title: shotTitle,
                body: markBody, trigger: .repeatingWeekday(components)
            ))
            return planned
        case "intervalDays":
            guard let next = MedicationScheduleEngine.nextDoseDate(
                after: now, facts: facts, events: events, calendar: calendar
            ), next > now else { return [] }
            return [.init(
                id: reminderId, title: shotTitle,
                body: markBody, trigger: .oneShot(next)
            )]
        case "daily":
            let title: String
            let body: String
            if isOral && emptyStomach {
                title = "your pill, before breakfast."
                body = "water only, then a quiet half hour. mark it when it's taken."
            } else if isOral {
                title = "today's pill."
                body = markBody
            } else {
                title = "today's dose."
                body = markBody
            }
            if resolvedToday {
                return resolvedSlotOneShot(title: title, body: body)
            }
            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60
            return [.init(
                id: reminderId, title: title,
                body: body, trigger: .repeatingDaily(components)
            )]
        default:
            return []
        }
    }

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
        let isOral = facts.isOral
        let emptyStomach = MedicationCatalog.product(id: plan.productId)?.emptyStomach ?? false

        // p82 — the shape lives in plannedStandingRequests (pure,
        // pinned); this loop only materializes it. The p53 laws ride
        // inside: split rhythms never stack, interval chains stay
        // event-anchored one-shots, and a RESOLVED slot downgrades
        // its repeating trigger to a one-shot at the next occurrence.
        let events = DoseEventStore.slotEvents(userId: userId, in: context)
        for planned in plannedStandingRequests(
            facts: facts, events: events,
            isOral: isOral, emptyStomach: emptyStomach
        ) {
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.categoryIdentifier = categoryId
            content.userInfo = ["deeplink": "jenifit://today"]
            content.title = planned.title
            content.body = planned.body
            let trigger: UNCalendarNotificationTrigger
            switch planned.trigger {
            case .repeatingWeekday(let components),
                 .repeatingDaily(let components):
                trigger = UNCalendarNotificationTrigger(
                    dateMatching: components, repeats: true
                )
            case .oneShot(let date):
                trigger = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: date
                    ),
                    repeats: false
                )
            }
            try? await center.add(UNNotificationRequest(
                identifier: planned.id, content: content, trigger: trigger
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
        // p53: interval slots have a late window too; daily windows
        // still close at midnight (tomorrow's reminder is the touch).
        guard facts.scheduleRule == "weeklyAnchor"
            || facts.scheduleRule == "intervalDays" else { return }
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

    /// p82 — the slot a lock-screen "taken" resolves: the day the
    /// reminder was DELIVERED (a lingering notification tapped the
    /// next morning is about yesterday's slot, not today), falling
    /// back to today when the delivery day is unknown or stale.
    static func actionSlotDayKey(
        deliveredAt: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let todayKey = MedicationScheduleEngine.dayKey(for: now, calendar: calendar)
        guard let deliveredAt else { return todayKey }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: deliveredAt),
            to: calendar.startOfDay(for: now)
        ).day ?? .max
        guard (0...7).contains(days) else { return todayKey }
        return MedicationScheduleEngine.dayKey(for: deliveredAt, calendar: calendar)
    }

    /// Route a category action. Returns true when handled.
    static func handleAction(
        _ actionIdentifier: String, deliveredAt: Date? = nil
    ) -> Bool {
        switch actionIdentifier {
        case actionTaken:
            // Cancel the follow-up + snooze immediately; the
            // container-bound mark (assigned at launch) lands the
            // dose event + observation + checklist state.
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(
                    withIdentifiers: [snoozeId, openFollowUpId]
                )
            Analytics.track(.doseReminderAction, properties: ["action": "taken"])
            onTakenAction?(actionSlotDayKey(deliveredAt: deliveredAt))
            return true
        case actionSnooze:
            Analytics.track(.doseReminderAction, properties: ["action": "snooze"])
            scheduleSnooze()
            return true
        case actionLogLater:
            // .foreground action — the tap opens the app; the
            // deeplink in userInfo lands her on Today where the
            // dose row waits.
            Analytics.track(.doseReminderAction, properties: ["action": "log_later"])
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
