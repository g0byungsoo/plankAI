import SwiftUI
import SwiftData
import PlankSync
import Auth  // MemberImportVisibility: User.id / .email live in Supabase's Auth submodule

/// "your account." — v1.1 clean-luxury pass: hairline sections replace
/// the boxed cards, destructive actions are quiet text rows, and the
/// membership mark carries the pearl sheen (the drawer's one jewel
/// beside the hub monogram).
struct AccountView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss

    @State private var auth = AuthService.shared
    @State private var payment = PaymentService.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Query private var userRecords: [UserRecord]
    @AppStorage("userName") private var userName = ""
    @State private var editName = ""
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
            VStack(alignment: .leading, spacing: 0) {
                JFPageHero(title: "your account.", italic: ["your"], alignment: .leading)
                    .padding(.horizontal, -Space.screenPadding)

                Spacer().frame(height: 28)

                SettingsSection(title: "your name") {
                    TextField("your name", text: $editName)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .submitLabel(.done)
                        .onSubmit { saveName() }
                        .padding(.vertical, 17)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                        }
                }

                Spacer().frame(height: 36)

                membershipSection

                Spacer().frame(height: 36)

                if auth.isAnonymous || !auth.isAuthenticated {
                    anonymousSection
                } else {
                    signedInSection
                }

                #if DEBUG
                Spacer().frame(height: 36)
                resetRow   // QA-only: wipes onboarding, hidden from real users
                #endif

                Spacer().frame(height: 40)
                versionFooter

                Spacer().frame(height: Space.xl)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
        }
        .background(Palette.programEraBg)
        .onAppear { editName = userName }
        .onDisappear { saveName() }
    }

    // MARK: - Name

    private var currentUserRecord: UserRecord? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return nil }
        if let hit = userRecords.first(where: { $0.id == userId }) { return hit }
        let descriptor = FetchDescriptor<UserRecord>(predicate: #Predicate { $0.id == userId })
        return try? modelContext.fetch(descriptor).first
    }

    /// Persist to AppStorage + UserRecord + Supabase (saved on submit + on
    /// leaving the screen, so no save button is needed for one field).
    private func saveName() {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != userName else { return }
        userName = trimmed
        if let record = currentUserRecord {
            record.name = trimmed
            record.pendingUpsert = true
            try? modelContext.save()
            Task { await AppSync.shared.upsertUser(record) }
        }
    }

    // MARK: - Membership

    private var membershipSection: some View {
        SettingsSection(title: "membership") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Palette.accent.opacity(0.55), lineWidth: 1)
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkle")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(Palette.accent)
                    }
                    .iridescentSheen()
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(payment.hasProAccess ? "jenifit plus" : "free plan")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 17))
                            .foregroundStyle(Palette.textPrimary)
                        Text(payment.hasProAccess
                             ? "you're all in. everything jeni planned is yours."
                             : "unlock everything jeni planned for you.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                }

                if payment.hasProAccess {
                    SettingsNavRow(icon: "arrow.up.right", title: "manage subscription") {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            openURL(url)
                        }
                    }
                }
            }
        }
    }

    private var versionFooter: some View {
        Text("jenifit · v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Anonymous

    private var anonymousSection: some View {
        SettingsSection(title: "save your progress") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("not signed in.")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                            .foregroundStyle(Palette.textPrimary)
                        Text("sign in to back up your routine.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)

                Button {
                    Haptics.light()
                    showSignInSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Text("sign in")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Palette.bgInverse))
                }
                .buttonStyle(SettingsGlowPressStyle())
                .padding(.bottom, 8)

                restorePurchasesRow
            }
        }
        .sheet(isPresented: $showSignInSheet) {
            NavigationStack {
                SignInPromptView { showSignInSheet = false }
                    .background(Palette.programEraBg)
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
        SettingsSection(title: "signed in") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: providerIcon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 24)
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
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                }

                quietRow(signingOut ? "signing out…" : "sign out", tint: Palette.textPrimary) {
                    showSignOutConfirm = true
                }
                .disabled(signingOut)

                // Delete Account — Apple App Store Review Guideline
                // 5.1.1(v) requires every account-creating app to expose
                // this in-app. Anonymous users have no cloud row to delete.
                quietRow("delete account", tint: Palette.stateBad) {
                    showDeleteAccountSheet = true
                }

                restorePurchasesRow
            }
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

    /// Quiet hairline action row — text only, no chrome. Destructive
    /// actions get their tint; everything stays still.
    private func quietRow(_ text: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(text)
                .font(Typo.body)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 17)
                .contentShape(Rectangle())
        }
        .buttonStyle(SettingsGlowPressStyle())
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
    }

    private var resetRow: some View {
        quietRow("reset onboarding (dev)", tint: Palette.stateBad) {
            showResetConfirm = true
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
        case .email: return "envelope"
        default: return "person"
        }
    }

    // MARK: - Restore Purchases

    /// Visible in both anonymous and authenticated states — restoring
    /// works on either, since RevenueCat scopes purchases to the
    /// configured appUserID and aliases anonymous → authenticated when
    /// the user signs in. Auto-clears feedback after 2s.
    private var restorePurchasesRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await performRestore() }
            } label: {
                ZStack(alignment: .leading) {
                    Text("restore purchases")
                        .font(Typo.body)
                        .foregroundStyle(Palette.accent)
                        .opacity(restoring ? 0 : 1)
                    if restoring {
                        PulsingDots(color: Palette.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 17)
                .contentShape(Rectangle())
            }
            .buttonStyle(SettingsGlowPressStyle())
            .disabled(restoring)

            if let restoreFeedback {
                Text(restoreFeedback.message)
                    .font(Typo.caption)
                    .foregroundStyle(restoreFeedback.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
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
            // v1.1.1 — wipe identity-scoped @AppStorage + cancel
            // retention pushes BEFORE the actual signOut so the
            // anonymous bootstrap re-fires onto a clean slate.
            // Otherwise the next account inherits the previous
            // user's onboarding answers, cohort flags, and
            // pending Day-1/Day-5 nudges.
            AppSync.shared.clearLocalUserStateForSignOut()
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
