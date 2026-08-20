import SwiftUI
import SwiftData
import PlankSync
import PlankFood
import Auth

/// The profile/settings hub. v1.1 clean-luxury pass: the scrapbook
/// card rows became hairline-ruled editorial lists (SettingsChrome),
/// the identity moment opens the page as a monogram + folio line, and
/// the one jewel is the mother-of-pearl sheen drifting across the
/// monogram ring.
///
/// State-driven navigation (no NavigationStack) keeps back/close clean.
/// Identity values trace to collected fields (data provenance): name,
/// program day (ProgramScheduleCalculator), "shown up N times"
/// (day_progress count, NOT a streak), "becoming since" (earliest
/// session date). Anything with no real data is omitted.
struct ProfileHubView: View {
    /// Closes the whole hub (host animates it out).
    var onClose: () -> Void = {}

    @AppStorage("userName") private var userName = ""
    @AppStorage("voicePreference") private var voicePreference = "encouraging"
    @AppStorage("jenimethod.last_lesson_completed_id") private var jeniMethodLastCompletedId = 0
    @AppStorage("jenimethod.feature_enabled") private var jeniMethodFlagEnabled = true

    @State private var stepsService = StepsService.shared
    @State private var bodyMassImport = BodyMassImportService.shared
    @Environment(\.modelContext) private var modelContext

    @State private var auth = AuthService.shared
    @State private var route: HubRoute?
    @State private var revealed = false
    // v3 — the "on a break" pause state (DayModel.swift). Local mirror
    // so the row re-renders on toggle.
    @State private var breakActive = BreakState.isActive
    @State private var showBreakConfirm = false
    // v9 P1 — Body Vision doors.
    @AppStorage(BodyScanStore.backupOnKey) private var scanBackupOn = false
    @State private var showScanBackupOffConfirm = false
    @State private var showScanDeleteConfirm = false
    @State private var showBodyScan = false
    // v8 refinement — the consumer bridge's settings affordance:
    // medication can start mid-journey (the Omada lesson), so the
    // quiet door exists here for everyone, not only the onboarding-
    // identified cohort.
    @State private var showRegimen = false
    // 2026-08-13 — the goal-weight editor (JKGoalRitual). `goalBump`
    // exists so the row's VALUE re-reads after a save: @AppStorage
    // would re-render on its own, but the row also needs the repaired
    // plan, and one explicit bump is clearer than two sources.
    @State private var showGoalRitual = false
    @State private var showPlanNumbers = false
    /// v25 §36 — which fact `your numbers` opens on. `nil` is the list.
    @State private var planNumbersFocus: JKPlanNumbersSheet.Fact?
    @State private var goalBump = 0
    @AppStorage("weightUnit") private var settingsWeightUnitRaw: String = "lb"
    // v8 S4 — the clinic connection door (enter a code / manage
    // access). Quiet, always reachable; clinic connections start
    // mid-journey, unsignaled, same as medication.
    @State private var showCareTeam = false
    @Query(sort: \DayProgressRecord.date, order: .reverse) private var allDayProgress: [DayProgressRecord]
    @Query(sort: \SessionLogRecord.completedAt, order: .forward) private var allSessionLogs: [SessionLogRecord]

    enum HubRoute: Hashable {
        // v25 §36 — `.myPace` removed. It was the only thing that
        // reached `EditProfileView`, and the row that used it now opens
        // the real pace editor. A route case nothing navigates to is a
        // false contract (`35` §9), so it goes rather than lingering.
        // p54 — `jeniMethod` (the 14-lesson re-read shelf) deleted with
        // its corpus: the case had ZERO `go(.jeniMethod)` callers for
        // four passes (the browse surface is `methodTold` — her own
        // notes, never a shelf of lessons she has not seen).
        case coach, reminders, account, feedback, foodSettings
        case jeniMemory
        case methodTold
        #if DEBUG
        case debug
        #endif
    }

    private let slow = Animation.easeInOut(duration: 0.5)

    /// The settings row's value: her medication + dose when known
    /// ("ozempic · 0.5"), her shot day as the v8 fallback, nothing
    /// otherwise — a fact, never a status.
    private var regimenValue: String? {
        guard let userId,
              let plan = RegimenService.activeMedicationPlan(userId: userId, in: modelContext)
        else { return nil }
        let name = MedicationCatalog.renderName(
            productId: plan.productId, displayName: plan.displayName
        )
        if name != "your medication" {
            if let dose = plan.strengthValue {
                return "\(name) · \(MedicationProduct.doseWord(dose))"
            }
            return name
        }
        if let anchor = plan.anchorWeekday, (1...7).contains(anchor) {
            let words = ["monday", "tuesday", "wednesday", "thursday",
                         "friday", "saturday", "sunday"]
            return words[anchor - 1]
        }
        return nil
    }

    // v8 S4 — a quiet "connected" hint when a care relationship is
    // active. Loaded async (RLS read); nil = not connected, no rail.
    @State private var careTeamConnected = false
    private var careTeamValue: String? { careTeamConnected ? "connected" : nil }

    private var userId: String? {
        guard let id = auth.currentUser?.id.uuidString, !id.isEmpty else { return nil }
        return id
    }
    private var shownUpCount: Int {
        guard let userId else { return 0 }
        return allDayProgress.filter { $0.userId == userId }.count
    }
    private var becomingSince: String? {
        guard let userId,
              let first = allSessionLogs.first(where: { $0.userId == userId })?.completedAt
        else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: first).lowercased()
    }
    /// "day N of M" from the active plan — nil pre-enrollment or
    /// post-goal so the folio never shows a stale frame.
    private var programDayLine: String? {
        guard let userId,
              let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext)
        else { return nil }
        let schedule = ProgramScheduleCalculator.compute(
            .init(startDate: plan.startDate, totalDays: plan.totalDays)
        )
        guard !schedule.isPostGoal else { return nil }
        return "day \(schedule.programDay) of \(schedule.totalDays)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: "back" only inside a sub-screen (left) + a clean close (right).
            HStack {
                if route != nil {
                    Button {
                        Haptics.light()
                        withAnimation(slow) { route = nil }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.custom("DMSans-SemiBold", size: 15, relativeTo: .subheadline))
                            Text("back").font(Typo.body)
                        }
                        .foregroundStyle(Palette.textSecondary)
                        .tappableArea()
                    }
                    .transition(.opacity)
                }
                Spacer()
                Button {
                    Haptics.light()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.custom("DMSans-Medium", size: 16, relativeTo: .body))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("close")
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.sm)
            .animation(slow, value: route)

            ZStack {
                if let route {
                    destination(for: route).transition(.opacity)
                } else {
                    hubList.transition(.opacity)
                }
            }
            .animation(slow, value: route)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.programEraBg)
        .onAppear {
            Analytics.track(.settingsHubOpened)
            withAnimation { revealed = true }
        }
        .task {
            careTeamConnected = await CareConnectionService.activeConnection() != nil
        }
        .onChange(of: showCareTeam) { _, open in
            if !open {
                Task { careTeamConnected = await CareConnectionService.activeConnection() != nil }
            }
        }
    }

    // MARK: - Hub list (staggered reveal)

    private var hubList: some View {
        scrollBody
            .confirmationDialog(
                "take a break?",
                isPresented: $showBreakConfirm,
                titleVisibility: .visible
            ) {
                Button("take the break") {
                    BreakState.begin()
                    breakActive = true
                    Haptics.soft()
                }
                Button("not now", role: .cancel) {}
            } message: {
                Text("the rhythm and the reminders pause. your place is kept, and coming back is one tap.")
            }
            .sheet(isPresented: $showRegimen) {
                if let userId {
                    RegimenSheet(userId: userId, onDone: { showRegimen = false })
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(Palette.bgPrimary)
                }
            }
            .sheet(isPresented: $showCareTeam) {
                if let userId {
                    CareConnectionSheet(userId: userId, onClose: { showCareTeam = false })
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(Palette.bgPrimary)
                }
            }
            .sheet(isPresented: $showGoalRitual) {
                JKGoalRitual(
                    currentKg: currentWeightKgForGoal,
                    existingGoalKg: storedGoalKg,
                    heightCm: UserDefaults.standard.double(forKey: "onboardingHeightCm"),
                    onSave: { kg in
                        if let userId {
                            GoalWeightStore.setGoalWeightKg(kg, userId: userId, in: modelContext)
                        }
                        goalBump += 1
                        showGoalRitual = false
                    },
                    onCancel: { showGoalRitual = false }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showPlanNumbers) {
                JKPlanNumbersSheet(focus: planNumbersFocus, onClose: {
                    showPlanNumbers = false
                    planNumbersFocus = nil
                    goalBump += 1
                })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)
            }
    }

    // MARK: - Goal weight

    private var settingsUnit: WeightUnit {
        WeightUnit(rawValue: settingsWeightUnitRaw) ?? .lb
    }

    private var storedGoalKg: Double? {
        let kg = UserDefaults.standard.double(forKey: "onboardingGoalWeightKg")
        return kg > 0 ? kg : nil
    }

    private var currentWeightKgForGoal: Double? {
        let onboarding = UserDefaults.standard.double(forKey: "onboardingCurrentWeightKg")
        let fallback: Double? = onboarding > 0 ? onboarding : nil
        guard let userId else { return fallback }
        return TargetsService.latestWeightKg(userId: userId, in: modelContext) ?? fallback
    }

    /// The row states the number, so she can confirm we still hold it
    /// without opening anything. "not set" is the honest empty — never
    /// a placeholder that looks like a goal.
    private var goalWeightValue: String {
        _ = goalBump
        guard let kg = storedGoalKg else { return "not set" }
        return "\(PlanSummary.formatted(settingsUnit.display(fromKg: kg))) \(settingsUnit.label)"
    }

    private var numericsSuppressed: Bool { CohortStore.isNumericSuppressed }

    /// Normally a signpost. When a fact her energy target needs is
    /// missing, it names the fact instead — Settings is the other place
    /// she might come looking after Home stopped quoting a number.
    private var numbersRowValue: String {
        _ = goalBump
        guard let userId else { return "height · how you move" }
        let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext)
        if let missing = TargetsService.missingEnergyInput(
            plan: plan,
            latestWeightKg: TargetsService.resolvedWeightKg(
                userId: userId, plan: plan, in: modelContext),
            careProtocol: CareProtocolStore.current
        ) {
            return missing.doorLine
        }
        return "height · how you move"
    }

    /// v25 §36 — the row states the pace she is on, in the SAME three
    /// words Home and `your numbers` use, so she can confirm we still
    /// hold it without opening anything. That is the goal row's rule
    /// (`29`), applied to the fact beside it.
    private var paceRowValue: String {
        _ = goalBump
        let raw = UserDefaults.standard.string(forKey: "onboardingPickedTier") ?? ""
        guard let tier = IntensityTier(rawValue: raw) else { return "not set" }
        return tier.label
    }

    private var scrollBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                identityHeader
                    .reveal(0, revealed)

                Spacer().frame(height: 40)

                SettingsSection(title: "program") {
                    // v4 — the journey door: settings answers "where
                    // am I in the plan?" by opening the place time
                    // is visible (docs/app_v4/03_FEATURES.md §11).
                    SettingsNavRow(icon: "point.bottomleft.forward.to.point.topright.scurvepath",
                                   title: "your plan") {
                        onClose()
                        AppRouter.shared.tab = .becoming
                    }
                    // 2026-08-13 — THE MISSING FLOOR. Onboarding asked
                    // for a goal weight, stored it and fed it to the
                    // energy target, and no surface in the app could
                    // show it or change it. A user who mis-set it had
                    // one repair: delete the account. This row is the
                    // repair, and it states the number so she can see
                    // that we still hold it.
                    // The safety gate's numeric suppression is a clinical
                    // instruction, not a display preference: a cohort
                    // screened for a restrictive pattern, or pregnant, is
                    // shown no weight numerals anywhere. `PlanSummary`
                    // already refuses to ask a suppressed cohort for a
                    // goal weight; this row was still stating one and
                    // opening a ruler full of them.
                    if !numericsSuppressed {
                        SettingsNavRow(icon: "target", title: "goal weight",
                                       value: goalWeightValue) {
                            showGoalRitual = true
                        }
                        // The rest of the arithmetic: her weight, her
                        // height, and how much she moves. None of the
                        // three had a repair path before today, and the
                        // last two move the daily energy target more than
                        // any deficit the app would ever choose.
                        SettingsNavRow(icon: "number", title: "your numbers",
                                       value: numbersRowValue) {
                            planNumbersFocus = nil
                            showPlanNumbers = true
                        }
                    }
                    // v25 §36 — THE ROW NOW EDITS THE THING IT IS NAMED
                    // FOR. It used to open `EditProfileView`, a v4-era
                    // screen titled "your pace" whose only control is
                    // `@AppStorage("workoutLevel")` — a device-local
                    // workout-difficulty preference that never touches
                    // her calorie target or her goal date.
                    //
                    // So the onramp printed "pick the rhythm, you can
                    // change it later", `31` §4 built the editor that
                    // honours it, and the Settings row named for the job
                    // pointed somewhere else. Worse, the two screens
                    // shared two of three words for two unrelated
                    // concepts ("keep it gentle · steady · a little
                    // more" against "gentle · steady · strong").
                    //
                    // `33` and `34` both recorded `EditProfileView` as
                    // dead code "superseded by my pace and your
                    // numbers". It was not dead: it WAS `my pace`. Two
                    // sessions reasoned about a screen from its name.
                    SettingsNavRow(icon: "slider.horizontal.3", title: "my pace",
                                   value: paceRowValue) {
                        planNumbersFocus = .pace
                        showPlanNumbers = true
                    }
                    SettingsNavRow(icon: "waveform", title: "coach",
                                   value: CoachAsset.displayName(for: voicePreference)) {
                        go(.coach)
                    }
                    if FoodFlags.isEnabled {
                        SettingsNavRow(icon: "fork.knife", title: "food") {
                            go(.foodSettings)
                        }
                    }
                    SettingsNavRow(icon: "bell", title: "reminders") {
                        go(.reminders)
                    }
                    // v8 refinement — her medication (the bridge
                    // door: dose days are shaped by the shot-day
                    // anchor; clinician-managed plans arrive here
                    // read-only later). Quiet, clinical, always
                    // reachable — medication starts mid-journey.
                    SettingsNavRow(icon: "pills",
                                   title: "your medication",
                                   value: regimenValue) {
                        showRegimen = true
                    }
                    // v8 S4 — connect with a clinic / manage access.
                    SettingsNavRow(icon: "cross.case",
                                   title: "your care team",
                                   value: careTeamValue) {
                        showCareTeam = true
                    }
                    // v3 — sick, travel, her period, a hard week: the
                    // pause that keeps her place instead of losing her.
                    SettingsNavRow(icon: "pause.circle",
                                   title: "on a break",
                                   value: breakActive ? "resting" : nil) {
                        if breakActive {
                            BreakState.end()
                            breakActive = false
                            Haptics.soft()
                        } else {
                            showBreakConfirm = true
                        }
                    }
                    appleHealthRowIfNeeded
                    weightImportRowIfNeeded
                    bodyVisionRowsIfNeeded
                }
                .reveal(1, revealed)

                Spacer().frame(height: 36)

                SettingsSection(title: "account") {
                    SettingsNavRow(icon: "person", title: "account") {
                        go(.account)
                    }
                    SettingsNavRow(icon: "envelope", title: "feedback") {
                        go(.feedback)
                    }
                    // v25 E3 ONE JENI — what jeni was told, and the
                    // way to take it back. The consent law's second
                    // half: a memory a person cannot audit is a
                    // profile, and jeni does not keep profiles.
                    SettingsNavRow(icon: "bookmark", title: "what jeni remembers") {
                        go(.jeniMemory)
                    }
                    // v25 E8.1 — the other half of the same law. That row
                    // is what the person told jeni; this is what jeni told
                    // the person. Between them the whole relationship is
                    // auditable, which is the only browse surface the
                    // Method needs: her own notes, never a shelf of
                    // lessons she has not seen.
                    SettingsNavRow(icon: "text.quote", title: "what jeni has told you") {
                        go(.methodTold)
                    }
                    #if DEBUG
                    SettingsNavRow(icon: "wrench.adjustable", title: "debug auth") {
                        go(.debug)
                    }
                    #endif
                }
                .reveal(2, revealed)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.sm)
            .padding(.bottom, 48)
        }
    }

    private func go(_ dest: HubRoute) {
        withAnimation(slow) { route = dest }
    }

    @ViewBuilder
    private func destination(for route: HubRoute) -> some View {
        switch route {
        case .coach:         ChangeTrainerView()
        case .reminders:     NotificationSettingsView()
        case .account:       AccountView()
        case .feedback:      FeedbackView()
        case .jeniMemory:    JeniMemoryView(userId: userId ?? "")
        case .methodTold:    MethodToldView()
        case .foodSettings:  FoodSettingsView()
        #if DEBUG
        case .debug:         DebugAuthView()
        #endif
        }
    }

    // MARK: - Identity header

    /// Open editorial composition — no card. Monogram in a thin ring
    /// with the pearl sheen, name in the hero serif, then a quiet
    /// folio line built only from real data.
    private var identityHeader: some View {
        let initial = userName.first.map { String($0).lowercased() } ?? "j"
        return VStack(alignment: .leading, spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Palette.accent.opacity(0.55), lineWidth: 1)
                    .frame(width: 72, height: 72)
                Text(initial)
                    .font(.custom("JeniHeroSerif-Italic", size: 34))
                    .foregroundStyle(Palette.accent)
                    .offset(y: -2)
            }
            .iridescentSheen()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                ItalicAccentText(
                    userName.isEmpty ? "your space." : "\(userName.lowercased())\u{2019}s space.",
                    italic: ["space."],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)

                if let folio = folioLine {
                    Text(folio)
                        .font(Typo.caption)
                        .kerning(0.4)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.md)
    }

    /// "day 12 of 154 · shown up 9 times · since june 2026" — only the
    /// segments backed by real data, dot-separated.
    private var folioLine: String? {
        var parts: [String] = []
        if let programDayLine { parts.append(programDayLine) }
        if shownUpCount > 0 {
            parts.append(shownUpCount == 1 ? "shown up once" : "shown up \(shownUpCount) times")
        }
        if let becomingSince { parts.append("since \(becomingSince)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Recovery rows

    /// Recovery surface for users who declined Apple Health during
    /// onboarding. Hidden when authorized or unavailable.
    ///   - .notDetermined → requestAccess() fires the iOS sheet (once).
    ///   - .denied → opens Apple Health → Sources, Apple's only re-path.
    @ViewBuilder
    private var appleHealthRowIfNeeded: some View {
        switch stepsService.authStatus {
        case .notDetermined:
            SettingsNavRow(icon: "heart", title: "apple health", value: "connect steps") {
                Task { await stepsService.requestAccess() }
            }
        case .denied:
            SettingsNavRow(icon: "heart", title: "apple health", value: "reconnect") {
                if let url = StepsService.openAppleHealthURL,
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
        case .authorized, .unavailable:
            EmptyView()
        }
    }

    /// v9 P1 — Body Vision's quiet doors (visible once she's met the
    /// consent sheet): the opt-in backup toggle (D3 — off by
    /// default; off means her cloud copies are REMOVED, not paused)
    /// and delete-everything. Copy is a D10 draft.
    @ViewBuilder
    private var bodyVisionRowsIfNeeded: some View {
        // v10.3d — the permanent door: a check-in from anywhere, at
        // any hour, consent met or not (the flow opens on its own
        // consent sheet the first time). Home's mirror hero is
        // conditional; this row never is.
        SettingsNavRow(icon: "figure.stand", title: "body vision",
                       value: BodyScanStore.consentSeen ? "check in" : "start") {
            showBodyScan = true
        }
        .fullScreenCover(isPresented: $showBodyScan) {
            BodyScanFlowView(
                userId: userId ?? "",
                onClose: { showBodyScan = false }
            )
            .presentationBackground(Palette.bgPrimary)
        }

        if BodyScanStore.consentSeen {
            SettingsNavRow(icon: "figure.stand", title: "scan backup",
                           value: scanBackupOn ? "on" : "off") {
                guard let userId = AuthService.shared.currentUser?.id.uuidString,
                      !userId.isEmpty else { return }
                if scanBackupOn {
                    showScanBackupOffConfirm = true
                } else {
                    Haptics.light()
                    Task {
                        await BodyScanSyncService.shared.enableBackup(
                            userId: userId, in: modelContext)
                        scanBackupOn = true
                    }
                }
            }
            .confirmationDialog(
                "turn off backup?",
                isPresented: $showScanBackupOffConfirm,
                titleVisibility: .visible
            ) {
                Button("turn off + remove cloud copies", role: .destructive) {
                    guard let userId = AuthService.shared.currentUser?.id.uuidString
                    else { return }
                    Task {
                        await BodyScanSyncService.shared.disableBackup(userId: userId)
                        scanBackupOn = false
                    }
                }
                Button("keep backup on", role: .cancel) {}
            } message: {
                Text("your scans stay on this iPhone. the cloud copies are removed.")
            }

            SettingsNavRow(icon: "trash", title: "delete all scans") {
                showScanDeleteConfirm = true
            }
            .confirmationDialog(
                "delete every scan?",
                isPresented: $showScanDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("delete them all", role: .destructive) {
                    guard let userId = AuthService.shared.currentUser?.id.uuidString
                    else { return }
                    BodyScanStore.deleteAll(userId: userId, in: modelContext)
                    Task {
                        await BodyScanSyncService.shared.deleteAllRemote(userId: userId)
                    }
                    Haptics.soft()
                }
                Button("keep them", role: .cancel) {}
            } message: {
                Text("removes every scan from this iPhone and any cloud backup. this can't be undone.")
            }
        }
    }

    /// Body-mass import enable surface. Smart scales write weight to
    /// Apple Health; one tap turns the typed-weight stream passive
    /// (one-per-day policy, never overwrites a manual log). Hidden
    /// once the permission sheet has been shown (HK read status is
    /// opaque) and when HK unavailable.
    @ViewBuilder
    private var weightImportRowIfNeeded: some View {
        if bodyMassImport.authStatus == .notDetermined {
            SettingsNavRow(icon: "scalemass", title: "weight",
                           value: "syncs from apple health") {
                guard let userId = AuthService.shared.currentUser?.id.uuidString,
                      !userId.isEmpty else { return }
                Task {
                    await bodyMassImport.requestAccessAndImport(
                        userId: userId, into: modelContext
                    )
                }
            }
        }
    }
}

// MARK: - Staggered reveal
//
// Each block fades + lifts in, delayed by its index, so the page
// reveals top-down (mindful, no abrupt pop).
private struct RevealModifier: ViewModifier {
    let index: Int
    let revealed: Bool
    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 14)
            .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.08), value: revealed)
    }
}

private extension View {
    func reveal(_ index: Int, _ revealed: Bool) -> some View {
        modifier(RevealModifier(index: index, revealed: revealed))
    }
}
