import Foundation
import SwiftData
import PlankSync
import PlankFood

// MARK: - DeletionLedger (v25 §38 — IF I DELETE IT, IT STAYS DELETED)
//
// THE DEFECT, stated once so nobody has to re-derive it:
//
//   Deletion was represented as ABSENCE, and absence is ambiguous. A
//   row that is not there may mean (1) it never existed, (2) it has
//   not hydrated yet, (3) the write failed, or (4) IT WAS DELETED
//   SOMEWHERE ELSE. Three heals exist to fix (2) and (3), and every
//   one of them resolves the ambiguity AGAINST (4):
//
//     · pushLocalFoodEntriesMissingFromServer  reads absence on the
//       server as "the server never got it", and re-uploads
//     · mergeRemote / applyHydratedWeightLogs / hydrateObservations /
//       hydrateDoseEvents are INSERT-ONLY, so they read absence
//       locally as "I don't have it yet", and re-insert
//
//   So a plate deleted on device A is re-uploaded by device B on its
//   next launch and lands back on A's next hydrate. No offline step
//   is required (v25 §37 §15, reproduced end to end in §38 §3).
//
// THE CONTRACT:
//
//   ▎ A DELETION IS A FACT THIS DEVICE RECORDS, NOT AN ABSENCE IT
//   ▎ INFERS.
//
// This is the smallest correct mechanism for that sentence, and it was
// chosen over a server tombstone, versioned rows and a change log for
// one reason that is not cost: a server tombstone CANNOT SHIP ALONE.
// Its read half needs every hydrate to filter `deleted_at is null`,
// and the shipping 1.2.0 (30) client does not filter — so applying it
// before a filtering client reaches the installed base would turn
// every deletion into a resurrection ON THE DELETING DEVICE, which is
// strictly worse than today. Client first, migration second. §38 §5-6.
//
// What this closes and what it does not:
//
//   ✓ "I deleted it on my iPhone — it never comes back on my iPhone",
//     permanently, whatever any other device does.
//   ✓ DELETE BEATS UPDATE: a deletion decides whether the record
//     exists; an edit decides what it says. The first outranks the
//     second, so a row a stale device pushed back is removed again
//     AND the server delete is re-asserted.
//   ✗ It does not carry the deletion TO the other device. Only a
//     server tombstone can. Named in §38, not hidden.
//   ✗ It is device-local, so a REINSTALL of the deleting device loses
//     it. Also named.
//
// Failure mode, by construction: this mechanism only ever PREVENTS an
// insert or removes a row it has already been told to remove. It can
// never destroy a record the customer still has — which is why it is
// safe to ship before the migration that would make it complete.

@MainActor
enum DeletionLedger {

    /// Device-local, per-account. NOT swept at sign-out (see
    /// `AppSync.clearOnboardingUserDefaults`): sign-out preserves the
    /// SwiftData rows, so a ledger swept alongside it would re-open
    /// every resurrection the next time she signed back in.
    private static func key(_ userId: String) -> String {
        "deletions.v1.\(userId.lowercased())"
    }

    /// 2,000 ids per account, oldest evicted. An entry is one
    /// lowercased id plus an epoch double — roughly 60 bytes, so the
    /// whole cap is ~120 KB. For scale: `MoveManualStore` caps at 400
    /// and the entire food corpus of a two-year daily logger is about
    /// 2,000 plates. The eviction is stated in the record rather than
    /// hidden: past the cap the OLDEST deletion can be resurrected by
    /// a stale device, which is the honest boundary of a device-local
    /// mechanism and another argument for the server tombstone.
    static let cap = 2_000

    // MARK: - The fact

    /// Record that the customer removed this record. Called at every
    /// real delete BEFORE the network call, so a delete attempted
    /// offline is still remembered by the device that made it.
    static func record(id: String, userId: String) {
        guard !id.isEmpty, !userId.isEmpty else { return }
        var map = stored(userId)
        map[id.lowercased()] = Date.now.timeIntervalSince1970
        if map.count > cap {
            let overflow = map.count - cap
            for (k, _) in map.sorted(by: { $0.value < $1.value }).prefix(overflow) {
                map.removeValue(forKey: k)
            }
        }
        UserDefaults.standard.set(map, forKey: key(userId))
    }

    /// The customer re-created a record under the SAME id, so the
    /// deletion fact is superseded.
    ///
    /// NOT optional. Dose slots (`user × slot`) and symptoms
    /// (`user × kind × day`) carry DETERMINISTIC ids, so without this
    /// a customer who unmarks a dose and then marks it again could
    /// never see that slot hydrate on another device: the ledger would
    /// refuse her own new record. Wired at the write chokepoints, not
    /// at the call sites.
    static func supersede(id: String, userId: String) {
        guard !id.isEmpty, !userId.isEmpty else { return }
        var map = stored(userId)
        guard map.removeValue(forKey: id.lowercased()) != nil else { return }
        UserDefaults.standard.set(map, forKey: key(userId))
    }

    static func contains(id: String, userId: String) -> Bool {
        guard !id.isEmpty, !userId.isEmpty else { return false }
        return stored(userId)[id.lowercased()] != nil
    }

    /// v25 §44 — **THE DAY SHE CLEARED, WHEN THE ROW HAD NO ID SHE
    /// CHOSE.**
    ///
    /// Every other tombstone in this ledger names a row id, because
    /// every other resurrection re-inserts THE SAME id (an insert-only
    /// hydrate, or a stale device re-pushing the row it kept).
    ///
    /// A weigh-in has a second author, and it does not work that way.
    /// `BodyMassImportService` re-reads ninety days of Apple Health at
    /// every launch and on every observer fire, decides BY CALENDAR DAY
    /// (*"a day with no local row is a day I create one for"*) and mints
    /// a FRESH uuid when it does. An id-shaped tombstone cannot see that
    /// row, so `remove it` — which `34` shipped and the screen promises
    /// in as many words — undid itself on the next launch for the
    /// commonest weigh-in source this product has.
    ///
    /// So the retraction is recorded against the thing she actually
    /// cleared. The shape follows the deterministic ids this codebase
    /// already uses (`<uid>-dose-<day>`, `<uid>-symptom-<s>-<day>`),
    /// which means `IdentityMerge.rekeyedDeterministicId`'s prefix swap
    /// and `carry` above translate it for free, and `sweep` ignores it —
    /// it can never match a real row id, and it is not meant to.
    ///
    /// It is deliberately NOT superseded by a later weigh-in: a row on
    /// that day makes the importer stand down anyway (manual wins its
    /// day), and if she removes THAT row too the tombstone is simply
    /// re-recorded. Clearing a day stays cleared until the account goes.
    static func clearedWeightDayId(userId: String, dayKey: String) -> String {
        "\(userId.lowercased())-weightday-\(dayKey)"
    }

    /// v25 pass 51 — **AND THE INSTANT, because the day key is a
    /// time-zone reading.** The day tombstone above is minted with the
    /// dayKey CURRENT AT DELETE and checked with the dayKey CURRENT AT
    /// IMPORT; a zone change between the two (a flight, a Settings
    /// change) re-buckets the same Apple Health sample onto a
    /// neighboring civil day, the keys stop matching, and the cleared
    /// weigh-in resurrects under a fresh uuid — §44's hole, re-opened
    /// along the timezone axis. The sample's INSTANT is zone-proof:
    /// the row the importer would re-create carries `loggedAt ==
    /// sample.startDate` verbatim, so tombstoning the epoch second
    /// blocks the same physical sample in every zone, with zero risk
    /// of over-blocking a neighbor day's genuine new sample. Same
    /// `<uid>-` prefix shape, so the handoff prefix swap carries it.
    static func clearedWeightInstantId(userId: String, at instant: Date) -> String {
        "\(userId.lowercased())-weightinstant-\(Int(instant.timeIntervalSince1970.rounded()))"
    }

    static func count(userId: String) -> Int { stored(userId).count }

    /// v25 §42 — **A DELETION FOLLOWS THE ROW IT NAMES, AND ONLY WHEN
    /// THE ROW KEPT ITS NAME.**
    ///
    /// `41` §19 ruled that this ledger must NEVER cross into the
    /// destination, and gave the right reason: *a deletion she made as
    /// one identity is not an assertion about another account's rows.*
    /// That holds exactly while the carry MINTS FRESH IDS — a tombstone
    /// for A's id says nothing about B's differently-named row.
    ///
    /// `complete_account_handoff(mode: 'move')` breaks the premise, not
    /// the principle: it moves the SAME PHYSICAL ROW with the SAME ID.
    /// A tombstone that named that row still names it, and dropping it
    /// would let the insert-only hydrates and the launch food reconcile
    /// resurrect a plate she deleted — `38`'s whole defect, re-opened by
    /// the migration meant to make ownership honest.
    ///
    /// Deterministic ids carry the uid, so they are translated by the
    /// SAME prefix swap the merge and the server both use. An id that
    /// does not carry the source uid is copied verbatim. Nothing is
    /// invented: an id this function cannot derive is dropped rather
    /// than guessed at, which is `rekeyedDeterministicId`'s own refusal.
    ///
    /// Never called on a SWITCH or a sign-out. Only on an ADOPT whose
    /// server move committed.
    static func carry(from oldId: String, to newId: String) {
        guard !oldId.isEmpty, !newId.isEmpty,
              oldId.caseInsensitiveCompare(newId) != .orderedSame
        else { return }
        let source = stored(oldId)
        guard !source.isEmpty else { return }
        let oldPrefix = oldId.lowercased()
        let newPrefix = newId.lowercased()
        var destination = stored(newId)
        for (id, stamp) in source {
            let carried = id.hasPrefix(oldPrefix)
                ? newPrefix + id.dropFirst(oldPrefix.count)
                : id
            // The destination's own tombstone for the same id is not
            // overwritten with an older timestamp; a deletion is a
            // deletion either way and the newer stamp is the honest one.
            destination[String(carried)] = max(destination[String(carried)] ?? 0, stamp)
        }
        if destination.count > cap {
            let overflow = destination.count - cap
            for (k, _) in destination.sorted(by: { $0.value < $1.value }).prefix(overflow) {
                destination.removeValue(forKey: k)
            }
        }
        UserDefaults.standard.set(destination, forKey: key(newId))
    }

    /// Account deletion only. The ledger is derived from the
    /// customer's own deletions, so it is her data and it goes with
    /// her account — but it must survive a sign-out, because the rows
    /// it protects do.
    static func clear(userId: String) {
        guard !userId.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: key(userId))
    }

    private static func stored(_ userId: String) -> [String: Double] {
        UserDefaults.standard.dictionary(forKey: key(userId)) as? [String: Double] ?? [:]
    }

    // MARK: - The sweep

    /// Run after EVERY hydrate. Any locally-present record whose id
    /// this device tombstoned is removed again, and the server delete
    /// is re-asserted so the row does not simply return next launch.
    ///
    /// Re-asserting is the only outward propagation available before
    /// tombstones exist: the deleting device re-deletes the row every
    /// time a stale device pushes it back. It flaps until the other
    /// device updates. Stated rather than dressed up.
    ///
    /// Returns the number of resurrected records it removed — zero on
    /// every normal launch.
    @discardableResult
    static func sweep(userId: String, in context: ModelContext) -> Int {
        guard !userId.isEmpty else { return 0 }
        let tombstoned = stored(userId)
        guard !tombstoned.isEmpty else { return 0 }
        var removed = 0

        // FOOD — driven through the SAME public function the
        // customer's own `remove` uses, so the re-deletion also fires
        // `onEntryDeleted` and the cloud row + thumbnail go again.
        for entry in FoodLogPersister.allEntries(userId: userId)
        where tombstoned[entry.id.lowercased()] != nil {
            FoodLogPersister.deleteEntry(id: entry.id)
            removed += 1
        }

        // WEIGHT · DOSE · SYMPTOM — the three insert-only hydrates.
        // Each removal re-asserts the server delete for the same
        // reason: DELETE BEATS UPDATE, so a stale device that edited
        // the row it should not still have does not win.
        let owner = userId
        let weights = (try? context.fetch(FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []
        for row in weights where tombstoned[row.id.lowercased()] != nil {
            context.delete(row)
            let id = row.id
            Task { await AppSync.shared.deleteWeightLog(id: id) }
            removed += 1
        }

        let doses = (try? context.fetch(FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []
        for row in doses where tombstoned[row.id.lowercased()] != nil {
            context.delete(row)
            let id = row.id
            Task { await AppSync.shared.deleteDoseEvent(id: id) }
            removed += 1
        }

        let observations = (try? context.fetch(FetchDescriptor<ObservationRecord>(
            predicate: #Predicate { $0.userId == owner }))) ?? []
        for row in observations where tombstoned[row.id.lowercased()] != nil {
            context.delete(row)
            let id = row.id
            Task { await AppSync.shared.deleteObservation(id: id) }
            removed += 1
        }

        if removed > 0 { try? context.save() }
        return removed
    }
}
