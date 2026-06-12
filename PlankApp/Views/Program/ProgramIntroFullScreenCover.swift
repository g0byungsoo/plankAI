import SwiftUI
import SwiftData
import PlankSync

// MARK: - ProgramOnrampView
//
// v1.1 program pivot. The Today tab's content for any user who has
// not yet committed to a program — new users straight out of
// onboarding AND existing users upgrading into the program era.
//
// Rendered INLINE as tab content, never presented. The previous
// fullScreenCover approach raced RootView's route cross-fade on the
// onboarding → MainTabView swap: the system cancelled the
// presentation mid-flight (a <1s flash) and stranded the user on the
// legacy HomeView. Structural rendering has no presentation to lose.
//
// There is deliberately no skip: the legacy HomeView is retired, so
// committing to the program is the only way into the Today surface.
// ProgramSetupSubflow sets programEraEnabled on commit, which swaps
// this view for PlanView on the next render.
//
// Layout architecture (founder QA 2026-06-09):
//   - VStack(spacing: 0): ScrollView (content) + Footer (CTA)
//   - Footer is OUTSIDE the ScrollView so the CTA never floats over rows.
//   - modernEntrance() for all visible elements — single shared
//     spring per Motion.modernPop.

struct ProgramOnrampView: View {

    @State private var showSubflow: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        ZStack {
            if showSubflow {
                ProgramSetupSubflow { committed in
                    // Commit flips programEraEnabled inside the subflow;
                    // MainTabView re-renders to PlanView on its own. A
                    // back-out returns to the intro beat.
                    if !committed {
                        showSubflow = false
                    }
                }
                .transition(.opacity)
            } else {
                intro
                    .transition(.opacity)
            }
        }
        .animation(Motion.crossFade, value: showSubflow)
        .onAppear {
            Analytics.captureScreen("ProgramOnramp")
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
        .background(Palette.programBgPrimary.ignoresSafeArea(edges: .top))
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

            // v8 P8.8: "daily checklist" swapped to "daily ritual" so
            // the language matches what users see on PlanView + the
            // teaser row below. Italic punch on "actually".
            ItalicAccentText(
                "we used what you told us in onboarding to build your plan. you'll get a daily ritual, paced for where you actually are.",
                italic: ["actually"],
                baseFont: Typo.body,
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
                color: Palette.cocoaSecondary,
                alignment: .leading
            )
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

            // v1.1 design pass — emoji glyphs swapped for thin SF
            // marks per the kill-list (no emoji) + clean-luxury
            // composition. Accent tint keeps the rows warm.
            teaserRow("checklist", "a daily ritual of 5 things")
            teaserRow("fork.knife", "food, paced. not a strict diet.")
            teaserRow("figure.run", "movement that matches your energy")
            teaserRow("book.closed", "a short lesson every day")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.programCard)
                .fill(Palette.programCard)
        )
        // v8 P8.8: complete the scrapbook chrome — accent border
        // matches PlanView + Subflow.
        .overlay(
            RoundedRectangle(cornerRadius: Radius.programCard)
                .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
        )
        .programPaperShadow()
        .modernEntrance(appeared, delay: 0.10)
    }

    private func teaserRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.accent)
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
                Analytics.track(.programInviteTapped)
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
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Palette.programBgPrimary
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
