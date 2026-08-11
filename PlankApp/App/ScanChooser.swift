import SwiftUI
import UIKit

// MARK: - ScanChooser (v25 E5 — rebuilt)
//
// The founder pointed at this screen directly. Its first cut (v11.5 N)
// chased Lovi's "Make a New Scan" and missed for four structural
// reasons, all visible in a capture and all recorded in
// docs/app_v25/17_E5_DECISION.md §5.2:
//
//   1. NESTED CONTAINERS — a white card holding a grey tile holding a
//      drawing. Card-in-card.
//   2. THE ART CARRIED NO INFORMATION — three capsules in a ring read
//      as an audio waveform; the body door was a heavy black blob, the
//      loudest object on a screen belonging to a body-neutral product.
//   3. FOUR GEOMETRIES IN 350pt — card, card, capsule pill, circle —
//      floating in a vertically-centred stack over a large void.
//   4. THE DIM ERASED INSTEAD OF SOFTENING, so "your page went soft"
//      never landed.
//
// What the references were good for (principles, not pixels): a chooser
// is a bottom-anchored composed object in the thumb zone; the interior
// of a door should carry substance rather than an icon; the close sits
// tight to the group it closes.
//
// What is JENI's, and not borrowed: THE DOORS ARE MADE OF HER RECORD.
// The meal door carries her own last plate's photograph; the again door
// names the dish by name. Nothing decorative is added — the substance
// inside the card is data she made. The body door stays DRAWN on
// purpose: body privacy (L4) says her scans are not chooser art.
//
// Order changed too: the meal leads. It is the overwhelmingly more
// frequent action and the one the product's thesis rests on.

struct ScanChooser: View {
    let onBody: () -> Void
    let onPlate: () -> Void
    /// v25 E4 — the plate's memory: the one-tap relog rail. nil =
    /// nothing on record yet (the row never advertises an empty
    /// sheet).
    var onAgain: (() -> Void)? = nil
    /// v25 E5 — her last plate, if she has one. The meal door wears the
    /// photograph; the again door wears the name.
    var lastPlateTitle: String? = nil
    var lastPlatePhoto: UIImage? = nil
    let onClose: () -> Void

    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let doorRadius: CGFloat = 24

    var body: some View {
        ZStack {
            scrim

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                Text("what are we looking at?")
                    .font(.custom("JeniHeroSerif-Regular", size: 27, relativeTo: .title2))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.md)
                    .jeniArrive(arrived, index: 0)

                HStack(spacing: 12) {
                    door(
                        title: "a meal",
                        detail: "counted from one photo",
                        index: 1,
                        art: { PlateDoorArt(photo: lastPlatePhoto) },
                        action: onPlate
                    )
                    door(
                        title: "your body",
                        detail: "the waist, week to week",
                        index: 2,
                        art: { BodyDoorArt() },
                        action: onBody
                    )
                }

                // The third door, in the SAME material as the other two
                // — the floating pill was a fourth geometry. It reads
                // as a door because it is one.
                if let onAgain {
                    Button(action: onAgain) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.cocoaSecondary)
                                .accessibilityHidden(true)
                            Text(againLabel)
                                .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                                .foregroundStyle(Palette.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Space.md)
                        .frame(height: 54)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: doorRadius, style: .continuous)
                                .fill(Palette.bgElevated)
                                .shadow(color: Palette.textPrimary.opacity(0.06),
                                        radius: 14, y: 6)
                        )
                    }
                    .buttonStyle(JeniPressable())
                    .padding(.top, 12)
                    .jeniArrive(arrived, index: 3)
                    .accessibilityLabel(againAccessibilityLabel)
                }

                // Tight to the group it closes, not adrift below it.
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Palette.bgElevated)
                                .shadow(color: Palette.textPrimary.opacity(0.06),
                                        radius: 12, y: 5)
                        )
                }
                .buttonStyle(JeniPressable())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Space.lg)
                .jeniArrive(arrived, index: 4)
                .accessibilityLabel("close")
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .transition(.opacity)
        .task {
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 40_000_000)
            arrived = true
        }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - The scrim
    //
    // The page she came from goes SOFT, not away. The first cut stacked
    // ultraThinMaterial + 12% ink over a cream app and left grey noise
    // with no figure/ground. A thicker blur plus a warm paper veil dims
    // the page while keeping its shapes legible, so the doors read as
    // rising off her own screen.

    private var scrim: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            // INK over the blur, never paper: a paper wash on a cream
            // app turns the page white and the doors stop separating
            // (caught twice now — once in v11.5, once in this era's
            // first cut, which added a 42% paper layer and erased the
            // page completely). The gradient deepens toward the doors
            // so the group has something to sit against.
            LinearGradient(
                colors: [Palette.textPrimary.opacity(0.06),
                         Palette.textPrimary.opacity(0.20)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { onClose() }
        .accessibilityLabel("close")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - A door

    private func door<Art: View>(
        title: String,
        detail: String,
        index: Int,
        @ViewBuilder art: @escaping () -> Art,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // The art sits ON the card's own paper at real scale.
                // No inner tile — that was the nested container.
                art()
                    .frame(maxWidth: .infinity)
                    .frame(height: 108)
                    .padding(.bottom, 14)

                Text(title)
                    .font(.custom("JeniHeroSerif-Regular", size: 20, relativeTo: .title3))
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: doorRadius, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.textPrimary.opacity(0.07),
                            radius: 18, y: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniPressable())
        .jeniArrive(arrived, index: index)
        .accessibilityLabel("\(title). \(detail)")
    }

    // MARK: - The again door's words

    private var againLabel: String {
        guard let t = lastPlateTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !t.isEmpty
        else { return "log a recent plate again" }
        return "again · \(t.lowercased())"
    }

    private var againAccessibilityLabel: String {
        guard let t = lastPlateTitle, !t.isEmpty else { return "log a recent plate again" }
        return "log \(t) again"
    }
}

// MARK: - The doors' art
//
// Drawn in the same ink vocabulary as the instrument they open, at a
// scale that reads at a glance. The meal door prefers HER photograph;
// the drawing is the empty state, not the default.

/// Her last plate, or a drawn one. The photograph is the whole idea:
/// the door is made of her record.
private struct PlateDoorArt: View {
    let photo: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        // Concentric with the door: outer 24 less the 14pt inset.
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        // A whisper of ink keeps a bright photograph
                        // from shouting over the serif beneath it.
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Palette.textPrimary.opacity(0.05))
                        )
                } else {
                    EmptyPlateDoor()
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The meal door with nothing on record yet. NOT a picture of food —
/// a picture of the ACTION: the scan tab's own corner brackets with a
/// plate inside them. It says "point this at a plate", which is what
/// the door does, and it borrows the glyph already in the tab bar so
/// the door and its destination speak the same language.
private struct EmptyPlateDoor: View {
    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height) * 0.96
            let corner = d * 0.26
            let ink = Palette.cocoaPrimary
            ZStack {
                // The plate, centred in the frame.
                Circle()
                    .strokeBorder(ink.opacity(0.24), lineWidth: 1.4)
                    .frame(width: d * 0.60, height: d * 0.60)
                Ellipse()
                    .fill(ink.opacity(0.20))
                    .frame(width: d * 0.28, height: d * 0.20)
                    .offset(x: -d * 0.05, y: -d * 0.02)
                Ellipse()
                    .fill(ink.opacity(0.11))
                    .frame(width: d * 0.19, height: d * 0.14)
                    .offset(x: d * 0.10, y: d * 0.09)

                // The window it is seen through.
                ForEach(0..<4, id: \.self) { i in
                    CornerBracket()
                        .stroke(ink.opacity(0.42),
                                style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: corner, height: corner)
                        .rotationEffect(.degrees(Double(i) * 90))
                        .offset(
                            x: (i == 0 || i == 3 ? -1 : 1) * (d / 2 - corner / 2),
                            y: (i == 0 || i == 1 ? -1 : 1) * (d / 2 - corner / 2)
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// One corner of the capture window, drawn top-left; rotated for the
/// other three.
private struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = rect.width * 0.34
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

/// The waist and the band that measures it — the instrument in
/// miniature. Drawn as an OUTLINE, never a filled silhouette: the old
/// solid figure was a heavy dark blob on a body-neutral product, and it
/// described a body where it should describe a measurement.
///
/// The whole figure is drawn (the first cut clipped a magnified one and
/// sliced the shoulders off) and the band spans the FIGURE's width, not
/// the card's (the first cut ran a rule across the entire door).
private struct BodyDoorArt: View {
    /// BodyFigure's waist sits at 0.314…0.570 of its height; the band
    /// rides the middle of that span.
    private let waistCenter: CGFloat = 0.442

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height * 1.0
            let w = h * 0.52
            ZStack(alignment: .top) {
                DoorFigure()
                    .stroke(Palette.cocoaPrimary.opacity(0.38),
                            style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
                    .frame(width: w, height: h)

                ZStack {
                    Capsule()
                        .fill(Palette.cocoaPrimary.opacity(0.09))
                        .frame(height: 13)
                    Rectangle()
                        .fill(Palette.cocoaPrimary.opacity(0.55))
                        .frame(height: 1.2)
                }
                .frame(width: w * 0.66)
                .offset(y: h * waistCenter - 6.5)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .accessibilityHidden(true)
    }
}

/// BodyFigure's outline as a Shape, for the door's miniature.
private struct DoorFigure: Shape {
    func path(in rect: CGRect) -> Path { BodyFigure.path(in: rect) }
}
