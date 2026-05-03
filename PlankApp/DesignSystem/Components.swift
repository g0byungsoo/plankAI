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
