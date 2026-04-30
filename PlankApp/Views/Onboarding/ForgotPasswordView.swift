import SwiftUI

// MARK: - ForgotPasswordView
//
// Sheet presented from the sign-in flow when the user taps "Forgot
// password?". Sends a Supabase reset email; the success message is
// intentionally vague (doesn't confirm whether the email is registered)
// to avoid leaking account existence.
//
// Phases:
//   .input     — email field + "Send reset link" + "Cancel".
//   .sending   — primary button text replaced with PulsingDots.
//   .confirmed — checkmark + "Check your email." + body + "Done".
//   .failed    — back to .input with inline error below the buttons.
//
// Optional initialEmail prefill so a user who already typed their email
// in the sign-in sheet doesn't have to retype it.

struct ForgotPasswordView: View {
    let initialEmail: String
    let onDismiss: () -> Void

    private enum Phase: Equatable {
        case input
        case sending
        case confirmed
        case failed(String)
    }

    @State private var email: String
    @State private var phase: Phase = .input
    @State private var validationError: String?
    @FocusState private var emailFocused: Bool

    init(initialEmail: String = "", onDismiss: @escaping () -> Void) {
        self.initialEmail = initialEmail
        self.onDismiss = onDismiss
        self._email = State(initialValue: initialEmail)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch phase {
            case .input, .sending, .failed:
                inputContent
            case .confirmed:
                confirmedContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.xl)
        .background(Palette.bgPrimary)
        .onAppear {
            // Defer focus so the sheet's slide-in animation finishes first;
            // focusing during the transition makes the keyboard cover the
            // headline.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if email.isEmpty { emailFocused = true }
            }
        }
    }

    // MARK: - Input phase

    private var inputContent: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Forgot password?")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Enter the email you used. We'll send a reset link.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            emailField

            VStack(spacing: 12) {
                sendButton
                cancelButton
            }

            if case let .failed(message) = phase {
                Text(message)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.stateBad)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EMAIL")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            ZStack(alignment: .leading) {
                if email.isEmpty {
                    Text("you@example.com")
                        .foregroundStyle(Palette.textSecondary)
                }
                TextField("", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($emailFocused)
                    .submitLabel(.send)
                    .onSubmit { submit() }
                    .onChange(of: email) { _, _ in
                        // Clear the inline format error as soon as the user
                        // edits — don't keep yelling while they're fixing it.
                        if validationError != nil { validationError = nil }
                    }
            }
            .font(Typo.body)
            .foregroundStyle(Palette.textPrimary)
            .padding(14)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(emailFocused ? Palette.textPrimary : Palette.divider, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: emailFocused)

            if let validationError {
                Text(validationError)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.stateBad)
                    .padding(.leading, 4)
            }
        }
    }

    private var sendButton: some View {
        Button {
            Haptics.light()
            submit()
        } label: {
            ZStack {
                Text("Send reset link")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.textInverse)
                    .opacity(phase == .sending ? 0 : 1)
                if phase == .sending {
                    PulsingDots(color: Palette.textInverse)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(CTAButtonStyle())
        .disabled(phase == .sending)
    }

    private var cancelButton: some View {
        Button {
            Haptics.light()
            onDismiss()
        } label: {
            Text("Cancel")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(Palette.divider, lineWidth: 1)
                )
        }
        .buttonStyle(CTAButtonStyle())
        .disabled(phase == .sending)
    }

    // MARK: - Confirmed phase

    private var confirmedContent: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.md) {
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(Palette.accent)
                    .padding(.top, Space.sm)

                Text("Check your email.")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("If an account exists with that email, you'll get a reset link in a few minutes.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer().frame(height: Space.sm)

            Button {
                Haptics.light()
                onDismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Palette.bgInverse)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            .buttonStyle(CTAButtonStyle())
        }
    }

    // MARK: - Submit

    private func submit() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard isValidEmail(trimmed) else {
            validationError = "That doesn't look like a valid email"
            return
        }
        validationError = nil

        Task {
            phase = .sending
            do {
                try await AuthService.shared.sendPasswordReset(email: trimmed)
                phase = .confirmed
            } catch {
                phase = .failed("Couldn't send reset link. Check your internet and try again.")
            }
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}
