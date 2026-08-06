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

    static let ladderIds: [String] = (1...7).map { "anchor_d\($0)" }
    static let legacyIds: [String] = ["daily_reminder", "daily-plank"]

    @MainActor
    static func refreshDailyAnchor(programDay: Int, totalDays: Int) {
        let d = UserDefaults.standard
        let todayKey = TodayStateService.dayKey()
        guard d.string(forKey: lastRefreshKey) != todayKey else { return }
        guard d.bool(forKey: "notificationsEnabled") else { return }
        guard !BreakState.isActive else { return }   // breaks silence the ladder
        guard programDay > 0, programDay < totalDays else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            Task { @MainActor in
                scheduleLadder(programDay: programDay, totalDays: totalDays)
                // v3 phase-7: today's lapse-support ping slates with
                // the ladder (once/day guard shared); a plate landing
                // cancels it (TodayModules snap completion).
                armLapseSupportIfEligible(programDay: programDay)
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
            content.body = anchorLine(
                archetype, who: who, offset: offset,
                targetProgramDay: targetProgramDay, totalDays: totalDays
            )
            content.sound = .default
            content.userInfo = ["deeplink": "jenifit://today"]

            center.add(UNNotificationRequest(
                identifier: "anchor_d\(offset)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            ))
        }

        scheduleReSigningKnock(programDay: programDay, hour: 19)
    }

    // MARK: - v4 — the re-signing knock (docs/app_v4/01_PROGRAM.md §0)
    //
    // One quiet evening knock on HER week's closing day: "the week's
    // receipt is ready." Follows the 4-site id protocol
    // (scheduler here · BreakState sweep · sign-time cancel · the
    // delegate's generic deeplink map). Cancelled the moment she
    // signs; never fires on a break (BreakState removes it).

    static let reSigningKnockId = "resigning_knock"

    private static func scheduleReSigningKnock(programDay: Int, hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reSigningKnockId])
        guard programDay >= 1 else { return }

        // Days until this program week's closing day (slot 6).
        let slot = PrescriptionEngineV2.dayInWeek(programDay)
        var daysAhead = 6 - slot
        // Today IS the closing day but the evening already passed —
        // knock at next week's close instead.
        if daysAhead == 0, Calendar.current.component(.hour, from: .now) >= hour {
            daysAhead = 7
        }
        guard let fireDay = Calendar.current.date(
            byAdding: .day, value: daysAhead, to: .now
        ) else { return }

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: fireDay)
        comps.hour = hour
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "your week, read back"
        content.body = "the week's receipt is ready. read it, sign the next step"
        content.sound = .default
        content.userInfo = ["deeplink": "jenifit://becoming"]

        center.add(UNNotificationRequest(
            identifier: reSigningKnockId,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        ))
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
            return ("a steadying week",
                    "the line drifted a little. protein first this week, nothing dramatic")
        case .reset:
            return ("jeni holds the plan",
                    "the line crossed your band. a reset is a few supported weeks, not a confession.")
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
        let uid = userId
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == uid },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        let logs = (try? context.fetch(descriptor)) ?? []
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
            title: "the line misses you",
            body: "one quiet morning, zero verdicts. the trend does the thinking",
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
        guard lapseSupportEligible(
            programDay: programDay,
            eveningReviewActive: RetentionNotifications.eveningPlateReviewEnabled,
            onBreak: BreakState.isActive
        ) else { return }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = 20
        comps.minute = 30
        scheduleOneShot(
            id: lapseSupportId,
            title: "the evening is the hard part",
            body: "sixty seconds of breath before the kitchen decides",
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
            UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            ))
        }
    }
}
