import Foundation
import SwiftData
import PlankSync

// MARK: - WeightSeries — THE canonical resolved weigh-in series (pass 51)
//
// ONE WEIGHT STORY. Before this file, seven trend consumers each ran
// their own `FetchDescriptor<WeightLogRecord>` and their own per-day
// pick: Becoming's delta line read ALL rows (her sign-up self-report
// included) reduced latest-of-day through the fast EMA, while the
// weekly read three screens later read rows-minus-onboarding reduced
// earliest-of-day through the τ-fold — the same record telling two
// stories inside one tab. VisitPacket ran a fourth universe of its
// own. This enum is the one place that decides WHICH ROWS ARE THE
// WEIGH-IN SERIES; every trend reader consumes it.
//
// The two resolution laws, and why:
//
//   1. THE SIGN-UP SELF-REPORT IS NOT A WEIGH-IN. `source ==
//      "onboarding"` rows are the number she TYPED at the consult —
//      a plan fact, not a measurement. They stay in the record (the
//      ledger lists them, provenance visible; the arithmetic ladder
//      may still fall back to the same number through its own rung)
//      but they never seed a trend: mixing a self-report into a
//      scale series distorts the very first segment of every line.
//
//   2. A DAY'S SAMPLE IS THE EARLIEST OF THE DAY. The fluctuation
//      literature the week read encodes assumes the fasted-morning
//      weight; `WeightWeekReadEngine` has said so since E2. Every
//      reducer now agrees, so one physical weigh-in can never count
//      differently on two surfaces.
//
// WHAT THIS DELIBERATELY IS NOT: a second smoother. The trend FOLD
// has one authority for everything a customer reads as a trend —
// `WeightWeekReadEngine` (its `read` for words, its `trendSeries`
// for drawn lines). The fast 7-day EMA (`WeightTrendChart`) remains
// only as the internal TRIGGER fold (band crossings, plateau
// counters, the rapid-loss tripwire) because its consumers' safety
// thresholds were calibrated against its reactivity — re-tuning
// triggers is engine work with its own evidence bar, named for pass
// 53, and it now runs over THIS series, so it can no longer disagree
// about what the record contains.

@MainActor
enum WeightSeries {

    /// The one exclusion rule, stated once.
    static let onboardingSource = "onboarding"

    /// Every weigh-in row for the user, oldest-first, sign-up
    /// self-report excluded. This is the trend universe; the LEDGER
    /// deliberately does not use it (a row you cannot see is a row
    /// you cannot remove — it lists everything, onboarding included,
    /// with its provenance word).
    static func records(
        userId: String, in context: ModelContext
    ) -> [WeightLogRecord] {
        guard !userId.isEmpty else { return [] }
        let uid = userId
        let excluded = onboardingSource
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate {
                $0.userId == uid && $0.source != excluded
            },
            sortBy: [SortDescriptor(\.loggedAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The resolved samples: one per civil day, EARLIEST of the day.
    /// Pure over the rows so the reduction itself is testable.
    static func samples(
        from records: [WeightLogRecord], calendar: Calendar = .current
    ) -> [WeightWeekReadEngine.Sample] {
        var earliestByDay: [Date: WeightLogRecord] = [:]
        for row in records {
            let day = calendar.startOfDay(for: row.loggedAt)
            if let held = earliestByDay[day], held.loggedAt <= row.loggedAt {
                continue
            }
            earliestByDay[day] = row
        }
        return earliestByDay.values
            .sorted { $0.loggedAt < $1.loggedAt }
            .map { .init(day: $0.loggedAt, kg: $0.weightKg) }
    }

    /// Fetch + reduce in one call — the everyday entry point.
    static func samples(
        userId: String, in context: ModelContext,
        calendar: Calendar = .current
    ) -> [WeightWeekReadEngine.Sample] {
        samples(from: records(userId: userId, in: context), calendar: calendar)
    }

    /// THE trend read — the one authority behind every direction word
    /// and every drawn trend line.
    static func read(
        userId: String, in context: ModelContext,
        now: Date = .now, calendar: Calendar = .current
    ) -> WeightWeekRead {
        WeightWeekReadEngine.read(
            samples: samples(userId: userId, in: context, calendar: calendar),
            now: now, calendar: calendar
        )
    }
}
