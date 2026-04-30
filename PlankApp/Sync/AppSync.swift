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
            print("[AppSync] hydrateAndSync: SKIP — already in flight for \(userId)")
            return
        }
        hydrationsInFlight.insert(userId)
        defer { hydrationsInFlight.remove(userId) }

        guard let service = syncService else {
            print("[AppSync] hydrateAndSync: no syncService configured")
            return
        }
        guard let container = modelContainer else {
            print("[AppSync] hydrateAndSync: no modelContainer configured")
            return
        }

        await service.hydrateFromCloud(userId: userId)
        syncUserDefaultsFromUserRecord(context: container.mainContext, userId: userId)
    }

    /// Mirror the freshly-hydrated UserRecord back into the @AppStorage keys
    /// that the rest of the app reads from. Reads from `container.mainContext`
    /// — the same context hydrateUser writes to — so the fetch is guaranteed
    /// to see the row.
    private func syncUserDefaultsFromUserRecord(context: ModelContext, userId: String) {
        print("[AppSync] syncUserDefaultsFromUserRecord: using context \(ObjectIdentifier(context))")
        let descriptor = FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == userId }
        )
        guard let record = try? context.fetch(descriptor).first else {
            print("[AppSync] syncUserDefaultsFromUserRecord: NO UserRecord found for \(userId)")
            return
        }
        print("[AppSync] syncUserDefaultsFromUserRecord: UserRecord found — name='\(record.name)'")

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

        print("[AppSync] syncUserDefaultsFromUserRecord: WROTE userName='\(defaults.string(forKey: "userName") ?? "")' userMotivation='\(defaults.string(forKey: "userMotivation") ?? "")' focusArea='\(defaults.string(forKey: "focusArea") ?? "")' userGoal='\(defaults.string(forKey: "userGoal") ?? "")' plankTime='\(defaults.string(forKey: "plankTime") ?? "")' sessionLengthPref=\(defaults.integer(forKey: "sessionLengthPref"))")
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

    /// Fire-and-forget Supabase upsert for the user's profile row. Caller is
    /// responsible for the SwiftData write (handleOnboardingComplete does it
    /// inline). Defensive: skips silently if the record's id is empty or if
    /// AuthService has no current user — should never happen post-bootstrap,
    /// but guards against init-order bugs.
    func upsertUser(_ user: UserRecord) async {
        let authUser = AuthService.shared.currentUser
        let authUid = authUser?.id.uuidString
        print("[AppSync] upsertUser called with record id: \(user.id)")
        print("[AppSync] currentUser: \(String(describing: authUser))")
        print("[AppSync] currentUserId from auth: \(String(describing: authUid))")
        print("[AppSync] record.id matches auth.uid()? \(user.id == authUid)")

        guard let service = syncService else {
            print("[AppSync] upsertUser ABORT: syncService is nil — configure(modelContainer:) hasn't run yet")
            return
        }
        guard !user.id.isEmpty else {
            print("[AppSync] upsertUser ABORT: UserRecord.id is empty")
            return
        }
        guard let authedId = currentUserId, !authedId.isEmpty else {
            print("[AppSync] upsertUser ABORT: no current auth user (currentUserId nil/empty)")
            return
        }
        if user.id != authedId {
            print("[AppSync] upsertUser WARN: record id (\(user.id)) != auth uid (\(authedId)); RLS will reject")
        }
        print("[AppSync] Calling SyncService.upsertUser...")
        await service.upsertUser(user)
        print("[AppSync] SyncService.upsertUser returned")
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
