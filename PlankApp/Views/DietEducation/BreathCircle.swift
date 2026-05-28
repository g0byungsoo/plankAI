import SwiftUI

/// Animated breath visual for the JeniMethod ritual flow.
///
/// Phase 9.6 — painterly bloom redesign:
/// - The visual is the **breath_bloom** asset (a hand-painted iridescent
///   torus, cream/rose/blue, with a soft hollow center). Scales with
///   breath, gently rotates for life, soft outer glow.
/// - **Continuous haptic** during inhale + exhale (Timer-based soft
///   pulses every ~0.55s during inhale, ~0.75s during exhale) plus a
///   `.medium()` punctuation at the apex of inhale and the bottom of
///   exhale. Matches the Apple Watch Breathe pattern — you can *feel*
///   the breath rhythm, not just see it.
/// - Italic-Fraunces **"inhale" / "exhale"** label below the bloom that
///   swaps with the breath phase. Visible only during cycling.
///
/// Reduce-motion: snaps to a static medium-size bloom, no animation,
/// no haptic timer, no phase text. Single completion callback fires
/// immediately so the auto-pacing ritual view can advance.
struct BreathCircle: View {
    enum State: Equatable {
        case idle
        case holding(scale: CGFloat)
        case cycling(inhale: Int, exhale: Int, repeats: Int)
    }

    enum Phase: Equatable {
        case idle, inhale, exhale
        var displayWord: String {
            switch self {
            case .idle:   return ""
            case .inhale: return "inhale"
            case .exhale: return "exhale"
            }
        }
    }

    let state: State
    var onCycleComplete: (() -> Void)? = nil
    /// Phase A.0 — customizable phase words so the breathwork session can
    /// use mindful cues ("breathe in" / "let it go") while the JeniMethod
    /// ritual keeps the default clinical "inhale" / "exhale". Defaults
    /// preserve existing ritual behavior.
    var inhaleWord: String = "inhale"
    var exhaleWord: String = "exhale"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.State private var animatedScale: CGFloat = 0.45
    @SwiftUI.State private var ambientRotation: Double = 0
    @SwiftUI.State private var phase: Phase = .idle
    @SwiftUI.State private var pulseTimer: Timer? = nil
    /// Monotonic counter — bumped on every state change, onDisappear,
    /// and natural cycle completion. Each `runCycle` call captures its
    /// generation; `asyncAfter` callbacks bail if the current
    /// generation has moved on. Without this, a pending callback can
    /// fire AFTER the user leaves the breath beat (or dismisses the
    /// ritual entirely) and re-arm `startPulses`, orphaning a haptic
    /// timer that nothing knows to stop — that's the "haptic never
    /// ends after the session" bug.
    @SwiftUI.State private var cycleGeneration: Int = 0
    // Phase 9.16 — countdown driver. `countdownSeconds` ticks 1Hz down
    // to 1 during each inhale/exhale; rendered as the big Fraunces
    // 88pt number below the bloom. Cancelled by the generation guard
    // alongside the pulse timer.
    @SwiftUI.State private var countdownSeconds: Int = 0
    @SwiftUI.State private var countdownTimer: Timer? = nil

    /// Phase 9.7 — bigger bloom (320pt vs 240pt) so the breath visual
    /// is dominant on screen. Combined with the more dramatic scale
    /// range below (0.45 ↔ 1.05) the contraction reads as a clear
    /// settle and the expansion as a clear bloom.
    private let baseSize: CGFloat = 320

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                // Soft outer glow — pulses with the bloom so the breath
                // feels visually warmer at the apex.
                Circle()
                    .fill(Palette.accent.opacity(0.22))
                    .frame(width: baseSize, height: baseSize)
                    .blur(radius: 36)
                    .scaleEffect(animatedScale * 1.08)

                // The painted bloom asset — the actual breath visual.
                // Subtle ambient rotation (~±3°) gives it life even when
                // the scale is holding; gentler than the breath itself.
                Image("breath_bloom")
                    .resizable()
                    .scaledToFit()
                    .frame(width: baseSize, height: baseSize)
                    .rotationEffect(.degrees(ambientRotation))
                    .scaleEffect(animatedScale)
                    .shadow(color: Palette.accent.opacity(0.18), radius: 14, x: 0, y: 6)

                // Phase 9.17 — countdown sits INSIDE the bloom's hollow
                // center. Small Fraunces, accent pink #C4677A. Fixed
                // size (not scale-tracked with the bloom) so it stays
                // legible across the breath cycle. The painted torus
                // has a soft hollow center that frames it naturally.
                Text(countdownDisplay)
                    .font(.custom("Fraunces72pt-SemiBold", size: 32))
                    .foregroundStyle(Color(hex: "#C4677A"))
                    .monospacedDigit()
                    .opacity(phaseTextOpacity)
            }
            .opacity(bloomOpacity)

            // Phase 9.17 — inhale/exhale label below the bloom, BIG
            // Fraunces serif cocoa #3D2A2A. This is the dominant
            // typographic cue; the countdown inside the bloom is the
            // quiet timing indicator.
            Text(currentPhaseWord)
                .font(.custom("Fraunces72pt-SemiBold", size: 44))
                .foregroundStyle(Color(hex: "#3D2A2A"))
                .tracking(1)
                .textCase(.lowercase)
                .opacity(phaseTextOpacity)
                .frame(height: 60)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            startAmbientRotation()
            applyState()
        }
        .onChange(of: state) { _, _ in applyState() }
        .onDisappear {
            // Bump first so any pending asyncAfter callbacks bail
            // before they re-arm the pulse timer.
            cycleGeneration &+= 1
            stopPulses()
            stopCountdown()
        }
    }

    private var bloomOpacity: Double {
        switch state {
        case .idle: return 0
        case .holding, .cycling: return 1
        }
    }

    private var phaseTextOpacity: Double {
        if case .cycling = state, phase != .idle { return 1 }
        return 0
    }

    /// Phase word honoring the customizable `inhaleWord` / `exhaleWord`.
    /// Falls back to empty on idle so the reserved frame stays stable.
    private var currentPhaseWord: String {
        switch phase {
        case .idle:   return ""
        case .inhale: return inhaleWord
        case .exhale: return exhaleWord
        }
    }

    /// Render the countdown as a plain integer string. Falls back to
    /// an empty string when we're not in a phase so the 100pt frame
    /// stays reserved without showing a stale "0".
    private var countdownDisplay: String {
        countdownSeconds > 0 ? "\(countdownSeconds)" : ""
    }

    /// Slow ambient sway. Runs forever; gives the bloom subtle life even
    /// during line/illustration beats where the breath is "holding."
    /// Skipped under reduce-motion.
    private func startAmbientRotation() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            ambientRotation = 4
        }
    }

    private func applyState() {
        // Bump generation FIRST so any in-flight asyncAfter callbacks
        // from the previous state see they're stale and bail. Then
        // stop the timer for the current run.
        cycleGeneration &+= 1
        stopPulses()
        stopCountdown()
        phase = .idle
        switch state {
        case .idle:
            withAnimation(.easeOut(duration: 0.4)) { animatedScale = 0 }
        case .holding(let scale):
            withAnimation(.easeInOut(duration: 0.6)) { animatedScale = scale }
        case .cycling(let inhale, let exhale, let repeats):
            startCycle(inhale: inhale, exhale: exhale, repeats: repeats)
        }
    }

    private func startCycle(inhale: Int, exhale: Int, repeats: Int) {
        if reduceMotion {
            animatedScale = 0.78
            phase = .idle
            onCycleComplete?()
            return
        }

        animatedScale = 0.45
        phase = .idle
        runCycle(
            generation: cycleGeneration,
            currentRep: 0,
            totalReps: repeats,
            inhale: inhale,
            exhale: exhale
        )
    }

    /// Recursive cycle driver. `generation` is the value of
    /// `cycleGeneration` at the moment this chain was scheduled; every
    /// re-entry checks it. If `applyState` or `onDisappear` has bumped
    /// the counter in the meantime, this chain stops dead — no more
    /// `startPulses`, no orphaned timers.
    private func runCycle(generation: Int, currentRep: Int, totalReps: Int, inhale: Int, exhale: Int) {
        guard generation == cycleGeneration else { return }
        guard currentRep < totalReps else {
            stopPulses()
            stopCountdown()
            phase = .idle
            onCycleComplete?()
            return
        }
        let inhaleSec = Double(inhale)
        let exhaleSec = Double(exhale)

        // ─── Inhale ─────────────────────────────────────────────────
        // Visual: scale 0.55 → 1.0 over inhaleSec with easeInOut.
        // Phase text: "inhale".
        // Haptic: continuous .soft() pulses every 0.55s through the
        // inhale (~7 pulses over 4 sec). Apple Watch Breathe pattern.
        // Countdown: starts at inhale, ticks down once per second.
        withAnimation(.easeOut(duration: 0.25)) { phase = .inhale }
        withAnimation(.easeInOut(duration: inhaleSec)) {
            animatedScale = 1.05  // bloom slightly past full for drama
        }
        startPulses(intervalSeconds: 0.55)
        startCountdown(seconds: inhale, generation: generation)
        DispatchQueue.main.asyncAfter(deadline: .now() + inhaleSec) {
            // Stale-chain guard. If the user has navigated off this
            // beat or dismissed the ritual, bail without re-arming
            // the next pulse train.
            guard generation == cycleGeneration else {
                stopPulses()
                stopCountdown()
                return
            }
            stopPulses()
            Haptics.medium()  // apex punctuation — clearly felt with the inhale completion

            // ─── Exhale ─────────────────────────────────────────────
            // Visual: scale 1.0 → 0.55 over exhaleSec.
            // Phase text: "exhale".
            // Haptic: continuous .soft() pulses, slightly slower
            // (0.75s) — feels like a longer release.
            // Countdown: restarts at exhale, ticks down once per sec.
            withAnimation(.easeOut(duration: 0.25)) { phase = .exhale }
            withAnimation(.easeInOut(duration: exhaleSec)) {
                animatedScale = 0.45
            }
            startPulses(intervalSeconds: 0.75)
            startCountdown(seconds: exhale, generation: generation)
            DispatchQueue.main.asyncAfter(deadline: .now() + exhaleSec) {
                guard generation == cycleGeneration else {
                    stopPulses()
                    stopCountdown()
                    return
                }
                stopPulses()
                Haptics.medium()  // bottom punctuation — settle
                runCycle(
                    generation: generation,
                    currentRep: currentRep + 1,
                    totalReps: totalReps,
                    inhale: inhale,
                    exhale: exhale
                )
            }
        }
    }

    // MARK: - Continuous-pulse haptic timer

    private func startPulses(intervalSeconds: TimeInterval) {
        pulseTimer?.invalidate()
        guard !reduceMotion else { return }
        // First pulse on the next runloop tick so it doesn't double up
        // with the phase-transition punctuation.
        pulseTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { _ in
            Haptics.soft()
        }
    }

    private func stopPulses() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }

    // MARK: - Countdown timer (Phase 9.16)
    //
    // Drives the big Fraunces 88pt number under the bloom. Starts at
    // `seconds` and ticks down to 1 once per second. Holds at 1 until
    // the parent phase boundary fires (the asyncAfter chain), so the
    // display never flashes "0" mid-phase. Generation-guarded so a
    // stale Timer can't keep updating @State after the user navigates
    // away from the breath beat.
    private func startCountdown(seconds: Int, generation: Int) {
        countdownTimer?.invalidate()
        countdownSeconds = seconds
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard generation == cycleGeneration else {
                timer.invalidate()
                return
            }
            if countdownSeconds > 1 {
                countdownSeconds -= 1
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSeconds = 0
    }
}

#if DEBUG
#Preview("Cycling 4 in, 6 out, x3") {
    ZStack {
        Palette.bgPrimary.ignoresSafeArea()
        BreathCircle(state: .cycling(inhale: 4, exhale: 6, repeats: 3))
    }
}

#Preview("Holding") {
    ZStack {
        Palette.bgPrimary.ignoresSafeArea()
        BreathCircle(state: .holding(scale: 0.7))
    }
}
#endif
