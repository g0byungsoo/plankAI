import SwiftUI
import UIKit

// MARK: - WrappingTextView
//
// Round-7: UITextView wrapped for SwiftUI so `NSTextContainer.exclusionPaths`
// can wrap body + headline text AROUND an absolutely-positioned sticker.
// Replaces the round-6 SideBleedHalf (which forced text into a 52%-width
// column and shredded it into 2-3 words per line, founder feedback:
// "readability is horrible"). With wrap_bleed, text uses the FULL canvas
// width and the sticker carves a magazine-style hole that text reflows
// around — like Vogue / Cereal page wraps.
//
// Implementation notes:
//   - isScrollEnabled = false lets SwiftUI size the view by intrinsic
//     content (UITextView reports preferredMaxLayoutWidth properly).
//   - textContainerInset = .zero + lineFragmentPadding = 0 removes the
//     stock 8pt + 5pt padding so the exclusion math aligns to the pixel.
//   - exclusionPaths lives in the text container's coordinate space,
//     which equals the UITextView's bounds after we zero the insets.
//   - The exclusion rect is inset by `exclusionInset` so glyphs don't
//     kiss the sticker edge.

struct WrappingTextView: UIViewRepresentable {
    let attributed: NSAttributedString
    /// Sticker rect in WrappingTextView's local coordinate space.
    /// Caller computes from the same GeometryReader the sticker uses.
    let exclusion: CGRect
    /// Extra breathing room around the sticker so glyphs don't kiss it.
    var exclusionInset: CGFloat = 10
    /// Corner radius used to soften the exclusion bezier so text hugs
    /// the curve instead of the square bounding box.
    var exclusionCornerRadius: CGFloat = 14

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.widthTracksTextView = true
        tv.adjustsFontForContentSizeCategory = true
        tv.setContentHuggingPriority(.required, for: .vertical)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        tv.attributedText = attributed
        let padded = exclusion.insetBy(dx: -exclusionInset, dy: -exclusionInset)
        let path = UIBezierPath(roundedRect: padded, cornerRadius: exclusionCornerRadius)
        tv.textContainer.exclusionPaths = [path]
        tv.invalidateIntrinsicContentSize()
    }
}

// MARK: - LessonAttributedBuilder
//
// Composes a single NSAttributedString from the lesson's headline +
// body + italic punch words so WrappingTextView can wrap one cohesive
// text block around a sticker. Matches the InkRevealHeadline italic-
// punch logic but lives at the AttributedString layer so UITextView
// can take it whole.

enum LessonAttributedBuilder {
    static func compose(headline: String,
                        italicWords: [String],
                        body: String,
                        kicker: String? = nil) -> NSAttributedString {
        let out = NSMutableAttributedString()

        let cocoa = UIColor(Palette.textPrimary)
        let secondary = UIColor(Palette.textSecondary)

        // Optional kicker (tracked uppercase, DM Sans 11).
        if let kicker, !kicker.isEmpty {
            let kickerStyle = NSMutableParagraphStyle()
            kickerStyle.paragraphSpacing = 12
            let kickerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "DMSans-Medium", size: 11) ?? .systemFont(ofSize: 11),
                .foregroundColor: secondary,
                .kern: 1.98 as NSNumber,
                .paragraphStyle: kickerStyle,
            ]
            out.append(NSAttributedString(string: kicker.lowercased() + "\n",
                                          attributes: kickerAttr))
        }

        // Headline — Jeni Hero Serif 32pt with italic-Fraunces punch words.
        let headlineStyle = NSMutableParagraphStyle()
        headlineStyle.paragraphSpacing = 14
        headlineStyle.lineHeightMultiple = 1.05
        let headlineFont = UIFont(name: "JeniHeroSerif-Regular", size: 32)
            ?? UIFont.systemFont(ofSize: 32, weight: .semibold)
        let headlineItalicFont = UIFont(name: "JeniHeroSerif-Italic", size: 32)
            ?? UIFont.italicSystemFont(ofSize: 32)
        let headlineBase: [NSAttributedString.Key: Any] = [
            .font: headlineFont,
            .foregroundColor: cocoa,
            .paragraphStyle: headlineStyle,
            .kern: -0.4 as NSNumber,
        ]

        // Pass 1: append the headline as base.
        let cleaned = headline
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "*", with: "")
        let head = NSMutableAttributedString(string: cleaned + "\n",
                                             attributes: headlineBase)
        // Pass 2: swap italic font over each punch-word range.
        for word in italicWords {
            let needle = word.lowercased()
            let hay = cleaned.lowercased()
            var search = hay.startIndex
            while search < hay.endIndex,
                  let range = hay.range(of: needle, range: search..<hay.endIndex) {
                let nsRange = NSRange(range, in: cleaned)
                head.addAttribute(.font, value: headlineItalicFont, range: nsRange)
                search = range.upperBound
            }
        }
        out.append(head)

        // Body — DM Sans 16pt, line spacing 4.
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 4
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "DMSans-Regular", size: 16) ?? .systemFont(ofSize: 16),
            .foregroundColor: cocoa,
            .paragraphStyle: bodyStyle,
        ]
        out.append(NSAttributedString(string: body, attributes: bodyAttr))

        return out
    }
}
