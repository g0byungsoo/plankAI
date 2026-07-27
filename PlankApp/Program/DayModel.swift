import Foundation
import SwiftData
import UserNotifications
import PlankFood
import PlankSync

// MARK: - DayModel (app v3 spine)
//
// docs/app_v3/00_THESIS.md §4. The three primitives every v3 surface
// shares: the CHAPTER she's in (losing / on-medication / keeping),
// the STANDING of a day (kept / partial / quiet), and PRESENCE (kept
// days — a lifetime count that never resets). Plus the BREAK state
// (a first-class pause: sick / period / travel / a hard week).
//
// All cores are pure and table-tested (AppV3SpineTests); the live
// accessors are thin wrappers over CohortStore / UserDefaults.

// MARK: - Chapter

/// The program chapter. Cohort routing stops being copy-deep here:
/// chapters carry structural differences (weigh cadence, scoring,
/// day shape) downstream, not just noun phrases.
enum Chapter: String, Equatable {
    case losing
    case onMedication = "on_medication"
    case keeping

    /// Pure derivation — the one place the chapter is decided.
    /// On-medication wins over maintenance (the medication chapter is
    /// the lived reality; the engine still honors maintenance slots
    /// through its own flags).
    static func derive(glp1StatusKey: String, isMaintenanceMode: Bool) -> Chapter {
        if ProgramGoalCalculator.isGLP1User(from: glp1StatusKey) { return .onMedication }
        if isMaintenanceMode { return .keeping }
        return .losing
    }

    /// The masthead / her-file word. Lowercase by voice contract.
    var fileWord: String {
        switch self {
        case .losing: return "losing, gently"
        case .onMedication: return "on medication support"
        case .keeping: return "keeping it"
        }
    }
}

extension CohortStore {
    /// Live chapter for the current identity.
    static var chapter: Chapter {
        Chapter.derive(
            glp1StatusKey: glp1StatusKey,
            isMaintenanceMode: isMaintenanceMode
        )
    }
}

// MARK: - DayStanding

/// How a day resolved. ONE vocabulary for the strip dots, the
/// past-day review, the evening receipt, the weekly story, and
/// Becoming's wins. Anti-shame floor: quiet is a fact, never a
/// verdict; paused days (break ranges) are excluded upstream.
enum DayStanding: Equatable {
    case kept
    case partial
    case quiet

    /// A day is KEPT at 3+ landed beats (of a typical 4-5 beat day)
    /// or when its one thing landed alongside anything else. PARTIAL
    /// = anything at all happened (presence). QUIET = no record.
    static let keptThreshold = 3

    static func from(completedCount: Int?, oneThingDone: Bool = false) -> DayStanding {
        let count = completedCount ?? 0
        if count >= keptThreshold { return .kept }
        if oneThingDone && count >= 2 { return .kept }
        if count >= 1 { return .partial }
        return .quiet
    }
}

// MARK: - PresenceLedger (kept days)

/// The lifetime presence count — "days with me." Replaces the v2
/// definition of `stats.shown_up_count`, which secretly counted only
/// WORKOUT days (RetentionNotifications.recordShownUpDay was called
/// solely from saveRoutineSession's new-DayProgressRecord branch), so
/// a woman who snapped, read, breathed, and weighed daily but never
/// completed a workout read "shown up 0 times" on Becoming, the wall,
/// and in the brief.
///
/// v3 definition: any meaningful action marks the day (snap / lesson
/// or rep / workout / breath / weigh-in / steps-crossed) — the same
/// actions ProgramService.markChecklistItem records — via the
/// once-per-day marker below. The count NEVER resets (kept days, not
/// a streak). Milestone celebration stays in RetentionNotifications
/// (the count crossing 3/7/14/30/50/100 fires at most one push).
enum PresenceLedger {

    static let countKey = "stats.shown_up_count"
    static let dayMarkerKey = "presence.lastDayKey"
    static let migratedKey = "presence.migrated.v3"

    static var keptDays: Int {
        UserDefaults.standard.integer(forKey: countKey)
    }

    /// Marks today as a kept-presence day (idempotent per day).
    /// Call from every meaningful-action write path; the marker makes
    /// double-calls free.
    static func recordMeaningfulAction(
        _ d: UserDefaults = .standard, now: Date = .now
    ) {
        let today = TodayStateService.dayKey(for: now)
        guard d.string(forKey: dayMarkerKey) != today else { return }
        d.set(today, forKey: dayMarkerKey)
        let next = d.integer(forKey: countKey) + 1
        d.set(next, forKey: countKey)
        // Milestone celebration rides the live defaults only (tests
        // inject a suite; recordShownUpDay re-stamps the same count).
        if d === UserDefaults.standard {
            RetentionNotifications.recordShownUpDay(count: next)
        }
    }

    /// One-time self-heal for existing users: derive presence days
    /// from the records that already exist (workout sessions, manual
    /// weigh-ins, plan checks, plates) and adopt the larger count.
    /// Milestones at-or-below the healed count are marked done so the
    /// heal never fires a surprise celebration push.
    @MainActor
    static func migrateIfNeeded(userId: String, in context: ModelContext) {
        let d = UserDefaults.standard
        guard !userId.isEmpty, !d.bool(forKey: migratedKey) else { return }
        d.set(true, forKey: migratedKey)

        var days = Set<String>()

        let sessions = FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for s in (try? context.fetch(sessions)) ?? [] {
            days.insert(TodayStateService.dayKey(for: s.completedAt))
        }

        let weights = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for w in (try? context.fetch(weights)) ?? [] where w.source != "onboarding" {
            days.insert(TodayStateService.dayKey(for: w.loggedAt))
        }

        if let plan = ProgramService.shared.activePlan(userId: userId, in: context) {
            let planId = plan.id
            let checks = FetchDescriptor<ProgramDayCheckRecord>(
                predicate: #Predicate {
                    $0.userId == userId && $0.programPlanId == planId
                }
            )
            let cal = Calendar.current
            for c in (try? context.fetch(checks)) ?? []
            where c.state == "complete" || c.state == "autoCompleted" {
                if let date = cal.date(
                    byAdding: .day, value: c.programDay - 1,
                    to: cal.startOfDay(for: plan.startDate)
                ) {
                    days.insert(TodayStateService.dayKey(for: date))
                }
            }
        }

        for plate in FoodLogPersister.allEntries(userId: userId) {
            days.insert(TodayStateService.dayKey(for: plate.loggedAt))
        }

        let healed = days.count
        guard healed > d.integer(forKey: countKey) else { return }
        d.set(healed, forKey: countKey)
        RetentionNotifications.markMilestonesDone(upTo: healed)
    }
}

// MARK: - BreakState

/// "On a break" — the first-class pause (docs/app_v3/00_THESIS.md).
/// While active: the rhythm renders as permission, no hollow-dot
/// debt accrues, and every uninvited notification sleeps. Return is
/// a warm welcome + automatic repair, never a catch-up.
///
/// Storage (identity-scoped; swept on sign-out by AppSync):
///   break.activeSince  ISO day key when the current break began
///   break.ranges       JSON [[startDayKey, endDayKey]] of past breaks
enum BreakState {

    static let activeSinceKey = "break.activeSince"
    static let rangesKey = "break.ranges"

    static var isActive: Bool { isActiveIn() }

    static func isActiveIn(_ d: UserDefaults = .standard) -> Bool {
        !(d.string(forKey: activeSinceKey) ?? "").isEmpty
    }

    static func begin(_ d: UserDefaults = .standard, now: Date = .now) {
        guard (d.string(forKey: activeSinceKey) ?? "").isEmpty else { return }
        d.set(TodayStateService.dayKey(for: now), forKey: activeSinceKey)
        // Scheduled anchor rungs would nag through the break — remove
        // them now; the ladder re-arms on the first refresh after she
        // returns (orchestrator guard).
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: NotificationOrchestrator.ladderIds
                + NotificationOrchestrator.legacyIds
                + NotificationOrchestrator.jitaiIds
                + [NotificationOrchestrator.reSigningKnockId]
                + ["winback_lapse", "evening_plate_review", "becoming.sunday.recap"]
        )
    }

    static func end(_ d: UserDefaults = .standard, now: Date = .now) {
        guard let start = d.string(forKey: activeSinceKey), !start.isEmpty else { return }
        var ranges = storedRanges(d)
        ranges.append([start, TodayStateService.dayKey(for: now)])
        if let data = try? JSONEncoder().encode(ranges) {
            d.set(String(data: data, encoding: .utf8), forKey: rangesKey)
        }
        d.removeObject(forKey: activeSinceKey)
    }

    /// Whether a calendar day (dayKey "yyyy-MM-dd") fell inside a
    /// break — past ranges or the currently active one. DayKeys sort
    /// lexicographically, so string comparison is date comparison.
    static func covers(dayKey: String, _ d: UserDefaults = .standard, now: Date = .now) -> Bool {
        if let start = d.string(forKey: activeSinceKey), !start.isEmpty,
           dayKey >= start, dayKey <= TodayStateService.dayKey(for: now) {
            return true
        }
        return storedRanges(d).contains { range in
            range.count == 2 && dayKey >= range[0] && dayKey <= range[1]
        }
    }

    static func storedRanges(_ d: UserDefaults = .standard) -> [[String]] {
        guard
            let raw = d.string(forKey: rangesKey),
            let data = raw.data(using: .utf8),
            let ranges = try? JSONDecoder().decode([[String]].self, from: data)
        else { return [] }
        return ranges
    }
}

// MARK: - One thing + rhythm (the v3 day split)

extension PrescriptionEngineV2.Day {
    /// The single ask of the day — the hero beat, skipping rows that
    /// complete themselves (steps can never be an ask). Rest days
    /// surface breath (60 seconds IS the ask). nil = a pure-ambient
    /// day (render as permission).
    ///
    /// v6.3 (docs/app_v6/03_CONVERSION.md): days 1-2 lead with the
    /// snap when the day carries one — the first plate is the 3.1x
    /// D1 behavior (61% vs 19.5% baseline) and only 17% of users
    /// ever reached it while lessons (baseline retention) held the
    /// hero slot.
    var oneThing: ProgramDayPrescription? {
        if programDay >= 1, programDay <= 2,
           let snap = beats.first(where: {
               if case .snapMeal = $0 { return true }
               return false
           }) {
            return snap
        }
        return beats.first(where: { !$0.isProgressRow })
    }

    /// Everything that isn't the one thing — rendered as quiet
    /// hairline rows, present but never debt.
    var rhythm: [ProgramDayPrescription] {
        guard let one = oneThing else { return beats }
        return beats.filter { $0.itemKey != one.itemKey }
    }

    /// v6.4 (founder call): workouts and breath are OPTIONAL — most
    /// users never touch them and they were reading as debt. A beat
    /// promoted to the one-thing stays required (rest days make
    /// breath the day's single ask).
    /// v7 (docs/app_v7 §§4-5): lessons leave the required set (the
    /// method is trigger-matched and pull-only now) and steps is an
    /// observation, not an ask — the day's asks are the care plan's
    /// lead + supporting, and past-day standings read the same
    /// generous definition.
    func isOptional(_ beat: ProgramDayPrescription) -> Bool {
        if beat.itemKey == oneThing?.itemKey { return false }
        switch beat {
        case .workout, .breath, .lesson, .steps: return true
        default: return false
        }
    }

    /// The beats the day actually asks for — drives the receipt
    /// arithmetic and the standing math so optional rows are never
    /// counted as debt.
    var requiredBeats: [ProgramDayPrescription] {
        beats.filter { !isOptional($0) }
    }
}
