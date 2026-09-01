import SwiftUI
import UIKit

// MARK: - BodyFigure (app v10)
//
// ONE drawn figure, shared by every surface that needs a body shape
// that is not a real scan: the Home mirror's zero-scan outline
// (dashed ghost) and the DEBUG seed scans (filled ink). A standing
// A-pose front silhouette — head, sloped shoulders, arms a touch
// away from the body (the capture guidance pose), a waist that can
// narrow, legs with real daylight between them. Never a pictogram:
// the outline is smoothed through its points so it reads as a
// person, not a restroom sign.
//
// The figure is DRAWN, never derived from anyone's photo — it is
// product furniture, in the same ink the real silhouettes wear.

enum BodyFigure {

    /// The figure's parts. Kept as SEPARATE paths so fills never
    /// cancel where they overlap (mixed winding directions under
    /// non-zero fill punch paper-colored slits — the bug the first
    /// render shipped). Stroke callers use `path` (the union);
    /// fill callers paint each part.
    static func subpaths(in rect: CGRect, waist: CGFloat = 1.0) -> [Path] {
        let w = rect.width, h = rect.height
        let ox = rect.minX, oy = rect.minY

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * w, y: oy + y * h)
        }

        // — head (ellipse) + neck, one part
        var headPart = Path()
        let headCenter = pt(0.5, 0.128)
        let headRX = 0.094 * w, headRY = 0.070 * h
        headPart.addEllipse(in: CGRect(
            x: headCenter.x - headRX, y: headCenter.y - headRY,
            width: headRX * 2, height: headRY * 2
        ))
        // The neck reads as a soft column, not a box — at guide
        // weight (v10.4 strokes this outline as THE INSTRUMENT's
        // illustration) square corners under the jaw looked drawn by
        // a machine.
        headPart.addRoundedRect(
            in: CGRect(
                x: ox + (0.5 - 0.042) * w, y: oy + 0.176 * h,
                width: 0.084 * w, height: 0.060 * h
            ),
            cornerSize: CGSize(width: 0.030 * w, height: 0.014 * h)
        )

        // — the body as ONE closed smoothed outline, arms included
        // (shoulder → outer arm → hand → inner arm → armpit →
        // torso → legs). No composed shapes, so no overlap geometry
        // can ever slit the figure; the armpit daylight is drawn,
        // not accidental. The fullest figures' arms graze the hip —
        // non-zero winding keeps any self-touch solid ink.
        let waistHalf = 0.176 * waist
        let hipHalf = 0.215 * waist
        let thighOuter = 0.196 * waist
        let right: [(CGFloat, CGFloat)] = [
            (0.5 + 0.042, 0.222),          // neck base
            (0.5 + 0.182, 0.256),          // shoulder
            (0.5 + 0.228, 0.310),          // deltoid
            (0.5 + 0.255, 0.405),          // outer arm
            (0.5 + 0.268, 0.512),          // outer wrist
            (0.5 + 0.258, 0.565),          // hand
            (0.5 + 0.220, 0.548),          // inner wrist
            (0.5 + 0.206, 0.462),          // inner forearm
            (0.5 + 0.184, 0.386),          // inner elbow
            (0.5 + 0.150, 0.322),          // armpit
            (0.5 + 0.152, 0.374),          // rib
            (0.5 + waistHalf, 0.438),      // waist
            (0.5 + hipHalf, 0.522),        // hip
            (0.5 + thighOuter, 0.604),     // outer thigh
            (0.5 + 0.118, 0.716),          // outer knee
            (0.5 + 0.100, 0.792),          // outer calf
            (0.5 + 0.062, 0.888),          // outer ankle
            (0.5 + 0.084, 0.938),          // foot edge
            (0.5 + 0.086, 0.952),          // toe
            (0.5 + 0.024, 0.952),          // heel
            (0.5 + 0.024, 0.900),          // inner ankle
            (0.5 + 0.030, 0.716),          // inner knee
            (0.5 + 0.024, 0.612),          // inner thigh
            (0.5 + 0.000, 0.566)           // crotch
        ]
        let left = right.reversed().map { (1.0 - $0.0, $0.1) }
        let outline = smoothedClosed((right + left).map { pt($0.0, $0.1) })
        return [outline, headPart]
    }

    /// The figure's OUTER boundary (true union, iOS 16+ path
    /// booleans) — the strokable ghost: no internal capsule edges.
    static func path(in rect: CGRect, waist: CGFloat = 1.0) -> Path {
        subpaths(in: rect, waist: waist).reduce(Path()) { $0.union($1) }
    }

    /// Quad-smoothed closed outline: each vertex becomes the control
    /// point of a curve through segment midpoints — organic, cheap.
    private static func smoothedClosed(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 2 else { return path }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        path.move(to: mid(points[points.count - 1], points[0]))
        for i in 0..<points.count {
            let next = points[(i + 1) % points.count]
            path.addQuadCurve(to: mid(points[i], next), control: points[i])
        }
        path.closeSubpath()
        return path
    }

    /// The figure rendered as ink on paper at scan resolution — the
    /// seed scans' image (DEBUG QA) and any future furniture render.
    static func inkImage(size: CGSize, waist: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 252/255, green: 250/255, blue: 247/255, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 42/255, green: 31/255, blue: 30/255, alpha: 1).setFill()
            // Inset so the figure floats on its paper like a print.
            let inset = CGRect(origin: .zero, size: size)
                .insetBy(dx: size.width * 0.16, dy: size.height * 0.07)
            // Each part fills on its own — overlapping subpaths can
            // never wind against each other and slit the figure.
            for sub in subpaths(in: inset, waist: waist) {
                ctx.cgContext.addPath(sub.cgPath)
                ctx.cgContext.fillPath(using: .winding)
            }
        }
    }
}

// MARK: - The waist band render (v10.2)

extension BodyFigure {
    /// The abdomen band of the drawn figure as an ink plate — the
    /// waist-era seed material and the sim's develop substitute.
    /// Crops the figure render between the ribs and the hip crest,
    /// where the `waist` knob does its narrowing.
    static func inkBand(waist: CGFloat) -> UIImage {
        let full = inkImage(size: CGSize(width: 1080, height: 1440), waist: waist)
        let band = WaistCrop.Band(top: 0.66, bottom: 0.44, centerX: 0.5)
        return WaistCrop.image(full, band: band)
    }
}

// MARK: - BodyMat
//
// The ONE mat every figure surface wears (v10 law: the figure is
// always matted on its own paper). Fill = the silhouette's exact
// ground, so a seam cannot exist; a 0.5pt ink hairline and the
// house ink shadow give it a print's edge on the grained page.
// Sizing belongs to callers — the scan derivatives are 3:4, so
// callers pin that aspect.

struct BodyMat: View {
    let image: UIImage?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
        ZStack {
            shape.fill(Palette.bgPrimary)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.cocoaPrimary.opacity(0.10), lineWidth: 0.5))
        .shadow(color: Palette.cocoaPrimary.opacity(0.07), radius: 18, y: 6)
    }
}
