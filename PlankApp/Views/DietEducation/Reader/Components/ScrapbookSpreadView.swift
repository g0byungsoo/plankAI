import SwiftUI

// MARK: - ScrapbookSpreadView
//
// Round-5 Pinterest-magazine-spread renderer for the JeniMethod lesson
// reader. Composes 2-3 brand-library assets around + within the
// typography column at varied scales / rotations / opacities / edge
// bleeds. Replaces the round-4 "single top-anchored hero stripe" with
// a magazine-spread register where stickers BLEND INTO the article.
//
// Composition rules (per round-5 expert synthesis):
//   - Layer 1 (under-text): large anchors at 0.78-0.85 opacity sit
//     BEHIND the text column; ink-reveal headline lands on them like
//     type on a magazine page. Soft warm-cocoa shadow (radius 12,
//     offset -3/+6) suggests 35° top-left light source.
//   - Layer 2 (text column): InkRevealHeadline + body + citation at
//     84% canvas width centered. Headline color stays ink-black
//     regardless of any sticker beneath — typography never gives way.
//   - Layer 3 (over-cream): mid-tier stickers float beside the text
//     in cream margins. Body never overlaps them.
//   - Layer 4 (marginalia): small stickers tucked in gutters with a
//     hard-offset shadow (scrapbook-tape register).
//
// Reduce-Motion + accessibility Dynamic Type: stickers ALL hidden;
// the typography column renders alone. Readability wins.
//
// Mount choreography: bloom-stagger entrance (each slot lands with
// 60ms cascade-tight delay + spring), 2.4s settle, then the largest
// under-text anchor begins a slow 3.2s sine breathe at ±1.5% scale.

struct ScrapbookSpreadView<Content: View>: View {
    let recipe: ScrapbookRecipe
    let slots: [ScrapbookSlot]
    @ViewBuilder let textColumn: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var mounted = false
    @State private var breathe = false

    var body: some View {
        GeometryReader { geo in
            let isAccessibility = dynamicType.isAccessibilitySize

            ZStack(alignment: .topLeading) {
                // Text column — primary surface, full canvas.
                textColumn()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .accessibilityElement(children: .contain)

                // Stickers — round-5b: ALL stickers live in cream-only
                // zones (top band above headline + bottom gap above
                // folio). They render OVER the text z-layer but never
                // physically overlap the typography because of where
                // they're positioned, not because of opacity tricks.
                // Accessibility Dynamic Type: stickers hidden, the
                // type column reflows freely without competing with art.
                if !isAccessibility {
                    ForEach(Array(slots.enumerated()), id: \.offset) { idx, slot in
                        stickerView(slot, in: geo.size, layer: slot.zIntent, staggerIndex: idx)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped(antialiased: false)
            .onAppear {
                if reduceMotion { mounted = true; return }
                withAnimation(.easeOut(duration: 0.42)) { mounted = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                        breathe = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stickerView(_ slot: ScrapbookSlot,
                             in canvas: CGSize,
                             layer: ZIntent,
                             staggerIndex: Int) -> some View {
        let base = min(canvas.width, canvas.height)
        let size = base * slot.sizePct
        let isBreatheTarget = layer == .underText && staggerIndex == 0
        let scale = (mounted ? 1.0 : 0.92) * (isBreatheTarget && breathe ? 1.015 : 1.0)

        // Enforce typography-legibility opacity caps per the round-5
        // expert spec. Any sticker that visually overlaps the body
        // column ducks to a safe-against-text opacity; gutters +
        // edge-bleeds run at the slot's declared opacity.
        let cappedOpacity = legibilityCappedOpacity(slot, layer: layer)
        let opacity = mounted ? cappedOpacity : 0

        let x = canvas.width * slot.position.defaultX + canvas.width * slot.offsetXPct
        let y = canvas.height * slot.position.defaultY + canvas.height * slot.offsetYPct

        Image(slot.assetSlug)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .rotationEffect(.degrees(slot.rotationDeg))
            .shadow(color: shadowColor(for: layer),
                    radius: shadowRadius(for: layer),
                    x: shadowOffset(for: layer).width,
                    y: shadowOffset(for: layer).height)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(x: x, y: y)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(reduceMotion ? nil
                       : .easeOut(duration: 0.42).delay(Double(staggerIndex) * 0.06),
                       value: mounted)
    }

    /// Round-5b: every slot lives in a cream-only zone, so we render
    /// at full declared opacity (no legibility tax). The previous
    /// under-text / over-cream capping is moot — there's nothing to
    /// overlap.
    private func legibilityCappedOpacity(_ slot: ScrapbookSlot, layer: ZIntent) -> Double {
        return slot.opacity
    }

    private func shadowColor(for layer: ZIntent) -> Color {
        switch layer {
        case .underText:  return Color(red: 0.30, green: 0.22, blue: 0.18).opacity(0.18)
        case .overCream:  return Color(red: 0.30, green: 0.22, blue: 0.18).opacity(0.16)
        case .marginalia: return Color(red: 0.30, green: 0.22, blue: 0.18).opacity(0.30)
        }
    }
    private func shadowRadius(for layer: ZIntent) -> CGFloat {
        switch layer {
        case .underText:  return 12
        case .overCream:  return 8
        case .marginalia: return 0
        }
    }
    private func shadowOffset(for layer: ZIntent) -> CGSize {
        switch layer {
        case .underText:  return CGSize(width: -3, height: 6)
        case .overCream:  return CGSize(width: -2, height: 4)
        case .marginalia: return CGSize(width:  3, height: 4)
        }
    }
}

// MARK: - DropCapParagraph
//
// Round-5 magazine-standard 4-line illuminated drop cap. Renders the
// first letter of the body at 52pt italic Jeni Hero Serif (jeweledRose
// cocoa fallback for the base palette), inline-aligned with the rest
// of the paragraph wrapping around it. The drop cap creates a
// negative-space triangle above + left that the topLeftVoid sticker
// fills (see ScrapbookSlot defaults). On every P1 of a scrapbook
// spread, this is the editorial-spread signature that signals
// "literate magazine" from first impression.

struct DropCapParagraph: View {
    let text: String
    var bodyFontSize: CGFloat = 16
    var lineSpacing: CGFloat = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var capVisible = false

    private var firstLetter: String {
        guard let first = text.first else { return "" }
        return String(first).lowercased()
    }
    private var restOfText: String {
        guard text.count > 1 else { return "" }
        return String(text.dropFirst())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(firstLetter)
                .font(.custom("JeniHeroSerif-Italic", size: 52))
                .foregroundStyle(Palette.textPrimary)
                .baselineOffset(-6)
                .padding(.trailing, 2)
                .opacity(capVisible ? 1 : 0)
                .accessibilityHidden(true)

            Text(restOfText)
                .font(.custom("DMSans-Regular", size: bodyFontSize, relativeTo: .body))
                .lineSpacing(lineSpacing)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .onAppear {
            guard !reduceMotion else { capVisible = true; return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) {
                withAnimation(.easeOut(duration: 0.22)) { capVisible = true }
            }
        }
    }
}
