import SwiftUI
import SwiftData
import PlankSync
import PlankFood

// MARK: - PlanView (v3 — UX redesign 2026-06-09 evening)
//
// v1.1 program pivot. The "today" tab content for program-enrolled
// users. v3 drops the 52pt italic-Fraunces hero entirely — the
// program structure (strip + checklist) becomes the screen's first
// read, and the JeniFit voice signature relocates to two quieter
// places below the fold (strip center marker + micro-caption).
//
// Layout (UX spec §v3.7):
//   24pt → eyebrow "day N of totalDays"
//   18pt → ProgramDayStrip (42pt cells, today pinned center, snap-back)
//    4pt → strip's own center marker "── today ──"
//   16pt → optional scrapbook pill "*viewing* day 8 ×"
//   22pt → white checklist card
//   24pt → PlanViewMicroCaption (italic punch word)
//   60pt → tab bar clearance
//
// Scrapbook mode (founder picked Phase 1 2026-06-09):
//   Tapping a past day on the strip swaps the checklist to that
//   day's snapshot. Strip auto-centers on the viewing day. Eyebrow
//   reflects the viewing day. Pill appears under the strip; tap to
//   return to today.
//
// Lock affordance: tapping a future cell presents ProgramLockSheet.

struct PlanView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var userId: String = ""

    // AppStorage fields needed to construct module inputs (mirrors
    // HomeView's pattern). Read-only here — PlanView never mutates.
    @AppStorage("bodyFocus") private var bodyFocusValue: String = "fullBody"
    @AppStorage("sessionLengthPref") private var sessionLengthPref: Int = 10
    @AppStorage("userExperience") private var userExperience: String = "beginner"
    @AppStorage("userBaselineSeconds") private var userBaselineSeconds: Int = 0
    @AppStorage("activityLevel") private var activityLevel: String = "lightly_active"
    @AppStorage("ageRange") private var ageRange: String = "25-34"
    @AppStorage("workoutLevel") private var workoutLevel: Int = 0
    @AppStorage("todaysEnergy") private var todaysEnergy: Int = 0
    @AppStorage("onboardingCuisinePreference") private var cuisineProfileCSV: String = ""
    @State private var schedule: ProgramScheduleCalculator.Result?
    @State private var profile: IntensityProfile = .medium
    @State private var todayPrescriptions: [ProgramDayPrescription] = []
    @State private var checkStateByKey: [String: ProgramService.ChecklistState] = [:]
    @State private var completionByDay: [Int: Int] = [:]
    @State private var animateIn: Bool = false

    // Scrapbook mode: nil = today; Int = viewing snapshot of past day.
    @State private var viewingDay: Int? = nil

    // Single-router pattern for modal presentations. Stacking 5+
    // .fullScreenCover and 3+ .sheet modifiers on the same view
    // is a known SwiftUI failure mode — only one of each type
    // reliably fires, the rest get silently shadowed. Two enum
    // routers (one fullScreenCover + one sheet) keep dispatch
    // unambiguous. Founder QA 2026-06-09: "long-pressing, press
    // to open module are[n't] working" — root cause was the
    // multi-modifier collision, not the gestures themselves.
    @State private var activeCover: PlanCover? = nil
    @State private var activeSheet: PlanSheet? = nil

    enum PlanCover: Identifiable {
        case lesson(LessonID)
        case captureFlow
        case preRoutine(WorkoutPreset)
        case breathSession
        case chapterComplete

        var id: String {
            switch self {
            case .lesson(let id): return "lesson-\(id.rawValue)"
            case .captureFlow:    return "captureFlow"
            case .preRoutine:     return "preRoutine"
            case .breathSession:  return "breathSession"
            case .chapterComplete: return "chapterComplete"
            }
        }
    }

    enum PlanSheet: Identifiable {
        case lock(day: Int)
        case markAsDone(ProgramDayPrescription)
        case logWeight
        case profileHub   // v6 settings entry via ellipsis on eyebrow row

        var id: String {
            switch self {
            case .lock(let day): return "lock-\(day)"
            case .markAsDone(let p): return "markAsDone-\(p.itemKey)"
            case .logWeight:     return "logWeight"
            case .profileHub:    return "profileHub"
            }
        }
    }

    /// Latest weight reading for the LogWeightSheet pre-fill.
    @Query(sort: \WeightLogRecord.loggedAt, order: .reverse) private var allWeightLogs: [WeightLogRecord]

    /// Recent session log records — drives the WorkoutGenerator
    /// "avoid recent exercises" param + auto-completion detection.
    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var allSessionLogs: [SessionLogRecord]

    // Live data for snap-meal subtitle (today's calorie total +
    // meal count from FoodLogPersister's in-memory store).
    @State private var todayKcal: Int = 0
    @State private var todayMealsLogged: Int = 0

    // v6 fat-row embed data (simplified from v5 per founder QA)
    @State private var todayProteinG: Int = 0
    @State private var todayCarbsG: Int = 0
    @State private var todayFatG: Int = 0
    @State private var todayStepCount: Int = 0

    /// One-time cleanup: prior buggy "tap = mark complete" code wrote
    /// .complete records for every test tap. Those stale records
    /// persist in SwiftData and make every PlanView open show all
    /// rows already checked, which the founder rightly flagged as
    /// broken: "each row needs to be unchecked as default and once
    /// user completes the module or long press the check, it's shown
    /// as checked." This flag fires the wipe once per install.
    @AppStorage("planChecksMigratedV1") private var planChecksMigratedV1: Bool = false

    var body: some View {
        ZStack {
            // v5: program home gets its own pink-tinted background
            // token. Brand identity over neutral cream cohort default.
            Palette.programBgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 24)
                    eyebrow
                    Spacer().frame(height: 18)
                    dayStrip
                    if viewingDay != nil {
                        Spacer().frame(height: 16)
                        viewingPastPill
                    }
                    Spacer().frame(height: 22)
                    checklistCard
                    Spacer().frame(height: 24)
                    PlanViewMicroCaption(
                        completed: completedRowCount,
                        total: todayPrescriptions.count
                    )
                    .modernEntrance(animateIn, delay: 0.4)
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, Space.lg)
            }
        }
        .onAppear { onAppear() }
        .fullScreenCover(item: $activeCover) { cover in
            coverContent(for: cover)
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    @ViewBuilder
    private func coverContent(for cover: PlanCover) -> some View {
        switch cover {
        case .lesson(let lessonId):
            JeniMethodRitualView(
                lesson: lessonId,
                user: JeniMethodUserContext.fromAppStorage(),
                onComplete: {
                    markAutoCompleted(.lesson(lessonId: String(lessonId.rawValue)))
                    dismissCover()
                },
                onSkip: { _ in dismissCover() }
            )

        case .captureFlow:
            CaptureFlowView(
                userId: userId,
                cuisineProfile: cuisineProfileCSV.isEmpty ? nil : cuisineProfileCSV,
                onDismiss: {
                    dismissCover()
                    refreshTodayFood()
                    if todayKcal > 0 {
                        markAutoCompleted(.snapMeal)
                    }
                }
            )

        case .preRoutine(let workout):
            PreRoutineView(
                workout: workout,
                onStart: {
                    // Phase 1.B: marks complete on tap-Start; Phase 2
                    // wires the full SessionView chain + SessionLogRecord
                    // auto-detection.
                    markAutoCompleted(.workout(tier: .medium, minutes: 0, bodyFocus: nil))
                    dismissCover()
                },
                onCancel: { dismissCover() }
            )

        case .breathSession:
            // BreathworkSessionView intentionally has no background of
            // its own (lifted to its original PostPurchaseFlowView host
            // to avoid phase-swap flicker). When presented from here,
            // we need to set the cover's container background so the
            // breath bloom isn't floating on system black.
            BreathworkSessionView(
                onReadyToMove: {
                    markAutoCompleted(.breath(minutes: 1, style: .calming))
                    dismissCover()
                },
                onLater: {
                    markAutoCompleted(.breath(minutes: 1, style: .calming))
                    dismissCover()
                },
                onDismiss: { dismissCover() }
            )
            .background(Palette.programBgPrimary.ignoresSafeArea())
            .presentationBackground(Palette.programBgPrimary)

        case .chapterComplete:
            ChapterCompleteView(
                totalDays: schedule?.totalDays ?? ProgramScheduleCalculator.fallbackTotalDays,
                userId: userId,
                onDismiss: { dismissCover() },
                onPickNextProgram: { _ in dismissCover() }
            )
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: PlanSheet) -> some View {
        switch sheet {
        case .lock(let day):
            ProgramLockSheet(
                lockedDay: day,
                currentDay: schedule?.programDay ?? 1,
                totalDays: schedule?.totalDays ?? ProgramScheduleCalculator.fallbackTotalDays,
                onDismiss: { dismissSheet() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Palette.programCard)

        case .markAsDone(let prescription):
            MarkAsDoneSheet(
                prescription: prescription,
                onConfirm: {
                    handleMarkAsDoneConfirm(prescription)
                    dismissSheet()
                },
                onDismiss: { dismissSheet() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Palette.programCard)

        case .logWeight:
            LogWeightSheet(
                startingFromKg: allWeightLogs.first?.weightKg ?? 65,
                isUpdatingToday: hasLoggedWeightToday,
                onSave: { newKg in
                    persistWeight(kg: newKg)
                    markAutoCompleted(.weighIn)
                    dismissSheet()
                },
                onCancel: { dismissSheet() }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Palette.programCard)

        case .profileHub:
            ProfileHubView(onClose: { dismissSheet() })
                .presentationDetents([.large])
                .presentationBackground(Palette.programBgPrimary)
        }
    }

    private var hasLoggedWeightToday: Bool {
        guard let latest = allWeightLogs.first else { return false }
        return Calendar.current.isDateInToday(latest.loggedAt)
    }

    /// Insert (or update-in-place) today's weight log via the same
    /// pattern AnalyticsView uses for the WeightCard. Mirrors the
    /// one-per-day policy locked in [[feedback-weightloss-ux-principles]].
    private func persistWeight(kg: Double) {
        let cal = Calendar.current
        if let existing = allWeightLogs.first, cal.isDateInToday(existing.loggedAt) {
            existing.weightKg = kg
            existing.pendingUpsert = true
        } else {
            let record = WeightLogRecord(
                userId: userId,
                weightKg: kg,
                loggedAt: .now,
                source: "manual"
            )
            modelContext.insert(record)
        }
        try? modelContext.save()
        // Fire-and-forget cloud sync.
        if let log = allWeightLogs.first {
            Task { await AppSync.shared.upsertWeightLog(log) }
        }
    }

    // MARK: - Eyebrow

    @ViewBuilder private var eyebrow: some View {
        if let schedule {
            // v6 audit: settings ellipsis on the right of the eyebrow
            // row. PlanView previously had no settings entry — launch
            // blocker. Founder approved both-tabs scope (Today + Becoming
            // both get the ellipsis).
            HStack(alignment: .center) {
                // v3 founder pick: clean eyebrow even in scrapbook mode.
                // Pill below the strip carries the "viewing past" signal.
                Text(ProgramScheduleCalculator.dayOfTotalLabel(
                    programDay: viewingDay ?? schedule.programDay,
                    totalDays: schedule.totalDays
                ))
                .font(Typo.editorialEyebrow)
                .foregroundStyle(Palette.cocoaTertiary)
                .textCase(.uppercase)
                .kerning(0.66)

                Spacer()

                Button {
                    Haptics.light()
                    present(sheet: .profileHub)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .frame(width: 44, height: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            .modernEntrance(animateIn)
        }
    }

    // MARK: - Day strip

    @ViewBuilder private var dayStrip: some View {
        if let schedule {
            ProgramDayStrip(
                programDay: schedule.programDay,
                totalDays: schedule.totalDays,
                completionByDay: completionByDay,
                centeredDay: viewingDay ?? schedule.programDay,
                onTap: { day in handleStripTap(day) }
            )
            .modernEntrance(animateIn, delay: 0.08)
        }
    }

    // MARK: - Scrapbook pill

    private var viewingPastPill: some View {
        Button {
            Haptics.light()
            withAnimation(Motion.snapBack) {
                viewingDay = nil
                refreshTodayChecks()
            }
        } label: {
            HStack(spacing: 8) {
                (
                    Text("viewing")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .caption))
                        .foregroundStyle(Palette.cocoaPrimary)
                    +
                    Text(" day \(viewingDay ?? 0)")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaPrimary)
                )
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Palette.accentSubtle))
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .accessibilityLabel("Viewing day \(viewingDay ?? 0). Tap to return to today.")
    }

    // MARK: - Checklist card

    private var checklistCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(todayPrescriptions.enumerated()), id: \.offset) { idx, prescription in
                PlanRow(
                    prescription: prescription,
                    state: rowState(for: prescription),
                    onTap: { handleRowTap(prescription) },
                    onLongPress: { handleLongPress(prescription) },
                    liveCaloriesToday: prescription.isSnapMeal ? todayKcal : nil,
                    liveMealsLoggedToday: prescription.isSnapMeal ? todayMealsLogged : nil,
                    stepsCurrent: todayStepCount,
                    stepsTarget: profile.stepsDailyGoal,
                    snapMealProteinG: todayProteinG,
                    snapMealCarbsG: todayCarbsG,
                    snapMealFatG: todayFatG,
                    moveTotalMinutes: moveTotalMinutes(for: prescription),
                    moveExercises: nil   // Phase 1.B wires real WorkoutGenerator preview
                )
                .modernEntrance(animateIn, delay: 0.16 + Double(idx) * 0.06)

                // Standard indented hairline divider between all rows.
                // Progress rows no longer have an underbar (founder QA
                // 2026-06-09 — broke the divider rhythm), so the
                // skip-after-progress workaround is gone too.
                if idx < todayPrescriptions.count - 1 {
                    Divider()
                        .background(Palette.hairlineCocoa)
                        .padding(.leading, 72)
                        .padding(.trailing, 20)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.programCard)
                .fill(Palette.programCard)
        )
        .programPaperShadow()
    }

    private var completedRowCount: Int {
        todayPrescriptions.reduce(0) { acc, p in
            let st = checkStateByKey[p.itemKey] ?? .empty
            return st.isCompleted ? acc + 1 : acc
        }
    }

    private func rowState(for prescription: ProgramDayPrescription) -> PlanRow.RowState {
        // Progress rows (steps, water) compute their own state from
        // live data, never from program_day_checks. Per
        // [[feedback-no-checkbox-circle]] §progress.
        if prescription.isProgressRow {
            return progressRowState(for: prescription)
        }

        let state = checkStateByKey[prescription.itemKey] ?? .empty
        let isPastView = viewingDay != nil
        switch state {
        case .complete:
            return .binaryComplete(isAuto: false)
        case .autoCompleted:
            return .binaryComplete(isAuto: true)
        case .skipped:
            return .skipped
        case .empty:
            return isPastView ? .skipped : .binaryEmpty
        }
    }

    /// Progress-row state derived from live telemetry. Steps reads
    /// StepsService.shared.todayCount + profile.stepsDailyGoal.
    /// Water defers to Phase 3 — currently returns (0, 8, "cups").
    private func progressRowState(for prescription: ProgramDayPrescription) -> PlanRow.RowState {
        switch prescription {
        case .steps(let goal):
            let current = StepsService.shared.todayCount
            return .progress(current: current, target: goal, unit: "")
        case .water(let ml):
            // Phase 3 wires HydrationService; v1 stub.
            return .progress(current: 0, target: max(1, ml / 250), unit: "cups")
        default:
            return .binaryEmpty
        }
    }

    // MARK: - Lifecycle

    private func onAppear() {
        userId = AppSync.shared.currentUserId ?? ""
        guard !userId.isEmpty else { return }

        guard let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext) else {
            return
        }

        // One-time stale-check wipe before hydration. See the
        // planChecksMigratedV1 property for the bug history.
        if !planChecksMigratedV1 {
            wipeStaleChecks(for: plan.id)
            planChecksMigratedV1 = true
        }

        let computed = ProgramScheduleCalculator.compute(
            .init(startDate: plan.startDate, totalDays: plan.totalDays)
        )
        schedule = computed
        profile = ProgramService.shared.currentProfile(userId: userId, in: modelContext)

        if computed.isPostGoal {
            DispatchQueue.main.async { present(cover: .chapterComplete) }
        }

        todayPrescriptions = composeTodaysChecklist(
            profile: profile,
            programDay: computed.programDay
        )
        checkStateByKey = hydrateChecks(
            planId: plan.id,
            programDay: computed.programDay
        )
        completionByDay = hydrateCompletionByDay(
            planId: plan.id,
            totalDays: plan.totalDays
        )

        // Live food data for the snap-meal subtitle + fat-row macro
        // strip. Reads from FoodLogPersister's in-memory store (the
        // v1.0.7 stop-gap documented in PlankAIApp). Refreshed every
        // PlanView appear since the user may have logged in another tab.
        refreshTodayFood()

        // Today's step count for the fat-row progress bar (v6).
        refreshStepsCount()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            animateIn = true
        }
    }

    private func refreshTodayFood() {
        let macros = FoodLogPersister.todayMacros()
        todayKcal = Int(macros.kcal.rounded())
        todayProteinG = Int(macros.protein.rounded())
        todayCarbsG = Int(macros.carbs.rounded())
        todayFatG = Int(macros.fat.rounded())
        todayMealsLogged = FoodLogPersister.todayLogCount()
    }

    /// Pull today's step count for the fat-row progress bar.
    /// v6 simplified — single value instead of v5's 24-bar hourly.
    private func refreshStepsCount() {
        todayStepCount = StepsService.shared.todayCount
    }

    /// Extract the prescription's workout minutes for the move row's
    /// totalMinutes display in the embed. Falls back to 0 for non-
    /// workout rows.
    private func moveTotalMinutes(for prescription: ProgramDayPrescription) -> Int {
        if case .workout(_, let minutes, _) = prescription {
            return minutes
        }
        return 0
    }

    private func refreshTodayChecks() {
        guard let schedule, let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext) else {
            return
        }
        checkStateByKey = hydrateChecks(planId: plan.id, programDay: schedule.programDay)
    }

    private func composeTodaysChecklist(
        profile: IntensityProfile,
        programDay: Int
    ) -> [ProgramDayPrescription] {
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: .now)
        let week = max(1, ((programDay - 1) / 7) + 1)
        let workoutMinutes = profile.workoutMinutes(forProgramWeek: week)

        // v5 row order: load-bearing-first per UX spec §v5.3 — keeps
        // snap + move fully above fold, ritual rows below.
        // lesson → snap → move → steps → ritual (weigh / breath).
        var rows: [ProgramDayPrescription] = []
        rows.append(.lesson(lessonId: nil))
        rows.append(.snapMeal)
        rows.append(.workout(tier: profile.tier, minutes: workoutMinutes, bodyFocus: nil))
        rows.append(.steps(goal: profile.stepsDailyGoal))
        if weekday == 1 {
            rows.append(.weighIn)
        } else {
            rows.append(.breath(minutes: 1, style: .calming))
        }
        return rows
    }

    /// One-time wipe of ALL ProgramDayCheckRecord rows for the
    /// active plan. Bug-recovery migration only; runs once per
    /// install via planChecksMigratedV1.
    private func wipeStaleChecks(for planId: String) {
        let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { $0.programPlanId == planId }
        )
        guard let rows = try? modelContext.fetch(descriptor) else { return }
        for row in rows {
            modelContext.delete(row)
        }
        try? modelContext.save()
    }

    private func hydrateChecks(planId: String, programDay: Int) -> [String: ProgramService.ChecklistState] {
        let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { check in
                check.programPlanId == planId && check.programDay == programDay
            }
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        var map: [String: ProgramService.ChecklistState] = [:]
        for row in rows {
            map[row.itemKey] = ProgramService.ChecklistState(rawValue: row.state) ?? .empty
        }
        return map
    }

    private func hydrateCompletionByDay(planId: String, totalDays: Int) -> [Int: Int] {
        let descriptor = FetchDescriptor<ProgramDayCheckRecord>(
            predicate: #Predicate { check in
                check.programPlanId == planId
            }
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        var map: [Int: Int] = [:]
        for row in rows {
            let st = ProgramService.ChecklistState(rawValue: row.state) ?? .empty
            if st.isCompleted {
                map[row.programDay, default: 0] += 1
            }
        }
        return map
    }

    // MARK: - Strip tap routing

    private func handleStripTap(_ day: ProgramDayStrip.Day) {
        guard let schedule else { return }
        switch day {
        case .today:
            Haptics.light()
            if viewingDay != nil {
                withAnimation(Motion.snapBack) {
                    viewingDay = nil
                    refreshTodayChecks()
                }
            }
        case .past(let d):
            Haptics.light()
            guard let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext) else { return }
            withAnimation(Motion.snapBack) {
                viewingDay = d
                checkStateByKey = hydrateChecks(planId: plan.id, programDay: d)
            }
        case .locked(let d):
            Haptics.medium()
            present(sheet: .lock(day: d))
        case .newProgram:
            Haptics.light()
            present(cover: .chapterComplete)
        }
    }

    // MARK: - Row tap handlers (v4 — retention pattern)

    /// Row body tap → routes to the actual module per prescription
    /// type (Phase 1.B). Long-press remains the manual override
    /// (MarkAsDoneSheet) for the offline edge case.
    private func handleRowTap(_ prescription: ProgramDayPrescription) {
        guard viewingDay == nil else { return }

        // Tap ALWAYS routes to the module — including for already-
        // completed rows. Users expect to re-read a lesson, log
        // another meal, do another workout, etc. To UNMARK a
        // completed row, long-press it (handleLongPress toggles
        // complete states off).
        Haptics.light()

        switch prescription {
        case .lesson:
            openLesson()
        case .snapMeal:
            present(cover: .captureFlow)
        case .workout(let tier, let minutes, let bodyFocus):
            openWorkout(tier: tier, minutes: minutes, bodyFocus: bodyFocus)
        case .steps:
            // No standalone steps module; HealthKit auto-fires when
            // threshold crossed. Tap is silent (Phase 2 will surface
            // a steps detail sheet here).
            return
        case .breath:
            present(cover: .breathSession)
        case .weighIn:
            present(sheet: .logWeight)
        case .plank, .water, .measurements:
            // Phase 2 will wire dedicated modules. For now fall back
            // to the manual mark-as-done sheet.
            present(sheet: .markAsDone(prescription))
        }
    }

    // MARK: - Modal present/dismiss helpers (snappy transitions)
    //
    // Wrapping the activeCover/activeSheet assignment in a
    // `Transaction(animation: nil)` disables the system slide-up
    // animation on .fullScreenCover and .sheet — same pattern
    // HomeView uses for PreSessionView and PreRoutineView. The
    // module materializes instantly; the destination's own
    // onAppear fade/spring carries the motion. Net feel: snappy
    // pop instead of laggy slide. Founder QA 2026-06-09: "the
    // transition when you click each row and module pops is kind
    // of laggy."

    private func present(cover: PlanCover) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            activeCover = cover
        }
    }

    private func present(sheet: PlanSheet) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            activeSheet = sheet
        }
    }

    private func dismissCover() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { activeCover = nil }
    }

    private func dismissSheet() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { activeSheet = nil }
    }

    private func openLesson() {
        // Lesson ID picked by JeniMethodState.lessonForCard from the
        // user's current engagement day. PlanView's programDay maps
        // 1-to-1 (program day 1 → lesson 1, etc.).
        let day = schedule?.programDay ?? 1
        if let lessonId = JeniMethodState.lessonForCard(currentDay: day) {
            present(cover: .lesson(lessonId))
        }
    }

    private func openWorkout(tier: IntensityTier, minutes: Int, bodyFocus: String?) {
        // Construct WorkoutGenerator.Input from the prescription +
        // the user's profile state. Mirrors HomeView.generateDailyWorkout.
        let focusToken = bodyFocus ?? bodyFocusValue
        let focus: [BodyFocus] = BodyFocus(rawValue: focusToken).map { [$0] } ?? [.fullBody]

        let recentIds = allSessionLogs.prefix(7).compactMap { log -> [String]? in
            [log.exerciseType]
        }

        let startingTierInt: Int = {
            switch tier {
            case .soft:   return 1
            case .medium: return 2
            case .hard:   return 3
            }
        }()

        let input = WorkoutGenerator.Input(
            bodyFocus: focus,
            lengthMinutes: minutes,
            recentSessionExerciseIds: Array(recentIds),
            recentRatings: [],
            startingTier: startingTierInt,
            intensityOffset: workoutLevel + todaysEnergy
        )
        let workout = WorkoutGenerator.generate(from: input)
        present(cover: .preRoutine(workout))
    }

    /// Called by module callbacks when a session/log fires successfully.
    /// Marks the prescription's row as autoCompleted (sparkle glyph)
    /// so the state visually distinguishes "system saw it" from
    /// long-press manual override.
    private func markAutoCompleted(_ prescription: ProgramDayPrescription) {
        markComplete(prescription, isAuto: true)
    }

    /// Long-press override per [[feedback-no-checkbox-circle]].
    /// Manual "I did it offline" escape hatch — presents
    /// MarkAsDoneSheet. Only fires on binary-empty rows.
    private func handleLongPress(_ prescription: ProgramDayPrescription) {
        guard viewingDay == nil else { return }
        guard !prescription.isProgressRow else { return }

        // On a COMPLETED row, long-press toggles back to empty
        // ("I tapped this by mistake" undo). On an EMPTY row,
        // long-press shows the MarkAsDoneSheet (the offline
        // "I did it without the phone" manual mark).
        let current = checkStateByKey[prescription.itemKey] ?? .empty
        Haptics.medium()
        if current.isCompleted {
            unmarkRow(prescription)
        } else {
            present(sheet: .markAsDone(prescription))
        }
    }

    /// Reset a row to .empty. Mirrors markComplete's persistence
    /// path but writes the .empty state and decrements the per-day
    /// completion count.
    private func unmarkRow(_ prescription: ProgramDayPrescription) {
        withAnimation(Motion.gentleSpring) {
            checkStateByKey[prescription.itemKey] = .empty
        }
        guard let record = ProgramService.shared.markChecklistItem(
            prescription: prescription,
            state: .empty,
            userId: userId,
            in: modelContext
        ) else { return }

        if let schedule {
            let key = schedule.programDay
            completionByDay[key] = max(0, (completionByDay[key] ?? 1) - 1)
        }
        Task { await AppSync.shared.upsertProgramDayCheck(record) }
    }

    /// User confirmed manual mark-as-done from the long-press sheet.
    /// Writes .complete state (NOT .autoCompleted — preserves provenance
    /// so the sparkle glyph only fires on system-detected completions).
    private func handleMarkAsDoneConfirm(_ prescription: ProgramDayPrescription) {
        Haptics.success()
        markComplete(prescription, isAuto: false)
    }

    private func markComplete(_ prescription: ProgramDayPrescription, isAuto: Bool) {
        let next: ProgramService.ChecklistState = isAuto ? .autoCompleted : .complete

        withAnimation(Motion.gentleSpring) {
            checkStateByKey[prescription.itemKey] = next
        }

        guard let record = ProgramService.shared.markChecklistItem(
            prescription: prescription,
            state: next,
            userId: userId,
            in: modelContext
        ) else { return }

        if let schedule {
            let key = schedule.programDay
            completionByDay[key] = (completionByDay[key] ?? 0) + 1
        }

        Task {
            await AppSync.shared.upsertProgramDayCheck(record)
        }
    }
}
