import Foundation
import SwiftData
import PlankSync

// MARK: - IdentityMerge (v25 §40 — THE LAST ORPHAN)
//
// THE FINDING, AND IT CORRECTS `39`.
//
// `39` §3 tabulated what happens to each thing she recorded when the
// uid changes, and recorded DOSE, SYMPTOM, PROGRAM FACTS and WEEKLY
// READS as **REKEYED** locally. They are not. `AppSync.reattributeModelRows`
// fetches exactly seven families — `SessionLogRecord` · `SessionRatingRecord`
// · `DayProgressRecord` · `WeightLogRecord` · `ProgramPlanRecord` ·
// `ProgramDayCheckRecord` · `BodyScanRecord` — plus the food JSONL.
// The repository declares EIGHTEEN `@Model` types.
//
// So on any uid change, everything below stayed keyed to the abandoned
// uid, on the phone in her hand, invisible to every `@Query userId` in
// the product:
//
//   · `DoseEventRecord`     every shot she marked            (v24)
//   · `ObservationRecord`   every symptom she logged         (`36`)
//   · `RegimenPlanRecord`   her medication regimen           (v24)
//   · `ProgramFactRecord`   her program's authority chains   (E1)
//   · `WeeklyReadRecord`    the weekly read's decisions      (E1)
//   · `JeniMemoryRecord`    the free text she asked Jeni to keep (E3)
//   · `ChatMessageRecord`   the transcript
//   · `ExerciseCalibrationRecord`
//
// ▎ A GLP-1 CUSTOMER WHO ONBOARDED ANONYMOUSLY, MARKED HER DOSES, LOGGED
// ▎ HER SYMPTOMS AND SET UP HER REGIMEN, THEN SIGNED IN, LOST ALL OF IT
// ▎ FROM HER OWN SCREEN IN THAT INSTANT — and the server copy stayed
// ▎ under the abandoned uid, which is the same orphan by a second road.
//
// Production carries **164 `regimen_plans`, 53 `observations` and 14
// `dose_events` under anonymous uids** today (§40 §2), so this is not
// hypothetical.
//
// WHY IT WAS INVISIBLE FOR SIX PASSES. Nothing throws, nothing logs, no
// number moves: the rows are still on disk and still perfectly valid.
// They simply answer to a name the app no longer uses. Every audit that
// read the DELETION sweep saw all eighteen families (it is exhaustive);
// only the MERGE is short, and no test compared the two lists.
//
// WHAT `39`'s LINK FIX ALREADY DOES ABOUT IT, WHICH IS A LOT.
// The dominant path — anonymous customer, brand-new Apple identity —
// no longer changes the uid at all, so there is nothing to re-key and
// this whole class disappears for it. What remains is every path where
// the uid genuinely must change: the collision fallback, and a
// returning customer signing in with email.
//
// THE RULES, ONE PER FAMILY, AND THE REFUSALS ARE THE POINT.

@MainActor
enum IdentityMerge {

    /// What happened, for the tests and for the record. Counts only.
    struct Report: Equatable {
        var regimenPlans = 0
        var doseEvents = 0
        var observations = 0
        var programFacts = 0
        var weeklyReads = 0
        var calibrations = 0
        var memories = 0
        var chatMessages = 0
        var profile = 0
        /// Rows dropped because the destination already owns that exact
        /// record. The account's own row wins; a duplicate is never
        /// created and content is never compared.
        var supersededByDestination = 0
        /// Rows left alone because their id does not carry the outgoing
        /// uid, so no id can be derived for them without inventing one.
        var skippedUnrecognisedId = 0
        /// v25 §41 — rows REFUSED because they carry an authority that
        /// was granted to the SOURCE identity by somebody else. A
        /// clinic's assignment and a prescribed program fact are not
        /// hers to move, and they are not the destination's to receive.
        var refusedForeignAuthority = 0
        /// v25 §41 — live medication regimens that arrived ENDED because
        /// the destination account already has one. Her history is kept;
        /// the present tense stays single.
        var regimensEndedByDestination = 0
        /// v25 §41 — rows the destination REFUSED and that were REMOVED
        /// rather than stranded under the retired account. A refusal
        /// that leaves the row on disk under a name nothing queries is
        /// not a refusal; it is an orphan with better manners.
        var refusedAndRemoved = 0
    }

    /// v25 §41 — **AN AUTHORITY GRANTED TO ONE IDENTITY IS NOT
    /// ANOTHER'S.** `38` §13 and `40` §2 wrote that sentence for
    /// CONSENT. Reading the deployed RLS this session showed it is a
    /// law of the schema for two more families, and the merge was
    /// breaking it for both:
    ///
    ///     regimen_plans   insert/update require
    ///                     authority = 'self' AND org_id IS NULL
    ///                     AND source_protocol_id IS NULL
    ///     program_facts   insert/update require
    ///                     authority <> 'prescribed'
    ///
    /// So a care-team regimen re-keyed to the destination could never
    /// be pushed — the upsert is rejected 42501, silently, and
    /// `pendingUpsert` never clears, so it is retried on every launch
    /// forever. Worse than the wasted call: LOCALLY it succeeds, and
    /// `RegimenService.activeCareTeamMedicationPlan` then returns a
    /// clinic-assigned plan **for an account that clinic has no
    /// relationship with** — which makes the regimen read-only, puts
    /// "assigned by your care team" on her screen, and gives
    /// `CareReconciliation` a prescription to ask her to confirm.
    ///
    /// Production holds **nine** care-team regimen rows and **all nine
    /// are under anonymous accounts** — the exact population that goes
    /// through a handoff — and **zero** prescribed program facts, so
    /// the second rule costs nothing to make now and will never be
    /// cheaper.
    ///
    /// The refused row is DELETED rather than left keyed to the source:
    /// the source account is being retired, so a row left under it is
    /// the "orphan on her own phone" shape this line of work exists to
    /// remove, and the clinic's own copy goes with the account it
    /// belonged to. **No authority is ever downgraded to make a row
    /// carryable** — rewriting `care_team` to `self` would be
    /// fabricating a prescription's provenance.
    static func carriesForeignAuthority(_ plan: RegimenPlanRecord) -> Bool {
        plan.authority != "self" || plan.orgId != nil || plan.sourceProtocolId != nil
    }

    static func carriesForeignAuthority(_ fact: ProgramFactRecord) -> Bool {
        fact.authority == "prescribed"
    }

    /// THE DETERMINISTIC-ID RULE.
    ///
    /// `DoseEventStore.deterministicId` is `"<uid>-dose-<dayKey>"` and
    /// `SideEffectLog.id` is `"<uid>-symptom-<symptom>-<dayKey>"`, both
    /// lowercased. Swapping the prefix satisfies BOTH invariants at
    /// once:
    ///
    ///   · the FRESH-ID invariant — the id is new, so the push is a
    ///     clean INSERT the new account owns, not an UPDATE of a row
    ///     RLS will reject with 42501 (the reason `applyReattribution`
    ///     mints fresh uuids for weight and sessions);
    ///   · DETERMINISM — the id is exactly the one the new account
    ///     would mint for that slot, so her next mark of the same dose
    ///     day upserts onto this row instead of creating a second.
    ///
    /// A random uuid would satisfy the first and break the second, which
    /// is why this is a prefix swap and not `UUID()`.
    static func rekeyedDeterministicId(_ id: String, from oldId: String, to newId: String) -> String? {
        let old = oldId.lowercased()
        let new = newId.lowercased()
        guard !old.isEmpty, !new.isEmpty, id.lowercased().hasPrefix(old) else { return nil }
        return new + id.dropFirst(old.count)
    }

    /// Carry the families `applyReattribution` never covered.
    ///
    /// Runs INSIDE `reattributeModelRows`, on the same context and
    /// before its single `save()`, so a merge is one transaction and a
    /// crash cannot half-apply it.
    ///
    /// Idempotent by the same construction as the rest of the merge: it
    /// only ever fetches rows still keyed to the OLD uid, so a completed
    /// pass is a no-op and an interrupted one picks up the remainder.
    ///
    /// v25 §42 — `idPolicy` carries the SERVER's answer. Under
    /// `.preserve` the cloud rows have already changed owner and kept
    /// their ids, so minting fresh ones here would push a second copy of
    /// her regimen and her program's authority chains. The deterministic
    /// families (dose · symptom · weekly read) are unaffected either
    /// way: the uid is inside the id, so both sides do the same prefix
    /// swap and reach the same value.
    @discardableResult
    static func carryRemainingFamilies(
        from oldId: String,
        to newId: String,
        in context: ModelContext,
        idPolicy: HandoffIdPolicy = .mintFresh
    ) -> Report {
        var report = Report()
        guard !oldId.isEmpty, !newId.isEmpty,
              oldId.caseInsensitiveCompare(newId) != .orderedSame
        else { return report }

        func carriedId(_ current: String) -> String {
            idPolicy == .preserve ? current : UUID().uuidString
        }
        func pushFlag(_ existing: Bool) -> Bool { idPolicy.queuesAPush || existing }

        // ── REGIMEN PLANS ─ REKEY, fresh uuid, chain pointer follows.
        // Append-only version chains (v24): `previousPlanId` points at
        // the superseded row, so the remap has to follow it or the
        // chain breaks and "the record" loses its eras.
        let regimens = (try? context.fetch(FetchDescriptor<RegimenPlanRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        // v25 §41 — **ONE LIVE MEDICATION REGIMEN, AND THE ACCOUNT'S
        // OWN IS THE ONE.** A regimen chain is not an append-only
        // ledger; its head is a CURRENT-STATE claim about what she is
        // taking right now, and `RegimenService.activeMedicationPlan`
        // resolves it by `createdAt` DESC — which on a hydrated row is
        // the hydration instant, so with two live heads the answer is
        // the order of a fetch (`31` §0, the same trap for plans).
        //
        // The destination account's regimen is its established truth.
        // A's live medication head is carried and ENDED in the same
        // breath, so her dose eras stay in the record — the model
        // already carries a superseded regimen exactly this way — and
        // the present tense stays single. Supplements have no single
        // authority (`supplementPlans` returns a list), so they carry
        // live.
        let destinationHasLiveMedication = ((try? context.fetch(
            FetchDescriptor<RegimenPlanRecord>(
                predicate: #Predicate { $0.userId == newId && $0.kind == "medication" }
            ))) ?? []).contains { $0.endedAt == nil }

        var regimenRemap: [String: String] = [:]
        var carriedRegimens: [RegimenPlanRecord] = []
        for plan in regimens {
            // v25 §41 — a clinic's assignment stays with the identity it
            // was assigned to. See `carriesForeignAuthority`.
            if carriesForeignAuthority(plan) {
                context.delete(plan)
                report.refusedForeignAuthority += 1
                continue
            }
            let fresh = carriedId(plan.id)
            regimenRemap[plan.id] = fresh
            plan.id = fresh
            plan.userId = newId
            if destinationHasLiveMedication, plan.kind == "medication", plan.endedAt == nil {
                plan.endedAt = .now
                plan.endReason = "ended"
                plan.updatedAt = .now
                report.regimensEndedByDestination += 1
            }
            plan.pendingUpsert = pushFlag(plan.pendingUpsert)
            report.regimenPlans += 1
            carriedRegimens.append(plan)
        }
        // The chain pointer follows only within the CARRIED set. A
        // pointer at a refused predecessor is left as it is rather than
        // guessed at — the same refusal `rekeyedDeterministicId` makes
        // for an id it cannot derive.
        for plan in carriedRegimens {
            if let prev = plan.previousPlanId, let remapped = regimenRemap[prev] {
                plan.previousPlanId = remapped
            }
        }

        // ── DOSE EVENTS ─ REKEY by prefix, and `regimenPlanId` follows
        // the regimen remap above (it is why regimens go first).
        let doses = (try? context.fetch(FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        let destinationDoseIds = Set(((try? context.fetch(FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == newId }
        ))) ?? []).map { $0.id.lowercased() })
        for dose in doses {
            guard let fresh = rekeyedDeterministicId(dose.id, from: oldId, to: newId) else {
                report.skippedUnrecognisedId += 1
                continue
            }
            if destinationDoseIds.contains(fresh.lowercased()) {
                // THE ACCOUNT'S OWN ROW WINS. One id means one slot on
                // one day for one account; two rows cannot both be it.
                // Content is never compared and nothing is merged —
                // "these look similar" is not evidence of duplication.
                context.delete(dose)
                report.supersededByDestination += 1
                continue
            }
            dose.id = fresh
            dose.userId = newId
            dose.regimenPlanId = regimenRemap[dose.regimenPlanId] ?? dose.regimenPlanId
            dose.pendingUpsert = pushFlag(dose.pendingUpsert)
            report.doseEvents += 1
        }

        // ── OBSERVATIONS (symptoms) ─ REKEY by prefix, same rule.
        let observations = (try? context.fetch(FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        let destinationObservationIds = Set(((try? context.fetch(FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.userId == newId }
        ))) ?? []).map { $0.id.lowercased() })
        for observation in observations {
            guard let fresh = rekeyedDeterministicId(observation.id, from: oldId, to: newId) else {
                report.skippedUnrecognisedId += 1
                continue
            }
            if destinationObservationIds.contains(fresh.lowercased()) {
                context.delete(observation)
                report.supersededByDestination += 1
                continue
            }
            observation.id = fresh
            observation.userId = newId
            observation.pendingUpsert = pushFlag(observation.pendingUpsert)
            report.observations += 1
        }

        // ── PROGRAM FACTS ─ REKEY, fresh uuid, `previousFactId` follows.
        let facts = (try? context.fetch(FetchDescriptor<ProgramFactRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        var factRemap: [String: String] = [:]
        var carriedFacts: [ProgramFactRecord] = []
        for fact in facts {
            // v25 §41 — iOS writes `prescribed` NEVER (E1's law, and
            // the RLS enforces it). A prescribed fact re-keyed to
            // another identity is a prescription nobody wrote for that
            // account. Zero rows in production today.
            if carriesForeignAuthority(fact) {
                context.delete(fact)
                report.refusedForeignAuthority += 1
                continue
            }
            let fresh = carriedId(fact.id)
            factRemap[fact.id] = fresh
            fact.id = fresh
            fact.userId = newId
            fact.pendingUpsert = pushFlag(fact.pendingUpsert)
            report.programFacts += 1
            carriedFacts.append(fact)
        }
        for fact in carriedFacts {
            if let prev = fact.previousFactId, let remapped = factRemap[prev] {
                fact.previousFactId = remapped
            }
        }

        // ── WEEKLY READS ─ REKEY by prefix. `WeeklyReadRecord` carries a
        // deterministic id too (`"<uid>-read-<windowStartDay>"`), which
        // a fresh uuid would silently break: her next read of the same
        // week would mint the canonical id and land a SECOND row for one
        // week. `factId` follows the fact remap the way
        // `program_day_checks` follows the plan remap.
        let reads = (try? context.fetch(FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        let destinationReadIds = Set(((try? context.fetch(FetchDescriptor<WeeklyReadRecord>(
            predicate: #Predicate { $0.userId == newId }
        ))) ?? []).map { $0.id.lowercased() })
        for read in reads {
            guard let fresh = rekeyedDeterministicId(read.id, from: oldId, to: newId) else {
                report.skippedUnrecognisedId += 1
                continue
            }
            if destinationReadIds.contains(fresh.lowercased()) {
                context.delete(read)
                report.supersededByDestination += 1
                continue
            }
            read.id = fresh
            read.userId = newId
            if let factId = read.factId, let remapped = factRemap[factId] {
                read.factId = remapped
            }
            read.pendingUpsert = pushFlag(read.pendingUpsert)
            report.weeklyReads += 1
        }

        // ── EXERCISE CALIBRATIONS ─ REKEY the composite key.
        let calibrations = (try? context.fetch(FetchDescriptor<ExerciseCalibrationRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        let destinationCalibrationKeys = Set(((try? context.fetch(
            FetchDescriptor<ExerciseCalibrationRecord>(
                predicate: #Predicate { $0.userId == newId }
            ))) ?? []).map { $0.compositeKey.lowercased() })
        for calibration in calibrations {
            let fresh = "\(newId):\(calibration.exerciseType)"
            if destinationCalibrationKeys.contains(fresh.lowercased()) {
                context.delete(calibration)
                report.supersededByDestination += 1
                continue
            }
            calibration.compositeKey = fresh
            calibration.userId = newId
            report.calibrations += 1
        }

        // ── JENI MEMORY ─ REKEY IN PLACE. There is no server row (`37`
        // §4A is drafted and deliberately unapplied), so no fresh id is
        // needed and none is minted: the id is only ever a local handle,
        // and `forget` addresses it. This is the same treatment
        // `BodyScanRecord` already gets, for the same reason.
        let memories = (try? context.fetch(FetchDescriptor<JeniMemoryRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        for memory in memories {
            memory.userId = newId
            report.memories += 1
        }

        // ── CHAT TRANSCRIPT ─ REKEY IN PLACE, same reason
        // (`public.coach_messages` has zero client writers, `37` §4B).
        let messages = (try? context.fetch(FetchDescriptor<ChatMessageRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        for message in messages {
            message.userId = newId
            report.chatMessages += 1
        }

        // ── PROFILE ─ B WINS, AND THE OUTGOING ROW IS ONLY EVER USED TO
        // FILL AN ABSENCE.
        //
        // `UserRecord.id` IS the uid, so there can be exactly one per
        // account, and the account she has just reached owns its own
        // body facts. Carrying an anonymous profile over a real one
        // would overwrite her account's height, weight, goal and cohort
        // with whatever this device happened to hold — which is the
        // shape of the bug `29` spent a whole pass removing.
        //
        // When the destination has NO profile row, there is nothing to
        // overwrite and the carry is monotone: it can only ever add.
        let destinationProfile = (try? context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == newId }
        )))?.first
        let outgoingProfile = (try? context.fetch(FetchDescriptor<UserRecord>(
            predicate: #Predicate { $0.id == oldId }
        )))?.first
        if let outgoing = outgoingProfile {
            if destinationProfile == nil {
                outgoing.id = newId
                outgoing.pendingUpsert = true   // the PK is the uid: the destination row does not exist under either policy
                report.profile += 1
            } else {
                // v25 §41 — **REFUSED IS NOT THE SAME AS LEFT BEHIND.**
                // `40` refused to overwrite the account's profile, which
                // is right, and then left the device's row on disk keyed
                // to a uid that is about to be retired. It holds her
                // height, her weight, her goal, her sex and her cohort;
                // nothing queries it, nothing hydrates it, and
                // `clearLocalUserRecords` scopes to the account she is
                // now in — so "delete my account" never reached it, on
                // disk or in any device backup. The same shape `37`
                // closed for jeni memory, program facts and weekly
                // reads.
                context.delete(outgoing)
                report.refusedAndRemoved += 1
            }
        }

        // ── CONSENT ─ REFUSED, AND THIS IS A DECISION, NOT AN OMISSION.
        //
        // `ConsentGrantRecord` is an answer she gave AS ONE IDENTITY.
        // Carrying it across an identity switch would hand a new account
        // a permission nobody granted under it, and `38` §13 already
        // wrote the rule this obeys: **unknown consent is never
        // permission**, and a failed or absent read must leave the
        // toggle OFF. `hydrateConsentGrants` brings the destination
        // account's own answer, from the server, which is the only
        // authority for it.
        //
        // v25 §41 — and the refused row is REMOVED rather than stranded,
        // for the same reason as the profile above. The account it
        // answered for is being retired; its server row goes with that
        // account; a local copy under a name nothing will ever use again
        // is exactly the orphan this line of work exists to remove.
        let grants = (try? context.fetch(FetchDescriptor<ConsentGrantRecord>(
            predicate: #Predicate { $0.userId == oldId }
        ))) ?? []
        for grant in grants {
            context.delete(grant)
            report.refusedAndRemoved += 1
        }

        return report
    }
}
