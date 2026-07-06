import SwiftUI

// MARK: - JKCoachLine
//
// Jeni's voice on a surface — the serif line with the italic punch
// and a breathing shadow, plus the quiet "ask jeni" affordance when
// a chat seed exists. This is the thread that makes the app feel
// authored: same register in briefs, snap notes, closes, and chat.

struct JKCoachLine: View {
    let text: String
    var italic: [String] = []
    /// The quiet affordance word ("ask jeni" on trend stories; "from
    /// jeni" when the tap opens the full note).
    var affordanceLabel: String = "ask jeni"
    var onOpenChat: (() -> Void)? = nil

    var body: some View {
        Button {
            guard let onOpenChat else { return }
            Haptics.soft()
            onOpenChat()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ItalicAccentText(
                    text,
                    italic: italic,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 22),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 22),
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(-4)
                .kerning(-0.2)
                .fixedSize(horizontal: false, vertical: true)
                .breathingShadow()

                if onOpenChat != nil {
                    HStack(spacing: 5) {
                        Text(affordanceLabel)
                            .font(Typo.captionTracked)
                            .kerning(1.4)
                            .textCase(.uppercase)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .disabled(onOpenChat == nil)
        .accessibilityLabel(text)
        .accessibilityHint(onOpenChat == nil ? "" : "opens a chat with jeni")
    }
}

// MARK: - JKReceiptRow
//
// The OV5 receipt grammar generalized: quiet cause (caption) →
// consequence (serif italic trailing). Used for day receipts, chat
// action summaries, migration beats.

struct JKReceiptRow: View {
    let lead: String
    let punch: String
    var punchItalic: [String] = []
    var showsRule: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if showsRule {
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(lead)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: 16)
                ItalicAccentText(
                    punch,
                    italic: punchItalic,
                    baseFont: .custom("DMSans-Medium", size: 15),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 17),
                    color: Palette.textPrimary,
                    alignment: .trailing
                )
            }
            .padding(.vertical, 14)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - JKSheetChrome
//
// Unified sheet dressing: cream, serif title with italic punch, a
// hairline under the title, content beneath. No grabber (drag still
// works; the grabber is iOS-chrome noise on an editorial page).

struct JKSheetChrome<Content: View>: View {
    let title: String
    var italic: [String] = []
    var eyebrow: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    if let eyebrow {
                        Text(eyebrow)
                            .font(Typo.captionTracked)
                            .kerning(1.98)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                    ItalicAccentText(
                        title,
                        italic: italic,
                        baseFont: .custom("JeniHeroSerif-Regular", size: 26),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 26),
                        alignment: .leading
                    )
                    .kerning(-0.4)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, 28)
                .padding(.bottom, Space.md)

                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(height: 0.33)
                    .padding(.horizontal, Space.lg)

                content()
            }
        }
        .presentationBackground(Palette.bgPrimary)
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - JKConfirmPills
//
// The paired-pill decision (OV5StatementYesNo grammar) for inline
// confirmations — chat action cards, destructive asks.

struct JKConfirmPills: View {
    var confirmLabel: String = "yes"
    var cancelLabel: String = "not now"
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            pill(cancelLabel, filled: false, action: onCancel)
            pill(confirmLabel, filled: true, action: onConfirm)
        }
    }

    private func pill(_ label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            Text(label)
                .font(.custom("DMSans-SemiBold", size: 14))
                .foregroundStyle(filled ? Palette.textInverse : Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    Capsule().fill(filled ? Palette.cocoaPrimary : Palette.bgElevated)
                )
                .overlay(
                    Capsule().strokeBorder(
                        filled ? Color.clear : Palette.cocoaPrimary.opacity(0.22),
                        lineWidth: 1.5
                    )
                )
        }
        .buttonStyle(JKPress())
    }
}
