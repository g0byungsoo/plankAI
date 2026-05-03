import SwiftUI

// MARK: - CTAButtonStyle
//
// Three semantic variants that map to JeniFit's button hierarchy:
//   .primary   — cocoa pill, cream label. The "do the thing" button. Used for
//                Get Started, Continue, Subscribe, etc. Single per screen.
//   .secondary — accent (dusty rose) pill, cream label. Reserved for
//                celebratory or selection-confirming actions (e.g., paywall
//                "Continue" once a plan is picked).
//   .tertiary  — text-only, cocoa label. Inline / dismissive actions
//                (Skip, Cancel, "Already have an account").
//
// All variants share the same press feedback (scale 0.98 + opacity 0.85) so
// the touch language reads consistent across hierarchies.

struct CTAButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, tertiary }

    let variant: Variant
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(foreground)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, Space.lg)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(backgroundShape)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var labelFont: Font {
        switch variant {
        case .primary, .secondary: return Typo.heading
        case .tertiary: return Typo.body
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary, .secondary: return Palette.textInverse
        case .tertiary: return Palette.textPrimary
        }
    }

    private var verticalPadding: CGFloat {
        switch variant {
        case .primary, .secondary: return Space.md
        case .tertiary: return Space.sm
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch variant {
        case .primary:
            Capsule().fill(Palette.bgInverse)
        case .secondary:
            Capsule().fill(Palette.accent)
        case .tertiary:
            Color.clear
        }
    }
}

extension ButtonStyle where Self == CTAButtonStyle {
    static var ctaPrimary: CTAButtonStyle { .init(variant: .primary) }
    static var ctaSecondary: CTAButtonStyle { .init(variant: .secondary) }
    static var ctaTertiary: CTAButtonStyle { .init(variant: .tertiary, fullWidth: false) }
}

// MARK: - ItalicAccentText
//
// Renders a base string with selected substrings rendered in Fraunces italic
// for editorial emphasis (e.g., "Become *her* in 30 days"). Implementation
// concatenates Text fragments via the `+` operator — Text concatenation
// preserves per-fragment fonts and produces a single layout-aware Text node,
// which avoids the wrapping artifacts an HStack of Texts would introduce.
//
// Deliberately avoids AttributedString / NSAttributedString so the
// implementation surface is small and predictable. Headlines are short, so
// the linear scan to locate italic substrings is not a performance concern.
//
// Usage:
//   ItalicAccentText(
//       "Become her in 30 days.",
//       italic: ["her"],
//       baseFont: Typo.title,
//       italicFont: Typo.titleItalic
//   )

struct ItalicAccentText: View {
    let base: String
    let italic: [String]
    var baseFont: Font = Typo.title
    var italicFont: Font = Typo.titleItalic
    var color: Color = Palette.textPrimary
    var alignment: TextAlignment = .leading

    init(_ base: String,
         italic: [String],
         baseFont: Font = Typo.title,
         italicFont: Font = Typo.titleItalic,
         color: Color = Palette.textPrimary,
         alignment: TextAlignment = .leading) {
        self.base = base
        self.italic = italic
        self.baseFont = baseFont
        self.italicFont = italicFont
        self.color = color
        self.alignment = alignment
    }

    var body: some View {
        composed
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
    }

    private var composed: Text {
        var output = Text("")
        var cursor = base.startIndex
        let end = base.endIndex
        while cursor < end {
            // Find the earliest italic substring at or after cursor across
            // all candidates. First-match-wins so callers can pass overlapping
            // candidates without surprising precedence.
            var nearest: Range<String.Index>? = nil
            for needle in italic where !needle.isEmpty {
                if let r = base.range(of: needle, range: cursor..<end),
                   nearest == nil || r.lowerBound < nearest!.lowerBound {
                    nearest = r
                }
            }
            if let match = nearest {
                if match.lowerBound > cursor {
                    output = output + Text(String(base[cursor..<match.lowerBound])).font(baseFont)
                }
                output = output + Text(String(base[match])).font(italicFont)
                cursor = match.upperBound
            } else {
                output = output + Text(String(base[cursor..<end])).font(baseFont)
                cursor = end
            }
        }
        return output
    }
}

// MARK: - OnboardingOptionCard
//
// Tappable row used in onboarding multi-choice screens. Layout:
//   [icon circle] [title / optional subtitle] ......... [radio]
// Selected state swaps the border to accent + lights the radio dot. Card bg
// stays bgElevated in both states so the selected row reads as "highlighted"
// rather than "filled" — closer to JustFit / CalAI than to the chunkier iOS
// settings cell.

struct OnboardingOptionCard: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                ZStack {
                    Circle()
                        .fill(Palette.accentSubtle)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Palette.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                Spacer(minLength: Space.sm)

                ZStack {
                    Circle()
                        .stroke(isSelected ? Palette.accent : Palette.divider, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(Space.md)
            .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isSelected ? Palette.accent : Palette.divider,
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PricingCard
//
// Used on the paywall to present a single plan. The yearly card carries a
// floating "Save N%" badge and the selected plan gets a 2pt accent border.
// Weekly stays bordered with the divider color so the visual weight tilts
// toward the yearly choice even before selection.
//
// Pricing copy (price + perWeekEquivalent) is passed in as already-formatted
// strings — the caller (PaywallView) sources these from RevenueCat offerings,
// not hardcoded.

struct PricingCard: View {
    let title: String
    let price: String
    var perWeekEquivalent: String? = nil
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textPrimary)
                    if let perWeekEquivalent {
                        Text(perWeekEquivalent)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer(minLength: Space.sm)
                Text(price)
                    .font(Typo.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(Space.md)
            .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isSelected ? Palette.accent : Palette.divider,
                            lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(Typo.eyebrow)
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, 4)
                        .background(Palette.accent, in: Capsule())
                        .offset(x: -Space.md, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DayBadge
//
// Small editorial pill used for day-count labels in the activity calendar,
// streak indicators, and "Day 7 of 30" copy on the paywall. AccentSubtle bg
// keeps it quiet enough to drop into a card without competing.

struct DayBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Typo.eyebrow)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 4)
            .background(Palette.accentSubtle, in: Capsule())
    }
}

// MARK: - JeniFitWordmark
//
// The brand mark: lowercase Fraunces SemiBold flanking a thin Light-weight
// bullet ("jeni • fit"). Used on AuthBootstrapSplash and the onboarding
// splash screen. Single canonical size so the brand reads identically
// everywhere; if a future surface needs scale variants, parametrize then.
//
// The bullet uses Fraunces72pt-Light at a smaller size with thin spaces
// (U+2009) padding either side — SemiBold's bullet glyph reads chunky next
// to the lowercase letterforms, so we step it down for breathing room.

struct JeniFitWordmark: View {
    var color: Color = Palette.textPrimary

    var body: some View {
        let base = Typo.title
        let separator = Font(UIFont(name: "Fraunces72pt-Light", size: 26)
                             ?? .systemFont(ofSize: 26))

        return (Text("jeni").font(base)
                + Text("\u{2009}•\u{2009}").font(separator)
                + Text("fit").font(base))
            .foregroundStyle(color)
    }
}

// MARK: - EditorialPlaceholder
//
// Holds the slot where coach photography will eventually live. Until the
// shoot happens, we render a diagonal-stripe block with a small label tag
// in the corner so the placeholder reads "intentionally unfinished" rather
// than "broken layout". Stripes use accent over accentSubtle for a quiet
// pink-on-pink hash; the label uses the eyebrow token in inverse on a 60%
// black scrim so it stays legible regardless of stripe contrast.

struct EditorialPlaceholder: View {
    let label: String
    var cornerRadius: CGFloat = Radius.lg

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.accentSubtle

            Canvas { context, size in
                let spacing: CGFloat = 18
                let diag = sqrt(size.width * size.width + size.height * size.height)
                var x: CGFloat = -diag
                while x < size.width + diag {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: -diag))
                    path.addLine(to: CGPoint(x: x + diag, y: diag))
                    context.stroke(path,
                                   with: .color(Palette.accent.opacity(0.18)),
                                   lineWidth: 6)
                    x += spacing
                }
            }

            Text(label)
                .font(Typo.eyebrow)
                .foregroundStyle(Color.white)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6), in: Capsule())
                .padding(Space.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Previews
//
// Visual scratchpad for the design system primitives. Run in the Xcode
// canvas (Editor → Canvas) to inspect each component in isolation against
// the JeniFit palette. These previews are #if DEBUG-gated implicitly by
// the #Preview macro — they don't ship in release builds.

#Preview("CTA buttons") {
    VStack(spacing: Space.md) {
        Button("Get started") {}.buttonStyle(.ctaPrimary)
        Button("Subscribe") {}.buttonStyle(.ctaSecondary)
        Button("Skip for now") {}.buttonStyle(.ctaTertiary)
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("OnboardingOptionCard") {
    VStack(spacing: Space.md) {
        OnboardingOptionCard(
            icon: "figure.core.training",
            title: "Definition",
            subtitle: "Visible abs, sculpted lines",
            isSelected: true,
            action: {}
        )
        OnboardingOptionCard(
            icon: "flame.fill",
            title: "Strength",
            subtitle: "Build a stronger core",
            isSelected: false,
            action: {}
        )
        OnboardingOptionCard(
            icon: "heart.fill",
            title: "Just feel better",
            isSelected: false,
            action: {}
        )
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("PricingCard") {
    VStack(spacing: Space.md) {
        PricingCard(
            title: "Yearly",
            price: "$59.99",
            perWeekEquivalent: "$1.15 / week",
            badge: "SAVE 76%",
            isSelected: true,
            action: {}
        )
        PricingCard(
            title: "Weekly",
            price: "$4.99",
            perWeekEquivalent: nil,
            badge: nil,
            isSelected: false,
            action: {}
        )
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("DayBadge") {
    HStack(spacing: Space.sm) {
        DayBadge(label: "DAY 1")
        DayBadge(label: "DAY 7")
        DayBadge(label: "DAY 30")
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("ItalicAccentText") {
    VStack(spacing: Space.lg) {
        ItalicAccentText("Become her in 30 days.", italic: ["her"])
        ItalicAccentText(
            "Sculpt your strongest body, at home.",
            italic: ["strongest"]
        )
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("JeniFitWordmark") {
    VStack(spacing: Space.lg) {
        JeniFitWordmark()
        JeniFitWordmark(color: Palette.accent)
    }
    .padding(Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.bgPrimary)
}

#Preview("EditorialPlaceholder") {
    EditorialPlaceholder(label: "EDITORIAL · COACH PHOTO")
        .frame(width: 280, height: 380)
        .padding(Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bgPrimary)
}
