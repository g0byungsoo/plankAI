import Foundation
import SwiftData

// MARK: - CBTCurriculumService
//
// App-wide front door for the new manifest-driven JeniMethod CBT
// curriculum. Loads the bundled `LessonManifest` lazily on first use
// (decode takes ~50ms on A14; caller can preload on a background queue
// at app launch if needed) and computes the per-user schedule from the
// active `ProgramPlanRecord.totalDays` + onboarding cohort flags.
//
// This is a *pure-read* layer — no SwiftData inserts here. Persistence
// of lesson opens/completes goes through `JeniMethodState` (existing
// UserDefaults gate) for the v1 wiring; a follow-up commit can add
// `LessonProgressRecord` SwiftData inserts once the container migration
// is validated.

@MainActor
public final class CBTCurriculumService {

    public static let shared = CBTCurriculumService()

    private var cachedManifest: LessonManifest?
    private var cachedScheduleKey: ScheduleKey?
    private var cachedSchedule: [ScheduledLesson] = []

    private init() {}

    // MARK: - Manifest

    /// Returns the bundled manifest, loading it on first call.
    public func manifest() -> LessonManifest? {
        if let m = cachedManifest { return m }
        do {
            let m = try LessonManifest.loadBundled()
            cachedManifest = m
            return m
        } catch {
            #if DEBUG
            print("[CBTCurriculumService] failed to load manifest: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Schedule

    /// Resolve the schedule for a given `(totalDays, cohort)` pair.
    /// Memoized — repeated calls with the same key return the cached
    /// result. Returns an empty array if the manifest isn't bundled.
    public func schedule(totalDays: Int,
                         cohort: CohortFlags) -> [ScheduledLesson] {
        guard let m = manifest() else { return [] }
        let key = ScheduleKey(totalDays: totalDays, cohort: cohort, version: m.version)
        if cachedScheduleKey == key { return cachedSchedule }
        let out = CBTCurriculumScheduler.schedule(
            totalDays: totalDays, cohort: cohort, manifest: m
        ).schedule
        cachedScheduleKey = key
        cachedSchedule = out
        return out
    }

    // MARK: - Today's lesson

    /// Resolve the lesson for a given program day (1-indexed) in the
    /// caller's schedule. Returns the slot + variant pair ready to
    /// hand to `LessonReaderView`, or nil if the day is out of bounds.
    public func lesson(forProgramDay day: Int,
                       totalDays: Int,
                       cohort: CohortFlags) -> ResolvedLessonRef? {
        guard let m = manifest() else { return nil }
        let schedule = self.schedule(totalDays: totalDays, cohort: cohort)
        guard day >= 1, day <= schedule.count else { return nil }
        let scheduled = schedule[day - 1]
        guard let slot = m.slot(byId: scheduled.lessonSlotId) else { return nil }
        let variant: CohortVariant?
        if let cohortKey = scheduled.variantCohort {
            variant = slot.cohortVariants.first { $0.cohort == cohortKey }
        } else {
            variant = nil
        }
        return ResolvedLessonRef(scheduled: scheduled, slot: slot, variant: variant)
    }

    /// Lookup helper for analytics: name of the pillar this scheduled
    /// lesson belongs to (matches manifest.pillar(_:).name).
    public func pillarName(_ pid: PillarId) -> String {
        manifest()?.pillar(pid)?.name ?? pid.debugName
    }

    // MARK: - Cache control

    /// Invalidate the schedule cache. Call when the user re-personalizes
    /// (changes intensity, accepts a new plan, etc.). Cheap, just
    /// drops the memoization.
    public func invalidate() {
        cachedScheduleKey = nil
        cachedSchedule = []
    }
}

// MARK: - ResolvedLessonRef

public struct ResolvedLessonRef: Equatable {
    public let scheduled: ScheduledLesson
    public let slot: LessonSlot
    public let variant: CohortVariant?
}

// MARK: - Schedule key (cache identity)

private struct ScheduleKey: Equatable {
    let totalDays: Int
    let cohort: CohortFlags
    let version: Int
}
