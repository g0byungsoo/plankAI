import SwiftUI

// MARK: - DeleteAccountCopy (v25 §39)
//
// Apple's TN3194 says an app that holds no revocable token must still
// meet the account-deletion requirement, and names the three steps.
// Jeni holds none of the three credentials Apple accepts — the
// `authorizationCode` the system hands the delegate has ZERO call sites
// in first-party code, and Supabase stores no provider token either —
// so step 2, *"direct the user to manually revoke access for your
// client"*, is the only honest thing this screen can say.
//
// It is shown to Apple customers only. An email or anonymous customer
// has no Apple credential, and telling her to go and revoke one would
// be a instruction to do something that does not exist.
//
// The wording may never imply Jeni did the revoking. It cannot.

enum DeleteAccountCopy {
    static func appleRevocationNote(for method: AuthMethod) -> String? {
        guard method == .apple else { return nil }
        return "you signed in with apple. deleting here removes your data, "
             + "but only you can take back the apple sign-in itself: "
             + "settings › your name › sign-in and security › sign in with apple."
    }
}

// MARK: - DeleteAccountSheet
//
// Confirms permanent account deletion. Apple App Store Review Guideline
// 5.1.1(v) requires every account-creating app to expose this in-app.
//
// Phases:
//   .confirm   — initial. Eyebrow, masthead, hairline, prose, one ink
//                capsule with `cancel` as its text link.
//   .deleting  — the capsule's own loading state; the link stands down.
//   .succeeded — the sentence replaces the question and auto-dismisses
//                after 1.2s. RootView re-renders to welcome because the
//                orchestrator clears hasCompletedOnboarding.
//   .failed    — back to .confirm with the reason ABOVE the action, so
//                it is read before the button rather than after it.
//                v25 §39: this state is now reachable ONLY when the
//                server did not confirm, so the sentence is true.

struct DeleteAccountSheet: View {
    /// Returns nil on success, an error message on failure.
    let onConfirm: () async -> String?
    let onSucceededDismiss: () -> Void
    let onCancel: () -> Void
    /// v25 §39 — decides whether Apple's manual-revocation step is
    /// shown. Defaults to the live identity; injectable so a preview or
    /// a walker can film the Apple face without an Apple account.
    var authMethod: AuthMethod = AuthService.shared.authMethod

    private enum Phase: Equatable {
        case confirm
        case deleting
        case succeeded
        case failed(String)
    }

    @State private var phase: Phase = .confirm

    // v25 §39 — THE SCROLL IS NOT POLISH, IT IS REACHABILITY.
    //
    // Filmed at AX5 before anything was added to this screen: the
    // warning card alone is taller than the display, so the masthead
    // sits above the top edge and **`delete account` and `cancel` are
    // both off the bottom, with no way to reach either**. Guideline
    // 5.1.1(v) requires account deletion to be initiable in the app;
    // at accessibility text sizes it was not. Pre-existing, found by
    // filming rather than by reading, and the added Apple sentence made
    // it three lines worse.
    //
    // `.basedOnSize` means nothing moves at any size that already fits.
    var body: some View {
        ScrollView {
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
        }
        .scrollBounceBehavior(.basedOnSize)
        // p68 — the decision is PINNED (§5.2 sticky anatomy). It used
        // to live inside the scroll: with the Apple-revocation note the
        // destructive confirm AND its cancel both started below the
        // fold, on the one sheet where reaching the exit is the point.
        .safeAreaInset(edge: .bottom) {
            if phase != .succeeded {
                JFContinueButton(
                    label: "delete account",
                    action: { confirmDeletion() },
                    isLoading: phase == .deleting,
                    secondaryLabel: "cancel",
                    secondaryAction: {
                        guard phase != .deleting else { return }
                        Haptics.light()
                        onCancel()
                    }
                )
                .padding(.top, Space.sm)
                .background {
                    Palette.bgPrimary
                        .overlay(alignment: .top) {
                            LinearGradient(
                                colors: [Palette.bgPrimary.opacity(0), Palette.bgPrimary],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 22)
                            .offset(y: -22)
                        }
                        .ignoresSafeArea()
                }
            }
        }
        .background(Palette.bgPrimary)
    }

    // MARK: - Confirm content

    // v25 §39 — BROUGHT ONTO THE CURRENT DESIGN LAW (founder steer,
    // mid-build). This screen predated it and still wore the pre-v21
    // chrome: a boxed warning card with a coloured 1.5pt stroke and an
    // offset drop-shadow rectangle, a ROSE-FILLED primary capsule, and a
    // bordered secondary capsule with a second offset shadow.
    //
    // Against `docs/design` and `37` §13 that is four violations: a card
    // around a paragraph (the one card is white, 20pt, no border, no
    // shadow, and is never used to box prose), a coloured primary (`26`
    // retired the last rose primary button to ink), a bordered secondary
    // (the law is bare text, no border), and the offset-rectangle
    // shadows that `27` found painting glyphs twice.
    //
    // Now: eyebrow, serif masthead, ONE hairline, prose, and the
    // product's own `JFContinueButton` — one ink capsule with its
    // tertiary text link beneath, the same object every other primary
    // action in Jeni is made of. `permanent` keeps the state tint
    // because it is the one word that names the stakes, and it is a
    // word, not a box.
    private var confirmContent: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("permanent")
                    .font(Typo.eyebrow).tracking(2)
                    .foregroundStyle(Palette.stateBad)
                Text("delete your account?")
                    .font(Typo.titleItalic)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(Palette.divider)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: Space.sm) {
                // p71 — "routine history" was plank-era vocabulary; the
                // deletion promise names what the record actually holds.
                Text("this permanently deletes your account and your whole record: plates, weigh-ins, doses, notes. if you have an active subscription, cancel it from your iOS settings first. deletion does not cancel App Store subscriptions.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // v25 §39 — Apple's TN3194 fallback for an app that
                // holds no revocable token, which Jeni is. Shown only to
                // customers who signed in with Apple; it is the one step
                // the product genuinely cannot do for her.
                if let note = DeleteAccountCopy.appleRevocationNote(for: authMethod) {
                    Text(note)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if case let .failed(message) = phase {
                Text(message)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.stateBad)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func confirmDeletion() {
        guard phase != .deleting else { return }
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
    }

    // MARK: - Success content

    /// v25 §39 — the 52pt filled green `checkmark.circle.fill` is gone.
    /// A filled system glyph in a state colour is the one thing the
    /// palette law does not have a slot for, and celebrating a deletion
    /// with a green tick was the wrong register for the act anyway. The
    /// sentence is the whole confirmation, in the same eyebrow-over-
    /// masthead shape as the question it answers.
    private var successContent: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Spacer().frame(height: Space.lg)
            Text("done")
                .font(Typo.eyebrow).tracking(2)
                .foregroundStyle(Palette.textSecondary)
            Text("account deleted.")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer().frame(height: Space.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
