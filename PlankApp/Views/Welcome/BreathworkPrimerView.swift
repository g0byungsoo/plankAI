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

    @State private var bgVisible = false
    @State private var coachVisible = false
    @State private var eyebrowVisible = false
    @State private var headlineVisible = false
    @State private var bodyVisible = false
    @State private var ctaVisible = false

    var body: some View {
        ZStack {
            Palette.bgPrimary
                .ignoresSafeArea()
                .opacity(bgVisible ? 1 : 0)

            // y2k coquette scatter — teacup (morning ritual), sparkle,
            // soft heart hugging the margins behind the content.
            StickerScatter(placements: StickerScatter.breathworkPrimerDefault())
                .opacity(bgVisible ? 1 : 0)
                .allowsHitTesting(false)

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

                        ItalicAccentText("did you know breath can help your weight loss?",
                                         italic: ["weight loss"],
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
            // The honest disclaimer up front — naming the myth builds
            // trust before the real mechanism lands.
            Text("not by burning fat. that's a myth.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            // The mechanism, stated as a logical chain with the real
            // terms (cortisol, parasympathetic) so it reads as science,
            // not vibes. Jeni translates each term casually so it stays
            // in voice rather than turning into a textbook.
            ItalicAccentText("the real lever is cortisol, your stress hormone.",
                             italic: ["cortisol"],
                             baseFont: bodyEmphasisFont,
                             italicFont: bodyEmphasisItalicFont,
                             color: Palette.textPrimary,
                             alignment: .center)

            VStack(spacing: Space.xs) {
                Text("when stress keeps cortisol high, your body holds onto fat. yale found it hits women hardest, right around the middle.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("epel et al., yale · cortisol & abdominal fat in women")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Text("slow breathing flips on your parasympathetic system, your body's \u{201C}rest and digest\u{201D} mode. cortisol comes down. and the cravings that were never really hunger come down with it.")
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            // Option B — the honest CO₂ hook. Uses the genuinely surprising
            // fact (fat leaves as CO₂, Meerman & Brown 2014 BMJ), then
            // immediately corrects the myth it usually gets twisted into.
            // Being the brand that says \"but that doesn't mean what you
            // think\" is itself the trust signal.
            VStack(spacing: Space.xs) {
                Text("here's the wild part. when you actually lose fat, most of it leaves through your breath, as carbon dioxide. real biochemistry. but breathing harder won't burn it. your body decides when to let go. breath just lowers the cortisol telling it to hold on.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("meerman & brown, bmj (2014) · where fat goes when you lose it")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Space.xs) {
                Text("five minutes a day of breathwork beat meditation for stress and mood, in a stanford trial.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text("balban et al., cell reports medicine (2023) · n=111")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            ItalicAccentText("breath won't melt fat. it clears the cortisol quietly working against you.",
                             italic: ["working against you"],
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
            Button {
                Haptics.medium()
                Analytics.track(.breathworkPrimerContinued)
                onBreathe()
            } label: {
                Text("one minute with me")
            }
            .buttonStyle(.ctaPrimary)

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

    private var headlineFont: Font {
        Font.custom("Fraunces72pt-SemiBold", size: 28, relativeTo: .title2)
    }
    private var headlineItalicFont: Font {
        Font.custom("Fraunces72pt-SemiBoldItalic", size: 28, relativeTo: .title2)
    }

    // MARK: - Choreography

    private func runChoreography() {
        withAnimation(.easeInOut(duration: 0.7)) { bgVisible = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.15)) { coachVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(0.45)) { eyebrowVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(0.70)) { headlineVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(1.05)) { bodyVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(1.45)) { ctaVisible = true }
    }

    private func runReducedMotion() {
        bgVisible = true
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
