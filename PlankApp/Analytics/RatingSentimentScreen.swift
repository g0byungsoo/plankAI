import SwiftUI
import UIKit

// MARK: - RatingSentimentScreen
//
// The full-screen sentiment gate (2026-07-08). Fires once after a
// genuine first win; "yes" → native SKStoreReviewController, "not
// really" → feedback. Replaces the old `.medium` bottom sheet with a
// design-forward full-screen moment in the app's generative-bloom
// language (the JKBreathField family): a custom breathing heart with a
// specular sheen over a warm rose bloom, all driven from one Canvas
// clock so nothing drifts. "yes" earns a celebratory bloom-swell +
// haptic ramp before the system prompt lands.
//
// Composition (top → bottom): breathing heart bloom · line-cascade
// question · prosocial sub · docked cocoa CTA + quiet decline.
// Reduce-Motion: static bloom, no cascade, instant.

struct RatingSentimentScreen: View {
    let onYes: () -> Void      // present SKStoreReviewController
    let onNotReally: () -> Void // open FeedbackView

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var heartIn = false
    @State private var questionIn = false
    @State private var ctaIn = false
    @State private var celebrateStart: Date?
    @State private var locked = false   // guards double-taps during the yes swell

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                RatingHeartBloom(celebrateStart: celebrateStart)
                    .frame(width: 240, height: 240)
                    .scaleEffect(heartIn ? 1 : 0.72)
                    .opacity(heartIn ? 1 : 0)

                LineCascadeText(
                    lines: [.composite(base: "enjoying jenifit so far?", italic: ["enjoying"])],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .center,
                    lineSpacing: Typo.heroHeadlineLineGap,
                    trigger: questionIn
                )
                .kerning(-0.4)
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xl)

                Text("a quick word helps other women find us.")
                    .font(Typo.teachSub)
                    .lineSpacing(Typo.teachSubLineSpacing)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg + Space.sm)
                    .padding(.top, Space.sm)
                    .opacity(questionIn ? 1 : 0)

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                ctaStack
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.lg)
                    .opacity(ctaIn ? 1 : 0)
                    .offset(y: ctaIn ? 0 : 14)
            }
        }
        .task { await runEntrance() }
    }

    // MARK: - CTAs

    private var ctaStack: some View {
        VStack(spacing: 10) {
            Button {
                guard !locked else { return }
                locked = true
                Haptics.success()
                // The earned beat: the bloom swells from the tap, then
                // the system prompt lands ~0.55s later so the native
                // sheet feels like the reward, not an interruption.
                celebrateStart = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { Haptics.soft() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { onYes() }
            } label: {
                (Text("yes, loving it ")
                    .font(.custom("DMSans-SemiBold", size: 16))
                    .foregroundStyle(Palette.textInverse)
                 + Text("\u{2665}\u{FE0E}")
                    .font(.custom("DMSans-SemiBold", size: 16))
                    .foregroundStyle(Palette.accent))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Palette.textPrimary)
                    )
                    // One specular sweep so the cocoa mass reads pressed
                    // + premium (the wall CTA's gloss).
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.white.opacity(0)],
                                startPoint: .top, endPoint: .center
                            ))
                            .allowsHitTesting(false)
                    )
            }
            .buttonStyle(PressFeedbackStyle())
            .disabled(locked)

            Button {
                guard !locked else { return }
                locked = true
                Haptics.light()
                onNotReally()
            } label: {
                Text("not really")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Entrance choreography

    private func runEntrance() async {
        if reduceMotion {
            heartIn = true; questionIn = true; ctaIn = true
            return
        }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) { heartIn = true }
        try? await Task.sleep(nanoseconds: 380_000_000)
        withAnimation { questionIn = true }   // LineCascadeText owns its own timing
        try? await Task.sleep(nanoseconds: 520_000_000)
        withAnimation(.easeOut(duration: 0.4)) { ctaIn = true }
    }
}

// MARK: - RatingHeartBloom
//
// A living heart drawn per-frame in Canvas from one clock (the
// JKBreathField technique). A slow ambient breath swells a warm rose
// halo + a custom-drawn heart with a radial fill and a clipped
// specular sheen; a handful of blush motes drift for coquette warmth.
// `celebrateStart` (set on "yes") drives a one-shot swell + an
// expanding heart ring that fades out — the tactile reward.
struct RatingHeartBloom: View {
    /// Non-nil once "yes" is tapped — the moment the celebration began.
    var celebrateStart: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion && celebrateStart == nil)) { context in
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let t = context.date.timeIntervalSinceReferenceDate

                // Ambient breath — a gentle 5s swell, zero-velocity ends.
                let breath: Double = reduceMotion ? 0.7 : (0.5 - 0.5 * cos(2 * .pi * (t.truncatingRemainder(dividingBy: 5)) / 5))

                // Celebration envelope: a fast swell (→1 over 0.28s) that
                // eases back toward rest, plus a ring that expands 0→1
                // over 0.7s and fades.
                var swell = 0.0
                var ring = 0.0
                if let start = celebrateStart {
                    let e = context.date.timeIntervalSince(start)
                    swell = e < 0.28 ? (e / 0.28) : max(0, 1 - (e - 0.28) / 0.9)
                    ring = min(1, e / 0.7)
                }

                drawBloom(ctx: ctx, canvas: size, center: center,
                          breath: breath, swell: swell, ring: ring, t: t)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: draw

    private func drawBloom(
        ctx: GraphicsContext, canvas: CGSize, center: CGPoint,
        breath: Double, swell: Double, ring: Double, t: Double
    ) {
        let base = min(canvas.width, canvas.height)
        // Heart box size breathes gently; the celebration swell adds punch.
        let heartW = base * (0.42 * (0.96 + 0.05 * breath) + 0.10 * swell)
        let heartH = heartW * 0.9
        let heartRect = CGRect(
            x: center.x - heartW / 2,
            y: center.y - heartH / 2 + heartH * 0.04,
            width: heartW, height: heartH
        )
        let heart = Self.heartPath(in: heartRect)

        // 1. Halo — a wide warm wash that swells with the breath. Reads
        //    as glow, not a ring.
        let haloR = base * (0.40 * (0.85 + 0.22 * breath) + 0.18 * swell)
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - haloR, y: center.y - haloR,
                                   width: haloR * 2, height: haloR * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    Palette.accent.opacity(0.20 + 0.10 * breath + 0.18 * swell),
                    Palette.accent.opacity(0),
                ]),
                center: center, startRadius: 0, endRadius: haloR
            )
        )

        // 2. Blush motes — a few soft points drifting slowly for warmth.
        if !reduceMotion {
            for k in 0..<5 {
                let a = Double(k) * (2 * .pi / 5) + t * 0.18
                let dist = base * (0.30 + 0.03 * sin(t * 0.5 + Double(k)))
                let mc = CGPoint(x: center.x + CGFloat(cos(a)) * dist,
                                 y: center.y + CGFloat(sin(a)) * dist)
                let mr = base * 0.075
                ctx.fill(
                    Path(ellipseIn: CGRect(x: mc.x - mr, y: mc.y - mr, width: mr * 2, height: mr * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Palette.accentSubtle.opacity(0.16), Palette.accentSubtle.opacity(0)]),
                        center: mc, startRadius: 0, endRadius: mr
                    )
                )
            }
        }

        // 3. The heart — radial rose fill, bright at the upper-left where
        //    the light falls, deepening to dusty rose at the rim.
        let lightPoint = CGPoint(x: heartRect.midX - heartW * 0.16,
                                 y: heartRect.midY - heartH * 0.18)
        ctx.fill(heart, with: .radialGradient(
            Gradient(stops: [
                .init(color: Palette.accentSubtle.opacity(0.98), location: 0.0),
                .init(color: Palette.accent.opacity(0.95), location: 0.55),
                .init(color: Palette.accent.opacity(1.0), location: 1.0),
            ]),
            center: lightPoint, startRadius: 0, endRadius: heartW * 0.78
        ))

        // 4. Specular sheen — clip to the heart, lay a soft white
        //    highlight in the upper-left lobe. The gloss that makes it
        //    read as a lacquered object, not a flat fill.
        ctx.drawLayer { layer in
            layer.clip(to: heart)
            let glossC = CGPoint(x: heartRect.midX - heartW * 0.17,
                                 y: heartRect.minY + heartH * 0.24)
            let glossR = heartW * 0.30
            layer.fill(
                Path(ellipseIn: CGRect(x: glossC.x - glossR, y: glossC.y - glossR * 0.8,
                                       width: glossR * 2, height: glossR * 1.6)),
                with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)]),
                    center: glossC, startRadius: 0, endRadius: glossR
                )
            )
        }

        // 5. Rim light — a hairline of warmth on the lower edge, drawn as
        //    a faint stroke so the silhouette stays crisp on cream.
        ctx.stroke(heart, with: .color(Palette.accent.opacity(0.5)),
                   lineWidth: max(0.75, base * 0.004))

        // 6. Celebration ring — an expanding heart outline that fades as
        //    it grows, emitted from the "yes" tap.
        if ring > 0 && ring < 1 {
            let grow = 1 + 0.5 * ring
            let rRect = CGRect(
                x: center.x - heartW * grow / 2,
                y: center.y - heartH * grow / 2 + heartH * 0.04,
                width: heartW * grow, height: heartH * grow
            )
            ctx.stroke(Self.heartPath(in: rRect),
                       with: .color(Palette.accent.opacity(0.5 * (1 - ring))),
                       lineWidth: max(1, base * 0.010 * (1 - ring)))
        }
    }

    // MARK: - Heart path

    /// The canonical two-lobe cubic heart, fitted to `rect` with the
    /// tip at the bottom-center. Pure geometry — reused for fill, clip,
    /// stroke, and the celebration ring.
    static func heartPath(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let ox = rect.minX, oy = rect.minY
        func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: ox + w * fx, y: oy + h * fy)
        }
        path.move(to: pt(0.5, 1.0))
        path.addCurve(to: pt(0.0, 0.27),
                      control1: pt(0.5, 0.78), control2: pt(0.0, 0.52))
        path.addArc(center: pt(0.25, 0.27), radius: w * 0.25,
                    startAngle: .radians(.pi), endAngle: .radians(0), clockwise: false)
        path.addArc(center: pt(0.75, 0.27), radius: w * 0.25,
                    startAngle: .radians(.pi), endAngle: .radians(0), clockwise: false)
        path.addCurve(to: pt(0.5, 1.0),
                      control1: pt(1.0, 0.52), control2: pt(0.5, 0.78))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("rating sentiment") {
    RatingSentimentScreen(onYes: {}, onNotReally: {})
}
#endif
