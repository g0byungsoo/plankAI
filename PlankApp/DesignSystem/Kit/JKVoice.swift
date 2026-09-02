import SwiftUI

// p66 — JKCoachLine deleted: zero shipping call sites (only the
// deleted v2-era JKGallery rendered it).

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
                // THE HEADER MUST ASSERT ITS OWN HEIGHT.
                //
                // E9 recorded "a long dish title truncates in
                // JKSheetChrome at XXXL" and left it as a narrow case.
                // It is not narrow and it is not about XXXL: it is the
                // primitive. Neither the eyebrow nor the title carried
                // `fixedSize(vertical:)`, so in this VStack — where
                // `content()` is a flexible ScrollView that absorbs
                // whatever is left — the header reported a compressible
                // ideal height and lost the competition. The result was
                // a dish name cut to "grilled chicken…" with two thirds
                // of the sheet standing empty below it, which is a
                // layout that HIDES CONTENT IN ORDER TO MAKE ROOM FOR
                // NOTHING.
                //
                // `fixedSize` says "give me my wrapped height and take
                // it out of the scroll region". A title that already
                // fits is unaffected — its ideal height does not change
                // — so this cannot destabilise the sheets that were
                // fine, which is why the fix belongs here rather than
                // in one call site. `lineLimit(4)` is the backstop for a
                // pathological name: four lines is every real dish at
                // AX5, and past that truncation is the correct answer
                // rather than a swallowed surface.
                VStack(alignment: .leading, spacing: 6) {
                    if let eyebrow {
                        Text(eyebrow)
                            .font(Typo.captionTracked)
                            .kerning(1.98)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ItalicAccentText(
                        title,
                        italic: italic,
                        baseFont: .custom("JeniHeroSerif-Regular", size: 26),
                        italicFont: .custom("JeniHeroSerif-Italic", size: 26),
                        alignment: .leading
                    )
                    .kerning(-0.4)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
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
        // Pass 57 — chrome no longer touches presentation config. It
        // used to hide the drag indicator for every sheet wearing it,
        // which left two `.large` sheets (JENI MOVE, the plate detail)
        // with no visible exit of any kind. The presenter (`jeniSheet`)
        // owns detents, background and the always-visible grabber now;
        // a header primitive has no business configuring the vessel.
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
