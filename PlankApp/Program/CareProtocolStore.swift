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
    ///
    /// S4: a clinician assignment redirects WHICH row resolves — the
    /// same white-label mechanism S2 built, now patient-directed. If
    /// an active assignment names an org protocol, that row leads;
    /// otherwise the org-null default. Either way the served payload
    /// still passes the whole-or-reject sanity gate; a malformed or
    /// unsafe assignment changes nothing and the last sane plan
    /// stands (S2 law, untouched).
    static func hydrate(userId: String = "") async {
        bootstrapFromCacheIfNeeded()
        var protocolId = CareProtocol.default.id
        if !userId.isEmpty,
           let assigned = await AppSync.shared.fetchAssignedProtocolId(userId: userId) {
            protocolId = assigned
        }
        guard let data = await AppSync.shared.fetchServedProtocolData(id: protocolId)
        else { return }
        // If an assigned row fails to decode/validate, fall back to
        // the default so a bad assignment can never strand her.
        if !applyServerResponse(data), protocolId != CareProtocol.default.id,
           let fallback = await AppSync.shared.fetchServedProtocolData(id: CareProtocol.default.id) {
            applyServerResponse(fallback)
        }
    }

    /// v25 §44 — **AN IDENTITY SWEEP MUST FORGET THE CLINIC TOO.**
    ///
    /// `careProtocol.served.v1` is a device-scoped cache of the last
    /// sane config a CLINIC served to ONE account, and `current` is a
    /// process-lifetime static that `bootstrapFromCacheIfNeeded` adopts
    /// at cold start before any network call. Neither was in any sweep.
    ///
    /// So after account A (a clinic patient) signed out, account B's
    /// protein floor, pace ceiling and hydration aim were composed from
    /// a protocol B's clinic never served — the sentence `41` §2 wrote
    /// for care-team regimen rows, one layer down — and it survived
    /// "delete my account" on disk. Online it healed at the first
    /// `hydrate`; offline it never healed at all.
    ///
    /// The bundled `.default` is the only honest state for an identity
    /// this device knows nothing about yet, and `hydrate` re-resolves
    /// the right row (org-null default, or B's own assignment) moments
    /// later. Called from `AppSync.clearOnboardingUserDefaults`, which
    /// is sign-out, account switch AND account deletion.
    static func forgetServedProtocol(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: cacheKey)
        current = .default
        cacheLoaded = false
    }

    /// Tests only: restore the bundled default + re-arm the cache
    /// bootstrap.
    static func resetForTesting() {
        current = .default
        cacheLoaded = false
    }
}
