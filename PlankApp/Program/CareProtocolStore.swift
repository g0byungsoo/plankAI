import Foundation

// MARK: - CareProtocolStore
//
// S2 — protocol served (docs/app_v8/03_ARCHITECTURE.md §5). The
// clinical config hydrates from the live `protocols` row — the
// org-null tenant reads "jenifit.default"; a clinic later is a
// DIFFERENT ROW through this same resolver, which is the entire
// white-label mechanism. The bundled `.default` is the permanent
// fallback; a served payload applies only when it decodes AND
// passes the clinical sanity gate whole (never partially, never
// blindly). The last sane payload caches for cold starts.
// Failures are silent: the app always has a protocol.
//
// Shape note: an enum service with @MainActor statics (the house
// idiom — TargetsService / RegimenService / ObservationStore),
// deliberately NOT a class: instance deinit of isolated classes
// routes through the concurrency runtime's deinit-on-executor
// back-deploy shim, which aborts in libmalloc on the current sim
// runtime (caught by the dealloc canary while this was a class).
// No instances → no deinit → the crash class is structurally gone.

@MainActor
enum CareProtocolStore {

    private(set) static var current: CareProtocol = .default

    private static let cacheKey = "careProtocol.served.v1"
    private static var cacheLoaded = false

    /// Cold-start warm-up: adopt the last SANE served payload
    /// before any network. Idempotent.
    static func bootstrapFromCacheIfNeeded(defaults: UserDefaults = .standard) {
        guard !cacheLoaded else { return }
        cacheLoaded = true
        guard let data = defaults.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(CareProtocol.self, from: data),
              cached.isClinicallySane
        else { return }
        current = cached
    }

    /// Apply a served protocol — the sanity gate is the whole
    /// contract. Returns whether it took effect.
    @discardableResult
    static func apply(
        _ served: CareProtocol, defaults: UserDefaults = .standard
    ) -> Bool {
        guard served.isClinicallySane else { return false }
        current = served
        if let data = try? JSONEncoder().encode(served) {
            defaults.set(data, forKey: cacheKey)
        }
        return true
    }

    /// Parse the PostgREST response for `select payload` rows and
    /// apply the first sane payload. Split from the network hop so
    /// tests exercise the full decode → gate → cache path.
    @discardableResult
    static func applyServerResponse(
        _ data: Data, defaults: UserDefaults = .standard
    ) -> Bool {
        struct Row: Decodable { let payload: CareProtocol }
        guard let rows = try? JSONDecoder().decode([Row].self, from: data),
              let served = rows.first?.payload
        else { return false }
        return apply(served, defaults: defaults)
    }

    /// Refresh from the live row (fire-and-forget from the hydrate
    /// pass; graceful on any failure).
    static func hydrate() async {
        bootstrapFromCacheIfNeeded()
        guard let data = await AppSync.shared.fetchServedProtocolData(
            id: CareProtocol.default.id
        ) else { return }
        applyServerResponse(data)
    }

    /// Tests only: restore the bundled default + re-arm the cache
    /// bootstrap.
    static func resetForTesting() {
        current = .default
        cacheLoaded = false
    }
}
