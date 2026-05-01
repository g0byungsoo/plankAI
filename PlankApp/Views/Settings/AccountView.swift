import SwiftUI
import Auth  // MemberImportVisibility: User.id / .email live in Supabase's Auth submodule

struct AccountView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss

    @State private var auth = AuthService.shared
    @State private var showResetConfirm = false
    @State private var showSignInSheet = false
    @State private var showSignOutConfirm = false
    @State private var signingOut = false
    @State private var showDeleteAccountSheet = false
    @State private var restoring = false
    @State private var restoreFeedback: RestoreFeedback?

    private enum RestoreFeedback: Equatable {
        case success
        case nothingToRestore
        case error(String)

        var message: String {
            switch self {
            case .success: return "Subscriptions restored"
            case .nothingToRestore: return "No active subscription found. If you think this is wrong, contact support."
            case .error(let msg): return msg
            }
        }

        var color: Color {
            switch self {
            case .success: return Palette.stateGood
            case .nothingToRestore, .error: return Palette.textSecondary
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("Account")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)

                // App info
                VStack(spacing: 0) {
                    infoRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Divider().padding(.leading, 14)
                    infoRow(label: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .plankShadow()

                // Account state — adapts to anonymous vs signed-in
                if auth.isAnonymous || !auth.isAuthenticated {
                    anonymousSection
                } else {
                    signedInSection
                }

                Spacer().frame(height: Space.xl)

                // Reset
                Button {
                    showResetConfirm = true
                } label: {
                    Text("Reset Onboarding")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.stateBad)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.stateBad.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .alert("Reset onboarding?", isPresented: $showResetConfirm) {
                    Button("Reset", role: .destructive) {
                        hasCompletedOnboarding = false
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will take you back to the intro screens. Your workout data stays.")
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.bgPrimary)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(14)
    }

    // MARK: - Anonymous

    private var anonymousSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("SAVE YOUR PROGRESS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Palette.accent.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundStyle(Palette.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not signed in")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text("Sign in to back up your routine")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                }

                Button {
                    Haptics.light()
                    showSignInSheet = true
                } label: {
                    Text("Sign In")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Palette.bgInverse)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                restorePurchasesButton
            }
            .padding(14)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .plankShadow()
        }
        .sheet(isPresented: $showSignInSheet) {
            NavigationStack {
                SignInPromptView { showSignInSheet = false }
                    .background(Palette.bgPrimary)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showSignInSheet = false
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
    }

    // MARK: - Signed in

    private var signedInSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("ACCOUNT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
                .tracking(2)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Palette.stateGood.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: providerIcon)
                            .font(.system(size: 16))
                            .foregroundStyle(Palette.stateGood)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(providerLabel)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                }

                Button {
                    Haptics.light()
                    showSignOutConfirm = true
                } label: {
                    Text(signingOut ? "Signing out…" : "Sign Out")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.stateBad)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Palette.stateBad.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(signingOut)

                restorePurchasesButton
            }
            .padding(14)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .plankShadow()

            // Delete Account — Apple App Store Review Guideline 5.1.1(v)
            // requires every account-creating app to expose this in-app.
            // Only shown when signed in; anonymous users have no cloud row
            // to delete.
            Button {
                Haptics.light()
                showDeleteAccountSheet = true
            } label: {
                Text("Delete Account")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.stateBad)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.stateBad.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, Space.sm)
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) { Task { await performSignOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your local data stays on this device. Sign in again to sync to the cloud.")
        }
        .sheet(isPresented: $showDeleteAccountSheet) {
            DeleteAccountSheet(
                onConfirm: {
                    do {
                        try await AppSync.shared.deleteCurrentAccount()
                        return nil
                    } catch {
                        return "Couldn't delete account. Try again or contact support@absmaxxing.com."
                    }
                },
                onSucceededDismiss: {
                    showDeleteAccountSheet = false
                    // hasCompletedOnboarding was reset by deleteCurrentAccount —
                    // RootView will swap to OnboardingView once this view
                    // dismisses. Pop Settings explicitly so the user isn't
                    // looking at a stale Account screen first.
                    dismiss()
                },
                onCancel: {
                    showDeleteAccountSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var displayLabel: String {
        if let email = auth.currentUser?.email, !email.isEmpty {
            return email
        }
        return "Apple ID user"
    }

    private var providerLabel: String {
        switch auth.authMethod {
        case .apple: return "Signed in with Apple"
        case .email: return "Signed in with email"
        case .anonymous: return "Anonymous"
        case .unknown: return "Signed in"
        }
    }

    private var providerIcon: String {
        switch auth.authMethod {
        case .apple: return "apple.logo"
        case .email: return "envelope.fill"
        default: return "person.fill"
        }
    }

    // MARK: - Restore Purchases

    /// Visible in both anonymous and authenticated states — restoring
    /// works on either, since RevenueCat scopes purchases to the
    /// configured appUserID and aliases anonymous → authenticated when
    /// the user signs in. Auto-clears feedback after 2s.
    private var restorePurchasesButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await performRestore() }
            } label: {
                ZStack {
                    Text("Restore Purchases")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .opacity(restoring ? 0 : 1)
                    if restoring {
                        PulsingDots(color: Palette.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .disabled(restoring)

            if let restoreFeedback {
                Text(restoreFeedback.message)
                    .font(Typo.caption)
                    .foregroundStyle(restoreFeedback.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .onChange(of: restoreFeedback) { _, newValue in
            // Auto-clear after 2s. Compare against the captured value
            // before clearing so a fresh tap during the delay window
            // doesn't get its message wiped early.
            guard let captured = newValue else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    if restoreFeedback == captured {
                        withAnimation(.easeOut(duration: 0.2)) {
                            restoreFeedback = nil
                        }
                    }
                }
            }
        }
    }

    private func performRestore() async {
        print("[Settings] Restore Purchases tapped")
        restoring = true
        restoreFeedback = nil
        defer { restoring = false }

        do {
            let restored = try await PaymentService.shared.restorePurchases()
            print("[Settings] Restore success: hasProAccess=\(restored)")
            withAnimation(.easeOut(duration: 0.2)) {
                restoreFeedback = restored ? .success : .nothingToRestore
            }
        } catch {
            print("[Settings] Restore failed: \(error)")
            withAnimation(.easeOut(duration: 0.2)) {
                restoreFeedback = .error("Couldn't restore. Check your internet and try again.")
            }
        }
    }

    private func performSignOut() async {
        signingOut = true
        defer { signingOut = false }
        do {
            try await AuthService.shared.signOut()
            // Returns to home — this sheet dismisses, anonymous bootstrap
            // already kicked off by signOut() so the user has a fresh user_id.
            dismiss()
        } catch {
            // No alert here — keep the user in Settings; they can retry.
            // Phase F may surface this via a global error toast.
        }
    }
}
