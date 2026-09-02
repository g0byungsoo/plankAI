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
        /// v9 P1 — Body Vision: the guided scan + her record.
        case bodyScan

        var id: String {
            switch self {
            case .lesson: return "lesson"
            case .captureFlow: return "capture"
            case .preRoutine: return "workout"
            case .breathSession: return "breath"
            case .jeniNote: return "jeniNote"
            case .bodyScan: return "bodyScan"
            }
        }
        static func == (lhs: Cover, rhs: Cover) -> Bool { lhs.id == rhs.id }
    }

    enum Sheet: Identifiable, Equatable {
        case logWeight
        case markAsDone(ProgramDayPrescription)
        case profileHub
        case stepsDetail
        /// v8 — her regimen (shot day, remove; since v24 the
        /// settings-door home, not the row's module).
        case regimen
        /// v24 — THE DOSE SHEET (the medication row's module: mark
        /// with site memory + rotation, note, skip with a reason,
        /// log a late slot).
        case doseSheet(slotDayKey: String)
        /// v25 E4 — the plate's memory: the one-tap relog rail
        /// ("add it again"), promoted out of its debug harness.
        case recentMeals
        /// E8.2 — what jeni has told you, from the method door on a
        /// silent day: the tile lands on her kept notes instead of a
        /// cover that flashes open and dismisses itself.
        case methodTold

        var id: String {
            switch self {
            case .logWeight: return "logWeight"
            case .markAsDone: return "markAsDone"
            case .profileHub: return "profileHub"
            case .stepsDetail: return "stepsDetail"
            case .regimen: return "regimen"
            case .doseSheet(let key): return "doseSheet-\(key)"
            case .recentMeals: return "recentMeals"
            case .methodTold: return "methodTold"
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


    /// v25 E3 ONE JENI — words jeni handed the capture flow
    /// ("i had a chicken burrito"). Set immediately before presenting
    /// the capture cover; cleared on dismiss so a later camera tap can
    /// never inherit an old sentence.
    var describePrefill: String?
    /// v25 E7 SAY IT — true when `describePrefill` holds words the USER
    /// typed into the capture surface and sent with her own return key.
    /// The flow then goes straight to the estimate. False (jeni's own
    /// prefill, E3) opens the field and waits for her.
    var describeWasSpoken = false

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
        describePrefill = nil
        describeWasSpoken = false
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
        case .medication:
            // v24 — the row opens THE DOSE SHEET: everything known
            // is already filled; she confirms the site (rotation
            // pre-ringed), marks it, done. The regimen home moved
            // to settings.
            // v25 E2 — when the row is the OPEN LATE SLOT (not a
            // dose day), the sheet opens at THAT slot: the late
            // face + label facts, never a blind today.
            present(sheet: .doseSheet(slotDayKey: currentDoseSlotKey()))
        case .bodyScan:
            present(cover: .bodyScan)
        }
    }

    func longPress(_ beat: ProgramDayPrescription, snapshot: TodaySnapshot?) {
        // v9 P1 — the scan invitation is never markable: a kept scan
        // is its completion, and its itemKey must never reach
        // program_day_checks (the SQL CHECK doesn't know it).
        if case .bodyScan = beat { return }
        // p65 — the `isProgressRow` guard died with the founder's
        // completion walk: the walking ask and water are manually
        // completable now (her word completes the ACTION; the sensor
        // keeps the NUMBER), so the override law — long-press = the
        // mark sheet, done = unmark — holds for every markable row.
        // A measured steps crossing stays un-unmarkable: unmarking
        // writes `empty`, and BeatCompletion's live-count authority
        // re-renders it done (a sensor reading cannot be taken back).
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

    // E8.2 — `lessonTitle` deleted: it resolved subtitles out of the
    // RETIRED 84-lesson manifest, so the method tile kept advertising
    // curriculum titles no note would ever render. The method's status
    // line now reads MethodLedger (what was actually told), in
    // HomeView.methodStatus().

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
        // p54 — and tonight's plate-review push dies with it, for the
        // same reason: the day is no longer blank, so "a soft look
        // back" would be noise about a record she just wrote.
        if case .snapMeal = beat {
            NotificationOrchestrator.cancelLapseSupport()
            RetentionNotifications.cancelEveningPlateReview()
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
                lead: "one more step",
                text: "talk it through with jeni",
                italic: ["jeni"],
                route: nil,
                chatSeed: "they just finished a method lesson. help them apply that one reframe to how today actually went. one concrete, kind next move, no lecture."
            )
        case .workout:
            chainSuggestion = ChainSuggestion(
                lead: "kept",
                text: "protein within the hour keeps muscle",
                italic: ["protein"],
                route: .snap
            )
        case .snapMeal:
            let d = UserDefaults.standard
            let hour = AppClock.hourOfDay
            if hour >= 15 {
                chainSuggestion = ChainSuggestion(
                    lead: "seen",
                    text: "want a dinner idea from jeni?",
                    italic: ["dinner idea"],
                    route: nil,
                    chatSeed: "they just logged a plate. suggest one gentle dinner idea that closes their protein gap; keep it one pan."
                )
            }
            _ = d
        case .weighIn:
            chainSuggestion = ChainSuggestion(
                lead: "logged",
                text: "see your trend line",
                italic: ["trend line"],
                route: .trend
            )
        default:
            break
        }
    }

    /// v25 E2 — the slot a medication tap/mark means TODAY: a due
    /// dose day is today's slot; otherwise an open late slot (the
    /// "log it late" door) IS the slot. Derived here at the
    /// chokepoint so every caller (row tap, quick-mark, mark-as-done
    /// sheet) converges without threading the snapshot.
    func currentDoseSlotKey() -> String {
        guard let modelContext, !userId.isEmpty,
              let plan = RegimenService.activeMedicationPlan(
                  userId: userId, in: modelContext
              ) else { return TodayStateService.dayKey() }
        let facts = RegimenService.facts(for: plan)
        // p55 — one event fetch decides BOTH questions. The bare-grid
        // isDoseDay here could resolve a mark onto a day that is not a
        // slot in her re-anchored chain — a record written to a
        // phantom day, skipping the genuinely open late slot below.
        let events = DoseEventStore.slotEvents(
            userId: userId, limit: 30, in: modelContext
        )
        if MedicationScheduleEngine.isDoseDay(.now, facts: facts, events: events) {
            return TodayStateService.dayKey()
        }
        if let open = MedicationScheduleEngine.openLateSlot(
            now: .now, facts: facts, events: events
        ) {
            return MedicationScheduleEngine.dayKey(for: open)
        }
        return TodayStateService.dayKey()
    }

    func mark(_ beat: ProgramDayPrescription, state: ProgramService.ChecklistState) {
        guard let modelContext, !userId.isEmpty else { return }
        // v24 — the medication mark flows through THE chokepoint
        // (MedicationLog owns all four truths: dose event, chart
        // observation, legacy key, today's check + reminder
        // retirement). The v11 dual-write that lived here moved in;
        // the v10 lesson stands: every path converges here.
        if case .medication = beat {
            // v25 E2 — a quick-mark on the late row resolves THE
            // SLOT (takenAt stays now — a late log is honest).
            MedicationLog.resolve(
                state == .complete
                    ? .taken(site: nil, note: nil, at: .now)
                    : .unmark,
                slotDayKey: currentDoseSlotKey(),
                source: .checklist,
                userId: userId,
                in: modelContext
            )
            onMutation()
            return
        }
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
            // Same-session push; the launch retry sweep is the safety net
            // (record inits pendingUpsert=true).
            Task { await AppSync.shared.upsertSessionRating(record) }
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
