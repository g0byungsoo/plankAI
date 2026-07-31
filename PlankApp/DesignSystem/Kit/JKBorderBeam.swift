import SwiftUI

// MARK: - JKBorderBeam (the Jeni release, 2026-07-30)
//
// One of Jeni's signature design-language elements: a slow, warm
// highlight that travels the border of a premium surface — light
// moving along the edge of good paper. It is part of the design
// system, not an animation effect: the rule set below is law.
//
//   • WHERE: earned and premium surfaces only — the paywall's chosen
//     plan + CTA, the program-ready moment, the weekly re-signing,
//     jeni's letter arrivals. Never on medication or clinical
//     surfaces (FR4: the record is the only reward there), never on
//     routine rows, never on more than one region of a screen.
//   • HOW STRONG: if the beam itself is noticed, it is too strong.
//     Peak opacity stays ≤ 0.5; the arc is short (~12% of the
//     border); one full lap takes ~8-10 seconds. The surface should
//     simply feel finished, lit, cared for.
//   • MOTION LAW: reduce-motion renders a static, faint gradient
//     border — the craft stays, the travel stops.
//
// Implementation: an additive stroke overlay carrying an angular
// gradient whose short bright arc is rotated by a TimelineView-driven
// phase. Stroke-only + 30fps cap keeps it effectively free on the
// GPU; nothing re-lays-out per frame.

struct JKBorderBeam: ViewModifier {
    var cornerRadius: CGFloat
    var lineWidth: CGFloat = 1
    var tint: Color = Palette.accent
    /// Peak arc opacity. The design ceiling is 0.5 — see header law.
    var intensity: Double = 0.4
    /// Seconds per full lap of the border.
    var period: Double = 9
    var enabled: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if enabled {
                if reduceMotion {
                    // Static craft: the same warmth, no travel.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    tint.opacity(intensity * 0.5),
                                    tint.opacity(0.0),
                                    tint.opacity(intensity * 0.35),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: lineWidth
                        )
                        .allowsHitTesting(false)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        let phase = (t.truncatingRemainder(dividingBy: period)) / period
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                AngularGradient(
                                    stops: [
                                        .init(color: tint.opacity(0), location: 0.00),
                                        .init(color: tint.opacity(0), location: 0.82),
                                        .init(color: tint.opacity(intensity * 0.55), location: 0.88),
                                        .init(color: tint.opacity(intensity), location: 0.91),
                                        .init(color: tint.opacity(intensity * 0.55), location: 0.94),
                                        .init(color: tint.opacity(0), location: 1.00),
                                    ],
                                    center: .center,
                                    angle: .degrees(phase * 360)
                                ),
                                lineWidth: lineWidth
                            )
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .accessibilityHidden(false)
    }
}

extension View {
    /// Jeni's traveling border highlight — see JKBorderBeam header for
    /// the placement + strength law before adding a call site.
    func jkBorderBeam(
        cornerRadius: CGFloat,
        lineWidth: CGFloat = 1,
        tint: Color = Palette.accent,
        intensity: Double = 0.4,
        period: Double = 9,
        enabled: Bool = true
    ) -> some View {
        modifier(JKBorderBeam(
            cornerRadius: cornerRadius,
            lineWidth: lineWidth,
            tint: tint,
            intensity: intensity,
            period: period,
            enabled: enabled
        ))
    }
}

#Preview("JKBorderBeam") {
    VStack(spacing: Space.xl) {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Palette.bgElevated)
            .frame(height: 140)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.hairlineCocoa, lineWidth: 0.5)
            )
            .jkBorderBeam(cornerRadius: 20, intensity: 0.4)

        Capsule()
            .fill(Palette.bgInverse)
            .frame(height: 56)
            .overlay(Text("start my program").font(Typo.heading).foregroundStyle(Palette.textInverse))
            .jkBorderBeam(cornerRadius: 28, lineWidth: 1.25, tint: Palette.accentSubtle, intensity: 0.5, period: 8)
    }
    .padding(Space.xl)
    .background(Palette.bgPrimary)
}
