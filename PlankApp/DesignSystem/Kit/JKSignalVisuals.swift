import SwiftUI

// MARK: - JKSignalVisuals (app v6 — the passive layer's objects)
//
// The signal components: the window horizon (Home's hero), the
// sleep dial + bars, the 7-night window band, cadence dots, and
// the sweetness mounds. All follow the house visual laws: palette
// tokens only, Motion.easedFinal fills, armed/disarm re-arming,
// Reduce-Motion resolves to a still finished frame, and every
// figure is one accessibility element with a spoken sentence.

// MARK: - Horizon geometry

/// The shallow arc a night makes over the module: endpoints on the
/// baseline, apex bulging up `rise`. Circle-chord math shared by the
/// shape, the tip dot, and the shader's tip uniform.
struct HorizonArcGeometry {
    let width: CGFloat
    let rise: CGFloat

    var radius: CGFloat { (width * width) / (8 * rise) + rise / 2 }
    var center: CGPoint { CGPoint(x: width / 2, y: radius) }

    /// Angles measured from `center`; t = 0 is the left endpoint
    /// (dusk), t = 1 the right (dawn).
    var startAngle: CGFloat { atan2(rise - radius, -width / 2) }
    var endAngle: CGFloat { atan2(rise - radius, width / 2) }

    func point(at t: CGFloat) -> CGPoint {
        let a = startAngle + (endAngle - startAngle) * min(1, max(0, t))
        return CGPoint(
            x: center.x + radius * cos(a),
            y: center.y + radius * sin(a)
        )
    }
}

private struct HorizonArcShape: Shape {
    var trim: CGFloat = 1

    var animatableData: CGFloat {
        get { trim }
        set { trim = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let geo = HorizonArcGeometry(width: rect.width, rise: rect.height)
        var p = Path()
        p.addArc(
            center: geo.center,
            radius: geo.radius,
            startAngle: .radians(geo.startAngle),
            endAngle: .radians(
                geo.startAngle + (geo.endAngle - geo.startAngle) * max(0.001, trim)
            ),
            clockwise: false
        )
        return p
    }
}

// MARK: - JKWindowHorizon
//
// The overnight window as a horizon: the kitchen's close sets on
// the left, the first plate (or "now") rises on the right, the
// night arcs between them. Deliberately NOT a gauge — the arc is a
// diagram with times at its feet, so it cannot be read as progress
// toward a fasting target. The jkDawn shader lights the stroke;
// when the night is live the tip breathes like an ember.

struct JKWindowHorizon: View {
    enum Mode: Equatable {
        /// The night is still open — the right foot is "now".
        case live(closedAt: Date, hours: Double)
        /// First plate landed — the window is a settled fact.
        case settled(closedAt: Date, openedAt: Date, hours: Double)
    }

    let mode: Mode
    /// Evening render: the same live arc wearing dusk light — rose
    /// sinking into deep cocoa-rose instead of blush rising to rose.
    var dusk: Bool = false
    var armed: Bool = true

    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let arcRise: CGFloat = 58
    private let footInset: CGFloat = 26

    private var isLive: Bool {
        if case .live = mode { return true }
        return false
    }

    private var arcGradient: LinearGradient {
        dusk
            ? LinearGradient(
                colors: [Palette.accent, Palette.jeweledRose],
                startPoint: .leading, endPoint: .trailing
            )
            : LinearGradient(
                colors: [Palette.accentSubtle, Palette.accent],
                startPoint: .leading, endPoint: .trailing
            )
    }

    private var hours: Double {
        switch mode {
        case let .live(_, h): return h
        case let .settled(_, _, h): return h
        }
    }

    private var closedAt: Date {
        switch mode {
        case let .live(at, _): return at
        case let .settled(at, _, _): return at
        }
    }

    private var rightLabel: String {
        switch mode {
        case .live: return "now"
        case let .settled(_, openedAt, _): return Self.clockWord(openedAt)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let w = proxy.size.width - footInset * 2
                let geo = HorizonArcGeometry(width: w, rise: arcRise)
                let tip = geo.point(at: drawn ? 1 : 0)

                ZStack(alignment: .topLeading) {
                    // The hairline track — the whole night, faint.
                    HorizonArcShape(trim: 1)
                        .stroke(Palette.hairlineCocoa,
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        .frame(width: w, height: arcRise)

                    // The lit arc, drawn in on arrival, lit by jkDawn.
                    TimelineView(.animation(minimumInterval: 1 / 30,
                                            paused: reduceMotion || !isLive)) { context in
                        let t = reduceMotion
                            ? 0.0
                            : context.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: 600)
                        HorizonArcShape(trim: drawn ? 1 : 0.001)
                            .stroke(
                                arcGradient,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: w, height: arcRise)
                            .colorEffect(ShaderLibrary.jkDawn(
                                .float2(Float(w), Float(arcRise)),
                                .float(Float(t)),
                                .float(isLive ? 1 : 0),
                                .float2(Float(tip.x), Float(tip.y))
                            ))
                    }

                    // The feet: dusk dot + dawn dot (or the breathing now-ember).
                    footDot(at: geo.point(at: 0), live: false)
                    footDot(at: tip, live: isLive)
                        .opacity(drawn ? 1 : 0)

                    // The numeral, resting under the apex.
                    VStack(spacing: 1) {
                        Text("\(Int(hours.rounded()))")
                            .font(.custom("JeniHeroSerif-Regular", size: 30))
                            .foregroundStyle(Palette.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(isLive ? "hours since your last plate, so far" : "hours since your last plate")
                            .font(Typo.numeralMeta)
                            .kerning(0.1)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .frame(width: w)
                    .offset(y: arcRise - 42)
                    .opacity(drawn ? 1 : 0)
                }
                .padding(.horizontal, footInset)
            }
            .frame(height: arcRise + 18)

            // The times at the feet — the diagram's provenance.
            HStack {
                Text(Self.clockWord(closedAt))
                Spacer()
                Text(rightLabel)
            }
            .font(Typo.numeralMeta)
            .monospacedDigit()
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.horizontal, footInset - 8)
        }
        .onAppear { if armed { arm() } }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else { disarm() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isLive
                ? "overnight fast since \(Self.clockWord(closedAt)), about \(Int(hours.rounded())) hours so far"
                : "your overnight fast ran about \(Int(hours.rounded())) hours"
        )
    }

    @ViewBuilder
    private func footDot(at point: CGPoint, live: Bool) -> some View {
        ZStack {
            if live && !reduceMotion {
                PulsingEmber()
            }
            Circle()
                .fill(live ? Palette.accent : Palette.cocoaSecondary)
                .frame(width: 7, height: 7)
        }
        .position(point)
    }

    private func arm() {
        if reduceMotion { drawn = true; return }
        withAnimation(Motion.trendDrawIn.delay(0.15)) { drawn = true }
    }

    private func disarm() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { drawn = false }
    }

    static func clockWord(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = Locale.current.hourCycle == .zeroToTwentyThree ? "H:mm" : "h:mma"
        return f.string(from: date).lowercased()
    }
}

/// The live tip's breathing halo — pure SwiftUI so it composes with
/// the shader's ember instead of fighting it.
private struct PulsingEmber: View {
    @State private var up = false
    var body: some View {
        Circle()
            .fill(Palette.accent.opacity(0.28))
            .frame(width: 22, height: 22)
            .scaleEffect(up ? 1.25 : 0.8)
            .opacity(up ? 0.25 : 0.6)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
    }
}

// MARK: - JKFormingHorizon
//
// The window before it exists: the hairline track and two waiting
// feet, nothing lit. The signals band shows this instead of
// emptiness on day one — she's finishing a set that has already
// started, not starting from zero.

struct JKFormingHorizon: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width - 52
            ZStack(alignment: .topLeading) {
                HorizonArcShape(trim: 1)
                    .stroke(Palette.hairlineCocoa,
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round,
                                               dash: [0.5, 6]))
                    .frame(width: w, height: 44)
                Circle()
                    .fill(Palette.cocoaTertiary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .position(HorizonArcGeometry(width: w, rise: 44).point(at: 0))
                Circle()
                    .strokeBorder(Palette.cocoaTertiary.opacity(0.5), lineWidth: 1)
                    .frame(width: 6, height: 6)
                    .position(HorizonArcGeometry(width: w, rise: 44).point(at: 1))
            }
            .padding(.horizontal, 26)
        }
        .frame(height: 52)
        .accessibilityHidden(true)
    }
}

// MARK: - JKCrescent
//
// The sleep row's glyph: a real crescent (two-circle cut), not an
// SF symbol — matches the hand-drawn JKMark family.

struct JKCrescent: View {
    var size: CGFloat = 14
    var color: Color = Palette.cocoaSecondary

    var body: some View {
        Canvas { context, canvasSize in
            let r = canvasSize.width / 2
            var moon = Path(ellipseIn: CGRect(x: 0, y: 0, width: r * 2, height: r * 2))
            let bite = Path(ellipseIn: CGRect(x: r * 0.62, y: -r * 0.18, width: r * 1.9, height: r * 1.9))
            moon = moon.subtracting(bite)
            context.fill(moon, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - JKSleepDial
//
// Last night as a dome: bedtime rises on the left, wake sets on the
// right, the stages band the arc (deep in full cocoa, core lighter,
// rem in rose). The jkNightSky shader breathes a whisper of stars
// inside the dome. The center speaks the one number that matters.

struct JKSleepDial: View {
    let night: LastNightSleep
    var diameter: CGFloat = 216
    var armed: Bool = true

    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 220° dome, opening at the bottom (the protein arc's stance).
    private let sweep: Double = 220
    private var startAngle: Double { 90 + (360 - sweep) / 2 }

    var body: some View {
        ZStack {
            // The dome's atmosphere — a faint night fill with stars.
            TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
                let t = reduceMotion
                    ? 0.0
                    : context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 600)
                Circle()
                    .trim(from: 0, to: sweep / 360)
                    .rotation(.degrees(startAngle))
                    .fill(
                        RadialGradient(
                            colors: [Palette.accentSubtle.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 6, endRadius: diameter / 2
                        )
                    )
                    .colorEffect(ShaderLibrary.jkNightSky(
                        .float2(Float(diameter), Float(diameter)),
                        .float(Float(t))
                    ))
            }

            // The track.
            domeArc(from: 0, to: 1)
                .stroke(Palette.hairlineCocoa,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))

            // The stage bands.
            ForEach(Array(bands.enumerated()), id: \.offset) { idx, band in
                domeArc(from: band.from, to: drawn ? band.to : band.from)
                    .stroke(band.color,
                            style: StrokeStyle(lineWidth: 5, lineCap: .butt))
                    .animation(
                        Motion.easedFinal.delay(Double(idx) * 0.03),
                        value: drawn
                    )
            }

            // The heart of the night.
            VStack(spacing: 2) {
                JKCrescent(size: 15)
                Text(SleepSignal.durationWord(night.asleepDuration))
                    .font(.custom("JeniHeroSerif-Regular", size: 32))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                Text("asleep")
                    .font(Typo.numeralMeta)
                    .kerning(0.1)
                    .foregroundStyle(Palette.textSecondary)
            }
            .opacity(drawn ? 1 : 0)
            .animation(Motion.easedFinal.delay(Motion.perceptualLag), value: drawn)

            // The night's bounds at the dome's feet.
            boundLabel(JKWindowHorizon.clockWord(night.bedtime), at: 0)
            boundLabel(JKWindowHorizon.clockWord(night.wakeTime), at: 1)
        }
        .frame(width: diameter, height: diameter)
        .onAppear { if armed { arm() } }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { drawn = false }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "asleep \(SleepSignal.durationWord(night.asleepDuration)), from \(JKWindowHorizon.clockWord(night.bedtime)) to \(JKWindowHorizon.clockWord(night.wakeTime))"
        )
    }

    private struct Band {
        let from: Double
        let to: Double
        let color: Color
    }

    /// Stage → arc fraction bands. Awake + inBed spans stay track-
    /// colored (the honest gaps in the night).
    private var bands: [Band] {
        guard night.inBedDuration > 0 else { return [] }
        return night.stages.compactMap { stage in
            let color: Color
            switch stage.kind {
            case .asleepDeep: color = Palette.cocoaPrimary
            case .asleepREM: color = Palette.accent
            case .asleepCore, .asleep: color = Palette.cocoaSecondary.opacity(0.75)
            case .inBed, .awake: return nil
            }
            let from = stage.startOffset / night.inBedDuration
            let to = (stage.startOffset + stage.duration) / night.inBedDuration
            return Band(from: max(0, from), to: min(1, to), color: color)
        }
    }

    private func domeArc(from: Double, to: Double) -> some Shape {
        Circle()
            .trim(from: (sweep / 360) * min(1, max(0, from)),
                  to: (sweep / 360) * min(1, max(0, to)))
            .rotation(.degrees(startAngle))
    }

    @ViewBuilder
    private func boundLabel(_ text: String, at t: Double) -> some View {
        let angle = Angle.degrees(startAngle + sweep * t)
        let r = diameter / 2 + 16
        Text(text)
            .font(Typo.numeralMeta)
            .monospacedDigit()
            .foregroundStyle(Palette.cocoaTertiary)
            .offset(x: CGFloat(cos(angle.radians)) * r * 0.82,
                    y: CGFloat(sin(angle.radians)) * r * 0.82 + 10)
    }

    private func arm() {
        if reduceMotion { drawn = true; return }
        withAnimation { drawn = true }
    }
}

// MARK: - JKWindowWeekBand
//
// Seven nights as falling bands: each capsule spans from the
// kitchen's close (top, dusk-rose) to the first plate (bottom,
// dawn-blush) on a shared evening→noon axis. Silent nights rest as
// a dot on the midnight line — absence stays quiet, never zero.

struct JKWindowWeekBand: View {
    let nights: [KitchenSignal.Night]   // oldest → today, 7 entries
    var height: CGFloat = 196
    var armed: Bool = true

    @State private var drawn = false
    @State private var selectedIdx: Int? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Axis: 18:00 → 12:00 next day (in minutes-of-day, folded).
    private let axisTop: Double = 18 * 60
    private let axisBottom: Double = 36 * 60

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let w = proxy.size.width
                let colW = w / CGFloat(max(nights.count, 1))

                ZStack(alignment: .topLeading) {
                    // The selection wash — a faint column behind the
                    // tapped night, under everything else.
                    if let sel = selectedIdx {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Palette.cocoaPrimary.opacity(0.05))
                            .frame(width: colW - 6, height: proxy.size.height)
                            .position(x: colW * (CGFloat(sel) + 0.5),
                                      y: proxy.size.height / 2)
                            .transition(.opacity)
                    }

                    // Midnight + 6am seams, whisper-faint (lines under
                    // the capsules, labels over them).
                    seamLine(at: 24 * 60, in: proxy.size)
                    seamLine(at: 30 * 60, in: proxy.size)

                    ForEach(Array(nights.enumerated()), id: \.element.id) { idx, night in
                        let x = colW * (CGFloat(idx) + 0.5)
                        if let closedAt = night.closedAt, let openedAt = night.openedAt {
                            nightCapsule(
                                closedAt: closedAt, openedAt: openedAt,
                                isToday: night.daysAgo == 0,
                                index: idx, x: x, size: proxy.size
                            )
                        } else {
                            Circle()
                                .fill(Palette.hairlineCocoa)
                                .frame(width: 4, height: 4)
                                .position(x: x, y: y(for: 24 * 60, in: proxy.size))
                        }
                    }

                    seamLabel("midnight", at: 24 * 60, in: proxy.size)
                    seamLabel("6am", at: 30 * 60, in: proxy.size)

                    // Tap strips — full-height columns so a 7pt capsule
                    // never demands a 7pt finger. Taps only; the pager's
                    // swipes pass straight through.
                    ForEach(Array(nights.indices), id: \.self) { idx in
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: colW, height: proxy.size.height)
                            .position(x: colW * (CGFloat(idx) + 0.5),
                                      y: proxy.size.height / 2)
                            .onTapGesture { select(idx) }
                    }
                }
            }
            .frame(height: height)

            // Weekday feet.
            HStack(spacing: 0) {
                ForEach(Array(nights.enumerated()), id: \.element.id) { idx, night in
                    Text(dayLetter(daysAgo: night.daysAgo))
                        .font(Typo.statLabel)
                        .kerning(0.5)
                        .foregroundStyle(
                            selectedIdx == idx || (selectedIdx == nil && night.daysAgo == 0)
                                ? Palette.cocoaPrimary
                                : Palette.cocoaTertiary
                        )
                        .frame(maxWidth: .infinity)
                }
            }

            JKSignalCallout(text: selectedIdx.map(calloutText))
        }
        .animation(Motion.easedFinal, value: selectedIdx)
        .onAppear {
            if armed { arm() }
            debugAutoSelect()
        }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { drawn = false; selectedIdx = nil }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func select(_ idx: Int) {
        Haptics.soft()
        selectedIdx = selectedIdx == idx ? nil : idx
    }

    /// "tuesday · 12h 40m · 8:52pm to 9:32am" — the night, told plainly.
    private func calloutText(_ idx: Int) -> String {
        let night = nights[idx]
        let day = jkWeekdayWord(daysAgo: night.daysAgo, todayWord: "last night")
        guard let hours = night.hours,
              let closedAt = night.closedAt, let openedAt = night.openedAt
        else { return "\(day) · not enough plates to measure" }
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        let close = f.string(from: closedAt).lowercased()
        let open = f.string(from: openedAt).lowercased()
        return "\(day) · \(SleepSignal.durationWord(hours * 3600)) · \(close) to \(open)"
    }

    private func debugAutoSelect() {
        #if DEBUG
        // QA: pre-select a narrated night so screenshots carry the
        // callout without a synthetic tap.
        if selectedIdx == nil,
           ProcessInfo.processInfo.arguments.contains("--uitest-select-figure") {
            selectedIdx = nights.lastIndex(where: { $0.hours != nil && $0.daysAgo != 0 })
                ?? nights.firstIndex(where: { $0.hours != nil })
        }
        #endif
    }

    @ViewBuilder
    private func nightCapsule(
        closedAt: Date, openedAt: Date, isToday: Bool, index: Int,
        x: CGFloat, size: CGSize
    ) -> some View {
        let closeM = foldedMinutes(closedAt)
        let openM = foldedMinutes(openedAt, isOpen: true)
        let top = y(for: closeM, in: size)
        let bottom = max(y(for: openM, in: size), top + 10)
        let h = drawn ? bottom - top : 10

        // Grows DOWNWARD from the close point — dusk first, dawn last —
        // because height and center-y ride the same animation.
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Palette.accent.opacity(isToday ? 0.95 : 0.62),
                        Palette.accentSubtle.opacity(isToday ? 0.95 : 0.7),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: isToday ? 9 : 7, height: h)
            .position(x: x, y: top + h / 2)
            .animation(
                Motion.easedFinal.delay(Double(index) * 0.05),
                value: drawn
            )
    }

    private func foldedMinutes(_ date: Date, isOpen: Bool = false) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        var m = Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
        // Opens are morning times on the NEXT day of the axis; closes
        // past midnight fold forward too.
        if isOpen || m < 17 * 60 { m += 24 * 60 }
        return min(max(m, axisTop), axisBottom)
    }

    private func y(for minutes: Double, in size: CGSize) -> CGFloat {
        let t = (minutes - axisTop) / (axisBottom - axisTop)
        return CGFloat(t) * size.height
    }

    @ViewBuilder
    private func seamLine(at minutes: Double, in size: CGSize) -> some View {
        Rectangle()
            .fill(Palette.hairlineCocoa.opacity(0.7))
            .frame(width: size.width, height: 0.66)
            .position(x: size.width / 2, y: y(for: minutes, in: size))
    }

    /// Rendered ABOVE the capsules with a cream backing so a
    /// late-week capsule can't strike through the word.
    @ViewBuilder
    private func seamLabel(_ label: String, at minutes: Double, in size: CGSize) -> some View {
        Text(label)
            .font(Typo.kicker)
            .kerning(0.8)
            .foregroundStyle(Palette.cocoaTertiary.opacity(0.8))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(Palette.bgPrimary.opacity(0.92)))
            .position(x: size.width - 26, y: y(for: minutes, in: size) - 9)
    }

    private func dayLetter(daysAgo: Int) -> String {
        guard let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)
        else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: day).lowercased()
    }

    private var accessibilitySummary: String {
        let narrated = nights.compactMap(\.hours)
        guard !narrated.isEmpty else { return "the week's overnight windows" }
        let avg = narrated.reduce(0, +) / Double(narrated.count)
        return "\(narrated.count) overnight windows this week, about \(Int(avg.rounded())) hours on average"
    }

    private func arm() {
        if reduceMotion { drawn = true; return }
        withAnimation { drawn = true }
    }
}

// MARK: - JKSleepBars
//
// The week of nights: soft columns of asleep-hours with the 7-hour
// line as a quiet reference (most grown bodies settle near 7 to 9 —
// a fact, not homework). Missing nights rest as dots.

struct JKSleepBars: View {
    /// Asleep hours per night, oldest → today (7 entries; nil = no data).
    let nights: [Double?]
    var height: CGFloat = 170
    var armed: Bool = true

    @State private var drawn = false
    @State private var selectedIdx: Int? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let scaleMax: Double = 10

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                let colW = w / CGFloat(max(nights.count, 1))
                let refY = h * (1 - CGFloat(7 / scaleMax))

                ZStack(alignment: .topLeading) {
                    if let sel = selectedIdx {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Palette.cocoaPrimary.opacity(0.05))
                            .frame(width: colW - 6, height: h)
                            .position(x: colW * (CGFloat(sel) + 0.5), y: h / 2)
                            .transition(.opacity)
                    }

                    // The 7h reference seam.
                    Rectangle()
                        .fill(Palette.hairlineCocoa.opacity(0.8))
                        .frame(width: w, height: 0.66)
                        .position(x: w / 2, y: refY)
                    Text("7h")
                        .font(Typo.kicker)
                        .kerning(0.6)
                        .foregroundStyle(Palette.cocoaTertiary.opacity(0.8))
                        .position(x: w - 12, y: refY - 8)

                    ForEach(Array(nights.enumerated()), id: \.offset) { idx, hours in
                        let x = colW * (CGFloat(idx) + 0.5)
                        if let hours {
                            let isToday = idx == nights.count - 1
                            let barH = max(10, h * CGFloat(min(hours, scaleMax) / scaleMax))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Palette.cocoaSecondary.opacity(isToday ? 1 : 0.55),
                                            Palette.cocoaPrimary.opacity(isToday ? 1 : 0.62),
                                        ],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(width: isToday ? 10 : 8,
                                       height: drawn ? barH : 10)
                                .position(x: x, y: h - (drawn ? barH : 10) / 2)
                                .animation(
                                    Motion.easedFinal.delay(Double(idx) * 0.05),
                                    value: drawn
                                )
                        } else {
                            Circle()
                                .fill(Palette.hairlineCocoa)
                                .frame(width: 4, height: 4)
                                .position(x: x, y: h - 4)
                        }
                    }

                    ForEach(Array(nights.indices), id: \.self) { idx in
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(width: colW, height: h)
                            .position(x: colW * (CGFloat(idx) + 0.5), y: h / 2)
                            .onTapGesture { select(idx) }
                    }
                }
            }
            .frame(height: height)

            JKSignalCallout(text: selectedIdx.map(calloutText))
        }
        .animation(Motion.easedFinal, value: selectedIdx)
        .onAppear {
            if armed { arm() }
            debugAutoSelect()
        }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { drawn = false; selectedIdx = nil }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func select(_ idx: Int) {
        Haptics.soft()
        selectedIdx = selectedIdx == idx ? nil : idx
    }

    /// "wednesday · 7h 12m asleep" — one night, told plainly.
    private func calloutText(_ idx: Int) -> String {
        let day = jkWeekdayWord(daysAgo: nights.count - 1 - idx, todayWord: "last night")
        guard let hours = nights[idx] else { return "\(day) · no sleep data" }
        return "\(day) · \(SleepSignal.durationWord(hours * 3600)) asleep"
    }

    private func debugAutoSelect() {
        #if DEBUG
        if selectedIdx == nil,
           ProcessInfo.processInfo.arguments.contains("--uitest-select-figure") {
            selectedIdx = nights.lastIndex(where: { $0 != nil })
        }
        #endif
    }

    private var accessibilitySummary: String {
        let known = nights.compactMap { $0 }
        guard !known.isEmpty else { return "the week's nights" }
        let avg = known.reduce(0, +) / Double(known.count)
        return "\(known.count) nights tracked, about \(SleepSignal.durationWord(avg * 3600)) a night"
    }

    private func arm() {
        if reduceMotion { drawn = true; return }
        withAnimation { drawn = true }
    }
}

// MARK: - JKCadenceDots
//
// Two weeks of weigh-ins as a rhythm of dots — consistency made
// visible without a single streak number. Filled = weighed; open =
// a day that simply happened.

struct JKCadenceDots: View {
    /// Trailing 14 days, oldest → today.
    let flags: [Bool]
    var armed: Bool = true

    @State private var drawn = false
    @State private var selectedIdx: Int? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 18) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        let on = idx < flags.count && flags[idx]
                        let isToday = idx == flags.count - 1
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    selectedIdx == idx
                                        ? Palette.cocoaPrimary
                                        : isToday ? Palette.cocoaSecondary : Palette.hairlineCocoa,
                                    lineWidth: selectedIdx == idx ? 1.4 : isToday ? 1.2 : 1
                                )
                                .frame(width: 13, height: 13)
                            if on {
                                Circle()
                                    .fill(Palette.accent)
                                    .frame(width: 9, height: 9)
                                    .scaleEffect(drawn ? 1 : 0.2)
                                    .animation(
                                        Motion.gentleSpring.delay(Double(idx) * 0.035),
                                        value: drawn
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { select(idx) }
                    }
                }
            }

            JKSignalCallout(text: selectedIdx.map(calloutText))
        }
        .animation(Motion.easedFinal, value: selectedIdx)
        .onAppear {
            if armed { arm() }
            #if DEBUG
            if selectedIdx == nil,
               ProcessInfo.processInfo.arguments.contains("--uitest-select-figure") {
                selectedIdx = flags.lastIndex(of: true)
            }
            #endif
        }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { drawn = false; selectedIdx = nil }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(flags.filter { $0 }.count) weigh-ins across the last two weeks")
    }

    private func select(_ idx: Int) {
        guard idx < flags.count else { return }
        Haptics.soft()
        selectedIdx = selectedIdx == idx ? nil : idx
    }

    /// "monday · weighed in" — one day of the cadence, told plainly.
    private func calloutText(_ idx: Int) -> String {
        let day = jkWeekdayWord(daysAgo: flags.count - 1 - idx, todayWord: "today")
        return flags[idx] ? "\(day) · weighed in" : "\(day) · no weigh-in"
    }

    private func arm() {
        if reduceMotion { drawn = true; return }
        withAnimation { drawn = true }
    }
}

// MARK: - JKMomentMounds
//
// A day in three soft mounds: morning, afternoon, evening shares of
// some substance (sweetness in rose, protein in cocoa). Shares only
// — no gram axis, no verdict color. The dominant moment stands a
// little taller and a little warmer.

struct JKMomentMounds: View {
    enum Tint { case rose, cocoa }

    let morning: Double
    let afternoon: Double
    let evening: Double
    var tint: Tint = .rose
    /// Spoken substance for the accessibility sentence.
    var substance: String = "sugar intake"
    var height: CGFloat = 150
    var armed: Bool = true
    /// Mission 2: optional per-bar value captions (e.g. "14%") shown
    /// above each mound — lets the pages retire the JKStatTriplet
    /// that duplicated the axis labels (one row, not two).
    var values: [String]? = nil

    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shares: [(label: String, value: Double)] {
        [("morning", morning), ("afternoon", afternoon), ("evening", evening)]
    }
    private var maxShare: Double { max(morning, afternoon, evening, 0.001) }

    private func gradient(dominant: Bool) -> LinearGradient {
        switch tint {
        case .rose:
            return LinearGradient(
                colors: dominant
                    ? [Palette.accent, Palette.accentSubtle]
                    : [Palette.accentSubtle.opacity(0.85),
                       Palette.accentSubtle.opacity(0.45)],
                startPoint: .top, endPoint: .bottom
            )
        case .cocoa:
            return LinearGradient(
                colors: dominant
                    ? [Palette.cocoaPrimary.opacity(0.9), Palette.cocoaSecondary.opacity(0.5)]
                    : [Palette.cocoaSecondary.opacity(0.45),
                       Palette.cocoaSecondary.opacity(0.18)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    @State private var selectedIdx: Int? = nil

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 22) {
                ForEach(Array(shares.enumerated()), id: \.offset) { idx, item in
                    let isDominant = item.value >= maxShare - 0.0001
                    VStack(spacing: 8) {
                        if let values, idx < values.count {
                            Text(values[idx])
                                .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .body))
                                .monospacedDigit()
                                .foregroundStyle(
                                    isDominant ? Palette.textPrimary : Palette.textSecondary
                                )
                                .opacity(drawn ? 1 : 0)
                                .animation(
                                    Motion.easedFinal.delay(0.3 + Double(idx) * 0.07),
                                    value: drawn
                                )
                                .padding(.bottom, 2)
                        }
                        UnevenRoundedRectangle(
                            topLeadingRadius: 22, topTrailingRadius: 22
                        )
                        .fill(gradient(dominant: isDominant))
                        .frame(height: drawn
                            ? max(14, height * CGFloat(item.value / maxShare) * 0.82)
                            : 14)
                        .animation(
                            Motion.easedFinal.delay(Double(idx) * 0.07),
                            value: drawn
                        )

                        Text(item.label)
                            .font(Typo.statLabel)
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(
                                selectedIdx == idx
                                    ? Palette.cocoaPrimary
                                    : isDominant ? Palette.cocoaSecondary : Palette.cocoaTertiary
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .background(alignment: .bottom) {
                        if selectedIdx == idx {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Palette.cocoaPrimary.opacity(0.05))
                                .frame(height: height + 24)
                                .padding(.horizontal, -8)
                                .transition(.opacity)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { select(idx) }
                }
            }
            .frame(height: height + 24, alignment: .bottom)

            JKSignalCallout(text: selectedIdx.map(calloutText))
        }
        .animation(Motion.easedFinal, value: selectedIdx)
        .onAppear {
            if armed { arm() }
            #if DEBUG
            if selectedIdx == nil,
               ProcessInfo.processInfo.arguments.contains("--uitest-select-figure") {
                selectedIdx = shares.indices.max(by: { shares[$0].value < shares[$1].value })
            }
            #endif
        }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { drawn = false; selectedIdx = nil }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(substance) lands mostly in your \(dominantWord)")
    }

    private func select(_ idx: Int) {
        Haptics.soft()
        selectedIdx = selectedIdx == idx ? nil : idx
    }

    /// "evenings · 62% of your sugar" — one share, told plainly.
    private func calloutText(_ idx: Int) -> String {
        let item = shares[idx]
        let total = max(morning + afternoon + evening, 0.001)
        let pct = Int((item.value / total * 100).rounded())
        return "\(item.label)s · \(pct)% of your \(substance)"
    }

    private var dominantWord: String {
        if evening >= morning && evening >= afternoon { return "evenings" }
        if morning >= afternoon { return "mornings" }
        return "afternoons"
    }

    private func arm() {
        if reduceMotion { drawn = true; return }
        withAnimation { drawn = true }
    }
}

// MARK: - JKSignalCallout — the tap's answer, one reserved line

/// The shared detail line under every tappable signal figure: fades
/// in with the selection, holds its height when empty so the page
/// never jumps. Taps only — the pager's swipes stay untouched.
struct JKSignalCallout: View {
    let text: String?

    var body: some View {
        Text(text ?? " ")
            .font(.custom("DMSans-Medium", size: 12))
            .monospacedDigit()
            .foregroundStyle(Palette.cocoaSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .opacity(text == nil ? 0 : 1)
            .frame(maxWidth: .infinity)
            .frame(height: 15)
            .accessibilityHidden(text == nil)
    }
}

/// "last night" / "tuesday" / "last tuesday" — how the figures name a
/// day when tapped. daysAgo 7–13 says "last" so the cadence grid's
/// second week never masquerades as this one.
func jkWeekdayWord(daysAgo: Int, todayWord: String) -> String {
    guard daysAgo > 0 else { return todayWord }
    guard let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)
    else { return "" }
    let f = DateFormatter()
    f.dateFormat = "EEEE"
    let word = f.string(from: day).lowercased()
    return daysAgo >= 7 ? "last \(word)" : word
}

// MARK: - JKSeasonBand
//
// The cycle as a season track: four soft segments (a compressed
// bleed segment, the open follicular stretch, a mid seam, the
// warmer luteal tail) with one breathing today-dot placed
// QUALITATIVELY. Deliberately unlabeled and unnumbered — this is
// context for appetite, never a calendar, never a prediction.

struct JKSeasonBand: View {
    let phase: CycleSignal.Phase
    /// 0…1 position across the whole cycle, qualitative only.
    let position: Double
    var armed: Bool = true

    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                let w = proxy.size.width
                let usable = w - 15   // three 5pt seams
                let x = 10 + CGFloat(min(max(position, 0), 1)) * (w - 20)

                ZStack(alignment: .leading) {
                    HStack(spacing: 5) {
                        segment(width: usable * 0.14, warm: phase == .menstrual, base: 0.5)
                        segment(width: usable * 0.36, warm: phase == .follicular, base: 0.28)
                        segment(width: usable * 0.12, warm: false, base: 0.34)
                        segment(width: usable * 0.38, warm: phase == .luteal, base: 0.42)
                    }
                    .frame(height: 10)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .opacity(drawn ? 1 : 0)

                    Circle()
                        .fill(Palette.cocoaPrimary)
                        .frame(width: 9, height: 9)
                        .overlay(
                            Circle()
                                .strokeBorder(Palette.bgPrimary, lineWidth: 1.6)
                        )
                        .position(x: x, y: proxy.size.height / 2)
                        .opacity(drawn ? 1 : 0)
                        .animation(Motion.easedFinal.delay(0.25), value: drawn)
                }
            }
            .frame(height: 24)

            Text("today")
                .font(Typo.kicker)
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
        }
        .onAppear { if armed { arm() } }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { drawn = false }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityWord)
    }

    @ViewBuilder
    private func segment(width: CGFloat, warm: Bool, base: Double) -> some View {
        Capsule()
            .fill(
                warm
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Palette.accent.opacity(0.85), Palette.accentSubtle],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    : AnyShapeStyle(Palette.accentSubtle.opacity(base))
            )
            .frame(width: max(width, 8))
    }

    private var accessibilityWord: String {
        switch phase {
        case .menstrual: return "period days"
        case .follicular: return "the quieter stretch of your cycle"
        case .luteal: return "the hungrier stretch before a period"
        }
    }

    private func arm() {
        if reduceMotion { drawn = true; return }
        withAnimation(Motion.easedFinal) { drawn = true }
    }
}

// MARK: - JKStagedReveal
//
// The page's second and third voices (stats, then meaning) enter
// AFTER the figure has begun speaking — frame audits showed them
// popping in at frame zero while the capsules were still drawing.
// Same arm/disarm contract as the figures, so swiping back replays
// the whole sentence in order.

private struct JKStagedReveal: ViewModifier {
    let armed: Bool
    let delay: Double

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 4)
            .onAppear { if armed { arm() } }
            .onChange(of: armed) { _, isArmed in
                if isArmed { arm() } else {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { shown = false }
                }
            }
    }

    private func arm() {
        if reduceMotion { shown = true; return }
        withAnimation(Motion.entranceSoft.delay(delay)) { shown = true }
    }
}

extension View {
    /// Staged entrance for a story page's supporting lines: waits
    /// `delay` after the page arms, then rises in. Reduce Motion
    /// resolves instantly.
    func jkStagedReveal(armed: Bool, delay: Double) -> some View {
        modifier(JKStagedReveal(armed: armed, delay: delay))
    }
}

// MARK: - JKStatTriplet
//
// The analysis pages' detail row: two or three quiet stat columns
// (value in medium sans, label in tracked small caps) — the same
// grammar as the weight page's started / now / goal row, promoted
// to a shared component so every story reads as one system.

struct JKStatTriplet: View {
    struct Item: Identifiable {
        let value: String
        let label: String
        var id: String { label }
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                VStack(spacing: 3) {
                    Text(item.value)
                        .font(.custom("DMSans-Medium", size: 15))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                    Text(item.label)
                        .font(Typo.statLabel)
                        .kerning(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - JKBodyLine
//
// The coach's "so what" — one serif-italic line under a figure that
// ties the pattern back to HER body (BodyLine engine composes it;
// this renders it). The eyebrow names the register once per page.

struct JKBodyLine: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("for your body")
                .font(Typo.kicker)
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.accent.opacity(0.85))
            Text(text)
                .font(.custom("JeniHeroSerif-Italic", size: 15, relativeTo: .body))
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - JKSectionSeam
//
// Home's section header, refined: tracked small caps over a hairline
// rule that runs to the edge — editorial structure instead of a
// floating caption. Optional trailing detail rides the same line.

struct JKSectionSeam: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: 12)
                if let detail {
                    Text(detail)
                        .font(Typo.kicker)
                        .kerning(0.8)
                        .foregroundStyle(Palette.cocoaTertiary.opacity(0.85))
                }
            }
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(height: 0.66)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - JKSeasonMark
//
// The Home row's glyph: a small ring with a warm arc segment where
// the cycle currently sits. Qualitative, tiny, quiet.

struct JKSeasonMark: View {
    let position: Double   // 0…1 around the ring
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.hairlineCocoa, lineWidth: 1.2)
            Circle()
                .trim(from: max(0, position - 0.10), to: min(1, position + 0.10))
                .stroke(Palette.accent,
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
