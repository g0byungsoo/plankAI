import SwiftUI
import Auth
import PlankFood

// MARK: - TodaySignalsBand (app v6 — the passive layer on Home)
//
// Research: docs/app_v6/00_RESEARCH.md. Three zero-input modules
// that turn her existing exhaust into felt understanding: THE
// WINDOW (overnight rhythm from plate timestamps), NIGHT (sleep →
// appetite, spoken as forgiveness), and AFTER-MEAL MOVES (steps
// landing after plates, receipts only). Nothing here asks for
// input; absence never renders; every number traces to a store.
//
// The on-medication chapter inverts the window module: their
// clinical risk is under-fueling, so their frame is "first plate
// landed", never hour arithmetic (no count-up to gamify delay).

struct TodaySignalsBand: View {
    let snapshot: TodaySnapshot

    @State private var sleep = SleepService.shared
    @State private var cycle = CycleService.shared
    @State private var vitals = VitalsService.shared
    @State private var hourlySteps: [Int]?
    @State private var showNightSheet = false
    /// v7 — the overnight fast came home to the band as an
    /// OBSERVATION (docs/app_v7 §1): the founder's plain name stays,
    /// the ≥12h completion ring dies (a ring at 12h is a target in
    /// UI grammar — 00_RESEARCH §4 rule 1 wins mechanically).
    @State private var showWindowSheet = false
    @State private var showStepsSheet = false

    // First-day whisper: teach the module once, on the day she meets it.
    @AppStorage("signals.firstSeenDayKey") private var firstSeenDayKey = ""

    private var userId: String {
        AuthService.shared.currentUser?.id.uuidString ?? ""
    }

    private var moves: [MealMoves.Move] {
        guard let hourlySteps else { return [] }
        let times = snapshot.plates.map(\.loggedAt)
        return MealMoves.detect(plateTimes: times, hourlySteps: hourlySteps)
    }

    /// The resting-heart ledger value ("62 · steady"), nil until
    /// HealthKit has a 7-day figure. QA: --uitest-force-signals
    /// renders a fixture so captures can show the rail.
    private var restingHeartValue: String? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-force-signals") {
            return VitalsTrend.ledgerValue(current: 62, baseline: 64)
        }
        #endif
        guard let current = vitals.read.restingHR7d else { return nil }
        return VitalsTrend.ledgerValue(
            current: current, baseline: vitals.read.restingHRBaseline
        )
    }

    private var showsWhisper: Bool {
        firstSeenDayKey == TodayStateService.dayKey()
    }

    /// The season row speaks ONLY when it helps (hungrier stretches);
    /// quiet weeks stay quiet. Perimenopausal identities are gated
    /// off — irregular cycles make the phase math misleading.
    private var season: CycleSignal.Read? {
        guard !CohortStore.isPerimenopausal else { return nil }
        #if DEBUG
        if let forced = Self.debugForcedSeason() { return forced }
        #endif
        return CycleSignal.read(periodStarts: cycle.periodStarts)
    }

    var body: some View {
        // v7 (docs/app_v7 §1): the band is THE NOTICED layer — every
        // observation jeni made for her, as received care: the
        // overnight fast (back from the day list, ring gone), last
        // night, steps counted for her, after-meal moves, the season,
        // and the on-medication fuel frame. Never graded, never debt.
        let night = sleep.lastNight ?? Self.debugForcedNight()
        let moves = self.moves
        let medFrame = medicationFrame
        let season = self.season
        let fast = fastObservation
        let seasonSpeaks = season.map { $0.phase != .follicular } ?? false
        let stepsCount = snapshot.steps
        let restingHeart = restingHeartValue
        let hasAny = medFrame != nil || night != nil || !moves.isEmpty
            || seasonSpeaks || fast != nil || stepsCount > 0
            || restingHeart != nil
        // v6.3 endowed progress: 83% of paying users made their D1
        // decision against an EMPTY signals band. Before her first
        // plates, the band shows what's already arriving and what
        // tonight unlocks — never a blank.
        let showsForming = !hasAny
            && QuietHours.mayNarrate
            && snapshot.chapter != .onMedication
            && snapshot.isEnrolled

        if hasAny {
            // v7.2 (founder: "100x more minimal"): the seam header
            // died — the observations read as a quiet continuation
            // of the receipt column, separated only by air.
            VStack(alignment: .leading, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.md) {
                    if snapshot.chapter == .onMedication, let medFrame {
                        medicationRow(medFrame)
                    }

                    if let fast {
                        fastRow(fast)
                    }

                    if let night {
                        nightRow(night)
                    }

                    if stepsCount > 0 {
                        stepsRow(stepsCount)
                    }

                    // The passive vitals rail (04_CLINICAL_CHECKLIST
                    // §4 #2): her resting heart against her own
                    // baseline. Observed, never interpreted — a
                    // trend she can bring to a clinician.
                    if let restingHeart {
                        ledgerRow(label: "resting heart", value: restingHeart)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("resting heart, \(restingHeart)")
                    }

                    if let season, season.phase != .follicular {
                        seasonRow(season)
                    }

                    if let move = moves.last {
                        moveReceipt(move)
                    }

                    if showsWhisper {
                        Text("noticed from your plate times and your phone. nothing to log \u{2665}\u{FE0E}")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .padding(.horizontal, Space.lg)
                    }
                }
            }
            .task(id: "\(TodayStateService.dayKey())·\(snapshot.plates.count)") {
                await sleep.refresh()
                await cycle.bootstrap()
                await vitals.refresh()
                hourlySteps = await StepsService.shared.hourlyBreakdown()
                if firstSeenDayKey.isEmpty {
                    firstSeenDayKey = TodayStateService.dayKey()
                }
                #if DEBUG
                // QA: land directly inside either detail sheet.
                let args = ProcessInfo.processInfo.arguments
                if args.contains("--uitest-open-night-sheet") {
                    try? await Task.sleep(for: .seconds(1.2))
                    showNightSheet = true
                }
                if args.contains("--uitest-open-window-sheet") {
                    try? await Task.sleep(for: .seconds(1.2))
                    showWindowSheet = true
                }
                #endif
            }
            // v7 sheet law (docs/app_v7 §9): no conditional content
            // inside a sheet closure — a nil at presentation time
            // must still render a page, never a blank.
            .sheet(isPresented: $showNightSheet) {
                if let night {
                    NightSheet(night: night)
                        .presentationDetents([.fraction(0.8), .large])
                } else {
                    JKSheetChrome(title: "last night", eyebrow: "noticed") {
                        Text("no sleep data arrived for last night.")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                            .padding(Space.lg)
                        Spacer()
                    }
                    .presentationDetents([.fraction(0.5)])
                }
            }
            .sheet(isPresented: $showWindowSheet) {
                WindowSheet(userId: userId, phase: {
                    #if DEBUG
                    if let forced = Self.debugForcedPhase() { return forced }
                    #endif
                    return KitchenSignal.livePhase(userId: userId)
                }())
                .presentationDetents([.large])
            }
        } else if showsForming {
            formingBand
        }
    }

    // MARK: The overnight fast (v7 — observation, never a target)

    /// The live read the old day-list row computed, minus its ≥12h
    /// done-state: the fact renders, nothing grades it. mayNarrate-
    /// gated; the on-medication chapter keeps its fuel frame instead.
    private var fastObservation: String? {
        guard QuietHours.mayNarrate, snapshot.chapter != .onMedication
        else { return nil }
        var phase = KitchenSignal.livePhase(userId: userId)
        #if DEBUG
        if let forced = Self.debugForcedPhase() { phase = forced }
        #endif
        switch phase {
        case let .settled(hours, _, _):
            return "\(Int(hours.rounded()))h between plates"
        case let .overnight(hours, _):
            return "\(Int(hours.rounded()))h so far"
        case .evening:
            return "counts tomorrow"
        case nil:
            return nil
        }
    }

    /// Mission 2 (02_VISUAL.md §1.8): observations speak in the
    /// ledger grammar the onboarding taught — whisper label left,
    /// serif value right, a hairline beneath. No marks, no chevrons;
    /// the line is the door.
    @ViewBuilder
    private func fastRow(_ note: String) -> some View {
        Button {
            Haptics.soft()
            showWindowSheet = true
        } label: {
            ledgerRow(label: "overnight fast", value: note)
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("overnight fast, \(note)")
        .accessibilityHint("opens the detail")
    }

    @ViewBuilder
    private func ledgerRow(label: String, value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: 16)
                Text(value)
                    .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 12)
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(height: 0.5)
        }
        .padding(.horizontal, Space.lg)
        .contentShape(Rectangle())
    }

    // MARK: Steps (v7 — counted for her, never owed)

    @ViewBuilder
    private func stepsRow(_ count: Int) -> some View {
        Button {
            Haptics.soft()
            showStepsSheet = true
        } label: {
            ledgerRow(label: "steps", value: count.formatted())
        }
        .buttonStyle(JKPress())
        .sheet(isPresented: $showStepsSheet) {
            TodayStepsSheet(goal: snapshot.targets.steps)
                .presentationDetents([.fraction(0.7), .large])
        }
        .accessibilityLabel("\(count.formatted()) steps, counted for you")
        .accessibilityHint("opens the detail")
    }

    // MARK: The forming state (day one, before her data exists)

    private var arrivingCount: Int {
        var n = 0
        if StepsService.shared.authStatus == .authorized { n += 1 }
        if snapshot.latestWeightKg != nil { n += 1 }
        return n
    }

    @ViewBuilder
    private var formingBand: some View {
        // v7.2: header-less like its formed sibling — the horizon
        // figure and the captions carry the day-one promise.
        VStack(alignment: .leading, spacing: Space.md) {
            JKFormingHorizon()

            VStack(alignment: .leading, spacing: 6) {
                Text("your overnight fast starts measuring after tonight's dinner \u{2665}\u{FE0E}")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if arrivingCount > 0 {
                    Text(arrivingCount == 2
                         ? "steps and weight are already flowing in"
                         : "steps are already flowing in")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                if sleep.authStatus == .notDetermined {
                    Button {
                        Haptics.soft()
                        Task { await sleep.requestAccess() }
                    } label: {
                        Text(sleep.authStatus == .requesting ? "asking…" : "add sleep · one tap")
                            .font(.custom("DMSans-Medium", size: 12))
                            .foregroundStyle(Palette.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .overlay(
                                Capsule().strokeBorder(
                                    Palette.cocoaPrimary.opacity(0.22), lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(JKPress())
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, Space.lg)
        }
        .task { await sleep.bootstrap() }
        .accessibilityElement(children: .combine)
    }

    // MARK: The on-medication fuel frame

    private enum MedicationFrame: Equatable {
        case waiting               // no plate yet, 10:00+
        case landed(Date)          // first plate time
    }

    private var medicationFrame: MedicationFrame? {
        guard snapshot.chapter == .onMedication else { return nil }
        if let first = KitchenSignal.liveFirstPlateToday(userId: userId) {
            return .landed(first)
        }
        return Calendar.current.component(.hour, from: .now) >= 10 ? .waiting : nil
    }

    @ViewBuilder
    private func medicationRow(_ frame: MedicationFrame) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            JKMark(kind: .plate, size: 13, color: Palette.cocoaSecondary.opacity(0.8))
            VStack(alignment: .leading, spacing: 3) {
                switch frame {
                case let .landed(at):
                    Text("first plate at \(JKWindowHorizon.clockWord(at))")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(Palette.textPrimary)
                    Text("eating early protects your muscle \u{2665}\u{FE0E}")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                case .waiting:
                    Text("no plates logged yet today")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(Palette.textPrimary)
                    Text("aim for protein when you do eat \u{2665}\u{FE0E}")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .padding(.horizontal, Space.lg)
    }

    // MARK: The night row

    @ViewBuilder
    private func nightRow(_ night: LastNightSleep) -> some View {
        let hours = night.asleepDuration / 3600
        Button {
            Haptics.soft()
            showNightSheet = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                JKCrescent(size: 13, color: Palette.cocoaSecondary.opacity(0.85))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(SleepSignal.durationWord(night.asleepDuration)) last night")
                        .font(.custom("DMSans-Medium", size: 14))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                    Text(SleepSignal.caption(for: SleepSignal.band(asleepHours: hours)))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityHint("opens last night's story")
    }

    // MARK: The season row

    @ViewBuilder
    private func seasonRow(_ season: CycleSignal.Read) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            JKSeasonMark(
                position: Double(season.dayOfCycle) / Double(max(season.cycleLengthDays, 1)),
                size: 13
            )
            VStack(alignment: .leading, spacing: 3) {
                switch season.phase {
                case .luteal:
                    Text("a hungrier stretch is normal right now")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(Palette.textPrimary)
                    Text("appetite rises before a period. your plan accounts for it \u{2665}\u{FE0E}")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .menstrual:
                    Text("period days")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(Palette.textPrimary)
                    Text("appetite usually settles as it passes \u{2665}\u{FE0E}")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .follicular:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .accessibilityElement(children: .combine)
    }

    // MARK: The move receipt

    @ViewBuilder
    private func moveReceipt(_ move: MealMoves.Move) -> some View {
        HStack(spacing: 10) {
            JKMark(kind: .path, size: 13, color: Palette.cocoaSecondary.opacity(0.8))
            Text("you moved after \(move.slot) \u{2665}\u{FE0E}")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, Space.lg)
        .accessibilityElement(children: .combine)
    }

    // MARK: DEBUG determinism

    /// QA: `--uitest-force-night` renders the synthesized sample
    /// night (the sim has no HealthKit data). No-op in release.
    static func debugForcedNight() -> LastNightSleep? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--uitest-force-night")
        else { return nil }
        return .sample()
        #else
        return nil
        #endif
    }

    #if DEBUG
    /// QA: `--uitest-force-season luteal|menstrual|follicular`.
    static func debugForcedSeason() -> CycleSignal.Read? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "--uitest-force-season"),
              idx + 1 < args.count else { return nil }
        switch args[idx + 1] {
        case "luteal":
            return CycleSignal.Read(phase: .luteal, dayOfCycle: 22, cycleLengthDays: 28)
        case "menstrual":
            return CycleSignal.Read(phase: .menstrual, dayOfCycle: 2, cycleLengthDays: 28)
        case "follicular":
            return CycleSignal.Read(phase: .follicular, dayOfCycle: 9, cycleLengthDays: 28)
        default:
            return nil
        }
    }

    /// QA: `--uitest-force-signal overnight|settled|evening` renders
    /// a deterministic window state regardless of the journal.
    static func debugForcedPhase() -> KitchenSignal.Phase? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "--uitest-force-signal"),
              idx + 1 < args.count else { return nil }
        let cal = Calendar.current
        let now = Date()
        let lastNight = cal.date(byAdding: .hour, value: -11,
                                 to: cal.startOfDay(for: now).addingTimeInterval(9.25 * 3600)) ?? now
        switch args[idx + 1] {
        case "overnight":
            return .overnight(sinceHours: 11.3, closedAt: now.addingTimeInterval(-11.3 * 3600))
        case "settled":
            return .settled(hours: 12.6, closedAt: lastNight,
                            openedAt: cal.startOfDay(for: now).addingTimeInterval(9.25 * 3600))
        case "evening":
            return .evening(sinceHours: 2.1, closedAt: now.addingTimeInterval(-2.1 * 3600))
        default:
            return nil
        }
    }
    #endif
}

// MARK: - WindowSheet
//
// The window's one level deeper: tonight on the 24h ring, the week
// of nights as falling bands, and the honest mechanism — cited,
// never prescribed.

struct WindowSheet: View {
    let userId: String
    let phase: KitchenSignal.Phase?

    @State private var weekStory: KitchenSignal.WeekStory?

    private func horizonMode(_ phase: KitchenSignal.Phase) -> JKWindowHorizon.Mode {
        switch phase {
        case let .overnight(hours, closedAt):
            return .live(closedAt: closedAt, hours: hours)
        case let .evening(hours, closedAt):
            return .live(closedAt: closedAt, hours: hours)
        case let .settled(hours, closedAt, openedAt):
            return .settled(closedAt: closedAt, openedAt: openedAt, hours: hours)
        }
    }

    var body: some View {
        // v6.4 (founder call): the fast is NAMED and explained —
        // she should know this is fasting and why it helps. The
        // safety rails hold underneath: 12-14h framing, no targets,
        // no timers, care tone at 16h+.
        JKSheetChrome(title: "the overnight fast", italic: ["fast"], eyebrow: "signals") {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Space.section) {
                    if let phase {
                        JKWindowHorizon(
                            mode: horizonMode(phase),
                            dusk: {
                                if case .evening = phase { return true }
                                return false
                            }()
                        )
                        .padding(.top, Space.sm)
                    }

                    if let weekStory {
                        VStack(alignment: .leading, spacing: Space.md) {
                            Text("the last 7 nights")
                                .font(Typo.captionTracked)
                                .kerning(1.98)
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.cocoaTertiary)
                            JKWindowWeekBand(nights: weekStory.nights)
                            if let avg = weekStory.averageHours {
                                Text("you fasted about \(Int(avg.rounded())) hours a night, on average")
                                    .font(Typo.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("why fasting helps")
                            .font(Typo.captionTracked)
                            .kerning(1.98)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text("the hours between dinner and breakfast are a nightly fast your body already runs. in trials, keeping it near 12 to 14 hours trimmed intake and improved insulin sensitivity, and the same food eaten earlier stores less. it works best gentle: 12 to 14 hours, never forced, never past comfort \u{2665}\u{FE0E}")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                        HStack(spacing: 8) {
                            JKCitationChip(text: "cell metabolism, 2022")
                            JKCitationChip(text: "nutrition reviews, 2025")
                        }
                        .padding(.top, 2)
                    }

                    Spacer(minLength: Space.xl)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.md)
            }
        }
        .task {
            weekStory = KitchenSignal.liveWeekStory(userId: userId)
            #if DEBUG
            if weekStory == nil,
               ProcessInfo.processInfo.arguments.contains("--uitest-force-signal") {
                weekStory = Self.sampleWeek()
            }
            #endif
        }
    }

    #if DEBUG
    static func sampleWeek() -> KitchenSignal.WeekStory? {
        var plates: [Date] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let closes: [Double] = [20.5, 21.25, 19.9, 22.0, 20.75, 21.5, 20.25, 20.6]
        let opens: [Double] = [8.5, 9.25, 8.0, 10.5, 9.0, 9.75, 8.25, 9.1]
        for d in 0...7 {
            guard let day = cal.date(byAdding: .day, value: -d, to: today) else { continue }
            plates.append(day.addingTimeInterval(opens[d] * 3600))
            plates.append(day.addingTimeInterval(closes[d] * 3600))
        }
        return KitchenSignal.weekStory(plateTimes: plates)
    }
    #endif
}

// MARK: - NightSheet
//
// Last night, one level deeper: the dial with her stages, the week
// of nights, and the sleep→appetite mechanism with its citation.

struct NightSheet: View {
    let night: LastNightSleep

    @State private var history: [SleepService.NightRecap] = []

    var body: some View {
        JKSheetChrome(title: "last night", italic: ["night"], eyebrow: "signals") {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Space.section) {
                    HStack {
                        Spacer()
                        JKSleepDial(night: night)
                        Spacer()
                    }
                    .padding(.top, Space.md)

                    if history.count >= 3 {
                        VStack(alignment: .leading, spacing: Space.md) {
                            Text("the last 7 nights")
                                .font(Typo.captionTracked)
                                .kerning(1.98)
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.cocoaTertiary)
                            JKSleepBars(nights: weekHours)
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("why it matters")
                            .font(Typo.captionTracked)
                            .kerning(1.98)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text("short sleep turns hunger hormones up and fullness hormones down. in a trial, one more hour of sleep cut eating by about 270 calories a day, without trying. tonight isn't homework. just expect more hunger after short nights \u{2665}\u{FE0E}")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                        JKCitationChip(text: "jama internal medicine, 2022")
                            .padding(.top, 2)
                    }

                    Spacer(minLength: Space.xl)
                }
                .padding(.horizontal, Space.lg)
            }
        }
        .task {
            history = await SleepService.shared.nightHistory()
            #if DEBUG
            if history.isEmpty,
               ProcessInfo.processInfo.arguments.contains("--uitest-force-night") {
                let sample: [Double] = [6.2, 7.4, 5.8, 0, 7.1, 6.7, 7.7]
                history = sample.enumerated().compactMap { idx, h in
                    h > 0 ? SleepService.NightRecap(daysAgo: idx, asleepDuration: h * 3600) : nil
                }
            }
            #endif
        }
    }

    /// oldest → today, 7 slots, nil where no night was found.
    private var weekHours: [Double?] {
        var slots: [Double?] = Array(repeating: nil, count: 7)
        for recap in history where recap.daysAgo < 7 {
            slots[6 - recap.daysAgo] = recap.hours
        }
        return slots
    }
}

// MARK: - TodayCycleAsk (v7 — out of the care surface)

/// The one-time cycle connect offer. v7 moved it out of the noticed
/// band (docs/app_v7 §1: a permission ask is a growth surface and
/// may not sit inside received care) — it renders once, at the foot
/// of the day, and retires forever on dismiss or denial.
struct TodayCycleAsk: View {
    @State private var cycle = CycleService.shared
    @AppStorage("signals.cycleAsk.retired") private var retired = false

    private var shows: Bool {
        !retired
            && cycle.authStatus == .notDetermined
            && !CohortStore.isPerimenopausal
            && CycleSignal.read(periodStarts: cycle.periodStarts) == nil
    }

    var body: some View {
        if shows {
            HStack(alignment: .center, spacing: 8) {
                Rectangle()
                    .fill(Palette.cocoaTertiary)
                    .frame(width: 0.75, height: 22)
                Text("hungrier weeks have a rhythm. your cycle can explain them")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button {
                    Haptics.soft()
                    Task {
                        await cycle.requestAccess()
                        if cycle.authStatus == .denied { retired = true }
                    }
                } label: {
                    Text(cycle.authStatus == .requesting ? "asking…" : "connect")
                        .font(.custom("DMSans-Medium", size: 12))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(
                            Capsule().strokeBorder(Palette.cocoaPrimary.opacity(0.22), lineWidth: 1)
                        )
                }
                .buttonStyle(JKPress())
                Button {
                    withAnimation(Motion.exit) { retired = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .tappableArea(32)
                }
                .buttonStyle(.plain)
            }
            .task { await cycle.bootstrap() }
        }
    }
}
