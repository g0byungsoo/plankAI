import SwiftUI

// MARK: - JKMasthead
//
// The page masthead — replaces navigation bars app-wide. Leading:
// the day pill (Fraunces italic in a white capsule, straight from
// the welcome device demo) or a serif title. Beneath: the tracked
// date eyebrow. Trailing: at most two quiet marks. The masthead is
// chrome — it rides jkBeat1 and never re-animates on content swaps.

struct JKMasthead: View {
    enum Lead {
        /// "day 12" italic pill + optional cohort word after it.
        case dayPill(day: Int, note: String?)
        /// Serif page title ("becoming", "jeni").
        case title(String, italic: [String])
    }

    let lead: Lead
    var eyebrow: String? = nil          // "thursday, july 3"
    var marks: [JKMastheadMark] = []
    /// v3 minimal correction: the day pill becomes the door to HER
    /// DAYS (the strip left Home). nil = pill renders inert.
    var onLeadTap: (() -> Void)? = nil

    /// At accessibility sizes the chapter note yields entirely (a
    /// designed absence beats an ellipsis — the pill + date carry
    /// the day; the clipping contract allows no "…").
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                switch lead {
                case let .dayPill(day, note):
                    if let onLeadTap {
                        Button {
                            Haptics.light()
                            onLeadTap()
                        } label: {
                            dayPill(day)
                        }
                        .buttonStyle(JKPress())
                        .accessibilityLabel("day \(day), the journey")
                        .accessibilityHint("opens the days sheet")
                    } else {
                        dayPill(day)
                    }
                    if let note, !typeSize.isAccessibilitySize {
                        Text(note)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                case let .title(text, italic):
                    ItalicAccentText(
                        text,
                        italic: italic,
                        baseFont: .custom("JeniHeroSerif-Regular", size: 28),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 28),
                        alignment: .leading
                    )
                    .kerning(-0.4)
                }

                Spacer(minLength: 0)

                ForEach(marks) { mark in
                    if mark.prominent {
                        JKProminentMark(
                            systemName: mark.systemName,
                            label: mark.label,
                            action: mark.action
                        )
                    } else {
                        JKQuietMark(
                            systemName: mark.systemName,
                            accessibilityLabel: mark.label,
                            action: mark.action
                        )
                    }
                }
            }

            if let eyebrow {
                Text(eyebrow)
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .padding(.horizontal, Space.lg)
    }

    private func dayPill(_ day: Int) -> some View {
        Text("day \(day)")
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 17))
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white, in: Capsule())
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            .accessibilityLabel("day \(day) of your plan")
    }
}

struct JKMastheadMark: Identifiable {
    let id = UUID()
    let systemName: String
    let label: String
    /// v5: the app's hero action (snap) wears a filled pill instead
    /// of a quiet mark — one per masthead, never more.
    var prominent: Bool = false
    let action: () -> Void
}

/// The filled masthead pill for the one hero action.
struct JKProminentMark: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.textInverse)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.cocoaPrimary))
                .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
                // v7 a11y floor: the hero action meets the 44pt
                // target without growing the visible circle.
                .tappableArea()
        }
        .buttonStyle(JKPress())
        .accessibilityLabel(label)
    }
}
