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
    /// p61 — posted once per completed `hydrateAndSync`, so mounted
    /// surfaces can repaint on the freshly-landed record instead of
    /// waiting for an unrelated signal.
    static let appSyncDidHydrate = Notification.Name("appSyncDidHydrate")
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

        // v25 §45 — THE SPINE'S REFUSAL FINALLY HAS SOMEWHERE TO GO.
        // Between 2026-08-10 and 2026-08-15 every program-fact and
        // weekly-read call returned 42501 and every one of them was
        // swallowed: the writes are fire-and-forget, the hydrates print
        // only under DEBUG. `SyncHealth` classifies the code, stays
        // silent for anything positively transient, and speaks at most
        // once per family per reason per day. Categorical payload only.
        SyncService.structuralFailureReporter = { family, code in
            SyncHealth.report(family: family, code: code)
        }

        // Food journal sync seam — PlankFood fires these after local
        // writes; we mirror to the food_logs table. Fire-and-forget:
        // logging requires the network anyway (the vision EF), so a
        // failed upsert here is rare and the launch reconcile in
        // hydrateFoodLogs sweeps up stragglers.
        FoodLogPersister.onEntryPersisted = { entry in
            Task { await AppSync.shared.upsertFoodLog(entry) }
        }
        Self.installFoodDeletionSeam()

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

    /// **THE FOOD DELETION CHOKEPOINT**, extracted as a static so the
    /// seam a test installs IS the seam the product installs — never a
    /// closure copied into a fixture, which is how a chokepoint stops
    /// testing the chokepoint (`35` §2, `37` §17).
    ///
    /// `FoodLogPersister` lives in `Packages/PlankFood` and cannot see
    /// `DeletionLedger`, so the tombstone is written HERE, on the one
    /// hook every food delete already fires. Idempotent.
    static func installFoodDeletionSeam() {
        FoodLogPersister.onEntryDeleted = { entryId, userId in
            // v25 §38 — the deletion is recorded BEFORE the network
            // call, so a delete made offline is still remembered by
            // the device that made it.
            DeletionLedger.record(id: entryId, userId: userId)
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
    }

    // MARK: Bootstrap

    /// Called once after AuthService.bootstrap completes and the model
    /// container is configured. Finishes any sign-in merge a prior process
    /// death interrupted, retries pending Supabase upserts from prior
    /// crashes, and hydrates from cloud when any synced entity family is
    /// locally empty for this user (fresh install OR a partial store;
    /// hydrates are insert-only, so over-hydrating is safe).
    func onLaunch(modelContext: ModelContext) async {
        // v25 §39 — FIRST, AND BEFORE EVERY GUARD BELOW. A deletion the
        // server completed and this device did not finish must converge
        // on the next launch, whatever else is true: no sync service, no
        // session, no network. It is scoped to the account named in the
        // intent, which is routinely NOT the account the app is holding
        // by now.
        Self.finishInterruptedAccountDeletion(in: modelContext)

        guard let service = syncService else { return }
        let userId = AuthService.shared.currentUser?.id.uuidString ?? ""
        lastUserId = userId
        lastAuthMethod = AuthService.shared.authMethod
        guard !userId.isEmpty else { return }

        // THE TRUTH REFRESH, first thing and before anything can dirty a
        // row. See `refreshProgramTruth`: without it a settled user's
        // phone can never receive a support repair, and running it AFTER
        // `retryPendingUpserts` would let a stale local row push itself
        // over the repair before ever reading it.
        await refreshProgramTruth(userId: userId, modelContext: modelContext)

        // 2026-06-23 one-time back-fill: pull the cohort + clinical intake
        // signals out of @AppStorage into the synced UserRecord for users who
        // onboarded before the persistence P0 (their answers were local-only).
        // Sets pendingUpsert, so the retry just below pushes them to Supabase.
        backfillCohortIntakeIfNeeded(modelContext: modelContext, userId: userId)

        // v25 §42 — **THE SERVER FACT IS ASKED FOR BEFORE THE LOCAL ONE
        // IS TRUSTED.**
        //
        // This is the recovery route for the case `40` could not close
        // and `41` could only design: the app died after the destination
        // authenticated, and every local record of what was owed is
        // gone — swept, reinstalled, or never written because the
        // process died first.
        //
        // `complete_account_handoff` takes NO arguments. There is
        // nothing for this device to remember and nothing for it to
        // supply: the server matches the caller's own Apple identity
        // against receipts the source itself pre-committed. So the
        // discovery is one unconditional call for any permanent account,
        // and on a device with nothing owed it is one indexed lookup
        // that returns {0, 0}.
        //
        // It runs BEFORE `resumePendingMergeIfNeeded`, because if it
        // moves the rows it changes the ID POLICY that resume must use.
        await dischargeOwedHandoffIfNeeded()

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
        } else {
            // p55 — the deletion-ledger sweep must not be gated behind
            // the hydrate: a settled payer (no locally-empty family)
            // never hydrates, so an OFFLINE delete whose server call
            // failed was never re-asserted — the plate stayed on the
            // server forever and returned on her next reinstall. The
            // sweep is idempotent and zero work on a normal launch.
            _ = DeletionLedger.sweep(userId: userId, in: modelContext)
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

        // v25 §41 — **THE ONE ORCHESTRATOR.** Three different operations
        // shared one condition (`userIdChanged && !isAnonNow`) for the
        // whole life of this product. They are named now, and the rule
        // that separates them is a pure function a test can read rather
        // than a condition inside an async view-driven body.
        //
        //   UPGRADE  anonymous A → permanent A   carries nothing
        //   ADOPT    anonymous A → permanent B   carries the anonymous
        //                                        period, and only it
        //   SWITCH   permanent A → permanent B   carries NOTHING and
        //                                        isolates A
        let operation = AccountOperationClassifier.classify(
            previousUid: previousUserId,
            previousMethod: previousMethod,
            newUid: newUserId,
            newIsAnonymous: isAnonNow
        )

        // OPERATION C — SWITCH ACCOUNT. **NAMED → NAMED IS ACCOUNT
        // SWITCHING. IT IS NEVER DATA MIGRATION.**
        //
        // `40` closed the SwiftData half of this by refusing the merge.
        // The other half was never closed and is not SwiftData at all:
        // the cross-account isolation sweep runs on explicit SIGN-OUT
        // and on account deletion, and on NOTHING ELSE — so a sign-in
        // that changed accounts left every device-scoped customer-
        // authored key in place. Account B's MOVE sheet listed account
        // A's workouts and counted them in Home's strength tile; Home
        // and `TodayStateService` read A's evening feeling and her
        // `day.note.*` words, which reach Jeni's own context envelope;
        // A's `safety_*` verdicts still capped B's program; and A's
        // body facts survived wherever B's profile row carries a null.
        //
        // It runs FIRST — before the RevenueCat re-key, before any
        // hydrate, before anything reads for the incoming account — so
        // no surface ever composes B out of A's answers. `35` already
        // tested and accepted the trade this makes (the sweep happens
        // before the next identity's own state can be restored, so the
        // choice is between losing device-local state and handing it to
        // a stranger), and `syncUserDefaultsFromUserRecord` puts B's own
        // answers back from B's own record moments later.
        Self.applyIsolationIfNeeded(for: operation)

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
        //
        // v25 §40 — THE MERGE IS FOR AN ANONYMOUS PERIOD, AND ONLY FOR
        // ONE. Without `previousMethod == .anonymous` this branch also
        // fires on a NAMED → NAMED switch (the re-auth sheet, the wall's
        // recovery sheet, the paywall's), and it would carry account A's
        // weigh-ins, plates, plans and — as of this build — her doses,
        // symptoms, regimen and transcript INTO ACCOUNT B. That is a
        // cross-account leak, not a merge. The function's own doc
        // comment has always said "so the user's anonymous-period work
        // merges into the account they just signed in to"; the guard
        // now says it too.
        var carried = false
        if operation.carriesTheAnonymousPeriod, let oldId = operation.source {
            // v25 §42 — the marker was already written AT THE SWITCH by
            // `AuthService.retireAbandonedAnonymousAccount`, together
            // with the id policy the server's answer determined. Reading
            // it back rather than re-deriving it is the point: this
            // function runs off a SwiftUI `onChange` and cannot know
            // what the RPC replied.
            let idPolicy = Self.pendingMergeIdPolicy()
            Self.writePendingMergeMarker(from: oldId, to: newUserId, idPolicy: idPolicy)
            // v25 §41 — the carry now REPORTS whether it committed. It
            // is one context and one `save()`, so a single unique-key
            // violation discards every family at once; clearing the
            // receipt regardless (below) made that silent AND permanent.
            carried = reattributeLocalRows(
                from: oldId, to: newUserId, modelContext: modelContext, idPolicy: idPolicy
            )
        }

        // Always push pending writes — covers signup-upgrade (where user_id
        // didn't change) and any sign-in-with-merge case above.
        await service.retryPendingUpserts()

        if carried {
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

    /// v25 §40 — pure, so the rule is a testable sentence rather than a
    /// condition buried in a view-driven async function (`36` §2: a rule
    /// inside a body cannot be tested, which is why nobody notices it is
    /// a rule).
    ///
    /// ▎ THE MERGE CARRIES AN ANONYMOUS PERIOD INTO AN ACCOUNT. IT IS
    /// ▎ NOT A WAY TO MOVE ONE ACCOUNT'S RECORD INTO ANOTHER.
    ///
    /// Without `previousMethod == .anonymous` this fires on a NAMED →
    /// NAMED switch too — reachable from the re-auth sheet, the wall's
    /// recovery sheet and the paywall's — and carries account A's
    /// weigh-ins, plates, plans, doses, symptoms, regimen and transcript
    /// into account B on the same phone.
    ///
    /// v25 §41 — it now DELEGATES to `AccountOperationClassifier`, so
    /// there is exactly one rule in the product rather than a condition
    /// here and a second one wherever the next caller needs it. The
    /// signature is unchanged and every assertion `40` pinned on it
    /// still holds.
    nonisolated static func shouldMergeAnonymousPeriod(
        userIdChanged: Bool,
        isAnonNow: Bool,
        previousMethod: AuthMethod,
        previousUserId: String?,
        newUserId: String
    ) -> Bool {
        guard userIdChanged else { return false }
        return AccountOperationClassifier.classify(
            previousUid: previousUserId,
            previousMethod: previousMethod,
            newUid: newUserId,
            newIsAnonymous: isAnonNow
        ).carriesTheAnonymousPeriod
    }

    /// v25 §41 — the SWITCH half of the orchestrator, as a named
    /// function rather than three lines inside an async body, so the
    /// wiring itself is what a test drives (`36` §2: a rule inside a
    /// body cannot be tested, which is why nobody notices it is a rule).
    ///
    /// Returns whether it isolated, so the caller and the test read the
    /// same answer.
    @discardableResult
    @MainActor
    static func applyIsolationIfNeeded(for operation: AccountOperation) -> Bool {
        guard operation.isolatesTheOutgoingAccount else { return false }
        #if DEBUG
        print("[AppSync] account switch: isolating the outgoing account")
        #endif
        shared.clearOnboardingUserDefaults()
        return true
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

        // v25 §43 — **THE FACTS MUST NOT ARRIVE LAST.**
        //
        // MEASURED ON A REAL PHONE, 2026-08-15: a returning payer signed
        // in at 06:25:05. The LAST step of this function is what puts her
        // height, weight, goal, cohort and enrollment flags back, and it
        // did not land until ~06:25:40. For those THIRTY-FIVE SECONDS the
        // app is fully interactive and knows none of her facts, so
        // `MainShell` showed her the "start my program" onramp — and at
        // 06:25:10 she tapped it. A SECOND LIVE PROGRAM PLAN was minted
        // with `started_at = today` (`5d7158d6…`, archived by hand
        // afterwards). The tail of this very function already names that
        // outcome — *"a re-enroll mints a fresh plan with startDate =
        // today, resetting the day"* — so the repair was written; it was
        // merely scheduled behind seventeen network calls.
        //
        // The restore was never broken. The device observation showed the
        // record found, exact-case matched, not pending, carrying every
        // fact, and filling the one key that was missing. **It was late,
        // and late is the whole defect.**
        //
        // It reads a LOCAL SwiftData record and needs no network at all,
        // so running it FIRST heals the sign-out → sign-in case (the
        // record is already on disk) in milliseconds instead of half a
        // minute. Running it again once the profile and the plans have
        // landed heals the REINSTALL case after four calls instead of
        // seventeen. The existing call at the end stays, because families
        // that hydrate later can still promote a flag.
        //
        // Safe to call early, and that is a property of the function
        // rather than a hope: every write it makes is MONOTONE. It sets
        // `hasCompletedOnboarding`, `programEraEnabled` and
        // `hasEnrolledInProgram` only to TRUE, never to false; and
        // `restoreBodyDefaults` / `restoreCohortDefaults` refuse a
        // pending record and never adopt an absent server value. An extra
        // call can restore a fact sooner. It cannot remove one.
        syncUserDefaultsFromUserRecord(context: container.mainContext, userId: userId)

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
        // v25 §43 — the REINSTALL case. The profile row and the plans now
        // exist locally, which is everything the onramp decision needs, so
        // the flags stop waiting on thirteen further network calls.
        syncUserDefaultsFromUserRecord(context: container.mainContext, userId: userId)
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
        await service.hydrateWeeklyReads(userId: userId)
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
        // v25 §38 — the visit-packet consent grant had an upsert and no
        // hydrate, so the toggle showed a DEVICE fact where the
        // customer reads an ACCOUNT fact, a revoke made on one phone
        // was invisible on the other, and re-granting on a new device
        // inserted a SECOND active row for one decision. Insert-only by
        // id, like the four hydrates above it; a failed read leaves the
        // toggle OFF, because unknown consent is never permission.
        await service.hydrateConsentGrants(userId: userId)
        syncUserDefaultsFromUserRecord(context: container.mainContext, userId: userId)
        // v25 §38 — LAST, and after every insert-only hydrate above.
        // A record this device deleted must not return because a stale
        // device pushed it back; the sweep removes it again and
        // re-asserts the server delete. Zero work on a normal launch.
        DeletionLedger.sweep(userId: userId, in: container.mainContext)

        // p61 — the hydrate finally SAYS it finished. Its seventeen
        // network calls land into SwiftData and UserDefaults with no
        // repaint signal of their own, so a mounted Home sat on
        // pre-hydrate numbers until an unrelated notifier happened to
        // fire (a measured 35s window on a real phone). One post, and
        // any surface that composes from the record can re-read.
        NotificationCenter.default.post(name: .appSyncDidHydrate, object: nil)
    }

    /// Day stamp for the truth refresh, "<userId>:<startOfDay>". Its own
    /// key, not the launch hydrate's: the two run on different
    /// conditions and sharing a stamp would let either suppress the
    /// other. Identity-scoped, so it is swept on sign-out.
    private static let truthRefreshStampKey = "sync.truthRefreshStamp"

    /// **CAN A SUPPORT REPAIR REACH AN INSTALLED PHONE?** Until
    /// 2026-08-14 the answer was: only if she signs out and back in, or
    /// reinstalls.
    ///
    /// Three walls stood between a corrected database row and the screen:
    ///
    ///   1. `shouldHydrateOnLaunch` only fires when some synced family is
    ///      locally EMPTY. A user with sessions, weigh-ins, a plan, day
    ///      checks, a reflection and one food entry has none — so the
    ///      launch hydrate never ran for exactly the people who have been
    ///      paying longest.
    ///   2. `applyHydratedProgramPlans` was insert-only, so even when it
    ///      did run it skipped a plan it already had (now
    ///      `ProgramPlanMerge`).
    ///   3. `restoreBodyDefaults` was absent-only, so a corrected goal
    ///      landed in the local `UserRecord` and never reached the
    ///      `@AppStorage` key every surface actually reads (now merged
    ///      under the same clean-record guard).
    ///
    /// This is wall 1. Two selects — `users` and `program_plans` — once
    /// per user per day, for a user who has finished onboarding. It does
    /// not touch history: no sessions, no checks, no food, no photos.
    private func refreshProgramTruth(userId: String, modelContext: ModelContext) async {
        guard let service = syncService, let container = modelContainer else { return }
        // Nothing to repair before she has a program at all, and mirroring
        // a half-built record over a consult in progress would be its own
        // bug.
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }

        let defaults = UserDefaults.standard
        let stamp = "\(userId):\(Int(Calendar.current.startOfDay(for: .now).timeIntervalSince1970))"
        guard defaults.string(forKey: Self.truthRefreshStampKey) != stamp else { return }
        defaults.set(stamp, forKey: Self.truthRefreshStampKey)

        await service.hydrateProgramTruth(userId: userId)

        let context = container.mainContext
        let descriptor = FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == userId }
        )
        if let record = try? context.fetch(descriptor).first {
            Self.restoreBodyDefaults(from: record, into: defaults)
            Self.restoreCohortDefaults(from: record, into: defaults)
            Self.mirrorActivityAlias(from: record, into: defaults)
        }
        // Plans can arrive archived (a support-side de-duplication), so
        // the one-live-plan rule re-runs over the merged set.
        await reconcileLivePlans(userId: userId)
    }

    /// The activity ALIAS the record can carry through a sign-out. Her raw
    /// consult answer (`onb_v4_movement_baseline`) outranks it in
    /// `TargetsService.activityKey` and is deliberately left alone: it is
    /// the more specific fact and she typed it on this device.
    /// `BodyFactsStore` writes both, so her own edits never drift.
    static func mirrorActivityAlias(from record: UserRecord, into defaults: UserDefaults) {
        guard !record.pendingUpsert,
              let alias = record.onboardingActivityLevel, !alias.isEmpty,
              defaults.string(forKey: "activityLevel") != alias
        else { return }
        defaults.set(alias, forKey: "activityLevel")
    }

    /// The body inputs the energy + protein math runs on, brought into
    /// line with the freshly-hydrated record. Pure over (record,
    /// defaults) so the round-trip is testable without a container.
    ///
    /// ## Absent-only was not enough
    ///
    /// 2026-08-13 this restored a value only when the device held NONE,
    /// reasoning that "a local write is the newer fact". That closed the
    /// hole where a returning payer came back with `heightCm = 0`. It did
    /// not close the one the support desk actually hits: a device holding
    /// a WRONG value. Support corrected a customer's goal to 110 in the
    /// `users` table, the record hydrated it correctly — and the
    /// `@AppStorage` key every surface reads stayed 124, because it was
    /// present. The repair reached the local database and stopped there.
    ///
    /// ## The rule
    ///
    /// `hydrateUser` refuses to touch a record with `pendingUpsert ==
    /// true`, so a record that arrives here clean IS server truth, not an
    /// unsent local edit. Mirroring it can therefore never overwrite a
    /// newer local write: a newer local write would have set the flag,
    /// and the hydrate would have skipped the row entirely.
    ///
    /// Two refusals stand:
    ///   * **A pending record is never mirrored.** Her unsent edit wins.
    ///   * **An absent server value is never adopted.** A legacy row whose
    ///     `onboarding_goal_weight_kg` is NULL must not delete a goal the
    ///     device holds — that is the same "lose the goal" defect arriving
    ///     from the other direction.
    static func restoreBodyDefaults(from record: UserRecord, into defaults: UserDefaults) {
        // A record with an unsent local edit is not server truth. Restore
        // nothing FROM it and overwrite nothing WITH it.
        let isServerTruth = !record.pendingUpsert

        func merge(_ value: Double?, _ key: String, floor: Double) {
            guard let value, value > floor else { return }
            let held = defaults.object(forKey: key) != nil
            guard !held || isServerTruth else { return }
            guard defaults.double(forKey: key) != value else { return }
            defaults.set(value, forKey: key)
        }
        merge(record.onboardingHeightCm, "onboardingHeightCm", floor: 100)
        merge(record.onboardingCurrentWeightKg, "onboardingCurrentWeightKg", floor: 0)
        merge(record.onboardingGoalWeightKg, "onboardingGoalWeightKg", floor: 0)

        guard !record.onboardingGender.isEmpty else { return }
        let heldGender = defaults.object(forKey: "onboardingGender") != nil
        guard !heldGender || isServerTruth else { return }
        guard defaults.string(forKey: "onboardingGender") != record.onboardingGender else { return }
        defaults.set(record.onboardingGender, forKey: "onboardingGender")
    }

    /// THE CLINICAL COHORT, brought home.
    ///
    /// 2026-08-14. `clearOnboardingUserDefaults` sweeps
    /// `onboarding_glp1_status`, `onboarding_glp1_phase`,
    /// `onboardingHormonalStage`, `onboardingSleepHours`,
    /// `onboarding_weight_trend`, `onboardingStressLevel` and
    /// `onboardingFoodRelationship` — correctly, they are identity-scoped
    /// clinical intake. **`UserRecord` has carried every one of them
    /// since 2026-06-23 and `syncUserDefaultsFromUserRecord` restored
    /// none of them**, so a GLP-1 payer came back from a sign-out, a
    /// reinstall or a new phone as a non-GLP-1 user:
    ///
    ///   * the protein floor drops from 1.6 g/kg to 1.2 (the cited
    ///     4-society advisory band, and the cohort's whole lean-mass
    ///     argument);
    ///   * `ProgramGoalCalculator`'s 0.3%/wk cautious floor becomes
    ///     0.5%/wk, so any recomputed horizon SPEEDS HER UP;
    ///   * `HardTierGate`'s GLP-1 and perimenopause locks lift.
    ///
    /// None of that is a new fact and none of it needs a schema change:
    /// the server has held all seven the whole time and the client
    /// simply never read them back.
    ///
    /// Same two refusals as `restoreBodyDefaults`, for the same reasons:
    /// a record with an unsent local edit is not server truth, and an
    /// absent server value never deletes a fact the device holds.
    static func restoreCohortDefaults(from record: UserRecord, into defaults: UserDefaults) {
        let isServerTruth = !record.pendingUpsert

        func merge(_ value: String?, _ key: String) {
            guard let value, !value.isEmpty else { return }
            let held = (defaults.string(forKey: key) ?? "").isEmpty == false
            guard !held || isServerTruth else { return }
            guard defaults.string(forKey: key) != value else { return }
            defaults.set(value, forKey: key)
        }
        merge(record.onboardingGlp1Status, "onboarding_glp1_status")
        merge(record.onboardingGlp1Phase, "onboarding_glp1_phase")
        merge(record.onboardingHormonalStage, "onboardingHormonalStage")
        merge(record.onboardingSleepHours, "onboardingSleepHours")
        merge(record.onboardingWeightTrend, "onboarding_weight_trend")
        merge(record.onboardingStressLevel, "onboardingStressLevel")
        merge(record.onboardingFoodRelationship, "onboardingFoodRelationship")
        // p58 — came_for comes home. The outcome answer has ridden
        // `users.onboarding_motivation` since the v5 assembler
        // (p37/p57 recorded it as needing a new column — wrong; the
        // server held it the whole time). One line closes the loop:
        // the coach's `came_for` reads `onb_v5_outcome`, and now a
        // reinstall speaks in the words she gave on day 0.
        merge(record.onboardingMotivation, "onb_v5_outcome")
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

        // 2026-08-13 — THE RESTORE HOLE. Height, the two weights and
        // the BMR sex are swept on sign-out (correctly: they are
        // identity-scoped body data) and were never put back, though
        // the record carries all four. The returning payer came back
        // with heightCm = 0, which makes `TargetsService.calorieTarget`
        // return nil — her energy number vanished on a new phone, and
        // nothing said why.
        Self.restoreBodyDefaults(from: record, into: defaults)
        // 2026-08-14 — THE COHORT HOLE, the same shape one layer over:
        // seven clinical intake keys the record has carried since
        // 2026-06-23 and nothing here restored. A GLP-1 payer signing in
        // on a new phone came back as a non-GLP-1 user.
        Self.restoreCohortDefaults(from: record, into: defaults)

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
    /// v25 §41 — returns whether the SwiftData half actually committed.
    /// It used to return nothing, and `onAuthChanged` cleared the merge
    /// receipt immediately afterwards whatever happened — so a merge
    /// that failed to save discharged the only record that it was owed.
    @discardableResult
    private func reattributeLocalRows(
        from oldId: String, to newId: String, modelContext: ModelContext,
        idPolicy: HandoffIdPolicy = .mintFresh
    ) -> Bool {
        let saved = Self.reattributeModelRows(
            from: oldId, to: newId, in: modelContext, idPolicy: idPolicy
        )
        // Food journal entries collected during the anonymous period
        // re-key the same way (views filter by current userId). The
        // persister mints fresh ids too + carries the local thumbnail
        // across; the post-sign-in hydrateFoodLogs reconcile pushes them.
        //
        // v25 §42 — unless the SERVER moved them. `pushLocalFoodEntriesMissingFromServer`
        // diffs by id every launch, so a fresh id after a server move
        // would make every plate look "missing from the server" and
        // upload a second copy of the whole journal.
        FoodLogPersister.reattributeEntries(
            from: oldId, to: newId, preservingIds: idPolicy == .preserve
        )
        return saved
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
    ///
    /// v25 §42 — AND THE INVARIANT NOW HAS A SECOND HALF. The fresh id
    /// exists because RLS rejects a same-id upsert of a row the OLD uid
    /// still owns. `complete_account_handoff(mode: 'move')` removes that
    /// reason by changing the owner server-side and keeping the id, and
    /// then minting a fresh one here would push a SECOND copy of every
    /// record she owns. `HandoffIdPolicy` carries the server's answer,
    /// and it defaults to the legacy behaviour so every path that has
    /// not spoken to the server is unchanged.
    @discardableResult
    static func reattributeModelRows(
        from oldId: String, to newId: String, in modelContext: ModelContext,
        idPolicy: HandoffIdPolicy = .mintFresh
    ) -> Bool {
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
        // v25 §41 — THE ONE UNGUARDED UNIQUE KEY IN THE WHOLE MERGE.
        // `DayProgressRecord.compositeKey` is `@Attribute(.unique)` and
        // the re-key rewrites it to "<newId>:<programDay>" — so if the
        // destination account already has that day, the merge writes a
        // duplicate unique key. See `applyReattribution` for what that
        // costs. The destination's own rows are fetched here so the
        // mutation can refuse rather than discover it at `save()`.
        let destinationProgress = (try? modelContext.fetch(FetchDescriptor<DayProgressRecord>(
            predicate: #Predicate { $0.userId == newId }
        ))) ?? []
        let dropped = applyReattribution(
            to: newId, sessions: sessions, progress: progress,
            weightLogs: weightLogs, plans: plans, checks: checks,
            existingPlans: destinationPlans, ratings: ratings,
            existingProgress: destinationProgress, idPolicy: idPolicy
        )
        for row in dropped { modelContext.delete(row) }
        // v9 P1 — body scans follow the account. Local-only rows:
        // the userId flips in place (no cloud insert → no fresh-id
        // invariant), and the on-disk photos stay keyed by the same
        // scan ids.
        let scans = (try? modelContext.fetch(FetchDescriptor<BodyScanRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        for scan in scans { scan.userId = newId }

        // v25 §40 — THE OTHER ELEVEN FAMILIES. This function fetched
        // SEVEN of the eighteen `@Model` types in the repository, and
        // `39` §3 recorded four of the missing ones as "REKEYED". Doses,
        // symptoms, her regimen, the program's authority chains, the
        // weekly reads, what Jeni remembers and the transcript all stayed
        // keyed to the abandoned uid — on the phone in her hand,
        // invisible to every `@Query userId` in the product. Same
        // context, same transaction, before the one save below.
        IdentityMerge.carryRemainingFamilies(
            from: oldId, to: newId, in: modelContext, idPolicy: idPolicy
        )

        // v25 §41 — SAVE FIRST, THEN DISCHARGE. `try?` swallowed the
        // one thing worth knowing: whether the transaction committed.
        // Everything above runs on one context and lands in one
        // `save()`, so a single unique-key violation discards ALL of
        // it — every family, silently — and the two things that used to
        // run afterwards (clearing the source's deletion ledger, and
        // `onAuthChanged` clearing the merge receipt) then destroyed the
        // bookkeeping that would have retried it.
        var saved = true
        do {
            try modelContext.save()
        } catch {
            saved = false
            #if DEBUG
            print("[AppSync] reattributeModelRows: save FAILED, receipt kept: \(error)")
            #endif
            Analytics.trackException(
                NSError(domain: "AppSync", code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "identity merge did not commit"]),
                context: "sync.identity_merge_not_committed"
            )
        }

        // The outgoing account's deletion ledger is now dead weight:
        // every id it protects was just re-keyed, so it can never match
        // a row again. It is derived from her own deletions, so it goes
        // rather than lingering under a uid nothing will ever use.
        // (This is NOT the sign-out case, which must keep it — §38 §18.2.
        // This runs only on a sign-IN that changed the uid.)
        //
        // v25 §41 — and only once the re-key it describes actually
        // committed. A UserDefaults write is not part of the SwiftData
        // transaction, so clearing it unconditionally destroyed a
        // ledger whose ids were still live.
        //
        // v25 §42 — [CORR] ON `41` §19, AND THE CORRECTION IS THE ID
        // POLICY AGAIN. `41` wrote that the ledger must NEVER cross into
        // the destination, because "a deletion she made as one identity
        // is not an assertion about another account's rows". That is
        // exactly right when the client mints fresh ids: the ids differ,
        // so a tombstone for A's id says nothing about B's row.
        //
        // Under a SERVER MOVE it is the same physical row with the same
        // id, now owned by B. A tombstone that named it still names it.
        // Dropping it would let `pushLocalFoodEntriesMissingFromServer`
        // and the insert-only hydrates resurrect a plate she deleted —
        // the exact defect `38` exists to prevent, re-introduced by the
        // migration that was supposed to make ownership honest.
        //
        //   ▎ A DELETION FOLLOWS THE ROW IT NAMES, AND ONLY WHEN THE ROW
        //   ▎ KEPT ITS NAME.
        if saved {
            if idPolicy == .preserve {
                DeletionLedger.carry(from: oldId, to: newId)
            }
            DeletionLedger.clear(userId: oldId)
        }
        return saved
    }

    /// The pure re-key mutation, split from the fetch so the fresh-id
    /// invariant is unit-testable on standalone model instances (no
    /// ModelContainer). Mutates the rows in place; the caller saves.
    ///
    /// ## v25 §41 — THE DAY-PROGRESS COLLISION
    ///
    /// `DayProgressRecord.compositeKey` is `@Attribute(.unique)` and
    /// this function rewrote it to `"<newId>:<programDay>"` with no
    /// check on what the destination already holds. Every other family
    /// in the merge is either given a FRESH uuid or explicitly guarded
    /// against the destination's ids (`IdentityMerge` guards doses,
    /// symptoms, weekly reads and calibrations); this one was neither.
    ///
    /// The server has exactly the same shape, read from the live
    /// catalog rather than the repository — `public.day_progress`'s
    /// PRIMARY KEY is `(user_id, program_day)` — so the collision is a
    /// property of the data, not of SwiftData.
    ///
    /// ▎ AND BOTH SIDES HAVING DAY 1 IS THE NORMAL CASE, NOT THE
    /// ▎ EXOTIC ONE. Production: 43 anonymous accounts hold day
    /// ▎ progress, 64 permanent accounts hold it.
    ///
    /// The cost was not one row. The whole merge is one context and one
    /// `save()`, so a single duplicate key discarded EVERY family's
    /// re-key at once — and the receipt was cleared immediately after,
    /// so nothing was left to retry it.
    ///
    /// The rule is the one `40` already wrote for id collisions: **the
    /// account's own row wins, and content is NEVER compared.** One
    /// composite key means one day for one account; two rows cannot
    /// both be it, and the row already inside the account is the one
    /// that stays. The incoming row is returned to the caller to be
    /// deleted — a day of the anonymous period is not evidence about a
    /// day the destination account already lived.
    ///
    /// Returns the incoming rows the caller must delete.
    @discardableResult
    static func applyReattribution(
        to newId: String,
        sessions: [SessionLogRecord],
        progress: [DayProgressRecord],
        weightLogs: [WeightLogRecord],
        plans: [ProgramPlanRecord] = [],
        checks: [ProgramDayCheckRecord] = [],
        existingPlans: [ProgramPlanRecord] = [],
        ratings: [SessionRatingRecord] = [],
        existingProgress: [DayProgressRecord] = [],
        idPolicy: HandoffIdPolicy = .mintFresh
    ) -> [DayProgressRecord] {
        // v25 §42 — the id policy in one place. Under `.preserve` the
        // remaps below are the identity function, so every pointer that
        // follows a remap keeps pointing at the row it already named.
        func carriedId(_ current: String) -> String {
            idPolicy == .preserve ? current : UUID().uuidString
        }
        // Under `.mintFresh` every carried row MUST be pushed: it is a
        // brand-new id the cloud has never seen. Under `.preserve` the
        // server already holds the row, so the flag is LEFT AS IT WAS —
        // a row that was genuinely unsynced stays owed and lands as a
        // clean INSERT under its own id, and a row that was clean stays
        // clean so `ProgramPlanMerge` adopts the server's answer instead
        // of the device pushing back over a decision the server made.
        func pushFlag(_ existing: Bool) -> Bool { idPolicy.queuesAPush || existing }

        // session_logs — fresh id; remember old→new so day_progress follows.
        var sessionIdRemap: [String: String] = [:]
        for s in sessions {
            let freshId = carriedId(s.id)
            sessionIdRemap[s.id] = freshId
            s.id = freshId
            s.userId = newId
            s.pendingUpsert = pushFlag(s.pendingUpsert)
        }

        // session_ratings: synced now, so the fresh-id invariant applies
        // here too, and the sessionLogId pointer follows the session remap
        // the way day_progress does (a stale pointer would orphan the
        // rating from both the delete-account join and the cloud push).
        for r in ratings {
            r.id = carriedId(r.id)
            r.userId = newId
            r.sessionLogId = sessionIdRemap[r.sessionLogId] ?? r.sessionLogId
            r.pendingUpsert = pushFlag(r.pendingUpsert)
        }

        let destinationDayKeys = Set(
            existingProgress
                .filter { $0.userId.caseInsensitiveCompare(newId) == .orderedSame }
                .map { $0.compositeKey.lowercased() }
        )
        var supersededByDestination: [DayProgressRecord] = []
        for p in progress {
            let incomingKey = "\(newId):\(p.programDay)"
            guard !destinationDayKeys.contains(incomingKey.lowercased()) else {
                // THE ACCOUNT'S OWN DAY WINS. Nothing is compared and
                // nothing is merged; the incoming row is dropped whole.
                supersededByDestination.append(p)
                continue
            }
            p.userId = newId
            p.compositeKey = incomingKey
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
            w.id = carriedId(w.id)
            w.userId = newId
            w.pendingUpsert = pushFlag(w.pendingUpsert)
        }

        // program_plans — the ANCHOR for "which day the user is on"
        // (programDay derives from plan.startDate). Conflicts on the global
        // `id` PK, so the same fresh-id invariant as weight/session applies:
        // a naive re-key would UPDATE the old-uid cloud row and hit RLS
        // 42501, stranding the enrollment on-device and resetting the day on
        // the next reinstall. Fresh id → clean INSERT the new account owns.
        var planIdRemap: [String: String] = [:]
        for plan in plans {
            let freshId = carriedId(plan.id)
            planIdRemap[plan.id] = freshId
            plan.id = freshId
            plan.userId = newId
            plan.pendingUpsert = pushFlag(plan.pendingUpsert)
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
            check.id = carriedId(check.id)
            check.userId = newId
            check.programPlanId = planIdRemap[check.programPlanId] ?? check.programPlanId
            check.pendingUpsert = pushFlag(check.pendingUpsert)
        }

        // One live plan per account. The incoming anon plan is usually an
        // interim re-enrollment (startDate = today) created while the user
        // was auto-logged-out; the account it merges into already holds
        // the genuine journey. Reconcile across destination + incoming so
        // the EARLIEST-startDate plan stays live and the interim one lands
        // archived. Pointers stay coherent: archiving never changes ids,
        // and the remaps above already ran.
        //
        // v25 §41 — **THE DESTINATION'S LIVE PLAN IS THE ACCOUNT'S
        // TRUTH, AND EARLIEST-STARTDATE IS NOT THE RULE FOR A HANDOFF.**
        //
        // `31` built earliest-wins to kill an interim junk plan, whose
        // startDate is always TODAY, so for that case the two rules give
        // the same answer. They differ in exactly one shape and it is a
        // real one: an anonymous period that began BEFORE the account's
        // own plan. Earliest-wins then archives the journey the customer
        // has actually been living in and re-dates her program from a
        // plan she built while logged out — *"do not abandon B's
        // established plan merely because A signed in"*.
        //
        // A's plan is not discarded: it arrives ARCHIVED, which is how
        // this model already carries a superseded enrollment, so it
        // stays in her history rather than becoming a second present
        // tense. Nothing is fabricated and no goal is silently
        // overwritten.
        let destinationHasLivePlan = existingPlans.contains {
            livePlanPhases.contains($0.phase) && $0.archivedAt == nil
        }
        if destinationHasLivePlan {
            for plan in plans where livePlanPhases.contains(plan.phase) && plan.archivedAt == nil {
                plan.phase = "abandoned"
                plan.archivedAt = .now
                plan.updatedAt = .now
                plan.pendingUpsert = true
            }
        } else if idPolicy == .preserve {
            // v25 §42 — THE SERVER MADE THE SAME DECISION FROM A BETTER
            // VANTAGE POINT. `destinationHasLivePlan` is read from the
            // LOCAL store, and on the normal handoff the destination's
            // own plans have not hydrated yet — so this device usually
            // cannot see the plan the server just archived A's for.
            // Leaving the row CLEAN is what lets `refreshProgramTruth` +
            // `ProgramPlanMerge` adopt the server's answer, which is the
            // authoritative one. Forcing a push here would send A's plan
            // back as live and undo the archive.
        }
        reconcileLivePlans(existingPlans + plans)

        return supersededByDestination
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

    /// v25 §42 — RECORD WHICH THING THE SERVER DID, AT THE INSTANT IT
    /// DID IT.
    ///
    /// The receipt already survives a sign-out and is discharged only on
    /// a commit. It must now also carry the ID POLICY, because a crash
    /// between the server move and the local carry would otherwise leave
    /// the next launch guessing — and the two guesses are not
    /// symmetrical: guessing `.preserve` when the server did NOT move
    /// strands her record on the device, and guessing `.mintFresh` when
    /// it DID duplicates the whole of it. Neither is acceptable, so the
    /// answer is written down rather than inferred.
    static func writePendingMergeMarker(
        from oldId: String, to newId: String, idPolicy: HandoffIdPolicy
    ) {
        UserDefaults.standard.set(
            ["from": oldId, "to": newId, "idPolicy": idPolicy.rawValue],
            forKey: pendingMergeKey
        )
    }

    /// Defaults to `.mintFresh` — the legacy behaviour — for a marker
    /// written by an older build or by a path that never reached the
    /// server. **The default is the safe direction**: a fresh id can
    /// strand a row, which the launch reconcile then heals; a preserved
    /// id that the server never moved cannot be un-duplicated.
    static func pendingMergeIdPolicy() -> HandoffIdPolicy {
        guard
            let dict = UserDefaults.standard.dictionary(forKey: pendingMergeKey) as? [String: String],
            let raw = dict["idPolicy"], let policy = HandoffIdPolicy(rawValue: raw)
        else { return .mintFresh }
        return policy
    }

    static func clearPendingMergeMarker() {
        UserDefaults.standard.removeObject(forKey: pendingMergeKey)
    }

    /// v25 §41 — how many customer-owned rows this device still holds
    /// for `uid`, across the ONE inventory. Used by the retirement gate
    /// (`SourceRetirementSafety`) so an account whose record this device
    /// is not carrying is never deleted from the server.
    ///
    /// Returns 0 when there is no container, which refuses the
    /// retirement — the safe direction, and the only honest answer when
    /// the device cannot look.
    @MainActor
    static func localFootprint(of uid: String) -> Int {
        guard let container = shared.modelContainer else { return 0 }
        return LocalHandoffInventory.footprint(of: uid, in: container.mainContext)
    }

    static func pendingMergeMarker() -> (from: String, to: String)? {
        guard
            let dict = UserDefaults.standard.dictionary(forKey: pendingMergeKey) as? [String: String],
            let from = dict["from"], let to = dict["to"],
            !from.isEmpty, !to.isEmpty, from != to
        else { return nil }
        return (from, to)
    }

    /// v25 §42 — **THE RECOVERY THAT NEEDS NO LOCAL STATE.**
    ///
    /// `40` §3.5 and `41` §22 both stated the hole plainly: a retry of
    /// the source retirement needs a bearer token for an account that no
    /// longer has one, so the client could not retry and would not
    /// persist a token to make it possible. This is the answer, and the
    /// reason it works is that it asks for NOTHING:
    ///
    ///   ▎ `complete_account_handoff` TAKES NO IDENTITY. The server
    ///   ▎ matches this caller's OWN Apple identity against receipts the
    ///   ▎ source pre-committed while it was still authenticated.
    ///
    /// So a device that lost the marker, was reinstalled, or was signed
    /// out and back in still discharges the obligation — and a device
    /// that never had one pays one indexed lookup.
    ///
    /// Anonymous sessions are skipped: the deployed function refuses an
    /// anonymous destination with `42501`, which is the firewall, not an
    /// error to work around.
    ///
    /// Never throws, is never surfaced, and cannot fail a launch.
    @discardableResult
    func dischargeOwedHandoffIfNeeded() async -> AccountHandoff.CompleteOutcome {
        guard AuthService.shared.isAuthenticated, !AuthService.shared.isAnonymous,
              let token = AuthService.shared.currentSession?.accessToken, !token.isEmpty
        else { return .unreachable }

        let outcome = await AccountHandoff.complete(accessToken: token, mode: "move")
        #if DEBUG
        if case .done(let moved, let retired) = outcome, moved > 0 || retired > 0 {
            print("[AppSync] handoff discharged at launch: moved=\(moved) retired=\(retired)")
        }
        #endif

        // If the server moved rows and this device still owes the local
        // carry, the carry MUST preserve ids. The marker is normally
        // already `.preserve` (written at the switch); this is the
        // belt to those braces for a marker an older build wrote.
        if outcome.movedTheRecord, let marker = Self.pendingMergeMarker() {
            Self.writePendingMergeMarker(from: marker.from, to: marker.to, idPolicy: .preserve)
        }
        return outcome
    }

    /// Re-run an interrupted sign-in merge. Idempotent by construction:
    /// reattributeLocalRows only fetches rows still keyed to the OLD uid,
    /// so a completed merge is a no-op and a half-finished one only picks
    /// up the stranded remainder. Rows re-keyed by the crashed pass kept
    /// their fresh ids + pendingUpsert flag, so the retry push (not a
    /// second re-key) is what lands them; no double-minting.
    /// v25 §41 — returns true only when the carry COMMITTED, so
    /// `onLaunch` cannot discharge a receipt for work that did not
    /// happen. A resume that fails leaves the receipt standing and the
    /// next launch tries again, which is the whole point of having one.
    private func resumePendingMergeIfNeeded(modelContext: ModelContext) -> Bool {
        guard let marker = Self.pendingMergeMarker() else { return false }
        #if DEBUG
        print("[AppSync] resuming interrupted merge \(marker.from) → \(marker.to)")
        #endif
        return reattributeLocalRows(
            from: marker.from, to: marker.to, modelContext: modelContext,
            idPolicy: Self.pendingMergeIdPolicy()
        )
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
            // E8.1 — `source` names WHICH DOOR, vocabulary shared with
            // PlankFood.EntryMethod and the food_logs_source_door_check
            // constraint. A pre-D3.B entry carries no source at all and
            // used to be upserted as 'photo', which invented an
            // attribution; it is now 'unknown', so the absence is
            // visible in the column instead of inflating the largest
            // real category. Legacy values pass through untranslated.
            source: EntryMethod.persistedSourceValue(for: entry.source),
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
                            sodium_mg: $0.sodiumMg, sat_fat_g: $0.satFatG,
                            source: $0.source
                        )
                    }
                },
                // v25 E4 — corrections survive a reinstall (the
                // flywheel's raw material rides the payload jsonb).
                corrections: entry.corrections,
                // p53 — hand edits + the barcode key survive too.
                edits: entry.edits,
                barcode: entry.barcode
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

    /// v25 §34 — a removed weigh-in has to leave the server too, or the
    /// insert-only weight hydrate puts it back on the next launch.
    func deleteWeightLog(id: String) async {
        guard let service = syncService else { return }
        await service.deleteWeightLog(id: id)
    }

    /// v25 §36 — the same rule for observations, and the same reason:
    /// `hydrateObservations` is insert-only by id, so a symptom she
    /// cleared came back on the next pull. It reaches `VisitPacket`,
    /// so the resurrected row could reach her clinician.
    func deleteObservation(id: String) async {
        guard let service = syncService else { return }
        await service.deleteObservation(id: id)
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
        #if DEBUG
        // v25 E5 — `--uitest-wipe-food` clears the local store so
        // empty-state faces can be filmed, but the deterministic QA
        // account's rows live in the shared dev database and used to
        // flood straight back in (the E4 record named this debt and the
        // first half-fix here still saw 16 plates return). The door
        // suppresses the pull for the launch instead of deleting cloud
        // rows a human may still want.
        if ProcessInfo.processInfo.arguments.contains("--uitest-wipe-food") { return }
        #endif

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
                            sodiumMg: $0.sodium_mg, satFatG: $0.sat_fat_g,
                            source: $0.source
                        )
                    }
                },
                corrections: row.payload?.corrections,
                edits: row.payload?.edits,
                barcode: row.payload?.barcode,
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

    func upsertWeeklyRead(_ read: WeeklyReadRecord) async {
        guard let service = syncService else { return }
        guard !read.userId.isEmpty else { return }
        await service.upsertWeeklyRead(read)
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

        // v25 §39 — THE INTENT IS WRITTEN BEFORE THE CALL, so a process
        // that dies during the RPC still leaves a record that a deletion
        // was in flight. Without it, a lost response meant the server
        // half completed, the local purge never ran, and NOTHING
        // anywhere knew the purge was owed.
        if let userId = userIdToWipe, !userId.isEmpty {
            AccountDeletionIntent.begin(userId: userId)
        }

        var rpcError: (any Error)?
        do {
            try await AuthService.shared.deleteAccount()
        } catch {
            rpcError = error
        }

        // A DEFINITIVE rejection is the server saying this account is
        // already gone, not a failure — treating it as one is what
        // stranded the local purge. A timeout says nothing about the
        // server, so it must not claim completion.
        let verdict = AccountDeletionVerdict.classify(rpcError)
        guard verdict == .serverComplete else {
            #if DEBUG
            print("[AppSync] deleteCurrentAccount: server verdict unknown, keeping everything. Error: \(rpcError as Any)")
            #endif
            throw rpcError ?? AccountDeletionError.serverDidNotConfirm
        }

        if let userId = userIdToWipe, !userId.isEmpty {
            AccountDeletionIntent.markServerComplete(userId: userId)
        }
        #if DEBUG
        print("[AppSync] deleteCurrentAccount: server complete, proceeding with local cleanup")
        #endif

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
        // v25 §39 — the purge the intent demanded has now happened, so
        // the intent is discharged. Anything that dies BEFORE this line
        // leaves it standing, and the next launch finishes the sweep.
        AccountDeletionIntent.finish()
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
        Self.clearLocalUserRecords(userId: userId, in: context)
    }

    /// v25 §39 — FINISH A DELETION THE DEVICE DID NOT FINISH.
    ///
    /// The server said the account was gone and the local purge never
    /// completed: the app was killed, the phone died, iOS reclaimed the
    /// process behind the sheet. Before this, nothing recorded that the
    /// purge was owed, so every weigh-in, plate and workout from a
    /// deleted account stayed on disk and in every device backup taken
    /// afterwards — under an account she had been told was deleted.
    ///
    /// Runs at launch. Purges ONLY the account named in the intent,
    /// which is routinely not the account the app is now holding: the
    /// sign-out at the end of deletion bootstraps a fresh anonymous
    /// uid, so a purge scoped to "the current user" would sweep the
    /// wrong one.
    ///
    /// An intent still at `.requested` — she asked, the server never
    /// answered — is deliberately left alone. `pendingLocalPurge()`
    /// returns nil for it, because destroying the only copy she can
    /// still reach while the server may keep its own is worse than
    /// doing nothing.
    /// v25 §39 — APPLE SAID THE CREDENTIAL IS GONE. TN3194 is explicit
    /// about what must follow: *"Delete all user-related account data,
    /// including … any user-related data stored in the Keychain or
    /// securely on disk in the native app"* and *"revert the client to
    /// an unauthenticated state."*
    ///
    /// This is not account deletion and does not pretend to be: her
    /// SERVER rows are untouched, because revoking Sign in with Apple is
    /// not a request to delete an account. Apple issues the same `sub`
    /// for the same Apple ID and team, so signing in again lands on the
    /// same Supabase user and hydrates the record back. The device stops
    /// holding a copy of a person whose credential the app no longer
    /// has; that is the whole of it.
    func handleAppleCredentialRevoked() async {
        let userId = currentUserId
        #if DEBUG
        print("[AppSync] apple credential revoked; reverting to unauthenticated")
        #endif
        if let userId, !userId.isEmpty, let container = modelContainer {
            Self.clearLocalUserRecords(userId: userId, in: container.mainContext)
        }
        clearOnboardingUserDefaults()
        RetentionNotifications.cancelAll()
        try? await AuthService.shared.signOut()
    }

    /// It finishes the WHOLE local purge, not the SwiftData half. Found
    /// by the test that measures the footprint rather than the sweep:
    /// with only `clearLocalUserRecords`, every workout she typed into
    /// MOVE survived an interrupted deletion — `move.manual.v1` lives in
    /// `UserDefaults`, which is exactly the hole `38` closed for the
    /// completed path and would have re-opened for this one.
    static func finishInterruptedAccountDeletion(in context: ModelContext) {
        guard let userId = AccountDeletionIntent.pendingLocalPurge() else { return }
        clearLocalUserRecords(userId: userId, in: context)
        shared.clearOnboardingUserDefaults()
        AccountDeletionIntent.finish()
        #if DEBUG
        print("[AppSync] finished an interrupted account deletion for user_id=\(userId)")
        #endif
    }

    /// **THE DELETION CONTRACT**, as a pure function over (userId,
    /// context) so the sweep a test drives is the sweep the product
    /// runs — never a list of model types copied into a fixture, which
    /// is how a sweep stops testing the sweep (`35` §2).
    ///
    /// Every family listed here is scoped by `userId`, so two accounts
    /// that have shared this device stay independent.
    @MainActor
    static func clearLocalUserRecords(userId: String, in context: ModelContext) {
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

        // v25 §37 — THREE FAMILIES ADDED AFTER THE 2026-08-08 SWEEP AND
        // NEVER ADDED TO IT.
        //
        // The sharpest is `JeniMemoryRecord`: it is free text the
        // customer typed and asked her coach to keep, Settings lists it
        // under *"what jeni remembers"* with a per-row forget, and the
        // whole store is E3's compounding half — so it reads to her as
        // the most personal thing the product holds. It survived "delete
        // my account" on disk and in every device backup taken
        // afterwards. `ProgramFactRecord` and `WeeklyReadRecord` are her
        // program's decisions and their authority chain.
        //
        // Same shape as the release audit's own finding, and the same
        // sentence answers it: **deletion means deletion.** No schema,
        // no server change — all three cascade from `auth.users` already.
        let memoryDescriptor = FetchDescriptor<JeniMemoryRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let notes = try? context.fetch(memoryDescriptor) {
            for n in notes { context.delete(n) }
        }
        let factsDescriptor = FetchDescriptor<ProgramFactRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let facts = try? context.fetch(factsDescriptor) {
            for f in facts { context.delete(f) }
        }
        let readsDescriptor = FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        if let reads = try? context.fetch(readsDescriptor) {
            for r in reads { context.delete(r) }
        }

        // Food journal lives in the JSONL store, not SwiftData. Server
        // rows are gone via the delete-account cascade; clear the
        // device copy too.
        FoodLogPersister.deleteAllEntries(userId: userId)

        // v25 §38 — THE DELETION LEDGER IS ALSO HERS. It is derived
        // entirely from records she asked Jeni to remove, so it goes
        // with the account. It must NOT be swept at sign-out (it is
        // deliberately absent from `clearOnboardingUserDefaults`),
        // because sign-out preserves the rows it protects and a ledger
        // cleared there would re-open every resurrection.
        DeletionLedger.clear(userId: userId)

        // p55 — her weekly re-signing decisions (a JSONL under
        // Application Support that no sweep touched: they survived
        // "delete my account" on disk and in every backup after).
        WeeklyReview.purge(userId: userId)

        // v25 §41 — the handoff receipt is bookkeeping about an account,
        // so it goes when that account does. It survives sign-out (it
        // names work this device still owes) and it must not survive the
        // deletion of either side of the pair it names: a receipt whose
        // source or destination no longer exists can only ever re-key
        // rows into an account that is gone.
        if let marker = Self.pendingMergeMarker(),
           marker.from.caseInsensitiveCompare(userId) == .orderedSame
            || marker.to.caseInsensitiveCompare(userId) == .orderedSame {
            Self.clearPendingMergeMarker()
        }

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
            // Sync bookkeeping is identity-scoped too: a stale hydrate
            // day-stamp must not leak across accounts.
            //
            // v25 §41 — `sync.pendingMergeV1` LEFT THIS LIST, AND IT IS
            // A CORRECTION. It is not a fact about the outgoing person;
            // it is a record that THIS DEVICE OWES a handoff, naming two
            // uids and no content. Swept here, signing out between an
            // interrupted merge and the next launch destroyed the only
            // thing that knew the anonymous period had not reached her
            // account — and the rows stayed keyed to a uid the app would
            // never use again, with nothing anywhere recording it.
            //
            // ▎ AN ISOLATION SWEEP CLEARS WHAT THE NEXT PERSON MUST NOT
            // ▎ SEE. IT MUST NOT CLEAR WHAT THIS DEVICE STILL OWES.
            //
            // It is the same sentence `38` §18.2 wrote for the deletion
            // ledger, which is deliberately absent from this list for
            // exactly the same reason. The receipt is discharged by its
            // own completion, and by account deletion (below).
            "sync.launchHydrateStamp",
            "sync.truthRefreshStamp",
            // v25 §44 — the photo backfill's own day stamp, the same
            // shape and the same reason as the two above.
            FoodPhotoSyncService.sweepStampKey,
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
            // v25 §38 P0 — MOVE's hand-recorded sessions were in NO
            // sweep at all. `move.manual.v1` is not in this list, it
            // matches none of the eighteen prefixes below, and the only
            // two callers of `MoveManualStore.wipe()` in the repository
            // are a DEBUG preview route and a QA seeder. So every
            // workout the customer typed survived sign-out — the next
            // account on this phone saw her sessions in the MOVE sheet
            // AND counted them in Home's strength tile — and survived
            // "delete my account" on disk and in every device backup
            // taken afterwards.
            //
            // It changes no arithmetic (there is no exercise
            // compensation anywhere in the product, `29` §3), which is
            // why five passes read past it. It is customer-authored
            // content, which is why it belongs here: the same sentence
            // that added `JeniMemoryRecord` to the sweep in `37`.
            //
            // Sweeping here means it also does not survive HER OWN
            // sign-out. That is the trade `35` already tested and
            // accepted for the `safety_` family: this sweep runs at
            // sign-OUT, before the next identity is known, so the
            // choice is between losing a device-local list and handing
            // it to a stranger.
            "move.manual.v1",

            // v25 p54 — WHAT JENI TOLD HER. The Method ledger stores
            // note ids, trigger names, dates and settled outcomes, and
            // the settings browse surface ("what jeni has told you")
            // renders straight from it — so before this line, account
            // B's settings listed what account A was told, and the
            // trigger names alone are health-state descriptors (a GI
            // symptom, a scale event, a dose rhythm's end). It changes
            // no arithmetic, which is why five passes read past it; it
            // is a record about ONE person, which is why it belongs
            // here — the same sentence as `move.manual.v1` above and
            // `JeniMemoryRecord` in `37`. Losing her own ledger at her
            // own sign-out is the §35/§38 trade, accepted again: this
            // sweep runs before the next identity is known.
            MethodLedger.storageKey,

            // v25 §39 — the Apple user identifier. An identifier, not a
            // token, and already on the server as `identity_data.sub`;
            // it exists only so a revocation notice can be confirmed
            // before the app acts on it. It names ONE account, so it
            // goes when that account's session does.
            AppleCredentialWatcher.userIdentifierKey,

            // p55 — the census's fourth harvest of state added after
            // the sweeps were written (the §38 lesson, again):
            // A readable medication-status string ("glp1_cohort=…|
            // medicated=true") that outlived the account — and whose
            // short-circuit silently kept the NEXT account's cohort
            // properties from ever reaching analytics.
            "analytics.cohortIdentity.fingerprint",
            // Shelved coach notes composed from her weeks (weight
            // delta, GLP-1 status, sleep). No view renders them today;
            // the residue is still hers.
            "coach_notes_v1",
            // Her notification opt-outs and her chosen reminder hour —
            // the sweep already treats `notificationsEnabled` as
            // per-identity; these are the same decision's siblings.
            "notif.winback_enabled", "notif.evening_plate_review_enabled",
            "notificationHour", "notificationMinute",
            // Same-day surface gates: A seeing the evening close must
            // not cost B hers on the same evening.
            "evening.moment.presentedDayKey", "letter.presentedDayKey",
            // p63 — the dial's once-per-day check draw (A's drawn
            // floor must not eat B's first-met moment the same day).
            "dial.floorDrawnDayKey",
            // The unswept breathwork sibling (lastOccasion/lastMinutes
            // are above; the week's day-keys were missed).
            "breathwork.weekly_day_keys",
            // First-run gates + the per-identity backfill marker.
            "coach_intro_shown_at", "cohortIntakeBackfillV1Done",
            // The consult's last typed answer.
            "onb_v8_last_answer",
            // A pending post-purchase flow must not fire under the
            // next identity (its wall one-shot siblings are above).
            "postPurchase.firstRunPending",
            // Walk-analytics day stamps (B's first-day events were
            // silently deduped against A's).
            "analytics.walkShown.day", "analytics.walkGoalHit.day",
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
            // p64 — the delight layer's once-per-day latches
            // (CelebrationLedger.keyPrefix): A's spent spark must not
            // eat B's first one, same law as the dial's drawn floor.
            CelebrationLedger.keyPrefix,
            // v3 spine: presence ledger (kept days + day marker +
            // migration flag) and break state are per-identity.
            "presence.", "break.",
            // v3 chapters: sit-notes feed jeni's reading; the band
            // (settle weight + last zone) is her body's data.
            "day.sit.", "band.",
            // v25 §44 — TOMORROW'S INTENTION, the fifth `day.` family
            // and the only one that was not here. `HomeEvening` writes
            // `day.intention.<tomorrow>` and `.text.<tomorrow>`;
            // `TodayStateService` reads the text back as
            // `morningIntention` and `DailyBriefEngine` prints it. So
            // the decision she made last night arrived in the NEXT
            // account's morning brief, and survived "delete my account"
            // on disk and in every device backup after it. Same
            // sentence as `move.manual.v1` in `38`: it changes no
            // arithmetic, which is why six passes read past it, and it
            // is customer-authored, which is why it belongs here.
            "day.intention.",
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
            // p55 — the notification brain's whole ledger family:
            // the 7-day budget stamps, the per-category ignore
            // streaks, and the silence flags. Left in place, B's
            // first-week interruptions were rationed by A's spent
            // budget, and a category A ignored six times arrived
            // MUTED for B with nothing anywhere to say why.
            "brain.",
            // p55 — packet-question tombstones (uid-suffixed, so
            // cross-account safe, but "user <uid> removed the
            // muscle-loss question" must not survive her deletion).
            "visitq.removed.",
            // p55 — the rating one-shot family (its legacy sibling
            // `onboardingReviewPromptShown` is already above): B's
            // own milestone must not be silenced by A's consumed
            // one-shots.
            "ratingPrompt.",
            // p55 — per-week weight-milestone analytics one-shots.
            "weight_outcome_milestone_",
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

        // v25 §44 — and the clinic. `careProtocol.served.v1` cached the
        // clinical config a CLINIC served to ONE account, and
        // `CareProtocolStore.current` is a process-lifetime static
        // adopted at cold start before any network call. Neither was in
        // this list, so the next identity's protein floor, pace ceiling
        // and hydration aim were composed from a protocol its clinic
        // never served. See `forgetServedProtocol`.
        CareProtocolStore.forgetServedProtocol()

        // p55 — `FirstPlateState.reset()`'s comment claimed "sign-out
        // sweeps user-scoped state; the proof beat is per-person" and
        // reset() had ZERO production callers — the FOURTH false
        // comment on a deletion path this line of work has found.
        // The comment is true now.
        FirstPlateState.reset()

        // p55 — the weekly-review store's process-lifetime cache holds
        // every user's rows (the CareProtocolStore.current class of
        // bug, second instance); the next identity re-reads from disk.
        WeeklyReview.resetCache()

        // v25 §40 — `AccountDeletionIntent.clear()`'s own doc comment
        // said *"Also called by `clearOnboardingUserDefaults`"* and it
        // was not: `account.deletion.intent.v1` appears in exactly one
        // file in the repository. A false comment on a deletion path is
        // the third of that class this line of work has found (`38` §0
        // on `signInWithApple`, `39` §8 on the deployed RPC). An intent
        // names ONE account and must never reach the next person on this
        // phone.
        //
        // LAST, DELIBERATELY. Everything above is the purge the intent
        // is owed; discharging it before the sweep finishes would mean a
        // process death mid-sweep leaves the remaining keys behind with
        // nothing recording that they are owed. Cleared here, a death
        // anywhere in this function leaves the intent standing and the
        // next launch runs the whole sweep again.
        //
        // v25 §41 — AND ONLY WHEN NOTHING IS STILL OWED. `40` cleared it
        // unconditionally, which is right for an intent at `.requested`
        // (she asked, the server never answered, nothing is owed) and
        // wrong for one at `.serverComplete`: that intent is the only
        // record that a CONFIRMED deletion's local purge has not run.
        // Signing out in that window discharged it and left every row of
        // an account she had been told was deleted on the disk, forever.
        // The same sentence as the merge receipt above: a sweep clears
        // what the next person must not see, never what this device
        // still owes — and an owed purge is strictly BETTER for the next
        // person, because it removes the previous account's rows.
        if AccountDeletionIntent.pendingLocalPurge() == nil {
            AccountDeletionIntent.clear()
        }

        // p58 — the Home Screen widget's shared snapshot is
        // identity-scoped state on the most public surface the
        // product has: the next account on this phone must never
        // glance the previous one's protein.
        WidgetBridge.retire()
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
