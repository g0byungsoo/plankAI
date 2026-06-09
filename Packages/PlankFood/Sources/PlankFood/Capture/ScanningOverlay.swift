#if canImport(UIKit)
import SwiftUI

// MARK: - ScanningOverlay
//
// v1.0.7 in-viewfinder scan magic per the camera UX research:
//   docs/camera_magic_research_calorie_ai_2026_06_06.md
//   docs/camera_magic_research_calai_teardown_2026_06_06.md
//   docs/camera_magic_research_ios_swift_2026_06_06.md
//
// v1.0.8 Phase K (2026-06-08) — smoothness pass. Founder feedback:
// "the scan animations are flickering — it's much better — but let's
// make a lot more smooth transition animation."
//
// Two root-cause fixes:
//
// 1. SWEEP LOOP BOUNDARY SNAP. The previous sweep used
//    `(t mod sweepDuration) / sweepDuration` for phase and drew the
//    scanline at `phase * height`. At each loop boundary the scanline
//    instantly teleported from the bottom of the frame back to the
//    top — a one-frame snap that read as a flicker. Now multiplied by
//    a sin alpha gate `sin(phase * π)` so the scanline fades IN at
//    the top, peaks at mid-frame, and fades OUT at the bottom before
//    the loop restarts. No visible snap.
//
// 2. PLUS-LIGHTER BLEND MODE on bright food photos was washing the
//    scanline to near-invisible on white plates and oversaturating it
//    on dark backgrounds — visible flicker as the camera auto-exposed
//    between frames. Dropped in favor of normal compositing; the
//    cocoa + rose gradient colors already carry enough contrast.
//
// Also lengthened the sweep cycle (1.4s → 2.2s) since the new
// fade-in/fade-out at the edges already adds visual time. A slower,
// more deliberate sweep reads as "carefully reading" — the right
// emotional register for a one-shot food capture.

@MainActor
struct ScanningOverlay: View {

    let isActive: Bool

    /// 2.2s sweep loop. Slower than before because the sin alpha gate
    /// already adds breathing room; a fast sweep on top of the fade
    /// looked anxious.
    private let sweepDuration: Double = 2.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: !isActive)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let raw = (t.truncatingRemainder(dividingBy: sweepDuration))
                      / sweepDuration

            Canvas { context, size in
                drawScanline(
                    in: context,
                    size: size,
                    phase: CGFloat(smoothstep(raw)),
                    gate: CGFloat(sin(raw * .pi))
                )
            }
        }
        .allowsHitTesting(false)
        .opacity(isActive ? 1 : 0)
        // v1.0.9 D2 polish round 2 — was 0.35s ease, perceived as
        // delay after the user tapped scan. 0.12s linear lands
        // immediately while still avoiding a hard cut.
        .animation(.linear(duration: 0.12), value: isActive)
    }

    /// v1.0.9 D2 polish — re-coloured for brand. Founder feedback:
    /// "improve the scan (the grey line) animation." The cocoa-on-rose
    /// stack was reading grey on busy food photos. New stack uses the
    /// FoodTheme camera-pink pair so the sweep pops as a JeniFit
    /// "magic line" instead of a dim shadow:
    ///   - outer halo: cameraIdlePink #FF7AD9 @ 16% (a 56pt soft glow)
    ///   - inner halo: bright rose #FF4FA8 @ 26% (28pt)
    ///   - core: white-hot pink #FF7AD9 @ 85% (2pt — slightly thicker
    ///     than before so the line stays visible against red/orange
    ///     food)
    ///
    /// `gate` is the sin-π alpha multiplier — 0 at the loop boundary,
    /// 1 at mid-cycle — that hides the y=0 / y=height teleport.
    private func drawScanline(
        in context: GraphicsContext,
        size: CGSize,
        phase: CGFloat,
        gate: CGFloat
    ) {
        let y = phase * size.height
        let innerHalo: CGFloat = 28
        let outerHalo: CGFloat = 56
        let core: CGFloat = 2.0

        let outerPink = Color(red: 1.00, green: 0.48, blue: 0.85)  // #FF7AD9
        let outerRect = CGRect(
            x: 0, y: y - outerHalo,
            width: size.width, height: outerHalo * 2
        )
        let outerGradient = Gradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: outerPink.opacity(0.16 * Double(gate)), location: 0.5),
            .init(color: .clear, location: 1.0),
        ])
        context.fill(
            Path(outerRect),
            with: .linearGradient(
                outerGradient,
                startPoint: CGPoint(x: 0, y: outerRect.minY),
                endPoint:   CGPoint(x: 0, y: outerRect.maxY)
            )
        )

        let innerPink = Color(red: 1.00, green: 0.31, blue: 0.66)  // #FF4FA8
        let innerRect = CGRect(
            x: 0, y: y - innerHalo,
            width: size.width, height: innerHalo * 2
        )
        let innerGradient = Gradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: innerPink.opacity(0.26 * Double(gate)), location: 0.5),
            .init(color: .clear, location: 1.0),
        ])
        context.fill(
            Path(innerRect),
            with: .linearGradient(
                innerGradient,
                startPoint: CGPoint(x: 0, y: innerRect.minY),
                endPoint:   CGPoint(x: 0, y: innerRect.maxY)
            )
        )

        let coreRect = CGRect(
            x: 0, y: y - core / 2,
            width: size.width, height: core
        )
        context.fill(
            Path(coreRect),
            with: .color(outerPink.opacity(0.85 * Double(gate)))
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
// v1.0.8 Phase K (2026-06-08) — rewritten for smoothness. The previous
// version used `.id(idx) + .transition` driven by a TimelineView body
// re-render. SwiftUI doesn't fire `.transition` reliably when the
// driver is a TimelineView (the body re-runs every tick without going
// through the animation system), so the label was hard-cutting on each
// 0.9s rotate instead of crossfading.
//
// New approach:
//   - @State index driven by a `.task(id:)` async loop with explicit
//     `withAnimation(.easeInOut(duration: 0.55))` per phase swap
//   - `.contentTransition(.opacity)` on the Text so the content
//     change cross-fades smoothly without remounting the view
//   - Cadence bumped 0.9s → 1.6s so each phrase has time to BE read
//     before the next one starts fading in — the previous pace was
//     racing the reader

@MainActor
struct ScanLabelRotator: View {

    let isActive: Bool

    @State private var idx: Int = 0

    private struct Phrase {
        let verb: String
        let tail: String
    }
    private static let phrases: [Phrase] = [
        // v1.0.9 D2 — UX expert pick. Tightens the rhythm of the
        // rotator + adds a heart on the last beat as a soft "almost
        // there" tell. "looking" is gentler than "reading" — less
        // clinical, more friend-energy.
        .init(verb: "looking", tail: " at your plate"),
        .init(verb: "finding", tail: " the good stuff"),
        .init(verb: "tallying", tail: " portions ♥"),
    ]

    var body: some View {
        let phrase = Self.phrases[idx]
        HStack(spacing: 0) {
            Text(phrase.verb)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
            Text(phrase.tail)
                .font(.custom("Fraunces72pt-Regular", size: 16))
        }
        .foregroundStyle(FoodTheme.textPrimary)
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.55), value: idx)
        .opacity(isActive ? 1 : 0)
        .animation(.easeInOut(duration: 0.35), value: isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("looking at your plate")
        .task(id: isActive) {
            guard isActive else { return }
            idx = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                if Task.isCancelled { return }
                idx = (idx + 1) % Self.phrases.count
            }
        }
    }
}

#endif  // canImport(UIKit)
