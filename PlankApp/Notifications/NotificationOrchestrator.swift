import Foundation
import SwiftData
import UserNotifications
import PlankSync

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

    /// Pass 52 — the day-one contract can GRANT authorization between
    /// two refreshes whose state key is identical (no new plate, same
    /// day), and the guard would then skip the rebuild until tomorrow:
    /// a granted permission with nothing scheduled behind it. The
    /// grant path clears the guard so the next refresh arms the ladder.
    @MainActor
    static func invalidateRefreshGuard() {
        UserDefaults.standard.removeObject(forKey: lastRefreshKey)
    }

    static let ladderIds: [String] = (1...7).map { "anchor_d\($0)" }
    static let legacyIds: [String] = ["daily_reminder", "daily-plank"]

    @MainActor
    static func refreshDailyAnchor(
        programDay: Int, totalDays: Int, weeklyDoseAnchor: Int? = nil,
        todayPlateCount: Int = 0, todayProteinG: Int? = nil
    ) {
        let d = UserDefaults.standard
        let todayKey = TodayStateService.dayKey()
        // v25 E4 — the once/day guard became a state guard: the
        // morning rung carries today's record ("2 plates on file.
        // your read is ready"), so a plate landing in the evening
        // must be able to refresh tomorrow's payload. Same-id
        // re-admits are free by the brain's law, so a rebuild costs
        // no budget.
        let stateKey = "\(todayKey)·\(todayPlateCount)·\(todayProteinG ?? -1)"
        guard d.string(forKey: lastRefreshKey) != stateKey else { return }
        guard d.bool(forKey: "notificationsEnabled") else { return }
        guard !BreakState.isActive else { return }   // breaks silence the ladder
        guard programDay > 0, programDay < totalDays else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            Task { @MainActor in
                scheduleLadder(
                    programDay: programDay, totalDays: totalDays,
                    weeklyDoseAnchor: weeklyDoseAnchor,
                    todayPlateCount: todayPlateCount,
                    todayProteinG: todayProteinG
                )
                // v3 phase-7: today's lapse-support ping slates with
                // the ladder (state guard shared); a plate landing
                // cancels it (TodayModules snap completion).
                armLapseSupportIfEligible(programDay: programDay)
                d.set(stateKey, forKey: lastRefreshKey)
            }
        }
    }

    @MainActor
    private static func scheduleLadder(
        programDay: Int, totalDays: Int, weeklyDoseAnchor: Int? = nil,
        todayPlateCount: Int = 0, todayProteinG: Int? = nil
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ladderIds + legacyIds)

        // Release audit 2026-08-08 — the Settings page's saved reminder
        // time was silently discarded for enrolled users (this ladder
        // deletes daily_reminder on every rebuild and fired at the
        // bucket hour regardless of what she saved). Her explicit
        // choice wins; the bucket stays the default. Name lowercased
        // per the voice law, matching every RetentionNotifications site.
        let savedHour = UserDefaults.standard.object(forKey: "notificationHour") as? Int
        let savedMinute = UserDefaults.standard.object(forKey: "notificationMinute") as? Int
        let hour = savedHour ?? NotificationTimeBucket.userPreferred.hour(for: .reminder) ?? 9
        let minute = savedHour != nil ? (savedMinute ?? 0) : 0
        let name = (UserDefaults.standard.string(forKey: "userName") ?? "").lowercased()
        let who = name.isEmpty ? "" : "\(name), "
        let cal = Calendar.current

        // v25 E4 — the ladder shrank from 7 rungs to 3. Five stamped
        // ids saturated the brain's 5/week budget permanently: the
        // winback push and the 3-day milestone were vetoed FOREVER
        // for exactly the one-active-day cohort they exist for. Three
        // mornings of anchors, then the winback grammar owns the gap.
        for offset in 1...3 {
            let targetProgramDay = programDay + offset
            guard targetProgramDay <= totalDays else { break }
            guard let fireDay = cal.date(byAdding: .day, value: offset, to: .now) else { continue }

            var comps = cal.dateComponents([.year, .month, .day], from: fireDay)
            comps.hour = hour
            comps.minute = minute

            let archetype = ProgramDayArchetype.archetype(
                forProgramDay: targetProgramDay,
                glp1Status: CohortStore.glp1StatusKey,
                restrictiveFoodRelationship: CohortStore.isRestrictiveRisk
            )

            let content = UNMutableNotificationContent()
            // v25 E4 — the morning rung is the read's knock: when
            // today left a record, tomorrow's push carries it (by
            // delivery time "today" reads as yesterday). Timely value
            // from her own data, not a nudge; same id, same budget.
            if offset == 1, todayPlateCount >= 1 {
                let plateWord = todayPlateCount == 1
                    ? "one plate" : "\(todayPlateCount) plates"
                let proteinPart = (todayProteinG ?? 0) > 0
                    ? " and \(todayProteinG ?? 0)g protein" : ""
                content.title = "your morning read is ready"
                content.body = "\(who)yesterday: \(plateWord)\(proteinPart), logged. jeni read it back this morning"
            } else {
                content.title = "day \(targetProgramDay) is ready"
                content.body = anchorLine(
                    archetype, who: who, offset: offset,
                    targetProgramDay: targetProgramDay, totalDays: totalDays
                )
            }
            content.sound = .default
            content.userInfo = ["deeplink": "jenifit://today"]

            // p54 — the anchor is the MORNING READ's delivery (the
            // day-one contract's own consented offer): the cadence
            // class, exempt and unstamped. As `.support` it re-stamped
            // three ledger slots daily and saturated the budget.
            NotificationGate.schedule(
                UNNotificationRequest(
                    identifier: "anchor_d\(offset)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                ),
                category: .morningRead,
                center: center
            )
        }

        scheduleReSigningKnock(
            programDay: programDay, hour: 19, weeklyDoseAnchor: weeklyDoseAnchor
        )
    }

    // MARK: - v4 — the re-signing knock (docs/app_v4/01_PROGRAM.md §0)
    //
    // One quiet evening knock on HER week's closing day: "the week's
    // receipt is ready." Follows the 4-site id protocol
    // (scheduler here · BreakState sweep · sign-time cancel · the
    // delegate's generic deeplink map). Cancelled the moment she
    // signs; never fires on a break (BreakState removes it).

    static let reSigningKnockId = "resigning_knock"

    private static func scheduleReSigningKnock(
        programDay: Int, hour: Int, weeklyDoseAnchor: Int? = nil
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reSigningKnockId])
        guard programDay >= 1 else { return }

        // p54 — the read is consented cadence now (exempt, unstamped);
        // its old privileged-but-stamped lane consumed a budget slot
        // every single day of every enrolled week.

        var comps: DateComponents
        if let anchor = weeklyDoseAnchor, (1...7).contains(anchor) {
            // The physiological monday: the morning AFTER dose day
            // (the anchor ladder's dose-day rung). Weekly repeats so
            // a quiet week still gets its one knock.
            comps = DateComponents()
            // ISO 1=mon..7=sun → Calendar 1=sun..7=sat; morning after.
            let dueIso = anchor % 7 + 1
            comps.weekday = dueIso == 7 ? 1 : dueIso + 1
            comps.hour = 9
            comps.minute = 30
        } else {
            // The enrollment rung: her week's closing evening (v4 law).
            let slot = PrescriptionEngineV2.dayInWeek(programDay)
            var daysAhead = 6 - slot
            if daysAhead == 0, Calendar.current.component(.hour, from: .now) >= hour {
                daysAhead = 7
            }
            guard let fireDay = Calendar.current.date(
                byAdding: .day, value: daysAhead, to: .now
            ) else { return }
            comps = Calendar.current.dateComponents([.year, .month, .day], from: fireDay)
            comps.hour = hour
            comps.minute = 0
        }

        let content = UNMutableNotificationContent()
        content.title = "your week is ready to read"
        content.body = "one small decision. it takes a minute"
        content.sound = .default
        content.userInfo = ["deeplink": "jenifit://becoming"]

        NotificationGate.schedule(
            UNNotificationRequest(
                identifier: reSigningKnockId,
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: comps, repeats: weeklyDoseAnchor != nil
                )
            ),
            category: .weeklyRead,
            center: center
        )
    }

    /// Sign-time cancel — the knock never nags a signed week.
    static func cancelReSigningKnock() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reSigningKnockId])
    }

    /// The day's line — archetype voice, with the later rungs easing
    /// into begin-again register (day 3+ of silence is a comeback
    /// moment, not a reminder moment). v4: a rung that lands on a
    /// program-week's first day announces the NAMED week instead —
    /// intents are deterministic, so the ladder can speak them safely
    /// where full readings (live-state) never could.
    private static func anchorLine(
        _ archetype: ProgramDayArchetype, who: String, offset: Int,
        targetProgramDay: Int, totalDays: Int
    ) -> String {
        if offset >= 3 {
            return "\(who)the plan kept your place. begin again, anytime"
        }
        if PrescriptionEngineV2.dayInWeek(targetProgramDay) == 0, targetProgramDay > 1 {
            let week = PrescriptionEngineV2.programWeek(targetProgramDay)
            let chapter = CohortStore.chapter
            let intent = WeekIntent.intent(
                week: week,
                chapter: chapter,
                phase: ProgramArc.phase(
                    week: week,
                    totalWeeks: ProgramArc.totalWeeks(totalDays: totalDays),
                    chapter: chapter
                ),
                flags: .live,
                pickedKey: UserDefaults.standard.string(
                    forKey: WeeklyReview.intentPickKey(week: week))
            )
            return "\(who)week \(week) begins: \(intent.name). a clean page"
        }
        switch archetype {
        case .protein:  return "\(who)today is a protein day. one strong plate at a time"
        case .movement: return "\(who)today is a movement day. small counts fully."
        case .balanced: return "\(who)today asks for steady, not perfect."
        case .rest:     return "\(who)today is a rest day. nothing heavy"
        }
    }

    // MARK: - v3 phase-7 JITAI pings (docs/app_v3/03_BUILD_PLAN §7)
    //
    // Three contextual pings, each opening an ACTION (the null-trial
    // law), each silenced by "on a break", each following the 4-site
    // id protocol (schedulers here · RetentionNotifications.cancelAll
    // · AppSync/BreakState sweeps · NotificationDelegate.destination).

    static let keepingZoneId = "keeping_zone"
    static let lineQuietId = "keeping_line_quiet"
    static let lapseSupportId = "lapse_support"
    static var jitaiIds: [String] { [keepingZoneId, lineQuietId, lapseSupportId] }

    /// Pure gate for the weeks-0–6 lapse-support ping: the program's
    /// early window only, never alongside the evening plate review
    /// (≤1 uninvited evening push, ever), never on a break.
    static func lapseSupportEligible(
        programDay: Int, eveningReviewActive: Bool, onBreak: Bool
    ) -> Bool {
        programDay >= 1 && programDay <= 42 && !eveningReviewActive && !onBreak
    }

    /// Zone-crossing copy — care register, action-first, no alarm.
    static func zonePushCopy(_ zone: BandZone) -> (title: String, body: String)? {
        switch zone {
        case .drifting:
            return ("this week: protein first",
                    "your trend drifted up a little. protein first steadies it")
        case .reset:
            return ("jeni has a plan for this week",
                    "your trend crossed your band. a few steady weeks bring it back")
        case .steady:
            return nil   // recovery celebrates in-app; no push needed
        }
    }

    /// Called from the weigh chokepoint (WeightLogWriter). Keeping
    /// chapter only: consumes a band crossing into a next-morning
    /// push, and re-arms the +8-day weigh-pattern watcher.
    @MainActor
    static func onWeighSaved(userId: String, in context: ModelContext) {
        guard CohortStore.chapter == .keeping,
              UserDefaults.standard.bool(forKey: "notificationsEnabled"),
              !BreakState.isActive,
              !userId.isEmpty
        else { return }

        armLineQuiet()

        guard let plan = ProgramService.shared.activePlan(userId: userId, in: context),
              let settle = BandModel.settleWeightKg(plan: plan)
        else { return }
        // Pass 51 — the zone trigger reads the canonical resolved
        // series (sign-up self-report excluded, one per-day rule); its
        // FOLD stays the fast EMA on purpose — the band widths were
        // calibrated to its reactivity, and re-tuning triggers is
        // pass-53 work.
        let logs = Array(WeightSeries.records(userId: userId, in: context).reversed())
        guard let emaLatest = WeightTrendChart.computeEMA(logs: logs).last?.emaKg
        else { return }
        let zone = BandModel.zone(emaKg: emaLatest, settleKg: settle)
        guard let crossed = BandModel.consumeCrossing(newZone: zone),
              let copy = zonePushCopy(crossed)
        else { return }

        scheduleOneShot(
            id: keepingZoneId,
            title: copy.title,
            body: copy.body,
            deeplink: "jenifit://today",
            at: nextMorningComponents()
        )
    }

    /// The weigh-pattern watcher: re-armed on every save; fires only
    /// if 8 days pass without another (each save cancels + reslates).
    /// The broken PATTERN is the earliest drift signal.
    @MainActor
    private static func armLineQuiet() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [lineQuietId])
        let cal = Calendar.current
        guard let fireDay = cal.date(byAdding: .day, value: 8, to: .now) else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: fireDay)
        comps.hour = NotificationTimeBucket.userPreferred.hour(for: .reminder) ?? 9
        comps.minute = 0
        scheduleOneShot(
            id: lineQuietId,
            title: "a 30-second weigh-in?",
            body: "one quiet morning keeps your trend honest. no verdicts",
            deeplink: "jenifit://today",
            at: comps
        )
    }

    /// The weeks-0–6 lapse-support ping: slated each morning for
    /// 20:30 tonight, CANCELLED the moment a plate lands
    /// (TodayModules snap completion). The body claims no state —
    /// it offers the brake, not a verdict.
    @MainActor
    static func armLapseSupportIfEligible(programDay: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [lapseSupportId])
        // v25 E4 (N3 fix): "active" means the evening review will
        // actually FIRE — it skips the whole first week, yet the old
        // check read only the toggle (default ON), so the lapse ping
        // could never arm for anyone, ever. Week 1 belongs to lapse
        // support; from week 2 the evening review owns the evening
        // (≤1 uninvited evening push, unchanged).
        guard lapseSupportEligible(
            programDay: programDay,
            eveningReviewActive: RetentionNotifications.eveningPlateReviewEnabled
                && programDay > 7,
            onBreak: BreakState.isActive
        ) else { return }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = 20
        comps.minute = 30
        scheduleOneShot(
            id: lapseSupportId,
            title: "evenings are the hard part",
            body: "60 seconds of breathing before you open the kitchen",
            deeplink: "jenifit://breath",
            at: comps
        )
    }

    @MainActor
    static func cancelLapseSupport() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [lapseSupportId])
    }

    // MARK: - Shared one-shot plumbing

    private static func nextMorningComponents() -> DateComponents {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1,
                                to: cal.startOfDay(for: .now)) ?? .now
        var comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = NotificationTimeBucket.userPreferred.hour(for: .reminder) ?? 9
        comps.minute = 0
        return comps
    }

    private static func scheduleOneShot(
        id: String, title: String, body: String,
        deeplink: String, at comps: DateComponents
    ) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = ["deeplink": deeplink]
            // p54 — the JITAI trio (zone crossing, quiet line, lapse
            // support) had NO brain gate at all: three interruption
            // sends, structurally invisible to the ≤5/week law they
            // were the reason for.
            NotificationGate.schedule(
                UNNotificationRequest(
                    identifier: id,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                ),
                category: .support
            )
        }
    }
}
