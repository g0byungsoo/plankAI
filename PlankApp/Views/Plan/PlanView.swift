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
    /// v1.0.10 — drives the day-archetype cohort override (.current GLP-1
    /// → every day is a protein day per the May 2025 joint advisory).
    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""
    /// v1.0.10 — restrictive-food-relationship override. When true the
    /// archetype rotation stays flat (no reset weeks, no phasing) per
    /// the 2026-06-17 WM physician brief: phase shifts re-trigger
    /// restrict/binge cognition. Source: new boolean key set in
    /// onboarding v4; the legacy AnalyticsView string also flags
    /// restriction-risk via "control"/"complicated".
    @AppStorage("onb_restrictive_food") private var restrictiveFoodFlag: Bool = false
    @AppStorage("onboardingFoodRelationship") private var foodRelationshipKeyLegacy: String = ""
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

    /// Two-step workout flow inside the .preRoutine cover:
    /// PreRoutineView (info card) → RoutineSessionView (live session).
    /// Mirrors HomeView's routineFlow swap so both entry points share
    /// one motion vocabulary.
    @State private var routineStep: RoutineStep = .pre
    private enum RoutineStep { case pre, session }

    @AppStorage("hasCompletedFirstSession") private var hasCompletedFirstSession = false

    enum PlanCover: Identifiable {
        // v1.1.1 (2026-06-19) — `programDay` lifted onto the case so
        // the cover content can resolve the CBT lesson for the
        // correct day. Previously the cover read `schedule.programDay`
        // directly, which always resolves to TODAY regardless of
        // viewingDay — past-day lesson taps opened today's content.
        case lesson(LessonID, programDay: Int)
        case captureFlow
        case preRoutine(WorkoutPreset)
        case breathSession
        case chapterComplete
        case programSetup

        var id: String {
            switch self {
            case .lesson(let id, let day): return "lesson-\(id.rawValue)-\(day)"
            case .captureFlow:    return "captureFlow"
            case .preRoutine:     return "preRoutine"
            case .breathSession:  return "breathSession"
            case .chapterComplete: return "chapterComplete"
            case .programSetup:   return "programSetup"
            }
        }
    }

    /// True when programEraEnabled is on but no active plan exists for
    /// this user (account switch, failed commit, wiped data). Without
    /// this the screen rendered a blank pink scroll — no checklist, no
    /// explanation, no way forward.
    @State private var planMissing: Bool = false

    /// One-time education beat: a new program user lands on the raw
    /// checklist with zero context (trial-cancellation audit gap #1).
    /// The hint retires forever on her first row tap.
    @AppStorage("planFirstRunHintSeen") private var planFirstRunHintSeen: Bool = false

    private var showFirstRunHint: Bool {
        !planFirstRunHintSeen && viewingDay == nil && completedRowCount == 0
    }

    enum PlanSheet: Identifiable {
        case lock(day: Int)
        case markAsDone(ProgramDayPrescription)
        case logWeight
        case profileHub   // v6 settings entry via ellipsis on eyebrow row
        /// v1.0.10 Phase 6 (2026-06-17) — tap on the archetype pill
        /// opens a soft explainer.
        case archetypeExplainer(ProgramDayArchetype)
        /// v1.0.36 Home Phase 2 (2026-06-19) — soft peek for short-
        /// horizon future days (within +7). Single warm sentence,
        /// archetype framing, no row preview. Per Panel 4 GLP-1 RD:
        /// avoids dangling locked content as pre-failure obligation.
        case dayPeek(day: Int, archetype: ProgramDayArchetype?)

        var id: String {
            switch self {
            case .lock(let day): return "lock-\(day)"
            case .markAsDone(let p): return "markAsDone-\(p.itemKey)"
            case .logWeight:     return "logWeight"
            case .profileHub:    return "profileHub"
            case .archetypeExplainer(let arch): return "archetype-\(arch.rawValue)"
            case .dayPeek(let day, _): return "peek-\(day)"
            }
        }
    }

    /// Latest weight reading for the LogWeightSheet pre-fill.
    @Query(sort: \WeightLogRecord.loggedAt, order: .reverse) private var allWeightLogs: [WeightLogRecord]

    /// Recent session log records — drives the WorkoutGenerator
    /// "avoid recent exercises" param + auto-completion detection.
    @Query(sort: \SessionLogRecord.completedAt, order: .reverse) private var allSessionLogs: [SessionLogRecord]

    /// Day-progress rows for the session save path (same derived-day
    /// write HomeView.saveRoutineSession performs).
    @Query private var allDayProgress: [DayProgressRecord]

    // Live data for snap-meal subtitle (today's calorie total +
    // meal count from FoodLogPersister's in-memory store).
    @State private var todayKcal: Int = 0

    /// v1.0.21 (2026-06-18) — increments each time CaptureFlowView
    /// reports a scan result landed. The Lottie heart + star
    /// explosion uses this as its `.id()` bump so the playback
    /// restarts from frame 0 on every new scan.
    @State private var scanExplosionTrigger: Int = -1
    @State private var todayMealsLogged: Int = 0

    // v6 fat-row embed data (simplified from v5 per founder QA)
    @State private var todayProteinG: Int = 0
    @State private var todayCarbsG: Int = 0
    @State private var todayFatG: Int = 0
    @State private var todayStepCount: Int = 0

    // MARK: - v1.1.1 (2026-06-19) perf cache
    //
    // showsUpCount + showsUpWeekDots + todayProteinSourcesHome
    // all derived from sessionLogs + dayProgress + foodLogs and were
    // computed on every body re-render — each rescanning 3 sources.
    // Cache here, update on appear + on data change.
    @State private var cachedFoodEntries: [FoodLogPersister.FoodLogEntry] = []
    @State private var cachedEngagedDates: Set<Date> = []

    /// One-time cleanup: prior buggy "tap = mark complete" code wrote
    /// .complete records for every test tap. Those stale records
    /// persist in SwiftData and make every PlanView open show all
    /// rows already checked, which the founder rightly flagged as
    /// broken: "each row needs to be unchecked as default and once
    /// user completes the module or long press the check, it's shown
    /// as checked." This flag fires the wipe once per install.
    @AppStorage("planChecksMigratedV1") private var planChecksMigratedV1: Bool = false

    /// Phase 3 retention atom — date key (YYYY-MM-DD) of the day the
    /// user last marked as "kind today" via long-press on the
    /// archetype header. Compared against today's date key to drive
    /// the kind-day header swap. Anti-shame agency: she can declare
    /// the day kind and the plan accepts it without penalty.
    @AppStorage("kindTodayDateKey") private var kindTodayDateKey: String = ""

    /// Phase 3 — confirmation alert for the kind-today long-press.
    @State private var showKindTodayConfirm = false

    /// Phase 3 — date key (YYYY-MM-DD) of the last day the yesterday
    /// recap line was shown. Set on first PlanView appearance for
    /// the day so the line auto-dismisses for the rest of the day.
    /// Anti-nagging: the recap is a single morning beat, not a
    /// running ticker.
    @AppStorage("lastRecapShownDateKey") private var lastRecapShownDateKey: String = ""

    /// Phase 3 — Unix timestamp of the previous PlanView appearance.
    /// Drives the welcome-back line when a multi-day gap is detected.
    /// Updated to "now" on every appearance, so the value reflects
    /// the gap until the NEXT visit.
    @AppStorage("lastPlanAppearAt") private var lastPlanAppearAt: Double = 0

    /// Phase 3 — whether to show the yesterday recap in the current
    /// render. Captured at first appearance so the line stays during
    /// the session even after we persist lastRecapShownDateKey.
    @State private var showYesterdayRecapThisSession: Bool = false

    /// Phase 3 — days since the last PlanView appearance, captured
    /// at .onAppear. Drives the welcome-back line in place of the
    /// recap when >= 3. Captured-once so the line stays through the
    /// session even as we update lastPlanAppearAt.
    @State private var welcomeBackDaysAway: Int = 0

    var body: some View {
        ZStack {
            // v5: program home gets its own pink-tinted background
            // token. Brand identity over neutral cream cohort default.
            Palette.programBgPrimary.ignoresSafeArea()

            if planMissing {
                planMissingState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 24)
                        eyebrow
                        Spacer().frame(height: 10)
                        dayArchetypePill
                        Spacer().frame(height: 12)
                        dayStrip
                        if viewingDay != nil {
                            Spacer().frame(height: 16)
                            viewingPastPill
                        }
                        Spacer().frame(height: 22)
                        if showFirstRunHint {
                            firstRunHint
                            Spacer().frame(height: 14)
                        }
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
        }
        .onAppear { onAppear() }
        // v1.1.1 perf — invalidate the food + engaged-dates cache
        // live when a new plate lands or a delete fires.
        .onReceive(FoodLogPersister.changeNotifier) { _ in
            refreshPerfCaches()
        }
        // Refresh when sessionLogs or dayProgress counts shift so the
        // engaged-dates set picks up completed routines + day progress
        // writes mid-session.
        .onChange(of: allSessionLogs.count) { _, _ in
            refreshPerfCaches()
        }
        .onChange(of: allDayProgress.count) { _, _ in
            refreshPerfCaches()
        }
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
        case .lesson(let lessonId, let coverProgramDay):
            // v1.2 (2026-06-15) — try the manifest-driven CBT reader
            // first. CBTCurriculumService.lesson(forProgramDay:...)
            // returns nil when the manifest isn't bundled OR the day
            // is past `canonical84.count`; we fall back to the legacy
            // `JeniMethodRitualView` in either case so existing 14-
            // lesson users keep their flow unbroken.
            //
            // v1.1.1 (2026-06-19) — `programDay` comes from the cover
            // case (carries viewingDay when re-reading a past lesson)
            // so the CBT lookup resolves to the RIGHT day instead of
            // always today's.
            let programDay = coverProgramDay
            let totalDays = schedule?.totalDays
                ?? ProgramScheduleCalculator.fallbackTotalDays
            if let resolved = CBTCurriculumService.shared.lesson(
                forProgramDay: programDay,
                totalDays: totalDays,
                cohort: CohortFlags.fromAppStorage()
            ) {
                LessonReaderView(
                    scheduled: resolved.scheduled,
                    slot: resolved.slot,
                    variant: resolved.variant,
                    onComplete: {
                        // v1.2 chain affordance — same shape as the
                        // legacy reader's `onChainNext`: mark the
                        // lesson row complete, dismiss the cover, then
                        // present the next unchecked checklist row
                        // after the cover dismissal settles. Without
                        // this, the CBT path would dead-end at "done"
                        // and the cohort would miss the legacy
                        // "lesson → snap meal → workout" rhythm.
                        markAutoCompleted(.lesson(lessonId: String(lessonId.rawValue)))
                        let next = nextUncheckedPrescription
                        dismissCover()
                        if let next {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                handleRowTap(next)
                            }
                        }
                    },
                    onSkip: { _ in dismissCover() }
                )
                .presentationBackground(Palette.programBgPrimary)
            } else {
                // Legacy 14-lesson fallback — also covers the chain-to-
                // next-row affordance that the new reader doesn't have
                // yet (Sprint A polish item).
                JeniMethodRitualView(
                    lesson: lessonId,
                    user: JeniMethodUserContext.fromAppStorage(),
                    onComplete: {
                        markAutoCompleted(.lesson(lessonId: String(lessonId.rawValue)))
                        dismissCover()
                    },
                    onSkip: { _ in dismissCover() },
                    nextRowTitle: nextUncheckedPrescription?.rowTitle,
                    onChainNext: {
                        markAutoCompleted(.lesson(lessonId: String(lessonId.rawValue)))
                        let next = nextUncheckedPrescription
                        dismissCover()
                        if let next {
                            // Let the cover dismissal settle before the
                            // next module's cover mounts (stacked
                            // fullScreenCovers read as a hitch).
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                handleRowTap(next)
                            }
                        }
                    }
                )
                .presentationBackground(Palette.programBgPrimary)
            }

        case .captureFlow:
            ZStack {
                CaptureFlowView(
                    userId: userId,
                    cuisineProfile: cuisineProfileCSV.isEmpty ? nil : cuisineProfileCSV,
                    onDismiss: {
                        dismissCover()
                        refreshTodayFood()
                        if todayKcal > 0 {
                            markAutoCompleted(.snapMeal)
                        }
                    },
                    onResultLanded: {
                        // v1.0.21 — the wow moment. The Lottie heart
                        // + star explosion replays from frame 0 each
                        // time triggerId bumps.
                        scanExplosionTrigger += 1
                    }
                )

                // v1.0.21 (2026-06-18) — TikTok/IG-girl-post register
                // wow moment per founder direction. Heart + star
                // Lottie burst that fires the instant the scan result
                // lands; reduce-motion gates straight to nothing.
                FoodResultExplosion(triggerId: scanExplosionTrigger)
                    .allowsHitTesting(false)
            }
            // v1.1 — kills the black frame the system cover paints
            // before the view draws (founder: "screen goes black for
            // milliseconds").
            .presentationBackground(Palette.bgPrimary)

        case .preRoutine(let workout):
            // Phase 2 (founder QA 2026-06-12: "start workout does
            // nothing"): full session chain. PreRoutine → RoutineSession
            // inside ONE cover, mirroring HomeView's routineFlow swap.
            // The checklist row marks complete only after the session
            // clears the ≥70% threshold — not on tap-Start.
            Group {
                if routineStep == .pre {
                    PreRoutineView(
                        workout: workout,
                        onStart: {
                            Analytics.track(.workoutStart, properties: [
                                "workout_name": workout.name,
                                "duration_min": workout.estimatedDuration,
                                "source": "plan_checklist"
                            ])
                            if !hasCompletedFirstSession {
                                Analytics.track(.firstWorkoutStart, properties: [
                                    "workout_name": workout.name
                                ])
                            }
                            withAnimation(Motion.crossFade) {
                                routineStep = .session
                            }
                        },
                        onCancel: { dismissCover() }
                    )
                    .transition(.opacity)
                } else {
                    RoutineSessionView(workout: workout) { results, duration in
                        let didMeet = SessionCompletion.didMeetThreshold(results)
                        if didMeet {
                            if !hasCompletedFirstSession {
                                Analytics.track(.firstWorkoutComplete, properties: [
                                    "workout_name": workout.name,
                                    "duration_seconds": Int(duration)
                                ])
                            }
                            Analytics.track(.workoutComplete, properties: [
                                "workout_name": workout.name,
                                "duration_seconds": Int(duration)
                            ])
                            saveRoutineSession(workout: workout, results: results, duration: duration)
                            hasCompletedFirstSession = true
                            markAutoCompleted(.workout(tier: .medium, minutes: 0, bodyFocus: nil))
                        }
                        dismissCover()
                    }
                    .transition(.opacity)
                }
            }
            .presentationBackground(Palette.programEraBg)

        case .breathSession:
            // v1.1 module-experience pass (2026-06-11): the row now
            // opens the full flow (occasion intro → session → receipt)
            // instead of a hardcoded 60s .calming session with no
            // intro. ≥3 lifetime completions quick-starts past the
            // intro with her last-used occasion + duration.
            BreathworkFlowView(
                onComplete: { minutes, techProtocol in
                    let style: ProgramDayPrescription.BreathStyle =
                        techProtocol == .energizing ? .energizing : .calming
                    markAutoCompleted(.breath(minutes: minutes, style: style))
                    dismissCover()
                },
                onDismiss: { dismissCover() }
            )
            .presentationBackground(Palette.programBgPrimary)

        case .programSetup:
            ProgramSetupSubflow { committed in
                dismissCover()
                if committed {
                    planMissing = false
                    onAppear()
                }
            }
            .presentationBackground(Palette.programBgPrimary)

        case .chapterComplete:
            ChapterCompleteView(
                totalDays: schedule?.totalDays ?? ProgramScheduleCalculator.fallbackTotalDays,
                userId: userId,
                onDismiss: { dismissCover() },
                onPickNextProgram: { _ in dismissCover() }
            )
            .presentationBackground(Palette.programBgPrimary)
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
            // 2026-06-15 founder note (round 2): .fraction(0.78) left
            // a big empty band between the steppers and the save
            // button — content is genuinely compact (~370pt) and the
            // tall sheet floated the CTA. .fraction(0.55) tightens
            // the proportions without re-introducing the .medium
            // sticker-overhang clipping. Both entry points share
            // the same detent.
            .presentationDetents([.fraction(0.55)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.programCard)

        case .profileHub:
            // v1.1 fix (2026-06-24): the settings drawer must CLOSE with the
            // standard animated slide-down. `dismissSheet()` wraps the change
            // in a `disablesAnimations` transaction — that's the deliberate
            // "instant materialize + custom content reveal" router pattern
            // (see PreSessionView), and it's right for the OPEN (ProfileHub
            // staggers its content in on appear). But the drawer has no exit
            // animation, so routing the close through it produced a jarring
            // instant CUT — inconsistent with every other transition (and with
            // this same sheet's own swipe-to-dismiss, which animates). A plain
            // binding mutation restores the system slide-down on close.
            ProfileHubView(onClose: { activeSheet = nil })
                .presentationDetents([.large])
                .presentationBackground(Palette.programBgPrimary)

        case .archetypeExplainer(let arch):
            ArchetypeExplainerSheet(
                archetype: arch,
                onDismiss: { dismissSheet() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.programCard)

        case .dayPeek(let day, let arch):
            ProgramDayPeekSheet(
                day: day,
                archetype: arch,
                onDismiss: { dismissSheet() }
            )
            .presentationDetents([.fraction(0.42)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.programCard)
        }
    }

    /// v1.1.1 (2026-06-19) — userId-scoped view over allWeightLogs.
    /// The raw @Query is unscoped (SwiftData doesn't natively
    /// support runtime predicates on string keys here); filtering at
    /// the read site is the locked pattern across this view + every
    /// other surface (see [[feedback-data-provenance]] +
    /// cross-account isolation invariant). Without this, the audit
    /// found a silent-data-corruption path: after an account switch
    /// + same-day log, `allWeightLogs.first` returned the OTHER
    /// user's row and the mutation wrote over their record.
    private var myWeightLogs: [WeightLogRecord] {
        guard !userId.isEmpty else { return [] }
        return allWeightLogs.filter { $0.userId == userId }
    }

    private var hasLoggedWeightToday: Bool {
        guard let latest = myWeightLogs.first else { return false }
        return Calendar.current.isDateInToday(latest.loggedAt)
    }

    /// Insert (or update-in-place) today's weight log via the same
    /// pattern AnalyticsView uses for the WeightCard. Mirrors the
    /// one-per-day policy locked in [[feedback-weightloss-ux-principles]].
    private func persistWeight(kg: Double) {
        let cal = Calendar.current
        // v1.1.1 — operate on userId-scoped view ONLY, never the
        // unfiltered @Query, to prevent cross-account row mutation.
        if let existing = myWeightLogs.first, cal.isDateInToday(existing.loggedAt) {
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
        if let log = myWeightLogs.first {
            Task { await AppSync.shared.upsertWeightLog(log) }
        }
        // v1.1.1 — signal cross-view weight change. AnalyticsView
        // listens and remounts BecomingTrendCanvas so the chart
        // updates even when it was on an inactive tab while the user
        // logged.
        NotificationCenter.default.post(name: .weightLogDidChange, object: nil)
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
                        .accessibilityLabel("settings")
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            .modernEntrance(animateIn)
        }
    }

    // MARK: - Day archetype pill (v1.0.10)
    //
    // Phase 1 of the program-quality pivot (Glow-Diet-inspired but
    // science-aligned per the research session 2026-06-17). Shows
    // today's archetype in the her75 register — italic Fraunces
    // punch word on a soft cocoa-tinted typography mark, no card
    // chrome. Tap-to-explain action is deferred to phase 2; phase 1
    // is render-only so the pattern can prove itself before we wire
    // chip re-ranking / lesson bias / Becoming strip on top.

    private var currentArchetype: ProgramDayArchetype? {
        guard let schedule else { return nil }
        let day = viewingDay ?? schedule.programDay
        return ProgramDayArchetype.archetype(
            forProgramDay: day,
            glp1Status: glp1Status,
            restrictiveFoodRelationship: isRestrictiveCohort
        )
    }

    /// Derived restrictive-cohort flag. Covers both the new boolean
    /// onboarding key AND the legacy string AnalyticsView reads
    /// ("control"/"complicated" → restriction risk).
    private var isRestrictiveCohort: Bool {
        if restrictiveFoodFlag { return true }
        return ["control", "complicated"].contains(foodRelationshipKeyLegacy.lowercased())
    }

    @ViewBuilder private var dayArchetypePill: some View {
        if let arch = currentArchetype {
            Button {
                Haptics.light()
                present(sheet: .archetypeExplainer(arch))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: arch.glyphName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.cocoaSecondary.opacity(0.7))

                    archetypeCopy(arch: arch)
                        .foregroundStyle(Palette.cocoaPrimary)

                    Spacer(minLength: 0)

                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Palette.cocoaSecondary.opacity(0.5))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(LuxuryPressButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("today is \(arch.rawValue) day. double tap to learn more")
            .accessibilityHint("opens a sheet explaining today's archetype")
            .modernEntrance(animateIn, delay: 0.08)
        }
    }

    /// Composes the pill text with the archetype's italic-punch word
    /// in JeniHeroSerif-Italic, the rest in DM Sans Regular — the
    /// her75 micro register that already lives on the eyebrow row.
    private func archetypeCopy(arch: ProgramDayArchetype) -> Text {
        let (raw, italic) = arch.pillCopy
        var out = Text("")
        let tokens = raw.split(separator: " ", omittingEmptySubsequences: false)
        for (i, raw) in tokens.enumerated() {
            let token = String(raw)
            let stripped = token
                .lowercased()
                .trimmingCharacters(in: .punctuationCharacters)
            if stripped == italic {
                out = out + Text(token)
                    .font(.custom("JeniHeroSerif-Italic", size: 19))
            } else {
                out = out + Text(token)
                    .font(.custom("DMSans-Regular", size: 16))
            }
            if i < tokens.count - 1 {
                out = out + Text(" ")
                    .font(.custom("DMSans-Regular", size: 16))
            }
        }
        return out
    }

    // MARK: - Day strip

    @ViewBuilder private var dayStrip: some View {
        if let schedule {
            ProgramDayStrip(
                programDay: schedule.programDay,
                totalDays: schedule.totalDays,
                completionByDay: completionByDay,
                centeredDay: viewingDay ?? schedule.programDay,
                onTap: { day in handleStripTap(day) },
                // v1.0.10 — surface each day's archetype on locked
                // (future) cells. Same derivation the Plan-tab pill +
                // Becoming letter row use, so the three surfaces agree.
                archetypeForDay: { day in
                    ProgramDayArchetype.archetype(
                        forProgramDay: day,
                        glp1Status: glp1Status,
                        restrictiveFoodRelationship: isRestrictiveCohort
                    )
                }
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
        VStack(alignment: .leading, spacing: 14) {
            // v1.0.35 Home Phase 3 (2026-06-19) — first-of-day
            // yesterday recap line. Single italic-Fraunces beat at
            // the top of the card acknowledging yesterday before
            // today's plan. Auto-dismisses after the first visit
            // per Panel 4 anti-nagging lock; gated to viewingDay
            // == nil so it never surfaces on past-day exploration.
            // v1.0.35 Home Phase 3 (2026-06-19) — re-engagement
            // wins the slot. When she returns after a 3+-day gap,
            // surface the welcome-back line instead of the recap.
            // The recap is for morning continuity; welcome-back is
            // for "she's back," which is the bigger moment.
            if viewingDay == nil, welcomeBackDaysAway >= 3 {
                HomeWelcomeBackLine(daysAway: welcomeBackDaysAway)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .modernEntrance(animateIn, delay: 0.04)
            } else if viewingDay == nil,
                      showYesterdayRecapThisSession,
                      let kind = yesterdayRecapKind {
                HomeYesterdayRecapLine(kind: kind, cohort: recapCohort)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .modernEntrance(animateIn, delay: 0.04)
            }

            // v1.0.35 Home Phase 1 (2026-06-19) — archetype framing
            // sentence above the rows. JeniHeroSerif with italic-
            // Fraunces punch word ("today is a *protein* day."). The
            // header carries the day's voice without color-coding the
            // rows underneath.
            if let arch = currentArchetype {
                HomeArchetypeHeader(
                    archetype: arch,
                    pastDay: viewingDay != nil,
                    kindToday: isKindToday,
                    onLongPressKind: { showKindTodayConfirm = true }
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .modernEntrance(animateIn, delay: 0.10)
            }

            // v1.0.35 Home Phase 3 (2026-06-19) — gain-only "shows
            // up" count below the archetype header. Replaces the
            // missing Home streak surface; Panel 4 anti-shame lock
            // = count only, no denominator, only when she has at
            // least 2 days in the bank. Hidden in past-view so the
            // settled day reads as the snapshot it is.
            if viewingDay == nil, showsUpCount >= 2 {
                HomeShowsUpLine(
                    count: showsUpCount,
                    week: showsUpWeekDots
                )
                    .padding(.horizontal, 20)
                    .modernEntrance(animateIn, delay: 0.14)
            }

            // Protein-day anchor surface — the founder's added ask.
            // Surfaces only on protein days + today (not past view) +
            // when she has logged food (no zero-state nag). Mirrors
            // BecomingProteinTile compressed for inline Home use;
            // cohort-routed copy via isGLP1Current.
            if viewingDay == nil
                && currentArchetype == .protein
                && todayProteinG > 0 {
                HomeProteinTracker(
                    proteinG: todayProteinG,
                    targetG: proteinTargetG,
                    isGLP1Current: glp1Status == "current",
                    sources: todayProteinSourcesHome
                )
                .padding(.horizontal, 20)
            }

            // Past-day quiet caption — Panel 4 GLP-1 RD's anti-shame
            // copy. Surfaces only when viewing the past so the user
            // knows the rows below are settled, not earnable. Phase 3
            // settling: fade-in instead of hard insert.
            if viewingDay != nil {
                Text("yesterday's page. it counted as it was.")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .caption))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

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
                        moveExercises: nil,
                        isAnchor: isAnchorRow(prescription, idx: idx),
                        anchorAccentColor: anchorAccentColor(for: prescription, idx: idx),
                        isPastDay: viewingDay != nil,
                        overrideSubtitle: overrideSubtitle(for: prescription)
                    )
                    .modernEntrance(animateIn, delay: 0.16 + Double(idx) * 0.06)
                    // Phase 3 — yesterday settling beat. When the
                    // user scrubs to a past day, animate the chrome
                    // shift (alpha drop, shadow fade) instead of a
                    // hard cut. Tied to viewingDay so today→past +
                    // past→today both smooth.
                    .animation(.easeInOut(duration: 0.35), value: viewingDay)

                    if idx < todayPrescriptions.count - 1 {
                        Divider()
                            .background(Palette.hairlineCocoa)
                            .padding(.leading, 72)
                            .padding(.trailing, 20)
                    }
                }
            }
            .padding(.vertical, 4)

            // v1.0.35 Home Phase 3 (2026-06-19) — after-9pm closing
            // line. Tomorrow always resets — Panel 4 GLP-1 RD's
            // anti-shame lock. Hidden in past view + when the day
            // is already fully checked. When the day was marked
            // kind, swap the copy to "tomorrow resets" earlier (any
            // hour) so the closing beat is part of the kind declaration.
            if viewingDay == nil, isKindToday || shouldShowTomorrowResets {
                HomeTomorrowResetsLine()
                    .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.programCard)
                .fill(Palette.programCard)
        )
        .programPaperShadow()
        .confirmationDialog(
            "mark today kind?",
            isPresented: $showKindTodayConfirm,
            titleVisibility: .visible
        ) {
            Button("mark today kind") {
                Haptics.medium()
                kindTodayDateKey = todayDateKey
            }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("the plan stays. nothing required. tomorrow resets \u{2661}")
        }
    }

    /// Phase 3 — YYYY-MM-DD for today, used to gate the kind-today
    /// flag against day rollover. Local-calendar, not UTC.
    private var todayDateKey: String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    /// Phase 3 — cohort routing for the yesterday recap line verb.
    /// Reads from the same flags the rest of the engine uses; GLP-1
    /// current takes precedence over restrictive flag if both are
    /// set (rare; the user is mid-GLP-1 with prior restriction).
    private var recapCohort: YesterdayRecapCohort {
        if glp1Status == "current" { return .glp1Current }
        if isRestrictiveCohort { return .restrictiveRisk }
        return .default
    }

    /// Phase 3 — yesterday's engagement summarized as a recap kind.
    /// Returns nil when yesterday had zero engagement (no recap = no
    /// shame). Plates = food log count for yesterday; rituals = the
    /// union of session logs + day progress for yesterday. Mixed
    /// when both > 0; engaged is the fallback when ≥1 bar fired but
    /// neither category accumulated a number (defensive).
    private var yesterdayRecapKind: YesterdayRecapKind? {
        let cal = Calendar.current
        let now = Date.now
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: now) else {
            return nil
        }
        let yStart = cal.startOfDay(for: yesterday)
        let yEnd = cal.startOfDay(for: now)

        let plates: Int
        if FoodFlags.isEnabled, !userId.isEmpty {
            plates = FoodLogPersister.allEntries(userId: userId).filter {
                $0.loggedAt >= yStart && $0.loggedAt < yEnd
            }.count
        } else {
            plates = 0
        }

        // v1.1.1 — user-scoped. Without this filter the yesterday
        // recap line was counting cross-account sessions on shared
        // devices, e.g. "you logged 3 plates yesterday" pulled from
        // a different user's prior day.
        let sessionCount = allSessionLogs.filter {
            $0.userId == userId &&
            $0.completedAt >= yStart && $0.completedAt < yEnd
        }.count
        let hadDayProgress = allDayProgress.contains {
            $0.userId == userId && $0.date >= yStart && $0.date < yEnd
        }
        // Sessions are the primary ritual signal; dayProgress is a
        // fallback so a completion that didn't write a session log
        // still earns a recap line.
        let rituals = sessionCount > 0 ? sessionCount : (hadDayProgress ? 1 : 0)

        switch (plates, rituals) {
        case (0, 0):                return nil
        case (let p, 0) where p > 0: return .plates(p)
        case (0, let r) where r > 0: return .rituals(r)
        case (let p, let r):         return .mixed(plates: p, rituals: r)
        }
    }

    /// Phase 3 — true when the user has long-pressed the archetype
    /// header today to declare it a kind day. Resets at midnight by
    /// dateKey comparison.
    private var isKindToday: Bool {
        viewingDay == nil
            && !kindTodayDateKey.isEmpty
            && kindTodayDateKey == todayDateKey
    }

    /// Phase 3 retention atom — true when (a) it's past 9pm local,
    /// (b) the day still has at least one incomplete row, and (c)
    /// the user is on the today view. Drives the "tomorrow resets ♡"
    /// closing line under the checklist.
    private var shouldShowTomorrowResets: Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        guard hour >= 21 else { return false }
        guard !todayPrescriptions.isEmpty else { return false }
        let hasOpen = todayPrescriptions.contains { rx in
            switch rowState(for: rx) {
            case .binaryEmpty, .skipped, .restDay:
                return true
            case .progress(let current, let target, _):
                return current < target
            case .binaryComplete:
                return false
            }
        }
        return hasOpen
    }

    /// Phase 3 retention atom — distinct days the user has shown up
    /// across the entire program. Mirrors AnalyticsView.engagedDates
    /// (session logs + food logs + day progress) but local to the
    /// Home checklist card. Never decrements; we only ever count
    /// dates that crossed at least one engagement bar.
    /// v1.1.1 (2026-06-19) — reads from the cached set instead of
    /// re-scanning 3 data sources on every body re-render. Updated
    /// by `refreshPerfCaches()` on appear + on data change.
    private var showsUpCount: Int { cachedEngagedDates.count }

    /// Phase 4 (2026-06-19) — 7-day dot pattern for the tap-expand
    /// reveal on HomeShowsUpLine. Oldest → today; true = engaged.
    /// v1.1.1 perf: reads from the cached engaged-dates set.
    private var showsUpWeekDots: [Bool] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let engaged = cachedEngagedDates
        return (0..<7).compactMap { offset -> Bool? in
            guard let day = cal.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            return engaged.contains(day)
        }
    }

    /// Phase 4 — today's plate sources ranked by protein contribution
    /// for the HomeProteinTracker long-press peek. v1.1.1 perf: reads
    /// from the cached food entries (no fresh FoodLogPersister scan).
    private var todayProteinSourcesHome: [(entryId: String, proteinG: Int)] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        return cachedFoodEntries
            .filter { $0.loggedAt >= start }
            .map { (entryId: $0.id, proteinG: Int($0.protein.rounded())) }
    }

    /// 1.0g/kg from onboarding weight, floor 70g, ceiling 150g per
    /// Phillips IJSNEM 2016 + Conte JCEM 2024. Returns 80g as a sane
    /// default if no body mass is on record yet.
    private var proteinTargetG: Int {
        let kg = UserDefaults.standard.double(forKey: "onboardingCurrentWeightKg")
        guard kg > 30 else { return 80 }
        let raw = 1.0 * kg
        return max(70, min(150, Int(raw.rounded())))
    }

    /// True when this row is the day's archetype anchor (position 0
    /// matches the archetype's anchor prescription). The reorder is
    /// applied in `composeTodaysChecklist` so the anchor always sits
    /// at idx 0 when one applies. Hidden in past-view (Panel 2: the
    /// hairline accent is a today-only signal).
    private func isAnchorRow(_ row: ProgramDayPrescription, idx: Int) -> Bool {
        guard idx == 0, viewingDay == nil,
              let arch = currentArchetype,
              let tag = arch.anchorTag
        else { return false }
        return matchesAnchorTag(row, tag)
    }

    private func anchorAccentColor(for row: ProgramDayPrescription, idx: Int) -> Color? {
        guard isAnchorRow(row, idx: idx),
              let arch = currentArchetype
        else { return nil }
        switch arch.anchorAccentColorName {
        case "stickyButter": return Palette.stickyButter
        case "stickyOlive":  return Palette.stickyOlive
        case "stickyMint":   return Palette.stickyMint
        default:             return nil
        }
    }

    private func overrideSubtitle(for row: ProgramDayPrescription) -> String? {
        guard let arch = currentArchetype else { return nil }
        if row.isSnapMeal {
            return arch.glp1ProteinNudge(glp1Status: glp1Status)
        }
        return nil
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

    // MARK: - First-run hint

    /// Quiet editorial beat above the checklist on her very first
    /// visit: what this screen is, how to use it. One line, no chrome
    /// competition with the card below.
    @ViewBuilder private var firstRunHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.accent)
            (
                Text("this is your ")
                    .font(Typo.caption)
                + Text("day")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                // U+FE0E pins text presentation — without it the heart
                // renders as the red emoji glyph (sim QA round 1).
                + Text(". tap any row to begin ♥\u{FE0E}")
                    .font(Typo.caption)
            )
            .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .modernEntrance(animateIn, delay: 0.25)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Plan-missing recovery

    /// Editorial recovery state. Reachable when the program era flag is
    /// on without a matching plan row — the setup subflow rebuilds the
    /// plan from her stored answers in under a minute.
    @ViewBuilder private var planMissingState: some View {
        VStack(spacing: 0) {
            Spacer()
            (
                Text("your plan, ")
                    .font(Typo.heroHeadline)
                + Text("ready when you are")
                    .font(Typo.heroHeadlineItalic)
            )
            .foregroundStyle(Palette.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.lg)

            Spacer().frame(height: 14)

            Text("a couple of quick questions and today's checklist is back.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "set up my program") {
                present(cover: .programSetup)
            }
        }
    }

    // MARK: - Lifecycle

    private func onAppear() {
        userId = AppSync.shared.currentUserId ?? ""
        guard !userId.isEmpty else { return }

        guard let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext) else {
            planMissing = true
            return
        }
        planMissing = false

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
            programDay: computed.programDay,
            archetype: currentArchetype
        )
        checkStateByKey = hydrateChecks(
            planId: plan.id,
            programDay: computed.programDay
        )
        // v1.1.1 (2026-06-19) — defer the totalDays-wide completion
        // map (drives the date strip dot states + becoming letters)
        // off the synchronous onAppear path so rows + archetype
        // header render IMMEDIATELY. The strip cells will populate
        // their dots in ~50-100ms when the SwiftData fetch returns
        // — cross-fades smoothly via the existing modernEntrance.
        let planId = plan.id
        let totalDays = plan.totalDays
        Task { @MainActor in
            completionByDay = hydrateCompletionByDay(
                planId: planId,
                totalDays: totalDays
            )
        }

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

        // Phase 3 — first-of-day yesterday recap. Capture once per
        // PlanView lifetime so the line stays through this session
        // even after we persist the dismiss key. Skip past-day view.
        if viewingDay == nil {
            let today = todayDateKey
            if lastRecapShownDateKey != today, yesterdayRecapKind != nil {
                showYesterdayRecapThisSession = true
                lastRecapShownDateKey = today
            }
        }

        // Phase 3 — welcome-back detection. Compute the gap BEFORE
        // updating the timestamp so we capture the right delta.
        // Only counts when she opens PlanView on a different
        // calendar day from the last appearance (not seconds later
        // in the same session).
        if viewingDay == nil, lastPlanAppearAt > 0 {
            let prev = Date(timeIntervalSince1970: lastPlanAppearAt)
            let cal = Calendar.current
            let prevDay = cal.startOfDay(for: prev)
            let today = cal.startOfDay(for: .now)
            if let gap = cal.dateComponents([.day], from: prevDay, to: today).day,
               gap >= 3 {
                welcomeBackDaysAway = gap
            }
        }
        lastPlanAppearAt = Date.now.timeIntervalSince1970
    }

    private func refreshTodayFood() {
        let macros = FoodLogPersister.todayMacros()
        todayKcal = Int(macros.kcal.rounded())
        todayProteinG = Int(macros.protein.rounded())
        todayCarbsG = Int(macros.carbs.rounded())
        todayFatG = Int(macros.fat.rounded())
        todayMealsLogged = FoodLogPersister.todayLogCount()
        // v1.1.1 perf — piggyback the engaged-dates + food-entries
        // cache update on the same refresh path. Cheap (~100 entries).
        refreshPerfCaches()
    }

    /// v1.1.1 (2026-06-19) — recomputes the shared engaged-dates set
    /// + food-entries cache that drive showsUpCount, showsUpWeekDots,
    /// todayProteinSourcesHome, etc. Called from refreshTodayFood +
    /// FoodLogPersister.changeNotifier so the cache stays fresh.
    private func refreshPerfCaches() {
        let entries: [FoodLogPersister.FoodLogEntry]
        if FoodFlags.isEnabled, !userId.isEmpty {
            entries = FoodLogPersister.allEntries(userId: userId)
        } else {
            entries = []
        }
        cachedFoodEntries = entries

        let cal = Calendar.current
        var days = Set<Date>()
        // v1.1.1 — filter sessionLogs by userId. The unfiltered
        // allSessionLogs leaked the prior account's engagement days
        // into showsUpCount + week dots on shared devices (e.g.,
        // founder + spouse on one phone). Matches the userId guard
        // already applied to allDayProgress.
        for log in allSessionLogs where log.userId == userId {
            days.insert(cal.startOfDay(for: log.completedAt))
        }
        for dp in allDayProgress where dp.userId == userId {
            days.insert(cal.startOfDay(for: dp.date))
        }
        for entry in entries {
            days.insert(cal.startOfDay(for: entry.loggedAt))
        }
        cachedEngagedDates = days
    }

    /// Pull today's step count for the fat-row progress bar.
    /// v6 simplified — single value instead of v5's 24-bar hourly.
    private func refreshStepsCount() {
        todayStepCount = StepsService.shared.todayCount
    }

    // (moveTotalMinutes helper deleted 2026-06-11 — the embed's
    // minutes line duplicated the row subtitle; the embed shows
    // exercise count only now.)

    private func refreshTodayChecks() {
        guard let schedule, let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext) else {
            return
        }
        checkStateByKey = hydrateChecks(planId: plan.id, programDay: schedule.programDay)
    }

    private func composeTodaysChecklist(
        profile: IntensityProfile,
        programDay: Int,
        archetype: ProgramDayArchetype? = nil
    ) -> [ProgramDayPrescription] {
        let week = max(1, ((programDay - 1) / 7) + 1)
        let workoutMinutes = profile.workoutMinutes(forProgramWeek: week)

        // Base v5 row order: lesson → snap → workout → steps → weigh →
        // breath. Load-bearing-first per UX spec §v5.3.
        var rows: [ProgramDayPrescription] = []
        rows.append(.lesson(lessonId: nil))
        rows.append(.snapMeal)
        rows.append(.workout(tier: profile.tier, minutes: workoutMinutes, bodyFocus: nil))
        rows.append(.steps(goal: profile.stepsDailyGoal))
        rows.append(.weighIn)
        rows.append(.breath(minutes: 1, style: .calming))

        // v1.0.35 Home Phase 1 (2026-06-19) — archetype-driven reorder.
        // Per Panel 2 (her75): the day's anchor floats to row 1 (Panel
        // 2's invisible-as-typography differentiation). Balanced day
        // keeps the base order (absence of reorder IS the balance
        // signal). The reorder matches by case discriminant only, so
        // the engine-driven minutes / tier / lessonId on each row
        // stay intact.
        guard let archetype, let tag = archetype.anchorTag else {
            return rows
        }
        if let idx = rows.firstIndex(where: { matchesAnchorTag($0, tag) }) {
            let row = rows.remove(at: idx)
            rows.insert(row, at: 0)
        }
        return rows
    }

    /// Match a fully-parametrized prescription against the archetype
    /// anchor tag (discriminant-only).
    private func matchesAnchorTag(
        _ row: ProgramDayPrescription,
        _ tag: ProgramDayArchetype.AnchorTag
    ) -> Bool {
        switch (row, tag) {
        case (.snapMeal, .snapMeal): return true
        case (.workout, .workout):   return true
        case (.breath, .breath):     return true
        default:                     return false
        }
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
            // v1.0.36 Home Phase 2 — within +7 days, present the soft
            // peek sheet (single warm sentence + archetype framing,
            // no row preview). Beyond +7 the existing ProgramLockSheet
            // still ships — it carries program-pace context that the
            // peek doesn't need to repeat.
            Haptics.light()
            let delta = d - schedule.programDay
            if delta > 0 && delta <= 7 {
                let arch = ProgramDayArchetype.archetype(
                    forProgramDay: d,
                    glp1Status: glp1Status,
                    restrictiveFoodRelationship: isRestrictiveCohort
                )
                present(sheet: .dayPeek(day: d, archetype: arch))
            } else {
                present(sheet: .lock(day: d))
            }
        case .newProgram:
            Haptics.light()
            present(cover: .chapterComplete)
        }
    }

    /// The lesson chain's target: the first unchecked, OPENABLE row
    /// after the lesson. Steps is skipped (no module to open); the
    /// lesson itself is skipped (she's in it).
    private var nextUncheckedPrescription: ProgramDayPrescription? {
        todayPrescriptions.first { p in
            if case .lesson = p { return false }
            if case .steps = p { return false }
            let state = checkStateByKey[p.itemKey] ?? .empty
            return !state.isCompleted
        }
    }

    // MARK: - Row tap handlers (v4 — retention pattern)

    /// Row body tap → routes to the actual module per prescription
    /// type (Phase 1.B). Long-press remains the manual override
    /// (MarkAsDoneSheet) for the offline edge case.
    private func handleRowTap(_ prescription: ProgramDayPrescription) {
        // Past-day view: lessons stay re-readable (Phase 1 / Panel 2
        // + 4 lock — lessons are CONTENT, not behavior). Every other
        // row is view-only on past days.
        if viewingDay != nil {
            if case .lesson = prescription {
                Haptics.light()
                openLesson()
            }
            return
        }

        // Tap ALWAYS routes to the module — including for already-
        // completed rows. Users expect to re-read a lesson, log
        // another meal, do another workout, etc. To UNMARK a
        // completed row, long-press it (handleLongPress toggles
        // complete states off).
        Haptics.light()

        // First tap = she's learned how the checklist works.
        if !planFirstRunHintSeen {
            withAnimation(Motion.exit) { planFirstRunHintSeen = true }
        }

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
        routineStep = .pre    // reset the workout flow for next launch
    }

    private func dismissSheet() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { activeSheet = nil }
    }

    private func openLesson() {
        // v1.0.35 (2026-06-19) Home Phase 1 — Panel 2 her75 + Panel 4
        // GLP-1: lessons on past days must open the PAST day's lesson,
        // not today's. Resolve through `viewingDay ?? programDay` so
        // re-reads land on the correct content.
        // v1.1.1 — also forward the day to the cover so the CBT
        // reader path resolves the right scheduled lesson (was
        // reading schedule.programDay = today, ignoring viewingDay).
        JeniMethodState.markEnrolled()
        let day = viewingDay ?? schedule?.programDay ?? 1
        let lessonId = LessonID(rawValue: JeniMethodState.lessonId(forDay: day)) ?? .generic
        present(cover: .lesson(lessonId, programDay: day))
    }

    private func openWorkout(tier: IntensityTier, minutes: Int, bodyFocus: String?) {
        // Construct WorkoutGenerator.Input from the prescription +
        // the user's profile state. Mirrors HomeView.generateDailyWorkout.
        let focusToken = bodyFocus ?? bodyFocusValue
        let focus: [BodyFocus] = BodyFocus(rawValue: focusToken).map { [$0] } ?? [.fullBody]

        // v1.1.1 — user-scoped. Without the filter, recent-exercise
        // dedupe pulled in the prior account's last 7 picks on shared
        // devices, biasing the generator away from what the current
        // user has actually done.
        let recentIds = scopedSessionLogs.prefix(7).compactMap { log -> [String]? in
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

    /// User-scoped session logs (cross-account isolation — same
    /// guarantee HomeView.sessionLogs provides).
    private var scopedSessionLogs: [SessionLogRecord] {
        guard !userId.isEmpty else { return [] }
        return allSessionLogs.filter { $0.userId == userId }
    }

    /// Day-progress record for today's calendar day, user-scoped.
    private var todayProgress: DayProgressRecord? {
        guard !userId.isEmpty else { return nil }
        let cal = Calendar.current
        return allDayProgress.first { $0.userId == userId && cal.isDate($0.date, inSameDayAs: .now) }
    }

    /// Persists a completed routine session. Mirrors
    /// HomeView.saveRoutineSession — derived engagement day, same-day
    /// DayProgress merge, fire-and-forget Supabase upserts.
    private func saveRoutineSession(workout: WorkoutPreset, results: [ExerciseResultEntry], duration: TimeInterval) {
        let uid = AppSync.shared.currentUserId ?? userId
        let resultsData = try? JSONEncoder().encode(results)
        let session = SessionLogRecord(
            userId: uid, exerciseType: "routine", holdTime: 0, targetTime: 0,
            qualityScore: 0, sessionType: "routine",
            presetId: workout.id, exerciseResults: resultsData,
            totalDuration: duration
        )
        modelContext.insert(session)
        let derivedDay = EngagementDayCalculator.programDayForNewSession(
            existingLogs: scopedSessionLogs,
            newSessionCompletedAt: session.completedAt
        )
        let progressRecord: DayProgressRecord
        if let existing = todayProgress {
            existing.primarySessionId = session.id
            var ids = existing.sessionLogIds ?? []; ids.append(session.id); existing.sessionLogIds = ids
            existing.programDay = derivedDay
            existing.updatedAt = .now
            progressRecord = existing
        } else {
            let progress = DayProgressRecord(userId: uid, programDay: derivedDay, primarySessionId: session.id,
                                             primaryQualityScore: 0, primaryHoldTime: 0)
            progress.sessionLogIds = [session.id]; modelContext.insert(progress)
            progressRecord = progress
            RetentionNotifications.recordShownUpDay(count: derivedDay)
        }
        try? modelContext.save()
        RetentionNotifications.markSessionCompleted()
        Task {
            await AppSync.shared.upsertSessionLog(session)
            await AppSync.shared.upsertDayProgress(progressRecord)
        }
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

// MARK: - ArchetypeExplainerSheet
//
// v1.0.10 Phase 6 (2026-06-17) — soft explainer for the four day
// archetypes (Protein / Balanced / Movement / Rest). Surfaces from
// PlanView when the user taps the day archetype pill.
//
// Copy register: lowercase casual, italic Fraunces punch on the
// archetype noun, post-Ozempic vocab (satiety / hunger / softer
// eating), hearts terminal-only, no diet vocab (no "deficit", no
// "earn", no "crush"). The Protein day variant cites the May 2025
// ACLM/ASN/OMA/Obesity Society joint advisory — it's the only
// archetype with a clinical brief behind it. Other archetypes carry
// the brand's structural rationale without over-claiming science.

private struct ArchetypeExplainerSheet: View {

    let archetype: ProgramDayArchetype
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 28)
            eyebrow.padding(.horizontal, Space.lg)
            Spacer().frame(height: 10)
            heroLine.padding(.horizontal, Space.lg)
            Spacer().frame(height: 22)
            subtext.padding(.horizontal, Space.lg)
            Spacer().frame(height: 26)
            focusBlock.padding(.horizontal, Space.lg)
            Spacer()
            citation.padding(.horizontal, Space.lg)
            Spacer().frame(height: 36)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(archetype.rawValue) day explainer")
    }

    @ViewBuilder private var eyebrow: some View {
        HStack(spacing: 6) {
            Image(systemName: archetype.glyphName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.cocoaSecondary.opacity(0.7))
            Text("TODAY")
                .font(.custom("Fraunces72pt-SemiBold", size: 11))
                .foregroundStyle(Palette.textSecondary)
                .kerning(2.4)
        }
    }

    @ViewBuilder private var heroLine: some View {
        let (raw, italic) = archetype.pillCopy
        composedHeroText(raw: raw, italic: italic)
            .foregroundStyle(Palette.cocoaPrimary)
            .multilineTextAlignment(.leading)
    }

    /// Token-walk the pill copy and render the italic punch word in
    /// JeniHeroSerif-Italic 36pt, the rest in JeniHeroSerif-Regular.
    /// Matches the share-card composer so the explainer's hero reads
    /// in the same face as the rest of the her75 surfaces.
    private func composedHeroText(raw: String, italic: String) -> Text {
        let tokens = raw.split(separator: " ", omittingEmptySubsequences: false)
        var out = Text("")
        for (i, rawToken) in tokens.enumerated() {
            let token = String(rawToken)
            let stripped = token
                .lowercased()
                .trimmingCharacters(in: .punctuationCharacters)
            if stripped == italic {
                out = out + Text(token).font(.custom("JeniHeroSerif-Italic", size: 36))
            } else {
                out = out + Text(token).font(.custom("JeniHeroSerif-Regular", size: 36))
            }
            if i < tokens.count - 1 {
                out = out + Text(" ").font(.custom("JeniHeroSerif-Regular", size: 36))
            }
        }
        return out
    }

    @ViewBuilder private var subtext: some View {
        Text(archetype.explainerBody)
            .font(.custom("DMSans-Regular", size: 16))
            .lineSpacing(5)
            .foregroundStyle(Palette.textPrimary.opacity(0.92))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var focusBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY'S FOCUS")
                .font(.custom("Fraunces72pt-SemiBold", size: 11))
                .foregroundStyle(Palette.textSecondary)
                .kerning(2.4)
            Text(archetype.explainerFocus)
                .font(.custom("DMSans-Medium", size: 16))
                .foregroundStyle(Palette.cocoaPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var citation: some View {
        Text(archetype.explainerCitation)
            .font(.custom("Fraunces72pt-Regular", size: 11))
            .italic()
            .foregroundStyle(Palette.textSecondary.opacity(0.85))
            .lineSpacing(3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Archetype explainer copy
//
// Per-archetype copy lives on the ProgramDayArchetype type so the
// sheet stays a pure render of model data — keeps the sheet ~120
// lines instead of ~250 and lets future writers tune the copy in
// one place. Voice-locked per [[feedback-voice-signals]] + post-
// Ozempic vocab per [[feedback-post-ozempic-vocabulary]].

private extension ProgramDayArchetype {

    /// Short paragraph (1–3 sentences) explaining what the archetype
    /// is and why it sits on the rotation. Anti-shame frame; no diet
    /// vocab; hearts saved for the focus line where they land.
    var explainerBody: String {
        switch self {
        case .protein:
            return "protein anchors the day. it steadies satiety, "
                + "protects lean mass while your body changes, and "
                + "carries the work the other days set up."
        case .balanced:
            return "no macro running the show. carbs, protein, fat. "
                + "a little of everything, in the proportions your body "
                + "asks for. variety is the brief."
        case .movement:
            return "strength day. lift, don't just sweat. resistance "
                + "work is what protects muscle while your body changes. "
                + "carbs around the lift, protein still leads the plate."
        case .rest:
            return "softer eating. listen, don't earn. rest is "
                + "recovery, not restriction."
        }
    }

    /// One actionable, brand-aligned focus line. Italic-Fraunces
    /// punch word territory; ends with a heart on the days that
    /// genuinely call for one (protein + rest — the earned-softness
    /// flank).
    var explainerFocus: String {
        switch self {
        case .protein:
            return "aim for protein in every meal. ~1g per pound of "
                + "your goal weight is the soft target ♡"
        case .balanced:
            return "eat what your body's asking for. nothing to "
                + "prove on a balanced day."
        case .movement:
            return "lift today. carbs around the work, protein "
                + "leads dinner — cardio alone won't hold the muscle."
        case .rest:
            return "soup, herbal tea, simple plates. nothing to "
                + "prove ♡"
        }
    }

    /// Short, honest source attribution. Protein day cites the
    /// joint advisory (the only archetype with a clinical brief);
    /// the others carry transparent rationale instead of over-
    /// claiming an evidence base that isn't there.
    var explainerCitation: String {
        switch self {
        case .protein:
            return "based on the may 2025 joint advisory from the "
                + "obesity society + american society for nutrition. "
                + "protein floor: 1.2–2.0g per kg adjusted body weight."
        case .balanced:
            return "no specific clinical brief. variety reduces "
                + "decision fatigue and supports hormonal regulation."
        case .movement:
            return "lean-mass preservation under caloric deficit is "
                + "RCT-grade evidence (Cava 2017, Memelink 2024). "
                + "resistance > cardio for holding muscle."
        case .rest:
            return "post-ozempic-era anti-shame frame. rest ≠ deficit."
        }
    }
}
