import SwiftUI

// MARK: - JFContinueButton
//
// v3 P11.6 (2026-06-10) — single source of truth for the primary
// CTA across onboarding + post-reveal screens. Founder QA mid-stream
// flagged button inconsistency: some screens shipped 52pt
// italic-Fraunces capsules; others used jfQuestion's existing 56pt
// DM Sans SemiBold. her75 reference (every IMG_6275-6282 button)
// is upright sans-serif white-on-cocoa pill — NOT italic-Fraunces.
// This component locks the her75 register.
//
// Use everywhere the user is about to advance one onboarding step.
// Disabled state, loading state, and an optional secondary "skip"
// link sit alongside so screens that previously hand-rolled all
// three can collapse to one component.
//
// Usage:
//   JFContinueButton(label: "continue", action: { advance() })
//
// With disabled-until-condition:
//   JFContinueButton(label: "i agree",
//                    isEnabled: consentChecked,
//                    action: handleAgree)
//
// With a "skip" secondary affordance:
//   JFContinueButton(label: "connect to health",
//                    action: requestHK,
//                    secondaryLabel: "skip for now",
//                    secondaryAction: { advance() })

struct JFContinueButton: View {
    let label: String
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false
    /// Set false when the call site fires its own haptic in `action`
    /// (the legacy ctaBtn sites do) — avoids a double-tap stutter.
    var firesHaptic: Bool = true
    /// Optional secondary text-link below the primary capsule
    /// (e.g. "skip for now", "maybe later"). Kept tertiary so the
    /// primary CTA stays the visual focus.
    var secondaryLabel: String? = nil
    var secondaryAction: (() -> Void)? = nil
    /// p66 — false when the call site owns the surrounding air
    /// (embedded in an already-padded column). True keeps the
    /// standing footer insets (horizontal Space.lg + bottom 24).
    var padded: Bool = true
    /// p67 — true on an INK scene: the pill inverts to paper with an
    /// ink label (the consult's "begin"). Same geometry, same
    /// register; only the surface relationship flips.
    var inverse: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                guard isEnabled, !isLoading else { return }
                if firesHaptic { Haptics.medium() }
                action()
            } label: {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Palette.textInverse)
                            .controlSize(.small)
                    }
                    Text(label)
                        // her75 register: upright sans-serif, NOT
                        // italic-Fraunces. The italic on the CTA
                        // reads as ornament; her75 keeps CTAs
                        // functional + lets the headline carry voice.
                        // p66 — the standing CTA finally scales with
                        // Dynamic Type (it was the one fixed-size label
                        // on the app's most important control), capped
                        // at accessibility2 so a one-line label never
                        // ellipsizes inside the 56pt pill (AX5 filmed
                        // "add something…" before the cap; ~1.5× still
                        // reads large, and the whole label survives).
                        .font(.custom("DMSans-SemiBold", size: 16, relativeTo: .body))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                        // v2.7 clipping contract: a CTA label never
                        // wraps into the fixed 56pt frame and never
                        // ellipsizes — it scales, imperceptibly, on
                        // narrow devices / long copy.
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 18)
                        // v1.1 "modern vibe" (2026-06-24): disabled is no
                        // longer a muddy grey pill (grey is the one color
                        // outside the 8-token system and read as broken) — the
                        // label dims to a cocoa ghost and the fill blooms from
                        // 12% → solid cocoa the instant she picks an answer.
                        // Enabling becomes a small reward, not a state flip.
                        .foregroundStyle(
                            inverse
                                ? (isEnabled ? Palette.cocoaPrimary : Palette.textInverse.opacity(0.4))
                                : (isEnabled ? Palette.textInverse : Palette.cocoaTertiary))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    (inverse ? Palette.textInverse : Palette.cocoaPrimary)
                        .opacity(isEnabled ? 1.0 : 0.12))
                .clipShape(Capsule())
                // the active CTA floats above the cream; the ghost casts nothing.
                .shadow(color: (inverse ? Color.black : Palette.cocoaPrimary)
                            .opacity(isEnabled ? 0.18 : 0),
                        radius: isEnabled ? 12 : 0, x: 0, y: isEnabled ? 5 : 0)
                .animation(Motion.modernPop, value: isEnabled)
            }
            .disabled(!isEnabled || isLoading)
            // v1.1 quiet-luxury: the primary CTA presses with depth + a
            // 220ms tap-acknowledge linger (soft haptic on touch; the
            // action still fires Haptics.medium on commit — a premium
            // two-stage touch→commit, not a same-moment stutter).
            .buttonStyle(LuxuryPressButtonStyle())

            if let secondaryLabel, let secondaryAction {
                Button {
                    Haptics.light()
                    secondaryAction()
                } label: {
                    Text(secondaryLabel)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(inverse
                            ? Palette.textInverse.opacity(0.66)
                            : Palette.textSecondary)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, padded ? Space.lg : 0)
        .padding(.bottom, padded ? 24 : 0)
    }
}

#Preview("standard") {
    JFContinueButton(label: "continue", action: {})
        .padding()
        .background(Palette.bgPrimary)
}

#Preview("disabled") {
    JFContinueButton(label: "i agree", action: {}, isEnabled: false)
        .padding()
        .background(Palette.bgPrimary)
}

#Preview("with skip") {
    JFContinueButton(
        label: "connect to health",
        action: {},
        secondaryLabel: "skip for now",
        secondaryAction: {}
    )
    .padding()
    .background(Palette.bgPrimary)
}
