import Foundation
import PlankSync
import SwiftData

// MARK: - MedicationLog (app v24 THE REGIMEN)
//
// THE mark chokepoint (docs/app_v24/00_REGIMEN.md §3.3): every
// surface that resolves a dose — the checklist quick-mark, THE DOSE
// SHEET, the evening ask, a notification action — lands here, and
// four truths update together, converging on deterministic ids so
// surfaces can never disagree:
//   1. the DoseEventRecord (the rich, historically-correct row),
//   2. the .doseTaken observation (the care chart the packet reads),
//   3. the legacy day key (evening pre-fill),
//   4. today's program-day check (the row's done state) — only when
//      the slot IS today; a late log never marks a past program day.
// Marks also retire the day's reminders. Without an active regimen
// (the cohort-without-plan window before the shot-day ask) the v8
// behavior stands: observation + key + check, no event to anchor.

@MainActor
enum MedicationLog {

    enum Resolution {
        case taken(site: InjectionSite?, note: String?, at: Date)
        case skipped(reason: String?)
        case unmark
    }

    enum Source: String {
        case checklist, sheet, notification, evening
    }

    @discardableResult
    static func resolve(
        _ resolution: Resolution,
        slotDayKey: String = TodayStateService.dayKey(),
        source: Source,
        userId: String,
        in context: ModelContext
    ) -> DoseEventRecord? {
        guard !userId.isEmpty else { return nil }
        let plan = RegimenService.activeMedicationPlan(userId: userId, in: context)
        let isToday = slotDayKey == TodayStateService.dayKey()
        var event: DoseEventRecord?

        switch resolution {
        case .taken(let site, let note, let at):
            if let plan {
                let facts = RegimenService.facts(for: plan)
                event = DoseEventStore.upsert(
                    dayKey: slotDayKey,
                    scheduledAt: scheduledAt(forSlot: slotDayKey, facts: facts),
                    status: "taken",
                    takenAt: at,
                    site: site,
                    note: note,
                    source: source.rawValue,
                    userId: userId,
                    regimenPlanId: plan.id,
                    in: context
                )
            }
            ObservationStore.record(
                .doseTaken, valueText: "yes",
                payload: ObservationStore.regimenPayload(plan?.id),
                dayKey: slotDayKey,
                userId: userId, in: context
            )
            UserDefaults.standard.set("yes", forKey: "day.dose.\(slotDayKey)")
            if isToday {
                setTodayCheck(.complete, userId: userId, in: context)
                MedicationReminders.onDoseMarked()
            }

        case .skipped(let reason):
            if let plan {
                let facts = RegimenService.facts(for: plan)
                event = DoseEventStore.upsert(
                    dayKey: slotDayKey,
                    scheduledAt: scheduledAt(forSlot: slotDayKey, facts: facts),
                    status: "skipped",
                    skipReason: reason,
                    source: source.rawValue,
                    userId: userId,
                    regimenPlanId: plan.id,
                    in: context
                )
            }
            ObservationStore.record(
                .doseTaken, valueText: "skipped",
                payload: ObservationStore.regimenPayload(plan?.id),
                dayKey: slotDayKey,
                userId: userId, in: context
            )
            UserDefaults.standard.set("skipped", forKey: "day.dose.\(slotDayKey)")
            if isToday {
                setTodayCheck(.skipped, userId: userId, in: context)
                MedicationReminders.onDoseMarked()
            }

        case .unmark:
            DoseEventStore.delete(dayKey: slotDayKey, userId: userId, in: context)
            ObservationStore.deleteSingular(
                .doseTaken, dayKey: slotDayKey, userId: userId, in: context
            )
            UserDefaults.standard.removeObject(forKey: "day.dose.\(slotDayKey)")
            if isToday {
                setTodayCheck(.empty, userId: userId, in: context)
            }
        }

        // The reminder family re-derives (next dose moved).
        let uid = userId
        Task { await MedicationReminders.refresh(userId: uid, in: context) }
        return event
    }

    // MARK: Helpers

    private static func scheduledAt(
        forSlot dayKey: String,
        facts: MedicationScheduleEngine.RegimenFacts
    ) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        let day = f.date(from: dayKey) ?? .now
        return MedicationScheduleEngine.scheduledAt(onDay: day, facts: facts)
    }

    private static func setTodayCheck(
        _ state: ProgramService.ChecklistState,
        userId: String,
        in context: ModelContext
    ) {
        if let record = ProgramService.shared.markChecklistItem(
            prescription: .medication, state: state,
            userId: userId, in: context
        ) {
            Task { await AppSync.shared.upsertProgramDayCheck(record) }
        }
    }
}
