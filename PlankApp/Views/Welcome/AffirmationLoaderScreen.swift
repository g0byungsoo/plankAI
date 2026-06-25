import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Shown while AuthService.bootstrap() runs on every app launch for
// returning users; parent unmounts when auth.isReady && entitlement
// resolves. Can die at ANY moment from ~300ms, so the composition is
// complete at frame 0.
//
// v8.0 — pure cream launch, brand arrives in two beats.
//
// The static iOS launch screen is intentionally just the cream
// LaunchBackground color (no image, no overlay) — the Calm /
// Headspace / Aesop pattern. The cream IS the brand opening note.
// This loader takes over the moment AuthService.bootstrap() starts
// drawing, and resolves the cream into two sequential brand beats:
//
//   beat 1 (60ms after handoff)   — jeni·fit wordmark softens in
//   beat 2 (340ms after handoff)  — her75 affirmation rises beneath
//
// Both beats are ease-out fades, no springs, no pops — the cohort
// research locks "subtle, mindful, slow" motion app-wide. Status bar
// hidden through launch + loader so the brand canvas is uninterrupted.
// Reduce-motion snaps to final state. Failure state preserved.
//
// Why no wordmark on the launch image: we tried pixel-matching a
// PDF-vector launch wordmark to the SwiftUI loader wordmark for an
// "invisible handoff." actool's PDF rasterization vs CoreText runtime
// rendering land ~5pt apart in both position and size, producing a
// visible crossfade artifact mid-handoff. Pure cream + a deliberate
// fade-in is the cleaner premium answer — there's nothing to mismatch.

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var wordmarkVisible = false
    @State private var affirmationVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Loader stays on brand cream (Palette.bgPrimary), even though
            // the static launch screen is pink. The transition pink →
            // cream happens at the launch-screen-to-loader handoff; the
            // cream then carries into MainTabView seamlessly.
            Palette.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                wordmark
                    .padding(.top, 24)
                Spacer()
                affirmation
                    .padding(.horizontal, 32)
                Spacer()
                // Visual ballast — keeps the affirmation slightly
                // above geometric center so the negative space below
                // breathes. The luxury pattern: text lands in the
                // upper-third optical center, never dead-center.
                Color.clear.frame(height: 80)
            }

            if case .failed = state {
                VStack {
                    Spacer()
                    failureContent
                        .padding(.bottom, 60)
                }
            }
        }
        .statusBarHidden(true)
        .onAppear { animateIn() }
    }

    // MARK: - Wordmark

    @ViewBuilder
    private var wordmark: some View {
        (Text("jeni").font(.custom("Fraunces72pt-SemiBold", size: 17))
         + Text("\u{2009}·\u{2009}").font(.custom("Fraunces72pt-Light", size: 14))
         + Text("fit").font(.custom("Fraunces72pt-SemiBold", size: 17)))
            .foregroundStyle(Palette.textPrimary)
            .opacity(wordmarkVisible ? 1 : 0)
    }

    // MARK: - Affirmation
    //
    // her75 register: regular roman + italic punch words. Single
    // brand-checked line per dayOfYear, so the same day shows the
    // same affirmation — feels intentional, not random.

    // v1.1.2 (2026-06-24) — the affirmation pool moved to the shared
    // `JeniAffirmations` source of truth so the launch loader and the
    // DailyReturnRitual always show the SAME line on a given day (the
    // loader's quick beat is a deliberate callback to the ritual's
    // fuller moment, never a second unrelated line).
    private var todaysAffirmation: JeniAffirmations.Line { JeniAffirmations.today() }

    @ViewBuilder
    private var affirmation: some View {
        let a = todaysAffirmation
        (Text(a.leading).font(.custom("JeniHeroSerif-Regular", size: 44))
         + Text(a.italic).font(.custom("JeniHeroSerif-Italic", size: 44))
         + Text(a.trailing).font(.custom("JeniHeroSerif-Regular", size: 44)))
            .foregroundStyle(Palette.textPrimary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .opacity(affirmationVisible ? 1 : 0)
            .offset(y: affirmationVisible ? 0 : 12)
    }

    // MARK: - Animation
    //
    // Two beats, both ease-out fades, no springs. The wordmark lands
    // first (the brand identity) and the affirmation rises beneath
    // it (the brand voice). The 280ms gap between them is enough for
    // the eye to register beat 1 before beat 2 lands, but tight
    // enough that the whole sequence reads as one composition
    // resolving, not two separate animations.

    private func animateIn() {
        if reduceMotion {
            wordmarkVisible = true
            affirmationVisible = true
            return
        }
        // ~60ms after the handoff: wordmark softens in (500ms ease-out).
        // Slightly faster than v6 so the brand identity lands before
        // the eye has time to read the cream as "blank."
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeOut(duration: 0.5)) {
                wordmarkVisible = true
            }
        }
        // ~340ms: affirmation rises 12pt and fades in (900ms ease-out).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.9)) {
                affirmationVisible = true
            }
        }
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
