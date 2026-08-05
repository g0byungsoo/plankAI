import SwiftUI
import SwiftData
import PlankFood
import PlankSync

// MARK: - Chat module cards (1.1.6)
//
// The chat's tool cards grew up. `show_today_plan` renders THE PLAN
// inline — the day's rows with live done-states, the kcal bar, the
// protein count — and every row is a door into its module.
// `show_weight_trend` renders the trend itself: a 28-day EMA
// sparkline with the 7-day delta in her display unit. Both read the
// same single sources of truth the tabs read (TodayStateService /
// WeightTrendChart.computeEMA), so the desk and the tabs never
// disagree. Register: direct, numeric, tappable.

// MARK: - Card chrome
//
// Paper-glass: warm white gradient, a specular top edge (the light
// catching the card's lip), hairline, soft lift. One chrome for
// every rich chat card so the transcript reads as one material.

// Mission 2 (02_VISUAL.md §1.4): the paper-glass material died with
// the container law — no fills, no specular, no shadows on cream.
// A rich card is now a DRAWN FRAME: one hairline outline, the print
// grammar of a boxed sidebar. Content sits on the page itself.
// v11.5: the drawn frame was the last flat surface in a chat made of
// soft bubbles — it read as a different app's component sitting in the
// thread. A rich card is now MATERIAL, like every other container.
private struct JKChatCardChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.textPrimary.opacity(0.05), radius: 12, y: 5)
                    .shadow(color: Palette.textPrimary.opacity(0.03), radius: 2, y: 1)
            )
    }
}

extension View {
    func jkChatCard() -> some View { modifier(JKChatCardChrome()) }
}

// MARK: - JKQuietSilk
//
// The jkSilk sheen without the day-complete haptic — a single soft
// light pass a rich card wears the moment it arrives. Reduce-motion:
// nothing (the card's entrance already told the story).

private struct JKQuietSilk: ViewModifier {
    let trigger: Int

    @State private var progress: Float = -0.35
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .visualEffect { view, proxy in
                view.colorEffect(
                    ShaderLibrary.jkSilk(
                        .float2(Float(proxy.size.width), Float(proxy.size.height)),
                        .float(progress)
                    ),
                    isEnabled: animating
                )
            }
            .onChange(of: trigger) { _, newValue in
                guard newValue > 0, !reduceMotion, !animating else { return }
                animating = true
                Task { @MainActor in
                    let duration: TimeInterval = 0.9
                    let start = Date()
                    while animating {
                        let t = Date().timeIntervalSince(start) / duration
                        if t >= 1 { break }
                        let eased = 1 - pow(1 - t, 3)
                        progress = -0.35 + Float(eased) * 1.7
                        try? await Task.sleep(nanoseconds: 16_000_000)
                    }
                    animating = false
                    progress = -0.35
                }
            }
    }
}

extension View {
    fileprivate func jkQuietSilk(trigger: Int) -> some View {
        modifier(JKQuietSilk(trigger: trigger))
    }
}

// MARK: - JKChatPlanCard
//
// "what's my plan today?" → the plan, right there. Arrives expanded
// for today's entries; the header collapses/reopens it on a spring.
// Rows are live (the same check-state writes Today reads) and every
// row routes into its module. Past days render a quiet one-line
// receipt — that day's data isn't re-derivable, so the card never
// pretends.

struct JKChatPlanCard: View {
    let createdAt: Date
    let userId: String

    @Environment(\.modelContext) private var modelContext
    @State private var snapshot: TodaySnapshot?
    @State private var expanded: Bool
    @State private var arrivalSheen = 0
    @State private var steps = StepsService.shared
    @State private var router = AppRouter.shared

    init(createdAt: Date, userId: String) {
        self.createdAt = createdAt
        self.userId = userId
        _expanded = State(initialValue: Calendar.current.isDateInToday(createdAt))
    }

    private var isLive: Bool { Calendar.current.isDateInToday(createdAt) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if expanded, isLive, let snapshot, let day = snapshot.day {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.5)
                        .padding(.top, 12)

                    ForEach(Array(day.beats.enumerated()), id: \.element.itemKey) { idx, beat in
                        VStack(spacing: 0) {
                            if idx > 0 {
                                Rectangle()
                                    .fill(Palette.hairlineCocoa.opacity(0.6))
                                    .frame(height: 0.5)
                                    .padding(.leading, 38)
                            }
                            beatRow(beat, snapshot: snapshot)
                        }
                    }

                    if footerHasContent(snapshot) {
                        Rectangle()
                            .fill(Palette.hairlineCocoa)
                            .frame(height: 0.5)
                        foodFooter(snapshot)
                            .padding(.top, 12)
                    }
                }
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        .padding(14)
        .jkChatCard()
        .jkQuietSilk(trigger: arrivalSheen)
        .onAppear {
            refresh()
            // The arrival sheen — once, only on a card born just now.
            if isLive, Date.now.timeIntervalSince(createdAt) < 8 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    arrivalSheen += 1
                }
            }
        }
        .onReceive(FoodLogPersister.changeNotifier) { _ in refresh() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(a11yLabel)
    }

    // MARK: header

    private var header: some View {
        Button {
            guard isLive else { return }
            Haptics.light()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                expanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                // v11.5: the tinted disc was the header's last sticker
                // remnant. The card's own material carries it now; the
                // TITLE is the header.
                Text(isLive ? "today's plan" : "\(weekdayWord)'s plan")
                    .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3))
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 0)
                if isLive, let snapshot {
                    Text("\(doneCount(snapshot)) of \(binaryCount(snapshot)) done")
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                } else if !isLive {
                    Text(shortDate)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isLive
                ? "today's plan, \(expanded ? "expanded" : "collapsed")"
                : "\(weekdayWord)'s plan"
        )
        .accessibilityHint(isLive ? "shows the day's items" : "")
    }

    // MARK: rows

    @ViewBuilder
    private func beatRow(_ beat: ProgramDayPrescription, snapshot: TodaySnapshot) -> some View {
        let state = beatState(beat, snapshot: snapshot)
        Button {
            Haptics.light()
            route(beat)
        } label: {
            HStack(spacing: 12) {
                // v11.5: the glossy sticker tiles retired here. They
                // belonged to the it-girl era and read as a different
                // product inside an ink thread; one quiet mark carries
                // the row, and the WORDS do the work (L3).
                Image(systemName: beat.stickyGlyph)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(
                        state.isDone ? Palette.cocoaTertiary : Palette.cocoaSecondary
                    )
                    .frame(width: 22, height: 22)

                Text(rowTitle(beat, snapshot: snapshot))
                    .font(.custom("DMSans-Medium", size: 14))
                    .foregroundStyle(state.isDone ? Palette.textSecondary : Palette.textPrimary)
                    .strikethrough(state.isDone, color: Palette.textPrimary.opacity(0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                if case .steps = beat {
                    Text(steps.todayCount.formatted())
                        .font(Typo.caption.monospacedDigit())
                        .foregroundStyle(state.isDone ? Palette.stateGood : Palette.textSecondary)
                } else if state.isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.stateGood)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else {
                    Circle()
                        .strokeBorder(Palette.hairlineCocoa, lineWidth: 1.2)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel("\(rowTitle(beat, snapshot: snapshot))\(state.isDone ? ", done" : "")")
        .accessibilityHint("opens it")
    }

    /// Direct row grammar: the thing + its number. No aphorisms.
    private func rowTitle(_ beat: ProgramDayPrescription, snapshot: TodaySnapshot) -> String {
        switch beat {
        case .snapMeal:
            let n = snapshot.plates.count
            return n == 0 ? "add a plate" : "add a plate · \(n) added"
        case .workout(_, let minutes, _):
            return "move · \(minutes) min"
        case .lesson:
            return "lesson · 2 min"
        case .steps(let goal):
            return "\(goal.formatted()) steps"
        case .weighIn:
            return "weigh in"
        case .breath(let minutes, _):
            return "breathe · \(minutes) min"
        case .plank(let seconds):
            return "plank · \(seconds)s"
        case .water:
            return "water"
        case .measurements:
            return "measure"
        case .medication:
            return "your medication"
        case .bodyScan:
            return "body scan"
        }
    }

    private func beatState(_ beat: ProgramDayPrescription, snapshot: TodaySnapshot) -> JKBeatState {
        if case .steps(let goal) = beat {
            let fraction = goal > 0 ? Double(steps.todayCount) / Double(goal) : 0
            return JKBeatState(isDone: fraction >= 1, isAuto: true, progress: min(1, fraction))
        }
        let raw = snapshot.checkStates[beat.itemKey] ?? "empty"
        return JKBeatState(
            isDone: raw == "complete" || raw == "autoCompleted",
            isAuto: raw == "autoCompleted",
            progress: nil
        )
    }

    private func route(_ beat: ProgramDayPrescription) {
        switch beat {
        case .snapMeal: router.open(.snap)
        case .weighIn: router.open(.weighIn)
        case .lesson: router.open(.lesson)
        case .breath: router.open(.breath)
        case .workout: router.open(.workout)
        case .steps: router.open(.steps)
        case .plank, .water, .measurements, .medication, .bodyScan: router.tab = .today
        }
    }

    // MARK: food footer

    private func footerHasContent(_ snapshot: TodaySnapshot) -> Bool {
        if snapshot.targets.numericsSuppressed { return snapshot.targets.proteinG != nil }
        return snapshot.kcalEaten > 0
    }

    @ViewBuilder
    private func foodFooter(_ snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if snapshot.targets.numericsSuppressed {
                if let target = snapshot.targets.proteinG {
                    Text("protein \(snapshot.proteinEatenG) of \(target)g")
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }
            } else {
                if let kcalTarget = snapshot.targets.kcal {
                    JKKcalBar(kcal: snapshot.kcalEaten, target: kcalTarget)
                } else {
                    JKKcalLine(kcal: snapshot.kcalEaten, target: nil)
                }
                if let target = snapshot.targets.proteinG {
                    Text("protein \(snapshot.proteinEatenG) of \(target)g")
                        .font(Typo.caption)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }

    // MARK: helpers

    private func doneCount(_ snapshot: TodaySnapshot) -> Int {
        guard let day = snapshot.day else { return 0 }
        return day.beats.filter { beat in
            if beat.isProgressRow { return false }
            let s = snapshot.checkStates[beat.itemKey] ?? "empty"
            return s == "complete" || s == "autoCompleted"
        }.count
    }

    private func binaryCount(_ snapshot: TodaySnapshot) -> Int {
        snapshot.day?.beats.filter { !$0.isProgressRow }.count ?? 0
    }

    private func stickyTile(_ kind: ProgramDayPrescription.StickyColor) -> Color {
        switch kind {
        case .mint: return Palette.stickyMint
        case .butter: return Palette.stickyButter
        case .rose: return Palette.stickyRose
        case .olive: return Palette.stickyOlive
        }
    }

    private var weekdayWord: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: createdAt).lowercased()
    }

    private var shortDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: createdAt).lowercased()
    }

    private var a11yLabel: String {
        guard isLive, let snapshot else { return "\(weekdayWord)'s plan" }
        return "today's plan, \(doneCount(snapshot)) of \(binaryCount(snapshot)) done"
    }

    private func refresh() {
        guard !userId.isEmpty else { return }
        snapshot = TodayStateService.snapshot(userId: userId, in: modelContext)
    }
}

// MARK: - JKChatTrendCard
//
// "explain my trend" → the line itself. 28 days of EMA drawn in
// place, the 7-day delta in her unit, the latest weigh-in as the
// headline numeral. Tap-through opens the full trend on becoming.

struct JKChatTrendCard: View {
    let userId: String

    @Environment(\.modelContext) private var modelContext
    @State private var ema: [WeightTrendChart.EMAPoint] = []
    @State private var delta7dKg: Double?
    @State private var latestKg: Double?
    @State private var drawn = false
    @State private var router = AppRouter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var unit: WeightUnit { WeightUnit.current }

    var body: some View {
        Button {
            Haptics.light()
            router.open(.trend)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.cocoaPrimary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Palette.accentSubtle.opacity(0.5)))
                    Text("your trend")
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: 0)
                    if let deltaLine {
                        Text(deltaLine)
                            .font(Typo.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.cocoaSecondary)
                    }
                }

                if ema.count >= 2 {
                    HStack(alignment: .center, spacing: 14) {
                        sparkline
                            .frame(height: 56)
                            .frame(maxWidth: .infinity)
                        if let latestKg {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(String(format: "%.1f", unit.display(fromKg: latestKg)))
                                    .font(.custom("JeniHeroSerif-Regular", size: 30))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.textPrimary)
                                Text(unit.label)
                                    .font(Typo.numeralMeta)
                                    .kerning(0.1)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                    // Mission 2: chevrons are dead — the ghost
                    // italic line is the door.
                    Text("open the full trend \u{2197}")
                        .font(.custom("JeniHeroSerif-Italic", size: 16, relativeTo: .footnote))
                        .foregroundStyle(Palette.cocoaSecondary)
                } else {
                    Text("no trend yet · 2 weigh-ins start the line")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .jkChatCard()
        .onAppear {
            compute()
            if reduceMotion { drawn = true } else {
                withAnimation(Motion.trendDrawIn.delay(0.15)) { drawn = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
        .accessibilityHint("opens the full trend")
    }

    /// The last 28 EMA points as one under-glowed stroke — the same
    /// craft grammar as becoming's trend figure, at chat scale. A
    /// Shape (not Canvas) so `.trim` animates the draw-in natively.
    private var sparkline: some View {
        let values = Array(ema.suffix(28)).map(\.emaKg)
        return GeometryReader { geo in
            let line = JKSparklineShape(values: values)
            ZStack {
                // Under-glow rides the same trimmed geometry.
                line
                    .trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(Palette.accent.opacity(0.35),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .blur(radius: 3)
                line
                    .trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(Palette.cocoaPrimary,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                // The live tip lands with the stroke.
                if let tip = JKSparklineShape.point(
                    at: 1, values: values, in: geo.size
                ) {
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 6, height: 6)
                        .position(tip)
                        .opacity(drawn ? 1 : 0)
                        .animation(.easeOut(duration: 0.25).delay(1.0), value: drawn)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// "−1.2 lb this week" — the number, her unit, no adjectives.
    private var deltaLine: String? {
        guard let delta7dKg else { return nil }
        let display = unit.display(fromKg: abs(delta7dKg))
        if display < 0.1 { return "held this week" }
        let sign = delta7dKg < 0 ? "−" : "+"
        return "\(sign)\(String(format: "%.1f", display)) \(unit.label) this week"
    }

    private var a11y: String {
        var parts = ["your weight trend"]
        if let deltaLine { parts.append(deltaLine) }
        if let latestKg { parts.append("latest \(unit.formatted(fromKg: latestKg))") }
        return parts.joined(separator: ", ")
    }

    private func compute() {
        guard !userId.isEmpty else { return }
        let uid = userId
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == uid },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        ema = WeightTrendChart.computeEMA(logs: logs)
        delta7dKg = TodayStateService.emaDelta7d(ema)
        latestKg = logs.first?.weightKg
    }
}

// MARK: - JKSparklineShape
//
// The EMA polyline as an animatable Shape: normalized into the rect
// with smoothed mid-point quad curves. `.trim` gives the draw-in.

private struct JKSparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard let path = Self.linePath(values: values, in: rect.size) else {
            return Path()
        }
        return path
    }

    /// The normalized point at `fraction` (0 = first, 1 = last) —
    /// used to place the tip dot on the stroke's landing spot.
    static func point(at fraction: Double, values: [Double], in size: CGSize) -> CGPoint? {
        guard values.count >= 2, let lo = values.min(), let hi = values.max()
        else { return nil }
        let span = max(hi - lo, 0.2)
        let idx = Int((Double(values.count - 1) * fraction).rounded())
        let stepX = size.width / CGFloat(values.count - 1)
        let inset: CGFloat = 4
        return CGPoint(
            x: CGFloat(idx) * stepX,
            y: inset + (size.height - inset * 2)
                * CGFloat(1 - (values[idx] - lo) / span)
        )
    }

    private static func linePath(values: [Double], in size: CGSize) -> Path? {
        guard values.count >= 2, let lo = values.min(), let hi = values.max()
        else { return nil }
        let span = max(hi - lo, 0.2)
        let stepX = size.width / CGFloat(values.count - 1)
        let inset: CGFloat = 4

        func pt(_ i: Int) -> CGPoint {
            CGPoint(
                x: CGFloat(i) * stepX,
                y: inset + (size.height - inset * 2)
                    * CGFloat(1 - (values[i] - lo) / span)
            )
        }

        var path = Path()
        path.move(to: pt(0))
        for i in 1..<values.count {
            let prev = pt(i - 1), cur = pt(i)
            let mid = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
        }
        path.addLine(to: pt(values.count - 1))
        return path
    }
}
