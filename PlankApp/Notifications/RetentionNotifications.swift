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
                "you've shown up \(shownUp) times your trial becomes a membership tomorrow. manage anytime in iOS settings."
            )
        }
        if shownUp == 1 {
            return (
                "your trial wraps tomorrow.",
                "you showed up once the door stays open. manage anytime in iOS settings."
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
            "\(opener)five minutes today. that's how the rhythm begins"
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
            "\(opener)yesterday you showed up. today's piece is two minutes"
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
            body = "the daily piece is taking shape. \(shownUp) times shown up so far"
        case .postGlp1:
            body = "the rhythm is forming. \(shownUp) times shown up so far"
        case .considering:
            body = "you're \(shownUp) days into the daily piece"
        }
        return ("five days in", body)
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
    /// The retired milestone thresholds — the done-flag ledger and the
    /// self-heal marker still speak this vocabulary (p54: the PUSH
    /// family is gone; the flags stay so a revival could never
    /// back-fire stale celebrations).
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
        // p54 — the retired families' pending requests are swept on
        // every launch, BEFORE any gate: an old install can still be
        // holding a scheduled affirmation drop, milestone, recap or
        // standalone daily reminder, and a family the product no
        // longer ships must not keep firing from a previous build.
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: NotificationCensus.retiredIds
        )
        // p54 — the app's own master switch, honored at last. This ran
        // on every launch checking only OS authorization, so turning
        // notifications OFF inside jeni re-armed five families on the
        // next launch — the census's worst finding. Same read the
        // orchestrator has always used.
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled")
        else { return }
        Task {
            guard await isAuthorized() else { return }
            armWinback(now: now)
            // p54 — scheduleAffirmations is GONE (the presumption of
            // deletion for clock-fired motivational filler: two sends
            // a week, zero record dependence, the exact voice the
            // product bans on its own surfaces).
            scheduleDay1MorningIfNeeded(now: now)
            retryDay5IfNeeded(now: now)
            // v1.0.7 Phase D — Day 3 first-log nudge CUT per the
            // retention expert brief; p54 deleted the scheduling
            // helper outright (the id stays in
            // NotificationCensus.retiredIds so stale requests sweep).
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

    /// The evening plate review. p54 — this was a REPEATING daily
    /// trigger, firing every evening forever with copy that could not
    /// know whether the day already held a record: the loudest
    /// clock-only send in the app, invisible to the arbiter, and the
    /// one family that even the master toggle failed to sweep. It is
    /// now a ONE-SHOT for tonight, re-armed at each launch, gated
    /// through the brain, and CANCELLED the moment a plate lands (the
    /// lapse-support pattern) — so it fires only on an evening whose
    /// day is still blank since the last open. Module-internal so
    /// FoodSettingsView can re-arm after the toggle flips.
    static func scheduleEveningPlateReview(now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [eveningPlateReviewIdentifier])
        guard eveningPlateReviewEnabled else { return }
        guard !BreakState.isActive else { return }   // breaks silence everything
        // v2 (2026-06-16): skip during trial week 1 entirely — an
        // evening "look back at today's plate" on Day 0/1/2 reads as
        // a guilt trigger for the anti-shame cohort.
        guard !isWithinFirstWeek(now: now) else { return }

        let content = UNMutableNotificationContent()
        content.title = "today's plate"
        content.body = "a soft look back. tap in when you're ready."
        content.sound = .default

        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: now)
        // v1.2 bucket-anchor: evening reflection lands post-her-dinner
        // (19/20/21/20 across buckets), minute :30 for the soft pause.
        components.hour = NotificationTimeBucket.userPreferred
            .hour(for: .eveningReflection) ?? 20
        components.minute = 30
        guard var fireDate = cal.date(from: components) else { return }
        if fireDate <= now.addingTimeInterval(60) {
            // Tonight's window already passed — arm tomorrow evening's.
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: fireDate)
            else { return }
            fireDate = tomorrow
        }
        NotificationGate.schedule(
            UNNotificationRequest(
                identifier: eveningPlateReviewIdentifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: cal.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: fireDate
                    ),
                    repeats: false
                )
            ),
            category: .support,
            center: center
        )
    }

    /// p54 — a plate landing clears tonight's review (the record is no
    /// longer blank, so the look-back push would be noise). Called
    /// beside the lapse-support cancel at the plate chokepoint.
    static func cancelEveningPlateReview() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [eveningPlateReviewIdentifier]
        )
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
                // Release audit 2026-08-08 — the promise carries her
                // name + her own words; it must never fire under the
                // next identity on this device. The dead Sunday recap
                // id sweeps too (same reasoning as firstLogNudge).
                NotificationPermission.day1PromiseIdentifier,
            ] + NotificationCensus.retiredIds       // p54 — one census
              + NotificationOrchestrator.jitaiIds   // v3 phase-7 pings
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
        // On a break, quiet days are the plan — "still here for you"
        // after 2 days would read as the app not listening.
        guard !BreakState.isActive else { return }

        let content = UNMutableNotificationContent()
        content.title = "still here for you."
        content.body = winbackBody()
        content.sound = .default

        let interval = TimeInterval(winbackAfterDays * 24 * 60 * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        // v25 E1 — re-engagement obeys THE BRAIN (p54: via the gate).
        NotificationGate.schedule(
            UNNotificationRequest(
                identifier: winbackIdentifier, content: content, trigger: trigger
            ),
            category: .reengagement,
            center: center
        )
    }

    private static func winbackBody() -> String {
        let name = (UserDefaults.standard.string(forKey: "userName") ?? "").lowercased()
        let opener = name.isEmpty ? "" : "\(name), "
        // v2 (2026-06-16): dropped "again" undertow from line 3 — implied
        // she lost herself, subtle contradiction with identity-led
        // framing. Added line 4 to widen the rotation pool.
        let lines = [
            "\(opener)one slip doesn't undo you. a short one's still here when you are",
            "\(opener)no catching up needed. just come back when you can.",
            "\(opener)five minutes is enough to feel like you",
            "\(opener)the door's still open. tap in when you're ready",
        ]
        return lines.randomElement() ?? lines[0]
    }

    // MARK: - Affirmation drops (DELETED, p54)
    //
    // Two clock-fired pushes a week ("you're becoming someone who
    // glows", "the version of you that shows up is already winning"),
    // zero record dependence, and the exact motivational-poster voice
    // §10 of the pass-54 brief bans from the product's own surfaces.
    // The presumption of deletion for generic engagement applied:
    // every send must answer WHY NOW?, and the only honest answer here
    // was "because it is tuesday." Their pending requests sweep via
    // NotificationCensus.retiredIds at every launch and in the master
    // toggle, so an old install's queued drops die too.

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
        // v7 D4 (2026-08-03) — the signature row "check on me in the
        // first days" finally gates what it names. An explicit false
        // (she left the row unsigned) suppresses the D1 morning push in
        // both variants; a missing key (legacy installs, pre-v7) keeps
        // the shipped default. The daily reminder and trial-end pushes
        // are separate consents and unaffected.
        if let consent = d.object(forKey: "onb_consent_day2") as? Bool, consent == false {
            d.set(true, forKey: Key.day1MorningDone)
            return
        }
        // Fix 2 (2026-06-28): suppress the Day-1 morning push when the user
        // has set a day1_promise via the commitment ritual. The promise IS the
        // Day-1 nudge - scheduling both would double-ping the same D1 slot.
        // Stamp done so reschedule() and markSessionCompleted don't retry.
        guard (d.string(forKey: "day1PromiseTimeISO") ?? "").isEmpty else {
            d.set(true, forKey: Key.day1MorningDone)
            return
        }
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
                hasEverActed: d.integer(forKey: Key.shownUpCount) > 0,
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
        // p54 — through the gate (this send never consulted the brain).
        NotificationGate.schedule(
            UNNotificationRequest(
                identifier: day1MorningIdentifier,
                content: content,
                trigger: trigger
            ),
            category: .reengagement,
            center: center
        )
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
            // p54 — through the gate (this send never consulted the
            // brain; the gate's add is synchronous inside its own
            // non-async body, so the async-overload footgun the old
            // comment described is gone with it).
            NotificationGate.schedule(
                UNNotificationRequest(
                    identifier: day5AntiRefundIdentifier,
                    content: content,
                    trigger: trigger
                ),
                category: .reengagement,
                center: center
            )
            d.set(true, forKey: Key.day5AntiRefundDone)
        }
    }

    // MARK: - Milestones (the PUSH family DELETED, p54)
    //
    // "three days in. you're building something" · "that's who you are
    // now." — identity praise fired at a day count, which is a streak
    // in celebration's clothing (§8: no streak that makes restarting
    // feel like failure; §10: no congratulating trivial actions). The
    // in-app record keeps every count; the push family goes. Two
    // details preserved: the shown-up count still stamps (the trial
    // recap and the day-5 gate read it), and the done-flags still
    // mark on self-heal so a future revival could never back-fire
    // stale celebrations. Pending requests sweep via
    // NotificationCensus.retiredIds.

    /// Record a newly-reached engagement day (a distinct day shown up).
    /// v3: called once per day from PresenceLedger.recordMeaningfulAction.
    static func recordShownUpDay(count: Int) {
        UserDefaults.standard.set(count, forKey: Key.shownUpCount)
    }

    /// v3 presence self-heal support (kept for the done-flag ledger).
    static func markMilestonesDone(upTo count: Int) {
        let d = UserDefaults.standard
        for m in milestones where m <= count {
            d.set(true, forKey: Key.milestoneDone(m))
        }
    }

    // MARK: - Permission

    private static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
