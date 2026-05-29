import Foundation
import UserNotifications

/// Local, additive retention notifications layered on top of the daily
/// reminder (`NotificationPermission`) and the trial-end reminder
/// (`TrialEndNotificationService`).
///
/// Everything here is LOCAL + identifier-scoped + idempotent + toggleable +
/// frequency-capped, with no DB schema and no new permission prompt — it
/// piggybacks the single notifications permission the daily reminder already
/// requests. Existing users are unaffected unless they already have
/// notifications authorized, in which case they get these gentle additions,
/// each independently toggleable in NotificationSettingsView.
///
/// Voice = Blend: identity/hope affirmations + gentle progress framed from
/// the user's own data. Never scale-shame, labor verbs, or streak-loss
/// threats (matches `NotificationPermission.dailyReminderBody`).
enum RetentionNotifications {

    // MARK: - Identifiers

    /// Single re-armed "we miss you" nudge. Re-scheduled from now on every
    /// completed session, so it only ever fires after a genuine lapse.
    static let winbackIdentifier = "winback_lapse"
    /// Affirmation drops are scheduled as a small rolling window of dated
    /// one-shots (`affirmation_drop_0…N`) so the copy can rotate — a single
    /// repeating trigger can't vary its body.
    private static let affirmationPrefix = "affirmation_drop_"

    // MARK: - Toggles (UserDefaults; default ON, gated on system permission)

    private enum Key {
        static let affirmationsEnabled = "notif.affirmations_enabled"
        static let winbackEnabled      = "notif.winback_enabled"
        static let lastSessionAt       = "notif.last_session_at"
        /// Latest distinct-days-shown-up count, stamped on each new day so
        /// the trial-end recap can surface it without a SwiftData read.
        static let shownUpCount        = "stats.shown_up_count"
        static func milestoneDone(_ n: Int) -> String { "notif.milestone_\(n)_done" }
    }

    /// Read-only count of distinct days shown up (stamped via
    /// `recordShownUpDay`). Used by TrialEndNotificationService's recap.
    static var shownUpCount: Int { UserDefaults.standard.integer(forKey: Key.shownUpCount) }

    /// Default ON: `object(forKey:) == nil` reads as enabled, so existing
    /// users (who never wrote the key) opt in by default, but only ever
    /// receive these if notifications are authorized.
    static var affirmationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Key.affirmationsEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Key.affirmationsEnabled) }
    }
    static var winbackEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Key.winbackEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Key.winbackEnabled) }
    }

    // MARK: - Tunables

    /// Days of quiet before the win-back fires (re-armed each session).
    private static let winbackAfterDays = 3
    /// Calm hour (24h) for affirmation drops — offset from the typical
    /// morning daily-reminder slot so the two channels don't read as one.
    private static let affirmationHour = 13
    /// Weekdays (1=Sun…7=Sat) affirmations land on. Two per week keeps the
    /// total gentle even when the daily reminder is also on.
    private static let affirmationWeekdays: Set<Int> = [3, 7] // Tue, Sat
    /// How many future affirmation occurrences to keep scheduled. Re-filled
    /// each launch so the copy stays fresh and always a step ahead.
    private static let affirmationLookahead = 6
    /// Distinct-days-shown-up counts that earn a celebration. Each fires
    /// once (guarded by a done-flag). Celebration only — never loss-framed.
    private static let milestones = [3, 7, 14, 30, 50, 100]
    /// Hour (24h) the milestone celebration lands the next morning — a
    /// surprise the day after, not an interruption mid-workout.
    private static let milestoneHour = 9

    // MARK: - Public API

    /// Re-arm everything. Call on app launch. No-op (and never prompts) when
    /// notifications aren't authorized.
    static func reschedule(now: Date = .now) {
        Task {
            guard await isAuthorized() else { return }
            armWinback(now: now)
            scheduleAffirmations(now: now)
        }
    }

    /// Stamp last-session and re-arm the win-back from now. Call when a
    /// session is persisted (HomeView.saveRoutineSession / saveBenchmarkSession).
    static func markSessionCompleted(now: Date = .now) {
        UserDefaults.standard.set(now, forKey: Key.lastSessionAt)
        Task {
            guard await isAuthorized() else { return }
            armWinback(now: now)
        }
    }

    /// Re-apply after a category toggle changes in settings.
    static func applyTogglesChanged() {
        let center = UNUserNotificationCenter.current()
        if !affirmationsEnabled {
            center.removePendingNotificationRequests(withIdentifiers: affirmationIdentifiers())
        }
        if !winbackEnabled {
            center.removePendingNotificationRequests(withIdentifiers: [winbackIdentifier])
        }
        reschedule()
    }

    /// Remove every retention notification + clear one-time state (account
    /// delete / full opt-out), so a fresh user on this device starts clean.
    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [winbackIdentifier] + affirmationIdentifiers() + milestoneIdentifiers())
        let d = UserDefaults.standard
        milestones.forEach { d.removeObject(forKey: Key.milestoneDone($0)) }
        d.removeObject(forKey: Key.shownUpCount)
        d.removeObject(forKey: Key.lastSessionAt)
    }

    // MARK: - Win-back

    private static func armWinback(now: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [winbackIdentifier])
        guard winbackEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "still here for you."
        content.body = winbackBody()
        content.sound = .default

        let interval = TimeInterval(winbackAfterDays * 24 * 60 * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: winbackIdentifier, content: content, trigger: trigger))
    }

    private static func winbackBody() -> String {
        let name = (UserDefaults.standard.string(forKey: "userName") ?? "").lowercased()
        let opener = name.isEmpty ? "" : "\(name), "
        let lines = [
            "\(opener)one slip doesn't undo you. a short one's still here when you are ♥",
            "\(opener)no catching up needed. just come back when you can.",
            "\(opener)five minutes is enough to feel like you again.",
        ]
        return lines.randomElement() ?? lines[0]
    }

    // MARK: - Affirmation drops

    private static func affirmationIdentifiers() -> [String] {
        (0..<affirmationLookahead).map { "\(affirmationPrefix)\($0)" }
    }

    private static func scheduleAffirmations(now: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: affirmationIdentifiers())
        guard affirmationsEnabled else { return }

        let calendar = Calendar.current
        let library = affirmationLibrary()
        guard !library.isEmpty else { return }
        let coachName = CoachAsset.displayName(for: UserDefaults.standard.string(forKey: "voicePreference") ?? "encouraging")

        var scheduled = 0
        var libIndex = Int.random(in: 0..<library.count)
        var dayCursor = 0

        // Walk forward day-by-day; on an affirmation weekday past the calm
        // hour, schedule the next rotating line. Cap at the lookahead window.
        while scheduled < affirmationLookahead && dayCursor < 60 {
            defer { dayCursor += 1 }
            guard let day = calendar.date(byAdding: .day, value: dayCursor, to: calendar.startOfDay(for: now)) else { break }
            guard affirmationWeekdays.contains(calendar.component(.weekday, from: day)) else { continue }

            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = affirmationHour
            comps.minute = 0
            guard let fireDate = calendar.date(from: comps), fireDate > now.addingTimeInterval(60) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "a note from \(coachName)."
            content.body = library[libIndex % library.count]
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false)
            center.add(UNNotificationRequest(identifier: "\(affirmationPrefix)\(scheduled)", content: content, trigger: trigger))
            scheduled += 1
            libIndex += 1
        }
    }

    /// Blend voice: identity/hope affirmations, personalized by
    /// `identityFeeling` + name where present. No scale numbers, no shame.
    private static func affirmationLibrary() -> [String] {
        let d = UserDefaults.standard
        let name = (d.string(forKey: "userName") ?? "").lowercased()
        let becoming: String
        switch d.string(forKey: "identityFeeling") ?? "" {
        case "powerful": becoming = "you're becoming someone strong."
        case "calm":     becoming = "you're becoming someone steady."
        case "light":    becoming = "you're becoming someone light on her feet."
        case "strong":   becoming = "you're becoming someone strong."
        case "radiant":  becoming = "you're becoming someone who glows."
        default:         becoming = "you're becoming someone who shows up."
        }
        var lines = [
            becoming,
            "small moves still count. they always have ♥",
            "you don't have to feel ready. you just have to begin.",
            "the version of you that shows up is already winning.",
            "progress is quiet. you're making it anyway.",
            "be the kind of friend to yourself you'd be to someone you love.",
        ]
        if !name.isEmpty {
            lines.append("\(name), today's a good day to be gentle with yourself.")
        }
        return lines
    }

    // MARK: - Milestones

    private static func milestoneIdentifiers() -> [String] {
        milestones.map { "milestone_\($0)" }
    }

    /// Record a newly-reached engagement day (a distinct day shown up).
    /// Stamps the count for the trial recap and fires a one-time milestone
    /// celebration when the count crosses a threshold. Call from the
    /// new-day branch of the session-save paths.
    static func recordShownUpDay(count: Int) {
        UserDefaults.standard.set(count, forKey: Key.shownUpCount)
        scheduleMilestoneIfNeeded(count: count)
    }

    private static func scheduleMilestoneIfNeeded(count: Int) {
        // Shares the affirmations toggle — both are gentle "notes from your
        // coach," so one switch keeps settings clean.
        guard affirmationsEnabled, milestones.contains(count) else { return }
        let doneKey = Key.milestoneDone(count)
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }

        Task {
            guard await isAuthorized() else { return }
            let calendar = Calendar.current
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) else { return }
            var comps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            comps.hour = milestoneHour
            comps.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "a little milestone."
            content.body = milestoneBody(count: count)
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "milestone_\(count)", content: content, trigger: trigger))
            UserDefaults.standard.set(true, forKey: doneKey)
        }
    }

    private static func milestoneBody(count: Int) -> String {
        let name = (UserDefaults.standard.string(forKey: "userName") ?? "").lowercased()
        let tail = name.isEmpty ? "" : " \(name)"
        switch count {
        case 3:   return "three days in\(tail). you're building something ♥"
        case 7:   return "you've shown up seven times. that's who you are now."
        case 14:  return "two weeks of showing up\(tail). look at you."
        case 30:  return "thirty days. this isn't a phase anymore — it's you."
        case 50:  return "fifty times. quietly, you became someone consistent."
        case 100: return "one hundred\(tail). you're not the same person as day one ♥"
        default:  return "another day shown up. that's the whole secret ♥"
        }
    }

    // MARK: - Permission

    private static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
