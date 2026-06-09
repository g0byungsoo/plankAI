import SwiftUI
import SwiftData
import PlankSync

// MARK: - ProgramIntroFullScreenCover
//
// v1.1 program pivot. Existing-user opt-in surface. Founder decision
// 2026-06-09: full-screen cover (NOT a quiet home card) — commitment
// device. Reuses PremiumWelcomeScreen chrome register.
//
// Lifecycle:
//   - Fires once on first launch post-v1.1 install for users who:
//     (a) have hasCompletedOnboarding = true (they're past onboarding)
//     (b) have hasEnrolledInProgram != true (haven't yet opted in)
//     (c) have hasSeenProgramIntro != true (haven't dismissed yet)
//   - Two CTAs: "start my program" → opens ProgramSetupSubflow;
//     "not yet — i'll wait" → sets hasSeenProgramIntro=true and
//     dismisses (no permanent flag — user can still opt in from
//     a settings entry later).
//   - Tap "start my program" → flips an internal state to show the
//     3-page subflow inside the same fullScreenCover.

struct ProgramIntroFullScreenCover: View {

    let onDismiss: () -> Void

    @AppStorage("hasSeenProgramIntro") private var hasSeenProgramIntro: Bool = false

    @State private var showSubflow: Bool = false
    @State private var animateIn: Bool = false

    var body: some View {
        ZStack {
            if showSubflow {
                ProgramSetupSubflow { committed in
                    // committed=false means the user backed out of page 1 —
                    // mark as seen but not enrolled. committed=true means
                    // they finished — also mark as seen + dismiss.
                    hasSeenProgramIntro = true
                    onDismiss()
                }
                .transition(.opacity)
            } else {
                intro
                    .transition(.opacity)
            }
        }
        .animation(Motion.crossFade, value: showSubflow)
        .onAppear { animateIn = true }
    }

    private var intro: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: Space.hero)

                    // Hero "your program is ready."
                    VStack(spacing: 12) {
                        Text("your")
                            .font(Typo.programHeroDisplay)
                            .foregroundStyle(Palette.cocoaPrimary)
                        (
                            Text("program")
                                .font(Typo.programHeroItalic)
                                .foregroundStyle(Palette.cocoaPrimary)
                            +
                            Text(" is ready.")
                                .font(Typo.programHeroDisplay)
                                .foregroundStyle(Palette.cocoaPrimary)
                        )
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 18)
                    .animation(Motion.entrance, value: animateIn)

                    Text("we used what you told us in onboarding to build a custom plan. you'll get a daily checklist — lessons, meals, walks, workouts — paced for where you actually are.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.cocoaSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg + 8)
                        .opacity(animateIn ? 1 : 0)
                        .animation(Motion.entrance.delay(0.15), value: animateIn)

                    // What's inside teaser
                    VStack(alignment: .leading, spacing: 16) {
                        Text("what's inside")
                            .font(Typo.editorialEyebrow)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .textCase(.uppercase)
                            .kerning(0.66)

                        teaserRow("🌿", "a daily ritual — 5 things, every morning")
                        teaserRow("🥗", "food, paced — not a strict diet")
                        teaserRow("🏃‍♀️", "movement that matches your energy")
                        teaserRow("📖", "a short lesson, every day")
                        teaserRow("✨", "a goal date you actually finish")
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.programCard)
                            .fill(Palette.programCard)
                    )
                    .programPaperShadow()
                    .padding(.horizontal, Space.lg)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 12)
                    .animation(Motion.entrance.delay(0.3), value: animateIn)

                    Spacer().frame(height: Space.lg)
                }
            }

            VStack {
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        Haptics.light()
                        withAnimation(Motion.crossFade) { showSubflow = true }
                    } label: {
                        Text("start my program")
                            .font(Typo.heading)
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Palette.cocoaPrimary)
                            .clipShape(Capsule())
                    }

                    Button {
                        Haptics.light()
                        hasSeenProgramIntro = true
                        onDismiss()
                    } label: {
                        Text("not yet — i'll wait")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaSecondary)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.lg)
                .background(
                    LinearGradient(
                        colors: [Palette.bgPrimary.opacity(0), Palette.bgPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 140)
                    .offset(y: -60),
                    alignment: .bottom
                )
                .opacity(animateIn ? 1 : 0)
                .animation(Motion.entrance.delay(0.5), value: animateIn)
            }
        }
    }

    private func teaserRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 22))
            Text(text)
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
        }
    }
}
