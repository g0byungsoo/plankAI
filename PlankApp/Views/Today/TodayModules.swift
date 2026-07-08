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
        /// THE NOTE — jeni's full reading as a received moment.
        case jeniNote

        var id: String {
            switch self {
            case .lesson: return "lesson"
            case .captureFlow: return "capture"
            case .preRoutine: return "workout"
            case .breathSession: return "breath"
            case .jeniNote: return "jeniNote"
            }
        }
        static func == (lhs: Cover, rhs: Cover) -> Bool { lhs.id == rhs.id }
    }

    enum Sheet: Identifiable, Equatable {
        case logWeight
        case markAsDone(ProgramDayPrescription)
        case profileHub
        case stepsDetail

        var id: String {
            switch self {
            case .logWeight: return "logWeight"
            case .markAsDone: return "markAsDone"
            case .profileHub: return "profileHub"
            case .stepsDetail: return "stepsDetail"
            }
        }
    }

    // v4: the her-days sheet family (dayPeek / dayLock / dayReview /
    // herDays + the stripSheet router) died with the journey rebuild —
    // past days live in becoming's ledger now (docs/app_v4/02_JOURNEY).

    enum RoutineStep { case pre, session }

    var activeCover: Cover?
    var activeSheet: Sheet?
    var routineStep: RoutineStep = .pre

    /// v2.4 — the read-becomes-a-rep chain: set when a lesson
    /// completes, rendered by TodayView as a one-shot "next:" line.
    struct ChainSuggestion: Equatable {
        let lead: String
        let text: String
        let italic: [String]
        /// Either a module route or a jeni conversation seed.
        let route: AppRouter.Route?
        var chatSeed: String? = nil
    }
    var chainSuggestion: ChainSuggestion?

    /// v2.4 — the five-minute floor. Remembers today's workout
    /// parameters so the brief's "make it 5 minutes" door can
    /// regenerate at the floor without re-deriving context.
    @ObservationIgnored private var lastWorkoutTier: IntensityTier = .medium
    @ObservationIgnored private var lastWorkoutBodyFocus: String?

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
            present(sheet: .stepsDetail)
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
        guard snapshot?.plan != nil else { return }
        JeniMethodState.markEnrolled()
        // v3: the host resolves fresh via MethodResolver at present
        // time; the cover payload is vestigial (kept for enum id
        // stability until the next schema-touching pass).
        present(cover: .lesson(programDay: 0, totalDays: 0))
    }

    /// Today's lesson title for the beat subtitle ("food noise, named").
    func lessonTitle(snapshot: TodaySnapshot?) -> String? {
        guard let snapshot, snapshot.plan != nil else { return nil }
        if cachedLessonTitleDay == snapshot.programDay { return cachedLessonTitle }
        let resolution = MethodResolver.resolve(
            plan: snapshot.plan, programDay: snapshot.programDay
        )
        cachedLessonTitleDay = snapshot.programDay
        cachedLessonTitle = resolution.map {
            MethodResolver.cleanTitle($0.ref.slot.workingTitle)
        }
        return cachedLessonTitle
    }

    // MARK: - Workout generation (mirrors PlanView.openWorkout)

    /// The floor: regenerate today's session as THE GENTLE FIVE. No
    /// guilt gradient — the smallest session she'll finish beats the
    /// optimal one she'll skip (26% completion is the evidence). v5.1:
    /// the floor is gentle now, not just short — a tired user asking
    /// for less shouldn't get the same intensity, compressed.
    func shrinkWorkoutToFloor() {
        Haptics.soft()
        openWorkout(
            tier: lastWorkoutTier, minutes: 5,
            bodyFocus: lastWorkoutBodyFocus, gentle: true
        )
    }

    private func openWorkout(
        tier: IntensityTier, minutes: Int, bodyFocus: String?,
        gentle: Bool = false
    ) {
        lastWorkoutTier = tier
        lastWorkoutBodyFocus = bodyFocus
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
            intensityOffset: d.integer(forKey: "workoutLevel") + d.integer(forKey: "todaysEnergy"),
            gentle: gentle
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
        // v3 phase-7: a landed plate cancels tonight's lapse-support
        // ping — the moment it exists, the ping's premise doesn't.
        if case .snapMeal = beat {
            NotificationOrchestrator.cancelLapseSupport()
        }
        // v2.5: everything chains — the next right action, one-shot
        // and quiet. Lessons become reps; workouts hand to protein;
        // plates hand to jeni; weigh-ins hand to the trend.
        switch beat {
        case .lesson:
            // Breath used to be the method's follow-on rep — but it's a
            // permanent rhythm row now, so that chain just pointed at a
            // row already on screen (founder: redundant). Hand the read
            // to jeni instead: apply the one reframe to how today
            // actually went.
            chainSuggestion = ChainSuggestion(
                lead: "put it to work",
                text: "talk it through with jeni",
                italic: ["jeni"],
                route: nil,
                chatSeed: "she just finished a method lesson. help her apply that one reframe to how today actually went — one concrete, kind next move, no lecture."
            )
        case .workout:
            chainSuggestion = ChainSuggestion(
                lead: "kept",
                text: "protein soon keeps the build",
                italic: ["protein"],
                route: .snap
            )
        case .snapMeal:
            let d = UserDefaults.standard
            let hour = Calendar.current.component(.hour, from: .now)
            if hour >= 15 {
                chainSuggestion = ChainSuggestion(
                    lead: "seen",
                    text: "want a dinner idea from jeni?",
                    italic: ["dinner idea"],
                    route: nil,
                    chatSeed: "she just logged a plate. suggest one gentle dinner idea that closes her protein gap; keep it one pan."
                )
            }
            _ = d
        case .weighIn:
            chainSuggestion = ChainSuggestion(
                lead: "logged",
                text: "the trend line does the thinking",
                italic: ["trend line"],
                route: .trend
            )
        default:
            break
        }
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
            // v3: presence flows through markChecklistItem (markAuto
            // fires .workout right after this save). The old direct
            // recordShownUpDay(count:) here made workouts the ONLY
            // action that counted as "showing up."
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
