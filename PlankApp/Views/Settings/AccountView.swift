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
            case .success: return "subscriptions restored."
            case .nothingToRestore: return "no active subscription found. if this looks wrong, contact support."
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.lg) {
                header

                appInfoCard

                if auth.isAnonymous || !auth.isAuthenticated {
                    anonymousSection
                } else {
                    signedInSection
                }

                Spacer().frame(height: Space.lg)

                resetButton

                Spacer().frame(height: Space.xl)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.bgPrimary)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("settings")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.accent)
            Text("your account.")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Heart-lock — "your stuff, locked to you" framing.
        .overlay(alignment: .topTrailing) {
            Image(StickerName.heartLock.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(10))
                .offset(x: 4, y: -10)
                .opacity(StickerName.heartLock.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - App info

    private var appInfoCard: some View {
        VStack(spacing: 0) {
            infoRow(label: "version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            Divider().padding(.horizontal, Space.md)
            infoRow(label: "build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
        }
        .background(scrapbookChrome())
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Text(value)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(Space.md)
    }

    // MARK: - Anonymous

    private var anonymousSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("save your progress")
                .font(Typo.eyebrow).tracking(3)
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: Space.md) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Palette.accent.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 17))
                            .foregroundStyle(Palette.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("not signed in.")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 17))
                            .foregroundStyle(Palette.textPrimary)
                        Text("sign in to back up your routine.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                }

                cocoaPill(text: "sign in", icon: "arrow.right") {
                    Haptics.light()
                    showSignInSheet = true
                }

                restorePurchasesButton
            }
            .padding(Space.md)
            .background(scrapbookChrome())
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
                                    .tappableArea()
                            }
                            .accessibilityLabel("Close sign in")
                        }
                    }
            }
        }
    }

    // MARK: - Signed in

    private var signedInSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("account")
                .font(Typo.eyebrow).tracking(3)
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: Space.md) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Palette.stateGood.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: providerIcon)
                            .font(.system(size: 17))
                            .foregroundStyle(Palette.stateGood)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayLabel)
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(providerLabel)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                }

                outlineButton(
                    text: signingOut ? "signing out…" : "sign out",
                    tint: Palette.stateBad
                ) {
                    Haptics.light()
                    showSignOutConfirm = true
                }
                .disabled(signingOut)

                restorePurchasesButton
            }
            .padding(Space.md)
            .background(scrapbookChrome())

            // Delete Account — Apple App Store Review Guideline 5.1.1(v)
            // requires every account-creating app to expose this in-app.
            // Only shown when signed in; anonymous users have no cloud row
            // to delete.
            outlineButton(text: "delete account", tint: Palette.stateBad) {
                Haptics.light()
                showDeleteAccountSheet = true
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
                        return "Couldn't delete account. Try again or contact support@jenifit.app."
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

    private var resetButton: some View {
        Button {
            showResetConfirm = true
        } label: {
            Text("reset onboarding")
                .font(Typo.body)
                .foregroundStyle(Palette.stateBad)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Palette.stateBad.opacity(0.10))
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Palette.bgElevated)
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Palette.stateBad.opacity(0.45), lineWidth: 1.5)
                    }
                )
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

    private var displayLabel: String {
        if let email = auth.currentUser?.email, !email.isEmpty {
            return email
        }
        return "Apple ID user"
    }

    private var providerLabel: String {
        switch auth.authMethod {
        case .apple: return "signed in with apple."
        case .email: return "signed in with email."
        case .anonymous: return "anonymous."
        case .unknown: return "signed in."
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
                    Text("restore purchases")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
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
                        withAnimation(Motion.crossFade) {
                            restoreFeedback = nil
                        }
                    }
                }
            }
        }
    }

    private func performRestore() async {
        #if DEBUG
        print("[Settings] Restore Purchases tapped")
        #endif
        restoring = true
        restoreFeedback = nil
        defer { restoring = false }

        do {
            let restored = try await PaymentService.shared.restorePurchases()
            #if DEBUG
            print("[Settings] Restore success: hasProAccess=\(restored)")
            #endif
            withAnimation(Motion.crossFade) {
                restoreFeedback = restored ? .success : .nothingToRestore
            }
        } catch {
            #if DEBUG
            print("[Settings] Restore failed: \(error)")
            #endif
            withAnimation(Motion.crossFade) {
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

    // MARK: - Shared chrome

    private func cocoaPill(text: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 17))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
            .foregroundStyle(Palette.textInverse)
            .padding(.horizontal, Space.md)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(Palette.bgInverse)
            )
        }
    }

    private func outlineButton(text: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(tint.opacity(0.10))
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .fill(Palette.bgElevated)
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .stroke(tint.opacity(0.55), lineWidth: 1.5)
                    }
                )
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
