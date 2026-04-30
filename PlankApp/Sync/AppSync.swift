import Foundation
import Observation
import SwiftData
import PlankSync
import Auth  // MemberImportVisibility: User.id lives in Supabase's Auth submodule

// MARK: - AppSync
//
// Bridge between AuthService (lives in PlankApp) and SyncService (lives in
// PlankSync). Reads the current user_id from AuthService at write time so
// PlankSync stays auth-agnostic. Owns the lone SyncService instance, lazily
// configured once the SwiftData ModelContainer is available.
//
// Lifecycle:
//   1. RootView calls `configure(modelContainer:)` after SwiftData boots.
//   2. RootView calls `onLaunch(modelContext:)` after AuthService.bootstrap
//      completes — retries pending upserts and hydrates if local cache is
//      empty (fresh install pattern).
//   3. RootView observes `auth.currentUser?.id` and calls
//      `onUserChanged(modelContext:)` when it changes — sign-in, sign-up,
//      and sign-out all flow through here.

@MainActor
@Observable
final class AppSync {
    static let shared = AppSync()
    private init() {}

    private var syncService: SyncService?
    private var lastUserId: String?

    /// Idempotent. Safe to call multiple times.
    func configure(modelContainer: ModelContainer) {
        guard syncService == nil else { return }
        syncService = SyncService(supabaseClient: supabase, modelContainer: modelContainer)
    }

    // MARK: Bootstrap

    /// Called once after AuthService.bootstrap completes and the model
    /// container is configured. Retries pending Supabase upserts from prior
    /// crashes; hydrates from cloud only when local is empty (fresh install
    /// on this device — avoids overwriting an existing user's local data
    /// with stale rows).
    func onLaunch(modelContext: ModelContext) async {
        guard let service = syncService else { return }
        let userId = AuthService.shared.currentUser?.id.uuidString ?? ""
        lastUserId = userId
        guard !userId.isEmpty else { return }

        await service.retryPendingUpserts()

        if isLocalCacheEmpty(modelContext: modelContext) {
            await service.hydrateFromCloud(userId: userId)
        }
    }

    /// Called on every observable auth-state change — sign-up (anon → email/
    /// apple, same user_id), sign-in (different user_id, non-anon), sign-out
    /// (different user_id, new is anon). The behavior branches by case:
    ///
    ///   * Sign-up upgrade (user_id same, was anon, now non-anon):
    ///     local rows already have the right user_id. Just retry pending
    ///     and hydrate to pull anything else in the account.
    ///
    ///   * Sign-in to existing account (user_id changes, new is non-anon):
    ///     re-attribute local rows that were attached to the previous
    ///     user_id (anon experimentation) so they belong to the new account,
    ///     mark them pendingUpsert so retry pushes them, then hydrate the
    ///     account's existing data from the server.
    ///
    ///   * Sign-out (user_id changes, new is anon): per spec, preserve
    ///     local data. The new anon has no server data anyway. Just retry
    ///     pending in case earlier writes never landed.
    func onAuthChanged(modelContext: ModelContext) async {
        guard let service = syncService else { return }
        let newUserId = AuthService.shared.currentUser?.id.uuidString ?? ""
        let isAnonNow = AuthService.shared.isAnonymous
        let previousUserId = lastUserId
        let userIdChanged = newUserId != previousUserId
        lastUserId = newUserId

        guard !newUserId.isEmpty else { return }

        // Sign-in to a non-anon account from a different identity:
        // bring local rows along so the user's anonymous-period work merges
        // into the account they just signed in to.
        if userIdChanged && !isAnonNow,
           let oldId = previousUserId, !oldId.isEmpty, oldId != newUserId {
            reattributeLocalRows(from: oldId, to: newUserId, modelContext: modelContext)
        }

        // Always push pending writes — covers signup-upgrade (where user_id
        // didn't change) and any sign-in-with-merge case above.
        await service.retryPendingUpserts()

        // Pull server state for non-anon identities. Sign-out (new is anon)
        // skips this — preserves local data.
        if !isAnonNow {
            await service.hydrateFromCloud(userId: newUserId)
        }
    }

    // Compatibility name for code that hasn't been renamed yet.
    func onUserChanged(modelContext: ModelContext) async {
        await onAuthChanged(modelContext: modelContext)
    }

    /// Re-attribute local SessionLog + DayProgress rows from the previous
    /// user_id to the new one so they land in the signed-in account on
    /// the next push. Marks SessionLog rows pendingUpsert so retry sends
    /// them; DayProgress is upserted again next session.
    private func reattributeLocalRows(from oldId: String, to newId: String, modelContext: ModelContext) {
        let sessions = (try? modelContext.fetch(FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        for s in sessions {
            s.userId = newId
            s.pendingUpsert = true
        }

        let progress = (try? modelContext.fetch(FetchDescriptor<DayProgressRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        for p in progress {
            p.userId = newId
            p.compositeKey = "\(newId):\(p.programDay)"
            p.updatedAt = .now
        }

        try? modelContext.save()
    }

    // MARK: Upsert pass-throughs

    /// Fire-and-forget Supabase upsert for a SessionLogRecord. Caller is
    /// responsible for the SwiftData write (HomeView does it inline).
    /// Skips silently when the user is unauthenticated — shouldn't happen
    /// after bootstrap, but defensive.
    func upsertSessionLog(_ session: SessionLogRecord) async {
        guard let service = syncService else { return }
        guard !session.userId.isEmpty else { return }
        await service.upsertSessionLog(session)
    }

    func upsertDayProgress(_ progress: DayProgressRecord) async {
        guard let service = syncService else { return }
        guard !progress.userId.isEmpty else { return }
        await service.upsertDayProgress(progress)
    }

    // MARK: Helpers

    /// Convenience for write callers. Returns the current Supabase user_id
    /// or nil if AuthService isn't bootstrapped yet.
    var currentUserId: String? {
        AuthService.shared.currentUser?.id.uuidString
    }

    private func isLocalCacheEmpty(modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<SessionLogRecord>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count == 0
    }
}
