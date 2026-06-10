import SwiftUI

// MARK: - ForgingRevealView
//
// v3 P11.4 (2026-06-10) — the keystone. Post-paywall "forging"
// moment that lands as the FIRST phase of PostPurchaseFlowView,
// before CoachIntro. Five milestone cascade lines reveal the
// program activating; a single Haptics.success() fires at 380ms
// into the cascade so the second line ("locked in") lands with
// a louder beat than the soft per-line taps.
//
// Total dwell: ~8 seconds (5 lines × 0.42s perLineDelay = 2.1s
// reveal, then a 4-5s read pause, then auto-advance to CoachIntro).
// User can tap "continue" mid-pause to advance early.
//
// Why this exists:
// - the existing PostPurchaseFlowView jumped straight to CoachIntro
//   after purchase, which felt abrupt — the user just committed
//   $47.99 + watched a 25s onboarding loader, and the first thing
//   they saw was "hi, I'm Jeni" with no acknowledgement of the
//   commitment itself
// - the forging beat acknowledges WHAT they just bought before
//   introducing WHO will guide them through it
// - per Cal AI calai31 ("All done!" frame), the post-loader / post-
//   purchase moment is a high-value emotional pivot — the cohort
//   converts on adherence to whatever rhythm the next 20 seconds
//   establishes
//
// Voice: italic-Fraunces punch per line on the verb that carries
// commitment ("activated", "locked in", "ready", "becoming",
// "begin"). Heart terminal on the final line. No labor verbs.

struct ForgingRevealView: View {
    let onContinue: () -> Void

    @State private var ctaVisible = false
    @State private var successHapticFired = false
    @AccessibilityFocusState private var heroFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Time from view appear to single Haptics.success() — lands on
    /// line 2 ("locked in") which is the meaning beat of the cascade.
    private static let successHapticDelay: Double = 0.38

    /// Total dwell before auto-advance. 5 lines × 0.42s reveal = 2.1s
    /// + 4.9s read pause = 7s total. Cap matches the her75 "magazine
    /// page-turn" pacing per [[feedback-her75-motion-vocabulary]].
    private static let autoAdvanceAfter: Double = 7.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            LineCascadeText(
                lines: [
                    .composite(base: "your program is activated.", italic: ["activated."]),
                    .composite(base: "your routine is locked in.",  italic: ["locked in."]),
                    .composite(base: "your first session is ready.", italic: ["ready."]),
                    .composite(base: "your becoming starts now.",    italic: ["becoming"]),
                    .composite(base: "let's begin ♥",                italic: ["begin"]),
                ],
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .leading,
                lineSpacing: Typo.heroHeadlineLineGap,
                perLineDelay: 0.42
            )
            .kerning(-0.4)
            .padding(.horizontal, Space.lg)
            .accessibilityFocused($heroFocused)
            .accessibilityLabel("Your program is activated. Your routine is locked in. Your first session is ready. Your becoming starts now. Let's begin.")
            Spacer()
            JFContinueButton(label: "let's go") {
                onContinue()
            }
            .opacity(ctaVisible ? 1 : 0)
            .allowsHitTesting(ctaVisible)
        }
        .onAppear {
            heroFocused = true
            // Single success haptic at +380ms — louder beat on the
            // second line ("locked in"), the commitment moment.
            // LineCascadeText still fires per-line soft haptics on
            // top; the success here adds emphasis rather than
            // replacing the cascade signal.
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.successHapticDelay) {
                    guard !successHapticFired else { return }
                    successHapticFired = true
                    Haptics.success()
                }
            }
            // Reveal the CTA after the cascade finishes reading
            // (~2.5s = 5 lines × 0.42s + 0.4s settle). Auto-advance
            // safety net fires `Self.autoAdvanceAfter` seconds after
            // appear if the user hasn't tapped.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(Motion.entranceSoft) {
                    ctaVisible = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoAdvanceAfter) {
                onContinue()
            }
        }
    }
}

#Preview {
    ForgingRevealView(onContinue: {})
        .background(Palette.programBgPrimary)
}
