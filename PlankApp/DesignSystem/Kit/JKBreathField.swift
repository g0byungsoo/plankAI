import SwiftUI

// MARK: - JKBreathField (app v4, docs/app_v4/03_FEATURES.md §6)
//
// The breathing minute, rebuilt. The static PNG that scale-animated
// with symmetric easeInOut (and a 1Hz countdown numeral) dies; in
// its place a GENERATIVE bloom — layered petal glows drawn per-frame
// in Canvas, breathing on a sinusoidal curve whose velocity reaches
// zero at every turn (the Apple Breathe curve family), each petal
// trailing the core by a phase offset so the bloom feels alive
// rather than scaled. Anticipation: a soft glow gathers ~0.3s before
// each turn so the eye knows before the turn arrives. Holds are
// stillness with micro-drift. No numerals anywhere mid-breath.
//
// Everything renders from pure date math (BreathClock) — the visual
// can't drift from the haptic/word driver because they read the
// same clock.

// MARK: - BreathClock (pure)

enum BreathClock {

    enum Phase: Equatable {
        case inhale, hold, exhale, done
    }

    struct State: Equatable {
        let phase: Phase
        /// 0...1 through the current phase.
        let phaseT: Double
        /// The breath position 0 (empty) ... 1 (full) — sinusoidal,
        /// zero velocity at both ends of every phase.
        let p: Double
        /// 0...1 anticipation glow, peaking ~0.3s before each turn.
        let turnGlow: Double
        /// 0-indexed breath this elapsed falls in (clamped to reps-1).
        let rep: Int
        /// Completed full breaths.
        let repsDone: Int
    }

    /// The whole session, computed from elapsed seconds. Pure —
    /// table-tested in BreathClockTests.
    static func state(
        elapsed: TimeInterval,
        inhale: Double,
        hold: Double,
        exhale: Double,
        reps: Int
    ) -> State {
        let cycle = inhale + hold + exhale
        guard cycle > 0, reps > 0 else {
            return State(phase: .done, phaseT: 1, p: 0, turnGlow: 0, rep: 0, repsDone: 0)
        }
        let total = cycle * Double(reps)
        if elapsed >= total {
            return State(phase: .done, phaseT: 1, p: 0, turnGlow: 0,
                         rep: reps - 1, repsDone: reps)
        }
        let clamped = max(elapsed, 0)
        let rep = min(Int(clamped / cycle), reps - 1)
        let t = clamped - Double(rep) * cycle

        let phase: Phase
        let phaseT: Double
        let p: Double
        var timeToTurn: Double

        if t < inhale {
            phase = .inhale
            phaseT = t / inhale
            // Sinusoidal rise: velocity zero at 0 and 1.
            p = 0.5 - 0.5 * cos(.pi * phaseT)
            timeToTurn = inhale - t
        } else if t < inhale + hold {
            phase = .hold
            phaseT = (t - inhale) / max(hold, 0.0001)
            // Stillness with micro-drift — alive, not frozen.
            p = 1.0 + 0.006 * sin(2 * .pi * 0.4 * (t - inhale))
            timeToTurn = (inhale + hold) - t
        } else {
            phase = .exhale
            phaseT = (t - inhale - hold) / exhale
            // Sinusoidal fall — the long emptying.
            p = 0.5 + 0.5 * cos(.pi * phaseT)
            timeToTurn = cycle - t
        }

        // The anticipation glow: a gaussian bump centered 0.3s before
        // the coming turn (skipped after the final exhale — nothing
        // follows, nothing to anticipate).
        let isFinalExhale = phase == .exhale && rep == reps - 1
        let glow: Double
        if isFinalExhale {
            glow = 0
        } else {
            let d = timeToTurn - 0.3
            glow = exp(-(d * d) / (2 * 0.15 * 0.15))
        }

        return State(
            phase: phase,
            phaseT: min(max(phaseT, 0), 1),
            p: min(max(p, 0), 1.01),
            turnGlow: min(max(glow, 0), 1),
            rep: rep,
            repsDone: rep + (phase == .exhale && phaseT >= 1 ? 1 : 0)
        )
    }
}

// MARK: - JKBreathField (the bloom)

struct JKBreathField: View {
    /// nil startDate = the settling state (ambient bloom, no cycles).
    let startDate: Date?
    let inhale: Double
    let hold: Double
    let exhale: Double
    let reps: Int
    // v5 presence pass: the bloom commands the stage (it read as a
    // small washed blob against the full-bleed cream).
    var size: CGFloat = 360

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Petal {
        let angle: Double      // base angle offset (radians)
        let lag: Double        // seconds this petal trails the core
        let radius: CGFloat    // petal glow radius at rest
        let reach: CGFloat     // how far the petal drifts outward
        let rose: Bool         // rose vs blush tint
    }

    private static let petals: [Petal] = (0..<7).map { (k: Int) -> Petal in
        let angle: Double = Double(k) * 2.0 * Double.pi / 7.0
        let lag: Double = Double(k % 4) * 0.09
        let radius: CGFloat = 50.0 + CGFloat((k * 7) % 16)
        let reach: CGFloat = 34.0 + CGFloat((k * 11) % 14)
        return Petal(angle: angle, lag: lag, radius: radius,
                     reach: reach, rose: k % 2 == 0)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion && startDate == nil)) { context in
            Canvas { ctx, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let resolved = resolve(date: context.date)
                drawBloom(ctx: ctx, center: center, state: resolved.state,
                          ambient: resolved.ambient, now: context.date)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func resolve(date: Date) -> (state: BreathClock.State, ambient: Double) {
        if reduceMotion {
            return (BreathClock.State(
                phase: .hold, phaseT: 0.5, p: 0.72,
                turnGlow: 0, rep: 0, repsDone: 0
            ), 0)
        }
        let ambient = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 90) / 90 * 2 * .pi
        if let startDate {
            let state = BreathClock.state(
                elapsed: date.timeIntervalSince(startDate),
                inhale: inhale, hold: hold, exhale: exhale, reps: reps
            )
            return (state, ambient)
        }
        // The settling state: a slow ambient breath at a 6-second
        // wavelength, no counting.
        let t = date.timeIntervalSinceReferenceDate
        let state = BreathClock.State(
            phase: .hold, phaseT: 0.5,
            p: 0.6 + 0.1 * sin(2 * .pi * t / 6),
            turnGlow: 0, rep: 0, repsDone: 0
        )
        return (state, ambient)
    }

    private func drawBloom(
        ctx: GraphicsContext, center: CGPoint,
        state: BreathClock.State, ambient: Double, now: Date
    ) {
        let p = state.p
        let glow = state.turnGlow

        // The outer atmosphere — one wide, faint wash that swells
        // with the breath (reads as warmth, not a ring).
        let atmosphereR = (size * 0.38) * (0.72 + 0.33 * p)
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: center.x - atmosphereR, y: center.y - atmosphereR,
                width: atmosphereR * 2, height: atmosphereR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Palette.accent.opacity(0.19 + 0.05 * glow),
                    Palette.accent.opacity(0),
                ]),
                center: center, startRadius: 0, endRadius: atmosphereR
            )
        )

        // The petals — each trails the core through its own lagged
        // clock, so the bloom gathers and releases like something
        // alive instead of scaling like an image.
        for petal in Self.petals {
            let lagged: Double
            if let startDate, !reduceMotion {
                lagged = BreathClock.state(
                    elapsed: now.timeIntervalSince(startDate) - petal.lag,
                    inhale: inhale, hold: hold, exhale: exhale, reps: reps
                ).p
            } else {
                lagged = p
            }
            let angle = petal.angle + ambient
            let distance = (10 + petal.reach * CGFloat(lagged))
            let petalCenter = CGPoint(
                x: center.x + CGFloat(cos(angle)) * distance,
                y: center.y + CGFloat(sin(angle)) * distance
            )
            let r = petal.radius * (0.62 + 0.5 * CGFloat(lagged))
            let tint = petal.rose ? Palette.accent : Palette.accentSubtle
            let alpha = (petal.rose ? 0.25 : 0.31) + 0.07 * glow

            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: petalCenter.x - r, y: petalCenter.y - r,
                    width: r * 2, height: r * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [tint.opacity(alpha), tint.opacity(0)]),
                    center: petalCenter, startRadius: 0, endRadius: r
                )
            )
        }

        // The core — a cream heart that keeps the bloom's hollow
        // center readable against the petals.
        let coreR = (size * 0.13) * (0.66 + 0.4 * p)
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: center.x - coreR, y: center.y - coreR,
                width: coreR * 2, height: coreR * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.5),
                    Palette.bgPrimary.opacity(0),
                ]),
                center: center, startRadius: 0, endRadius: coreR
            )
        )

        // The still point — one cocoa mark, the eye's anchor.
        let dotR: CGFloat = 3.0
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: center.x - dotR, y: center.y - dotR,
                width: dotR * 2, height: dotR * 2
            )),
            with: .color(Palette.cocoaPrimary.opacity(0.6))
        )
    }
}

// MARK: - JKBreathScene (the breathing stage)

/// The whole breathing moment: the field, the phase words (soft, no
/// clock), the cycle dots (glanceable progress, never a countdown),
/// and the haptic/word driver reading the SAME BreathClock as the
/// pixels. The parent owns intro/receipt phases; this owns the
/// breath itself.
struct JKBreathScene: View {
    let techProtocol: BreathworkProtocol
    let totalReps: Int
    /// Fired once when every breath completes.
    let onComplete: () -> Void

    @State private var startDate: Date? = nil
    @State private var word: String = ""
    @State private var wordVisible = false
    @State private var repsDone = 0
    @State private var completed = false
    /// The 20Hz effects driver (haptics + words). Visuals never read
    /// it — they read the clock directly.
    @State private var driver: Timer? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var inhale: Double { Double(techProtocol.inhaleSec) }
    private var hold: Double { Double(techProtocol.holdSec) }
    private var exhale: Double { Double(techProtocol.exhaleSec) }

    var body: some View {
        VStack(spacing: 20) {
            JKBreathField(
                startDate: startDate,
                inhale: inhale, hold: hold, exhale: exhale,
                reps: totalReps
            )

            // The phase word — a cue, not a clock. Fraunces, soft.
            Text(word)
                .font(.custom("Fraunces72pt-SemiBold", size: 27, relativeTo: .title2))
                .foregroundStyle(Palette.textPrimary)
                .tracking(0.6)
                .opacity(wordVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: wordVisible)
                .animation(.easeInOut(duration: 0.35), value: word)
                .frame(height: 40)

            // The breaths, as dots that fill — progress you can
            // glance, never a number to watch.
            HStack(spacing: 7) {
                ForEach(0..<totalReps, id: \.self) { idx in
                    Circle()
                        .fill(idx < repsDone
                              ? Palette.cocoaSecondary
                              : Palette.cocoaTertiary.opacity(0.25))
                        .frame(width: 6, height: 6)
                        .animation(Motion.entranceSoft, value: repsDone)
                }
            }
            .accessibilityLabel(
                repsDone == 1 ? "one breath done" : "\(repsDone) breaths done"
            )
        }
        .onAppear { begin() }
        .onDisappear { end() }
    }

    // MARK: - The driver

    private func begin() {
        guard startDate == nil else { return }
        let start = Date()
        startDate = start

        if reduceMotion {
            // The visual holds still; words + haptics still guide,
            // and the session completes on schedule.
            word = "breathe with her"
            wordVisible = true
        }

        var lastPhase: BreathClock.Phase? = nil
        driver = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let state = BreathClock.state(
                elapsed: Date().timeIntervalSince(start),
                inhale: inhale, hold: hold, exhale: exhale, reps: totalReps
            )
            if state.repsDone != repsDone {
                repsDone = min(state.repsDone, totalReps)
            }
            guard state.phase != lastPhase else { return }
            lastPhase = state.phase
            switch state.phase {
            case .inhale:
                setWord("breathe in")
                BreathHaptics.shared.playInhale(duration: inhale)
            case .hold:
                setWord(holdWord)
                BreathHaptics.shared.holdSilence()
            case .exhale:
                setWord("let it go")
                BreathHaptics.shared.playExhale(
                    duration: exhale,
                    anotherFollows: state.rep < totalReps - 1
                )
            case .done:
                finish()
            }
        }
    }

    private var holdWord: String {
        hold > 0 ? "hold, softly" : ""
    }

    private func setWord(_ new: String) {
        guard !reduceMotion else { return }
        guard !new.isEmpty else { return }
        word = new
        wordVisible = true
    }

    private func finish() {
        guard !completed else { return }
        completed = true
        end()
        onComplete()
    }

    private func end() {
        driver?.invalidate()
        driver = nil
        BreathHaptics.shared.stop()
    }
}

#if DEBUG
#Preview("cycling 4-0-6 ×3") {
    ZStack {
        Palette.bgPrimary.ignoresSafeArea()
        JKBreathScene(techProtocol: .calming, totalReps: 3, onComplete: {})
    }
}

#Preview("settling") {
    ZStack {
        Palette.bgPrimary.ignoresSafeArea()
        JKBreathField(startDate: nil, inhale: 4, hold: 0, exhale: 6, reps: 1)
    }
}
#endif
