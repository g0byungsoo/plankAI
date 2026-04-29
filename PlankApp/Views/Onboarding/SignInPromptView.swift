import SwiftUI
import AuthenticationServices

// MARK: - SignInPromptView
//
// Soft sign-in prompt shown between plan reveal and the rest of onboarding.
// Three paths, all advance the flow via `onContinue()`:
//   1. Sign in with Apple (Apple's HIG-required button component)
//   2. Continue with Email (presents an email sign-up sheet)
//   3. Maybe later (skip — user stays anonymous)
//
// The user can sign in later from Settings (Phase E). Anonymous sessions
// are first-class — local progress and SessionLog writes work the same way
// whether or not the user has linked an Apple/email identity.

struct SignInPromptView: View {
    let onContinue: () -> Void

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

            Text("Save your progress.")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Space.sm)

            Text("Sign in to keep your routine\nwhen you switch phones.")
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
                    Text("Maybe later")
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
            EmailSignUpSheet { onContinue() }
        }
    }

    // MARK: - Apple

    private var appleButton: some View {
        SignInWithAppleButton(
            .signUp,
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
// Sign-up only for Phase D. Returning users on a new device sign in via
// Settings (Phase E) once they realize they already have an account. If
// the email is already registered, Supabase returns an error and the user
// can dismiss + try Apple or Maybe Later.

private struct EmailSignUpSheet: View {
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var working = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
            password.count >= 6 &&
            !working
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Create your account")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Text("Save your routine to a Supabase account so it follows you to a new phone.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: Space.sm) {
                        field("Email") {
                            TextField("you@example.com", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                        }
                        field("Password (min 6 characters)") {
                            SecureField("••••••••", text: $password)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.stateBad)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Text(working ? "Creating account…" : "Create Account")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(canSubmit ? Palette.bgInverse : Palette.bgInverse.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(!canSubmit)
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

    private func submit() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        working = true
        errorMessage = nil
        defer { working = false }
        do {
            try await AuthService.shared.signUpWithEmail(trimmedEmail, password: password)
            Haptics.success()
            dismiss()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
