import SwiftUI

struct AccountView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showResetConfirm = false

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

                // Sign in (placeholder)
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("SYNC")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                        .tracking(2)

                    HStack(spacing: 12) {
                        Image(systemName: "icloud")
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sign in to sync")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Palette.textPrimary)
                            Text("Keep your data across devices")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                        Text("soon")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Palette.divider)
                            .clipShape(Capsule())
                    }
                    .padding(14)
                    .background(Palette.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .plankShadow()
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
}
