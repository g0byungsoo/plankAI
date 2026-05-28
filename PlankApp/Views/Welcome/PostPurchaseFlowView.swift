import SwiftUI

// MARK: - PostPurchaseFlowView
//
// Orchestrates the post-purchase sequence inside a SINGLE fullScreenCover
// so transitions between steps are smooth cross-fades (.opacity) rather
// than iOS's default cover slide. Each child view handles its own content
// + audio; this container only owns the phase state and the routing.
//
// Flow (per product decisions 2026-05-27):
//   coachIntro → breathworkPrimer → breathworkSession → finish
//                      │ skip ─────────────────────────→ finish(workout)
//
//   breathworkSession completion (option C choice):
//      "ready to move"     → finish(launchWorkout: true)
//      "save it for later" → finish(launchWorkout: false)
//      X (any phase)       → finish(launchWorkout: false)
//
// `onFinish(launchWorkout:)` is the single exit. The caller (PlankAIApp)
// dismisses the cover and, when launchWorkout is true, sets the
// pendingPostRitualWorkoutLaunch flag HomeView already reads on appear.

struct PostPurchaseFlowView: View {
    /// Single exit. `launchWorkout` = true means route the user into the
    /// first workout; false means land them on Home (workout card still
    /// prominent, user picks their own moment).
    let onFinish: (_ launchWorkout: Bool) -> Void

    private enum Phase: Equatable {
        case coachIntro
        case breathworkPrimer
        case breathworkSession
    }

    @State private var phase: Phase = .coachIntro

    var body: some View {
        ZStack {
            // Shared cream canvas so phase swaps cross-fade over a stable
            // background rather than flashing.
            Palette.bgPrimary.ignoresSafeArea()

            switch phase {
            case .coachIntro:
                CoachIntroView(onContinue: {
                    transition(to: .breathworkPrimer)
                })
                .transition(.opacity)

            case .breathworkPrimer:
                BreathworkPrimerView(
                    onBreathe: { transition(to: .breathworkSession) },
                    onSkip: { onFinish(true) }   // skip breath → straight to workout
                )
                .transition(.opacity)

            case .breathworkSession:
                BreathworkSessionView(
                    onReadyToMove: { onFinish(true) },
                    onLater: { onFinish(false) },
                    onDismiss: { onFinish(false) }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
    }

    private func transition(to next: Phase) {
        withAnimation(.easeInOut(duration: 0.5)) {
            phase = next
        }
    }
}
