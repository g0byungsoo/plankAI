import SwiftUI

// The legacy HomeView (pre-program-era home surface) was retired in
// v1.1 — MainTabView renders ProgramOnrampView or PlanView instead.
// StatCard remains: PostSessionView composes it for the hold-time +
// streak pair.

struct StatCard: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: Space.xs) {
            Text(value)
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(Palette.textPrimary)
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.accent.opacity(0.15))
                    .offset(x: 4, y: 4)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
        )
    }
}
