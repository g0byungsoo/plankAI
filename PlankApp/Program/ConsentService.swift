import Foundation
import SwiftData
import PlankSync

// MARK: - ConsentService (app v8 S3)
//
// The minimum durable consent seam (09_S3_PACKET §1): explicit,
// scoped, revocable, auditable, INACTIVE by default. S3 ships one
// scope — visit-packet sharing — and delivers nothing anywhere:
// an active grant only permits FUTURE connected sharing; a
// revoked grant blocks it. The share sheet stays her manual act
// on a file either way.

@MainActor
enum ConsentService {

    static let visitPacketScope = "visit_packet_sharing"

    static func activeGrant(
        scope: String, userId: String, in context: ModelContext
    ) -> ConsentGrantRecord? {
        var d = FetchDescriptor<ConsentGrantRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.scope == scope && $0.revokedAt == nil
            },
            sortBy: [SortDescriptor(\.grantedAt, order: .reverse)]
        )
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    static func isActive(
        scope: String, userId: String, in context: ModelContext
    ) -> Bool {
        activeGrant(scope: scope, userId: userId, in: context) != nil
    }

    @discardableResult
    static func grant(
        scope: String, purpose: String, userId: String, in context: ModelContext
    ) -> ConsentGrantRecord? {
        guard !userId.isEmpty else { return nil }
        if let existing = activeGrant(scope: scope, userId: userId, in: context) {
            return existing   // idempotent; the audit row stands
        }
        let record = ConsentGrantRecord(
            userId: userId, scope: scope, purpose: purpose
        )
        context.insert(record)
        try? context.save()
        let toSync = record
        Task { await AppSync.shared.upsertConsentGrant(toSync) }
        return record
    }

    static func revoke(
        scope: String, userId: String, in context: ModelContext
    ) {
        guard let grant = activeGrant(scope: scope, userId: userId, in: context)
        else { return }
        grant.revokedAt = .now
        grant.pendingUpsert = true
        try? context.save()
        let toSync = grant
        Task { await AppSync.shared.upsertConsentGrant(toSync) }
    }
}
