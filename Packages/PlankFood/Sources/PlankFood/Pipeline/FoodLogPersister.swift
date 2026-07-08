import Foundation
import SwiftData
import Combine
import UIKit

// MARK: - FoodLogPersister
//
// Account-lifetime food log store. Cross-package SwiftData @Model
// integration originally hung the app on launch (suspect cross-package
// @Model registration on iOS 17), so persistence runs through a
// dedicated on-disk store seeded by an in-memory cache.
//
// Persistence flow (current — JSONL since 2026-06-11):
//   - `persist()` appends to inMemoryEntries AND writes one JSON line
//     to entries.jsonl. O(1) append per log, no full rewrite.
//   - First read on every entry point calls hydrateIfNeeded(), which
//     parses entries.jsonl line-by-line on a cold launch (a corrupt
//     line skips just that entry, the rest load). Subsequent reads
//     are pure in-memory.
//   - The pre-2026-06-11 UserDefaults blob ("jenifit.foodlog.v1") is
//     migrated into the JSONL once via `migratedFlagKey` and kept on
//     disk as a backup.
//   - No TTL. Industry posture per v1.1 food journal spec is account-
//     lifetime retention (MacroFactor parity, anti-MFP 2-year cliff);
//     ~220KB/yr of entries is non-load-bearing.
//
// HomeFoodCard + the Becoming plates teaser read via
// `todayAndWeekly(userId:)` + `allEntries(userId:)` and observe
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
        /// v1.1.5 — added sugar so the plate detail + becoming food page
        /// can surface it (a diet signal the founder wanted visible).
        /// Device-local for now: it rides the JSONL like `itemsDetail`,
        /// NOT the cloud row (which would need a food_logs.sugar_g column
        /// + a coordinated migration). Sums CapturedItem.sugarG, which
        /// today comes from USDA/OpenFoodFacts calibration and, once the
        /// food-vision EF adds sugar_g, from the model directly. 0 (silent)
        /// for older entries + cloud-restored plates.
        let sugar: Double
        /// v1.0.9 D3.B — short human-readable label for the timeline
        /// row (e.g. "scrambled eggs", "chipotle chicken bowl").
        /// Derived from CapturedFood.items[0].name at persist time.
        /// Empty for old entries written before this field existed
        /// (backwards-compat decode supplies "" — the timeline row
        /// renders "scanned plate" as a fallback).
        let title: String
        /// v1.0.13 (2026-06-18) — full list of food-item names from
        /// the scan, in vision-ranked order. nil for older entries
        /// written before this field existed (decoder defaults to
        /// nil → callers fall back to splitting `title`). Carries
        /// what the share card actually wants to render: every item
        /// the user logged, not just the first + count.
        let items: [String]?
        /// v1.0.9 D3.B — capture source tag ("photo" / "quick add" /
        /// "dining out"). Drives the row icon. nil/missing for old
        /// entries.
        let source: String?
        /// v1.2 snap-food rebuild (2026-07-01) — full per-item nutrition
        /// detail (name + portion + kcal + macros per ingredient).
        /// Powers the journal detail ledger and high-fidelity relogs.
        /// nil for entries written before this field existed; the
        /// device-local JSONL grows ~120 bytes/item. NOT synced (the
        /// food_logs cloud row stays plate-level).
        let itemsDetail: [ItemDetail]?

        init(
            id: String = UUID().uuidString,
            userId: String,
            loggedAt: Date,
            kcal: Double,
            protein: Double = 0,
            carbs: Double = 0,
            fat: Double = 0,
            fiber: Double = 0,
            sugar: Double = 0,
            title: String = "",
            items: [String]? = nil,
            source: String? = nil,
            itemsDetail: [ItemDetail]? = nil
        ) {
            self.id = id
            self.userId = userId
            self.loggedAt = loggedAt
            self.kcal = kcal
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.fiber = fiber
            self.sugar = sugar
            self.title = title
            self.items = items
            self.source = source
            self.itemsDetail = itemsDetail
        }

        // Backwards-compatible decode — entries written before macros
        // were added decode with 0 for each missing field. Same for
        // title/source/id added in D3.B (2026-06-08); items added
        // v1.0.13 (2026-06-18) and itemsDetail added v1.2 (2026-07-01)
        // decode to nil for older entries.
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
            sugar = (try? c.decode(Double.self, forKey: .sugar)) ?? 0
            title = (try? c.decode(String.self, forKey: .title)) ?? ""
            items = try? c.decode([String].self, forKey: .items)
            source = try? c.decode(String.self, forKey: .source)
            itemsDetail = try? c.decode([ItemDetail].self, forKey: .itemsDetail)
        }

        enum CodingKeys: String, CodingKey {
            case id, userId, loggedAt, kcal, protein, carbs, fat, fiber, sugar,
                 title, items, source, itemsDetail
        }
    }

    /// v1.2 — per-ingredient nutrition snapshot persisted with the
    /// entry. Device-local only (rides the JSONL, not the cloud row).
    public struct ItemDetail: Codable, Sendable, Equatable {
        public let name: String
        public let portionG: Double
        public let kcal: Double
        public let protein: Double
        public let carbs: Double
        public let fat: Double

        public init(
            name: String, portionG: Double, kcal: Double,
            protein: Double, carbs: Double, fat: Double
        ) {
            self.name = name
            self.portionG = portionG
            self.kcal = kcal
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
        }
    }

    // MARK: - Cloud sync seam
    //
    // The JSONL store is device-local; without a sync path every
    // reinstall or device switch silently wipes the journal ("your
    // plates, kept" broken). PlankFood stays Supabase-blind: the main
    // app registers the two hooks at launch and AppSync does the
    // network work against the food_logs table.

    /// Full-fidelity entry DTO for the sync layer (FoodLogEntry drops
    /// userId + fiber, which the cloud row needs).
    public struct SyncableEntry: Sendable {
        public let id: String
        public let userId: String
        public let loggedAt: Date
        public let kcal: Double
        public let protein: Double
        public let carbs: Double
        public let fat: Double
        public let fiber: Double
        public let title: String
        public let source: String?

        public init(
            id: String, userId: String, loggedAt: Date, kcal: Double,
            protein: Double, carbs: Double, fat: Double, fiber: Double,
            title: String, source: String?
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
    }

    /// Fired after a new entry lands in the local store. Registered by
    /// the main app at launch; nil = sync disabled (tests, previews).
    public static var onEntryPersisted: (@MainActor (SyncableEntry) -> Void)?
    /// Fired after a local delete with (entryId, userId).
    public static var onEntryDeleted: (@MainActor (String, String) -> Void)?

    /// Every local entry for the user, full fidelity — the launch
    /// reconcile pushes the ones the server doesn't have yet.
    public static func allSyncableEntries(userId: String) -> [SyncableEntry] {
        hydrateIfNeeded()
        return inMemoryEntries
            .filter { $0.userId == userId }
            .map {
                SyncableEntry(
                    id: $0.id, userId: $0.userId, loggedAt: $0.loggedAt,
                    kcal: $0.kcal, protein: $0.protein, carbs: $0.carbs,
                    fat: $0.fat, fiber: $0.fiber, title: $0.title,
                    source: $0.source
                )
            }
    }

    /// Merge server rows into the local store. Insert-only by id —
    /// local edits never get clobbered, replays are no-ops. Fires
    /// changeNotifier once when anything new landed.
    public static func mergeRemote(_ remote: [SyncableEntry]) {
        hydrateIfNeeded()
        let localIds = Set(inMemoryEntries.map(\.id))
        let fresh = remote.filter { !localIds.contains($0.id) }
        guard !fresh.isEmpty else { return }
        for r in fresh {
            let entry = Entry(
                id: r.id, userId: r.userId, loggedAt: r.loggedAt,
                kcal: r.kcal, protein: r.protein, carbs: r.carbs,
                fat: r.fat, fiber: r.fiber, title: r.title, source: r.source
            )
            inMemoryEntries.append(entry)
            appendToStore(entry)
        }
        inMemoryEntries.sort { $0.loggedAt < $1.loggedAt }
        changeNotifier.send(())
    }

    #if DEBUG
    /// QA-only: append a fully-specified local entry (including sugar,
    /// which the cloud SyncableEntry doesn't carry) so the sugar surfaces
    /// can be audited without a real scan.
    public static func debugSeed(
        id: String, userId: String, loggedAt: Date, kcal: Double,
        protein: Double, carbs: Double, fat: Double, fiber: Double,
        sugar: Double, title: String, source: String?
    ) {
        hydrateIfNeeded()
        guard !inMemoryEntries.contains(where: { $0.id == id }) else { return }
        let entry = Entry(
            id: id, userId: userId, loggedAt: loggedAt, kcal: kcal,
            protein: protein, carbs: carbs, fat: fat, fiber: fiber,
            sugar: sugar, title: title, source: source
        )
        inMemoryEntries.append(entry)
        appendToStore(entry)
        inMemoryEntries.sort { $0.loggedAt < $1.loggedAt }
        changeNotifier.send(())
    }
    #endif

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
        /// v1.0.13 (2026-06-18) — exposed on the public surface so
        /// the daily / weekly share card label can show fiber per
        /// pic ("8:42am · 430c · 25p · 7f"). Internal Entry has
        /// carried fiber since Phase T; this bridges it.
        public let fiber: Double
        /// v1.1.5 — plate sugar (device-local; 0 = silent). Surfaced on
        /// the plate detail sheet + folded into today's totals.
        public var sugar: Double = 0
        /// v1.0.13 (2026-06-18) — full list of food-item names from
        /// the scan, in vision-ranked order. nil for entries written
        /// before this field existed (callers fall back to splitting
        /// `title` on common separators). Used by the daily / weekly
        /// share card to render the vertical ingredient stack the
        /// founder wants instead of the "name + N more" title.
        public let items: [String]?
        public let source: String?
        /// v1.2 — per-ingredient nutrition detail when the entry was
        /// written by the rebuilt snap flow; nil for older entries.
        public let itemsDetail: [ItemDetail]?

        public init(
            id: String,
            loggedAt: Date,
            title: String,
            kcal: Double,
            protein: Double,
            carbs: Double,
            fat: Double,
            fiber: Double = 0,
            sugar: Double = 0,
            items: [String]? = nil,
            source: String?,
            itemsDetail: [ItemDetail]? = nil
        ) {
            self.id = id
            self.loggedAt = loggedAt
            self.title = title
            self.kcal = kcal
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.fiber = fiber
            self.sugar = sugar
            self.items = items
            self.source = source
            self.itemsDetail = itemsDetail
        }
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
        /// v1.1.5 — today's sugar total. 0 when no logged plate carried
        /// a sugar value (silent, per the provenance rule).
        public var sugar: Double = 0
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
    /// v2.7 — user-scoped overload. The unscoped variant summed EVERY
    /// account's plates on the device: after a sign-out -> new-anon
    /// switch, the prior user's lunch kept feeding the new user's
    /// kcal line (caught by the motion-QA frame where the plate strip
    /// was empty while the kcal line read 860). Same case-insensitive
    /// uuid compare as allEntries(userId:).
    public static func todayMacros(userId: String) -> TodayMacros {
        hydrateIfNeeded()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let uid = userId.lowercased()
        let todays = inMemoryEntries.filter {
            $0.loggedAt >= startOfDay && $0.userId.lowercased() == uid
        }
        return TodayMacros(
            kcal:    todays.reduce(0.0) { $0 + $1.kcal },
            protein: todays.reduce(0.0) { $0 + $1.protein },
            carbs:   todays.reduce(0.0) { $0 + $1.carbs },
            fat:     todays.reduce(0.0) { $0 + $1.fat },
            fiber:   todays.reduce(0.0) { $0 + $1.fiber },
            sugar:   todays.reduce(0.0) { $0 + $1.sugar }
        )
    }

    public static func todayMacros() -> TodayMacros {
        hydrateIfNeeded()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let todays = inMemoryEntries.filter { $0.loggedAt >= startOfDay }
        return TodayMacros(
            kcal:    todays.reduce(0.0) { $0 + $1.kcal },
            protein: todays.reduce(0.0) { $0 + $1.protein },
            carbs:   todays.reduce(0.0) { $0 + $1.carbs },
            fat:     todays.reduce(0.0) { $0 + $1.fat },
            fiber:   todays.reduce(0.0) { $0 + $1.fiber },
            sugar:   todays.reduce(0.0) { $0 + $1.sugar }
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
        // v1.1.5 — sugar rides along when the pipeline has it (USDA/OFF
        // calibration today; the model directly once the EF returns
        // sugar_g). Items without a sugar value contribute nothing, so
        // the plate total stays honest rather than guessed.
        let plateSugar   = food.items.compactMap { $0.sugarG }.reduce(0, +)

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
        // v1.0.13 (2026-06-18) — persist the full item-name list so
        // the share card can show every food, not just the title's
        // "first + N more" heuristic. Empty for restaurant-range /
        // im-out path (no detected items), which the share card
        // handles via the title-split fallback.
        let plateItems: [String]? = {
            let names = food.items
                .map { $0.name.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return names.isEmpty ? nil : names
        }()
        // v1.2 — full per-ingredient snapshot (device-local). Powers
        // the journal detail ledger + high-fidelity "log it again".
        let detail: [ItemDetail]? = {
            let rows = food.items.compactMap { item -> ItemDetail? in
                guard !item.name.trimmingCharacters(in: .whitespaces).isEmpty
                else { return nil }
                return ItemDetail(
                    name: item.name,
                    portionG: item.portionGrams,
                    kcal: item.kcal ?? 0,
                    protein: item.proteinG ?? 0,
                    carbs: item.carbsG ?? 0,
                    fat: item.fatG ?? 0
                )
            }
            return rows.isEmpty ? nil : rows
        }()
        let entry = Entry(
            id: entryId,
            userId: userId,
            loggedAt: loggedAt,
            kcal: plateKcal,
            protein: plateProtein,
            carbs: plateCarbs,
            fat: plateFat,
            fiber: plateFiber,
            sugar: plateSugar,
            title: title,
            items: plateItems,
            source: food.source.rawValue,
            itemsDetail: detail
        )
        inMemoryEntries.append(entry)
        appendToStore(entry)

        // v1.1 Becoming filmstrip — persist a small on-device thumbnail
        // keyed by the entry id. Forward-only; nil for quick-add /
        // dining-out paths.
        if let photo { FoodPhotoStore.save(photo, entryId: entryId) }

        changeNotifier.send(())

        // Cloud sync hook — fire-and-forget upsert to food_logs.
        onEntryPersisted?(SyncableEntry(
            id: entry.id, userId: entry.userId, loggedAt: entry.loggedAt,
            kcal: entry.kcal, protein: entry.protein, carbs: entry.carbs,
            fat: entry.fat, fiber: entry.fiber, title: entry.title,
            source: entry.source
        ))

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
        let uid = userId.lowercased()
        return inMemoryEntries
            .filter { $0.userId.lowercased() == uid }
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
                    fiber: $0.fiber,
                    sugar: $0.sugar,
                    items: $0.items,
                    source: $0.source,
                    itemsDetail: $0.itemsDetail
                )
            }
    }

    // MARK: - v1.2 recents + relog ("again")

    /// Distinct recent meals for the one-tap relog rail — newest first,
    /// deduped by normalized title (the same lunch logged five times is
    /// one row), untitled rows skipped. Most meals are repeats; the
    /// fastest and most accurate "scan" is not scanning at all.
    public static func recentMeals(userId: String, limit: Int = 6) -> [FoodLogEntry] {
        var seen = Set<String>()
        var result: [FoodLogEntry] = []
        for entry in allEntries(userId: userId) {
            let key = entry.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !key.isEmpty, entry.kcal > 0, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(entry)
            if result.count >= limit { break }
        }
        return result
    }

    /// One-tap relog: persist a fresh entry (now-timestamped) copying a
    /// prior meal's nutrition + title + per-item detail. No photo (the
    /// old thumbnail belongs to the old moment). Fires the same change
    /// + sync hooks as a scan-sourced persist.
    public static func relog(_ source: FoodLogEntry, userId: String) {
        hydrateIfNeeded()
        let entry = Entry(
            userId: userId,
            loggedAt: Date(),
            kcal: source.kcal,
            protein: source.protein,
            carbs: source.carbs,
            fat: source.fat,
            fiber: source.fiber,
            title: source.title,
            items: source.items,
            source: source.source,
            itemsDetail: source.itemsDetail
        )
        inMemoryEntries.append(entry)
        appendToStore(entry)
        changeNotifier.send(())
        onEntryPersisted?(SyncableEntry(
            id: entry.id, userId: entry.userId, loggedAt: entry.loggedAt,
            kcal: entry.kcal, protein: entry.protein, carbs: entry.carbs,
            fat: entry.fat, fiber: entry.fiber, title: entry.title,
            source: entry.source
        ))
        FoodHealthKitWriter.writeIfRegistered(kcal: entry.kcal, at: entry.loggedAt)
    }

    /// v1.0.9 D3.B — remove a single entry by id. Used by the
    /// timeline's swipe-to-delete affordance. Fires changeNotifier
    /// so HomeFoodCard's bars refresh after a delete. Silent no-op
    /// if the id doesn't match (user could have force-quit between
    /// list render and tap).
    public static func deleteEntry(id: String) {
        hydrateIfNeeded()
        guard let removed = inMemoryEntries.first(where: { $0.id == id }) else { return }
        inMemoryEntries.removeAll { $0.id == id }
        rewriteStore()
        // v1.1.1 (2026-06-19) — also remove the plate thumbnail.
        // Before this, deleting an entry left the JPEG on disk
        // indefinitely — privacy regression (user thinks she wiped
        // her food diary; she didn't) + slow disk leak.
        FoodPhotoStore.delete(entryId: removed.id)
        changeNotifier.send(())
        onEntryDeleted?(removed.id, removed.userId)
    }

    /// Re-key entries from one userId to another — the sign-in merge
    /// path (anon experimentation folds into the named account). The
    /// launch reconcile pushes the re-keyed rows on the next hydrate.
    public static func reattributeEntries(from oldId: String, to newId: String) {
        hydrateIfNeeded()
        guard oldId != newId, inMemoryEntries.contains(where: { $0.userId == oldId }) else { return }
        inMemoryEntries = inMemoryEntries.map { e in
            guard e.userId == oldId else { return e }
            // Fresh id, not just a new userId: the cloud row already exists
            // under the old uid, so a same-id upsert is an UPDATE that RLS
            // rejects (auth.uid() != the row's old user_id → 42501, silently
            // dropped). A new id makes the launch reconcile push a clean
            // INSERT the signed-in account owns, so the entry survives the
            // next reinstall. The local thumbnail is keyed by entry id, so
            // it moves with the re-key.
            let freshId = UUID().uuidString
            FoodPhotoStore.rekey(from: e.id, to: freshId)
            return Entry(
                id: freshId, userId: newId, loggedAt: e.loggedAt, kcal: e.kcal,
                protein: e.protein, carbs: e.carbs, fat: e.fat,
                fiber: e.fiber, title: e.title, items: e.items,
                source: e.source
            )
        }
        rewriteStore()
        changeNotifier.send(())
    }

    /// Wipe every entry for a user — the delete-account path. Cloud
    /// rows are removed by the server-side cascade; this only clears
    /// the device copy (no per-entry delete hooks fired).
    public static func deleteAllEntries(userId: String) {
        hydrateIfNeeded()
        let before = inMemoryEntries.count
        // Capture the entries being removed so we can wipe their
        // photos too — privacy invariant: delete-account leaves zero
        // user content on disk.
        let removed = inMemoryEntries.filter { $0.userId == userId }
        inMemoryEntries.removeAll { $0.userId == userId }
        guard inMemoryEntries.count != before else { return }
        rewriteStore()
        // v1.1.1 (2026-06-19) — wipe each removed entry's thumbnail.
        // Photos are keyed by entryId so per-entry delete is the
        // safe path (single-tenant device with multi-user sign-in:
        // we don't want to clobber another user's photos here).
        for entry in removed {
            FoodPhotoStore.delete(entryId: entry.id)
        }
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
