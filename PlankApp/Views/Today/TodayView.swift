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
                        // THE UNDERSTANDING (v7 §1) — the reading is
                        // the page's reason: one calm observation of
                        // her current state, spoken in full. The tap
                        // opens the full note. v7.2: it now follows
                        // the masthead directly — nothing stands
                        // between the date and jeni's sentence.
                        JKCoachLine(
                            text: snapshot.brief.line,
                            italic: snapshot.brief.italic,
                            second: snapshot.brief.second,
                            secondItalic: snapshot.brief.secondItalic,
                            mechanism: snapshot.brief.mechanism,
                            affordanceLabel: "from jeni",
                            onOpenChat: {
                                // v7 one-thread law (docs/app_v7 §3):
                                // the reading IS the day's letter in
                                // the jeni thread — the affordance
                                // goes THERE, not to a dead-end cover.
                                // (JeniNoteView is reserved for the
                                // phase-3 first-move letter arrival.)
                                router.openChat()
                            }
                        )
                        .accessibilityIdentifier("jeni.line")
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.section)
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
                            // (v7.3: the position line moved back up
                            // into the masthead — founder: program
                            // identity must be instant.)
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
                        askBlock(lead, snapshot: snapshot)
                    } else {
                        permissionLine(
                            snapshot.carePlan.tone == .gentle
                                ? "a quiet day. nothing owed \u{2665}\u{FE0E}"
                                : "rest day. nothing scheduled \u{2665}\u{FE0E}",
                            italic: snapshot.carePlan.tone == .gentle ? ["quiet"] : ["rest"]
                        )
                    }
                    planRows(snapshot, includeLead: false)
                        .padding(.top, Space.md)
                }
                .jkSilkSweep(trigger: silkTrigger)
            }
        }
    }

    // MARK: - The ask, type-first (v7.2)

    /// Founder call: the cocoa slab card read as app furniture. The
    /// day's one thing is now a typographic object — a short cocoa
    /// rule (the "one thing" gesture), the ask at serif scale, its
    /// reason beneath. Completion strikes the line and lands the
    /// glossy seal — the reward arriving ON the typography.
    @ViewBuilder
    private func askBlock(_ lead: CarePlanEngine.Move, snapshot: TodaySnapshot) -> some View {
        let title = oneThingTitle(lead.beat, snapshot: snapshot)
        let isDone = beatState(lead.beat, snapshot: snapshot).isDone
        let sub = lead.because ?? oneThingSubtitle(lead.beat, snapshot: snapshot)

        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Palette.cocoaPrimary.opacity(isDone ? 0.35 : 1))
                .frame(width: 28, height: 2)

            HStack(alignment: .top, spacing: 10) {
                ItalicAccentText(
                    title.text,
                    italic: title.italic,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 27, relativeTo: .title2),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 27, relativeTo: .title2),
                    color: isDone ? Palette.textSecondary : Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(-3)
                .kerning(-0.3)
                .fixedSize(horizontal: false, vertical: true)
                .overlay(alignment: .leading) {
                    if isDone {
                        Rectangle()
                            .fill(Palette.textPrimary.opacity(0.5))
                            .frame(height: 1.5)
                            .offset(y: 1)
                            .allowsHitTesting(false)
                    }
                }
                Spacer(minLength: 0)
                if isDone, let seal = lead.beat.stickerAsset {
                    Image(seal)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
                        .accessibilityHidden(true)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }

            if isDone {
                Text("kept \u{2665}\u{FE0E}")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.jeweledRose)
            } else if let sub {
                Text(sub)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .modifier(JKTapWithLongPress(
            onTap: { if !isDone { modules.open(lead.beat, snapshot: snapshot) } },
            onLongPress: isDone ? nil : { modules.longPress(lead.beat, snapshot: snapshot) }
        ))
        .animation(Motion.entranceSoft, value: isDone)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "the one thing, \(title.text)\(isDone ? ", done" : (sub.map { ", \($0)" } ?? ""))".a11yStripped
        )
        .accessibilityHint(isDone ? "" : "opens \(title.text)")
        .accessibilityActions {
            if !isDone {
                Button("mark as done") { modules.longPress(lead.beat, snapshot: snapshot) }
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
            // THE LIST (v7.3, founder: onboarding DNA in-app) — plan
            // moves render in the signed OV5SelectRow grammar: the
            // 26pt leading radio, 19pt label, the cross-off strike.
            // The radio is finally an HONEST one-tap "kept" target
            // (crossOff haptic, tap again to undo); the row body
            // still enters the module.
            ForEach(Array(ringed.enumerated()), id: \.element.beat.itemKey) { idx, move in
                PlanListRow(
                    title: beatTitle(move.beat),
                    note: moveNote(move, snapshot: snapshot, ring: true),
                    state: beatState(move.beat, snapshot: snapshot),
                    onToggle: { setDone(move.beat, done: $0) },
                    onOpen: { modules.open(move.beat, snapshot: snapshot) },
                    onLongPress: move.beat.isProgressRow
                        ? nil
                        : { modules.longPress(move.beat, snapshot: snapshot) }
                )
                .jkBeat2(extraDelay: 0.08 + Double(idx) * Motion.revealStagger)
            }

            ForEach(Array(plan.offered.enumerated()), id: \.element.beat.itemKey) { idx, move in
                JKRhythmRow(
                    title: beatTitle(move.beat),
                    note: moveNote(move, snapshot: snapshot, ring: false),
                    mark: JKMarkKind.mark(for: move.beat),
                    state: beatState(move.beat, snapshot: snapshot),
                    showsCheckRing: false,
                    onTap: { modules.open(move.beat, snapshot: snapshot) },
                    onLongPress: move.beat.isProgressRow
                        ? nil
                        : { modules.longPress(move.beat, snapshot: snapshot) }
                )
                .opacity(0.88)
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

    // MARK: - Masthead (v7.2 — the whisper)

    /// Founder call 2026-07-27: Home's calendar+checklist chrome
    /// "100x more minimal". The day pill, archetype chip, and pill
    /// tap all died — the masthead is the date, whispered, and the
    /// two marks. Position lives at the day's foot; the day's
    /// character lives in the reading, where a sentence can carry
    /// it better than a chip.
    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 14) {
                Text(
                    Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
                        .lowercased()
                )
                .font(Typo.captionTracked)
                .kerning(1.98)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: 12)
                JKProminentMark(systemName: "camera", label: "snap a meal") {
                    modules.present(cover: .captureFlow)
                }
                JKQuietMark(systemName: "line.3.horizontal", accessibilityLabel: "settings") {
                    modules.present(sheet: .profileHub)
                }
            }

            // v7.3 (founder): "which program they are on" must be
            // instant — the program line is the masthead's second
            // eyebrow (onboarding act-header grammar), full width so
            // the named week never truncates. Opens the journey.
            if let snapshot, snapshot.isEnrolled, let intent = snapshot.weekIntent {
                Button {
                    Haptics.soft()
                    router.tab = .becoming
                } label: {
                    HStack(spacing: 6) {
                        Text("day \(max(snapshot.programDay, 1)) · week \(snapshot.programWeek) of \(max(snapshot.totalWeeks, 1)) · \(intent.name)")
                            .font(Typo.captionTracked)
                            .kerning(1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(JKPress())
                .accessibilityLabel(
                    "day \(max(snapshot.programDay, 1)), week \(snapshot.programWeek) of \(max(snapshot.totalWeeks, 1)), \(intent.name)"
                )
                .accessibilityHint("opens your journey")
            }
        }
        .padding(.horizontal, Space.lg)
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

// MARK: - PlanListRow (v7.3 — the onboarding grammar, in-app)
//
// OV5SelectRow's signed material transplanted to the day: 26pt
// leading radio, DMSans-Medium 19 label, the 1.5pt cross-off strike,
// the decided fade. The radio toggles kept (honest at last, 44pt via
// tappableArea); the body opens the module; long-press keeps the
// granular override.

private struct PlanListRow: View {
    let title: String
    var note: String? = nil
    let state: JKBeatState
    let onToggle: (Bool) -> Void
    let onOpen: () -> Void
    var onLongPress: (() -> Void)? = nil

    @State private var strikeProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            Button {
                onToggle(!state.isDone)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(
                            state.isDone ? Palette.cocoaPrimary : Palette.cocoaPrimary.opacity(0.28),
                            lineWidth: 1.5
                        )
                        .frame(width: 26, height: 26)
                    if state.isDone {
                        Circle()
                            .fill(Palette.cocoaPrimary)
                            .frame(width: 26, height: 26)
                        Image(systemName: state.isAuto ? "sparkle" : "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.textInverse)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                .animation(Motion.bloom, value: state.isDone)
                .tappableArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.isDone ? "kept, \(title)" : "mark \(title) as kept")

            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("DMSans-Medium", size: 19, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(Palette.textPrimary.opacity(0.55))
                                    .frame(width: geo.size.width * strikeProgress, height: 1.5)
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .allowsHitTesting(false)
                        }
                    if let note {
                        Text(note)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .modifier(JKTapWithLongPress(
                onTap: onOpen,
                onLongPress: onLongPress
            ))
        }
        .padding(.vertical, 16)
        .opacity(state.isDone ? 0.38 : 1)
        .animation(.easeOut(duration: 0.25), value: state.isDone)
        .onChange(of: state.isDone) { _, done in
            guard done else {
                withAnimation(Motion.exit) { strikeProgress = 0 }
                return
            }
            if reduceMotion { strikeProgress = 1; return }
            withAnimation(.easeOut(duration: 0.18).delay(0.05)) { strikeProgress = 1 }
        }
        .onAppear { strikeProgress = state.isDone ? 1 : 0 }
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            if !state.isDone {
                Button("mark as done") { onToggle(true) }
            }
        }
    }
}
