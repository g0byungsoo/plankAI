import SwiftUI
import AVFoundation

// MARK: - CoachIntroView
//
// Phase A post-purchase moment. Replaces the 6-minute JeniMethodRitualView
// gate with a tight, single-focal-beat coach welcome.
//
// v3 design (post-user-feedback 2026-05-27):
//   - Layout cleaned up — single hero (coach + sparkle burst), single
//     greeting, single focal beat, single today line, CTA. No more
//     restatement of the entire onboarding dossier on one screen.
//   - Focal beat picks ONE thing — identity feeling (primary,
//     aspirational) > barrier (secondary, validating) > generic fallback.
//     The other personalization signals (weight pace, plank curve, etc.)
//     move to Home / Becoming / tomorrow's push where they get their own
//     moment instead of competing on the first screen.
//   - Bigger typography — display-size Fraunces for the greeting, 22pt
//     Fraunces for the focal beat. Reads as editorial / pretty rather
//     than informational.
//   - Sparkle burst mirrors PremiumWelcomeScreen visual language — keeps
//     the welcome→intro pair feeling like one continuous moment.
//
// Audio: prefers `coach_intro_<voice>.m4a` (~30s dedicated post-purchase
// recording — run Scripts/generate_coach_intro_clips.sh to generate);
// falls back to `method_preview_<voice>.m4a` (the 8s sample) if the
// dedicated files haven't been produced yet, so the screen always has
// some audio rather than silent.
//
// Voice rules per docs/product_direction_2026.md §4 — no AI signaling,
// lowercase casual, italic-Fraunces on punch words only, hearts as
// terminal punctuation only, no em-dashes, no negative parallelism,
// asymmetric care.

struct CoachIntroView: View {
    /// Called when the user taps "let's go". Caller is responsible for
    /// dismissing the cover and presenting the first workout.
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // ── Personalization (read at onAppear via @AppStorage mirrors) ──
    @AppStorage("userName") private var storedName: String = ""
    @AppStorage("voicePreference") private var storedVoice: String = "encouraging"
    @AppStorage("identityFeeling") private var storedIdentityFeeling: String = ""
    @AppStorage("userBarriers") private var storedBarriers: String = ""
    /// Phase A.0 (v4 post-feedback) — re-added so the focal beat can
    /// acknowledge weight loss as the primary motivation when applicable.
    /// Per the welcome-message research synthesis (2026-05-27): use the
    /// GOAL DATE as the load-bearing specific, never the weight number
    /// itself on the welcome screen (post-SkinnyTok-ban register).
    @AppStorage("onboardingCurrentWeightKg") private var currentKg: Double = 0
    @AppStorage("onboardingGoalWeightKg") private var goalKg: Double = 0
    @AppStorage("onboardingGoalDate") private var goalDateInterval: Double = 0

    // ── Animation reveal state ──────────────────────────────────────
    @State private var bgVisible = false
    @State private var coachVisible = false
    @State private var sparkleBurstActive = false
    @State private var sparkleBurstVisible = false
    @State private var eyebrowVisible = false
    @State private var greetingVisible = false
    @State private var focalVisible = false
    @State private var todayVisible = false
    @State private var ctaVisible = false
    @State private var didAdvance = false

    // ── Audio ───────────────────────────────────────────────────────
    @State private var audioPlayer: AVAudioPlayer?

    // ── Sparkle burst placements (mirror PremiumWelcomeScreen) ──────
    // 8 sparkles fanning out from the coach portrait. Scales/offsets
    // tuned for a slightly larger spread than the welcome's heart burst
    // (the coach portrait is bigger than the heart sticker).
    private static let sparkleBurst: [(offset: CGSize, size: CGFloat)] = [
        (CGSize(width:  -88, height: -52), 22),
        (CGSize(width:   86, height: -56), 18),
        (CGSize(width: -100, height:  40), 16),
        (CGSize(width:   98, height:  48), 20),
        (CGSize(width:    0, height: -98), 14),
        (CGSize(width:  -36, height:  90), 12),
        (CGSize(width:   42, height:  96), 14),
        (CGSize(width: -112, height: -16), 12),
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            Palette.bgPrimary
                .ignoresSafeArea()
                .opacity(bgVisible ? 1 : 0)

            // y2k coquette corner scatter behind the content. Hit-test
            // transparent + reduce-motion safe (StickerScatter handles
            // both). Fades with the background so it joins the cross-fade.
            StickerScatter(placements: StickerScatter.coachIntroDefault())
                .opacity(bgVisible ? 1 : 0)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: Space.lg)

                coachPortrait
                    .padding(.bottom, Space.lg)

                eyebrow
                    .padding(.bottom, Space.xs)

                greeting
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.xl)

                focalBeat
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.xl)

                todayLine
                    .padding(.horizontal, Space.lg)

                Spacer(minLength: Space.lg)

                Button(action: advance) {
                    Text("let's go")
                }
                .buttonStyle(.ctaPrimary)
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 12)
            }
        }
        .onAppear {
            Analytics.track(.coachIntroViewed)
            prepareAndPlayAudio()
            if reduceMotion {
                runReducedMotion()
            } else {
                runChoreography()
            }
        }
        .onDisappear {
            stopAudio()
        }
    }

    // MARK: - Sections

    private var coachPortrait: some View {
        ZStack {
            // Sparkle burst fanning out behind the portrait. Same sticker
            // as PremiumWelcomeScreen's heart burst for visual continuity
            // — both screens feel like one moment of arrival.
            ForEach(Self.sparkleBurst.indices, id: \.self) { i in
                let entry = Self.sparkleBurst[i]
                Image(StickerName.sparkleGlossy.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: entry.size, height: entry.size)
                    .opacity(sparkleBurstVisible ? 0.85 : 0)
                    .scaleEffect(sparkleBurstActive ? 1 : 0.4)
                    .offset(sparkleBurstActive ? entry.offset : .zero)
            }

            Circle()
                .fill(Palette.accentSubtle)
                .frame(width: 180, height: 180)
                .scaleEffect(coachVisible ? 1 : 0.5)
                .opacity(coachVisible ? 1 : 0)

            Image(coachAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 164, height: 164)
                .clipShape(Circle())
                .overlay(Circle().stroke(Palette.bgPrimary, lineWidth: 5))
                .scaleEffect(coachVisible ? 1 : 0.6)
                .opacity(coachVisible ? 1 : 0)
        }
        .animation(.spring(response: 0.70, dampingFraction: 0.80), value: coachVisible)
        .accessibilityLabel("\(coachDisplayName), your coach")
    }

    private var eyebrow: some View {
        Text("DAY 1 WITH \(coachDisplayName.uppercased())")
            .font(Typo.eyebrow)
            .tracking(1.6)
            .foregroundStyle(Palette.accent)
            .opacity(eyebrowVisible ? 1 : 0)
            .offset(y: eyebrowVisible ? 0 : 6)
    }

    private var greeting: some View {
        Group {
            if storedName.isEmpty {
                ItalicAccentText("hi. ♥",
                                 italic: [],
                                 baseFont: greetingFont,
                                 italicFont: greetingItalicFont,
                                 color: Palette.textPrimary,
                                 alignment: .center)
            } else {
                ItalicAccentText("hi, \(storedName.lowercased()). ♥",
                                 italic: [storedName.lowercased()],
                                 baseFont: greetingFont,
                                 italicFont: greetingItalicFont,
                                 color: Palette.textPrimary,
                                 alignment: .center)
            }
        }
        .multilineTextAlignment(.center)
        .opacity(greetingVisible ? 1 : 0)
        .offset(y: greetingVisible ? 0 : 8)
    }

    /// The single emotionally resonant beat. Picks ONE detail from
    /// onboarding and engages with it directly — does NOT enumerate every
    /// data point. A real coach picks the thing that mattered most, not
    /// the whole dossier.
    private var focalBeat: some View {
        Group {
            if let beat = focalContent {
                ItalicAccentText(beat.body,
                                 italic: beat.italics,
                                 baseFont: focalFont,
                                 italicFont: focalItalicFont,
                                 color: Palette.textPrimary,
                                 alignment: .center)
            }
        }
        .opacity(focalVisible ? 1 : 0)
        .offset(y: focalVisible ? 0 : 8)
    }

    private var todayLine: some View {
        VStack(spacing: Space.xs) {
            ItalicAccentText("today. five minutes.",
                             italic: ["today"],
                             baseFont: focalFont,
                             italicFont: focalItalicFont,
                             color: Palette.textPrimary,
                             alignment: .center)
            Text("that's all i'm asking.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .opacity(todayVisible ? 1 : 0)
        .offset(y: todayVisible ? 0 : 8)
    }

    // MARK: - Typography overrides
    //
    // Larger Fraunces sizes than the standard Typo.title (32pt) so the
    // greeting feels like a display headline. focal beat at 22pt sits
    // between body (16pt) and title (32pt) — visually substantial without
    // overwhelming the coach portrait.

    private var greetingFont: Font {
        Font.custom("Fraunces72pt-SemiBold", size: 36, relativeTo: .largeTitle)
    }

    private var greetingItalicFont: Font {
        Font.custom("Fraunces72pt-SemiBoldItalic", size: 36, relativeTo: .largeTitle)
    }

    private var focalFont: Font {
        Font.custom("Fraunces72pt-SemiBold", size: 22, relativeTo: .title3)
    }

    private var focalItalicFont: Font {
        Font.custom("Fraunces72pt-SemiBoldItalic", size: 22, relativeTo: .title3)
    }

    // MARK: - Coach lookup

    private var coachAssetName: String {
        switch storedVoice {
        case "balanced":   return "coach-matson"
        case "keepItReal": return "coach-kira"
        default:           return "coach-jeni"   // encouraging or unknown
        }
    }

    /// Display name follows the matson → "Sam" rebrand from CLAUDE.md;
    /// asset prefixes stay legacy. Lowercase per voice rules in body
    /// text; uppercased in the eyebrow per editorial chrome convention.
    private var coachDisplayName: String {
        switch storedVoice {
        case "balanced":   return "sam"
        case "keepItReal": return "kira"
        default:           return "jeni"
        }
    }

    // MARK: - Audio

    /// Ordered audio candidates — coach_intro_* is the dedicated
    /// post-purchase recording (~30s, voice-specific warmth);
    /// method_preview_* is the 8s sample reused as a fallback so the
    /// screen still has audio if the dedicated files haven't been
    /// generated yet (run Scripts/generate_coach_intro_clips.sh).
    private var audioCandidates: [String] {
        switch storedVoice {
        case "balanced":   return ["coach_intro_matson", "method_preview_matson"]
        case "keepItReal": return ["coach_intro_kira",   "method_preview_kira"]
        default:           return ["coach_intro_jeni",   "method_preview_jeni"]
        }
    }

    private func resolveAudioURL() -> URL? {
        for name in audioCandidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "m4a") {
                return url
            }
        }
        return nil
    }

    private func prepareAndPlayAudio() {
        guard let url = resolveAudioURL() else {
            #if DEBUG
            print("[CoachIntro] no audio found for voice=\(storedVoice). text-only fallback.")
            #endif
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayer = player
            // Start audio after the coach portrait + greeting are
            // visible (~1.1s after appear). Lets the visual land first
            // so the voice reads as "jeni materialized and is now
            // speaking to me" rather than disembodied audio playing
            // over an empty fading screen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                player.play()
                Analytics.track(.coachIntroAudioPlayed)
            }
        } catch {
            #if DEBUG
            print("[CoachIntro] audio prep FAILED: \(error)")
            #endif
        }
    }

    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Focal beat picker

    private struct FocalBeat {
        let body: String
        let italics: [String]
    }

    /// Pick the most resonant single beat. Priority order (v4 — post
    /// welcome-message research 2026-05-27):
    ///   1. weightGoalFocalBeat — addresses the user's PRIMARY motivation
    ///      (lose weight) when we have both current + goal weight + date.
    ///      Uses the "permission + date" register the welcome-copy
    ///      research identified as the unfilled niche: explicitly grant
    ///      permission to want the goal, anchor on the date (not the
    ///      weight number — post-SkinnyTok register), and set up the
    ///      first action. This is what brought the user to the app.
    ///   2. identityFeeling — aspirational fallback when no weight goal
    ///      (e.g., growGlutes users); picks up the user's Q140 answer.
    ///   3. topBarrier — validates a vulnerability if no identity set.
    ///   4. generic fallback — "you made it here"
    private var focalContent: FocalBeat? {
        if let beat = weightGoalFocalBeat { return beat }
        if let beat = identityFocalBeat   { return beat }
        if let beat = barrierFocalBeat    { return beat }
        return FocalBeat(
            body: "you made it. that's the hardest part. let's just begin.",
            italics: ["the hardest part"]
        )
    }

    /// The weight-loss permission beat. Three moves the research found
    /// no other welcome screen does together:
    ///   - Names "lose weight" plainly (the goal that brought them here)
    ///   - Grants explicit permission ("that's allowed") — the unfilled
    ///     niche per the 2026-05-27 welcome-message research synthesis;
    ///     post-body-positivity / post-Ozempic discourse has made many
    ///     women feel guilty about wanting this; saying it's okay does
    ///     more emotional work than any aspirational reframe
    ///   - Anchors on the DATE, never the weight number (the Noom move
    ///     adapted to JeniFit voice — pounds live on the Becoming tab
    ///     where the user has earned the right to see them in context)
    ///
    /// Returns nil when we don't have a meaningful weight delta + date,
    /// so users on capability-led goals (fullBody / growGlutes etc.)
    /// gracefully fall through to identityFocalBeat.
    private var weightGoalFocalBeat: FocalBeat? {
        guard currentKg > 0,
              goalKg > 0,
              currentKg > goalKg + 0.5,
              goalDateInterval > 0
        else { return nil }
        let date = Date(timeIntervalSinceReferenceDate: goalDateInterval)
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let dateLabel = f.string(from: date).lowercased()
        return FocalBeat(
            body: "you came here to lose weight. that's allowed. i've got \(dateLabel) in my calendar. let's go there together.",
            italics: ["allowed"]
        )
    }

    /// Identity-feeling reflection — picks up the user's Q140 answer
    /// (powerful / calm / light / strong / radiant) and responds to it
    /// the way a coach would, not the way a dossier would. Each variant
    /// engages with that specific word's emotional texture.
    private var identityFocalBeat: FocalBeat? {
        switch storedIdentityFeeling {
        case "powerful":
            return FocalBeat(
                body: "powerful. you said it like you meant it. let's get to work.",
                italics: ["powerful"]
            )
        case "calm":
            return FocalBeat(
                body: "calm. that's a word people forget to ask for. let's start there.",
                italics: ["calm"]
            )
        case "light":
            return FocalBeat(
                body: "light. like your shoulders dropping after a long day. we'll get there.",
                italics: ["light"]
            )
        case "strong":
            return FocalBeat(
                body: "strong. i can already tell. let's prove it.",
                italics: ["strong"]
            )
        case "radiant":
            return FocalBeat(
                body: "radiant. your skin will tell you first. let's begin.",
                italics: ["radiant"]
            )
        default:
            return nil
        }
    }

    /// Barrier reflection — only shown when no identityFeeling is set.
    /// Validates the user's stated friction by acknowledging it directly,
    /// then names the one mechanic in the plan that addresses it. Avoids
    /// piling barrier resolution on top of identity reframe (that was the
    /// kitchen-sink mistake of v2).
    private var barrierFocalBeat: FocalBeat? {
        let first = storedBarriers.split(separator: ",").first.map(String.init) ?? ""
        switch first {
        case "time":
            return FocalBeat(
                body: "no time. that's the one i hear most. so we keep it small. five minutes.",
                italics: ["no time"]
            )
        case "motivation":
            return FocalBeat(
                body: "hard to stay consistent. honestly, that's most days for most people. i'll be here.",
                italics: ["hard to stay consistent"]
            )
        case "boring":
            return FocalBeat(
                body: "gets boring. fair. i'll keep it small and varied so it doesn't.",
                italics: ["gets boring"]
            )
        case "dontKnow":
            return FocalBeat(
                body: "not sure what to do. that's why every session is guided. nothing to figure out.",
                italics: ["not sure what to do"]
            )
        case "injury":
            return FocalBeat(
                body: "worried about form. we start at your baseline. nothing past what your body's done.",
                italics: ["worried about form"]
            )
        default:
            return nil
        }
    }

    // MARK: - Choreography

    private func runChoreography() {
        Haptics.success()

        // Background cream cross-fades in over a full beat — this is
        // what the user perceives as the cover transition (the iOS
        // slide is suppressed at the caller via Transaction).
        withAnimation(.easeInOut(duration: 0.7)) { bgVisible = true }

        // Coach portrait springs in next, slower curve so it feels
        // grounded rather than bouncy.
        withAnimation(.spring(response: 0.70, dampingFraction: 0.80).delay(0.15)) {
            coachVisible = true
        }

        // Sparkle burst fans out behind the portrait, holds briefly,
        // then fades. Same timing pattern as PremiumWelcomeScreen so
        // the two screens feel like one continuous moment of arrival.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.60)) {
                sparkleBurstActive = true
            }
            withAnimation(.easeOut(duration: 0.40)) {
                sparkleBurstVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
            withAnimation(.easeOut(duration: 0.70)) {
                sparkleBurstVisible = false
            }
        }

        // Text content cascades in over a calm rhythm. Fewer slots than
        // v2 (was 6 sections, now 4) so each has more breathing room.
        withAnimation(.easeInOut(duration: 0.5).delay(0.55)) { eyebrowVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(0.80)) { greetingVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(1.30)) { focalVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(1.85)) { todayVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(2.30)) { ctaVisible = true }
    }

    private func runReducedMotion() {
        bgVisible = true
        coachVisible = true
        sparkleBurstActive = true
        sparkleBurstVisible = true
        eyebrowVisible = true
        greetingVisible = true
        focalVisible = true
        todayVisible = true
        ctaVisible = true
    }

    private func advance() {
        guard !didAdvance else { return }
        didAdvance = true
        Haptics.medium()
        Analytics.track(.coachIntroContinued)
        stopAudio()
        onContinue()
    }
}

// MARK: - CoachIntroState
//
// Post-purchase idempotency for the coach intro. Mirrors
// JeniMethodState.shouldShowOnPurchase but tracks a separate key so the
// curriculum enrollment (fat-loss gated) stays decoupled from the
// universal Jeni welcome. The intro fires for every paying user once;
// the curriculum still requires goal-based opt-in via the home card.

enum CoachIntroState {
    private static let shownAtKey = "coach_intro_shown_at"

    /// True iff the coach intro has not yet been shown to this user.
    /// Idempotent across cold relaunches and restore-purchase flows.
    ///
    /// DEBUG builds bypass the idempotency check so devs can re-test the
    /// welcome flow without having to delete the app between runs. The
    /// `markShown()` write still happens — so production behavior is
    /// preserved when the build flips to release.
    static func shouldShowOnPurchase() -> Bool {
        #if DEBUG
        let already = UserDefaults.standard.object(forKey: shownAtKey) != nil
        if already {
            print("[CoachIntroState] DEBUG bypass — coach_intro_shown_at is set; would block in release. Re-presenting anyway.")
        }
        return true
        #else
        return UserDefaults.standard.object(forKey: shownAtKey) == nil
        #endif
    }

    /// Stamp the timestamp on first show. Re-calls preserve the original
    /// (matches JeniMethodState.markEnrolled semantics).
    static func markShown(now: Date = .now) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: shownAtKey) == nil {
            defaults.set(now, forKey: shownAtKey)
        }
    }

    /// DEBUG-only: wipe the idempotency stamp so the welcome will fire
    /// again on next purchase. Useful for debug menu / manual reset.
    /// No-op in release (since the bypass above means this is unused
    /// in production anyway).
    static func resetForDebug() {
        UserDefaults.standard.removeObject(forKey: shownAtKey)
    }
}

#if DEBUG
#Preview("identity: strong") {
    let _ = {
        UserDefaults.standard.set("han", forKey: "userName")
        UserDefaults.standard.set("encouraging", forKey: "voicePreference")
        UserDefaults.standard.set("strong", forKey: "identityFeeling")
        UserDefaults.standard.set("time", forKey: "userBarriers")
    }()
    return CoachIntroView(onContinue: {})
}

#Preview("identity: calm") {
    let _ = {
        UserDefaults.standard.set("maya", forKey: "userName")
        UserDefaults.standard.set("balanced", forKey: "voicePreference")
        UserDefaults.standard.set("calm", forKey: "identityFeeling")
        UserDefaults.standard.set("", forKey: "userBarriers")
    }()
    return CoachIntroView(onContinue: {})
}

#Preview("barrier only: motivation") {
    let _ = {
        UserDefaults.standard.set("sam", forKey: "userName")
        UserDefaults.standard.set("keepItReal", forKey: "voicePreference")
        UserDefaults.standard.set("", forKey: "identityFeeling")
        UserDefaults.standard.set("motivation", forKey: "userBarriers")
    }()
    return CoachIntroView(onContinue: {})
}

#Preview("generic fallback") {
    let _ = {
        UserDefaults.standard.set("", forKey: "userName")
        UserDefaults.standard.set("encouraging", forKey: "voicePreference")
        UserDefaults.standard.set("", forKey: "identityFeeling")
        UserDefaults.standard.set("", forKey: "userBarriers")
    }()
    return CoachIntroView(onContinue: {})
}
#endif
