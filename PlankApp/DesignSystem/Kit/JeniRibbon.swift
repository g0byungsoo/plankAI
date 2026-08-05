import SwiftUI

// MARK: - JeniRibbon (v11.5 — the ribbed measure)
//
// Both reference screens the founder set share one texture: a bar
// built from many fine strokes rather than a solid fill. It reads as
// an INSTRUMENT — a printed scale, a ruler's teeth — instead of a
// progress bar, and it holds detail at small sizes where a solid
// capsule reads as a blob.
//
// This is Jeni's version, and it replaces the line charts on
// Becoming's tile faces: one lightweight Canvas per tile instead of a
// full chart engine, so eleven tiles no longer mean eleven animated
// charts on arrival.

struct JeniRibbon: View {
    /// 0…1. Values beyond 1 clamp — a met window never overflows.
    var progress: Double
    var height: CGFloat = 26
    /// Stroke width and the gap between strokes.
    var stroke: CGFloat = 2.5
    var gap: CGFloat = 3.0
    /// Draws the filled teeth in on arrival, left to right.
    var animated: Bool = true

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Double = 0

    private var shown: Double {
        let p = max(0, min(1, progress))
        return animated && !reduceMotion ? p * phase : p
    }

    var body: some View {
        Canvas { ctx, size in
            let pitch = stroke + gap
            let count = max(1, Int(size.width / pitch))
            let lit = Int((Double(count) * shown).rounded())
            for i in 0..<count {
                let x = CGFloat(i) * pitch
                // The teeth shorten toward the ends, so the ribbon
                // reads as a machined object rather than a rectangle.
                let t = Double(i) / Double(max(1, count - 1))
                let taper = 0.78 + 0.22 * sin(t * .pi)
                let h = size.height * taper
                let rect = CGRect(x: x, y: (size.height - h) / 2,
                                  width: stroke, height: h)
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: stroke / 2),
                    with: .color(i < lit
                                 ? Palette.textPrimary
                                 : Palette.textPrimary.opacity(0.13))
                )
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
        .task(id: arrived) {
            guard animated, !reduceMotion, arrived, phase < 1 else {
                phase = 1
                return
            }
            // 22 steps is enough for teeth: each frame lights a tooth
            // or two, which is exactly the read we want.
            for step in 1...22 {
                phase = Double(step) / 22
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            phase = 1
        }
    }
}

// MARK: - JeniPillBars (v11.5 — the reference's weight trend)
//
// Rounded pill columns with the current one filled and labelled, the
// rest quiet. This is what replaces the hairline comb on detail pages:
// the founder's reference uses full rounded pills, and they read far
// better at a glance than 3pt strokes.

struct JeniPillBars: View {
    /// One value per column; nil = a day with no data (never a zero).
    let values: [Double?]
    /// Short labels under each column ("mon", "tue"…). May be empty.
    var labels: [String] = []
    /// Which column reads as "now". Defaults to the last real value.
    var highlighted: Int? = nil
    var height: CGFloat = 150

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown: Double = 0

    private var maxValue: Double {
        max(values.compactMap { $0 }.max() ?? 1, 0.0001)
    }

    private var focus: Int {
        highlighted ?? (values.lastIndex { $0 != nil } ?? 0)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, value in
                    column(value: value, isFocus: i == focus)
                }
            }
            .frame(height: height)
            if !labels.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                        Text(label)
                            .font(.custom(i == focus ? "DMSans-SemiBold" : "DMSans-Regular",
                                          size: 11, relativeTo: .caption2))
                            .foregroundStyle(i == focus ? Palette.textPrimary
                                                        : Palette.cocoaTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .task(id: arrived) {
            guard !reduceMotion, arrived, grown < 1 else { grown = 1; return }
            for step in 1...26 {
                let t = Double(step) / 26
                grown = 1 - pow(1 - t, 3)
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            grown = 1
        }
    }

    @ViewBuilder
    private func column(value: Double?, isFocus: Bool) -> some View {
        GeometryReader { geo in
            let fraction = value.map { $0 / maxValue } ?? 0
            let full = geo.size.height
            // An empty day keeps a ghost column so the row's rhythm
            // never breaks — but it is visibly EMPTY, never a zero.
            let h = max(10, full * fraction * (reduceMotion ? 1 : grown))
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Palette.textPrimary.opacity(0.07))
                    .frame(height: full)
                if value != nil {
                    Capsule()
                        .fill(isFocus ? Palette.textPrimary
                                      : Palette.textPrimary.opacity(0.22))
                        .frame(height: h)
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
        }
    }
}
