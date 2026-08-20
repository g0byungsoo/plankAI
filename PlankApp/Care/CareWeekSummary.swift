import Foundation
import SwiftData
import PlankSync
import PlankFood

// MARK: - CareWeekSummary (app v9 P6)
//
// One week of her chart, reduced to the deterministic facts a
// clinician reads between visits — the S3 packet's honesty rules at
// weekly grain. No AI, no network, offline-valid; unrecorded is
// counted as unrecorded, never as skipped (the S3 law). The pure
// `compose(facts:)` half is the tested surface; `gather` is the one
// store-touching collector.

enum CareWeekSummary {

    struct Facts: Equatable {
        /// ISO-monday of the week being summarized ("2026-07-28").
        var weekKey: String
        var doseScheduled: Int = 0
        var doseTaken: Int = 0
        var doseSkipped: Int = 0
        var weighCount: Int = 0
        var loggedDays: Int = 0
        var proteinDaysMet: Int = 0
        var proteinTargetG: Int? = nil
        var movedDays: Int = 0
        var stepsWeekAvg: Int? = nil
    }

    struct Summary: Equatable {
        let weekKey: String
        let payload: [String: Any]

        static func == (l: Summary, r: Summary) -> Bool {
            l.weekKey == r.weekKey
                && NSDictionary(dictionary: l.payload)
                    .isEqual(to: r.payload)
        }
    }

    /// Pure: facts → the wire payload. Absent streams are absent
    /// keys (the dashboard renders what exists — provenance law).
    static func compose(_ facts: Facts) -> Summary {
        var payload: [String: Any] = ["weekKey": facts.weekKey]
        if facts.doseScheduled > 0 {
            let taken = min(facts.doseTaken, facts.doseScheduled)
            let skipped = min(facts.doseSkipped, facts.doseScheduled - taken)
            payload["regimen"] = [
                "scheduled": facts.doseScheduled,
                "taken": taken,
                "skipped": skipped,
                "unrecorded": max(0, facts.doseScheduled - taken - skipped),
            ]
        }
        payload["weight"] = ["entryCount": facts.weighCount]
        if facts.loggedDays > 0, let target = facts.proteinTargetG {
            payload["nutrition"] = [
                "loggedDays": facts.loggedDays,
                "proteinDaysMet": facts.proteinDaysMet,
                "targetG": target,
            ]
        }
        if facts.movedDays > 0 || facts.stepsWeekAvg != nil {
            var movement: [String: Any] = ["movedDays": facts.movedDays]
            if let avg = facts.stepsWeekAvg { movement["stepsWeekAvg"] = avg }
            payload["movement"] = movement
        }
        return Summary(weekKey: facts.weekKey, payload: payload)
    }

    /// The ISO-monday key for a date (the week the summary names).
    static func weekKey(for date: Date = .now, calendar: Calendar = .current) -> String {
        // Pass 51: the key is a server row id component — pinned
        // Gregorian so a Buddhist/Islamic preferred calendar cannot
        // mint an era year into the primary key (which would create a
        // second row for the same week after a region change). Only
        // the caller's time zone is honored.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = calendar.timeZone
        cal.firstWeekday = 2   // monday-anchored regardless of locale
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: start)
    }

    // MARK: - The collector (trailing 7 days, store-backed)

    @MainActor
    static func gather(userId: String, in context: ModelContext) -> Facts {
        var facts = Facts(weekKey: weekKey())
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let weekStart = cal.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart

        // Medication rhythm (on-med cohort).
        if let plan = RegimenService.activeMedicationPlan(userId: userId, in: context) {
            // p54 — the denominator comes from the schedule engine,
            // never a constant. `doseScheduled = 1` told the clinic a
            // DAILY patient had one scheduled dose a week while the
            // visit packet derived seven — two adherence denominators
            // for one patient, on the clinician's own artifacts. Same
            // slot derivation the packet uses (every rhythm: weekly,
            // split, interval, daily).
            let facts0 = RegimenService.facts(for: plan)
            let events = DoseEventStore.slotEvents(
                userId: userId, limit: 30, in: context
            )
            facts.doseScheduled = VisitPacketBuilder.scheduledSlotKeys(
                window: .init(
                    start: weekStart, end: todayStart, label: "", dayKeys: []
                ),
                plan: plan, facts: facts0, events: events
            ).count
            facts.doseTaken = ObservationStore.countMatching(
                .doseTaken, values: ["yes"], lastDays: 7,
                userId: userId, in: context
            )
            // A skipped dose is a recorded answer, not a silence —
            // same correction as VisitPacketBuilder.skippedAnswers.
            facts.doseSkipped = ObservationStore.countMatching(
                .doseTaken, values: VisitPacketBuilder.skippedAnswers, lastDays: 7,
                userId: userId, in: context
            )
        }

        // Weigh-ins (trailing 7; onboarding seeds excluded).
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId && $0.loggedAt >= weekStart }
        )
        // p55 — DAYS, not rows (VisitPacket's own rule): a morning
        // weigh-in plus a same-day correction is one weigh-in, and a
        // clinician's "weigh-ins this week" must never read 9 of 7.
        facts.weighCount = Set(
            ((try? context.fetch(descriptor)) ?? [])
                .filter { $0.source != "onboarding" }
                .map { Calendar.current.startOfDay(for: $0.loggedAt) }
        ).count

        // Protein presence (the TodayStateService trailing-7 math).
        let targets = TargetsService.current(userId: userId, in: context)
        if let target = targets.proteinG {
            facts.proteinTargetG = target
            var proteinByDay: [String: Double] = [:]
            for entry in FoodLogPersister.allEntries(userId: userId)
            where entry.loggedAt >= weekStart {
                proteinByDay[
                    TodayStateService.dayKey(for: entry.loggedAt), default: 0
                ] += entry.protein
            }
            facts.loggedDays = proteinByDay.count
            facts.proteinDaysMet = proteinByDay.values
                .filter { $0 >= Double(target) }.count
        }

        // Movement (steps only — the granted stream).
        let weekly = StepsService.shared.weeklyCounts
        let active = weekly.filter { $0 > 0 }
        facts.movedDays = active.count
        facts.stepsWeekAvg = active.isEmpty ? nil : active.reduce(0, +) / active.count

        return facts
    }
}
