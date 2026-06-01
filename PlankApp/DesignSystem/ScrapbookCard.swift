import SwiftUI

// MARK: - ScrapbookCard
//
// The canonical card chrome for v1.0+ JeniFit surfaces — 24pt continuous
// corners + 1.5pt accent border + hard offset shadow (tint at 15%
// opacity, offset (4, 4)). Matches Home, Settings sub-pages, Becoming
// tab modules, Browse, PreSession, AnalyticsView, EditProfile.
//
// Extracted 2026-05-30 (epic #1 visual upgrade) from
// AnalyticsView.swift's `scrapbookCardChrome` helper so the onboarding
// brand-promises screen + future surfaces can use the same chrome
// without re-implementing the 3-layer ZStack each time.
//
// Usage:
//   YourContentView()
//       .scrapbookCardBackground()              // accent tint default
//       .scrapbookCardBackground(tint: .pink)   // custom tint shadow
//
// The companion ScrapbookCardBackground view can also be inlined inside
// a ZStack for full layout control (e.g. when you need to overlay
// elements on the card border itself).

/// Reusable scrapbook chrome — 3-layer rounded rectangle stack with
/// hard offset shadow + tinted border. Renders as a background, sized
/// to fit the parent's frame.
struct ScrapbookCardBackground: View {
    var tint: Color = Palette.accent
    var cornerRadius: CGFloat = 24
    var borderWidth: CGFloat = 1.5
    var shadowOffset: CGSize = CGSize(width: 4, height: 4)
    var shadowOpacity: Double = 0.15

    var body: some View {
        ZStack {
            // Layer 1: hard offset shadow — tint-colored, slightly
            // translucent, sits behind the card surface. This is the
            // "scrapbook" feel (cut paper offset, not a soft Material
            // shadow).
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint.opacity(shadowOpacity))
                .offset(x: shadowOffset.width, y: shadowOffset.height)
            // Layer 2: the card surface itself, in the elevated bg
            // tone so it reads as separate from the page background.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Palette.bgElevated)
            // Layer 3: 1.5pt accent border — the visual signature of
            // the JeniFit scrapbook chrome.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(tint, lineWidth: borderWidth)
        }
    }
}

extension View {
    /// Wraps this view in the canonical scrapbook chrome (24pt corners,
    /// 1.5pt accent border, hard offset shadow). Use as a drop-in
    /// replacement for `.background(RoundedRectangle…fill…stroke)`
    /// stacks scattered across the codebase.
    ///
    /// Tint controls both the border color and the offset-shadow color
    /// (at 15% opacity). Pass a non-accent tint when the card needs to
    /// signal a non-default state (e.g. warning, success).
    func scrapbookCardBackground(
        tint: Color = Palette.accent,
        cornerRadius: CGFloat = 24,
        borderWidth: CGFloat = 1.5
    ) -> some View {
        self.background(
            ScrapbookCardBackground(
                tint: tint,
                cornerRadius: cornerRadius,
                borderWidth: borderWidth
            )
        )
    }
}
