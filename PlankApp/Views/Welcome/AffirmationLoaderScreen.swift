import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Shown while AuthService.bootstrap() runs on every app launch for
// returning users; parent unmounts when auth.isReady && entitlement
// resolves. Can die at ANY moment from ~300ms, so the composition is
// complete at frame 0.
//
// v4.8 — fully baked launch composition.
// All composition (pink ground + sticker collage + jeni·fit wordmark
// + her75 affirmation in the empty middle) is baked into the
// LaunchStickers PNG. The static iOS launch screen renders it via
// Info.plist UILaunchScreen.UIImageName at FULL BLEED
// (UIImageRespectsSafeAreaInsets=false). This view mirrors that
// exact composition: same color asset, same image asset, same
// .fit aspect, full bleed via .ignoresSafeArea. Pixel-identical to
// the static launch screen → invisible handoff.
//
// No SwiftUI text on top — the affirmation lives in the image. A
// single ambient breath layer (1.04×, repeats, reduce-motion gated)
// adds the only motion moment so the static-to-live transition has
// a subtle pulse of life. The failure state is preserved.

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // 1. Pink ground — exact match to the LaunchBackground
            //    color asset the static launch screen draws.
            Color("LaunchBackground")
                .ignoresSafeArea()

            // 2. Sticker + wordmark + affirmation composite —
            //    identical bitmap to the one iOS draws on launch.
            //    Full bleed (.ignoresSafeArea) + aspect-fit so it
            //    matches Info.plist UIImageRespectsSafeAreaInsets=false
            //    behavior pixel-for-pixel.
            Image("LaunchStickers")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(breathing ? 1.04 : 1.0)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            if case .failed = state {
                VStack {
                    Spacer()
                    failureContent
                        .padding(.bottom, 60)
                }
            }
        }
        .onAppear { startBreath() }
    }

    // MARK: - Animation

    private func startBreath() {
        guard !reduceMotion else { return }
        // Ambient sticker breath — gentle, 1.04× over ~4s, repeats.
        // Per the clean-luxury north star: one almost-imperceptible
        // ambient. The handoff is otherwise still — the only thing
        // that changes from launch frame 0 is this subtle pulse.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                breathing = true
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
