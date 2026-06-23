import Foundation
import Observation
import SwiftData
import PlankSync
import PlankFood
import Auth  // MemberImportVisibility: User.id lives in Supabase's Auth submodule

// v1.1.1 cross-view weight-change signal. SwiftData @Query doesn't
// reliably fire body re-renders on in-place property mutations for
// views attached to inactive tabs (e.g. AnalyticsView's trend canvas
// when the user logs from PlanView). Anyone who writes a
// WeightLogRecord (insert OR in-place mutation) posts this
// notification; AnalyticsView listens and bumps its weightChartVersion
// to force the trend canvas to re-mount. Decouples writers (PlanView,
// AnalyticsView's own LogWeightSheet, BodyMassImportService) from
// the consumer.
extension Notification.Name {
    static let weightLogDidChange = Notification.Name("weightLogDidChange")
}

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
    private var modelContainer: ModelContainer?
    private var lastUserId: String?
    private var lastAuthMethod: AuthMethod = .unknown
    /// Guards against the same user_id triggering hydrate+sync twice
    /// concurrently. Sign-in fires both `onChange(of: currentUser?.id)` and
    /// `onChange(of: authMethod)` in the same render cycle — without this
    /// set, the hydrate path runs 2-3x in close succession.
    private var hydrationsInFlight: Set<String> = []

    /// Idempotent. Safe to call multiple times.
    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        guard syncService == nil else { return }
        syncService = SyncService(supabaseClient: supabase, modelContainer: modelContainer)

        // Food journal sync seam — PlankFood fires these after local
        // writes; we mirror to the food_logs table. Fire-and-forget:
        // logging requires the network anyway (the vision EF), so a
        // failed upsert here is rare and the launch reconcile in
        // hydrateFoodLogs sweeps up stragglers.
        FoodLogPersister.onEntryPersisted = { entry in
            Task { await AppSync.shared.upsertFoodLog(entry) }
        }
        FoodLogPersister.onEntryDeleted = { entryId, _ in
            Task { await AppSync.shared.deleteFoodLog(id: entryId) }
        }
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
        lastAuthMethod = AuthService.shared.authMethod
        guard !userId.isEmpty else { return }

        await service.retryPendingUpserts()

        if isLocalCacheEmpty(modelContext: modelContext) {
            await hydrateAndSync(userId: userId)
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
        let newMethod = AuthService.shared.authMethod
        let previousUserId = lastUserId
        let previousMethod = lastAuthMethod
        let userIdChanged = newUserId != previousUserId
        lastUserId = newUserId
        lastAuthMethod = newMethod

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
            await hydrateAndSync(userId: newUserId)
        }

        // Sign-up upgrade re-upsert: when an anonymous user becomes named on
        // the SAME user_id, push the local profile so onboarding answers
        // collected during the anon period land under the now-named account.
        // Gated on userIdChanged == false to avoid clobbering an existing
        // account's profile during a Named-A → Named-B sign-in switch.
        let upgraded = previousMethod == .anonymous
            && (newMethod == .apple || newMethod == .email)
            && !userIdChanged
        if upgraded {
            let descriptor = FetchDescriptor<UserRecord>(
                predicate: #Predicate { $0.id == newUserId }
            )
            if let record = try? modelContext.fetch(descriptor).first {
                await service.upsertUser(record)
            }
        }

        // Keep RevenueCat's appUserID aligned with the Supabase identity so
        // entitlements scope to the same user across both backends. Cleans
        // up the orphan anonymous RevenueCat record created when configure()
        // ran with the bootstrap-anon uid that the user later upgraded away
        // from. handleAuthChange is a no-op when newUserId matches what's
        // already synced, so the two onChange handlers in RootView don't
        // double-call this path.
        await PaymentService.shared.handleAuthChange(newUserID: newUserId)
    }

    // Compatibility name for code that hasn't been renamed yet.
    func onUserChanged(modelContext: ModelContext) async {
        await onAuthChanged(modelContext: modelContext)
    }

    /// Hydrate from cloud and immediately mirror the UserRecord into
    /// @AppStorage. Both phases run on the SAME context — the container's
    /// mainContext — so the post-hydrate read is guaranteed to see the
    /// SwiftData write hydrateUser just made. Earlier, the read used the
    /// `@Environment(\.modelContext)` from RootView, which was a different
    /// `ModelContext` instance and consistently returned 0 results.
    ///
    /// The `hydrationsInFlight` guard collapses the 2-3x sign-in firings
    /// (currentUser?.id onChange + authMethod onChange + onLaunch) into a
    /// single hydrate per user_id.
    private func hydrateAndSync(userId: String) async {
        guard !userId.isEmpty else { return }
        if hydrationsInFlight.contains(userId) {
            #if DEBUG
            print("[AppSync] hydrateAndSync: SKIP — already in flight for \(userId)")
            #endif
            return
        }
        hydrationsInFlight.insert(userId)
        defer { hydrationsInFlight.remove(userId) }

        guard let service = syncService else { return }
        guard let container = modelContainer else { return }

        await service.hydrateFromCloud(userId: userId)
        await service.hydrateWeightLogs(userId: userId)
        // v1.1 program pivot — pulls active + archived plans + per-day
        // checks so PlanView renders the right state immediately on a
        // fresh device install. Both hydrate paths are no-ops when the
        // user has no enrollment.
        await service.hydrateProgramPlans(userId: userId)
        await service.hydrateProgramDayChecks(userId: userId)
        // Food journal: pull server rows into the JSONL store, then
        // push any local entries the server doesn't have (covers logs
        // recorded before sync shipped + rare failed upserts).
        await hydrateFoodLogs(userId: userId)
        syncUserDefaultsFromUserRecord(context: container.mainContext, userId: userId)
    }

    /// Mirror the freshly-hydrated UserRecord back into the @AppStorage keys
    /// that the rest of the app reads from. Reads from `container.mainContext`
    /// — the same context hydrateUser writes to — so the fetch is guaranteed
    /// to see the row.
    private func syncUserDefaultsFromUserRecord(context: ModelContext, userId: String) {
        let descriptor = FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == userId }
        )
        guard let record = try? context.fetch(descriptor).first else { return }

        let defaults = UserDefaults.standard
        if !record.name.isEmpty { defaults.set(record.name, forKey: "userName") }
        if let value = record.onboardingGoal { defaults.set(value, forKey: "userMotivation") }
        if let value = record.onboardingExperience { defaults.set(value, forKey: "userExperience") }
        if let value = record.onboardingVoicePreference { defaults.set(value, forKey: "voicePreference") }
        if let value = record.onboardingAgeRange { defaults.set(value, forKey: "ageRange") }
        if let value = record.onboardingActivityLevel { defaults.set(value, forKey: "activityLevel") }
        if let value = record.onboardingBaselineHoldSeconds { defaults.set(value, forKey: "userBaselineSeconds") }
        if let value = record.onboardingCommitmentDaysPerWeek { defaults.set(value, forKey: "commitmentDays") }
        if let value = record.onboardingBarriers {
            defaults.set(value.joined(separator: ","), forKey: "userBarriers")
        }
        defaults.set(record.onboardingNotificationEnabled, forKey: "notificationsEnabled")
        if let focusArea = record.onboardingFocusArea {
            defaults.set(focusArea, forKey: "focusArea")
            // userGoal mirrors the derivation in PlankAIApp.handleOnboardingComplete:
            // focusArea drives the WorkoutGenerator's anatomy pipeline. Re-derived
            // here so the cloud-only path produces the same userGoal a fresh
            // onboarding would.
            let derivedGoal: String
            switch focusArea {
            case "abs": derivedGoal = "definition"
            case "obliques": derivedGoal = "sculpting"
            case "lowerBack": derivedGoal = "strength"
            default: derivedGoal = "fullCore"
            }
            defaults.set(derivedGoal, forKey: "userGoal")
        }
        if let plankTime = record.onboardingPlankTime {
            defaults.set(plankTime, forKey: "plankTime")
        }
        if let sessionLengthPref = record.onboardingSessionLengthPref {
            defaults.set(sessionLengthPref, forKey: "sessionLengthPref")
        }
        // Phase 4 bodyFocus mirror. HomeView's WorkoutGenerator + PaywallView's
        // personalized headline both read this AppStorage key directly, so a
        // fresh-device sign-in needs this written or workouts fall back to
        // .fullBody until the next EditProfile selection.
        if let firstFocus = record.onboardingBodyFocus.first, !firstFocus.isEmpty {
            defaults.set(firstFocus, forKey: "bodyFocus")
        }
    }

    /// Re-attribute local SessionLog + DayProgress rows from the previous
    /// user_id to the new one so they land in the signed-in account on
    /// the next push. Marks SessionLog + WeightLog rows pendingUpsert so
    /// retry sends them; DayProgress is upserted again next session.
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

        // Weight logs are the load-bearing source for the analytics weight
        // trend; without this, an onboarding-seeded log (or any manual log
        // collected during the anonymous period) stays attached to the
        // anon user_id and goes invisible after sign-in because the views
        // filter by the current user_id.
        let weightLogs = (try? modelContext.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        for w in weightLogs {
            w.userId = newId
            w.pendingUpsert = true
        }

        // Food journal entries collected during the anonymous period
        // re-key the same way (views filter by current userId). The
        // post-sign-in hydrateFoodLogs reconcile pushes them.
        FoodLogPersister.reattributeEntries(from: oldId, to: newId)

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

    func upsertWeightLog(_ log: WeightLogRecord) async {
        guard let service = syncService else { return }
        guard !log.userId.isEmpty else { return }
        await service.upsertWeightLog(log)
    }

    // MARK: - Food journal (v1.1 — journal sync)

    private static let foodLogDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func syncRow(from entry: FoodLogPersister.SyncableEntry) -> SyncService.FoodLogSyncRow {
        SyncService.FoodLogSyncRow(
            id: entry.id,
            user_id: entry.userId,
            logged_at: ISO8601DateFormatter().string(from: entry.loggedAt),
            kcal_total: entry.kcal,
            protein_g: entry.protein,
            carbs_g: entry.carbs,
            fat_g: entry.fat,
            fiber_g: entry.fiber,
            // food_logs.source CHECK list mirrors FoodCapture raw
            // values; old pre-D3.B entries carry nil → 'photo'.
            source: entry.source ?? "photo",
            payload: .init(title: entry.title.isEmpty ? nil : entry.title)
        )
    }

    func upsertFoodLog(_ entry: FoodLogPersister.SyncableEntry) async {
        guard let service = syncService else { return }
        guard !entry.userId.isEmpty else { return }
        await service.upsertFoodLog(Self.syncRow(from: entry))
    }

    func deleteFoodLog(id: String) async {
        guard let service = syncService else { return }
        await service.deleteFoodLog(id: id)
    }

    /// Two-way reconcile: merge server rows into the local journal,
    /// then push local entries the server doesn't have.
    func hydrateFoodLogs(userId: String) async {
        guard let service = syncService else { return }
        guard !userId.isEmpty else { return }

        let rows = await service.fetchFoodLogs(userId: userId)
        let fallbackFormatter = ISO8601DateFormatter()
        let remote: [FoodLogPersister.SyncableEntry] = rows.map { row in
            FoodLogPersister.SyncableEntry(
                id: row.id,
                userId: row.user_id,
                loggedAt: Self.foodLogDateFormatter.date(from: row.logged_at)
                    ?? fallbackFormatter.date(from: row.logged_at)
                    ?? .now,
                kcal: row.kcal_total,
                protein: row.protein_g ?? 0,
                carbs: row.carbs_g ?? 0,
                fat: row.fat_g ?? 0,
                fiber: row.fiber_g ?? 0,
                title: row.payload?.title ?? "",
                source: row.source
            )
        }
        FoodLogPersister.mergeRemote(remote)

        let remoteIds = Set(rows.map(\.id))
        for entry in FoodLogPersister.allSyncableEntries(userId: userId)
        where !remoteIds.contains(entry.id) {
            await service.upsertFoodLog(Self.syncRow(from: entry))
        }
    }

    // MARK: - Program (v1.1 program pivot)

    func upsertProgramPlan(_ plan: ProgramPlanRecord) async {
        guard let service = syncService else { return }
        guard !plan.userId.isEmpty else { return }
        await service.upsertProgramPlan(plan)
    }

    func upsertProgramDayCheck(_ check: ProgramDayCheckRecord) async {
        guard let service = syncService else { return }
        guard !check.userId.isEmpty else { return }
        await service.upsertProgramDayCheck(check)
    }

    // MARK: Delete account

    /// End-to-end delete-account orchestration:
    ///   1. Call AuthService.deleteAccount() RPC. Cloud cascade removes every
    ///      user-data row keyed to auth.uid().
    ///   2. Wipe local SwiftData rows for the deleted user. Other accounts
    ///      previously signed in on this device stay intact.
    ///   3. Clear @AppStorage onboarding state so RootView routes back to
    ///      the welcome screen — fresh device-equivalent.
    ///   4. Sign out (re-bootstraps an anonymous session, restores a valid
    ///      auth.uid() for first-launch behavior).
    ///
    /// Throws on RPC failure. Caller (DeleteAccountSheet) catches and shows
    /// an inline error; partial-success cleanup steps after the RPC are
    /// best-effort and don't throw.
    func deleteCurrentAccount() async throws {
        let userIdToWipe = currentUserId
        #if DEBUG
        print("[AppSync] deleteCurrentAccount: ENTER user_id=\(userIdToWipe ?? "<nil>")")
        #endif

        do {
            try await AuthService.shared.deleteAccount()
            #if DEBUG
            print("[AppSync] deleteCurrentAccount: RPC succeeded, proceeding with local cleanup")
            #endif
        } catch {
            #if DEBUG
            print("[AppSync] deleteCurrentAccount: RPC threw, aborting local cleanup. Error: \(error)")
            #endif
            throw error
        }

        if let userId = userIdToWipe, !userId.isEmpty,
           let container = modelContainer {
            clearLocalUserData(context: container.mainContext, userId: userId)
            #if DEBUG
            print("[AppSync] deleteCurrentAccount: local SwiftData cleared for user_id=\(userId)")
            #endif
        } else {
            #if DEBUG
            print("[AppSync] deleteCurrentAccount: skipped SwiftData clear — empty userId or no modelContainer")
            #endif
        }

        clearOnboardingUserDefaults()
        // Cancel pending local retention notifications so a deleted user
        // never gets a stray affirmation / win-back after wiping.
        RetentionNotifications.cancelAll()
        #if DEBUG
        print("[AppSync] deleteCurrentAccount: UserDefaults onboarding keys cleared")
        #endif

        do {
            try await AuthService.shared.signOut()
            #if DEBUG
            print("[AppSync] deleteCurrentAccount: signOut + re-bootstrap complete; EXIT success")
            #endif
        } catch {
            #if DEBUG
            print("[AppSync] deleteCurrentAccount: signOut threw (cloud already deleted). Error: \(error)")
            #endif
            throw error
        }
    }

    /// Delete every SwiftData record keyed to the given user_id. Ratings
    /// reference sessionLogId, not userId, so we collect the user's session
    /// IDs first, delete matching ratings, then delete the sessions.
    @MainActor
    private func clearLocalUserData(context: ModelContext, userId: String) {
        let sessionsDescriptor = FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        let sessions = (try? context.fetch(sessionsDescriptor)) ?? []
        let sessionIds = Set(sessions.map(\.id))

        let allRatings = (try? context.fetch(FetchDescriptor<SessionRatingRecord>())) ?? []
        for rating in allRatings where sessionIds.contains(rating.sessionLogId) {
            context.delete(rating)
        }
        for session in sessions {
            context.delete(session)
        }

        let dayProgressDescriptor = FetchDescriptor<DayProgressRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let progresses = try? context.fetch(dayProgressDescriptor) {
            for progress in progresses { context.delete(progress) }
        }

        let userRecordDescriptor = FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == userId }
        )
        if let users = try? context.fetch(userRecordDescriptor) {
            for user in users { context.delete(user) }
        }

        let calibrationsDescriptor = FetchDescriptor<ExerciseCalibrationRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let calibrations = try? context.fetch(calibrationsDescriptor) {
            for cal in calibrations { context.delete(cal) }
        }

        // Food journal lives in the JSONL store, not SwiftData. Server
        // rows are gone via the delete-account cascade; clear the
        // device copy too.
        FoodLogPersister.deleteAllEntries(userId: userId)

        try? context.save()
    }

    /// Reset every onboarding-derived @AppStorage key + the gate flags so
    /// RootView lands the user back on the welcome screen with a fresh
    /// anonymous session. Bundle-Identifier-scoped — doesn't touch other
    /// apps' defaults.
    ///
    /// v1.1.1 (2026-06-19) — the original 14-key list was the pre-1.0
    /// onboarding surface. Phases 4-9 + the v2/v3/v4 onboarding rebuilds +
    /// the Plan-tab retention layer + cohort routing all added their own
    /// user-scoped keys, NONE of which were swept on delete-account / sign-
    /// out. Symptoms in production: User A signs out → User B signs in →
    /// B sees A's stale identity word in Becoming, A's kindTodayDateKey
    /// in the Plan recap line, A's saved cuisine prefs in QuickAdd, A's
    /// lessons-completed count in Settings. Expanded to the full audit
    /// list. Audio levels (voiceVolume/bgmVolume) + display prefs
    /// (weightUnit) + feature-flag toggles stay because those are
    /// device-level prefs, not identity-scoped.
    func clearOnboardingUserDefaults() {
        let defaults = UserDefaults.standard
        let keys = [
            // Original pre-1.0 keys.
            "userName", "userGoal", "userExperience", "userMotivation",
            "voicePreference", "ageRange", "activityLevel", "focusArea",
            "plankTime", "sessionLengthPref", "userBaselineSeconds",
            "commitmentDays", "userBarriers", "notificationsEnabled",
            "hasCompletedFirstSession", "hasCompletedOnboarding",
            // Onboarding v2 (Phase A).
            "onboardingSleepHours", "onboardingStressLevel",
            "onboardingEatingCadence", "onboardingEatingWindow",
            "onboardingPriorAttempts", "onboardingPriorWin",
            "onboardingFoodRelationship", "onboardingHormonalStage",
            "onboardingTriedBefore",
            // Onboarding v3 + v4 (cohort routing, paywall mechanics,
            // NSV, weight, tier, dates, cuisine, body-focus key).
            "onboarding_glp1_status", "onboarding_glp1_phase", "onboardingNsvPriority",
            "onboardingPickedTier", "onboardingPaceChoice",
            "onboardingCurrentWeightKg", "onboardingGoalWeightKg",
            "onboarding_weight_trend",
            "onboardingGoalDate", "onboardingCuisinePreference",
            "onboardingAgeRange", "onboardingActivityLevel",
            "onboardingBodyFocusKey", "onboardingReviewPromptShown",
            // Onboarding v4 fear/consent flags + restrictive food
            // override + movement baseline.
            "onb_fear_anotherDiet", "onb_fear_priorAttempt",
            "onb_fear_quickResults", "onb_consent_personalize",
            "onb_consent_day2", "onb_restrictive_food",
            "onb_v4_movement_baseline",
            // Identity + cohort copy keys read by Welcome + Becoming +
            // Plan retention layer (Home Phase 3).
            "identityFeeling", "bodyFocus", "workoutLevel",
            "todaysEnergy", "hideWeightStats", "hasEnrolledInProgram",
            // Plan-tab user-scoped session state. kindTodayDateKey
            // gates the kind-today identity nudge, lastRecapShownDateKey
            // gates yesterday recap, lastPlanAppearAt drives the
            // luxury press-feedback timing, planFirstRunHintSeen is
            // the first-session affordance gate, planChecksMigratedV1
            // is the SwiftData migration marker (per-user).
            "kindTodayDateKey", "lastRecapShownDateKey",
            "lastPlanAppearAt", "planFirstRunHintSeen",
            "planChecksMigratedV1",
            // JeniMethod lesson + breathwork + steps + Becoming recap
            // per-user counters (formerly carried across signouts).
            "jenimethod.last_lesson_completed_id",
            "steps.last_goal_hit_day",
            "breathwork.lastOccasion", "breathwork.lastMinutes",
            "becoming.recap.lastShownWeek",
            // Food rail user-scoped prefs (dietary pattern + targets +
            // exclusions + HealthKit write + photo retention + AI
            // consent are per-identity, NOT device-level).
            "foodDailyTarget", "foodDietaryPattern", "foodExclusionsCSV",
            "foodHealthKitWriteEnabled", "foodPhotoRetention",
            "foodAIConsentAccepted", "foodAIConsentAt",
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }

    /// v1.1.1 sign-out sweep. Per the AuthService comment, sign-out
    /// preserves SwiftData (the old user_id rows stay on disk for
    /// offline reading under their original userId), but @AppStorage
    /// is process-level and not userId-keyed — without this, the next
    /// user signing in inherits the previous identity's onboarding
    /// state, retention timers, and cohort flags. Also cancels
    /// pending retention notifications so a deleted user's scheduled
    /// nudges don't fire under the new identity. Called from
    /// AccountView.performSignOut() BEFORE AuthService.signOut so
    /// the cleared keys propagate before the bootstrap re-fires.
    @MainActor
    func clearLocalUserStateForSignOut() {
        clearOnboardingUserDefaults()
        RetentionNotifications.cancelAll()
    }

    /// Fire-and-forget Supabase upsert for the user's profile row. Caller is
    /// responsible for the SwiftData write (handleOnboardingComplete does it
    /// inline). Defensive: skips silently if the record's id is empty or if
    /// AuthService has no current user — should never happen post-bootstrap,
    /// but guards against init-order bugs.
    func upsertUser(_ user: UserRecord) async {
        guard let service = syncService else { return }
        guard !user.id.isEmpty else { return }
        guard let authedId = currentUserId, !authedId.isEmpty else { return }
        await service.upsertUser(user)
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
