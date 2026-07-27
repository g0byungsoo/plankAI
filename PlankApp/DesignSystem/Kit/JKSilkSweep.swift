import SwiftUI

// MARK: - JKSilkSweep
//
// The one-shot day-complete sheen (jkSilk shader). Attach to a
// container; bump `trigger` to play. The light takes 1.15s to cross
// with an easeOut so it decelerates as it exits; a success haptic
// marks the crest. Reduce-motion: no sweep (the strike-throughs +
// haptic already told the story).

struct JKSilkSweep: ViewModifier {
    let trigger: Int

    @State private var progress: Float = -0.35
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // visualEffect supplies the layer's real geometry so the
            // shader's diagonal is normalized to the view, not pixels.
            // State is read directly (no capture list) so the effect
            // closure re-evaluates with live values on every frame of
            // the drive loop.
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
                // v7 (docs/app_v7 §7): the visual modifier never owns
                // feel — call sites own meaning. The stock success()
                // here was double-firing over the crafted arcComplete
                // swell at t=0 and masking it.
                // Explicit frame loop: SwiftUI's implicit animation
                // doesn't tween raw state captured in visualEffect;
                // ~60fps steps over 1.15s with cubic ease-out.
                Task { @MainActor in
                    let duration: TimeInterval = 1.15
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
    /// One-shot silk sheen across this view whenever `trigger`
    /// increments. Use for the day's completion moment.
    func jkSilkSweep(trigger: Int) -> some View {
        modifier(JKSilkSweep(trigger: trigger))
    }
}
