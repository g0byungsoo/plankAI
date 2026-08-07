import SwiftUI

// MARK: - JeniTypedLines
//
// The consult's typewriter, promoted out of onboarding so the app can
// speak the same way (founder steer, 2026-08-06: "these kinds of
// notifications need to be on full screen text, like how onboarding
// spit out the sentence by sentence"). Lines type in order at the
// shared V8TypeClock cadence, with the same haptic grammar — a
// whisper per word, a firmer land at each sentence end.
//
// Layout is stable from the first frame (V8LineText paints unrevealed
// characters clear), so nothing reflows as the ink arrives.

struct JeniTypedLines: View {
    let lines: [V8Line]
    var font: Font = V8Type.message
    var italicFont: Font = V8Type.messageItalic
    var color: Color = Palette.textPrimary
    var alignment: TextAlignment = .leading
    /// Fires once the last character of the last line has landed.
    var onComplete: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed: [Int] = []
    @State private var shownCount = 0

    var body: some View {
        VStack(alignment: alignment == .center ? .center : .leading, spacing: 14) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                V8LineText(
                    line: line,
                    revealed: revealed.indices.contains(idx) ? revealed[idx] : 0,
                    font: font,
                    italicFont: italicFont,
                    color: color,
                    alignment: alignment
                )
                .lineSpacing(V8Type.messageLineGap)
                .opacity(idx < shownCount ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .task { await run() }
    }

    @MainActor
    private func run() async {
        revealed = Array(repeating: 0, count: lines.count)
        guard !reduceMotion else {
            revealed = lines.map(\.text.count)
            shownCount = lines.count
            onComplete?()
            return
        }
        try? await Task.sleep(nanoseconds: 260_000_000)
        for (idx, line) in lines.enumerated() {
            guard !Task.isCancelled else { return }
            shownCount = idx + 1
            let chars = Array(line.text)
            var lastTick = Date.distantPast
            for i in 0..<chars.count {
                guard !Task.isCancelled else { return }
                revealed[idx] = i + 1
                let c = chars[i]
                let now = Date()
                if c == "." || c == "!" || c == "?" {
                    JeniHaptic.land()
                    lastTick = now
                } else if c == " ", now.timeIntervalSince(lastTick) > 0.09 {
                    JeniHaptic.tick()
                    lastTick = now
                }
                try? await Task.sleep(
                    nanoseconds: UInt64(V8TypeClock.delay(after: i, in: line.text) * 1_000_000_000)
                )
            }
            revealed[idx] = chars.count
            if idx < lines.count - 1 {
                try? await Task.sleep(nanoseconds: UInt64(V8Tempo.interLine * 1_000_000_000))
            }
        }
        onComplete?()
    }
}

// MARK: - JeniMoment
//
// A full-screen beat: the page says its piece in typed sentences,
// then whatever it needs from you arrives beneath. This is where the
// app's declarations live now — never as a headline block wedged into
// a scrolling surface (Home keeps its anatomy; moments take the room
// they deserve, then hand it back).
//
// Grammar: paper + the same light Home sits under · a quiet eyebrow ·
// typed lines · content arriving on the kit's stagger · one action.
// Swipe down or the pill dismisses; tapping the page completes the
// typing early (the consult's rule).

struct JeniMoment<Content: View>: View {
    var eyebrow: String? = nil
    /// v12 (R6) — the hero numeral register: one massive counted fact
    /// under the eyebrow ("12" · "of 140 days"), before Jeni speaks.
    var heroValue: Double? = nil
    var heroWord: String? = nil
    let lines: [V8Line]
    var cta: String = "done"
    var onDismiss: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var linesDone = false
    @State private var contentIn = false
    @State private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bgPrimary.ignoresSafeArea()
            JeniAtmosphere(height: 420)
                .ignoresSafeArea(edges: .top)

            GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: Space.hero)

                    if let eyebrow {
                        Text(eyebrow.uppercased())
                            .font(.custom("DMSans-SemiBold", size: 11, relativeTo: .caption2))
                            .tracking(1.6)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .padding(.bottom, Space.md)
                            .accessibilityAddTraits(.isHeader)
                    }

                    if let heroValue {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            JeniCountingNumeral(
                                value: heroValue,
                                font: .custom("JeniHeroSerif-Regular", size: 96,
                                              relativeTo: .largeTitle)
                            )
                            if let heroWord {
                                Text(heroWord)
                                    .font(.custom("JeniHeroSerif-Regular", size: 26,
                                                  relativeTo: .title2))
                                    .foregroundStyle(Palette.textPrimary.opacity(0.55))
                            }
                        }
                        .padding(.bottom, Space.blockGap)
                        .accessibilityElement(children: .combine)
                    }

                    JeniTypedLines(lines: lines) {
                        linesDone = true
                        withAnimation(JeniMotion.arrive) { contentIn = true }
                    }

                    if linesDone {
                        content()
                            .padding(.top, Space.blockGap)
                            .opacity(contentIn ? 1 : 0)
                            .offset(y: contentIn || reduceMotion ? 0 : JeniMotion.rise)
                            .transition(.opacity)
                    }

                    // Short moments push their action to the foot of
                    // the screen; long ones let it follow the content.
                    Spacer(minLength: Space.sectionGap)

                    JeniPrimaryButton(cta) { onDismiss() }
                        .opacity(linesDone ? 1 : 0)
                        .animation(JeniMotion.arrive, value: linesDone)
                        .allowsHitTesting(linesDone)

                    Color.clear.frame(height: Space.lg)
                }
                .padding(.horizontal, Space.gutter)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            }
        }
        .offset(y: dragOffset)
        // Drag down to leave — the sheet physics without the sheet
        // chrome (a moment is a page, not a modal).
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { g in
                    guard g.translation.height > 0 else { return }
                    dragOffset = g.translation.height * 0.7
                }
                .onEnded { g in
                    if g.translation.height > 120 {
                        JeniHaptic.tick()
                        onDismiss()
                    } else {
                        withAnimation(JeniMotion.settle) { dragOffset = 0 }
                    }
                }
        )
        .animation(JeniMotion.settle, value: linesDone)
    }
}
