import SwiftUI
import SwiftData
import PlankFood
import PlankSync
import Auth

// MARK: - TodayModules
//
// App v2. The module launcher behind TodayView's beats — the same
// module views and the same completion writes PlanView used, behind
// one router. Tap always enters the module (completed rows re-open
// for re-reads / extra logs); long-press is the manual override.

@MainActor
@Observable
final class TodayModuleState {

    enum Cover: Identifiable, Equatable {
        case lesson(programDay: Int, totalDays: Int)
        case captureFlow
        case preRoutine(WorkoutPreset)
        case breathSession

        var id: String {
            switch self {
            case .lesson: return "lesson"
            case .captureFlow: return "capture"
            case .preRoutine: return "workout"
            case .breathSession: return "breath"
            }
        }
        static func == (lhs: Cover, rhs: Cover) -> Bool { lhs.id == rhs.id }
    }

    enum Sheet: Identifiable, Equatable {
        case logWeight
        case markAsDone(ProgramDayPrescription)
        case profileHub

        var id: String {
            switch self {
            case .logWeight: return "logWeight"
            case .markAsDone: return "markAsDone"
            case .profileHub: return "profileHub"
            }
        }
    }

    enum RoutineStep { case pre, session }

    var activeCover: Cover?
    var activeSheet: Sheet?
    var routineStep: RoutineStep = .pre

    // Injected by the host modifier on appear.
    @ObservationIgnored var modelContext: ModelContext?
    @ObservationIgnored var userId: String = ""
    @ObservationIgnored var onMutation: () -> Void = {}

    @ObservationIgnored private var cachedLessonTitleDay: Int = -1
    @ObservationIgnored private var cachedLessonTitle: String?

    // MARK: - Present / dismiss (instant materialize, module owns motion)

    func present(cover: Cover) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { activeCover = cover }
    }

    func present(sheet: Sheet) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { activeSheet = sheet }
    }

    func dismissCover() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { activeCover = nil }
        routineStep = .pre
        onMutation()
    }

    func dismissSheet() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { activeSheet = nil }
        onMutation()
    }

    // MARK: - Beat routing

    func open(_ beat: ProgramDayPrescription, snapshot: TodaySnapshot?) {
        Haptics.light()
        switch beat {
        case .lesson:
            openLesson(snapshot: snapshot)
        case .snapMeal:
            present(cover: .captureFlow)
        case .workout(let tier, let minutes, let bodyFocus):
            openWorkout(tier: tier, minutes: minutes, bodyFocus: bodyFocus)
        case .steps:
            return   // auto-tracks; silent tap (detail sheet is v2.1)
        case .breath:
            present(cover: .breathSession)
        case .weighIn:
            present(sheet: .logWeight)
        case .plank, .water, .measurements:
            present(sheet: .markAsDone(beat))
        }
    }

    func longPress(_ beat: ProgramDayPrescription, snapshot: TodaySnapshot?) {
        guard !beat.isProgressRow else { return }
        Haptics.medium()
        let raw = snapshot?.checkStates[beat.itemKey] ?? "empty"
        if raw == "complete" || raw == "autoCompleted" {
            mark(beat, state: .empty)
        } else {
            present(sheet: .markAsDone(beat))
        }
    }

    func openLesson(snapshot: TodaySnapshot?) {
        guard let snapshot, let plan = snapshot.plan else { return }
        JeniMethodState.markEnrolled()
        let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium
        let cadence = IntensityProfile.from(tier: tier).lessonCadence
        // Cadence-aware ordinal (04_DAILY_PROGRAM): soft-tier users
        // sweep the full curriculum across their lesson-days instead
        // of skipping 5 of every 7 slots.
        let ordinal = PrescriptionEngineV2.lessonOrdinal(
            programDay: snapshot.programDay, cadence: cadence
        ) ?? snapshot.programDay
        let lessonTotal = PrescriptionEngineV2.totalLessonDays(
            totalDays: plan.totalDays, cadence: cadence
        )
        present(cover: .lesson(programDay: ordinal, totalDays: lessonTotal))
    }

    /// Today's lesson title for the beat subtitle ("food noise, named").
    func lessonTitle(snapshot: TodaySnapshot?) -> String? {
        guard let snapshot, let plan = snapshot.plan else { return nil }
        if cachedLessonTitleDay == snapshot.programDay { return cachedLessonTitle }
        let tier = IntensityTier(rawValue: plan.intensityTier) ?? .medium
        let cadence = IntensityProfile.from(tier: tier).lessonCadence
        guard let ordinal = PrescriptionEngineV2.lessonOrdinal(
            programDay: snapshot.programDay, cadence: cadence
        ) else { return nil }
        let lessonTotal = PrescriptionEngineV2.totalLessonDays(
            totalDays: plan.totalDays, cadence: cadence
        )
        let resolved = CBTCurriculumService.shared.lesson(
            forProgramDay: ordinal,
            totalDays: lessonTotal,
            cohort: CohortFlags.fromAppStorage()
        )
        cachedLessonTitleDay = snapshot.programDay
        cachedLessonTitle = resolved.map {
            $0.slot.workingTitle
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .replacingOccurrences(of: "*", with: "")
                .lowercased()
        }
        return cachedLessonTitle
    }

    // MARK: - Workout generation (mirrors PlanView.openWorkout)

    private func openWorkout(tier: IntensityTier, minutes: Int, bodyFocus: String?) {
        let d = UserDefaults.standard
        let focusToken = bodyFocus ?? (d.string(forKey: "bodyFocus") ?? "fullBody")
        let focus: [BodyFocus] = BodyFocus(rawValue: focusToken).map { [$0] } ?? [.fullBody]

        let recentIds: [[String]] = recentSessionLogs().prefix(7).map { [$0.exerciseType] }

        let startingTierInt: Int = {
            switch tier {
            case .soft: return 1
            case .medium: return 2
            case .hard: return 3
            }
        }()

        let input = WorkoutGenerator.Input(
            bodyFocus: focus,
            lengthMinutes: minutes,
            recentSessionExerciseIds: recentIds,
            recentRatings: [],
            startingTier: startingTierInt,
            intensityOffset: d.integer(forKey: "workoutLevel") + d.integer(forKey: "todaysEnergy")
        )
        let workout = WorkoutGenerator.generate(from: input)
        present(cover: .preRoutine(workout))
    }

    private func recentSessionLogs() -> [SessionLogRecord] {
        guard let modelContext, !userId.isEmpty else { return [] }
        let uid = userId
        var descriptor = FetchDescriptor<SessionLogRecord>(
            predicate: #Predicate { $0.userId == uid },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 7
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Completion writes (the same records PlanView wrote)

    func markAuto(_ beat: ProgramDayPrescription) {
        mark(beat, state: .autoCompleted)
    }

    func mark(_ beat: ProgramDayPrescription, state: ProgramService.ChecklistState) {
        guard let modelContext, !userId.isEmpty else { return }
        if let record = ProgramService.shared.markChecklistItem(
            prescription: beat,
            state: state,
            userId: userId,
            in: modelContext
        ) {
            Task { await AppSync.shared.upsertProgramDayCheck(record) }
        }
        onMutation()
    }

    // MARK: - Workout save (mirrors PlanView.saveRoutineSession)

    func saveRoutineSession(
        workout: WorkoutPreset,
        results: [ExerciseResultEntry],
        duration: TimeInterval,
        rating: (stars: Int, tags: [String])?
    ) {
        guard let modelContext else { return }
        let uid = AppSync.shared.currentUserId ?? userId
        let resultsData = try? JSONEncoder().encode(results)
        let session = SessionLogRecord(
            userId: uid, exerciseType: "routine", holdTime: 0, targetTime: 0,
            qualityScore: 0, sessionType: "routine",
            presetId: workout.id, exerciseResults: resultsData,
            totalDuration: duration
        )
        modelContext.insert(session)
        if let rating {
            let record = SessionRatingRecord(
                userId: uid,
                sessionLogId: session.id,
                rating: rating.stars,
                tags: rating.tags
            )
            modelContext.insert(record)
        }
        let existingLogs = recentSessionLogs()
        let derivedDay = EngagementDayCalculator.programDayForNewSession(
            existingLogs: existingLogs,
            newSessionCompletedAt: session.completedAt
        )
        let progress = fetchTodayProgress(uid: uid)
        let progressRecord: DayProgressRecord
        if let progress {
            progress.primarySessionId = session.id
            var ids = progress.sessionLogIds ?? []
            ids.append(session.id)
            progress.sessionLogIds = ids
            progress.programDay = derivedDay
            progress.updatedAt = .now
            progressRecord = progress
        } else {
            let fresh = DayProgressRecord(
                userId: uid, programDay: derivedDay, primarySessionId: session.id,
                primaryQualityScore: 0, primaryHoldTime: 0
            )
            fresh.sessionLogIds = [session.id]
            modelContext.insert(fresh)
            progressRecord = fresh
            RetentionNotifications.recordShownUpDay(count: derivedDay)
        }
        try? modelContext.save()
        RetentionNotifications.markSessionCompleted()
        Task {
            await AppSync.shared.upsertSessionLog(session)
            await AppSync.shared.upsertDayProgress(progressRecord)
        }
    }

    private func fetchTodayProgress(uid: String) -> DayProgressRecord? {
        guard let modelContext else { return nil }
        let descriptor = FetchDescriptor<DayProgressRecord>(
            predicate: #Predicate { $0.userId == uid }
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let cal = Calendar.current
        return all.first { cal.isDate($0.date, inSameDayAs: .now) }
    }

    // MARK: - Weight (mirrors PlanView.persistWeight)

    func persistWeight(kg: Double) {
        guard let modelContext, !userId.isEmpty else { return }
        // The one shared write path (chat's log_weight tool uses it too).
        WeightLogWriter.persist(kg: kg, userId: userId, in: modelContext)
        onMutation()
    }
}
