import SwiftUI

// MARK: - JeniDoodle (p66 — THE ILLUSTRATION REGISTER)
//
// Founder law, 2026-09-02: screens that need an illustration carry a
// BIG hand-drawn doodle (the ~/Pictures "doodle icons" set, imported
// as template-tinted vector imagesets named `doodle-*`) moving on a
// MOTION PATH. The set already lived in the product at chip scale
// (Home's task rows); this is the same hand at illustration scale.
//
// Laws:
//   · the doodle is INK on paper (template tint, cocoa at 90%) — the
//     one-colour law holds; illustration is never a second palette
//   · the motion is an ambient DRIFT along a closed Lissajous path
//     (slow, a few points of travel, a whisper of rotation) — alive,
//     never busy; it must read as paper breathing, not as an
//     animation performing
//   · decorative only: hidden from VoiceOver, never hit-testable
//   · Reduce Motion: perfectly still (remove motion, never the
//     illustration)
//   · use at most ONE per screen, on surfaces with genuine air —
//     empty states are the canonical site (JKEmptyState carries the
//     slot). A dense instrument panel never earns one.

struct JeniDoodle: View {
    /// Asset name (`doodle-*` imageset).
    let name: String
    var size: CGFloat = 140
    var tint: Color = Palette.textPrimary.opacity(0.9)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                doodle
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    doodle
                        // The motion path: a closed Lissajous drift.
                        // Incommensurate periods keep the path from
                        // reading as a loop; amplitudes stay small so
                        // the drawing floats rather than travels.
                        .offset(
                            x: sin(t * 2 * .pi / 7.3) * 7,
                            y: sin(t * 2 * .pi / 5.1 + 1.2) * 5
                        )
                        .rotationEffect(.degrees(sin(t * 2 * .pi / 9.7) * 2.4))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var doodle: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(maxWidth: size, maxHeight: size)
            .foregroundStyle(tint)
    }
}

#if DEBUG
#Preview("doodles") {
    VStack(spacing: 40) {
        JeniDoodle(name: "doodle-heart-beat")
        JeniDoodle(name: "doodle-dish", size: 120)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}
#endif
