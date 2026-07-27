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
    /// v7.4 — the day's letter presents once (the one-time
    /// information moment); this remembers which day received it.
    @AppStorage("letter.presentedDayKey") private var letterPresentedDayKey = ""

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
            maybePresentLetter()
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
                        // Mission 2: the whisper died with the
                        // truncation law — the dateline is the
                        // letter's door now, and the day opens
                        // straight onto its act.

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
                                // The develop reads top-down: the
                                // whisper (beat 2) lands before the
                                // ask follows it.
                                .jkBeat2(extraDelay: 0.08)

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

                            // Mission 2.1 (the no-scroll law): after
                            // 18:00 the page IS the close — the
                            // day-state bands yield until morning
                            // (the receipt's "the plan · N of M"
                            // already carries the day), so the
                            // evening composes to one screen.
                            if !isEvening {
                                TodayStateBand(snapshot: snapshot, landedPulse: plateLandedPulse)
                                    .padding(.top, Space.section)
                                    .jkBeat2(extraDelay: 0.2)

                                // v6 — THE SIGNALS: the passive layer
                                // (overnight window / last night /
                                // moves after plates). Zero input,
                                // receipts only; collapses to
                                // nothing without data.
                                TodaySignalsBand(snapshot: snapshot)
                                    .padding(.top, Space.section)
                                    .jkBeat2(extraDelay: 0.28)
                            }

                            // Mission 2 (02_VISUAL.md §5): the cycle
                            // banner is dead on the ceremony — the
                            // ask relocates to the profile hub in a
                            // later pass (TodayCycleAsk survives for
                            // it).

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
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if let lead = snapshot.carePlan.lead {
                        KeptLine(
                            title: oneThingTitle(lead.beat, snapshot: snapshot).text,
                            italic: oneThingTitle(lead.beat, snapshot: snapshot).italic,
                            reason: lead.because
                                ?? oneThingSubtitle(lead.beat, snapshot: snapshot),
                            isLead: true,
                            isKept: beatState(lead.beat, snapshot: snapshot).isDone,
                            onOpen: { modules.open(lead.beat, snapshot: snapshot) },
                            onSign: { kept in setDone(lead.beat, done: kept) }
                        )
                    } else {
                        permissionLine(
                            snapshot.carePlan.tone == .gentle
                                ? "a quiet day. nothing owed \u{2665}\u{FE0E}"
                                : "rest day. nothing scheduled \u{2665}\u{FE0E}",
                            italic: snapshot.carePlan.tone == .gentle ? ["quiet"] : ["rest"]
                        )
                    }
                    planRows(snapshot, includeLead: false)
                        .padding(.top, Space.sm)
                }
            }
        }
    }

    @ViewBuilder
    private func permissionLine(_ text: String, italic: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Palette.cocoaPrimary.opacity(0.35))
                .frame(width: 28, height: 2)
            ItalicAccentText(
                text,
                italic: italic,
                baseFont: .custom("JeniHeroSerif-Regular", size: 27, relativeTo: .title2),
                italicFont: .custom("JeniHeroSerif-Italic", size: 27, relativeTo: .title2),
                color: Palette.textPrimary,
                alignment: .leading
            )
            .lineSpacing(-3)
            .kerning(-0.3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
            // THE KEPT LINES (mission 2): each plan move is a bare
            // serif line that she countersigns with a hold — the
            // signature interaction (02_VISUAL.md §3).
            ForEach(Array(ringed.enumerated()), id: \.element.beat.itemKey) { idx, move in
                KeptLine(
                    title: beatTitle(move.beat),
                    reason: moveNote(move, snapshot: snapshot, ring: true),
                    isKept: beatState(move.beat, snapshot: snapshot).isDone,
                    onOpen: { modules.open(move.beat, snapshot: snapshot) },
                    onSign: { kept in setDone(move.beat, done: kept) }
                )
                .jkBeat2(extraDelay: 0.08 + Double(idx) * Motion.revealStagger)
            }

            // Invitations stay unsigned ghosts — no hairline, no
            // seal, never counted (SDT law: contingency only where
            // she chose).
            ForEach(Array(plan.offered.enumerated()), id: \.element.beat.itemKey) { idx, move in
                Button {
                    Haptics.light()
                    modules.open(move.beat, snapshot: snapshot)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(beatTitle(move.beat))
                            .font(.custom("JeniHeroSerif-Regular", size: 21, relativeTo: .title3))
                            .foregroundStyle(Palette.textPrimary.opacity(0.42))
                        if let note = moveNote(move, snapshot: snapshot, ring: false) {
                            Text(note)
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary.opacity(0.7))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
                .accessibilityLabel("\(beatTitle(move.beat)), if it fits today")
                .jkBeat2(extraDelay: 0.14 + Double(ringed.count + idx) * Motion.revealStagger)
            }
        }
    }

    /// One tap on the radio = kept (the onboarding crossOff feel);
    /// tap again = undo. The MarkAsDoneSheet stays on long-press for
    /// the granular override.
    private func setDone(_ beat: ProgramDayPrescription, done: Bool) {
        _ = ProgramService.shared.markChecklistItem(
            prescription: beat,
            state: done ? .complete : .empty,
            userId: userId,
            in: modelContext
        )
        if done {
            ActivationHaptics.shared.crossOff()
        } else {
            Haptics.soft()
        }
        refresh()
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

    // v7.3: the position line lives in the masthead's second eyebrow
    // (founder: program identity must be instant). The foot version
    // was deleted.

    // MARK: - The whisper + the letter (v7.4)

    // Mission 2: jeniWhisper deleted — the truncation law
    // (02_VISUAL.md §1.7). The dateline is the letter's door.

    /// The day's letter presents itself ONCE — the first open of the
    /// day receives it full-screen (the one-time information moment);
    /// every open after that lands on the functional page. Quiet on
    /// breaks; suppressed under QA args unless forced.
    private func maybePresentLetter() {
        guard let snapshot, snapshot.isEnrolled, !snapshot.isOnBreak,
              modules.activeCover == nil,
              router.tab == .today
        else { return }
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--uitest-letter") {
            guard letterPresentedDayKey != TodayStateService.dayKey() else { return }
            letterPresentedDayKey = TodayStateService.dayKey()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                modules.present(cover: .jeniNote)
            }
            return
        }
        // Deterministic QA runs keep the page underneath reachable.
        if args.contains("--uitest-inapp-qa") { return }
        #endif
        guard letterPresentedDayKey != TodayStateService.dayKey() else { return }
        letterPresentedDayKey = TodayStateService.dayKey()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard modules.activeCover == nil, router.tab == .today else { return }
            modules.present(cover: .jeniNote)
        }
    }

    // MARK: - Masthead (v7.2 — the whisper)

    /// Founder call 2026-07-27: Home's calendar+checklist chrome
    /// "100x more minimal". The day pill, archetype chip, and pill
    /// tap all died — the masthead is the date, whispered, and the
    /// two marks. Position lives at the day's foot; the day's
    /// character lives in the reading, where a sentence can carry
    /// it better than a chip.
    /// Mission 2 (02_VISUAL.md §§1-2): ONE tracked-caps eyebrow — the
    /// dateline — carrying the day and its seal. The dateline is the
    /// letter's door (a letter is delivered whole or not at all —
    /// the truncated teaser is dead). The ✦ beside the date is the
    /// day's seal: hollow until the last kept line signs, then
    /// filled — the colophon (the silk shimmer crosses this line).
    private var masthead: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                Haptics.soft()
                modules.present(cover: .jeniNote)
            } label: {
                HStack(spacing: 8) {
                    Text(datelineText)
                        .font(Typo.captionTracked)
                        .kerning(1.98)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: daySealed ? .medium : .light))
                        .symbolVariant(daySealed ? .fill : .none)
                        .foregroundStyle(
                            daySealed ? Palette.jeweledRose : Palette.cocoaPrimary.opacity(0.3)
                        )
                        .animation(Motion.gentleSpring, value: daySealed)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .accessibilityIdentifier("jeni.line")
            .accessibilityLabel(
                daySealed
                    ? "\(datelineText), kept. opens today's letter"
                    : "\(datelineText). opens today's letter"
            )
            Spacer(minLength: 12)
            JKProminentMark(systemName: "camera", label: "snap a meal") {
                modules.present(cover: .captureFlow)
            }
            JKQuietMark(systemName: "line.3.horizontal", accessibilityLabel: "settings") {
                modules.present(sheet: .profileHub)
            }
        }
        .padding(.horizontal, Space.lg)
        .jkSilkSweep(trigger: silkTrigger)
    }

    private var datelineText: String {
        let date = Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
            .lowercased()
        guard let snapshot, snapshot.isEnrolled else { return date }
        return "\(date) · day \(max(snapshot.programDay, 1))"
    }

    private var daySealed: Bool {
        guard let snapshot else { return false }
        let total = snapshot.carePlan.actionableBeats.count
        return total > 0 && snapshot.completedBeatCount >= total
    }

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

// MARK: - KeptLine (mission 2 — THE SIGNATURE, docs/app_v7/02_VISUAL.md §3)
//
// The checklist as countersigned correspondence. No circles, no
// boxes, no strikes: an intention is a bare serif line on a
// hairline, terminated by a hollow ✦. Press-and-hold ~450ms (the
// hold-to-sign gesture onboarding taught) — the ink deepens, the
// hairline redraws itself in rose, and jeni's mark fills and blooms
// with the her-file commit haptic at the apex. A short tap still
// opens the module (the row-tap law). Hold a signed line to unsign
// it, quietly.

private struct KeptLine: View {
    let title: String
    var italic: [String] = []
    var reason: String? = nil
    /// Display scale: the day's lead line signs at act scale.
    var isLead: Bool = false
    let isKept: Bool
    let onOpen: () -> Void
    let onSign: (Bool) -> Void

    @State private var holdProgress: CGFloat = 0
    @State private var lineDraw: CGFloat = 0
    @State private var sealScale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var serifSize: CGFloat { isLead ? 34 : 26 }
    private var sealSize: CGFloat { isLead ? 19 : 15 }
    private var ink: Double {
        if isKept { return 0.5 }
        return 0.78 + 0.22 * Double(holdProgress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                ItalicAccentText(
                    title,
                    italic: italic,
                    baseFont: .custom("JeniHeroSerif-Regular", size: serifSize, relativeTo: isLead ? .title : .title3),
                    italicFont: .custom("JeniHeroSerif-Italic", size: serifSize, relativeTo: isLead ? .title : .title3),
                    color: Palette.textPrimary.opacity(ink),
                    alignment: .leading
                )
                .lineSpacing(-2)
                .kerning(-0.3)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: "sparkle")
                    .font(.system(size: sealSize, weight: isKept ? .medium : .light))
                    .symbolVariant(isKept ? .fill : .none)
                    .foregroundStyle(
                        isKept ? Palette.jeweledRose : Palette.cocoaPrimary.opacity(0.3)
                    )
                    .scaleEffect(sealScale)
                    .accessibilityHidden(true)
            }

            // The line she signs: the hairline, redrawn in rose when kept.
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.5)
                GeometryReader { geo in
                    Rectangle()
                        .fill(Palette.jeweledRose.opacity(0.55))
                        .frame(width: geo.size.width * lineDraw, height: 0.75)
                }
                .frame(height: 0.75)
            }

            if isKept {
                HStack {
                    Spacer(minLength: 0)
                    Text("kept")
                        .font(.custom("JeniHeroSerif-Italic", size: 16, relativeTo: .footnote))
                        .foregroundStyle(Palette.jeweledRose)
                }
                .transition(.opacity)
            } else if let reason {
                Text(reason)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, isLead ? 14 : 12)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.light()
            onOpen()
        }
        .onLongPressGesture(minimumDuration: 0.45, pressing: { pressing in
            guard !isKept else { return }
            if pressing {
                Haptics.soft()
                withAnimation(reduceMotion ? nil : .linear(duration: 0.45)) {
                    holdProgress = 1
                }
            } else {
                withAnimation(reduceMotion ? nil : Motion.exit) { holdProgress = 0 }
            }
        }, perform: {
            if isKept {
                unsign()
            } else {
                sign()
            }
        })
        .onAppear {
            lineDraw = isKept ? 1 : 0
        }
        .onChange(of: isKept) { _, kept in
            // External writes (module completion, undo elsewhere)
            // keep the line's material honest without the ceremony.
            if !kept {
                withAnimation(reduceMotion ? nil : Motion.exit) { lineDraw = 0 }
            } else if lineDraw == 0 {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.32)) { lineDraw = 1 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(title)\(isKept ? ", kept" : (reason.map { ", \($0)" } ?? ""))".a11yStripped
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isKept ? "" : "opens \(title). hold to keep it")
        .accessibilityActions {
            if !isKept {
                Button("keep it") { sign() }
            } else {
                Button("unkeep") { unsign() }
            }
        }
    }

    private func sign() {
        if reduceMotion {
            lineDraw = 1
            ActivationHaptics.shared.commit()
            onSign(true)
            return
        }
        withAnimation(.easeOut(duration: 0.32)) { lineDraw = 1 }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.55).delay(0.18)) {
            sealScale = 1.25
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            ActivationHaptics.shared.commit()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { sealScale = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            onSign(true)
        }
        holdProgress = 0
    }

    private func unsign() {
        Haptics.soft()
        withAnimation(reduceMotion ? nil : Motion.exit) {
            lineDraw = 0
            sealScale = 1
        }
        onSign(false)
    }
}
