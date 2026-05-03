import SwiftUI

// MARK: - DeleteAccountSheet
//
// Confirms permanent account deletion. Apple App Store Review Guideline
// 5.1.1(v) requires every account-creating app to expose this in-app.
//
// Phases:
//   .confirm   — initial. Headline + body + two stacked buttons.
//   .deleting  — primary button shows three pulsing dots, secondary disabled.
//   .succeeded — content replaced with checkmark + "Account deleted",
//                auto-dismisses after 1.2s. RootView re-renders to welcome
//                because the orchestrator clears hasCompletedOnboarding.
//   .failed    — back to .confirm with inline error below the buttons.

struct DeleteAccountSheet: View {
    /// Returns nil on success, an error message on failure.
    let onConfirm: () async -> String?
    let onSucceededDismiss: () -> Void
    let onCancel: () -> Void

    private enum Phase: Equatable {
        case confirm
        case deleting
        case succeeded
        case failed(String)
    }

    @State private var phase: Phase = .confirm

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch phase {
            case .confirm, .deleting, .failed:
                confirmContent
            case .succeeded:
                successContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.xl)
        .background(Palette.bgPrimary)
    }

    // MARK: - Confirm content

    private var confirmContent: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Delete your account?")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("This permanently deletes your routine history, progress, and account. If you have an active subscription, cancel it from your iOS Settings before continuing — deletion does not cancel App Store subscriptions.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: Space.sm)

            VStack(spacing: 12) {
                deleteButton
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

    private var deleteButton: some View {
        Button {
            Haptics.light()
            Task {
                phase = .deleting
                if let errorMessage = await onConfirm() {
                    phase = .failed(errorMessage)
                } else {
                    phase = .succeeded
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    onSucceededDismiss()
                }
            }
        } label: {
            ZStack {
                Text("Delete account")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.textInverse)
                    .opacity(phase == .deleting ? 0 : 1)
                if phase == .deleting {
                    PulsingDots(color: Palette.textInverse)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Palette.stateBad)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(PressFeedbackStyle())
        .disabled(phase == .deleting)
    }

    private var cancelButton: some View {
        Button {
            Haptics.light()
            onCancel()
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
        .buttonStyle(PressFeedbackStyle())
        .disabled(phase == .deleting)
    }

    // MARK: - Success content

    private var successContent: some View {
        VStack(spacing: Space.md) {
            Spacer().frame(height: Space.lg)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(Palette.stateGood)
            Text("Account deleted")
                .font(Typo.heading)
                .foregroundStyle(Palette.textPrimary)
            Spacer().frame(height: Space.lg)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PulsingDots

/// Three-dot loading indicator. Calmer than iOS's spinning circle and
/// matches the project's "Notion / Linear" animation language. Each dot
/// pulses opacity 0.3 → 1.0 → 0.3 over 600ms with a 200ms stagger.
struct PulsingDots: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
