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
    @State private var schedule: ProgramScheduleCalculator.Result?
    @State private var profile: IntensityProfile = .medium
    @State private var todayPrescriptions: [ProgramDayPrescription] = []
    @State private var checkStateByKey: [String: ProgramService.ChecklistState] = [:]
    @State private var completionByDay: [Int: Int] = [:]
    @State private var showChapterComplete: Bool = false
    @State private var animateIn: Bool = false

    // Scrapbook mode: nil = today; Int = viewing snapshot of past day.
    @State private var viewingDay: Int? = nil

    // Lock sheet
    @State private var showLockSheet: Bool = false
    @State private var lockedDayTapped: Int = 1

    // Mark-as-done sheet (long-press override)
    @State private var showMarkAsDoneSheet: Bool = false
    @State private var markAsDonePrescription: ProgramDayPrescription? = nil

    // Live data for snap-meal subtitle (today's calorie total +
    // meal count from FoodLogPersister's in-memory store).
    @State private var todayKcal: Int = 0
    @State private var todayMealsLogged: Int = 0

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

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
        .fullScreenCover(isPresented: $showChapterComplete) {
            ChapterCompleteView(
                totalDays: schedule?.totalDays ?? ProgramScheduleCalculator.fallbackTotalDays,
                userId: userId,
                onDismiss: { showChapterComplete = false },
                onPickNextProgram: { _ in
                    showChapterComplete = false
                }
            )
        }
        .sheet(isPresented: $showLockSheet) {
            ProgramLockSheet(
                lockedDay: lockedDayTapped,
                currentDay: schedule?.programDay ?? 1,
                totalDays: schedule?.totalDays ?? ProgramScheduleCalculator.fallbackTotalDays,
                onDismiss: { showLockSheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            // Force the entire sheet container background to white
            // (iOS 16.4+). Without this the system uses .systemBackground
            // which on dark-mode-ish overlay renders as a grey bleed at
            // the top/bottom edges of the .medium detent.
            .presentationBackground(Palette.programCard)
        }
        .sheet(isPresented: $showMarkAsDoneSheet) {
            if let prescription = markAsDonePrescription {
                MarkAsDoneSheet(
                    prescription: prescription,
                    onConfirm: {
                        handleMarkAsDoneConfirm(prescription)
                        showMarkAsDoneSheet = false
                    },
                    onDismiss: { showMarkAsDoneSheet = false }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Palette.programCard)
            }
        }
    }

    // MARK: - Eyebrow

    @ViewBuilder private var eyebrow: some View {
        if let schedule {
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
                    liveMealsLoggedToday: prescription.isSnapMeal ? todayMealsLogged : nil
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

        let computed = ProgramScheduleCalculator.compute(
            .init(startDate: plan.startDate, totalDays: plan.totalDays)
        )
        schedule = computed
        profile = ProgramService.shared.currentProfile(userId: userId, in: modelContext)

        if computed.isPostGoal {
            DispatchQueue.main.async { showChapterComplete = true }
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

        // Live food data for the snap-meal subtitle. Reads from
        // FoodLogPersister's in-memory store (the v1.0.7 stop-gap
        // documented in PlankAIApp). Refreshed every PlanView appear
        // since the user may have logged a meal in another tab.
        refreshTodayFood()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            animateIn = true
        }
    }

    private func refreshTodayFood() {
        let macros = FoodLogPersister.todayMacros()
        todayKcal = Int(macros.kcal.rounded())
        todayMealsLogged = FoodLogPersister.todayLogCount()
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
            lockedDayTapped = d
            showLockSheet = true
        case .newProgram:
            Haptics.light()
            showChapterComplete = true
        }
    }

    // MARK: - Row tap handlers (v4 — retention pattern)

    /// Row body tap. Phase 1 (modules unwired): routes to the same
    /// MarkAsDoneSheet as long-press, so users who tap discover the
    /// explicit confirmation and we never accidentally mark a row
    /// complete from a stray tap. Phase 1.B will swap this to route
    /// to the actual module player (lesson / food camera /
    /// SessionPreView / breath / weight sheet); long-press will
    /// remain the manual override.
    ///
    /// Founder QA 2026-06-09: "how come those checkboxes are green
    /// now? the user didn't finish them. let's get rid of the
    /// ambiguity." → no tap-to-toggle.
    private func handleRowTap(_ prescription: ProgramDayPrescription) {
        guard viewingDay == nil else { return }

        // Progress rows (steps, water): silent for now. Phase 1.B
        // will open a StepsBottomSheet / WaterBottomSheet here.
        if prescription.isProgressRow {
            Haptics.light()
            return
        }

        // Already-complete binary row: tap is a noop (don't re-prompt
        // a sheet to confirm something already done).
        let current = checkStateByKey[prescription.itemKey] ?? .empty
        guard !current.isCompleted else {
            Haptics.light()
            return
        }

        // Open the same MarkAsDoneSheet as long-press. Phase 1.B will
        // replace this with module routing.
        Haptics.light()
        markAsDonePrescription = prescription
        showMarkAsDoneSheet = true
    }

    /// Long-press override per [[feedback-no-checkbox-circle]].
    /// Manual "I did it offline" escape hatch — presents
    /// MarkAsDoneSheet. Only fires on binary-empty rows.
    private func handleLongPress(_ prescription: ProgramDayPrescription) {
        guard viewingDay == nil else { return }
        guard !prescription.isProgressRow else { return }
        Haptics.medium()
        markAsDonePrescription = prescription
        showMarkAsDoneSheet = true
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
