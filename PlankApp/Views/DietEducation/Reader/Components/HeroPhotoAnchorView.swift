import SwiftUI

// MARK: - HeroPhotoAnchorView
//
// Round-4 replacement for the round-3 HeroPhotoBleedView. Single
// photo at a fixed 260pt height (per PageDimensions.visualHeight),
// edge-bled in the chosen direction with a 60pt cream gradient at
// the bottom so the headline column reads against the photo's lower
// edge. Costs 260pt of vertical column (NOT full-bleed) — the
// reader's standard headline + body still render BELOW this view.
//
// Distinction from the round-3 hero (which suppressed the standard
// headline column and rendered its own headline inside the photo's
// pocket): round-4 hero is an ANCHOR not a full-bleed canvas. The
// page still has standard headline + body + dingbat below the
// anchor; this matches the magazine designer's "anchored single
// photo" register where the photo is a figure inside the page, not
// the page itself.

struct HeroPhotoAnchorView: View {
    let slug: HeroPhotoSlug
    let bleed: BleedDirection
    @State private var bloomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            Image(slug.rawValue)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width + 32, height: geo.size.height)
                .offset(x: xOffset, y: 0)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [Palette.bgPrimary, Palette.bgPrimary.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 60)
                    .allowsHitTesting(false)
                }
                .shadow(color: Palette.cocoaPrimary.opacity(0.08),
                        radius: 12, x: 0, y: 4)
                .opacity(bloomed || reduceMotion ? 1 : 0)
                .scaleEffect(bloomed || reduceMotion ? 1.0 : 1.04,
                             anchor: .center)
                .onAppear {
                    if reduceMotion {
                        bloomed = true
                    } else {
                        withAnimation(Motion.bloom.delay(0.28)) { bloomed = true }
                    }
                }
        }
        .accessibilityHidden(true)
    }

    private var xOffset: CGFloat {
        switch bleed {
        case .leftBleed:        return -16
        case .rightBleed:       return  16
        case .topBleedCentered: return   0
        }
    }
}
