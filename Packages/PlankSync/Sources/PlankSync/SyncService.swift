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

    // MARK: - User profile upsert
    //
    // Typed payload (not [String: String] like the older upserts) so
    // PostgREST gets the right column types end-to-end. This is the first
    // upsert to use this pattern; SessionLog/DayProgress will migrate.
    //
    // Dates are emitted as ISO8601 strings to match the existing convention
    // and avoid encoder-config drift.

    public func upsertUser(_ user: UserRecord) async {
        guard !user.id.isEmpty else {
            print("[SyncService] upsertUser ABORT: UserRecord.id empty")
            return
        }

        let iso = ISO8601DateFormatter()
        let payload = SupabaseUserUpsert(
            id: user.id,
            name: user.name,
            start_date: iso.string(from: user.startDate),
            current_day: user.currentDay,
            core_score: user.coreScore,
            last_session_date: user.lastSessionDate.map { iso.string(from: $0) },
            streak_current: user.streakCurrent,
            streak_longest: user.streakLongest,
            streak_last_reset_date: user.streakLastResetDate.map { iso.string(from: $0) },
            program_phase: user.programPhase,
            foundations_completed_date: user.foundationsCompletedDate.map { iso.string(from: $0) },
            onboarding_goal: user.onboardingGoal,
            onboarding_experience: user.onboardingExperience,
            onboarding_baseline_hold_seconds: user.onboardingBaselineHoldSeconds,
            onboarding_barriers: user.onboardingBarriers,
            onboarding_age_range: user.onboardingAgeRange,
            onboarding_activity_level: user.onboardingActivityLevel,
            onboarding_commitment_days_per_week: user.onboardingCommitmentDaysPerWeek,
            onboarding_notification_enabled: user.onboardingNotificationEnabled,
            onboarding_notification_time: user.onboardingNotificationTime.map { iso.string(from: $0) },
            onboarding_voice_preference: user.onboardingVoicePreference,
            onboarding_focus_area: user.onboardingFocusArea,
            onboarding_plank_time: user.onboardingPlankTime,
            onboarding_session_length_pref: user.onboardingSessionLengthPref
        )

        print("[SyncService] upsertUser: payload built for user_id=\(user.id)")
        do {
            let response = try await supabase.from("users")
                .upsert(payload)
                .execute()
            print("[SyncService] upsertUser SUCCESS: status=\(response.status)")
        } catch {
            print("[SyncService] upsertUser FAILED: \(error)")
            print("[SyncService] error type: \(type(of: error))")
            print("[SyncService] error localizedDescription: \(error.localizedDescription)")
            // Surface PostgREST error fields if the SDK exposes them.
            let mirror = Mirror(reflecting: error)
            for child in mirror.children {
                if let label = child.label {
                    print("[SyncService] error.\(label) = \(child.value)")
                }
            }
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
        await hydrateUser(userId: userId)
        await hydrateSessionLogs(userId: userId)
        await hydrateDayProgress(userId: userId)
    }

    @MainActor
    private func hydrateUser(userId: String) async {
        let context = modelContainer.mainContext
        print("[SyncService] hydrateUser: using context \(ObjectIdentifier(context))")

        do {
            let response: [SupabaseUserRow] = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value

            guard let row = response.first else {
                print("[SyncService] hydrateUser: no public.users row for \(userId) — user signed up but never finished onboarding, or schema row never written")
                return
            }
            print("[SyncService] hydrateUser: row found for \(userId), name=\(row.name)")

            let descriptor = FetchDescriptor<UserRecord>(
                predicate: #Predicate { $0.id == userId }
            )
            let target: UserRecord
            if let existing = try? context.fetch(descriptor).first {
                target = existing
                print("[SyncService] hydrateUser: updated existing UserRecord (id=\(userId))")
            } else {
                // Use `userId` (uppercase from Swift UUID.uuidString), NOT
                // `row.id` (lowercase from PostgREST). Swift String comparison
                // is case-sensitive; if we insert with row.id, the predicate
                // `$0.id == userId` later won't find this row even though it
                // exists. PostgreSQL UUID equality is case-insensitive on the
                // SQL side, which is why the .eq("id", value: userId) round
                // trip works regardless of case — but the local SwiftData
                // store is just strings.
                target = UserRecord(
                    id: userId,
                    name: row.name,
                    startDate: row.startDate,
                    currentDay: row.currentDay,
                    coreScore: row.coreScore,
                    programPhase: row.programPhase
                )
                context.insert(target)
                print("[SyncService] hydrateUser: inserted new UserRecord (id=\(userId))")
            }
            // Copy every column. Re-running hydrate is idempotent — if the
            // local UserRecord was just created, this is the first write; if
            // it already existed, this brings it in line with the cloud.
            target.name = row.name
            target.startDate = row.startDate
            target.currentDay = row.currentDay
            target.coreScore = row.coreScore
            target.lastSessionDate = row.lastSessionDate
            target.streakCurrent = row.streakCurrent
            target.streakLongest = row.streakLongest
            target.streakLastResetDate = row.streakLastResetDate
            target.programPhase = row.programPhase
            target.foundationsCompletedDate = row.foundationsCompletedDate
            target.onboardingGoal = row.onboardingGoal
            target.onboardingExperience = row.onboardingExperience
            target.onboardingBaselineHoldSeconds = row.onboardingBaselineHoldSeconds
            target.onboardingBarriers = row.onboardingBarriers
            target.onboardingAgeRange = row.onboardingAgeRange
            target.onboardingActivityLevel = row.onboardingActivityLevel
            target.onboardingCommitmentDaysPerWeek = row.onboardingCommitmentDaysPerWeek
            target.onboardingNotificationEnabled = row.onboardingNotificationEnabled
            target.onboardingNotificationTime = row.onboardingNotificationTime
            target.onboardingVoicePreference = row.onboardingVoicePreference
            target.onboardingFocusArea = row.onboardingFocusArea
            target.onboardingPlankTime = row.onboardingPlankTime
            target.onboardingSessionLengthPref = row.onboardingSessionLengthPref

            print("[SyncService] hydrateUser: about to save context")
            do {
                try context.save()
                print("[SyncService] hydrateUser: context saved successfully")
            } catch {
                print("[SyncService] hydrateUser: SAVE FAILED: \(error)")
                return
            }

            // Verify the write is durable on the same context. A count of 1
            // means the row is queryable; a count of 0 means the save didn't
            // persist or the context's fetch doesn't see uncommitted state.
            let verifyDescriptor = FetchDescriptor<UserRecord>(
                predicate: #Predicate { $0.id == userId }
            )
            let verifyCount = (try? context.fetch(verifyDescriptor))?.count ?? -1
            print("[SyncService] hydrateUser: post-save fetch count = \(verifyCount) on context \(ObjectIdentifier(context))")
        } catch {
            print("[SyncService] hydrateUser FAILED for \(userId): \(error)")
        }
    }

    @MainActor
    private func hydrateSessionLogs(userId: String) async {
        let context = modelContainer.mainContext

        do {
            let rows: [SupabaseSessionLogRow] = try await supabase
                .from("session_logs")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            for row in rows {
                let rowId = row.id
                let descriptor = FetchDescriptor<SessionLogRecord>(
                    predicate: #Predicate { $0.id == rowId }
                )
                if let existing = try? context.fetch(descriptor).first {
                    // Local row exists. Don't clobber a pending-upsert local
                    // record with server state — the local row may be newer.
                    if !existing.pendingUpsert {
                        existing.userId = row.userId
                        existing.exerciseType = row.exerciseType
                        existing.sessionType = row.sessionType
                        existing.completedAt = row.completedAt
                        existing.holdTime = row.holdTime
                        existing.targetTime = row.targetTime
                        existing.qualityScore = row.qualityScore
                        existing.formFaultsCount = row.formFaultsCount
                        existing.modifiedVersion = row.modifiedVersion
                        existing.presetId = row.presetId
                        existing.totalDuration = row.totalDuration
                        existing.plankHoldTime = row.plankHoldTime
                        existing.plankFormScore = row.plankFormScore
                    }
                } else {
                    let record = SessionLogRecord(
                        id: row.id,
                        userId: row.userId,
                        exerciseType: row.exerciseType,
                        completedAt: row.completedAt,
                        holdTime: row.holdTime,
                        targetTime: row.targetTime,
                        qualityScore: row.qualityScore,
                        formFaultsCount: row.formFaultsCount,
                        modifiedVersion: row.modifiedVersion,
                        sessionType: row.sessionType,
                        presetId: row.presetId,
                        totalDuration: row.totalDuration,
                        plankHoldTime: row.plankHoldTime,
                        plankFormScore: row.plankFormScore
                    )
                    record.pendingUpsert = false  // came from server
                    context.insert(record)
                }
            }
            try? context.save()
        } catch {
            // Best-effort. Tables may not exist or network failed.
        }
    }

    @MainActor
    private func hydrateDayProgress(userId: String) async {
        let context = modelContainer.mainContext

        do {
            let rows: [SupabaseDayProgressRow] = try await supabase
                .from("day_progress")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            for row in rows {
                let key = "\(row.userId):\(row.programDay)"
                let descriptor = FetchDescriptor<DayProgressRecord>(
                    predicate: #Predicate { $0.compositeKey == key }
                )
                if let existing = try? context.fetch(descriptor).first {
                    // Last-write-wins on updatedAt.
                    if row.updatedAt > existing.updatedAt {
                        existing.date = row.date
                        existing.primarySessionId = row.primarySessionId
                        existing.primaryQualityScore = row.primaryQualityScore
                        existing.primaryHoldTime = row.primaryHoldTime
                        existing.updatedAt = row.updatedAt
                    }
                } else {
                    let record = DayProgressRecord(
                        userId: row.userId,
                        programDay: row.programDay,
                        date: row.date,
                        primarySessionId: row.primarySessionId,
                        primaryQualityScore: row.primaryQualityScore,
                        primaryHoldTime: row.primaryHoldTime
                    )
                    record.updatedAt = row.updatedAt
                    context.insert(record)
                }
            }
            try? context.save()
        } catch {
            // Best-effort.
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

/// Typed upsert payload for public.users. Snake_case keys match the schema
/// columns; dates are pre-formatted ISO8601 strings so we don't depend on a
/// specific encoder date strategy.
private struct SupabaseUserUpsert: Encodable {
    let id: String
    let name: String
    let start_date: String
    let current_day: Int
    let core_score: Double
    let last_session_date: String?
    let streak_current: Int
    let streak_longest: Int
    let streak_last_reset_date: String?
    let program_phase: String
    let foundations_completed_date: String?
    let onboarding_goal: String?
    let onboarding_experience: String?
    let onboarding_baseline_hold_seconds: Int?
    let onboarding_barriers: [String]?
    let onboarding_age_range: String?
    let onboarding_activity_level: String?
    let onboarding_commitment_days_per_week: Int?
    let onboarding_notification_enabled: Bool
    let onboarding_notification_time: String?
    let onboarding_voice_preference: String?
    let onboarding_focus_area: String?
    let onboarding_plank_time: String?
    let onboarding_session_length_pref: Int?
}

/// Decodable mirror of SupabaseUserUpsert. Mirrors all 21 columns of
/// public.users so hydration restores everything the upsert wrote — name,
/// streaks, program state, AND the 10 onboarding fields. Optional dates
/// arrive as ISO8601 strings; we re-parse with the same formatter.
private struct SupabaseUserRow: Decodable {
    let id: String
    let name: String
    let startDate: Date
    let currentDay: Int
    let coreScore: Double
    let lastSessionDate: Date?
    let streakCurrent: Int
    let streakLongest: Int
    let streakLastResetDate: Date?
    let programPhase: String
    let foundationsCompletedDate: Date?
    let onboardingGoal: String?
    let onboardingExperience: String?
    let onboardingBaselineHoldSeconds: Int?
    let onboardingBarriers: [String]?
    let onboardingAgeRange: String?
    let onboardingActivityLevel: String?
    let onboardingCommitmentDaysPerWeek: Int?
    let onboardingNotificationEnabled: Bool
    let onboardingNotificationTime: Date?
    let onboardingVoicePreference: String?
    let onboardingFocusArea: String?
    let onboardingPlankTime: String?
    let onboardingSessionLengthPref: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case startDate = "start_date"
        case currentDay = "current_day"
        case coreScore = "core_score"
        case lastSessionDate = "last_session_date"
        case streakCurrent = "streak_current"
        case streakLongest = "streak_longest"
        case streakLastResetDate = "streak_last_reset_date"
        case programPhase = "program_phase"
        case foundationsCompletedDate = "foundations_completed_date"
        case onboardingGoal = "onboarding_goal"
        case onboardingExperience = "onboarding_experience"
        case onboardingBaselineHoldSeconds = "onboarding_baseline_hold_seconds"
        case onboardingBarriers = "onboarding_barriers"
        case onboardingAgeRange = "onboarding_age_range"
        case onboardingActivityLevel = "onboarding_activity_level"
        case onboardingCommitmentDaysPerWeek = "onboarding_commitment_days_per_week"
        case onboardingNotificationEnabled = "onboarding_notification_enabled"
        case onboardingNotificationTime = "onboarding_notification_time"
        case onboardingVoicePreference = "onboarding_voice_preference"
        case onboardingFocusArea = "onboarding_focus_area"
        case onboardingPlankTime = "onboarding_plank_time"
        case onboardingSessionLengthPref = "onboarding_session_length_pref"
    }
}

private struct SupabaseSessionLogRow: Decodable {
    let id: String
    let userId: String
    let exerciseType: String
    let sessionType: String
    let completedAt: Date
    let holdTime: Double
    let targetTime: Double
    let qualityScore: Double
    let formFaultsCount: Int
    let modifiedVersion: Bool
    let presetId: String?
    let totalDuration: Double?
    let plankHoldTime: Double?
    let plankFormScore: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case exerciseType = "exercise_type"
        case sessionType = "session_type"
        case completedAt = "completed_at"
        case holdTime = "hold_time"
        case targetTime = "target_time"
        case qualityScore = "quality_score"
        case formFaultsCount = "form_faults_count"
        case modifiedVersion = "modified_version"
        case presetId = "preset_id"
        case totalDuration = "total_duration"
        case plankHoldTime = "plank_hold_time"
        case plankFormScore = "plank_form_score"
    }
}

private struct SupabaseDayProgressRow: Decodable {
    let userId: String
    let programDay: Int
    let date: Date
    let primarySessionId: String
    let primaryQualityScore: Double
    let primaryHoldTime: Double
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case programDay = "program_day"
        case date
        case primarySessionId = "primary_session_id"
        case primaryQualityScore = "primary_quality_score"
        case primaryHoldTime = "primary_hold_time"
        case updatedAt = "updated_at"
    }
}
