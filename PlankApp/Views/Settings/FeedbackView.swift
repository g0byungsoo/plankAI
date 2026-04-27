import SwiftUI

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var submitted = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Feedback")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                Text("What's working? What's broken? What do you wish existed? We read everything.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)

                if submitted {
                    VStack(spacing: Space.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Palette.stateGood)
                        Text("Sent. Thank you.")
                            .font(Typo.heading)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.xl)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    TextEditor(text: $feedbackText)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .focused($focused)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(14)
                        .background(Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .plankShadow()

                    Button {
                        Haptics.medium()
                        // TODO: send feedback to backend
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            submitted = true
                        }
                        focused = false
                    } label: {
                        Text("SEND")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty ? Palette.divider : Palette.bgInverse)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.bgPrimary)
        .onAppear { focused = true }
    }
}
