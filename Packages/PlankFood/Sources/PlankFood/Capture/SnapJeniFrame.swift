#if canImport(UIKit)
import SwiftUI

// MARK: - SnapJeniCorners (v22 ONE HAND — the frame that is ours)
//
// The founder: "the capture frame itself deserves redesign… design a
// frame that belongs only to Jeni." Every camera app draws brackets;
// ours are DRAWN — four corner strokes in the stationery register
// (the doodle set's hand): round caps, a soft bend, and a breath of
// wobble so no two arms are machine-straight. White over the glass,
// nothing else — the rose border retired (a border is the ordinary-
// camera tell, and the card law's lesson holds here too: separation
// by fill, identity by hand).
//
// While a scan runs the corners BREATHE (a slow 1.5% swell) — focus
// as a living thing, not a state color. Reduce Motion holds still.

struct SnapJeniCorners: View {
    /// Breathing only while understanding is in flight.
    let isScanning: Bool
    var inset: CGFloat = 18
    var arm: CGFloat = 34
    var lineWidth: CGFloat = 2.6

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

/// Four hand-bent corner brackets. Each arm carries one soft
/// mid-point drift (~1.3pt) so the stroke reads drawn, not drafted;
/// the drifts are fixed per corner (deterministic — the frame is a
/// mark, not a random sketch).
private struct JeniCornerStrokes: Shape {
    let inset: CGFloat
    let arm: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 14   // the corner's bend radius

        func corner(_ cx: CGFloat, _ cy: CGFloat,
                    _ dx: CGFloat, _ dy: CGFloat,
                    driftA: CGFloat, driftB: CGFloat) {
            // Vertical arm end → bend → horizontal arm end, drawn as
            // one stroke. dx/dy are +1/-1 direction multipliers.
            let vEnd = CGPoint(x: cx, y: cy + dy * arm)
            let vMid = CGPoint(x: cx + dx * driftA, y: cy + dy * (arm * 0.55))
            let bendStart = CGPoint(x: cx, y: cy + dy * r)
            let cornerPt = CGPoint(x: cx, y: cy)
            let bendEnd = CGPoint(x: cx + dx * r, y: cy)
            let hMid = CGPoint(x: cx + dx * (arm * 0.55), y: cy + dy * driftB)
            let hEnd = CGPoint(x: cx + dx * arm, y: cy)

            p.move(to: vEnd)
            p.addQuadCurve(to: bendStart, control: vMid)
            p.addQuadCurve(to: bendEnd, control: cornerPt)
            p.addQuadCurve(to: hEnd, control: hMid)
        }

        corner(rect.minX + inset, rect.minY + inset, 1, 1,
               driftA: 1.3, driftB: -1.1)
        corner(rect.maxX - inset, rect.minY + inset, -1, 1,
               driftA: -1.1, driftB: 1.2)
        corner(rect.minX + inset, rect.maxY - inset, 1, -1,
               driftA: -1.2, driftB: 1.3)
        corner(rect.maxX - inset, rect.maxY - inset, -1, -1,
               driftA: 1.1, driftB: -1.3)
        return p
    }
}

#endif  // canImport(UIKit)
