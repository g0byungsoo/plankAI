import SwiftUI

// MARK: - PostPurchaseFlowView
//
// Orchestrates the post-purchase sequence inside a SINGLE fullScreenCover
// so transitions between steps are smooth cross-fades (.opacity) rather
// than iOS's default cover slide. Each child view handles its own content
// + audio; this container only owns the phase state and the routing.
//
// Flow (v1.1 program era):
//   forging -> coachIntro -> ratingPrompt -> breathworkPrimer -> breathworkSession -> finish
//                               | (rating skips if ineligible)  | skip --------------> finish
//
// Task 10 (2026-06-28): if promiseAction + promiseAnchor are both set,
// breathworkSession routes to promiseConfirmation before finish so the
// user sees her own words replayed before landing on home.
//
// v1.1.3 T8 (2026-06-29): the App Store rating ask ("love your plan?")
// moved OUT of onboarding (was case 215, pre-paywall) and lands here -
// right after the coach intro, where the user is already committed, so
// it no longer bleeds impulse intent before the price. PostPurchaseRatingView
// self-skips when RatingPromptService says the trigger is ineligible
// (per-install once + 30-day cooldown + legacy flag), so eligibility +
// quota behavior is identical to the old onboarding placement.
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
        case ratingPrompt          // T8 (2026-06-29) - relocated from onb case 215
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
                    transition(to: .ratingPrompt)
                })
                .transition(.opacity)

            case .ratingPrompt:
                // T8 (2026-06-29) - the rating ask, relocated from onboarding
                // case 215. Self-skips to breathworkPrimer when the trigger
                // is ineligible, so most repeat sessions never see it.
                PostPurchaseRatingView(onContinue: {
                    transition(to: .breathworkPrimer)
                })
                .transition(.opacity)

            case .breathworkPrimer:
                BreathworkPrimerView(
                    onBreathe: { transition(to: .breathworkSession) },
                    onSkip: {
                        if let action = promiseAction, !action.isEmpty,
                           let anchor = promiseAnchor, !anchor.isEmpty {
                            transition(to: .promiseConfirmation)
                        } else {
                            onFinish()
                        }
                    }
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

// MARK: - PostPurchaseRatingView (T8, 2026-06-29)
//
// The App Store rating prefilter ("love your plan?"), relocated from
// onboarding case 215. It used to sit between the method preview and the
// projection reveal + paywall, bleeding impulse intent before the price.
// Now it lands post-purchase (right after the coach intro) where the user
// is already committed, so the run to the wall stays clean.
//
// Logic is preserved verbatim from the old onboarding handlers
// (handleReviewPromptYes / handleReviewPromptNo): the legacy AppStorage
// flag is kept in sync, RatingPromptService marks the .postPlanReveal
// trigger shown, the sentiment result is tracked, and "yes" fires the
// system review sheet. Eligibility is checked on appear - if the trigger
// is ineligible (already fired this install, 30-day cooldown, or legacy
// flag set), the view self-skips to onContinue without showing the card,
// so quota + per-install behavior is identical to the old placement.
//
// Renders on the parent PostPurchaseFlowView canvas (programBgPrimary +
// shared scatter) - no own background, matching the sibling phases.
struct PostPurchaseRatingView: View {
    let onContinue: () -> Void

    @AppStorage("onboardingReviewPromptShown") private var onboardingReviewPromptShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Card hero - hero sticker on accent halo inside the scrapbook
            // chrome. Same composition as the old onboarding case 215 so
            // the rating ask reads as the brand's familiar "love your plan?"
            // moment, just later in the journey.
            VStack(spacing: Space.lg) {
                ZStack {
                    Circle()
                        .fill(Palette.accent.opacity(0.12))
                        .frame(width: 96, height: 96)
                    Image(StickerName.heartGlossy.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 68, height: 68)
                        .opacity(StickerName.heartGlossy.style.opacity)
                }
                .padding(.top, Space.md)

                (Text("love ").font(Typo.title)
                 + Text("your plan").font(Typo.titleItalic)
                 + Text("?").font(Typo.title))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.md)

                Text("a quick rating helps other women find us, and keeps the app independent.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.md)
                    .padding(.bottom, Space.md)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Space.md)
            .frame(maxWidth: .infinity)
            .scrapbookCardBackground()
            .padding(.horizontal, Space.screenPadding)
            .opacity(cardVisible ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (cardVisible ? 0 : 12))

            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(
                label: "loving it",
                action: {
                    Haptics.success()
                    handleYes()
                    // Brief delay so the system sheet has a beat to appear
                    // before we cross-fade forward; if iOS suppresses it
                    // (quota / throttle), the user just lands on breathwork.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        onContinue()
                    }
                },
                firesHaptic: false,
                secondaryLabel: "not yet",
                secondaryAction: {
                    // JFContinueButton fires Haptics.light() for the
                    // secondary tap itself - don't double it here.
                    handleNo()
                    onContinue()
                }
            )
        }
        .task {
            // Skip silently when the trigger can't fire - don't show a
            // prompt the system would suppress anyway.
            guard RatingPromptService.shared.isEligible(for: .postPlanReveal) else {
                onContinue()
                return
            }
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(120))
            }
            withAnimation(.easeOut(duration: 0.4)) { cardVisible = true }
        }
    }

    private func handleYes() {
        // Keep the legacy AppStorage flag in sync (parity with the old
        // onboarding handleReviewPromptYes).
        onboardingReviewPromptShown = true
        RatingPromptService.shared.markShown(.postPlanReveal)
        RatingPromptService.shared.trackSentimentResult(trigger: .postPlanReveal, sentimentYes: true)
        RatingPromptService.shared.presentSystemReviewSheet()
    }

    private func handleNo() {
        onboardingReviewPromptShown = true
        RatingPromptService.shared.markShown(.postPlanReveal)
        RatingPromptService.shared.trackSentimentResult(trigger: .postPlanReveal, sentimentYes: false)
    }
}

// MARK: - PostPurchasePromisePhase (Task 10, 2026-06-28)
//
// Shows the user's Day-1 promise back to her as a sealed confirmation
// before she lands on the Today tab.
//
// Three-zone ceremonial layout (full viewport):
//   1. Upper (~32% from top via balanced flex spacers): headline settled
//      like a receipt, centered. Not top-pinned.
//   2. Center: the sealed-promise ticket - a thin-hairline-bordered card
//      ~280pt wide holding "tomorrow, [anchor], you'll [action]." plus a
//      dusty-rose heart seal. On appear the ticket STAMPS in (scale
//      1.06->1.0, ~250ms spring) then fires ActivationHaptics.shared.commit()
//      as the "sealed" beat.
//   3. Grounded bottom: docked CTA via safeAreaInset; corner cluster as
//      secondary accent. Nothing overlaps the CTA.
//
// The two equal Spacers() above and below the content naturally position
// the headline at ~32% (content fixed heights: headline ~50pt, gap 44pt,
// ticket ~160pt, reassurance ~30pt = ~284pt total; remaining ~495pt
// split equally gives top spacer ~247pt = 32% of ~779pt usable height).
//
// Reduce Motion: ticket renders statically at final scale; stamp haptic
// fires unconditionally (haptic is not motion).
//
// Bug fixes baked in:
//   - Empty middle void: filled by sealed-promise ticket (center anchor)
//   - Headline top-pinned: moved to optical center-upper via balanced spacers
//   - 6-sticker spray: parent scatter hidden by GrainfieldBackground
//   - Sticker/text overlap: cluster corner-overlaid in ZStack, not in VStack
//   - Red heart: U+2665 U+FE0E forces text glyph; Palette.accent dusty rose
//
// Named at internal (not private) access so PlankAIApp debug harnesses
// can instantiate it directly for screenshot iteration.

struct PostPurchasePromisePhase: View {
    let action: String
    let anchor: String
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heroVisible = false
    @State private var ticketVisible = false
    @State private var ticketStamped = false
    @State private var reassuranceVisible = false
    @State private var ctaVisible = false
    @State private var clusterAnimated = false

    var body: some View {
        ZStack {
            // Premium alive-surface background. Covers the parent's
            // programBgPrimary + coachIntroDefault scatter so this phase
            // reads as an earned moment, not the shared flow canvas.
            GrainfieldBackground()

            // Three-zone layout: two equal flex Spacers distribute the
            // content to optical thirds (headline ~32%, ticket ~55%).
            VStack(spacing: 0) {
                // Top flex spacer - pushes headline to optical center-upper
                Spacer()

                // ZONE 1: Headline - settled, centered, not top-pinned
                ItalicAccentText(
                    "your promise is set.",
                    italic: ["set"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)
                .opacity(heroVisible ? 1 : 0)
                .offset(y: reduceMotion ? 0 : (heroVisible ? 0 : 10))

                // Fixed gap: headline -> ticket
                Spacer().frame(height: 44)

                // ZONE 2: Sealed-promise ticket (center anchor)
                // Stamps in: scale 1.06->1.0 over ~250ms spring.
                // Reduce-Motion: renders statically at final scale (ticket
                // still appears; only the stamp motion is gated).
                sealedTicket
                    .scaleEffect(reduceMotion || ticketStamped ? 1.0 : 1.06)
                    .opacity(ticketVisible ? 1 : 0)
                    .animation(
                        reduceMotion ? nil
                            : .spring(response: 0.28, dampingFraction: 0.72),
                        value: ticketStamped
                    )

                // Reassurance - quiet line just below the ticket
                // Heart: U+FE0E text-presentation selector forces a text
                // glyph (not the red emoji). Palette.accent = dusty rose
                // #C4677A. NOT red.
                (Text("we'll be here ")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundStyle(Palette.textSecondary.opacity(0.72))
                + Text("\u{2665}\u{FE0E}")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundStyle(Palette.accent))
                .padding(.top, 18)
                .opacity(reduceMotion ? 1 : (reassuranceVisible ? 1 : 0))

                // Bottom flex spacer - fills space above docked CTA
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Corner cluster: top-trailing, bounded 90pt diameter, never
            // overlapping centered copy. ZStack placement keeps it entirely
            // out of the VStack flow so no vertical space is reserved for it.
            VStack {
                HStack {
                    Spacer()
                    EarnedStickerCluster(
                        animate: clusterAnimated,
                        stickers: [.flower3D, .heartGlossy, .sparkleGlossy],
                        diameter: 90
                    )
                    .padding(.top, 12)
                    .padding(.trailing, 8)
                    .allowsHitTesting(false)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "continue", action: {
                ActivationHaptics.shared.commit()
                onContinue()
            })
            .opacity(ctaVisible ? 1 : 0)
        }
        .task {
            ActivationHaptics.shared.prepare()

            // Cluster blooms first (before headline so it reads as ambient)
            clusterAnimated = true

            // Headline fades + rises in
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.4)) { heroVisible = true }

            // Ticket appears then stamps in - fire haptic on the stamp landing
            try? await Task.sleep(for: .milliseconds(380))
            ticketVisible = true
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                ticketStamped = true
            }
            // "Sealed" haptic fires as the stamp settles (~250ms into the spring)
            try? await Task.sleep(for: .milliseconds(180))
            ActivationHaptics.shared.commit()

            // Reassurance fades in after the ticket is settled
            try? await Task.sleep(for: .milliseconds(140))
            withAnimation(.easeOut(duration: 0.35)) { reassuranceVisible = true }

            // CTA appears last - a beat after the reassurance
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 0.35)) { ctaVisible = true }
        }
    }

    // MARK: - Sealed-promise ticket

    // Premium hairline-bordered ticket card holding the user's own promise
    // words. Thin cocoa border (0.75pt - the "clinical" weight, see
    // HairlineRule). A dusty-rose heart seal above a hairline divider
    // marks the commitment. Generous padding signals the luxury register.
    private var sealedTicket: some View {
        VStack(spacing: 0) {
            // Heart seal - dusty rose, text glyph via U+FE0E, not red emoji
            Text("\u{2665}\u{FE0E}")
                .font(.custom("DMSans-Regular", size: 18))
                .foregroundStyle(Palette.accent)

            // Thin hairline divider under the seal
            HairlineRule()
                .frame(width: 36)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Promise sentence - the user's own words
            Text("tomorrow, \(anchor),\nyou'll \(action).")
                .font(.custom("DMSans-Regular", size: 16))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 28)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                // bgElevated (#FFFAF8) lifts the ticket off the bgPrimary
                // (#FDF6F4) GrainfieldBackground so the hairline border reads.
                // Same separation used by the kept-promise card in PlanView.
                .fill(Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Palette.hairlineCocoa, lineWidth: 0.75)
        )
        .shadow(color: Palette.cocoaPrimary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}
