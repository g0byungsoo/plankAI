import SwiftUI

// MARK: - PageDimensions
//
// Round-4 vertical budget table. Each lesson page must fit one iPhone
// viewport with no scroll under standard Dynamic Type. On iPhone 17
// (852pt), after status bar (60pt) + top bar (44pt) + folio (28pt) +
// CTA pill (88pt) + safe area (40pt) = ~260pt chrome. The body region
// gets 592pt. Every visual+typography composition fits inside that.

enum PageDimensions {
    // MARK: - Overall budget

    static let bodyRegion: CGFloat        = 592

    // MARK: - Top bar (round-4 K1)

    static let topBarHeight: CGFloat      = 44   // was ~80
    static let topBarVPad: CGFloat        = 8    // was 12
    static let chevronSize: CGFloat       = 28   // was 36
    static let pageDotDiameter: CGFloat   = 5    // was 6
    static let pageDotSpacing: CGFloat    = 4

    // MARK: - Hairline divider (round-4 K3)

    static let hairlineWidth: CGFloat     = 56
    static let hairlineThickness: CGFloat = 0.75 // was 1.0
    static let hairlineVGutter: CGFloat   = 11   // was Space.md (16); total 32pt → 22pt

    // MARK: - Body type (round-4 K4)

    static let bodyFontSize: CGFloat      = 16   // was 17
    static let bodyLineSpacing: CGFloat   = 4    // was 5
    static let bodyMaxLines: Int          = 8    // 5 was too aggressive on iPhone-17

    // MARK: - Footer (round-4 K8)

    static let footerHeight: CGFloat      = 88   // was 120
    static let ctaHeight: CGFloat         = 48   // was 52

    // MARK: - Anchor visual ladder (round-4 K5)

    /// Returns the vertical region the visual anchor occupies. Pinned
    /// artifacts + accent corners use ABSOLUTE OVERLAY so they cost
    /// zero vertical — only hero photos take a slot in the column.
    static func visualHeight(for anchor: LessonAnchor) -> CGFloat {
        switch anchor {
        case .typographyOnly:       return 0
        case .singleHeroPhoto:      return 260
        case .singleArtifactPinned: return 0
        case .twinAccentCorners:    return 0
        case .scrapbookSpread:      return 0
        case .layoutArchetype:      return 0   // archetype renderer owns layout
        }
    }
}
