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
            SignUpView(initialMode: mode == .signIn ? .signIn : .signUp) {
                showEmailSheet = false
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
                // Apple's odd-state failure mode (no identity token returned).
                // Friendly copy matches SignUpView so the auth flow reads
                // consistent regardless of which sheet surfaced the error.
                errorMessage = "Couldn't sign in with Apple. Try email instead?"
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
                    print("[SignInPrompt] Apple completion failed: \(error)")
                    errorMessage = "Couldn't sign in with Apple. Try email instead?"
                }
            }

        case .failure(let error):
            // Apple signals user-cancel via ASAuthorizationError.canceled —
            // stay on this screen quietly, no error UI.
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            print("[SignInPrompt] Apple authorization failed: \(error)")
            errorMessage = "Couldn't sign in with Apple. Try email instead?"
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
