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
            payload["regimen"] = [
                "scheduled": facts.doseScheduled,
                "taken": min(facts.doseTaken, facts.doseScheduled),
                "unrecorded": max(0, facts.doseScheduled - facts.doseTaken),
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
        var cal = calendar
        cal.firstWeekday = 2   // monday-anchored regardless of locale
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let f = DateFormatter()
        f.calendar = cal
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

        // Medication rhythm (on-med cohort; weekly anchor = 1).
        if RegimenService.activeMedicationPlan(userId: userId, in: context) != nil {
            facts.doseScheduled = 1
            facts.doseTaken = ObservationStore.countMatching(
                .doseTaken, values: ["yes"], lastDays: 7,
                userId: userId, in: context
            )
        }

        // Weigh-ins (trailing 7; onboarding seeds excluded).
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId && $0.loggedAt >= weekStart }
        )
        facts.weighCount = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.source != "onboarding" }.count

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
