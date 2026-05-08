import Foundation
import UserNotifications

// MARK: - TrialEndNotificationService
//
// Schedules a single local notification 24 hours before the user's free
// trial converts to a paid subscription. Apple's introductory-offer
// guidelines require advance disclosure; this is also user-friendly —
// avoids surprise charges and gives one explicit "cancel before billing"
// moment.
//
// Permission is requested contextually at the moment scheduling happens
// (right after the user starts a trial), not during onboarding. iOS
// caches the user's response, so subsequent calls don't re-prompt.
//
// Identifier is fixed so we always schedule at most one reminder; a
// repeat schedule replaces the prior one, and cancel removes by identifier.

@MainActor
final class TrialEndNotificationService {
    static let shared = TrialEndNotificationService()
    private init() {}

    /// Stable identifier for the trial-end reminder. Lets us look it up
    /// by ID for cancellation without scanning the full pending list by
    /// content.
    private let identifier = "absmaxxing.trial.ending.reminder"

    /// Request permission + schedule the reminder for 24 hours before
    /// `trialEndDate`. Idempotent — repeated calls with the same date
    /// produce one pending notification (existing one is replaced when
    /// add() is called with the same identifier). Skipped when:
    ///   - permission is denied (silent — no fallback nag UI in v1)
    ///   - the fire date is already in the past or within the next
    ///     handful of seconds (no nag-after-the-fact)
    func scheduleIfNeeded(trialEndDate: Date) async {
        let fireDate = trialEndDate.addingTimeInterval(-86_400)  // 24h before
        guard fireDate > Date() else {
            #if DEBUG
            print("[TrialEndNotification] less than 24h until expiration — skipping")
            #endif
            return
        }

        let center = UNUserNotificationCenter.current()

        // requestAuthorization is iOS-cached: prompts on first call,
        // returns the prior decision instantly thereafter. So even if
        // we hit this path many times across launches it only ever asks
        // the user once.
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else {
                #if DEBUG
                print("[TrialEndNotification] permission denied — skipping")
                #endif
                return
            }
        } catch {
            #if DEBUG
            print("[TrialEndNotification] permission request FAILED: \(error)")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends tomorrow"
        content.body = "Tap to manage your subscription in iOS Settings if you'd like to cancel before billing starts."
        content.sound = .default

        // Calendar trigger pins to a specific wall-clock moment, not a
        // relative interval. Better behavior across device sleeps and
        // timezone changes than UNTimeIntervalNotificationTrigger.
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            #if DEBUG
            print("[TrialEndNotification] scheduled for date=\(fireDate) identifier=\(identifier)")
            #endif
        } catch {
            #if DEBUG
            print("[TrialEndNotification] schedule FAILED: \(error)")
            #endif
        }
    }

    /// Drop the pending trial-end reminder if one exists. No-op when no
    /// reminder is scheduled. Logs only when an actual cancellation
    /// happens, so we don't spam the console on every customerInfoStream
    /// reconcile pass.
    func cancelTrialEndReminder() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard pending.contains(where: { $0.identifier == identifier }) else { return }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        #if DEBUG
        print("[TrialEndNotification] cancelled identifier=\(identifier)")
        #endif
    }

    /// Bulk cleanup. Currently equivalent to cancelTrialEndReminder
    /// because there's only one reminder identifier; left as a separate
    /// method so delete-account / sign-out paths have a clear hook even
    /// if we add more reminder identifiers later.
    func cancelAllTrialReminders() async {
        await cancelTrialEndReminder()
    }
}
