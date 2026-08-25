import Foundation
import SwiftData
import PlankSync

// MARK: - RegimenService
//
// App v8 (docs/app_v8/03_ARCHITECTURE.md §3c) — her medication /
// supplement plans, resolved. The shot-day anchor is the one field
// the clinic panel named transformative: with it the engines know
// WHERE in the medication week her body is. Pure date math lives in
// static funcs (unit-tested); the resolver wraps SwiftData.
//
// Laws: the app never authors dosing content; displayName renders
// only where SHE reads it; dose-day composition rides CareProtocol.

@MainActor
enum RegimenService {

    // MARK: - Resolve

    static func activeMedicationPlan(
        userId: String, in context: ModelContext
    ) -> RegimenPlanRecord? {
        guard !userId.isEmpty else { return nil }
        let d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == "medication" && $0.endedAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let active = (try? context.fetch(d)) ?? []
        // S4: when a care-team plan and a self plan are both active
        // (the window between assignment and the patient's
        // reconciliation), the clinician plan leads — deterministic,
        // never an ambiguous double-active. Dose marks stamp its id
        // (provenance follows the resolver). The self plan stays in
        // the chart until she confirms; then it ends.
        return active.first { $0.authority == "care_team" } ?? active.first
    }

    /// The active SELF-managed plan, if any — the reconciliation
    /// moment needs it to retire it once she confirms the clinician's.
    static func activeSelfMedicationPlan(
        userId: String, in context: ModelContext
    ) -> RegimenPlanRecord? {
        guard !userId.isEmpty else { return nil }
        let d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == "medication"
                    && $0.endedAt == nil && $0.authority == "self"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(d)).flatMap { $0.first }
    }

    /// The active CARE-TEAM plan, if any (the reconciliation subject).
    static func activeCareTeamMedicationPlan(
        userId: String, in context: ModelContext
    ) -> RegimenPlanRecord? {
        guard !userId.isEmpty else { return nil }
        let d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == "medication"
                    && $0.endedAt == nil && $0.authority == "care_team"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(d)).flatMap { $0.first }
    }

    static func supplementPlans(
        userId: String, in context: ModelContext
    ) -> [RegimenPlanRecord] {
        guard !userId.isEmpty else { return [] }
        let d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == "supplement" && $0.endedAt == nil
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? context.fetch(d)) ?? []
    }

    // MARK: - Authority (founder refinement 2026-07-28)

    /// The future source of truth for medication is the CLINICIAN.
    /// A plan whose authority is the care team (or that carries the
    /// org/protocol seam — belt and braces) is clinician-managed:
    /// the patient app renders it faithfully and only marks doses /
    /// reports symptoms — it NEVER silently modifies it. Self-
    /// created plans stay hers to edit. Enforced here at the
    /// service so no future surface can forget.
    static func isManagedByCareTeam(_ plan: RegimenPlanRecord) -> Bool {
        plan.authority == "care_team"
            || plan.orgId != nil
            || plan.sourceProtocolId != nil
    }

    /// The active medication plan's id, for stamping dose-mark and
    /// symptom observations with their regimen provenance (the
    /// clinician-portal join key).
    static func activeMedicationPlanId(
        userId: String, in context: ModelContext
    ) -> String? {
        activeMedicationPlan(userId: userId, in: context)?.id
    }

    // MARK: - Write (self-managed plans only; v24 version chains)

    /// v24 — the full desired state of a SELF regimen. One spec in,
    /// one version out; the chain is the history.
    struct SelfRegimenSpec: Equatable {
        var productId: String?
        var displayName: String = ""
        var route: String = "injection"          // "injection" | "oral"
        var scheduleRule: String = "weeklyAnchor" // weeklyAnchor | daily | intervalDays | asNeeded
        var anchorWeekday: Int? = nil
        /// v25 p53 — the split rhythm's second weekday.
        var secondAnchorWeekday: Int? = nil
        /// v25 p53 — every-N-days rhythm (scheduleRule intervalDays).
        var intervalDays: Int? = nil
        /// v25 p53 — the interval chain's first planned civil day.
        var anchorDayKey: String? = nil
        var timeOfDayMinutes: Int? = nil
        var doseValue: Double? = nil
        var doseUnit: String? = nil
        var reminderEnabled: Bool = false

        /// p53 — one rhythm's fields at a time: a weekly plan holds
        /// no interval residue and an interval plan no weekday. The
        /// chokepoint normalizes so no editor can strand a stale
        /// fact on a row it no longer governs.
        func normalized() -> SelfRegimenSpec {
            var s = self
            switch s.scheduleRule {
            case "weeklyAnchor":
                s.intervalDays = nil
                s.anchorDayKey = nil
            case "intervalDays":
                s.anchorWeekday = nil
                s.secondAnchorWeekday = nil
            default:   // daily | asNeeded
                s.anchorWeekday = nil
                s.secondAnchorWeekday = nil
                s.intervalDays = nil
                s.anchorDayKey = nil
            }
            return s
        }

        /// The spec as it would read lifted from an existing row —
        /// change detection compares these.
        fileprivate func matchesFacts(of plan: RegimenPlanRecord) -> Bool {
            plan.productId == productId
                && plan.displayName == displayName
                && plan.route == route
                && plan.scheduleRule == scheduleRule
                && plan.anchorWeekday == anchorWeekday
                && plan.secondAnchorWeekday == secondAnchorWeekday
                && plan.intervalDays == intervalDays
                && plan.anchorDayKey == anchorDayKey
                && plan.timeOfDayMinutes == timeOfDayMinutes
                && plan.strengthValue == doseValue
                && (plan.strengthUnit ?? "mg") == (doseUnit ?? "mg")
        }
    }

    /// THE v24 write chokepoint (docs/app_v24/00_REGIMEN.md §3.2):
    /// apply a desired self-regimen state. Never overwrites
    /// history — a real change ENDS the current row (`endedAt` +
    /// `endReason`) and inserts a new one chained by
    /// `previousPlanId`. Two deliberate softenings:
    /// - same-day coalescing: a row created TODAY mutates in place
    ///   (corrections settle within the day; versions represent
    ///   settled states, not fat-fingers);
    /// - reminder toggling mutates in place always (a preference,
    ///   not regimen history).
    /// Titration continuity: schedule-only changes inherit
    /// `startedAt`; dose/medication changes restart it (the
    /// escalation window re-arms — the S1 comment's promised pass).
    /// Care-team-managed users get NO self writes (returns nil).
    @discardableResult
    static func applySelfRegimen(
        _ rawSpec: SelfRegimenSpec,
        reason: String? = nil,
        userId: String,
        now: Date = .now,
        in context: ModelContext
    ) -> RegimenPlanRecord? {
        let spec = rawSpec.normalized()
        guard !userId.isEmpty else { return nil }
        if let careTeam = activeCareTeamMedicationPlan(userId: userId, in: context),
           isManagedByCareTeam(careTeam) {
            return nil
        }

        let existing = activeSelfMedicationPlan(userId: userId, in: context)

        // No active plan → version 1.
        guard let current = existing else {
            let plan = RegimenPlanRecord(
                userId: userId,
                kind: "medication",
                displayName: spec.displayName,
                scheduleRule: spec.scheduleRule,
                anchorWeekday: spec.anchorWeekday,
                timeOfDayMinutes: spec.timeOfDayMinutes,
                startedAt: now,
                reminderEnabled: spec.reminderEnabled,
                productId: spec.productId,
                route: spec.route
            )
            plan.strengthValue = spec.doseValue
            plan.strengthUnit = spec.doseValue == nil ? nil : (spec.doseUnit ?? "mg")
            plan.secondAnchorWeekday = spec.secondAnchorWeekday
            plan.intervalDays = spec.intervalDays
            plan.anchorDayKey = spec.anchorDayKey
            plan.createdAt = now
            plan.updatedAt = now
            context.insert(plan)
            save(plan, in: context)
            trackChange("created", plan: plan)
            reconcileCohortStatus(userId: userId, in: context)
            CohortIdentity.refresh(userId: userId, in: context)
            return plan
        }

        // Unchanged facts → preference-only touch.
        if spec.matchesFacts(of: current) {
            if current.reminderEnabled != spec.reminderEnabled {
                current.reminderEnabled = spec.reminderEnabled
                current.updatedAt = now
                current.pendingUpsert = true
                save(current, in: context)
                trackChange("reminder_toggle", plan: current)
            }
            return current
        }

        let changeReason = reason ?? inferredReason(from: current, to: spec)

        // Same-day coalesce: the row she created today absorbs the
        // correction in place (its id keeps event provenance).
        if MedicationScheduleEngine.dayKey(for: current.createdAt)
            == MedicationScheduleEngine.dayKey(for: now) {
            write(spec, onto: current, now: now)
            save(current, in: context)
            trackChange(changeReason, plan: current)
            reconcileCohortStatus(userId: userId, in: context)
            CohortIdentity.refresh(userId: userId, in: context)
            return current
        }

        // A settled change → version.
        current.endedAt = now
        current.endReason = changeReason
        current.updatedAt = now
        current.pendingUpsert = true

        let next = RegimenPlanRecord(
            userId: userId,
            kind: "medication",
            displayName: spec.displayName,
            scheduleRule: spec.scheduleRule,
            anchorWeekday: spec.anchorWeekday,
            timeOfDayMinutes: spec.timeOfDayMinutes,
            startedAt: changeReason == "schedule_changed"
                ? current.startedAt : now,
            reminderEnabled: spec.reminderEnabled,
            productId: spec.productId,
            route: spec.route
        )
        next.strengthValue = spec.doseValue
        next.strengthUnit = spec.doseValue == nil ? nil : (spec.doseUnit ?? "mg")
        next.secondAnchorWeekday = spec.secondAnchorWeekday
        next.intervalDays = spec.intervalDays
        next.anchorDayKey = spec.anchorDayKey
        // Tenure is biographical — every version carries it forward.
        next.treatmentStartedOn = current.treatmentStartedOn
        next.previousPlanId = current.id
        next.createdAt = now
        next.updatedAt = now
        context.insert(next)
        try? context.save()
        let endedSync = current
        let nextSync = next
        Task {
            await AppSync.shared.upsertRegimenPlan(endedSync)
            await AppSync.shared.upsertRegimenPlan(nextSync)
        }
        trackChange(changeReason, plan: next)
        reconcileCohortStatus(userId: userId, in: context)
        CohortIdentity.refresh(userId: userId, in: context)
        return next
    }

    /// v25 E2 B1 — the regimen lifecycle, categorical only (change
    /// word, route, cadence class, authority; never a name or dose).
    private static func trackChange(_ change: String, plan: RegimenPlanRecord) {
        Analytics.track(.regimenChanged, properties: [
            "change": change,
            "route": plan.route ?? "unknown",
            "cadence": plan.scheduleRule,
            "authority": plan.authority,
        ])
    }

    private static func write(
        _ spec: SelfRegimenSpec, onto plan: RegimenPlanRecord, now: Date
    ) {
        plan.productId = spec.productId
        plan.displayName = spec.displayName
        plan.route = spec.route
        plan.scheduleRule = spec.scheduleRule
        plan.anchorWeekday = spec.anchorWeekday
        plan.secondAnchorWeekday = spec.secondAnchorWeekday
        plan.intervalDays = spec.intervalDays
        plan.anchorDayKey = spec.anchorDayKey
        plan.timeOfDayMinutes = spec.timeOfDayMinutes
        plan.strengthValue = spec.doseValue
        plan.strengthUnit = spec.doseValue == nil ? nil : (spec.doseUnit ?? "mg")
        plan.reminderEnabled = spec.reminderEnabled
        plan.updatedAt = now
        plan.pendingUpsert = true
    }

    private static func inferredReason(
        from plan: RegimenPlanRecord, to spec: SelfRegimenSpec
    ) -> String {
        if plan.productId != spec.productId
            || plan.displayName != spec.displayName
            || plan.route != spec.route {
            return "medication_changed"
        }
        if plan.strengthValue != spec.doseValue { return "dose_changed" }
        return "schedule_changed"
    }

    private static func save(_ plan: RegimenPlanRecord, in context: ModelContext) {
        try? context.save()
        let toSync = plan
        Task { await AppSync.shared.upsertRegimenPlan(toSync) }
    }

    /// Lift a spec off an existing plan (the change sheets start
    /// from the current truth).
    static func spec(from plan: RegimenPlanRecord) -> SelfRegimenSpec {
        SelfRegimenSpec(
            productId: plan.productId,
            displayName: plan.displayName,
            route: plan.route ?? "injection",
            scheduleRule: plan.scheduleRule,
            anchorWeekday: plan.anchorWeekday,
            secondAnchorWeekday: plan.secondAnchorWeekday,
            intervalDays: plan.intervalDays,
            anchorDayKey: plan.anchorDayKey,
            timeOfDayMinutes: plan.timeOfDayMinutes,
            doseValue: plan.strengthValue,
            doseUnit: plan.strengthUnit,
            reminderEnabled: plan.reminderEnabled
        )
    }

    /// Create or update the SELF-managed medication plan's shot-day
    /// anchor (the v8 API, preserved — evening close + seeds call
    /// it). Since v24 it flows through the version chokepoint.
    @discardableResult
    static func setShotDay(
        _ isoWeekday: Int, userId: String, in context: ModelContext
    ) -> RegimenPlanRecord? {
        guard (1...7).contains(isoWeekday), !userId.isEmpty else { return nil }
        if let existing = activeMedicationPlan(userId: userId, in: context),
           isManagedByCareTeam(existing) {
            return existing
        }
        var spec = activeSelfMedicationPlan(userId: userId, in: context)
            .map(Self.spec(from:)) ?? SelfRegimenSpec()
        spec.scheduleRule = "weeklyAnchor"
        spec.anchorWeekday = isoWeekday
        return applySelfRegimen(
            spec, reason: "schedule_changed", userId: userId, in: context
        )
    }

    /// v25 p53 — record when treatment actually began (a CIVIL day,
    /// "yyyy-MM-dd"). Biographical fact, not a regimen version: it
    /// mutates the active plan in place (the reminderEnabled
    /// precedent) and the spec carries it across future versions.
    /// Care-team plans refuse, like every self write.
    static func setTreatmentStart(
        civilDay: String?, userId: String, in context: ModelContext
    ) {
        guard let plan = activeMedicationPlan(userId: userId, in: context),
              !isManagedByCareTeam(plan) else { return }
        // Refuse garbage at the door: nil clears, a real civil day
        // must parse in the pinned vocabulary.
        if let civilDay,
           MedicationScheduleEngine.parseDayKey(civilDay, calendar: .current) == nil {
            return
        }
        guard plan.treatmentStartedOn != civilDay else { return }
        plan.treatmentStartedOn = civilDay
        plan.updatedAt = .now
        plan.pendingUpsert = true
        try? context.save()
        let toSync = plan
        Task { await AppSync.shared.upsertRegimenPlan(toSync) }
    }

    /// p58 — THE RECORD OUTRANKS THE QUESTIONNAIRE, kept true at the
    /// chokepoint. `onboarding_glp1_status` was written once by the
    /// consult and then read by every cohort consumer (the count-up
    /// grammar, the protein branch, the chapter, the coach envelope,
    /// the notification brain) — while the regimen record aged
    /// underneath it. Walked on the sim: an active injectable regimen
    /// with no consult key put "your shot is today" and "187 over" on
    /// ONE screen. So the same chokepoints that own regimen truth now
    /// keep the key honest:
    ///   · an ACTIVE medication plan (self or care-team) means she IS
    ///     on medication — the key becomes "current";
    ///   · ending the last active plan ages a stated "current" to
    ///     "past" — but ONLY when the record actually holds
    ///     medication history. An answer the record neither confirms
    ///     nor denies (none / considering / prefer_not_say with no
    ///     history) is HER word and is never rewritten.
    /// The UserRecord mirror follows so a reinstall restores the aged
    /// fact rather than resurrecting the consult-era answer.
    @MainActor
    static func reconcileCohortStatus(userId: String, in context: ModelContext) {
        guard !userId.isEmpty else { return }
        let d = UserDefaults.standard
        let key = "onboarding_glp1_status"
        let stated = d.string(forKey: key) ?? ""
        let active = activeMedicationPlan(userId: userId, in: context) != nil

        let desired: String?
        if active {
            desired = stated == "current" ? nil : "current"
        } else if stated == "current",
                  !medicationHistory(userId: userId, in: context).isEmpty {
            desired = "past"
        } else {
            desired = nil
        }
        guard let desired else { return }
        d.set(desired, forKey: key)

        let fetch = FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == userId }
        )
        if let record = try? context.fetch(fetch).first,
           record.onboardingGlp1Status != desired {
            record.onboardingGlp1Status = desired
            record.pendingUpsert = true
            try? context.save()
            let toSync = record
            Task { await AppSync.shared.upsertUser(toSync) }
        }
    }

    /// End the SELF-managed medication plan. `reason` is "ended"
    /// (stopped for good) or "paused" (a break — the history ledger
    /// renders the difference; the engines treat both as inactive).
    /// Clinician-managed plans end only through the care team.
    static func endMedicationPlan(
        userId: String, reason: String = "ended", in context: ModelContext
    ) {
        guard let plan = activeMedicationPlan(userId: userId, in: context),
              !isManagedByCareTeam(plan) else { return }
        plan.endedAt = .now
        plan.endReason = reason
        plan.updatedAt = .now
        plan.pendingUpsert = true
        try? context.save()
        let toSync = plan
        Task { await AppSync.shared.upsertRegimenPlan(toSync) }
        trackChange(reason, plan: plan)
        reconcileCohortStatus(userId: userId, in: context)
        CohortIdentity.refresh(userId: userId, in: context)
    }

    // MARK: - v24 reads

    /// The full medication history, newest first — every version
    /// (self and care-team) that ever composed her days. The
    /// regimen home's ledger + the dose-era read consume this.
    static func medicationHistory(
        userId: String, in context: ModelContext
    ) -> [RegimenPlanRecord] {
        guard !userId.isEmpty else { return [] }
        let d = FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate {
                $0.userId == userId && $0.kind == "medication"
            },
            // createdAt breaks the tie when a schedule-only change
            // inherited its predecessor's startedAt.
            sortBy: [
                SortDescriptor(\.startedAt, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
            ]
        )
        return (try? context.fetch(d)) ?? []
    }

    /// Lift the schedule engine's facts off a plan.
    static func facts(
        for plan: RegimenPlanRecord
    ) -> MedicationScheduleEngine.RegimenFacts {
        .init(
            scheduleRule: plan.scheduleRule,
            anchorWeekday: plan.anchorWeekday,
            secondAnchorWeekday: plan.secondAnchorWeekday,
            intervalDays: plan.intervalDays,
            anchorDayKey: plan.anchorDayKey,
            timeOfDayMinutes: plan.timeOfDayMinutes,
            route: plan.route,
            startedAt: plan.startedAt
        )
    }

    // MARK: - Pure date math (unit-tested)

    /// Stage A intake words → ISO weekday. nil for empty/unknown
    /// (a skipped ask writes nothing).
    nonisolated static func isoWeekday(fromWord word: String?) -> Int? {
        switch word {
        case "mon": return 1
        case "tue": return 2
        case "wed": return 3
        case "thu": return 4
        case "fri": return 5
        case "sat": return 6
        case "sun": return 7
        default: return nil
        }
    }

    /// ISO weekday for a date: 1 = Monday … 7 = Sunday.
    nonisolated static func isoWeekday(
        _ date: Date, calendar: Calendar = .current
    ) -> Int {
        let apple = calendar.component(.weekday, from: date)  // 1 = Sun
        return apple == 1 ? 7 : apple - 1
    }

    /// Whether `date` is a dose day for a weekly anchor.
    nonisolated static func isDoseDay(
        _ date: Date, anchorWeekday: Int?, calendar: Calendar = .current
    ) -> Bool {
        guard let anchorWeekday else { return false }
        return isoWeekday(date, calendar: calendar) == anchorWeekday
    }

    /// 0 = shot day, 1 = day after … 6 = the day before the next
    /// shot. nil without an anchor. The waveform position the
    /// briefs + sit-check correlation read (v8 next passes).
    nonisolated static func dayInMedicationWeek(
        _ date: Date, anchorWeekday: Int?, calendar: Calendar = .current
    ) -> Int? {
        guard let anchorWeekday else { return nil }
        return (isoWeekday(date, calendar: calendar) - anchorWeekday + 7) % 7
    }

    /// The titration-support window: weeks since the plan started,
    /// against the protocol's window. (S1 approximation — a later
    /// pass keys off dose-stage changes when she records them.)
    nonisolated static func titrationWindowActive(
        _ date: Date, startedAt: Date?,
        careProtocol: CareProtocol = .default,
        calendar: Calendar = .current
    ) -> Bool {
        guard let startedAt else { return false }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: startedAt),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return days >= 0 && days < careProtocol.regimen.titrationSupportWeeks * 7
    }
}
