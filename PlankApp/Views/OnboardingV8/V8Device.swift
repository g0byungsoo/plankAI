import SwiftUI

// MARK: - V8DeviceDemo — the product, lit, on the arrival's ink
//
// Founder steer (2026-08-07): the old welcome carried a device demo,
// and it taught what the app IS before asking for a single answer.
// It comes back — in this era's language, not the one it was born in.
//
// What changed, and why:
//
//   · NO CHASSIS. v20's card law: separation is FILL, never a drawn
//     edge. Paper on ink separates by itself, so the phone is simply
//     its screen. The black plastic body with buttons, a notch and a
//     glare was the stock-mockup tell (§15's hunt list) — and drawing
//     a phone inside a phone is the oldest one there is.
//   · NO STICKERS. The cherries, the hearts and the drop shadows on
//     white cards belong to the era the rebirth deleted.
//   · THE FACES ARE THIS APP. Home's nutrition band as v17-v20 built
//     it, the plate ledger, the record. The old demo still showed a
//     day-1 checklist with photo thumbnails — a demo of a dead layout
//     is a lie about the product (L2: honesty).
//
// Every size derives from ONE scale factor so the miniature holds at
// any device height, and the subtree is pinned to `.large`: this is a
// PICTURE of a screen, so its type must not resize with the reader's.
// The words around it do that (v19.1 — a fixed frame around scaling
// type is always a bug; the fix here is that the frame's contents
// aren't type, they're an image).

struct V8DeviceDemo: View {
    /// The screen's height in points. Width and every interior size
    /// follow from it.
    let height: CGFloat

    @State private var face = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// iPhone proportion, screen only (no chassis to add).
    private var width: CGFloat { (height * 0.474).rounded() }
    /// A device radius, not a toy radius (a real 6.1" is ~6.5% of its
    /// height; ours rounds a touch softer because it is small).
    private var radius: CGFloat { height * 0.076 }
    /// 168pt of width is the drawing's baseline.
    private var s: CGFloat { width / 168 }

    var body: some View {
        ZStack {
            // A lit screen throws light into the room. This is the
            // same warm bloom the chapter already drifts (V8Blooms),
            // borrowed as contact light — not an outline.
            RadialGradient(
                colors: [
                    Palette.textInverse.opacity(0.11),
                    Palette.textInverse.opacity(0),
                ],
                center: .center,
                startRadius: width * 0.32,
                endRadius: width * 1.15
            )
            .frame(width: width * 2.3, height: height * 1.3)
            .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Palette.bgPrimary)
                .frame(width: width, height: height)
                .overlay(alignment: .top) {
                    Group {
                        switch face {
                        case 1: V8DemoPlate(s: s)
                        case 2: V8DemoDay(s: s)
                        default: V8DemoWindow(s: s)
                        }
                    }
                    .frame(width: width, height: height)
                    .id(face)
                    .transition(.opacity)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                // The object still blocks light behind it.
                .shadow(color: .black.opacity(0.34), radius: 22 * s, y: 13 * s)
        }
        .frame(width: width, height: height)
        .dynamicTypeSize(.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "a preview of jeni: what's left to eat today, a plate "
            + "counted from one photo, and the plan for your day"
        )
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_400_000_000)
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.55)) {
                    face = (face + 1) % 3
                }
            }
        }
    }
}

// MARK: - Drawing kit for the miniature

private enum V8Demo {
    static func sans(_ size: CGFloat, _ cut: String = "Regular") -> Font {
        .custom("DMSans-\(cut)", size: size)
    }
    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "JeniHeroSerif-Italic" : "JeniHeroSerif-Regular", size: size)
    }

    /// JeniRing at miniature scale (hairline track, ink arc).
    static func ring(_ fraction: Double, size: CGFloat, line: CGFloat) -> some View {
        ZStack {
            // A touch heavier than the shipping track (0.12): at this
            // size the remainder has to survive the scale.
            Circle().strokeBorder(Palette.textPrimary.opacity(0.14), lineWidth: line)
            Circle()
                .inset(by: line / 2)
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(Palette.textPrimary,
                        style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }

    /// JeniCheck at miniature scale.
    static func check(_ done: Bool, s: CGFloat) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    done ? Palette.textPrimary : Palette.textPrimary.opacity(0.28),
                    lineWidth: 1.2 * s
                )
            if done {
                Circle().fill(Palette.textPrimary)
                Image(systemName: "checkmark")
                    .font(.system(size: 7 * s, weight: .bold))
                    .foregroundStyle(Palette.bgPrimary)
            }
        }
        .frame(width: 15 * s, height: 15 * s)
    }

}

// MARK: - The faces
//
// Founder steer, mid-build (2026-08-07): the old welcome's demos read
// better because they were ABSTRACT — one idea per screen, drawn big —
// and because the app's design keeps moving, so a pixel-faithful
// miniature is stale the week after it ships.
//
// So each face is a CONCEPT, not a screenshot: the day's window · a
// photo becoming a plate · the plan for today. They survive a redesign
// because they say what the product DOES, not what it currently looks
// like. Same three-beat structure the founder's set had (a big figure,
// a supporting shape, one caption), in this era's language: paper and
// ink, no accent, no stickers, no chassis.

// MARK: Face 1 — the day's window

private struct V8DemoWindow: View {
    let s: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ZStack {
                V8Demo.ring(0.747, size: 124 * s, line: 8 * s)
                VStack(spacing: 1 * s) {
                    Text("1,100")
                        .font(V8Demo.serif(30 * s))
                        .foregroundStyle(Palette.textPrimary)
                    Text("of 1,473 kcal")
                        .font(V8Demo.sans(8.5 * s))
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            weekBars.padding(.top, 24 * s)

            Text("what's left today")
                .font(V8Demo.serif(12 * s, italic: true))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .padding(.top, 20 * s)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 14 * s)
    }

    /// The week behind the day — real shape, no invented target, and
    /// today reads full ink (v12's bar grammar).
    private var weekBars: some View {
        let heights: [CGFloat] = [0.62, 0.85, 0.54, 0.93, 0.71, 0.44, 0.75]
        let letters = ["m", "t", "w", "t", "f", "s", "s"]
        return VStack(spacing: 5 * s) {
            HStack(alignment: .bottom, spacing: 8 * s) {
                ForEach(0..<7, id: \.self) { i in
                    Capsule()
                        .fill(Palette.textPrimary.opacity(i == 6 ? 0.92 : 0.20))
                        .frame(width: 10 * s, height: 14 * s + 42 * s * heights[i])
                }
            }
            HStack(spacing: 8 * s) {
                ForEach(0..<7, id: \.self) { i in
                    Text(letters[i])
                        .font(V8Demo.sans(6.5 * s, i == 6 ? "Medium" : "Regular"))
                        .foregroundStyle(
                            i == 6 ? Palette.textPrimary : Palette.cocoaTertiary
                        )
                        .frame(width: 9 * s)
                }
            }
        }
        // The founder's reference seats the week on its own card, and
        // it is the one piece of material on this face — depth is a
        // fill plus one contact shadow, never an edge (v20).
        .padding(.horizontal, 12 * s)
        .padding(.vertical, 10 * s)
        .background(
            RoundedRectangle(cornerRadius: Radius.md * s, style: .continuous)
                .fill(Palette.bgElevated)
                .shadow(color: Palette.textPrimary.opacity(0.04),
                        radius: 6 * s, y: 2 * s)
        )
    }
}

// MARK: Face 2 — a photo becomes a plate

private struct V8DemoPlate: View {
    let s: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // The founder's own plate — the same bowl the mid-flow
            // demo reads, at the same honest numbers, so screen one
            // and the demo never disagree.
            Image("onb-v5-demo-poke")
                .resizable()
                .scaledToFill()
                .frame(width: 142 * s, height: 142 * s)
                .clipShape(RoundedRectangle(cornerRadius: 20 * s, style: .continuous))

            Text("ahi poke bowl")
                .font(V8Demo.serif(17 * s))
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 14 * s)

            HStack(spacing: 5 * s) {
                V8Demo.check(true, s: s)
                Text("fits today")
                    .font(V8Demo.sans(10 * s, "SemiBold"))
                    .foregroundStyle(Palette.textPrimary)
                Text("· 500 kcal")
                    .font(V8Demo.sans(10 * s))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 10 * s)
            .padding(.vertical, 6 * s)
            .background(
                Capsule()
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.textPrimary.opacity(0.05),
                            radius: 5 * s, y: 1.5 * s)
            )
            .padding(.top, 10 * s)

            Text("counted before you eat")
                .font(V8Demo.serif(12 * s, italic: true))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .padding(.top, 14 * s)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12 * s)
    }
}

// MARK: Face 3 — the plan for today

private struct V8DemoDay: View {
    let s: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline) {
                Text("TODAY")
                    .font(V8Demo.sans(8.5 * s, "Medium"))
                    .kerning(1.1 * s)
                    .foregroundStyle(Palette.textPrimary.opacity(0.75))
                Spacer(minLength: 0)
                Text("1 of 4")
                    .font(V8Demo.sans(7 * s))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .padding(.bottom, 8 * s)

            VStack(spacing: 8 * s) {
                row("add a meal", "before you eat",
                    glyph: "fork.knife", done: false, lead: true)
                row("move", "10 min · gentle",
                    glyph: "figure.walk", done: true, lead: false)
                row("the method", "a 2-minute read",
                    glyph: "book", done: false, lead: false)
                row("weigh in", "takes 30 seconds",
                    glyph: "scalemass", done: false, lead: false)
            }

            Text("built around your real day")
                .font(V8Demo.serif(12 * s, italic: true))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 20 * s)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 13 * s)
    }

    /// The shipping checklist row's grammar: DM Sans (size carries the
    /// hierarchy, never family), a white row on the warm paper, the
    /// beat's glyph trailing, and a done row that DIMS rather than
    /// strikes itself out (no shame states, L10).
    private func row(_ title: String, _ note: String,
                     glyph: String, done: Bool, lead: Bool) -> some View {
        HStack(spacing: 8 * s) {
            V8Demo.check(done, s: s)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(V8Demo.sans(12.5 * s, lead ? "SemiBold" : "Medium"))
                    .foregroundStyle(done ? Palette.cocoaTertiary : Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(note)
                    .font(V8Demo.sans(8.5 * s))
                    .foregroundStyle(
                        done ? Palette.cocoaTertiary.opacity(0.7) : Palette.textSecondary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4 * s)
            Image(systemName: glyph)
                .font(.system(size: 10 * s))
                .foregroundStyle(Palette.cocoaTertiary.opacity(done ? 0.35 : 0.75))
        }
        .padding(.vertical, 12 * s)
        .padding(.horizontal, 11 * s)
        .background(
            RoundedRectangle(cornerRadius: 12 * s, style: .continuous)
                .fill(Palette.bgElevated)
                .shadow(color: Palette.textPrimary.opacity(done ? 0 : 0.04),
                        radius: 5 * s, y: 1.4 * s)
        )
        .opacity(done ? 0.75 : 1)
    }
}
