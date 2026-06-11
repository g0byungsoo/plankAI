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

    /// v1.1 education pass (2026-06-11) — the chain. When set, the
    /// final page's CTA reads "next: {nextRowTitle}" and fires this
    /// instead of the legacy workout handoff: the lesson's 84%
    /// engagement routes into whatever's actually next on her
    /// checklist. The old "start today's workout" CTA had isHandoff
    /// set but PlanView never passed the closure, so the button
    /// label lied and silently dismissed (founder QA).
    var nextRowTitle: String? = nil
    var onChainNext: (() -> Void)? = nil

    @State private var pageIndex = 0
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
            // v1.1 education pass (2026-06-11): scatter REMOVED (teach
            // beats are scatter-free per the milestone rule); the page
            // becomes a left-aligned editorial column on the program
            // canvas, matching the breathwork intro's register.
            Palette.programBgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Space.md) {
                        Spacer().frame(height: Space.sm)
                        // Kicker — lowercase quiet label (the pink
                        // uppercase eyebrow read survey-app).
                        if let eyebrow = page.eyebrow {
                            Text(eyebrow.lowercased())
                                .font(.custom("DMSans-Medium", size: 13))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        ItalicAccentText(page.headline,
                                         italic: page.italic,
                                         baseFont: headlineFont,
                                         italicFont: headlineItalicFont,
                                         color: Palette.textPrimary,
                                         alignment: .leading)
                            .kerning(-0.4)
                            .lineSpacing(Typo.heroHeadlineLineGap)
                            .fixedSize(horizontal: false, vertical: true)

                        if page.citation != nil {
                            factCard
                        } else if let body = page.body {
                            Text(body)
                                .font(Typo.body)
                                .foregroundStyle(Palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let breathLine = page.breathLine {
                            Text(breathLine)
                                .font(Typo.body)
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, Space.xs)
                        }
                        Spacer().frame(height: Space.lg)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Space.lg)
                    // v1.1 — JFPageTransition page-turn (200ms exit /
                    // 60ms gap / 350ms entrance) replaces the 0.45s
                    // crossfade; the same vocabulary as onboarding +
                    // tab switches so module pages feel like one app.
                    .id(page.id)
                    .transition(JFPageTransition.standard)
                }

                ctaButton
                    .padding(.top, Space.sm)
            }
        }
        .onAppear {
            musicPlayer.play()
            fireLessonViewedOnce()
        }
        .onDisappear { musicPlayer.stop() }
    }

    // MARK: - Sections

    private var topBar: some View {
        ZStack {
            // Page dots — centered, the same dot grammar as the
            // Becoming week row. Filled = read (incl. current).
            HStack(spacing: 6) {
                ForEach(0..<script.pages.count, id: \.self) { i in
                    if i <= pageIndex {
                        Circle().fill(Palette.cocoaPrimary).frame(width: 6, height: 6)
                    } else {
                        Circle().stroke(Palette.divider, lineWidth: 1.1).frame(width: 6, height: 6)
                    }
                }
            }
            .accessibilityLabel("page \(pageIndex + 1) of \(script.pages.count)")

            HStack {
                if pageIndex > 0 {
                    Button {
                        Haptics.light()
                        withAnimation(Motion.pageEntrance) { pageIndex -= 1 }
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
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md)
    }

    // (visualBlock deleted 2026-06-11 — the Grok paper-craft
    // illustration slot and per-page sticker accents are dead per
    // Direction A; fact pages carry a typographic card instead.)

    /// Typographic fact card — the breathwork protocol card's sibling:
    /// body inside quiet white chrome, citation as the receipt row.
    private var factCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if let body = page.body {
                Text(body)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let citation = page.citation {
                Text(citation.lowercased())
                    .font(.custom("DMSans-Medium", size: 11))
                    .foregroundStyle(Palette.textSecondary.opacity(0.7))
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.divider, lineWidth: 1)
        )
    }

    @ViewBuilder private var ctaButton: some View {
        if page.isHandoff, let onChainNext, let nextRowTitle {
            // The chain — lesson energy routes to whatever's actually
            // next on her checklist; "done for today" stays one quiet
            // link below (never two pills).
            JFContinueButton(
                label: "next: \(nextRowTitle.lowercased())",
                action: {
                    completeBookkeeping()
                    onChainNext()
                },
                secondaryLabel: "done for today",
                secondaryAction: {
                    completeBookkeeping()
                    onComplete()
                }
            )
        } else if page.isHandoff {
            JFContinueButton(label: legacyHandoffLabel) {
                completeAndLaunch()
            }
        } else {
            JFContinueButton(label: page.ctaLabel.lowercased()) {
                Haptics.light()
                withAnimation(Motion.pageEntrance) { pageIndex += 1 }
            }
        }
    }

    /// Legacy final-page label. The old scripts say "start today's
    /// workout" — only honest when a workout handoff is actually
    /// wired (HomeView path); otherwise the truthful "done for today".
    private var legacyHandoffLabel: String {
        onCompleteAndStartWorkout != nil ? page.ctaLabel.lowercased() : "done for today"
    }

    // MARK: - Behavior

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

    /// Shared completion bookkeeping — live cohort only. The receipt
    /// is deliberately tiny (a lesson is 3 minutes of reading): one
    /// success haptic, no celebration screen (v1.1 education pass —
    /// was heavy + delayed success, which over-celebrated).
    private func completeBookkeeping() {
        guard !isReread else { return }
        JeniMethodState.markLessonCompleted(script.id)
        Haptics.success()
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

    /// Legacy final-page CTA — completion bookkeeping, then launch the
    /// workout (or plain dismiss in re-read / no-workout calls).
    private func completeAndLaunch() {
        completeBookkeeping()
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

    // v3 P11.6 (2026-06-10) — promoted from questionHero 34pt to
    // heroHeadline 42pt per [[feedback-hero-typography-ladder]].
    // Lessons are a daily intent-setting beat — belongs on the
    // default hero ladder alongside plan reveal / PacePicker /
    // welcome / coach intro. Was bumped from 28pt → questionHero
    // in v9 P9.7; this pass takes it the rest of the way.
    private var headlineFont: Font { Typo.heroHeadline }
    private var headlineItalicFont: Font { Typo.heroHeadlineItalic }
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
