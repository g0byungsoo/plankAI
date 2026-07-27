import SwiftUI
import SwiftData
import Combine
import PlankFood
import PlankSync
import Auth
import RevenueCat

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
    /// v6 — increments when a plate lands via the capture cover; the
    /// food band celebrates on change.
    @State private var plateLandedPulse = 0
    /// v6.5 — the day-6 weekly→quarterly upgrade moment. Shown at
    /// most once per install; the flag is set only after a successful
    /// preflight so a pricing outage never burns the one showing.
    @State private var showUpgradeMoment = false
    @AppStorage("upgradeMoment.shownV1") private var upgradeMomentShown = false
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
                        // v6 — fire THE LANDED moment without a camera
                        // pass (sweep + line + swell on the food band).
                        if ProcessInfo.processInfo.arguments.contains("--uitest-land-plate") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                                plateLandedPulse += 1
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
        .onAppear {
            refresh()
            maybeOfferUpgradeMoment()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        // v6 — THE LANDED moment: when the capture cover closes and a
        // plate just persisted, the food band celebrates the action
        // (silk sweep + receipt line + haptic swell). Inline, never a
        // popup; the founder-named gap after logging.
        .onChange(of: modules.activeCover) { old, new in
            guard old == .captureFlow, new == nil else { return }
            refresh()
            if let newest = snapshot?.plates.last,
               Date.now.timeIntervalSince(newest.loggedAt) < 120 {
                plateLandedPulse += 1
            }
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
        // v6.5 — the day-6 weekly→quarterly moment (one showing,
        // founder memo #3 in docs/app_v6/03_CONVERSION.md).
        .fullScreenCover(isPresented: $showUpgradeMoment) {
            UpgradeMomentView(
                programDay: snapshot?.programDay ?? 0,
                receipt: upgradeReceipt,
                onDone: { showUpgradeMoment = false }
            )
        }
    }

    // MARK: - The day-6 upgrade moment (v6.5)

    /// Her first week, as receipt rows the moment can show — computed
    /// from stores this view already reads. Provenance-only.
    private var upgradeReceipt: [(String, String)] {
        var rows: [(String, String)] = []
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let plates = FoodLogPersister.allEntries(userId: userId)
            .filter { $0.loggedAt >= weekAgo }
        if !plates.isEmpty {
            rows.append(("plates logged", "\(plates.count)"))
        }
        if let week = KitchenSignal.liveWeekStory(userId: userId),
           week.narratedCount > 0 {
            rows.append(("overnight fasts measured", "\(week.narratedCount)"))
        }
        if snapshot?.latestWeightKg != nil,
           let daysAgo = snapshot?.lastWeighInDaysAgo, daysAgo <= 7 {
            rows.append(("weighed in", "this week"))
        }
        return rows
    }

    /// Present once: weekly subscriber + day 6 or later + no cover in
    /// flight + the visible tab. The AppStorage flag is set HERE (not
    /// in the view) only when presentation actually fires.
    private func maybeOfferUpgradeMoment() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-upgrade-moment") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showUpgradeMoment = true
            }
            return
        }
        #endif
        guard !upgradeMomentShown,
              router.tab == .today,
              PaymentService.shared.activeProductIsWeekly,
              (snapshot?.programDay ?? 0) >= 6,
              modules.activeCover == nil
        else { return }
        Task {
            // Preflight: the quarter must price before the one showing
            // is spent (a pricing outage keeps the moment for later).
            guard Purchases.isConfigured,
                  let offerings = try? await Purchases.shared.offerings() else { return }
            #if DEBUG
            let offering = offerings.all[RevenueCatConfig.previewOfferingID] ?? offerings.current
            #else
            let offering = offerings.current
            #endif
            let hasQuarter = offering?.availablePackages.contains {
                $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.quarterly
            } ?? false
            guard hasQuarter, !upgradeMomentShown, router.tab == .today,
                  modules.activeCover == nil else { return }
            upgradeMomentShown = true
            showUpgradeMoment = true
        }
    }

    private var scrollBody: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    masthead
                        .padding(.top, Space.hero)
                        .jkBeat1()

                    if let snapshot {
                        // THE POSITION LINE (v7 §1) — the rail's
                        // seven ambiguous dots died; one quiet line
                        // carries where she is, and opens the journey.
                        if snapshot.isEnrolled, let intent = snapshot.weekIntent {
                            positionLine(snapshot, intent: intent)
                                .padding(.horizontal, Space.lg)
                                .padding(.top, Space.sm)
                                .jkBeat2(extraDelay: 0.04)
                        }

                        // THE UNDERSTANDING (v7 §1) — the reading is
                        // the page's reason: one calm observation of
                        // her current state, spoken in full. The tap
                        // opens the full note.
                        JKCoachLine(
                            text: snapshot.brief.line,
                            italic: snapshot.brief.italic,
                            second: snapshot.brief.second,
                            secondItalic: snapshot.brief.secondItalic,
                            mechanism: snapshot.brief.mechanism,
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

                            TodayStateBand(snapshot: snapshot, landedPulse: plateLandedPulse)
                                .padding(.top, Space.section)
                                .jkBeat2(extraDelay: 0.2)

                            // v6 — THE SIGNALS: the passive layer
                            // (overnight window / last night / moves
                            // after plates). Zero input, receipts
                            // only; collapses to nothing without data.
                            TodaySignalsBand(snapshot: snapshot)
                                .padding(.top, Space.section)
                                .jkBeat2(extraDelay: 0.28)

                            // v7 — the one-time cycle offer sits at
                            // the day's foot, outside received care.
                            TodayCycleAsk()
                                .padding(.horizontal, Space.lg)
                                .padding(.top, Space.section)

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

    // MARK: - The day (v7: the care plan / evening receipt)

    /// Day shape (docs/app_v7 §1): the lead move as the one elevated
    /// card, supporting moves as ringed rows, offered moves as quiet
    /// invitations — composed by CarePlanEngine, not slot tables.
    /// After 18:00 the receipt leads and open moves soften into
    /// "still open" rows.
    @ViewBuilder
    private func dayContent(_ snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEvening {
                EveningClose(
                    snapshot: snapshot,
                    onReflect: { feeling in
                        storeReflection(feeling)
                    }
                )
                planRows(snapshot, includeLead: true)
                    .padding(.top, Space.section)
                    .jkSilkSweep(trigger: silkTrigger)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if let lead = snapshot.carePlan.lead {
                        JKOneThingCard(
                            title: oneThingTitle(lead.beat, snapshot: snapshot).text,
                            italic: oneThingTitle(lead.beat, snapshot: snapshot).italic,
                            subtitle: lead.because
                                ?? oneThingSubtitle(lead.beat, snapshot: snapshot),
                            sealAsset: lead.beat.stickerAsset,
                            isDone: beatState(lead.beat, snapshot: snapshot).isDone,
                            onTap: { modules.open(lead.beat, snapshot: snapshot) },
                            onLongPress: { modules.longPress(lead.beat, snapshot: snapshot) }
                        )
                    } else {
                        JKOneThingCard(
                            title: snapshot.carePlan.tone == .gentle
                                ? "a quiet day. nothing owed \u{2665}\u{FE0E}"
                                : "rest day. nothing scheduled \u{2665}\u{FE0E}",
                            italic: snapshot.carePlan.tone == .gentle ? ["quiet"] : ["rest"],
                            isPermission: true
                        )
                    }
                    planRows(snapshot, includeLead: false)
                        .padding(.top, Space.md)
                }
                .jkSilkSweep(trigger: silkTrigger)
            }
        }
    }

    /// The plan's rows (v7 ring policy): supporting moves wear the
    /// ring — they are part of today's plan; offered moves render as
    /// quiet invitations, never debt, never counted. Observations
    /// (steps, the overnight window, sleep) live in the noticed band,
    /// not here.
    @ViewBuilder
    private func planRows(_ snapshot: TodaySnapshot, includeLead: Bool) -> some View {
        let plan = snapshot.carePlan
        let leadRow: [CarePlanEngine.Move] = includeLead
            ? (plan.lead.map { [$0] } ?? [])
            : []
        let ringed = leadRow + plan.supporting

        VStack(spacing: 0) {
            ForEach(Array(ringed.enumerated()), id: \.element.beat.itemKey) { idx, move in
                VStack(spacing: 0) {
                    if idx > 0 {
                        Rectangle()
                            .fill(Palette.hairlineCocoa)
                            .frame(height: 0.5)
                    }
                    moveRow(move, snapshot: snapshot, ring: true)
                }
                .jkBeat2(extraDelay: 0.08 + Double(idx) * Motion.revealStagger)
            }

            ForEach(Array(plan.offered.enumerated()), id: \.element.beat.itemKey) { idx, move in
                VStack(spacing: 0) {
                    if idx > 0 || !ringed.isEmpty {
                        Rectangle()
                            .fill(Palette.hairlineCocoa)
                            .frame(height: 0.5)
                    }
                    moveRow(move, snapshot: snapshot, ring: false)
                        .opacity(0.88)
                }
                .jkBeat2(extraDelay: 0.14 + Double(ringed.count + idx) * Motion.revealStagger)
            }
        }
    }

    private func moveRow(
        _ move: CarePlanEngine.Move, snapshot: TodaySnapshot, ring: Bool
    ) -> some View {
        JKRhythmRow(
            title: beatTitle(move.beat),
            note: moveNote(move, snapshot: snapshot, ring: ring),
            mark: JKMarkKind.mark(for: move.beat),
            state: beatState(move.beat, snapshot: snapshot),
            showsCheckRing: ring,
            onTap: { modules.open(move.beat, snapshot: snapshot) },
            onLongPress: move.beat.isProgressRow
                ? nil
                : { modules.longPress(move.beat, snapshot: snapshot) }
        )
    }

    /// A move's row note: in the evening an open plan move answers
    /// the only question that hour asks ("is it done?"); otherwise
    /// the engine's reason wins; offered rows carry the invitation.
    private func moveNote(
        _ move: CarePlanEngine.Move, snapshot: TodaySnapshot, ring: Bool
    ) -> String? {
        if isEvening,
           ring,
           !beatState(move.beat, snapshot: snapshot).isDone {
            return "still open"
        }
        if let because = move.because { return because }
        if !ring {
            let base = beatSubtitle(move.beat, snapshot: snapshot)
            return base.map { "\($0) · if it fits today" } ?? "if it fits today"
        }
        return beatSubtitle(move.beat, snapshot: snapshot)
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
                // v6.3 first session: "next plate" defers the ask past
                // the session boundary; "the last thing you ate" is
                // answerable RIGHT NOW.
                if snapshot.programDay <= 2 {
                    return ("snap the last thing you ate", ["last"])
                }
                return ("snap your first plate", ["first"])
            }
            return ("snap the next plate", ["next"])
        case .workout(_, let minutes, _):
            return ("move for \(minutes) minutes", ["move"])
        case .lesson:
            return ("today's 2-minute lesson", ["lesson"])
        case .weighIn:
            return ("weigh in", ["weigh"])
        case .breath:
            return ("60 seconds of breath", ["60 seconds"])
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
            if n == 0 {
                // v6.3 pre-forgiveness: plate shame + unclear payoff
                // are the first-snap blockers — kill both in the ask.
                return snapshot.programDay <= 2
                    ? "even coffee counts. no grading here \u{2665}\u{FE0E}"
                    : "one photo · calories counted"
            }
            return n == 1 ? "1 plate logged" : "\(n) plates logged"
        case .workout(let tier, _, _):
            return "\(tierWord(tier)) · pause or end anytime"
        case .lesson:
            return modules.lessonTitle(snapshot: snapshot) ?? "a 2-minute read"
        case .weighIn:
            if snapshot.day?.weighInIsStaleFallback == true {
                return "first one in a while · 30 seconds"
            }
            return snapshot.chapter == .keeping
                ? "weekly check"
                : "30 seconds"
        case .breath:
            return "1 minute · that's it"
        case .steps, .plank, .water, .measurements:
            return nil
        }
    }

    // MARK: - Position line (v7 — the rail's successor)

    /// One quiet line of place: the named week + the fraction, and
    /// the door to the journey. Seven ambiguous dots became eleven
    /// legible words.
    private func positionLine(_ snapshot: TodaySnapshot, intent: WeekIntentSpec) -> some View {
        Button {
            Haptics.soft()
            router.tab = .becoming
        } label: {
            HStack(spacing: 6) {
                Text(intent.name)
                    .font(.custom("JeniHeroSerif-Italic", size: 16, relativeTo: .callout))
                    .foregroundStyle(Palette.textPrimary)
                Text("· week \(snapshot.programWeek) of \(max(snapshot.totalWeeks, 1))")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("\(intent.name), week \(snapshot.programWeek) of \(max(snapshot.totalWeeks, 1))")
        .accessibilityHint("opens your journey")
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
            return "auto-tracked"
        case .weighIn:
            if snapshot.day?.weighInIsStaleFallback == true {
                return "first one in a while · 30 seconds"
            }
            return CohortStore.isMaintenanceMode
                ? "weekly check"
                : "30 seconds"
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

        // The day-complete moment: every plan move landed. Fires
        // once per crossing (never on restore — the first snapshot
        // only records the baseline). v7: the plan's asks are the
        // day, so the silk answers the plan, not the slot tables.
        let planTotal = fresh.carePlan.actionableBeats.count
        let done = fresh.completedBeatCount
        if lastCompletedCount >= 0,
           done >= planTotal, planTotal > 0,
           lastCompletedCount < planTotal {
            silkTrigger += 1
        }
        lastCompletedCount = done
    }

    private func consume(_ route: AppRouter.Route?) {
        guard let route else { return }
        router.pendingRoute = nil
        switch route {
        case .snap: modules.present(cover: .captureFlow)
        case .weighIn: modules.present(sheet: .logWeight)
        case .lesson: modules.openLesson(snapshot: snapshot)
        case .breath: modules.present(cover: .breathSession)
        case .workout:
            // The chat plan-card's move row — open today's session
            // with the day's actual parameters.
            if let day = snapshot?.day,
               let beat = day.beats.first(where: {
                   if case .workout = $0 { return true } else { return false }
               }) {
                modules.open(beat, snapshot: snapshot)
            }
        case .steps: modules.present(sheet: .stepsDetail)
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

// v7: HowItWorksBlock deleted — a Home that leads with the reading
// and a ≤3-move plan teaches its own contract (docs/app_v7 §1).
