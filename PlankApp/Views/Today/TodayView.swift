import SwiftUI
import SwiftData
import Combine
import PlankFood
import PlankSync
import Auth

// MARK: - TodayView
//
// App v2 (docs/app_v2/04_DAILY_PROGRAM.md). The daily coaching
// ritual — the screen the onboarding device demo promised. Top to
// bottom: masthead (day pill · archetype word · date · quiet marks),
// jeni's line of the day, the day strip, today's 3-5 beats, the
// living state band (protein hero · steps · kcal sentence · plates),
// and the evening close after 18:00.
//
// One snapshot (TodayStateService) feeds everything; module covers
// and completion writes live in TodayModuleHost so this file stays
// composition.

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth = AuthService.shared
    @State private var router = AppRouter.shared
    @State private var steps = StepsService.shared

    @State private var snapshot: TodaySnapshot?
    @State private var modules = TodayModuleState()
    /// Day-complete silk sweep (jkSilk). Bumped once when the last
    /// binary beat lands; -1 until the first snapshot so restoring an
    /// already-complete day never replays it.
    @State private var silkTrigger = 0
    @State private var lastCompletedCount = -1

    private var userId: String {
        auth.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        JKScreenChrome {
            ScrollViewReader { proxy in
                scrollBody
                    .onAppear {
                        #if DEBUG
                        if ProcessInfo.processInfo.arguments.contains("--uitest-today-bottom") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                proxy.scrollTo("today.bottom", anchor: .bottom)
                            }
                        }
                        #endif
                    }
            }
        }
        .todayModuleHost(
            state: modules,
            userId: userId,
            snapshot: snapshot,
            onMutation: { refresh() }
        )
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onReceive(FoodLogPersister.changeNotifier) { _ in refresh() }
        .onChange(of: router.pendingRoute) { _, route in
            consume(route)
        }
        .onChange(of: steps.todayCount) { _, count in
            autoCompleteStepsIfCrossed(count)
        }
    }

    private var scrollBody: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    masthead
                        .padding(.top, Space.hero)
                        .jkBeat1()

                    if let snapshot {
                        JKCoachLine(
                            text: snapshot.brief.line,
                            italic: snapshot.brief.italic,
                            onOpenChat: {
                                router.openChat(seed: snapshot.brief.chatSeed)
                            }
                        )
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.lg)
                        .jkBeat2()

                        dayStrip(snapshot)
                            .padding(.top, Space.section)
                            .jkBeat2(extraDelay: 0.05)

                        beats(snapshot)
                            .padding(.horizontal, Space.lg)
                            .padding(.top, Space.section)
                            .jkSilkSweep(trigger: silkTrigger)

                        JKCoachMark(
                            text: "tap a row to begin it. it strikes through when it's done.",
                            seenKey: "jk.mark.beatRow"
                        )
                        .padding(.top, Space.md)

                        // v2.4 — the read-becomes-a-rep chain (one-shot,
                        // set by lesson completion).
                        if let chain = modules.chainSuggestion {
                            JKChainLine(
                                lead: chain.lead,
                                suggestion: chain.text,
                                italic: chain.italic,
                                action: {
                                    modules.chainSuggestion = nil
                                    if let seed = chain.chatSeed {
                                        router.openChat(seed: seed)
                                    } else if let route = chain.route {
                                        router.open(route)
                                    }
                                }
                            )
                            .padding(.horizontal, Space.lg)
                            .padding(.top, Space.sm)
                            .transition(.opacity.combined(with: .offset(y: 6)))
                        }

                        TodayStateBand(
                            snapshot: snapshot,
                            liveSteps: steps.todayCount,
                            onSnap: { modules.present(cover: .captureFlow) },
                            onTapPlate: { _ in router.tab = .becoming }
                        )
                        .padding(.top, Space.section)
                        .jkBeat2(extraDelay: 0.2)

                        if isEvening {
                            EveningClose(
                                snapshot: snapshot,
                                onReflect: { feeling in
                                    storeReflection(feeling)
                                }
                            )
                            .padding(.horizontal, Space.lg)
                            .padding(.top, Space.section)
                            .jkBeat2(extraDelay: 0.25)
                        }
                    }

                    Spacer(minLength: 96)
                        .id("today.bottom")
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { refresh() }
    }

    // MARK: - Masthead

    private var masthead: some View {
        JKMasthead(
            lead: .dayPill(
                day: max(snapshot?.programDay ?? 1, 1),
                note: archetypeNote
            ),
            eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
                .lowercased(),
            marks: [
                JKMastheadMark(systemName: "camera", label: "snap a meal") {
                    modules.present(cover: .captureFlow)
                },
                JKMastheadMark(systemName: "line.3.horizontal", label: "settings") {
                    modules.present(sheet: .profileHub)
                },
            ]
        )
    }

    private var archetypeNote: String? {
        guard let archetype = snapshot?.day?.archetype else { return nil }
        let pill = archetype.pillCopy
        return pill.text
    }

    // MARK: - Strip

    private func dayStrip(_ snapshot: TodaySnapshot) -> some View {
        ProgramDayStrip(
            programDay: snapshot.programDay,
            totalDays: snapshot.totalDays,
            completionByDay: snapshot.completionWindow,
            centeredDay: snapshot.programDay,
            onTap: { day in
                // v1.1.4 — past-day review restored. Past taps open a
                // read-only recap of that day; future taps keep the warm
                // peek (≤ +7) / lock (beyond) behavior unchanged. The
                // strip never moves, so dismissing returns to today.
                // Routing extracted to a pure helper for testability.
                if let sheet = TodayModuleState.stripSheet(
                    for: day, programDay: snapshot.programDay
                ) {
                    modules.present(sheet: sheet)
                }
            }
        )
    }

    // MARK: - Beats

    private func beats(_ snapshot: TodaySnapshot) -> some View {
        VStack(spacing: Space.optionGap) {
            if let day = snapshot.day {
                ForEach(Array(day.beats.enumerated()), id: \.element.itemKey) { idx, beat in
                    JKBeatRow(
                        title: beatTitle(beat),
                        subtitle: beatSubtitle(beat, snapshot: snapshot),
                        thumbAsset: beat.stickerAsset,
                        glyph: beat.stickyGlyph,
                        state: beatState(beat, snapshot: snapshot),
                        isHero: idx == 0,
                        onTap: { modules.open(beat, snapshot: snapshot) },
                        // Progress rows (steps) have no manual override, so
                        // no long-press. Passing nil keeps their tap clean:
                        // JKBeatRow only arms the tap-swallow when a real
                        // long-press handler exists.
                        onLongPress: beat.isProgressRow
                            ? nil
                            : { modules.longPress(beat, snapshot: snapshot) }
                    )
                    .jkBeat2(extraDelay: 0.08 + Double(idx) * Motion.revealStagger)
                }
            }
        }
    }

    private func beatTitle(_ beat: ProgramDayPrescription) -> String {
        switch beat {
        case .snapMeal: return "snap a meal"
        case .workout: return "move"
        case .lesson: return "the method"
        case .steps(let goal): return "\(goal.formatted()) steps"
        case .weighIn: return "trend check"
        case .breath: return "breathe"
        case .plank: return "hold"
        case .water: return "water"
        case .measurements: return "measure"
        }
    }

    private func beatSubtitle(_ beat: ProgramDayPrescription, snapshot: TodaySnapshot) -> String? {
        switch beat {
        case .snapMeal:
            if snapshot.plates.isEmpty {
                if snapshot.day?.archetype == .protein, let target = snapshot.targets.proteinG {
                    return "protein first · aim near \(target)g"
                }
                return "before you eat"
            }
            let n = snapshot.plates.count
            return n == 1 ? "one plate so far" : "\(n) plates so far"
        case .workout(let tier, let minutes, _):
            return "\(minutes) min · \(tierWord(tier))"
        case .lesson:
            return modules.lessonTitle(snapshot: snapshot) ?? "a 2-minute read"
        case .steps:
            return "counted for you"
        case .weighIn:
            if snapshot.day?.weighInIsStaleFallback == true {
                return "been a minute · zero verdicts"
            }
            return CohortStore.isMaintenanceMode
                ? "the weekly trend check"
                : "thirty seconds, then it's done"
        case .breath(let minutes, let style):
            let styleWord = style == .calming ? "calming" : "energizing"
            return "\(minutes) min · \(styleWord)"
        case .plank, .water, .measurements:
            return nil
        }
    }

    private func tierWord(_ tier: IntensityTier) -> String {
        switch tier {
        case .soft: return "gentle"
        case .medium: return "steady"
        case .hard: return "strong"
        }
    }

    private func beatState(_ beat: ProgramDayPrescription, snapshot: TodaySnapshot) -> JKBeatState {
        if case .steps(let goal) = beat {
            let fraction = goal > 0 ? Double(steps.todayCount) / Double(goal) : 0
            return JKBeatState(
                isDone: fraction >= 1,
                isAuto: true,
                progress: min(1, fraction)
            )
        }
        let raw = snapshot.checkStates[beat.itemKey] ?? "empty"
        return JKBeatState(
            isDone: raw == "complete" || raw == "autoCompleted",
            isAuto: raw == "autoCompleted",
            progress: nil
        )
    }

    // MARK: - Evening

    private var isEvening: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-evening") {
            return true
        }
        #endif
        return Calendar.current.component(.hour, from: .now) >= 18
    }

    private func storeReflection(_ feeling: String) {
        UserDefaults.standard.set(
            feeling,
            forKey: "day.reflection.\(TodayStateService.dayKey())"
        )
        Haptics.soft()
    }

    // MARK: - Refresh + routing

    private func refresh() {
        guard !userId.isEmpty else { return }
        let fresh = TodayStateService.snapshot(userId: userId, in: modelContext)
        snapshot = fresh

        // v2.5 — the daily anchor speaks tomorrow's line (once/day).
        if fresh.isEnrolled {
            NotificationOrchestrator.refreshDailyAnchor(
                programDay: fresh.programDay,
                totalDays: fresh.totalDays
            )
        }

        // The day-complete moment: every binary beat landed. Fires
        // once per crossing (never on restore — the first snapshot
        // only records the baseline).
        if let day = fresh.day {
            let binaryTotal = day.beats.filter { $0.itemKey != "steps" }.count
            let done = fresh.completedBeatCount
            if lastCompletedCount >= 0,
               done >= binaryTotal, binaryTotal > 0,
               lastCompletedCount < binaryTotal {
                silkTrigger += 1
            }
            lastCompletedCount = done
        }
    }

    private func consume(_ route: AppRouter.Route?) {
        guard let route else { return }
        router.pendingRoute = nil
        switch route {
        case .snap: modules.present(cover: .captureFlow)
        case .weighIn: modules.present(sheet: .logWeight)
        case .lesson: modules.openLesson(snapshot: snapshot)
        case .breath: modules.present(cover: .breathSession)
        case .trend: break   // becoming's route; not ours
        }
    }

    /// Steps crossing the goal writes an autoCompleted check ONCE per
    /// day so the strip's completed-count sees the anchor land.
    private func autoCompleteStepsIfCrossed(_ count: Int) {
        guard
            let snapshot, let day = snapshot.day,
            case .steps(let goal)? = day.beats.first(where: {
                if case .steps = $0 { return true } else { return false }
            }),
            count >= goal,
            (snapshot.checkStates["steps"] ?? "empty") == "empty"
        else { return }
        _ = ProgramService.shared.markChecklistItem(
            prescription: .steps(goal: goal),
            state: .autoCompleted,
            userId: userId,
            in: modelContext
        )
        refresh()
    }
}
