import Foundation

// MARK: - MoveManualStore (v25 E8.1)
//
// Activity Health missed. The minimum useful input, chosen by asking
// what the record actually needs rather than what a form could collect:
//
//   WHAT   a closed set of six kinds, because a free-text field would be
//          unanalysable and a 128-row exercise picker is the thing this
//          release is trying not to become
//   HOW LONG  minutes, in coarse steps
//
// That is all. No sets, no reps, no weight lifted, no RPE, no heart
// rate. The one judgement Move makes is "did something heavy happen
// twice this week", and two taps answer it.
//
// Deliberately NOT written to HealthKit. Writing a fabricated workout
// into a person's health record would put a Jeni estimate into the store
// every other app reads as measurement, and it would come back to us
// through `MovementService` as `measured` on the next refresh — a
// laundering loop. Move keeps its own entries and labels them.
//
// Device-local UserDefaults, no migration, no cloud row: eleven bytes a
// session, and syncing a self-reported activity log is a decision for
// when there is a reason.

@MainActor
enum MoveManualStore {

    private static let key = "move.manual.v1"
    private static let maxEntries = 400

    struct Entry: Codable, Equatable, Identifiable {
        var id: String = UUID().uuidString
        let kind: MoveEnergy.ManualKind
        let minutes: Int
        let at: Date
        /// The estimate at the time it was recorded, so a later weight
        /// change never silently rewrites history. nil when no weight was
        /// on file — the entry is still worth keeping.
        let estimatedKcal: Int?
    }

    static func all() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rows = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return rows.sorted { $0.at > $1.at }
    }

    @discardableResult
    static func record(
        kind: MoveEnergy.ManualKind, minutes: Int, weightKg: Double?, at: Date = .now
    ) -> Entry {
        let entry = Entry(
            kind: kind,
            minutes: minutes,
            at: at,
            estimatedKcal: MoveEnergy.estimatedKcal(
                kind: kind, minutes: minutes, weightKg: weightKg
            )
        )
        var rows = all()
        rows.insert(entry, at: 0)
        save(rows)
        return entry
    }

    static func delete(id: String) {
        save(all().filter { $0.id != id })
    }

    /// Entries in the trailing 7 days, newest first.
    static func lastWeek(now: Date = .now) -> [Entry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        return all().filter { $0.at >= cutoff }
    }

    /// Strength-shaped entries in the trailing 7 days. Only `.strength`
    /// counts: a generous definition here would quietly retire the one
    /// judgement Move makes.
    static func strengthLastWeek(now: Date = .now) -> Int {
        lastWeek(now: now).filter { $0.kind.countsAsStrength }.count
    }

    static func wipe() { UserDefaults.standard.removeObject(forKey: key) }

    private static func save(_ rows: [Entry]) {
        guard let data = try? JSONEncoder().encode(Array(rows.prefix(maxEntries)))
        else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
