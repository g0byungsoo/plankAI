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
        case forging               // v3 P11.4 — 8s post-paywall keystone
        case coachIntro
        case breathworkPrimer
        case breathworkSession
        case forceFirstAction      // W4-T2 — D38 post-paywall picker
    }

    // v3 P11.4 (2026-06-10) — forging phase lands FIRST so the user
    // sees the program activating before Jeni introduces herself.
    // 5 milestone cascade lines + single success haptic at 380ms
    // acknowledge the just-made commitment ($47.99 + the 25s
    // onboarding loader). Lands as the brand's "you bought it,
    // here's what it is" beat per the Cal AI calai31 + her75
    // editorial register synthesis.
    @State private var phase: Phase = .forging

    /// Mirror of the AppStorage key HomeView watches to launch the
    /// food capture flow on appear. PostPurchaseFlow sets it true on
    /// the food choice; HomeView reads + clears on next render.
    @AppStorage("pendingFoodScan") private var pendingFoodScan = false

    var body: some View {
        ZStack {
            // Shared cream canvas + shared sticker scatter so phase swaps
            // cross-fade over a stable background — subviews no longer
            // own their own background/scatter layers (was the source of
            // the inter-phase flicker — each subview's `bgVisible` faded
            // in from 0 on appear, creating a flash between phases).
            // Single canonical scatter (coachIntroDefault) reads as the
            // welcome flow's visual constant across all 4 phases.
            // v8 P8.6: post-paywall router canvas — pink directly so
            // all welcome children (premium welcome, coach intro, breath
            // primer, force first action) inherit the program-era pink
            // without each child re-declaring its bg.
            Palette.programBgPrimary.ignoresSafeArea()
            StickerScatter(placements: StickerScatter.coachIntroDefault())
                .allowsHitTesting(false)

            switch phase {
            case .forging:
                ForgingRevealView(onContinue: {
                    transition(to: .coachIntro)
                })
                .transition(.opacity)

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
        // v1.1 module pass — phase swaps ride the shared crossFade
        // token (0.45 easeInOut) instead of a one-off 0.5.
        withAnimation(Motion.crossFade) {
            phase = next
        }
    }
}
