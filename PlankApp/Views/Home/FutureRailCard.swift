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
    // .foodLog removed 2026-06-07 — food scanning shipped in v1.0.7,
    // no longer "coming soon". .stepCounter also removed — steps
    // shipped in v1.0.6 and is already gated out of the HomeView
    // callsite. New: .foodScrapbook — Pinterest-coded polaroid log
    // layered on top of the v1.0.7 food rail. Tests cohort interest
    // in the aesthetic-curation angle before we commit build cost.
    case foodScrapbook = "food_scrapbook"
    case bodyScan      = "body_scan"
    case weeklyCheckIn = "weekly_check_in"

    var id: String { rawValue }

    /// Full title — explainer sheet + accessibility label.
    var title: String {
        switch self {
        case .foodScrapbook: return "food scrapbook"
        case .bodyScan:      return "body scan + jeni"
        case .weeklyCheckIn: return "weekly check-in photo"
        }
    }

    /// Short title for the compact home chip.
    var shortTitle: String {
        switch self {
        case .foodScrapbook: return "scrapbook"
        case .bodyScan:      return "body scan"
        case .weeklyCheckIn: return "weekly photo"
        }
    }

    /// Brand sticker for the explainer hero (replaces SF Symbols).
    var sticker: StickerName {
        switch self {
        // .bowSatin is the most "scrapbook-handcrafted" reading
        // sticker in the brand pack — matches washi-tape /
        // ribbon-on-polaroid energy without being too literal.
        case .foodScrapbook: return .bowSatin
        case .bodyScan:      return .butterflyRing
        case .weeklyCheckIn: return .cameraLineart
        }
    }

    var explainerEyebrow: String {
        switch self {
        case .foodScrapbook: return "coming soon"
        case .bodyScan:      return "coming soon"
        case .weeklyCheckIn: return "coming soon"
        }
    }

    var explainerBody: String {
        switch self {
        // Food scrapbook — the cohort-aesthetic layer on top of the
        // shipped food rail. Pinterest-coded curation, polaroid
        // meals, washi-tape arrangements, captions. Anti-MFP-
        // spreadsheet vibe. Voice locks held: lowercase, no
        // diet-culture verbs, ED-safety (no good-or-bad labels).
        case .foodScrapbook:
            return "your meals as a soft scrapbook. each plate gets a polaroid, a sticker, a little note from your day. no spreadsheet. just a quiet record of how you eat, kept like a journal you'd actually open again."
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
    FutureRailRow(rails: [.foodScrapbook, .bodyScan, .weeklyCheckIn], onTap: { _ in })
        .padding()
        .background(Palette.bgPrimary)
}

#Preview("scrapbook rail explainer") {
    FutureRailExplainerSheet(rail: .foodScrapbook, onClose: {})
}

#Preview("body scan rail explainer") {
    FutureRailExplainerSheet(rail: .bodyScan, onClose: {})
}

#Preview("photo rail explainer") {
    FutureRailExplainerSheet(rail: .weeklyCheckIn, onClose: {})
}
#endif
