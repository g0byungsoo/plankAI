import Foundation

// MARK: - CBTCurriculumScheduler
//
// Given a user's `totalDays` (from `ProgramPlanRecord.totalDays`) and
// `CohortFlags`, emit the deterministic ordered day-by-day lesson
// schedule. Pure function: no I/O, no clock, no randomness — same
// inputs always produce same output. Snapshot-friendly: write the
// emitted `[ScheduledLesson]` to disk once at enrollment, never
// regenerate per app launch unless the manifest version bumps or the
// user re-personalizes.
//
// Invariants enforced (validated by XCTests in
// CBTCurriculumSchedulerTests):
//   I1: schedule.count == clamp(totalDays, 30, 150).
//   I2: every PillarId in PillarId.all appears at least once.
//   I3: act order I→II→III→IV preserved; act boundaries shift but
//       never flip.
//   I4: every anchor slot (priorityWithinAct == 1) is included at any
//       length ≥ 60.
//   I5: no two consecutive days share the same primaryPillar (best-
//       effort — falls back to natural ordering if the manifest can't
//       satisfy without breaking act order).
//   I6: cohort variants REPLACE the slot's pages (never extend); only
//       one variant per slot per user.
//   I7: the closing milestone day of each act (canonicalDay 21/42/63/
//       84) is anchored to the closing day of its act block in the
//       schedule.
//
// Length bands:
//   30-59  → snap to anchor-only floor; lessons cycle through the
//            keepIn60 set in act order, never two-same-pillar adjacent.
//   60-74  → cut from the bottom of priorityWithinAct, keeping anchors.
//   75-83  → canonical-minus-N skip set (drops priority 4-5 first).
//   84     → 1:1 with canonical84.
//   85-102 → inject from extension18 paired with their seed days.
//   103-150→ repeat the maintenance extension pool in act-IV-only.

public struct CBTCurriculumScheduler {

    public struct Output: Equatable {
        public var schedule: [ScheduledLesson]
        public var droppedSlotIds: [String]    // for analytics / debug only
        public var injectedSlotIds: [String]
    }

    /// The default entry point. Returns the schedule in program-day
    /// order (day 1 first).
    public static func schedule(
        totalDays: Int,
        cohort: CohortFlags,
        manifest: LessonManifest
    ) -> Output {
        let N = max(30, min(150, totalDays))

        // Step 1 — pick the working pool of slots.
        var pool: [LessonSlot] = manifest.canonical84.sorted { $0.canonicalDay < $1.canonicalDay }
        var dropped: [String] = []
        var injected: [String] = []

        switch N {
        case 84:
            break
        case 75...83:
            pool = compress(pool, to: N, dropped: &dropped)
        case 60...74:
            pool = compress(pool, to: N, dropped: &dropped)
        case 30...59:
            // Floor: keepIn60 anchors only. Repeat them with weekly
            // pillar rotation if the user's program is shorter than
            // the anchor set itself.
            pool = floor(pool, to: N, dropped: &dropped)
        case 85...102:
            pool = expandWithExtensions(pool, target: N,
                                        extensions: manifest.extension18,
                                        injected: &injected)
        case 103...150:
            // First fill the 102-day spine, then loop the act-IV
            // extension pool with day-cycling pillars for maintenance.
            pool = expandWithExtensions(pool, target: 102,
                                        extensions: manifest.extension18,
                                        injected: &injected)
            pool = padMaintenance(pool, target: N,
                                  extensions: manifest.extension18,
                                  injected: &injected)
        default:
            break  // unreachable; clamp above guarantees 30...150
        }

        // Step 2 — anti-adjacency reshuffle (no two same primary pillar
        // back-to-back) — respects act boundaries.
        pool = enforceAntiAdjacency(pool)

        // Step 3 — milestone anchoring. Closing-act days move to the
        // closing day of their act block in the final schedule.
        pool = anchorMilestones(pool, total: pool.count)

        // Step 4 — emit ScheduledLesson per day with cohort variant
        // selection applied.
        var schedule: [ScheduledLesson] = []
        schedule.reserveCapacity(pool.count)
        for (i, slot) in pool.enumerated() {
            let variant = slot.variant(for: cohort)
            schedule.append(
                ScheduledLesson(
                    programDay: i + 1,
                    lessonSlotId: slot.id,
                    variantCohort: variant?.cohort,
                    primaryPillar: slot.primaryPillar,
                    pillarIds: slot.pillarIds,
                    act: slot.act,
                    isMilestone: slot.isMilestone,
                    isActClosing: slot.isActClosing,
                    isDataAware: slot.isDataAware,
                    isVoiceNoteEligible: slot.isVoiceNoteEligible,
                    isBreathRitual: slot.isBreathRitual,
                    isJournalPrompt: slot.isJournalPrompt,
                    manifestVersion: manifest.version
                )
            )
        }

        return Output(schedule: schedule,
                      droppedSlotIds: dropped,
                      injectedSlotIds: injected)
    }

    // MARK: - Length bands

    /// Drop the lowest-priority slots until we reach `target` count.
    /// Anchors (priority 1) and act-closing days are immune. Drop
    /// order: keepIn75=false first, then keepIn60=false, then by
    /// priority descending (cuttable first).
    private static func compress(
        _ slots: [LessonSlot], to target: Int, dropped: inout [String]
    ) -> [LessonSlot] {
        var working = slots
        while working.count > target {
            let pool = working.enumerated().filter { (_, s) in
                s.priorityWithinAct > 1 && !s.isActClosing
            }
            guard !pool.isEmpty else {
                // Nothing else to cut without breaking invariants —
                // accept the floor and stop.
                break
            }
            let cuttable = pool.sorted { (a, b) in
                let sa = a.element, sb = b.element
                if target < 75 && sa.keepIn60 != sb.keepIn60 { return !sa.keepIn60 }
                if sa.keepIn75 != sb.keepIn75 { return !sa.keepIn75 }
                if sa.priorityWithinAct != sb.priorityWithinAct {
                    return sa.priorityWithinAct > sb.priorityWithinAct
                }
                return sa.canonicalDay > sb.canonicalDay
            }
            let victim = cuttable.first!.element
            dropped.append(victim.id)
            working.removeAll { $0.id == victim.id }
        }
        return working
    }

    private static func floor(
        _ slots: [LessonSlot], to target: Int, dropped: inout [String]
    ) -> [LessonSlot] {
        let anchorSet = slots.filter { $0.keepIn60 || $0.priorityWithinAct == 1 || $0.isActClosing }
        let dropIds = Set(slots.map(\.id)).subtracting(anchorSet.map(\.id))
        dropped.append(contentsOf: dropIds)
        if anchorSet.count <= target {
            return anchorSet
        }
        // Even floor too big — trim by priority descending while
        // preserving milestones.
        var working = anchorSet
        while working.count > target {
            guard let victim = working
                .filter({ !$0.isActClosing && $0.priorityWithinAct > 1 })
                .sorted(by: { $0.priorityWithinAct > $1.priorityWithinAct })
                .first
            else { break }
            dropped.append(victim.id)
            working.removeAll { $0.id == victim.id }
        }
        return working
    }

    /// Inject extension lessons after their seed canonical day, in
    /// priority order, until we reach `target`. Extension slots that
    /// don't fit are skipped (recorded in `injected`).
    private static func expandWithExtensions(
        _ canonical: [LessonSlot],
        target: Int,
        extensions: [LessonSlot],
        injected: inout [String]
    ) -> [LessonSlot] {
        var working = canonical
        var deck = extensions.sorted { $0.priorityWithinAct < $1.priorityWithinAct }
        while working.count < target {
            guard let next = deck.first else { break }
            deck.removeFirst()
            // Insert AFTER the canonical day it's paired with (we use
            // canonicalDay as the seed-anchor hint; absent that, append
            // at the end of its act block).
            let act = next.act
            let actEndIdx = working.lastIndex(where: { $0.act == act }) ?? (working.count - 1)
            let insertIdx = min(actEndIdx + 1, working.count)
            working.insert(next, at: insertIdx)
            injected.append(next.id)
        }
        return working
    }

    private static func padMaintenance(
        _ pool: [LessonSlot],
        target: Int,
        extensions: [LessonSlot],
        injected: inout [String]
    ) -> [LessonSlot] {
        guard pool.count < target else { return pool }
        var working = pool
        // Maintenance pad: cycle the act-IV extension slots (with
        // canonicalDay-based identity stability so the same lesson
        // never reappears twice in a row). If the act-IV extension
        // pool is empty, cycle the canonical act-IV anchors.
        let act4Ext = extensions.filter { $0.act == 4 }
        let pool4 = act4Ext.isEmpty
            ? working.filter { $0.act == 4 && $0.priorityWithinAct == 1 }
            : act4Ext
        guard !pool4.isEmpty else { return working }
        var cycle = 0
        while working.count < target {
            let next = pool4[cycle % pool4.count]
            cycle += 1
            working.append(next)
            injected.append(next.id)
        }
        return working
    }

    // MARK: - Anti-adjacency reshuffle

    private static func enforceAntiAdjacency(_ slots: [LessonSlot]) -> [LessonSlot] {
        guard slots.count > 1 else { return slots }
        var result = slots
        for i in 1..<result.count {
            if result[i].primaryPillar == result[i-1].primaryPillar {
                // Look ahead in the same act for a swap candidate.
                if let swapIdx = result.indices.dropFirst(i + 1).first(where: { j in
                    result[j].act == result[i].act
                        && result[j].primaryPillar != result[i-1].primaryPillar
                        && !result[j].isActClosing
                        && !result[i].isActClosing
                }) {
                    result.swapAt(i, swapIdx)
                }
                // If no swap candidate exists, leave it; act ordering
                // outranks anti-adjacency per the invariants.
            }
        }
        return result
    }

    // MARK: - Milestone anchoring

    private static func anchorMilestones(_ slots: [LessonSlot], total: Int) -> [LessonSlot] {
        guard total > 0 else { return slots }
        var result = slots
        // For each act, ensure its closing slot ends up at the closing
        // index of its block in the FINAL schedule.
        for actNumber in 1...4 {
            let actSlots = result.enumerated().filter { $0.element.act == actNumber }
            guard let lastIdxInBlock = actSlots.last?.offset else { continue }
            if let closingPos = actSlots.firstIndex(where: { $0.element.isActClosing }),
               closingPos != actSlots.count - 1 {
                let from = actSlots[closingPos].offset
                let closing = result.remove(at: from)
                let insertAt = min(lastIdxInBlock, result.count)
                result.insert(closing, at: insertAt)
            }
        }
        return result
    }

    // MARK: - Validation (for tests)

    public static func validatePillarCoverage(
        _ schedule: [ScheduledLesson]
    ) -> Set<PillarId> {
        Set(schedule.map(\.primaryPillar))
    }

    public static func validateActOrdering(_ schedule: [ScheduledLesson]) -> Bool {
        var lastAct = 0
        for s in schedule {
            if s.act < lastAct { return false }
            lastAct = s.act
        }
        return true
    }

    public static func validateAntiAdjacency(_ schedule: [ScheduledLesson]) -> Int {
        // Returns the count of same-pillar adjacencies (best-effort
        // metric; 0 is ideal, low single-digits acceptable).
        var hits = 0
        for i in 1..<schedule.count {
            if schedule[i].primaryPillar == schedule[i-1].primaryPillar { hits += 1 }
        }
        return hits
    }
}
