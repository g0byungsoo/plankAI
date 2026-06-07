import Foundation
import SwiftData
import Combine

// MARK: - FoodLogPersister
//
// V1.0.7 STOP-GAP (2026-06-04, hardened 2026-06-06 per QA blocker 1):
// SwiftData @Model integration caused the app to hang on launch
// (suspect cross-package @Model registration on iOS 17). Until
// v1.0.8 lands a proper integration with VersionedSchema +
// MigrationPlan, FoodLogPersister keeps logs in an in-memory store
// MIRRORED to UserDefaults JSON so cold-launch + background-kill
// no longer wipe today's plate.
//
// Persistence flow:
//   - `persist()` appends to inMemoryEntries AND writes the full
//     entry array to UserDefaults under "jenifit.foodlog.v1" as
//     JSON. Atomic enough for our load — single-array overwrite.
//   - First read (`todayAndWeekly` / `last7DaysKcal`) hydrates
//     inMemoryEntries from UserDefaults if the in-memory store
//     is empty (cold launch). Subsequent reads are pure in-memory.
//   - 14-day TTL prunes old entries on each write to bound the
//     UserDefaults payload size (Becoming + Home only ever query
//     the last 7 days; 14 gives headroom for clock skew + weekly
//     recap).
//
// HomeFoodCard reads via `todayAndWeekly(userId:)` + observes
// `changeNotifier` for live updates after a scan.
//
// The `persist(_:userId:photoMode:into:)` signature is preserved so
// CaptureFlowView's call site doesn't change — the ModelContext
// argument is ignored, swap is invisible to call sites.

@MainActor
public enum FoodLogPersister {

    // MARK: - In-memory store + UserDefaults mirror

    private static var inMemoryEntries: [Entry] = []
    private static var didHydrate: Bool = false
    private static let userDefaultsKey = "jenifit.foodlog.v1"
    /// Entries older than this many days are pruned on every write
    /// to bound the UserDefaults payload. 14d covers the 7-day
    /// Becoming/Home reads plus headroom.
    private static let retentionDays: Int = 14

    /// Combine publisher fires when a new entry is added. HomeFoodCard
    /// subscribes via .onReceive to refresh its bar on every log.
    public static let changeNotifier = PassthroughSubject<Void, Never>()

    /// Codable entry — serializes to JSON for UserDefaults storage.
    /// Decoupled from the public API so we can swap to SwiftData in
    /// v1.0.8 without breaking the on-disk format readers.
    private struct Entry: Codable {
        let userId: String
        let loggedAt: Date
        let kcal: Double
    }

    /// Lazy hydrate from UserDefaults on first read after a cold
    /// launch. Idempotent — guarded by `didHydrate` so warm reads
    /// stay O(1).
    private static func hydrateIfNeeded() {
        guard !didHydrate else { return }
        didHydrate = true
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        do {
            let decoded = try JSONDecoder().decode([Entry].self, from: data)
            inMemoryEntries = decoded
        } catch {
            // Bad blob — treat as empty (worst case: user loses the
            // last few logs, not the entire run). Don't overwrite
            // the corrupt blob until the next successful write so
            // a debugger can still inspect it.
            #if DEBUG
            print("[FoodLogPersister] failed to decode UserDefaults blob: \(error)")
            #endif
        }
    }

    /// Write the full entry array (post-prune) to UserDefaults as
    /// JSON. Called from `persist()` on every successful log.
    private static func writeToUserDefaults() {
        // Prune entries older than retentionDays before persisting.
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)
        inMemoryEntries.removeAll { $0.loggedAt < cutoff }
        do {
            let data = try JSONEncoder().encode(inMemoryEntries)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            #if DEBUG
            print("[FoodLogPersister] failed to encode entries: \(error)")
            #endif
        }
    }

    // MARK: - Public API

    /// Insert a CapturedFood. Returns a placeholder FoodLogRecord
    /// (caller may use the returned id for telemetry). The
    /// ModelContext argument is IGNORED in the stop-gap — kept in
    /// the signature so CaptureFlowView doesn't change.
    @discardableResult
    public static func persist(
        _ food: CapturedFood,
        userId: String,
        into context: ModelContext
    ) throws -> FoodLogRecord {

        let plateKcal: Double
        if let low = food.kcalLow, let high = food.kcalHigh {
            plateKcal = (low + high) / 2
        } else {
            plateKcal = food.items
                .compactMap { $0.kcal }
                .reduce(0, +)
        }

        hydrateIfNeeded()
        let loggedAt = Date()
        inMemoryEntries.append(Entry(
            userId: userId,
            loggedAt: loggedAt,
            kcal: plateKcal
        ))
        writeToUserDefaults()

        changeNotifier.send(())

        // Apple Health write hook. The main app registers a closure at
        // launch that reads the user's "foodHealthKitWriteEnabled"
        // toggle, confirms HK auth, and saves an HKQuantitySample.
        // No-op if toggle off or write auth not granted. PlankFood
        // stays HealthKit-blind.
        FoodHealthKitWriter.writeIfRegistered(kcal: plateKcal, at: loggedAt)

        // Return a placeholder FoodLogRecord so the call-site signature
        // is preserved (the @Model class still exists; it's just not in
        // the app's ModelContainer until v1.0.8).
        return FoodLogRecord(
            userId: userId,
            kcalTotal: plateKcal,
            plateType: food.plateType.rawValue,
            source: food.source.rawValue,
            photoMode: nil  // D54 — column kept for v1.0.8 SwiftData
                            // migration safety; always nil now.
        )
    }

    /// Aggregate today's kcal + weekly average from the in-memory
    /// store. Called by HomeFoodCard on appear + every changeNotifier
    /// emission.
    public static func todayAndWeekly(userId: String) -> (today: Double, weekly: Double?) {
        hydrateIfNeeded()
        let cal = Calendar.current
        let now = Date.now
        let startOfToday = cal.startOfDay(for: now)
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: now)!

        let userEntries = inMemoryEntries.filter { $0.userId == userId }

        let today = userEntries
            .filter { $0.loggedAt >= startOfToday }
            .reduce(0) { $0 + $1.kcal }

        // Group last-7-days entries by day for the weekly average.
        var byDay: [Date: Double] = [:]
        for entry in userEntries where entry.loggedAt >= sevenDaysAgo {
            let day = cal.startOfDay(for: entry.loggedAt)
            byDay[day, default: 0] += entry.kcal
        }
        let weekly: Double?
        if byDay.isEmpty {
            weekly = nil
        } else {
            weekly = byDay.values.reduce(0, +) / Double(byDay.count)
        }

        return (today, weekly)
    }

    /// Per-day kcal totals for the last 7 days, ordered oldest → newest.
    /// Days with no logs return 0. Used by FoodWeekBentoTile to render
    /// the 7-bar week strip in the Becoming bento.
    public static func last7DaysKcal(userId: String) -> [(date: Date, kcal: Double)] {
        hydrateIfNeeded()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date.now)
        let userEntries = inMemoryEntries.filter { $0.userId == userId }

        var byDay: [Date: Double] = [:]
        for entry in userEntries {
            let day = cal.startOfDay(for: entry.loggedAt)
            // Only consider entries within the last-7-days window.
            guard let daysAgo = cal.dateComponents([.day], from: day, to: today).day,
                  daysAgo >= 0, daysAgo < 7 else { continue }
            byDay[day, default: 0] += entry.kcal
        }

        var result: [(date: Date, kcal: Double)] = []
        for offset in (0..<7).reversed() {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            result.append((day, byDay[day] ?? 0))
        }
        return result
    }
}
