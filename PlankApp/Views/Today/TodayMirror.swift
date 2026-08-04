import SwiftUI
import UIKit

// MARK: - TodayMirror (app v10 §4a — the mirror opens)
//
// Home's opening statement: her latest figure, matted on the house
// paper, beside the change line. The first thing the day answers is
// "am I changing?" — before it asks for anything. Tap opens the
// record (becoming); with no scans yet the slot holds the drawn
// outline and the line becomes the invitation (tap starts the scan).
//
// Mat law (v10): the figure is always matted on its own paper — the
// mat fills with the silhouette's exact ground (#FCFAF7) so a seam
// cannot exist; a hairline and a soft ink shadow give it the print's
// edge. No numbers here, ever (L3) — the line is the trend sentence
// or the record's own floor-gated status.

struct TodayMirror: View {
    let face: UIImage?
    let line: String
    let italic: [String]
    let caption: String
    let onOpen: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var hasScan: Bool { face != nil }

    var body: some View {
        Button {
            Haptics.soft()
            onOpen()
        } label: {
            content
        }
        .buttonStyle(JKPress())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            hasScan
                ? "your latest scan. \(line)"
                : "no scans yet. \(line)"
        )
        .accessibilityHint(hasScan ? "opens your record" : "starts your first scan")
    }

    @ViewBuilder
    private var content: some View {
        // Accessibility sizes stack the spread vertically — the
        // headline needs the full column to wrap.
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Space.md) {
                mat
                readColumn
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 18) {
                mat
                readColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var readColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            ItalicAccentText(
                line,
                italic: italic,
                baseFont: .custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title2),
                italicFont: .custom("JeniHeroSerif-Italic", size: 28, relativeTo: .title2),
                color: Palette.textPrimary,
                alignment: .leading
            )
            .lineSpacing(-2)
            .kerning(-0.4)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Text(caption)
                    .font(.custom("DMSans-Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(Palette.cocoaTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.cocoaTertiary.opacity(0.8))
            }
        }
    }

    private var mat: some View {
        let width = matWidth
        return BodyMat(image: face)
            .overlay {
                if face == nil {
                    // The ghost: the figure she hasn't drawn yet.
                    BodyFigure.path(
                        in: CGRect(
                            x: width * 0.14, y: width * 4 / 3 * 0.05,
                            width: width * 0.72, height: width * 4 / 3 * 0.90
                        )
                    )
                    .stroke(
                        Palette.cocoaPrimary.opacity(0.22),
                        style: StrokeStyle(lineWidth: 1.4, dash: [4, 6])
                    )
                }
            }
            .frame(width: width, height: width * 4 / 3)
    }

    private var matWidth: CGFloat {
        // 42% of the content column (screen minus the page gutters).
        (UIScreen.main.bounds.width - Space.lg * 2) * 0.42
    }
}
