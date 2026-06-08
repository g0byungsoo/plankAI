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

// v1.0.9 D2 — split-role pink per expert pick. Idle uses the softer
// FoodTheme.cameraIdlePink (#FF7AD9) so the resting frame reads
// coquette; scanning jolts to FoodTheme.cameraScanPink (#FF13F0)
// for the energy beat. Border base color picks the right token
// based on `isScanning`.

struct RotatingScanBorder: View {
    let isScanning: Bool
    let isError: Bool
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    init(
        isScanning: Bool = false,
        isError: Bool = false,
        cornerRadius: CGFloat = 28,
        lineWidth: CGFloat = 5
    ) {
        self.isScanning = isScanning
        self.isError = isError
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
    }

    private let revolutionDuration: Double = 2.5

    var body: some View {
        ZStack {
            // Base layer: solid uniform hot pink. Slightly cooler
            // (lower saturation) when not actively scanning so the
            // scanning state has clear "energy bump" visual contrast.
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    isScanning ? FoodTheme.cameraScanPink : FoodTheme.cameraIdlePink,
                    lineWidth: lineWidth
                )

            // Shimmer overlay: a single bright stop that sweeps around
            // the border during scan. Mostly-transparent gradient so
            // the base pink shows through everywhere except the
            // ~45° arc where the sweep is.
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
                                .clear,
                                .clear,
                                Color.white.opacity(0.75),
                                .clear,
                                .clear,
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
            .animation(.easeInOut(duration: 0.35), value: isScanning)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#endif  // canImport(UIKit)
