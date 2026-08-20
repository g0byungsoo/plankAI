import Foundation
import SwiftData
import PlankSync
import PlankFood

// MARK: - LocalHandoffInventory (v25 §41 — THE HANDOFF)
//
// THE ONE LIST. `40` found that the merge covered SEVEN families while
// the deletion sweep covered all of them, and that nothing anywhere
// compared the two lists — which is exactly how ten customer-owned
// families stayed keyed to an abandoned uid for six passes. The fix
// `40` shipped was correct and it was still a SECOND list written
// beside the first.
//
// ▎ THE COUNT, RE-DERIVED RATHER THAN INHERITED.
//
// The repository declares **eighteen** `@Model` types.
// `ExerciseRecord` is the exercise LIBRARY — `type` / `unlockDay` /
// `isStatic`, no `userId`, seeded from a static array — so it is
// reference data and not customer-owned. **SEVENTEEN `@Model` families
// are customer-owned**, and the pre-`40` merge dropped **ten** of them,
// not eleven. `40` §2's "eleven of eighteen" counted the exercise
// library as a record family.
//
// And `@Model` was never the ownership inventory. Four more families
// are customer-owned and are not SwiftData rows at all:
//
//   · the FOOD JOURNAL      a JSONL store, uid-keyed  → in the merge
//   · food PHOTOS           files keyed by entry id   → follow the entry
//   · `move.manual.v1`      every workout she typed   → device-scoped
//   · `day.note.*` / `day.reflection.*` / `day.sit.*`
//                           her evening words, and the SERVER table
//                           `public.day_reflections` behind them
//                                                     → device-scoped
//
// The last two are the ones this pass had to decide, because they are
// customer-AUTHORED and they are keyed to the DEVICE rather than to an
// account:
//
//   ▎ A DEVICE-SCOPED CUSTOMER-AUTHORED FACT FOLLOWS THE **PERSON**, SO
//   ▎ IT FOLLOWS AN ADOPT AND IT MUST NOT FOLLOW A SWITCH.
//
// On an ADOPT the person did not change, so leaving them in place is
// correct and is what happens today, by accident rather than by rule.
// On a SWITCH the person DID change, and today they carry — B's MOVE
// sheet lists A's workouts and B's Home reads A's evening feeling,
// which reaches Jeni's own context envelope. That is closed by
// `AccountOperation.isolatesTheOutgoingAccount` running the existing
// cross-account isolation sweep.

@MainActor
enum LocalHandoffInventory {

    /// What a handoff does with each family. Written down so the rule is
    /// a sentence rather than the shape of whichever function last
    /// touched it.
    enum Rule: String {
        /// Move it to the destination. Ids are rewritten only where the
        /// server's ownership rules force it.
        case rekey
        /// Move it, keeping the id, because no server row exists for it.
        case rekeyInPlace
        /// The destination's own row wins; the incoming one is dropped.
        /// Content is NEVER compared.
        case destinationWins
        /// Never carried across an identity transition, and the reason
        /// is always the same one: an answer, a permission or an
        /// authority given as one identity is not another's.
        case refused
        /// Keyed to the device, not the account. Follows the person on
        /// an ADOPT; swept on a SWITCH.
        case deviceScoped
    }

    /// The whole inventory, in one place. The test does not read this
    /// table to decide what to check — it counts the FOOTPRINT — but a
    /// reader deserves the list, and a family added to the product
    /// without a line here is a family nobody decided about.
    static let families: [(name: String, rule: Rule)] = [
        ("UserRecord (profile)",        .destinationWins),
        ("SessionLogRecord",            .rekey),
        ("SessionRatingRecord",         .rekey),
        ("DayProgressRecord",           .destinationWins),
        ("WeightLogRecord",             .rekey),
        ("ExerciseCalibrationRecord",   .destinationWins),
        ("ProgramPlanRecord",           .rekey),
        ("ProgramDayCheckRecord",       .rekey),
        ("ObservationRecord",           .destinationWins),
        ("RegimenPlanRecord",           .rekey),
        ("DoseEventRecord",             .destinationWins),
        ("ProgramFactRecord",           .rekey),
        ("WeeklyReadRecord",            .destinationWins),
        ("BodyScanRecord",              .rekeyInPlace),
        ("ChatMessageRecord",           .rekeyInPlace),
        ("JeniMemoryRecord",            .rekeyInPlace),
        ("ConsentGrantRecord",          .refused),
        ("food journal (JSONL)",        .rekey),
        ("food photos (files)",         .rekey),
        ("move.manual.v1",              .deviceScoped),
        ("day.note / day.reflection",   .deviceScoped),
        ("day.sit / day.dose / band",   .deviceScoped),
        ("deletions.v1.<uid>",          .refused),
    ]

    /// **HOW MANY ROWS STILL ANSWER TO THIS NAME.**
    ///
    /// Every customer-owned local family, counted rather than listed —
    /// the property `40` used to prove the merge was whole, promoted
    /// here so the RETIREMENT can use the same number.
    ///
    /// It exists for two callers and they need the same answer:
    ///   · the handoff test, which asserts `footprint(source) == 0`
    ///     and `footprint(destination) > 0` after a carry, because a
    ///     test that only checks the first cannot tell MOVED from
    ///     VANISHED;
    ///   · `SourceRetirementSafety`, which must never delete a server
    ///     account whose rows this device does not hold (§41 [CORR] on
    ///     `40` §3.4).
    static func footprint(of uid: String, in context: ModelContext) -> Int {
        guard !uid.isEmpty else { return 0 }
        let owner = uid
        func n<T: PersistentModel>(_ d: FetchDescriptor<T>) -> Int {
            (try? context.fetchCount(d)) ?? 0
        }
        var total = 0
        total += n(FetchDescriptor<UserRecord>(predicate: #Predicate { $0.id == owner }))
        total += n(FetchDescriptor<SessionLogRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<SessionRatingRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<DayProgressRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<WeightLogRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<ExerciseCalibrationRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<ProgramPlanRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<ProgramDayCheckRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<ObservationRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<RegimenPlanRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<DoseEventRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<ProgramFactRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<WeeklyReadRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<BodyScanRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<ChatMessageRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<JeniMemoryRecord>(predicate: #Predicate { $0.userId == owner }))
        total += n(FetchDescriptor<ConsentGrantRecord>(predicate: #Predicate { $0.userId == owner }))
        total += FoodLogPersister.allEntries(userId: owner).count
        return total
    }
}
