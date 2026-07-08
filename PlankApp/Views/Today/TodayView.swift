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
    /// A rail day tap → that day's receipt (the week entry loads on
    /// demand; the sheet opens straight onto the day page).
    @State private var railWeek: JourneyModel.WeekEntry?
    @State private var railDay: Int?
    /// Day-complete silk sweep (jkSilk). Bumped once when the last
    /// binary beat lands; -1 until the first snapshot so restoring an
    /// already-complete day never replays it.
    @State private var silkTrigger = 0
    @State private var lastCompletedCount = -1
    /// First-use teaching (v5.1): the three-row map under the day-one
    /// reading. Days 1–2 only; one tap retires it forever. Swept on
    /// sign-out with the other user-scoped keys.
    @AppStorage("howItWorks.dismissed") private var howItWorksDismissed = false
    /// v5.1 — a tapped plate opens its own page (the strip used to
    /// dump her on the becoming tab; now the meal explains itself).
    @State private var detailPlate: FoodLogPersister.FoodLogEntry?

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
                        // v5.1 — screenshot the plate detail without a
                        // tap (first plate of the day).
                        if ProcessInfo.processInfo.arguments.contains("--uitest-plate-detail") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                detailPlate = snapshot?.plates.first
                            }
                        }
                        // v5.1 — the gentle five's preview, no taps.
                        if ProcessInfo.processInfo.arguments.contains("--uitest-gentle-preview") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                modules.shrinkWorkoutToFloor()
                            }
                        }
                        // 1.1.5 — open the breath intro for the chip audit.
                        if ProcessInfo.processInfo.arguments.contains("--uitest-breath-preview") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                modules.present(cover: .breathSession)
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
        .sheet(item: $detailPlate) { plate in
            PlateDetailSheet(
                entry: plate,
                userId: userId,
                onDismiss: { detailPlate = nil }
            )
            .presentationDetents([.large])
            .presentationBackground(Palette.bgPrimary)
        }
        .sheet(item: $railWeek) { entry in
            JourneyWeekPage(
                entry: entry,
                snapshot: snapshot ?? TodayStateService.snapshot(userId: userId, in: modelContext),
                userId: userId,
                onAskJeni: { seed in
                    railWeek = nil
                    router.openChat(seed: seed)
                },
                onDismiss: { railWeek = nil },
                initialProgramDay: railDay
            )
            .presentationDetents([.large])
            .presentationBackground(Palette.bgPrimary)
        }
    }

    /// The rail's day tap: load this week's entry once, open the
    /// sheet directly on that day's receipt.
    private func openRailDay(_ programDay: Int) {
        guard let snapshot else { return }
        let model = JourneyModel.load(userId: userId, snapshot: snapshot, in: modelContext)
        guard let current = model.currentWeek else { return }
        railDay = programDay
        railWeek = current
    }

    private var scrollBody: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    masthead
                        .padding(.top, Space.hero)
                        .jkBeat1()

                    if let snapshot {
                        // THE DAY RAIL (v5 re-steer) — the program
                        // week she can read and touch: past days open
                        // their receipts, the caption opens the
                        // journey. The calendar-strip answer.
                        if snapshot.isEnrolled, snapshot.weekIntent != nil {
                            JKDayRail(
                                snapshot: snapshot,
                                onOpen: { router.tab = .becoming },
                                onOpenDay: { day in openRailDay(day) }
                            )
                            .padding(.horizontal, Space.lg)
                            .padding(.top, Space.md)
                            .jkBeat2(extraDelay: 0.04)
                        }

                        // JENI'S LINE — one sentence, no card, no
                        // chrome (the minimal correction). The full
                        // note opens as a received full-screen moment.
                        JKCoachLine(
                            text: snapshot.brief.line,
                            italic: snapshot.brief.italic,
                            affordanceLabel: "from jeni",
                            onOpenChat: {
                                modules.present(cover: .jeniNote)
                            }
                        )
                        .accessibilityIdentifier("jeni.line")
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.lg)
                        .jkBeat2()

                        if snapshot.isOnBreak {
                            JKBreakCard(onReturn: {
                                BreakState.end()
                                refresh()
                            })
                            .padding(.horizontal, Space.lg)
                            .padding(.top, Space.section)
                            .jkBeat2(extraDelay: 0.1)
                        } else {
                            // FIRST-USE TEACHING — the map, once. The
                            // day-one reading teaches the contract in
                            // one line; this names the three doors in
                            // receipt grammar. Days 1–2, then gone.
                            if snapshot.isEnrolled,
                               snapshot.programDay <= 2,
                               !howItWorksDismissed {
                                HowItWorksBlock(onDismiss: {
                                    withAnimation(Motion.entranceSoft) {
                                        howItWorksDismissed = true
                                    }
                                })
                                .padding(.horizontal, Space.lg)
                                .padding(.top, Space.section)
                                .jkBeat2(extraDelay: 0.06)
                                .transition(.opacity.combined(with: .offset(y: 6)))
                            }

                            // NOTE: the silk layer effect lives INSIDE
                            // dayContent on the card+rows subtree only —
                            // a layerEffect ancestor over EveningClose's
                            // TextField renders SwiftUI's yellow
                            // uncomposable-view placeholder.
                            dayContent(snapshot)
                                .padding(.horizontal, Space.lg)
                                .padding(.top, Space.section)

                            // v2.4 — the read-becomes-a-rep chain
                            // (one-shot, set by lesson completion).
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

                            TodayStateBand(snapshot: snapshot)
                                .padding(.top, Space.section)
                                .jkBeat2(extraDelay: 0.2)

                            // The evening ends on her words.
                            if isEvening {
                                EveningJournalLine(snapshot: snapshot)
                                    .padding(.horizontal, Space.lg)
                                    .padding(.top, Space.section)
                            }
                        }
                    }

                    Spacer(minLength: 96)
                        .id("today.bottom")
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { refresh() }
            // Scrolled content fades under the status bar instead of
            // colliding with the clock (the v3 masthead scrim).
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Palette.bgPrimary, Palette.bgPrimary.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 54)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
    }

    // MARK: - The day (one thing + rhythm / evening receipt)

    /// Day shape: the one thing leads, the rhythm follows as hairline
    /// rows. After 18:00 the receipt leads and every remaining beat
    /// (the one thing included) softens into "still open" rows.
    @ViewBuilder
    private func dayContent(_ snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEvening {
                // v4 order (03_FEATURES §9): the receipt reads, the
                // rows stay reachable; the journal closes the page
                // after the plate story (mounted by the parent).
                EveningClose(
                    snapshot: snapshot,
                    onReflect: { feeling in
                        storeReflection(feeling)
                    }
                )
                rhythmRows(snapshot, includeOneThing: true)
                    .padding(.top, Space.section)
                    .jkSilkSweep(trigger: silkTrigger)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if let one = snapshot.day?.oneThing {
                        JKOneThingCard(
                            title: oneThingTitle(one, snapshot: snapshot).text,
                            italic: oneThingTitle(one, snapshot: snapshot).italic,
                            subtitle: oneThingSubtitle(one, snapshot: snapshot),
                            sealAsset: one.stickerAsset,
                            isDone: beatState(one, snapshot: snapshot).isDone,
                            onTap: { modules.open(one, snapshot: snapshot) },
                            onLongPress: { modules.longPress(one, snapshot: snapshot) }
                        )
                    } else {
                        JKOneThingCard(
                            title: "nothing owed today. a walk if you want it \u{2665}\u{FE0E}",
                            italic: ["nothing owed"],
                            isPermission: true
                        )
                    }
                    rhythmRows(snapshot, includeOneThing: false)
                        .padding(.top, Space.md)
                }
                .jkSilkSweep(trigger: silkTrigger)
            }
        }
    }

    /// The rhythm: every non-hero beat as a quiet hairline row.
    @ViewBuilder
    private func rhythmRows(_ snapshot: TodaySnapshot, includeOneThing: Bool) -> some View {
        if let day = snapshot.day {
            let rows = rhythmBeats(day: day, includeOneThing: includeOneThing)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.itemKey) { idx, beat in
                    VStack(spacing: 0) {
                        if idx > 0 {
                            Rectangle()
                                .fill(Palette.hairlineCocoa)
                                .frame(height: 0.5)
                        }
                        JKRhythmRow(
                            title: beatTitle(beat),
                            note: rhythmNote(beat, snapshot: snapshot),
                            sticker: beat.stickerAsset.map {
                                (asset: $0, tile: stickyTile(beat.stickyColorKind))
                            },
                            mark: JKMarkKind.mark(for: beat),
                            state: beatState(beat, snapshot: snapshot),
                            liveTrailing: liveTrailing(beat),
                            onTap: { modules.open(beat, snapshot: snapshot) },
                            onLongPress: beat.isProgressRow
                                ? nil
                                : { modules.longPress(beat, snapshot: snapshot) }
                        )
                    }
                    .jkBeat2(extraDelay: 0.08 + Double(idx) * Motion.revealStagger)
                }
            }
        }
    }

    /// The rows the rhythm renders. Breathwork is an always-reachable
    /// reset: when the day's prescription didn't already call for it
    /// (rest-day hero / high-stress companion), we surface it as the
    /// final quiet row so it's never more than a tap from home. We build
    /// a LOCAL list — the day's completion math reads `day.beats`, so an
    /// appended reset never inflates the day's required count.
    private func rhythmBeats(day: PrescriptionEngineV2.Day, includeOneThing: Bool) -> [ProgramDayPrescription] {
        let base = includeOneThing ? day.beats : day.rhythm
        let dayHasBreath = day.beats.contains { if case .breath = $0 { return true } else { return false } }
        guard !dayHasBreath else { return base }
        return base + [.breath(minutes: 1, style: isEvening ? .calming : .energizing)]
    }

    private func liveTrailing(_ beat: ProgramDayPrescription) -> String? {
        if case .steps = beat {
            // A cold "0" reads like a grade; the note ("counted for
            // you") carries the row until HealthKit has something.
            let count = steps.todayCount
            return count > 0 ? count.formatted() : nil
        }
        return nil
    }

    /// Evening note for a still-open one thing; otherwise the beat's
    /// standard note.
    private func rhythmNote(_ beat: ProgramDayPrescription, snapshot: TodaySnapshot) -> String? {
        if isEvening,
           beat.itemKey == snapshot.day?.oneThing?.itemKey,
           !beatState(beat, snapshot: snapshot).isDone {
            return "still open, no pressure"
        }
        return beatSubtitle(beat, snapshot: snapshot)
    }

    // MARK: - One-thing copy (ask-shaped, provenance-backed)

    private func oneThingTitle(
        _ beat: ProgramDayPrescription, snapshot: TodaySnapshot
    ) -> (text: String, italic: [String]) {
        switch beat {
        case .snapMeal:
            if snapshot.chapter == .onMedication {
                return ("one gentle plate, protein first", ["protein first"])
            }
            if snapshot.plates.isEmpty {
                return ("snap your first plate", ["first"])
            }
            return ("snap the next plate", ["next"])
        case .workout(_, let minutes, _):
            return ("move for \(minutes) minutes", ["move"])
        case .lesson:
            return ("two minutes with the method", ["method"])
        case .weighIn:
            return ("the trend check", ["trend"])
        case .breath:
            return ("sixty seconds of breath", ["sixty seconds"])
        case .steps, .plank, .water, .measurements:
            return (beatTitle(beat), [])
        }
    }

    private func oneThingSubtitle(
        _ beat: ProgramDayPrescription, snapshot: TodaySnapshot
    ) -> String? {
        switch beat {
        case .snapMeal:
            if snapshot.chapter == .onMedication, let target = snapshot.targets.proteinG {
                return "small plates count double · aim near \(target)g"
            }
            if snapshot.day?.archetype == .protein, let target = snapshot.targets.proteinG {
                return "protein first · aim near \(target)g"
            }
            let n = snapshot.plates.count
            return n == 0 ? "one photo · we read the plate"
                          : (n == 1 ? "one plate so far" : "\(n) plates so far")
        case .workout(let tier, _, _):
            return "\(tierWord(tier)) · pause or end anytime"
        case .lesson:
            return modules.lessonTitle(snapshot: snapshot) ?? "a 2-minute read"
        case .weighIn:
            if snapshot.day?.weighInIsStaleFallback == true {
                return "been a minute · zero verdicts"
            }
            return snapshot.chapter == .keeping
                ? "the weekly trend check"
                : "thirty seconds, then it's done"
        case .breath:
            return "that's the whole assignment \u{2665}\u{FE0E}"
        case .steps, .plank, .water, .measurements:
            return nil
        }
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
                // v5: snap is the hero action — it wears the filled
                // pill (the quiet mark undersold the app's signature).
                JKMastheadMark(systemName: "camera", label: "snap a meal", prominent: true) {
                    modules.present(cover: .captureFlow)
                },
                JKMastheadMark(systemName: "line.3.horizontal", label: "settings") {
                    modules.present(sheet: .profileHub)
                },
            ],
            // v4: the pill opens THE JOURNEY (the her-days dead-end
            // sheet died with the plan-over-time rebuild).
            onLeadTap: snapshot?.isEnrolled == true
                ? { router.tab = .becoming }
                : nil
        )
    }

    private var archetypeNote: String? {
        if snapshot?.isOnBreak == true {
            return "on a break \u{2665}\u{FE0E}"
        }
        // Keeping chapter: the masthead speaks the band (the week
        // frame), not the day archetype.
        if snapshot?.chapter == .keeping, let zone = snapshot?.bandZone {
            switch zone {
            case BandZone.steady.rawValue: return "inside your band \u{2665}\u{FE0E}"
            case BandZone.drifting.rawValue: return "a steadying week"
            case BandZone.reset.rawValue: return "a reset week, held"
            default: break
            }
        }
        guard let archetype = snapshot?.day?.archetype else { return nil }
        let pill = archetype.pillCopy
        return pill.text
    }

    // v4: the week ribbon above is Home's thread to the plan; the
    // pill and the ribbon both open THE JOURNEY (becoming's ledger).

    // MARK: - Beat copy

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
            // v5: a lesson title alone ("your inner critic has a
            // script") reads as a context-free claim on the row —
            // the time frame makes it legible as today's topic.
            return modules.lessonTitle(snapshot: snapshot).map { "2 min · \($0)" }
                ?? "a 2-minute practice"
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

    private func stickyTile(_ kind: ProgramDayPrescription.StickyColor) -> Color {
        switch kind {
        case .mint: return Palette.stickyMint
        case .butter: return Palette.stickyButter
        case .rose: return Palette.stickyRose
        case .olive: return Palette.stickyOlive
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
        // Deterministic day-layout captures + walker runs after 18:00
        // local (the evening flip is wall-clock; QA must not be).
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-day") {
            return false
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

// MARK: - HowItWorksBlock (first-use teaching)
//
// The ritual named once, in the app's own receipt grammar — not a
// tour, not cards. Three rows answer the only day-one questions:
// how food gets counted, what today asks of her, where progress
// lives. "got it" retires it forever (howItWorks.dismissed).

private struct HowItWorksBlock: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("how this works")
                .font(Typo.captionTracked)
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.bottom, 6)

            JKReceiptRow(
                lead: "snap a plate",
                punch: "i read the calories for you",
                punchItalic: ["calories"],
                showsRule: false
            )
            JKReceiptRow(
                lead: "the one thing",
                punch: "one card a day. do just that",
                punchItalic: ["just that"]
            )
            JKReceiptRow(
                lead: "becoming",
                punch: "your story, one swipe at a time",
                punchItalic: ["story"]
            )

            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Text("got it")
                        .font(.custom("DMSans-Medium", size: 13))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(JKPress())
                .accessibilityHint("hides this guide")
            }
            .padding(.top, 2)
        }
    }
}
