import SwiftUI

// MARK: - BreathworkHomeCard
//
// Re-entry point to the breathwork primer + session from the home screen.
//
// Why a separate card from the steps pulse: breathwork is an *action* (a
// CTA you tap and complete), while steps is a *passive read* (the count
// happens whether you look or not). Lumping them into the same component
// would either turn steps into a CTA or breathwork into a passive number,
// both of which the design has deliberately pushed back on. The home IA
// already separates anchors from actions (workout card = the hero action;
// steps = anchor; quickActions = utility nav) — this card is a *secondary
// action*, sized smaller than the workout hero so the workout still wins
// the eye, but still a clear "do this" with a tap target.
//
// Three states:
//   .unfamiliar  — user hasn't completed a breath session yet. Copy
//                  leans on the science honest claim (cortisol, not
//                  fat-burn) so the first tap is informed.
//   .invitation  — user has completed at least one session before but
//                  not today. Warm "settle for a minute" invite.
//   .completed   — already breathed today. Subdued affirmation; tap
//                  still re-enters the session (no lockout).
//
// Tapping any state surfaces the primer (parent presents fullScreenCover);
// from there the existing flow does the rest. After completion, the
// session view writes to BreathworkState.shared which mutates this card's
// state via @Observable.

struct BreathworkHomeCard: View {
    @Bindable var state: BreathworkState
    var onTap: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            onTap()
        } label: {
            HStack(alignment: .center, spacing: Space.md) {
                bloomIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(eyebrow)
                        .font(Typo.eyebrow).tracking(1.5)
                        .foregroundStyle(Palette.accent)
                    titleLine
                    Text(supporting)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(chrome)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens a one-minute guided breath with Jeni.")
    }

    // MARK: - States

    private enum Mode { case unfamiliar, invitation, completed }
    private var mode: Mode {
        if state.totalCompleted == 0 { return .unfamiliar }
        if state.breathedToday        { return .completed }
        return .invitation
    }

    private var eyebrow: String {
        switch mode {
        case .unfamiliar:  return "before you move"
        case .invitation:  return "one minute"
        case .completed:   return "you breathed today"
        }
    }

    @ViewBuilder
    private var titleLine: some View {
        switch mode {
        case .unfamiliar:
            HStack(spacing: 6) {
                Text("settle")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                    .foregroundStyle(Palette.textPrimary)
                Text("the cortisol")
                    .font(Typo.body).fontWeight(.semibold)
                    .foregroundStyle(Palette.textPrimary)
            }
        case .invitation:
            HStack(spacing: 6) {
                Text("breathe")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                    .foregroundStyle(Palette.textPrimary)
                Text("with jeni")
                    .font(Typo.body).fontWeight(.semibold)
                    .foregroundStyle(Palette.textPrimary)
            }
        case .completed:
            HStack(spacing: 6) {
                Text("again")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                    .foregroundStyle(Palette.textPrimary)
                Text("if it helps")
                    .font(Typo.body).fontWeight(.semibold)
                    .foregroundStyle(Palette.textPrimary)
            }
        }
    }

    private var supporting: String {
        switch mode {
        case .unfamiliar:
            return "1 min · slow exhale · jeni guides you"
        case .invitation:
            let d = state.distinctDaysThisWeek
            return d > 0 ? "\(d)× this week ♥ · 1 min" : "1 min · slow exhale"
        case .completed:
            return "as many times as you want ♥"
        }
    }

    private var accessibilityLabel: String {
        switch mode {
        case .unfamiliar: return "Breathwork. Settle the cortisol. One minute with Jeni."
        case .invitation: return "Breathwork invitation. One minute with Jeni. \(state.distinctDaysThisWeek) times this week."
        case .completed:  return "You breathed today. Tap to breathe again."
        }
    }

    // MARK: - Visual

    /// Soft animated bloom — a coquette stand-in for the BreathCircle that
    /// lives inside the session. Reduce-motion holds the bloom static.
    @State private var bloomScale: CGFloat = 0.85
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bloomIcon: some View {
        ZStack {
            Circle()
                .fill(Palette.accent.opacity(0.18))
                .frame(width: 48, height: 48)
                .scaleEffect(bloomScale)
            Circle()
                .fill(Palette.accent.opacity(0.32))
                .frame(width: 28, height: 28)
                .scaleEffect(bloomScale)
            Image(StickerName.heartGlossy.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .opacity(StickerName.heartGlossy.style.opacity * 0.95)
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
        .onAppear { startBloom() }
    }

    private func startBloom() {
        guard !reduceMotion else { bloomScale = 1.0; return }
        // Slow 5s ease for one cycle, matches the BreathCircle pace
        // signal (inhale-hold-exhale) without forcing the user to keep
        // pace with it from the home glance.
        withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
            bloomScale = 1.06
        }
    }

    private var chrome: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.accent.opacity(0.14))
                .offset(x: 4, y: 4)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.bgElevated)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
        }
    }
}

#if DEBUG
#Preview("breathwork home card · unfamiliar") {
    BreathworkHomeCard(state: BreathworkState.shared, onTap: {})
        .padding()
        .background(Palette.bgPrimary)
}
#endif
