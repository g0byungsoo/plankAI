import SwiftUI

// MARK: - V8Glyph — the quiz speaks in pictures
//
// Founder: "use images instead of text" on the quiz. Jeni never uses
// stock; the images are DRAWN — thin single-weight strokes in the
// JKMark stationery register (one idea per glyph, soft curves, the
// one-colour law). Each quiz option leads with its picture; the word
// stays as the caption.

enum V8Glyph: Equatable {
    // outcome
    case mirrorSelf, quietWave, energyRise, hanger, holdLine
    // history
    case oneDot, twoDots, reboundMini, spiral
    // food relationship
    case plateMorsel, warmBowl, sharedPlates, checklist, tangle
}

struct V8GlyphView: View {
    let glyph: V8Glyph
    var size: CGFloat = 44
    var color: Color = Palette.cocoaPrimary

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = canvasSize.width / 24.0
            let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func draw(_ path: Path, _ alpha: Double = 1, width: CGFloat = 1.5) {
                var st = stroke; st.lineWidth = width
                ctx.stroke(path, with: .color(color.opacity(alpha)), style: st)
            }
            func dot(_ x: CGFloat, _ y: CGFloat, r: CGFloat = 1.5, _ alpha: Double = 1) {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: (x - r) * s, y: (y - r) * s,
                                           width: r * 2 * s, height: r * 2 * s)),
                    with: .color(color.opacity(alpha))
                )
            }

            switch glyph {
            case .mirrorSelf:
                // A figure and its truer reflection, one line apart.
                var head = Path(); head.addArc(center: pt(8, 7), radius: 2.4 * s,
                                               startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                draw(head)
                var body = Path()
                body.move(to: pt(8, 9.6)); body.addQuadCurve(to: pt(8, 17.5), control: pt(6.6, 13.5))
                draw(body)
                var mirror = Path()
                mirror.move(to: pt(15.5, 4.5)); mirror.addLine(to: pt(15.5, 19.5))
                draw(mirror, 0.45)
                var rHead = Path(); rHead.addArc(center: pt(19.5, 7), radius: 2.4 * s,
                                                 startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                draw(rHead, 0.45)
                var rBody = Path()
                rBody.move(to: pt(19.5, 9.6)); rBody.addQuadCurve(to: pt(19.5, 17.5), control: pt(20.9, 13.5))
                draw(rBody, 0.45)

            case .quietWave:
                // The noise settling to a hush (the figure's signature).
                var p = Path()
                p.move(to: pt(3, 12))
                p.addCurve(to: pt(9, 12), control1: pt(4.6, 5.5), control2: pt(7.4, 18.5))
                p.addCurve(to: pt(14.5, 12), control1: pt(10.6, 8), control2: pt(12.9, 16))
                p.addCurve(to: pt(21, 12), control1: pt(16.5, 10.6), control2: pt(18.8, 12.6))
                draw(p)
                dot(21.6, 12, r: 1.3)

            case .energyRise:
                var p = Path()
                p.move(to: pt(4, 18))
                p.addCurve(to: pt(20, 7), control1: pt(10, 17.4), control2: pt(15.5, 12.8))
                draw(p)
                var sun = Path(); sun.addArc(center: pt(20, 7), radius: 1.8 * s,
                                             startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                draw(sun)

            case .hanger:
                var hook = Path()
                hook.move(to: pt(12, 4.5))
                hook.addQuadCurve(to: pt(13.8, 6.4), control: pt(14.2, 4.6))
                draw(hook)
                var frame = Path()
                frame.move(to: pt(12, 8))
                frame.addLine(to: pt(4.5, 14.5))
                frame.addQuadCurve(to: pt(6, 16.2), control: pt(4.6, 16.2))
                frame.addLine(to: pt(18, 16.2))
                frame.addQuadCurve(to: pt(19.5, 14.5), control: pt(19.4, 16.2))
                frame.closeSubpath()
                draw(frame)

            case .holdLine:
                // Down, then held — the keep.
                var p = Path()
                p.move(to: pt(3.5, 8))
                p.addCurve(to: pt(13, 15.5), control1: pt(7, 9), control2: pt(10, 14))
                p.addLine(to: pt(20.5, 15.5))
                draw(p)
                dot(20.5, 15.5, r: 1.4)

            case .oneDot:
                var p = Path()
                p.move(to: pt(4, 16)); p.addQuadCurve(to: pt(20, 16), control: pt(12, 13.4))
                draw(p, 0.35)
                dot(6, 15.4, r: 1.8)

            case .twoDots:
                var p = Path()
                p.move(to: pt(4, 16)); p.addQuadCurve(to: pt(20, 16), control: pt(12, 13.4))
                draw(p, 0.35)
                dot(6, 15.4, r: 1.8)
                dot(12, 14.6, r: 1.8)

            case .reboundMini:
                var quick = Path()
                quick.move(to: pt(3.5, 9))
                quick.addCurve(to: pt(11, 16), control1: pt(6, 9.6), control2: pt(8.6, 15))
                quick.addCurve(to: pt(20.5, 6.5), control1: pt(13.8, 16.6), control2: pt(17.6, 9.8))
                draw(quick, 0.5)
                var paced = Path()
                paced.move(to: pt(3.5, 9))
                paced.addCurve(to: pt(20.5, 13.5), control1: pt(9, 10), control2: pt(15.5, 13))
                draw(paced)

            case .spiral:
                var p = Path()
                p.addArc(center: pt(12, 12), radius: 7 * s, startAngle: .degrees(-90),
                         endAngle: .degrees(150), clockwise: false)
                p.addArc(center: pt(12.6, 12.4), radius: 4.2 * s, startAngle: .degrees(150),
                         endAngle: .degrees(30), clockwise: false)
                draw(p)
                dot(13.4, 10.2, r: 1.3)

            case .plateMorsel:
                var rim = Path(ellipseIn: CGRect(x: 4 * s, y: 4 * s, width: 16 * s, height: 16 * s))
                draw(rim)
                dot(14.4, 10.2, r: 1.7)

            case .warmBowl:
                var bowl = Path()
                bowl.move(to: pt(5, 13))
                bowl.addQuadCurve(to: pt(19, 13), control: pt(12, 20.5))
                bowl.move(to: pt(5, 13)); bowl.addLine(to: pt(19, 13))
                draw(bowl)
                var s1 = Path()
                s1.move(to: pt(9.6, 10.2)); s1.addQuadCurve(to: pt(9.6, 6.2), control: pt(11.2, 8.2))
                draw(s1, 0.55)
                var s2 = Path()
                s2.move(to: pt(14.4, 10.2)); s2.addQuadCurve(to: pt(14.4, 6.2), control: pt(12.8, 8.2))
                draw(s2, 0.55)

            case .sharedPlates:
                var a = Path(ellipseIn: CGRect(x: 3.4 * s, y: 8 * s, width: 10 * s, height: 10 * s))
                draw(a)
                var b = Path(ellipseIn: CGRect(x: 11 * s, y: 5.6 * s, width: 9 * s, height: 9 * s))
                draw(b, 0.55)

            case .checklist:
                for (i, y) in [7.2, 12.0, 16.8].enumerated() {
                    var line = Path()
                    line.move(to: pt(9.5, CGFloat(y))); line.addLine(to: pt(20, CGFloat(y)))
                    draw(line, i == 2 ? 0.5 : 1)
                    var tick = Path()
                    tick.move(to: pt(4.4, CGFloat(y)))
                    tick.addLine(to: pt(5.6, CGFloat(y + 1.1)))
                    tick.addLine(to: pt(7.4, CGFloat(y - 1.3)))
                    draw(tick, i == 2 ? 0.5 : 1, width: 1.3)
                }

            case .tangle:
                var p = Path()
                p.move(to: pt(4, 14))
                p.addCurve(to: pt(12, 10), control1: pt(7, 6), control2: pt(8.5, 16))
                p.addCurve(to: pt(15, 14), control1: pt(15.5, 4.5), control2: pt(11.4, 15))
                p.addCurve(to: pt(20.5, 10.5), control1: pt(18, 13), control2: pt(18.6, 8.4))
                draw(p)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - V8QuizCard — the image-led option
//
// A soft card that leads with its drawn picture; the word captions.
// Two-up grid, one tap, spring press — the frictionless quiz.

struct V8QuizCard: View {
    let glyph: V8Glyph
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                V8GlyphView(
                    glyph: glyph,
                    size: 46,
                    color: selected ? Palette.textInverse : Palette.cocoaPrimary
                )
                Text(label)
                    .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? Palette.bgInverse : Palette.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                selected ? Color.clear : Palette.hairlineCocoa,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: Palette.textPrimary.opacity(selected ? 0.10 : 0.045),
                        radius: 14, x: 0, y: 6
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(JeniPressable())
        .animation(JeniMotion.morph, value: selected)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct V8QuizGrid: View {
    let items: [V8QuizItem]
    let selected: String?
    let onPick: (String) -> Void

    private let cols = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            ForEach(items, id: \.option.id) { item in
                V8QuizCard(
                    glyph: item.glyph,
                    label: item.option.label,
                    selected: selected == item.option.id,
                    action: { onPick(item.option.id) }
                )
            }
        }
    }
}
