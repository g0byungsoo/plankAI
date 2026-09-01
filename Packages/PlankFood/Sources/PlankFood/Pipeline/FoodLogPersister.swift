import Foundation
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
        /// v9 P5 (2026-08-03) — sodium + saturated fat finally
        /// persist (the audit's dead-end: sodium was cited as THE
        /// scale-swing mechanism yet stored nowhere). Filled by the
        /// USDA/OFF calibration sweep today and by the model directly
        /// once the EF's sodium_mg/saturated_fat_g deploy. 0 = not
        /// collected (never fabricated).
        let sodiumMg: Double
        let satFatG: Double
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
        /// v25 E4 — every fix-with-words sentence she applied before
        /// logging, in order. The corrections flywheel's raw
        /// material: an entry with corrections is the strong prior
        /// for the next scan of the same dish. nil = untouched.
        let corrections: [String]?
        /// p53 — structured DELIBERATE hand edits (stepper, fraction,
        /// editor, remove, add), their own channel beside the spoken
        /// fixes. nil = untouched by hand.
        let edits: [String]?
        /// p53 — the package code when this plate came through the
        /// barcode door. The verify-once key.
        let barcode: String?

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
            sodiumMg: Double = 0,
            satFatG: Double = 0,
            title: String = "",
            items: [String]? = nil,
            source: String? = nil,
            itemsDetail: [ItemDetail]? = nil,
            corrections: [String]? = nil,
            edits: [String]? = nil,
            barcode: String? = nil
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
            self.sodiumMg = sodiumMg
            self.satFatG = satFatG
            self.title = title
            self.items = items
            self.source = source
            self.itemsDetail = itemsDetail
            self.corrections = corrections
            self.edits = edits
            self.barcode = barcode
        }

        /// p55 — THE ONE RE-INIT. Every "same entry, different
        /// id/owner/day" site used to hand-write `Entry(...)` and the
        /// defaulted parameters ate a newly-added field SIX times
        /// (#7–#9 were `edits` + `barcode` at `setLoggedDay` and both
        /// merge branches). This helper names every field exactly
        /// once; a field added to `Entry` without being added here
        /// fails to compile only if it has no default — so the carry
        /// tests in `Pass55FieldCarryTests` pin the behavior too.
        func with(
            id: String? = nil, userId: String? = nil, loggedAt: Date? = nil
        ) -> Entry {
            Entry(
                id: id ?? self.id,
                userId: userId ?? self.userId,
                loggedAt: loggedAt ?? self.loggedAt,
                kcal: kcal, protein: protein, carbs: carbs, fat: fat,
                fiber: fiber, sugar: sugar, sodiumMg: sodiumMg,
                satFatG: satFatG, title: title, items: items,
                source: source, itemsDetail: itemsDetail,
                corrections: corrections, edits: edits, barcode: barcode
            )
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
            sodiumMg = (try? c.decode(Double.self, forKey: .sodiumMg)) ?? 0
            satFatG = (try? c.decode(Double.self, forKey: .satFatG)) ?? 0
            title = (try? c.decode(String.self, forKey: .title)) ?? ""
            items = try? c.decode([String].self, forKey: .items)
            source = try? c.decode(String.self, forKey: .source)
            itemsDetail = try? c.decode([ItemDetail].self, forKey: .itemsDetail)
            corrections = try? c.decode([String].self, forKey: .corrections)
            edits = try? c.decode([String].self, forKey: .edits)
            barcode = try? c.decode(String.self, forKey: .barcode)
        }

        enum CodingKeys: String, CodingKey {
            case id, userId, loggedAt, kcal, protein, carbs, fat, fiber, sugar,
                 sodiumMg, satFatG, title, items, source, itemsDetail, corrections,
                 edits, barcode
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
        /// v9 P5 — the water-weight mechanisms ride the detail too
        /// (nil = not measured for this ingredient; decoder-tolerant
        /// for pre-P5 rows).
        public var sodiumMg: Double? = nil
        public var satFatG: Double? = nil
        /// p61 — fiber + sugar join the detail so a repaired plate can
        /// re-derive them from its parts instead of scaling a plate
        /// aggregate (nil = not measured; decoder-tolerant for every
        /// row written before this field).
        public var fiberG: Double? = nil
        public var sugarG: Double? = nil

        public init(
            name: String, portionG: Double, kcal: Double,
            protein: Double, carbs: Double, fat: Double,
            sodiumMg: Double? = nil, satFatG: Double? = nil,
            fiberG: Double? = nil, sugarG: Double? = nil
        ) {
            self.name = name
            self.portionG = portionG
            self.kcal = kcal
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.sodiumMg = sodiumMg
            self.satFatG = satFatG
            self.fiberG = fiberG
            self.sugarG = sugarG
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
        /// v1.1.5 — sugar now rides the cloud row too (food_logs.sugar_g).
        /// Defaulted so any caller predating the field still compiles;
        /// cloud rows written before the column existed hydrate as 0.
        public var sugar: Double = 0
        /// v9 P5 — sodium/sat-fat ride the cloud row
        /// (food_logs.sodium_mg / .saturated_fat_g, additive
        /// migration) and the per-ingredient detail rides the
        /// payload jsonb — a reinstall no longer loses the ledger.
        public var sodiumMg: Double = 0
        public var satFatG: Double = 0
        public var itemsDetail: [ItemDetail]? = nil
        /// v25 E4 — corrections ride the payload jsonb (zero-migration).
        public var corrections: [String]? = nil
        /// p53 — hand edits + the barcode key ride the payload jsonb too.
        public var edits: [String]? = nil
        public var barcode: String? = nil
        public let title: String
        public let source: String?

        public init(
            id: String, userId: String, loggedAt: Date, kcal: Double,
            protein: Double, carbs: Double, fat: Double, fiber: Double,
            sugar: Double = 0, sodiumMg: Double = 0, satFatG: Double = 0,
            itemsDetail: [ItemDetail]? = nil,
            corrections: [String]? = nil,
            edits: [String]? = nil,
            barcode: String? = nil,
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
            self.sugar = sugar
            self.sodiumMg = sodiumMg
            self.satFatG = satFatG
            self.itemsDetail = itemsDetail
            self.corrections = corrections
            self.edits = edits
            self.barcode = barcode
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
        let uid = userId.lowercased()
        return inMemoryEntries
            .filter { $0.userId.lowercased() == uid }
            .map {
                SyncableEntry(
                    id: $0.id, userId: $0.userId, loggedAt: $0.loggedAt,
                    kcal: $0.kcal, protein: $0.protein, carbs: $0.carbs,
                    fat: $0.fat, fiber: $0.fiber, sugar: $0.sugar,
                    sodiumMg: $0.sodiumMg, satFatG: $0.satFatG,
                    itemsDetail: $0.itemsDetail,
                    corrections: $0.corrections,
                    edits: $0.edits,
                    barcode: $0.barcode,
                    title: $0.title, source: $0.source
                )
            }
    }

    /// Merge server rows into the local store. Insert-only by id —
    /// local edits never get clobbered, replays are no-ops. Fires
    /// changeNotifier once when anything new landed.
    ///
    /// The id compare is case-insensitive: Postgres normalizes uuid
    /// columns to lowercase while locally-minted ids are uppercase
    /// (UUID().uuidString), so a case-sensitive compare treated every
    /// hydrated row as "new" and re-inserted a photo-less lowercase
    /// twin of each local entry on every re-login.
    public static func mergeRemote(_ remote: [SyncableEntry]) {
        hydrateIfNeeded()
        let localIds = Set(inMemoryEntries.map { $0.id.lowercased() })
        let fresh = remote.filter { !localIds.contains($0.id.lowercased()) }
        guard !fresh.isEmpty else { return }
        for r in fresh {
            let entry = Entry(
                id: r.id, userId: r.userId, loggedAt: r.loggedAt,
                kcal: r.kcal, protein: r.protein, carbs: r.carbs,
                fat: r.fat, fiber: r.fiber, sugar: r.sugar,
                sodiumMg: r.sodiumMg, satFatG: r.satFatG,
                title: r.title,
                // Pass 51 — the ingredient-name list cannot cross the
                // wire (SyncableEntry never carried it), but the
                // per-ingredient ledger does and holds the SAME names:
                // derive, don't lose. A row with no detail keeps its
                // honest absence.
                items: r.itemsDetail.map { $0.map(\.name) },
                source: r.source,
                itemsDetail: r.itemsDetail,
                corrections: r.corrections,
                edits: r.edits,
                barcode: r.barcode
            )
            inMemoryEntries.append(entry)
            appendToStore(entry)
        }
        inMemoryEntries.sort { $0.loggedAt < $1.loggedAt }
        changeNotifier.send(())
    }

    #if DEBUG
    /// QA-only: append a fully-specified local entry (including sugar +
    /// itemsDetail, which the cloud SyncableEntry doesn't carry) so the
    /// sugar surfaces can be audited without a real scan.
    public static func debugSeed(
        id: String, userId: String, loggedAt: Date, kcal: Double,
        protein: Double, carbs: Double, fat: Double, fiber: Double,
        sugar: Double, sodiumMg: Double = 0, title: String, source: String?,
        itemsDetail: [ItemDetail]? = nil,
        corrections: [String]? = nil,
        edits: [String]? = nil,
        barcode: String? = nil
    ) {
        hydrateIfNeeded()
        guard !inMemoryEntries.contains(where: {
            $0.id.lowercased() == id.lowercased()
        }) else { return }
        let entry = Entry(
            id: id, userId: userId, loggedAt: loggedAt, kcal: kcal,
            protein: protein, carbs: carbs, fat: fat, fiber: fiber,
            sugar: sugar, sodiumMg: sodiumMg, title: title, source: source,
            itemsDetail: itemsDetail, corrections: corrections,
            edits: edits, barcode: barcode
        )
        inMemoryEntries.append(entry)
        appendToStore(entry)
        inMemoryEntries.sort { $0.loggedAt < $1.loggedAt }
        changeNotifier.send(())
    }

    /// Test seam — point the JSONL store at a scratch location and drop
    /// all in-memory state so unit tests never read or write the real
    /// journal in Application Support. Pass nil to restore the default.
    static func debugResetStore(to url: URL?) {
        storeURLOverride = url
        inMemoryEntries = []
        didHydrate = false
    }

    private static var storeURLOverride: URL?
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
        /// v9 P5 — the water-weight mechanisms on the public surface
        /// (0 = not collected, silent per the provenance rule).
        public var sodiumMg: Double = 0
        public var satFatG: Double = 0
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
        /// HER OWN SENTENCES, back out of the record.
        ///
        /// E4 shipped "corrections PERSIST": every fix-with-words line
        /// is written to the JSONL and rides `food_logs.payload` to the
        /// cloud and back. Only the WRITE half shipped. This DTO — the
        /// one every food surface reads through — had no field for them,
        /// so nothing in the product could ever show a correction again.
        /// The single reader was `priorObservations`, which reduces them
        /// to a `Bool`.
        ///
        /// The effect: she tells jeni "that was a large, not a medium",
        /// jeni agrees and files it, and tomorrow the plate says "read
        /// from your photo · ranges, not exact" with no trace that she
        /// touched it. The most valuable thing in a food record — the
        /// user's own correction — was the one thing the record could
        /// not read back.
        ///
        /// nil for untouched plates and for every entry written before
        /// E4. No migration: the bytes have been on disk and in the
        /// cloud row since E4.
        public let corrections: [String]?

        /// p53 — DELIBERATE hand edits, their own channel beside the
        /// spoken fixes ("greek yogurt → 140 kcal", "removed granola").
        /// nil = untouched by hand.
        public let edits: [String]?

        /// p53 — the package code when this plate came through the
        /// barcode door. The verify-once key.
        public let barcode: String?

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
            sodiumMg: Double = 0,
            satFatG: Double = 0,
            items: [String]? = nil,
            source: String?,
            itemsDetail: [ItemDetail]? = nil,
            corrections: [String]? = nil,
            edits: [String]? = nil,
            barcode: String? = nil
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
            self.sodiumMg = sodiumMg
            self.satFatG = satFatG
            self.items = items
            self.source = source
            self.itemsDetail = itemsDetail
            self.corrections = corrections
            self.edits = edits
            self.barcode = barcode
        }

        /// True when she changed this plate's numbers with her own words
        /// before filing it. The one signal on this DTO that comes from
        /// the user rather than from a model or a database.
        public var wasCorrected: Bool { !(corrections ?? []).isEmpty }

        /// p53 — true when she touched this plate's numbers AT ALL
        /// (spoken fix or hand edit). The usuals rail ranks verified
        /// entries as her strongest truth.
        public var wasVerified: Bool {
            wasCorrected || !(edits ?? []).isEmpty
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
        #if DEBUG
        if let storeURLOverride { return storeURLOverride }
        #endif
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
        // De-dupe by id — case-insensitive, keeping the FIRST
        // occurrence. Same-id replays from a partially-failed rewrite
        // are byte-identical, so first-vs-last doesn't matter there;
        // what does matter is self-healing the pre-fix mergeRemote bug
        // that appended a photo-less lowercase twin of each local
        // entry on re-login. The first occurrence is the original
        // local entry (richer: itemsDetail + sugar + the entry id the
        // on-disk photo is keyed by); the twin drops here and the next
        // rewriteStore drops its JSONL line too.
        var byId: [String: Entry] = [:]
        for entry in loaded where byId[entry.id.lowercased()] == nil {
            byId[entry.id.lowercased()] = entry
        }
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

    /// Insert a CapturedFood. Returns the new entry's id (telemetry +
    /// photo keying).
    @discardableResult
    public static func persist(
        _ food: CapturedFood,
        userId: String,
        photo: UIImage? = nil
    ) throws -> String {

        // p61 — the record holds the number the reading showed her.
        // This used to store the model band's MIDPOINT whenever a band
        // existed, and `total_kcal_low`/`total_kcal_high` are REQUIRED
        // fields of the vision schema, so that was every photographed
        // plate: she agreed to one number and the product kept another,
        // in Home's dial, the day totals, Apple Health, the coach's
        // envelope and the clinician packet. `recordedKcal` is now the
        // one rule and the reading reads the same one.
        let plateKcal = food.recordedKcal

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
        // v9 P5 — the water-weight mechanisms, summed the same honest
        // way (contributing items add; missing items add nothing).
        let plateSodium  = food.items.compactMap { $0.sodiumMg }.reduce(0, +)
        let plateSatFat  = food.items.compactMap { $0.saturatedFatG }.reduce(0, +)

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
        } else if food.source == .restaurant {
            // E8.1 — this branch tested `.imOut`, a value nothing has ever
            // written (the dispatcher builds `.restaurantEstimate`), so the
            // restaurant path fell through to "scanned plate" for its whole
            // life. One vocabulary makes the test correct by construction.
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
                    fat: item.fatG ?? 0,
                    sodiumMg: item.sodiumMg,
                    satFatG: item.saturatedFatG,
                    fiberG: item.fiberG,
                    sugarG: item.sugarG
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
            sodiumMg: plateSodium,
            satFatG: plateSatFat,
            title: title,
            items: plateItems,
            source: food.source.rawValue,
            itemsDetail: detail,
            corrections: food.appliedCorrections.isEmpty ? nil : food.appliedCorrections,
            edits: food.editNotes.isEmpty ? nil : food.editNotes,
            // A barcode-prefixed item id only ever comes from the
            // barcode reader or a barcode usual re-served — either
            // way the code is true, whatever door word the plate
            // wears, so the verify-once chain compounds across
            // relogs.
            barcode: food.items.compactMap {
                $0.id.hasPrefix("barcode-")
                    ? String($0.id.dropFirst("barcode-".count)) : nil
            }.first
        )
        inMemoryEntries.append(entry)
        appendToStore(entry)

        // v1.1 Becoming filmstrip — persist a small on-device thumbnail
        // keyed by the entry id. Forward-only; nil for quick-add /
        // dining-out paths.
        //
        // Release audit 2026-08-08: the Settings › privacy "photo
        // retention" control finally has its reader — an explicit
        // "discard" skips the thumbnail entirely, and with it the
        // cloud-upload hook FoodPhotoStore.save fires. Any other value
        // (unset, "keep", the retired "keep30") keeps today's behavior.
        let retention = UserDefaults.standard.string(forKey: "foodPhotoRetention")
        if let photo, retention != "discard" {
            FoodPhotoStore.save(photo, entryId: entryId)
        }

        changeNotifier.send(())

        // Cloud sync hook — fire-and-forget upsert to food_logs.
        onEntryPersisted?(SyncableEntry(
            id: entry.id, userId: entry.userId, loggedAt: entry.loggedAt,
            kcal: entry.kcal, protein: entry.protein, carbs: entry.carbs,
            fat: entry.fat, fiber: entry.fiber, sugar: entry.sugar,
            sodiumMg: entry.sodiumMg, satFatG: entry.satFatG,
            itemsDetail: entry.itemsDetail,
            corrections: entry.corrections,
            edits: entry.edits,
            barcode: entry.barcode,
            title: entry.title, source: entry.source
        ))

        // Apple Health write hook. The main app registers a closure at
        // launch that reads the user's "foodHealthKitWriteEnabled"
        // toggle, confirms HK auth, and saves an HKQuantitySample.
        // No-op if toggle off or write auth not granted. PlankFood
        // stays HealthKit-blind.
        FoodHealthKitWriter.writeIfRegistered(kcal: plateKcal, at: loggedAt)

        return entryId
    }

    /// v25 E4 — the corrections flywheel's feed: her record as
    /// PlatePriors observations. Only rows that carry a correction
    /// can become priors; the engine enforces the rest of the law.
    public static func priorObservations(userId: String) -> [PlatePriors.Observation] {
        hydrateIfNeeded()
        let uid = userId.lowercased()
        return inMemoryEntries
            .filter { $0.userId.lowercased() == uid }
            .map {
                PlatePriors.Observation(
                    title: $0.title,
                    kcal: $0.kcal,
                    proteinG: $0.protein,
                    corrected: !($0.corrections ?? []).isEmpty,
                    at: $0.loggedAt
                )
            }
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

        // Case-insensitive uuid compare, same as allEntries(userId:) —
        // hydrated rows carry Postgres-lowercase user_ids.
        let uid = userId.lowercased()
        let userEntries = inMemoryEntries.filter { $0.userId.lowercased() == uid }

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
    /// Days with no logs return 0.
    public static func last7DaysKcal(userId: String) -> [(date: Date, kcal: Double)] {
        hydrateIfNeeded()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date.now)
        let uid = userId.lowercased()
        let userEntries = inMemoryEntries.filter { $0.userId.lowercased() == uid }

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
                    sodiumMg: $0.sodiumMg,
                    satFatG: $0.satFatG,
                    items: $0.items,
                    source: $0.source,
                    itemsDetail: $0.itemsDetail,
                    corrections: $0.corrections,
                    edits: $0.edits,
                    barcode: $0.barcode
                )
            }
    }

    /// 2026-07-25 photo cloud backup — entries in the journal with no
    /// thumbnail on THIS device, newest first. The app layer walks this
    /// after hydrate and downloads each entry's photo from the user's
    /// private cloud space (FoodPhotoSyncService.hydrateMissingPhotos).
    /// Quick-add / dining-out / relog entries never had a photo, so a
    /// missing remote object is the caller's expected no-op, not an
    /// error.
    public static func entriesMissingPhoto(userId: String) -> [FoodLogEntry] {
        allEntries(userId: userId)
            .filter { !FoodPhotoStore.hasPhoto(entryId: $0.id) }
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
    ///
    /// E8.1 — the new entry's door is `again`, not the original's door.
    /// It has to be: the copied plate carries no photograph, so
    /// inheriting `photo` made the record promise a picture that was
    /// deliberately not saved, and the plate page said so out loud.
    /// This is also the only way `food_log_saved{entry_method}` can
    /// count the again door, which E4 shipped as the cheapest path to a
    /// kept log.
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
            // 2026-07-25 — sugar rides the relog like every other macro
            // (it was silently zeroed before, same bug family as the
            // reattribution drop).
            sugar: source.sugar,
            sodiumMg: source.sodiumMg,
            satFatG: source.satFatG,
            title: source.title,
            items: source.items,
            source: EntryMethod.again.rawValue,
            itemsDetail: source.itemsDetail,
            // THE RECORD MUST COMPOUND, NOT DECAY. Every other field
            // rides a relog; corrections were dropped, which had two
            // costs. The plate's own page lost the fact that she had
            // fixed these numbers, and `priorObservations` read the
            // relogged row as `corrected: false` — so relogging a dish
            // she had taught jeni about diluted the record with an
            // uncorrected twin of her own correction. The numbers being
            // copied ARE the corrected numbers; saying so is the honest
            // read, and it is what keeps the flywheel turning on the
            // cheapest door in the product.
            corrections: source.corrections,
            // p53 — hand edits and the barcode key compound the same
            // way (the relogged numbers ARE the edited numbers).
            edits: source.edits,
            barcode: source.barcode
        )
        inMemoryEntries.append(entry)
        appendToStore(entry)
        changeNotifier.send(())
        onEntryPersisted?(SyncableEntry(
            id: entry.id, userId: entry.userId, loggedAt: entry.loggedAt,
            kcal: entry.kcal, protein: entry.protein, carbs: entry.carbs,
            fat: entry.fat, fiber: entry.fiber, sugar: entry.sugar,
            sodiumMg: entry.sodiumMg, satFatG: entry.satFatG,
            itemsDetail: entry.itemsDetail,
            corrections: entry.corrections,
            edits: entry.edits,
            barcode: entry.barcode,
            title: entry.title, source: entry.source
        ))
        FoodHealthKitWriter.writeIfRegistered(kcal: entry.kcal, at: entry.loggedAt)
        // E8.1 — `food_log_saved` fires HERE, not at the call sites.
        // Three surfaces relog (the plate page, the book, and the
        // chooser's again door) and only two of them ever fired it: the
        // chooser — E4's headline "≤3 taps cold to a kept log", and the
        // one a new payer is most likely to use — recorded a
        // `food_relog_used` and no save at all, so every "did she log
        // food" funnel undercounted the cheapest door in the product.
        // A plate cannot land in the record without this line now.
        FoodAnalytics.track(.logSaved, properties: [
            "items_count": entry.itemsDetail?.count ?? entry.items?.count ?? 0,
            "source": EntryMethod.again.rawValue,
            "entry_method": EntryMethod.again.rawValue,
        ])
        FoodAnalytics.firstLogSavedIfNeeded()
    }

    /// Move one plate to the day she actually ate it.
    ///
    /// v25 §34 — THE BACK-DATED PLATE. Every capture path stamps
    /// `Date()` at persist (`persist` above, and `relog`), so a meal
    /// could only ever land on the calendar day it was LOGGED. Two
    /// ordinary things follow from that and both were unfixable:
    ///
    ///   · a late dinner logged at 12:10am lands on tomorrow, and the
    ///     day it fed reads short by 700 kcal forever;
    ///   · a meal she remembers the next morning cannot be put where it
    ///     belongs at all.
    ///
    /// Three sessions have named "logging food to a past day" as the
    /// largest remaining boring gap and deferred it as a write-path
    /// change. This is that change at its smallest honest size: the
    /// capture pipeline is untouched — no path learns a date, no new
    /// flow, no schema — and the RECORD becomes correctable instead.
    /// Log it now, then say when.
    ///
    /// What it preserves, deliberately:
    ///   · the id — it is the same plate, so the photograph
    ///     (`FoodPhotoStore` keys on the entry id) travels with it and
    ///     the cloud row is an UPDATE, never a duplicate;
    ///   · the clock time — she ate at 9:40pm whichever calendar day we
    ///     file it under, and inventing a time would be inventing a
    ///     fact;
    ///   · every nutrient, item, correction and door.
    ///
    /// What it refuses: a future day. A plate cannot have been eaten
    /// tomorrow, and a forward-dated entry would silently subtract
    /// itself from today's total.
    ///
    /// Returns false when nothing moved, so a caller never claims a
    /// repair that did not happen.
    @discardableResult
    public static func setLoggedDay(
        id: String, to day: Date, now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        hydrateIfNeeded()
        let target = id.lowercased()
        guard let index = inMemoryEntries.firstIndex(where: {
            $0.id.lowercased() == target
        }) else { return false }
        let existing = inMemoryEntries[index]

        // Keep the clock time; move only the calendar day.
        let clock = calendar.dateComponents(
            [.hour, .minute, .second], from: existing.loggedAt
        )
        guard let moved = calendar.date(
            bySettingHour: clock.hour ?? 12,
            minute: clock.minute ?? 0,
            second: clock.second ?? 0,
            of: calendar.startOfDay(for: day)
        ) else { return false }

        // p61 — a move to TODAY whose preserved clock time hasn't
        // happened yet lands at the moment she made it. The old rule
        // refused it outright ("9pm tonight is the future"), which was
        // the commonest re-date there is — yesterday's dinner moved to
        // today this afternoon — and the one caller discarded the Bool
        // and claimed the repair anyway. Future DAYS stay refused.
        let effective: Date
        if moved <= now {
            effective = moved
        } else if calendar.isDate(moved, inSameDayAs: now) {
            effective = now
        } else {
            return false
        }
        guard !calendar.isDate(effective, inSameDayAs: existing.loggedAt) else { return false }

        // p55 — the hand-written re-init that lived here became
        // instance #7 of the defaulted-init drop family (it predated
        // `edits` + `barcode`, so redating a plate erased her hand
        // edits and the verify-once key, locally and — via the
        // whole-row upsert — in the cloud copy). `with(...)` carries
        // every unnamed field by construction.
        let entry = existing.with(loggedAt: effective)
        inMemoryEntries[index] = entry
        inMemoryEntries.sort { $0.loggedAt < $1.loggedAt }
        rewriteStore()
        changeNotifier.send(())

        // The cloud row is keyed by id, so this is an UPDATE of
        // `logged_at` — no migration, no second row, and the
        // insert-only `mergeRemote` cannot resurrect the old date
        // because it skips ids it already holds.
        onEntryPersisted?(SyncableEntry(
            id: entry.id, userId: entry.userId, loggedAt: entry.loggedAt,
            kcal: entry.kcal, protein: entry.protein, carbs: entry.carbs,
            fat: entry.fat, fiber: entry.fiber, sugar: entry.sugar,
            sodiumMg: entry.sodiumMg, satFatG: entry.satFatG,
            itemsDetail: entry.itemsDetail,
            corrections: entry.corrections,
            edits: entry.edits,
            barcode: entry.barcode,
            title: entry.title, source: entry.source
        ))
        // NOT re-written to Apple Health. `FoodHealthKitWriter` can only
        // add a sample, so a second write would double-count the energy
        // in Health while the first sample still sat on the old day.
        // Named in the record rather than half-done here.
        return true
    }

    // MARK: - p61: THE FILED PLATE IS CORRECTABLE

    /// Reconstruct the editable plate a filed entry describes, so the
    /// SAME editor she used at scan time can repair it after filing.
    ///
    /// Before this, "add it" was a one-way door: `PlateEditSession`,
    /// the item editor and fix-with-words were mounted only on the
    /// scan reading, and the persister's whole public mutation set was
    /// persist / relog / re-date / delete. The plate page's own copy
    /// was "off? remove this plate" — the only remedy for a wrong
    /// number was destroying the record, while the BOOK's a11y hint
    /// promised "open, fix or remove it".
    ///
    /// Entries with `itemsDetail` rebuild item-by-item. Older or
    /// cloud-restored entries (no detail) rebuild as ONE item carrying
    /// the plate's numbers — with no recorded mass, so the editor
    /// offers its direct fields and invents no portion.
    public static func repairFood(from entry: FoodLogEntry) -> CapturedFood {
        let items: [CapturedItem]
        if let detail = entry.itemsDetail, !detail.isEmpty {
            items = detail.map { d in
                CapturedItem(
                    id: UUID().uuidString,
                    name: d.name,
                    portionGrams: d.portionG,
                    portionGramsLow: d.portionG,
                    portionGramsHigh: d.portionG,
                    usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
                    confidence: nil, notes: nil,
                    kcal: d.kcal,
                    proteinG: d.protein,
                    carbsG: d.carbs,
                    fatG: d.fat,
                    fiberG: d.fiberG,
                    nutritionSource: nil,
                    sugarG: d.sugarG,
                    sodiumMg: d.sodiumMg,
                    saturatedFatG: d.satFatG
                )
            }
        } else {
            items = [CapturedItem(
                id: UUID().uuidString,
                name: entry.title.isEmpty ? "this plate" : entry.title,
                portionGrams: 0, portionGramsLow: 0, portionGramsHigh: 0,
                usdaSearchTerms: [], preparation: nil, cuisineHint: nil,
                confidence: nil, notes: nil,
                kcal: entry.kcal,
                proteinG: entry.protein,
                carbsG: entry.carbs,
                fatG: entry.fat,
                fiberG: entry.fiber > 0 ? entry.fiber : nil,
                nutritionSource: nil,
                sugarG: entry.sugar > 0 ? entry.sugar : nil,
                sodiumMg: entry.sodiumMg > 0 ? entry.sodiumMg : nil,
                saturatedFatG: entry.satFatG > 0 ? entry.satFatG : nil
            )]
        }
        var food = CapturedFood(
            items: items,
            plateType: items.count > 1 ? .mixed : .single,
            source: EntryMethod(rawValue: entry.source ?? "") ?? .unknown,
            confidence: nil, needsSecondPhoto: false, secondPhotoHint: nil,
            kcalLow: nil, kcalHigh: nil
        )
        food.appliedCorrections = entry.corrections ?? []
        food.editNotes = []
        return food
    }

    /// Apply a repaired plate back onto its entry, in place: same id
    /// (the photograph and the cloud row are keyed by it), same day,
    /// same door, her corrections intact. The numbers re-derive by the
    /// SAME rules `persist` uses — one arithmetic, two moments.
    ///
    /// Aggregates the reconstruction could not carry per-item (fiber /
    /// sugar on pre-p61 rows) scale with the plate's energy: "I ate
    /// half" halves them; an untouched plate keeps them exactly.
    ///
    /// Returns false when the entry is not on file.
    @discardableResult
    public static func updateEntry(
        id: String, with food: CapturedFood, editNotes: [String] = []
    ) -> Bool {
        hydrateIfNeeded()
        let target = id.lowercased()
        guard let index = inMemoryEntries.firstIndex(where: {
            $0.id.lowercased() == target
        }) else { return false }
        let existing = inMemoryEntries[index]

        let plateKcal = food.recordedKcal
        let protein = food.items.compactMap { $0.proteinG }.reduce(0, +)
        let carbs   = food.items.compactMap { $0.carbsG }.reduce(0, +)
        let fat     = food.items.compactMap { $0.fatG }.reduce(0, +)

        // A field measured per-item re-derives from the parts; a field
        // the parts never carried scales with the energy edit.
        let ratio = existing.kcal > 0 ? plateKcal / existing.kcal : 1
        func aggregate(
            _ kp: KeyPath<CapturedItem, Double?>, kept: Double
        ) -> Double {
            let measured = food.items.compactMap { $0[keyPath: kp] }
            if !measured.isEmpty { return measured.reduce(0, +) }
            return kept > 0 ? kept * ratio : kept
        }
        let fiber   = aggregate(\.fiberG, kept: existing.fiber)
        let sugar   = aggregate(\.sugarG, kept: existing.sugar)
        let sodium  = aggregate(\.sodiumMg, kept: existing.sodiumMg)
        let satFat  = aggregate(\.saturatedFatG, kept: existing.satFatG)

        // Title + item names re-derive exactly as `persist` derives
        // them, so a renamed or removed item renames the row.
        let title: String
        if let first = food.items.first {
            let more = food.items.count - 1
            title = more > 0 ? "\(first.name) + \(more) more" : first.name
        } else {
            title = existing.title
        }
        let names: [String]? = {
            let list = food.items
                .map { $0.name.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return list.isEmpty ? nil : list
        }()
        let detail: [ItemDetail]? = {
            let rows = food.items.compactMap { item -> ItemDetail? in
                guard !item.name.trimmingCharacters(in: .whitespaces).isEmpty
                else { return nil }
                return ItemDetail(
                    name: item.name, portionG: item.portionGrams,
                    kcal: item.kcal ?? 0, protein: item.proteinG ?? 0,
                    carbs: item.carbsG ?? 0, fat: item.fatG ?? 0,
                    sodiumMg: item.sodiumMg, satFatG: item.saturatedFatG,
                    fiberG: item.fiberG, sugarG: item.sugarG
                )
            }
            return rows.isEmpty ? nil : rows
        }()

        let mergedEdits: [String]? = {
            let joined = (existing.edits ?? []) + editNotes + food.editNotes
            return joined.isEmpty ? nil : joined
        }()

        let entry = Entry(
            id: existing.id,
            userId: existing.userId,
            loggedAt: existing.loggedAt,
            kcal: plateKcal,
            protein: protein, carbs: carbs, fat: fat,
            fiber: fiber, sugar: sugar,
            sodiumMg: sodium, satFatG: satFat,
            title: title,
            items: names ?? existing.items,
            source: existing.source,
            itemsDetail: detail ?? existing.itemsDetail,
            corrections: existing.corrections,
            edits: mergedEdits,
            barcode: existing.barcode
        )
        inMemoryEntries[index] = entry
        rewriteStore()
        changeNotifier.send(())

        // The cloud row updates in place — keyed by id, so no second
        // row, and the insert-only hydrate cannot resurrect the old
        // numbers.
        onEntryPersisted?(SyncableEntry(
            id: entry.id, userId: entry.userId, loggedAt: entry.loggedAt,
            kcal: entry.kcal, protein: entry.protein, carbs: entry.carbs,
            fat: entry.fat, fiber: entry.fiber, sugar: entry.sugar,
            sodiumMg: entry.sodiumMg, satFatG: entry.satFatG,
            itemsDetail: entry.itemsDetail,
            corrections: entry.corrections,
            edits: entry.edits,
            barcode: entry.barcode,
            title: entry.title, source: entry.source
        ))
        // NOT re-written to Apple Health — the writer can only add a
        // sample; the original sample stands (same stance as re-date).
        return true
    }

    /// v1.0.9 D3.B — remove a single entry by id. Used by the
    /// timeline's swipe-to-delete affordance. Fires changeNotifier
    /// so HomeFoodCard's bars refresh after a delete. Silent no-op
    /// if the id doesn't match (user could have force-quit between
    /// list render and tap).
    public static func deleteEntry(id: String) {
        hydrateIfNeeded()
        let target = id.lowercased()
        guard let removed = inMemoryEntries.first(where: {
            $0.id.lowercased() == target
        }) else { return }
        inMemoryEntries.removeAll { $0.id.lowercased() == target }
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
    ///
    /// v25 §42 — `preservingIds` is the SERVER's answer, not a
    /// preference. `complete_account_handoff(mode: 'move')` changes
    /// `food_logs.user_id` and KEEPS `food_logs.id`, so after it the
    /// fresh-id rule below is inverted: `pushLocalFoodEntriesMissingFromServer`
    /// diffs by id on every launch, so a fresh id would make every plate
    /// she owns look absent from the server and upload a duplicate of
    /// her entire journal. Defaults to the legacy behaviour, so every
    /// path that has not spoken to the server is byte-for-byte unchanged.
    public static func reattributeEntries(
        from oldId: String, to newId: String, preservingIds: Bool = false
    ) {
        hydrateIfNeeded()
        let oldUid = oldId.lowercased()
        guard oldUid != newId.lowercased(),
              inMemoryEntries.contains(where: { $0.userId.lowercased() == oldUid })
        else { return }
        inMemoryEntries = inMemoryEntries.map { e in
            guard e.userId.lowercased() == oldUid else { return e }
            // The server already owns this row under this id; only the
            // owner changed. The photo is keyed by entry id, so keeping
            // the id also means the thumbnail does not have to move.
            if preservingIds {
                // p55 — instance #8 of the drop family lived here
                // (`edits` + `barcode` missing). One re-init now.
                return e.with(userId: newId)
            }
            // Fresh id, not just a new userId: the cloud row already exists
            // under the old uid, so a same-id upsert is an UPDATE that RLS
            // rejects (auth.uid() != the row's old user_id → 42501, silently
            // dropped). A new id makes the launch reconcile push a clean
            // INSERT the signed-in account owns, so the entry survives the
            // next reinstall. The local thumbnail is keyed by entry id, so
            // it moves with the re-key. Every field carries through —
            // sugar + itemsDetail were silently dropped here before
            // 2026-07-25 (a sign-in merge stripped the detail ledger).
            let freshId = UUID().uuidString
            FoodPhotoStore.rekey(from: e.id, to: freshId)
            // Release audit 2026-08-08: sodiumMg + satFatG (v9 P5
            // fields) were missing from this init — the exact bug
            // family the comment above memorializes — so a sign-in
            // merge zeroed every carried plate's sodium and saturated
            // fat.
            //
            // 2026-08-12: `corrections` was missing too — the THIRD
            // time a field added to `Entry` was forgotten at this one
            // call site.
            //
            // p55 (2026-08-20): and then `edits` + `barcode` — the
            // FOURTH time, at the one call site whose comment said
            // "every field is now named here on purpose". A list a
            // human maintains drifts; `with(...)` is the one re-init
            // and carries unnamed fields by construction.
            return e.with(id: freshId, userId: newId)
        }
        rewriteStore()
        changeNotifier.send(())
    }

    /// Wipe every entry for a user — the delete-account path. Cloud
    /// rows are removed by the server-side cascade; this only clears
    /// the device copy (no per-entry delete hooks fired).
    /// v25 E7 — QA only. The user-scoped wipe could not clear entries
    /// written under an earlier launch's anonymous id, so the "empty
    /// record" faces stayed unfilmable across three eras. Behind
    /// `--uitest-wipe-food` on a DEBUG build the honest scope is the
    /// device's whole food store.
    public static func deleteAllEntriesForAllUsers() {
        hydrateIfNeeded()
        let removed = inMemoryEntries
        guard !removed.isEmpty else { return }
        inMemoryEntries.removeAll()
        rewriteStore()
        for entry in removed { FoodPhotoStore.delete(entryId: entry.id) }
        changeNotifier.send(())
    }

    public static func deleteAllEntries(userId: String) {
        hydrateIfNeeded()
        let before = inMemoryEntries.count
        let uid = userId.lowercased()
        // Capture the entries being removed so we can wipe their
        // photos too — privacy invariant: delete-account leaves zero
        // user content on disk.
        let removed = inMemoryEntries.filter { $0.userId.lowercased() == uid }
        inMemoryEntries.removeAll { $0.userId.lowercased() == uid }
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
