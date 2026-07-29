import Foundation
import SwiftData
import PlankSync

// MARK: - ObservationStore
//
// App v8 (docs/app_v8/03_ARCHITECTURE.md §3b) — the chart's API.
// One typed, userId-scoped store absorbing the day-keyed
// UserDefaults string families (day.reflection / day.sit / day.dose
// / day.note / plan.tonight). Records survive sign-out under her
// userId the way weight logs already do; the legacy string keys
// keep their sign-out sweep (they are not userId-scoped).
//
// Laws:
//   - Day-singular kinds upsert by deterministic id (a changed
//     evening answer replaces that day's record; history across
//     days is never rewritten). careEvent appends.
//   - Every record carries `source` provenance.
//   - Nothing here ever renders; readers speak through the engines.
//   - Dose/regimen rows NEVER enter notification payloads or
//     analytics (01_RESEARCH §A4).

enum ObservationKind: String, CaseIterable {
    /// proud / okay / tender — the evening feeling chip.
    case feeling
    /// fine / heavy / queasy — the on-medication sit-check
    /// (the GI side-effect stream in plain words).
    case sitCheck
    /// yes / skipped — the dose-day mark.
    case doseTaken
    /// Her one journal line.
    case journalNote
    /// The if-then tonight plan.
    case tonightPlan
    /// The titration-window hydration mark (v8).
    case hydration
    /// A care rule fired (severity + provenance in payload).
    case careEvent
    /// The sealed day's asked-set (payload; the receipts record).
    case daySealed

    /// One record per day (deterministic id) vs append-per-event.
    var isDaySingular: Bool { self != .careEvent }

    /// The UserDefaults prefix this kind absorbs (backfill).
    var legacyPrefix: String? {
        switch self {
        case .feeling: return "day.reflection."
        case .sitCheck: return "day.sit."
        case .doseTaken: return "day.dose."
        case .journalNote: return "day.note."
        case .tonightPlan: return "plan.tonight."
        case .hydration, .careEvent, .daySealed: return nil
        }
    }
}

@MainActor
enum ObservationStore {

    // MARK: - Ids + day keys

    static func deterministicId(
        userId: String, kind: ObservationKind, dayKey: String
    ) -> String {
        "\(userId.lowercased())-\(kind.rawValue)-\(dayKey)"
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Write

    /// Record an observation. Day-singular kinds upsert in place;
    /// careEvent appends. Fires the cloud upsert fire-and-forget
    /// (graceful when the table isn't deployed yet).
    @discardableResult
    static func record(
        _ kind: ObservationKind,
        valueText: String? = nil,
        valueNum: Double? = nil,
        unit: String? = nil,
        payload: Data? = nil,
        dayKey: String,
        userId: String,
        source: String = "manual",
        in context: ModelContext,
        sync: Bool = true
    ) -> ObservationRecord {
        guard !userId.isEmpty else {
            return ObservationRecord(userId: "", kind: kind.rawValue, dayKey: dayKey)
        }
        let record: ObservationRecord
        if kind.isDaySingular {
            let id = deterministicId(userId: userId, kind: kind, dayKey: dayKey)
            if let existing = fetch(id: id, in: context) {
                existing.valueText = valueText
                existing.valueNum = valueNum
                existing.unit = unit
                if let payload { existing.payload = payload }
                existing.source = source
                existing.updatedAt = .now
                existing.pendingUpsert = true
                record = existing
            } else {
                record = ObservationRecord(
                    id: id, userId: userId, kind: kind.rawValue, dayKey: dayKey,
                    valueText: valueText, valueNum: valueNum, unit: unit,
                    payload: payload, source: source
                )
                context.insert(record)
            }
        } else {
            record = ObservationRecord(
                userId: userId, kind: kind.rawValue, dayKey: dayKey,
                valueText: valueText, valueNum: valueNum, unit: unit,
                payload: payload, source: source
            )
            context.insert(record)
        }
        try? context.save()
        if sync {
            let toSync = record
            Task { await AppSync.shared.upsertObservation(toSync) }
        }
        return record
    }

    // MARK: - Read

    static func fetch(id: String, in context: ModelContext) -> ObservationRecord? {
        var d = FetchDescriptor<ObservationRecord>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    /// The day's answer for a singular kind ("queasy", "proud"…).
    static func valueText(
        _ kind: ObservationKind, dayKey: String, userId: String, in context: ModelContext
    ) -> String? {
        fetch(
            id: deterministicId(userId: userId, kind: kind, dayKey: dayKey),
            in: context
        )?.valueText
    }

    /// Recent records of a kind, newest first, capped.
    static func series(
        _ kind: ObservationKind, userId: String, limit: Int = 30, in context: ModelContext
    ) -> [ObservationRecord] {
        let kindRaw = kind.rawValue
        var d = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.userId == userId && $0.kind == kindRaw },
            sortBy: [SortDescriptor(\.dayKey, order: .reverse)]
        )
        d.fetchLimit = limit
        return (try? context.fetch(d)) ?? []
    }

    /// "queasy 3 of the last 7 evenings" — the aggregation the
    /// clinic panel named as structurally impossible before this
    /// store existed.
    static func countMatching(
        _ kind: ObservationKind, values: Set<String>, lastDays: Int,
        userId: String, today: Date = .now, in context: ModelContext
    ) -> Int {
        guard lastDays > 0 else { return 0 }
        let calendar = Calendar.current
        let keys: Set<String> = Set((0..<lastDays).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
                .map { dayKeyFormatter.string(from: $0) }
        })
        return series(kind, userId: userId, limit: lastDays * 3, in: context)
            .filter { keys.contains($0.dayKey) }
            .filter { $0.valueText.map(values.contains) ?? false }
            .count
    }

    /// Remove a day-singular record — the same-day correction path
    /// (a retracted mark is a correction, never history rewrite;
    /// past days are immutable by convention, not mechanism).
    static func deleteSingular(
        _ kind: ObservationKind, dayKey: String, userId: String, in context: ModelContext
    ) {
        guard kind.isDaySingular else { return }
        let id = deterministicId(userId: userId, kind: kind, dayKey: dayKey)
        guard let record = fetch(id: id, in: context) else { return }
        context.delete(record)
        try? context.save()
    }

    // MARK: - Backfill (history becomes chartable)

    private static func backfilledFlagKey(userId: String) -> String {
        "observations.backfilled.v1.\(userId.lowercased())"
    }

    /// One-time sweep of the legacy day-keyed UserDefaults families
    /// into records. Runs after day-reflection hydrate (so a fresh
    /// install's restored keys convert too). Insert-only: never
    /// clobbers a record that already exists.
    static func backfillLegacyIfNeeded(
        userId: String, in context: ModelContext, defaults: UserDefaults = .standard
    ) {
        guard !userId.isEmpty else { return }
        let flag = backfilledFlagKey(userId: userId)
        guard !defaults.bool(forKey: flag) else { return }

        for kind in ObservationKind.allCases {
            guard let prefix = kind.legacyPrefix else { continue }
            for (key, value) in defaults.dictionaryRepresentation()
            where key.hasPrefix(prefix) {
                guard let text = value as? String, !text.isEmpty else { continue }
                let dayKey = String(key.dropFirst(prefix.count))
                guard dayKey.count == 10,
                      let day = dayKeyFormatter.date(from: dayKey) else { continue }
                let id = deterministicId(userId: userId, kind: kind, dayKey: dayKey)
                guard fetch(id: id, in: context) == nil else { continue }
                let record = ObservationRecord(
                    id: id, userId: userId, kind: kind.rawValue, dayKey: dayKey,
                    effectiveAt: day.addingTimeInterval(12 * 3600),
                    valueText: text, source: "manual"
                )
                context.insert(record)
            }
        }
        try? context.save()
        defaults.set(true, forKey: flag)
    }

    // MARK: - Delete-account

    static func deleteAll(userId: String, in context: ModelContext) {
        let d = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for record in (try? context.fetch(d)) ?? [] { context.delete(record) }
        let r = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        for plan in (try? context.fetch(r)) ?? [] { context.delete(plan) }
        try? context.save()
    }
}
