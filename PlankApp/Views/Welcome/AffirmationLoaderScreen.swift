import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Shown while AuthService.bootstrap() runs on every app launch for
// returning users; parent unmounts when auth.isReady && entitlement
// resolves. Can die at ANY moment from ~300ms, so the composition is
// complete at frame 0.
//
// v4.7 — invisible-handoff launch sequence.
// The static iOS launch screen renders the SAME composition (pink
// `LaunchBackground` + centered `LaunchStickers` overlay) the instant
// the user taps the icon. The next frame is this view: pink + the
// SAME sticker image, rendered identically — so the handoff is
// pixel-invisible. Once mounted, the empty middle of the design
// breathes into life: a per-day affirmation cascades in, then a
// subline slides up. Reduce-motion snaps to final.
//
// No wordmark in SwiftUI — the wordmark is baked into the sticker
// image at the top of the canvas. Adding one here would double up.

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var heroVisible = false
    @State private var subVisible = false
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Pink ground — exact match to the LaunchBackground
                //    color asset the static launch screen draws.
                Color("LaunchBackground")
                    .ignoresSafeArea()

                // 2. Sticker overlay — identical bitmap to the one
                //    iOS centered on the static launch screen. Frame
                //    0 of this view = frame N of launch. The optional
                //    ambient breath (1.04x over ~4s) only activates
                //    when reduce-motion is OFF.
                Image("LaunchStickers")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(breathing ? 1.04 : 1.0)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                // 3. Affirmation — anchored in the empty middle zone
                //    (~y 48% of canvas). Center-aligned because the
                //    sticker composition is symmetric around the
                //    vertical axis.
                VStack(spacing: 14) {
                    Spacer().frame(height: geo.size.height * 0.42)

                    affirmationHero
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textPrimary)
                        .kerning(-0.4)
                        .lineSpacing(Typo.heroHeadlineLineGap)
                        .opacity(heroVisible ? 1 : 0)
                        .offset(y: heroVisible ? 0 : 8)

                    affirmationSub
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textSecondary)
                        .opacity(subVisible ? 1 : 0)
                        .offset(y: subVisible ? 0 : 6)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity)

                if case .failed = state {
                    VStack {
                        Spacer()
                        failureContent
                            .padding(.bottom, 60)
                    }
                }
            }
        }
        .onAppear { animateIn() }
    }

    // MARK: - Animation

    private func animateIn() {
        if reduceMotion {
            heroVisible = true
            subVisible = true
            return
        }
        // ~70ms after appear: hero affirmation softens in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(Motion.entranceSoft) {
                heroVisible = true
            }
        }
        // ~450ms: subline rises 6pt and fades.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(Motion.entranceSoft) {
                subVisible = true
            }
        }
        // Ambient sticker breath — gentle, 1.04x over ~4s, repeats.
        // Per the clean-luxury north star: ONE motion moment plus an
        // almost-imperceptible ambient. Never feels busy.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    // MARK: - Affirmation rotation
    //
    // Per-day rotation (dayOfYear % count). Same day = same line —
    // intentional, not gimmicky. Brand-checked: italic punch words
    // only, lowercase casual, no em-dashes, no AI slop.

    private struct Affirmation {
        let hero: String
        let italic: String
        let tail: String
        let sub: String
    }

    private static let affirmations: [Affirmation] = [
        Affirmation(hero: "this is your ", italic: "that girl", tail: " era.",
                    sub: "she's been in you the whole time."),
        Affirmation(hero: "soft ", italic: "is", tail: " strong.",
                    sub: "you don't have to push."),
        Affirmation(hero: "you are ", italic: "becoming", tail: " her.",
                    sub: "every quiet choice counts."),
        Affirmation(hero: "your timeline ", italic: "is yours", tail: ".",
                    sub: "not 75 days. not 90. yours."),
        Affirmation(hero: "begin ", italic: "again", tail: ", anytime.",
                    sub: "the door is never closed."),
        Affirmation(hero: "small choices ", italic: "stack", tail: ".",
                    sub: "today's plate, today's lesson."),
        Affirmation(hero: "kindness ", italic: "is", tail: " the strategy.",
                    sub: "warmth converts, shame doesn't."),
    ]

    private var todaysAffirmation: Affirmation {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let idx = (day - 1).quotientAndRemainder(dividingBy: Self.affirmations.count).remainder
        return Self.affirmations[max(0, idx)]
    }

    @ViewBuilder
    private var affirmationHero: some View {
        let a = todaysAffirmation
        Text(a.hero).font(Typo.heroHeadline)
            + Text(a.italic).font(Typo.heroHeadlineItalic)
            + Text(a.tail).font(Typo.heroHeadline)
    }

    @ViewBuilder
    private var affirmationSub: some View {
        let a = todaysAffirmation
        Text(a.sub).font(.custom("DMSans-Regular", size: 15))
    }

    // MARK: - Failure state (preserved from prior version)

    @ViewBuilder
    private var failureContent: some View {
        VStack(spacing: Space.md) {
            (
                Text("couldn't ").font(.custom("Fraunces72pt-SemiBold", size: 18)) +
                Text("connect.").font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
            )
            .foregroundStyle(Palette.textPrimary)

            Text(failureMessage)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)

            Button(action: onRetry) {
                Text("try again")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                    .foregroundStyle(Palette.textInverse)
                    .frame(width: 160, height: 44)
                    .background(Palette.bgInverse)
                    .clipShape(Capsule())
            }
            .padding(.top, Space.xs)
        }
        .padding(.horizontal, Space.lg)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.bgPrimary.opacity(0.92))
                .padding(-12)
        )
    }

    private var failureMessage: String {
        if case .failed(let message) = state { return message }
        return ""
    }
}

#Preview("Running") {
    AffirmationLoaderScreen(state: .running, onRetry: {})
}

#Preview("Failed") {
    AffirmationLoaderScreen(
        state: .failed("Make sure you're connected to the internet, then try again."),
        onRetry: {}
    )
}
