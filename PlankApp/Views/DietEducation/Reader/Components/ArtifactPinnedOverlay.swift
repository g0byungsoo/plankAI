import SwiftUI

// MARK: - ArtifactPinnedOverlay
//
// Round-4 replacement for `singleArtifact` + `photoEdgeBleed`. One
// brand-library asset pinned to one corner of the page canvas with a
// -16pt edge bleed. ABSOLUTE OVERLAY — costs zero vertical space in
// the typography column. Disables hit testing so taps fall through
// to whatever's beneath (body text, save-line gesture, etc).
//
// Use as a `.background` or `.overlay` on the reader's page-body
// container, NOT inside the column. Renders at ~32% canvas width.

struct ArtifactPinnedOverlay: View {
    let slug: ArtifactSlug
    let pin: CornerPin
    @State private var bloomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width * 0.32
            Image(slug.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .opacity(bloomed || reduceMotion ? 1 : 0)
                .scaleEffect(bloomed || reduceMotion ? 1 : 0.92,
                             anchor: .center)
                .offset(offset(for: pin, in: geo.size, assetSize: size))
                .onAppear {
                    if reduceMotion {
                        bloomed = true
                    } else {
                        withAnimation(.easeOut(duration: 0.42).delay(0.36)) {
                            bloomed = true
                        }
                    }
                }
                .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }

    private func offset(for pin: CornerPin,
                        in canvas: CGSize,
                        assetSize: CGFloat) -> CGSize {
        switch pin {
        case .topRightPin:
            return CGSize(width: canvas.width - assetSize + 16, height: -16)
        case .bottomLeftBleed:
            return CGSize(width: -16, height: canvas.height - assetSize + 16)
        }
    }
}

// MARK: - TwinAccentCornersOverlay
//
// Two accent-* stickers in opposite diagonal corners, framing the
// typography column. Used sparingly (≤8 pages across all 84 lessons)
// for the most ornamental moments — prompt pages on milestone days,
// graduation. Also an absolute overlay; costs no vertical space.

struct TwinAccentCornersOverlay: View {
    let leading: AccentSlug
    let trailing: AccentSlug
    let diagonal: Diagonal
    @State private var bloomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = 78
            ZStack {
                Image(leading.rawValue)
                    .resizable().scaledToFit()
                    .frame(width: size, height: size)
                    .offset(leadingOffset(in: geo.size, assetSize: size))
                Image(trailing.rawValue)
                    .resizable().scaledToFit()
                    .frame(width: size, height: size)
                    .offset(trailingOffset(in: geo.size, assetSize: size))
            }
            .opacity(bloomed || reduceMotion ? 1 : 0)
            .scaleEffect(bloomed || reduceMotion ? 1 : 0.94)
            .onAppear {
                if reduceMotion {
                    bloomed = true
                } else {
                    withAnimation(.easeOut(duration: 0.46).delay(0.40)) {
                        bloomed = true
                    }
                }
            }
            .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }

    private func leadingOffset(in canvas: CGSize, assetSize: CGFloat) -> CGSize {
        switch diagonal {
        case .topLeftToBottomRight, .topRightToBottomLeft:
            // Leading sits top-left for L→R; bottom-left for R→L
            if diagonal == .topLeftToBottomRight {
                return CGSize(width: -8, height: -12)
            } else {
                return CGSize(width: -8, height: canvas.height - assetSize + 12)
            }
        }
    }

    private func trailingOffset(in canvas: CGSize, assetSize: CGFloat) -> CGSize {
        switch diagonal {
        case .topLeftToBottomRight:
            return CGSize(width: canvas.width - assetSize + 8,
                          height: canvas.height - assetSize + 12)
        case .topRightToBottomLeft:
            return CGSize(width: canvas.width - assetSize + 8, height: -12)
        }
    }
}
