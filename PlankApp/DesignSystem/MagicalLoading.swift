import SwiftUI

// MARK: - TypewriterText
//
// Letter-by-letter reveal. Restarts when the `text` parameter changes
// (used for the "shuffling your plan, [name]…" loading copy on home).
// `charInterval` controls speed; 0.04s ≈ 25 chars/sec, which is the
// sweet spot between "feels handwritten" and "user is waiting too long".
//
// Per the design research: letter-by-letter italic-Fraunces reveal reads
// as handwritten / personalized; spinners + skeleton bars read as 2021
// SaaS. Pair with a sticker stamp burst for the magical loading moment.

struct TypewriterText: View {
    let text: String
    var charInterval: Double = 0.04

    @State private var visibleCount: Int = 0

    var body: some View {
        // ZStack: invisible full text reserves layout space (so a multi-
        // line affirmation doesn't grow the parent as more lines reveal),
        // visible prefix on top fills it in letter-by-letter.
        ZStack(alignment: .top) {
            Text(text)
                .opacity(0)
                .accessibilityHidden(true)
            Text(String(text.prefix(visibleCount)))
        }
        .task(id: text) {
            visibleCount = 0
            for _ in text {
                try? await Task.sleep(for: .seconds(charInterval))
                if Task.isCancelled { return }
                visibleCount += 1
            }
        }
    }
}

// MARK: - StickerStampView
//
// Single sticker that spring-stamps into place at a fractional anchor
// inside its parent. Sequence multiple instances with different delays
// to produce the sticker-burst loading effect (Cal AI / Finch idiom).
//
// Anchor is normalized 0…1 over the parent's bounds, so a sticker at
// (0.18, 0.22) sits 18% from the left and 22% from the top — works at
// any size without hardcoded coords.

struct StickerStampView: View {
    let sticker: StickerName
    let anchor: UnitPoint
    let size: CGFloat
    var rotation: Double = 0
    var delay: Double = 0

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        GeometryReader { geo in
            Image(sticker.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .opacity(sticker.style.opacity * opacity)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
                .position(
                    x: geo.size.width * anchor.x,
                    y: geo.size.height * anchor.y
                )
                .task {
                    try? await Task.sleep(for: .seconds(delay))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                }
        }
        .allowsHitTesting(false)
    }
}
