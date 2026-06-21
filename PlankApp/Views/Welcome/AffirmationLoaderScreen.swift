import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Shown while AuthService.bootstrap() runs on every app launch for
// returning users; parent unmounts when auth.isReady && entitlement
// resolves. Can die at ANY moment from ~300ms, so the composition is
// complete at frame 0.
//
// v5.0 — match-native + animated her75 affirmation.
//
// The iOS launch screen draws LaunchStickers at NATIVE @3x size,
// centered on screen (UILaunchScreen.UIImageRespectsSafeAreaInsets
// = false). It does NOT scale the image. To get an invisible
// handoff, this view renders the same image WITHOUT any
// `.resizable()` / `.aspectRatio()` modifiers — so SwiftUI also
// shows the image at its native @3x size, centered. Same bitmap,
// same size, same position → zero visible jump.
//
// The background image stays still (no scale, no breath). The only
// motion moment is the her75 affirmation softly fading in over the
// empty middle of the composition. Per the founder direction:
// background still, text in the empty space transitions in.
//
// Failure state preserved.

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var textVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // 1. Pink ground — exact match to the LaunchBackground
            //    color asset the static launch screen draws.
            Color("LaunchBackground")
                .ignoresSafeArea()

            // 2. Sticker + wordmark composite at NATIVE @3x size,
            //    centered. No .resizable / no aspectRatio — that's
            //    what makes the size match iOS's launch screen
            //    pixel-for-pixel.
            Image("LaunchStickers")
                .accessibilityHidden(true)

            // 3. Affirmation text in the empty middle space.
            //    Positioned by a fixed offset from screen center —
            //    image is at native @3x size centered, so the
            //    image's empty middle (image-y ~1200/3 = 400pt)
            //    lands at screen-center-y - 66 regardless of
            //    device. her75 register: regular + italic punch
            //    line, no subtitle.
            GeometryReader { geo in
                VStack(spacing: 6) {
                    Text("you are")
                        .font(.custom("JeniHeroSerif-Regular", size: 56))
                    Text("becoming her.")
                        .font(.custom("JeniHeroSerif-Italic", size: 68))
                }
                .foregroundStyle(Color(red: 0x3D/255.0, green: 0x2A/255.0, blue: 0x2A/255.0))
                .multilineTextAlignment(.center)
                .opacity(textVisible ? 1 : 0)
                .offset(y: textVisible ? 0 : 14)
                .position(x: geo.size.width / 2, y: geo.size.height / 2 - 66)
                .allowsHitTesting(false)
            }

            if case .failed = state {
                VStack {
                    Spacer()
                    failureContent
                        .padding(.bottom, 60)
                }
            }
        }
        .onAppear { animateTextIn() }
    }

    // MARK: - Animation

    private func animateTextIn() {
        if reduceMotion {
            textVisible = true
            return
        }
        // ~120ms after appear (one perceptual breath after the
        // static-to-live handoff), the affirmation softens in
        // over 700ms with a 14pt slide-up. No background motion,
        // no cascade — one moment, ends.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.7)) {
                textVisible = true
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
