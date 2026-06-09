import SwiftUI
import SwiftData
import PlankSync

// MARK: - PlanView
//
// v1.1 program pivot. The new "Today" tab content for program-enrolled
// users. Replaces HomeView's card stack with a Her75-style 5-row
// daily checklist anchored by ProgramStickyNote markers.
//
// Behavior:
//   - Gated upstream — HomeView checks programEraEnabled + reads
//     ProgramService.activePlan; if no active plan, falls back to
//     legacy HomeView render path
//   - 5 rows: lesson · snap a meal · move · steps · weigh-in / breath
//     (row 5 alternates by day-of-week + 7-day-stale predicate)
//   - Rows auto-complete from existing telemetry sources where
//     possible (SessionLog, FoodScan, WeightLog, HealthKit steps);
//     Phase 1 ships with manual tap-to-toggle as the baseline + the
//     auto-completion observers wire in Phase 1.B
//   - Day-75 sentinel: if ProgramScheduleCalculator.isPostGoal == true
//     on appear, fires ChapterCompleteView as fullScreenCover
//
// Founder-locked visual rules:
//   - White cards on pink scroll (Palette.programCard + Palette.bgPrimary)
//   - ProgramStickyNote as the ONE craft signal — no sticker scatter
//   - Italic Fraunces on the day greeting punch word
//   - Generous 80pt hero top inset + 24pt row gutters

struct PlanView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var userId: String = ""
    @State private var schedule: ProgramScheduleCalculator.Result?
    @State private var profile: IntensityProfile = .medium
    @State private var todayPrescriptions: [ProgramDayPrescription] = []
    @State private var checkStateByKey: [String: ProgramService.ChecklistState] = [:]
    @State private var showChapterComplete: Bool = false
    @State private var animateIn: Bool = false

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    Spacer().frame(height: Space.hero)
                    greeting
                    checklistCard
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, Space.lg)
            }
        }
        .onAppear { onAppear() }
        .fullScreenCover(isPresented: $showChapterComplete) {
            ChapterCompleteView(
                userId: userId,
                onDismiss: { showChapterComplete = false },
                onPickNextProgram: { _ in
                    // Phase 5 wires the actual transitions. For Phase 1
                    // we just dismiss — picker UI is visible but only
                    // .newGoal75 is functional, and that handler still
                    // needs ProgramService.transition (Phase 5 method).
                    // Future work: route to ProgramSetupSubflow with
                    // the picked kind as preset intensity.
                    showChapterComplete = false
                }
            )
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let schedule {
                Text(ProgramScheduleCalculator.dayOfTotalLabel(
                    programDay: schedule.programDay,
                    totalDays: schedule.totalDays
                ))
                .font(Typo.editorialEyebrow)
                .foregroundStyle(Palette.cocoaTertiary)
                .textCase(.uppercase)
                .kerning(0.66)
            }
            (
                Text("today, ")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
                +
                Text("gently")
                    .font(Typo.programHeroItalic)
                    .foregroundStyle(Palette.cocoaPrimary)
                +
                Text(".")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
            )
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 12)
        .animation(Motion.entrance, value: animateIn)
    }

    // MARK: - Checklist card

    private var checklistCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(todayPrescriptions.enumerated()), id: \.offset) { idx, prescription in
                PlanRow(
                    index: idx + 1,
                    prescription: prescription,
                    state: checkStateByKey[prescription.itemKey] ?? .empty,
                    onTap: { handleTap(prescription) }
                )
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 10)
                .animation(
                    Motion.entrance.delay(0.10 + Double(idx) * Motion.stagger),
                    value: animateIn
                )
                if idx < todayPrescriptions.count - 1 {
                    Divider()
                        .background(Palette.hairlineCocoa)
                        .padding(.leading, 88)
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.programCard)
                .fill(Palette.programCard)
        )
        .programPaperShadow()
    }

    // MARK: - Lifecycle

    private func onAppear() {
        userId = AppSync.shared.currentUserId ?? ""
        guard !userId.isEmpty else { return }

        guard let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext) else {
            // No active plan — HomeView gate should have prevented this
            // render path. Defensive: empty checklist + no crash.
            return
        }

        let computed = ProgramScheduleCalculator.compute(
            .init(startDate: plan.startDate, totalDays: plan.totalDays)
        )
        schedule = computed
        profile = ProgramService.shared.currentProfile(userId: userId, in: modelContext)

        // Day-75 sentinel — if user crossed goalDate, show graduation.
        // Defer to next runloop so the PlanView render commits first.
        if computed.isPostGoal {
            DispatchQueue.main.async { showChapterComplete = true }
        }

        todayPrescriptions = composeTodaysChecklist(
            profile: profile,
            programDay: computed.programDay
        )
        checkStateByKey = hydrateExistingChecks(
            planId: plan.id,
            programDay: computed.programDay
        )

        animateIn = true
    }

    /// Composes today's 5-row checklist from the active intensity
    /// profile + day-of-week. Row 5 alternates: weekly weigh-in on
    /// Sundays + 7-day-stale fallback, breathwork on weekdays.
    /// Phase 1 keeps cadence simple — workouts always render even
    /// if the tier's sessionsPerWeek is 3 (row stays empty + tappable;
    /// rest days surface as "rest day" in the subtitle in Phase 2).
    private func composeTodaysChecklist(
        profile: IntensityProfile,
        programDay: Int
    ) -> [ProgramDayPrescription] {
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: .now)  // 1=Sun … 7=Sat
        let week = max(1, ((programDay - 1) / 7) + 1)
        let workoutMinutes = profile.workoutMinutes(forProgramWeek: week)

        var rows: [ProgramDayPrescription] = []
        rows.append(.lesson(lessonId: nil))
        rows.append(.snapMeal)
        rows.append(.workout(tier: profile.tier, minutes: workoutMinutes, bodyFocus: nil))
        rows.append(.steps(goal: profile.stepsDailyGoal))

        // Row 5: Sunday → weighIn; else → breath
        if weekday == 1 {
            rows.append(.weighIn)
        } else {
            rows.append(.breath(minutes: 1, style: .calming))
        }
        return rows
    }

    /// Reads existing ProgramDayCheckRecord rows for today + maps
    /// to a key-keyed dict so render is O(1).
    private func hydrateExistingChecks(planId: String, programDay: Int) -> [String: ProgramService.ChecklistState] {
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

    // MARK: - Row tap

    private func handleTap(_ prescription: ProgramDayPrescription) {
        Haptics.light()
        let current = checkStateByKey[prescription.itemKey] ?? .empty
        let next: ProgramService.ChecklistState = current.isCompleted ? .empty : .complete

        // Optimistic local update
        withAnimation(Motion.gentleSpring) {
            checkStateByKey[prescription.itemKey] = next
        }

        // Persist
        guard let record = ProgramService.shared.markChecklistItem(
            prescription: prescription,
            state: next,
            userId: userId,
            in: modelContext
        ) else { return }

        // Cloud sync — fire-and-forget
        Task {
            await AppSync.shared.upsertProgramDayCheck(record)
        }
    }
}

// MARK: - PlanRow

struct PlanRow: View {

    let index: Int
    let prescription: ProgramDayPrescription
    let state: ProgramService.ChecklistState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ProgramStickyNote(index: index)
                VStack(alignment: .leading, spacing: 3) {
                    Text(prescription.rowTitle)
                        .font(Typo.body)
                        .foregroundStyle(Palette.cocoaPrimary)
                        .strikethrough(state.isCompleted, color: Palette.cocoaTertiary)
                    Text(prescription.rowSubtitle)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaSecondary)
                }
                Spacer()
                checkbox
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(prescription.rowTitle), \(prescription.rowSubtitle), \(state.isCompleted ? "complete" : "not complete")")
        .accessibilityHint("Double tap to toggle")
    }

    private var checkbox: some View {
        Group {
            if state.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Palette.stateGood)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .strokeBorder(Palette.cocoaTertiary, lineWidth: 1.5)
                    .frame(width: 26, height: 26)
            }
        }
        .frame(width: 28, height: 28)
    }
}

// MARK: - ProgramStickyNote
//
// The Her75 paper-square row marker. 56×56pt rounded-6, italic
// Fraunces numeral, alternating -2/+2 rotation, cycled palette
// stickyMint/Butter/Rose/Olive by index. The ONE craft signal
// per program screen.

struct ProgramStickyNote: View {

    let index: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(stickyColor)
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(index.isMultiple(of: 2) ? 2 : -2))
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
            Text("\(index)")
                .font(Typo.stickyNumeral)
                .foregroundStyle(Palette.cocoaPrimary)
        }
        .accessibilityHidden(true)  // numeral position conveyed by row order
    }

    private var stickyColor: Color {
        switch (index - 1) % 4 {
        case 0: return Palette.stickyMint
        case 1: return Palette.stickyButter
        case 2: return Palette.stickyRose
        default: return Palette.stickyOlive
        }
    }
}
