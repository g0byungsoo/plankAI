import CoreHaptics
import UIKit

// MARK: - BreathHaptics (app v4, docs/app_v4/03_FEATURES.md §6)
//
// The breath's felt channel: CONTINUOUS CoreHaptics envelopes that
// ride the same sinusoidal curve as the visual bloom — a swell that
// gathers through the inhale, a long decay that empties with the
// exhale, silence through the hold (stillness IS the cue), and a
// soft "ghost" transient ~0.3s before each turn so the body knows
// the turn is coming before it arrives (the anticipation principle;
// docs/app_v4/research/BREATHWORK_BAR.md — no major breath app
// ships a continuous curve; the old Timer-based discrete taps were
// the single clearest "meditation-app default" tell).
//
// Safety mirrors ActivationHaptics: lazy engine, every call wrapped,
// UIKit soft-pulse fallback on unsupported hardware (the old
// pattern, so nothing regresses below the previous floor).

final class BreathHaptics {
    static let shared = BreathHaptics()

    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool
    private var activePlayer: CHHapticAdvancedPatternPlayer?
    private var fallbackTimer: Timer?
    private let softFallback = UIImpactFeedbackGenerator(style: .soft)

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    // MARK: - Phase envelopes

    /// The inhale: a gathering swell — intensity 0.18 → 0.62 along a
    /// sinusoidal-feeling ramp, sharpness easing up slightly, and the
    /// pre-turn ghost so the apex never surprises. Call at the start
    /// of each inhale with its duration.
    func playInhale(duration: TimeInterval) {
        guard duration > 0.5 else { return }
        let ghostAt = max(duration - 0.3, duration * 0.7)
        let played = play(
            events: [
                continuousEvent(duration: duration, intensity: 0.62, sharpness: 0.3),
                transient(time: ghostAt, intensity: 0.3, sharpness: 0.45),
            ],
            curves: [
                curve(.hapticIntensityControl, [
                    (0.0, 0.18), (duration * 0.55, 0.72), (duration, 1.0),
                ]),
                curve(.hapticSharpnessControl, [
                    (0.0, 0.35), (duration, 0.55),
                ]),
            ]
        )
        if !played { startFallbackPulses(interval: 0.55) }
    }

    /// The exhale: the long emptying — intensity starts near the
    /// apex and decays to almost nothing over the whole exhale, the
    /// felt permission to let go. Ghost before the bottom turn only
    /// when another breath follows.
    func playExhale(duration: TimeInterval, anotherFollows: Bool) {
        guard duration > 0.5 else { return }
        var events = [
            continuousEvent(duration: duration, intensity: 0.55, sharpness: 0.22),
        ]
        if anotherFollows {
            events.append(transient(
                time: max(duration - 0.3, duration * 0.7),
                intensity: 0.22, sharpness: 0.4
            ))
        }
        let played = play(
            events: events,
            curves: [
                curve(.hapticIntensityControl, [
                    (0.0, 1.0), (duration * 0.4, 0.5), (duration, 0.06),
                ]),
                curve(.hapticSharpnessControl, [
                    (0.0, 0.4), (duration, 0.12),
                ]),
            ]
        )
        if !played { startFallbackPulses(interval: 0.75) }
    }

    /// The hold is SILENT by design — call this to guarantee the
    /// silence (stops any running envelope; stillness is the cue).
    func holdSilence() {
        stopActive()
    }

    /// The session's end — everything off.
    func stop() {
        stopActive()
    }

    // MARK: - Engine plumbing

    private func stopActive() {
        try? activePlayer?.stop(atTime: CHHapticTimeImmediate)
        activePlayer = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    private func prepare() {
        guard supportsHaptics else {
            softFallback.prepare()
            return
        }
        if engine == nil {
            engine = try? CHHapticEngine()
            engine?.stoppedHandler = { [weak self] _ in self?.engine = nil }
            engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        }
        try? engine?.start()
    }

    private func play(events: [CHHapticEvent], curves: [CHHapticParameterCurve]) -> Bool {
        guard supportsHaptics else { return false }
        prepare()
        guard let engine else { return false }
        stopActive()
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            activePlayer = player
            return true
        } catch {
            #if DEBUG
            print("[BreathHaptics] play failed: \(error)")
            #endif
            return false
        }
    }

    /// The old discrete-pulse floor for hardware without CoreHaptics —
    /// the previous session's whole vocabulary, now the fallback only.
    private func startFallbackPulses(interval: TimeInterval) {
        fallbackTimer?.invalidate()
        softFallback.prepare()
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.softFallback.impactOccurred(intensity: 0.6)
        }
    }

    // MARK: - Builders

    private func transient(time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private func continuousEvent(
        duration: TimeInterval, intensity: Float, sharpness: Float
    ) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: duration
        )
    }

    private func curve(
        _ id: CHHapticDynamicParameter.ID, _ points: [(TimeInterval, Float)]
    ) -> CHHapticParameterCurve {
        CHHapticParameterCurve(
            parameterID: id,
            controlPoints: points.map {
                CHHapticParameterCurve.ControlPoint(relativeTime: $0.0, value: $0.1)
            },
            relativeTime: 0
        )
    }
}
