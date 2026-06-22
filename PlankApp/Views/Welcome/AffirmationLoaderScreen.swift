import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Shown while AuthService.bootstrap() runs on every app launch for
// returning users; parent unmounts when auth.isReady && entitlement
// resolves. Can die at ANY moment from ~300ms, so the composition is
// complete at frame 0.
//
// v5.2 — heart pulse.
//
// The composition is fully baked into LaunchStickers@3x.png (pink
// ground + sticker collage + jeni·fit wordmark + "Hi ♡" speech
// bubble + "you made it!" hero). The static iOS launch screen
// renders this via Info.plist UILaunchScreen.UIImageName with
// UIImageRespectsSafeAreaInsets = true. This view mirrors that
// exactly — same color, same image, same fit — so the handoff is
// pixel-invisible.
//
// ONE motion moment: the pink heart inside the "Hi ♡" speech
// bubble gently pulses (1.0 → 1.15 → 1.0 over 1.6s, repeats).
// A SwiftUI heart layer sits over the baked one at the same
// position; when it scales, the eye reads it as the heart
// breathing. Reduce-motion snaps to static. No other motion;
// background composition stays still.

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var heartScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Image intrinsic size + heart position in image coords
    // (sampled from LaunchStickers@3x.png — heart center pixel
    // (450, 770) of (1290, 2796), heart diameter ~70px).
    private static let imageSize: CGSize = CGSize(width: 1290, height: 2796)
    private static let heartCenterInImage: CGPoint = CGPoint(x: 450, y: 770)
    private static let heartDiameterInImage: CGFloat = 80

    var body: some View {
        ZStack {
            // 1. Pink ground — exact match to the LaunchBackground
            //    color asset the static launch screen draws.
            Color("LaunchBackground")
                .ignoresSafeArea()

            // 2. Full baked composition + the heart-pulse overlay.
            //    .aspectRatio(.fill) + .clipped() matches the static
            //    launch screen's behavior: image fills the safe-area
            //    width edge-to-edge, vertical overflow clipped (no
            //    pink margins). The launch screen renders the image
            //    at native @3x size within the safe area; on phones
            //    whose aspect doesn't exactly match the image, the
            //    overflow direction is the same here as it is there.
            GeometryReader { geo in
                let bounds = filledImageBounds(in: geo.size)
                let heart = heartFrame(in: bounds)

                Image("LaunchStickers")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .accessibilityHidden(true)

                Image(systemName: "heart.fill")
                    .resizable()
                    .frame(width: heart.size, height: heart.size)
                    .foregroundStyle(Color(red: 0xC8 / 255.0, green: 0x79 / 255.0, blue: 0x7E / 255.0))
                    .scaleEffect(heartScale)
                    .position(x: heart.center.x, y: heart.center.y)
                    .accessibilityHidden(true)
            }

            if case .failed = state {
                VStack {
                    Spacer()
                    failureContent
                        .padding(.bottom, 60)
                }
            }
        }
        .onAppear { startPulse() }
    }

    // MARK: - Heart pulse

    private func startPulse() {
        guard !reduceMotion else { return }
        // 1.6s cycle, ease in/out, repeats forever while the loader
        // is mounted. The 1.15× peak is enough to read as a beat
        // without the SwiftUI heart visibly diverging from the
        // baked one underneath.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                heartScale = 1.15
            }
        }
    }

    // MARK: - Image-coord projection

    /// Bounds of the image once .aspectRatio(.fill)+.clipped() has
    /// scaled it to cover the container. In fill mode, ONE dimension
    /// matches the container exactly and the other overflows on both
    /// sides (negative origin in the overflowing axis). The heart
    /// projection uses these bounds so the SwiftUI overlay stays on
    /// top of the baked heart even when part of the image is clipped.
    private func filledImageBounds(in containerSize: CGSize) -> CGRect {
        let imgAspect = Self.imageSize.width / Self.imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        let imageSize: CGSize
        if containerAspect > imgAspect {
            // Container wider than image — scale to fill width,
            // vertical overflow.
            imageSize = CGSize(width: containerSize.width, height: containerSize.width / imgAspect)
        } else {
            // Container taller-relative than image — scale to fill
            // height, horizontal overflow.
            imageSize = CGSize(width: containerSize.height * imgAspect, height: containerSize.height)
        }
        return CGRect(
            x: (containerSize.width - imageSize.width) / 2,
            y: (containerSize.height - imageSize.height) / 2,
            width: imageSize.width,
            height: imageSize.height
        )
    }

    private func heartFrame(in imageBounds: CGRect) -> (center: CGPoint, size: CGFloat) {
        let xRatio = Self.heartCenterInImage.x / Self.imageSize.width
        let yRatio = Self.heartCenterInImage.y / Self.imageSize.height
        let sizeRatio = Self.heartDiameterInImage / Self.imageSize.width
        return (
            center: CGPoint(
                x: imageBounds.minX + xRatio * imageBounds.width,
                y: imageBounds.minY + yRatio * imageBounds.height
            ),
            size: sizeRatio * imageBounds.width
        )
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
