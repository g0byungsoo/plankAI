import SwiftUI

// MARK: - OV5 chrome
//
// One top bar for the whole flow: thin back chevron, five hairline act
// segments (the current act fills as per-act sub-progress; total length
// stays hidden — BetterMe #11 / her75 segmented dashes), lowercase act
// eyebrow beneath. The bar and the Grainfield atmosphere persist across
// screen swaps and never re-animate; only screen content transitions.

struct OV5TopBar: View {
    let canGoBack: Bool
    let act: Int
    let fraction: Double
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                HStack {
                    if canGoBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Palette.cocoaSecondary)
                        }
                        .buttonStyle(.plain)
                        .tappableArea()
                        .transition(.opacity)
                    }
                    Spacer()
                }

                // Five 2pt hairline segments, 160pt total. The active
                // act's segment fills left-to-right; finished acts hold
                // solid; future acts stay at 12% cocoa.
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { i in
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Palette.hairlineCocoa)
                                Capsule()
                                    .fill(Palette.cocoaPrimary)
                                    .frame(width: geo.size.width * segmentFill(i))
                                    .animation(.easeOut(duration: 0.35), value: fraction)
                            }
                        }
                        .frame(height: 2)
                    }
                }
                .frame(width: 160, height: 2)
            }
            .frame(height: 44)

            Text(OV5Step.actEyebrows[act])
                .font(Typo.kicker)
                .kerning(2.0)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .animation(.none, value: act)
        }
        .padding(.horizontal, Space.md)
    }

    private func segmentFill(_ index: Int) -> CGFloat {
        if index < act { return 1 }
        if index > act { return 0 }
        return CGFloat(fraction)
    }
}

// MARK: - OV5Screen frame
//
// Three-band vertical rhythm (panel designer spec): the headline band
// starts at a FIXED 96pt below the chrome on every screen so headlines
// never reflow screen-to-screen; the interaction band owns the middle;
// the CTA dock (when present) rides safeAreaInset so it can never be
// pushed off-screen. Short lists hold position — they do not center.

struct OV5Screen<Content: View>: View {
    var headlineTopPadding: CGFloat = 44
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: headlineTopPadding)
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - OV5Header

struct OV5Header: View {
    let title: String
    var italic: [String] = []
    var sub: String? = nil
    var alignment: TextAlignment = .center

    var body: some View {
        VStack(spacing: Space.md) {
            ItalicAccentText(
                title,
                italic: italic,
                baseFont: Typo.questionHero,
                italicFont: Typo.questionHeroItalic,
                alignment: alignment
            )
            .lineSpacing(Typo.questionHeroLineGap)
            .kerning(-0.4)
            .fixedSize(horizontal: false, vertical: true)
            .ov5Beat1()

            if let sub {
                Text(sub)
                    .font(Typo.teachSub)
                    .lineSpacing(Typo.teachSubLineSpacing)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(alignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .ov5Beat2()
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
        .padding(.horizontal, Space.lg)
    }
}

// MARK: - Two-beat entrance system
//
// Port of the founder-tuned SoftInRise cadence: beat 1 (headline) rides
// the page cross-dissolve with only a 6pt settle; beat 2 (everything
// else) holds invisible through the swap and reveals ONCE as a single
// unit at +0.34s. No scale — "bloom spam" was flagged and removed in
// v1.9; opacity + small rise only.

private struct OV5BeatModifier: ViewModifier {
    let delay: Double
    let fade: Bool
    var rise: CGFloat = 6
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(fade && !reduceMotion && !appeared ? 0 : 1)
            .offset(y: appeared || reduceMotion ? 0 : rise)
            .task {
                guard !appeared else { return }
                if reduceMotion { appeared = true; return }
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                withAnimation(Motion.revealFade) { appeared = true }
            }
    }
}

extension View {
    /// Headline beat: the cross-dissolve owns the fade; a small rise
    /// settles it. Apply to the hero + anything that must land first.
    func ov5Beat1() -> some View {
        modifier(OV5BeatModifier(delay: 0, fade: false))
    }
    /// Content beat: hidden through the page swap, reveals as one unit
    /// after the headline settles (~0.34s), the two-beat luxury read.
    func ov5Beat2(extraDelay: Double = 0) -> some View {
        modifier(OV5BeatModifier(delay: 0.34 + extraDelay, fade: true))
    }
}

// MARK: - CTA dock

struct OV5CTADock<Extra: View>: ViewModifier {
    let label: String
    let isEnabled: Bool
    let action: () -> Void
    var secondaryLabel: String? = nil
    var secondaryAction: (() -> Void)? = nil
    @ViewBuilder var extra: () -> Extra

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                extra()
                JFContinueButton(
                    label: label,
                    action: action,
                    isEnabled: isEnabled,
                    secondaryLabel: secondaryLabel,
                    secondaryAction: secondaryAction
                )
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.sm)
            .background(
                // Content scrolling under the dock dissolves instead of
                // hard-clipping against the button.
                LinearGradient(
                    colors: [Palette.bgPrimary.opacity(0), Palette.bgPrimary.opacity(0.92), Palette.bgPrimary],
                    startPoint: .top, endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
            .ov5Beat2(extraDelay: 0.05)
        }
    }
}

extension View {
    func ov5CTA(
        _ label: String,
        isEnabled: Bool = true,
        secondaryLabel: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        modifier(OV5CTADock(
            label: label, isEnabled: isEnabled, action: action,
            secondaryLabel: secondaryLabel, secondaryAction: secondaryAction,
            extra: { EmptyView() }
        ))
    }
}

// MARK: - Citation chip (honest-credential register)

struct OV5CitationChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Typo.captionTracked)
            .kerning(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                Capsule().strokeBorder(Palette.hairlineCocoa, lineWidth: 1)
            )
    }
}
