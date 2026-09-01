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
        // p61 — the cut-paper offset shadow and the accent border were
        // the v1.0 scrapbook signature, retired app-side at v14 (§6.1:
        // hairline edge + contact shadow; §12.4 bans border+shadow+fill;
        // §12.5 bans colour carrying state). Every surviving call site
        // is the pre-paywall reveal chain — the last thing a prospect
        // sees before the wall — so it now renders the SAME material as
        // the product she is buying. Parameters stay for call-site
        // compatibility; the geometry rides the app's own tokens.
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .fill(Palette.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Palette.textPrimary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: Palette.textPrimary.opacity(0.06), radius: 14, y: 6)
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
