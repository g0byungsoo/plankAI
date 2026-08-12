import SwiftUI
import UIKit

// MARK: - ScanChooser (v25 E7 — SAY IT)
//
// The centre tab is the only universal affordance the app owns, and
// until this era it spent that position on a camera. Its question was
// "what are we looking at?" — a lens question — and it offered two
// photographic doors. The cheap door (type a sentence, get a reading)
// already existed and worked, reachable only from a small "snap
// instead" link INSIDE the camera screen. So the product's fastest
// path to a record was buried under its slowest one, and 3.4% of
// people ever started (14_E4_DECISION §1).
//
// Now the question is "what did you eat?" and the answer is a field.
// The lens, the relog and the body scan sit under it as quiet peers.
//
// What that buys, measured in gestures: tab → type → return. The words
// go straight to the estimate; nothing asks her to confirm the same
// sentence twice.
//
// GEOMETRY. E5's two big doors STAY, at full size, with their art at
// full scale — the founder compared this era's first cut (a field over
// three small pills) against them and kept E5's, correctly: shrunk to
// 38pt marks the art stopped carrying information and the composition
// went flat. So the field is added ABOVE the doors rather than in
// place of them. The doors are still made of her record — the meal
// door wears her own last plate's photograph, the again door names the
// dish by name.
//
// The body door stays DRAWN (L4: body privacy — her scans are not
// chooser art).

struct ScanChooser: View {
    let onBody: () -> Void
    let onPlate: () -> Void
    /// v25 E7 — the words path. The field's own submit.
    var onWords: ((String) -> Void)? = nil
    /// v25 E4 — the plate's memory: the one-tap relog rail. nil =
    /// nothing on record yet (the row never advertises an empty
    /// sheet).
    var onAgain: (() -> Void)? = nil
    /// v25 E5 — her last plate, if she has one. The lens pill wears the
    /// photograph; the again pill wears the name.
    var lastPlateTitle: String? = nil
    var lastPlatePhoto: UIImage? = nil
    let onClose: () -> Void

    /// v25 E7 — today's protein, so the question is asked in context.
    /// The host composes it (this view owns no stores); nil = nothing
    /// true to say yet, and nothing renders.
    var standingLine: PlateAnswerEngine.Answer? = nil

    @State private var arrived = false
    @State private var text = ""
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let doorRadius: CGFloat = 24

    /// Splits the standing sentence around its punch so the punch can
    /// carry the italic serif inside otherwise flat prose (the same
    /// grammar the reading's day line uses). The engine guarantees the
    /// punch is a substring, pinned by a test.
    private var standing: (prefix: String, punch: String, suffix: String, text: String)? {
        guard let s = standingLine,
              let r = s.text.range(of: s.punch)
        else {
            guard let s = standingLine else { return nil }
            return ("", s.text, "", s.text)
        }
        return (String(s.text[s.text.startIndex..<r.lowerBound]),
                s.punch,
                String(s.text[r.upperBound...]),
                s.text)
    }

    var body: some View {
        ZStack {
            scrim

            VStack(alignment: .leading, spacing: 0) {
                Text("what did you eat?")
                    .font(.custom("JeniHeroSerif-Regular", size: 27, relativeTo: .title2))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .jeniArrive(arrived, index: 0)

                // The question is asked in context, not into a void:
                // where today's protein already stands, from the SAME
                // engine that answers when the plate lands. Absent when
                // there is nothing true to say — an empty day is not
                // "0 g" (PlateAnswerEngine.standing).
                if let standing {
                    (Text(standing.prefix)
                        .font(.custom("DMSans-Regular", size: 14, relativeTo: .subheadline))
                     + Text(standing.punch)
                        .font(.custom("JeniHeroSerif-Italic", size: 15, relativeTo: .subheadline))
                     + Text(standing.suffix)
                        .font(.custom("DMSans-Regular", size: 14, relativeTo: .subheadline)))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
                        .jeniArrive(arrived, index: 0)
                        .accessibilityLabel(standing.text)
                }

                field
                    .padding(.top, Space.md)
                    .jeniArrive(arrived, index: 1)

                doors
                    .padding(.top, 12)

                // Tight to the group it closes, not adrift below it.
                // While she is typing it steps back with the again
                // door: the keyboard costs ~330pt, tapping outside
                // already dismisses, and the two big doors are the
                // alternatives worth keeping in view.
                if !fieldFocused {
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
                .padding(.top, Space.md)
                .jeniArrive(arrived, index: 5)
                .accessibilityLabel("close")
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.lg)
            .padding(.top, Space.md)
            .frame(maxWidth: .infinity, alignment: .bottom)
            // The group is bottom-anchored, so when the keyboard lifts
            // it — or when accessibility type grows it — it overflowed
            // UPWARD, straight under the status bar. A bottom-anchored
            // scroll view keeps the composition identical while it
            // fits and scrolls the moment it does not. Applied to the
            // GROUP only: wrapping the whole ZStack inset the scrim
            // too and put a band of un-softened page above it
            // (frame-caught).
            .modifier(BottomAnchoredScroll())
        }
        .transition(.opacity)
        .animation(JeniMotion.settle, value: fieldFocused)
        .task {
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 40_000_000)
            arrived = true
        }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - The field
    //
    // NOT auto-focused. The keyboard arriving unasked over a page she
    // just softened would take the doors with it and make the lens
    // feel like a mistake. She taps once to type; the doors stay put
    // and ride up together when she does.

    private var field: some View {
        HStack(spacing: 10) {
            TextField("", text: $text, prompt: promptText, axis: .vertical)
                .focused($fieldFocused)
                .font(.custom("DMSans-Regular", size: 17, relativeTo: .body))
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.roseBerry)
                .lineLimit(1...3)
                .submitLabel(.go)
                .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        trimmed.isEmpty ? Palette.cocoaSecondary : Palette.bgPrimary
                    )
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(
                            trimmed.isEmpty
                            ? Palette.textPrimary.opacity(0.08)
                            : Palette.textPrimary
                        )
                    )
            }
            .buttonStyle(JeniPressable())
            .disabled(trimmed.isEmpty)
            .animation(JeniMotion.settle, value: trimmed.isEmpty)
            .accessibilityLabel("count it")
        }
        .padding(.leading, Space.md)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Palette.bgElevated)
                .shadow(color: Palette.textPrimary.opacity(0.07), radius: 18, y: 8)
        )
        .contentShape(Rectangle())
        .onTapGesture { fieldFocused = true }
    }

    private var promptText: Text {
        Text("greek yogurt and berries")
            .font(.custom("DMSans-Regular", size: 17))
            .foregroundColor(Palette.textSecondary.opacity(0.55))
    }

    private func submit() {
        guard !trimmed.isEmpty, let onWords else { return }
        JeniHaptic.tick()
        fieldFocused = false
        onWords(trimmed)
    }

    // MARK: - The doors (E5's, unchanged)

    private var doors: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                door(
                    title: "a meal",
                    detail: "counted from one photo",
                    index: 2,
                    art: { PlateDoorArt(photo: lastPlatePhoto) },
                    action: onPlate
                )
                door(
                    title: "your body",
                    detail: "the waist, week to week",
                    index: 3,
                    art: { BodyDoorArt() },
                    action: onBody
                )
            }

            // The third door, in the SAME material as the other two —
            // a floating pill was a fourth geometry. It reads as a door
            // because it is one.
            if let onAgain, !fieldFocused {
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
                .jeniArrive(arrived, index: 4)
                .accessibilityLabel(againAccessibilityLabel)
            }
        }
    }

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

    // MARK: - The scrim
    //
    // The page she came from goes SOFT, not away. The first cut stacked
    // ultraThinMaterial + 12% ink over a cream app and left grey noise
    // with no figure/ground. A thicker blur plus an ink veil dims the
    // page while keeping its shapes legible, so the group reads as
    // rising off her own screen.

    private var scrim: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            // INK over the blur, never paper: a paper wash on a cream
            // app turns the page white and the doors stop separating
            // (caught twice — once in v11.5, once in E5's first cut,
            // which added a 42% paper layer and erased the page).
            LinearGradient(
                colors: [Palette.textPrimary.opacity(0.06),
                         Palette.textPrimary.opacity(0.20)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            if fieldFocused { fieldFocused = false } else { onClose() }
        }
        .accessibilityLabel("close")
        .accessibilityAddTraits(.isButton)
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
    }
}

/// BodyFigure's outline as a Shape, for the door's miniature.
private struct DoorFigure: Shape {
    func path(in rect: CGRect) -> Path { BodyFigure.path(in: rect) }
}

// MARK: - BottomAnchoredScroll (v25 E7)
//
// Keeps a bottom-anchored group exactly where it is while it fits, and
// scrolls it the moment it does not — the keyboard rising, or an
// accessibility type size growing the serif question to three lines.
// Without this the group overflowed upward off the top of the screen
// (frame-caught: the question sat behind the status bar clock).
private struct BottomAnchoredScroll: ViewModifier {
    /// The status bar plus a hair of air. Read from the window rather
    /// than hard-coded so it is right on every device and on the ones
    /// with no notch.
    private var topInset: CGFloat {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let inset = scene?.keyWindow?.safeAreaInsets.top ?? 20
        return inset + 10
    }

    func body(content: Content) -> some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                content
                    .frame(minHeight: geo.size.height - topInset, alignment: .bottom)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.bottom)
            // The chooser mounts in MainShell's ZStack next to a
            // safe-area-ignoring scrim, so this view's own top edge
            // reaches the status bar and the overflow drew straight
            // through the clock. Insetting the FRAME (not the content
            // margin — that only moved it 25pt) is what actually keeps
            // the serif question clear, at every keyboard height and
            // every type size. Frame-caught three times.
            .frame(height: max(0, geo.size.height - topInset))
            .padding(.top, topInset)
        }
    }
}
