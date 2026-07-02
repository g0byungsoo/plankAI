import SwiftUI

// MARK: - OV5WelcomeCollage
//
// Screen 1 — the her75 "become that girl" register rebuilt JeniFit-safe
// (no body imagery, no fabricated counts). 9-13 real-object cutouts
// bleed off the edges around a cleared headline zone; one from-behind
// hero girl anchors the lower third; ONE polaroid whispers the product
// (a scanned plate with a soft kcal pill — cashed by the real demo mid-
// flow). Sticker scatter ≤2: welcome is earned-moment #1. Entrance is a
// stagger-drop (scale 1.04→1.0 settle), hero lands last, then the
// line-cascade headline with a soft haptic per line.

private struct CollageItem: Identifiable {
    let asset: String
    let x: CGFloat          // relative position (0-1)
    let y: CGFloat
    let size: CGFloat       // pt height
    let rotation: Double    // photos stay axis-aligned; polaroid only tilts
    let delay: Double
    var id: String { asset }
}

struct OV5WelcomeCollage: View {
    let onBegin: () -> Void
    let onSignIn: () -> Void

    @State private var itemsIn = false
    @State private var line1In = false
    @State private var line2In = false
    @State private var ctaIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let items: [CollageItem] = [
        .init(asset: "onb-filler-books", x: 0.10, y: 0.055, size: 128, rotation: 0, delay: 0.00),
        .init(asset: "onb-filler-bouquet", x: 0.93, y: 0.09, size: 158, rotation: 0, delay: 0.07),
        .init(asset: "onb-filler-matcha", x: 0.05, y: 0.24, size: 104, rotation: 0, delay: 0.14),
        .init(asset: "onb-filler-bracelets", x: 0.97, y: 0.30, size: 108, rotation: 0, delay: 0.21),
        .init(asset: "onb-filler-candle", x: 0.02, y: 0.44, size: 96, rotation: 0, delay: 0.28),
        .init(asset: "onb-filler-tumbler", x: 0.07, y: 0.66, size: 128, rotation: 0, delay: 0.35),
        .init(asset: "onb-filler-roses", x: 0.97, y: 0.62, size: 138, rotation: 0, delay: 0.42),
        .init(asset: "onb-filler-anthurium", x: 0.05, y: 0.90, size: 140, rotation: 0, delay: 0.49),
        .init(asset: "onb-filler-hourglass", x: 0.94, y: 0.95, size: 96, rotation: 0, delay: 0.56),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Object cutouts — every one cropped by an edge or
                // overlapping a neighbor; nothing floats fully inside.
                ForEach(Self.items) { item in
                    Image(item.asset)
                        .resizable()
                        .scaledToFit()
                        .frame(height: item.size)
                        .rotationEffect(.degrees(item.rotation))
                        .position(x: item.x * geo.size.width, y: item.y * geo.size.height)
                        .opacity(itemsIn ? 1 : 0)
                        .scaleEffect(itemsIn ? 1.0 : 1.04)
                        .animation(Motion.entranceSoft.delay(reduceMotion ? 0 : item.delay), value: itemsIn)
                }

                // The product whisper: a scanned-plate polaroid with a
                // soft kcal pill (the demo's real staged value — the
                // same bowl she can pick mid-flow).
                polaroid
                    .position(x: 0.86 * geo.size.width, y: 0.46 * geo.size.height)
                    .opacity(itemsIn ? 1 : 0)
                    .scaleEffect(itemsIn ? 1.0 : 1.04)
                    .animation(Motion.entranceSoft.delay(reduceMotion ? 0 : 0.63), value: itemsIn)

                // From-behind hero girl, lower third, cropped by bottom.
                Image("onb-itgirl-firstweek")
                    .resizable()
                    .scaledToFit()
                    .frame(height: min(320, geo.size.height * 0.36))
                    .position(x: 0.46 * geo.size.width, y: 0.86 * geo.size.height)
                    .opacity(itemsIn ? 1 : 0)
                    .scaleEffect(itemsIn ? 1.0 : 1.03)
                    .animation(Motion.entrance.delay(reduceMotion ? 0 : 0.72), value: itemsIn)

                // Earned-moment stickers (≤2).
                StickerScatter(placements: [
                    StickerPlacement(sticker: .sparkleGlossy,
                                     position: CGPoint(x: 0.20, y: 0.135),
                                     size: 30, rotation: -10, phaseDelay: 0.8),
                    StickerPlacement(sticker: .bowSatin,
                                     position: CGPoint(x: 0.78, y: 0.70),
                                     size: 34, rotation: 9, phaseDelay: 0.95),
                ])

                // Cleared headline zone.
                VStack(spacing: 0) {
                    Text("jeni·fit")
                        .font(.custom("Fraunces72pt-SemiBold", size: 17))
                        .kerning(0.3)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 10)
                        .opacity(itemsIn ? 1 : 0)
                        .animation(Motion.entranceSoft, value: itemsIn)

                    Spacer()

                    VStack(spacing: 2) {
                        ItalicAccentText(
                            "become",
                            italic: [],
                            baseFont: .custom("JeniHeroSerif-Regular", size: 52),
                            italicFont: .custom("JeniHeroSerif-Italic", size: 52),
                            alignment: .center
                        )
                        .kerning(-0.5)
                        .opacity(line1In ? 1 : 0)
                        .offset(y: line1In ? 0 : 10)

                        ItalicAccentText(
                            "her.",
                            italic: ["her."],
                            baseFont: .custom("JeniHeroSerif-Regular", size: 52),
                            italicFont: .custom("JeniHeroSerif-Italic", size: 52),
                            alignment: .center
                        )
                        .kerning(-0.5)
                        .padding(.top, -18)
                        .opacity(line2In ? 1 : 0)
                        .offset(y: line2In ? 0 : 10)

                        Text("a plan that finally fits")
                            .font(Typo.heroSubpill)
                            .kerning(0.2)
                            .foregroundStyle(Palette.textInverse)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Palette.cocoaPrimary.opacity(0.92)))
                            .padding(.top, 14)
                            .opacity(line2In ? 1 : 0)
                            .offset(y: line2In ? 0 : 8)
                    }
                    .frame(maxWidth: .infinity)
                    // Soft cream halo so the serif never fights a cutout.
                    .padding(.vertical, 26)
                    .background(
                        RadialGradient(
                            colors: [Palette.bgPrimary.opacity(0.94), Palette.bgPrimary.opacity(0)],
                            center: .center, startRadius: 60, endRadius: 210
                        )
                    )
                    .offset(y: -geo.size.height * 0.135)

                    Spacer()

                    VStack(spacing: 10) {
                        Button {
                            Haptics.medium()
                            onBegin()
                        } label: {
                            Text("i'm ready")
                                .font(.custom("DMSans-SemiBold", size: 16))
                                .foregroundStyle(Palette.textInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Palette.cocoaPrimary)
                                .clipShape(Capsule())
                                .shadow(color: Palette.cocoaPrimary.opacity(0.22), radius: 14, x: 0, y: 6)
                        }
                        .buttonStyle(PressFeedbackStyle())

                        Text("free to start.")
                            .font(.custom("DMSans-Regular", size: 13))
                            .foregroundStyle(Palette.textSecondary)

                        Button {
                            Haptics.light()
                            onSignIn()
                        } label: {
                            HStack(spacing: 4) {
                                Text("already have an account?")
                                Text("sign in").underline()
                            }
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Space.lg + Space.sm)
                    .padding(.bottom, Space.sm)
                    .background(
                        LinearGradient(
                            colors: [Palette.bgPrimary.opacity(0), Palette.bgPrimary.opacity(0.9), Palette.bgPrimary.opacity(0.96)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .padding(.horizontal, -Space.lg)
                        .padding(.top, -30)
                        .allowsHitTesting(false)
                    )
                    .opacity(ctaIn ? 1 : 0)
                    .offset(y: ctaIn ? 0 : 8)
                }
            }
        }
        .onAppear { runChoreography() }
    }

    private var polaroid: some View {
        VStack(spacing: 5) {
            Image("onb-v5-demo-bowl")
                .resizable()
                .scaledToFill()
                .frame(width: 104, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            HStack(spacing: 4) {
                Text("610")
                    .font(.custom("JeniHeroSerif-Regular", size: 13))
                    .monospacedDigit()
                Text("cal, read")
                    .font(.custom("JeniHeroSerif-Italic", size: 11))
            }
            .foregroundStyle(Palette.textPrimary.opacity(0.75))
        }
        .padding(7)
        .padding(.bottom, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white)
                .shadow(color: Palette.cocoaPrimary.opacity(0.14), radius: 9, x: 0, y: 4)
        )
        .rotationEffect(.degrees(-5))
    }

    private func runChoreography() {
        guard !itemsIn else { return }
        if reduceMotion {
            itemsIn = true; line1In = true; line2In = true; ctaIn = true
            return
        }
        withAnimation { itemsIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(Motion.entranceSoft) { line1In = true }
            Haptics.soft()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.18) {
            withAnimation(Motion.entranceSoft) { line2In = true }
            Haptics.soft()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(Motion.entrance) { ctaIn = true }
        }
    }
}
