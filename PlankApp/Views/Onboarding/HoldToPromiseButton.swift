import SwiftUI

// MARK: - HoldToPromiseButton (2026-06-30)
//
// The commitment ritual's seal. Replaces the passive "continue" tap at
// the close of CommitmentRitualPresentation with an EFFORTFUL press-and-
// hold: she physically holds her finger down while a dusty-rose arc
// traces around the cocoa pill and a CoreHaptics ramp builds under her
// fingertip. At 100% the pill seals - a firm commit haptic, an accent
// bloom, the label turns to "promised ♥" - then it advances. Release
// early and it springs back to zero with a soft tick; nothing commits.
// The hold is the point: a promise you have to MEAN costs a second of
// intention, not a reflex tap.
//
// her75 register: cocoa pill, DM Sans label (CTAs stay functional; the
// headline carries voice). The accent only appears as the tracing arc +
// seal bloom - a celebration signal earned by the hold, not decoration.
//
// Accessibility: when Reduce Motion OR VoiceOver is on, it renders as an
// ordinary solid cocoa TAP button ("seal your promise") - no ring, no
// hold, no timing barrier - and still fires a confirmation haptic before
// advancing. An `accessibilityAction` covers the hold variant too, so a
// VoiceOver double-tap always seals.
//
// Only the 8 locked tokens + bgPrimary. No red. Heart terminal-only.

struct HoldToPromiseButton: View {
    /// Label for the hold variant (e.g. "hold to promise").
    let label: String
    /// Fired once - after a full hold seals, or on tap in the fallback.
    let onSeal: () -> Void

    /// How long she must hold for the ring to fill + seal.
    var holdDuration: Double = 1.1

    /// DEBUG-only: auto-begin the hold shortly after appear so a CLI
    /// screenshot can capture the filled/sealed state (which a static
    /// screenshot can't otherwise reach). Never set in production.
    var autoHoldForDebug: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    // Ring fill 0...1 (also drives interior cocoa deepening + label cross-fade).
    @State private var progress: CGFloat = 0
    // True while her finger is down mid-hold (drives the press-deepen scale).
    @State private var isPressing = false
    // Latches once sealed so a release / re-press can't double-fire.
    @State private var isSealed = false
    // Seal flourish state: the accent bloom ring + "promised ♥" swap.
    @State private var bloomActive = false
    // Bloom ring: expands + fades once at seal (separate so it can travel
    // from a visible value down to 0, which a single bool can't express).
    @State private var bloomScale: CGFloat = 1
    @State private var bloomOpacity: Double = 0

    // Running CoreHaptics ramp; stopped on early release or at seal.
    @State private var ramp: HoldHapticHandle?
    // Cancellable seal trigger so an early release aborts the commit.
    @State private var sealWork: DispatchWorkItem?

    private var useTapFallback: Bool { reduceMotion || voiceOver }

    var body: some View {
        Group {
            if useTapFallback {
                tapFallbackButton
            } else {
                holdButton
            }
        }
        // Single actionable element for VoiceOver regardless of variant.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("seal your promise"))
        .accessibilityHint(Text("double tap to seal your promise"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { fireSeal() }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, 24)
        .onAppear {
            guard autoHoldForDebug, !useTapFallback else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { beginHold() }
        }
    }

    // MARK: Hold variant

    private var holdButton: some View {
        ZStack {
            // Interior fill: a cocoa ghost at rest that deepens to solid as
            // the ring fills, so the pill visibly "fills with intention".
            Capsule()
                .fill(Palette.cocoaPrimary.opacity(0.10 + 0.90 * Double(progress)))

            // Resting track: a hairline cocoa outline, always present, that
            // the accent arc draws over.
            Capsule()
                .stroke(Palette.cocoaPrimary.opacity(0.24), lineWidth: 1.5)

            // The tracing arc: dusty-rose, draws around the pill perimeter
            // from 0 to `progress`. The signal that the seal is being drawn.
            Capsule()
                .trim(from: 0, to: progress)
                .stroke(
                    Palette.accent,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )

            // Seal bloom: an accent ring that expands + fades once at seal.
            Capsule()
                .stroke(Palette.accent, lineWidth: 2)
                .scaleEffect(bloomScale)
                .opacity(bloomOpacity)

            // Label cross-fade. Resting cocoa label fades out as the fill
            // deepens; the cream label fades in. On seal it reads "promised ♥".
            ZStack {
                Text(label)
                    .foregroundStyle(Palette.cocoaPrimary)
                    .opacity(max(0, 1 - Double(progress) * 1.6))
                // U+FE0E forces the heart to TEXT (monochrome) presentation
                // so it inherits the cream label color instead of rendering
                // as a red emoji glyph (no-red constraint).
                Text(bloomActive ? "promised ♥\u{FE0E}" : label)
                    .foregroundStyle(Palette.textInverse)
                    .opacity(min(1, Double(progress) * 1.4))
            }
            .font(.custom("DMSans-SemiBold", size: 16))
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .clipShape(Capsule())
        .scaleEffect(sealScale)
        .shadow(
            color: Palette.cocoaPrimary.opacity(0.18 * Double(progress)),
            radius: 12 * progress, x: 0, y: 5 * progress
        )
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginHold() }
                .onEnded { _ in releaseHold() }
        )
    }

    // Press-deepen + seal-bloom scale, composed: deepen to 0.97 while held,
    // a brief 1.04 pop at seal, settling to 1.0.
    private var sealScale: CGFloat {
        if bloomActive { return 1.04 }
        return isPressing ? 0.97 : 1.0
    }

    // MARK: Tap fallback (Reduce Motion / VoiceOver)

    private var tapFallbackButton: some View {
        Button(action: fireSeal) {
            Text("seal your promise")
                .font(.custom("DMSans-SemiBold", size: 16))
                .foregroundStyle(Palette.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Palette.cocoaPrimary)
                .clipShape(Capsule())
                .shadow(color: Palette.cocoaPrimary.opacity(0.18), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: Gesture logic

    private func beginHold() {
        // First touch of a fresh press only; ignore the drag's repeated
        // onChanged ticks and any input after a seal has latched.
        guard !isPressing, !isSealed else { return }
        isPressing = true

        // Building haptic ramp under the fingertip (nil-safe on old hardware).
        ramp = ActivationHaptics.shared.makeHoldRamp(duration: holdDuration)

        // Drive the ring fill linearly across the hold window.
        withAnimation(.linear(duration: holdDuration)) {
            progress = 1
        }

        // Seal fires from a cancellable timer, not the animation completion,
        // so an early release can reliably abort it.
        let work = DispatchWorkItem { seal() }
        sealWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: work)
    }

    private func releaseHold() {
        // A release after the seal latched is a no-op (finger lifting off the
        // sealed pill); only an EARLY release springs back + cancels.
        guard !isSealed else { return }
        guard isPressing else { return }
        isPressing = false

        sealWork?.cancel(); sealWork = nil
        ramp?.stop(); ramp = nil

        // Gentle "let go" tick + spring the ring back to empty.
        ActivationHaptics.shared.tick()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
            progress = 0
        }
    }

    private func seal() {
        guard !isSealed else { return }
        isSealed = true
        isPressing = false
        sealWork = nil

        // The ramp has run its course; stop defensively + release the handle.
        ramp?.stop(); ramp = nil

        // The "this counts" payoff - firm transient with a decaying tail.
        ActivationHaptics.shared.commit()

        // Lock the ring full + bloom: accent ring expands/fades, the pill
        // pops, the label turns to "promised ♥".
        withAnimation(.easeOut(duration: 0.2)) { progress = 1 }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bloomActive = true }
        // Bloom ring: snap to a visible radius, then expand + fade out.
        bloomScale = 1; bloomOpacity = 0.55
        withAnimation(.easeOut(duration: 0.5)) {
            bloomScale = 1.25
            bloomOpacity = 0
        }

        // Let the seal land before advancing the flow.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            onSeal()
        }
    }

    // Shared seal path for the tap fallback + VoiceOver action: a single
    // confirmation haptic, then advance. No ring, no hold timing.
    private func fireSeal() {
        guard !isSealed else { return }
        isSealed = true
        ActivationHaptics.shared.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            onSeal()
        }
    }
}

#Preview("hold") {
    VStack {
        Spacer()
        HoldToPromiseButton(label: "hold to promise", onSeal: {})
    }
    .background(Palette.bgPrimary)
}
