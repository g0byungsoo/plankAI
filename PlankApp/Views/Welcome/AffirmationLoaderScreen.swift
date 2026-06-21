import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Shown while AuthService.bootstrap() runs on every app launch for
// returning users; parent unmounts when auth.isReady && entitlement
// resolves. Can die at ANY moment from ~300ms, so the composition is
// complete at frame 0.
//
// v5.1 — all-baked composition.
//
// The founder finalized the launch screen as a single static
// composition: pink ground + sticker collage + jeni·fit wordmark
// + "Hi ♡" speech bubble + "you made it!" hero, all baked into
// LaunchStickers@3x.png.
//
// The static iOS launch screen renders this image via Info.plist
// UILaunchScreen.UIImageName with UIImageRespectsSafeAreaInsets =
// true — so the whole composition fits inside the safe area
// (wordmark stays clear of the notch). This view mirrors that
// behavior exactly: same color asset behind, same image fit to
// safe-area bounds. Pixel-identical handoff.
//
// No animation, no text overlay — the image is the entire
// composition. Per the founder direction: simple and beautiful
// beats clever-and-animated. The failure state is preserved for
// bootstrap retries.

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            // 1. Pink ground — exact match to the LaunchBackground
            //    color asset the static launch screen draws. Also
            //    matches the pink baked into the image, so any
            //    safe-area margin blends invisibly.
            Color("LaunchBackground")
                .ignoresSafeArea()

            // 2. The full composition — fit within safe area to
            //    match Info.plist UIImageRespectsSafeAreaInsets =
            //    true. Same image, same fit, same insets → zero
            //    visible jump from the static launch frame.
            Image("LaunchStickers")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .accessibilityHidden(true)

            if case .failed = state {
                VStack {
                    Spacer()
                    failureContent
                        .padding(.bottom, 60)
                }
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
