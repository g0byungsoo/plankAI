import Foundation
import SwiftData
import PlankSync

// MARK: - WeeklyReadStore (E1 THE SPINE — B2)
//
// docs/app_v25/05_E1_SPINE.md §2. Decided reads only; deterministic
// per-window ids (devices converge on one decision); the offer
// cooldown is read from here (declined kinds sleep 14 days).

@MainActor
enum WeeklyReadStore {

    @discardableResult
    static func recordDecision(
        windowStartDay: String,
        anchor: WeeklyReadAnchor.Kind,
        shown: String?,
        offer: WeeklyReadOffer,
        decision: String,
        factId: String?,
        userId: String,
        now: Date = .now,
        in context: ModelContext
    ) -> WeeklyReadRecord? {
        guard !userId.isEmpty else { return nil }
        let id = WeeklyReadRecord.deterministicId(
            userId: userId, windowStartDay: windowStartDay
        )
        let record: WeeklyReadRecord
        if let existing = fetchById(id, in: context) {
            // Devices (or a re-decide) converge on ONE row per
            // window; the latest decision stands.
            existing.anchor = anchor.rawValue
            existing.shown = shown
            existing.offerKey = offer.key
            existing.decision = decision
            existing.factId = factId
            existing.decidedAt = now
            existing.updatedAt = now
            existing.pendingUpsert = true
            record = existing
        } else {
            let fresh = WeeklyReadRecord(
                userId: userId,
                windowStartDay: windowStartDay,
                anchor: anchor.rawValue,
                shown: shown,
                offerKey: offer.key,
                decision: decision,
                factId: factId,
                decidedAt: now
            )
            fresh.createdAt = now
            fresh.updatedAt = now
            context.insert(fresh)
            record = fresh
        }
        try? context.save()
        let toSync = record
        Task { await AppSync.shared.upsertWeeklyRead(toSync) }
        return record
    }

    static func signedWindows(
        userId: String, in context: ModelContext
    ) -> Set<String> {
        guard !userId.isEmpty else { return [] }
        let d = FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        return Set(((try? context.fetch(d)) ?? []).map(\.windowStartDay))
    }

    static func recentlyDeclinedKinds(
        userId: String,
        now: Date = .now,
        within days: Int = 14,
        in context: ModelContext
    ) -> Set<String> {
        guard !userId.isEmpty else { return [] }
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let d = FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.decision == "declined"
                    && $0.decidedAt >= cutoff
            }
        )
        return Set(((try? context.fetch(d)) ?? []).map(\.offerKey))
    }

    static func latest(
        userId: String, in context: ModelContext
    ) -> WeeklyReadRecord? {
        guard !userId.isEmpty else { return nil }
        var d = FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.decidedAt, order: .reverse)]
        )
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    private static func fetchById(
        _ id: String, in context: ModelContext
    ) -> WeeklyReadRecord? {
        var d = FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.id == id }
        )
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }
}
