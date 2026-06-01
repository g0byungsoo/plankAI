import SwiftUI

// MARK: - BreathLibraryView
//
// The picker for the breathwork library — the screen the user lands on
// when they tap BreathworkHomeCard from home. Three protocols for v1, all
// sharing the same BreathCircle visual but with different inhale/exhale/
// repeats configs.
//
// Pattern: expandable cards. At most one card open at a time. Tap any card
// → it expands to reveal when-to-use, mechanism, and "let's begin" CTA.
// Tap another → collapse current + expand new. This keeps everything on a
// single scroll (no push-pop nav) so the user can compare protocols
// quickly, which matches the 2026 fitness-app pattern (Othership's
// session-category browse).
//
// Day-1 PostPurchaseFlowView intentionally does NOT route through here —
// first-timers see the science primer (BreathworkPrimerView) + a default
// calming session. The library is the re-entry surface for users who've
// already met the practice once.

struct BreathLibraryView: View {
    /// Caller dismisses the cover when the user picks a protocol — and
    /// passes back the chosen one so the parent's @State can be set
    /// before the session view mounts.
    let onBegin: (BreathworkProtocol) -> Void
    let onClose: () -> Void

    @State private var expanded: BreathworkProtocol? = nil

    // v1.0.7 — decoupled height from content visibility. `expanded`
    // drives the container conditional (height transitions); `contentReady`
    // gates the inner text opacity (shown only AFTER the height
    // transition completes on expand, hidden BEFORE the height
    // transition starts on collapse). The earlier "flicker" the user
    // reported was the text fading in/out simultaneously with the
    // height change, so glyphs were partly visible against a partly
    // collapsed chrome — read as a layout bug.
    @State private var contentReady: BreathworkProtocol? = nil

    // Entrance state — header + per-card visibility. Animates in a
    // cascade on view appear so the screen reads as deliberate, not
    // an instant content dump. Matches the AnalyticsView cascade
    // language (header up, then rows ripple in 0.12s stagger).
    @State private var headerVisible = false
    @State private var cardVisible: [Bool] = Array(
        repeating: false,
        count: BreathworkProtocol.allCases.count
    )
    @State private var entranceDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            StickerScatter(placements: Self.libraryScatter)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.md) {
                        header
                            .padding(.top, Space.md)
                            .padding(.bottom, Space.sm)
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : 10)
                        ForEach(Array(BreathworkProtocol.allCases.enumerated()), id: \.element.id) { idx, proto in
                            protocolCard(proto)
                                .opacity(cardVisible[idx] ? 1 : 0)
                                .offset(y: cardVisible[idx] ? 0 : 14)
                        }
                        Spacer().frame(height: Space.xl)
                    }
                    .padding(.horizontal, Space.lg)
                }
            }
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Entrance cascade

    /// Header fades up first, then each card ripples in one by one with
    /// 0.12s stagger. Reduce-motion snaps to final state. Single source
    /// of truth via `entranceDone` so a re-appear (e.g. cover dismiss
    /// returning here) doesn't replay the animation.
    private func runEntrance() {
        guard !entranceDone else { return }
        entranceDone = true

        if reduceMotion {
            headerVisible = true
            for i in cardVisible.indices { cardVisible[i] = true }
            return
        }

        Haptics.soft()
        withAnimation(.easeOut(duration: 0.55).delay(0.05)) {
            headerVisible = true
        }
        for i in cardVisible.indices {
            let delay = 0.18 + Double(i) * 0.12
            withAnimation(Motion.gentleSpring.delay(delay)) {
                cardVisible[i] = true
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                Haptics.light()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.5)))
                    .tappableArea()
            }
            .accessibilityLabel("Close")
            .padding(.trailing, Space.lg)
            .padding(.top, Space.md)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("PICK YOUR BREATH")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)
            ItalicAccentText("three ways to settle, find balance, or wake up.",
                             italic: ["settle", "balance", "wake up"],
                             baseFont: titleFont,
                             italicFont: titleItalicFont,
                             color: Palette.textPrimary,
                             alignment: .leading)
            Text("tap a breath to see how + when to use it.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleFont: Font {
        Font.custom("Fraunces72pt-SemiBold", size: 22, relativeTo: .title3)
    }
    private var titleItalicFont: Font {
        Font.custom("Fraunces72pt-SemiBoldItalic", size: 22, relativeTo: .title3)
    }

    // MARK: - Card

    @ViewBuilder
    private func protocolCard(_ proto: BreathworkProtocol) -> some View {
        let isOpen = expanded == proto
        let showContent = contentReady == proto
        VStack(alignment: .leading, spacing: Space.sm) {
            // Summary block — title, subtitle, pattern. Not a button
            // anymore (the affordance row below carries both actions
            // explicitly). Stays tappable via the row tap area below.
            summary(proto)

            // Affordance row — v1.0.7. The collapsed card previously
            // showed only a chevron, so users couldn't tell they could
            // START the breathwork without first expanding. Now there
            // are two explicit hit targets:
            //   • [▶ begin] — primary accent pill, starts the session
            //   • how it works ⌄ — secondary text link, expands details
            // The pill is always visible (collapsed AND expanded) so the
            // begin action is one tap from any state. Tapping the
            // chevron link toggles the expansion.
            affordanceRow(proto, isOpen: isOpen)

            if isOpen {
                expansion(proto)
                    // Two-phase animation kills the mid-animation
                    // glyph-peek flicker AND the "second card snaps
                    // back" issue:
                    //
                    //  • EXPANDING: chrome grows first via the spring
                    //    in `toggleCard`'s `withAnimation`, then content
                    //    fades in (also wrapped in withAnimation) once
                    //    the chrome settles. Text never appears inside
                    //    a partially-grown card.
                    //
                    //  • COLLAPSING: content fades out first, THEN the
                    //    chrome shrinks. Because the chrome-shrink is
                    //    inside `withAnimation(.spring(...))`, the PARENT
                    //    VStack picks up the animation context and the
                    //    sibling cards REFLOW SMOOTHLY into the freed
                    //    space instead of snapping. Earlier versions
                    //    mutated `expanded = nil` outside any animation
                    //    transaction, which left the layout reflow
                    //    un-animated — that's what made the second card
                    //    "jump back to original position" abruptly.
                    .opacity(showContent ? 1 : 0)
                    .clipped()
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(chrome(highlight: isOpen))
        .overlay(alignment: .topTrailing) { cardSticker(proto.sticker) }
        .accessibilityElement(children: .contain)
        // No `.animation(value:)` here — the toggle handler wraps every
        // state mutation in `withAnimation` so a single animation
        // transaction covers chrome, expansion, content opacity, AND
        // sibling VStack reflow. Mixing explicit `withAnimation` with
        // implicit `.animation(value:)` was causing the abrupt
        // sibling jump because the implicit one fired before the
        // explicit transaction settled.
    }

    /// Tap handler — orchestrates the two-phase expand/collapse using
    /// `withAnimation` so the parent VStack's layout reflow (sibling
    /// cards moving) is part of the same animation transaction. Spring
    /// (response 0.5, damping 0.86) for the chrome — feels natural for
    /// size changes, matches SwiftUI's default fluid motion. easeIn for
    /// content fade-out (lingers, then settles), easeOut for fade-in
    /// (snappy start, slow finish — feels alive).
    private func toggleCard(_ proto: BreathworkProtocol) {
        Haptics.light()
        let wasOpen = expanded == proto

        if wasOpen {
            // COLLAPSING the same card.
            // Phase 1: fade content out (0.24s, easeIn).
            withAnimation(.easeIn(duration: 0.24)) {
                contentReady = nil
            }
            // Phase 2: shrink chrome — wrapped in withAnimation so the
            // VStack reflow (sibling cards moving up) animates as part
            // of the same transaction. Spring duration ~0.5s.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    expanded = nil
                }
            }
        } else if expanded != nil {
            // SWITCHING from one open card to another. Four phases.
            // Phase 1: fade old content (0.24s).
            withAnimation(.easeIn(duration: 0.24)) {
                contentReady = nil
            }
            // Phase 2: close old + open new chrome in one spring
            // transaction so both cards reflow together.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    expanded = proto
                }
                // Phase 3: reveal new content after the spring settles
                // (~0.5s for response=0.5).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        contentReady = proto
                    }
                }
            }
        } else {
            // EXPANDING from collapsed. Two phases.
            // Phase 1: grow chrome with spring.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                expanded = proto
            }
            // Phase 2: reveal content after spring settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    contentReady = proto
                }
            }
        }
    }

    private func summary(_ proto: BreathworkProtocol) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(proto.title.uppercased())
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)
            Text(proto.subtitle)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 20))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 38)   // reserve room for the sticker
            Text("\(proto.patternLabel) · \(proto.durationLabel)")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two explicit hit targets so the collapsed card carries both
    /// affordances visibly: the begin pill (primary) and the details
    /// chevron (secondary). Replaces the prior chevron-only summary
    /// where users couldn't tell they could start without expanding.
    private func affordanceRow(_ proto: BreathworkProtocol, isOpen: Bool) -> some View {
        HStack(spacing: Space.sm) {
            // Begin pill — dusty rose, italic Fraunces, primary action.
            Button {
                Haptics.medium()
                Analytics.track(.breathworkProtocolSelected, properties: [
                    "protocol_id": proto.rawValue,
                    "entry": isOpen ? "expanded_pill" : "collapsed_pill"
                ])
                onBegin(proto)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("begin")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
                }
                .foregroundStyle(Palette.textInverse)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Palette.bgInverse)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Begin \(proto.title) breath now")

            Spacer(minLength: 0)

            // Details link — secondary, text + chevron. Tap to expand.
            Button {
                toggleCard(proto)
            } label: {
                HStack(spacing: 4) {
                    Text(isOpen ? "less" : "how it works")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Palette.textSecondary)
                .padding(.vertical, 6)
                .tappableArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOpen ? "Collapse details" : "Show how it works")
        }
        .padding(.top, 4)
    }

    private func expansion(_ proto: BreathworkProtocol) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Divider().padding(.vertical, 2)

            // Rhythm bar — the in/out pills are proportionally sized to
            // the seconds, so calming visibly shows "long exhale" without
            // anyone having to read the numbers. The hero of the
            // expansion; everything below supports it.
            rhythmBar(proto)

            // WHEN — a dot-separated single line, no chip chrome. The
            // earlier paragraph read as instructions; this reads as a
            // scannable receipt.
            VStack(alignment: .leading, spacing: 4) {
                Text("WHEN")
                    .font(Typo.eyebrow).tracking(1.5)
                    .foregroundStyle(Palette.textSecondary)
                Text(proto.whenSituations.joined(separator: " · "))
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // WHY — a single italic-Fraunces pull quote naming the
            // mechanism. The science word italicized; everything else
            // lowercase casual. One line beats the prior textbook
            // paragraph for the clean/luxury read.
            VStack(alignment: .leading, spacing: 4) {
                Text("WHY")
                    .font(Typo.eyebrow).tracking(1.5)
                    .foregroundStyle(Palette.textSecondary)
                ItalicAccentText(
                    proto.whyHeadline,
                    italic: proto.whyItalicWords,
                    baseFont: whyFont,
                    italicFont: whyItalicFont,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
            }

            // Citation footer — receipts, not a footnote dump. The
            // bottom-of-expansion `let's begin` CTA was removed in
            // v1.0.7 because the affordance row's begin pill (above
            // the expansion) is always visible — having two begin
            // buttons in the same card was redundant. One pill, one
            // place to tap.
            Text(proto.citation)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Palette.textSecondary.opacity(0.85))
                .tracking(0.3)
        }
    }

    // MARK: - Rhythm bar

    /// Two proportional pills: inhale on the left, exhale on the right.
    /// Widths are sized by `inhaleSec : exhaleSec`, so .calming (4:6)
    /// renders the exhale pill noticeably wider than the inhale pill —
    /// the "long exhale" mechanism is visible before anyone reads the
    /// numbers.
    private func rhythmBar(_ proto: BreathworkProtocol) -> some View {
        GeometryReader { geo in
            let total = CGFloat(proto.inhaleSec + proto.exhaleSec)
            let gap: CGFloat = 8
            let usable = max(0, geo.size.width - gap)
            let inhaleW = max(56, usable * CGFloat(proto.inhaleSec) / total)
            let exhaleW = max(56, usable * CGFloat(proto.exhaleSec) / total)
            HStack(spacing: gap) {
                rhythmPill(label: "IN", seconds: proto.inhaleSec, width: inhaleW)
                rhythmPill(label: "OUT", seconds: proto.exhaleSec, width: exhaleW)
            }
        }
        .frame(height: 56)
    }

    private func rhythmPill(label: String, seconds: Int, width: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(1.4)
            Text("\(seconds)")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 24))
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(width: width, height: 56)
        .background(
            Capsule().fill(Palette.accent.opacity(0.18))
        )
        .overlay(
            Capsule().stroke(Palette.accent.opacity(0.55), lineWidth: 1.2)
        )
    }

    private var whyFont: Font {
        Font.custom("Fraunces72pt-SemiBold", size: 18, relativeTo: .body)
    }
    private var whyItalicFont: Font {
        Font.custom("Fraunces72pt-SemiBoldItalic", size: 18, relativeTo: .body)
    }

    private func chrome(highlight: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.accent.opacity(highlight ? 0.18 : 0.12))
                .offset(x: 4, y: 4)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.bgElevated)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.accent.opacity(highlight ? 0.85 : 0.5), lineWidth: 1.5)
        }
    }

    private func cardSticker(_ name: StickerName) -> some View {
        Image(name.assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
            .rotationEffect(.degrees(10))
            .offset(x: 6, y: -10)
            .opacity(name.style.opacity * 0.9)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Scatter

    private static let libraryScatter: [StickerPlacement] = [
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.92, y: 0.08),
                         size: 28, rotation: 14, phaseDelay: 0.0),
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.08, y: 0.92),
                         size: 30, rotation: -8, phaseDelay: 0.6),
    ]
}

#if DEBUG
#Preview {
    BreathLibraryView(onBegin: { _ in }, onClose: {})
}
#endif
