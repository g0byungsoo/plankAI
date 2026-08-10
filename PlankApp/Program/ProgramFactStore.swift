import Foundation
import SwiftData
import PlankSync

// MARK: - ProgramFactStore (E1 THE SPINE — the one writer)
//
// docs/app_v25/05_E1_SPINE.md §1. The RegimenService chokepoint law
// generalized to program facts: one active chain per (kind,
// authority); same-day coalescing; supersede-never-mutate; iOS never
// authors prescriptions; recommendations exist only once accepted.
// Engines read heads through here — never raw rows.
//
// Transition law (05_E1_SPINE §1): every write ALSO writes the
// resolved head through to the v4 legacy knobs
// (plan.proteinAdjustG / plan.sessionsAdjust / plan.weighSoftened)
// so engines not yet converted this era keep reading truth. The
// knobs die in a later era.

@MainActor
enum ProgramFactStore {

    // MARK: - Write chokepoint

    @discardableResult
    static func apply(
        _ kind: ProgramFactKind,
        value: ProgramFactValue,
        authority: ProgramFactAuthority,
        basis: ProgramFactBasis,
        source: String,
        acceptedAt: Date? = nil,
        userId: String,
        now: Date = .now,
        in context: ModelContext,
        legacyDefaults: UserDefaults = .standard
    ) -> ProgramFactRecord? {
        guard !userId.isEmpty else { return nil }

        // S4 law: iOS never authors prescriptions — they arrive via
        // sync hydrate only.
        guard authority != .prescribed else { return nil }

        // An unaccepted recommendation is not a fact.
        if authority == .recommended, acceptedAt == nil { return nil }

        // Vocabulary + safe-band laws.
        if case .word(let w) = value {
            guard kind.isWordKind, ProgramFacts.isValidWord(w, kind: kind) else {
                return nil
            }
        }
        if case .int = value, kind.isWordKind { return nil }
        let clamped = ProgramFacts.clamped(value, kind: kind, authority: authority)

        let result: ProgramFactRecord
        if let current = activeRecord(kind, authority: authority, userId: userId, in: context) {
            if Calendar.current.isDate(current.createdAt, inSameDayAs: now) {
                // Same-day coalesce: corrections settle in place;
                // versions represent settled states.
                current.value = clamped.encoded
                current.basis = basis.rawValue
                current.source = source
                if let acceptedAt { current.acceptedAt = acceptedAt }
                current.updatedAt = now
                current.pendingUpsert = true
                result = current
            } else {
                // A settled change → version.
                current.endedAt = now
                current.endReason = "superseded"
                current.updatedAt = now
                current.pendingUpsert = true

                let next = ProgramFactRecord(
                    userId: userId,
                    kind: kind.rawValue,
                    value: clamped.encoded,
                    authority: authority.rawValue,
                    basis: basis.rawValue,
                    source: source,
                    previousFactId: current.id,
                    acceptedAt: acceptedAt
                )
                next.createdAt = now
                next.updatedAt = now
                context.insert(next)
                result = next
            }
        } else {
            let first = ProgramFactRecord(
                userId: userId,
                kind: kind.rawValue,
                value: clamped.encoded,
                authority: authority.rawValue,
                basis: basis.rawValue,
                source: source,
                acceptedAt: acceptedAt
            )
            first.createdAt = now
            first.updatedAt = now
            context.insert(first)
            result = first
        }

        try? context.save()
        writeThroughLegacyKnob(kind, userId: userId, in: context, defaults: legacyDefaults)
        let toSync = result
        Task { await AppSync.shared.upsertProgramFact(toSync) }
        // The loop closes visibly: Today recomposes on the next
        // breath after a fact changes (HomeView listens).
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        Analytics.track(.programFactChanged, properties: [
            "kind": kind.rawValue,
            "authority": authority.rawValue,
            "source": source,
        ])
        return result
    }

    /// Posted after any fact write or end — surfaces recompose.
    static let didChange = Notification.Name("programFactsDidChange")

    // MARK: - Reads

    /// The resolved head for a kind (the pure law over all active
    /// chains). nil = no fact in force; callers fall back to their
    /// legacy defaults.
    static func head(
        _ kind: ProgramFactKind, userId: String, in context: ModelContext
    ) -> ProgramFacts.Row? {
        ProgramFacts.head(of: rows(kind, userId: userId, in: context), kind: kind)
    }

    static func headValue(
        _ kind: ProgramFactKind, userId: String, in context: ModelContext
    ) -> ProgramFactValue? {
        head(kind, userId: userId, in: context)?.value
    }

    /// Every version ever, newest first — the "why it changed" read.
    static func history(
        _ kind: ProgramFactKind, userId: String, in context: ModelContext
    ) -> [ProgramFactRecord] {
        guard !userId.isEmpty else { return [] }
        let kindRaw = kind.rawValue
        let d = FetchDescriptor<ProgramFactRecord>(
            predicate: #Predicate { $0.userId == userId && $0.kind == kindRaw },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(d)) ?? []
    }

    // MARK: - End (revocation / reset)

    static func endFact(
        _ kind: ProgramFactKind,
        authority: ProgramFactAuthority,
        reason: String,
        userId: String,
        now: Date = .now,
        in context: ModelContext,
        legacyDefaults: UserDefaults = .standard
    ) {
        guard let current = activeRecord(
            kind, authority: authority, userId: userId, in: context
        ) else { return }
        current.endedAt = now
        current.endReason = reason
        current.updatedAt = now
        current.pendingUpsert = true
        try? context.save()
        writeThroughLegacyKnob(kind, userId: userId, in: context, defaults: legacyDefaults)
        let toSync = current
        Task { await AppSync.shared.upsertProgramFact(toSync) }
    }

    // MARK: - Bootstrap (migration moment)

    /// Migrates the v4 consented knobs into facts ONCE (source
    /// "migration", authority preferred — she consented to each at a
    /// re-signing). Default-valued knobs write NOTHING: defaults
    /// live in code, not rows.
    static func bootstrapIfNeeded(
        userId: String,
        defaults: UserDefaults = .standard,
        now: Date = .now,
        in context: ModelContext
    ) {
        guard !userId.isEmpty else { return }
        let marker = "programFacts.bootstrapped.v1"
        guard !defaults.bool(forKey: marker) else { return }

        // Cross-device guard: if migration rows already hydrated
        // from another device, this device's bootstrap writes
        // nothing — the knobs were migrated exactly once, ever.
        let migrated = [ProgramFactKind.proteinAdjust, .movesAdjust, .weighCadence]
            .contains { kind in
                history(kind, userId: userId, in: context)
                    .contains { $0.source == "migration" }
            }
        if migrated {
            defaults.set(true, forKey: marker)
            return
        }

        let proteinAdjust = defaults.integer(forKey: WeeklyReview.proteinAdjustKey)
        if proteinAdjust != 0 {
            apply(
                .proteinAdjust, value: .int(proteinAdjust), authority: .preferred,
                basis: .stated, source: "migration",
                userId: userId, now: now, in: context, legacyDefaults: defaults
            )
        }
        let sessionsAdjust = defaults.integer(forKey: WeeklyReview.sessionsAdjustKey)
        if sessionsAdjust != 0 {
            apply(
                .movesAdjust, value: .int(sessionsAdjust), authority: .preferred,
                basis: .stated, source: "migration",
                userId: userId, now: now, in: context, legacyDefaults: defaults
            )
        }
        if defaults.bool(forKey: WeeklyReview.weighSoftenedKey) {
            apply(
                .weighCadence, value: .word("softened"), authority: .preferred,
                basis: .stated, source: "migration",
                userId: userId, now: now, in: context, legacyDefaults: defaults
            )
        }
        defaults.set(true, forKey: marker)
    }

    // MARK: - Internals

    private static func rows(
        _ kind: ProgramFactKind, userId: String, in context: ModelContext
    ) -> [ProgramFacts.Row] {
        guard !userId.isEmpty else { return [] }
        let kindRaw = kind.rawValue
        let d = FetchDescriptor<ProgramFactRecord>(
            predicate: #Predicate { $0.userId == userId && $0.kind == kindRaw }
        )
        return ((try? context.fetch(d)) ?? []).compactMap { record in
            guard
                let k = ProgramFactKind(rawValue: record.kind),
                let value = ProgramFactValue.decode(record.value),
                let auth = ProgramFactAuthority(rawValue: record.authority)
            else { return nil }
            return ProgramFacts.Row(
                kind: k, value: value, authority: auth,
                endedAt: record.endedAt, acceptedAt: record.acceptedAt,
                createdAt: record.createdAt
            )
        }
    }

    private static func activeRecord(
        _ kind: ProgramFactKind,
        authority: ProgramFactAuthority,
        userId: String,
        in context: ModelContext
    ) -> ProgramFactRecord? {
        let kindRaw = kind.rawValue
        let authRaw = authority.rawValue
        var d = FetchDescriptor<ProgramFactRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == kindRaw
                    && $0.authority == authRaw && $0.endedAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    /// The transition law: the RESOLVED head (not the last write)
    /// flows through to the legacy knob, so straggler engines read
    /// exactly what the resolver would say.
    private static func writeThroughLegacyKnob(
        _ kind: ProgramFactKind,
        userId: String,
        in context: ModelContext,
        defaults: UserDefaults
    ) {
        let resolved = headValue(kind, userId: userId, in: context)
        switch kind {
        case .proteinAdjust:
            defaults.set(resolved?.intValue ?? 0, forKey: WeeklyReview.proteinAdjustKey)
        case .movesAdjust:
            defaults.set(resolved?.intValue ?? 0, forKey: WeeklyReview.sessionsAdjustKey)
        case .weighCadence:
            defaults.set(resolved?.wordValue == "softened",
                         forKey: WeeklyReview.weighSoftenedKey)
        case .stepGoal, .loggingMode, .notificationPosture, .walkTiming, .readAnchor:
            break   // no legacy knob exists for these kinds
        }
    }
}
