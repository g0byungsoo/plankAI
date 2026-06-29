import Foundation
import UserNotifications

// MARK: - Glp1Cohort
//
// Cohort identity derived from the onboarding GLP-1 question
// (`onboarding_glp1_status` AppStorage). Single source of truth for
// trial-week notification routing. Adding new cohort strings to the
// onboarding question maps here, not at every call site.
//
// Voice: cohort tunes the noun ("the layer underneath the shot,"
// "the keep-it-off habit"); brand voice (lowercase casual,
// heart-as-terminal-punctuation, no labor verbs, no scale shame) is
// preserved across all variants. Matches the existing trial-week copy
// the generalWL branch keeps verbatim.
//
// Regulatory floor: app-controlled surfaces never name drug brand
// names (Apple 5.2.1) and never claim drug-equivalence (FTC NextMed +
// FDA Feb 2026 warning letters). The `considering` cohort copy
// avoids the substitution frame entirely. Safe phrases: "the daily
// work," "without an Rx," "the habit underneath."

public enum Glp1Cohort {
    /// `onboarding_glp1_status == "current"` — woman on a GLP-1 now.
    case onGlp1
    /// `onboarding_glp1_status == "past"` — woman off a GLP-1 (the
    /// 47-65% JAMA 2025 discontinuation cohort).
    case postGlp1
    /// `onboarding_glp1_status == "considering"` — woman who has
    /// weighed the shot but hasn't started (needle-averse,
    /// affordability, refuser).
    case considering
    /// `onboarding_glp1_status == "none"` / `"prefer_not_say"` /
    /// empty / any unrecognized value — general WL audience. The safe
    /// default.
    case generalWL

    /// Read the user's cohort from the onboarding AppStorage key.
    public static var current: Glp1Cohort {
        switch UserDefaults.standard.string(forKey: "onboarding_glp1_status") ?? "" {
        case "current":     return .onGlp1
        case "past":        return .postGlp1
        case "considering": return .considering
        default:            return .generalWL
        }
    }

    // MARK: - Trial-week push copy (v2 spec)
    //
    // Four pushes have cohort variants in v2:
    //   - Day 1 morning push (gated shownUp == 0)
    //   - Trial-end T-24h (with three shownUp-count branches)
    //   - Day 5 anti-refund (post-conversion)
    //
    // Per founder direction (2026-06-16): cohort lives in the noun
    // phrase (identity acknowledgment) but cohort-specific feature
    // promises are stripped from bodies — JeniFit does not ship a
    // protein floor, food noise tracker, post-shot rhythm module, or
    // keep-it-off curriculum yet, so bodies reference only what
    // exists today (lessons, breath cards, becoming, plate). v1.0.7
    // Day 0 anchor + Day 2 engagement helpers removed in v2 since
    // their scheduling functions were also dropped.

    /// Trial-end T-24h — the conversion-decision push. `shownUp` is
    /// the engagement-day count (RetentionNotifications.shownUpCount).
    /// Three branches:
    ///   - shownUp >= 2: celebration (universal copy, no cohort routing —
    ///     the count IS the personalization)
    ///   - shownUp == 1: middle, warm but not celebratory (universal)
    ///   - shownUp == 0: cold-zone — cohort-routed TITLE only (identity
    ///     acknowledgment); body universal, references only shipping
    ///     features (lessons, breath cards, becoming). Never promises
    ///     features that don't exist (no "protein floor," no "food noise
    ///     tracker," no "keep-it-off curriculum") — that's the founder's
    ///     reality-check rule per the 2026-06-16 notification spec.
    public func trialEndContent(shownUp: Int) -> (title: String, body: String) {
        if shownUp >= 2 {
            return (
                "look how far you've come.",
                "you've shown up \(shownUp) times ♥ your trial becomes a membership tomorrow. manage anytime in iOS settings."
            )
        }
        if shownUp == 1 {
            return (
                "your trial wraps tomorrow.",
                "you showed up once ♥ the door stays open. manage anytime in iOS settings."
            )
        }
        // shownUp == 0 — cold zone. Cohort signal in title only.
        let title: String
        switch self {
        case .generalWL, .postGlp1:
            // The rhythm framing fits both default WL and the keep-it-off
            // identity. No cohort-specific feature promise.
            title = "the rhythm is here when you are."
        case .onGlp1, .considering:
            // "The daily piece" is identity-framed (we see you, woman
            // working on something) without promising a cohort-specific
            // module that doesn't exist yet.
            title = "the daily piece is here."
        }
        return (
            title,
            "your trial converts tomorrow. lessons, breath cards, and your becoming. manage anytime in iOS settings."
        )
    }

    // MARK: - New trial-week + post-conversion push copy (v2 spec)

    /// Day 1 morning push (T+18-26h after install, bucket-anchored).
    /// Replaces the cut Day 0 anchor. Gated at scheduling time on
    /// shownUp == 0. Title cohort-routed (identity); body universal.
    public func day1MorningContent(opener: String) -> (title: String, body: String) {
        let title: String
        switch self {
        case .generalWL:   title = "your first morning here."
        case .onGlp1:      title = "day one, alongside the shot."
        case .postGlp1:    title = "the rhythm that keeps it."
        case .considering: title = "the daily piece, day one."
        }
        return (
            title,
            "\(opener)five minutes today. that's how the rhythm begins ♥"
        )
    }

    /// Day 1 morning push — ENGAGED variant. v1.1.2 (2026-06-24)
    /// retention fix: the engaged D0 user (the most savable) previously
    /// had her D1 push CANCELLED on the engagement signal, leaving ZERO
    /// D1 pull — the dominant driver of the D0→D1 cliff (~89% one-and-
    /// done). This fires instead, referencing that she already began; the
    /// lesson reader's "tomorrow, the next one" close sets up the open
    /// loop this push closes. Title cohort-routed (identity), body
    /// universal + anti-shame. "today's piece" = the daily lesson, which
    /// ships — no unshipped-feature promise.
    public func day1ContinueContent(opener: String) -> (title: String, body: String) {
        let title: String
        switch self {
        case .generalWL:   title = "you already started."
        case .onGlp1:      title = "day two, alongside the shot."
        case .postGlp1:    title = "the rhythm you started."
        case .considering: title = "the daily piece, day two."
        }
        return (
            title,
            "\(opener)yesterday you showed up. today's piece is two minutes ♥"
        )
    }

    /// Day 5 anti-refund push (T+5d after trial→paid conversion).
    /// Bucket-anchored. Gated at fire-resolution time on shownUp > 0
    /// (silence beats guilt when she hasn't engaged post-charge).
    /// Annual + quarterly only — weekly tier skips (no refund risk at
    /// $5.99). Body cohort-routed since each cohort frames the
    /// "five days in" moment differently.
    public func day5AntiRefundContent(shownUp: Int) -> (title: String, body: String) {
        let body: String
        switch self {
        case .generalWL:
            body = "you've shown up \(shownUp) times since you joined. small moves still count."
        case .onGlp1:
            body = "the daily piece is taking shape. \(shownUp) times shown up so far ♥"
        case .postGlp1:
            body = "the rhythm is forming. \(shownUp) times shown up so far ♥"
        case .considering:
            body = "you're \(shownUp) days into the daily piece ♥"
        }
        return ("five days in ♥", body)
    }
}

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
    /// v2 (2026-06-16) — Day 0 anchor + Day 2 engagement dropped per
    /// founder direction. Day 0 anchor (T+4h) fought onboarding euphoria
    /// and the iOS permission grant (half of installs never saw it
    /// because permission wasn't granted yet). Day 2 engagement sprayed
    /// everyone with "haven't tried yet?" copy that primed cancellation.
    /// Replaced by Day 1 morning push (T+18-26h, bucket-anchored, gated
    /// at scheduling time on shownUp == 0) — catches users who went a
    /// sleep cycle without opening, lower-noise, identity-routed.
    /// Fires ONCE per install (`day1MorningDone` flag) and is cancelled
    /// on any session save.
    static let day1MorningIdentifier = "day1_morning"
    /// v2 (2026-06-16) — Day 5 anti-refund push. Fires T+5d after
    /// trial→paid conversion, bucket-anchored, gated on shownUp > 0
    /// at scheduling time. The 90-day App Store refund window peaks
    /// Days 5-14 (post-charge regret + first credit card statement);
    /// this single value-recap reframes spend as earned, not regretted.
    /// Annual + quarterly only — weekly tier ($5.99) skips since refund
    /// risk is negligible at that price point. Scheduled from
    /// PaymentService.reconcileTrialReminder on trial→paid transition.
    static let day5AntiRefundIdentifier = "day5_anti_refund"
    /// v1.5 / delta v7 D64 — daily Evening Plate Review at 8:30pm local.
    /// Per Brief #5 behavioral-science research, the single highest-
    /// leverage retention move for a diet-first WL app: converts food
    /// logging (control behavior) into food reflection (self-regulation).
    /// Reflection-based interventions outperform tracking-only 2-3×
    /// (Burke et al. 2011). Cal AI / MFP / Noom / MacroFactor all have
    /// silent evenings; this is JeniFit's evening wedge.
    static let eveningPlateReviewIdentifier = "evening_plate_review"
    /// v1.0.7 W5-T5 — Day 3 first-log nudge for users who haven't logged
    /// a single meal in the food rail yet. Fires ONCE per install at
    /// 12:30pm local on Day 3 (firstSeen + 72h). Cancelled the moment
    /// FoodAnalytics records the firstLogSaved milestone — so users who
    /// log on Day 0/1/2 never see it.
    static let firstLogNudgeIdentifier = "food_first_log_nudge"

    // MARK: - Toggles (UserDefaults; default ON, gated on system permission)

    private enum Key {
        static let affirmationsEnabled = "notif.affirmations_enabled"
        static let winbackEnabled      = "notif.winback_enabled"
        static let eveningPlateReviewEnabled = "notif.evening_plate_review_enabled"
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
        /// One-shot flag for the trial-week Day 1 morning push so a
        /// re-launch within the same install doesn't re-schedule a
        /// duplicate. Legacy day0/day2 keys were dropped in v2 (2026-
        /// 06-16). cancelAll still clears any pending UserDefaults
        /// entries on those legacy keys via `legacyTrialWeekDoneKeys`.
        static let day1MorningDone     = "notif.day1_morning_done"
        /// v2 — one-shot flag for the Day 5 anti-refund push.
        static let day5AntiRefundDone  = "notif.day5_anti_refund_done"
        /// v2 — stored chargeDate for the Day 5 push so retry on
        /// each launch can re-evaluate the shownUp gate (handles
        /// users who convert without engaging then engage Day 1-4).
        static let day5ChargeDate      = "notif.day5_charge_date"
        static let firstLogNudgeDone   = "notif.first_log_nudge_done"
        /// v1.1.2 - cumulative count of D0-D3 activation-category pushes
        /// scheduled on this install. Checked by ActivationPushPolicy to
        /// enforce the hard cap of 3 (one per day slot: D1, D2, D3).
        /// Only the INACTIVE (cold) nudge variant increments this counter;
        /// the v1.1.2 engaged re-arm ("you already started") is a
        /// continuation nudge and does not count toward the activation cap.
        static let activationNudgesScheduled = "notif.activation_nudges_scheduled"
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
    static var eveningPlateReviewEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Key.eveningPlateReviewEnabled) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Key.eveningPlateReviewEnabled) }
    }

    // MARK: - Tunables

    /// Days of quiet before the win-back fires (re-armed each session).
    // v1.1.2 (2026-06-24) — tightened 3 → 2. For an ~89% one-and-done
    // cohort a 3-day lapse fires after she is already gone; landing the
    // single re-armed win-back on D2 catches her while still recoverable.
    // Still one push, still re-armed on every completed session.
    private static let winbackAfterDays = 2
    /// Weekdays (1=Sun…7=Sat) affirmations land on. Two per week keeps the
    /// total gentle even when the daily reminder is also on.
    private static let affirmationWeekdays: Set<Int> = [3, 7] // Tue, Sat
    /// How many future affirmation occurrences to keep scheduled. Re-filled
    /// each launch so the copy stays fresh and always a step ahead.
    private static let affirmationLookahead = 6
    /// Distinct-days-shown-up counts that earn a celebration. Each fires
    /// once (guarded by a done-flag). Celebration only — never loss-framed.
    private static let milestones = [3, 7, 14, 30, 50, 100]

    // v1.2 2026-06-15 — `affirmationHour` (13) and `milestoneHour` (9)
    // removed; both intents are now bucket-anchored via
    // NotificationTimeBucket so morning/evening/afternoon/whenever users
    // each see these pushes in their preferred window. See
    // PlankApp/Notifications/NotificationTimeBucket.swift.

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
            scheduleDay1MorningIfNeeded(now: now)
            retryDay5IfNeeded(now: now)
            // v1.0.7 Phase D — Day 3 first-log nudge CUT per the
            // retention expert brief
            // (docs/home_becoming_research_retention_2026_06_06.md §3):
            // "Cut Week-1 push surface from 5 to 3. 3-6 weekly pushes
            // drive 40% opt-out; iOS opt-in is already only 43.9%."
            // Day 3 first-log surface moves in-app. The scheduling
            // helper + cancelFirstLogNudge() stay defined so any
            // pending request from a prior install is cancelled
            // gracefully (see cancelFirstLogNudge() above which still
            // fires on first food log).
            // scheduleFirstLogNudgeIfNeeded(now: now)
            scheduleEveningPlateReview()
        }
    }

    /// Cancel the first-log nudge. Called by PlankAIApp's
    /// FoodHealthKitWriter / FoodAnalytics registration site — when the
    /// firstLogSaved AppStorage flag flips, this fires once to clear
    /// any pending Day 3 push.
    static func cancelFirstLogNudge() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [firstLogNudgeIdentifier]
        )
        UserDefaults.standard.set(true, forKey: Key.firstLogNudgeDone)
    }

    // MARK: - Day 3 first-log nudge (W5-T5)
    //
    // Fires at 12:30pm local on Day 3 (firstSeen + 72h, at the next
    // 12:30pm window) for users who haven't logged a single food entry
    // yet. Lunch is the highest-intention first-scan moment — breakfast
    // is rushed, dinner is socially loaded, lunch is plate-on-desk.
    //
    // Cancellation: the FoodAnalytics.firstLogSavedIfNeeded flag drives
    // skip + cancel. Users who scan on Day 0/1/2 never see this push.
    // PlankAIApp's analytics-sink registration calls cancelFirstLogNudge
    // when firstLogSaved fires so the cancel is real-time, not next-launch.
    //
    // Voice: lowercase, anti-shame, no "you haven't" framing. "even a
    // coffee counts" reframes the friction question (how hard is the
    // first scan?) into a permission question (anything counts as start).

    private static func scheduleFirstLogNudgeIfNeeded(now: Date) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Key.firstLogNudgeDone) else { return }
        // Skip if the user has already logged at least once. The flag
        // mirrors FoodAnalytics.firstLogSavedIfNeeded.
        if d.bool(forKey: "food_analytics.first_log_saved_fired") {
            d.set(true, forKey: Key.firstLogNudgeDone)
            return
        }
        guard let firstSeen = firstSeenAt() else { return }

        let cal = Calendar.current
        // Day 3 = firstSeen + 3 calendar days at 12:30pm local.
        guard let day3 = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: firstSeen)) else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: day3)
        comps.hour = 12
        comps.minute = 30
        guard let fireDate = cal.date(from: comps), fireDate > now.addingTimeInterval(60) else {
            // Window already past (e.g. user installs and opens for the
            // first time on Day 4+). Stamp done so we don't retry.
            d.set(true, forKey: Key.firstLogNudgeDone)
            return
        }

        let content = UNMutableNotificationContent()
        let name = (d.string(forKey: "userName") ?? "").lowercased()
        let opener = name.isEmpty ? "" : "\(name), "
        content.title = "your first plate ♥"
        content.body = "\(opener)even a coffee counts. it takes three seconds — promise."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: firstLogNudgeIdentifier,
            content: content,
            trigger: trigger
        ))
        d.set(true, forKey: Key.firstLogNudgeDone)
    }

    /// Daily 8:30pm local Evening Plate Review push (D64). Single
    /// repeating UNCalendarNotificationTrigger — fires every day at
    /// 8:30pm local time once authorized. Idempotent — repeated calls
    /// replace the existing scheduled request rather than stacking.
    /// Module-internal (was private) so FoodSettingsView can re-arm
    /// immediately after the user flips the toggle, rather than
    /// waiting for the next bootstrap.
    static func scheduleEveningPlateReview() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [eveningPlateReviewIdentifier])
        guard eveningPlateReviewEnabled else { return }
        // v2 (2026-06-16): skip during trial week 1 entirely. Trial
        // users haven't built the food-logging habit yet — an evening
        // "look back at today's plate" push on Day 0/1/2 reads as a
        // guilt trigger ("look back at what you didn't log") for the
        // anti-shame cohort. The push gets scheduled once on first
        // launch after the user crosses Day 7 (reschedule() runs on
        // every launch and re-evaluates this gate).
        guard !isWithinFirstWeek() else { return }

        let content = UNMutableNotificationContent()
        content.title = "today's plate ♥"
        content.body = "a soft look back. tap in when you're ready."
        content.sound = .default

        var components = DateComponents()
        // v1.2 bucket-anchor: evening reflection is semantically
        // evening, but a morning person's wind-down may be earlier
        // (7pm) where a night-owl is later (9pm). NotificationTimeBucket
        // .eveningReflection returns 19/20/21/20 across buckets so the
        // "today's plate" review lands post-her-dinner, not at a
        // blanket 8:30pm. Minute stays at :30 for the soft-pause feel.
        components.hour = NotificationTimeBucket.userPreferred
            .hour(for: .eveningReflection) ?? 20
        components.minute = 30
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        center.add(UNNotificationRequest(
            identifier: eveningPlateReviewIdentifier,
            content: content,
            trigger: trigger
        ))
    }

    /// Stamp last-session and re-arm the win-back from now. Call when a
    /// session is persisted (HomeView.saveRoutineSession / saveBenchmarkSession).
    /// Also cancels the trial-week pushes — once the user engages, those
    /// "are you still there?" nudges are no longer needed.
    static func markSessionCompleted(now: Date = .now) {
        UserDefaults.standard.set(now, forKey: Key.lastSessionAt)
        // v1.1.2 (2026-06-24) RETENTION FIX — was: CANCEL the Day 1
        // morning push the moment the user engaged, which starved the
        // most-savable user (engaged on D0) of any D1 pull and was the
        // dominant driver of the D0→D1 cliff (~89% one-and-done). Now we
        // REPLACE it with the warm "continue" variant: her D1 morning
        // still lands, referencing what she began. Clearing *Done lets
        // scheduleDay1Morning re-arm; if the D1 window already passed it
        // self-stamps done and clears the slot.
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "day0_anchor",       // legacy v1.0.7
            "day2_engagement",   // legacy v1.0.7
        ])

        Task {
            guard await isAuthorized() else { return }
            // v1.1.2 (2026-06-25) — re-arm the D1 push (and winback) only
            // when notifications are authorized, so an unauthorized session
            // doesn't flip day1MorningDone and silently suppress the
            // "continue" push if she grants permission later.
            UserDefaults.standard.set(false, forKey: Key.day1MorningDone)
            scheduleDay1Morning(now: now, engaged: true)
            armWinback(now: now)
        }
    }

    // MARK: - First-seen stamp + trial-week gating

    /// Stamp the first time the user's notification scheduler ran on this
    /// install. Anchors the trial-week math (Day 1 morning push,
    /// evening plate review trial-week pause, affirmation week-1
    /// pause). Idempotent — re-calls preserve the original timestamp.
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
        if !eveningPlateReviewEnabled {
            center.removePendingNotificationRequests(withIdentifiers: [eveningPlateReviewIdentifier])
        }
        reschedule()
    }

    /// Remove every retention notification + clear one-time state (account
    /// delete / full opt-out), so a fresh user on this device starts clean.
    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                winbackIdentifier,
                day1MorningIdentifier,
                day5AntiRefundIdentifier,
                "day0_anchor",       // legacy v1.0.7
                "day2_engagement",   // legacy v1.0.7
                eveningPlateReviewIdentifier,
                // v1.1.1 (2026-06-19) — the audit found that
                // firstLogNudgeIdentifier was missing from the
                // delete-account / opt-out sweep. The scheduling
                // function is currently commented out, but any
                // pending request from a prior version (or future
                // re-enable) would survive a delete-account and
                // fire from a now-unknown user. Cancel it too.
                firstLogNudgeIdentifier,
            ] + affirmationIdentifiers() + milestoneIdentifiers()
        )
        let d = UserDefaults.standard
        milestones.forEach { d.removeObject(forKey: Key.milestoneDone($0)) }
        d.removeObject(forKey: Key.shownUpCount)
        d.removeObject(forKey: Key.lastSessionAt)
        // v2 (2026-06-16) — clear the trial-week + post-conversion
        // stamps so a re-create on the same device (account delete →
        // onboarding again) gets a clean firstSeenAt + fresh Day 1
        // morning + fresh Day 5 anti-refund. Legacy day0/day2 done
        // keys also cleared for upgraded installs.
        d.removeObject(forKey: Key.firstSeenAt)
        d.removeObject(forKey: Key.day1MorningDone)
        d.removeObject(forKey: Key.day5AntiRefundDone)
        d.removeObject(forKey: Key.day5ChargeDate)
        d.removeObject(forKey: "notif.day0_anchor_done")
        d.removeObject(forKey: "notif.day2_engagement_done")
        // v1.1.1 — also wipe the first-log-nudge done flag so a
        // re-create cleanly re-arms when (if) scheduling re-enables.
        d.removeObject(forKey: Key.firstLogNudgeDone)
        // v1.1.2 - clear activation-nudge counter so a re-create
        // (delete-account + re-onboard) starts with a clean slate.
        d.removeObject(forKey: Key.activationNudgesScheduled)
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
        // v2 (2026-06-16): dropped "again" undertow from line 3 — implied
        // she lost herself, subtle contradiction with identity-led
        // framing. Added line 4 to widen the rotation pool.
        let lines = [
            "\(opener)one slip doesn't undo you. a short one's still here when you are ♥",
            "\(opener)no catching up needed. just come back when you can.",
            "\(opener)five minutes is enough to feel like you ♥",
            "\(opener)the door's still open. tap in when you're ready ♥",
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
            // v1.2 bucket-anchor: affirmation lands in the user's
            // chosen window (morning/afternoon/evening/whenever) so a
            // morning person doesn't get a Tue-1pm interrupt during
            // her productive block. Falls back to 13 (legacy 1pm) if
            // the bucket helper returns nil for some unforeseen
            // intent mapping.
            comps.hour = NotificationTimeBucket.userPreferred
                .hour(for: .affirmation) ?? 13
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
        // v2 (2026-06-16): added hearts to "calm" + "radiant" becoming
        // lines per the notification voice spec — both register as
        // warm-state identity, hearts amplify the soft signal.
        switch d.string(forKey: "identityFeeling") ?? "" {
        case "powerful": becoming = "you're becoming someone strong."
        case "calm":     becoming = "you're becoming someone steady ♥"
        case "light":    becoming = "you're becoming someone light on her feet."
        case "strong":   becoming = "you're becoming someone strong."
        case "radiant":  becoming = "you're becoming someone who glows ♥"
        default:         becoming = "you're becoming someone who shows up."
        }
        // v2 (2026-06-16): dropped "be the kind of friend to yourself
        // you'd be to someone you love" — 16 words, lock-screen
        // truncates. Replaced + added 2 lines to widen the pool.
        var lines = [
            becoming,
            "small moves still count. they always have ♥",
            "you don't have to feel ready. you just have to begin.",
            "the version of you that shows up is already winning.",
            "progress is quiet. you're making it anyway.",
            "be gentle with yourself today ♥",
            "the woman who came back is already the woman you wanted.",
            "five minutes still counts. it always did ♥",
        ]
        if !name.isEmpty {
            // v2: "gentle" → "soft" matches the cohort's anti-shame
            // post-Ozempic vocabulary register.
            lines.append("\(name), today's a good day to be soft on yourself.")
        }
        return lines
    }

    // MARK: - Day 1 morning push (trial-week)
    //
    // Lands at the user's bucket-anchored hour on Day 1 (the calendar
    // day after install, i.e. ~T+18-26h depending on bucket). Single
    // goal: catch users who went a sleep cycle without opening the app
    // post-install. Replaces the v1.0.7 Day 0 anchor (T+4h, fired into
    // onboarding euphoria + half of installs hadn't granted permission
    // yet) and the v1.0.7 Day 2 engagement push (sprayed everyone with
    // accusatory "haven't tried yet?" copy that primed cancellation).
    //
    // Per v2 notification spec (2026-06-16): one re-engagement push
    // during the 3-day trial is enough — beyond that, additional
    // pushes burn through the 5/wk ceiling without converting.
    //
    // Gating:
    //   - Skipped if user has shown up at least once (shownUpCount > 0)
    //   - Cancelled the moment the user saves a session (see
    //     markSessionCompleted)
    //   - Stamps `day1MorningDone` so a re-launch within the same
    //     install doesn't re-schedule a duplicate

    private static func scheduleDay1MorningIfNeeded(now: Date) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Key.day1MorningDone) else { return }
        // v1.1.2 (2026-06-24) — was: skip + stamp done when shownUp > 0,
        // so an engaged user got NO D1 push at all. Now we always arm the
        // D1 slot; `engaged` only picks the copy (warm "continue" vs the
        // "first morning" nudge). The engaged variant is what re-arms the
        // most-savable user against the D0→D1 cliff.
        let engaged = d.integer(forKey: Key.shownUpCount) > 0
        scheduleDay1Morning(now: now, engaged: engaged)
    }

    /// Arms the single Day 1 morning slot (firstSeen + 1 day, at the
    /// user's bucket-anchored morning hour). `engaged` selects the copy.
    /// Stamps `day1MorningDone` so the next reschedule() pass won't
    /// duplicate. Re-armed with the engaged variant from
    /// `markSessionCompleted` the moment the user acts.
    private static func scheduleDay1Morning(now: Date, engaged: Bool) {
        let d = UserDefaults.standard
        guard let firstSeen = firstSeenAt() else { return }

        let cal = Calendar.current
        // Day 1 = the calendar day AFTER install at the user's bucket-
        // anchored morning hour (18-26h post-install) — past onboarding
        // euphoria, before the trial-end decision window.
        guard let day1 = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: firstSeen)) else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: day1)
        comps.hour = NotificationTimeBucket.userPreferred
            .hour(for: .reminder) ?? 10
        comps.minute = 0
        let center = UNUserNotificationCenter.current()
        guard let fireDate = cal.date(from: comps), fireDate > now.addingTimeInterval(60) else {
            // D1 window already past (e.g. installs in the evening, or
            // engages a day later). No D1 push makes sense — clear any
            // stale pending request and stamp done.
            center.removePendingNotificationRequests(withIdentifiers: [day1MorningIdentifier])
            d.set(true, forKey: Key.day1MorningDone)
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: [day1MorningIdentifier])

        // Activation-state policy gate (ActivationPushPolicy).
        // Applied to the INACTIVE (cold) variant only - the engaged re-arm
        // path (v1.1.2 "you already started") is a continuation nudge and
        // is intentionally exempt from the activation cap so the most-
        // savable user (active on D0) still gets her D1 pull.
        if !engaged {
            let alreadyScheduled = d.integer(forKey: Key.activationNudgesScheduled)
            guard ActivationPushPolicy.shouldSchedule(
                dayIndex: 1,
                hasActedToday: d.integer(forKey: Key.shownUpCount) > 0,
                alreadyScheduled: alreadyScheduled
            ) else {
                // Cap reached or user already acted - stamp done so
                // reschedule() doesn't retry on the next launch.
                d.set(true, forKey: Key.day1MorningDone)
                return
            }
        }

        let content = UNMutableNotificationContent()
        let name = (d.string(forKey: "userName") ?? "").lowercased()
        let opener = name.isEmpty ? "" : "\(name), "
        let (title, body) = engaged
            ? Glp1Cohort.current.day1ContinueContent(opener: opener)
            : Glp1Cohort.current.day1MorningContent(opener: opener)
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        center.add(UNNotificationRequest(
            identifier: day1MorningIdentifier,
            content: content,
            trigger: trigger
        ))
        // Increment the activation-push counter for inactive (cold) nudges.
        // The engaged re-arm (v1.1.2 continuation) does not count toward
        // the ActivationPushPolicy cap.
        if !engaged {
            d.set(
                d.integer(forKey: Key.activationNudgesScheduled) + 1,
                forKey: Key.activationNudgesScheduled
            )
        }
        d.set(true, forKey: Key.day1MorningDone)
    }

    // MARK: - Day 5 anti-refund push (post-conversion)
    //
    // Lands at T+5d after trial→paid charge, bucket-anchored. The
    // 90-day App Store refund window peaks Days 5-14 post-charge
    // (post-charge regret + first credit card statement landing).
    // Single value-recap reframes spend as earned, not regretted.
    //
    // Gating model: scheduled from PaymentService.reconcileTrialReminder
    // on trial→paid transition (annual + quarterly only, weekly tier
    // skipped — no refund risk at $5.99). Schedule-time gate on
    // shownUp > 0: if the user converted without engaging, silence
    // beats guilt. Re-evaluated each launch via retryDay5IfNeeded so
    // a user who converts on Day 3 with shownUp == 0 but then engages
    // on Day 4 still gets the Day 5 push.

    /// Public entry point called by PaymentService when a trial→paid
    /// conversion is detected. Stores the chargeDate so retry on each
    /// launch can re-evaluate the shownUp gate, then attempts an
    /// immediate schedule.
    static func scheduleDay5AntiRefundIfNeeded(chargeDate: Date, now: Date = .now) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Key.day5AntiRefundDone) else { return }
        // Persist chargeDate so retryDay5IfNeeded can re-attempt on
        // each launch if the shownUp gate fails right now.
        d.set(chargeDate, forKey: Key.day5ChargeDate)
        tryScheduleDay5(chargeDate: chargeDate, now: now)
    }

    /// Re-entry point called from reschedule() on each launch. Picks
    /// up a stored chargeDate and re-tries scheduling — handles the
    /// case where the user converted without engaging then engaged
    /// on Day 1-4 of paid (push still has time to fire on Day 5).
    private static func retryDay5IfNeeded(now: Date) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Key.day5AntiRefundDone) else { return }
        guard let chargeDate = d.object(forKey: Key.day5ChargeDate) as? Date else { return }
        tryScheduleDay5(chargeDate: chargeDate, now: now)
    }

    /// Inner helper: computes Day 5 fire date, checks shownUp gate,
    /// and either schedules + stamps done, or leaves the chargeDate
    /// stored for a future retry. Stamps done when the fire window
    /// has already passed (no point retrying forever).
    private static func tryScheduleDay5(chargeDate: Date, now: Date) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Key.day5AntiRefundDone) else { return }

        let cal = Calendar.current
        guard let day5 = cal.date(byAdding: .day, value: 5, to: cal.startOfDay(for: chargeDate)) else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: day5)
        comps.hour = NotificationTimeBucket.userPreferred
            .hour(for: .reminder) ?? 10
        comps.minute = 0

        guard let fireDate = cal.date(from: comps), fireDate > now.addingTimeInterval(60) else {
            // Day 5 window already past — stamp done so we don't
            // retry on every launch forever.
            d.set(true, forKey: Key.day5AntiRefundDone)
            return
        }

        // Schedule-time shownUp gate. If the user hasn't engaged yet,
        // don't schedule — silence beats guilt. retryDay5IfNeeded
        // will re-attempt on next launch if she engages Day 1-4.
        let shownUp = d.integer(forKey: Key.shownUpCount)
        guard shownUp > 0 else { return }

        Task {
            guard await isAuthorized() else { return }

            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [day5AntiRefundIdentifier])

            let content = UNMutableNotificationContent()
            let (title, body) = Glp1Cohort.current.day5AntiRefundContent(shownUp: shownUp)
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            // Inside the Task, center.add resolves to the async-throwing
            // variant; mirror the scheduleMilestoneIfNeeded pattern with
            // try? await — failure to schedule isn't load-bearing
            // (best-effort retention push).
            try? await center.add(UNNotificationRequest(
                identifier: day5AntiRefundIdentifier,
                content: content,
                trigger: trigger
            ))
            d.set(true, forKey: Key.day5AntiRefundDone)
        }
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
            // v1.2 bucket-anchor: milestone celebration lands in the
            // user's preferred window next morning. Morning people
            // see it 8am, evening people see it 7pm (still next-
            // calendar-day, just shifted into their attention slot).
            // Fallback to 9 (legacy 9am) on the unforeseen-intent path.
            comps.hour = NotificationTimeBucket.userPreferred
                .hour(for: .milestone) ?? 9
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
        case 7:   return "you've shown up seven times\(tail). that's who you are now."
        case 14:  return "two weeks of showing up\(tail). look at you ♥"
        case 30:  return "thirty days\(tail). this isn't a phase anymore. it's you."
        case 50:  return "fifty times\(tail). quietly, you became someone consistent."
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
