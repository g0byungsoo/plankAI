import SwiftUI

// MARK: - ScanChooser (v11.5 N — the two doors)
//
// The founder pointed at Lovi's "Make a New Scan": the page she was
// on blurs away, two large soft cards rise, a round close sits under
// them. That grammar, in paper and ink.
//
// Presented IN-TREE from MainShell (never a sheet) so the material
// blurs the LIVE screen behind it and the arrival can be ours.

struct ScanChooser: View {
    let onBody: () -> Void
    let onPlate: () -> Void
    /// v25 E4 — the plate's memory: the one-tap relog rail. nil =
    /// nothing on record yet (the row never advertises an empty
    /// sheet).
    var onAgain: (() -> Void)? = nil
    let onClose: () -> Void

    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // The page she came from, gone soft. A whisper of paper
            // over the blur keeps the world warm rather than grey.
            Rectangle()
                .fill(.ultraThinMaterial)
                // A breath of INK over the blur, not paper: on a cream
                // app, paper-over-blur washed the page white and the
                // cards stopped separating (frame-caught).
                .overlay(Palette.textPrimary.opacity(0.12))
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Text("what are we looking at?")
                    .font(.custom("JeniHeroSerif-Regular", size: 27, relativeTo: .title2))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Space.gutter)
                    .jeniArrive(arrived, index: 0)

                HStack(spacing: 14) {
                    door(
                        title: "your body",
                        detail: "the waist, week to week",
                        index: 1,
                        art: { BodyDoorArt() },
                        action: onBody
                    )
                    door(
                        title: "a meal",
                        detail: "counted from one photo",
                        index: 2,
                        art: { PlateDoorArt() },
                        action: onPlate
                    )
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.sectionGap)

                // v25 E4 — the quiet third door: most meals repeat,
                // and the fastest honest log is her own corrected
                // plate again. Text row, not a card — the same
                // alternate-door grammar as the camera's "or write it".
                if let onAgain {
                    Button(action: onAgain) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .medium))
                                .accessibilityHidden(true)
                            Text("or log a recent plate again")
                                .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                        }
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Palette.bgElevated)
                                .shadow(color: Palette.textPrimary.opacity(0.05),
                                        radius: 10, y: 4)
                        )
                    }
                    .buttonStyle(JeniPressable())
                    .padding(.top, Space.md)
                    .jeniArrive(arrived, index: 3)
                    .accessibilityLabel("log a recent plate again")
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(Palette.bgElevated)
                                .shadow(color: Palette.textPrimary.opacity(0.06),
                                        radius: 14, y: 6)
                        )
                }
                .buttonStyle(JeniPressable())
                .padding(.top, Space.sectionGap)
                .jeniArrive(arrived, index: 3)
                .accessibilityLabel("close")

                Spacer(minLength: 0)
            }
        }
        .transition(.opacity)
        .task {
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 40_000_000)
            arrived = true
        }
        .accessibilityAddTraits(.isModal)
    }

    private func door<Art: View>(
        title: String,
        detail: String,
        index: Int,
        @ViewBuilder art: @escaping () -> Art,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            JeniSurface(radius: 26, padding: Space.md) {
                VStack(alignment: .leading, spacing: 0) {
                    art()
                        .frame(maxWidth: .infinity)
                        .frame(height: 104)
                        .padding(.bottom, Space.md)
                    Text(title)
                        .font(.custom("JeniHeroSerif-Regular", size: 20, relativeTo: .title3))
                        .foregroundStyle(Palette.textPrimary)
                    Text(detail)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JeniPressable())
        .jeniArrive(arrived, index: index)
        .accessibilityLabel("\(title). \(detail)")
    }
}

// MARK: - The doors' art
//
// Drawn, never photographed: the same ink vocabulary as the
// instrument, so the chooser belongs to the scan it opens.

/// A waist band inside its aperture — the instrument, in miniature.
private struct BodyDoorArt: View {
    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.80, geo.size.height * 1.15)
            let h = w * 0.70
            let aperture = RoundedRectangle(cornerRadius: 12, style: .continuous)
            ZStack {
                aperture
                    .fill(Palette.cocoaPrimary.opacity(0.05))
                // The drawn body, clipped to the window: exactly what
                // the instrument keeps.
                // The WAIST in the window, not the shoulders: the
                // band sits at 0.314…0.570 of BodyFigure's height, so
                // the drawing rides up to put it dead centre.
                DoorFigure()
                    .fill(Palette.cocoaPrimary.opacity(0.8))
                    .frame(width: h * 1.45, height: h * 2.45)
                    .offset(y: h * 0.27)
                    .frame(width: w, height: h)
                    .clipShape(aperture)
            }
            .frame(width: w, height: h)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}

/// BodyFigure's outline as a Shape, for the door's miniature.
private struct DoorFigure: Shape {
    func path(in rect: CGRect) -> Path { BodyFigure.path(in: rect) }
}

/// A plate with three quiet marks — the food rail's own shorthand.
private struct PlateDoorArt: View {
    var body: some View {
        GeometryReader { geo in
            // The SAME field as the body door, so the two read as
            // siblings rather than as two unrelated drawings.
            let w = min(geo.size.width * 0.80, geo.size.height * 1.15)
            let h = w * 0.70
            let d = h * 0.78
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.cocoaPrimary.opacity(0.05))
                Circle()
                    .strokeBorder(Palette.cocoaPrimary.opacity(0.30), lineWidth: 1.6)
                    .frame(width: d, height: d)
                HStack(spacing: d * 0.11) {
                    Capsule()
                        .fill(Palette.cocoaPrimary.opacity(0.55))
                        .frame(width: d * 0.11, height: d * 0.30)
                    Capsule()
                        .fill(Palette.cocoaPrimary.opacity(0.78))
                        .frame(width: d * 0.11, height: d * 0.46)
                    Capsule()
                        .fill(Palette.cocoaPrimary.opacity(0.45))
                        .frame(width: d * 0.11, height: d * 0.22)
                }
            }
            .frame(width: w, height: h)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}
