import SwiftUI

// MARK: - Settings chrome (v1.1 clean-luxury pass)
//
// The settings tree drops the scrapbook card chrome for the program
// era's editorial vocabulary: hairline-ruled rows on cream, thin SF
// marks, serif emphasis on the selected state. One shared kit so all
// sub-screens read as one drawer.

// MARK: Section

/// Uppercase eyebrow + hairline-ruled row group. No card, no border —
/// the rule lines ARE the structure.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Typo.editorialEyebrow)
                .textCase(.uppercase)
                .kerning(1.8)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.bottom, 10)
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(height: 0.5)
            content
        }
    }
}

// MARK: Nav row

/// Hairline list row: thin mark, title, optional trailing value, a
/// quiet chevron. Press fades in a blush tint instead of scaling a
/// card around — the page stays still, the touch glows.
struct SettingsNavRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 24, alignment: .center)
                Text(title)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 12)
                if let value {
                    Text(value)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsGlowPressStyle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
    }
}

// MARK: Select row

/// Single-choice row. Selection = the label slips into italic serif
/// and a small accent dot springs in at the trailing edge. No filled
/// pills, no checkmark boxes.
struct SettingsSelectRow: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !selected else { return }
            Haptics.soft()
            action()
        } label: {
            HStack {
                Text(label)
                    .font(selected
                          ? .custom("Fraunces72pt-SemiBoldItalic", size: 17)
                          : Typo.body)
                    .foregroundStyle(selected ? Palette.textPrimary : Palette.cocoaSecondary)
                Spacer()
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 7, height: 7)
                    .scaleEffect(selected ? 1 : 0.01)
                    .opacity(selected ? 1 : 0)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsGlowPressStyle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
        .animation(Motion.gentleSpring, value: selected)
    }
}

// MARK: Toggle row

/// Hairline row hosting a native toggle, tinted to the brand accent.
struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Palette.accent)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
    }
}

// MARK: Press style

/// Shared press feedback: a blush wash + barely-there settle. The
/// row glows under the finger instead of jumping.
struct SettingsGlowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Rectangle()
                    .fill(Palette.accentSubtle.opacity(configuration.isPressed ? 0.35 : 0))
                    .padding(.horizontal, -Space.screenPadding)
            )
            .scaleEffect(configuration.isPressed ? 0.995 : 1.0)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

// MARK: Iridescent sheen

/// Slow mother-of-pearl drift over whatever it's applied to — the one
/// jewel in the settings drawer (identity monogram ring). A pastel
/// triad rotates softly, masked to the content's own shape. Pure
/// SwiftUI (no Metal toolchain dependency in the archive pipeline);
/// reduce-motion renders the content still.
struct IridescentSheen: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pearl = [
        Color(red: 0.96, green: 0.80, blue: 0.85),   // blush
        Color(red: 0.81, green: 0.87, blue: 0.96),   // baby blue
        Color(red: 0.94, green: 0.90, blue: 0.80),   // champagne
        Color(red: 0.96, green: 0.80, blue: 0.85),   // close the loop
    ]

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let angle = Angle.degrees((t * 14).truncatingRemainder(dividingBy: 360))
                content
                    .overlay(
                        AngularGradient(colors: Self.pearl, center: .center)
                            .rotationEffect(angle)
                            .opacity(0.5)
                            .blendMode(.softLight)
                            .mask(content)
                            .allowsHitTesting(false)
                    )
            }
        }
    }
}

extension View {
    func iridescentSheen() -> some View { modifier(IridescentSheen()) }
}
