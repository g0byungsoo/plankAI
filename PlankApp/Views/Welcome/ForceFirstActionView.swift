import SwiftUI
import PlankFood

// MARK: - ForceFirstActionView
//
// Per v5 D38 + §1 New user journey: post-paywall picker that gives
// the user an explicit choice — food photo OR 4-min plank — before
// landing on Home. Closes the 38% post-paywall activation gap
// surfaced in the 2026-06-02 PostHog audit (23 of 37 paid users
// never started any session in their first 3 days).
//
// Two equal-weight CTAs + soft "not right now" skip. Per v5 D51,
// plank option = existing JeniFit plank session (sets the existing
// pendingPostRitualWorkoutLaunch flag HomeView already reads on
// appear). Food option = new pendingFoodScan flag HomeView reads
// + presents CaptureFlowView.
//
// Gated on FoodFlags.isEnabled — for users not in the food rail
// rollout cohort, this view is skipped entirely (PostPurchaseFlow
// finishes straight to Home). Means the picker only appears for
// the audience getting food-rail messaging anyway.

struct ForceFirstActionView: View {

    let onFood: () -> Void
    let onPlank: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            VStack(spacing: 8) {
                Text("welcome 🌸")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.textSecondary)
                ItalicAccentText("let's *start*.",
                                 italic: ["start"],
                                 baseFont: .custom("Fraunces72pt-Regular", size: 32),
                                 italicFont: .custom("Fraunces72pt-RegularItalic", size: 32),
                                 alignment: .center)
            }
            .multilineTextAlignment(.center)

            Text("pick one to do right now —\nit's how this works:")
                .font(.system(size: 15))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, Space.sm)

            // Food option
            Button(action: onFood) {
                actionRow(
                    icon: "📷",
                    title: "log what you're eating",
                    subtitle: "(or about to eat)"
                )
            }
            .buttonStyle(.plain)

            // Plank option — existing 4-min starter session
            Button(action: onPlank) {
                actionRow(
                    icon: "💪",
                    title: "do a 4-min starter set",
                    subtitle: "(one plank, that's it)"
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onSkip) {
                Text("not right now →")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.bottom, Space.lg)
        }
        .padding(.horizontal, Space.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bgPrimary.ignoresSafeArea())
    }

    @ViewBuilder
    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Space.md) {
            Text(icon)
                .font(.system(size: 28))
                .frame(width: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Fraunces72pt-SemiBold", size: 17))
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(Space.md)
        .background(Palette.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.textPrimary.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview("ForceFirstActionView") {
    ForceFirstActionView(
        onFood: { print("food") },
        onPlank: { print("plank") },
        onSkip: { print("skip") }
    )
}
