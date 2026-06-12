import SwiftUI

// MARK: - PostPurchaseFlowView
//
// Orchestrates the post-purchase sequence inside a SINGLE fullScreenCover
// so transitions between steps are smooth cross-fades (.opacity) rather
// than iOS's default cover slide. Each child view handles its own content
// + audio; this container only owns the phase state and the routing.
//
// Flow (v1.1 program era):
//   forging → coachIntro → breathworkPrimer → breathworkSession → finish
//                               │ skip ──────────────────────────→ finish
//
// `onFinish` is the single exit; the caller dismisses the cover and the
// user lands on the Today tab's program onramp. The old ForceFirstAction
// picker is retired — both of its choices routed into legacy-HomeView
// flags, and the onramp → PlanView checklist is the activation surface.

struct PostPurchaseFlowView: View {
    let onFinish: () -> Void

    private enum Phase: Equatable {
        case forging               // v3 P11.4 — 8s post-paywall keystone
        case coachIntro
        case breathworkPrimer
        case breathworkSession
    }

    // v3 P11.4 (2026-06-10) — forging phase lands FIRST so the user
    // sees the program activating before Jeni introduces herself.
    // 5 milestone cascade lines + single success haptic at 380ms
    // acknowledge the just-made commitment ($47.99 + the 25s
    // onboarding loader). Lands as the brand's "you bought it,
    // here's what it is" beat per the Cal AI calai31 + her75
    // editorial register synthesis.
    @State private var phase: Phase = .forging

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
                    onSkip: { onFinish() }
                )
                .transition(.opacity)

            case .breathworkSession:
                BreathworkSessionView(
                    onReadyToMove: { onFinish() },
                    onLater: { onFinish() },
                    onDismiss: { onFinish() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
    }

    private func transition(to next: Phase) {
        // v1.1 module pass — phase swaps ride the shared crossFade
        // token (0.45 easeInOut) instead of a one-off 0.5.
        withAnimation(Motion.crossFade) {
            phase = next
        }
    }
}
