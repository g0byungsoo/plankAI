import SwiftUI

// MARK: - FutureRailCard
//
// Grayed stub cards at the bottom of HomeView that preview Phase B and
// Phase C features (food logging, weekly check-in photo). Per
// docs/product_direction_2026.md §8.5, these serve two purposes:
//
//   1. Plant program-shape — the user sees Jeni is preparing more for
//      them, not "today's workout is the whole app."
//   2. Capture intent signal — taps fire `future_rail_tapped` with
//      `rail_id`, telling us which Phase B/C feature has more pull
//      before we commit build cost.
//
// Voice rules: framed as "jeni's working on this" (coach preparing
// more for the user), NOT "AI will track your meals" (surveillance
// language Gen Z rejects).

enum FutureRail: String, Identifiable {
    case foodLog       = "food_log"
    case weeklyCheckIn = "weekly_check_in"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .foodLog:       return "fork.knife"
        case .weeklyCheckIn: return "camera"
        }
    }

    var title: String {
        switch self {
        case .foodLog:       return "food + jeni"
        case .weeklyCheckIn: return "weekly check-in photo"
        }
    }

    var subtitle: String {
        switch self {
        case .foodLog:       return "jeni's working on this. soon."
        case .weeklyCheckIn: return "your time capsule. soon."
        }
    }

    var explainerEyebrow: String {
        switch self {
        case .foodLog:       return "coming next"
        case .weeklyCheckIn: return "coming soon"
        }
    }

    var explainerBody: String {
        switch self {
        case .foodLog:
            return "snap a photo of what you're eating. jeni will see it, log it for you, and write you a note back. no calorie math, no good-or-bad labels. just you sharing your plate."
        case .weeklyCheckIn:
            return "one photo a week, just for you. stays on your phone. jeni references the cadence so you can see how far you've come, without the before-and-after grid."
        }
    }
}

struct FutureRailCard: View {
    let rail: FutureRail
    let onTap: (FutureRail) -> Void

    var body: some View {
        Button {
            Haptics.light()
            Analytics.track(.futureRailTapped, properties: ["rail_id": rail.rawValue])
            onTap(rail)
        } label: {
            HStack(spacing: Space.md) {
                ZStack {
                    Circle()
                        .fill(Palette.divider)
                        .frame(width: 36, height: 36)
                    Image(systemName: rail.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.textSecondary)
                        Text(rail.title)
                            .font(Typo.heading)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    Text(rail.subtitle)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary.opacity(0.6))
            }
            .padding(Space.md)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.bgElevated.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Palette.divider, style: StrokeStyle(lineWidth: 1.0, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(rail.title), coming soon")
        .accessibilityHint("tap to learn more")
    }
}

// MARK: - FutureRailExplainerSheet

struct FutureRailExplainerSheet: View {
    let rail: FutureRail
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer().frame(height: Space.sm)

            ZStack {
                Circle()
                    .fill(Palette.accentSubtle)
                    .frame(width: 72, height: 72)
                Image(systemName: rail.icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Palette.accent)
            }

            VStack(spacing: Space.sm) {
                Text(rail.explainerEyebrow.uppercased())
                    .font(Typo.eyebrow)
                    .tracking(1.2)
                    .foregroundStyle(Palette.accent)

                ItalicAccentText(rail.title,
                                 italic: [],
                                 baseFont: Typo.title,
                                 italicFont: Typo.titleItalic,
                                 color: Palette.textPrimary,
                                 alignment: .center)
            }

            Text(rail.explainerBody)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: onClose) {
                Text("got it")
            }
            .buttonStyle(.ctaPrimary)
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bgPrimary)
    }
}

#if DEBUG
#Preview("food rail card") {
    FutureRailCard(rail: .foodLog, onTap: { _ in })
        .padding()
        .background(Palette.bgPrimary)
}

#Preview("photo rail card") {
    FutureRailCard(rail: .weeklyCheckIn, onTap: { _ in })
        .padding()
        .background(Palette.bgPrimary)
}

#Preview("food rail explainer") {
    FutureRailExplainerSheet(rail: .foodLog, onClose: {})
}

#Preview("photo rail explainer") {
    FutureRailExplainerSheet(rail: .weeklyCheckIn, onClose: {})
}
#endif
