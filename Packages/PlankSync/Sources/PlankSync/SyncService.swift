import Foundation
import SwiftData
import Supabase

/// Local-first, cloud-backed sync service.
/// Reads always from SwiftData. Writes to SwiftData first, then fire-and-forget to Supabase.
/// Failed upserts retry on next app launch.
public actor SyncService {

    private let supabase: SupabaseClient
    private let modelContainer: ModelContainer

    public init(supabaseURL: URL, supabaseKey: String, modelContainer: ModelContainer) {
        self.supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
        self.modelContainer = modelContainer
    }

    // MARK: - Session Write Flow

    /// Complete write flow: SwiftData first, then Supabase upsert.
    @MainActor
    public func saveSession(
        userId: String,
        exerciseType: String,
        holdTime: Double,
        targetTime: Double,
        qualityScore: Double,
        formFaultsCount: Int,
        programDay: Int
    ) async {
        let context = modelContainer.mainContext
        let sessionId = UUID().uuidString

        // 1. Write SessionLog to SwiftData
        let sessionLog = SessionLogRecord(
            id: sessionId,
            userId: userId,
            exerciseType: exerciseType,
            holdTime: holdTime,
            targetTime: targetTime,
            qualityScore: qualityScore,
            formFaultsCount: formFaultsCount
        )
        context.insert(sessionLog)

        // 2. Update/insert DayProgress
        let compositeKey = "\(userId):\(programDay)"
        let descriptor = FetchDescriptor<DayProgressRecord>(
            predicate: #Predicate { $0.compositeKey == compositeKey }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.primarySessionId = sessionId
            existing.primaryQualityScore = qualityScore
            existing.primaryHoldTime = holdTime
            existing.updatedAt = .now
        } else {
            let dayProgress = DayProgressRecord(
                userId: userId,
                programDay: programDay,
                primarySessionId: sessionId,
                primaryQualityScore: qualityScore,
                primaryHoldTime: holdTime
            )
            context.insert(dayProgress)
        }

        try? context.save()

        // 3. Fire-and-forget Supabase upsert
        Task {
            await upsertSessionToSupabase(sessionLog)
            await upsertDayProgressToSupabase(userId: userId, programDay: programDay, sessionId: sessionId, qualityScore: qualityScore, holdTime: holdTime)
        }
    }

    // MARK: - Supabase Upserts

    private func upsertSessionToSupabase(_ session: SessionLogRecord) async {
        let sessionId = session.id
        let holdTime = session.holdTime

        do {
            try await supabase.from("session_logs")
                .upsert([
                    "id": session.id,
                    "user_id": session.userId,
                    "exercise_type": session.exerciseType,
                    "completed_at": ISO8601DateFormatter().string(from: session.completedAt),
                    "hold_time": String(session.holdTime),
                    "target_time": String(session.targetTime),
                    "quality_score": String(session.qualityScore),
                    "form_faults_count": String(session.formFaultsCount),
                    "modified_version": String(session.modifiedVersion),
                ])
                .execute()

            // Clear pending flag on success
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

    private func upsertDayProgressToSupabase(
        userId: String,
        programDay: Int,
        sessionId: String,
        qualityScore: Double,
        holdTime: Double
    ) async {
        do {
            try await supabase.from("day_progress")
                .upsert([
                    "user_id": userId,
                    "program_day": String(programDay),
                    "date": ISO8601DateFormatter().string(from: .now),
                    "primary_session_id": sessionId,
                    "primary_quality_score": String(qualityScore),
                    "primary_hold_time": String(holdTime),
                    "updated_at": ISO8601DateFormatter().string(from: .now),
                ])
                .execute()
        } catch {
            // Non-fatal. DayProgress syncs on next successful attempt.
        }
    }

    // MARK: - Hydrate on Login

    /// Pull user data from Supabase and hydrate SwiftData.
    /// Called on fresh install after auth.
    @MainActor
    public func hydrateFromCloud(userId: String) async {
        let context = modelContainer.mainContext

        // Hydrate user record
        do {
            let response: [SupabaseUserRow] = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value

            if let row = response.first {
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
                try? context.save()
            }
        } catch {
            // Hydration failed. User starts fresh locally.
        }
    }

    // MARK: - Retry Pending Upserts

    /// Called on app launch. Finds SessionLogs with pendingUpsert=true and retries.
    @MainActor
    public func retryPendingUpserts() async {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )

        guard let pending = try? context.fetch(descriptor) else { return }

        for session in pending {
            await upsertSessionToSupabase(session)
        }
    }
}

// MARK: - Supabase Row Types

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
