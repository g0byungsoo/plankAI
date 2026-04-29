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

    /// Called whenever AuthService.currentUser?.id changes (sign-in, sign-up,
    /// sign-out). Always re-hydrates so local state matches Supabase under
    /// the new identity. Same-user-id changes (Apple/email upgrade preserves
    /// the user_id) skip the work via the `lastUserId` guard.
    func onUserChanged(modelContext: ModelContext) async {
        guard let service = syncService else { return }
        let newUserId = AuthService.shared.currentUser?.id.uuidString ?? ""
        guard newUserId != lastUserId else { return }
        lastUserId = newUserId
        guard !newUserId.isEmpty else { return }

        await service.retryPendingUpserts()
        await service.hydrateFromCloud(userId: newUserId)
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
