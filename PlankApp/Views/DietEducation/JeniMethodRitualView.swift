import SwiftUI

/// The JeniFit Method lesson player. Phase 10 — primer-style rewrite.
///
/// Replaces the auto-paced beat engine + center breath bubble with a short
/// sequence of static, tappable pages modeled on the breathwork-primer
/// screen: pink gradient + sticker scatter, an optional paper-craft
/// illustration in a rounded frame, an eyebrow, a big italic-Fraunces
/// headline, a body paragraph, an optional citation, an optional one-line
/// breath cue, and a pinned CTA. Tap the CTA to advance; the final page's
/// CTA hands off to today's workout.
///
/// Init signature is unchanged so all call sites (Home, re-read, coach
/// intro, debug) keep working. State suppression in re-read mode is
/// preserved (analytics + markLessonCompleted gated on !isReread).
struct JeniMethodRitualView: View {
    let lesson: LessonID
    let user: JeniMethodUserContext
    var isReread: Bool = false
    let onComplete: () -> Void
    let onSkip: (_ atPageId: String) -> Void
    /// Fires when the user taps the final page's "start today's workout"
    /// CTA. Parent dismisses the lesson AND launches today's generated
    /// workout. Optional so re-read mode / call sites without a workout
    /// presentation can pass nil (treated like onComplete).
    var onCompleteAndStartWorkout: (() -> Void)? = nil

    @State private var pageIndex = 0
    @State private var contentVisible = false
    /// Ambient zen-lofi under the lesson — same player the welcome
    /// breathwork session uses. Boxed once by @State across redraws.
    @State private var musicPlayer = RitualMusicPlayer()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Splash bridge — flipped true when the handoff CTA fires so the
    /// RitualToWorkoutSplash overlay hides the cover swap into the routine.
    /// HomeView observes the same key and renders the receiving end.
    @AppStorage("ritualToWorkoutTransition") private var ritualToWorkoutTransition = false

    private var script: LessonScript {
        JeniMethodRitualContent.resolve(lesson: lesson, user: user)
    }
    private var page: LessonPage { script.pages[pageIndex] }

    var body: some View {
        ZStack {
            // v6 audit #2: lesson player aligns with the program-era
            // pink home tab. Per designer note, accentSubtle mat at
            // line 157 (around the illustration pocket) stays — it
            // provides the right contrast on the visual card.
            Palette.programBgPrimary.ignoresSafeArea()

            StickerScatter(placements: StickerScatter.breathworkPrimerDefault())
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.md) {
                        Spacer().frame(height: Space.sm)
                        visualBlock
                        if let eyebrow = page.eyebrow {
                            Text(eyebrow.uppercased())
                                .font(Typo.eyebrow)
                                .tracking(1.6)
                                .foregroundStyle(Palette.accent)
                                .multilineTextAlignment(.center)
                        }
                        ItalicAccentText(page.headline,
                                         italic: page.italic,
                                         baseFont: headlineFont,
                                         italicFont: headlineItalicFont,
                                         color: Palette.textPrimary,
                                         alignment: .center)
                            .padding(.horizontal, Space.sm)
                        if let body = page.body {
                            Text(body)
                                .font(Typo.body)
                                .foregroundStyle(Palette.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Space.xs)
                        }
                        if let citation = page.citation {
                            Text(citation)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.textSecondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        if let breathLine = page.breathLine {
                            Text(breathLine)
                                .font(Typo.body)
                                .foregroundStyle(Palette.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, Space.xs)
                                .padding(.horizontal, Space.sm)
                        }
                        Spacer().frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.lg)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 8)
                }

                ctaButton
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.sm)
                    .padding(.bottom, Space.xl)
            }
        }
        .onAppear {
            musicPlayer.play()
            fireLessonViewedOnce()
            reveal()
        }
        .onDisappear { musicPlayer.stop() }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            if pageIndex > 0 {
                Button {
                    Haptics.light()
                    contentVisible = false
                    pageIndex -= 1
                    reveal()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.textPrimary.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.4)))
                }
                .accessibilityLabel("Back")
            }
            Spacer()
            Button {
                skip()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.textPrimary.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.4)))
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
    }

    @ViewBuilder
    private var visualBlock: some View {
        if let asset = page.illustration {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 196)
                .background(Palette.accentSubtle.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(Palette.accent.opacity(0.4), lineWidth: 1.5)
                )
                .padding(.bottom, Space.xs)
                .accessibilityHidden(true)
        } else if let sticker = page.sticker {
            Image(sticker.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .padding(.bottom, Space.xs)
                .accessibilityHidden(true)
        }
    }

    private var ctaButton: some View {
        Button {
            if page.isHandoff {
                completeAndLaunch()
            } else {
                Haptics.light()
                contentVisible = false
                pageIndex += 1
                reveal()
            }
        } label: {
            Text(page.ctaLabel)
        }
        .buttonStyle(.ctaPrimary)
    }

    // MARK: - Behavior

    private func reveal() {
        if reduceMotion {
            contentVisible = true
            return
        }
        withAnimation(.easeInOut(duration: 0.45)) { contentVisible = true }
    }

    /// X tapped — record the skip (live cohort only) and hand back to the
    /// parent, which dismisses. Mirrors the old beat player's skip path.
    private func skip() {
        Haptics.light()
        if !isReread {
            Analytics.track(
                .dietEducationSkipped,
                properties: JeniMethodAnalytics.skipProps(
                    lesson: resolvedShim, user: user, screen: page.id
                )
            )
            JeniMethodState.incrementSkipCount()
        }
        onSkip(page.id)
    }

    /// Final-page CTA — completion bookkeeping (live cohort only), then
    /// launch the workout (or plain dismiss in re-read / no-workout calls).
    private func completeAndLaunch() {
        if !isReread {
            JeniMethodState.markLessonCompleted(script.id)
            Haptics.heavy()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Haptics.success()
            }
            // The terminal arc event fires once, on the last numbered day.
            if script.id == LessonID.dailyLessons.last?.rawValue {
                let days = JeniMethodState.daysSinceEnrolled() ?? 0
                Analytics.track(
                    .dietEducationCompleted,
                    properties: JeniMethodAnalytics.completedProps(
                        user: user,
                        lessonsCompleted: LessonID.dailyLessons.count,
                        lessonsSkipped: JeniMethodState.skipCount,
                        daysElapsed: days
                    )
                )
            }
        }
        if let handoff = onCompleteAndStartWorkout {
            // Raise the plain light-pink bridge (RitualToWorkoutSplash) and
            // let it reach full opacity (HomeView fades it in over 0.3s)
            // before the lesson cover dismisses underneath it — so the
            // cover-swap and the workout's appearance are both hidden behind
            // pink and the workout reads as gently appearing, not sliding
            // up. No bubble: the splash is just the gradient now.
            ritualToWorkoutTransition = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                handoff()
            }
        } else {
            onComplete()
        }
    }

    private func fireLessonViewedOnce() {
        guard !isReread else { return }
        // Stamp the once-per-day gate so HomeView won't auto-present
        // another lesson today after this one closes.
        JeniMethodState.markRitualShownToday()
        Analytics.track(
            .dietEducationLessonViewed,
            properties: JeniMethodAnalytics.lessonProps(
                lesson: resolvedShim, user: user
            )
        )
    }

    /// The analytics props helpers expect a ResolvedLesson; build a
    /// minimal one inline (same id + topic + voice as the script).
    private var resolvedShim: ResolvedLesson {
        ResolvedLesson(
            id: script.id, topic: script.topic,
            standingSafetyLine: script.standingSafetyLine, voice: script.voice
        )
    }

    // MARK: - Typography

    private var headlineFont: Font {
        Font.custom("Fraunces72pt-SemiBold", size: 28, relativeTo: .title2)
    }
    private var headlineItalicFont: Font {
        Font.custom("Fraunces72pt-SemiBoldItalic", size: 28, relativeTo: .title2)
    }
}

#if DEBUG
#Preview("Day 1 lesson") {
    JeniMethodRitualView(
        lesson: .day1,
        user: .empty,
        onComplete: {},
        onSkip: { _ in }
    )
}
#endif
