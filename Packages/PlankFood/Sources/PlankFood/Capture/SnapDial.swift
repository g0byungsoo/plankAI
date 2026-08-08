#if canImport(UIKit)
import SwiftUI

// MARK: - SnapDial (v23 THE STILL LIFE §2)
//
// THE DIAL — the identity targeting frame. One hairline shape with
// four cardinal ticks, an instrument face over the live feed:
//
//   scan    — a circle (a plate seen from above; Home's ring closes
//             the loop: she composes the meal in the ring, the ring
//             on Home fills with what it became)
//   barcode — a wide rounded rect (~2.4:1)
//   label   — a tall rounded rect (3:4, "fit the panel")
//
// The shape MORPHS between modes (one geometry animating, never a
// swap). On capture, THE READING CLOSES THE CIRCLE: the stroke
// redraws itself from 12 o'clock to ~96% and holds — visible,
// honest tension — then accelerates closed the moment the
// understanding lands. Causality, not a spinner.
//
// The path deliberately starts at top-center so `.trim` closes from
// 12 o'clock in every mode. Nothing ever renders inside the frame:
// no crosshair, no grid, no reticle. Reduce Motion: no trace; the
// caption line alone carries the wait.

public enum DialMode: String, CaseIterable, Identifiable, Sendable {
    case scan
    case barcode
    case label

    public var id: String { rawValue }

    /// The mode strip word (lowercase, plain).
    public var word: String { rawValue }
}

public struct SnapDial: View {

    public let mode: DialMode
    /// A reading is in flight — the trace draws to its hold point.
    public let isScanning: Bool
    /// The understanding landed — the trace accelerates closed.
    public let scanComplete: Bool
    /// The width the dial composes against (screen width).
    public let availableWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Trace progress 0…1 along the frame from 12 o'clock.
    @State private var traceTo: CGFloat = 0

    public init(
        mode: DialMode,
        isScanning: Bool,
        scanComplete: Bool,
        availableWidth: CGFloat
    ) {
        self.mode = mode
        self.isScanning = isScanning
        self.scanComplete = scanComplete
        self.availableWidth = availableWidth
    }

    // MARK: Geometry per mode

    private var frameSize: CGSize {
        switch mode {
        case .scan:
            let d = availableWidth * 0.78
            return CGSize(width: d, height: d)
        case .barcode:
            let w = availableWidth * 0.82
            return CGSize(width: w, height: w / 2.4)
        case .label:
            let w = availableWidth * 0.60
            return CGSize(width: w, height: w * 4.0 / 3.0)
        }
    }

    private var cornerRadius: CGFloat {
        // Pass 2 (frame-caught): 24 read bulbous on the barcode's
        // short rect — the radius follows each frame's scale.
        switch mode {
        case .scan:    return frameSize.width / 2
        case .barcode: return 16
        case .label:   return 20
        }
    }

    private static let tickLength: CGFloat = 10
    private static let tickGap: CGFloat = 5

    public var body: some View {
        let size = frameSize
        ZStack {
            // The base hairline — recedes while the trace draws.
            DialFrameShape(
                frameWidth: size.width,
                frameHeight: size.height,
                cornerRadius: cornerRadius
            )
            .stroke(
                Color.white.opacity(isScanning ? 0.30 : 0.92),
                style: StrokeStyle(lineWidth: 1, lineCap: .round)
            )

            // The reading's trace — closes from 12 o'clock.
            if isScanning || scanComplete {
                DialFrameShape(
                    frameWidth: size.width,
                    frameHeight: size.height,
                    cornerRadius: cornerRadius
                )
                .trim(from: 0, to: traceTo)
                .stroke(
                    Color.white.opacity(0.95),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
            }

            // Four cardinal ticks just outside the rim — the
            // instrument's minute marks.
            tick.offset(y: -(size.height / 2 + Self.tickGap + Self.tickLength / 2))
            tick.offset(y:  (size.height / 2 + Self.tickGap + Self.tickLength / 2))
            tick.rotationEffect(.degrees(90))
                .offset(x: -(size.width / 2 + Self.tickGap + Self.tickLength / 2))
            tick.rotationEffect(.degrees(90))
                .offset(x:  (size.width / 2 + Self.tickGap + Self.tickLength / 2))
        }
        // One soft shadow so the hairline reads over bright scenes.
        .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 1)
        .frame(
            width: size.width + (Self.tickGap + Self.tickLength) * 2,
            height: size.height + (Self.tickGap + Self.tickLength) * 2
        )
        // Mode morph — JeniMotion.morph's numbers (the package cannot
        // import the app kit; the values are the law's, restated).
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: mode)
        .onChange(of: isScanning) { _, scanning in
            guard !reduceMotion else { return }
            if scanning {
                traceTo = 0
                // The draw curve at reading pace: ~2.4s to the hold
                // point, where it waits for the understanding.
                withAnimation(.timingCurve(0.30, 0.8, 0.30, 1.0, duration: 2.4)) {
                    traceTo = 0.96
                }
            } else if !scanComplete {
                // The reading didn't land (failure / cancel) — the
                // trace lets go quietly.
                withAnimation(.easeOut(duration: 0.25)) { traceTo = 0 }
            }
        }
        .onChange(of: scanComplete) { _, complete in
            if complete {
                // The understanding landed — the circle closes.
                withAnimation(.easeOut(duration: 0.26)) { traceTo = 1.0 }
            } else {
                traceTo = 0
            }
        }
        .accessibilityHidden(true)
    }

    private var tick: some View {
        Capsule()
            .fill(Color.white.opacity(0.85))
            .frame(width: 2, height: Self.tickLength)
    }
}

// MARK: - DialFrameShape

/// The dial's one path: a rounded rectangle (a circle when the radius
/// reaches half the side) drawn CLOCKWISE FROM TOP-CENTER, so a trim
/// closes from 12 o'clock in every mode. Width, height and radius all
/// animate — the mode morph is one shape changing, never a swap.
struct DialFrameShape: Shape {
    var frameWidth: CGFloat
    var frameHeight: CGFloat
    var cornerRadius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(frameWidth, frameHeight), cornerRadius) }
        set {
            frameWidth = newValue.first.first
            frameHeight = newValue.first.second
            cornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let w = frameWidth
        let h = frameHeight
        let r = max(0.1, min(cornerRadius, min(w, h) / 2))
        let cx = rect.midX
        let cy = rect.midY
        let minX = cx - w / 2
        let maxX = cx + w / 2
        let minY = cy - h / 2
        let maxY = cy + h / 2

        var p = Path()
        p.move(to: CGPoint(x: cx, y: minY))
        p.addLine(to: CGPoint(x: maxX - r, y: minY))
        p.addArc(
            center: CGPoint(x: maxX - r, y: minY + r), radius: r,
            startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        p.addLine(to: CGPoint(x: maxX, y: maxY - r))
        p.addArc(
            center: CGPoint(x: maxX - r, y: maxY - r), radius: r,
            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        p.addLine(to: CGPoint(x: minX + r, y: maxY))
        p.addArc(
            center: CGPoint(x: minX + r, y: maxY - r), radius: r,
            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        p.addLine(to: CGPoint(x: minX, y: minY + r))
        p.addArc(
            center: CGPoint(x: minX + r, y: minY + r), radius: r,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        p.addLine(to: CGPoint(x: cx, y: minY))
        return p
    }
}

#endif  // canImport(UIKit)
