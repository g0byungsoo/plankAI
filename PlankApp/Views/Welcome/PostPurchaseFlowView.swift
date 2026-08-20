import SwiftUI

// MARK: - PostPurchaseFlowView
//
// Orchestrates the post-purchase sequence inside a SINGLE fullScreenCover
// so transitions between steps are smooth cross-fades (.opacity) rather
// than iOS's default cover slide. Each child view handles its own content
// + audio; this container only owns the phase state and the routing.
//
// Flow (pass 52 — THE FIRST DAY):
//   forging -> coachIntro -> [promiseConfirmation] -> finish
//
// Task 10 (2026-06-28): if promiseAction + promiseAnchor are both set,
// the corridor replays her own oath once before finish. The breathwork
// primer/session detour left the corridor in pass 52 — the activation
// minute belongs to the first record, and breathe stays one tap away
// on Home's tools.
//
// Rating ask: the App Store rating ask sits pre-paywall in OnboardingRevealView
// (case .ratingAsk, right after firstWeek). Post-purchase is the wrong moment
// for a rating ask - the user has just spent money and is in the program
// activation flow. Pre-paywall at the plan-reveal high is the correct placement.
//
// `onFinish` is the single exit; the caller dismisses the cover and the
// user lands on the Today tab's program onramp. The old ForceFirstAction
// picker is retired - both of its choices routed into legacy-HomeView
// flags, and the onramp -> PlanView checklist is the activation surface.

// MARK: - PostPurchaseCorridor (pass 52 — THE FIRST DAY)
//
// The corridor's routing as a pure table, so the first minutes after a
// purchase are table-testable (FirstDayActivationTests). The view
// reads THIS; there is no second copy of the route.
enum PostPurchaseCorridor {
    enum Beat: Equatable {
        case forging
        case coachIntro
        case promiseConfirmation
        case finish
    }

    /// Where the corridor goes after `beat`. `hasPromise` is the
    /// consult's own oath (the day-1 promise keys). The breathwork
    /// primer left this corridor in pass 52: a teaching detour in the
    /// activation minute, promising "skip to workout" on a build with
    /// no workout next. Breathwork itself stays one tap away on Home's
    /// own tools ("breathe").
    static func next(after beat: Beat, hasPromise: Bool) -> Beat {
        switch beat {
        case .forging: return .coachIntro
        case .coachIntro:
            return hasPromise ? .promiseConfirmation : .finish
        case .promiseConfirmation, .finish: return .finish
        }
    }
}

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
        case promiseConfirmation   // Task 10 (2026-06-28)
    }

    private var hasPromise: Bool {
        promiseAction?.isEmpty == false && promiseAnchor?.isEmpty == false
    }

    /// The one routing authority (pinned by FirstDayActivationTests).
    private func advance(from beat: PostPurchaseCorridor.Beat) {
        switch PostPurchaseCorridor.next(after: beat, hasPromise: hasPromise) {
        case .forging:             transition(to: .forging)
        case .coachIntro:          transition(to: .coachIntro)
        case .promiseConfirmation: transition(to: .promiseConfirmation)
        case .finish:              onFinish()
        }
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
            // Pass 52 (founder steer, filmed): the corridor wore the
            // v3-era welcome canvas — pink program ground + glossy
            // sticker scatter — two eras behind the design law. The
            // corridor is a MOMENT (law §1.1b): editorial serif on the
            // one paper ground, nothing scattered over it. The shared
            // canvas stays lifted here so phase swaps still cross-fade
            // over a stable ground (the original reason it was hoisted).
            Palette.bgPrimary.ignoresSafeArea()

            switch phase {
            case .forging:
                ForgingRevealView(onContinue: {
                    advance(from: .forging)
                })
                .transition(.opacity)

            case .coachIntro:
                // Pass 52 — the coach's close is the HANDOFF: the next
                // beat is the product itself. The breathwork primer that
                // used to stand here promised "skip to workout" on a
                // build whose first action is a sentence; breathe lives
                // on Home's tools now, one tap away, un-skipped.
                CoachIntroView(onContinue: {
                    advance(from: .coachIntro)
                })
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
                Text("we'll be here.")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundStyle(Palette.textSecondary.opacity(0.72))
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
            // The brand seal — the mark in ink, per the one-colour law.
            JeniMark(height: 16)

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
