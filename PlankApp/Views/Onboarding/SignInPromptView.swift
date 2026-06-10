import SwiftUI
import AuthenticationServices

// MARK: - SignInPromptView
//
// Soft sign-in prompt with three modes:
//   .signUp        — default. Mid-onboarding nudge: "Save your progress."
//                    Apple button reads "Sign up with Apple"; email sheet
//                    defaults to the create-account form.
//   .signIn        — opened from the welcome screen "Already have an
//                    account?" link. Apple button reads "Continue with
//                    Apple"; email sheet defaults to the sign-in form.
//   .sunkCostLock  — Delta v8 D82 post-reveal sunk-cost lock. Fires
//                    IMMEDIATELY after OnboardingRevealView and IMMEDIATELY
//                    before the paywall. Headline ties directly to the
//                    plan she just saw ("save your *becoming* plan ♥")
//                    so sign-in reads as preserving the artifact, not as
//                    account-setup friction.
//
// All three paths (Apple, Email, Maybe later) advance the flow via
// `onContinue()`. The user can also sign in later from Settings (Phase E).
// Anonymous sessions are first-class — local progress and SessionLog writes
// work the same way whether or not the user has linked an Apple/email
// identity. The anonymous-first AuthService UPGRADES the anonymous
// account on Apple/email sign-in (it does NOT create a new account),
// preserving everything she entered in onboarding.

enum SignInPromptMode {
    case signUp
    case signIn
    case sunkCostLock
}

struct SignInPromptView: View {
    let onContinue: () -> Void
    var mode: SignInPromptMode = .signUp

    @State private var showEmailSheet = false
    @State private var working = false
    @State private var errorMessage: String?

    // Sign-in prompt scatter — 6-sticker fuller treatment (matches the
    // section-divider density; auth is a meaningful interstitial, not a
    // form-heavy screen, so it earns the same density). Edges only,
    // mid-screen kept clear for the hero sticker + headline + buttons.
    // 2 line-art + 4 painterly.
    private static let signInPromptPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.10, y: 0.08),
                         size: 30, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.88, y: 0.12),
                         size: 28, rotation: 12, phaseDelay: 0.18),
        StickerPlacement(sticker: .heartGlossy,
                         position: CGPoint(x: 0.92, y: 0.42),
                         size: 32, rotation: 13, phaseDelay: 0.36),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.08, y: 0.55),
                         size: 30, rotation: -8, phaseDelay: 0.54),
        StickerPlacement(sticker: .gummyBear,
                         position: CGPoint(x: 0.90, y: 0.84),
                         size: 34, rotation: -8, phaseDelay: 0.72),
        StickerPlacement(sticker: .bowIridescent,
                         position: CGPoint(x: 0.10, y: 0.86),
                         size: 32, rotation: 10, phaseDelay: 0.90),
    ]

    // Hero sticker — sign up mode gets sparkle (forward energy),
    // sign in mode gets heart (welcome back warmth), sunk-cost-lock
    // gets flower3D (the becoming/plan signifier from the projection
    // card). Larger size + soft accent halo behind it so it reads as
    // a deliberate brand mark, not ambient decor.
    private var heroStickerName: StickerName {
        switch mode {
        case .signIn:       return .heartGlossy
        case .sunkCostLock: return .flower3D
        case .signUp:       return .sparkleGlossy
        }
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            StickerScatter(placements: Self.signInPromptPlacements)

            VStack(spacing: 0) {
                Spacer()

                // Hero sticker — soft accent halo behind a brand sticker
                // chosen by mode. Replaces the previous SF Symbol icon for
                // a warmer, on-brand JeniFit moment.
                ZStack {
                    Circle()
                        .fill(Palette.accent.opacity(0.12))
                        .frame(width: 110, height: 110)
                    Image(heroStickerName.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78, height: 78)
                        .opacity(heroStickerName.style.opacity)
                }

            Spacer().frame(height: Space.lg)

            // Italic accent on the emphasis word — Fraunces italic against
            // Fraunces SemiBold gives the headline its JeniFit voice.
            // Sunk-cost-lock copy ties directly to what she just saw on
            // the reveal screen ("save your *becoming* plan ♥") so the
            // sign-in reads as preserving the artifact, not friction.
            Group {
                switch mode {
                case .signIn:
                    (Text("Welcome ").font(Typo.title)
                     + Text("back").font(Typo.titleItalic)
                     + Text(".").font(Typo.title))
                case .sunkCostLock:
                    (Text("save your ").font(Typo.title)
                     + Text("becoming").font(Typo.titleItalic)
                     + Text(" plan ♥").font(Typo.title))
                case .signUp:
                    (Text("Save your ").font(Typo.title)
                     + Text("progress").font(Typo.titleItalic)
                     + Text(".").font(Typo.title))
                }
            }
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Space.sm)

            // v3 P11.1.C (2026-06-10) — sunkCostLock sub dropped per
            // [[feedback-her75-editorial-register]]. signIn/signUp
            // modes keep their subs (different cohort context: signIn
            // is recovery, signUp is opt-in; both benefit from the
            // affordance hint). sunkCostLock is the Cal AI S4 commit
            // moment — the headline ("save your becoming plan ♥")
            // already carries the meaning; the sub was restating it.
            if mode != .sunkCostLock {
                Text({
                    switch mode {
                    case .signIn:
                        return "Sign in to recover your routine\non this device."
                    case .signUp:
                        return "Sign in to keep your routine\nwhen you switch phones."
                    case .sunkCostLock:
                        return ""
                    }
                }())
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
            }

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
                    Text({
                        switch mode {
                        case .signIn:       return "Cancel"
                        case .sunkCostLock: return "skip for now"
                        case .signUp:       return "Maybe later"
                        }
                    }())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 8)
                }
                .padding(.top, Space.xs)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            SignUpView(initialMode: mode == .signIn ? .signIn : .signUp) {
                showEmailSheet = false
                onContinue()
            }
        }
    }

    // MARK: - Apple
    //
    // Custom HIG-style button that triggers the **programmatic** Apple
    // sign-in path via `AuthService.shared.signInWithApple()`. We dropped
    // SwiftUI's `SignInWithAppleButton` here because its nonce capture
    // (state in `@State` between `onRequest` and `onCompletion`) raced
    // with view rebuilds and produced "Nonces mismatch" 400s from
    // Supabase. The programmatic path keeps the raw nonce on
    // `AppleSignInService`'s instance, isolated from view lifecycle.

    private var appleButton: some View {
        Button(action: triggerAppleSignIn) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 19))
                Text(mode == .signIn ? "Sign in with Apple" : "Continue with Apple")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(working)
        .opacity(working ? 0.6 : 1)
    }

    private func triggerAppleSignIn() {
        Task {
            working = true
            defer { working = false }
            do {
                try await AuthService.shared.signInWithApple()
                Haptics.success()
                onContinue()
            } catch AppleSignInService.SignInError.canceled {
                // User-cancel — stay quiet.
            } catch {
                #if DEBUG
                print("[SignInPrompt] Apple sign-in failed: \(error)")
                #endif
                errorMessage = "Couldn't sign in with Apple. Try email instead?"
            }
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
        .buttonStyle(PressFeedbackStyle())
        .disabled(working)
    }
}
