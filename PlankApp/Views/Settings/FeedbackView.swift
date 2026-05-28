import SwiftUI
import UIKit

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var submitted = false
    @State private var mailUnavailable = false
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
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Palette.stateGood)
                        Text("opened in mail.")
                            .font(Typo.titleItalic)
                            .foregroundStyle(Palette.textPrimary)
                        Text("tap send in mail to finish. we read every one.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.xl)
                    .padding(Space.md)
                    .background(scrapbookChrome(tint: Palette.stateGood))
                    .transition(.scale.combined(with: .opacity))
                } else {
                    TextEditor(text: $feedbackText)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .focused($focused)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .padding(Space.md)
                        .background(scrapbookChrome())

                    sendButton

                    if mailUnavailable {
                        Text("no mail app set up. email \(Self.supportEmail) directly.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.stateWarn)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }
                }

                Spacer().frame(height: Space.xl)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.bgPrimary)
        .onAppear { focused = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("settings")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)
            Text("send feedback.")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Sparkle — small handwritten-ish accent.
        .overlay(alignment: .topTrailing) {
            Image(StickerName.starLineart.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(15))
                .offset(x: 4, y: -6)
                .opacity(StickerName.starLineart.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var sendButton: some View {
        let isEmpty = feedbackText.trimmingCharacters(in: .whitespaces).isEmpty
        return Button {
            Haptics.medium()
            focused = false
            handoffToMail(body: feedbackText)
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

    private func handoffToMail(body: String) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "JeniFit feedback"),
            URLQueryItem(name: "body", value: body)
        ]
        guard let url = components.url else { return }
        UIApplication.shared.open(url) { success in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if success {
                    mailUnavailable = false
                    submitted = true
                } else {
                    mailUnavailable = true
                }
            }
        }
    }

    private func scrapbookChrome(tint: Color = Palette.accent) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint.opacity(0.15))
                .offset(x: 4, y: 4)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.bgElevated)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint, lineWidth: 1.5)
        }
    }
}
