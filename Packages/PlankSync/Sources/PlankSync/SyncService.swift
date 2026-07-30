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
    ///
    /// Typed Codable payload: numeric fields encode as JSON numbers (not
    /// stringified), optional fields encode as JSON null when Swift nil
    /// (not ""), and exercise_results decodes to [ExerciseResultEntry]
    /// before encoding so the jsonb column receives a real JSON array
    /// instead of a base64 blob.
    public func upsertSessionLog(_ session: SessionLogRecord) async {
        let sessionId = session.id
        guard !session.userId.isEmpty else { return }

        // Decode local Data? → [ExerciseResultEntry]? for the jsonb column.
        // nil Data → nil array → JSON null on the wire (correct for "no
        // exercises captured"). Set Data → decoded entries → real JSON array.
        // Decode failure → nil + log (degraded: row still upserts without
        // the per-exercise breakdown rather than failing the whole upsert).
        let exerciseResultsArray: [ExerciseResultEntry]?
        if let data = session.exerciseResults {
            do {
                exerciseResultsArray = try JSONDecoder().decode(
                    [ExerciseResultEntry].self,
                    from: data
                )
            } catch {
                exerciseResultsArray = nil
            }
        } else {
            exerciseResultsArray = nil
        }

        let payload = SupabaseSessionLogUpsert(
            id: session.id,
            user_id: session.userId,
            exercise_type: session.exerciseType,
            session_type: session.sessionType,
            completed_at: ISO8601DateFormatter().string(from: session.completedAt),
            hold_time: session.holdTime,
            target_time: session.targetTime,
            quality_score: session.qualityScore,
            form_faults_count: session.formFaultsCount,
            modified_version: session.modifiedVersion,
            preset_id: session.presetId,
            total_duration: session.totalDuration,
            plank_hold_time: session.plankHoldTime,
            plank_form_score: session.plankFormScore,
            exercise_results: exerciseResultsArray
        )

        do {
            try await supabase.from("session_logs")
                .upsert(payload)
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
            #if DEBUG
            print("[SyncService] upsertSessionLog FAILED for \(sessionId): \(error)")
            #endif
            // pendingUpsert stays true. Retry on next launch.
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
        guard !user.id.isEmpty else { return }

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
            onboarding_session_length_pref: user.onboardingSessionLengthPref,
            onboarding_body_focus: user.onboardingBodyFocus.isEmpty ? nil : user.onboardingBodyFocus,
            onboarding_current_weight_kg: user.onboardingCurrentWeightKg,
            onboarding_goal_weight_kg: user.onboardingGoalWeightKg,
            // Phase 4 remaining 11 fields. Empty strings/arrays send as
            // nil so the row stays clean across legacy + Phase-4 users
            // (matches the bodyFocus pattern above).
            onboarding_motivation: user.onboardingMotivation.isEmpty ? nil : user.onboardingMotivation,
            onboarding_workout_location: user.onboardingWorkoutLocation.isEmpty ? nil : user.onboardingWorkoutLocation,
            onboarding_workout_style: user.onboardingWorkoutStyle.isEmpty ? nil : user.onboardingWorkoutStyle,
            onboarding_gender: user.onboardingGender.isEmpty ? nil : user.onboardingGender,
            onboarding_height_cm: user.onboardingHeightCm,
            onboarding_body_type_current: user.onboardingBodyTypeCurrent,
            onboarding_body_type_desired: user.onboardingBodyTypeDesired,
            onboarding_identity_feeling: user.onboardingIdentityFeeling.isEmpty ? nil : user.onboardingIdentityFeeling,
            onboarding_reward_choice: user.onboardingRewardChoice.isEmpty ? nil : user.onboardingRewardChoice,
            onboarding_relatability_1: user.onboardingRelatability1,
            onboarding_relatability_2: user.onboardingRelatability2,
            onboarding_relatability_3: user.onboardingRelatability3,
            onboarding_acquisition_source: user.onboardingAcquisitionSource,
            // 2026-06-23 cohort + clinical intake. Already nil-cleaned at
            // onboarding-complete, so pass through directly.
            onboarding_glp1_status: user.onboardingGlp1Status,
            onboarding_glp1_phase: user.onboardingGlp1Phase,
            onboarding_hormonal_stage: user.onboardingHormonalStage,
            onboarding_weight_trend: user.onboardingWeightTrend,
            onboarding_sleep_hours: user.onboardingSleepHours,
            onboarding_stress_level: user.onboardingStressLevel,
            onboarding_eating_cadence: user.onboardingEatingCadence,
            onboarding_eating_window: user.onboardingEatingWindow,
            onboarding_food_relationship: user.onboardingFoodRelationship,
            // Phase 1a (2026-06-28) - clinical baseline + activation counter.
            computed_start_bmi: user.computedStartBMI,
            target_rate_pct_per_week: user.targetRatePctPerWeek,
            medical_disclaimer_ack_at: user.medicalDisclaimerAckAt.map { iso.string(from: $0) },
            promises_kept: user.promisesKept
        )

        let userId = user.id
        do {
            try await supabase.from("users")
                .upsert(payload)
                .execute()
            // Clear the pending flag once the cloud has accepted the row.
            // Refetch on the main context — `user` may have been captured
            // off-main and the property write needs to happen where the
            // @Model lives.
            await MainActor.run {
                let descriptor = FetchDescriptor<UserRecord>(
                    predicate: #Predicate { $0.id == userId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            #if DEBUG
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
            #endif
        }
    }

    // MARK: - Day progress upsert

    public func upsertDayProgress(_ progress: DayProgressRecord) async {
        guard !progress.userId.isEmpty else { return }

        let iso = ISO8601DateFormatter()
        let payload = SupabaseDayProgressUpsert(
            user_id: progress.userId,
            program_day: progress.programDay,
            date: iso.string(from: progress.date),
            primary_session_id: progress.primarySessionId,
            primary_quality_score: progress.primaryQualityScore,
            primary_hold_time: progress.primaryHoldTime,
            updated_at: iso.string(from: progress.updatedAt),
            session_log_ids: progress.sessionLogIds
        )

        do {
            // Explicit composite-PK conflict target. Without it, PostgREST's
            // default upsert conflict resolution doesn't match the
            // (user_id, program_day) primary key cleanly — the row is
            // inserted-or-updated correctly EXCEPT the new column
            // session_log_ids gets dropped on the UPDATE branch. Naming
            // the columns explicitly fixes that.
            try await supabase.from("day_progress")
                .upsert(payload, onConflict: "user_id,program_day")
                .execute()
        } catch {
            #if DEBUG
            print("[SyncService] upsertDayProgress FAILED for user=\(progress.userId) day=\(progress.programDay): \(error)")
            #endif
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

        do {
            let response: [SupabaseUserRow] = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .execute()
                .value

            guard let row = response.first else { return }

            let descriptor = FetchDescriptor<UserRecord>(
                predicate: #Predicate { $0.id == userId }
            )
            let target: UserRecord
            if let existing = try? context.fetch(descriptor).first {
                target = existing
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
            // Phase 4 hydration — empty array on the wire decodes cleanly
            // to []; nil weights stay nil. Cross-device sign-in restores
            // bodyFocus + weights so PaywallView's personalized headline
            // works on the new device without re-onboarding.
            target.onboardingBodyFocus = row.onboardingBodyFocus ?? []
            target.onboardingCurrentWeightKg = row.onboardingCurrentWeightKg
            target.onboardingGoalWeightKg = row.onboardingGoalWeightKg
            // Phase 4 remaining 11 fields. Strings/arrays default to ""/[]
            // when the wire payload is nil so SwiftData String/array fields
            // stay non-optional; numerics + booleans pass through as
            // Optional. Cross-device sign-in restores the full Phase 4
            // answer set so analytics + future personalization hooks have
            // the synced values immediately.
            target.onboardingMotivation = row.onboardingMotivation ?? ""
            target.onboardingWorkoutLocation = row.onboardingWorkoutLocation ?? ""
            target.onboardingWorkoutStyle = row.onboardingWorkoutStyle ?? []
            target.onboardingGender = row.onboardingGender ?? ""
            target.onboardingHeightCm = row.onboardingHeightCm
            target.onboardingBodyTypeCurrent = row.onboardingBodyTypeCurrent
            target.onboardingBodyTypeDesired = row.onboardingBodyTypeDesired
            target.onboardingIdentityFeeling = row.onboardingIdentityFeeling ?? ""
            target.onboardingRewardChoice = row.onboardingRewardChoice ?? ""
            target.onboardingRelatability1 = row.onboardingRelatability1
            target.onboardingRelatability2 = row.onboardingRelatability2
            target.onboardingRelatability3 = row.onboardingRelatability3
            // 2026-05-30 (epic #1 child #7) — TikTok/IG/friend attribution.
            target.onboardingAcquisitionSource = row.onboardingAcquisitionSource
            // 2026-06-23 — cohort + clinical intake (persistence P0). Restores
            // GLP-1 status/phase, hormonal stage, weight trend, and the
            // lifestyle signals on cross-device sign-in so cohort routing +
            // analytics survive a reinstall.
            target.onboardingGlp1Status = row.onboardingGlp1Status
            target.onboardingGlp1Phase = row.onboardingGlp1Phase
            target.onboardingHormonalStage = row.onboardingHormonalStage
            target.onboardingWeightTrend = row.onboardingWeightTrend
            target.onboardingSleepHours = row.onboardingSleepHours
            target.onboardingStressLevel = row.onboardingStressLevel
            target.onboardingEatingCadence = row.onboardingEatingCadence
            target.onboardingEatingWindow = row.onboardingEatingWindow
            target.onboardingFoodRelationship = row.onboardingFoodRelationship
            // Phase 1a (2026-06-28) - clinical baseline + activation counter.
            // nil columns on legacy rows decode as nil and pass through as nil.
            // promisesKept coalesces nil (legacy row) to 0 so the Int field
            // on UserRecord stays non-optional and the counter self-heals on
            // first reinstall.
            target.computedStartBMI = row.computedStartBMI
            target.targetRatePctPerWeek = row.targetRatePctPerWeek
            target.medicalDisclaimerAckAt = row.medicalDisclaimerAckAt
            target.promisesKept = row.promisesKept ?? 0

            do {
                try context.save()
            } catch {
                #if DEBUG
                print("[SyncService] hydrateUser: SAVE FAILED: \(error)")
                #endif
                return
            }
        } catch {
            #if DEBUG
            print("[SyncService] hydrateUser FAILED for \(userId): \(error)")
            #endif
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
                        // Use the userId param (uppercase Swift UUID), NOT
                        // row.userId (lowercase from PostgREST). Local writes
                        // store uppercase; HomeView's user-scoped filter
                        // compares against uppercase. Storing lowercase here
                        // would make hydrated rows invisible to the filter.
                        existing.userId = userId
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
                        userId: userId,
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
                // Build composite key with the uppercase userId param so it
                // matches the key HomeView's saveRoutineSession produces
                // ("\(currentUserId):\(currentDay)"). Using row.userId
                // (lowercase) would create a parallel set of keys that
                // never collide with the local writes — duplicate rows.
                let key = "\(userId):\(row.programDay)"
                let descriptor = FetchDescriptor<DayProgressRecord>(
                    predicate: #Predicate { $0.compositeKey == key }
                )
                if let existing = try? context.fetch(descriptor).first {
                    // Last-write-wins on updatedAt.
                    if row.updatedAt > existing.updatedAt {
                        existing.userId = userId
                        existing.date = row.date
                        existing.primarySessionId = row.primarySessionId
                        existing.primaryQualityScore = row.primaryQualityScore
                        existing.primaryHoldTime = row.primaryHoldTime
                        existing.sessionLogIds = row.sessionLogIds
                        existing.updatedAt = row.updatedAt
                    }
                } else {
                    let record = DayProgressRecord(
                        userId: userId,
                        programDay: row.programDay,
                        date: row.date,
                        primarySessionId: row.primarySessionId,
                        primaryQualityScore: row.primaryQualityScore,
                        primaryHoldTime: row.primaryHoldTime
                    )
                    record.updatedAt = row.updatedAt
                    record.sessionLogIds = row.sessionLogIds
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

        // User profile retries run FIRST so a settings edit that didn't
        // land before the previous app session ended gets pushed to cloud
        // before the next hydrate overwrites local with stale server data.
        let userDescriptor = FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(userDescriptor) {
            for user in pending {
                await upsertUser(user)
            }
        }

        let descriptor = FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )

        if let pending = try? context.fetch(descriptor) {
            for session in pending {
                await upsertSessionLog(session)
            }
        }

        // Weight logs share the same fire-and-forget retry shape.
        let weightDescriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(weightDescriptor) {
            for log in pending {
                await upsertWeightLog(log)
            }
        }

        // The program plan is the ANCHOR for "which day the user is on"
        // (programDay derives from plan.startDate). Before v1.1.6 it was
        // the one synced entity NOT retried here — so an enrollment that
        // failed its single fire-and-forget push (offline / backgrounded)
        // stayed pendingUpsert forever and was lost on reinstall, resetting
        // the day. Retried now like every other record.
        let planDescriptor = FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(planDescriptor) {
            for plan in pending {
                await upsertProgramPlan(plan)
            }
        }

        let checkDescriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(checkDescriptor) {
            for check in pending {
                await upsertProgramDayCheck(check)
            }
        }

        // Session ratings joined the sync set last (the docs claimed they
        // synced; nothing did). New writes flag pendingUpsert in init, so
        // this sweep alone is enough to land them; no per-write call
        // site required. Pre-v2 rows migrated with pendingUpsert=false
        // and no userId, so they stay local, as intended.
        let ratingDescriptor = FetchDescriptor<SessionRatingRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(ratingDescriptor) {
            for rating in pending {
                await upsertSessionRating(rating)
            }
        }
    }

    // MARK: - Weight log upsert / fetch

    public func upsertWeightLog(_ log: WeightLogRecord) async {
        let logId = log.id
        guard !log.userId.isEmpty else { return }

        let payload = SupabaseWeightLogUpsert(
            id: log.id,
            user_id: log.userId,
            weight_kg: log.weightKg,
            logged_at: ISO8601DateFormatter().string(from: log.loggedAt),
            source: log.source
        )

        do {
            try await supabase.from("weight_logs")
                .upsert(payload)
                .execute()

            await MainActor.run {
                let descriptor = FetchDescriptor<WeightLogRecord>(
                    predicate: #Predicate { $0.id == logId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            #if DEBUG
            print("[SyncService] upsertWeightLog FAILED for \(logId): \(error)")
            #endif
        }
    }

    // MARK: - Day reflection upsert (app v2.6 — jeni's memory seam)
    //
    // Fire-and-forget; the table ships with the 20260703 migration.
    // Until the founder applies it this 404s and we stay local-first
    // (same graceful posture as the chat transport). Deterministic id
    // (userId-dayKey) makes retries idempotent.

    public func upsertDayReflection(
        userId: String, dayKey: String, feeling: String, note: String?
    ) async {
        guard !userId.isEmpty else { return }
        let payload = SupabaseDayReflectionUpsert(
            id: "\(userId.lowercased())-\(dayKey)",
            user_id: userId,
            day_key: dayKey,
            feeling: feeling,
            note: note
        )
        do {
            try await supabase.from("day_reflections")
                .upsert(payload)
                .execute()
        } catch {
            #if DEBUG
            print("[SyncService] upsertDayReflection deferred (table not deployed yet?): \(error)")
            #endif
        }
    }

    /// Pull the evening reflections back into the device-local
    /// `day.reflection.<dayKey>` (feeling) + `day.note.<dayKey>` (note)
    /// keys they render from. Before v1.1.6 these uploaded but never
    /// hydrated, so a reinstall lost every logged feeling/note even
    /// though the cloud held them. Restore-if-missing: never clobbers a
    /// value already on this device (hydrate runs on a fresh cache).
    public func hydrateDayReflections(userId: String) async {
        struct Row: Decodable {
            let day_key: String
            let feeling: String
            let note: String?
        }
        do {
            let rows: [Row] = try await supabase.from("day_reflections")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            let defaults = UserDefaults.standard
            for row in rows {
                let feelingKey = "day.reflection.\(row.day_key)"
                if defaults.string(forKey: feelingKey) == nil {
                    defaults.set(row.feeling, forKey: feelingKey)
                }
                if let note = row.note, !note.isEmpty {
                    let noteKey = "day.note.\(row.day_key)"
                    if defaults.string(forKey: noteKey) == nil {
                        defaults.set(note, forKey: noteKey)
                    }
                }
            }
        } catch {
            #if DEBUG
            print("[SyncService] hydrateDayReflections deferred (table not deployed / no rows): \(error)")
            #endif
        }
    }

    // MARK: - Observations (app v8 — the chart)
    //
    // Fire-and-forget with the day-reflection posture: until the
    // 20260728 migration is applied this 404s and the store stays
    // local-first. Deterministic ids make retries idempotent.
    // `payload` stays device-local in S1 (care events + asked-sets
    // are not yet clinic-served data).

    public func upsertObservation(_ record: ObservationRecord) async {
        let recordId = record.id
        guard !record.userId.isEmpty else { return }
        struct SupabaseObservationUpsert: Encodable {
            let id: String
            let user_id: String
            let kind: String
            let day_key: String
            let effective_at: String
            let value_text: String?
            let value_num: Double?
            let unit: String?
            let source: String
        }
        let payload = SupabaseObservationUpsert(
            id: record.id,
            user_id: record.userId,
            kind: record.kind,
            day_key: record.dayKey,
            effective_at: ISO8601DateFormatter().string(from: record.effectiveAt),
            value_text: record.valueText,
            value_num: record.valueNum,
            unit: record.unit,
            source: record.source
        )
        do {
            try await supabase.from("observations")
                .upsert(payload)
                .execute()
            await MainActor.run {
                let descriptor = FetchDescriptor<ObservationRecord>(
                    predicate: #Predicate { $0.id == recordId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            #if DEBUG
            print("[SyncService] upsertObservation deferred (table not deployed yet?): \(error)")
            #endif
        }
    }

    /// Insert-only merge of cloud observations. userId normalizes to
    /// the passed param (uuid columns come back lowercase from
    /// PostgREST — the program-day-check lesson).
    @MainActor
    public func hydrateObservations(userId: String) async {
        struct Row: Decodable {
            let id: String
            let kind: String
            let day_key: String
            let effective_at: String?
            let value_text: String?
            let value_num: Double?
            let unit: String?
            let source: String?
        }
        do {
            let rows: [Row] = try await supabase.from("observations")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            let context = modelContainer.mainContext
            let iso = ISO8601DateFormatter()
            let isoFractional = ISO8601DateFormatter()
            isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            for row in rows {
                let rowId = row.id
                let descriptor = FetchDescriptor<ObservationRecord>(
                    predicate: #Predicate { $0.id == rowId }
                )
                if let existing = try? context.fetch(descriptor).first {
                    if existing.userId != userId,
                       existing.userId.lowercased() == userId.lowercased() {
                        existing.userId = userId
                    }
                    continue
                }
                let effective = row.effective_at.flatMap {
                    iso.date(from: $0) ?? isoFractional.date(from: $0)
                }
                let record = ObservationRecord(
                    id: row.id,
                    userId: userId,
                    kind: row.kind,
                    dayKey: row.day_key,
                    effectiveAt: effective ?? .now,
                    valueText: row.value_text,
                    valueNum: row.value_num,
                    unit: row.unit,
                    source: row.source ?? "manual"
                )
                record.pendingUpsert = false
                context.insert(record)
            }
            try? context.save()
        } catch {
            #if DEBUG
            print("[SyncService] hydrateObservations deferred (table not deployed / no rows): \(error)")
            #endif
        }
    }

    // MARK: - Consent grants (app v8 S3 — durable audit rows)

    public func upsertConsentGrant(_ grant: ConsentGrantRecord) async {
        let grantId = grant.id
        guard !grant.userId.isEmpty else { return }
        struct SupabaseConsentGrantUpsert: Encodable {
            let id: String
            let user_id: String
            let scope: String
            let purpose: String
            let granted_at: String
            let revoked_at: String?
            let org_id: String?
        }
        let iso = ISO8601DateFormatter()
        let payload = SupabaseConsentGrantUpsert(
            id: grant.id,
            user_id: grant.userId,
            scope: grant.scope,
            purpose: grant.purpose,
            granted_at: iso.string(from: grant.grantedAt),
            revoked_at: grant.revokedAt.map { iso.string(from: $0) },
            org_id: grant.orgId
        )
        do {
            try await supabase.from("consent_grants").upsert(payload).execute()
            await MainActor.run {
                let descriptor = FetchDescriptor<ConsentGrantRecord>(
                    predicate: #Predicate { $0.id == grantId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            #if DEBUG
            print("[SyncService] upsertConsentGrant deferred: \(error)")
            #endif
        }
    }

    // MARK: - Served protocol (app v8 S2)

    /// Raw PostgREST bytes for `protocols.payload` at the given
    /// id. The app layer owns decode + the clinical sanity gate
    /// (the config type lives app-side by design).
    public func fetchServedProtocolData(id: String) async -> Data? {
        do {
            let response = try await supabase.from("protocols")
                .select("payload")
                .eq("id", value: id)
                .limit(1)
                .execute()
            return response.data
        } catch {
            #if DEBUG
            print("[SyncService] fetchServedProtocolData deferred: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Assigned protocol (app v8 S4)

    /// The protocol id an active clinician assignment resolves to
    /// for `userId`, or nil (→ the org-null default). The patient's
    /// own assignment rows are RLS-readable; a clinic is simply a
    /// different protocol row through the same resolver (S2 law).
    public func fetchAssignedProtocolId(userId: String) async -> String? {
        struct Row: Decodable { let protocol_id: String }
        do {
            let rows: [Row] = try await supabase.from("protocol_assignments")
                .select("protocol_id")
                .eq("patient_id", value: userId)
                .eq("status", value: "active")
                .limit(1)
                .execute()
                .value
            return rows.first?.protocol_id
        } catch {
            #if DEBUG
            print("[SyncService] fetchAssignedProtocolId deferred: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Visit packet publish (app v8 S4)

    /// Publish the patient's canonical S3 packet for a connected
    /// org. The projection is computed app-side (S3 law: one
    /// implementation); this only transports the serialized payload.
    /// RLS gates it: the insert policy requires an active packet
    /// consent, so a revoked patient simply can't publish.
    public func publishVisitPacket(
        id: String, userId: String, orgId: String,
        payload: Data, windowStart: String?, windowEnd: String?, appVersion: String?
    ) async {
        guard !userId.isEmpty, !orgId.isEmpty else { return }
        struct Upsert: Encodable {
            let id: String
            let user_id: String
            let org_id: String
            let payload: AnyJSON
            let window_start: String?
            let window_end: String?
            let app_version: String?
        }
        guard let json = try? JSONDecoder().decode(AnyJSON.self, from: payload) else { return }
        let row = Upsert(
            id: id, user_id: userId, org_id: orgId, payload: json,
            window_start: windowStart, window_end: windowEnd, app_version: appVersion
        )
        do {
            try await supabase.from("visit_packets").upsert(row).execute()
        } catch {
            #if DEBUG
            print("[SyncService] publishVisitPacket deferred (no packet consent / offline): \(error)")
            #endif
        }
    }

    // MARK: - Regimen plans (app v8 — medication + supplements)

    public func upsertRegimenPlan(_ plan: RegimenPlanRecord) async {
        let planId = plan.id
        guard !plan.userId.isEmpty else { return }
        struct SupabaseRegimenPlanUpsert: Encodable {
            let id: String
            let user_id: String
            let kind: String
            let display_name: String
            let schedule_rule: String
            let anchor_weekday: Int?
            let time_of_day_minutes: Int?
            let dose_stage_label: String?
            let started_at: String
            let ended_at: String?
            let reminder_enabled: Bool
            let authority: String
            let rxnorm_code: String?
            let strength_value: Double?
            let strength_unit: String?
            let source_protocol_id: String?
            let org_id: String?
        }
        let iso = ISO8601DateFormatter()
        let payload = SupabaseRegimenPlanUpsert(
            id: plan.id,
            user_id: plan.userId,
            kind: plan.kind,
            display_name: plan.displayName,
            schedule_rule: plan.scheduleRule,
            anchor_weekday: plan.anchorWeekday,
            time_of_day_minutes: plan.timeOfDayMinutes,
            dose_stage_label: plan.doseStageLabel,
            started_at: iso.string(from: plan.startedAt),
            ended_at: plan.endedAt.map { iso.string(from: $0) },
            reminder_enabled: plan.reminderEnabled,
            authority: plan.authority,
            rxnorm_code: plan.rxnormCode,
            strength_value: plan.strengthValue,
            strength_unit: plan.strengthUnit,
            source_protocol_id: plan.sourceProtocolId,
            org_id: plan.orgId
        )
        do {
            try await supabase.from("regimen_plans")
                .upsert(payload)
                .execute()
            await MainActor.run {
                let descriptor = FetchDescriptor<RegimenPlanRecord>(
                    predicate: #Predicate { $0.id == planId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            #if DEBUG
            print("[SyncService] upsertRegimenPlan deferred (table not deployed yet?): \(error)")
            #endif
        }
    }

    @MainActor
    public func hydrateRegimenPlans(userId: String) async {
        struct Row: Decodable {
            let id: String
            let kind: String
            let display_name: String
            let schedule_rule: String
            let anchor_weekday: Int?
            let time_of_day_minutes: Int?
            let dose_stage_label: String?
            let instruction: String?
            let started_at: String?
            let ended_at: String?
            let reminder_enabled: Bool?
            let authority: String?
            let rxnorm_code: String?
            let strength_value: Double?
            let strength_unit: String?
            let source_protocol_id: String?
            let org_id: String?
        }
        do {
            let rows: [Row] = try await supabase.from("regimen_plans")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            let context = modelContainer.mainContext
            let iso = ISO8601DateFormatter()
            let isoFractional = ISO8601DateFormatter()
            isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            func date(_ s: String?) -> Date? {
                s.flatMap { iso.date(from: $0) ?? isoFractional.date(from: $0) }
            }
            for row in rows {
                let rowId = row.id
                let descriptor = FetchDescriptor<RegimenPlanRecord>(
                    predicate: #Predicate { $0.id == rowId }
                )
                if let existing = try? context.fetch(descriptor).first {
                    if existing.userId != userId,
                       existing.userId.lowercased() == userId.lowercased() {
                        existing.userId = userId
                    }
                    // S4: care-team plans are SERVER-AUTHORITATIVE —
                    // a clinician's update (strength, day, instruction,
                    // end) must land on the patient's next hydrate.
                    // Self plans stay client-owned (never clobbered by
                    // a stale cloud row mid-edit).
                    if (row.authority ?? "self") == "care_team" {
                        existing.displayName = row.display_name
                        existing.scheduleRule = row.schedule_rule
                        existing.anchorWeekday = row.anchor_weekday
                        existing.timeOfDayMinutes = row.time_of_day_minutes
                        existing.doseStageLabel = row.dose_stage_label
                        existing.instruction = row.instruction
                        existing.endedAt = date(row.ended_at)
                        existing.authority = "care_team"
                        existing.rxnormCode = row.rxnorm_code
                        existing.strengthValue = row.strength_value
                        existing.strengthUnit = row.strength_unit
                        existing.sourceProtocolId = row.source_protocol_id
                        existing.orgId = row.org_id
                        existing.pendingUpsert = false
                    }
                    continue
                }
                let plan = RegimenPlanRecord(
                    id: row.id,
                    userId: userId,
                    kind: row.kind,
                    displayName: row.display_name,
                    scheduleRule: row.schedule_rule,
                    anchorWeekday: row.anchor_weekday,
                    timeOfDayMinutes: row.time_of_day_minutes,
                    doseStageLabel: row.dose_stage_label,
                    startedAt: date(row.started_at) ?? .now,
                    reminderEnabled: row.reminder_enabled ?? false
                )
                plan.endedAt = date(row.ended_at)
                plan.instruction = row.instruction
                plan.authority = row.authority ?? "self"
                plan.rxnormCode = row.rxnorm_code
                plan.strengthValue = row.strength_value
                plan.strengthUnit = row.strength_unit
                plan.sourceProtocolId = row.source_protocol_id
                plan.orgId = row.org_id
                plan.pendingUpsert = false
                context.insert(plan)
            }
            try? context.save()
        } catch {
            #if DEBUG
            print("[SyncService] hydrateRegimenPlans deferred (table not deployed / no rows): \(error)")
            #endif
        }
    }

    // MARK: - Program plan upsert / fetch (v1.1 program pivot)

    public func upsertProgramPlan(_ plan: ProgramPlanRecord) async {
        let planId = plan.id
        guard !plan.userId.isEmpty else { return }

        let isoStartDate = ISO8601DateFormatter.dateOnly.string(from: plan.startDate)
        let isoGoalDate = ISO8601DateFormatter.dateOnly.string(from: plan.goalDate)
        let payload = SupabaseProgramPlanUpsert(
            id: plan.id,
            user_id: plan.userId,
            started_at: ISO8601DateFormatter().string(from: plan.createdAt),
            start_date: isoStartDate,
            goal_date: isoGoalDate,
            total_days: plan.totalDays,
            current_weight_kg: plan.currentWeightKg,
            goal_weight_kg: plan.goalWeightKg,
            intensity_tier: plan.intensityTier,
            phase: plan.phase,
            parent_plan_id: plan.parentPlanId,
            archived_at: plan.archivedAt.map { ISO8601DateFormatter().string(from: $0) },
            completed_at: plan.completedAt.map { ISO8601DateFormatter().string(from: $0) }
        )

        do {
            try await supabase.from("program_plans")
                .upsert(payload)
                .execute()

            await MainActor.run {
                let descriptor = FetchDescriptor<ProgramPlanRecord>(
                    predicate: #Predicate { $0.id == planId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            #if DEBUG
            print("[SyncService] upsertProgramPlan FAILED for \(planId): \(error)")
            #endif
        }
    }

    @MainActor
    public func hydrateProgramPlans(userId: String) async {
        do {
            let rows: [ProgramPlanHydrateRow] = try await supabase.from("program_plans")
                .select()
                .eq("user_id", value: userId)
                .order("started_at", ascending: false)
                .execute()
                .value

            Self.applyHydratedProgramPlans(rows, userId: userId, context: modelContainer.mainContext)
        } catch {
            #if DEBUG
            print("[SyncService] hydrateProgramPlans FAILED: \(error)")
            #endif
        }
    }

    /// Insert-only merge of cloud plan rows into the local store. Split
    /// from the network fetch so the case rules are unit-testable.
    ///
    /// THE CASE SEAM: program_plans.id / parent_plan_id are uuid columns,
    /// so PostgREST returns them lowercase, while locally-created plans
    /// carry uppercase UUID().uuidString ids, and Swift String == is
    /// case-sensitive. Three rules keep the graph coherent:
    ///   1. userId stores the uppercase `userId` param, NOT row.user_id
    ///      (same reason as hydrateSessionLogs: readers filter with the
    ///      uppercase auth uid, lowercase rows are invisible to them).
    ///   2. Dedupe compares ids case-insensitively, or the same cloud
    ///      plan re-inserts as a duplicate local row every hydrate.
    ///   3. Inserts normalize id + parentPlanId to uppercase so day-check
    ///      pointers and plan chains keep matching with plain ==.
    @MainActor
    static func applyHydratedProgramPlans(
        _ rows: [ProgramPlanHydrateRow], userId: String, context: ModelContext
    ) {
        let locals = (try? context.fetch(FetchDescriptor<ProgramPlanRecord>())) ?? []
        let localsById = Dictionary(grouping: locals, by: { $0.id.uppercased() })

        for row in rows {
            let normalizedId = row.id.uppercased()
            if let variants = localsById[normalizedId] {
                // Already local. A pre-fix hydrate stored this row with a
                // lowercase id + userId, making it invisible to every
                // reader; normalize the casing in place so it surfaces.
                // Identity fields only; data fields stay untouched
                // (insert-only semantics). Skipped when several case
                // variants share the id (the pre-fix duplicate-row shape:
                // the uppercase original is already visible, and re-casing
                // its lowercase twin would collide on the unique id).
                if variants.count == 1, let existing = variants.first,
                   existing.userId != userId,
                   existing.userId.lowercased() == userId.lowercased() {
                    existing.userId = userId
                    existing.id = normalizedId
                    existing.parentPlanId = existing.parentPlanId?.uppercased()
                }
                continue
            }
            let startDate = ISO8601DateFormatter.dateOnly.date(from: row.start_date) ?? .now
            let goalDate = ISO8601DateFormatter.dateOnly.date(from: row.goal_date) ?? .now
            let plan = ProgramPlanRecord(
                id: normalizedId,
                userId: userId,
                startDate: startDate,
                goalDate: goalDate,
                totalDays: row.total_days,
                currentWeightKg: row.current_weight_kg,
                goalWeightKg: row.goal_weight_kg,
                intensityTier: row.intensity_tier,
                phase: row.phase,
                parentPlanId: row.parent_plan_id?.uppercased()
            )
            plan.archivedAt = row.archived_at.flatMap { ISO8601DateFormatter().date(from: $0) }
            plan.completedAt = row.completed_at.flatMap { ISO8601DateFormatter().date(from: $0) }
            plan.pendingUpsert = false
            context.insert(plan)
        }
        try? context.save()
    }

    // MARK: - Program day check upsert / fetch (v1.1 program pivot)

    public func upsertProgramDayCheck(_ check: ProgramDayCheckRecord) async {
        let checkId = check.id
        guard !check.userId.isEmpty else { return }

        let payload = SupabaseProgramDayCheckUpsert(
            id: check.id,
            user_id: check.userId,
            program_plan_id: check.programPlanId,
            program_day: check.programDay,
            item_key: check.itemKey,
            state: check.state,
            completed_at: check.completedAt.map { ISO8601DateFormatter().string(from: $0) }
        )

        do {
            try await supabase.from("program_day_checks")
                .upsert(payload)
                .execute()

            await MainActor.run {
                let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
                    predicate: #Predicate { $0.id == checkId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            #if DEBUG
            print("[SyncService] upsertProgramDayCheck FAILED for \(checkId): \(error)")
            #endif
        }
    }

    @MainActor
    public func hydrateProgramDayChecks(userId: String) async {
        do {
            let rows: [ProgramDayCheckHydrateRow] = try await supabase.from("program_day_checks")
                .select()
                .eq("user_id", value: userId)
                .order("program_day", ascending: true)
                .execute()
                .value

            Self.applyHydratedProgramDayChecks(rows, userId: userId, context: modelContainer.mainContext)
        } catch {
            #if DEBUG
            print("[SyncService] hydrateProgramDayChecks FAILED: \(error)")
            #endif
        }
    }

    /// Insert-only merge of cloud day-check rows. id is a text column, so
    /// it round-trips verbatim and the dedupe stays an exact match, but
    /// user_id AND program_plan_id are uuid columns (lowercase from
    /// PostgREST), so both normalize: userId to the uppercase param (or
    /// hydrated checks are invisible to readers), programPlanId to
    /// uppercase (or the check points at a plan id that no longer
    /// compares equal to the plan hydrate's normalized id).
    @MainActor
    static func applyHydratedProgramDayChecks(
        _ rows: [ProgramDayCheckHydrateRow], userId: String, context: ModelContext
    ) {
        for row in rows {
            let rowId = row.id
            let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
                predicate: #Predicate { $0.id == rowId }
            )
            if let existing = try? context.fetch(descriptor).first {
                // Pre-fix hydrates stored lowercase owner + plan pointer;
                // normalize casing in place so the row surfaces. Identity
                // fields only; data fields keep insert-only semantics.
                if existing.userId != userId,
                   existing.userId.lowercased() == userId.lowercased() {
                    existing.userId = userId
                    existing.programPlanId = existing.programPlanId.uppercased()
                }
                continue
            }
            let check = ProgramDayCheckRecord(
                id: row.id,
                userId: userId,
                programPlanId: row.program_plan_id.uppercased(),
                programDay: row.program_day,
                itemKey: row.item_key,
                state: row.state,
                payload: nil
            )
            check.completedAt = row.completed_at.flatMap { ISO8601DateFormatter().date(from: $0) }
            check.pendingUpsert = false
            context.insert(check)
        }
        try? context.save()
    }

    /// Pull the user's full weight history from Supabase. Used during
    /// hydrate-on-sign-in so the trend chart renders immediately on a
    /// fresh device install.
    @MainActor
    public func hydrateWeightLogs(userId: String) async {
        do {
            let rows: [WeightLogHydrateRow] = try await supabase.from("weight_logs")
                .select()
                .eq("user_id", value: userId)
                .order("logged_at", ascending: true)
                .execute()
                .value

            Self.applyHydratedWeightLogs(rows, userId: userId, context: modelContainer.mainContext)
        } catch {
            #if DEBUG
            print("[SyncService] hydrateWeightLogs FAILED: \(error)")
            #endif
        }
    }

    /// Insert-only merge of cloud weight rows. id is a text column and
    /// round-trips verbatim (exact dedupe), but user_id is uuid
    /// (lowercase from PostgREST), so the record stores the uppercase
    /// `userId` param, NOT row.user_id, or every hydrated weigh-in is
    /// invisible to the trend chart's case-sensitive user filter.
    @MainActor
    static func applyHydratedWeightLogs(
        _ rows: [WeightLogHydrateRow], userId: String, context: ModelContext
    ) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterFallback = ISO8601DateFormatter()

        for row in rows {
            let rowId = row.id   // #Predicate can't capture struct field directly
            let descriptor = FetchDescriptor<WeightLogRecord>(
                predicate: #Predicate { $0.id == rowId }
            )
            if let existing = try? context.fetch(descriptor).first {
                // Pre-fix hydrates stored the lowercase owner; normalize
                // in place so the weigh-in surfaces. Identity field only.
                if existing.userId != userId,
                   existing.userId.lowercased() == userId.lowercased() {
                    existing.userId = userId
                }
                continue   // already local
            }
            let date = formatter.date(from: row.logged_at)
                ?? formatterFallback.date(from: row.logged_at)
                ?? .now
            let log = WeightLogRecord(
                id: row.id,
                userId: userId,
                weightKg: row.weight_kg,
                loggedAt: date,
                source: row.source ?? "manual"
            )
            log.pendingUpsert = false   // came from server, no need to push back
            context.insert(log)
        }
        try? context.save()
    }

    // MARK: - Session rating upsert / fetch
    //
    // The docs claimed session_ratings synced; until now nothing did.
    // The local record's userId is optional (pre-v2 rows were written
    // without it), so ownership derives through the parent
    // SessionLogRecord when missing: the same session-id join the
    // delete-account sweep uses. No resolvable owner, no push (there is
    // nothing for RLS to scope the row to).

    public func upsertSessionRating(_ rating: SessionRatingRecord) async {
        let ratingId = rating.id
        let sessionLogId = rating.sessionLogId
        var userId = rating.userId ?? ""
        if userId.isEmpty {
            userId = await MainActor.run {
                let descriptor = FetchDescriptor<SessionLogRecord>(
                    predicate: #Predicate { $0.id == sessionLogId }
                )
                return (try? modelContainer.mainContext.fetch(descriptor).first)?.userId ?? ""
            }
        }
        guard !userId.isEmpty else { return }

        let payload = SupabaseSessionRatingUpsert(
            id: rating.id,
            user_id: userId,
            session_log_id: rating.sessionLogId,
            rating: rating.rating,
            tags: rating.tags,
            created_at: ISO8601DateFormatter().string(from: rating.createdAt)
        )

        do {
            try await supabase.from("session_ratings")
                .upsert(payload)
                .execute()

            await MainActor.run {
                let descriptor = FetchDescriptor<SessionRatingRecord>(
                    predicate: #Predicate { $0.id == ratingId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            #if DEBUG
            print("[SyncService] upsertSessionRating FAILED for \(ratingId): \(error)")
            #endif
        }
    }

    @MainActor
    public func hydrateSessionRatings(userId: String) async {
        do {
            let rows: [SessionRatingHydrateRow] = try await supabase.from("session_ratings")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: true)
                .execute()
                .value

            Self.applyHydratedSessionRatings(rows, userId: userId, context: modelContainer.mainContext)
        } catch {
            #if DEBUG
            print("[SyncService] hydrateSessionRatings FAILED: \(error)")
            #endif
        }
    }

    /// Insert-only merge of cloud rating rows. id + session_log_id are
    /// text columns (verbatim round-trip, exact dedupe); user_id is uuid
    /// (lowercase from PostgREST), so the record stores the uppercase
    /// `userId` param, same rule as every other hydrate.
    @MainActor
    static func applyHydratedSessionRatings(
        _ rows: [SessionRatingHydrateRow], userId: String, context: ModelContext
    ) {
        for row in rows {
            let rowId = row.id
            let descriptor = FetchDescriptor<SessionRatingRecord>(
                predicate: #Predicate { $0.id == rowId }
            )
            if let existing = try? context.fetch(descriptor).first {
                // Back-fill a missing / lowercase owner. The cloud row was
                // fetched BY this user_id, so ownership is authoritative.
                if existing.userId == nil
                    || existing.userId?.lowercased() == userId.lowercased() {
                    existing.userId = userId
                }
                continue
            }
            let record = SessionRatingRecord(
                id: row.id,
                userId: userId,
                sessionLogId: row.session_log_id,
                rating: row.rating,
                tags: row.tags
            )
            record.createdAt = row.created_at
            record.pendingUpsert = false   // came from server
            context.insert(record)
        }
        try? context.save()
    }

    // MARK: - Food logs (v1.1 — journal sync)
    //
    // The food journal lives in PlankFood's JSONL store, not SwiftData,
    // so this section trades the record-type pattern for a plain
    // Codable row. Title rides in the payload jsonb column (food_logs
    // has no title column; payload is the designated evolving-field
    // home per the schema comment).

    public struct FoodLogSyncRow: Codable, Sendable {
        public let id: String
        public let user_id: String
        public let logged_at: String
        public let kcal_total: Double
        public let protein_g: Double?
        public let carbs_g: Double?
        public let fat_g: Double?
        public let fiber_g: Double?
        /// v1.1.5 — sugar joins the synced macros (food_logs.sugar_g).
        /// Optional + decode-tolerant: rows written before the column
        /// existed decode nil, so a hydrate never breaks on old data.
        public let sugar_g: Double?
        public let source: String
        public let payload: Payload?

        public struct Payload: Codable, Sendable {
            public let title: String?
            public init(title: String?) { self.title = title }
        }

        public init(
            id: String, user_id: String, logged_at: String,
            kcal_total: Double, protein_g: Double?, carbs_g: Double?,
            fat_g: Double?, fiber_g: Double?, sugar_g: Double?, source: String,
            payload: Payload?
        ) {
            self.id = id
            self.user_id = user_id
            self.logged_at = logged_at
            self.kcal_total = kcal_total
            self.protein_g = protein_g
            self.carbs_g = carbs_g
            self.fat_g = fat_g
            self.fiber_g = fiber_g
            self.sugar_g = sugar_g
            self.source = source
            self.payload = payload
        }

        // Decode-tolerant: sugar_g is absent from rows written before the
        // column shipped; treat a missing key as nil rather than failing.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            user_id = try c.decode(String.self, forKey: .user_id)
            logged_at = try c.decode(String.self, forKey: .logged_at)
            kcal_total = try c.decode(Double.self, forKey: .kcal_total)
            protein_g = try? c.decode(Double.self, forKey: .protein_g)
            carbs_g = try? c.decode(Double.self, forKey: .carbs_g)
            fat_g = try? c.decode(Double.self, forKey: .fat_g)
            fiber_g = try? c.decode(Double.self, forKey: .fiber_g)
            sugar_g = try? c.decode(Double.self, forKey: .sugar_g)
            source = (try? c.decode(String.self, forKey: .source)) ?? "photo"
            payload = try? c.decode(Payload.self, forKey: .payload)
        }
    }

    public func upsertFoodLog(_ row: FoodLogSyncRow) async {
        guard !row.user_id.isEmpty else { return }
        do {
            try await supabase.from("food_logs")
                .upsert(row)
                .execute()
        } catch {
            #if DEBUG
            print("[SyncService] upsertFoodLog FAILED for \(row.id): \(error)")
            #endif
        }
    }

    public func deleteFoodLog(id: String) async {
        do {
            // RLS delete_own policy scopes the delete to auth.uid();
            // no explicit user_id filter needed (and adding one would
            // break for the re-attributed sign-in merge case).
            try await supabase.from("food_logs")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            #if DEBUG
            print("[SyncService] deleteFoodLog FAILED for \(id): \(error)")
            #endif
        }
    }

    public func fetchFoodLogs(userId: String) async -> [FoodLogSyncRow] {
        do {
            // `.select()` (all columns) rather than an explicit list so a
            // freshly-added column like sugar_g never has to be present
            // for the read to work — the decoder tolerates its absence.
            let rows: [FoodLogSyncRow] = try await supabase.from("food_logs")
                .select()
                .eq("user_id", value: userId)
                .order("logged_at", ascending: true)
                .execute()
                .value
            return rows
        } catch {
            #if DEBUG
            print("[SyncService] fetchFoodLogs FAILED: \(error)")
            #endif
            return []
        }
    }
}

// MARK: - Supabase row types

/// Typed upsert payload for public.session_logs. Numeric fields are real
/// JSON numbers, optionals are JSON null when nil, exercise_results is a
/// proper JSON array (jsonb column). Property names use snake_case to map
/// directly to the columns without relying on encoder strategy.
private struct SupabaseDayReflectionUpsert: Encodable {
    let id: String
    let user_id: String
    let day_key: String
    let feeling: String
    let note: String?
}

private struct SupabaseSessionLogUpsert: Encodable {
    let id: String
    let user_id: String
    let exercise_type: String
    let session_type: String
    let completed_at: String
    let hold_time: Double
    let target_time: Double
    let quality_score: Double
    let form_faults_count: Int
    let modified_version: Bool
    let preset_id: String?
    let total_duration: Double?
    let plank_hold_time: Double?
    let plank_form_score: Double?
    let exercise_results: [ExerciseResultEntry]?
}

/// Typed upsert payload for public.weight_logs. Append-only history; client
/// UUID id so retries idempotently upsert. See
/// `docs/weight_loss_analytics_research.md` for the analytics design that
/// reads this table.
private struct SupabaseWeightLogUpsert: Encodable {
    let id: String
    let user_id: String
    let weight_kg: Double
    let logged_at: String
    let source: String
}

/// Typed upsert payload for public.program_plans. v1.1 program pivot.
/// dates are pre-formatted strings — start_date / goal_date are
/// yyyy-MM-dd (date column), the rest are ISO8601 timestamps.
private struct SupabaseProgramPlanUpsert: Encodable {
    let id: String
    let user_id: String
    let started_at: String
    let start_date: String
    let goal_date: String
    let total_days: Int
    let current_weight_kg: Double?
    let goal_weight_kg: Double?
    let intensity_tier: String
    let phase: String
    let parent_plan_id: String?
    let archived_at: String?
    let completed_at: String?
}

/// Typed upsert payload for public.program_day_checks. v1.1 program pivot.
/// Phase 1 sends payload as nil; Phase 2 will populate it with the
/// resolved WorkoutPreset to kill WorkoutGenerator non-determinism.
private struct SupabaseProgramDayCheckUpsert: Encodable {
    let id: String
    let user_id: String
    let program_plan_id: String
    let program_day: Int
    let item_key: String
    let state: String
    let completed_at: String?
}

/// Typed upsert payload for public.session_ratings. user_id derives from
/// the record's own userId or the parent SessionLogRecord (pre-v2 rows
/// carry no owner); created_at rides along so the cloud keeps the
/// original rating moment across retries.
private struct SupabaseSessionRatingUpsert: Encodable {
    let id: String
    let user_id: String
    let session_log_id: String
    let rating: Int
    let tags: [String]
    let created_at: String
}

// MARK: - Hydrate row types
//
// Internal (not private) so the apply* merge functions are unit-testable
// with hand-built rows; the network fetch is the only untested seam.
// snake_case fields map straight onto the columns.

struct WeightLogHydrateRow: Decodable {
    let id: String
    let user_id: String
    let weight_kg: Double
    let logged_at: String
    let source: String?
}

struct ProgramPlanHydrateRow: Decodable {
    let id: String
    let user_id: String
    let start_date: String
    let goal_date: String
    let total_days: Int
    let current_weight_kg: Double?
    let goal_weight_kg: Double?
    let intensity_tier: String
    let phase: String
    let parent_plan_id: String?
    let archived_at: String?
    let completed_at: String?
}

struct ProgramDayCheckHydrateRow: Decodable {
    let id: String
    let user_id: String
    let program_plan_id: String
    let program_day: Int
    let item_key: String
    let state: String
    let completed_at: String?
}

struct SessionRatingHydrateRow: Decodable {
    let id: String
    let user_id: String
    let session_log_id: String
    let rating: Int
    let tags: [String]
    let created_at: Date
}

/// Date-only formatter for Postgres `date` columns (yyyy-MM-dd, UTC).
/// Used by ProgramPlan upsert/hydrate where start_date + goal_date
/// are calendar dates, not timestamps.
extension ISO8601DateFormatter {
    fileprivate static let dateOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withYear, .withMonth, .withDay, .withDashSeparatorInDate]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

/// Typed upsert payload for public.day_progress. Composite primary key
/// (user_id, program_day) — PostgREST handles the upsert conflict resolution.
/// session_log_ids is the new text[] column; was missing from the dict-based
/// upsert, so all prior runs left it null on the server.
private struct SupabaseDayProgressUpsert: Encodable {
    let user_id: String
    let program_day: Int
    let date: String
    let primary_session_id: String
    let primary_quality_score: Double
    let primary_hold_time: Double
    let updated_at: String
    let session_log_ids: [String]?
}

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
    // Phase 4 additions — keep nil for legacy rows so the upsert is
    // null-safe across DB columns added 2026-05-04.
    let onboarding_body_focus: [String]?
    let onboarding_current_weight_kg: Double?
    let onboarding_goal_weight_kg: Double?
    // Phase 4 remaining 11 fields (2026-05-04 second migration).
    let onboarding_motivation: String?
    let onboarding_workout_location: String?
    let onboarding_workout_style: [String]?
    let onboarding_gender: String?
    let onboarding_height_cm: Double?
    let onboarding_body_type_current: Int?
    let onboarding_body_type_desired: Int?
    let onboarding_identity_feeling: String?
    let onboarding_reward_choice: String?
    let onboarding_relatability_1: Bool?
    let onboarding_relatability_2: Bool?
    let onboarding_relatability_3: Bool?
    /// 2026-05-30 (epic #1 child #7) — TikTok/IG/friend attribution.
    let onboarding_acquisition_source: String?
    /// 2026-06-23 — cohort + clinical intake (persistence P0). Nullable text.
    let onboarding_glp1_status: String?
    let onboarding_glp1_phase: String?
    let onboarding_hormonal_stage: String?
    let onboarding_weight_trend: String?
    let onboarding_sleep_hours: String?
    let onboarding_stress_level: String?
    let onboarding_eating_cadence: String?
    let onboarding_eating_window: String?
    let onboarding_food_relationship: String?
    /// Phase 1a (2026-06-28) - clinical baseline + activation counter.
    /// Dates are ISO8601 strings to match the existing convention.
    /// promises_kept is non-optional with default 0 so existing rows keep working.
    let computed_start_bmi: Double?
    let target_rate_pct_per_week: Double?
    let medical_disclaimer_ack_at: String?
    let promises_kept: Int
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
    // Phase 4 additions — optional / array-with-empty-default so legacy
    // rows that lack these columns decode cleanly.
    let onboardingBodyFocus: [String]?
    let onboardingCurrentWeightKg: Double?
    let onboardingGoalWeightKg: Double?
    // Phase 4 remaining 11 fields (2026-05-04 second migration).
    let onboardingMotivation: String?
    let onboardingWorkoutLocation: String?
    let onboardingWorkoutStyle: [String]?
    let onboardingGender: String?
    let onboardingHeightCm: Double?
    let onboardingBodyTypeCurrent: Int?
    let onboardingBodyTypeDesired: Int?
    let onboardingIdentityFeeling: String?
    let onboardingRewardChoice: String?
    let onboardingRelatability1: Bool?
    let onboardingRelatability2: Bool?
    let onboardingRelatability3: Bool?
    /// 2026-05-30 (epic #1 child #7) — TikTok/IG/friend attribution.
    let onboardingAcquisitionSource: String?
    /// 2026-06-23 — cohort + clinical intake (persistence P0).
    let onboardingGlp1Status: String?
    let onboardingGlp1Phase: String?
    let onboardingHormonalStage: String?
    let onboardingWeightTrend: String?
    let onboardingSleepHours: String?
    let onboardingStressLevel: String?
    let onboardingEatingCadence: String?
    let onboardingEatingWindow: String?
    let onboardingFoodRelationship: String?
    /// Phase 1a (2026-06-28) - clinical baseline + activation counter.
    /// Optional so legacy rows that lack these columns decode cleanly.
    /// promisesKept is Int? here; hydrate coalesces nil to 0.
    let computedStartBMI: Double?
    let targetRatePctPerWeek: Double?
    let medicalDisclaimerAckAt: Date?
    let promisesKept: Int?

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
        case onboardingBodyFocus = "onboarding_body_focus"
        case onboardingCurrentWeightKg = "onboarding_current_weight_kg"
        case onboardingGoalWeightKg = "onboarding_goal_weight_kg"
        case onboardingMotivation = "onboarding_motivation"
        case onboardingWorkoutLocation = "onboarding_workout_location"
        case onboardingWorkoutStyle = "onboarding_workout_style"
        case onboardingGender = "onboarding_gender"
        case onboardingHeightCm = "onboarding_height_cm"
        case onboardingBodyTypeCurrent = "onboarding_body_type_current"
        case onboardingBodyTypeDesired = "onboarding_body_type_desired"
        case onboardingIdentityFeeling = "onboarding_identity_feeling"
        case onboardingRewardChoice = "onboarding_reward_choice"
        case onboardingRelatability1 = "onboarding_relatability_1"
        case onboardingRelatability2 = "onboarding_relatability_2"
        case onboardingRelatability3 = "onboarding_relatability_3"
        case onboardingAcquisitionSource = "onboarding_acquisition_source"
        case onboardingGlp1Status = "onboarding_glp1_status"
        case onboardingGlp1Phase = "onboarding_glp1_phase"
        case onboardingHormonalStage = "onboarding_hormonal_stage"
        case onboardingWeightTrend = "onboarding_weight_trend"
        case onboardingSleepHours = "onboarding_sleep_hours"
        case onboardingStressLevel = "onboarding_stress_level"
        case onboardingEatingCadence = "onboarding_eating_cadence"
        case onboardingEatingWindow = "onboarding_eating_window"
        case onboardingFoodRelationship = "onboarding_food_relationship"
        // Phase 1a (2026-06-28)
        case computedStartBMI = "computed_start_bmi"
        case targetRatePctPerWeek = "target_rate_pct_per_week"
        case medicalDisclaimerAckAt = "medical_disclaimer_ack_at"
        case promisesKept = "promises_kept"
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
    let sessionLogIds: [String]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case programDay = "program_day"
        case date
        case primarySessionId = "primary_session_id"
        case primaryQualityScore = "primary_quality_score"
        case primaryHoldTime = "primary_hold_time"
        case updatedAt = "updated_at"
        case sessionLogIds = "session_log_ids"
    }
}
