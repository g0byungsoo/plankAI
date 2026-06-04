import Foundation

// MARK: - NutritionCache
//
// Hot-tier cache for NutritionLookupResult. Uses NSCache (thread-safe,
// auto-evicts under memory pressure). Per architect: SwiftData warm
// tier deferred to v1.0.8 once telemetry shows the warm-up cost
// matters — at 80 paid users + 200 scans/day the in-session NSCache
// is enough.
//
// Key convention (GLOBAL, not per-user — per architect's lock-in
// notes): when we eventually add SwiftData persistence + migrate
// some users to the Edge Function variant, the server cache uses
// the same keys so we can warm it from the exported NSCache.
//
//   usda_fdc:<fdcId>
//   off:<barcode-or-search-hash>
//   pantry:<slug>
//
// Read returns immediately even if stale (the call site handles the
// stale-while-revalidate refresh in the background — the
// NutritionLookupResult.isStale check + a Task to re-fetch).

public final class NutritionCache: @unchecked Sendable {

    private let store = NSCache<NSString, Box>()

    public init(countLimit: Int = 1024) {
        store.countLimit = countLimit
    }

    public func get(_ key: String) -> NutritionLookupResult? {
        store.object(forKey: key as NSString)?.value
    }

    public func set(_ key: String, _ value: NutritionLookupResult) {
        store.setObject(Box(value: value), forKey: key as NSString)
    }

    public func remove(_ key: String) {
        store.removeObject(forKey: key as NSString)
    }

    public func clear() {
        store.removeAllObjects()
    }

    // MARK: - Key helpers

    public static func usdaKey(fdcId: Int) -> String {
        "usda_fdc:\(fdcId)"
    }

    public static func offKey(barcodeOrHash: String) -> String {
        "off:\(barcodeOrHash)"
    }

    public static func pantryKey(slug: String) -> String {
        "pantry:\(slug)"
    }
}

// MARK: - Box

/// NSCache requires NSObject keys + values. Wrapping the Swift struct.
private final class Box: NSObject {
    let value: NutritionLookupResult
    init(value: NutritionLookupResult) { self.value = value }
}
