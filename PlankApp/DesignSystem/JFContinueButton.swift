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
    /// Optional secondary text-link below the primary capsule
    /// (e.g. "skip for now", "maybe later"). Kept tertiary so the
    /// primary CTA stays the visual focus.
    var secondaryLabel: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Button {
                guard isEnabled, !isLoading else { return }
                Haptics.medium()
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
                        .font(.custom("DMSans-SemiBold", size: 16))
                        .foregroundStyle(Palette.textInverse)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isEnabled ? Palette.bgInverse : Palette.cocoaPrimary.opacity(0.35))
                .clipShape(Capsule())
            }
            .disabled(!isEnabled || isLoading)
            .buttonStyle(.plain)

            if let secondaryLabel, let secondaryAction {
                Button {
                    Haptics.light()
                    secondaryAction()
                } label: {
                    Text(secondaryLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, 24)
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
