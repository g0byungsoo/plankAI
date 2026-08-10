import Foundation
import UserNotifications
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
        FoodLogPersister.onEntryDeleted = { entryId, userId in
            Task {
                await AppSync.shared.deleteFoodLog(id: entryId)
                // Wipe the cloud thumbnail too — same privacy invariant as
                // the local FoodPhotoStore.delete in deleteEntry (a deleted
                // plate must not linger anywhere).
                await FoodPhotoSyncService.shared.deleteRemotePhoto(
                    entryId: entryId, userId: userId
                )
            }
        }

        // Photo cloud backup seam (2026-07-25) — FoodPhotoStore fires after a
        // thumbnail lands on disk (snap persist AND the sign-in rekey, which
        // re-announces the photo under its fresh entry id). Mirror it to the
        // user's private food-photos bucket; a failed upload self-queues and
        // flushPendingUploads retries it.
        FoodPhotoStore.onPhotoPersisted = { entryId, data in
            guard let userId = AuthService.shared.currentUser?.id.uuidString,
                  !userId.isEmpty else { return }
            Task {
                await FoodPhotoSyncService.shared.uploadPhoto(
                    entryId: entryId, data: data, userId: userId
                )
            }
        }

        // v9 P1 (D3) — the body-scan OPT-IN mirror. The service
        // no-ops unless she turned backup on; the seam still wires
        // unconditionally so flipping the toggle needs no relaunch.
        BodyScanStore.onScanKept = { record in
            BodyScanSyncService.shared.scanKept(record)
        }
    }

    // MARK: Bootstrap

    /// Called once after AuthService.bootstrap completes and the model
    /// container is configured. Finishes any sign-in merge a prior process
    /// death interrupted, retries pending Supabase upserts from prior
    /// crashes, and hydrates from cloud when any synced entity family is
    /// locally empty for this user (fresh install OR a partial store;
    /// hydrates are insert-only, so over-hydrating is safe).
    func onLaunch(modelContext: ModelContext) async {
        guard let service = syncService else { return }
        let userId = AuthService.shared.currentUser?.id.uuidString ?? ""
        lastUserId = userId
        lastAuthMethod = AuthService.shared.authMethod
        guard !userId.isEmpty else { return }

        // 2026-06-23 one-time back-fill: pull the cohort + clinical intake
        // signals out of @AppStorage into the synced UserRecord for users who
        // onboarded before the persistence P0 (their answers were local-only).
        // Sets pendingUpsert, so the retry just below pushes them to Supabase.
        backfillCohortIntakeIfNeeded(modelContext: modelContext, userId: userId)

        // If the app died mid sign-in-merge, the marker written before
        // reattribution survives; re-run the merge for that pair so the
        // stranded foreign-uid rows finally reach the account. Idempotent
        // (see resumePendingMergeIfNeeded). Cleared only after the retry
        // push below has had its shot at landing the re-keyed rows.
        let resumedMerge = resumePendingMergeIfNeeded(modelContext: modelContext)

        // v8 S2/S4 — the served protocol refreshes EVERY launch
        // (config freshness is not data hydration; hydrateAndSync
        // below is conditional on empty families and may never run
        // on a long-lived install). Cheap: at most two rows,
        // graceful on failure. The userId resolves a clinician
        // assignment when one exists (S4).
        await CareProtocolStore.hydrate(userId: userId)

        await service.retryPendingUpserts()

        if resumedMerge {
            Self.clearPendingMergeMarker()
        }

        // Photo cloud backup — retry queued photo uploads every launch (the
        // hydrate path below only runs when a synced family is empty), and
        // backfill missing thumbnails for users whose entries hydrated before
        // photo backup shipped. Both no-op fast when there's nothing to do.
        await FoodPhotoSyncService.shared.flushPendingUploads(userId: userId)
        await FoodPhotoSyncService.shared.hydrateMissingPhotos(userId: userId)

        // Release audit 2026-08-08 — the push half of the food reconcile,
        // EVERY launch, anonymous identities included. The full two-way
        // reconcile only runs inside the gated hydrate (at most daily,
        // and only when a synced family is empty — never for a fully-
        // engaged user, never for anon), so a food row whose one
        // write-time upsert failed (offline "add it", force-quit before
        // the Task ran, transient 500) stayed device-only forever —
        // while its PHOTO had a persistent retry queue. One id-only
        // select + set diff heals the asymmetry.
        await pushLocalFoodEntriesMissingFromServer(userId: userId)

        if shouldHydrateOnLaunch(modelContext: modelContext, userId: userId) {
            await hydrateAndSync(userId: userId)
        }

        // v9 P6 — the between-visit series: the current week's
        // summary publishes at the packet's cadence (only when her
        // app runs; RLS requires her active packet consent). No-op
        // for the unconnected consumer tenant.
        await WeeklySummaryPublisher.publishIfConnected(
            userId: userId, in: modelContext
        )

        // v8 THE DOOR — the care entitlement is SERVER TRUTH: a live
        // provider connection entitles the app (no wall); a revoked
        // one un-entitles it at the next sync. The onboarding code
        // beat sets the flag optimistically; this keeps it honest.
        #if DEBUG
        let qaCareAccept = ProcessInfo.processInfo.arguments
            .contains("--uitest-clinic-code-accept")
        #else
        let qaCareAccept = false
        #endif
        if !qaCareAccept {
            let careActive = await CareConnectionService.activeConnection() != nil
            UserDefaults.standard.set(careActive, forKey: "care_entitlement_active")
        }

        #if DEBUG
        await runCareQAHooksIfNeeded(userId: userId, modelContext: modelContext)
        #endif
    }

    #if DEBUG
    /// S4 live on-sim proof hooks. `--uitest-care-connect-code CODE`
    /// makes the CURRENT sim user accept a real invitation against
    /// the live server (genuine round trip). Every QA launch also
    /// re-hydrates regimen plans + the assigned protocol so a
    /// clinician assignment made between launches lands. Test-only.
    private func runCareQAHooksIfNeeded(userId: String, modelContext: ModelContext) async {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "--uitest-care-connect-code"),
           idx + 1 < args.count {
            let code = args[idx + 1]
            let already = await CareConnectionService.activeConnection() != nil
            if !already {
                _ = try? await CareConnectionService.accept(
                    code: code, lookbackDays: 28,
                    scopes: [.visitPacket, .observations, .assignment]
                )
            }
        }
        // Re-pull care-team assignments each QA launch (they arrive
        // server-side between launches).
        if args.contains("--uitest-care-connect-code")
            || args.contains("--uitest-care-refresh"),
           let service = syncService {
            await service.hydrateRegimenPlans(userId: userId)
            await CareProtocolStore.hydrate(userId: userId)
            await VisitPacketPublisher.publishIfConnected(userId: userId, in: modelContext)
        }
        // Drive the real reconciliation / correction / revoke code
        // paths deterministically (coordinate taps are flaky under
        // simctl; these exercise the SAME code the UI buttons call).
        let ctx = modelContext
        if args.contains("--uitest-care-auto-confirm"),
           case let .needsConfirmation(plan) = CareReconciliation.state(userId: userId, in: ctx) {
            CareReconciliation.confirm(plan: plan, userId: userId, in: ctx)
        }
        if let idx = args.firstIndex(of: "--uitest-care-submit-correction"),
           idx + 1 < args.count,
           let cat = CorrectionCategory(rawValue: args[idx + 1]),
           let plan = RegimenService.activeCareTeamMedicationPlan(userId: userId, in: ctx),
           let orgId = plan.orgId {
            try? await CareConnectionService.submitCorrection(
                orgId: orgId, regimenPlanId: plan.id, category: cat,
                note: cat == .other ? "sim e2e note" : nil
            )
        }
        if args.contains("--uitest-care-revoke"),
           let conn = await CareConnectionService.activeConnection() {
            try? await CareConnectionService.revoke(orgId: conn.orgId, scope: nil, disconnect: true)
        }
    }
    #endif

    /// One-time back-fill (2026-06-23, persistence P0). The cohort + clinical
    /// intake fields were @AppStorage-only until they were added to UserRecord;
    /// users who onboarded before that have the answers locally but nil on the
    /// record, so they'd never sync. For an already-onboarded user, copy each
    /// AppStorage value into the record when the record field is still nil, and
    /// flag pendingUpsert so the launch retry pushes the profile. Guarded by a
    /// device run-once flag. If no local UserRecord exists yet (fresh install,
    /// pre-hydrate) it no-ops WITHOUT setting the flag, so a later post-hydrate
    /// launch can still run it. Only fills nils, so it never clobbers a value
    /// handleOnboardingComplete already wrote for a new user.
    private func backfillCohortIntakeIfNeeded(modelContext: ModelContext, userId: String) {
        let defaults = UserDefaults.standard
        let flagKey = "cohortIntakeBackfillV1Done"
        guard !defaults.bool(forKey: flagKey) else { return }

        let descriptor = FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == userId }
        )
        guard let record = try? modelContext.fetch(descriptor).first else { return }

        func value(_ key: String) -> String? {
            let v = defaults.string(forKey: key) ?? ""
            return v.isEmpty ? nil : v
        }

        var changed = false
        if record.onboardingGlp1Status == nil,       let v = value("onboarding_glp1_status")      { record.onboardingGlp1Status = v; changed = true }
        if record.onboardingGlp1Phase == nil,        let v = value("onboarding_glp1_phase")       { record.onboardingGlp1Phase = v; changed = true }
        if record.onboardingHormonalStage == nil,    let v = value("onboardingHormonalStage")     { record.onboardingHormonalStage = v; changed = true }
        if record.onboardingWeightTrend == nil,      let v = value("onboarding_weight_trend")     { record.onboardingWeightTrend = v; changed = true }
        if record.onboardingSleepHours == nil,       let v = value("onboardingSleepHours")        { record.onboardingSleepHours = v; changed = true }
        if record.onboardingStressLevel == nil,      let v = value("onboardingStressLevel")       { record.onboardingStressLevel = v; changed = true }
        if record.onboardingEatingCadence == nil,    let v = value("onboardingEatingCadence")     { record.onboardingEatingCadence = v; changed = true }
        if record.onboardingEatingWindow == nil,     let v = value("onboardingEatingWindow")      { record.onboardingEatingWindow = v; changed = true }
        if record.onboardingFoodRelationship == nil, let v = value("onboardingFoodRelationship")  { record.onboardingFoodRelationship = v; changed = true }

        if changed {
            record.pendingUpsert = true
            try? modelContext.save()
        }
        defaults.set(true, forKey: flagKey)
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

        // Keep RevenueCat's appUserID aligned with the Supabase identity so
        // entitlements scope to the same user across both backends. Runs
        // FIRST (release audit 2026-08-08 — it used to run after the full
        // cloud hydrate): the re-key is independent of the model context,
        // and every second it waits is a window where a purchase lands on
        // the OUTGOING appUserID and the arriving payer stares at a wall
        // her entitlement should have dismissed. Cleans up the orphan
        // anonymous RevenueCat record created when configure() ran with
        // the bootstrap-anon uid the user later upgraded away from.
        // handleAuthChange is a no-op when newUserId matches what's
        // already synced, so the two onChange handlers in RootView don't
        // double-call this path.
        await PaymentService.shared.handleAuthChange(newUserID: newUserId)

        // Sign-in to a non-anon account from a different identity:
        // bring local rows along so the user's anonymous-period work merges
        // into the account they just signed in to. The marker written FIRST
        // makes the merge crash-safe: if the process dies anywhere between
        // here and the retry push, onLaunch finds the marker and re-runs
        // the (idempotent) merge instead of stranding the rows forever.
        var mergeInFlight = false
        if userIdChanged && !isAnonNow,
           let oldId = previousUserId, !oldId.isEmpty, oldId != newUserId {
            Self.writePendingMergeMarker(from: oldId, to: newUserId)
            mergeInFlight = true
            reattributeLocalRows(from: oldId, to: newUserId, modelContext: modelContext)
        }

        // Always push pending writes — covers signup-upgrade (where user_id
        // didn't change) and any sign-in-with-merge case above.
        await service.retryPendingUpserts()

        if mergeInFlight {
            Self.clearPendingMergeMarker()
        }

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
        // One live plan per account. A pre-fix merge (or a pre-fix hydrate
        // duplicate) can leave several active-phase plans locally AND in
        // cloud; ProgramService.activePlan sorts createdAt DESC, so the
        // junk interim plan (startDate = today) wins and the user wakes up
        // on day 1. Heal here, after plans hydrate, so the flag restore
        // below and every reader see the reconciled state.
        await reconcileLivePlans(userId: userId)
        // Session ratings run after hydrateFromCloud so the parent session
        // rows are already local (the ratings join through them on push).
        await service.hydrateSessionRatings(userId: userId)
        // v1.1.6 — evening reflections (feeling + note) restore-if-missing
        // so a reinstall keeps them (they feed jeni's context + the day
        // receipt); the upload path already existed, the read-back didn't.
        await service.hydrateDayReflections(userId: userId)
        // v8 S2/S4 — the served protocol refreshes first so the day
        // composes against the freshest sane config (bundled
        // default + last-good cache cover every failure mode). The
        // userId lets a clinician assignment redirect the resolved
        // row (S4); absent one, the org-null default stands.
        await CareProtocolStore.hydrate(userId: userId)
        // v8 — the chart: observations + regimen plans restore, then
        // the one-time backfill converts legacy day-keyed strings
        // (including the ones the reflection hydrate just restored)
        // into typed records so history is chartable.
        await service.hydrateObservations(userId: userId)
        await service.hydrateRegimenPlans(userId: userId)
        // v24 — dose events restore beside the chart they annotate.
        await service.hydrateDoseEvents(userId: userId)
        // v25 E1 — program facts restore BEFORE the bootstrap decides
        // (a second device must see the first device's migration rows
        // and write nothing).
        await service.hydrateProgramFacts(userId: userId)
        await ProgramFactStore.bootstrapIfNeeded(
            userId: userId, in: container.mainContext
        )
        await ObservationStore.backfillLegacyIfNeeded(
            userId: userId, in: container.mainContext
        )
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

        // v1.1.6 retention fix — a cloud UserRecord only exists once
        // onboarding completed (upsertLocalUserRecord runs at completion).
        // A reinstall wipes the device-local hasCompletedOnboarding, so
        // without this the returning payer is force-re-onboarded — and a
        // re-enroll mints a fresh plan with startDate = today, resetting the
        // day the founder saw disappear. Restoring it here routes the phase
        // machine back into the app instead of onboarding.
        defaults.set(true, forKey: "hasCompletedOnboarding")

        // If an active (non-archived) plan hydrated, this account was
        // enrolled — restore the enrollment flags too, or MainShell's
        // TodayHost would show the "start my program" onramp instead of
        // TodayView at their real (hydrated) day. Archived-only history
        // (finished program) correctly falls through to the onramp.
        // userId compares case-insensitively: hydrates normalize to
        // uppercase now, but a plan row a pre-fix hydrate stored
        // lowercase must not route a returning enrolled user to the
        // onramp (that re-enroll is what mints the day-resetting plan).
        let allPlans = (try? context.fetch(FetchDescriptor<ProgramPlanRecord>())) ?? []
        let hasActivePlan = allPlans.contains {
            $0.userId.caseInsensitiveCompare(userId) == .orderedSame
                && $0.archivedAt == nil
                && Self.livePlanPhases.contains($0.phase)
        }
        if hasActivePlan {
            defaults.set(true, forKey: "programEraEnabled")
            defaults.set(true, forKey: "hasEnrolledInProgram")
        }
    }

    /// Re-attribute local SessionLog + DayProgress rows from the previous
    /// user_id to the new one so they land in the signed-in account on
    /// the next push. Marks SessionLog + WeightLog rows pendingUpsert so
    /// retry sends them; DayProgress is upserted again next session.
    private func reattributeLocalRows(from oldId: String, to newId: String, modelContext: ModelContext) {
        Self.reattributeModelRows(from: oldId, to: newId, in: modelContext)
        // Food journal entries collected during the anonymous period
        // re-key the same way (views filter by current userId). The
        // persister mints fresh ids too + carries the local thumbnail
        // across; the post-sign-in hydrateFoodLogs reconcile pushes them.
        FoodLogPersister.reattributeEntries(from: oldId, to: newId)
    }

    /// Re-key the SwiftData rows an anonymous user created so they belong
    /// to the account just signed into. `static` + split out from
    /// `reattributeLocalRows` so the fresh-id invariant is unit-testable
    /// without touching the food JSONL store.
    ///
    /// THE FRESH-ID INVARIANT (the fix for "my weigh-ins reset on
    /// reinstall"): weight_logs + session_logs share a global primary-key
    /// `id`, and their rows already exist in the cloud under the OLD uid.
    /// A naive re-key (change `user_id`, keep `id`) makes the next push an
    /// upsert-on-`id` that resolves to an UPDATE of the old-owned row —
    /// and RLS's `USING (auth.uid() = user_id)` evaluates that EXISTING
    /// row, still owned by the old uid, so Postgres returns 42501 and the
    /// fire-and-forget push swallows it. The row then lives only on this
    /// device and vanishes on the next reinstall (the new account's cloud
    /// never received it). A brand-new `id` makes the push a clean INSERT
    /// the new account owns; the orphaned old-uid rows stay put, invisible
    /// to the new account under RLS. day_progress conflicts on
    /// (user_id, program_day) not id, so it re-keys cleanly — but it
    /// points at session ids, so those pointers follow the remap.
    static func reattributeModelRows(from oldId: String, to newId: String, in modelContext: ModelContext) {
        let sessions = (try? modelContext.fetch(FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        // Ratings scope through their parent session (pre-v2 rows carry no
        // userId), so collect them by the sessions' CURRENT ids, before the
        // re-key mints fresh ones. Now that session_ratings sync, they need
        // the same fresh-id + pointer-follow treatment as everything else.
        let oldSessionIds = Set(sessions.map(\.id))
        let ratings = ((try? modelContext.fetch(FetchDescriptor<SessionRatingRecord>())) ?? [])
            .filter { oldSessionIds.contains($0.sessionLogId) }
        let progress = (try? modelContext.fetch(FetchDescriptor<DayProgressRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        let weightLogs = (try? modelContext.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        // The program plan is the day anchor; its day-checks point at it.
        // Both re-key with the fresh-id invariant (same RLS-42501 reason as
        // weight/session), and the checks' programPlanId follows the plan
        // remap the way day_progress follows the session remap.
        let plans = (try? modelContext.fetch(FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        let checks = (try? modelContext.fetch(FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        // The destination account's own plans, so the merge can keep ONE
        // live plan: without these, an interim anon enrollment (startDate
        // = today, minted while the user was auto-logged-out) imports as
        // a second active plan, out-sorts the real one on createdAt, and
        // resets the account to day 1. Case-insensitive filter because a
        // pre-fix hydrate may have stored the account's plans lowercase.
        let destinationPlans = ((try? modelContext.fetch(
            FetchDescriptor<ProgramPlanRecord>())) ?? [])
            .filter { $0.userId.caseInsensitiveCompare(newId) == .orderedSame }
        applyReattribution(to: newId, sessions: sessions, progress: progress,
                           weightLogs: weightLogs, plans: plans, checks: checks,
                           existingPlans: destinationPlans, ratings: ratings)
        // v9 P1 — body scans follow the account. Local-only rows:
        // the userId flips in place (no cloud insert → no fresh-id
        // invariant), and the on-disk photos stay keyed by the same
        // scan ids.
        let scans = (try? modelContext.fetch(FetchDescriptor<BodyScanRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        for scan in scans { scan.userId = newId }
        try? modelContext.save()
    }

    /// The pure re-key mutation, split from the fetch so the fresh-id
    /// invariant is unit-testable on standalone model instances (no
    /// ModelContainer). Mutates the rows in place; the caller saves.
    static func applyReattribution(
        to newId: String,
        sessions: [SessionLogRecord],
        progress: [DayProgressRecord],
        weightLogs: [WeightLogRecord],
        plans: [ProgramPlanRecord] = [],
        checks: [ProgramDayCheckRecord] = [],
        existingPlans: [ProgramPlanRecord] = [],
        ratings: [SessionRatingRecord] = []
    ) {
        // session_logs — fresh id; remember old→new so day_progress follows.
        var sessionIdRemap: [String: String] = [:]
        for s in sessions {
            let freshId = UUID().uuidString
            sessionIdRemap[s.id] = freshId
            s.id = freshId
            s.userId = newId
            s.pendingUpsert = true
        }

        // session_ratings: synced now, so the fresh-id invariant applies
        // here too, and the sessionLogId pointer follows the session remap
        // the way day_progress does (a stale pointer would orphan the
        // rating from both the delete-account join and the cloud push).
        for r in ratings {
            r.id = UUID().uuidString
            r.userId = newId
            r.sessionLogId = sessionIdRemap[r.sessionLogId] ?? r.sessionLogId
            r.pendingUpsert = true
        }

        for p in progress {
            p.userId = newId
            p.compositeKey = "\(newId):\(p.programDay)"
            // Follow the re-keyed session ids so the day still links to its
            // session (primary + the v2 multi-session list).
            if let remapped = sessionIdRemap[p.primarySessionId] {
                p.primarySessionId = remapped
            }
            if let ids = p.sessionLogIds {
                p.sessionLogIds = ids.map { sessionIdRemap[$0] ?? $0 }
            }
            p.updatedAt = .now
        }

        // weight_logs — the load-bearing source for the analytics weight
        // trend; without a fresh id an onboarding-seeded log (or any manual
        // log from the anonymous period) never reaches the signed-in
        // account and the trend reads empty after a reinstall. No incoming
        // references, so the id swap is self-contained.
        for w in weightLogs {
            w.id = UUID().uuidString
            w.userId = newId
            w.pendingUpsert = true
        }

        // program_plans — the ANCHOR for "which day the user is on"
        // (programDay derives from plan.startDate). Conflicts on the global
        // `id` PK, so the same fresh-id invariant as weight/session applies:
        // a naive re-key would UPDATE the old-uid cloud row and hit RLS
        // 42501, stranding the enrollment on-device and resetting the day on
        // the next reinstall. Fresh id → clean INSERT the new account owns.
        var planIdRemap: [String: String] = [:]
        for plan in plans {
            let freshId = UUID().uuidString
            planIdRemap[plan.id] = freshId
            plan.id = freshId
            plan.userId = newId
            plan.pendingUpsert = true
        }
        // A re-signed plan points parentPlanId at its archived predecessor;
        // if that predecessor re-keyed in this batch, follow the remap.
        for plan in plans {
            if let parent = plan.parentPlanId, let remapped = planIdRemap[parent] {
                plan.parentPlanId = remapped
            }
        }

        // program_day_checks — the kept-item state for each day; each points
        // at its plan via programPlanId (like day_progress → session). Fresh
        // id + follow the plan remap so the checks still link to the re-keyed
        // plan under the new account.
        for check in checks {
            check.id = UUID().uuidString
            check.userId = newId
            check.programPlanId = planIdRemap[check.programPlanId] ?? check.programPlanId
            check.pendingUpsert = true
        }

        // One live plan per account. The incoming anon plan is usually an
        // interim re-enrollment (startDate = today) created while the user
        // was auto-logged-out; the account it merges into already holds
        // the genuine journey. Reconcile across destination + incoming so
        // the EARLIEST-startDate plan stays live and the interim one lands
        // archived. Pointers stay coherent: archiving never changes ids,
        // and the remaps above already ran.
        reconcileLivePlans(existingPlans + plans)
    }

    // MARK: Active-plan reconciliation (the day-1 reset heal)

    /// Phases that count as "the plan the user is living in"; mirrors
    /// ProgramService.activePlan's predicate.
    static let livePlanPhases: Set<String> = ["active", "maintenance", "recomp", "pause"]

    /// One live plan per user. When a merge or a pre-fix hydrate left
    /// several active-phase plans, the genuine journey is the one with the
    /// EARLIEST startDate. The interim junk plan is always the one minted
    /// at a forced re-enrollment with startDate = today, and letting it
    /// win (ProgramService.activePlan sorts createdAt DESC) resets the
    /// user to day 1. Keep the earliest, mark the rest abandoned +
    /// archived, and flag them pendingUpsert so the healed phase reaches
    /// the cloud even if the immediate push fails. Pure mutation, no
    /// container, so it is unit-testable like applyReattribution. Returns the
    /// plans it archived so callers can push right away.
    @discardableResult
    static func reconcileLivePlans(_ plans: [ProgramPlanRecord]) -> [ProgramPlanRecord] {
        let live = plans.filter { livePlanPhases.contains($0.phase) && $0.archivedAt == nil }
        guard live.count > 1 else { return [] }
        // Earliest startDate wins; createdAt breaks a same-day tie (the
        // original enrollment predates the interim one).
        let keeper = live.min {
            ($0.startDate, $0.createdAt) < ($1.startDate, $1.createdAt)
        }
        var archived: [ProgramPlanRecord] = []
        for plan in live where plan !== keeper {
            plan.phase = "abandoned"
            plan.archivedAt = .now
            plan.updatedAt = .now
            plan.pendingUpsert = true
            archived.append(plan)
        }
        return archived
    }

    /// Post-hydrate heal for accounts already corrupted in the field: if
    /// this user has multiple live plans locally (junk interim plan +
    /// the real journey, both hydrated), archive everything but the
    /// earliest-startDate one and push the archived phase so the CLOUD
    /// heals too; otherwise every reinstall re-imports the corruption.
    private func reconcileLivePlans(userId: String) async {
        guard let service = syncService, let container = modelContainer else { return }
        let context = container.mainContext
        let mine = ((try? context.fetch(FetchDescriptor<ProgramPlanRecord>())) ?? [])
            .filter { $0.userId.caseInsensitiveCompare(userId) == .orderedSame }
        let archived = Self.reconcileLivePlans(mine)
        guard !archived.isEmpty else { return }
        try? context.save()
        for plan in archived {
            await service.upsertProgramPlan(plan)
        }
    }

    // MARK: Pending-merge marker (crash-safe sign-in merge)

    /// UserDefaults key holding ["from": oldUid, "to": newUid] while a
    /// sign-in merge is in flight. Written before reattribution starts,
    /// cleared after the merge AND its retry push complete, so a process
    /// death anywhere in between leaves the marker for onLaunch to resume.
    private static let pendingMergeKey = "sync.pendingMergeV1"

    static func writePendingMergeMarker(from oldId: String, to newId: String) {
        UserDefaults.standard.set(["from": oldId, "to": newId], forKey: pendingMergeKey)
    }

    static func clearPendingMergeMarker() {
        UserDefaults.standard.removeObject(forKey: pendingMergeKey)
    }

    static func pendingMergeMarker() -> (from: String, to: String)? {
        guard
            let dict = UserDefaults.standard.dictionary(forKey: pendingMergeKey) as? [String: String],
            let from = dict["from"], let to = dict["to"],
            !from.isEmpty, !to.isEmpty, from != to
        else { return nil }
        return (from, to)
    }

    /// Re-run an interrupted sign-in merge. Idempotent by construction:
    /// reattributeLocalRows only fetches rows still keyed to the OLD uid,
    /// so a completed merge is a no-op and a half-finished one only picks
    /// up the stranded remainder. Rows re-keyed by the crashed pass kept
    /// their fresh ids + pendingUpsert flag, so the retry push (not a
    /// second re-key) is what lands them; no double-minting.
    private func resumePendingMergeIfNeeded(modelContext: ModelContext) -> Bool {
        guard let marker = Self.pendingMergeMarker() else { return false }
        #if DEBUG
        print("[AppSync] resuming interrupted merge \(marker.from) → \(marker.to)")
        #endif
        reattributeLocalRows(from: marker.from, to: marker.to, modelContext: modelContext)
        return true
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

    /// Fire-and-forget push for a post-session rating. Optional at the
    /// write site: new ratings init with pendingUpsert = true, so the
    /// launch retry sweep lands them even if nobody calls this.
    func upsertSessionRating(_ rating: SessionRatingRecord) async {
        guard let service = syncService else { return }
        await service.upsertSessionRating(rating)
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
            // v1.1.5 — nil when the plate carried no sugar, so a nil is
            // omitted from the upsert (encodeIfPresent) rather than
            // written as a fabricated 0.
            sugar_g: entry.sugar > 0 ? entry.sugar : nil,
            // food_logs.source CHECK list mirrors FoodCapture raw
            // values; old pre-D3.B entries carry nil → 'photo'.
            source: entry.source ?? "photo",
            // v9 P5 — the story data rides the payload jsonb: sodium
            // + sat-fat (nil-when-0, never fabricated) and the
            // per-ingredient ledger, so a reinstall keeps the detail.
            payload: .init(
                title: entry.title.isEmpty ? nil : entry.title,
                sodium_mg: entry.sodiumMg > 0 ? entry.sodiumMg : nil,
                saturated_fat_g: entry.satFatG > 0 ? entry.satFatG : nil,
                items_detail: entry.itemsDetail.map { details in
                    details.map {
                        SyncService.FoodLogSyncRow.Payload.ItemRow(
                            name: $0.name, portion_g: $0.portionG,
                            kcal: $0.kcal, protein_g: $0.protein,
                            carbs_g: $0.carbs, fat_g: $0.fat,
                            sodium_mg: $0.sodiumMg, sat_fat_g: $0.satFatG
                        )
                    }
                }
            )
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

    /// Release audit 2026-08-08 — push-only food reconcile (the cheap
    /// half of hydrateFoodLogs). Uploads local entries the server
    /// doesn't have; never pulls, never merges. A nil id fetch means
    /// the select itself failed — skip rather than blind-push into a
    /// dead network.
    private func pushLocalFoodEntriesMissingFromServer(userId: String) async {
        guard let service = syncService, !userId.isEmpty else { return }
        let local = FoodLogPersister.allSyncableEntries(userId: userId)
        guard !local.isEmpty else { return }
        guard let remoteIds = await service.fetchFoodLogIds(userId: userId) else { return }
        for entry in local where !remoteIds.contains(entry.id.lowercased()) {
            await service.upsertFoodLog(Self.syncRow(from: entry))
        }
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
                sugar: row.sugar_g ?? 0,
                sodiumMg: row.payload?.sodium_mg ?? 0,
                satFatG: row.payload?.saturated_fat_g ?? 0,
                itemsDetail: row.payload?.items_detail.map { rows in
                    rows.map {
                        FoodLogPersister.ItemDetail(
                            name: $0.name, portionG: $0.portion_g,
                            kcal: $0.kcal, protein: $0.protein_g,
                            carbs: $0.carbs_g, fat: $0.fat_g,
                            sodiumMg: $0.sodium_mg, satFatG: $0.sat_fat_g
                        )
                    }
                },
                title: row.payload?.title ?? "",
                source: row.source
            )
        }
        FoodLogPersister.mergeRemote(remote)

        // Lowercase both sides: server uuids come back lowercase, local ids
        // are uppercase UUID().uuidString — a case-sensitive miss here just
        // re-pushes rows the server already has.
        let remoteIds = Set(rows.map { $0.id.lowercased() })
        for entry in FoodLogPersister.allSyncableEntries(userId: userId)
        where !remoteIds.contains(entry.id.lowercased()) {
            await service.upsertFoodLog(Self.syncRow(from: entry))
        }

        // Photo cloud backup — push any queued offline uploads, then pull
        // thumbnails for entries that have no local photo (reinstall / new
        // device). Both are idempotent and swallow network errors.
        await FoodPhotoSyncService.shared.flushPendingUploads(userId: userId)
        await FoodPhotoSyncService.shared.hydrateMissingPhotos(userId: userId)
    }

    // MARK: - Program (v1.1 program pivot)

    /// v2.6 — the evening reflection (jeni's memory seam).
    func upsertDayReflection(
        userId: String, dayKey: String, feeling: String, note: String?
    ) async {
        guard let service = syncService, !userId.isEmpty else { return }
        await service.upsertDayReflection(
            userId: userId, dayKey: dayKey, feeling: feeling, note: note
        )
    }

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

    // MARK: - Served protocol (app v8 S2)

    func fetchServedProtocolData(id: String) async -> Data? {
        guard let service = syncService else { return nil }
        return await service.fetchServedProtocolData(id: id)
    }

    // App v8 S4 — the assignment resolver + packet transport.

    func fetchAssignedProtocolId(userId: String) async -> String? {
        guard let service = syncService, !userId.isEmpty else { return nil }
        return await service.fetchAssignedProtocolId(userId: userId)
    }

    /// v9 P6 — the weekly-summary pass-through.
    func publishWeeklySummary(
        id: String, userId: String, orgId: String,
        weekKey: String, payload: Data, appVersion: String?
    ) async {
        guard let service = syncService else { return }
        await service.publishWeeklySummary(
            id: id, userId: userId, orgId: orgId,
            weekKey: weekKey, payload: payload, appVersion: appVersion
        )
    }

    func publishVisitPacket(
        id: String, userId: String, orgId: String,
        payload: Data, windowStart: String?, windowEnd: String?, appVersion: String?
    ) async {
        guard let service = syncService else { return }
        await service.publishVisitPacket(
            id: id, userId: userId, orgId: orgId, payload: payload,
            windowStart: windowStart, windowEnd: windowEnd, appVersion: appVersion
        )
    }

    func upsertConsentGrant(_ grant: ConsentGrantRecord) async {
        guard let service = syncService else { return }
        guard !grant.userId.isEmpty else { return }
        await service.upsertConsentGrant(grant)
    }

    // MARK: - Observations + regimen (app v8 — the chart)

    func upsertObservation(_ record: ObservationRecord) async {
        guard let service = syncService else { return }
        guard !record.userId.isEmpty else { return }
        await service.upsertObservation(record)
    }

    func upsertRegimenPlan(_ plan: RegimenPlanRecord) async {
        guard let service = syncService else { return }
        guard !plan.userId.isEmpty else { return }
        await service.upsertRegimenPlan(plan)
    }

    // v24 THE REGIMEN — dose events (docs/app_v24 §3.3).

    func upsertDoseEvent(_ event: DoseEventRecord) async {
        guard let service = syncService else { return }
        guard !event.userId.isEmpty else { return }
        await service.upsertDoseEvent(event)
    }

    // v25 E1 THE SPINE — program facts (docs/app_v25/05_E1_SPINE §1).

    func upsertProgramFact(_ fact: ProgramFactRecord) async {
        guard let service = syncService else { return }
        guard !fact.userId.isEmpty else { return }
        await service.upsertProgramFact(fact)
    }

    func deleteDoseEvent(id: String) async {
        guard let service = syncService else { return }
        await service.deleteDoseEvent(id: id)
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

        // Release audit 2026-08-08: purge opted-in body-scan cloud copies
        // BEFORE the RPC, awaited — the old fire-and-forget ran after
        // auth.users was already deleted, racing the session teardown,
        // and silently lost. Order matters: the storage RLS needs a
        // living auth uid. Best-effort (never blocks the deletion the
        // user asked for) — the updated delete_user_account RPC now
        // purges the body-scans bucket server-side as the backstop.
        if let userId = userIdToWipe, !userId.isEmpty {
            await BodyScanSyncService.shared.deleteAllRemote(userId: userId)
        }

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
        // never gets a stray affirmation / win-back after wiping. The
        // trial-end reminder sweeps too: it previously had no caller on
        // this path, so a deleted account could still get "trial ends
        // tomorrow" on this device.
        RetentionNotifications.cancelAll()
        await TrialEndNotificationService.shared.cancelAllTrialReminders()
        #if DEBUG
        print("[AppSync] deleteCurrentAccount: UserDefaults onboarding keys cleared")
        #endif

        do {
            try await AuthService.shared.signOut()
            #if DEBUG
            print("[AppSync] deleteCurrentAccount: signOut + re-bootstrap complete; EXIT success")
            #endif
        } catch {
            // Release audit 2026-08-08: do NOT rethrow — the RPC already
            // succeeded, so the account IS deleted; surfacing "couldn't
            // delete account" here was a false failure that invited
            // pointless retries. The dead session self-heals at next
            // launch (sessionless signOut returns early; bootstrap mints
            // a fresh anonymous identity).
            #if DEBUG
            print("[AppSync] deleteCurrentAccount: signOut threw (cloud already deleted; reporting success). Error: \(error)")
            #endif
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

        // v8 — the chart + regimen plans are userId-scoped SwiftData;
        // delete-account removes them (sign-out keeps them, like
        // weight logs).
        ObservationStore.deleteAll(userId: userId, in: context)

        // v9 P1 — body scans: records AND their on-device images go
        // together (L4: the sweep ships in the same commit as the
        // store). Cloud copies are purged pre-RPC in
        // deleteCurrentAccount (awaited, while the session is alive)
        // with the delete_user_account RPC as the server backstop.
        BodyScanStore.deleteAll(userId: userId, in: context)

        // Release audit 2026-08-08: five families survived "delete
        // account" on device — most sensitively the full chat
        // transcript and weight history (hidden by userId filters but
        // present on disk and in device backups). Deletion means
        // deletion.
        let weightsDescriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let weights = try? context.fetch(weightsDescriptor) {
            for w in weights { context.delete(w) }
        }
        let plansDescriptor = FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let plans = try? context.fetch(plansDescriptor) {
            for p in plans { context.delete(p) }
        }
        let checksDescriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let checks = try? context.fetch(checksDescriptor) {
            for c in checks { context.delete(c) }
        }
        let chatDescriptor = FetchDescriptor<ChatMessageRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let messages = try? context.fetch(chatDescriptor) {
            for m in messages { context.delete(m) }
        }
        let consentsDescriptor = FetchDescriptor<ConsentGrantRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let consents = try? context.fetch(consentsDescriptor) {
            for c in consents { context.delete(c) }
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
            // v8 THE DOOR — the clinic fork + entitlement are
            // user-scoped: a new account on this device must never
            // inherit the prior user's provider link or wall bypass.
            "onb_v8_door", "onb_v8_clinic_org", "care_entitlement_active",
            // FIX 4 (2026-06-29) gender + height (BMR-formula inputs) and the
            // cohort-aware soft-tier floor are user-scoped - sweep them so a
            // new account on the same device never inherits the prior user's
            // body data or pacing. (onboardingHeightCm was missing too.)
            "onboardingGender", "onboardingHeightCm", "onboardingSoftFloorRate",
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
            // programEraEnabled was missing from the sweep: the next
            // identity on this device routed into TodayView with a nil
            // plan instead of the onramp. It re-restores on hydrate for
            // genuinely enrolled accounts.
            "programEraEnabled",
            // Sync bookkeeping is identity-scoped too: a stale merge
            // marker or hydrate day-stamp must not leak across accounts.
            "sync.pendingMergeV1", "sync.launchHydrateStamp",
            // v5.1 first-use teaching — a new account on this device
            // should meet the map again.
            "howItWorks.dismissed",
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
            // v8 Stage A rider — canonical OV5 mirror keys that were
            // MISSING from this explicit list (the onb_v5_ prefix
            // sweep never covered them; identity data leaked to the
            // next account on shared devices). Audit source:
            // docs/app_v8/08_STAGE_A.md anchors pass.
            "onboarding_dietary", "onboarding_medication_status",
            "onboarding_goal_direction", "onboarding_glp1_stop_window",
            "onboarding_appetite_return", "onb_fear_offramp",
            "onb_fear_regain", "medicalDisclaimerAckAtISO",
            // Release audit 2026-08-08 — program mode + the v8 clinic
            // code path are per-identity (the next account must not
            // inherit maintenance mode or a clinic fork), and the
            // conversion one-shots are per-identity funnel state.
            "program_mode", "onb_v8_code_path",
            "downsellShownOnce", "upgradeMoment.shownV1",
            "smallerStepShownOnce",
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }

        // v2.8 identity audit — DATE-SUFFIXED user-scoped families
        // added by app v2 (evening feeling, her-file note, kept rep,
        // day-progress mirrors, anchor refresh guard). These are
        // per-identity: the note reaches jeni's context envelope, so
        // leaking it to the next account on this device would hand
        // one user's private words to another user's coach. Prefix
        // sweep because the keys carry dayKey suffixes.
        let scopedPrefixes = [
            "day.note.", "day.reflection.", "lesson.rep.kept.",
            "stats.shown_up_count", "day1Promise",
            "orchestrator.anchorRefreshDayKey",
            // v3 spine: presence ledger (kept days + day marker +
            // migration flag) and break state are per-identity.
            "presence.", "break.",
            // v3 chapters: sit-notes feed jeni's reading; the band
            // (settle weight + last zone) is her body's data.
            "day.sit.", "band.",
            // v8 — the dose-day mark was WRITTEN since mission 3 but
            // never swept (audit defect: a cross-account leak class);
            // the backfill flag is per-identity so the next account
            // backfills its own history.
            "day.dose.", "observations.",
            // v4 spine: the re-signing's consented knobs (protein
            // adjust, sessions adjust, weigh cadence, intent picks)
            // are per-identity plan state — leaking them would bend
            // the next account's program with her consents.
            "plan.", "review.",
            // Onboarding v5 store's private mirror keys (onb_v5_gender,
            // onb_v5_weight_kg, onb_v5_height_cm, onb_v5_age_years,
            // onb_v5_identity…). OV5Store.init re-reads these, so a new
            // account onboarding on this device would see the prior
            // user's body data + identity pre-filled into the rulers.
            "onb_v5_",
            // v9 P1 — Body Vision preferences (consent seen, render
            // choice, backup opt-in) are per-identity; the next
            // account must meet its own consent sheet.
            "bodyScan.",
            // Release audit 2026-08-08 — the ENTIRE safety-gate family
            // (pregnancy status, SCOFF eating-pattern screen, pace cap,
            // numeric suppression, screen-completed/checkin-seen flags)
            // was never swept: user A's clinical answers survived
            // sign-out AND account deletion on this device, bent user
            // B's program caps, and could suppress B's own safety
            // screening entirely. The most sensitive cross-account
            // leak class in the app.
            "safety_",
            // v24 THE REGIMEN — the consult's medication answers
            // (route / product / dose / hour) are her clinical
            // intake; the next account must never see them
            // pre-filled or bridged into ITS regimen at completion.
            "onb_med_",
        ]
        for key in defaults.dictionaryRepresentation().keys {
            if scopedPrefixes.contains(where: { key.hasPrefix($0) }) {
                defaults.removeObject(forKey: key)
            }
        }

        // The v2.6 anchor ladder is per-identity content (her name,
        // her program day) — remove the rungs alongside the legacy
        // reminder so the next account never hears the prior user's
        // plan.
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: NotificationOrchestrator.ladderIds
                + NotificationOrchestrator.legacyIds
                + NotificationOrchestrator.jitaiIds   // v3 phase-7 pings
                + [NotificationOrchestrator.reSigningKnockId]   // v4 knock
        )

        // Release audit 2026-08-08 — two more identity boundaries:
        // RevenueCat's device-scoped wall residue (wasEverEntitled +
        // cached entitlement) must not compose the next account's wall
        // or arm a silent receipt transfer against the wrong user, and
        // PostHog must forget the outgoing person — posthog-ios ignores
        // identify() with a new distinct id until reset(), so without
        // this every post-sign-out event (including another account's
        // purchases) kept attributing to the signed-out user.
        PaymentService.shared.clearDeviceEntitlementResidueForSignOut()
        Analytics.resetIdentity()
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
        // The trial-end reminder is scheduled per-identity from the
        // paying user's entitlement; it had no sign-out caller, so the
        // next identity on this device inherited the prior user's
        // "trial ends tomorrow" ping. Fire-and-forget Task because this
        // sweep is synchronous by contract (runs before signOut).
        Task { await TrialEndNotificationService.shared.cancelAllTrialReminders() }
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

    /// Throttle stamp for the launch hydrate: "<userId>:<startOfDay>".
    /// Prevents a family that is legitimately empty (user never weighed
    /// in, say) from triggering a network hydrate on every single launch.
    private static let launchHydrateStampKey = "sync.launchHydrateStamp"

    /// The launch hydrate decision, per entity family. The old gate
    /// counted only SessionLogRecord, so ONE existing session log blocked
    /// hydration of weight logs, plans, checks, reflections, and food
    /// logs forever; a partial store never healed. Hydrates are
    /// insert-only, so over-hydrating is safe; the day stamp keeps the
    /// worst case at one needless network pass per day.
    private func shouldHydrateOnLaunch(modelContext: ModelContext, userId: String) -> Bool {
        let defaults = UserDefaults.standard
        let stamp = "\(userId):\(Int(Calendar.current.startOfDay(for: .now).timeIntervalSince1970))"
        guard defaults.string(forKey: Self.launchHydrateStampKey) != stamp else { return false }
        guard isAnySyncedFamilyEmpty(modelContext: modelContext, userId: userId) else { return false }
        defaults.set(stamp, forKey: Self.launchHydrateStampKey)
        return true
    }

    /// True when any synced entity family has zero rows VISIBLE to the
    /// current user (predicates are case-sensitive on purpose: rows a
    /// pre-fix hydrate stored lowercase are invisible to readers, and the
    /// re-hydrate is exactly what re-cases them).
    private func isAnySyncedFamilyEmpty(modelContext: ModelContext, userId: String) -> Bool {
        func count<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> Int {
            (try? modelContext.fetchCount(descriptor)) ?? 0
        }
        if count(FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.userId == userId })) == 0 { return true }
        if count(FetchDescriptor<DayProgressRecord>(
            predicate: #Predicate { $0.userId == userId })) == 0 { return true }
        if count(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId })) == 0 { return true }
        if count(FetchDescriptor<ProgramPlanRecord>(
            predicate: #Predicate { $0.userId == userId })) == 0 { return true }
        if count(FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { $0.userId == userId })) == 0 { return true }
        // Evening reflections live in UserDefaults, not SwiftData; any
        // key of the family counts as presence (restore-if-missing makes
        // over-hydrating a no-op anyway).
        if !UserDefaults.standard.dictionaryRepresentation().keys
            .contains(where: { $0.hasPrefix("day.reflection.") }) { return true }
        // Food journal lives in PlankFood's JSONL store.
        if FoodLogPersister.allSyncableEntries(userId: userId).isEmpty { return true }
        return false
    }
}
