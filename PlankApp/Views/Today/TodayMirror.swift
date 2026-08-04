import SwiftUI
import UIKit

// MARK: - TodayMirror (v10.1 — the front page's hero)
//
// The day's edition opens on HER. The ink figure stands directly
// ON the page — its ground is the same paper as the page, so it
// needs no card, no frame, no chrome (the editorial move: not a
// photo in a box, a figure on the paper). The change line sets
// beneath it as the headline. Photograph-mode records keep the
// BodyMat (arbitrary pixels never bleed raw onto the page).
//
// Zero scans: the drawn outline stands in the figure's place and
// the headline becomes the invitation. No numbers, ever (L3).

struct TodayMirror: View {
    let face: UIImage?
    /// True when the face is the ink silhouette (frameless on-page);
    /// false = her photograph (matted).
    let faceIsSilhouette: Bool
    let line: String
    let italic: [String]
    let caption: String
    let onOpen: () -> Void

    private var hasScan: Bool { face != nil }

    var body: some View {
        Button {
            Haptics.soft()
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                figure
                    .frame(maxWidth: .infinity)

                ItalicAccentText(
                    line,
                    italic: italic,
                    baseFont: Typo.questionHero,
                    italicFont: Typo.questionHeroItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(Typo.questionHeroLineGap)
                .kerning(-0.4)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.md)

                HStack(spacing: 4) {
                    Text(caption)
                        .font(.custom("DMSans-Medium", size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.cocoaTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.cocoaTertiary.opacity(0.8))
                }
                .padding(.top, 8)
            }
        }
        .buttonStyle(JKPress())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            hasScan
                ? "your latest scan. \(line)"
                : "no scans yet. \(line)"
        )
        .accessibilityHint(hasScan ? "opens your record" : "starts your first check-in")
    }

    @ViewBuilder
    private var figure: some View {
        if let face {
            if faceIsSilhouette {
                // On the page, not in a box.
                Image(uiImage: face)
                    .resizable()
                    .scaledToFit()
                    .frame(height: figureHeight)
            } else {
                BodyMat(image: face)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .frame(height: figureHeight)
            }
        } else {
            BodyFigure.path(
                in: CGRect(
                    x: 0, y: 0,
                    width: figureHeight * 0.62, height: figureHeight
                )
            )
            .stroke(
                Palette.cocoaPrimary.opacity(0.22),
                style: StrokeStyle(lineWidth: 1.4, dash: [4, 6])
            )
            .frame(width: figureHeight * 0.62, height: figureHeight)
        }
    }

    private var figureHeight: CGFloat {
        // Sized so the lead sits fully above the fold with the next
        // row peeking — the page invites the scroll it now has.
        min(296, UIScreen.main.bounds.height * 0.36)
    }
}
