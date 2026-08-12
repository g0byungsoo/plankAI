import SwiftUI

// MARK: - BreathworkPrimerView
//
// The "before we move" education screen between Jeni's welcome and the
// breath session. Per the breathwork-science research synthesis
// (2026-05-27), this makes ONE honest claim — breathwork helps weight
// loss indirectly via stress regulation, NOT by burning fat — and backs
// it with the strongest available citation (Balban et al. 2023, Stanford,
// Cell Reports Medicine, n=111). The data-provenance rule (CLAUDE.md)
// forbids overclaiming; the credibility moat is being the brand that
// doesn't.
//
// Two paths (option C per product decision):
//   "yes, let's breathe" → onBreathe()  → BreathworkSessionView
//   "skip to workout"     → onSkip()      → straight to workout
//
// Coach portrait carries parasocial continuity (Jeni is teaching this);
// smaller than CoachIntroView's hero since this is a secondary beat.

struct BreathworkPrimerView: View {
    let onBreathe: () -> Void
    let onSkip: () -> Void

    @AppStorage("voicePreference") private var storedVoice: String = "encouraging"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var coachVisible = false
    @State private var eyebrowVisible = false
    @State private var headlineVisible = false
    @State private var bodyVisible = false
    @State private var ctaVisible = false

    var body: some View {
        // Background + sticker scatter lifted to PostPurchaseFlowView so
        // they stay stable across phase swaps (was the flicker cause).
        ZStack {
            // Scrollable content above a pinned CTA. The educational copy
            // is longer than CoachIntroView's (it's explaining a
            // mechanism), so the scroll guarantees nothing hides behind
            // the button on smaller screens — fixes the prior overflow.
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: Space.lg)

                        coachPortrait
                            .padding(.bottom, Space.md)

                        Text("DAY 1 · BEFORE WE MOVE")
                            .font(Typo.eyebrow)
                            .tracking(1.6)
                            .foregroundStyle(Palette.accent)
                            .opacity(eyebrowVisible ? 1 : 0)
                            .offset(y: eyebrowVisible ? 0 : 6)
                            .padding(.bottom, Space.sm)

                        // v8 P8.6 — replaces the Cal-AI-coded "did you know
                        // weight loss?" hook. Post-Ozempic copy rule kills
                        // direct weight-loss framing here. The citation
                        // blocks below still carry the science substance.
                        ItalicAccentText("breath does more than you think.",
                                         italic: ["more"],
                                         baseFont: headlineFont,
                                         italicFont: headlineItalicFont,
                                         color: Palette.textPrimary,
                                         alignment: .center)
                            .padding(.horizontal, Space.lg)
                            .opacity(headlineVisible ? 1 : 0)
                            .offset(y: headlineVisible ? 0 : 8)
                            .padding(.bottom, Space.lg)

                        bodyBlock
                            .padding(.horizontal, Space.lg)
                            .opacity(bodyVisible ? 1 : 0)
                            .offset(y: bodyVisible ? 0 : 8)

                        Spacer().frame(height: Space.lg)
                    }
                }

                ctaStack
                    .opacity(ctaVisible ? 1 : 0)
                    .offset(y: ctaVisible ? 0 : 12)
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.sm)
                    .padding(.bottom, Space.xl)
            }
        }
        .onAppear {
            Analytics.captureScreen("BreathworkPrimer")
            Analytics.track(.breathworkPrimerViewed)
            if reduceMotion { runReducedMotion() } else { runChoreography() }
        }
    }

    // MARK: - Sections

    private var coachPortrait: some View {
        Image(coachAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay(Circle().stroke(Palette.accentSubtle, lineWidth: 4))
            .scaleEffect(coachVisible ? 1 : 0.6)
            .opacity(coachVisible ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.78), value: coachVisible)
            .accessibilityHidden(true)
    }

    private var bodyBlock: some View {
        VStack(spacing: Space.md) {
            // v25 E8.1 — THE CLAIMS, CUT BACK TO WHAT THE EVIDENCE CARRIES.
            //
            // This block used to assert a chain: breathing lowers
            // cortisol, cortisol is what tells the body to hold on to
            // fat, therefore breathing helps you let go of it. The first
            // step has trial support. The second and third do not, and
            // together they are a mechanistic claim about fat storage
            // this product has no business making. It also carried a
            // paragraph about fat leaving the body as carbon dioxide,
            // which was true, surprising, and doing no work except
            // setting up the claim that followed it.
            //
            // What replaced it is the mechanism that IS supported and
            // happens to be the actual job of this tool: a long exhale
            // shortens the urge you are standing in right now.
            Text("this is not a fat-burning exercise. nothing you do with your breath moves fat.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            ItalicAccentText("it is for the ten minutes you are standing in.",
                             italic: ["standing in"],
                             baseFont: bodyEmphasisFont,
                             italicFont: bodyEmphasisItalicFont,
                             color: Palette.textPrimary,
                             alignment: .center)

            // The urge-management finding, which is the most on-point
            // evidence there is for a weight-management product: a
            // breathing pattern with a longer out-breath than in-breath,
            // measured against food craving and impulsivity in people
            // with obesity.
            VStack(spacing: Space.xs) {
                Text("breathing out for longer than you breathe in lowered food craving and impulsiveness in a trial with people carrying extra weight. a craving is a wave with a shape, and this changes the shape.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("complementary medicine research (2024) \u{00B7} prolonged-exhale breathing, food craving and impulsivity")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Space.xs) {
                Text("five minutes a day of breathwork beat meditation for stress and mood, in a stanford trial.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("balban et al., cell reports medicine (2023) \u{00B7} n=111")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            ItalicAccentText("one minute. it is the shortest useful thing in here.",
                             italic: ["shortest useful thing"],
                             baseFont: bodyEmphasisFont,
                             italicFont: bodyEmphasisItalicFont,
                             color: Palette.textPrimary,
                             alignment: .center)
        }
    }

    private var bodyEmphasisFont: Font {
        Font.custom("Fraunces72pt-SemiBold", size: 18, relativeTo: .body)
    }
    private var bodyEmphasisItalicFont: Font {
        Font.custom("Fraunces72pt-SemiBoldItalic", size: 18, relativeTo: .body)
    }

    private var ctaStack: some View {
        VStack(spacing: Space.sm) {
            JFContinueButton(
                label: "one minute with me",
                action: {
                    Analytics.track(.breathworkPrimerContinued)
                    onBreathe()
                }
            )

            Button {
                Haptics.light()
                Analytics.track(.breathworkPrimerSkipped)
                onSkip()
            } label: {
                Text("skip to workout")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, Space.xs)
        }
    }

    // MARK: - Coach lookup

    private var coachAssetName: String {
        switch storedVoice {
        case "balanced":   return "coach-matson"
        case "keepItReal": return "coach-kira"
        default:           return "coach-jeni"
        }
    }

    // MARK: - Typography

    // v3 P11.6 (2026-06-10) — promoted to heroHeadline 42pt per the
    // locked typography ladder ([[feedback-hero-typography-ladder]]).
    // BreathworkPrimer is a post-purchase hero beat (sits between
    // CoachIntro and BreathworkSession in PostPurchaseFlowView),
    // belongs on the default hero ladder. Was bumped from 28pt →
    // questionHero in v9 P9.7; this pass takes it the rest of the way.
    private var headlineFont: Font { Typo.heroHeadline }
    private var headlineItalicFont: Font { Typo.heroHeadlineItalic }

    // MARK: - Choreography

    private func runChoreography() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.15)) { coachVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(0.45)) { eyebrowVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(0.70)) { headlineVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(1.05)) { bodyVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(1.45)) { ctaVisible = true }
    }

    private func runReducedMotion() {
        coachVisible = true
        eyebrowVisible = true
        headlineVisible = true
        bodyVisible = true
        ctaVisible = true
    }
}

#if DEBUG
#Preview {
    let _ = { UserDefaults.standard.set("encouraging", forKey: "voicePreference") }()
    return BreathworkPrimerView(onBreathe: {}, onSkip: {})
}
#endif
