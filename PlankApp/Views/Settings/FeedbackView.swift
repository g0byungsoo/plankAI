import SwiftUI

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var submitted = false
    @FocusState private var focused: Bool

    private static let supportEmail = "support@jenifit.app"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                header

                Text("what's working? what's broken? what do you wish existed? we read everything.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if submitted {
                    VStack(spacing: Space.md) {
                        Image(StickerName.fluffyHeart.assetName)
                            .resizable().scaledToFit()
                            .frame(width: 52, height: 52)
                            .opacity(StickerName.fluffyHeart.style.opacity)
                        Text("got it ♥")
                            .font(Typo.titleItalic)
                            .foregroundStyle(Palette.textPrimary)
                        Text("jeni reads every one.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.xl)
                    .padding(Space.md)
                    .scrapbookCard(tint: Palette.stateGood)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    TextEditor(text: $feedbackText)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .focused($focused)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .padding(Space.md)
                        .editorialCard()

                    sendButton

                    // Quiet fallback for anyone who'd rather email.
                    Text("or email \(Self.supportEmail)")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Space.xs)
                }

                Spacer().frame(height: Space.xl)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.programEraBg)
        .onAppear { focused = true }
    }

    private var header: some View {
        // her75 Phase 6 — JFPageHero (audit §7). Breadcrumb eyebrow
        // dropped (her75 sub-pages show none); title promoted from
        // titleItalic 32pt to the ONE page-hero register.
        JFPageHero(title: "send feedback.", italic: ["send"], alignment: .leading)
            .padding(.horizontal, -Space.screenPadding)  // parent already pads
    }

    private var sendButton: some View {
        let isEmpty = feedbackText.trimmingCharacters(in: .whitespaces).isEmpty
        return Button {
            Haptics.medium()
            focused = false
            submit()
        } label: {
            HStack {
                Text("send")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isEmpty ? Palette.divider : Palette.accent)
            }
            .foregroundStyle(Palette.textInverse)
            .padding(.horizontal, Space.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Palette.accent.opacity(isEmpty ? 0.06 : 0.18))
                        .offset(x: 4, y: 4)
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(isEmpty ? Palette.divider : Palette.bgInverse)
                }
            )
        }
        .disabled(isEmpty)
    }

    /// Capture feedback in-app via the existing PostHog pipeline — no Mail
    /// dependency (the old mailto handoff produced zero submissions: most
    /// users have no Mail app configured, and "success" only meant Mail
    /// opened, not sent). Every message now lands + is measurable in PostHog.
    private func submit() {
        let text = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Analytics.track(.feedbackSubmitted, properties: [
            "message": text,
            "source": "settings"
        ])
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            submitted = true
        }
    }

    // v8 P8.10: local scrapbookChrome removed — unified to
    // `View.scrapbookCard(tint:)` in DesignSystem/Tokens.swift.
}
