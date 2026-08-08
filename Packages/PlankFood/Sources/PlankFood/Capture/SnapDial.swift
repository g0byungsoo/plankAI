#if canImport(UIKit)
import SwiftUI

// MARK: - SnapDial (v23 THE STILL LIFE §2 — amended by founder steer)
//
// THE AIM — the targeting frame. Founder direction (2026-08-07,
// pass 3): the circle retired; the aim is FOUR CORNER BRACKETS in
// the premium-camera class (Cal AI / Apple / Halide) — engineered,
// not illustrated. The cardinal ticks retired with the circle.
//
// What survives is the identity MOTION: THE READING CLOSES THE
// FRAME. On capture, the complete soft-cornered outline draws
// itself from 12 o'clock over the resting brackets (~2.4s to 96%,
// an honest hold, then it accelerates shut the moment the
// understanding lands — causality, never a spinner).
//
// One geometry, three modes, morphing (never swapping):
//   scan    — a soft square (plates, bowls, stacks)
//   barcode — a wide rect (~2.4:1)
//   label   — a tall rect (3:4, "fit the panel")
//
// Reduce Motion: no trace; the caption line alone carries the wait.

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
    /// The width the frame composes against (screen width).
    public let availableWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Trace progress 0…1 along the outline from 12 o'clock.
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
            let w = availableWidth * 0.78
            return CGSize(width: w, height: w * 1.04)
        case .barcode:
            let w = availableWidth * 0.82
            return CGSize(width: w, height: w / 2.4)
        case .label:
            let w = availableWidth * 0.60
            return CGSize(width: w, height: w * 4.0 / 3.0)
        }
    }

    private var cornerRadius: CGFloat {
        switch mode {
        case .scan:    return 30
        case .barcode: return 16
        case .label:   return 20
        }
    }

    /// How far each bracket arm reaches along its edges, as a
    /// fraction of the shorter side (past the bend).
    private var armFraction: CGFloat {
        switch mode {
        case .scan:    return 0.22
        case .barcode: return 0.26
        case .label:   return 0.24
        }
    }

    public var body: some View {
        let size = frameSize
        ZStack {
            // THE AIM — four engineered corner brackets, resting.
            CornerBracketsShape(
                frameWidth: size.width,
                frameHeight: size.height,
                cornerRadius: cornerRadius,
                armLength: min(size.width, size.height) * armFraction
            )
            .stroke(
                Color.white.opacity(isScanning ? 0.30 : 0.92),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )

            // THE READING — the complete outline closes from
            // 12 o'clock over the resting brackets.
            if isScanning || scanComplete {
                DialFrameShape(
                    frameWidth: size.width,
                    frameHeight: size.height,
                    cornerRadius: cornerRadius
                )
                .trim(from: 0, to: traceTo)
                .stroke(
                    Color.white.opacity(0.95),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
            }
        }
        // One soft shadow so the strokes read over bright scenes.
        .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 1)
        .frame(width: size.width + 8, height: size.height + 8)
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
                // The understanding landed — the frame closes.
                withAnimation(.easeOut(duration: 0.26)) { traceTo = 1.0 }
            } else {
                traceTo = 0
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - CornerBracketsShape

/// Four corner brackets: each is arm → bend arc → arm, drawn as its
/// own subpath. Width, height, radius and arm length all animate so
/// the mode morph is one shape changing, never a swap.
struct CornerBracketsShape: Shape {
    var frameWidth: CGFloat
    var frameHeight: CGFloat
    var cornerRadius: CGFloat
    var armLength: CGFloat

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<CGFloat, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(frameWidth, frameHeight),
                AnimatablePair(cornerRadius, armLength)
            )
        }
        set {
            frameWidth = newValue.first.first
            frameHeight = newValue.first.second
            cornerRadius = newValue.second.first
            armLength = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let w = frameWidth
        let h = frameHeight
        let r = max(0.1, min(cornerRadius, min(w, h) / 2))
        // The arm reach past the bend, clamped so opposing corners
        // never touch.
        let reach = max(0, min(armLength, min(w, h) / 2 - r - 2))
        let minX = rect.midX - w / 2
        let maxX = rect.midX + w / 2
        let minY = rect.midY - h / 2
        let maxY = rect.midY + h / 2

        var p = Path()

        // Top-left: down-arm up to the bend, arc, right-arm out.
        p.move(to: CGPoint(x: minX, y: minY + r + reach))
        p.addLine(to: CGPoint(x: minX, y: minY + r))
        p.addArc(
            center: CGPoint(x: minX + r, y: minY + r), radius: r,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        p.addLine(to: CGPoint(x: minX + r + reach, y: minY))

        // Top-right.
        p.move(to: CGPoint(x: maxX - r - reach, y: minY))
        p.addLine(to: CGPoint(x: maxX - r, y: minY))
        p.addArc(
            center: CGPoint(x: maxX - r, y: minY + r), radius: r,
            startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        p.addLine(to: CGPoint(x: maxX, y: minY + r + reach))

        // Bottom-right.
        p.move(to: CGPoint(x: maxX, y: maxY - r - reach))
        p.addLine(to: CGPoint(x: maxX, y: maxY - r))
        p.addArc(
            center: CGPoint(x: maxX - r, y: maxY - r), radius: r,
            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        p.addLine(to: CGPoint(x: maxX - r - reach, y: maxY))

        // Bottom-left.
        p.move(to: CGPoint(x: minX + r + reach, y: maxY))
        p.addLine(to: CGPoint(x: minX + r, y: maxY))
        p.addArc(
            center: CGPoint(x: minX + r, y: maxY - r), radius: r,
            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        p.addLine(to: CGPoint(x: minX, y: maxY - r - reach))

        return p
    }
}

// MARK: - DialFrameShape

/// The complete soft-cornered outline the READING draws: a rounded
/// rectangle traced CLOCKWISE FROM TOP-CENTER, so a trim closes from
/// 12 o'clock at every aspect. Width, height and radius all animate.
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
