import SwiftUI

/// CorePower-vibe guided ritual for The JeniFit Method. Phase 9.4.
///
/// Replaces the swipeable card lesson model with a single-screen auto-
/// paced session that flows through beats: welcome → breath → instructor
/// lines → illustration → pause → movement → close. Total runtime
/// ~3 minutes per lesson.
///
/// Visual: warm mood gradient (cream → soft amber → dusky rose),
/// persistent ambient breath circle behind the content, large editorial
/// type for the line beats. No progress bar, no chrome that screams
/// "app." Single tap on the body skips to the next beat.
///
/// Audio: pending Phase 9.4b — ambient music via BackgroundMusicService.
/// This pass is silent.
///
/// State suppression in re-read mode is preserved (analytics +
/// markLessonCompleted gated on !isReread).
struct JeniMethodRitualView: View {
    let lesson: LessonID
    let user: JeniMethodUserContext
    var isReread: Bool = false
    let onComplete: () -> Void
    let onSkip: (_ atBeatId: String) -> Void
    /// Phase 9.19 — Day 1 only. Fires when the user taps the
    /// workoutHandoff beat's CTA button. Parent dismisses the ritual
    /// AND launches today's generated workout. Optional so re-read
    /// mode / Days 2-5 / call sites that don't own a workout
    /// presentation can pass nil (treated like onComplete).
    var onCompleteAndStartWorkout: (() -> Void)? = nil

    @State private var beatIndex: Int = 0
    @State private var beatStartedAt: Date = .now
    @State private var beatTimerToken = UUID()
    @State private var paused: Bool = false
    /// Drives the line-beat fade-in / fade-out per beat change.
    @State private var lineOpacity: Double = 0
    /// Phase 9.9 — tap debounce. Auto-advancing beats compose with
    /// the user-tap-to-advance affordance; rapid double-taps used to
    /// skip two beats (the second tap landing during the 0.25s fade
    /// of the first advance). Stamp the last advance time and ignore
    /// taps that come within ~0.5s of the previous one.
    @State private var lastAdvanceAt: Date = .distantPast
    /// Ambient music — loaded on view appear, faded out on dismiss.
    /// Reference-typed; SwiftUI keeps the same instance across redraws
    /// because @State boxes it once. Plays the zen lofi track.
    @State private var musicPlayer = RitualMusicPlayer()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Phase 9.24 — splash bridge flag. When the CTA fires, we flip
    /// this true; the RitualToWorkoutSplash overlay below fades in
    /// and hides the cover-dismiss + cover-present animation between
    /// here and the routine session. HomeView observes the same key
    /// and renders its own splash for the receiving end.
    @AppStorage("ritualToWorkoutTransition") private var ritualToWorkoutTransition = false
    /// Phase 9.27 — content fade-in on appear. Cover-present slide is
    /// disabled at each trigger site via UIView.setAnimationsEnabled,
    /// so the cover materializes instantly; this opacity ramp is the
    /// only motion the user sees on entry. Matches the appear pattern
    /// used on PreRoutineView and PreSessionView.
    @State private var contentOpacity: Double = 0

    private var ritual: LessonRitual {
        JeniMethodRitualContent.resolve(lesson: lesson, user: user)
    }

    private var currentBeat: LessonBeat { ritual.beats[beatIndex] }
    private var isLastBeat: Bool { beatIndex >= ritual.beats.count - 1 }

    var body: some View {
        ZStack {
            ritualBackground

            // Persistent breath presence — visible during line / pause /
            // illustration beats; the breath beat takes over its scale.
            BreathCircle(state: persistentBreathState)
                .offset(y: 40)  // sits behind the foreground content

            VStack(spacing: Space.lg) {
                topBar
                Spacer()
                beatContent
                    .opacity(lineOpacity)
                Spacer()
                footerHint
            }
            .padding(.horizontal, Space.lg)
        }
        // Tap anywhere on the body → advance. Hint at the bottom tells
        // the user this is available. Phase 9.19 — workoutHandoff
        // beat gates inside advance() so the inner CTA Button gets
        // priority on its own taps and the parent gesture is a no-op.
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .opacity(contentOpacity)
        .onAppear {
            // Phase 9.27 — fade the ritual in over 0.6s. Cover-slide
            // is killed at the trigger site so this is the appear
            // animation the user sees.
            withAnimation(.easeInOut(duration: 0.6)) {
                contentOpacity = 1
            }
            fireLessonViewedOnce()
            startBeat(at: 0, fresh: true)
            musicPlayer.play()
        }
        .onDisappear {
            musicPlayer.stop()
        }
    }

    // MARK: - Background

    private var ritualBackground: some View {
        ZStack {
            // Phase 9.7: cream → soft pink vertical gradient. Cream at
            // top keeps headline contrast; soft pink at bottom adds
            // warmth + matches the reference screens. The "candle"
            // feeling now comes entirely from the painted bloom +
            // music + cream-to-pink shift; no dark color anywhere.
            LinearGradient(
                colors: [
                    Color(hex: "#FDF6F4"),  // bgPrimary (cream)
                    Color(hex: "#F5D5D8"),  // accentSubtle (soft pink)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ambient sticker scatter — always present (welcome + line
            // + close beats). Reference screens show small accent
            // stickers in corners across every screen, so we match.
            // Five varied types instead of two of the same — adds
            // personality without competing with copy.
            StickerScatter(placements: Self.ritualStickers)
                .allowsHitTesting(false)
                .opacity(0.85)
        }
    }

    /// Phase 9.8: 10 stickers with varied sizes (18-34pt) spread across
    /// all four edges of the screen — matches the onboarding welcome
    /// reference (IMG_5690 + IMG_5698). Mix of types: outlined hearts,
    /// sparkles, glossy gummy bears, plush teddies, cherries,
    /// strawberries, flowers, bows, camera, star. Larger painterly
    /// stickers (gummy bear, teddy, flower) act as bigger accent
    /// anchors; smaller line-art (hearts, star, sparkle) provide
    /// scattered confetti energy.
    private static let ritualStickers: [StickerPlacement] = [
        // ── TOP edge ─────────────────────────────────────────────────
        StickerPlacement(
            sticker: .heartsLineart,
            position: CGPoint(x: 0.10, y: 0.07),
            size: 24, rotation: -16, phaseDelay: 0.0
        ),
        StickerPlacement(
            sticker: .starLineart,
            position: CGPoint(x: 0.48, y: 0.05),
            size: 22, rotation: 8, phaseDelay: 0.15
        ),
        StickerPlacement(
            sticker: .bowSatin,
            position: CGPoint(x: 0.88, y: 0.09),
            size: 32, rotation: -12, phaseDelay: 0.3
        ),

        // ── MID edges (left + right) ────────────────────────────────
        StickerPlacement(
            sticker: .cameraLineart,
            position: CGPoint(x: 0.06, y: 0.42),
            size: 26, rotation: -8, phaseDelay: 0.45
        ),
        StickerPlacement(
            sticker: .sparkleGlossy,
            position: CGPoint(x: 0.94, y: 0.38),
            size: 18, rotation: 14, phaseDelay: 0.55
        ),
        StickerPlacement(
            sticker: .flower3D,
            position: CGPoint(x: 0.93, y: 0.62),
            size: 28, rotation: 6, phaseDelay: 0.65
        ),

        // ── BOTTOM edge ─────────────────────────────────────────────
        StickerPlacement(
            sticker: .gummyBear,
            position: CGPoint(x: 0.10, y: 0.88),
            size: 34, rotation: -8, phaseDelay: 0.75
        ),
        StickerPlacement(
            sticker: .cherries,
            position: CGPoint(x: 0.36, y: 0.92),
            size: 26, rotation: 4, phaseDelay: 0.82
        ),
        StickerPlacement(
            sticker: .teddyPink,
            position: CGPoint(x: 0.66, y: 0.90),
            size: 32, rotation: -6, phaseDelay: 0.88
        ),
        StickerPlacement(
            sticker: .strawberryRipe,
            position: CGPoint(x: 0.92, y: 0.93),
            size: 24, rotation: 10, phaseDelay: 0.95
        ),
    ]

    // MARK: - Top bar (close only — no progress)

    private var topBar: some View {
        HStack {
            // Back button — Phase 9.9. Goes back one beat. Hidden on the
            // first beat (nothing to go back to). Cancels the in-flight
            // auto-advance timer so going back doesn't immediately
            // re-advance from the timer that was scheduled for the
            // beat we're leaving.
            Button {
                guard beatIndex > 0 else { return }
                Haptics.light()
                let prev = beatIndex - 1
                if reduceMotion {
                    startBeat(at: prev, fresh: false)
                } else {
                    withAnimation(.easeIn(duration: 0.2)) { lineOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        startBeat(at: prev, fresh: false)
                    }
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.textPrimary.opacity(beatIndex > 0 ? 0.7 : 0))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(beatIndex > 0 ? 0.4 : 0)))
            }
            .disabled(beatIndex == 0)
            .accessibilityLabel("Back")

            Spacer()

            Button {
                if !isReread {
                    Analytics.track(
                        .dietEducationSkipped,
                        properties: JeniMethodAnalytics.skipProps(
                            lesson: skippablyResolvedShim, user: user, screen: currentBeat.id
                        )
                    )
                    JeniMethodState.incrementSkipCount()
                }
                onSkip(currentBeat.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.textPrimary.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.4)))
            }
            .accessibilityLabel("Close")
        }
        .padding(.top, Space.md)
    }

    // The analytics props helpers expect a ResolvedLesson; build a
    // minimal one inline for the events. Same id + topic + voice as
    // the ritual. Phase 9.22 dropped the cards field from ResolvedLesson.
    private var skippablyResolvedShim: ResolvedLesson {
        ResolvedLesson(
            id: ritual.id, topic: ritual.topic,
            standingSafetyLine: ritual.standingSafetyLine, voice: ritual.voice
        )
    }

    // MARK: - Beat content

    @ViewBuilder
    private var beatContent: some View {
        switch currentBeat.kind {
        case .welcome(let line, let italic):
            welcomeBeat(line: line, italic: italic)
        case .breath:
            // Breath beat: the BreathCircle in the background handles
            // the visual AND the countdown number + inhale/exhale
            // label. Phase 9.16 dropped the small "breathe" eyebrow
            // here — the countdown number IS the cue now.
            Color.clear.frame(height: 1)
        case .line(let text, let italic):
            lineBeat(text: text, italic: italic)
        case .illustration(let asset):
            illustrationBeat(asset: asset)
        case .illustratedExplanation(let asset, let eyebrow, let headline, let italic, let body):
            illustratedExplanationBeat(
                asset: asset, eyebrow: eyebrow,
                headline: headline, italic: italic, body: body
            )
        case .movement(let invitation, _):
            movementBeat(invitation: invitation)
        case .pause(let label):
            pauseBeat(label: label)
        case .close(let line, let italic):
            closeBeat(line: line, italic: italic)
        case .workoutHandoff(let line, let italic, let ctaLabel):
            workoutHandoffBeat(line: line, italic: italic, ctaLabel: ctaLabel)
        }
    }

    /// Phase 9.9 — illustration paired with text in the reference
    /// onboarding pattern. Soft pink rounded square frame holds the
    /// illustration; eyebrow + italic-Fraunces headline + body
    /// paragraph sit below. Matches the screens in IMG_5701/5702/5700.
    private func illustratedExplanationBeat(
        asset: String,
        eyebrow: String,
        headline: String,
        italic: [String],
        body: String
    ) -> some View {
        // Phase 9.18 — tightened heights so the full stack
        // (frame + eyebrow + headline + body) fits without pushing
        // the topBar / footerHint past the safe area:
        //   - frame 280→220, illustration 240→180
        //   - outer spacing Space.lg → Space.md
        //   - eyebrow top padding removed (spacing handles it)
        //   - headline 28→24, lineSpacing 4→2
        //   - body lineSpacing 4→2
        VStack(spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Palette.accentSubtle)
                    .frame(width: 220, height: 220)
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
            }
            .shadow(color: Palette.bgInverse.opacity(0.08), radius: 12, x: 0, y: 6)

            Text(eyebrow)
                .font(Typo.eyebrow)
                .foregroundStyle(Palette.accent)
                .tracking(4)

            ItalicAccentText(
                headline, italic: italic,
                baseFont: .custom("Fraunces72pt-SemiBold", size: 24),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 24),
                color: Palette.textPrimary,
                alignment: .center
            )
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .lineSpacing(2)
            .padding(.horizontal, Space.md)

            Text(body)
                .font(.custom("DMSans-Regular", size: 15))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.lg)
        }
    }

    private func welcomeBeat(line: String, italic: [String]) -> some View {
        VStack(spacing: Space.lg) {
            ItalicAccentText(
                line, italic: italic,
                baseFont: .custom("Fraunces72pt-SemiBold", size: 38),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 38),
                alignment: .center
            )
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.md)

            // Standing safety line — small, ambient, only on the welcome beat.
            Text(ritual.standingSafetyLine)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, Space.md)
        }
    }

    private func lineBeat(text: String, italic: [String]) -> some View {
        // Phase 9.7: Fraunces SemiBold at 28pt for headline impact —
        // matches the reference onboarding screens' visual weight.
        // Italic accents in Fraunces SemiBoldItalic. The 72pt-optical
        // *is* the right choice at display sizes; my earlier complaint
        // about it being "spindly" was at body sizes — at 28pt+ it
        // reads as confident editorial serif, the JeniFit signature.
        ItalicAccentText(
            text, italic: italic,
            baseFont: .custom("Fraunces72pt-SemiBold", size: 28),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 28),
            color: Palette.textPrimary,
            alignment: .center
        )
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .lineSpacing(6)
        .padding(.horizontal, Space.md)
    }

    private func illustrationBeat(asset: String) -> some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 320, maxHeight: 320)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .shadow(color: Palette.bgInverse.opacity(0.15), radius: 18, x: 0, y: 8)
    }

    private func movementBeat(invitation: String) -> some View {
        VStack(spacing: Space.md) {
            Text("move")
                .font(Typo.eyebrow)
                .tracking(4)
                .foregroundStyle(Palette.accent)
            ItalicAccentText(
                invitation, italic: ["roll your shoulders", "three"],
                baseFont: .custom("Fraunces72pt-SemiBold", size: 26),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 26),
                color: Palette.textPrimary,
                alignment: .center
            )
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .lineSpacing(6)
            .padding(.horizontal, Space.md)
        }
    }

    private func pauseBeat(label: String?) -> some View {
        Group {
            if let label {
                // Phase 9.15 — pause labels ("feel that", "stay with
                // it", "almost there", "notice this") render in the
                // same DMSans 14pt accent pink eyebrow treatment as
                // the breath cue — typographic cousins, visually quiet.
                Text(label)
                    .font(.custom("DMSans-SemiBold", size: 14))
                    .foregroundStyle(Color(hex: "#C4677A"))
                    .tracking(5)
                    .textCase(.lowercase)
            } else {
                Color.clear.frame(height: 1)
            }
        }
    }

    private func closeBeat(line: String, italic: [String]) -> some View {
        // Phase 9.15 — fireworks Lottie plays once behind the closing
        // line as the day-1 finale celebration. ZStack so the burst
        // sits behind the text + heart and the text stays the focal
        // point. One-shot (loop: false) — celebrates and settles.
        ZStack {
            LottieEffectView(.fireworks, loop: false)
                .frame(width: 360, height: 360)
                .opacity(0.85)
                .allowsHitTesting(false)

            VStack(spacing: Space.lg) {
                ItalicAccentText(
                    line, italic: italic,
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 32),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 32),
                    alignment: .center
                )
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Space.md)

                Image(systemName: "heart.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Palette.accent)
            }
        }
    }

    /// Phase 9.19 — Day 1's final beat. Closing line + CTA button
    /// that hands off into the user's daily workout. Visually mirrors
    /// `closeBeat` (fireworks behind, italic-Fraunces line, heart
    /// glyph) but adds a solid pill button below as the explicit
    /// action. Tap-to-advance is suppressed on this beat upstream;
    /// the only way forward is the button.
    private func workoutHandoffBeat(line: String, italic: [String], ctaLabel: String) -> some View {
        ZStack {
            LottieEffectView(.fireworks, loop: false)
                .frame(width: 360, height: 360)
                .opacity(0.85)
                .allowsHitTesting(false)

            VStack(spacing: Space.md) {
                ItalicAccentText(
                    line, italic: italic,
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 28),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 28),
                    alignment: .center
                )
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Space.md)

                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Palette.accent)

                // Phase 9.19 — `.ctaPrimary` is the cocoa pill
                // (#3D2A2A bgInverse) — the canonical "do the thing"
                // button per DesignSystem/Components.swift. Cream
                // label, same press feedback (0.98 scale + 0.85
                // opacity) as Get Started / Continue / Subscribe.
                Button {
                    // Same debounce as advance() — prevents double-tap
                    // from launching the workout twice.
                    let now = Date()
                    guard now.timeIntervalSince(lastAdvanceAt) > 0.5 else { return }
                    lastAdvanceAt = now
                    Haptics.heavy()
                    // Phase 9.25 — splash now fades over ~0.9s so the
                    // bloom continuation reads as the ritual itself
                    // slowly settling. Wait a hair longer than the
                    // fade-in (1.0s) so the splash is fully opaque
                    // before the underlying cover swap fires.
                    ritualToWorkoutTransition = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        finishWithWorkoutLaunch()
                    }
                } label: {
                    Text(ctaLabel)
                }
                .buttonStyle(.ctaPrimary)
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
            }
        }
    }

    // MARK: - Persistent breath state

    /// What the ambient breath circle does on each beat type.
    private var persistentBreathState: BreathCircle.State {
        switch currentBeat.kind {
        case .breath(let inhale, let exhale, let repeats):
            return .cycling(inhale: inhale, exhale: exhale, repeats: repeats)
        case .welcome, .close, .workoutHandoff:
            return .holding(scale: 0.5)
        case .line, .movement, .pause:
            return .holding(scale: 0.7)
        case .illustration, .illustratedExplanation:
            return .idle  // image carries the visual; hide the circle
        }
    }

    // MARK: - Footer (skip hint)

    private var footerHint: some View {
        Text(isLastBeat ? "tap when you're ready" : "tap to continue")
            .font(Typo.caption)
            .foregroundStyle(Palette.textPrimary.opacity(0.35))
            .padding(.bottom, Space.md)
    }

    // MARK: - Pacing

    /// Kick off the current beat: fade the content in, schedule the
    /// auto-advance timer. Cancellation via `beatTimerToken` invalidates
    /// stale fires when the user manually advances.
    private func startBeat(at index: Int, fresh: Bool) {
        beatIndex = index
        beatStartedAt = .now
        beatTimerToken = UUID()
        let token = beatTimerToken

        // Fade content in (skip animation on reduce-motion).
        lineOpacity = 0
        if reduceMotion {
            lineOpacity = 1
        } else {
            withAnimation(.easeOut(duration: 0.5)) { lineOpacity = 1 }
        }

        // Schedule auto-advance — only if the beat has a duration.
        if let duration = currentBeat.durationSeconds {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                guard token == beatTimerToken else { return }  // user tapped already
                guard !paused else { return }
                advance()
            }
        }
        _ = fresh  // currently unused; placeholder for future first-beat haptic
    }

    /// Advance to the next beat OR complete the ritual if on the last.
    /// Haptic strength is differentiated per beat type per Phase 9.5
    /// product direction — soft for routine line transitions, medium
    /// for movement + breath transitions, rigid for the satisfaction-
    /// signal beats (halfway / yes / good), success for the midpoint
    /// halfway-marker. Stronger haptics on the meaningful beats give
    /// the ritual its felt-rhythm difference from routine swiping.
    private func advance() {
        // Phase 9.19 — workoutHandoff beat owns its own advance via
        // the CTA button. Tap-anywhere is a no-op so a stray screen
        // tap can't accidentally launch the workout.
        if case .workoutHandoff = currentBeat.kind { return }
        // Phase 9.9 — debounce rapid taps. Without this, tapping the
        // body during the 0.25s fade-out of the previous advance lands
        // on the NEW beat and immediately advances past it. Ignore any
        // tap within 0.5s of the previous advance.
        let now = Date()
        guard now.timeIntervalSince(lastAdvanceAt) > 0.5 else { return }
        lastAdvanceAt = now

        // Snapshot the beat the user is dismissing (the beat the haptic
        // is "for") — we read its id to pick the right haptic vocab.
        let leavingBeat = currentBeat

        // Fade out current line first so the swap reads as a settle, not
        // a snap.
        if !reduceMotion {
            withAnimation(.easeIn(duration: 0.25)) { lineOpacity = 0 }
        }
        let next = beatIndex + 1
        let delay = reduceMotion ? 0 : 0.25
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if next >= ritual.beats.count {
                finish()
            } else {
                fireAdvanceHaptic(leaving: leavingBeat)
                startBeat(at: next, fresh: false)
            }
        }
    }

    /// Picks the haptic strength for the just-left beat. Routine line +
    /// pause transitions get the existing `.soft()`. Beats that earn
    /// stronger acknowledgment (movement, satisfaction signals, breath
    /// completions) get `.medium()` / `.rigid()`; the midpoint
    /// "you're halfway" line additionally fires a `.success()`
    /// notification — explicit micro-relief per Zeigarnik.
    private func fireAdvanceHaptic(leaving beat: LessonBeat) {
        switch beat.id {
        case "movement":
            // Movement was a physical instruction — settle it with a
            // medium impact (the body just did something).
            Haptics.medium()
        case "line_halfway":
            // Midpoint Zeigarnik beat — sharp tap + success
            // notification combo. The "I'm making progress" punch.
            Haptics.rigid()
            Haptics.success()
        case "line_yes", "line_good", "pause_almost_there":
            // Affirmation beats — sharper than soft, doesn't overwhelm.
            Haptics.rigid()
        default:
            switch beat.kind {
            case .breath:
                // Settle out of a breath cycle with medium impact.
                Haptics.medium()
            case .illustration:
                // Image presentation was passive — light dismiss tap.
                Haptics.light()
            default:
                Haptics.soft()
            }
        }
    }

    private func finish() {
        if !isReread {
            JeniMethodState.markLessonCompleted(ritual.id)
            // Heavier completion punch — heavy impact + success
            // notification stacked. Marks the ritual's end clearly
            // distinct from routine beat transitions.
            Haptics.heavy()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Haptics.success()
            }
            if ritual.id == LessonID.day5.rawValue {
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
        onComplete()
    }

    /// Phase 9.19 — Day 1 workout hand-off path. Runs the same
    /// completion bookkeeping as `finish()` (markLessonCompleted,
    /// haptics, analytics) but routes to `onCompleteAndStartWorkout`
    /// when the parent provided one. Falls back to plain onComplete
    /// otherwise so re-read / test callers without a workout
    /// presentation context still dismiss cleanly.
    private func finishWithWorkoutLaunch() {
        if !isReread {
            JeniMethodState.markLessonCompleted(ritual.id)
            Haptics.heavy()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Haptics.success()
            }
        }
        if let handoff = onCompleteAndStartWorkout {
            handoff()
        } else {
            onComplete()
        }
    }

    private func fireLessonViewedOnce() {
        guard !isReread else { return }
        // Phase 9.21 — stamp the once-per-day gate so HomeView won't
        // auto-present another ritual today after this one closes.
        JeniMethodState.markRitualShownToday()
        Analytics.track(
            .dietEducationLessonViewed,
            properties: JeniMethodAnalytics.lessonProps(
                lesson: skippablyResolvedShim, user: user
            )
        )
    }
}

#if DEBUG
#Preview("Day 1 ritual") {
    JeniMethodRitualView(
        lesson: .day1,
        user: .empty,
        onComplete: {},
        onSkip: { _ in }
    )
}
#endif
