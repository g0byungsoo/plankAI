import SwiftUI

// MARK: - FutureRail
//
// Phase B/C feature previews (food logging, weekly check-in photo).
// Per docs/product_direction_2026.md §8.5 these serve two purposes:
//
//   1. Plant program-shape — the user sees Jeni is preparing more for
//      them, not "today's workout is the whole app."
//   2. Capture intent signal — taps fire `future_rail_tapped` with
//      `rail_id`, telling us which feature has more pull before we
//      commit build cost.
//
// Surfaced on Home as ONE quiet line (`FutureRailRow`), not two dashed
// stub cards — the boxed/locked styling read as generic clutter. Voice:
// "coming soon", framed as Jeni preparing more (never "AI will track
// your meals" — surveillance language Gen Z rejects).

enum FutureRail: String, Identifiable {
    case foodLog       = "food_log"
    case stepCounter   = "step_counter"
    case bodyScan      = "body_scan"
    case weeklyCheckIn = "weekly_check_in"

    var id: String { rawValue }

    /// Full title — explainer sheet + accessibility label.
    var title: String {
        switch self {
        case .foodLog:       return "food + jeni"
        case .stepCounter:   return "steps + jeni"
        case .bodyScan:      return "body scan + jeni"
        case .weeklyCheckIn: return "weekly check-in photo"
        }
    }

    /// Short title for the compact home chip.
    var shortTitle: String {
        switch self {
        case .foodLog:       return "food + jeni"
        case .stepCounter:   return "steps"
        case .bodyScan:      return "body scan"
        case .weeklyCheckIn: return "weekly photo"
        }
    }

    /// Brand sticker for the explainer hero (replaces SF Symbols).
    var sticker: StickerName {
        switch self {
        case .foodLog:       return .peach
        case .stepCounter:   return .sparkleGlossy
        case .bodyScan:      return .butterflyRing
        case .weeklyCheckIn: return .cameraLineart
        }
    }

    var explainerEyebrow: String {
        switch self {
        case .foodLog:       return "coming next"
        case .stepCounter:   return "coming soon"
        case .bodyScan:      return "coming soon"
        case .weeklyCheckIn: return "coming soon"
        }
    }

    var explainerBody: String {
        switch self {
        // Calorie tracking is the core demand (the Cal AI draw) — surfaced
        // plainly. Stays Jeni-voiced (never "AI", per §5.1 CI rule) and
        // keeps the ED-safety guardrail (no good-or-bad food labels, §10).
        case .foodLog:
            return "snap a photo of your plate and jeni does the rest. she counts the calories and tracks them for you, so there's no manual logging. just the numbers, never good-or-bad labels about what you eat."
        case .stepCounter:
            return "jeni keeps an eye on your steps in the background, no extra app to open. the little walks count too, and she'll notice the days you moved more."
        // Body scan is body-image sensitive — framed private, on-device, and
        // NSV ("the progress the scale misses"), never a score or comparison.
        case .bodyScan:
            return "a private body read you can take at home, whenever you want. it stays on your phone. jeni uses it to see how your shape is changing — the progress the scale can miss — never a score, never a comparison."
        case .weeklyCheckIn:
            return "one photo a week, just for you. stays on your phone. jeni references the cadence so you can see how far you've come, without the before-and-after grid."
        }
    }
}

// MARK: - FutureRailRow
//
// One low-emphasis line of "coming soon" chips. Each chip still fires
// `future_rail_tapped` (preserves the §8.5 demand signal) and opens the
// explainer. No dashed boxes, no lock icons, no SF Symbols.

struct FutureRailRow: View {
    let rails: [FutureRail]
    let onTap: (FutureRail) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("coming soon")
                .font(Typo.eyebrow)
                .tracking(1.5)
                .foregroundStyle(Palette.textSecondary.opacity(0.7))

            HStack(spacing: Space.sm) {
                ForEach(rails) { rail in
                    Button {
                        Haptics.light()
                        Analytics.track(.futureRailTapped, properties: ["rail_id": rail.rawValue])
                        onTap(rail)
                    } label: {
                        Text(rail.shortTitle)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Palette.accentSubtle.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(rail.title), coming soon")
                    .accessibilityHint("tap to learn more")
                }

                Spacer(minLength: 0)
            }
        }
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
                Image(rail.sticker.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .opacity(rail.sticker.style.opacity)
            }
            .accessibilityHidden(true)

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
#Preview("rail row") {
    FutureRailRow(rails: [.foodLog, .stepCounter, .weeklyCheckIn], onTap: { _ in })
        .padding()
        .background(Palette.bgPrimary)
}

#Preview("food rail explainer") {
    FutureRailExplainerSheet(rail: .foodLog, onClose: {})
}

#Preview("steps rail explainer") {
    FutureRailExplainerSheet(rail: .stepCounter, onClose: {})
}

#Preview("photo rail explainer") {
    FutureRailExplainerSheet(rail: .weeklyCheckIn, onClose: {})
}
#endif
