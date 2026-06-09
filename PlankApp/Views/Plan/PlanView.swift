import SwiftUI
import SwiftData
import PlankSync

// MARK: - PlanView (v2 — UX redesign 2026-06-09)
//
// v1.1 program pivot. The new "today" tab content for program-enrolled
// users. Replaces HomeView's card stack with a Her75-style 5-row
// daily checklist anchored by ProgramStickyNote markers + a BetterMe-
// style horizontal day-pill strip on top.
//
// Layout (UX spec §4):
//   - eyebrow "day N of totalDays"
//   - hero "today, *gently*."
//   - ProgramDayStrip (7-cell window, snap-aligned, lock affordance)
//   - first-launch hint "← swipe to see all N days →"
//   - white checklist card (5 PlanRows with module-bound rows)
//   - PlanViewMicroCaption (6 completion buckets)
//
// Scrapbook mode (founder picked Phase 1 2026-06-09):
//   Tapping a past day on the strip swaps the checklist to that day's
//   snapshot. CTAs hide, rows render in their final state, a pink
//   "viewing day N" pill appears under the hero; tap the pill to
//   return to today. No separate screen, no back button.
//
// Lock affordance (founder rule):
//   Tapping a future cell presents ProgramLockSheet with wistful copy.
//   No paywall CTA — the lock is structural, not commercial.
//
// Sentinel:
//   When ProgramScheduleCalculator.isPostGoal == true on appear,
//   ChapterCompleteView fires as fullScreenCover.

struct PlanView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var userId: String = ""
    @State private var schedule: ProgramScheduleCalculator.Result?
    @State private var profile: IntensityProfile = .medium
    @State private var todayPrescriptions: [ProgramDayPrescription] = []
    @State private var checkStateByKey: [String: ProgramService.ChecklistState] = [:]
    @State private var completionByDay: [Int: Int] = [:]   // day → completed-row count
    @State private var showChapterComplete: Bool = false
    @State private var animateIn: Bool = false

    // Scrapbook mode: nil = viewing today; Int = viewing snapshot of past day.
    @State private var viewingDay: Int? = nil

    // Lock sheet
    @State private var showLockSheet: Bool = false
    @State private var lockedDayTapped: Int = 1

    // First-launch hint (UX spec §5 + §7)
    @AppStorage("planview_strip_hint_dismissed_count") private var stripHintDismissedCount: Int = 0
    @AppStorage("planview_strip_user_scrolled") private var stripUserScrolled: Bool = false

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 28)
                    eyebrow
                    Spacer().frame(height: 12)
                    hero
                    if viewingDay != nil {
                        Spacer().frame(height: 16)
                        viewingPastPill
                    }
                    Spacer().frame(height: 28)
                    dayStrip
                    if shouldShowStripHint {
                        Spacer().frame(height: 8)
                        stripHint
                    }
                    Spacer().frame(height: 24)
                    checklistCard
                    Spacer().frame(height: 28)
                    PlanViewMicroCaption(
                        completed: completedRowCount,
                        total: todayPrescriptions.count
                    )
                    .modernEntrance(animateIn, delay: 0.5)
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
                    // Phase 5 wires real transitions. Phase 1 just dismisses.
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
        }
    }

    // MARK: - Eyebrow

    @ViewBuilder private var eyebrow: some View {
        if let schedule {
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

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: Typo.programHeroLineGap) {
            Text("today,")
                .font(Typo.programHeroDisplay)
                .foregroundStyle(Palette.cocoaPrimary)
            (
                Text("gently")
                    .font(Typo.programHeroItalic)
                    .foregroundStyle(Palette.cocoaPrimary)
                +
                Text(".")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .modernEntrance(animateIn, delay: 0.05)
    }

    // MARK: - Viewing-past pill (scrapbook mode)

    private var viewingPastPill: some View {
        Button {
            Haptics.light()
            withAnimation(Motion.modernPop) {
                viewingDay = nil
                refreshTodayChecks()
            }
        } label: {
            HStack(spacing: 8) {
                Text("viewing day \(viewingDay ?? 0)")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaPrimary)
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

    // MARK: - Day strip

    @ViewBuilder private var dayStrip: some View {
        if let schedule {
            ProgramDayStrip(
                programDay: schedule.programDay,
                totalDays: schedule.totalDays,
                completionByDay: completionByDay,
                onTap: { day in handleStripTap(day) }
            )
            .modernEntrance(animateIn, delay: 0.12)
        }
    }

    private var shouldShowStripHint: Bool {
        !stripUserScrolled && stripHintDismissedCount < 3
    }

    @ViewBuilder private var stripHint: some View {
        if let schedule {
            Text("← swipe to see all \(schedule.totalDays) days →")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .frame(maxWidth: .infinity)
                .modernEntrance(animateIn, delay: 0.6)
        }
    }

    // MARK: - Checklist card

    private var checklistCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(todayPrescriptions.enumerated()), id: \.offset) { idx, prescription in
                PlanRow(
                    index: idx + 1,
                    prescription: prescription,
                    state: rowState(for: prescription),
                    onEnter: { handleEnter(prescription) },
                    onCheckToggle: { handleCheckToggle(prescription) }
                )
                .modernEntrance(animateIn, delay: 0.20 + Double(idx) * 0.06)

                if idx < todayPrescriptions.count - 1 {
                    Divider()
                        .background(Palette.hairlineCocoa)
                        .padding(.leading, 88)
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

    /// Maps ProgramService.ChecklistState → PlanRow.RowState.
    /// In scrapbook mode (viewing past), incomplete rows render as
    /// .skipped instead of .empty so the row doesn't look like
    /// "still actionable" on a past day.
    private func rowState(for prescription: ProgramDayPrescription) -> PlanRow.RowState {
        let state = checkStateByKey[prescription.itemKey] ?? .empty
        let isPastView = viewingDay != nil
        switch state {
        case .complete:
            return .completeUser(completedAt: nil)
        case .autoCompleted:
            return .completeAuto
        case .skipped:
            return .skipped
        case .empty:
            return isPastView ? .skipped : .empty
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            animateIn = true
        }

        // Increment first-launch hint counter, hide after 3 opens.
        if shouldShowStripHint {
            stripHintDismissedCount += 1
        }
    }

    private func refreshTodayChecks() {
        guard let schedule, let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext) else {
            return
        }
        checkStateByKey = hydrateChecks(planId: plan.id, programDay: schedule.programDay)
    }

    /// Composes the 5-row checklist for any program day. Same rules
    /// as today's composition — Sunday = weighIn else breath.
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

    /// Per-day completion counts across the whole plan. Read once on
    /// appear; powers the day-strip's per-cell visual state.
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
                withAnimation(Motion.modernPop) {
                    viewingDay = nil
                    refreshTodayChecks()
                }
            }
        case .past(let d):
            Haptics.light()
            stripUserScrolled = true
            guard let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext) else { return }
            withAnimation(Motion.modernPop) {
                viewingDay = d
                checkStateByKey = hydrateChecks(planId: plan.id, programDay: d)
            }
        case .locked(let d):
            Haptics.medium()
            lockedDayTapped = d
            showLockSheet = true
            stripUserScrolled = true
        case .newProgram:
            Haptics.light()
            showChapterComplete = true
        }
    }

    // MARK: - Row tap handlers

    private func handleEnter(_ prescription: ProgramDayPrescription) {
        Haptics.light()
        // Phase 1 stub: routing to actual modules wires in Phase 1.B.
        // For now, tapping the row toggles complete as a fallback so
        // the user can still close the day. Future: route to lesson
        // player / food camera / SessionPreView / weight sheet etc.
        handleCheckToggle(prescription)
    }

    private func handleCheckToggle(_ prescription: ProgramDayPrescription) {
        // Disable interaction in scrapbook mode — read-only past days.
        guard viewingDay == nil else { return }

        Haptics.light()
        let current = checkStateByKey[prescription.itemKey] ?? .empty
        let next: ProgramService.ChecklistState = current.isCompleted ? .empty : .complete

        withAnimation(Motion.gentleSpring) {
            checkStateByKey[prescription.itemKey] = next
        }

        guard let record = ProgramService.shared.markChecklistItem(
            prescription: prescription,
            state: next,
            userId: userId,
            in: modelContext
        ) else { return }

        // Refresh completionByDay if today's count changed.
        if let schedule {
            let key = schedule.programDay
            let newCount = next.isCompleted ? (completionByDay[key] ?? 0) + 1 : max(0, (completionByDay[key] ?? 1) - 1)
            completionByDay[key] = newCount
        }

        Task {
            await AppSync.shared.upsertProgramDayCheck(record)
        }
    }
}
