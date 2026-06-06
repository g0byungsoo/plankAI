#if canImport(UIKit)
import SwiftUI

// MARK: - ScanningOverlay
//
// v1.0.7 in-viewfinder scan magic per the camera UX research:
//   docs/camera_magic_research_calorie_ai_2026_06_06.md
//   docs/camera_magic_research_calai_teardown_2026_06_06.md
//   docs/camera_magic_research_ios_swift_2026_06_06.md
//
// Three-layer composition that gives JeniFit-register magic without
// going AR-clinical (the trap Cal AI / SnapCalorie fell into):
//
//   1. Cocoa scanline sweep — 2pt height, 12pt halo, gradient cocoa
//      → transparent. Sweeps top→bottom on a 1.4s smoothstep loop.
//      Cocoa not laser-green = coquette-not-clinical register.
//   2. Subtle aperture breathing (1.0 → 1.012 on 1.6s) — the frozen
//      still feels "alive" rather than locked. Almost subliminal.
//   3. Italic-Fraunces label rotator — "*reading* your plate" →
//      "*finding* ingredients" → "*tallying* portions" — every 700ms.
//      Italic-Fraunces punch word per locked voice signal.
//
// Sits INSIDE the viewfinder bounds, on top of the frozenFrame
// Image. The AVCaptureVideoPreviewLayer keeps running underneath
// (covered by the still), so when the call returns we can clear
// the frozenFrame and the live preview is back without a hitch.
//
// TimelineView(.animation(paused:)) drives both layers — flipping
// isActive=false freezes the sweep mid-stride for clean cancellation.
// Reduce-motion gate replaces the moving bar with a static still +
// labels only (kept by the caller).

@MainActor
struct ScanningOverlay: View {

    let isActive: Bool

    /// 1.4s sweep loop. Fast enough to feel alive, slow enough to read.
    private let sweepDuration: Double = 1.4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: !isActive)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: sweepDuration))
                        / sweepDuration

            Canvas { context, size in
                drawScanline(
                    in: context,
                    size: size,
                    phase: CGFloat(smoothstep(phase))
                )
            }
        }
        .compositingGroup()
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    /// Two-layer JeniFit scanline: a SOFT ROSE outer halo (44pt) +
    /// COCOA core (1.5pt) with a slim cocoa halo (20pt) in between.
    /// Rose-on-cocoa keeps the coquette-not-clinical register — pure
    /// cocoa read as too utility, pure rose read as too femtech. Both
    /// layers are GPU-backed linear gradients.
    private func drawScanline(
        in context: GraphicsContext,
        size: CGSize,
        phase: CGFloat
    ) {
        let y = phase * size.height
        let cocoaHalo: CGFloat = 20
        let roseHalo: CGFloat = 44
        let core: CGFloat = 1.5

        // Outer rose halo — softens the cocoa scanline into the
        // coquette voice. JeniFit accent rose, low alpha so it
        // washes the photo with warmth rather than tinting it.
        let rose = Color(red: 0.77, green: 0.40, blue: 0.48)  // #C4677A
        let roseRect = CGRect(
            x: 0, y: y - roseHalo,
            width: size.width, height: roseHalo * 2
        )
        let roseGradient = Gradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: rose.opacity(0.10), location: 0.5),
            .init(color: .clear, location: 1.0),
        ])
        context.fill(
            Path(roseRect),
            with: .linearGradient(
                roseGradient,
                startPoint: CGPoint(x: 0, y: roseRect.minY),
                endPoint:   CGPoint(x: 0, y: roseRect.maxY)
            )
        )

        // Inner cocoa halo — the "reading" mark proper.
        let cocoa = Color(red: 0.24, green: 0.16, blue: 0.16)  // #3D2A2A
        let cocoaRect = CGRect(
            x: 0, y: y - cocoaHalo,
            width: size.width, height: cocoaHalo * 2
        )
        let cocoaGradient = Gradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: cocoa.opacity(0.18), location: 0.5),
            .init(color: .clear, location: 1.0),
        ])
        context.fill(
            Path(cocoaRect),
            with: .linearGradient(
                cocoaGradient,
                startPoint: CGPoint(x: 0, y: cocoaRect.minY),
                endPoint:   CGPoint(x: 0, y: cocoaRect.maxY)
            )
        )

        // Core line — crisp cocoa thread.
        let coreRect = CGRect(
            x: 0, y: y - core / 2,
            width: size.width, height: core
        )
        context.fill(
            Path(coreRect),
            with: .color(cocoa.opacity(0.55))
        )
    }

    /// Smoothstep curve so the bar accelerates in and decelerates out
    /// of each sweep — feels more deliberate than a linear scroll.
    private func smoothstep(_ t: Double) -> Double {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }
}

// MARK: - ScanLabelRotator
//
// Italic-Fraunces label that rotates between three states every 700ms
// while isActive. PhaseAnimator alternative: TimelineView(.periodic)
// drives the index, which forces a SwiftUI body re-render with .id()
// so the .transition fires per swap. Italic-Fraunces on the verb only
// per the voice signal lock.

@MainActor
struct ScanLabelRotator: View {

    let isActive: Bool

    private enum Phase: Int, CaseIterable {
        case reading, finding, tallying

        var verb: String {
            switch self {
            case .reading:  return "reading"
            case .finding:  return "finding"
            case .tallying: return "tallying"
            }
        }
        var tail: String {
            switch self {
            case .reading:  return " your plate"
            case .finding:  return " ingredients"
            case .tallying: return " portions"
            }
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.9)) { ctx in
            let elapsed = ctx.date.timeIntervalSinceReferenceDate
            let idx = max(0, Int(elapsed / 0.9)) % Phase.allCases.count
            let phase = Phase.allCases[idx]

            // .id(idx) forces SwiftUI to mount a fresh subtree per
            // phase change so the transition actually fires. Cleaner
            // resolve: opacity + slight blur fade-in (no slide — the
            // slide-from-bottom was the part that read clinical).
            HStack(spacing: 0) {
                Text(phase.verb)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                Text(phase.tail)
                    .font(.custom("Fraunces72pt-Regular", size: 16))
            }
            .foregroundStyle(FoodTheme.textPrimary)
            .id(idx)
            .transition(
                .asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.45)),
                    removal:   .opacity.animation(.easeIn(duration: 0.25))
                )
            )
        }
        .opacity(isActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("looking at your plate")
    }
}

#endif  // canImport(UIKit)
