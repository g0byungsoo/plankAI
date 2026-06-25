#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - RotatingScanBorder
//
// v1.0.8 Phase M (2026-06-08) — rewritten per founder direction:
// "mimic everything from the reference. uniform hot pink border at
// rest, the hot pink revolves when scanning."
//
// Composition: two stacked strokes around a single RoundedRectangle.
//
//   Base layer: solid uniform hot pink stroke, ALWAYS visible. This
//   is what the user sees most of the time — the resting "camera
//   ready" frame. Same color regardless of state, so the transition
//   into/out of scanning doesn't show a color change.
//
//   Shimmer layer: an AngularGradient where most stops are transparent
//   and one stop is a bright white-ish sweep. Driven by TimelineView
//   (paused: !isScanning) so it only consumes frames during a scan.
//   Crossfaded in/out via opacity + 0.35s easeInOut. The shimmer rides
//   ON TOP of the base, so the moment the shimmer disappears, the
//   underlying solid pink takes over visually — no jarring color hop.
//
// The previous AngularGradient-as-base approach drew the border with
// non-uniform alpha at rest (the gradient stops at lower opacity were
// visibly faded on some edges), which read as "border broken" in the
// founder's review screenshots. The shimmer-as-overlay pattern is the
// canonical iPhone Camera / Cal AI border-glow trick — uniform base,
// rotating highlight.
//
// Caller is responsible for sizing/positioning the border. This view
// fills its parent's bounds and strokes a RoundedRectangle inside,
// matching `cornerRadius`. For an inset camera frame, place the
// border in the same ZStack as the clipped camera content with the
// same corner radius.

// 2026-06-23 — calmed per the her75/JeniFit design review. The old
// border jumped to neon hot-magenta (#FF13F0) on tap — the only neon
// in the whole 8-token palette, reading as "slot machine" against the
// minimal-luxury north star. Now the border is the app's dusty-rose
// `accent` in BOTH states; only the MOTION of a soft white light
// travelling around it signals "reading." Thinner (3pt edge, not a 5pt
// frame), slower (3.4s revolution — careful, not buffering), and the
// bright arc is wider + feathered so it swells rather than blinks.
// `isError` is gone: a failed scan is a gentle cream card now, never a
// red/loud frame.

struct RotatingScanBorder: View {
    let isScanning: Bool
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    init(
        isScanning: Bool = false,
        cornerRadius: CGFloat = 28,
        lineWidth: CGFloat = 3
    ) {
        self.isScanning = isScanning
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
    }

    // Slow on purpose: a fast revolution reads as "buffering," a slow
    // one as "carefully looking." 3.4s is the calm beat.
    private let revolutionDuration: Double = 3.4

    var body: some View {
        ZStack {
            // Base layer: uniform dusty-rose, same at rest and scanning
            // so there's zero color hop entering/leaving the scan.
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(FoodTheme.accent, lineWidth: lineWidth)

            // Shimmer overlay: a soft, wide white arc that travels the
            // border during scan. Feathered (clear → accent → white peak
            // → accent → clear) so it swells through the rose rather
            // than blinking a hard highlight. Peak 0.55 (was a harsh
            // 0.75). Paused when idle so it costs zero frames at rest.
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: !isScanning)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let phase = (elapsed.truncatingRemainder(dividingBy: revolutionDuration))
                            / revolutionDuration
                let angle = phase * 360.0

                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                .clear,
                                FoodTheme.accent.opacity(0.0),
                                FoodTheme.accent.opacity(0.35),
                                Color.white.opacity(0.55),
                                FoodTheme.accent.opacity(0.35),
                                FoodTheme.accent.opacity(0.0),
                                .clear,
                                .clear,
                            ],
                            center: .center,
                            angle: .degrees(angle)
                        ),
                        lineWidth: lineWidth
                    )
            }
            .opacity(isScanning ? 1 : 0)
            // Swell in (easeOut) so the glow grows rather than snaps.
            .animation(.easeOut(duration: 0.42), value: isScanning)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#endif  // canImport(UIKit)
