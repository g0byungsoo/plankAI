#if DEBUG
import SwiftUI
import Auth  // MemberImportVisibility: User.id / .email are defined in Supabase's Auth submodule

/// Temporary scaffolding for testing Phase B (email/password upgrade) and
/// Phase C (Apple Sign-In) before the real onboarding/settings UI lands.
/// Delete this file when Phase D + E ship the production surfaces.
struct DebugAuthView: View {
    @State private var auth = AuthService.shared
    @State private var payment = PaymentService.shared

    @State private var email = ""
    @State private var password = ""

    @State private var status = ""
    @State private var working = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Debug · Auth")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                stateCard

                credentialFields

                actionButtons

                if !status.isEmpty {
                    Text(status)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.bgPrimary)
    }

    // MARK: - State header

    private var stateCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CURRENT STATE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            row("user_id", auth.currentUser?.id.uuidString ?? "—")
            row("isAnonymous", String(auth.isAnonymous))
            row("authMethod", auth.authMethod.rawValue)
            row("email", auth.currentUser?.email ?? "—")
        }
        .padding(14)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    // MARK: - Inputs

    private var credentialFields: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("CREDENTIALS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            TextField("email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .padding(12)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            SecureField("password", text: $password)
                .padding(12)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            actionButton("Sign up with email (upgrade anon)", color: Palette.accent) {
                try await auth.signUpWithEmail(email, password: password)
                return "signed up · user_id \(auth.currentUser?.id.uuidString ?? "?")"
            }

            actionButton("Sign in with email", color: Palette.bgInverse) {
                try await auth.signInWithEmail(email, password: password)
                return "signed in · user_id \(auth.currentUser?.id.uuidString ?? "?")"
            }

            actionButton("Sign in with Apple", color: Color.black) {
                try await auth.signInWithApple()
                return "apple sign-in · user_id \(auth.currentUser?.id.uuidString ?? "?")"
            }

            actionButton("Send password reset", color: Palette.stateGood) {
                try await auth.sendPasswordReset(email: email)
                return "reset email sent to \(email)"
            }

            // Paywall force-toggle — QA the paywall without revoking the
            // RC entitlement or signing out. Flipping this re-evaluates
            // PlankAIApp's fullScreenCover gate on the next render.
            Button {
                payment.debugForcePaywall.toggle()
                status = "debugForcePaywall = \(payment.debugForcePaywall) · hasProAccess = \(payment.hasProAccess) · effective = \(payment.effectiveHasProAccess)"
            } label: {
                Text(payment.debugForcePaywall ? "Force paywall: ON (tap to disable)" : "Force paywall: OFF (tap to enable)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(payment.debugForcePaywall ? Palette.accent : Palette.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func actionButton(
        _ title: String,
        color: Color,
        action: @escaping () async throws -> String
    ) -> some View {
        Button {
            Task { await run(action) }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(working)
        .opacity(working ? 0.5 : 1)
    }

    private func run(_ action: () async throws -> String) async {
        working = true
        status = "running…"
        defer { working = false }
        do {
            status = try await action()
        } catch {
            status = "error: \(error.localizedDescription)"
        }
    }
}
#endif
