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
    /// v1.0.7 trial-week additions. Day 0 anchor lands ~4h after install
    /// (clamped to 10am-9pm window, deferred to next-morning 10am if the
    /// 4h window falls outside that range). Day 2 engagement nudges
    /// users who haven't done a session yet by mid-day Wednesday-ish.
    /// Both fire ONCE per install (`*Done` flags) and are cancelled on
    /// any session save.
    static let day0AnchorIdentifier = "day0_anchor"
    static let day2EngagementIdentifier = "day2_engagement"

    // MARK: - Toggles (UserDefaults; default ON, gated on system permission)

    private enum Key {
        static let affirmationsEnabled = "notif.affirmations_enabled"
        static let winbackEnabled      = "notif.winback_enabled"
        static let lastSessionAt       = "notif.last_session_at"
        /// Latest distinct-days-shown-up count, stamped on each new day so
        /// the trial-end recap can surface it without a SwiftData read.
        static let shownUpCount        = "stats.shown_up_count"
        static func milestoneDone(_ n: Int) -> String { "notif.milestone_\(n)_done" }
        /// v1.0.7 — first time `reschedule()` ran on this install. Anchors
        /// the trial-week gating logic (Day 0 anchor, Day 2 engagement
        /// push, first-week affirmation pause). NOT the same as the
        /// JeniMethod enrollment timestamp — that's about the program
        /// arc; this is about retention windows. Idempotent stamp.
        static let firstSeenAt         = "notif.first_seen_at"
        /// One-shot flags for the trial-week pushes so a re-launch within
        /// the same install doesn't re-schedule a duplicate.
        static let day0AnchorDone      = "notif.day0_anchor_done"
        static let day2EngagementDone  = "notif.day2_engagement_done"
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
    /// notifications aren't authorized. v1.0.7 — also stamps firstSeenAt
    /// + schedules the trial-week anchors (Day 0 + Day 2) on first launch.
    static func reschedule(now: Date = .now) {
        stampFirstSeenIfNeeded(now: now)
        Task {
            guard await isAuthorized() else { return }
            armWinback(now: now)
            scheduleAffirmations(now: now)
            scheduleDay0AnchorIfNeeded(now: now)
            scheduleDay2EngagementIfNeeded(now: now)
        }
    }

    /// Stamp last-session and re-arm the win-back from now. Call when a
    /// session is persisted (HomeView.saveRoutineSession / saveBenchmarkSession).
    /// Also cancels the trial-week pushes — once the user engages, those
    /// "are you still there?" nudges are no longer needed.
    static func markSessionCompleted(now: Date = .now) {
        UserDefaults.standard.set(now, forKey: Key.lastSessionAt)
        // Cancel the Day 0 + Day 2 anchors. If they were scheduled for a
        // future moment, the user just gave us the engagement signal they
        // were designed to nudge, so firing them later reads as the app
        // not knowing what's happening.
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            day0AnchorIdentifier,
            day2EngagementIdentifier,
        ])
        // Stamp the *Done flags so the next reschedule() doesn't re-fire
        // them. Belt-and-suspenders with the removePending above.
        UserDefaults.standard.set(true, forKey: Key.day0AnchorDone)
        UserDefaults.standard.set(true, forKey: Key.day2EngagementDone)

        Task {
            guard await isAuthorized() else { return }
            armWinback(now: now)
        }
    }

    // MARK: - First-seen stamp + trial-week gating

    /// Stamp the first time the user's notification scheduler ran on this
    /// install. Anchors the trial-week math (Day 0 anchor, Day 2 push,
    /// first-week affirmation pause). Idempotent — re-calls preserve the
    /// original timestamp.
    static func stampFirstSeenIfNeeded(now: Date) {
        let d = UserDefaults.standard
        if d.object(forKey: Key.firstSeenAt) == nil {
            d.set(now, forKey: Key.firstSeenAt)
        }
    }

    static func firstSeenAt() -> Date? {
        UserDefaults.standard.object(forKey: Key.firstSeenAt) as? Date
    }

    /// True if `now` is within 7 calendar days of the user's first scheduling
    /// pass. Used to pause affirmation drops during the trial week so the
    /// per-week notification count stays under the research ceiling (5).
    /// Returns false on legacy installs that never stamped firstSeenAt (they
    /// are by definition past their first week).
    static func isWithinFirstWeek(now: Date = .now) -> Bool {
        guard let first = firstSeenAt() else { return false }
        let cal = Calendar.current
        guard let dayDelta = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: first),
            to: cal.startOfDay(for: now)
        ).day else { return false }
        return dayDelta < 7
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
            withIdentifiers: [
                winbackIdentifier,
                day0AnchorIdentifier,
                day2EngagementIdentifier,
            ] + affirmationIdentifiers() + milestoneIdentifiers()
        )
        let d = UserDefaults.standard
        milestones.forEach { d.removeObject(forKey: Key.milestoneDone($0)) }
        d.removeObject(forKey: Key.shownUpCount)
        d.removeObject(forKey: Key.lastSessionAt)
        // v1.0.7 — clear the trial-week stamps so a re-create on the same
        // device (account delete → onboarding again) gets a clean
        // firstSeenAt + fresh Day 0 / Day 2 anchors.
        d.removeObject(forKey: Key.firstSeenAt)
        d.removeObject(forKey: Key.day0AnchorDone)
        d.removeObject(forKey: Key.day2EngagementDone)
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
        // v1.0.7 — pause affirmations during the trial week so the total
        // push count for Day 0-7 stays under the 5-pushes/week ceiling
        // (Airbridge 2026: above 5/wk, 40%+ disable push permission).
        // Daily reminder + milestones + Day 0 anchor + Day 2 engagement
        // already total 2-4 pushes/week for an engaged trial user;
        // adding affirmations on top would tip over the line. Returns
        // the channel after the honeymoon — week 2+ gets the calm Tue/
        // Sat rhythm as before.
        guard !isWithinFirstWeek(now: now) else { return }

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

    // MARK: - Day 0 anchor (trial-week)
    //
    // Lands ~4 hours after onboarding completes (RetentionNotifications
    // .reschedule() stamps firstSeenAt on first call from PlankAIApp).
    // Single goal: combat the 55% of 3-day-trial cancels that happen on
    // Day 0 (Airbridge 2026 + RevenueCat State of Subscription Apps 2026).
    // Cancelled the moment the user saves a session — see markSessionCompleted.
    //
    // Timing logic: 4h is the sweet spot per habit-formation research
    // (Fogg) — long enough that the user has had time to install/forget,
    // short enough that the day's intention is still warm. Clamped to a
    // sane 10am-9pm window; pushes outside that range defer to the next
    // morning's 10am slot.

    private static func scheduleDay0AnchorIfNeeded(now: Date) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Key.day0AnchorDone) else { return }
        guard let fireDate = computeDay0AnchorDate(from: now) else { return }
        guard fireDate > now.addingTimeInterval(60) else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [day0AnchorIdentifier])

        let content = UNMutableNotificationContent()
        let name = (d.string(forKey: "userName") ?? "").lowercased()
        let opener = name.isEmpty ? "" : "\(name), "
        content.title = "five minutes today."
        content.body = "\(opener)your first day matters most. five minutes is enough to feel like you ♥"
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(
            identifier: day0AnchorIdentifier,
            content: content,
            trigger: trigger
        ))
        d.set(true, forKey: Key.day0AnchorDone)
    }

    /// 4h ahead, clamped to a [10am, 9pm] window. If now+4h is in window,
    /// fire then. Else defer to next-morning 10am.
    private static func computeDay0AnchorDate(from now: Date) -> Date? {
        let cal = Calendar.current
        guard let candidate = cal.date(byAdding: .hour, value: 4, to: now) else { return nil }
        let hour = cal.component(.hour, from: candidate)
        if hour >= 10 && hour < 21 {
            return candidate
        }
        // Defer to next-morning 10am.
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now) else { return nil }
        var comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = 10
        comps.minute = 0
        return cal.date(from: comps)
    }

    // MARK: - Day 2 engagement (trial-week)
    //
    // Lands on Day 2 at 10am local time. Designed for users who still
    // haven't completed a session on Day 1 — Day 2 is where the second
    // push to engage matters most before the trial honeymoon ends.
    //
    // We don't have access to SwiftData session counts from this pure
    // UserDefaults helper, so the gating happens via cancellation: if
    // any session saves between scheduling and Day 2 morning, the push
    // is cancelled (see markSessionCompleted). If it fires, the user is
    // definitively a no-session-yet Day-2 user.

    private static func scheduleDay2EngagementIfNeeded(now: Date) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Key.day2EngagementDone) else { return }
        guard let firstSeen = firstSeenAt() else { return }

        let cal = Calendar.current
        // Day 2 (calendar-day index 2 from firstSeen, so 48h+ later).
        guard let day2 = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: firstSeen)) else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: day2)
        comps.hour = 10
        comps.minute = 0
        guard let fireDate = cal.date(from: comps), fireDate > now.addingTimeInterval(60) else {
            // Past the fire window already (e.g. user just opened the app
            // on Day 3 for the first time). Stamp done so we don't re-try.
            d.set(true, forKey: Key.day2EngagementDone)
            return
        }

        let content = UNMutableNotificationContent()
        let name = (d.string(forKey: "userName") ?? "").lowercased()
        let opener = name.isEmpty ? "" : "\(name), "
        content.title = "the easiest start ♥"
        content.body = "\(opener)haven't tried jeni yet? a five-minute breath card is the gentlest way in."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: day2EngagementIdentifier,
            content: content,
            trigger: trigger
        ))
        d.set(true, forKey: Key.day2EngagementDone)
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
