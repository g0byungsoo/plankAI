import SwiftUI

// MARK: - PostPurchaseFlowView
//
// Orchestrates the post-purchase sequence inside a SINGLE fullScreenCover
// so transitions between steps are smooth cross-fades (.opacity) rather
// than iOS's default cover slide. Each child view handles its own content
// + audio; this container only owns the phase state and the routing.
//
// Flow (v1.1 program era):
//   forging -> coachIntro -> breathworkPrimer -> breathworkSession -> finish
//                               | skip ----------------------------------> finish
//
// Task 10 (2026-06-28): if promiseAction + promiseAnchor are both set,
// breathworkSession routes to promiseConfirmation before finish so the
// user sees her own words replayed before landing on home.
//
// `onFinish` is the single exit; the caller dismisses the cover and the
// user lands on the Today tab's program onramp. The old ForceFirstAction
// picker is retired - both of its choices routed into legacy-HomeView
// flags, and the onramp -> PlanView checklist is the activation surface.

struct PostPurchaseFlowView: View {
    let onFinish: () -> Void
    // Task 10 (2026-06-28) - optional promise replay values. When both are
    // non-nil and non-empty, the flow routes to promiseConfirmation after
    // breathwork so the user sees her own words replayed before home.
    var promiseAction: String? = nil
    var promiseAnchor: String? = nil

    private enum Phase: Equatable {
        case forging               // v3 P11.4 - 8s post-paywall keystone
        case coachIntro
        case breathworkPrimer
        case breathworkSession
        case promiseConfirmation   // Task 10 (2026-06-28)
    }

    // v3 P11.4 (2026-06-10) - forging phase lands FIRST so the user
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
            // cross-fade over a stable background - subviews no longer
            // own their own background/scatter layers (was the source of
            // the inter-phase flicker - each subview's `bgVisible` faded
            // in from 0 on appear, creating a flash between phases).
            // Single canonical scatter (coachIntroDefault) reads as the
            // welcome flow's visual constant across all 4 phases.
            // v8 P8.6: post-paywall router canvas - pink directly so
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
                // Task 10 (2026-06-28): route to promiseConfirmation when
                // the user stored a Day-1 promise during onboarding. All
                // three exit paths check the same condition so the promise
                // phase appears regardless of how breathwork ends.
                BreathworkSessionView(
                    onReadyToMove: {
                        if let action = promiseAction, !action.isEmpty,
                           let anchor = promiseAnchor, !anchor.isEmpty {
                            transition(to: .promiseConfirmation)
                        } else {
                            onFinish()
                        }
                    },
                    onLater: {
                        if let action = promiseAction, !action.isEmpty,
                           let anchor = promiseAnchor, !anchor.isEmpty {
                            transition(to: .promiseConfirmation)
                        } else {
                            onFinish()
                        }
                    },
                    onDismiss: {
                        if let action = promiseAction, !action.isEmpty,
                           let anchor = promiseAnchor, !anchor.isEmpty {
                            transition(to: .promiseConfirmation)
                        } else {
                            onFinish()
                        }
                    }
                )
                .transition(.opacity)

            case .promiseConfirmation:
                // Task 10 (2026-06-28) - replays the user's own promise
                // words before she lands on the Today tab. Single exit
                // to onFinish so CoachIntroState.markShown() fires once.
                PostPurchasePromisePhase(
                    action: promiseAction ?? "",
                    anchor: promiseAnchor ?? "",
                    onContinue: { onFinish() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
    }

    private func transition(to next: Phase) {
        // v1.1 module pass - phase swaps ride the shared crossFade
        // token (0.45 easeInOut) instead of a one-off 0.5.
        withAnimation(Motion.crossFade) {
            phase = next
        }
    }
}

// MARK: - PostPurchasePromisePhase (Task 10, 2026-06-28)
//
// Shows the user's Day-1 promise back to her as a soft confirmation
// before she lands on the Today tab. No background: the parent
// PostPurchaseFlowView canvas (programBgPrimary + sticker scatter)
// shows through.
//
// Named at internal (not private) access so PlankAIApp debug harnesses
// can instantiate it directly for screenshot iteration.

struct PostPurchasePromisePhase: View {
    let action: String
    let anchor: String
    let onContinue: () -> Void

    @State private var heroVisible = false
    @State private var lineVisible = false
    @State private var ctaVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 80)

            ItalicAccentText(
                "your promise is set.",
                italic: ["set"],
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .leading
            )
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Space.lg)
            .opacity(heroVisible ? 1 : 0)
            .offset(y: heroVisible ? 0 : 12)

            Spacer().frame(height: 32)

            Text("tomorrow, after \(anchor), you'll \(action). we'll be here \u{2665}")
                .font(.custom("DMSans-Regular", size: 16))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, Space.lg)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(lineVisible ? 1 : 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "continue", action: onContinue)
                .opacity(ctaVisible ? 1 : 0)
        }
        .task {
            withAnimation(.easeOut(duration: 0.35)) { heroVisible = true }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.35)) { lineVisible = true }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeOut(duration: 0.35)) { ctaVisible = true }
        }
    }
}
