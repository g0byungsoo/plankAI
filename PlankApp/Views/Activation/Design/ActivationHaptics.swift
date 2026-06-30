import CoreHaptics
import UIKit

// MARK: - ActivationHaptics
//
// A CoreHaptics-backed delight engine for the activation screens. Unlike
// the project's `Haptics` enum (UIKit feedback generators), this composes
// custom transient + continuous events with intensity envelopes so the
// "commit", "cross-off", and "arc complete" beats feel bespoke, not
// stock iOS.
//
// Safety: the `CHHapticEngine` is created lazily and every play call is
// wrapped so an unsupported device, a denied capability, or an engine
// error degrades gracefully. On hardware without CoreHaptics support it
// falls back to the closest UIKit generator (still better than silence).
// Nothing here can crash the caller.
//
// Usage:
//
//   ActivationHaptics.shared.commit()
//   ActivationHaptics.shared.crossOff()
//
// All methods are main-actor-free and cheap to call from gesture
// handlers / animation completion blocks.
final class ActivationHaptics {
    static let shared = ActivationHaptics()

    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool

    // UIKit fallbacks for unsupported hardware.
    private let lightFallback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFallback = UIImpactFeedbackGenerator(style: .medium)
    private let rigidFallback = UIImpactFeedbackGenerator(style: .rigid)

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        prepare()
    }

    // MARK: Named patterns

    /// Firm, satisfying confirm: a strong transient with a brief
    /// continuous tail that decays away. The "this counts" beat (commit
    /// a promise, confirm a choice).
    func commit() {
        let played = playEngine(
            events: [
                transient(time: 0, intensity: 1.0, sharpness: 0.7),
                continuous(time: 0.02, duration: 0.16, intensity: 0.45, sharpness: 0.35)
            ],
            parameterCurves: [
                intensityCurve(points: [(0.02, 0.45), (0.18, 0.0)])
            ]
        )
        if !played { mediumFallback.impactOccurred(intensity: 1.0) }
    }

    /// Light, crisp tick: a single low-intensity high-sharpness
    /// transient. For incremental marks (a tick filling, a step counted).
    func tick() {
        guard playEngine(events: [
            transient(time: 0, intensity: 0.45, sharpness: 0.85)
        ]) else {
            lightFallback.impactOccurred(intensity: 0.6)
            return
        }
    }

    /// A two-event "kept" flourish: a soft lead-in transient then a
    /// firmer landing a beat later, like drawing a line through a
    /// completed item.
    func crossOff() {
        guard playEngine(events: [
            transient(time: 0, intensity: 0.55, sharpness: 0.4),
            transient(time: 0.11, intensity: 0.95, sharpness: 0.7)
        ]) else {
            lightFallback.impactOccurred(intensity: 0.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { [weak self] in
                self?.mediumFallback.impactOccurred(intensity: 0.9)
            }
            return
        }
    }

    /// A soft swell: a continuous event whose intensity ramps up then
    /// settles, matching the arc sparkline arriving. The gentlest of the
    /// set; reads as a breath rather than a tap.
    func arcComplete() {
        let played = playEngine(
            events: [
                continuous(time: 0, duration: 0.5, intensity: 0.6, sharpness: 0.2)
            ],
            parameterCurves: [
                intensityCurve(points: [(0.0, 0.0), (0.18, 1.0), (0.5, 0.0)])
            ]
        )
        if !played { lightFallback.impactOccurred(intensity: 0.5) }
    }

    /// Mimics the feel of an iOS notification arriving: a soft lead-in
    /// tap, a slightly firmer landing a beat later, and a short continuous
    /// tail so it reads as a gentle "buzz" rather than a single click. Used
    /// on the onboarding nudge-preview so she feels jeni's nudge before
    /// granting notification permission. Falls back to the system
    /// notification-success haptic on hardware without CoreHaptics.
    func notificationBuzz() {
        let played = playEngine(
            events: [
                transient(time: 0, intensity: 0.55, sharpness: 0.5),
                transient(time: 0.10, intensity: 1.0, sharpness: 0.6),
                continuous(time: 0.12, duration: 0.16, intensity: 0.45, sharpness: 0.3)
            ],
            parameterCurves: [
                intensityCurve(points: [(0.12, 0.45), (0.28, 0.0)])
            ]
        )
        if !played { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }

    /// Build a rising-intensity continuous "building pressure" ramp for a
    /// press-and-hold gesture (the hold-to-promise seal). Returns an opaque
    /// handle the caller can `.stop()` the instant she releases early, so
    /// the buzz dies with the gesture. Both intensity AND sharpness climb
    /// across the hold so it reads as tension accumulating toward the seal,
    /// not a flat drone. Returns nil if CoreHaptics is unsupported - the
    /// caller still gets the `commit()` payoff on seal, just no ramp.
    func makeHoldRamp(duration: TimeInterval) -> HoldHapticHandle? {
        guard supportsHaptics else { return nil }
        prepare()
        guard let engine else { return nil }
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
                duration: duration
            )
            // Intensity climbs from a soft floor to full as the ring fills;
            // the last stretch ramps fastest so the approach to 100% feels
            // like it's gathering toward the seal.
            let intensityCurve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.16),
                    .init(relativeTime: duration * 0.65, value: 0.62),
                    .init(relativeTime: duration, value: 1.0)
                ],
                relativeTime: 0
            )
            // Sharpness rises too: a soft hum at the start sharpens to a
            // crisp edge as the seal nears.
            let sharpnessCurve = CHHapticParameterCurve(
                parameterID: .hapticSharpnessControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 0.2),
                    .init(relativeTime: duration, value: 0.75)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(
                events: [event],
                parameterCurves: [intensityCurve, sharpnessCurve]
            )
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return HoldHapticHandle(player: player)
        } catch {
            #if DEBUG
            print("[ActivationHaptics] hold ramp failed: \(error)")
            #endif
            return nil
        }
    }

    /// Light, playful landing: a small transient plus a tiny bounce, for
    /// a sticker settling into place.
    func stickerSettle() {
        guard playEngine(events: [
            transient(time: 0, intensity: 0.7, sharpness: 0.5),
            transient(time: 0.07, intensity: 0.3, sharpness: 0.6)
        ]) else {
            lightFallback.impactOccurred(intensity: 0.7)
            return
        }
    }

    // MARK: Engine lifecycle

    /// Warm the generators + start the engine. Safe to call repeatedly;
    /// callers may invoke this on screen-appear to remove first-play
    /// latency. No-op (beyond prepping UIKit fallbacks) if unsupported.
    func prepare() {
        lightFallback.prepare()
        mediumFallback.prepare()
        rigidFallback.prepare()
        guard supportsHaptics else { return }
        if engine == nil {
            engine = try? CHHapticEngine()
            // Recreate / restart on system-driven stops + resets so a
            // backgrounded engine doesn't silently stay dead.
            engine?.stoppedHandler = { [weak self] _ in
                self?.engine = nil
            }
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
        }
        try? engine?.start()
    }

    // MARK: Event builders

    private func transient(time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time
        )
    }

    private func continuous(
        time: TimeInterval,
        duration: TimeInterval,
        intensity: Float,
        sharpness: Float
    ) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time,
            duration: duration
        )
    }

    /// Intensity-control envelope for a continuous event. `points` are
    /// (relativeTime, value) pairs in pattern time; the engine multiplies
    /// the event's base intensity by this curve so the swell rises +
    /// settles smoothly.
    private func intensityCurve(points: [(TimeInterval, Float)]) -> CHHapticParameterCurve {
        CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: points.map {
                CHHapticParameterCurve.ControlPoint(relativeTime: $0.0, value: $0.1)
            },
            relativeTime: 0
        )
    }

    /// Build + play a pattern. Returns false if CoreHaptics is
    /// unsupported or anything throws, so callers can fall back. Never
    /// throws to the caller.
    private func playEngine(events: [CHHapticEvent], parameterCurves: [CHHapticParameterCurve] = []) -> Bool {
        guard supportsHaptics else { return false }
        prepare()
        guard let engine else { return false }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: parameterCurves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            #if DEBUG
            print("[ActivationHaptics] play failed: \(error)")
            #endif
            return false
        }
    }
}

// MARK: - HoldHapticHandle
//
// Opaque handle around a running CoreHaptics advanced player for the
// hold-to-promise ramp. The hold gesture starts the ramp on press-down
// and must `stop()` it the instant she releases early (or the moment the
// seal fires) so the buzz never outlives the gesture. Safe to call
// `stop()` more than once - a second stop on an already-finished player
// is swallowed.
struct HoldHapticHandle {
    fileprivate let player: CHHapticAdvancedPatternPlayer

    func stop() {
        try? player.stop(atTime: CHHapticTimeImmediate)
    }
}
