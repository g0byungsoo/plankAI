import SwiftUI
import PlankFood

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
        case forceFirstAction      // W4-T2 — D38 post-paywall picker
    }

    @State private var phase: Phase = .coachIntro

    /// Mirror of the AppStorage key HomeView watches to launch the
    /// food capture flow on appear. PostPurchaseFlow sets it true on
    /// the food choice; HomeView reads + clears on next render.
    @AppStorage("pendingFoodScan") private var pendingFoodScan = false

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
                    // Skip breath → still surface food/plank picker for
                    // the food-rail rollout cohort; existing cohort goes
                    // straight to workout (current behavior preserved).
                    onSkip: { afterBreath(routeToWorkout: true) }
                )
                .transition(.opacity)

            case .breathworkSession:
                BreathworkSessionView(
                    onReadyToMove: { afterBreath(routeToWorkout: true) },
                    onLater: { afterBreath(routeToWorkout: false) },
                    onDismiss: { afterBreath(routeToWorkout: false) }
                )
                .transition(.opacity)

            case .forceFirstAction:
                // W4-T2 — D38 picker. Food sets the pendingFoodScan
                // AppStorage flag; HomeView reads it on appear and
                // presents CaptureFlowView. Plank reuses the existing
                // pendingPostRitualWorkoutLaunch flag via launchWorkout=true.
                ForceFirstActionView(
                    onFood: {
                        pendingFoodScan = true
                        onFinish(false)  // land on Home; Home opens camera
                    },
                    onPlank: { onFinish(true) },
                    onSkip: { onFinish(false) }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
    }

    /// Decision gate after the breath phase finishes. If food rail is
    /// enabled for this user, show the picker so they explicitly
    /// choose food OR plank. Otherwise preserve the existing
    /// breath → workout-or-home routing (no behavior change for
    /// flag-off cohort).
    private func afterBreath(routeToWorkout: Bool) {
        if FoodFlags.isEnabled {
            transition(to: .forceFirstAction)
        } else {
            onFinish(routeToWorkout)
        }
    }

    private func transition(to next: Phase) {
        withAnimation(.easeInOut(duration: 0.5)) {
            phase = next
        }
    }
}
