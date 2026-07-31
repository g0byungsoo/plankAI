import SwiftUI

// MARK: - OV5WelcomeCollage (round 3 — the demo invitation)
//
// Founder direction (2026-07-02, round 2 review): the device-frame
// demo IS the first impression — the app selling itself in miniature
// (daily plan · snap camera with his real plate · steps), over the
// headline he approved. Composition stays radically quiet around it:
// wordmark, the device, two cascade lines, the CTA, and five small
// sticker accents at the edges (welcome is earned-moment #1 — accents,
// never a collage; round 1's eleven-cutout mood board is dead).

struct OV5WelcomeCollage: View {
    let onBegin: () -> Void
    let onSignIn: () -> Void

    @State private var wordmarkIn = false
    @State private var deviceIn = false
    @State private var line1In = false
    @State private var line2In = false
    @State private var ctaIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Edge accents — small, cropped-feeling, never central.
                StickerScatter(placements: [
                    StickerPlacement(sticker: .starLineart,
                                     position: CGPoint(x: 0.93, y: 0.075),
                                     size: 26, rotation: 12, phaseDelay: 0.9),
                    StickerPlacement(sticker: .sparkleGlossy,
                                     position: CGPoint(x: 0.965, y: 0.16),
                                     size: 24, rotation: -8, phaseDelay: 1.05),
                    StickerPlacement(sticker: .flower3D,
                                     position: CGPoint(x: 0.955, y: 0.315),
                                     size: 30, rotation: 10, phaseDelay: 1.2),
                    StickerPlacement(sticker: .heartGlossy,
                                     position: CGPoint(x: 0.04, y: 0.42),
                                     size: 24, rotation: -10, phaseDelay: 1.35),
                    StickerPlacement(sticker: .cherries,
                                     position: CGPoint(x: 0.945, y: 0.60),
                                     size: 30, rotation: 9, phaseDelay: 1.5),
                ])
                .opacity(deviceIn ? 1 : 0)

                VStack(spacing: 0) {
                    HStack {
                        JeniWordmark(size: 15)
                        Spacer()
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, 10)
                    .opacity(wordmarkIn ? 1 : 0)

                    Spacer().frame(height: geo.size.height * 0.035)

                    JFDeviceDemoFrame(
                        height: max(330, min(470, geo.size.height * 0.50))
                    )
                    .opacity(deviceIn ? 1 : 0)
                    .scaleEffect(deviceIn || reduceMotion ? 1.0 : 0.97)
                    .offset(y: deviceIn || reduceMotion ? 0 : 10)

                    Spacer().frame(height: geo.size.height * 0.045)

                    // The approved headline — two cascade lines, italic
                    // punch on "simple."
                    VStack(spacing: 0) {
                        ItalicAccentText(
                            "your care plan,",
                            italic: [],
                            baseFont: .custom("JeniHeroSerif-Regular", size: 36),
                            italicFont: .custom("JeniHeroSerif-Italic", size: 36),
                            alignment: .center
                        )
                        .kerning(-0.5)
                        .opacity(line1In ? 1 : 0)
                        .offset(y: line1In || reduceMotion ? 0 : 10)

                        ItalicAccentText(
                            "made around real days.",
                            italic: ["simple."],
                            baseFont: .custom("JeniHeroSerif-Regular", size: 36),
                            italicFont: .custom("JeniHeroSerif-Italic", size: 36),
                            alignment: .center
                        )
                        .kerning(-0.5)
                        .padding(.top, -8)
                        .opacity(line2In ? 1 : 0)
                        .offset(y: line2In || reduceMotion ? 0 : 10)
                    }
                    .padding(.horizontal, Space.lg)

                    Spacer(minLength: Space.md)

                    VStack(spacing: 10) {
                        Button {
                            Haptics.medium()
                            onBegin()
                        } label: {
                            Text("continue")
                                .font(.custom("DMSans-SemiBold", size: 16))
                                .foregroundStyle(Palette.textInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Palette.cocoaPrimary)
                                .clipShape(Capsule())
                                .shadow(color: Palette.cocoaPrimary.opacity(0.18),
                                        radius: 12, x: 0, y: 5)
                        }
                        .buttonStyle(PressFeedbackStyle())

                        Text("free to start.")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundStyle(Palette.textSecondary)

                        Button {
                            Haptics.light()
                            onSignIn()
                        } label: {
                            (Text("already have an account? ")
                             + Text("sign in").underline())
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Space.lg + Space.sm)
                    .padding(.bottom, Space.sm)
                    .opacity(ctaIn ? 1 : 0)
                    .offset(y: ctaIn || reduceMotion ? 0 : 8)
                }
            }
        }
        .onAppear { runChoreography() }
    }

    private func runChoreography() {
        guard !line2In else { return }
        if reduceMotion {
            wordmarkIn = true; deviceIn = true
            line1In = true; line2In = true; ctaIn = true
            return
        }
        withAnimation(Motion.entranceSoft.delay(0.1)) { wordmarkIn = true }
        withAnimation(Motion.entrance.delay(0.25)) { deviceIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(Motion.entranceSoft) { line1In = true }
            Haptics.soft()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
            withAnimation(Motion.entranceSoft) { line2In = true }
            Haptics.soft()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(Motion.entrance) { ctaIn = true }
        }
    }
}
