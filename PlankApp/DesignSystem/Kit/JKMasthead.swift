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
                        .accessibilityLabel("day \(day), her days")
                        .accessibilityHint("opens the days sheet")
                    } else {
                        dayPill(day)
                    }
                    if let note {
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
                    JKQuietMark(
                        systemName: mark.systemName,
                        accessibilityLabel: mark.label,
                        action: mark.action
                    )
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
    let action: () -> Void
}
