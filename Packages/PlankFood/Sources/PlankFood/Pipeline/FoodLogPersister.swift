import Foundation
import SwiftData
import Combine
import UIKit

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
    private static let migratedFlagKey = "jenifit.foodlog.jsonl.migrated"
    // v1.1 food journal (2026-06-11): the 14-day TTL is DEAD. The
    // journal's promise is "your plates, kept" — industry norm is
    // account-lifetime retention (MacroFactor posture; MFP's 2-year
    // free cliff is the category's most-hated policy) and the math
    // says pruning solves a non-problem (~220KB/yr of entries).
    // Storage moved from a UserDefaults blob to an append-only JSONL
    // file (corrupt-line tolerant, atomic appends); the old blob
    // migrates once and is kept as a backup.

    /// Combine publisher fires when a new entry is added. HomeFoodCard
    /// subscribes via .onReceive to refresh its bar on every log.
    public static let changeNotifier = PassthroughSubject<Void, Never>()

    /// Codable entry — serializes to JSON for UserDefaults storage.
    /// Decoupled from the public API so we can swap to SwiftData in
    /// v1.0.8 without breaking the on-disk format readers.
    ///
    /// v1.0.8 Phase T (2026-06-08) — extended with macros so the
    /// NutritionCarousel's daily-totals card can show REAL today's
    /// protein/carbs/fat/fiber instead of heuristic estimates.
    /// Backwards-compatible: old v1 entries (kcal only) decode with
    /// macros defaulted to 0.
    private struct Entry: Codable {
        let id: String
        let userId: String
        let loggedAt: Date
        let kcal: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double
        /// v1.0.9 D3.B — short human-readable label for the timeline
        /// row (e.g. "scrambled eggs", "chipotle chicken bowl").
        /// Derived from CapturedFood.items[0].name at persist time.
        /// Empty for old entries written before this field existed
        /// (backwards-compat decode supplies "" — the timeline row
        /// renders "scanned plate" as a fallback).
        let title: String
        /// v1.0.9 D3.B — capture source tag ("photo" / "quick add" /
        /// "dining out"). Drives the row icon. nil/missing for old
        /// entries.
        let source: String?

        init(
            id: String = UUID().uuidString,
            userId: String,
            loggedAt: Date,
            kcal: Double,
            protein: Double = 0,
            carbs: Double = 0,
            fat: Double = 0,
            fiber: Double = 0,
            title: String = "",
            source: String? = nil
        ) {
            self.id = id
            self.userId = userId
            self.loggedAt = loggedAt
            self.kcal = kcal
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.fiber = fiber
            self.title = title
            self.source = source
        }

        // Backwards-compatible decode — entries written before macros
        // were added decode with 0 for each missing field. Same for
        // title/source/id added in D3.B (2026-06-08).
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
            userId = try c.decode(String.self, forKey: .userId)
            loggedAt = try c.decode(Date.self, forKey: .loggedAt)
            kcal = try c.decode(Double.self, forKey: .kcal)
            protein = (try? c.decode(Double.self, forKey: .protein)) ?? 0
            carbs = (try? c.decode(Double.self, forKey: .carbs)) ?? 0
            fat = (try? c.decode(Double.self, forKey: .fat)) ?? 0
            fiber = (try? c.decode(Double.self, forKey: .fiber)) ?? 0
            title = (try? c.decode(String.self, forKey: .title)) ?? ""
            source = try? c.decode(String.self, forKey: .source)
        }

        enum CodingKeys: String, CodingKey {
            case id, userId, loggedAt, kcal, protein, carbs, fat, fiber, title, source
        }
    }

    // MARK: - Public DTO (D3.B timeline)

    /// v1.0.9 D3.B — public per-entry DTO surfaced to the food log
    /// timeline screen. Identifiable so SwiftUI's ForEach works
    /// without a wrapper. All fields are populated from the in-memory
    /// store; old entries (pre-D3.B) ship with synthesized ids +
    /// empty titles, which the timeline row handles via fallback copy.
    public struct FoodLogEntry: Sendable, Identifiable {
        public let id: String
        public let loggedAt: Date
        public let title: String
        public let kcal: Double
        public let protein: Double
        public let carbs: Double
        public let fat: Double
        public let source: String?
    }

    /// v1.0.8 Phase T — today's macro totals at a glance. All values
    /// reflect REAL logged macros, defaulting to 0 for old entries
    /// without macro data. Returned as a struct so callers grab all
    /// macros in a single store-walk.
    public struct TodayMacros: Sendable {
        public let kcal: Double
        public let protein: Double
        public let carbs: Double
        public let fat: Double
        public let fiber: Double
    }

    // MARK: - JSONL store

    private static var storeURL: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        let dir = base.appendingPathComponent("FoodLogs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("entries.jsonl")
    }

    /// Lazy hydrate on first read after a cold launch. Reads the
    /// JSONL file line-by-line — a corrupt line loses ONE entry,
    /// never the journal. One-time migration pulls the legacy
    /// UserDefaults blob in first (blob kept as a backup; never
    /// deleted).
    private static func hydrateIfNeeded() {
        guard !didHydrate else { return }
        didHydrate = true
        migrateLegacyBlobIfNeeded()
        guard let url = storeURL,
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return }
        let decoder = JSONDecoder()
        var loaded: [Entry] = []
        for line in raw.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let entry = try? decoder.decode(Entry.self, from: data) else { continue }
            loaded.append(entry)
        }
        // De-dupe by id (replays from a partially-failed rewrite keep
        // the last occurrence) and restore chronological order.
        var byId: [String: Entry] = [:]
        for entry in loaded { byId[entry.id] = entry }
        inMemoryEntries = byId.values.sorted { $0.loggedAt < $1.loggedAt }
    }

    private static func migrateLegacyBlobIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedFlagKey),
              let url = storeURL else { return }
        defer { UserDefaults.standard.set(true, forKey: migratedFlagKey) }
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let legacy = try? JSONDecoder().decode([Entry].self, from: data),
              !legacy.isEmpty else { return }
        // Don't double-write if a JSONL already exists (defensive).
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let encoder = JSONEncoder()
        let lines = legacy.compactMap { entry -> String? in
            guard let d = try? encoder.encode(entry) else { return nil }
            return String(data: d, encoding: .utf8)
        }
        try? (lines.joined(separator: "\n") + "\n")
            .write(to: url, atomically: true, encoding: .utf8)
    }

    /// Append ONE entry to the JSONL file. O(1) per log; no rewrite
    /// of history, no pruning — logs are kept for the account
    /// lifetime per the retention policy.
    private static func appendToStore(_ entry: Entry) {
        guard let url = storeURL,
              let data = try? JSONEncoder().encode(entry),
              let line = String(data: data, encoding: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data((line + "\n").utf8))
        } else {
            try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Public read APIs

    /// v1.0.8 Phase S (2026-06-08) — sum of all kcal logged TODAY,
    /// across all users on this device. Single-user-per-device app
    /// so no userId filter needed. Drives the "Calories: N / target"
    /// progress bar on the NutritionCarousel's daily-totals card.
    /// Returns 0 before any logs are persisted today.
    public static func todayKcalTotal() -> Double {
        hydrateIfNeeded()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return inMemoryEntries
            .filter { $0.loggedAt >= startOfDay }
            .reduce(0.0) { $0 + $1.kcal }
    }

    /// v1.0.8 Phase S — count of logs today, used for a future
    /// "you've logged N meals" affordance. Currently unused but
    /// cheap, so left in.
    public static func todayLogCount() -> Int {
        hydrateIfNeeded()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return inMemoryEntries.filter { $0.loggedAt >= startOfDay }.count
    }

    /// v1.0.8 Phase T — sum of TODAY's kcal + macros from real
    /// persisted entries. Drives the NutritionCarousel daily-totals
    /// card; every percentage on slide 2 now traces to a number
    /// here, not a heuristic.
    public static func todayMacros() -> TodayMacros {
        hydrateIfNeeded()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let todays = inMemoryEntries.filter { $0.loggedAt >= startOfDay }
        return TodayMacros(
            kcal:    todays.reduce(0.0) { $0 + $1.kcal },
            protein: todays.reduce(0.0) { $0 + $1.protein },
            carbs:   todays.reduce(0.0) { $0 + $1.carbs },
            fat:     todays.reduce(0.0) { $0 + $1.fat },
            fiber:   todays.reduce(0.0) { $0 + $1.fiber }
        )
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
        photo: UIImage? = nil,
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

        // v1.0.8 Phase T — sum macros across items so today's totals
        // are REAL. compactMap skips items missing a given macro
        // (which can happen on the .imOut restaurant-range path or
        // when the LLM omits a value); contributing items add their
        // value, missing items add 0. This is the source-of-truth for
        // every "today's protein/carbs/fat/fiber" number across the
        // app, including the carousel daily-totals card.
        let plateProtein = food.items.compactMap { $0.proteinG }.reduce(0, +)
        let plateCarbs   = food.items.compactMap { $0.carbsG }.reduce(0, +)
        let plateFat     = food.items.compactMap { $0.fatG }.reduce(0, +)
        let plateFiber   = food.items.compactMap { $0.fiberG }.reduce(0, +)

        hydrateIfNeeded()
        let loggedAt = Date()
        // v1.0.9 D3.B — derive a short title for the timeline row.
        // Heuristic: first item's name, plus "+ N more" if multiple
        // items. Empty items (restaurant-range / .imOutTonight path)
        // falls back to "dining out" so the row reads meaningfully.
        let title: String
        if let first = food.items.first {
            let more = food.items.count - 1
            title = more > 0 ? "\(first.name) + \(more) more" : first.name
        } else if food.source == .imOut {
            title = "dining out"
        } else {
            title = "scanned plate"
        }
        let entryId = UUID().uuidString
        let entry = Entry(
            id: entryId,
            userId: userId,
            loggedAt: loggedAt,
            kcal: plateKcal,
            protein: plateProtein,
            carbs: plateCarbs,
            fat: plateFat,
            fiber: plateFiber,
            title: title,
            source: food.source.rawValue
        )
        inMemoryEntries.append(entry)
        appendToStore(entry)

        // v1.1 Becoming filmstrip — persist a small on-device thumbnail
        // keyed by the entry id. Forward-only; nil for quick-add /
        // dining-out paths.
        if let photo { FoodPhotoStore.save(photo, entryId: entryId) }

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

    // MARK: - D3.B timeline reads

    /// v1.0.9 D3.B — every entry for this user, ordered newest first.
    /// Drives the chronological food log timeline screen. Returns all
    /// retained entries (up to retentionDays, currently 14d). Cheap
    /// since the store is in-memory after hydrate.
    public static func allEntries(userId: String) -> [FoodLogEntry] {
        hydrateIfNeeded()
        return inMemoryEntries
            .filter { $0.userId == userId }
            .sorted { $0.loggedAt > $1.loggedAt }
            .map {
                FoodLogEntry(
                    id: $0.id,
                    loggedAt: $0.loggedAt,
                    title: $0.title,
                    kcal: $0.kcal,
                    protein: $0.protein,
                    carbs: $0.carbs,
                    fat: $0.fat,
                    source: $0.source
                )
            }
    }

    /// v1.0.9 D3.B — remove a single entry by id. Used by the
    /// timeline's swipe-to-delete affordance. Fires changeNotifier
    /// so HomeFoodCard's bars refresh after a delete. Silent no-op
    /// if the id doesn't match (user could have force-quit between
    /// list render and tap).
    public static func deleteEntry(id: String) {
        hydrateIfNeeded()
        let before = inMemoryEntries.count
        inMemoryEntries.removeAll { $0.id == id }
        guard inMemoryEntries.count != before else { return }
        rewriteStore()
        changeNotifier.send(())
    }

    /// Full rewrite of the JSONL file — deletes are rare, so the
    /// O(n) rewrite is fine (appends stay O(1) via appendToStore).
    private static func rewriteStore() {
        guard let url = storeURL else { return }
        let encoder = JSONEncoder()
        let lines = inMemoryEntries.compactMap { entry -> String? in
            guard let d = try? encoder.encode(entry) else { return nil }
            return String(data: d, encoding: .utf8)
        }
        try? (lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n"))
            .write(to: url, atomically: true, encoding: .utf8)
    }
}
