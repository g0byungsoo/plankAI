import SwiftUI
import AuthenticationServices
import SafariServices

// MARK: - SignUpView
//
// Polished email/password auth screen presented from SignInPromptView's
// "Continue with Email" path. Same view backs both sign-up and sign-in
// flows via a `mode` toggle (the link at the bottom flips it inline,
// not a navigation push). Phase C polishes sign-up; Phase D refines
// sign-in copy/layout.
//
// Layout (top to bottom):
//   - Headline + subhead
//   - SignInWithAppleButton (Apple's required component, never replaced)
//   - "OR" divider with thin terracotta lines
//   - Email field — small-caps label, format-validated on blur
//   - Password field — small-caps label, show/hide toggle
//   - Password requirements checklist (sign-up only, animated)
//   - Primary button — terracotta, disabled until valid, PulsingDots loading
//   - Mode toggle link
//   - Legal text with linked Terms / Privacy (sign-up only)
//
// Form area shakes (4px, 3 cycles, 200ms) when the API returns an error,
// so the user gets a kinetic cue alongside the inline message.

struct SignUpView: View {
    let onSuccess: () -> Void

    enum Mode: Equatable { case signUp, signIn }

    @State private var mode: Mode
    @State private var email = ""
    @State private var emailFormatError: String?
    @State private var password = ""
    @State private var showPassword = false
    @State private var rawNonce = ""
    @State private var working = false
    @State private var errorMessage: String?
    @State private var shakeTrigger: CGFloat = 0
    @State private var legalDoc: LegalDoc?
    @FocusState private var focused: Field?
    @Environment(\.dismiss) private var dismiss

    init(initialMode: Mode = .signUp, onSuccess: @escaping () -> Void) {
        self._mode = State(initialValue: initialMode)
        self.onSuccess = onSuccess
    }

    private enum Field: Hashable { case email, password }

    private enum LegalDoc: String, Identifiable {
        case terms, privacy
        var id: String { rawValue }
        var url: URL {
            switch self {
            case .terms: return URL(string: "https://jenifit.app/terms")!
            case .privacy: return URL(string: "https://jenifit.app/privacy")!
            }
        }
    }

    // MARK: Validation

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces) }
    private var emailValid: Bool { isValidEmail(trimmedEmail) }
    private var hasMinLength: Bool { password.count >= 8 }
    private var hasLowercase: Bool { password.contains(where: { $0.isLowercase }) }
    private var hasUppercase: Bool { password.contains(where: { $0.isUppercase }) }
    private var hasDigit: Bool { password.contains(where: { $0.isNumber }) }
    private var passwordValid: Bool { hasMinLength && hasLowercase && hasUppercase && hasDigit }

    private var canSubmit: Bool {
        guard !working, emailValid else { return false }
        return mode == .signUp ? passwordValid : !password.isEmpty
    }

    // MARK: Copy

    private var headline: String {
        mode == .signUp ? "Create your account." : "Welcome back."
    }
    private var subhead: String {
        mode == .signUp
            ? "Save your progress on every device."
            : "Sign in to keep your routine going."
    }
    private var primaryLabel: String {
        if working { return mode == .signUp ? "Creating account…" : "Signing in…" }
        return mode == .signUp ? "Create account" : "Sign in"
    }
    private var toggleLabel: String {
        mode == .signUp ? "Already have an account? Sign in" : "New here? Create account"
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    headerSection
                    appleButton
                    orDivider
                    emailField
                    passwordField
                    if mode == .signUp {
                        passwordRequirements
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if mode == .signIn {
                        forgotPasswordLink
                            .transition(.opacity)
                    }
                    primaryButton
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.stateBad)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    modeToggle
                    if mode == .signUp {
                        legalText
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.md)
                .padding(.bottom, Space.xl)
                .modifier(ShakeEffect(animatableData: shakeTrigger))
            }
            .scrollDismissesKeyboard(.interactively)
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
        .sheet(item: $legalDoc) { doc in
            SafariView(url: doc.url).ignoresSafeArea()
        }
        .sheet(isPresented: Binding(
            get: { showForgotPassword },
            set: { if !$0 { showForgotPassword = false } }
        )) {
            ForgotPasswordView(initialEmail: trimmedEmail) {
                showForgotPassword = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @State private var showForgotPassword = false

    // MARK: Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headline)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subhead)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(
            mode == .signUp ? .signUp : .signIn,
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
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .disabled(working)
        .opacity(working ? 0.6 : 1)
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Palette.accent.opacity(0.3))
                .frame(height: 1)
            Text("OR")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)
            Rectangle()
                .fill(Palette.accent.opacity(0.3))
                .frame(height: 1)
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
                    .focused($focused, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }
                    .onChange(of: email) { _, _ in
                        // Clear the format error as the user re-edits — quiet
                        // correction beats persistent red text.
                        if emailFormatError != nil { emailFormatError = nil }
                    }
            }
            .font(Typo.body)
            .foregroundStyle(Palette.textPrimary)
            .padding(14)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(focused == .email ? Palette.textPrimary : Palette.divider, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: focused)

            if let emailFormatError {
                Text(emailFormatError)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.stateBad)
                    .padding(.leading, 4)
            }
        }
        .onChange(of: focused) { oldValue, newValue in
            // Validate on blur from email — only when there's something to
            // check (don't yell at an empty field the user touched and left).
            if oldValue == .email && newValue != .email {
                if !trimmedEmail.isEmpty && !emailValid {
                    emailFormatError = "That doesn't look like a valid email"
                }
            }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PASSWORD")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    if password.isEmpty {
                        Text(mode == .signUp ? "8+ characters" : "Your password")
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Group {
                        if showPassword {
                            TextField("", text: $password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("", text: $password)
                        }
                    }
                    .focused($focused, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { submit() }
                }

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .font(Typo.body)
            .foregroundStyle(Palette.textPrimary)
            .padding(14)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(focused == .password ? Palette.textPrimary : Palette.divider, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: focused)
        }
    }

    private var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 6) {
            requirementRow("8+ characters", satisfied: hasMinLength)
            requirementRow("Mixed case", satisfied: hasLowercase && hasUppercase)
            requirementRow("Contains a digit", satisfied: hasDigit)
        }
        .padding(.leading, 4)
    }

    private func requirementRow(_ label: String, satisfied: Bool) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(satisfied ? Palette.accent : Palette.textSecondary.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                if satisfied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .transition(.opacity)
                }
            }
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(satisfied ? Palette.accent : Palette.textSecondary)
        }
        .animation(.easeOut(duration: 0.2), value: satisfied)
    }

    private var forgotPasswordLink: some View {
        Button {
            Haptics.light()
            showForgotPassword = true
        } label: {
            Text("Forgot password?")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var primaryButton: some View {
        let disabled = !canSubmit
        return Button {
            Haptics.light()
            submit()
        } label: {
            ZStack {
                Text(primaryLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.textInverse)
                    .opacity(working ? 0 : 1)
                if working {
                    PulsingDots(color: Palette.textInverse)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(disabled ? Palette.accent.opacity(0.4) : Palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .animation(.easeOut(duration: 0.15), value: disabled)
        }
        .buttonStyle(PressFeedbackStyle())
        .disabled(disabled)
    }

    private var modeToggle: some View {
        Button {
            Haptics.light()
            withAnimation(.easeOut(duration: 0.2)) {
                mode = (mode == .signUp ? .signIn : .signUp)
            }
            errorMessage = nil
            emailFormatError = nil
        } label: {
            Text(toggleLabel)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
    }

    private var legalText: some View {
        // Markdown links produce a tappable URL inside Text; the openURL
        // handler intercepts and routes to SFSafariViewController so the
        // user stays in-app rather than losing context to Safari.
        let markdown = "By creating an account you agree to our [Terms](https://jenifit.app/terms) and [Privacy Policy](https://jenifit.app/privacy)."
        let attributed = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
        return Text(attributed)
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .tint(Palette.accent)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .environment(\.openURL, OpenURLAction { url in
                if url.path.contains("terms") {
                    legalDoc = .terms
                } else if url.path.contains("privacy") {
                    legalDoc = .privacy
                }
                return .handled
            })
    }

    // MARK: Apple completion

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple did not return an identity token."
                triggerShake()
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
                    dismiss()
                    onSuccess()
                } catch {
                    errorMessage = "Couldn't sign in with Apple. Try email instead?"
                    triggerShake()
                }
            }

        case .failure(let error):
            // Apple signals user-cancel via ASAuthorizationError.canceled —
            // stay on this screen quietly, no error UI.
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            errorMessage = "Couldn't sign in with Apple. Try email instead?"
            triggerShake()
        }
    }

    // MARK: Submit

    private func submit() {
        // Re-validate email on submit in case the user never blurred the field.
        if !trimmedEmail.isEmpty && !emailValid {
            emailFormatError = "That doesn't look like a valid email"
            triggerShake()
            return
        }
        guard canSubmit else { return }

        Task {
            working = true
            errorMessage = nil
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
                errorMessage = friendlyError(from: error, mode: mode)
                triggerShake()
            }
        }
    }

    /// Translate Supabase's error strings into the Phase E error copy. Falls
    /// back to a generic message — no raw error text in the UI.
    private func friendlyError(from error: Error, mode: Mode) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("already registered") || raw.contains("already in use") {
            return "Looks like you have an account. Try signing in instead."
        }
        if raw.contains("invalid login") || raw.contains("invalid credentials") {
            return "That email and password don't match. Try again or reset your password."
        }
        if raw.contains("network") || raw.contains("connection") || raw.contains("offline") {
            return "Couldn't connect. Check your internet and try again."
        }
        if raw.contains("password") && raw.contains("weak") {
            return "Add an uppercase letter and a number."
        }
        return mode == .signUp
            ? "Couldn't create account. Try again in a moment."
            : "Couldn't sign in. Try again in a moment."
    }

    private func triggerShake() {
        Haptics.soft()
        withAnimation(.linear(duration: 0.2)) {
            shakeTrigger += 1
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - ShakeEffect
//
// 4px horizontal oscillation, 3 cycles, 200ms total. animatableData is a
// monotonically-increasing CGFloat; SwiftUI interpolates from old → new
// over the animation duration and we map that to a sine wave.

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat = 0
    var amount: CGFloat = 4
    var shakesPerUnit: CGFloat = 3

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amount * sin(animatableData * .pi * shakesPerUnit * 2)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

// MARK: - SafariView
//
// SwiftUI wrapper around SFSafariViewController so Terms / Privacy links
// open in-app instead of bouncing the user out to Safari.

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
