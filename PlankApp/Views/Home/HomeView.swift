import SwiftUI
import SwiftData
import Combine
import UIKit
import UserNotifications
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
    /// Day-complete silk sweep. -1 baseline so a restored complete
    /// day never replays it.
    @State private var silkTrigger = 0
    /// p64 — the delight layer's burst tokens (JeniBurst plays on
    /// increment; CelebrationLedger owns eligibility, so these move
    /// at most once per moment per day).
    @State private var waterBurst = 0
    @State private var stepsBurst = 0
    @State private var lastCompletedCount = -1
    @State private var showUpgradeMoment = false
    @AppStorage("upgradeMoment.shownV1") private var upgradeMomentShown = false
    @State private var detailPlate: FoodLogPersister.FoodLogEntry?
    @State private var reconcilePlan: RegimenPlanRecord?
    @State private var showReconcile = false
    /// Non-nil while the plan-numbers repair door is open, carrying which
    /// fact it should land on.
    @State private var repairFocus: JKPlanNumbersSheet.Fact? = nil
    @State private var qaShowCareConnect = false
    @State private var qaShowRegimen = false
    @State private var qaShowSideEffects = false
    @AppStorage("letter.presentedDayKey") private var letterPresentedDayKey = ""
    /// The evening close, as its own full screen. Auto-arrives once
    /// per evening; the invitation row re-opens it any time.
    @State private var showEveningMoment = false
    @AppStorage("evening.moment.presentedDayKey") private var eveningMomentDayKey = ""
    /// A connected clinic is the only reason the care-team's written
    /// instructions may render (10_S4_CLINIC_LOOP §10).
    @AppStorage("care_entitlement_active") private var careEntitlementActive = false
    @State private var careSupportsExpanded = false

    /// The page's single arrival flag (L12).
    @State private var arrived = false
    @Environment(\.dynamicTypeSize) private var typeSize
    /// v11.5 — the strip's selection. Today by default; past days
    /// re-key the page to that day's record.
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    /// v12 D13 — which side the recap slides in from. Set BEFORE the
    /// morph commits (the strip's onChange runs in the same
    /// transaction), so the insertion reads the travel direction.
    @State private var recapDirection: CGFloat = 24

    private var userId: String {
        auth.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if let snapshot {
                        // p59 — THE MASTHEAD: the greeting above, the
                        // program position SET beneath it as a dateline
                        // (tracked caps · a short rule · the week's word
                        // in the serif italic) instead of worn as a pink
                        // capsule. Typography carries what furniture was
                        // carrying. The dateline keeps everything the
                        // chip held: the letter on tap, settings on
                        // hold. One structure at every type size — a
                        // stack cannot truncate her name (§10.2).
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                                greeting
                                Spacer(minLength: Space.sm)
                                settingsGear
                            }
                            dateline(snapshot)
                        }
                        .jkSilkSweep(trigger: silkTrigger)
                        .padding(.top, Space.sm)
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
                        .padding(.top, Space.bandRow)
                        .jeniArrive(arrived, index: 1)

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
                            .jeniArrive(arrived, index: 2)
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
                            doseStandingRow(snapshot)

                            HomeNutritionSummary(
                                snapshot: snapshot,
                                userId: userId,
                                // p54 — the instrument opens THE BOOK
                                // (today's spread), not the camera: a
                                // READING's tap should land on the
                                // record it reads, and the capture
                                // doors are already abundant (the
                                // centre tab, the tools, the letter).
                                // The p53 §19 proposal, shipped: one
                                // navigation, zero new surfaces.
                                onOpenFood: { AppRouter.shared.open(.plates) },
                                // The empty denominator becomes a door.
                                // Opening on the missing fact is the
                                // point: "one tap into the exact missing
                                // fact" rather than a settings hunt.
                                onRepairNumbers: { missing in
                                    repairFocus = {
                                        switch missing {
                                        case .weight:    return .weight
                                        case .height:    return .height
                                        case .goal:      return .goal
                                        case .direction: return .direction
                                        }
                                    }()
                                }
                            )
                            // The standing already opened the band; a
                            // second bandGap under it stacked ~100pt of
                            // dead air above the ring (frame-caught).
                            .padding(.top, snapshot.doseStanding == nil
                                     ? Space.bandGap : Space.blockGap)
                            .jeniArrive(arrived, index: 3)

                            daySection(snapshot)
                                .jeniArrive(arrived, index: 4)

                            // Pass 52 — THE DAY-ONE CONTRACT: after her
                            // first record files, one card names what
                            // pays out tomorrow, and THAT is the
                            // notification moment (R1's close — the ask
                            // rides a promise she just watched come
                            // true, never a launch dialog).
                            dayOneContractCard(snapshot)
                                .jeniArrive(arrived, index: 5)

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
                                .jeniArrive(arrived, index: 5)
                            }

                            toolsSection(snapshot)
                                .jeniArrive(arrived, index: 6)
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
                    JeniAtmosphere(
                        height: 380,
                        // The page's light rests while a full-screen
                        // cover owns the stage (its own atmosphere
                        // does the breathing there).
                        paused: modules.activeCover != nil
                            || showEveningMoment || showUpgradeMoment
                    )
                }
                .ignoresSafeArea()
            }
            .refreshable { refresh() }
            .jeniTopScrollEdge()
            // The masthead scrim — the kit's one law (p62).
            .jeniMastheadScrim()
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--uitest-today-bottom") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        proxy.scrollTo("today.bottom", anchor: .bottom)
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--uitest-plate-detail") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        // `--uitest-plate-corrected` opens the plate she
                        // FIXED, which is the only way to film the "your
                        // numbers" tier. Without it the door opens the
                        // first plate, as it always has.
                        let corrected = ProcessInfo.processInfo.arguments
                            .contains("--uitest-plate-corrected")
                        detailPlate = corrected
                            ? (snapshot?.plates.first(where: { $0.wasCorrected })
                               ?? snapshot?.plates.first)
                            : snapshot?.plates.first
                    }
                }
                // v25 E4 — the again rail, straight from launch
                // (films the sheet; pairs with --uitest-seed-week).
                if ProcessInfo.processInfo.arguments.contains("--uitest-open-again-sheet") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        modules.present(sheet: .recentMeals)
                    }
                }
                // E8.2 — JENI MOVE without a tab tap (simctl can't
                // tap): the same sheet the steps beat and the .move
                // route open. Pairs with --debug-hk-write-move for
                // the real-read proof and films.
                if ProcessInfo.processInfo.arguments.contains("--uitest-open-move") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        modules.present(sheet: .stepsDetail)
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
        .jeniCover(isPresented: $showEveningMoment) {
            if let snapshot {
                HomeEveningMoment(
                    snapshot: snapshot,
                    onReflect: { feeling in storeReflection(feeling) },
                    onDismiss: {
                        eveningMomentDayKey = TodayStateService.dayKey()
                        showEveningMoment = false
                    }
                )
            } else {
                // Unreachable through the arbiter (eligibility needs a
                // snapshot), but a cover with no exit is a trap — the
                // kit's own law. Self-dismiss instead of a blank wall.
                Color.clear.onAppear { showEveningMoment = false }
            }
        }
        .onAppear {
            refresh()
            readNotificationAskState()
            runAutoPresent()
            // p61 — a route set BEFORE Home mounted (a notification
            // tapped at cold launch: NotificationDelegate writes
            // pendingRoute while the phase is still .booting) never
            // fires onChange, so "log your meal" landed on Home with
            // nothing open. Becoming has carried this same onAppear
            // consumer since E4; Home finally does too.
            consume(router.pendingRoute)
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--uitest-open-care-connect") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { qaShowCareConnect = true }
            }
            if args.contains("--uitest-open-regimen") {
                // p53 — the same identity wait the dose door earned:
                // a fixed +0.4s raced auth restore under the test
                // runner and presented nothing (an identity-less
                // sheet on a slower launch).
                func openRegimenWhenReady(_ attempts: Int = 0) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        if !userId.isEmpty {
                            qaShowRegimen = true
                        } else if attempts < 10 {
                            openRegimenWhenReady(attempts + 1)
                        }
                    }
                }
                openRegimenWhenReady()
            }
            // v24 — THE DOSE SHEET's film door. v25 E2: the slot
            // derives at the chokepoint, so an open late slot opens
            // its LATE face (label facts on film). The door WAITS
            // for identity — a +0.4s fixed delay raced auth restore
            // and opened a plan-less sheet (frame-caught).
            if args.contains("--uitest-open-dose-sheet") {
                func openWhenReady(_ attempts: Int = 0) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        if !userId.isEmpty {
                            modules.present(sheet: .doseSheet(
                                slotDayKey: modules.currentDoseSlotKey()
                            ))
                        } else if attempts < 10 {
                            openWhenReady(attempts + 1)
                        }
                    }
                }
                openWhenReady()
            }
            // v25 E2 — the symptom logger's film door (new chips +
            // the mood support card).
            if args.contains("--uitest-open-side-effects") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { qaShowSideEffects = true }
            }
            #endif
        }
        #if DEBUG
        .jeniSheet(isPresented: $qaShowCareConnect, detents: JeniSheetHeight.full) {
            CareConnectionSheet(userId: userId, onClose: { qaShowCareConnect = false })
        }
        .jeniSheet(isPresented: $qaShowRegimen, detents: JeniSheetHeight.full) {
            RegimenSheet(userId: userId, onDone: { qaShowRegimen = false })
        }
        .jeniSheet(isPresented: $qaShowSideEffects) {
            SideEffectSheet(userId: userId, onDone: { qaShowSideEffects = false })
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refresh()
                // The OS is the authority on the notification ask —
                // Settings can change it while we're backgrounded, so
                // the card's gate re-reads on every return.
                readNotificationAskState()
                // p61 — a foreground return is an ARRIVAL: the same
                // director run as an appear. Before this, a loser's
                // "goes next time" only came on a tab switch or a
                // relaunch, and the evening close bypassed arbitration
                // entirely to fire from refresh().
                runAutoPresent()
            }
        }
        // Release audit 2026-08-08 — an app left foregrounded across
        // midnight kept showing yesterday (checklist, greeting, food
        // day, evening close) until the next touch; nothing observed
        // the day change. iOS posts this on day rollover, timezone
        // changes, and significant clock changes alike.
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refresh()
            // Midnight is an arrival too — the new day's letter can
            // speak without waiting for a background/foreground cycle.
            runAutoPresent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appSyncDidHydrate)) { _ in
            // The launch hydrate landed (plans, weights, doses,
            // program facts). Recompose from the record it just wrote.
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .attPromptSettled)) { _ in
            // The system dialog has left the stage; the held arrival
            // plays now.
            runAutoPresent()
        }
        // p62 — publish Home's slot occupancy to the shared gate so
        // becoming's director never fires into the letter, the close,
        // or an open module cover.
        .onChange(of: anyHomeSurfaceUp) { _, isUp in
            PresentationGate.shared.set(.home, up: isUp)
        }
        // p55 — the SHEET analog of the cover refresh below: the Move
        // sheet records/deletes strength sessions and the strength
        // tile reads MoveManualStore during body evaluation, so a
        // dismissal without a refresh left Home counting a session she
        // just removed (or missing one she just recorded) until the
        // next backgrounding.
        .onChange(of: modules.activeSheet) { old, new in
            guard old != nil, new == nil else { return }
            refresh()
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
        .onReceive(NotificationCenter.default.publisher(
            for: ProgramFactStore.didChange
        )) { _ in refresh() }
        .onChange(of: router.pendingRoute) { _, route in
            consume(route)
        }
        .onChange(of: steps.todayCount) { _, count in
            autoCompleteStepsIfCrossed(count)
        }
        .jeniSheet(item: $repairFocus, detents: JeniSheetHeight.full) { fact in
            JKPlanNumbersSheet(
                focus: fact,
                onClose: { repairFocus = nil; refresh() }
            )
        }
        .jeniSheet(item: $detailPlate, detents: JeniSheetHeight.full) { plate in
            PlateDetailSheet(
                entry: plate,
                userId: userId,
                onDismiss: { detailPlate = nil }
            )
        }
        .jeniSheet(isPresented: $showReconcile, detents: JeniSheetHeight.full) {
            if let reconcilePlan {
                ReconciliationSheet(
                    userId: userId, plan: reconcilePlan,
                    onClose: { showReconcile = false; refresh() }
                )
            }
        }
        .jeniCover(isPresented: $showUpgradeMoment) {
            UpgradeMomentView(
                programDay: snapshot?.programDay ?? 0,
                receipt: upgradeReceipt,
                onDone: { showUpgradeMoment = false }
            )
        }
    }

    // MARK: - The dateline (the letter's door)

    /// p59 — the program position as a SET line: `DAY 12 — the steady
    /// week`. The caps are Fraunces (the ornament register), the rule
    /// is a hairline, the week's word is the serif italic — a
    /// magazine's dateline, not a pill. It keeps everything the old
    /// chip carried: the letter on tap, settings on hold, the full
    /// position in its spoken label.
    private func dateline(_ snapshot: TodaySnapshot) -> some View {
        Button {
            Haptics.light()
            modules.present(cover: .jeniNote)
        } label: {
        HStack(spacing: 8) {
            Text(datelineCaps(snapshot))
                .font(.custom("Fraunces72pt-SemiBold", size: 11, relativeTo: .caption2))
                .tracking(1.8)
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary.opacity(0.65))
                .lineLimit(1)
            if let word = datelineWord(snapshot) {
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(width: 22, height: 0.5)
                Text(word)
                    .font(.custom("JeniHeroSerif-Italic", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            // p63 — the letter's unread mark: a berry dot while
            // today's letter waits. The one honest cue that this
            // line is a DOOR — the product's most-loved surface hid
            // behind editorial typography with no affordance at all.
            // Reading the letter (any path) retires the dot.
            if letterPresentedDayKey != TodayStateService.dayKey() {
                Circle()
                    .fill(Palette.roseBerry)
                    .frame(width: 5, height: 5)
                    .transition(.opacity)
            }
        }
        // p63 — a 16pt-tall strip was the letter's whole tap target.
        // The padding grows the hit shape to ~44pt and the negative
        // margin hands the layout back; the strip's discs sit later
        // in the tree and keep winning their own territory.
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .padding(.vertical, -14)
        // The dateline is chrome typography, like the strip's discs
        // right beneath it: it caps at XXXL rather than truncating
        // ("DAY… — the pro…" at AX5, frame-caught). The spoken label
        // always carries the full position.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        // p63 — a real Button (press acknowledgment included; the
        // gesture modifier had none), and the hold-for-settings died:
        // the gear sits 44pt away, visible, doing the same thing. One
        // door, one path; a hidden duplicate is drift, not depth.
        .buttonStyle(JKPress())
        .accessibilityIdentifier("jeni.line")
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            daySealed
                ? "\(datelineText), kept. opens today's letter"
                : "\(datelineText). opens today's letter"
        )
    }

    /// The caps half: the program day when enrolled, the date before.
    private func datelineCaps(_ snapshot: TodaySnapshot) -> String {
        guard snapshot.isEnrolled else {
            return Date.now.formatted(.dateTime.month(.wide).day()).uppercased()
        }
        return "DAY \(max(snapshot.programDay, 1))"
    }

    /// The italic half: the week's own word when the program named
    /// one, the calendar date otherwise. Nil before enrollment — the
    /// caps already state the date.
    private func datelineWord(_ snapshot: TodaySnapshot) -> String? {
        guard snapshot.isEnrolled else { return nil }
        if let intent = snapshot.weekIntent {
            return intent.name
        }
        return Date.now.formatted(.dateTime.month(.wide).day()).lowercased()
    }

    private var settingsGear: some View {
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

    /// The hour's word plus her name, when she gave one. The name
    /// takes the softer ink so the two read as a single breath.
    private var greeting: some View {
        // E8.1 — the THIRD hour source. E8 recorded two (`isEvening` vs
        // `hourOfDay`); the greeting was a third, reading the wall clock
        // directly, so `--uitest-force-hour 10` produced a morning day
        // composer under an "evening, maya." headline in the same frame.
        // Caught by filming, not by a test.
        let hour = AppClock.hourOfDay
        let word = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
        let name = (UserDefaults.standard.string(forKey: "userName") ?? "")
            .trimmingCharacters(in: .whitespaces)
        // v25 E9, XXXL frame-caught: this was an HStack of two Texts, so
        // each wrapped INDEPENDENTLY — at accessibility sizes the roman
        // half broke after "afternoon" and stranded its own comma on a
        // line of its own beneath the name ("afternoonmaya." over ",").
        // Concatenated Text is one run with two faces: it wraps as a
        // single phrase and the comma can never separate from the word
        // it follows.
        let roman = Text(name.isEmpty ? "\(word)." : "\(word), ")
            .font(.custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title2))
            .foregroundColor(Palette.textPrimary)
        let italic = Text(name.lowercased() + ".")
            .font(.custom("JeniHeroSerif-Italic", size: 24, relativeTo: .title2))
            .foregroundColor(Palette.textPrimary.opacity(0.42))
        return (name.isEmpty ? roman : roman + italic)
            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Which days of the visible weeks she actually KEPT — the strip's
    /// rings are her record, never decoration (L8).
    private var keptDays: Set<Date> {
        guard !userId.isEmpty else { return [] }
        return ProgramService.shared.keptDayStarts(userId: userId, in: modelContext)
    }

    private var isSelectedToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var datelineText: String {
        // v11.5: the greeting names the moment and the strip names the
        // date, so repeating "wednesday, august 5" here was the page
        // saying the same thing three times. The dateline carries only
        // what neither says: where she is in the program — v13: with
        // the week's intent folded in, one line instead of two.
        guard let snapshot, snapshot.isEnrolled else {
            return Date.now.formatted(.dateTime.month(.wide).day()).lowercased()
        }
        let base = "day \(max(snapshot.programDay, 1)) of \(snapshot.totalDays)"
        if let intent = snapshot.weekIntent {
            return "\(base) · \(intent.name)"
        }
        return base
    }

    // MARK: - TODAY (the checklist)

    /// THE STANDING (2026-08-13) — "when is my next shot, and did I
    /// take the last one?"
    ///
    /// Measured over the three days these events have existed: 42
    /// users configured a regimen, 34 logged a side effect, **3 ever
    /// marked a dose taken.** The capability was never the problem —
    /// the mark was a to-do row ~1,400pt down the page on dose day,
    /// and on every other day Home said nothing about her medication
    /// at all. She could not learn when her next shot was without
    /// opening a sheet behind a row she had to scroll to find.
    ///
    /// One line, directly under the strip she already reads, above
    /// everything. It is not a card and it is not a to-do: it states
    /// where she is, and the tap opens the slot it names.
    ///
    /// **For a non-medicated user this draws nothing** — `doseStanding`
    /// is nil by construction without a scheduled regimen, so the
    /// non-GLP-1 product gains zero medication pixels.
    @ViewBuilder
    private func doseStandingRow(_ snapshot: TodaySnapshot) -> some View {
        if let standing = snapshot.doseStanding {
            let read = DoseStanding.read(
                standing, isOral: snapshot.doseRouteIsOral
            )
            // p59 — the standing is an OBJECT now, not a floating text
            // pair: a hairline-bordered row in the clinical register
            // (ink seat, SF glyph, no rose, no celebration). Between
            // the strip's discs and the band's serif, a bare line read
            // as an accident; a bordered object anchors without
            // borrowing the task list's card weight.
            Button {
                JeniHaptic.tick()
                switch standing {
                case .dueToday, .late:
                    modules.present(sheet: .doseSheet(
                        slotDayKey: modules.currentDoseSlotKey()
                    ))
                case .doneToday, .skippedToday, .upcoming:
                    qaShowRegimen = true
                }
            } label: {
                HStack(alignment: .center, spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(Palette.textPrimary.opacity(0.05))
                        Image(systemName: snapshot.doseRouteIsOral
                              ? "pills" : "cross.vial")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Palette.textPrimary.opacity(0.75))
                    }
                    .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(read.headline)
                            .font(.custom("DMSans-SemiBold", size: 15.5,
                                          relativeTo: .subheadline))
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail = read.detail {
                            Text(detail)
                                .font(.custom("DMSans-Regular", size: 12,
                                              relativeTo: .caption))
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: Space.sm)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .strokeBorder(Palette.textPrimary.opacity(0.08), lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: Radius.row,
                                               style: .continuous))
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.bandGap)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(read.voiceOver)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home.doseStanding")
            // p61 — was index 1, duplicating the calendar strip's: two
            // adjacent blocks arrived together and the cascade skipped
            // a beat. Every block steps once now.
            .jeniArrive(arrived, index: 2)
        }
    }

    /// The medication beat the standing has already spoken for, or nil.
    /// Only today's slot is ever hidden — an `.upcoming` or `.late`
    /// standing names a day that is not today, so the list keeps
    /// whatever it holds for today.
    private func hiddenMedicationBeat(
        _ snapshot: TodaySnapshot
    ) -> ProgramDayPrescription? {
        guard let standing = snapshot.doseStanding else { return nil }
        switch standing {
        case .late, .upcoming:
            return nil
        case .dueToday, .doneToday, .skippedToday:
            return snapshot.carePlan.actionableBeats
                .first(where: { $0 == .medication })
        }
    }

    @ViewBuilder
    private func daySection(_ snapshot: TodaySnapshot) -> some View {
        // The standing above carries today's dose; a second medication
        // row in the list would be the same fact twice on one screen.
        // Suppressed at the RENDER, never in the plan — CarePlanEngine,
        // completion counting, quick-mark and analytics all still see
        // the beat, so only the two numbers this view draws change.
        let hidden = hiddenMedicationBeat(snapshot)
        let hiddenDone = hidden.map { beat -> Bool in
            let s = snapshot.checkStates[beat.itemKey] ?? "empty"
            return s == "complete" || s == "autoCompleted"
        } ?? false
        let doneCount = snapshot.completedBeatCount - (hiddenDone ? 1 : 0)
        let totalCount = snapshot.carePlan.actionableBeats.count
            - (hidden == nil ? 0 : 1)
        VStack(alignment: .leading, spacing: 0) {
            // One shape, every hour of the day. In the evening the
            // header names what it is — the rest, not the whole day.
            // v12 — the header carries the day's quiet count; it
            // morphs as tasks land (numbers count, §4.3).
            HStack(alignment: .firstTextBaseline) {
                JeniSectionHeader(isEvening ? "still today" : "today",
                                  topAir: Space.bandGap)
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
            if let lead = snapshot.carePlan.lead, lead.beat != hidden {
                leadAsk(lead, snapshot: snapshot)
            } else if snapshot.carePlan.lead == nil {
                JeniHeadline(
                    snapshot.carePlan.tone == .gentle
                        ? "a quiet day. nothing owed."
                        : "rest day. nothing scheduled.",
                    italic: snapshot.carePlan.tone == .gentle ? ["quiet"] : ["rest"]
                )
                .padding(.vertical, Space.sm)
            }
            planRows(snapshot, includeLead: false, hiding: hidden)

            if isEvening {
                eveningInvitation
                    .padding(.top, Space.blockGap)
            }
        }
    }

    /// The evening's one invitation, in the list's own grammar (v21
    /// D8: four blocks means four — the close is a ROW, not a fifth
    /// surface). A moon chip, no check; tapping opens the close.
    ///
    /// p63 — after goodnight the row compresses to the day's own
    /// receipt. It used to keep saying "close the day" all evening
    /// after she had just closed it — the one place on Home where
    /// the product forgot she acted seconds ago. Tapping the receipt
    /// reopens the close to revisit; nothing re-arms.
    private var eveningInvitation: some View {
        let closed = eveningMomentDayKey == TodayStateService.dayKey()
        return JeniTaskRow(
            title: closed ? "day closed" : "close the day",
            note: closed ? nil : "the receipt, the feeling, tomorrow",
            chip: .doodle("doodle-night"),
            isDone: closed,
            onOpen: {
                JeniHaptic.tick()
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { showEveningMoment = true }
            }
        )
        .accessibilityIdentifier("home.closeTheDay")
    }

    /// v21 §6.3 — the lead is the first OBJECT in the list: same row,
    /// a touch more weight, the dose-dot when promoted.
    @ViewBuilder
    private func leadAsk(_ lead: CarePlanEngine.Move, snapshot: TodaySnapshot) -> some View {
        taskRow(
            lead,
            snapshot: snapshot,
            title: oneThingTitle(lead.beat, snapshot: snapshot).text,
            note: lead.because ?? oneThingSubtitle(lead.beat, snapshot: snapshot),
            emphasized: true,
            showsDot: snapshot.carePlan.leadIsPromoted
        )
    }

    /// One object shape for the whole list (JeniTaskRow): identity
    /// chip · words · drawn check. Row tap opens the module, the
    /// check quick-marks, long-press raises the mark sheet.
    @ViewBuilder
    private func taskRow(
        _ move: CarePlanEngine.Move,
        snapshot: TodaySnapshot,
        title: String,
        note: String?,
        emphasized: Bool,
        showsDot: Bool = false
    ) -> some View {
        let done = beatState(move.beat, snapshot: snapshot).isDone
        JeniTaskRow(
            title: title,
            note: note,
            chip: beatChip(move.beat, snapshot: snapshot),
            isDone: done,
            emphasized: emphasized,
            clinical: isClinicalBeat(move.beat),
            showsDot: showsDot,
            onOpen: { modules.open(move.beat, snapshot: snapshot) },
            onQuickMark: {
                modules.mark(move.beat, state: done ? .empty : .complete)
                // p64 — an EXPLICIT completion of the walking ask is
                // her own act: the spark's haptic rides it (unlike
                // the witnessed auto-crossing, which stays visual).
                if case .steps = move.beat, !done {
                    celebrateStepsCrossing(haptic: true)
                }
            },
            onLongPress: { modules.present(sheet: .markAsDone(move.beat)) }
        )
        .overlay(alignment: .trailing) {
            if case .steps = move.beat {
                JeniBurst(tier: .spark, play: stepsBurst)
                    .frame(width: 320, height: 320)
                    .offset(x: 128)
            }
        }
    }

    /// A supporting task — the same object, unemphasized.
    @ViewBuilder
    private func taskCard(_ move: CarePlanEngine.Move, snapshot: TodaySnapshot) -> some View {
        taskRow(
            move,
            snapshot: snapshot,
            title: beatTitle(move.beat),
            note: moveNote(move, snapshot: snapshot, ring: true),
            emphasized: false
        )
    }

    /// An offered move — the same spine on bare paper, a hairline
    /// chip seat: an invitation, never debt. Same chip language as
    /// the owed rows (one voice per list — film-caught: SF walk
    /// beside doodle cutlery read as two icon sets).
    ///
    /// p64 — an offered row that HAPPENED renders done (before this,
    /// marking water done and crossing the step goal were invisible:
    /// the record moved, the row never did). Water is a one-tap mark
    /// with the spark riding its first completion of the day; steps
    /// complete on their own and celebrate only when the crossing is
    /// WITNESSED (an automatic fact never vibrates, §8.3).
    @ViewBuilder
    private func offeredCard(_ move: CarePlanEngine.Move, snapshot: TodaySnapshot) -> some View {
        let state = beatState(move.beat, snapshot: snapshot)
        switch move.beat {
        case .water:
            JeniTaskRow(
                title: beatTitle(move.beat),
                note: offeredDetail(move, snapshot: snapshot),
                chip: beatChip(move.beat, snapshot: snapshot),
                offered: true,
                isDone: state.isDone,
                onOpen: { toggleWater(move.beat, done: state.isDone, fromRow: true) },
                onQuickMark: { toggleWater(move.beat, done: state.isDone, fromRow: false) }
            )
            .overlay(alignment: .trailing) {
                JeniBurst(tier: .spark, play: waterBurst)
                    .frame(width: 320, height: 320)
                    .offset(x: 128)
            }
        case .steps:
            JeniTaskRow(
                title: state.isDone
                    ? "\(steps.todayCount.formatted()) steps"
                    : beatTitle(move.beat),
                note: offeredDetail(move, snapshot: snapshot),
                chip: beatChip(move.beat, snapshot: snapshot),
                offered: true,
                isDone: state.isDone,
                onOpen: { modules.open(move.beat, snapshot: snapshot) }
            )
            .overlay(alignment: .trailing) {
                JeniBurst(tier: .spark, play: stepsBurst)
                    .frame(width: 320, height: 320)
                    .offset(x: 128)
            }
            .onChange(of: state.isDone) { was, isNow in
                guard !was, isNow else { return }
                celebrateStepsCrossing(haptic: false)
            }
        default:
            JeniTaskRow(
                title: beatTitle(move.beat),
                note: offeredDetail(move, snapshot: snapshot),
                chip: beatChip(move.beat, snapshot: snapshot),
                offered: true,
                onOpen: { modules.open(move.beat, snapshot: snapshot) }
            )
        }
    }

    /// p64 — water is a one-tap fact: the row IS the control (the
    /// old path opened a confirm sheet for an act with no stakes,
    /// then rendered nothing). Marking the first time today sparks;
    /// re-marks and unmarks settle quietly.
    private func toggleWater(
        _ beat: ProgramDayPrescription, done: Bool, fromRow: Bool
    ) {
        if fromRow { JeniHaptic.land() }
        let marking = !done
        modules.mark(beat, state: marking ? .complete : .empty)
        guard marking else { return }
        let today = TodayStateService.dayKey()
        guard CelebrationLedger.shouldCelebrate(.waterDone, dayKey: today) else { return }
        CelebrationLedger.recordCelebrated(.waterDone, dayKey: today)
        JeniHaptic.spark()
        waterBurst += 1
        Analytics.track(.celebrationShown, properties: [
            "tier": "spark", "moment": "water_done",
        ])
    }

    /// p64 — the step goal's celebration: once per day, from the row
    /// that carries the fact. Witnessed auto-crossings stay silent to
    /// the hand (§8.3 — a passive event never vibrates); an explicit
    /// mark of the walking ask brings the spark's haptic with it.
    private func celebrateStepsCrossing(haptic: Bool) {
        let today = TodayStateService.dayKey()
        guard CelebrationLedger.shouldCelebrate(.stepsGoal, dayKey: today) else { return }
        CelebrationLedger.recordCelebrated(.stepsGoal, dayKey: today)
        if haptic { JeniHaptic.spark() }
        stepsBurst += 1
        Analytics.track(.celebrationShown, properties: [
            "tier": "spark", "moment": "steps_goal",
        ])
    }

    /// v21 D6 — the identity chip: the food row carries the day's
    /// LAST PLATE as a real photograph when one exists (the only
    /// photography on Home, and it is hers); everything else carries
    /// its DOODLE — the founder's hand-drawn set, the stationery
    /// stroke register §12.6 always preferred. Medication stays an
    /// unadorned SF glyph (the clinical register is set apart on
    /// purpose); plank keeps its SF fallback (legacy beat, no doodle).
    private func beatChip(
        _ beat: ProgramDayPrescription, snapshot: TodaySnapshot
    ) -> JeniTaskRow.Chip {
        if case .snapMeal = beat,
           let last = snapshot.plates.last,
           let photo = FoodPhotoStore.photo(entryId: last.id) {
            return .photo(photo)
        }
        if let doodle = beatDoodle(beat) {
            return .doodle(doodle)
        }
        return .symbol(beatSymbol(beat))
    }

    private func beatDoodle(_ beat: ProgramDayPrescription) -> String? {
        switch beat {
        case .snapMeal: return "doodle-cutlery"
        case .workout: return "doodle-shoe"
        case .lesson: return "doodle-book"
        case .steps: return "doodle-footprints"
        case .weighIn: return "doodle-scale"
        case .breath: return "doodle-wind"
        case .water: return "doodle-water"
        case .measurements: return "doodle-ruler"
        case .bodyScan: return "doodle-user"
        case .medication, .plank: return nil
        }
    }

    /// THE CLINICAL REGISTER — medication rows carry no rose.
    private func isClinicalBeat(_ beat: ProgramDayPrescription) -> Bool {
        if case .medication = beat { return true }
        return false
    }

    @ViewBuilder
    private func planRows(
        _ snapshot: TodaySnapshot,
        includeLead: Bool,
        hiding hidden: ProgramDayPrescription? = nil
    ) -> some View {
        let plan = snapshot.carePlan
        let leadRow: [CarePlanEngine.Move] = includeLead
            ? (plan.lead.map { [$0] } ?? [])
            : []
        let ringed = (leadRow + plan.supporting)
            .filter { hidden == nil || $0.beat != hidden }

        // v15: the list is one object — rows sit tight against each
        // other and the group breathes as a whole beneath the ask.
        VStack(spacing: 7) {
            ForEach(ringed, id: \.beat.itemKey) { move in
                taskCard(move, snapshot: snapshot)
            }
            ForEach(plan.offered, id: \.beat.itemKey) { move in
                offeredCard(move, snapshot: snapshot)
            }
            careSupportsLine
        }
        .padding(.top, ringed.isEmpty && plan.offered.isEmpty ? 0 : Space.sm)
    }

    /// THE CARE TEAM'S INSTRUCTION (10_S4_CLINIC_LOOP §10).
    ///
    /// When a clinic assigns its own protocol, the protocol can carry
    /// the clinic's written instructions. The law has always been
    /// precise about how they may appear: at most ONE attributed,
    /// observational line — never a checkable row, never a debt, never
    /// jeni's voice borrowing the clinic's authority. The seam was
    /// specified, the payload has shipped since S2, and nothing ever
    /// read it. This is the line.
    @ViewBuilder
    private var careSupportsLine: some View {
        let supports = CareProtocolStore.current.supports
        if careEntitlementActive, !supports.isEmpty {
            Button {
                Haptics.soft()
                withAnimation(Motion.entranceSoft) { careSupportsExpanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("your care team's plan includes")
                        .font(Typo.statLabel)
                        .tracking(0.06 * 11)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                    if careSupportsExpanded {
                        ForEach(supports.indices, id: \.self) { i in
                            if let note = supports[i].note, !note.isEmpty {
                                Text(note)
                                    .font(Typo.caption)
                                    .foregroundStyle(Palette.cocoaTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } else {
                        Text(supports.compactMap(\.note).first ?? "")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .overlay(alignment: .leading) {
                    // A hairline rule in the clinical register: this
                    // is recorded care, not a jeni suggestion.
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(width: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "your care team's plan includes. "
                    + supports.compactMap(\.note).joined(separator: " ")
            )
            .padding(.top, Space.xs)
        }
    }

    /// An offered row's detail without the "if it fits" suffix — the
    /// invitation moved to the trailing slot.
    private func offeredDetail(
        _ move: CarePlanEngine.Move, snapshot: TodaySnapshot
    ) -> String? {
        if let because = move.because { return because }
        return beatSubtitle(move.beat, snapshot: snapshot)
    }

    // MARK: - TOOLS (p59 — the index)

    /// p59 — the grid of tiles became an INDEX: five hairline rows,
    /// a doodle, a word, the state. The tiles were the page's noisiest
    /// block (uneven heights, a hole in the grid, wrapping statuses,
    /// three different instrument species) for the page's quietest
    /// job — a footer of doors. The live instruments went where their
    /// facts now live: the plates in the band's second face, the
    /// weight distance in its own status line, the steps in the plan
    /// row. A place still shows its weather — in words.
    @ViewBuilder
    private func toolsSection(_ snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            JeniSectionHeader("tools", topAir: Space.bandGap)
            VStack(spacing: 0) {
                toolRow("snap a meal", snapStatus(snapshot), doodle: "doodle-camera") {
                    modules.present(cover: .captureFlow)
                }
                toolHairline
                toolRow("weigh in", weighStatus(snapshot), doodle: "doodle-scale") {
                    modules.present(sheet: .logWeight)
                }
                toolHairline
                // E8.2 — the door stopped advertising the retired
                // 84-lesson curriculum: a note when the record has
                // one, her told-history otherwise.
                toolRow("the method", methodStatus(), doodle: "doodle-book") {
                    openMethodDoor()
                }
                toolHairline
                toolRow("breathe", "one minute", doodle: "doodle-wind") {
                    modules.present(cover: .breathSession)
                }
                toolHairline
                // E8.2 — "move" opens THE MOVEMENT RECORD; the guided
                // session keeps its own doors so the library's
                // retirement trigger stays measurable.
                toolRow("move", moveStatus(snapshot), doodle: "doodle-shoe") {
                    modules.present(sheet: .stepsDetail)
                }
            }
        }
    }

    private var toolHairline: some View {
        Rectangle()
            .fill(Palette.hairlineCocoa)
            .frame(height: 0.5)
            .padding(.leading, 34)
    }

    /// One index row: the doodle bare on the paper (no seat — the
    /// stationery register), the word, the state right-aligned. At
    /// accessibility sizes the state drops under the word.
    private func toolRow(
        _ word: String, _ status: String, doodle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            JeniHaptic.tick()
            action()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(doodle)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Palette.roseBerry.opacity(0.85))
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        toolWord(word)
                        toolStatus(status, trailing: false)
                    }
                } else {
                    toolWord(word)
                    Spacer(minLength: Space.sm)
                    toolStatus(status, trailing: true)
                }
                // p63 — the index rows read as a stats table (word ·
                // right-aligned value · no cue), while the dose row
                // one block up carries a chevron: two grammars for
                // one gesture. Navigation looks navigable now — the
                // dose row's own mark, the settings rows' own mark.
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(word). \(status)")
        .accessibilityAddTraits(.isButton)
    }

    private func toolWord(_ word: String) -> some View {
        Text(word)
            .font(.custom("DMSans-Medium", size: 15, relativeTo: .subheadline))
            .foregroundStyle(Palette.textPrimary)
            .lineLimit(2)
    }

    private func toolStatus(_ status: String, trailing: Bool) -> some View {
        Text(status)
            .font(.custom("DMSans-Regular", size: 11.5, relativeTo: .caption2))
            .foregroundStyle(Palette.cocoaTertiary)
            .multilineTextAlignment(trailing ? .trailing : .leading)
            .lineLimit(2)
    }

    // Every state line traces to a store (§1.6).

    private func snapStatus(_ snapshot: TodaySnapshot) -> String {
        let n = snapshot.plates.count
        if n == 0 { return "none yet today" }
        return n == 1 ? "1 plate today" : "\(n) plates today"
    }

    /// 2026-08-13 — the tile stated a fact about LOGGING on the one
    /// surface where the fact she came for is the weight. Every other
    /// tile names the thing ("4 plates today", "strength met this
    /// week"); this one said "last logged yesterday" beside an
    /// unlabelled sparkline, and Home carried no weight number at all.
    /// It leads with the distance now, and falls back to the cadence
    /// only while the record is too thin to claim one.
    private func weighStatus(_ snapshot: TodaySnapshot) -> String {
        if let journey = snapshot.weightJourney {
            return journey.changeLine()
        }
        guard let daysAgo = snapshot.lastWeighInDaysAgo else {
            return "takes 30 seconds"
        }
        if daysAgo <= 0 { return "logged today" }
        if daysAgo == 1 { return "last logged yesterday" }
        return "last logged \(daysAgo) days ago"
    }

    /// E8.2 — the tile states the record's one judgement: strength
    /// this week (HealthKit + hand-recorded), never a plan. Both
    /// figures trace to stores (§1.6); the anti-shame law holds — a
    /// week with one session says "one", not "you missed one".
    private func moveStatus(_ snapshot: TodaySnapshot) -> String {
        // p55 — the everRequested gate, matching Becoming's tile and
        // jeni's read_activity (three sites, one rule).
        let hk = MovementService.shared.everRequested
            ? MovementService.shared.strengthSessionsLast7 : 0
        let n = hk + MoveManualStore.strengthLastWeek()
        if n == 0 { return "what your body did" }
        if n >= MoveRecord.strengthTargetPerWeek { return "strength met this week" }
        return n == 1 ? "1 strength session in" : "\(n) strength sessions in"
    }

    /// E8.2 — what is actually behind the method door right now:
    /// today's note when one was shown, her kept notes otherwise,
    /// and an honest word about the silence-first design before any
    /// exist. Never a title from the retired 84-lesson manifest.
    private func methodStatus() -> String {
        // p54 — `entries()` is newest-first; reading `.last` here took
        // the OLDEST entry ever recorded, so "a note from your record"
        // survived only while the whole ledger was same-day and the
        // tile permanently degraded from day two on. The rule now
        // lives in the ledger (`latestEntry`), where it has a test.
        if let latest = MethodLedger.latestEntry(),
           Calendar.current.isDateInToday(latest.shownAt) {
            return "a note from your record"
        }
        if MethodLedger.latestEntry() != nil { return "what jeni has told you" }
        return "quiet until it matters"
    }

    /// E8.2 — the method door always lands somewhere real. The engine
    /// resolves BEFORE presenting: a note opens the note; silence
    /// opens what jeni has told you (the beat path keeps its own
    /// mark-and-close behaviour — silence completing a beat is
    /// correct there, a tile flashing open-shut is not).
    private func openMethodDoor() {
        var clinic = MethodClinicSource.Resolved.empty
        #if DEBUG
        clinic = MethodClinicSource.current()
        #endif
        let note: ResolvedMethodNote? = snapshot.flatMap {
            MethodEngine.note(
                MethodInputBuilder.input(
                    userId: userId, snapshot: $0,
                    clinic: clinic, in: modelContext
                )
            )
        }
        if note != nil {
            modules.openLesson(snapshot: snapshot)
        } else {
            modules.present(sheet: .methodTold)
        }
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

    // MARK: - The one auto-present slot (pass 57, D3)
    //
    // Eligibility is computed WITHOUT stamping; `HomeAutoPresent`
    // picks exactly one winner (reconcile › letter › upgrade); every
    // once-flag is stamped at the moment its surface actually
    // presents, never at schedule time. A loser keeps its eligibility
    // and goes on a later appear. Before this, four independent timers
    // raced one modal slot and two of them burned once-flags for
    // surfaces that never appeared — a morning letter could be marked
    // delivered and never shown.

    private var nothingPresented: Bool {
        !anyHomeSurfaceUp
            // p61 — MainShell's reauth sheet and post-purchase cover
            // occupy the same one-modal slot; firing into it was the
            // D3 failure class one level up. p62 — the gate is an
            // owner set now: becoming's covers and the scan chooser
            // answer here too.
            && !PresentationGate.shared.occupied(besides: .home)
    }

    /// Home's own contribution to the one-modal-slot truth — the same
    /// set `nothingPresented` reads, published so the OTHER directors
    /// (becoming's weekly read) can see an occupied slot.
    private var anyHomeSurfaceUp: Bool {
        modules.activeCover != nil || modules.activeSheet != nil
            || showReconcile || showUpgradeMoment
            || showEveningMoment
            || repairFocus != nil || detailPlate != nil
    }

    private func runAutoPresent() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--uitest-upgrade-moment") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showUpgradeMoment = true
            }
            return
        }
        if args.contains("--uitest-letter") {
            guard letterPresentedDayKey != TodayStateService.dayKey() else { return }
            letterPresentedDayKey = TodayStateService.dayKey()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                modules.present(cover: .jeniNote)
            }
            return
        }
        // p61 — the close presents only through the arbiter now, and
        // the arbiter stands down under the QA door; the film door
        // mirrors --uitest-letter so the surface stays filmable.
        if args.contains("--uitest-evening-close") {
            DispatchQueue.main.asyncAfter(deadline: .now() + HomeAutoPresent.settleBeat) {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { showEveningMoment = true }
            }
            return
        }
        if args.contains("--uitest-inapp-qa") { return }
        #endif
        // p61 — while the ATT system dialog is still owed for this
        // launch, every candidate stands down (eligibility survives).
        // The dialog is a legal requirement with its own settle beat;
        // racing a designed cover against it was the one collision the
        // arbiter couldn't see.
        if ATTService.promptIsPending {
            return
        }
        let winner = HomeAutoPresent.winner(
            reconcileEligible: reconcileEligible,
            eveningEligible: eveningEligible,
            letterEligible: letterEligible,
            upgradeEligible: upgradeEligible,
            isEvening: isEvening
        )
        switch winner {
        case .reconcile: presentReconcile()
        case .eveningClose: presentEveningClose()
        case .letter: presentLetter()
        case .upgrade: presentUpgrade()
        case nil: break
        }
    }

    private var eveningEligible: Bool {
        isEvening
            && (snapshot?.isEnrolled ?? false)
            && eveningMomentDayKey != TodayStateService.dayKey()
            && !showEveningMoment
    }

    private func presentEveningClose() {
        DispatchQueue.main.asyncAfter(deadline: .now() + HomeAutoPresent.settleBeat) {
            guard nothingPresented, isEvening, router.tab == .today,
                  eveningMomentDayKey != TodayStateService.dayKey()
            else { return }
            // The cover materializes and the moment owns its own
            // motion — the same grammar as every module cover.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { showEveningMoment = true }
        }
    }

    private var reconcileEligible: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-suppress-reconcile") { return false }
        #endif
        guard !userId.isEmpty, !Self.reconciliationOfferedThisSession else { return false }
        if case .needsConfirmation = CareReconciliation.state(userId: userId, in: modelContext) {
            return true
        }
        return false
    }

    private var letterEligible: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-suppress-letter") { return false }
        #endif
        guard let snapshot, snapshot.isEnrolled, !snapshot.isOnBreak,
              router.tab == .today,
              letterPresentedDayKey != TodayStateService.dayKey()
        else { return false }
        return true
    }

    private var upgradeEligible: Bool {
        !upgradeMomentShown
            && router.tab == .today
            && PaymentService.shared.activeProductIsWeekly
            && (snapshot?.programDay ?? 0) >= 6
    }

    private func presentReconcile() {
        guard case let .needsConfirmation(plan) =
            CareReconciliation.state(userId: userId, in: modelContext) else { return }
        reconcilePlan = plan
        DispatchQueue.main.asyncAfter(deadline: .now() + HomeAutoPresent.settleBeat) {
            guard nothingPresented else { return }
            Self.reconciliationOfferedThisSession = true
            showReconcile = true
        }
    }

    private func presentLetter() {
        DispatchQueue.main.asyncAfter(deadline: .now() + HomeAutoPresent.settleBeat) {
            guard nothingPresented, router.tab == .today,
                  let snapshot,
                  letterPresentedDayKey != TodayStateService.dayKey()
            else { return }
            letterPresentedDayKey = TodayStateService.dayKey()
            // v25 E4 — the morning read's honesty metric: which clause
            // claimed the day, and whether there was a record to read.
            Analytics.track(.morningReadShown, properties: [
                "clause": snapshot.brief.clause,
                "has_receipt": snapshot.brief.receipt != nil,
                "has_intention": snapshot.brief.carriesIntention,
            ])
            modules.present(cover: .jeniNote)
        }
    }

    private func presentUpgrade() {
        Task {
            // p61 — the fetch is bounded: a commerce cover landing at a
            // network-determined instant minutes into her session is
            // the one arrival nobody directed. Slow answer → stand
            // down; eligibility survives for the next arrival.
            let asked = Date()
            guard Purchases.isConfigured,
                  let offerings = try? await Purchases.shared.offerings(),
                  Date().timeIntervalSince(asked) < 5
            else { return }
            #if DEBUG
            let offering = offerings.all[RevenueCatConfig.previewOfferingID] ?? offerings.current
            #else
            let offering = offerings.current
            #endif
            let hasQuarter = offering?.availablePackages.contains {
                $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.quarterly
            } ?? false
            guard hasQuarter, !upgradeMomentShown, router.tab == .today,
                  nothingPresented else { return }
            upgradeMomentShown = true
            // Instant materialize; UpgradeMomentView stages its own
            // arrival — the cover grammar, everywhere.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { showUpgradeMoment = true }
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
            // v24 (founder brief): the checklist speaks the route's
            // noun. Weekly injectable leads with the shot; a daily
            // rhythm speaks pill/dose (it rides as support, but a
            // gentle day can lead with it).
            if snapshot.doseRouteIsOral {
                return ("take today's pill", ["pill"])
            }
            return snapshot.doseCadenceIsDaily
                ? ("take today's dose", ["dose"])
                : ("take today's shot", ["shot"])
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
                return "small plates count double · aim near \(target) g"
            }
            if snapshot.day?.archetype == .protein, let target = snapshot.targets.proteinG {
                return "protein first · aim near \(target) g"
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
            // E8.2 — never a title from the retired manifest.
            return "a 2-minute read"
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

    /// v18 — every task carries a SYMBOL so the list can be scanned
    /// without reading. The founder's explicit override of L3's
    /// "words, not icons" for this surface: a symbol that improves
    /// scanning earns its place. Meaning never rests on it alone —
    /// the title still says the thing (§10.8).
    private func beatSymbol(_ beat: ProgramDayPrescription) -> String {
        switch beat {
        case .snapMeal: return "fork.knife"
        case .workout: return "figure.walk"
        case .lesson: return "book"
        case .steps: return "figure.walk.motion"
        case .weighIn: return "scalemass"
        case .breath: return "wind"
        case .plank: return "figure.core.training"
        case .water: return "drop"
        case .measurements: return "ruler"
        case .medication: return "pills"
        case .bodyScan: return "camera.viewfinder"
        }
    }

    private func beatTitle(_ beat: ProgramDayPrescription) -> String {
        switch beat {
        case .snapMeal: return "add a meal"
        // E8.2 — "move" names the movement RECORD now (the tile); the
        // workout beat is an action, and its title says so.
        case .workout: return "a short session"
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
                    return "protein first · aim near \(target) g"
                }
                return "before you eat"
            }
            let n = snapshot.plates.count
            return n == 1 ? "one plate so far" : "\(n) plates so far"
        case .workout(let tier, let minutes, _):
            return "\(minutes) min · \(tierWord(tier))"
        case .lesson:
            // E8.2 — never a title from the retired manifest.
            return "a 2-minute read"
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
            // A number here is a care team's, or there is no number.
            // The instruction survives without one, and it is the one
            // the FDA medication guides actually give: take fluids,
            // because the GI events cost them.
            guard let ml else { return "sips through the day, not all at once" }
            return "about \(ml.formatted()) ml · your care team's aim"
        case .medication:
            // v24 — route-aware; the daily rhythm never says "dose
            // day" (every day would be one).
            if snapshot.doseCadenceIsDaily {
                return snapshot.doseRouteIsOral
                    ? "daily · mark it when taken"
                    : "daily dose · mark it when taken"
            }
            return "dose day · mark it when taken"
        case .bodyScan:
            return "a few seconds · stays on your phone"
        }
    }

    /// v25 §37 — one authority for the pace word. This was the third
    /// identical copy of the mapping; they agreed only because someone
    /// kept editing all of them.
    private func tierWord(_ tier: IntensityTier) -> String { tier.paceWord }

    /// p64 — delegates to BeatCompletion, the ONE testable authority
    /// (the rule lived in this view body; the offered rows never
    /// consulted it, which is how "marked water and nothing happened"
    /// shipped — the §36 lesson again).
    private func beatState(_ beat: ProgramDayPrescription, snapshot: TodaySnapshot) -> JKBeatState {
        BeatCompletion.state(
            for: beat,
            checkStates: snapshot.checkStates,
            stepsToday: steps.todayCount
        )
    }

    // MARK: - Evening + reflection (ported)

    /// E8.1 — one hour source. This used to read the wall clock directly
    /// while `TodayStateService.hourOfDay` read it through
    /// `--uitest-force-hour`, so the two could disagree inside one launch.
    private var isEvening: Bool { AppClock.isEvening }

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
        guard let record else { return nil }
        // v24 — a skipped dose compresses with its own quiet word.
        if record.valueText == "skipped" { return "not today" }
        guard record.valueText == "yes" else { return nil }
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

    // MARK: - THE DAY-ONE CONTRACT (pass 52)

    /// True while the OS notification ask has never been made — the
    /// only state the contract card may render in. Read from the real
    /// authorization on appear and on every foreground return, never
    /// remembered (the OS is the authority; Settings can change it).
    @State private var notifAskAvailable = false
    @State private var dayOneAnswered = DayOneContract.answered

    private func readNotificationAskState() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let available = settings.authorizationStatus == .notDetermined
            DispatchQueue.main.async {
                guard notifAskAvailable != available else { return }
                // p61 — this flip inserts/removes the day-one card
                // mid-column; unanimated it hard-appeared and shoved
                // the tools index under her thumb.
                withAnimation(JeniMotion.settle) { notifAskAvailable = available }
            }
        }
    }

    /// Records SHE made today: plates, a marked dose, a kept weigh-in
    /// (her own — the consult's onboarding self-report is not an
    /// in-app act). The promise must be about something she just did.
    private func recordsToday(_ snapshot: TodaySnapshot) -> Int {
        var n = snapshot.plates.count
        if case .doneToday = snapshot.doseStanding { n += 1 }
        let cal = Calendar.current
        if WeightSeries.records(userId: userId, in: modelContext)
            .contains(where: { cal.isDateInToday($0.loggedAt) }) {
            n += 1
        }
        return n
    }

    @ViewBuilder
    private func dayOneContractCard(_ snapshot: TodaySnapshot) -> some View {
        let decision = DayOneContract.decide(.init(
            answered: dayOneAnswered,
            osAskAvailable: notifAskAvailable,
            recordsToday: recordsToday(snapshot),
            wantsDoseReminder: snapshot.hasMedicationRegimen
                && (UserDefaults.standard.string(forKey: "onb_med_hour") ?? "none") != "none"
        ))
        if case .show(let line, let ask) = decision {
            VStack(alignment: .leading, spacing: 12) {
                Text(line)
                    .font(.custom("DMSans-Regular", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(ask)
                    .font(.custom("JeniHeroSerif-Italic", size: 16, relativeTo: .body))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button {
                        JeniHaptic.tick()
                        acceptDayOneContract()
                    } label: {
                        Text("yes, a quiet note")
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .callout))
                            .foregroundStyle(Palette.textInverse)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Palette.cocoaPrimary))
                    }
                    .buttonStyle(JeniPressable())
                    Button {
                        Haptics.light()
                        DayOneContract.markAnswered()
                        withAnimation(JeniMotion.settle) { dayOneAnswered = true }
                        Analytics.track("day_one_contract_declined")
                    } label: {
                        Text("no thanks")
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .callout))
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .tappableArea()
                    }
                    .buttonStyle(JKPress())
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.textPrimary.opacity(0.05), radius: 12, y: 5)
            )
            .padding(.top, Space.blockGap)
            .transition(.opacity)
            .onAppear { Analytics.track("day_one_contract_shown") }
            .accessibilityElement(children: .contain)
        }
    }

    /// The one place the app ever asks the OS for notifications on the
    /// entitled path. Granted → `notificationsEnabled` (the product's
    /// own switch, the same key Settings owns) and the standing
    /// schedulers re-arm on the refresh that follows; the medicated
    /// user's reminders re-derive through the same call `refresh`
    /// already makes. Denied → quiet. The card never returns either way.
    private func acceptDayOneContract() {
        DayOneContract.markAnswered()
        Analytics.track("day_one_contract_accepted")
        Task { @MainActor in
            let granted = await NotificationPermission.request()
            withAnimation(JeniMotion.settle) { dayOneAnswered = true }
            UserDefaults.standard.set(granted, forKey: "notificationsEnabled")
            Analytics.track("day_one_contract_permission", properties: [
                "granted": granted,
            ])
            readNotificationAskState()
            if granted {
                // The orchestrator's once-per-state guard predates the
                // grant; clear it so THIS refresh arms the ladder
                // instead of tomorrow's.
                NotificationOrchestrator.invalidateRefreshGuard()
                refresh()
            }
        }
    }

    // MARK: - Refresh + routing (ported; the mirror reads retired)

    private func refresh() {
        guard !userId.isEmpty else { return }
        let fresh = TodayStateService.snapshot(userId: userId, in: modelContext)
        snapshot = fresh

        // E8.2 — reconcile the food beat against the record itself
        // (self-heals exactly once: the second pass finds it marked).
        autoCompleteFoodIfPlated()

        // p61 — the close no longer schedules itself here. refresh()
        // runs on every tab switch, plate log, sheet dismissal and
        // foreground, so "arrives once, the first time Home is seen
        // after the evening turns" was actually "re-arms all evening
        // and can fire 0.9s after any interaction". It now presents
        // only through the arbiter, at an arrival moment — which is
        // the sentence above, finally enforced. Mid-session, the
        // invitation row is the door.

        if fresh.isEnrolled {
            let medPlan = RegimenService.activeMedicationPlan(
                userId: userId, in: modelContext
            )
            NotificationOrchestrator.refreshDailyAnchor(
                programDay: fresh.programDay,
                totalDays: fresh.totalDays,
                weeklyDoseAnchor: medPlan?.scheduleRule == "weeklyAnchor"
                    ? medPlan?.anchorWeekday : nil,
                // v25 E4 — tomorrow's morning rung carries today's
                // record; a plate landing tonight refreshes it.
                todayPlateCount: fresh.plates.count,
                todayProteinG: fresh.proteinEatenG > 0
                    ? fresh.proteinEatenG : nil
            )
        }

        // v24 — the dose reminder family re-derives at the same
        // composition point (replace, never stack), and the lazily-
        // derived missed stamps land before any surface reads
        // history. Cheap no-ops without an active regimen.
        if let plan = RegimenService.activeMedicationPlan(
            userId: userId, in: modelContext
        ) {
            DoseEventStore.stampMissedIfNeeded(
                userId: userId,
                facts: RegimenService.facts(for: plan),
                regimenPlanId: plan.id,
                in: modelContext
            )
            let uid = userId
            let context = modelContext
            Task { await MedicationReminders.refresh(userId: uid, in: context) }
        }

        // p58 — the launch/foreground heal: a regimen that arrived by
        // hydrate (reinstall, new phone) reconciles the cohort key
        // here, the same cadence CohortIdentity always ran on.
        RegimenService.reconcileCohortStatus(userId: userId, in: modelContext)
        // v25 E2 B1 — cohort identity re-derives at the same
        // composition point (fingerprint-deduped; a no-op when
        // nothing changed). Fires for the non-medicated too —
        // medicated=false is equally decision-relevant.
        CohortIdentity.refresh(userId: userId, in: modelContext)

        // p58 — the Home Screen widget rides the snapshot already in
        // hand (zero extra queries, no widget budget spent while the
        // app is foreground).
        WidgetBridge.publish(from: fresh)

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
        // v25 E4 — becoming-destined routes are becoming's to
        // consume. This always-mounted tab used to grab pendingRoute
        // first and swallow them with a bare `break`, so the chat's
        // "show me the weekly read" switched tabs and did nothing.
        switch route {
        case .trend, .weeklyRead, .plates: return
        default: break
        }
        router.pendingRoute = nil
        switch route {
        case .snap: modules.present(cover: .captureFlow)
        case .weighIn: modules.present(sheet: .logWeight)
        // E8.2 — same honest door as the tile: chat's open_lesson and
        // jenifit://lesson land on the note, or on her kept notes —
        // never on a cover that flashes open and dismisses itself.
        case .lesson: openMethodDoor()
        case .breath: modules.present(cover: .breathSession)
        case .workout:
            if let day = snapshot?.day,
               let beat = day.beats.first(where: {
                   if case .workout = $0 { return true } else { return false }
               }) {
                modules.open(beat, snapshot: snapshot)
            }
        // v25 E8.1 — JENI MOVE. `.steps` and `.move` land on the same
        // surface: Move IS the movement record now, and the old
        // steps-only destination was the thing it grew out of. The
        // `.steps` case survives so notification and chat deep links
        // written before this release still resolve.
        case .steps, .move: modules.present(sheet: .stepsDetail)
        case .bodyScan: modules.present(cover: .bodyScan)
        // v25 E4 — the plate's memory: the one-tap relog rail.
        case .foodAgain: modules.present(sheet: .recentMeals)
        case .trend: break
        // v25 E3 ONE JENI — jeni hands the describe path the words
        // the user just said. Same flow, same reading, same confirm.
        case .foodDescribe(let text, let spoken):
            modules.describePrefill = text
            modules.describeWasSpoken = spoken
            modules.present(cover: .captureFlow)
        // v25 E3 — jeni routes to the dose sheet; she never marks a
        // dose. The slot derives at the same chokepoint every other
        // door uses, so the late face opens when one is open.
        case .doseSheet:
            modules.present(sheet: .doseSheet(
                slotDayKey: modules.currentDoseSlotKey()
            ))
        // Handled on the becoming side (the read presents itself
        // there when one is due).
        case .weeklyRead, .plates: break
        }
    }

    /// E8.2 — the food-beat self-heal. E4's "any plate today marks the
    /// beat" was a transient Combine subscription, not a property of
    /// the data: `FoodLogPersister.changeNotifier` has no replay, so a
    /// plate that lands with no listener alive — the first-plate flow,
    /// a sync from another device, a QA seed at launch, a write under
    /// a non-capture cover — left the record and the checklist
    /// permanently disagreeing ("3 plates today" over an unchecked
    /// "add your next meal"). Mirror of `autoCompleteStepsIfCrossed`:
    /// derived at refresh, so the mark is a consequence of the record
    /// rather than of who was listening when it happened.
    private func autoCompleteFoodIfPlated() {
        guard let snapshot,
              !snapshot.plates.isEmpty,
              snapshot.carePlan.actionableBeats.contains(where: {
                  if case .snapMeal = $0 { return true } else { return false }
              }),
              (snapshot.checkStates["snap_meal"] ?? "empty") == "empty"
        else { return }
        _ = ProgramService.shared.markChecklistItem(
            prescription: .snapMeal,
            state: .autoCompleted,
            userId: userId,
            in: modelContext
        )
        refresh()
    }

    private func autoCompleteStepsIfCrossed(_ count: Int) {
        // v25 E1 — the threshold is the RESOLVED goal (facts-first
        // via TargetsService), never the prescription's baked tier
        // number: a consented 5,150 goal must complete at 5,150.
        // Fires for the prescription's steps beat OR the composed
        // walking action (both carry itemKey "steps").
        guard let snapshot, let day = snapshot.day else { return }
        let hasStepsBeat = day.beats.contains {
            if case .steps = $0 { return true } else { return false }
        }
        let hasWalkMove = snapshot.carePlan.actionableBeats.contains {
            if case .steps = $0 { return true } else { return false }
        }
        guard
            hasStepsBeat || hasWalkMove,
            count >= snapshot.targets.steps,
            (snapshot.checkStates["steps"] ?? "empty") == "empty"
        else { return }
        _ = ProgramService.shared.markChecklistItem(
            prescription: .steps(goal: snapshot.targets.steps),
            state: .autoCompleted,
            userId: userId,
            in: modelContext
        )
        // v25 E2 B1 — the goal crossing, once per day.
        let stampKey = "analytics.walkGoalHit.day"
        let today = TodayStateService.dayKey()
        if UserDefaults.standard.string(forKey: stampKey) != today {
            UserDefaults.standard.set(today, forKey: stampKey)
            Analytics.track(.walkGoalHit)
        }
        refresh()
    }
}
