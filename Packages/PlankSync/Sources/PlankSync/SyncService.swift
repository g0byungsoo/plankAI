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

    // MARK: - Structural failure seam (v25 §45)

    /// **A STRUCTURAL SERVER REFUSAL MUST NOT DISAPPEAR INTO A `try?`.**
    ///
    /// `44` found E1's two families returning `42501` on every write and
    /// every hydrate since 2026-08-10 — for everyone, for five days —
    /// with no evidence anywhere, because the write is fire-and-forget
    /// and the hydrate's `catch` only prints under DEBUG. The missing
    /// grant was one defect; a refusal that can only be seen with a
    /// debugger attached was the reason it survived.
    ///
    /// The package reports the FAMILY and the CODE, and nothing else.
    /// It does not report the server's message or hint (PostgREST's
    /// 42501 hint prints the exact `GRANT` and names the table), it does
    /// not report a row, an id or a uid, and it decides nothing: the
    /// classification, the bound and the destination are the app's
    /// (`SyncHealth`). A host that installs no reporter behaves exactly
    /// as before.
    public nonisolated(unsafe) static var structuralFailureReporter:
        (@Sendable (String, String) -> Void)?

    /// Reduces any thrown error to a machine token. `PostgrestError`
    /// carries the SQLSTATE / PGRST code; a `URLError` is this client's
    /// own `urlerror`; everything else is `unknown` and — by
    /// `SyncFailureClassifier`'s deliberate polarity — is reported
    /// rather than assumed harmless.
    nonisolated static func reportStructuralFailure(_ family: String, _ error: Error) {
        guard let reporter = structuralFailureReporter else { return }
        let code: String
        if let postgrest = error as? PostgrestError {
            code = postgrest.code ?? "unknown"
        } else if error is URLError {
            code = "urlerror"
        } else if (error as NSError).domain == NSURLErrorDomain {
            code = "urlerror"
        } else {
            code = "unknown"
        }
        reporter(family, code)
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

    /// THE TRUTH REFRESH — the two tables that carry every
    /// program-critical fact about a person, and nothing else.
    ///
    /// The full `hydrateAndSync` pass runs at sign-in, and on launch only
    /// when some synced family is locally EMPTY. A settled paying user
    /// has none, so for her the launch hydrate never fires and the only
    /// route a server-side repair had to her phone was a sign-out. That
    /// is why the customer whose database row was corrected went on
    /// seeing the old number.
    ///
    /// Two selects, throttled to once a day by the caller. Deliberately
    /// NOT the full hydrate: sessions, checks, reflections and the food
    /// journal are append-only history and do not need re-reading to
    /// answer "what is my plan".
    @MainActor
    public func hydrateProgramTruth(userId: String) async {
        guard !userId.isEmpty else { return }
        await hydrateUser(userId: userId)
        await hydrateProgramPlans(userId: userId)
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
                // Release audit 2026-08-08 — same guard session logs
                // have had all along (their hydrate skips rows with
                // pendingUpsert): if a local profile edit hasn't landed
                // yet, copying the server row over it reverts the edit
                // and the still-true flag later pushes the REVERTED
                // values. The retry that runs before hydrate usually
                // clears the flag; this closes the window where the
                // push failed but the pull succeeded.
                guard !existing.pendingUpsert else {
                    #if DEBUG
                    print("[SyncService] hydrateUser: SKIP — local edit pending upsert")
                    #endif
                    return
                }
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
            Self.applyHydratedUser(row, to: target)

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

    /// The profile adoption rules, split from the network fetch so
    /// they are unit-testable (pass 51 — the applyHydrated* pattern).
    ///
    /// **AN ABSENT SERVER VALUE IS NEVER ADOPTED.** Non-optional wire
    /// columns copy unconditionally (the server always holds a value);
    /// every OPTIONAL column adopts only when PRESENT. This used to be
    /// an unconditional column copy, and a legacy row's NULLs erased
    /// local facts — `onboardingGender` blanked to "" (the BMR's sex
    /// input), `onboardingHeightCm` to nil (the energy math's input),
    /// `promisesKept` to 0 — after which the still-populated
    /// `upsertUser` pushed the erased values back, converting one
    /// missing column into a durable loss loop. Same law as the
    /// defaults mirror (`AppSync.restoreCohortDefaults`) and
    /// `ProgramPlanMerge`'s user facts.
    @MainActor
    static func applyHydratedUser(_ row: SupabaseUserRow, to target: UserRecord) {
        // Non-optional on the wire — always present, always adopted.
        target.name = row.name
        target.startDate = row.startDate
        target.currentDay = row.currentDay
        target.coreScore = row.coreScore
        target.streakCurrent = row.streakCurrent
        target.streakLongest = row.streakLongest
        target.programPhase = row.programPhase
        target.onboardingNotificationEnabled = row.onboardingNotificationEnabled

        func adopt<T>(_ value: T?, _ keyPath: ReferenceWritableKeyPath<UserRecord, T>) {
            if let value { target[keyPath: keyPath] = value }
        }
        func adoptOptional<T>(_ value: T?, _ keyPath: ReferenceWritableKeyPath<UserRecord, T?>) {
            if let value { target[keyPath: keyPath] = value }
        }

        adoptOptional(row.lastSessionDate, \.lastSessionDate)
        adoptOptional(row.streakLastResetDate, \.streakLastResetDate)
        adoptOptional(row.foundationsCompletedDate, \.foundationsCompletedDate)
        adoptOptional(row.onboardingGoal, \.onboardingGoal)
        adoptOptional(row.onboardingExperience, \.onboardingExperience)
        adoptOptional(row.onboardingBaselineHoldSeconds, \.onboardingBaselineHoldSeconds)
        adoptOptional(row.onboardingBarriers, \.onboardingBarriers)
        adoptOptional(row.onboardingAgeRange, \.onboardingAgeRange)
        adoptOptional(row.onboardingActivityLevel, \.onboardingActivityLevel)
        adoptOptional(row.onboardingCommitmentDaysPerWeek, \.onboardingCommitmentDaysPerWeek)
        adoptOptional(row.onboardingNotificationTime, \.onboardingNotificationTime)
        adoptOptional(row.onboardingVoicePreference, \.onboardingVoicePreference)
        adoptOptional(row.onboardingFocusArea, \.onboardingFocusArea)
        adoptOptional(row.onboardingPlankTime, \.onboardingPlankTime)
        adoptOptional(row.onboardingSessionLengthPref, \.onboardingSessionLengthPref)
        adopt(row.onboardingBodyFocus, \.onboardingBodyFocus)
        adoptOptional(row.onboardingCurrentWeightKg, \.onboardingCurrentWeightKg)
        adoptOptional(row.onboardingGoalWeightKg, \.onboardingGoalWeightKg)
        adopt(row.onboardingMotivation, \.onboardingMotivation)
        adopt(row.onboardingWorkoutLocation, \.onboardingWorkoutLocation)
        adopt(row.onboardingWorkoutStyle, \.onboardingWorkoutStyle)
        adopt(row.onboardingGender, \.onboardingGender)
        adoptOptional(row.onboardingHeightCm, \.onboardingHeightCm)
        adoptOptional(row.onboardingBodyTypeCurrent, \.onboardingBodyTypeCurrent)
        adoptOptional(row.onboardingBodyTypeDesired, \.onboardingBodyTypeDesired)
        adopt(row.onboardingIdentityFeeling, \.onboardingIdentityFeeling)
        adopt(row.onboardingRewardChoice, \.onboardingRewardChoice)
        adoptOptional(row.onboardingRelatability1, \.onboardingRelatability1)
        adoptOptional(row.onboardingRelatability2, \.onboardingRelatability2)
        adoptOptional(row.onboardingRelatability3, \.onboardingRelatability3)
        adoptOptional(row.onboardingAcquisitionSource, \.onboardingAcquisitionSource)
        adoptOptional(row.onboardingGlp1Status, \.onboardingGlp1Status)
        adoptOptional(row.onboardingGlp1Phase, \.onboardingGlp1Phase)
        adoptOptional(row.onboardingHormonalStage, \.onboardingHormonalStage)
        adoptOptional(row.onboardingWeightTrend, \.onboardingWeightTrend)
        adoptOptional(row.onboardingSleepHours, \.onboardingSleepHours)
        adoptOptional(row.onboardingStressLevel, \.onboardingStressLevel)
        adoptOptional(row.onboardingEatingCadence, \.onboardingEatingCadence)
        adoptOptional(row.onboardingEatingWindow, \.onboardingEatingWindow)
        adoptOptional(row.onboardingFoodRelationship, \.onboardingFoodRelationship)
        adoptOptional(row.computedStartBMI, \.computedStartBMI)
        adoptOptional(row.targetRatePctPerWeek, \.targetRatePctPerWeek)
        adoptOptional(row.medicalDisclaimerAckAt, \.medicalDisclaimerAckAt)
        adopt(row.promisesKept, \.promisesKept)
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
                        // Pass 51 — the per-exercise breakdown comes
                        // home too (present-only: a legacy NULL column
                        // must not erase a local breakdown).
                        if let results = row.exerciseResults {
                            existing.exerciseResults = try? JSONEncoder().encode(results)
                        }
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
                        exerciseResults: row.exerciseResults.flatMap {
                            try? JSONEncoder().encode($0)
                        },
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

        // Release audit 2026-08-08 — the v8 care chart was never in
        // this sweep: observations (dose marks, sit-checks), regimen
        // plans, and consent grants each got exactly ONE fire-and-
        // forget push at write time, so an offline medication plan or
        // dose mark stayed device-only forever (and a consent grant
        // that never landed silently blocked the RLS-gated packet /
        // weekly-summary publishes). The upserts below already clear
        // pendingUpsert on success — the sweep is all that was missing.
        let observationDescriptor = FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(observationDescriptor) {
            for observation in pending {
                await upsertObservation(observation)
            }
        }

        let regimenDescriptor = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(regimenDescriptor) {
            for plan in pending {
                await upsertRegimenPlan(plan)
            }
        }

        let consentDescriptor = FetchDescriptor<ConsentGrantRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(consentDescriptor) {
            for grant in pending {
                await upsertConsentGrant(grant)
            }
        }

        // v24 THE REGIMEN — dose events ride the same sweep from
        // day one (the 2026-08-08 audit lesson, pre-applied).
        let doseDescriptor = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(doseDescriptor) {
            for event in pending {
                await upsertDoseEvent(event)
            }
        }

        // v25 E1 THE SPINE — program facts ride the sweep from day
        // one (same audit law: no fire-and-forget-only families).
        let factDescriptor = FetchDescriptor<ProgramFactRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(factDescriptor) {
            for fact in pending {
                await upsertProgramFact(fact)
            }
        }

        let readDescriptor = FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.pendingUpsert == true }
        )
        if let pending = try? context.fetch(readDescriptor) {
            for read in pending {
                await upsertWeeklyRead(read)
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
                    // Pass 51 — UNKNOWN STAYS UNKNOWN: these rows reach
                    // the clinician packet; "manual" is an authorship
                    // claim, not a default.
                    source: row.source ?? "unknown"
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

    /// v25 §38 — THE MISSING HALF OF THE CONSENT SEAM.
    ///
    /// `upsertConsentGrant` has shipped since v8 S3 with no read-back,
    /// so `ConsentGrantRecord` was the one durable answer the customer
    /// gives that never came home. On a second phone
    /// `ConsentService.activeGrant` returned nil while the server row
    /// still said granted, so:
    ///
    ///   · the visit-packet toggle showed a DEVICE fact where she reads
    ///     an ACCOUNT fact,
    ///   · `revoke()` no-opped, because it needs a local active grant,
    ///   · and `grant()` — idempotent only against the local store —
    ///     inserted a SECOND active row for one decision.
    ///
    /// Insert-only by id, and `revokedAt` rides the row, so a revoke
    /// made on any device is visible on every device that hydrates
    /// after it. No migration: `consent_grants_select_own` and the
    /// `select` grant to `authenticated` have shipped since
    /// `20260729120000_s3_consent_grants.sql`; there is no delete
    /// policy and none is needed, because revocation is a timestamp.
    ///
    /// MONOTONIC IN THE SAFE DIRECTION: this can only ever ADD
    /// knowledge of a grant or of its revocation. A failed read leaves
    /// the toggle OFF, because unknown consent is never permission.
    @MainActor
    public func hydrateConsentGrants(userId: String) async {
        guard !userId.isEmpty else { return }
        struct Row: Decodable {
            let id: String
            let scope: String
            let purpose: String
            let granted_at: String
            let revoked_at: String?
            let org_id: String?
        }
        do {
            let rows: [Row] = try await supabase.from("consent_grants")
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
                let descriptor = FetchDescriptor<ConsentGrantRecord>(
                    predicate: #Predicate { $0.id == rowId }
                )
                if let existing = try? context.fetch(descriptor).first {
                    // Same case-normalisation every hydrate beside this
                    // one carries: user_id comes back lowercase from
                    // PostgREST and the readers filter case-sensitively.
                    if existing.userId != userId,
                       existing.userId.lowercased() == userId.lowercased() {
                        existing.userId = userId
                    }
                    // A revocation that reached the server on another
                    // device is the one field that must land on a row
                    // this device already holds — otherwise the phone
                    // that granted it can never learn it was withdrawn.
                    // One direction only: granted → revoked, never back.
                    if existing.revokedAt == nil, let revoked = date(row.revoked_at),
                       !existing.pendingUpsert {
                        existing.revokedAt = revoked
                    }
                    continue
                }
                let record = ConsentGrantRecord(
                    id: row.id, userId: userId,
                    scope: row.scope, purpose: row.purpose
                )
                record.grantedAt = date(row.granted_at) ?? .now
                record.revokedAt = date(row.revoked_at)
                record.orgId = row.org_id
                record.pendingUpsert = false
                context.insert(record)
            }
            try? context.save()
        } catch {
            #if DEBUG
            print("[SyncService] hydrateConsentGrants deferred: \(error)")
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

    /// v9 P6 — the weekly-summary series (care_weekly_summaries;
    /// publish-only from the patient, the visit_packets stance —
    /// RLS requires her active packet consent, so a revoked patient
    /// can't publish even if this fires).
    public func publishWeeklySummary(
        id: String, userId: String, orgId: String,
        weekKey: String, payload: Data, appVersion: String?
    ) async {
        guard !userId.isEmpty, !orgId.isEmpty else { return }
        struct Upsert: Encodable {
            let id: String
            let user_id: String
            let org_id: String
            let week_key: String
            let payload: AnyJSON
            let app_version: String?
        }
        guard let json = try? JSONDecoder().decode(AnyJSON.self, from: payload) else { return }
        let row = Upsert(
            id: id, user_id: userId, org_id: orgId,
            week_key: weekKey, payload: json, app_version: appVersion
        )
        do {
            try await supabase.from("care_weekly_summaries").upsert(row).execute()
        } catch {
            #if DEBUG
            print("[SyncService] publishWeeklySummary deferred (no consent / un-migrated / offline): \(error)")
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
            let second_anchor_weekday: Int?
            let interval_days: Int?
            let anchor_date: String?
            let treatment_started_on: String?
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
            // v24 THE REGIMEN — additive columns; the server
            // ignores unknown keys ONLY after the founder applies
            // 20260809 migration, so these ship together with it.
            let product_id: String?
            let route: String?
            let previous_plan_id: String?
            let end_reason: String?
        }
        let iso = ISO8601DateFormatter()
        let payload = SupabaseRegimenPlanUpsert(
            id: plan.id,
            user_id: plan.userId,
            kind: plan.kind,
            display_name: plan.displayName,
            schedule_rule: plan.scheduleRule,
            anchor_weekday: plan.anchorWeekday,
            second_anchor_weekday: plan.secondAnchorWeekday,
            interval_days: plan.intervalDays,
            anchor_date: plan.anchorDayKey,
            treatment_started_on: plan.treatmentStartedOn,
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
            org_id: plan.orgId,
            product_id: plan.productId,
            route: plan.route,
            previous_plan_id: plan.previousPlanId,
            end_reason: plan.endReason
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
            let second_anchor_weekday: Int?
            let interval_days: Int?
            let anchor_date: String?
            let treatment_started_on: String?
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
            let product_id: String?
            let route: String?
            let previous_plan_id: String?
            let end_reason: String?
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
                        existing.secondAnchorWeekday = row.second_anchor_weekday
                        existing.intervalDays = row.interval_days
                        existing.anchorDayKey = row.anchor_date
                        // treatmentStartedOn is HER biographical fact
                        // — a clinic update never erases it (present-
                        // only adoption, the pass-51 law).
                        if let stated = row.treatment_started_on {
                            existing.treatmentStartedOn = stated
                        }
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
                        existing.productId = row.product_id
                        existing.route = row.route
                        existing.previousPlanId = row.previous_plan_id
                        existing.endReason = row.end_reason
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
                plan.secondAnchorWeekday = row.second_anchor_weekday
                plan.intervalDays = row.interval_days
                plan.anchorDayKey = row.anchor_date
                plan.treatmentStartedOn = row.treatment_started_on
                plan.authority = row.authority ?? "self"
                plan.rxnormCode = row.rxnorm_code
                plan.strengthValue = row.strength_value
                plan.strengthUnit = row.strength_unit
                plan.sourceProtocolId = row.source_protocol_id
                plan.orgId = row.org_id
                plan.productId = row.product_id
                plan.route = row.route
                plan.previousPlanId = row.previous_plan_id
                plan.endReason = row.end_reason
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

    // MARK: - Program facts (app v25 E1 THE SPINE)

    public func upsertProgramFact(_ fact: ProgramFactRecord) async {
        let factId = fact.id
        guard !fact.userId.isEmpty else { return }
        struct SupabaseProgramFactUpsert: Encodable {
            let id: String
            let user_id: String
            let kind: String
            let value: String
            let authority: String
            let basis: String
            let source: String
            let previous_fact_id: String?
            let accepted_at: String?
            let ended_at: String?
            let end_reason: String?
        }
        let iso = ISO8601DateFormatter()
        let payload = SupabaseProgramFactUpsert(
            id: fact.id,
            user_id: fact.userId,
            kind: fact.kind,
            value: fact.value,
            authority: fact.authority,
            basis: fact.basis,
            source: fact.source,
            previous_fact_id: fact.previousFactId,
            accepted_at: fact.acceptedAt.map { iso.string(from: $0) },
            ended_at: fact.endedAt.map { iso.string(from: $0) },
            end_reason: fact.endReason
        )
        do {
            try await supabase.from("program_facts")
                .upsert(payload)
                .execute()
            await MainActor.run {
                let descriptor = FetchDescriptor<ProgramFactRecord>(
                    predicate: #Predicate { $0.id == factId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            Self.reportStructuralFailure("program_facts", error)
            #if DEBUG
            print("[SyncService] upsertProgramFact deferred (table not deployed yet?): \(error)")
            #endif
        }
    }

    @MainActor
    public func hydrateProgramFacts(userId: String) async {
        struct Row: Decodable {
            let id: String
            let kind: String
            let value: String
            let authority: String?
            let basis: String?
            let source: String?
            let previous_fact_id: String?
            let accepted_at: String?
            let ended_at: String?
            let end_reason: String?
        }
        do {
            let rows: [Row] = try await supabase.from("program_facts")
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
                let descriptor = FetchDescriptor<ProgramFactRecord>(
                    predicate: #Predicate { $0.id == rowId }
                )
                if let existing = try? context.fetch(descriptor).first {
                    if existing.userId != userId,
                       existing.userId.lowercased() == userId.lowercased() {
                        existing.userId = userId
                    }
                    // Authority law (mirrors regimen S4): PRESCRIBED
                    // rows are SERVER-AUTHORITATIVE — a clinician's
                    // change or revocation must land on the next
                    // hydrate. Every other authority is client-owned
                    // (never clobbered by a stale cloud row).
                    if (row.authority ?? "") == "prescribed" {
                        existing.value = row.value
                        existing.basis = row.basis ?? existing.basis
                        existing.source = row.source ?? existing.source
                        existing.previousFactId = row.previous_fact_id
                        existing.acceptedAt = date(row.accepted_at)
                        existing.endedAt = date(row.ended_at)
                        existing.endReason = row.end_reason
                        existing.pendingUpsert = false
                    }
                    continue
                }
                let fact = ProgramFactRecord(
                    id: row.id,
                    userId: userId,
                    kind: row.kind,
                    value: row.value,
                    authority: row.authority ?? "preferred",
                    basis: row.basis ?? "stated",
                    source: row.source ?? "sync",
                    previousFactId: row.previous_fact_id,
                    acceptedAt: date(row.accepted_at)
                )
                fact.endedAt = date(row.ended_at)
                fact.endReason = row.end_reason
                fact.pendingUpsert = false
                context.insert(fact)
            }
            try? context.save()
        } catch {
            Self.reportStructuralFailure("program_facts", error)
            #if DEBUG
            print("[SyncService] hydrateProgramFacts deferred (table not deployed / no rows): \(error)")
            #endif
        }
    }

    public func upsertWeeklyRead(_ read: WeeklyReadRecord) async {
        let readId = read.id
        guard !read.userId.isEmpty else { return }
        struct SupabaseWeeklyReadUpsert: Encodable {
            let id: String
            let user_id: String
            let window_start_day: String
            let anchor: String
            let shown: String?
            let offer_key: String
            let decision: String
            let fact_id: String?
            let decided_at: String
        }
        let iso = ISO8601DateFormatter()
        let payload = SupabaseWeeklyReadUpsert(
            id: read.id,
            user_id: read.userId,
            window_start_day: read.windowStartDay,
            anchor: read.anchor,
            shown: read.shown,
            offer_key: read.offerKey,
            decision: read.decision,
            fact_id: read.factId,
            decided_at: iso.string(from: read.decidedAt)
        )
        do {
            try await supabase.from("weekly_reads")
                .upsert(payload)
                .execute()
            await MainActor.run {
                let descriptor = FetchDescriptor<WeeklyReadRecord>(
                    predicate: #Predicate { $0.id == readId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            Self.reportStructuralFailure("weekly_reads", error)
            #if DEBUG
            print("[SyncService] upsertWeeklyRead deferred (table not deployed yet?): \(error)")
            #endif
        }
    }

    @MainActor
    public func hydrateWeeklyReads(userId: String) async {
        struct Row: Decodable {
            let id: String
            let window_start_day: String
            let anchor: String?
            let shown: String?
            let offer_key: String?
            let decision: String?
            let fact_id: String?
            let decided_at: String?
        }
        do {
            let rows: [Row] = try await supabase.from("weekly_reads")
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
                let descriptor = FetchDescriptor<WeeklyReadRecord>(
                    predicate: #Predicate { $0.id == rowId }
                )
                if let existing = try? context.fetch(descriptor).first {
                    if existing.userId != userId,
                       existing.userId.lowercased() == userId.lowercased() {
                        existing.userId = userId
                    }
                    continue   // client-owned; never clobbered
                }
                let read = WeeklyReadRecord(
                    userId: userId,
                    windowStartDay: row.window_start_day,
                    anchor: row.anchor ?? "enrollment",
                    shown: row.shown,
                    offerKey: row.offer_key ?? "hold_steady",
                    decision: row.decision ?? "declined",
                    factId: row.fact_id,
                    decidedAt: row.decided_at.flatMap {
                        iso.date(from: $0) ?? isoFractional.date(from: $0)
                    } ?? .now
                )
                read.pendingUpsert = false
                context.insert(read)
            }
            try? context.save()
        } catch {
            Self.reportStructuralFailure("weekly_reads", error)
            #if DEBUG
            print("[SyncService] hydrateWeeklyReads deferred (table not deployed / no rows): \(error)")
            #endif
        }
    }

    // MARK: - Dose events (app v24 THE REGIMEN)

    public func upsertDoseEvent(_ event: DoseEventRecord) async {
        let eventId = event.id
        guard !event.userId.isEmpty else { return }
        struct SupabaseDoseEventUpsert: Encodable {
            let id: String
            let user_id: String
            let regimen_plan_id: String
            let day_key: String
            let scheduled_at: String
            let status: String
            let taken_at: String?
            let site: String?
            let dose_label: String?
            let note: String?
            let skip_reason: String?
            let source: String
        }
        let iso = ISO8601DateFormatter()
        let payload = SupabaseDoseEventUpsert(
            id: event.id,
            user_id: event.userId,
            regimen_plan_id: event.regimenPlanId,
            day_key: event.dayKey,
            scheduled_at: iso.string(from: event.scheduledAt),
            status: event.status,
            taken_at: event.takenAt.map { iso.string(from: $0) },
            site: event.site,
            dose_label: event.doseLabel,
            note: event.note,
            skip_reason: event.skipReason,
            source: event.source
        )
        do {
            try await supabase.from("dose_events")
                .upsert(payload)
                .execute()
            await MainActor.run {
                let descriptor = FetchDescriptor<DoseEventRecord>(
                    predicate: #Predicate { $0.id == eventId }
                )
                if let refetched = try? modelContainer.mainContext.fetch(descriptor).first {
                    refetched.pendingUpsert = false
                    try? modelContainer.mainContext.save()
                }
            }
        } catch {
            #if DEBUG
            print("[SyncService] upsertDoseEvent deferred (table not deployed yet?): \(error)")
            #endif
        }
    }

    public func deleteDoseEvent(id: String) async {
        do {
            try await supabase.from("dose_events")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            #if DEBUG
            print("[SyncService] deleteDoseEvent deferred: \(error)")
            #endif
        }
    }

    @MainActor
    public func hydrateDoseEvents(userId: String) async {
        struct Row: Decodable {
            let id: String
            let regimen_plan_id: String
            let day_key: String
            let scheduled_at: String?
            let status: String
            let taken_at: String?
            let site: String?
            let dose_label: String?
            let note: String?
            let skip_reason: String?
            let source: String?
        }
        do {
            let rows: [Row] = try await supabase.from("dose_events")
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
                let descriptor = FetchDescriptor<DoseEventRecord>(
                    predicate: #Predicate { $0.id == rowId }
                )
                if let existing = try? context.fetch(descriptor).first {
                    if existing.userId != userId,
                       existing.userId.lowercased() == userId.lowercased() {
                        existing.userId = userId
                    }
                    continue   // insert-only merge; local truth wins
                }
                let record = DoseEventRecord(
                    id: row.id,
                    userId: userId,
                    regimenPlanId: row.regimen_plan_id,
                    dayKey: row.day_key,
                    scheduledAt: date(row.scheduled_at) ?? .now,
                    status: row.status,
                    takenAt: date(row.taken_at),
                    site: row.site,
                    note: row.note,
                    skipReason: row.skip_reason,
                    // Pass 51 — UNKNOWN STAYS UNKNOWN: "sheet" is a
                    // door she never used; absence arrives as absence.
                    source: row.source ?? "unknown"
                )
                record.doseLabel = row.dose_label
                record.pendingUpsert = false
                context.insert(record)
            }
            try? context.save()
        } catch {
            #if DEBUG
            print("[SyncService] hydrateDoseEvents deferred (table not deployed / no rows): \(error)")
            #endif
        }
    }

    // MARK: - Program plan upsert / fetch (v1.1 program pivot)

    public func upsertProgramPlan(_ plan: ProgramPlanRecord) async {
        let planId = plan.id
        guard !plan.userId.isEmpty else { return }

        // Civil dates on the wire — the LOCAL calendar day, because
        // that is the day she is living the program in (pass 51; the
        // UTC form shifted the program day ±1 across a reinstall).
        let isoStartDate = PlanWireDate.wireString(from: plan.startDate)
        let isoGoalDate = PlanWireDate.wireString(from: plan.goalDate)
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

    /// Merge cloud plan rows into the local store. Split from the network
    /// fetch so the case rules AND the merge contract are unit-testable.
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
    ///
    /// 2026-08-14 — THE RECOVERY CONTRACT. This used to `continue` on a
    /// row that already existed locally: *"data fields stay untouched
    /// (insert-only semantics)"*. That is why a support repair to
    /// `program_plans` could not reach an installed client. The reported
    /// shape: the database was corrected to `goal 110 / 119 days`, and the
    /// customer's phone went on showing `goal 124` and the maintenance
    /// energy target that follows from it, forever. Insert-only is right
    /// for append-only history; a plan row is a MUTABLE STATEMENT ABOUT
    /// HER BODY, and it has to be repairable from the only place support
    /// can reach. See `ProgramPlanMerge`.
    @MainActor
    public static func applyHydratedProgramPlans(
        _ rows: [ProgramPlanHydrateRow], userId: String, context: ModelContext
    ) {
        let locals = (try? context.fetch(FetchDescriptor<ProgramPlanRecord>())) ?? []
        let localsById = Dictionary(grouping: locals, by: { $0.id.uppercased() })

        for row in rows {
            let normalizedId = row.id.uppercased()
            if let variants = localsById[normalizedId] {
                // Already local. Skipped entirely when several case
                // variants share the id (the pre-fix duplicate-row shape:
                // the uppercase original is already visible, and re-casing
                // its lowercase twin would collide on the unique id).
                guard variants.count == 1, let existing = variants.first else { continue }
                // A pre-fix hydrate stored this row with a lowercase id +
                // userId, making it invisible to every reader; normalize
                // the casing in place so it surfaces.
                if existing.userId != userId,
                   existing.userId.lowercased() == userId.lowercased() {
                    existing.userId = userId
                    existing.id = normalizedId
                    existing.parentPlanId = existing.parentPlanId?.uppercased()
                }
                ProgramPlanMerge.apply(row, to: existing)
                continue
            }
            // Civil dates anchored at LOCAL midnight, so the program
            // day derived from them is the day the wire string names —
            // in every zone, on every reinstall (pass 51).
            let startDate = PlanWireDate.localDate(fromWire: row.start_date) ?? .now
            let goalDate = PlanWireDate.localDate(fromWire: row.goal_date) ?? .now
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
            // Pass 51 — WireTimestamp everywhere a server-written
            // instant is read: `now()` defaults and support SQL carry
            // microseconds the bare formatter refused, so an archived
            // plan hydrated un-archived and a DEFAULT-stamped
            // started_at fell back to the hydration moment.
            plan.archivedAt = WireTimestamp.parse(row.archived_at)
            plan.completedAt = WireTimestamp.parse(row.completed_at)
            // The enrollment moment, not the hydration moment.
            // `ProgramService.activePlan` sorts `createdAt` DESC, and every
            // hydrated row used to carry `.now` from the initialiser — so
            // after a reinstall the plan the app called "active" was decided
            // by the order of this loop. `started_at` is the column the
            // upsert has always written; it just was not read back.
            if let started = WireTimestamp.parse(row.started_at) {
                plan.createdAt = started
            }
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
            // Pass 51 — WireTimestamp: a server-written completed_at
            // carries microseconds the bare formatter refused.
            check.completedAt = WireTimestamp.parse(row.completed_at)
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
                // Pass 51 — UNKNOWN STAYS UNKNOWN: "manual" means SHE
                // TYPED IT, and it decides which author wins the day
                // under the importer's per-day rule. An absent source
                // arrives as the absence it is.
                source: row.source ?? "unknown"
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

    /// Remove one weigh-in server-side.
    ///
    /// v25 §34 — the mirror of `deleteFoodLog`, and the only thing that
    /// was missing for a weigh-in to be correctable at all: the local
    /// hydrate is insert-only by id (`applyHydratedWeightLogs`), so a
    /// row deleted only on the device is re-inserted by the next pull.
    /// The `weight_logs_delete_own` RLS policy and the DELETE grant to
    /// `authenticated` have both shipped since `scripts/schema.sql`, so
    /// this needs no migration.
    ///
    /// Fire-and-forget, exactly like `deleteFoodLog` and
    /// `deleteDoseEvent`: the RLS delete_own policy scopes the delete
    /// to `auth.uid()`, so no explicit user_id filter is needed. A
    /// delete attempted offline is lost and the row returns on the next
    /// hydrate — the same known limitation the other two carry, named
    /// rather than papered over.
    public func deleteWeightLog(id: String) async {
        do {
            try await supabase.from("weight_logs")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            #if DEBUG
            print("[SyncService] deleteWeightLog FAILED for \(id): \(error)")
            #endif
        }
    }

    /// v25 §36 — the missing half of the observation delete.
    ///
    /// `hydrateObservations` above is insert-only by id, so a row
    /// removed on the device alone is re-inserted by the next pull. The
    /// argument is `34`'s verbatim: a delete the hydrate undoes is worse
    /// than no delete. Additive; no schema, no DTO, no transport change
    /// — `observations_delete_own` and
    /// `grant … delete on public.observations` have shipped since
    /// `20260728000000_app_v8_care_platform_foundation.sql`.
    public func deleteObservation(id: String) async {
        do {
            try await supabase.from("observations")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            #if DEBUG
            print("[SyncService] deleteObservation FAILED for \(id): \(error)")
            #endif
        }
    }

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
        /// WHICH DOOR the entry came through. Optional because the DTO
        /// is TRANSPORT: a NULL on the server is an absence of
        /// attribution and must arrive as one. The write side has said
        /// so since E8.1 (`EntryMethod.persistedSourceValue` upserts
        /// absent as `unknown`); the read side used to default a NULL
        /// to `"photo"`, which manufactured a door on hydrate.
        public let source: String?
        public let payload: Payload?

        public struct Payload: Codable, Sendable {
            public let title: String?
            /// v9 P5 — the story data rides the EXISTING payload
            /// jsonb (no new columns → no migration gate, and an
            /// un-migrated server can never reject the upsert).
            /// Sodium/sat-fat may graduate to real columns later via
            /// a server-side backfill from here.
            public var sodium_mg: Double? = nil
            public var saturated_fat_g: Double? = nil
            public var items_detail: [ItemRow]? = nil
            /// v25 E4 — the fix-with-words sentences she applied, in
            /// order (the corrections flywheel survives a reinstall).
            public var corrections: [String]? = nil
            /// p53 — her deliberate hand edits + the barcode
            /// verify-once key, riding the same jsonb (no migration).
            public var edits: [String]? = nil
            public var barcode: String? = nil

            public struct ItemRow: Codable, Sendable {
                public let name: String
                public let portion_g: Double
                public let kcal: Double
                public let protein_g: Double
                public let carbs_g: Double
                public let fat_g: Double
                public var sodium_mg: Double? = nil
                public var sat_fat_g: Double? = nil
                public init(
                    name: String, portion_g: Double, kcal: Double,
                    protein_g: Double, carbs_g: Double, fat_g: Double,
                    sodium_mg: Double? = nil, sat_fat_g: Double? = nil
                ) {
                    self.name = name
                    self.portion_g = portion_g
                    self.kcal = kcal
                    self.protein_g = protein_g
                    self.carbs_g = carbs_g
                    self.fat_g = fat_g
                    self.sodium_mg = sodium_mg
                    self.sat_fat_g = sat_fat_g
                }
            }

            public init(
                title: String?,
                sodium_mg: Double? = nil,
                saturated_fat_g: Double? = nil,
                items_detail: [ItemRow]? = nil,
                corrections: [String]? = nil,
                edits: [String]? = nil,
                barcode: String? = nil
            ) {
                self.title = title
                self.sodium_mg = sodium_mg
                self.saturated_fat_g = saturated_fat_g
                self.items_detail = items_detail
                self.corrections = corrections
                self.edits = edits
                self.barcode = barcode
            }
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
            // UNKNOWN STAYS UNKNOWN (pass 51): a NULL source used to
            // decode as "photo", manufacturing a door on hydrate for a
            // row whose attribution was honestly absent — the exact
            // inversion of the write-side law (absent upserts as
            // 'unknown'). Absence arrives as absence.
            source = try? c.decode(String.self, forKey: .source)
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

    /// Release audit 2026-08-08 — id-only select for the every-launch
    /// push reconcile. Distinguishes "fetch failed" (nil: do nothing —
    /// blind re-pushes would be wasted writes on a dead network) from
    /// "server genuinely has none" (empty set: push everything local).
    public func fetchFoodLogIds(userId: String) async -> Set<String>? {
        struct IdRow: Decodable { let id: String }
        do {
            let rows: [IdRow] = try await supabase.from("food_logs")
                .select("id")
                .eq("user_id", value: userId)
                .execute()
                .value
            return Set(rows.map { $0.id.lowercased() })
        } catch {
            #if DEBUG
            print("[SyncService] fetchFoodLogIds FAILED: \(error)")
            #endif
            return nil
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

/// Public so the merge contract in `ProgramPlanMerge` can be exercised
/// end to end from the app's own regression suite — the customer-recovery
/// path is a product law now, not a sync detail.
public struct ProgramPlanHydrateRow: Decodable {
    public let id: String
    public let user_id: String
    public let start_date: String
    public let goal_date: String
    public let total_days: Int
    public let current_weight_kg: Double?
    public let goal_weight_kg: Double?
    public let intensity_tier: String
    public let phase: String
    public let parent_plan_id: String?
    public let archived_at: String?
    public let completed_at: String?
    /// The enrollment timestamp. Written by every upsert since v1.1 and
    /// never decoded until 2026-08-14 (see `applyHydratedProgramPlans`).
    /// Optional so a NULL on a pre-v1.1 row decodes rather than throwing.
    public let started_at: String?

    public init(
        id: String, user_id: String, start_date: String, goal_date: String,
        total_days: Int, current_weight_kg: Double?, goal_weight_kg: Double?,
        intensity_tier: String, phase: String, parent_plan_id: String?,
        archived_at: String?, completed_at: String?, started_at: String? = nil
    ) {
        self.id = id
        self.user_id = user_id
        self.start_date = start_date
        self.goal_date = goal_date
        self.total_days = total_days
        self.current_weight_kg = current_weight_kg
        self.goal_weight_kg = goal_weight_kg
        self.intensity_tier = intensity_tier
        self.phase = phase
        self.parent_plan_id = parent_plan_id
        self.archived_at = archived_at
        self.completed_at = completed_at
        self.started_at = started_at
    }
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
/// `internal`, not `private`, since pass 51: the adoption rules in
/// `applyHydratedUser` are pinned by PlankSyncTests, which builds
/// fixture rows through the memberwise initializer.
struct SupabaseUserRow: Decodable {
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

    /// Pass 51 — the column the upsert has always written and the
    /// hydrate never read back: without it, every routine's
    /// per-exercise breakdown was lost on reinstall/new device even
    /// though the server held it.
    let exerciseResults: [ExerciseResultEntry]?

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
        case exerciseResults = "exercise_results"
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
