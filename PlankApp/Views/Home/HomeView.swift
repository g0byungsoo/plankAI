import SwiftUI
import SwiftData
import Combine
import UIKit
import PlankFood
import PlankSync
import Auth
import RevenueCat

// MARK: - HomeView (v11 T3 — HOME, from zero)
//
// docs/app_v11/00_REBIRTH.md §6: MyFitnessPal's information
// architecture in Jeni's editorial skin — calendar strip → nutrition
// → TODAY → TOOLS → the below-fold moments. Body progress lives in
// BECOMING, not here.
//
// This file is TodayView's SPINE under a new skin: every engine,
// QA door, presentation moment and observation write ported intact
// (see docs/app_v11/01_PLAN.md Task 3's port inventory). The layout
// is kit primitives only.

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var auth = AuthService.shared
    @State private var router = AppRouter.shared
    @State private var steps = StepsService.shared

    @State private var snapshot: TodaySnapshot?
    @State private var modules = TodayModuleState()
    // v9 P2 — the once-ever Body Vision introduction.
    @State private var showBodyIntro = false
    @AppStorage("bodyScan.introSeenAt") private var bodyIntroSeenAt = ""
    /// Day-complete silk sweep. -1 baseline so a restored complete
    /// day never replays it.
    @State private var silkTrigger = 0
    @State private var lastCompletedCount = -1
    @State private var showUpgradeMoment = false
    @AppStorage("upgradeMoment.shownV1") private var upgradeMomentShown = false
    @State private var detailPlate: FoodLogPersister.FoodLogEntry?
    @State private var reconcilePlan: RegimenPlanRecord?
    @State private var showReconcile = false
    @State private var qaShowCareConnect = false
    @State private var qaShowRegimen = false
    @AppStorage("letter.presentedDayKey") private var letterPresentedDayKey = ""
    /// The evening close, as its own full screen. Auto-arrives once
    /// per evening; the invitation row re-opens it any time.
    @State private var showEveningMoment = false
    @AppStorage("evening.moment.presentedDayKey") private var eveningMomentDayKey = ""

    /// The page's single arrival flag (L12).
    @State private var arrived = false
    /// v11.5 — the strip's selection. Today by default; past days
    /// re-key the page to that day's record.
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    /// v12 D13 — which side the recap slides in from. Set BEFORE the
    /// morph commits (the strip's onChange runs in the same
    /// transaction), so the insertion reads the travel direction.
    @State private var recapDirection: CGFloat = 24
    /// The lead's long-press latch (JKTapWithLongPress pattern).
    @State private var leadLongPressJustFired = false

    private var userId: String {
        auth.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if let snapshot {
                        // v11.5 — THE GREETING. Both references open on
                        // a human line, not a datestamp. Hers uses her
                        // name when she gave one; the hour decides the
                        // word. The name takes the lighter ink so the
                        // greeting reads as one breath (Lovi's move).
                        // v12 — one LIVING sub-line beneath, when a real
                        // store has something worth saying (kept run →
                        // trend word → silence). Never noise (§1.6).
                        VStack(alignment: .leading, spacing: 5) {
                            greeting
                            if let sub = greetingSubLine(snapshot) {
                                Text(sub)
                                    .font(Typo.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                        .padding(.top, Space.md)
                        .jeniArrive(arrived, index: 0)

                        HomeCalendarStrip(
                            // The wrapping binding stamps the travel
                            // direction IN the selection's transaction,
                            // so the recap's insertion reads it (D13);
                            // a plain onChange lags one selection.
                            selectedDate: Binding(
                                get: { selectedDate },
                                set: { new in
                                    recapDirection = new < selectedDate ? -24 : 24
                                    selectedDate = new
                                }
                            ),
                            keptDays: keptDays
                        )
                        .padding(.top, Space.blockGap)
                        .jeniArrive(arrived, index: 1)

                        homeDateline(snapshot)
                            .padding(.top, Space.md)
                            .jeniArrive(arrived, index: 2)

                        if !isSelectedToday {
                            HomeDayRecap(
                                date: selectedDate,
                                userId: userId,
                                onOpenRecord: { router.tab = .becoming },
                                onBackToToday: {
                                    JeniHaptic.tick()
                                    withAnimation(JeniMotion.morph) {
                                        recapDirection = 24
                                        selectedDate = Calendar.current.startOfDay(for: .now)
                                    }
                                }
                            )
                            .id(selectedDate)
                            // D13 — the recap arrives from the side the
                            // strip travelled: an earlier day slides in
                            // from the left, a later one from the right.
                            // The strip and the page move as one object.
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(x: recapDirection)),
                                removal: .opacity
                            ))
                        } else if snapshot.isOnBreak {
                            JKBreakCard(onReturn: {
                                BreakState.end()
                                refresh()
                            })
                            .padding(.top, Space.sectionGap)
                            .jeniArrive(arrived, index: 3)
                        } else {
                            // Founder law (2026-08-06): Home ALWAYS
                            // reads nutrition → what's left → tools.
                            // The evening used to swap this whole
                            // column for a takeover headline; the
                            // close now lives in its own full screen.
                            // v12 D13 — returning from a past day, the
                            // live page arrives from the right, as one
                            // object with the strip.
                            VStack(alignment: .leading, spacing: 0) {
                            HomeNutritionSummary(
                                snapshot: snapshot,
                                onOpenFood: { modules.present(cover: .captureFlow) }
                            )
                            .jeniArrive(arrived, index: 3)

                            daySection(snapshot)
                                .jeniArrive(arrived, index: 4)

                            if let chain = modules.chainSuggestion {
                                JeniRow(
                                    chain.text,
                                    detail: chain.lead,
                                    trailing: .chevron,
                                    action: {
                                        modules.chainSuggestion = nil
                                        if let seed = chain.chatSeed {
                                            router.openChat(seed: seed)
                                        } else if let route = chain.route {
                                            router.open(route)
                                        }
                                    }
                                )
                                .transition(.opacity)
                            }

                            if daySealed, !snapshot.carePlan.closing.isEmpty, !isEvening {
                                secondAct(snapshot)
                                    .padding(.top, Space.sectionGap)
                                    .transition(.opacity)
                            }

                            toolsSection(snapshot)
                                .jeniArrive(arrived, index: 5)

                            if isEvening {
                                EveningJournalLine(snapshot: snapshot)
                                    .padding(.top, Space.sectionGap)
                            }
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(x: recapDirection)),
                                removal: .opacity
                            ))
                        }
                    }

                    Spacer(minLength: 120)   // clears the floating tab bar
                        .id("today.bottom")
                }
                .padding(.horizontal, Space.gutter)
            }
            .background(alignment: .top) {
                // The light behind the day (v11.5). It lives BEHIND the
                // scroll so the page moves through it rather than
                // dragging it along.
                ZStack(alignment: .top) {
                    Palette.bgPrimary
                    JeniAtmosphere(height: 380)
                }
                .ignoresSafeArea()
            }
            .refreshable { refresh() }
            // Scrolled content fades under the clock (the masthead scrim).
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Palette.bgPrimary, Palette.bgPrimary.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 54)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--uitest-today-bottom") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        proxy.scrollTo("today.bottom", anchor: .bottom)
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--uitest-plate-detail") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        detailPlate = snapshot?.plates.first
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--uitest-gentle-preview") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        modules.shrinkWorkoutToFloor()
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--uitest-breath-preview") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        modules.present(cover: .breathSession)
                    }
                }
                // v12 film doors — deterministic interaction scenes for
                // THE LOOP (synthesized drags can't scroll this sim).
                if ProcessInfo.processInfo.arguments.contains("--uitest-walk-strip") {
                    // A past day arrives from the left; today returns
                    // from the right (D13, both directions on film).
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                        JeniHaptic.tick()
                        withAnimation(JeniMotion.morph) {
                            recapDirection = -24
                            selectedDate = Calendar.current.date(
                                byAdding: .day, value: -3,
                                to: Calendar.current.startOfDay(for: .now)
                            ) ?? selectedDate
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) {
                        JeniHaptic.tick()
                        withAnimation(JeniMotion.morph) {
                            recapDirection = 24
                            selectedDate = Calendar.current.startOfDay(for: .now)
                        }
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--uitest-mark-lead") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                        guard let snapshot, let lead = snapshot.carePlan.lead else { return }
                        modules.mark(lead.beat, state: .complete)
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--uitest-land-plate") {
                    // A real plate lands mid-scene: the numeral MORPHS
                    // forward, the ring advances, the protein bar
                    // re-keys — addition, never a reset (v12).
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                        FoodLogPersister.debugSeed(
                            id: "qa-plate-\(TodayStateService.dayKey())-live",
                            userId: userId,
                            loggedAt: .now,
                            kcal: 240, protein: 21, carbs: 18, fat: 9,
                            fiber: 4, sugar: 6, sodiumMg: 180,
                            title: "afternoon yogurt", source: "quick_add"
                        )
                        refresh()
                        JeniHaptic.swell()
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--uitest-seal-day") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard let snapshot else { return }
                        for beat in snapshot.carePlan.actionableBeats {
                            _ = ProgramService.shared.markChecklistItem(
                                prescription: beat, state: .complete,
                                userId: userId, in: modelContext
                            )
                        }
                        refresh()
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--uitest-unseal-day") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard let snapshot else { return }
                        for beat in snapshot.carePlan.actionableBeats {
                            _ = ProgramService.shared.markChecklistItem(
                                prescription: beat, state: .empty,
                                userId: userId, in: modelContext
                            )
                        }
                        refresh()
                    }
                }
                #endif
            }
        }
        .environment(\.jeniArrived, arrived)
        .task {
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
            arrived = true
        }
        .todayModuleHost(
            state: modules,
            userId: userId,
            snapshot: snapshot,
            onMutation: { refresh() }
        )
        .fullScreenCover(isPresented: $showEveningMoment) {
            if let snapshot {
                HomeEveningMoment(
                    snapshot: snapshot,
                    onReflect: { feeling in storeReflection(feeling) },
                    onDismiss: {
                        eveningMomentDayKey = TodayStateService.dayKey()
                        showEveningMoment = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showBodyIntro) {
            BodyVisionIntroView(
                onSee: {
                    showBodyIntro = false
                    Analytics.track(.bodyVisionIntro, properties: ["choice": "see"])
                    modules.present(cover: .bodyScan)
                },
                onLater: {
                    showBodyIntro = false
                    Analytics.track(.bodyVisionIntro, properties: ["choice": "later"])
                }
            )
        }
        .onAppear {
            refresh()
            maybePresentLetter()
            maybeOfferUpgradeMoment()
            maybeOfferReconciliation()
            maybePresentBodyIntro()
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--uitest-open-care-connect") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { qaShowCareConnect = true }
            }
            if args.contains("--uitest-open-regimen") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { qaShowRegimen = true }
            }
            #endif
        }
        #if DEBUG
        .sheet(isPresented: $qaShowCareConnect) {
            CareConnectionSheet(userId: userId, onClose: { qaShowCareConnect = false })
                .presentationDetents([.large])
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $qaShowRegimen) {
            RegimenSheet(userId: userId, onDone: { qaShowRegimen = false })
                .presentationDetents([.medium, .large])
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onChange(of: modules.activeCover) { old, new in
            guard old == .captureFlow, new == nil else { return }
            refresh()
            // The refreshed snapshot morphs the numeral + ring forward
            // on its own (v12); the swell marks the landing.
            if let newest = snapshot?.plates.last,
               Date.now.timeIntervalSince(newest.loggedAt) < 120 {
                JeniHaptic.swell()
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
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showReconcile) {
            if let reconcilePlan {
                ReconciliationSheet(
                    userId: userId, plan: reconcilePlan,
                    onClose: { showReconcile = false; refresh() }
                )
                .presentationDetents([.large])
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)
            }
        }
        .fullScreenCover(isPresented: $showUpgradeMoment) {
            UpgradeMomentView(
                programDay: snapshot?.programDay ?? 0,
                receipt: upgradeReceipt,
                onDone: { showUpgradeMoment = false }
            )
        }
    }

    // MARK: - The dateline (the letter's door + settings)

    private func homeDateline(_ snapshot: TodaySnapshot) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(datelineText)
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .modifier(JKTapWithLongPress(
                        onTap: { modules.present(cover: .jeniNote) },
                        onLongPress: { modules.present(sheet: .profileHub) }
                    ))
                    .accessibilityIdentifier("jeni.line")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(
                        daySealed
                            ? "\(datelineText), kept. opens today's letter"
                            : "\(datelineText). opens today's letter"
                    )
                    .accessibilityHint("hold for settings")
                    .accessibilityActions {
                        Button("settings") { modules.present(sheet: .profileHub) }
                    }
                if snapshot.isEnrolled, let intent = snapshot.weekIntent, !isEvening {
                    Button {
                        Haptics.soft()
                        router.tab = .becoming
                    } label: {
                        Text("\(intent.name) · week \(snapshot.programWeek) of \(snapshot.totalWeeks)")
                            .font(.custom("DMSans-Medium", size: 12, relativeTo: .caption))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(JKPress())
                    .accessibilityIdentifier("today.weekRibbon")
                    .accessibilityLabel(
                        "\(intent.name), week \(snapshot.programWeek) of \(snapshot.totalWeeks). opens becoming"
                    )
                }
            }
            // The letter tap + settings hold live on the DATE LINE
            // ONLY — a parent-level gesture would swallow the week
            // ribbon's tap (the surface walker caught exactly that).

            Spacer(minLength: 12)

            Button {
                Haptics.light()
                modules.present(sheet: .profileHub)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .tappableArea(44)
            }
            .buttonStyle(JKPress())
            .accessibilityLabel("settings")
        }
        .jkSilkSweep(trigger: silkTrigger)
    }

    /// The hour's word plus her name, when she gave one. The name
    /// takes the softer ink so the two read as a single breath.
    private var greeting: some View {
        let hour = Calendar.current.component(.hour, from: .now)
        let word = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
        let name = (UserDefaults.standard.string(forKey: "userName") ?? "")
            .trimmingCharacters(in: .whitespaces)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(name.isEmpty ? "\(word)." : "\(word), ")
                .font(Typo.questionHero)
                .foregroundStyle(Palette.textPrimary)
            if !name.isEmpty {
                Text(name.lowercased() + ".")
                    .font(Typo.questionHeroItalic)
                    .foregroundStyle(Palette.textPrimary.opacity(0.42))
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Which days of the visible weeks she actually KEPT — the strip's
    /// rings are her record, never decoration (L8).
    private var keptDays: Set<Date> {
        guard !userId.isEmpty else { return [] }
        return ProgramService.shared.keptDayStarts(userId: userId, in: modelContext)
    }

    /// v12 — the greeting's one living line, by priority: the kept run
    /// (her streak, ≥2), else the easing trend, else quiet. Every fact
    /// traces to a store (§1.6); when nothing is worth saying, the
    /// greeting stands alone.
    private func greetingSubLine(_ snapshot: TodaySnapshot) -> String? {
        let run = keptRun
        if run >= 2 { return "\(run) days kept in a row" }
        if snapshot.trendIsEstablished,
           let delta = snapshot.emaDelta7dKg, delta < -0.05 {
            let unit = WeightUnit(
                rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "lb"
            ) ?? .lb
            let word = String(
                format: "%.1f %@", abs(unit.display(fromKg: delta)), unit.label
            )
            return "down about \(word) this week"
        }
        return nil
    }

    /// Consecutive kept days ending today (or yesterday, when today is
    /// still being written).
    private var keptRun: Int {
        let cal = Calendar.current
        let kept = keptDays
        guard !kept.isEmpty else { return 0 }
        var day = cal.startOfDay(for: .now)
        if !kept.contains(day) {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var run = 0
        while kept.contains(day) {
            run += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return run
    }

    private var isSelectedToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var datelineText: String {
        // v11.5: the greeting names the moment and the strip names the
        // date, so repeating "wednesday, august 5" here was the page
        // saying the same thing three times. The dateline now carries
        // only what neither of them says: where she is in the program.
        guard let snapshot, snapshot.isEnrolled else {
            return Date.now.formatted(.dateTime.month(.wide).day()).lowercased()
        }
        return "day \(max(snapshot.programDay, 1)) of \(snapshot.totalDays)"
    }

    // MARK: - TODAY (the checklist)

    @ViewBuilder
    private func daySection(_ snapshot: TodaySnapshot) -> some View {
        let doneCount = snapshot.completedBeatCount
        let totalCount = snapshot.carePlan.actionableBeats.count
        VStack(alignment: .leading, spacing: 0) {
            // One shape, every hour of the day. In the evening the
            // header names what it is — the rest, not the whole day.
            // v12 — the header carries the day's quiet count; it
            // morphs as tasks land (numbers count, §4.3).
            HStack(alignment: .firstTextBaseline) {
                JeniSectionHeader(isEvening ? "still today" : "today")
                Spacer(minLength: Space.md)
                if totalCount > 0 {
                    Text("\(doneCount) of \(totalCount)")
                        .font(Typo.statLabel)
                        .kerning(0.66)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(JeniMotion.morph, value: doneCount)
                        .accessibilityLabel("\(doneCount) of \(totalCount) done")
                }
            }
            if let lead = snapshot.carePlan.lead {
                leadAsk(lead, snapshot: snapshot)
            } else {
                JeniHeadline(
                    snapshot.carePlan.tone == .gentle
                        ? "a quiet day. nothing owed."
                        : "rest day. nothing scheduled.",
                    italic: snapshot.carePlan.tone == .gentle ? ["quiet"] : ["rest"]
                )
                .padding(.vertical, Space.sm)
            }
            planRows(snapshot, includeLead: false)

            if isEvening {
                eveningInvitation
                    .padding(.top, Space.blockGap)
            }
        }
    }

    /// The evening's one invitation. Tapping it opens the close as a
    /// full screen that types itself — Home stays Home.
    private var eveningInvitation: some View {
        Button {
            JeniHaptic.tick()
            showEveningMoment = true
        } label: {
            JeniSurface {
                HStack(alignment: .center, spacing: Space.md) {
                    VStack(alignment: .leading, spacing: 3) {
                        JeniHeadline("close the day.", italic: ["close"])
                        Text("the receipt, the feeling, tomorrow")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(JeniPressable())
        .accessibilityLabel("close the day")
        .accessibilityIdentifier("home.closeTheDay")
    }

    /// The day's ONE ask — a soft card carrying the serif headline
    /// and its check (v11.5). Card tap enters; the circle quick-marks;
    /// the long-press override sheet stays.
    @ViewBuilder
    private func leadAsk(_ lead: CarePlanEngine.Move, snapshot: TodaySnapshot) -> some View {
        let title = oneThingTitle(lead.beat, snapshot: snapshot)
        let done = beatState(lead.beat, snapshot: snapshot).isDone
        Button {
            if leadLongPressJustFired {
                leadLongPressJustFired = false
                return
            }
            modules.open(lead.beat, snapshot: snapshot)
        } label: {
            JeniSurface {
                HStack(alignment: .center, spacing: Space.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        JeniHeadline(title.text, italic: title.italic)
                            .opacity(done ? 0.45 : 1)
                        if let note = lead.because ?? oneThingSubtitle(lead.beat, snapshot: snapshot) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                if snapshot.carePlan.leadIsPromoted {
                                    Circle()
                                        .fill(Palette.accent)
                                        .frame(width: 4, height: 4)
                                        .accessibilityHidden(true)
                                }
                                Text(note)
                                    .font(Typo.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                    Spacer(minLength: Space.sm)
                    JeniCheck(isDone: done) {
                        modules.mark(lead.beat, state: done ? .empty : .complete)
                    }
                }
            }
            .contentShape(Rectangle())
            // Completion SETTLES: the title's dim and the check's draw
            // share one morph, so the card exhales as a single object.
            .animation(JeniMotion.morph, value: done)
        }
        .buttonStyle(JeniPressable())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                leadLongPressJustFired = true
                JeniHaptic.land()
                modules.present(sheet: .markAsDone(lead.beat))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    leadLongPressJustFired = false
                }
            }
        )
        .accessibilityHint(Text("double-tap to open. long-press to mark."))
    }

    /// A supporting task as a soft card: check leading, words center.
    @ViewBuilder
    private func taskCard(_ move: CarePlanEngine.Move, snapshot: TodaySnapshot) -> some View {
        let done = beatState(move.beat, snapshot: snapshot).isDone
        Button {
            modules.open(move.beat, snapshot: snapshot)
        } label: {
            JeniSurface(radius: 20, padding: Space.md) {
                HStack(spacing: Space.md) {
                    JeniCheck(isDone: done) {
                        modules.mark(move.beat, state: done ? .empty : .complete)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(beatTitle(move.beat))
                            .font(.custom("DMSans-Medium", size: 16, relativeTo: .body))
                            .foregroundStyle(done ? Palette.cocoaTertiary : Palette.textPrimary)
                        if let note = moveNote(move, snapshot: snapshot, ring: true) {
                            Text(note)
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .contentShape(Rectangle())
            .animation(JeniMotion.morph, value: done)
        }
        .buttonStyle(JeniPressable())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                JeniHaptic.land()
                modules.present(sheet: .markAsDone(move.beat))
            }
        )
        .accessibilityHint(Text("double-tap to open. long-press to mark."))
    }

    /// An offered move: the same material, no check — an invitation,
    /// never debt.
    @ViewBuilder
    private func offeredCard(_ move: CarePlanEngine.Move, snapshot: TodaySnapshot) -> some View {
        Button {
            modules.open(move.beat, snapshot: snapshot)
        } label: {
            JeniSurface(radius: 20, padding: Space.md) {
                HStack(spacing: Space.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(beatTitle(move.beat))
                            .font(.custom("DMSans-Medium", size: 16, relativeTo: .body))
                            .foregroundStyle(Palette.textPrimary)
                        if let note = offeredDetail(move, snapshot: snapshot) {
                            Text(note)
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    Text("if it fits")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniPressable())
        .accessibilityLabel("\(beatTitle(move.beat)), if it fits today")
    }

    @ViewBuilder
    private func planRows(_ snapshot: TodaySnapshot, includeLead: Bool) -> some View {
        let plan = snapshot.carePlan
        let leadRow: [CarePlanEngine.Move] = includeLead
            ? (plan.lead.map { [$0] } ?? [])
            : []
        let ringed = leadRow + plan.supporting

        VStack(spacing: 12) {
            ForEach(ringed, id: \.beat.itemKey) { move in
                taskCard(move, snapshot: snapshot)
            }
            ForEach(plan.offered, id: \.beat.itemKey) { move in
                offeredCard(move, snapshot: snapshot)
            }
        }
        .padding(.top, 2)
    }

    /// An offered row's detail without the "if it fits" suffix — the
    /// invitation moved to the trailing slot.
    private func offeredDetail(
        _ move: CarePlanEngine.Move, snapshot: TodaySnapshot
    ) -> String? {
        if let because = move.because { return because }
        return beatSubtitle(move.beat, snapshot: snapshot)
    }

    // MARK: - TOOLS (words, not icons — L3)

    @ViewBuilder
    private func toolsSection(_ snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            JeniSectionHeader("tools")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12),
                          GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                toolCard("snap a meal", glyph: "camera",
                         status: snapStatus(snapshot)) {
                    modules.present(cover: .captureFlow)
                }
                toolCard("weigh in", glyph: "scalemass",
                         status: weighStatus(snapshot)) {
                    modules.present(sheet: .logWeight)
                }
                // v10.3d law: the check-in door renders at every hour.
                toolCard("body check-in", glyph: "figure.stand",
                         status: scanStatus(snapshot)) {
                    modules.present(cover: .bodyScan)
                }
                toolCard("the method", glyph: "book",
                         status: modules.lessonTitle(snapshot: self.snapshot)
                             ?? "a 2-minute read") {
                    modules.openLesson(snapshot: self.snapshot)
                }
                toolCard("breathe", glyph: "wind",
                         status: "one quiet minute") {
                    modules.present(cover: .breathSession)
                }
                toolCard("move", glyph: "figure.strengthtraining.functional",
                         status: moveStatus(snapshot)) {
                    let beat = self.snapshot?.day?.beats.first(where: {
                        if case .workout = $0 { return true } else { return false }
                    }) ?? .workout(tier: .soft, minutes: 10, bodyFocus: nil)
                    modules.open(beat, snapshot: self.snapshot)
                }
            }
            .padding(.top, 2)
        }
    }

    // v12 — a tool is a DESTINATION: its card carries where things
    // stand, so the grid reads as places with state, not buttons.
    // Every line traces to a store (§1.6).

    private func snapStatus(_ snapshot: TodaySnapshot) -> String {
        let n = snapshot.plates.count
        if n == 0 { return "none yet today" }
        return n == 1 ? "1 plate today" : "\(n) plates today"
    }

    private func weighStatus(_ snapshot: TodaySnapshot) -> String {
        guard let daysAgo = snapshot.lastWeighInDaysAgo else {
            return "takes 30 seconds"
        }
        if daysAgo <= 0 { return "logged today" }
        if daysAgo == 1 { return "last logged yesterday" }
        return "last logged \(daysAgo) days ago"
    }

    private func scanStatus(_ snapshot: TodaySnapshot) -> String {
        let onPlan = snapshot.day?.beats.contains(where: {
            if case .bodyScan = $0 { return true } else { return false }
        }) ?? false
        return onPlan ? "on today's plan" : "stays on your phone"
    }

    private func moveStatus(_ snapshot: TodaySnapshot) -> String {
        if let beat = snapshot.day?.beats.first(where: {
            if case .workout = $0 { return true } else { return false }
        }), case .workout(let tier, let minutes, _) = beat {
            return "\(minutes) min · \(tierWord(tier))"
        }
        return "10 min · gentle"
    }

    /// A tool as a compact soft card: the word first, a quiet glyph
    /// beside it (L3 tempered — 15pt, secondary, never alone), and
    /// one living state line beneath.
    private func toolCard(_ word: String, glyph: String, status: String,
                          action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            JeniSurface(radius: 18, padding: Space.md) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 10) {
                        Image(systemName: glyph)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Palette.cocoaSecondary)
                            .frame(width: 20)
                        Text(word)
                            .font(.custom("DMSans-Medium", size: 15, relativeTo: .subheadline))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                    }
                    Text(status)
                        .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption2))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniPressable())
        .accessibilityLabel("\(word). \(status)")
    }

    // MARK: - The second act (ported; the closing acts sign by being done)

    @State private var revealedAct: CarePlanEngine.CareAct?
    @AppStorage("act.recover.dayKey") private var recoverActDayKey = ""

    @ViewBuilder
    private func secondAct(_ snapshot: TodaySnapshot) -> some View {
        let today = TodayStateService.dayKey()
        JeniSurface {
        VStack(alignment: .leading, spacing: 0) {
            JeniHeadline("the day, kept. what's left is yours.", italic: ["yours."])

            ForEach(snapshot.carePlan.closing, id: \.rawValue) { act in
                switch act {
                case .celebrate:
                    JeniRow("your first down week", trailing: .done, action: {})
                case .reflect:
                    JeniRow(
                        "close the day in one line",
                        trailing: UserDefaults.standard.string(
                            forKey: "day.reflection.\(today)") != nil ? .done : .none,
                        action: {
                            withAnimation(JeniMotion.settle) {
                                revealedAct = revealedAct == .reflect ? nil : .reflect
                            }
                        }
                    )
                    if revealedAct == .reflect {
                        HStack(spacing: Space.blockGap) {
                            actWord("proud"); actWord("okay"); actWord("tender")
                        }
                        .padding(.vertical, Space.sm)
                        .transition(.opacity)
                    }
                case .prepare:
                    JeniRow(
                        "tomorrow, prepared",
                        trailing: TonightPlan.planned(dayKey: today) != nil ? .done : .none,
                        action: {
                            withAnimation(JeniMotion.settle) {
                                revealedAct = revealedAct == .prepare ? nil : .prepare
                            }
                        }
                    )
                    if revealedAct == .prepare {
                        VStack(alignment: .leading, spacing: Space.sm) {
                            HStack(spacing: Space.md) {
                                actPlan(TonightPlan.options[0]); actPlan(TonightPlan.options[1])
                            }
                            HStack(spacing: Space.md) {
                                actPlan(TonightPlan.options[2]); actPlan(TonightPlan.options[3])
                            }
                        }
                        .padding(.vertical, Space.sm)
                        .transition(.opacity)
                    }
                case .recover:
                    JeniRow(
                        "two quiet minutes",
                        trailing: recoverActDayKey == today ? .done : .none,
                        action: { modules.present(cover: .breathSession) }
                    )
                }
            }
        }
        }
        .onChange(of: modules.activeCover) { old, new in
            if old == .breathSession, new == nil, daySealed {
                recoverActDayKey = TodayStateService.dayKey()
            }
        }
    }

    private func actWord(_ word: String) -> some View {
        Button {
            storeReflection(word)
            withAnimation(JeniMotion.settle) { revealedAct = nil }
            refresh()
        } label: {
            Text(word)
                .font(.custom("JeniHeroSerif-Regular", size: 23, relativeTo: .title3))
                .foregroundStyle(Palette.textPrimary)
                .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
    }

    private func actPlan(_ option: TonightPlan.Option) -> some View {
        Button {
            TonightPlan.set(option.key, dayKey: TodayStateService.dayKey())
            Haptics.soft()
            withAnimation(JeniMotion.settle) { revealedAct = nil }
            refresh()
        } label: {
            Text(option.label)
                .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                .foregroundStyle(Palette.textPrimary)
                .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
    }

    // MARK: - Presentations (ported verbatim)

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

    private func maybePresentBodyIntro() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-body-intro") {
            showBodyIntro = true
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--uitest-inapp-qa") {
            return
        }
        #endif
        guard bodyIntroSeenAt.isEmpty,
              !BodyScanStore.consentSeen,
              let snapshot, snapshot.isEnrolled, snapshot.programDay >= 2
        else { return }
        bodyIntroSeenAt = ISO8601DateFormatter().string(from: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showBodyIntro = true
        }
    }

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
        if args.contains("--uitest-inapp-qa") { return }
        #endif
        guard letterPresentedDayKey != TodayStateService.dayKey() else { return }
        letterPresentedDayKey = TodayStateService.dayKey()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard modules.activeCover == nil, router.tab == .today else { return }
            modules.present(cover: .jeniNote)
        }
    }

    private func maybeOfferReconciliation() {
        guard !userId.isEmpty, !Self.reconciliationOfferedThisSession else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-suppress-reconcile") { return }
        #endif
        if case let .needsConfirmation(plan) = CareReconciliation.state(userId: userId, in: modelContext) {
            Self.reconciliationOfferedThisSession = true
            reconcilePlan = plan
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard !showUpgradeMoment else { return }
                showReconcile = true
            }
        }
    }
    nonisolated(unsafe) private static var reconciliationOfferedThisSession = false

    // MARK: - Copy (ported verbatim)
    //
    // Marking flows through TodayModuleState.mark() — the chokepoint
    // that owns the checklist write, the sync, and the medication
    // observation dual-write. The quick-toggle path died with v11's
    // override law (long-press = MarkAsDoneSheet, always).

    private func moveNote(
        _ move: CarePlanEngine.Move, snapshot: TodaySnapshot, ring: Bool
    ) -> String? {
        if isEvening,
           ring,
           !beatState(move.beat, snapshot: snapshot).isDone {
            return "still open"
        }
        if case .medication = move.beat,
           beatState(move.beat, snapshot: snapshot).isDone {
            return doseTakenNote() ?? "taken"
        }
        if let because = move.because { return because }
        if !ring {
            let base = beatSubtitle(move.beat, snapshot: snapshot)
            return base.map { "\($0) · if it fits today" } ?? "if it fits today"
        }
        return beatSubtitle(move.beat, snapshot: snapshot)
    }

    private func oneThingTitle(
        _ beat: ProgramDayPrescription, snapshot: TodaySnapshot
    ) -> (text: String, italic: [String]) {
        switch beat {
        case .snapMeal:
            // v11.5 (founder): "plate" is OUR word, not hers — "add the
            // next plate" left users guessing what a plate is. The ask
            // says MEAL, and says it plainly.
            if snapshot.chapter == .onMedication {
                return ("add a small meal, protein first", ["protein first"])
            }
            if snapshot.plates.isEmpty {
                if snapshot.programDay <= 2 {
                    return ("add what you last ate", ["last"])
                }
                return ("add your first meal", ["first"])
            }
            return ("add your next meal", ["next"])
        case .workout(_, let minutes, _):
            return ("move for \(minutes) minutes", ["move"])
        case .lesson:
            return ("today's 2-minute lesson", ["lesson"])
        case .weighIn:
            return ("weigh in", ["weigh"])
        case .breath:
            return ("60 seconds of breath", ["60 seconds"])
        case .medication:
            return ("mark today's dose", ["dose"])
        case .bodyScan:
            return ("your weekly scan", ["scan"])
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
                return snapshot.programDay <= 2
                    ? "even coffee counts. no grading here"
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
        case .medication:
            return "recorded with one tap"
        case .bodyScan:
            return "a few seconds · stays on your phone"
        case .steps, .plank, .water, .measurements:
            return nil
        }
    }

    private func beatTitle(_ beat: ProgramDayPrescription) -> String {
        switch beat {
        case .snapMeal: return "add a meal"
        case .workout: return "move"
        case .lesson: return "the method"
        case .steps(let goal): return "\(goal.formatted()) steps"
        case .weighIn: return "trend check"
        case .breath: return "breathe"
        case .plank: return "hold"
        case .water: return "water"
        case .measurements: return "measure"
        case .medication: return "your medication"
        case .bodyScan: return "body scan"
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
        case .plank, .measurements:
            return nil
        case .water(let ml):
            return "about \(ml.formatted()) ml across the day"
        case .medication:
            return "dose day · mark it when taken"
        case .bodyScan:
            return "a few seconds · stays on your phone"
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

    // MARK: - Evening + reflection (ported)

    private var isEvening: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-evening") {
            return true
        }
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-day") {
            return false
        }
        #endif
        return Calendar.current.component(.hour, from: .now) >= 18
    }

    private var daySealed: Bool {
        guard let snapshot else { return false }
        let total = snapshot.carePlan.actionableBeats.count
        return total > 0 && snapshot.completedBeatCount >= total
    }

    private func doseTakenNote() -> String? {
        let record = ObservationStore.fetch(
            id: ObservationStore.deterministicId(
                userId: userId, kind: .doseTaken,
                dayKey: TodayStateService.dayKey()
            ),
            in: modelContext
        )
        guard let record, record.valueText == "yes" else { return nil }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return "taken · \(f.string(from: record.updatedAt))"
    }

    private func storeReflection(_ feeling: String) {
        let key = TodayStateService.dayKey()
        UserDefaults.standard.set(feeling, forKey: "day.reflection.\(key)")
        ObservationStore.record(
            .feeling, valueText: feeling, dayKey: key,
            userId: userId, in: modelContext
        )
        Haptics.soft()
    }

    // MARK: - Refresh + routing (ported; the mirror reads retired)

    private func refresh() {
        guard !userId.isEmpty else { return }
        let fresh = TodayStateService.snapshot(userId: userId, in: modelContext)
        snapshot = fresh

        // The close arrives on its own, once, the first time Home is
        // seen after the evening turns — the way a good notification
        // would. Every later visit uses the invitation row.
        if isEvening,
           fresh.isEnrolled,
           eveningMomentDayKey != TodayStateService.dayKey(),
           !showEveningMoment {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                guard isEvening, !showEveningMoment else { return }
                showEveningMoment = true
            }
        }

        if fresh.isEnrolled {
            NotificationOrchestrator.refreshDailyAnchor(
                programDay: fresh.programDay,
                totalDays: fresh.totalDays
            )
        }

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
            if let day = snapshot?.day,
               let beat = day.beats.first(where: {
                   if case .workout = $0 { return true } else { return false }
               }) {
                modules.open(beat, snapshot: snapshot)
            }
        case .steps: modules.present(sheet: .stepsDetail)
        case .bodyScan: modules.present(cover: .bodyScan)
        case .trend: break
        }
    }

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
