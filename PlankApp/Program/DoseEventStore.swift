import Foundation
import SwiftData
import PlankSync

// MARK: - DoseEventStore (app v24 THE REGIMEN)
//
// docs/app_v24/00_REGIMEN.md §3.3 — the historically-correct dose
// record. One row per slot day, upserted by DETERMINISTIC id so the
// checklist quick-mark, THE DOSE SHEET, the evening ask and a
// notification action converge instead of duplicating (the
// ObservationStore discipline). Rows are never mutated into lies:
// a late log flips a derived `missed` back to `taken` with the real
// `takenAt`; deleting a same-day mark is a correction, not history
// editing. `site`/`note` are hers — surfaces she reads only.

@MainActor
enum DoseEventStore {

    static func deterministicId(userId: String, dayKey: String) -> String {
        "\(userId.lowercased())-dose-\(dayKey)"
    }

    // MARK: Write

    /// Upsert the slot's row. Passing nil for `site`/`note` on an
    /// existing row PRESERVES what she already recorded (marking
    /// from the checklist never erases the sheet's detail).
    @discardableResult
    static func upsert(
        dayKey: String,
        scheduledAt: Date,
        status: String,
        takenAt: Date? = nil,
        site: InjectionSite? = nil,
        note: String? = nil,
        skipReason: String? = nil,
        source: String,
        userId: String,
        regimenPlanId: String,
        in context: ModelContext,
        sync: Bool = true
    ) -> DoseEventRecord? {
        guard !userId.isEmpty else { return nil }
        let id = deterministicId(userId: userId, dayKey: dayKey)
        let record: DoseEventRecord
        if let existing = fetch(id: id, in: context) {
            existing.status = status
            switch status {
            case "taken":
                existing.takenAt = takenAt ?? existing.takenAt ?? .now
                if let site { existing.site = site.rawValue }
                existing.skipReason = nil
            case "skipped":
                existing.takenAt = nil
                existing.site = nil
                existing.skipReason = skipReason ?? existing.skipReason
            default:   // "missed" | "pending"
                existing.takenAt = nil
                existing.site = nil
                existing.skipReason = nil
            }
            if let note { existing.note = note }
            existing.source = source
            existing.regimenPlanId = regimenPlanId
            existing.updatedAt = .now
            existing.pendingUpsert = true
            record = existing
        } else {
            record = DoseEventRecord(
                id: id,
                userId: userId,
                regimenPlanId: regimenPlanId,
                dayKey: dayKey,
                scheduledAt: scheduledAt,
                status: status,
                takenAt: takenAt,
                site: site?.rawValue,
                note: note,
                skipReason: status == "skipped" ? skipReason : nil,
                source: source
            )
            context.insert(record)
        }
        try? context.save()
        if sync {
            let toSync = record
            Task { await AppSync.shared.upsertDoseEvent(toSync) }
        }
        return record
    }

    /// Remove the slot's row entirely (a same-day unmark — she says
    /// "didn't, actually"). A correction, not history editing.
    static func delete(dayKey: String, userId: String, in context: ModelContext) {
        let id = deterministicId(userId: userId, dayKey: dayKey)
        guard let record = fetch(id: id, in: context) else { return }
        context.delete(record)
        try? context.save()
        Task { await AppSync.shared.deleteDoseEvent(id: id) }
    }

    // MARK: Read

    static func fetch(id: String, in context: ModelContext) -> DoseEventRecord? {
        let d = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(d))?.first
    }

    static func event(
        dayKey: String, userId: String, in context: ModelContext
    ) -> DoseEventRecord? {
        fetch(id: deterministicId(userId: userId, dayKey: dayKey), in: context)
    }

    /// Newest-first events, capped.
    static func events(
        userId: String, limit: Int = 60, in context: ModelContext
    ) -> [DoseEventRecord] {
        guard !userId.isEmpty else { return [] }
        var d = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.dayKey, order: .reverse)]
        )
        d.fetchLimit = limit
        return (try? context.fetch(d)) ?? []
    }

    /// The engine's lightweight join input. `takenDayKey` carries
    /// the ACTUAL take day when it differs from the slot day (v25
    /// E2: a late take anchors the cycle to the real injection).
    static func slotEvents(
        userId: String, limit: Int = 60, in context: ModelContext
    ) -> [MedicationScheduleEngine.SlotEvent] {
        events(userId: userId, limit: limit, in: context).map {
            .init(
                dayKey: $0.dayKey,
                status: $0.status,
                takenDayKey: $0.takenAt.map {
                    MedicationScheduleEngine.dayKey(for: $0)
                }
            )
        }
    }

    /// Her most recent sites, newest first — the rotation advisor's
    /// input (taken doses only; a skipped day has no site).
    static func recentSites(
        userId: String, limit: Int = 6, in context: ModelContext
    ) -> [InjectionSite] {
        events(userId: userId, limit: 40, in: context)
            .filter { $0.status == "taken" }
            .compactMap { $0.site.flatMap(InjectionSite.init(rawValue:)) }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Missed derivation (lazy, reversible)

    /// Stamp `missed` rows for slots whose late window closed with
    /// nothing recorded. Called from composition points (Today
    /// snapshot / regimen home), never from a timer. A later "log
    /// it late" upsert flips the row to taken — reversible by
    /// construction.
    static func stampMissedIfNeeded(
        userId: String,
        facts: MedicationScheduleEngine.RegimenFacts,
        regimenPlanId: String,
        now: Date = .now,
        in context: ModelContext
    ) {
        guard !userId.isEmpty else { return }
        let events = slotEvents(userId: userId, in: context)
        let missed = MedicationScheduleEngine.missedSlotDays(
            now: now, facts: facts, events: events
        )
        guard !missed.isEmpty else { return }
        for slot in missed {
            let key = MedicationScheduleEngine.dayKey(for: slot)
            _ = upsert(
                dayKey: key,
                scheduledAt: MedicationScheduleEngine.scheduledAt(
                    onDay: slot, facts: facts
                ),
                status: "missed",
                source: "derived",
                userId: userId,
                regimenPlanId: regimenPlanId,
                in: context,
                sync: true
            )
        }
    }

    // MARK: Sweeps

    /// Delete-account purge (rides the ObservationStore sweep).
    static func deleteAll(userId: String, in context: ModelContext) {
        guard !userId.isEmpty else { return }
        let d = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for record in (try? context.fetch(d)) ?? [] {
            context.delete(record)
        }
        try? context.save()
    }
}
