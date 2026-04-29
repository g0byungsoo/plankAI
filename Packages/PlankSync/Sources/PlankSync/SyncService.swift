import Foundation
import SwiftData
import Supabase

/// Local-first, cloud-backed sync service.
///
/// Reads always from SwiftData. Writes go to SwiftData first (instant UI),
/// then fire-and-forget to Supabase. Failed upserts retry on next app
/// launch. The append-only SessionLog with client-generated UUIDs makes
/// retries idempotent — the same `id` upserts cleanly without collisions.
///
/// SyncService is auth-agnostic: callers pass the user_id explicitly.
/// PlankApp's AppSync wrapper reads it from AuthService.shared at write
/// time. Keeping that boundary lets PlankSync stay free of any Supabase
/// auth dependencies.
public actor SyncService {

    private let supabase: SupabaseClient
    private let modelContainer: ModelContainer

    /// Pass the same SupabaseClient used by AuthService so writes share
    /// the auth header (auth.uid() must match user_id under RLS).
    public init(supabaseClient: SupabaseClient, modelContainer: ModelContainer) {
        self.supabase = supabaseClient
        self.modelContainer = modelContainer
    }

    // MARK: - Session log upsert

    /// Upsert a SessionLogRecord to Supabase. SwiftData write is the caller's
    /// responsibility — this method only handles the cloud side. On success,
    /// clears the local `pendingUpsert` flag.
    public func upsertSessionLog(_ session: SessionLogRecord) async {
        let sessionId = session.id
        guard !session.userId.isEmpty else { return }

        do {
            try await supabase.from("session_logs")
                .upsert([
                    "id": session.id,
                    "user_id": session.userId,
                    "exercise_type": session.exerciseType,
                    "session_type": session.sessionType,
                    "completed_at": ISO8601DateFormatter().string(from: session.completedAt),
                    "hold_time": String(session.holdTime),
                    "target_time": String(session.targetTime),
                    "quality_score": String(session.qualityScore),
                    "form_faults_count": String(session.formFaultsCount),
                    "modified_version": String(session.modifiedVersion),
                    "preset_id": session.presetId ?? "",
                    "total_duration": session.totalDuration.map { String($0) } ?? "",
                    "plank_hold_time": session.plankHoldTime.map { String($0) } ?? "",
                    "plank_form_score": session.plankFormScore.map { String($0) } ?? "",
                ])
                .execute()

            // Clear pending flag on success.
            await MainActor.run {
                let descriptor = FetchDescriptor<SessionLogRecord>(
                    predicate: #Predicate { $0.id == sessionId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            // Upsert failed. pendingUpsert stays true. Retry on next launch.
        }
    }

    // MARK: - Day progress upsert

    public func upsertDayProgress(_ progress: DayProgressRecord) async {
        guard !progress.userId.isEmpty else { return }

        do {
            try await supabase.from("day_progress")
                .upsert([
                    "user_id": progress.userId,
                    "program_day": String(progress.programDay),
                    "date": ISO8601DateFormatter().string(from: progress.date),
                    "primary_session_id": progress.primarySessionId,
                    "primary_quality_score": String(progress.primaryQualityScore),
                    "primary_hold_time": String(progress.primaryHoldTime),
                    "updated_at": ISO8601DateFormatter().string(from: progress.updatedAt),
                ])
                .execute()
        } catch {
            // Non-fatal. DayProgress syncs on next attempt.
        }
    }

    // MARK: - Hydrate on login
    //
    // Pull the user's row from Supabase and reflect it locally. Best-effort:
    // if the table doesn't exist or the user has no row yet (fresh anonymous
    // user), this is a no-op.

    @MainActor
    public func hydrateFromCloud(userId: String) async {
        guard !userId.isEmpty else { return }
        let context = modelContainer.mainContext

        do {
            let response: [SupabaseUserRow] = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value

            guard let row = response.first else { return }

            // Idempotent: update existing or insert new.
            let descriptor = FetchDescriptor<UserRecord>(
                predicate: #Predicate { $0.id == userId }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.name = row.name
                existing.startDate = row.startDate
                existing.currentDay = row.currentDay
                existing.coreScore = row.coreScore
                existing.streakCurrent = row.streakCurrent
                existing.streakLongest = row.streakLongest
                existing.programPhase = row.programPhase
            } else {
                let user = UserRecord(
                    id: row.id,
                    name: row.name,
                    startDate: row.startDate,
                    currentDay: row.currentDay,
                    coreScore: row.coreScore,
                    programPhase: row.programPhase
                )
                user.streakCurrent = row.streakCurrent
                user.streakLongest = row.streakLongest
                context.insert(user)
            }
            try? context.save()
        } catch {
            // No table, no row, or network — leave local state alone.
        }
    }

    // MARK: - Retry pending upserts
    //
    // Called on app launch and on auth-state changes. Walks SessionLogs with
    // pendingUpsert == true and retries each.

    @MainActor
    public func retryPendingUpserts() async {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )

        guard let pending = try? context.fetch(descriptor) else { return }

        for session in pending {
            await upsertSessionLog(session)
        }
    }
}

// MARK: - Supabase row types

private struct SupabaseUserRow: Decodable {
    let id: String
    let name: String
    let startDate: Date
    let currentDay: Int
    let coreScore: Double
    let streakCurrent: Int
    let streakLongest: Int
    let programPhase: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case startDate = "start_date"
        case currentDay = "current_day"
        case coreScore = "core_score"
        case streakCurrent = "streak_current"
        case streakLongest = "streak_longest"
        case programPhase = "program_phase"
    }
}
