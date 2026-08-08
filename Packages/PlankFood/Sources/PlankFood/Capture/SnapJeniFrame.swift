#if canImport(UIKit)
import SwiftUI

// MARK: - SnapJeniCorners (v22 ONE HAND — the frame that is ours)
//
// v22.3 (founder): "the scanner is a precision instrument — elegant
// rounded white corner brackets, perfectly aligned, minimal, quiet."
// The drawn-wobble corners read charming but not precise; the
// brackets are now exact quarter-bend strokes (Vision Pro / Halide
// class), white over the glass, nothing else. Identity lives in the
// breathing and the discovery, not in the linework.
//
// While a scan runs the corners BREATHE (a slow 1.5% swell) — focus
// as a living thing, not a state color. Reduce Motion holds still.

struct SnapJeniCorners: View {
    /// Breathing only while understanding is in flight.
    let isScanning: Bool
    var inset: CGFloat = 18
    var arm: CGFloat = 34
    var lineWidth: CGFloat = 3

    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            JeniCornerStrokes(inset: inset, arm: arm)
                .stroke(
                    Color.white.opacity(0.92),
                    style: StrokeStyle(lineWidth: lineWidth,
                                       lineCap: .round, lineJoin: .round)
                )
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(breathe ? 1.015 : 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: isScanning) { _, scanning in
            guard !reduceMotion else { return }
            if scanning {
                withAnimation(.easeInOut(duration: 1.4)
                    .repeatForever(autoreverses: true)) {
                    breathe = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.4)) { breathe = false }
            }
        }
    }
}

/// Four exact corner brackets: straight arms into a true quarter
/// bend, one stroke each. Perfectly aligned, minimal, quiet.
private struct JeniCornerStrokes: Shape {
    let inset: CGFloat
    let arm: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 16   // the corner's bend radius

        func corner(_ cx: CGFloat, _ cy: CGFloat,
                    _ dx: CGFloat, _ dy: CGFloat) {
            let vEnd = CGPoint(x: cx, y: cy + dy * arm)
            let bendStart = CGPoint(x: cx, y: cy + dy * r)
            let bendEnd = CGPoint(x: cx + dx * r, y: cy)
            let hEnd = CGPoint(x: cx + dx * arm, y: cy)
            p.move(to: vEnd)
            p.addLine(to: bendStart)
            p.addQuadCurve(to: bendEnd,
                           control: CGPoint(x: cx, y: cy))
            p.addLine(to: hEnd)
        }

        corner(rect.minX + inset, rect.minY + inset, 1, 1)
        corner(rect.maxX - inset, rect.minY + inset, -1, 1)
        corner(rect.minX + inset, rect.maxY - inset, 1, -1)
        corner(rect.maxX - inset, rect.maxY - inset, -1, -1)
        return p
    }
}

#endif  // canImport(UIKit)
