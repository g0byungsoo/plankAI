#if canImport(UIKit)
import SwiftUI

// MARK: - SnapSweepOverlay
//
// v1.2 snap-food rebuild (2026-07-01) — SwiftUI host for the
// `snapSweep` Metal pass (SnapShaders.metal). Mounted over the
// viewfinder content with .plusLighter so the shader's premultiplied
// additive light lands on the live preview and gallery photos alike
// (a colorEffect can't filter an AVCaptureVideoPreviewLayer's pixels,
// but it can paint light over them — which is all this moment needs).
//
// Same integration contract as the Canvas overlay it replaces:
//   - TimelineView paused when inactive (zero cost at rest)
//   - 0.12s opacity in/out so the light never hard-cuts
//   - an invisible 1×1 prewarm instance compiles the pipeline at
//     view-appear so the first real scan doesn't pay the cold start

@MainActor
public struct SnapSweepOverlay: View {

    let isActive: Bool

    // Public: the onboarding snap demo (OV5SnapDemo) runs the REAL scan
    // pass over its staged plates — the product magic pre-paywall is
    // only honest if it is literally the same Metal pass.
    public init(isActive: Bool) {
        self.isActive = isActive
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: !isActive)) { timeline in
            // Modulo keeps the float uniform small (shader-side fract
            // needs precision); one hairline phase skip per hour is
            // beneath perception.
            let t = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 3600)

            GeometryReader { geo in
                Rectangle()
                    .fill(Color.white.opacity(0.02))
                    .colorEffect(
                        ShaderLibrary.bundle(.module).snapSweep(
                            .float2(Float(geo.size.width), Float(geo.size.height)),
                            .float(Float(t)),
                            .float(isActive ? 1 : 0)
                        )
                    )
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .opacity(isActive ? 1 : 0)
        .animation(.linear(duration: 0.12), value: isActive)
    }
}
#endif
