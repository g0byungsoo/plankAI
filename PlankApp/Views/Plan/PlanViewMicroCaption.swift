import SwiftUI

// MARK: - PlanViewMicroCaption
//
// v1.1 program pivot — PlanView redesign per UX spec §6.
// One sentence below the checklist card that names what the user
// has done today. Anti-shame voice signature; her75 has nothing
// here, BetterMe has a productivity percentage bar — we go the
// JeniFit middle: calm, named, never numbered.
//
// Bucket copy locked 2026-06-09:
//   - 0/N: "a fresh page. start anywhere."
//   - 1/N: "you opened the door."
//   - 2/N: "you're moving."
//   - 3/N: "you're showing up."
//   - 4/N: "one to go. or don't. either's fine."
//   - all done: "all {N}. you closed the day."

struct PlanViewMicroCaption: View {

    let completed: Int
    let total: Int

    var body: some View {
        Text(copy)
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var copy: String {
        guard total > 0 else { return "" }
        if completed >= total { return "all \(total). you closed the day." }
        switch completed {
        case 0: return "a fresh page. start anywhere."
        case 1: return "you opened the door."
        case 2: return "you're moving."
        case 3: return "you're showing up."
        case 4: return "one to go. or don't. either's fine."
        default: return "you're showing up."
        }
    }
}
