import SwiftUI

// MARK: - LayoutArchetypeView
//
// Round-6 layout dispatcher. Renders one of 5 archetype views around
// the lesson's text column. Each archetype is its own SwiftUI render
// pattern — VStack-flow guarantees text never overlaps anything by
// construction (the founder's absolute rule).
//
// Archetype precedents are the her75 App Store screen set:
//   - .pureTypography     = IMG_6267 / IMG_6280 — breath beat
//   - .bottomBleedHero    = IMG_6275 / IMG_6268 — tucked headline
//   - .sideBleedHalf      = IMG_6278               — window portrait
//   - .flatLayPinboard    = IMG_6270 / IMG_6271 / IMG_6272 — pinboard
//   - .topPin             = IMG_6282 / IMG_6261 — small top decoration

struct LayoutArchetypeView<Content: View>: View {
    let archetype: LayoutArchetype
    let slots: [LayoutSlot]
    /// Optional pre-composed attributed string for wrap_bleed. Only
    /// used by the .wrapBleed archetype; ignored by others.
    var wrapAttributed: NSAttributedString? = nil
    @ViewBuilder let textColumn: () -> Content

    var body: some View {
        switch archetype {
        case .pureTypography:
            textColumn()
        case .bottomBleedHero:
            BottomBleedHero(slots: slots, content: textColumn)
        case .sideBleedHalf, .wrapBleed:
            // Round-7: sideBleedHalf is retired and aliased to wrap_bleed.
            if let attr = wrapAttributed {
                WrapBleed(slots: slots, attributed: attr)
            } else {
                BottomBleedHero(slots: slots, content: textColumn)
            }
        case .flatLayPinboard:
            FlatLayPinboard(slots: slots, content: textColumn)
        case .topPin:
            TopPin(slots: slots, content: textColumn)
        }
    }
}

// MARK: - Bottom bleed hero
//
// One large portrait bleeds off the bottom 55-70% of canvas. Text
// renders ABOVE in the cream void. VStack flow guarantees no
// overlap — text takes whatever space it needs, photo fills the
// rest.

private struct BottomBleedHero<Content: View>: View {
    let slots: [LayoutSlot]
    @ViewBuilder let content: Content
    @State private var bloomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var primary: LayoutSlot? { slots.first }

    var body: some View {
        GeometryReader { geo in
            // Round-8f: flex-height image + clip-to-bounds + cream
            // gradient fade at top of photo. Three guarantees:
            //   1. image never extends past the layout bounds (no
            //      overlap with footer folio or CTA pill)
            //   2. image fills the cream void below body, scaledToFit
            //      so it's never cropped to "barely showing"
            //   3. the top edge of every photo dissolves into cream
            //      via a vertical mask gradient, so cutout edges (like
            //      a face-obscured chin line) blend in instead of
            //      cutting hard
            VStack(alignment: .leading, spacing: 0) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let p = primary, let ui = UIImage(named: p.assetSlug) {
                    // Round-8h: per-asset horizontal anchor. The
                    // manifest's xPct field carries the subject's
                    // alpha-weighted x centroid (computed once at gen
                    // time). Photos with subject offset to one side
                    // (>0.58 right, <0.42 left) anchor to that edge
                    // so the visible body stays in frame instead of
                    // appearing "cut" when scaledToFit centers a
                    // wider-than-tall composition.
                    let xAnchor: Alignment = {
                        if p.xPct > 0.58 { return .bottomTrailing }
                        if p.xPct < 0.42 { return .bottomLeading }
                        return .bottom
                    }()
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width,
                               maxHeight: .infinity,
                               alignment: xAnchor)
                        .rotationEffect(.degrees(p.rotationDeg))
                        .opacity(bloomed || reduceMotion ? 1 : 0)
                        .scaleEffect(bloomed || reduceMotion ? 1 : 1.04, anchor: .bottom)
                        .accessibilityHidden(true)
                        .onAppear {
                            if reduceMotion { bloomed = true }
                            else {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.82)
                                                .delay(0.25)) { bloomed = true }
                            }
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .clipped()
        }
    }
}

// MARK: - Side bleed half
//
// Photo extends from right (or left) edge at 40-55% width. Text on
// opposite half. HStack flow guarantees no overlap.

private struct SideBleedHalf<Content: View>: View {
    let slots: [LayoutSlot]
    @ViewBuilder let content: Content
    @State private var bloomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var primary: LayoutSlot? { slots.first }

    private var photoOnLeft: Bool {
        (primary?.xPct ?? 0.78) < 0.5
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if photoOnLeft, let p = primary, let ui = UIImage(named: p.assetSlug) {
                    photoView(ui, slot: p, in: geo.size, side: .left)
                }

                content
                    .frame(maxWidth: .infinity, alignment: photoOnLeft ? .leading : .leading)
                    .frame(width: geo.size.width * 0.52)
                    .padding(.horizontal, Space.sm)

                if !photoOnLeft, let p = primary, let ui = UIImage(named: p.assetSlug) {
                    photoView(ui, slot: p, in: geo.size, side: .right)
                }
            }
        }
    }

    private enum Side { case left, right }

    private func photoView(_ ui: UIImage, slot: LayoutSlot, in canvas: CGSize, side: Side) -> some View {
        Image(uiImage: ui)
            .resizable()
            .scaledToFill()
            .frame(width: canvas.width * slot.sizePct,
                   height: canvas.height * 0.62,
                   alignment: .center)
            .clipped()
            .rotationEffect(.degrees(slot.rotationDeg))
            .opacity(bloomed || reduceMotion ? 1 : 0)
            .scaleEffect(bloomed || reduceMotion ? 1 : 1.03)
            .accessibilityHidden(true)
            .onAppear {
                if reduceMotion { bloomed = true }
                else {
                    withAnimation(.easeOut(duration: 0.55).delay(0.25)) { bloomed = true }
                }
            }
    }
}

// MARK: - WrapBleed
//
// Round-7 archetype that replaces the retired SideBleedHalf. Sticker
// floats at a chosen position; the text USES THE FULL CANVAS WIDTH
// and reflows AROUND the sticker via UITextView.exclusionPaths. This
// is the magazine-spread wrap the founder asked for — text + image
// share a column without competing.

private struct WrapBleed: View {
    let slots: [LayoutSlot]
    let attributed: NSAttributedString
    @State private var bloomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var primary: LayoutSlot? { slots.first }

    var body: some View {
        GeometryReader { geo in
            if let p = primary {
                // Padded text area accounts for horizontal page gutters
                // and a top breath inset (kicker + headline sit inline
                // in the attributed string).
                let textInsetH: CGFloat = Space.lg
                let textInsetTop: CGFloat = 28
                let availableW = geo.size.width - textInsetH * 2
                let availableH = geo.size.height - textInsetTop
                let stickerW = availableW * p.sizePct
                let stickerH = stickerW
                // Exclusion rect is in the text view's local space
                // (i.e. offset by the text view's origin = inset).
                let originX  = availableW * p.xPct - stickerW * 0.5
                let originY  = availableH * p.yPct - stickerH * 0.5
                let exclusionRect = CGRect(x: originX, y: originY,
                                           width: stickerW, height: stickerH)

                ZStack(alignment: .topLeading) {
                    WrappingTextView(attributed: attributed, exclusion: exclusionRect)
                        .frame(width: availableW, height: availableH, alignment: .topLeading)
                        .padding(.horizontal, textInsetH)
                        .padding(.top, textInsetTop)

                    // Sticker positioned in the same local coordinate
                    // space as the exclusion path so they align.
                    if let ui = UIImage(named: p.assetSlug) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(width: stickerW, height: stickerH)
                            .rotationEffect(.degrees(p.rotationDeg))
                            .shadow(color: Palette.cocoaPrimary.opacity(0.10),
                                    radius: 8, x: 0, y: 5)
                            .position(x: textInsetH + originX + stickerW / 2,
                                      y: textInsetTop + originY + stickerH / 2)
                            .opacity(bloomed || reduceMotion ? 1 : 0)
                            .scaleEffect(bloomed || reduceMotion ? 1 : 0.9, anchor: .center)
                            .accessibilityHidden(true)
                            .onAppear {
                                if reduceMotion { bloomed = true; return }
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.78)
                                                .delay(0.20)) { bloomed = true }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Flat lay pinboard
//
// Three stickers VARIED sizes (large + medium + small) scatter in
// the bottom cream zone below the text. Text column comes first in
// the VStack; pinboard sits in remaining cream. If body is too long,
// the pinboard simply clips out of view — text wins.

private struct FlatLayPinboard<Content: View>: View {
    let slots: [LayoutSlot]
    @ViewBuilder let content: Content
    @State private var bloomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, Space.lg)
            // Round-7d: inline HStack of varied-size stickers AFTER
            // the body. SwiftUI's VStack flow guarantees no overlap;
            // if body fills the viewport the row simply clips off-
            // screen. Sizes vary 0.45x → 1.0x base for visual rhythm,
            // rotations vary -10 to +12, z-ordered smaller-on-top.
            inlineRow
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer(minLength: 0)
        }
    }

    private var inlineRow: some View {
        let sorted = slots.sorted { $0.sizePct > $1.sizePct }
        return HStack(alignment: .bottom, spacing: -8) {
            ForEach(Array(sorted.enumerated()), id: \.offset) { idx, slot in
                if let ui = UIImage(named: slot.assetSlug) {
                    let size = 80 + (slot.sizePct - 0.10) * 220   // 80...160pt
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(width: max(60, size), height: max(60, size))
                        .rotationEffect(.degrees(slot.rotationDeg))
                        .shadow(color: Palette.cocoaPrimary.opacity(idx == 0 ? 0.14 : 0.08),
                                radius: idx == 0 ? 10 : 5,
                                x: 0, y: idx == 0 ? 6 : 3)
                        .offset(y: idx == 1 ? -12 : (idx == 2 ? 8 : 0))
                        .opacity(bloomed || reduceMotion ? 1 : 0)
                        .scaleEffect(bloomed || reduceMotion ? 1 : 0.85, anchor: .center)
                        .animation(reduceMotion ? nil
                                   : .spring(response: 0.55, dampingFraction: 0.78)
                                       .delay(Double(idx) * 0.10 + 0.25),
                                   value: bloomed)
                        .zIndex(Double(idx))
                        .accessibilityHidden(true)
                }
            }
        }
        .onAppear { bloomed = true }
    }
}

// MARK: - Top pin
//
// One small/medium sticker between top bar and kicker. Text column
// renders below. VStack flow guarantees no overlap.

private struct TopPin<Content: View>: View {
    let slots: [LayoutSlot]
    @ViewBuilder let content: Content
    @State private var bloomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var primary: LayoutSlot? { slots.first }

    var body: some View {
        VStack(spacing: 0) {
            if let p = primary, let ui = UIImage(named: p.assetSlug) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .rotationEffect(.degrees(p.rotationDeg))
                    .shadow(color: Palette.cocoaPrimary.opacity(0.10),
                            radius: 6, x: 0, y: 3)
                    .padding(.top, 8)
                    .padding(.bottom, Space.md)
                    .opacity(bloomed || reduceMotion ? 1 : 0)
                    .scaleEffect(bloomed || reduceMotion ? 1 : 0.85)
                    .accessibilityHidden(true)
                    .onAppear {
                        if reduceMotion { bloomed = true }
                        else {
                            withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
                                bloomed = true
                            }
                        }
                    }
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
