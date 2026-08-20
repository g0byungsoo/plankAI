import SwiftUI
import SwiftData
import PlankSync

// MARK: - CoachIntroView
//
// Phase A post-purchase moment — jeni's FIRST LETTER (pass 52). The
// v3-era welcome (illustrated portrait in a pink circle, sparkle
// burst, ambient music) was two eras behind the design law; the
// corridor is a MOMENT (law §1.1b), and the letter is the surface
// where jeni already speaks in sentences. Same anatomy as the morning
// read — name rule, serif body, her signature — so tomorrow's letter
// is already familiar the second time she meets one.
//
// The focal beat picks ONE thing — weight-goal permission (primary) >
// identity feeling > barrier > generic fallback — and the close is
// THE HANDOFF: the sentence door, armed before Home is ever seen.
//
// Voice rules per docs/product_direction_2026.md §4 — no AI signaling,
// lowercase casual, italic-Fraunces on punch words only, no em-dashes
// between words (the letter's signature glyph is the letter's own),
// no negative parallelism, asymmetric care.

struct CoachIntroView: View {
    /// Called when the user taps "let's go". Caller is responsible for
    /// dismissing the cover and presenting the first workout.
    let onContinue: () -> Void

    // MARK: - The handoff (pass 52 — THE FIRST DAY)
    //
    // The intro's LAST beat arms the first real action before Home is
    // ever seen. Pinned by FirstDayActivationTests: the sentence door
    // is the product's cheapest record, so the handoff names it — the
    // old close ("today. five minutes. that's all i'm asking.")
    // promised a workout-era product this build does not ship.
    static let handoffLine = "say your last meal and i'll count it."
    static let handoffItalic = "count"
    static let handoffSub = "a sentence is enough. that's day one started."

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // v8 P8.6: pull active plan to anchor the eyebrow to the user's
    // custom program duration (never hardcode 75 per
    // [[project-program-duration-custom]]).
    @Environment(\.modelContext) private var modelContext

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
    @State private var eyebrowVisible = false
    @State private var greetingVisible = false
    @State private var focalVisible = false
    @State private var todayVisible = false
    @State private var signatureVisible = false
    @State private var ctaVisible = false
    @State private var didAdvance = false

    // MARK: - Body
    //
    // Pass 52 (founder steer, filmed): the intro wore the v3-era
    // welcome theme — illustrated portrait in a pink circle, glossy
    // sparkle burst, pink eyebrow, ambient music. Two eras behind the
    // law. The corridor is a MOMENT (law §1.1b), and the product
    // already owns the surface where jeni speaks in sentences: THE
    // LETTER. This is her first one — the same anatomy the morning
    // read uses (name rule, serif body, her signature), so the second
    // letter she meets tomorrow is already familiar. The portrait and
    // the music die with the era; jeni is a written voice here
    // ("jeni is a digital coach. not a person"), and the mark signs.

    var body: some View {
        // Background lifted to PostPurchaseFlowView so phase swaps
        // cross-fade over one stable paper ground. The letter SCROLLS
        // when accessibility type outgrows the page (the pass-48
        // no-scroll-container law; this pass's own AX5 walk caught the
        // hero truncating to "you made i…" on the SE) — the min-height
        // frame keeps the settled composition identical when it fits.
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: Space.lg)

                    letterRule
                        .padding(.bottom, Space.xl)

                    greeting
                        .padding(.bottom, Space.lg)

                    focalBeat
                        .padding(.bottom, Space.lg)

                    todayLine

                    signature
                        .padding(.top, Space.xl)

                    Spacer(minLength: Space.lg)
                }
                .padding(.horizontal, Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "let's go", action: advance)
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 12)
        }
        .onAppear {
            Analytics.captureScreen("CoachIntro")
            Analytics.track(.coachIntroViewed)
            if reduceMotion {
                runReducedMotion()
            } else {
                runChoreography()
            }
        }
    }

    // MARK: - Sections

    /// The letter's name rule — the same grammar the morning read
    /// carries ("JENI ——— tuesday"), so this surface and tomorrow's
    /// are one object in two moments.
    @Environment(\.dynamicTypeSize) private var typeSize

    private var letterRule: some View {
        // The words never truncate (AX5 rendered "day…"); at
        // accessibility sizes the rule STACKS (the onramp's own
        // stacked-pair law) so both facts stay whole.
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    Text(coachDisplayName.uppercased())
                        .font(Typo.eyebrow)
                        .tracking(1.6)
                        .foregroundStyle(Palette.cocoaTertiary)
                    Text(eyebrowCopy)
                        .font(.custom("JeniHeroSerif-Italic", size: 13, relativeTo: .caption))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            } else {
                HStack(spacing: Space.sm) {
                    Text(coachDisplayName.uppercased())
                        .font(Typo.eyebrow)
                        .tracking(1.6)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize()
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.75)
                        .frame(minWidth: 12)
                    Text(eyebrowCopy)
                        .font(.custom("JeniHeroSerif-Italic", size: 13, relativeTo: .caption))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize()
                }
            }
        }
        .opacity(eyebrowVisible ? 1 : 0)
        .offset(y: eyebrowVisible ? 0 : 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("a letter from \(coachDisplayName). \(eyebrowCopy)")
    }

    private var eyebrowCopy: String {
        let userId = AppSync.shared.currentUserId ?? ""
        if !userId.isEmpty,
           let plan = ProgramService.shared.activePlan(userId: userId, in: modelContext) {
            return "day one of \(plan.totalDays)"
        }
        return "day one"
    }

    private var greeting: some View {
        Group {
            if storedName.isEmpty {
                ItalicAccentText("hi.",
                                 italic: [],
                                 baseFont: greetingFont,
                                 italicFont: greetingItalicFont,
                                 color: Palette.textPrimary,
                                 alignment: .leading)
            } else {
                ItalicAccentText("hi, \(storedName.lowercased()).",
                                 italic: [storedName.lowercased()],
                                 baseFont: greetingFont,
                                 italicFont: greetingItalicFont,
                                 color: Palette.textPrimary,
                                 alignment: .leading)
            }
        }
        .multilineTextAlignment(.leading)
        .opacity(greetingVisible ? 1 : 0)
        .offset(y: greetingVisible ? 0 : 8)
    }

    /// The letter signs the way every jeni letter signs.
    private var signature: some View {
        Text("\u{2014} \(coachDisplayName)")
            .font(.custom("JeniHeroSerif-Italic", size: 18, relativeTo: .body))
            .foregroundStyle(Palette.cocoaSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(signatureVisible ? 1 : 0)
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
                                 alignment: .leading)
            }
        }
        .opacity(focalVisible ? 1 : 0)
        .offset(y: focalVisible ? 0 : 8)
    }

    private var todayLine: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ItalicAccentText(Self.handoffLine,
                             italic: [Self.handoffItalic],
                             baseFont: focalFont,
                             italicFont: focalItalicFont,
                             color: Palette.textPrimary,
                             alignment: .leading)
            Text(Self.handoffSub)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(todayVisible ? 1 : 0)
        .offset(y: todayVisible ? 0 : 8)
    }

    // MARK: - Typography overrides
    //
    // Larger Fraunces sizes than the standard Typo.title (32pt) so the
    // greeting feels like a display headline. focal beat at 22pt sits
    // between body (16pt) and title (32pt) — visually substantial without
    // overwhelming the coach portrait.

    // v3 P11.6 (2026-06-10) — promoted from questionHero 34pt to
    // heroHeadline 42pt per [[feedback-hero-typography-ladder]]. The
    // coach greeting is the first emotional beat post-paywall (lands
    // after ForgingRevealView via PostPurchaseFlowView phase swap) —
    // belongs on the same hero ladder as plan reveal / PacePicker /
    // welcome. Was bumped from 36pt → questionHero in v9 P9.7; this
    // pass takes it the rest of the way.
    private var greetingFont: Font { Typo.heroHeadline }
    private var greetingItalicFont: Font { Typo.heroHeadlineItalic }

    private var focalFont: Font {
        Font.custom("Fraunces72pt-SemiBold", size: 22, relativeTo: .title3)
    }

    private var focalItalicFont: Font {
        Font.custom("Fraunces72pt-SemiBoldItalic", size: 22, relativeTo: .title3)
    }

    // MARK: - Coach lookup

    /// Display name follows the matson → "Sam" rebrand from CLAUDE.md.
    /// Lowercase per voice rules in body text; uppercased in the
    /// letter rule per editorial chrome convention.
    private var coachDisplayName: String {
        switch storedVoice {
        case "balanced":   return "sam"
        case "keepItReal": return "kira"
        default:           return "jeni"
        }
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
                body: "no time. that's the one i hear most. so we keep it small. a sentence counts.",
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
                body: "not sure what to do. that's why i ask for one small thing at a time. nothing to figure out.",
                italics: ["not sure what to do"]
            )
        case "injury":
            return FocalBeat(
                body: "worried about your body. we start where you are. nothing past what it's done.",
                italics: ["worried about your body"]
            )
        default:
            return nil
        }
    }

    // MARK: - Choreography
    //
    // The letter settles in reading order — rule, greeting, beat,
    // handoff, signature, then the door. Same calm cadence the old
    // choreography kept; only the portrait's spring and the sparkle
    // burst died with the theme.

    private func runChoreography() {
        Haptics.success()
        withAnimation(.easeInOut(duration: 0.5).delay(0.15)) { eyebrowVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(0.45)) { greetingVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(1.00)) { focalVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(1.55)) { todayVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(1.95)) { signatureVisible = true }
        withAnimation(.easeInOut(duration: 0.5).delay(2.20)) { ctaVisible = true }
    }

    private func runReducedMotion() {
        eyebrowVisible = true
        greetingVisible = true
        focalVisible = true
        todayVisible = true
        signatureVisible = true
        ctaVisible = true
    }

    private func advance() {
        guard !didAdvance else { return }
        didAdvance = true
        Haptics.medium()
        Analytics.track(.coachIntroContinued)
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

    /// True iff the coach intro has not yet been shown to this user
    /// AND the account doesn't already have prior activity.
    ///
    /// 2026-06-07 — `hasExistingActivity` parameter added (founder bug:
    /// a returning user with Day 4 of session_logs was seeing "DAY 1
    /// WITH JENI" after re-subscribing). The DEBUG bypass that always
    /// returned true is preserved for the no-activity case so devs can
    /// re-test fresh-user flows, but explicit existing activity now
    /// wins even in DEBUG — re-running the post-purchase intro for a
    /// user who's already logged sessions is misleading regardless of
    /// build configuration.
    ///
    /// In production:
    ///   - First-purchase, no prior activity → true (intro shows)
    ///   - Re-purchase after expiry, no prior activity → false (gated
    ///     by `markShown` timestamp; idempotent across relaunches)
    ///   - Re-purchase after expiry, has prior activity → false
    ///     (gated by activity; covers cross-device re-install case
    ///     where the per-device UserDefaults stamp was lost)
    static func shouldShowOnPurchase(hasExistingActivity: Bool = false) -> Bool {
        if hasExistingActivity {
            #if DEBUG
            print("[CoachIntroState] suppressed — account has existing session activity")
            #endif
            return false
        }
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
