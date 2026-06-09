import SwiftUI

// MARK: - PlanViewMicroCaption (v3 — italic punch word)
//
// v1.1 program pivot — PlanView redesign per UX spec §v3.3.
// One sentence below the checklist card that names what the user
// has done today. With the hero gone, this caption now carries the
// italic-Fraunces voice signature for PlanView — punch word per
// bucket renders in Fraunces SemiBoldItalic.
//
// Bucket copy locked 2026-06-09 (italic word in *asterisks*):
//   0/N: "a fresh page. *start anywhere*."
//   1/N: "you *opened* the door."
//   2/N: "you're *moving*."
//   3/N: "you're *showing up*."
//   4/N: "one to go. or don't. *either's fine*."
//   N/N: "all {N}. you *closed* the day."

struct PlanViewMicroCaption: View {

    let completed: Int
    let total: Int

    var body: some View {
        guard total > 0 else { return AnyView(EmptyView()) }
        let segments = copySegments()
        return AnyView(
            (
                Text(segments.prefix)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                +
                Text(segments.italic)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .caption))
                    .foregroundStyle(Palette.cocoaTertiary)
                +
                Text(segments.suffix)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        )
    }

    private struct Segments {
        let prefix: String
        let italic: String
        let suffix: String
    }

    private func copySegments() -> Segments {
        if completed >= total {
            return Segments(prefix: "all \(total). you ", italic: "closed", suffix: " the day.")
        }
        switch completed {
        case 0: return Segments(prefix: "a fresh page. ", italic: "start anywhere", suffix: ".")
        case 1: return Segments(prefix: "you ", italic: "opened", suffix: " the door.")
        case 2: return Segments(prefix: "you're ", italic: "moving", suffix: ".")
        case 3: return Segments(prefix: "you're ", italic: "showing up", suffix: ".")
        case 4: return Segments(prefix: "one to go. or don't. ", italic: "either's fine", suffix: ".")
        default: return Segments(prefix: "you're ", italic: "showing up", suffix: ".")
        }
    }
}
