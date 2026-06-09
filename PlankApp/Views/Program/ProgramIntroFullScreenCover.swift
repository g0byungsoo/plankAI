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
//     (a) have hasCompletedOnboarding = true
//     (b) have hasEnrolledInProgram != true
//     (c) have hasSeenProgramIntro != true
//   - Two CTAs (pinned footer, NOT inside scroll): "start my program"
//     → opens ProgramSetupSubflow; "not yet — i'll wait" → sets
//     hasSeenProgramIntro=true and dismisses.
//
// Layout architecture (founder QA 2026-06-09):
//   - VStack(spacing: 0): ScrollView (content) + Footer (CTAs)
//   - Footer is OUTSIDE the ScrollView so CTAs never float over rows.
//   - Hero typography sized to fit 2-3 lines on iPhone 15 (36pt vs
//     the old 48pt that wrapped to 4 lines).
//   - modernEntrance() for all visible elements — single shared
//     spring per Motion.modernPop.

struct ProgramIntroFullScreenCover: View {

    let onDismiss: () -> Void

    @AppStorage("hasSeenProgramIntro") private var hasSeenProgramIntro: Bool = false

    @State private var showSubflow: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            if showSubflow {
                ProgramSetupSubflow { _ in
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
        .onAppear {
            // One-frame delay so the cover's own present-transition
            // (system fullScreenCover slide-up) completes before our
            // entrance spring fires. Prevents the two from competing.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                appeared = true
            }
        }
    }

    // MARK: - Intro layout

    private var intro: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.hero)
                    .padding(.bottom, 24)
            }
            footer
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Space.section) {
            hero
            whatsInsideCard
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Her75-style 2-line display: hand-stacked Text components
                // with negative spacing so the lines visually clamp
                // together. programHeroLineGap = -10 is tuned for 52pt.
            VStack(alignment: .leading, spacing: Typo.programHeroLineGap) {
                Text("your program")
                    .font(Typo.programHeroDisplay)
                    .foregroundStyle(Palette.cocoaPrimary)
                (
                    Text("is ")
                        .font(Typo.programHeroDisplay)
                        .foregroundStyle(Palette.cocoaPrimary)
                    +
                    Text("ready.")
                        .font(Typo.programHeroItalic)
                        .foregroundStyle(Palette.cocoaPrimary)
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            Text("we used what you told us in onboarding to build your plan. you'll get a daily checklist, paced for where you actually are.")
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modernEntrance(appeared)
    }

    private var whatsInsideCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("what's inside")
                .font(Typo.editorialEyebrow)
                .foregroundStyle(Palette.cocoaTertiary)
                .textCase(.uppercase)
                .kerning(0.66)

            teaserRow("🌿", "a daily ritual of 5 things")
            teaserRow("🥗", "food, paced. not a strict diet.")
            teaserRow("🏃‍♀️", "movement that matches your energy")
            teaserRow("📖", "a short lesson every day")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.programCard)
                .fill(Palette.programCard)
        )
        .programPaperShadow()
        .modernEntrance(appeared, delay: 0.10)
    }

    private func teaserRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 20))
                .frame(width: 28, alignment: .center)
            Text(text)
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Footer (pinned)

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.light()
                withAnimation(Motion.crossFade) { showSubflow = true }
            } label: {
                Text("start my program")
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Palette.cocoaPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                Haptics.light()
                hasSeenProgramIntro = true
                onDismiss()
            } label: {
                Text("maybe later")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Palette.bgPrimary
                .overlay(
                    // Hairline divider above the footer so the
                    // scrollable content reads as a separate
                    // layer when the user scrolls past.
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
        .modernEntrance(appeared, delay: 0.20)
    }
}
