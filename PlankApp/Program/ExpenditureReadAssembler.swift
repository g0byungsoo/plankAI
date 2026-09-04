import Foundation
import SwiftData
import PlankFood
import PlankSync

// MARK: - ExpenditureReadAssembler (p79 — THE LEARNED BURN's live half)
//
// Gathers the record's own rows and hands them to the pure engine.
// Three consumers, one assembler — the Becoming burn card, the weekly
// read's energy proposal, and the plan sheet's provenance line — so
// the learned number can never fork the way the weight fold once did
// (five hand-ported EMAs, pass 51).

@MainActor
enum ExpenditureReadAssembler {

    /// History handed to the engine: the 21-day window plus enough
    /// context to anchor the fragment median and seed the fold.
    static let historyDays = 42

    static func current(
        userId: String,
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ExpenditureRead.Read {
        let cal = calendar
        let today = cal.startOfDay(for: now)
        guard let historyStart = cal.date(
            byAdding: .day, value: -(historyDays - 1), to: today
        ) else { return .silent(.trendNotEstablished) }

        // Intake — logged plates reduced to day rows. kcal is the
        // recorded energy (the ONE rule, p61 recordedKcal); a day
        // with no plates is simply absent, and the engine treats
        // absence as absence.
        var byDay: [Date: (kcal: Double, plates: Int)] = [:]
        for entry in FoodLogPersister.allEntries(userId: userId)
        where entry.loggedAt >= historyStart {
            let day = cal.startOfDay(for: entry.loggedAt)
            var t = byDay[day] ?? (0, 0)
            t.kcal += entry.kcal
            t.plates += 1
            byDay[day] = t
        }
        let days = byDay.map { key, value in
            ExpenditureRead.DayIntake(day: key, kcal: value.kcal, plates: value.plates)
        }

        // The canonical weight fold — same samples, same engine, same
        // sufficiency word every spoken sentence uses (p51/p74 law).
        let samples = WeightSeries.samples(userId: userId, in: context, calendar: cal)
        let weekRead = WeightWeekReadEngine.read(samples: samples, now: now, calendar: cal)
        let trend = WeightWeekReadEngine.trendSeries(
            samples: samples, now: now, windowDays: historyDays, calendar: cal
        )
        let windowStart = cal.date(
            byAdding: .day, value: -(ExpenditureRead.windowDays - 1), to: today
        ) ?? today
        let weighDaysInWindow = Set(
            samples.lazy.filter { $0.day >= windowStart }
                .map { cal.startOfDay(for: $0.day) }
        ).count

        // A regimen era younger than the titration floor holds the
        // read — the window straddles two appetites. First eras
        // included: before the medication there was a third.
        var daysSinceDoseChange: Int?
        if let medPlan = RegimenService.activeMedicationPlan(userId: userId, in: context) {
            daysSinceDoseChange = cal.dateComponents(
                [.day], from: medPlan.startedAt, to: now
            ).day
        }

        // The BMR rail's input (nil when the profile can't say —
        // the engine then falls back to its absolute floor).
        let profile = TargetsService.profileInputs()
        let plan = ProgramService.shared.activePlan(userId: userId, in: context)
        let weightKg = TargetsService.resolvedWeightKg(
            userId: userId, plan: plan, in: context
        )
        let bmr: Int? = {
            guard let kg = weightKg, kg > 30, profile.heightCm > 100 else { return nil }
            return Int(CalorieTargetCalculator.bmrRaw(
                weightKg: kg, heightCm: profile.heightCm,
                age: profile.age, sex: profile.sex
            ).rounded())
        }()

        return ExpenditureRead.read(.init(
            days: days,
            trend: trend,
            sufficiency: weekRead.sufficiency,
            weighInDaysInWindow: weighDaysInWindow,
            daysSinceDoseChange: daysSinceDoseChange,
            bmrKcal: bmr,
            numericsSuppressed: CohortStore.isNumericSuppressed,
            now: now,
            calendar: cal
        ))
    }
}
