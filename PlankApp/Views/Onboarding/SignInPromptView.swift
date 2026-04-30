import SwiftUI
import AuthenticationServices

// MARK: - SignInPromptView
//
// Soft sign-in prompt with two modes:
//   .signUp — default. Mid-onboarding nudge: "Save your progress."
//             Apple button reads "Sign up with Apple"; email sheet defaults
//             to the create-account form.
//   .signIn — opened from the welcome screen "Already have an account?"
//             link. Apple button reads "Continue with Apple"; email sheet
//             defaults to the sign-in form.
//
// All three paths (Apple, Email, Maybe later) advance the flow via
// `onContinue()`. The user can also sign in later from Settings (Phase E).
// Anonymous sessions are first-class — local progress and SessionLog writes
// work the same way whether or not the user has linked an Apple/email
// identity.

enum SignInPromptMode {
    case signUp
    case signIn
}

struct SignInPromptView: View {
    let onContinue: () -> Void
    var mode: SignInPromptMode = .signUp

    @State private var rawNonce: String = ""
    @State private var showEmailSheet = false
    @State private var working = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Brand-shape icon — same lockup vibe as the splash dot trio
            ZStack {
                Circle()
                    .fill(Palette.accent.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Palette.accent)
            }

            Spacer().frame(height: Space.lg)

            Text(mode == .signIn ? "Welcome back." : "Save your progress.")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Space.sm)

            Text(mode == .signIn
                 ? "Sign in to recover your routine\non this device."
                 : "Sign in to keep your routine\nwhen you switch phones.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                appleButton
                emailButton

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.stateBad)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.md)
                }

                Button(action: { Haptics.light(); onContinue() }) {
                    Text(mode == .signIn ? "Cancel" : "Maybe later")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 8)
                }
                .padding(.top, Space.xs)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailSignUpSheet(initialMode: mode == .signIn ? .signIn : .signUp) {
                onContinue()
            }
        }
    }

    // MARK: - Apple

    private var appleButton: some View {
        SignInWithAppleButton(
            mode == .signIn ? .continue : .signUp,
            onRequest: { request in
                let nonce = AppleSignInService.randomNonce()
                rawNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleSignInService.sha256(nonce)
            },
            onCompletion: handleAppleCompletion
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .disabled(working)
        .opacity(working ? 0.6 : 1)
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple did not return an identity token."
                return
            }
            Task {
                working = true
                defer { working = false }
                do {
                    try await AuthService.shared.completeAppleSignIn(
                        idToken: token,
                        rawNonce: rawNonce,
                        fullName: credential.fullName
                    )
                    Haptics.success()
                    onContinue()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }

        case .failure(let error):
            // Apple signals user-cancel via ASAuthorizationError.canceled —
            // stay on this screen quietly, no error UI.
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Email

    private var emailButton: some View {
        Button {
            Haptics.light()
            errorMessage = nil
            showEmailSheet = true
        } label: {
            Text("Continue with Email")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.divider, lineWidth: 1)
                )
        }
        .buttonStyle(CTAButtonStyle())
        .disabled(working)
    }
}

// MARK: - EmailSignUpSheet
//
// Two modes — sign-up (default, for new accounts) and sign-in (for
// returning users on a new device). A toggle at the bottom switches
// between them. In sign-in mode, a "Forgot Password?" link triggers
// sendPasswordReset.

private enum EmailMode {
    case signUp, signIn
}

private struct EmailSignUpSheet: View {
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var mode: EmailMode
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var working = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    init(initialMode: EmailMode = .signUp, onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
        self._mode = State(initialValue: initialMode)
    }

    private var passwordsMatch: Bool {
        password == confirmPassword
    }

    /// Show the mismatch warning only after the user has typed something
    /// in both fields — no scary red text while they're still typing.
    private var showPasswordMismatch: Bool {
        mode == .signUp && !confirmPassword.isEmpty && !passwordsMatch
    }

    // Supabase rejects weak passwords. These mirror the project's enforced
    // rules: at least 6 characters AND at least one of each character class.
    private var hasMinLength: Bool { password.count >= 6 }
    private var hasLowercase: Bool { password.contains(where: { $0.isLowercase }) }
    private var hasUppercase: Bool { password.contains(where: { $0.isUppercase }) }
    private var hasDigit: Bool { password.contains(where: { $0.isNumber }) }
    private var passwordMeetsRules: Bool {
        hasMinLength && hasLowercase && hasUppercase && hasDigit
    }

    private var canSubmit: Bool {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !working else { return false }
        if mode == .signUp {
            // Sign-up: enforce all password rules + matching confirm field
            guard passwordMeetsRules else { return false }
            return passwordsMatch && !confirmPassword.isEmpty
        }
        // Sign-in: existing accounts may predate rule changes, just need non-empty
        return !password.isEmpty
    }

    private var canResetPassword: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !working
    }

    private var headline: String {
        mode == .signUp ? "Create your account" : "Welcome back"
    }

    private var subhead: String {
        mode == .signUp
            ? "Save your routine so it follows you to a new phone."
            : "Sign in with the email you used before."
    }

    private var actionLabel: String {
        if working {
            return mode == .signUp ? "Creating account…" : "Signing in…"
        }
        return mode == .signUp ? "Create Account" : "Sign In"
    }

    private var toggleLabel: String {
        mode == .signUp ? "Already have an account? Sign in" : "New here? Create an account"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(headline)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(subhead)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: Space.sm) {
                        field("Email") {
                            // Manual ZStack placeholder. The `prompt:` parameter
                            // approach picked up the environment tint in iOS
                            // and rendered blue despite explicit foregroundStyle.
                            ZStack(alignment: .leading) {
                                if email.isEmpty {
                                    Text("you@example.com")
                                        .foregroundStyle(Palette.textSecondary)
                                }
                                TextField("", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                            }
                        }
                        field("Password") {
                            ZStack(alignment: .leading) {
                                if password.isEmpty {
                                    Text("••••••••")
                                        .foregroundStyle(Palette.textSecondary)
                                }
                                SecureField("", text: $password)
                            }
                        }

                        if mode == .signUp {
                            passwordRulesBlock

                            field("Confirm password") {
                                ZStack(alignment: .leading) {
                                    if confirmPassword.isEmpty {
                                        Text("re-enter password")
                                            .foregroundStyle(Palette.textSecondary)
                                    }
                                    SecureField("", text: $confirmPassword)
                                }
                            }

                            if showPasswordMismatch {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.stateBad)
                                    Text("Passwords don't match")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.stateBad)
                                }
                                .padding(.leading, 4)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.stateBad)
                    }

                    if let infoMessage {
                        Text(infoMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.stateGood)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Text(actionLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(canSubmit ? Palette.bgInverse : Palette.bgInverse.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(!canSubmit)

                    if mode == .signIn {
                        Button {
                            Task { await sendReset() }
                        } label: {
                            Text("Forgot password?")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.accent)
                        }
                        .disabled(!canResetPassword)
                        .opacity(canResetPassword ? 1 : 0.5)
                    }

                    Button {
                        Haptics.light()
                        withAnimation { mode = (mode == .signUp ? .signIn : .signUp) }
                        errorMessage = nil
                        infoMessage = nil
                        confirmPassword = ""
                    } label: {
                        Text(toggleLabel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, Space.xs)
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.top, Space.md)
            }
            .background(Palette.bgPrimary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Palette.bgElevated)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)
            content()
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .padding(14)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    /// Live password requirements with checkmarks. Each rule mirrors what
    /// Supabase enforces server-side, so the user knows exactly what they
    /// need before submitting.
    private var passwordRulesBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password requirements")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)
                .padding(.top, 2)

            ruleRow("At least 6 characters", satisfied: hasMinLength)
            ruleRow("One lowercase letter", satisfied: hasLowercase)
            ruleRow("One uppercase letter", satisfied: hasUppercase)
            ruleRow("One digit", satisfied: hasDigit)

            Text("Passwords missing any of these will be rejected as weak.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 4)
                .padding(.leading, 4)
        }
        .padding(.leading, 4)
    }

    private func ruleRow(_ text: String, satisfied: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: satisfied ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(satisfied ? Palette.stateGood : Palette.textSecondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(satisfied ? Palette.stateGood : Palette.textSecondary)
        }
    }

    private func submit() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        working = true
        errorMessage = nil
        infoMessage = nil
        defer { working = false }
        do {
            switch mode {
            case .signUp:
                try await AuthService.shared.signUpWithEmail(trimmedEmail, password: password)
            case .signIn:
                try await AuthService.shared.signInWithEmail(trimmedEmail, password: password)
            }
            Haptics.success()
            dismiss()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendReset() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        working = true
        errorMessage = nil
        infoMessage = nil
        defer { working = false }
        do {
            try await AuthService.shared.sendPasswordReset(email: trimmedEmail)
            infoMessage = "Reset link sent to \(trimmedEmail). Check your inbox."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
