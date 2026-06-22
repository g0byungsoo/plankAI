import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Shown while AuthService.bootstrap() runs on every app launch for
// returning users; parent unmounts when auth.isReady && entitlement
// resolves. Can die at ANY moment from ~300ms, so the composition is
// complete at frame 0.
//
// v6.0 — clean-slate minimalist typography.
//
// The static iOS launch screen is now just the cream
// LaunchBackground color (no image, no overlay) with the status bar
// hidden. This view inherits the same cream and adds the brand
// composition: small jeni·fit wordmark at the top, a single her75
// affirmation centered in the page. The wordmark and affirmation
// fade in sequentially after the static-to-live handoff lands —
// the only motion in the experience.
//
// No safe-area gymnastics, no image positioning math, no overlay
// alignment risk. Pure SwiftUI typography in registered fonts.
// Status bar hidden through launch + loader so the brand canvas is
// uninterrupted (Calm/Headspace/Linear pattern). Reduce-motion snaps
// to final state. Failure state preserved.

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var wordmarkVisible = false
    @State private var affirmationVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
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

    private struct Affirmation {
        let leading: String     // regular
        let italic: String      // JeniHeroSerif-Italic punch
        let trailing: String    // regular
    }

    private static let affirmations: [Affirmation] = [
        Affirmation(leading: "you are ", italic: "becoming",  trailing: " her."),
        Affirmation(leading: "soft ",    italic: "is",        trailing: " strong."),
        Affirmation(leading: "your ",    italic: "timeline",  trailing: " is yours."),
        Affirmation(leading: "begin ",   italic: "again",     trailing: ", anytime."),
        Affirmation(leading: "small ",   italic: "choices",   trailing: " stack."),
        Affirmation(leading: "kindness ",italic: "is",        trailing: " the strategy."),
        Affirmation(leading: "she is ",  italic: "already",   trailing: " in you."),
    ]

    private var todaysAffirmation: Affirmation {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let idx = (day - 1) % Self.affirmations.count
        return Self.affirmations[max(0, idx)]
    }

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

    private func animateIn() {
        if reduceMotion {
            wordmarkVisible = true
            affirmationVisible = true
            return
        }
        // ~80ms after the handoff: wordmark softens in (450ms ease-out).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.45)) {
                wordmarkVisible = true
            }
        }
        // ~350ms: affirmation rises 12pt and fades in (800ms ease-out).
        // The sequence reads as: brand identity arrives → brand voice
        // arrives. Two beats, both calm, one motion moment per phrase.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.8)) {
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
