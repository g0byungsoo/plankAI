import Foundation
import SwiftData

// MARK: - ProgramPlanMerge
//
// THE RECOVERY CONTRACT, in one place.
//
// ## Why this exists
//
// A paying customer's `program_plans` row was corrupt: `start = 124 lb`,
// `goal = 124 lb`, `210 days`. A goal equal to the start weight is not a
// weight-loss plan, and every energy path downstream read it as
// maintenance. Support repaired the row in the database —
// `goal = 110 lb`, `119 days`, `goal_date = start + 119` — and **her
// phone went on showing 124**.
//
// It was not a propagation delay. `applyHydratedProgramPlans` was
// insert-only: a row whose id already existed locally was skipped, with
// the comment *"data fields stay untouched (insert-only semantics)"*.
// Insert-only is the right rule for append-only history (a weigh-in, a
// session, a dose event: the past does not change). A program plan is
// not history. It is a MUTABLE STATEMENT ABOUT HER BODY, and it has to
// be repairable from the only place a human on the support side can
// reach.
//
// ## What this is NOT
//
// It is **not** "server always wins". That would be a second bug: she
// may have edited her goal on a plane, and the row on the server is only
// as fresh as the last successful push.
//
// ## The rule, and why the existing schema is enough
//
// `program_plans` carries no trustworthy `updated_at` — the upsert has
// never written one and the hydrate has never read one — so there is no
// timestamp to arbitrate with, and inventing one would be inventing a
// fact. It does not need one, because `pendingUpsert` already carries
// exactly the information required:
//
//   * `pendingUpsert == true`  — this device holds a local write that has
//     not landed. The device is the newer author. **Keep local**; the
//     retry will make the server agree.
//   * `pendingUpsert == false` — every local write this device has ever
//     made has been acknowledged by the server (the flag is cleared only
//     inside the success branch of `upsertProgramPlan`). So if the server
//     row now DISAGREES, the change came from somewhere newer than this
//     device: support, or another device. **Adopt the server's facts.**
//
// The flag is set by every local mutation and cleared only by a
// successful push, which is precisely the "has this device said anything
// the server has not heard" question. No new column, no new timestamp.
//
// ## The field taxonomy
//
// | field | class | on a clean local row |
// |---|---|---|
// | `id`, `userId` | IMMUTABLE IDENTITY | case-normalised only |
// | `startDate` | IMMUTABLE IDENTITY — the day anchor | **kept local** |
// | `createdAt` | IMMUTABLE IDENTITY | kept local |
// | `goalWeightKg` | SERVER-REPAIRABLE USER FACT | adopted |
// | `currentWeightKg` (start weight) | SERVER-REPAIRABLE USER FACT | adopted |
// | `intensityTier` (pace) | SERVER-REPAIRABLE USER FACT | adopted |
// | `totalDays`, `goalDate` | DERIVED from the above | adopted |
// | `phase`, `archivedAt`, `completedAt` | LIFECYCLE | adopted |
// | `parentPlanId` | plan chain | adopted |
//
// `startDate` is deliberately immutable here. It is the anchor
// `programDay` is derived from; moving it moves what day she is on, and
// the documented incident this codebase already carries (`AppSync:520` —
// a re-enroll minting `startDate = .now`) is what that costs. A row
// reached by id IS the same enrollment, so its start date is not in
// dispute; if the two ever disagree, the day she has been living in wins.
//
// **A nil server value is never adopted** — for USER FACTS. A legacy
// row whose `goal_weight_kg` is NULL must not delete a goal the device
// holds — that would be the same "lose the goal" defect arriving from
// the other direction. The two LIFECYCLE timestamps are the deliberate
// exception (pass 51 makes it explicit instead of implied): a truly
// NULL `archived_at`/`completed_at` IS adopted, because un-archiving a
// wrongly-archived plan is a legitimate support repair and NULL is its
// only vocabulary. What must never happen — and did, until pass 51 —
// is a REAL timestamp parsing to nil (server `now()` writes carry
// microseconds) and riding that exception into a silent un-archive.

public enum ProgramPlanMerge {

    /// Fold a server row into a local plan. Returns true when anything
    /// changed, so callers can log/save conditionally.
    ///
    /// Pure over (row, record): no container, no network, no clock.
    @discardableResult
    @MainActor
    public static func apply(
        _ row: ProgramPlanHydrateRow, to plan: ProgramPlanRecord
    ) -> Bool {
        // The device has something to say that the server has not heard.
        // Her unsent edit is the newest fact there is.
        guard !plan.pendingUpsert else { return false }

        var changed = false

        func adopt<T: Equatable>(_ new: T, _ keyPath: ReferenceWritableKeyPath<ProgramPlanRecord, T>) {
            guard plan[keyPath: keyPath] != new else { return }
            plan[keyPath: keyPath] = new
            changed = true
        }

        // USER FACTS — the ones a support repair exists to fix. Only a
        // PRESENT server value is adopted; an absent one means the server
        // never learned it, not that she gave it up.
        if let goal = row.goal_weight_kg, goal > 0 {
            adopt(Optional(goal), \.goalWeightKg)
        }
        if let start = row.current_weight_kg, start > 0 {
            adopt(Optional(start), \.currentWeightKg)
        }
        if !row.intensity_tier.isEmpty {
            adopt(row.intensity_tier, \.intensityTier)
        }

        // DERIVED — the horizon that follows from the facts above. A
        // repaired goal with the old 210-day window would still publish
        // the old rate, so these travel together or not at all.
        if row.total_days > 0 {
            adopt(row.total_days, \.totalDays)
        }
        if let goalDate = PlanWireDate.localDate(fromWire: row.goal_date) {
            adopt(goalDate, \.goalDate)
        }

        // LIFECYCLE — "is this the plan she is living in". Adopting these
        // is what lets a support-side archive of a duplicate plan actually
        // reach the device instead of being re-imported every launch.
        if !row.phase.isEmpty {
            adopt(row.phase, \.phase)
        }
        // Pass 51 — WireTimestamp, not a bare formatter: server-side
        // writes (`archived_at = now()` — the pass-43 production
        // repair's own shape) carry microseconds, which the plain
        // formatter parsed to NIL, and the nil was ADOPTED — silently
        // un-archiving the very plan support had archived, on every
        // hydrate. A nil is adopted only when the column is truly
        // NULL (the deliberate support un-archive lever), never
        // because a real timestamp failed to parse.
        adopt(WireTimestamp.parse(row.archived_at), \.archivedAt)
        adopt(WireTimestamp.parse(row.completed_at), \.completedAt)
        if let parent = row.parent_plan_id?.uppercased() {
            adopt(Optional(parent), \.parentPlanId)
        }

        // NOT adopted, on purpose: startDate (the day anchor), createdAt,
        // id, userId. See the table in this file's header.

        if changed {
            plan.updatedAt = .now
            // The row now equals the server's. It must NOT be queued for
            // push — a whole-row upsert of an adopted row is a no-op at
            // best and, if the server moved again in between, a
            // resurrection. Adoption is a READ.
            plan.pendingUpsert = false
        }
        return changed
    }
}
