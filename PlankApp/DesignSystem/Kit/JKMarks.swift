import SwiftUI

// MARK: - JKMark — the JeniFit ritual symbol system
//
// docs/app_v3/07_SOUL_PASS.md. Not icons: small product MARKS, drawn
// as thin single-weight strokes (1.3pt, round caps) on a 24-grid —
// the register of a good stationery set. One idea per mark, soft
// curves only, no boxes, no literal pictograms. They restore the
// app's own language where SF Symbols read utility and bare text
// read anonymous.
//
// The set (one per ritual):
//   plate  — a circle with a morsel resting inside (food / snap)
//   path   — three footfall dots rising along an arc (steps)
//   line   — the trend easing down to its dot (weight / the line)
//   breath — two nested crescents (the exhale)
//   door   — a doorway with its swing hint (the method / the rep)
//   hop    — a soft arch over its landing (move)
//
// jeni's own mark stays the text heart (♥ U+FE0E) — never drawn,
// never replaced. Usage floors: rows and eyebrows only, one mark
// per row, never inside prose, never decorative repetition.

enum JKMarkKind {
    case plate, path, line, breath, door, hop
}

struct JKMark: View {
    let kind: JKMarkKind
    var size: CGFloat = 18
    var color: Color = Palette.cocoaSecondary
    var lineWidth: CGFloat = 1.3

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = canvasSize.width / 24.0   // 24-grid → render size
            var stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * s, y: y * s)
            }
            func dot(_ x: CGFloat, _ y: CGFloat, r: CGFloat) {
                let rect = CGRect(x: (x - r) * s, y: (y - r) * s,
                                  width: r * 2 * s, height: r * 2 * s)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }

            switch kind {
            case .plate:
                // The rim…
                let rim = Path(ellipseIn: CGRect(x: 3 * s, y: 3 * s,
                                                 width: 18 * s, height: 18 * s))
                ctx.stroke(rim, with: .color(color), style: stroke)
                // …and the morsel, resting just off-center.
                dot(14.2, 10.4, r: 1.7)

            case .path:
                // Three footfalls rising along a soft diagonal.
                dot(6, 17.5, r: 1.55)
                dot(12, 12.6, r: 1.55)
                dot(18, 7.7, r: 1.55)

            case .line:
                // The line, easing down — then its dot (the day's
                // number, small on purpose).
                var curve = Path()
                curve.move(to: pt(4, 8.5))
                curve.addCurve(to: pt(17.2, 15.6),
                               control1: pt(9.5, 8.0),
                               control2: pt(12.5, 16.4))
                ctx.stroke(curve, with: .color(color), style: stroke)
                dot(19.6, 16.1, r: 1.55)

            case .breath:
                // Two nested crescents — the exhale settling.
                var outer = Path()
                outer.addArc(center: pt(12, 12), radius: 8.4 * s,
                             startAngle: .degrees(-50), endAngle: .degrees(195),
                             clockwise: false)
                ctx.stroke(outer, with: .color(color), style: stroke)
                var inner = Path()
                inner.addArc(center: pt(12, 12), radius: 4.6 * s,
                             startAngle: .degrees(-30), endAngle: .degrees(140),
                             clockwise: false)
                ctx.stroke(inner, with: .color(color), style: stroke)

            case .door:
                // The doorway (the rep's grammar: what's the move?) —
                // jamb, header, and the swing hint.
                var frame = Path()
                frame.move(to: pt(7, 20))
                frame.addLine(to: pt(7, 5.5))
                frame.addQuadCurve(to: pt(17, 5.5), control: pt(12, 3.2))
                frame.addLine(to: pt(17, 20))
                ctx.stroke(frame, with: .color(color), style: stroke)
                var swing = Path()
                swing.move(to: pt(17, 20))
                swing.addQuadCurve(to: pt(21.2, 16.4), control: pt(20.4, 19.4))
                stroke.lineWidth = lineWidth * 0.85
                ctx.stroke(swing, with: .color(color.opacity(0.65)), style: stroke)
                dot(14.6, 12.6, r: 1.1)

            case .hop:
                // A soft arch over its landing — movement without a
                // gym in sight.
                var arch = Path()
                arch.move(to: pt(5, 17))
                arch.addQuadCurve(to: pt(19, 17), control: pt(12, 4.5))
                ctx.stroke(arch, with: .color(color), style: stroke)
                var ground = Path()
                ground.move(to: pt(8.4, 20.2))
                ground.addLine(to: pt(15.6, 20.2))
                stroke.lineWidth = lineWidth * 0.85
                ctx.stroke(ground, with: .color(color.opacity(0.65)), style: stroke)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension JKMarkKind {
    /// The mark for a plan beat — ONE mapping, shared by Home's
    /// rhythm rows and any surface that names a ritual.
    static func mark(for beat: ProgramDayPrescription) -> JKMarkKind? {
        switch beat {
        case .snapMeal: return .plate
        case .steps: return .path
        case .weighIn: return .line
        case .breath: return .breath
        case .lesson: return .door
        case .workout: return .hop
        case .plank, .water, .measurements: return nil
        }
    }
}
