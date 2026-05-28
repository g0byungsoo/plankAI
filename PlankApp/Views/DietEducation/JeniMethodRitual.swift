import Foundation

// MARK: - Ritual data model (Phase 9.4 — CorePower-vibe rewrite)
//
// A LessonRitual is a guided 3-minute experience: auto-paced beats that
// flow together with breath, music (Phase 9.4b), and mood lighting.
// Replaces the swipeable card model for the post-purchase flow.
//
// Why a new model: the swipeable-card / Noom-style format the previous
// phase shipped was wrong for this product moment. The target audience
// (TikTok-acquired young women, short attention) doesn't want to read +
// answer quizzes — they want a small ritual that gives them a "I felt
// something" moment in 3 minutes. This model encodes that: timed beats,
// instructor-style single-line cues, breath cycles, mood-driven pacing.
//
// Coexists with the older LessonCard model for now so HomeView card +
// re-read + tests keep working. Migration happens in a follow-up pass.

struct LessonRitual: Equatable {
    let id: Int
    let topic: String
    let beats: [LessonBeat]
    let standingSafetyLine: String  // shown once on welcome beat
    let voice: String

    /// Total ritual runtime for the home-card "today's 4 min moment"
    /// label. Untimed beats default to 6s — most are line beats and
    /// 6s reads at ~14 words.
    var estimatedDurationSeconds: Double {
        beats.reduce(0) { $0 + ($1.durationSeconds ?? 6.0) }
    }
}

struct LessonBeat: Identifiable, Equatable {
    let id: String
    let kind: LessonBeatKind
    /// Auto-advance after this many seconds. `nil` = wait for tap
    /// (used sparingly — defeats the auto-pacing if overused).
    let durationSeconds: Double?
}

enum LessonBeatKind: Equatable {
    /// Opening beat. Big italic-Fraunces line + mood entrance.
    /// Renders the standing safety line as ambient footer.
    case welcome(line: String, italic: [String])

    /// Guided breath. Inhale/exhale/repeats; circle expands + contracts
    /// with the rhythm. No text after the entry cue. Haptic on each beat.
    case breath(inhale: Int, exhale: Int, repeats: Int)

    /// Single instructor line. Fades in, holds, fades out. The workhorse
    /// beat — most ritual content is a sequence of these.
    case line(text: String, italic: [String])

    /// Display an editorial illustration (existing
    /// Assets.xcassets/lesson_*.imageset). Sized large, breathes
    /// against the mood background. Phase 9.9: kept for back-compat
    /// but production-discouraged — illustrations should always pair
    /// with text via `.illustratedExplanation` below.
    case illustration(asset: String)

    /// Phase 9.9 — illustration + text combined. Matches the reference
    /// onboarding pattern: illustration inside a soft pink rounded
    /// square frame on top, eyebrow label below ("heads up", "real
    /// talk", "one more thing"), big italic-Fraunces headline with
    /// inline italic accents, then a body paragraph in DMSans. Use
    /// this for every illustrated beat; standalone `.illustration` is
    /// only for special cases (full-bleed transition cards).
    case illustratedExplanation(
        asset: String,
        eyebrow: String,
        headline: String,
        italic: [String],
        body: String
    )

    /// Movement invitation. Small physical cue ("roll your shoulders")
    /// with optional Lottie animation. Breath circle holds steady.
    case movement(invitation: String, lottieFile: String?)

    /// Silent pause. Breath circle continues, no copy. Lets the
    /// previous beat land. `label` is shown small if non-nil
    /// ("notice this") — usually nil for pure silence.
    case pause(label: String?)

    /// Final beat. Closing line + completion gesture. Triggers the
    /// markLessonCompleted + diet_education_completed flow on advance.
    case close(line: String, italic: [String])

    /// Phase 9.19 — Day 1 hand-off to the user's daily workout. Renders
    /// like `.close` but with an explicit CTA button at the bottom.
    /// Tap-to-advance is suppressed on this beat — only the button
    /// fires (gives the user an opt-out by tapping the X / back
    /// instead of being auto-launched into a workout). The button
    /// triggers `onCompleteAndStartWorkout` on JeniMethodRitualView,
    /// which dismisses the ritual AND launches the routine session.
    case workoutHandoff(line: String, italic: [String], ctaLabel: String)
}

// MARK: - Content (Day 1 only for this pass)
//
// Days 2-5 ship as 3-beat stub rituals until the user has felt Day 1
// and approved the format. Migrating all 5 in one pass with the old
// content model still alive would balloon the change surface — better
// to lock the vibe first.

enum JeniMethodRitualContent {
    /// Single resolver — branches on user goal for the hero line.
    ///
    /// Days 2-5 + generic (day 6+ check-in) currently route through
    /// `stubBeats(label:)` per the comment above the content block —
    /// the canonical content for those days hasn't shipped yet. The
    /// switch previously referenced undefined `day2Beats`/`day3Beats`/
    /// etc. functions, breaking a clean build. Fixed 2026-05-25.
    static func resolve(lesson: LessonID, user: JeniMethodUserContext) -> LessonRitual {
        let voice = JeniMethodContent.voiceForDietContent(user.voicePreference)
        let beats: [LessonBeat]
        switch lesson {
        case .day1:    beats = day1Beats(user: user)
        case .day2:    beats = day2Beats(user: user)
        case .day3:    beats = day3Beats(user: user)
        case .day4:    beats = day4Beats(user: user)
        case .day5:    beats = day5Beats(user: user)
        case .generic: beats = genericBeats(user: user)
        }
        return LessonRitual(
            id: lesson.rawValue,
            topic: lesson.topicSlug,
            beats: beats,
            standingSafetyLine: JeniMethodSafetyLine.text,
            voice: voice
        )
    }

    private static func day1Beats(user: JeniMethodUserContext) -> [LessonBeat] {
        let isFatLoss = JeniMethodContent.goalFrame(for: user.goal) == .fatLossPrimary

        // Phase 9.7 copy refresh — language patterns pulled from
        // Cialdini (unity, authority via specifics, insider language),
        // James Clear (identity-based habits), 12-step sermon cadence.
        // - "we / us" pronouns throughout (unity, in-group framing)
        // - concrete numbers replace vague "more" ("seventy percent",
        //   "a quarter") — authority via specificity
        // - "here's what they don't tell you" — insider/secret framing
        // - identity statements before behavior ("you're someone who's
        //   done with the cycle")
        // - sacred cadence: short declarative sentences, prayer-rhythm
        // - permission language replaces shame
        return [
            // ─── PART 1: ORIENTATION ────────────────────────────────
            // Phase 9.10: Jeni as a personal coach. "I" voice instead
            // of impersonal "we" — Jeni introduces herself, frames
            // what she's about to do, asks for permission. Users
            // arrive here having just paid for a program; Jeni IS the
            // program, not an abstract narrator.

            // Phase 9.20 — name-personalized opener. If onboarding
            // captured a name, prepend it lowercased to match the
            // brand's casual voice. Empty name → unchanged copy.
            LessonBeat(id: "welcome", kind: .welcome(
                line: namedOpener(for: user),
                italic: ["in"]
            ), durationSeconds: 5),

            LessonBeat(id: "intro_jeni", kind: .line(
                text: "i'm jeni. and i'm gonna be right here every day.",
                italic: ["jeni", "every day"]
            ), durationSeconds: 7),

            LessonBeat(id: "intro_made_this", kind: .line(
                text: "i made this because nothing else fit me. and i bet you know that feeling.",
                italic: ["fit"]
            ), durationSeconds: 8),

            LessonBeat(id: "intro_program", kind: .line(
                text: "five minutes a day. every day. that's all i'm asking.",
                italic: ["five minutes"]
            ), durationSeconds: 7),

            LessonBeat(id: "intro_two_things", kind: .line(
                text: "we'll do two things together.",
                italic: ["two things"]
            ), durationSeconds: 5),

            LessonBeat(id: "intro_first_thing", kind: .line(
                text: "i'll teach you one true thing about your body.",
                italic: ["one true thing"]
            ), durationSeconds: 6),

            LessonBeat(id: "intro_second_thing", kind: .line(
                text: "and we'll breathe together.",
                italic: ["breathe"]
            ), durationSeconds: 5),

            LessonBeat(id: "intro_breath_why", kind: .line(
                text: "the breath isn't decorative.",
                italic: ["decorative"]
            ), durationSeconds: 5),

            LessonBeat(id: "intro_breath_purpose", kind: .line(
                text: "it slows you down enough to actually hear what i'm about to tell you.",
                italic: ["hear"]
            ), durationSeconds: 8),

            LessonBeat(id: "intro_begin", kind: .line(
                text: "okay. let's start.",
                italic: ["start"]
            ), durationSeconds: 5),

            // ─── PART 2: THE BREATH ──────────────────────────────────
            LessonBeat(id: "settle_jaw", kind: .line(
                text: "soften your jaw.", italic: ["soften"]
            ), durationSeconds: 4),

            LessonBeat(id: "settle_shoulders", kind: .line(
                text: "drop your shoulders.", italic: ["drop"]
            ), durationSeconds: 4),

            LessonBeat(id: "breath_open", kind: .breath(
                inhale: 4, exhale: 6, repeats: 3
            ), durationSeconds: 30),

            LessonBeat(id: "settle_pause", kind: .pause(label: nil),
                       durationSeconds: 2),

            // ─── THE WHY — identity + insider framing ────────────────
            LessonBeat(id: "line_setup", kind: .line(
                text: isFatLoss ? "this isn't a diet." : "this isn't a quick fix.",
                italic: isFatLoss ? ["diet"] : ["quick fix"]
            ), durationSeconds: 5),

            LessonBeat(id: "line_it_never_was", kind: .line(
                text: "it never was.", italic: ["never"]
            ), durationSeconds: 4),

            LessonBeat(id: "line_we_are_here", kind: .line(
                text: "let me tell you what every diet hides from you.",
                italic: ["hides"]
            ), durationSeconds: 7),

            LessonBeat(id: "pause_a", kind: .pause(label: nil),
                       durationSeconds: 2),

            // ─── THE SCIENCE — concrete numbers (authority) ──────────
            LessonBeat(id: "line_body_burns_clock", kind: .line(
                text: "your body burns around the clock.",
                italic: ["around the clock"]
            ), durationSeconds: 5),

            LessonBeat(id: "line_seventy", kind: .line(
                text: "seventy percent of what you eat fuels you doing nothing.",
                italic: ["seventy percent"]
            ), durationSeconds: 7),

            // Phase 9.20 — experience-branched insider line. Beginners
            // get the "nobody told me either" framing (everyone's first
            // time hearing it). Casual users get "you've heard pieces";
            // experienced get the sharper "you already know — and got
            // told the opposite anyway." Acknowledges what they bring.
            insiderSetupBeat(for: user),

            // Phase 9.9: consolidated science illustration + 3 short
            // text beats into ONE illustratedExplanation beat. Match
            // the reference onboarding pattern (illustration in frame,
            // eyebrow, italic headline, body paragraph).
            LessonBeat(id: "illus_science", kind: .illustratedExplanation(
                asset: "lesson_d1_science",
                eyebrow: "real talk",
                headline: "muscle changes the math.",
                italic: ["math"],
                body: "kg for kg, muscle burns about three times more energy at rest than fat. the more muscle you have, the more your body spends every day — even sitting still. i'll keep coming back to this because most plans get it backwards."
            ), durationSeconds: 16),

            LessonBeat(id: "pause_feel_that", kind: .pause(label: "feel that"),
                       durationSeconds: 3),

            LessonBeat(id: "line_unclench", kind: .line(
                text: "unclench your hands.", italic: ["unclench"]
            ), durationSeconds: 4),

            // ─── THE COST — specific numbers, sermon cadence ─────────
            LessonBeat(id: "line_now_imagine", kind: .line(
                text: "now imagine you eat less. just less.",
                italic: ["less"]
            ), durationSeconds: 5),

            LessonBeat(id: "line_a_quarter", kind: .line(
                text: "a quarter of what you lose isn't fat. it's muscle.",
                italic: ["a quarter", "muscle"]
            ), durationSeconds: 7),

            LessonBeat(id: "line_less_muscle", kind: .line(
                text: "less muscle. lower burn. every day.",
                italic: ["lower burn"]
            ), durationSeconds: 6),

            LessonBeat(id: "line_thats_why", kind: .line(
                text: "that's why it always comes back.",
                italic: ["always"]
            ), durationSeconds: 5),

            LessonBeat(id: "pause_let_it_land", kind: .pause(label: "stay with it"),
                       durationSeconds: 4),

            LessonBeat(id: "line_i_know", kind: .line(
                text: "i know. it's a lot. and it's not your fault.",
                italic: ["not your fault"]
            ), durationSeconds: 7),

            LessonBeat(id: "line_good", kind: .line(
                text: "good. you're still here.",
                italic: ["good"]
            ), durationSeconds: 5),

            // ─── MIDPOINT — breath + identity statement ──────────────
            LessonBeat(id: "breath_mid", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),

            LessonBeat(id: "line_halfway", kind: .line(
                text: "you're halfway through this one. and you're already someone who's done with the cycle.",
                italic: ["done with the cycle"]
            ), durationSeconds: 8),

            LessonBeat(id: "pause_c", kind: .pause(label: nil),
                       durationSeconds: 2),

            // ─── THE SHIFT — permission + sip-sized ─────────────────
            LessonBeat(id: "line_we_do_this", kind: .line(
                text: "so i made this differently.",
                italic: ["differently"]
            ), durationSeconds: 5),

            LessonBeat(id: "line_we_dont_put", kind: .line(
                text: "i'm not gonna put you in a hole and call it discipline.",
                italic: ["hole"]
            ), durationSeconds: 7),

            LessonBeat(id: "line_you_eat", kind: .line(
                text: "you eat.", italic: ["eat"]
            ), durationSeconds: 3),

            LessonBeat(id: "line_you_train", kind: .line(
                text: "you train.", italic: ["train"]
            ), durationSeconds: 3),

            LessonBeat(id: "line_body_keeps_you", kind: .line(
                text: "your body keeps what makes you, you.",
                italic: ["keeps", "you"]
            ), durationSeconds: 5),

            LessonBeat(id: "pause_d", kind: .pause(label: nil),
                       durationSeconds: 2),

            // ─── THE RECOMP WINDOW — illustrated explanation ────────
            // Phase 9.9: consolidated 1 illustration + 4 short lines
            // into ONE illustratedExplanation. Same teaching arc but
            // cleaner — the illustration anchors the moment, eyebrow
            // labels it ("one more thing"), headline + body land it.
            LessonBeat(id: "illus_recomp", kind: .illustratedExplanation(
                asset: "lesson_d1_recomp",
                eyebrow: "one more thing",
                headline: "right now, you're in a rare window.",
                italic: ["rare window"],
                body: "if you're new to training, your body can do something it won't always be able to — lose fat and build muscle at the same time. researchers call it body recomposition. i don't want you to miss it. that's why i'm telling you this first."
            ), durationSeconds: 18),

            // ─── YOUR PLAN — believe + utilize bridge (Phase 9.16) ──
            // Bridges the science arc to the JeniFit product itself.
            // Echoes the user's literal bodyFocus answer (proof we
            // listened — strength reframing already lives in the
            // science block, so we don't paternalize here), names
            // the design rationale (short, settled, not random), and
            // hands them off to today's workout. Sits before the
            // movement celebration because celebration is the
            // emotional landing; this is the practical bridge.

            LessonBeat(id: "line_before_you_go", kind: .line(
                text: "one more thing — before you go.",
                italic: ["before you go"]
            ), durationSeconds: 4),

            LessonBeat(id: "line_plan_listened", kind: .line(
                text: "you said you want \(bodyFocusPhrase(for: user)). the plan i built for you leans there.",
                italic: [bodyFocusPhrase(for: user)]
            ), durationSeconds: 7),

            LessonBeat(id: "line_plan_short", kind: .line(
                text: "short on purpose. five minutes done well beats forty you skip.",
                italic: ["five minutes done well"]
            ), durationSeconds: 7),

            LessonBeat(id: "line_plan_flow", kind: .line(
                text: "every session settles you, builds you, finishes clean. no random shuffle. no junk volume.",
                italic: ["settles", "builds", "finishes clean"]
            ), durationSeconds: 8),

            LessonBeat(id: "pause_ready", kind: .pause(label: "ready"),
                       durationSeconds: 3),

            LessonBeat(id: "line_handoff", kind: .line(
                text: "today's workout is waiting. when you finish here — open it. that's the rest of this.",
                italic: ["the rest of this"]
            ), durationSeconds: 8),

            // ─── MOVEMENT + CELEBRATION ──────────────────────────────
            LessonBeat(id: "movement", kind: .movement(
                invitation: "let's wake the body. roll your shoulders with me. three, slow.",
                lottieFile: nil
            ), durationSeconds: 14),

            LessonBeat(id: "line_yes", kind: .line(
                text: "yes.", italic: ["yes"]
            ), durationSeconds: 3),

            LessonBeat(id: "pause_almost_there", kind: .pause(label: "almost there"),
                       durationSeconds: 3),

            LessonBeat(id: "breath_close", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),

            // ─── CLOSE — identity + workout hand-off ─────────────────
            // Phase 9.19: Day 1's final beat is a workoutHandoff
            // instead of plain close. The closing line lands, then
            // the CTA button launches today's generated workout in
            // one continuous flow. Days 2-5 keep `.close` (they're
            // stubs; no workout to hand off from).
            LessonBeat(id: "pause_final", kind: .pause(label: "notice this"),
                       durationSeconds: 4),

            // Phase 9.20 — identity-feeling-anchored landing line.
            // Echoes the user's Q140 answer ("powerful" / "calm" /
            // "light" / "strong" / "radiant") right before the CTA so
            // the workout reads as the literal next step toward what
            // they said they wanted to feel. Empty identityFeeling
            // falls back to "stronger" — still on-brand.
            identityFeelingBeat(for: user),

            LessonBeat(id: "workout_handoff", kind: .workoutHandoff(
                line: "you showed up. that's who we are now. ready to do it?",
                italic: ["showed up", "ready to do it"],
                ctaLabel: "start today's workout"
            ), durationSeconds: nil),  // hold until user taps CTA
        ]
    }

    /// Phase 9.20 — name-personalized welcome line. Lowercased to
    /// match the brand's casual voice ("sarah. you're in." rather
    /// than "Sarah. You're in."). Trimmed defensively. Empty/whitespace
    /// name falls back to the original generic opener.
    private static func namedOpener(for user: JeniMethodUserContext) -> String {
        let trimmed = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "you're in." }
        return "\(trimmed.lowercased()). you're in."
    }

    /// Phase 9.21 — leading prefix usable in any welcome beat. Empty
    /// when the user has no name, otherwise "[name]. " with trailing
    /// space so call sites append the per-day verbiage cleanly.
    private static func namedPrefix(for user: JeniMethodUserContext) -> String {
        let trimmed = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : "\(trimmed.lowercased()). "
    }

    /// Phase 9.21 — same identityFeeling map used in `identityFeelingBeat`,
    /// reusable across Days 2-5 + generic ritual.
    private static func identityFeelingWord(for user: JeniMethodUserContext) -> String {
        switch user.identityFeeling {
        case "powerful": return "powerful"
        case "calm":     return "calm"
        case "light":    return "light"
        case "strong":   return "strong"
        case "radiant":  return "radiant"
        default:         return "stronger"
        }
    }

    /// Phase 9.20 — branches the "insider setup" line on experience
    /// bucket. Beginners (neverTried + triedFailed) get the existing
    /// "nobody told me either" framing — accurate, everyone's first
    /// time hearing it. Casual users (sometimes) get "you've heard
    /// pieces" — respects they've encountered fitness content but not
    /// this synthesis. Experienced (regularly) get the sharper
    /// "you already know — and got told the opposite anyway." — gives
    /// them credit for what they bring AND positions the conventional
    /// wisdom as the enemy, not them.
    private static func insiderSetupBeat(for user: JeniMethodUserContext) -> LessonBeat {
        let bucket = JeniMethodContent.experienceBucket(for: user.experience)
        let (text, italic): (String, [String])
        switch bucket {
        case .experienced:
            text = "you already know this. and you still got told the opposite."
            italic = ["already know", "opposite"]
        case .casual:
            text = "you've heard pieces of this. nobody put it together."
            italic = ["pieces", "together"]
        case .beginner:
            text = "here's the part nobody told me either."
            italic = ["nobody told me"]
        }
        return LessonBeat(
            id: "line_insider_setup",
            kind: .line(text: text, italic: italic),
            durationSeconds: 6
        )
    }

    /// Phase 9.20 — landing line tied to the user's Q140 identity
    /// feeling. Echoes the literal word they picked so the workout
    /// reads as the next concrete step toward what they said they
    /// wanted. Empty/unknown falls back to "stronger" — universal
    /// and on-brand without making a promise we can't keep.
    private static func identityFeelingBeat(for user: JeniMethodUserContext) -> LessonBeat {
        let phrase: String
        switch user.identityFeeling {
        case "powerful": phrase = "powerful"
        case "calm":     phrase = "calm"
        case "light":    phrase = "light"
        case "strong":   phrase = "strong"
        case "radiant":  phrase = "radiant"
        default:         phrase = "stronger"
        }
        return LessonBeat(
            id: "line_identity_feeling",
            kind: .line(
                text: "this is what \(phrase) looks like at the start.",
                italic: [phrase]
            ),
            durationSeconds: 6
        )
    }

    /// Friendly phrase for the user's onboarding bodyFocus selection,
    /// used in the day-1 "your plan" block. Echoes the user's chosen
    /// words verbatim — the block's purpose is to prove we listened,
    /// not to reframe. Strength language is woven into the science
    /// block elsewhere; this beat trusts the user's stated goal.
    ///
    /// `JeniMethodUserContext.fromAppStorage` currently reads only the
    /// first bodyFocus value (single string in @AppStorage), but the
    /// struct's array shape lets us grow to multi-select without
    /// changing this signature. Empty/unknown falls through to a
    /// neutral "a stronger body" so onboarding-skipped users still
    /// see a complete sentence.
    private static func bodyFocusPhrase(for user: JeniMethodUserContext) -> String {
        let labels: [String: String] = [
            "flatBelly":  "a flat belly",
            "tonedArms":  "toned arms",
            "roundButt":  "round glutes",
            "slimLegs":   "slim legs",
            "fullBody":   "a full body workout"
        ]
        let mapped = user.bodyFocus.compactMap { labels[$0] }
        if mapped.isEmpty { return "a stronger body" }
        if mapped.count == 1 { return mapped[0] }
        if mapped.count == 2 { return "\(mapped[0]) and \(mapped[1])" }
        let head = mapped.dropLast().joined(separator: ", ")
        return "\(head), and \(mapped.last!)"
    }

    // MARK: - Day 2 — consistency wins

    /// Phase 9.21 — Day 2 ritual. Evidence-backed topic: consistency
    /// over intensity. Most weight-loss plans fail to adherence, not
    /// physiology. Short sessions you do beat heroic sessions you
    /// skip — that's the entire shape of the JeniFit method.
    /// Personalizes with name + bodyFocus + identityFeeling.
    private static func day2Beats(user: JeniMethodUserContext) -> [LessonBeat] {
        return [
            // ─── ORIENTATION ───────────────────────────────────────
            LessonBeat(id: "welcome", kind: .welcome(
                line: "\(namedPrefix(for: user))consistency.",
                italic: ["consistency"]
            ), durationSeconds: 5),

            LessonBeat(id: "intro_came_back", kind: .line(
                text: "you came back. that's the whole secret. seriously.",
                italic: ["came back", "the whole secret"]
            ), durationSeconds: 7),

            LessonBeat(id: "intro_today", kind: .line(
                text: "today's the lesson that decides whether this works for you.",
                italic: ["whether this works"]
            ), durationSeconds: 7),

            // ─── BREATH ────────────────────────────────────────────
            LessonBeat(id: "breath_open", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),

            // ─── WHY — programs fail to adherence, not physiology ──
            LessonBeat(id: "line_plans_dont_fail", kind: .line(
                text: "most weight-loss plans don't fail because the plan was wrong.",
                italic: ["weren't wrong"]
            ), durationSeconds: 8),

            LessonBeat(id: "line_they_fail", kind: .line(
                text: "they fail because the person quits. usually inside two weeks.",
                italic: ["two weeks"]
            ), durationSeconds: 8),

            LessonBeat(id: "line_not_weakness", kind: .line(
                text: "it's not weakness. perfect plans demand perfect humans.",
                italic: ["perfect humans"]
            ), durationSeconds: 8),

            // ─── RESEARCH — the one signal that predicts success ────
            LessonBeat(id: "line_study", kind: .line(
                text: "a study of thirty-five thousand people. the ones who lost weight weren't the ones who tried hardest.",
                italic: ["thirty-five thousand", "tried hardest"]
            ), durationSeconds: 10),

            LessonBeat(id: "line_study_punchline", kind: .line(
                text: "they were the ones who came back tomorrow.",
                italic: ["came back tomorrow"]
            ), durationSeconds: 6),

            // ─── ILLUSTRATED EXPLANATION ───────────────────────────
            LessonBeat(id: "illus_consistency", kind: .illustratedExplanation(
                asset: "lesson_d2_consistency",
                eyebrow: "the rule that wins",
                headline: "small you do beats heroic you can't.",
                italic: ["small you do"],
                body: "thirty-five thousand people. the ones who lost weight weren't trying harder. they were just there tomorrow. and the day after. that's the whole thing."
            ), durationSeconds: 16),

            // ─── MIDPOINT ──────────────────────────────────────────
            LessonBeat(id: "breath_mid", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),

            LessonBeat(id: "line_halfway", kind: .line(
                text: "halfway through this one. and you're already someone who came back.",
                italic: ["came back"]
            ), durationSeconds: 8),

            // ─── SHIFT — the rule that beats every other rule ──────
            LessonBeat(id: "line_shift_setup", kind: .line(
                text: "so here's the rule that beats every other rule.",
                italic: ["beats every other rule"]
            ), durationSeconds: 6),

            LessonBeat(id: "line_shift_small", kind: .line(
                text: "small you can do beats heroic you can't.",
                italic: ["small", "heroic"]
            ), durationSeconds: 6),

            LessonBeat(id: "line_shift_math", kind: .line(
                text: "five minutes every day is twenty-five minutes a week. forty-five minutes once isn't.",
                italic: ["every day", "once"]
            ), durationSeconds: 9),

            LessonBeat(id: "line_shift_one_rep", kind: .line(
                text: "even one rep is more than zero. always.",
                italic: ["one rep", "zero"]
            ), durationSeconds: 6),

            LessonBeat(id: "pause_d2_b", kind: .pause(label: nil),
                       durationSeconds: 2),

            // ─── ACTIONABLE — the standard ─────────────────────────
            LessonBeat(id: "line_actionable_intro", kind: .line(
                text: "here's the standard for the next two weeks. only one rule.",
                italic: ["only one rule"]
            ), durationSeconds: 7),

            LessonBeat(id: "line_actionable_one", kind: .line(
                text: "if you can do five minutes, you do five. don't make it optional.",
                italic: ["don't make it optional"]
            ), durationSeconds: 8),

            LessonBeat(id: "line_actionable_two", kind: .line(
                text: "miss a day? next day, show up smaller. never skip to 'make up.'",
                italic: ["show up smaller", "never"]
            ), durationSeconds: 8),

            // ─── MOVEMENT + HANDOFF ────────────────────────────────
            LessonBeat(id: "movement", kind: .movement(
                invitation: "clap your hands once. you showed up today. that counts.",
                lottieFile: nil
            ), durationSeconds: 12),

            LessonBeat(id: "pause_almost", kind: .pause(label: "almost there"),
                       durationSeconds: 3),

            LessonBeat(id: "line_d2_identity", kind: .line(
                text: "this is what \(identityFeelingWord(for: user)) actually looks like. boring. repeatable. real.",
                italic: [identityFeelingWord(for: user), "repeatable"]
            ), durationSeconds: 9),

            LessonBeat(id: "workout_handoff", kind: .workoutHandoff(
                line: "small session waiting. let's not skip it.",
                italic: ["not skip"],
                ctaLabel: "start today's workout"
            ), durationSeconds: nil),
        ]
    }

    // MARK: - Day 3 — the invisible burn (NEAT)

    /// Phase 9.21 — Day 3 ritual. Evidence-backed topic: Non-Exercise
    /// Activity Thermogenesis. Daily steps + general movement
    /// outside the gym is a 300-800 kcal/day burn — bigger than most
    /// people's workouts. The silent multiplier most users miss.
    private static func day3Beats(user: JeniMethodUserContext) -> [LessonBeat] {
        return [
            // ─── ORIENTATION ───────────────────────────────────────
            LessonBeat(id: "welcome", kind: .welcome(
                line: "\(namedPrefix(for: user))the invisible burn.",
                italic: ["invisible burn"]
            ), durationSeconds: 5),

            LessonBeat(id: "intro_three", kind: .line(
                text: "you're already in the top ten percent of people who bought this. seriously.",
                italic: ["top ten percent"]
            ), durationSeconds: 9),

            // ─── BREATH ────────────────────────────────────────────
            LessonBeat(id: "breath_open", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),

            // ─── WHY — the silent burn most people miss ─────────────
            LessonBeat(id: "line_today_about", kind: .line(
                text: "today's the thing that does more for fat loss than any workout you'll ever do.",
                italic: ["more than any workout"]
            ), durationSeconds: 9),

            LessonBeat(id: "line_setup_secret", kind: .line(
                text: "scientists call it NEAT. non-exercise activity thermogenesis. ugly name. life-changing concept.",
                italic: ["NEAT", "life-changing"]
            ), durationSeconds: 10),

            LessonBeat(id: "line_neat_explain", kind: .line(
                text: "it's every calorie you burn that isn't workout, sleep, or digestion.",
                italic: ["every calorie"]
            ), durationSeconds: 8),

            LessonBeat(id: "line_neat_examples", kind: .line(
                text: "standing. walking. taking stairs. carrying groceries. fidgeting in your chair.",
                italic: ["fidgeting"]
            ), durationSeconds: 8),

            // ─── DATA — how big it is ──────────────────────────────
            LessonBeat(id: "line_data_big", kind: .line(
                text: "for an average woman, NEAT can be three hundred to eight hundred calories a day.",
                italic: ["three hundred to eight hundred"]
            ), durationSeconds: 9),

            LessonBeat(id: "line_data_compare", kind: .line(
                text: "that's more than most thirty-minute workouts. every single day.",
                italic: ["more than most"]
            ), durationSeconds: 8),

            // ─── ILLUSTRATED EXPLANATION ───────────────────────────
            LessonBeat(id: "illus_neat", kind: .illustratedExplanation(
                asset: "lesson_d3_neat",
                eyebrow: "the invisible burn",
                headline: "your steps add up to more than your workout.",
                italic: ["more than your workout"],
                body: "standing, walking, taking stairs — non-exercise activity can be three hundred to eight hundred calories a day. bigger than most sessions. and it costs nothing."
            ), durationSeconds: 16),

            LessonBeat(id: "line_cost_sitting", kind: .line(
                text: "sit eight hours straight — your NEAT crashes. all the workout in the world won't fix that.",
                italic: ["crashes", "won't fix"]
            ), durationSeconds: 10),

            LessonBeat(id: "pause_let_it_land", kind: .pause(label: "stay with it"),
                       durationSeconds: 3),

            // ─── MIDPOINT ──────────────────────────────────────────
            LessonBeat(id: "breath_mid", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),

            LessonBeat(id: "line_halfway", kind: .line(
                text: "halfway through this one. it's free. you don't need a gym. just a body that moves.",
                italic: ["free"]
            ), durationSeconds: 9),

            // ─── SHIFT — actionable NEAT ───────────────────────────
            LessonBeat(id: "line_shift_intro", kind: .line(
                text: "so here's the standard. it's tiny. it's stupid easy. and it works.",
                italic: ["tiny", "works"]
            ), durationSeconds: 8),

            LessonBeat(id: "line_shift_steps", kind: .line(
                text: "aim for six thousand steps a day to start. work up to eight thousand over a month.",
                italic: ["six thousand", "eight thousand"]
            ), durationSeconds: 10),

            LessonBeat(id: "line_shift_walk_after", kind: .line(
                text: "walk ten minutes after your bigger meals. helps digestion, drops blood sugar, adds steps.",
                italic: ["ten minutes"]
            ), durationSeconds: 9),

            LessonBeat(id: "line_shift_stand_up", kind: .line(
                text: "stand up every thirty minutes. once. that's it. set a timer if you have to.",
                italic: ["thirty minutes"]
            ), durationSeconds: 8),

            LessonBeat(id: "pause_d3_b", kind: .pause(label: nil),
                       durationSeconds: 2),

            // ─── MOVEMENT ──────────────────────────────────────────
            LessonBeat(id: "movement", kind: .movement(
                invitation: "stand up. roll your shoulders. take ten steps. doesn't matter where.",
                lottieFile: nil
            ), durationSeconds: 14),

            LessonBeat(id: "line_yes", kind: .line(
                text: "that's neat in action. literally.",
                italic: ["neat", "literally"]
            ), durationSeconds: 5),

            // ─── CLOSE + HANDOFF ───────────────────────────────────
            LessonBeat(id: "pause_almost", kind: .pause(label: "almost there"),
                       durationSeconds: 3),

            LessonBeat(id: "line_d3_identity", kind: .line(
                text: "\(identityFeelingWord(for: user)) gets built between sessions. steps count.",
                italic: [identityFeelingWord(for: user), "between sessions"]
            ), durationSeconds: 8),

            LessonBeat(id: "workout_handoff", kind: .workoutHandoff(
                line: "session first. then walk after dinner. that's today's whole plan.",
                italic: ["walk after"],
                ctaLabel: "start today's workout"
            ), durationSeconds: nil),
        ]
    }

    // MARK: - Day 4 — "eat to fuel" (ED-sensitive)

    /// Phase 9.21 — Day 4 ritual. Topic: food as fuel.
    ///
    /// ED-sensitivity rules locked into this beat set:
    /// - NO calorie / gram / macro / portion numbers
    /// - NO restriction language ("cut", "less", "smaller", "clean")
    /// - NO "earn it" framing
    /// - NO good/bad food binary
    /// - NO before/after, weight-loss-by-X-date promises
    /// - Food is fuel, never penance
    private static func day4Beats(user: JeniMethodUserContext) -> [LessonBeat] {
        return [
            // ─── ORIENTATION ───────────────────────────────────────
            LessonBeat(id: "welcome", kind: .welcome(
                line: "\(namedPrefix(for: user))the food talk.",
                italic: ["food talk"]
            ), durationSeconds: 5),

            LessonBeat(id: "intro_one_food_rule", kind: .line(
                text: "today's the food talk. and i've got exactly one rule worth caring about.",
                italic: ["exactly one rule"]
            ), durationSeconds: 9),

            LessonBeat(id: "intro_no_counting", kind: .line(
                text: "nothing to count. nothing to cut. no foods you're not allowed.",
                italic: ["nothing"]
            ), durationSeconds: 8),

            // ─── BREATH ────────────────────────────────────────────
            LessonBeat(id: "breath_open", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),

            // ─── WHY — protein is the muscle stay-signal ───────────
            LessonBeat(id: "line_one_thing", kind: .line(
                text: "the one thing that decides whether your body keeps muscle while you lose fat — protein.",
                italic: ["protein"]
            ), durationSeconds: 9),

            LessonBeat(id: "line_protein_why", kind: .line(
                text: "protein is the literal building block of muscle. and it tells your body 'keep this part.'",
                italic: ["building block", "keep this part"]
            ), durationSeconds: 10),

            LessonBeat(id: "line_protein_bonus", kind: .line(
                text: "it also makes you full longer than carbs or fat. and it takes more energy just to digest.",
                italic: ["full longer", "more energy"]
            ), durationSeconds: 10),

            // ─── ILLUSTRATED EXPLANATION ───────────────────────────
            LessonBeat(id: "illus_protein", kind: .illustratedExplanation(
                asset: "lesson_d4_protein",
                eyebrow: "one rule",
                headline: "protein at every meal. that's it.",
                italic: ["that's it"],
                body: "a palm-sized portion. chicken, fish, eggs, greek yogurt, tofu, beans. no counting, no apps, no rules beyond this. three meals, three palms. done."
            ), durationSeconds: 16),

            // ─── COST — low protein wrecks the deficit ─────────────
            LessonBeat(id: "line_cost_low", kind: .line(
                text: "low protein during weight loss — you lose more muscle than fat. you stay hungry. you get tired.",
                italic: ["more muscle than fat"]
            ), durationSeconds: 10),

            LessonBeat(id: "line_cost_skinny_fat", kind: .line(
                text: "that's the 'i lost weight but i look softer' story. always the same culprit.",
                italic: ["always the same"]
            ), durationSeconds: 9),

            LessonBeat(id: "pause_let_it_land", kind: .pause(label: "stay with it"),
                       durationSeconds: 3),

            // ─── MIDPOINT ──────────────────────────────────────────
            LessonBeat(id: "breath_mid", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),

            LessonBeat(id: "line_halfway", kind: .line(
                text: "halfway through this one. and you're about to be done thinking about food the hard way.",
                italic: ["done thinking"]
            ), durationSeconds: 9),

            // ─── SHIFT — the actionable rule ───────────────────────
            LessonBeat(id: "line_shift_intro", kind: .line(
                text: "so here's the rule. just one.",
                italic: ["just one"]
            ), durationSeconds: 5),

            LessonBeat(id: "line_shift_rule", kind: .line(
                text: "three real meals a day. protein at every meal. a palm-sized portion is enough.",
                italic: ["three real meals", "palm-sized"]
            ), durationSeconds: 10),

            LessonBeat(id: "line_shift_what", kind: .line(
                text: "chicken. fish. eggs. greek yogurt. tofu. beans. cottage cheese. pick what you'll actually eat.",
                italic: ["what you'll actually eat"]
            ), durationSeconds: 10),

            LessonBeat(id: "line_shift_check", kind: .line(
                text: "no tracking. no apps. just a daily check — did i get protein in three meals today?",
                italic: ["no apps", "three meals"]
            ), durationSeconds: 10),

            // ─── ANTI-RESTRICTION REINFORCEMENT ────────────────────
            LessonBeat(id: "line_no_earn", kind: .line(
                text: "and you never earn food by working out. you eat because you're alive.",
                italic: ["never", "alive"]
            ), durationSeconds: 8),

            LessonBeat(id: "pause_d4_b", kind: .pause(label: nil),
                       durationSeconds: 2),

            // ─── MOVEMENT ──────────────────────────────────────────
            LessonBeat(id: "movement", kind: .movement(
                invitation: "hand on your belly. one slow breath. that body is your home.",
                lottieFile: nil
            ), durationSeconds: 12),

            // ─── CLOSE + HANDOFF ───────────────────────────────────
            LessonBeat(id: "pause_almost", kind: .pause(label: "almost there"),
                       durationSeconds: 3),

            LessonBeat(id: "line_d4_identity", kind: .line(
                text: "\(identityFeelingWord(for: user)) doesn't come from skipping lunch. it comes from eating it. with protein.",
                italic: [identityFeelingWord(for: user), "eating it"]
            ), durationSeconds: 10),

            LessonBeat(id: "workout_handoff", kind: .workoutHandoff(
                line: "fueled up. today's session is waiting.",
                italic: ["fueled up"],
                ctaLabel: "start today's workout"
            ), durationSeconds: nil),
        ]
    }

    // MARK: - Day 5 — sleep, cortisol, recovery (ED-sensitive)

    /// Phase 9.21 — Day 5 ritual. Evidence-backed topic: sleep is
    /// the underrated weight-loss multiplier. <7hr sleep raises
    /// ghrelin + lowers leptin → ~300 extra kcal next day without
    /// noticing. Stretching at night drops cortisol → deeper sleep →
    /// better recovery. The thing no one tells you about fat loss.
    ///
    /// ED-sensitivity rules: no body-shape promises, no calorie
    /// tracking, frame sleep as self-care not optimization.
    private static func day5Beats(user: JeniMethodUserContext) -> [LessonBeat] {
        return [
            // ─── ORIENTATION ───────────────────────────────────────
            LessonBeat(id: "welcome", kind: .welcome(
                line: "\(namedPrefix(for: user))the multiplier.",
                italic: ["multiplier"]
            ), durationSeconds: 5),

            LessonBeat(id: "intro_made_it", kind: .line(
                text: "you made it to the last lesson. and it's the one nobody talks about.",
                italic: ["last lesson", "nobody talks about"]
            ), durationSeconds: 9),

            LessonBeat(id: "intro_topic", kind: .line(
                text: "today is sleep. and the thing your body needs more than another workout.",
                italic: ["sleep", "more than another workout"]
            ), durationSeconds: 9),

            // ─── BREATH ────────────────────────────────────────────
            LessonBeat(id: "breath_open", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),

            // ─── WHY — sleep is a hunger hormone game ──────────────
            LessonBeat(id: "line_under_seven", kind: .line(
                text: "sleep less than seven hours, and your hunger hormones change. by morning.",
                italic: ["seven hours", "change"]
            ), durationSeconds: 9),

            LessonBeat(id: "line_hungry_more", kind: .line(
                text: "you wake up hungrier. you crave sugar. you eat about three hundred extra calories without noticing.",
                italic: ["three hundred extra", "without noticing"]
            ), durationSeconds: 11),

            LessonBeat(id: "line_cortisol", kind: .line(
                text: "bad sleep also keeps your stress hormone up. cortisol. that holds fat — especially around your middle.",
                italic: ["cortisol", "around your middle"]
            ), durationSeconds: 11),

            // ─── ILLUSTRATED EXPLANATION ───────────────────────────
            LessonBeat(id: "illus_sleep", kind: .illustratedExplanation(
                asset: "lesson_d5_sleep",
                eyebrow: "the multiplier",
                headline: "rest is offensive, not optional.",
                italic: ["offensive"],
                body: "seven to nine hours. same bedtime. five minutes of stretching before you lie down. this is the part that decides if everything else works."
            ), durationSeconds: 16),

            // ─── COST — silent saboteur ────────────────────────────
            LessonBeat(id: "line_cost", kind: .line(
                text: "you can train perfectly. eat protein. walk your steps. and chronic bad sleep will stall every bit of it.",
                italic: ["chronic bad sleep", "stall"]
            ), durationSeconds: 11),

            LessonBeat(id: "line_silent", kind: .line(
                text: "it's the silent thing. and it's the thing most weight-loss plans never mention.",
                italic: ["silent", "never mention"]
            ), durationSeconds: 9),

            LessonBeat(id: "pause_let_it_land", kind: .pause(label: "stay with it"),
                       durationSeconds: 3),

            // ─── MIDPOINT ──────────────────────────────────────────
            LessonBeat(id: "breath_mid", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),

            LessonBeat(id: "line_halfway", kind: .line(
                text: "halfway through the last lesson. and rest is offensive — it's not the absence of work.",
                italic: ["offensive", "absence"]
            ), durationSeconds: 9),

            // ─── SHIFT — actionable ────────────────────────────────
            LessonBeat(id: "line_shift_intro", kind: .line(
                text: "so here's the standard. tonight, two things. that's all i'll ever ask of you.",
                italic: ["two things"]
            ), durationSeconds: 9),

            LessonBeat(id: "line_shift_hours", kind: .line(
                text: "seven to nine hours of sleep. same bedtime, same wake time. weekends too.",
                italic: ["seven to nine", "weekends too"]
            ), durationSeconds: 9),

            LessonBeat(id: "line_shift_phone", kind: .line(
                text: "phone away thirty minutes before bed. screen light blocks the hormone that puts you to sleep.",
                italic: ["thirty minutes", "blocks the hormone"]
            ), durationSeconds: 11),

            LessonBeat(id: "line_shift_stretch", kind: .line(
                text: "and five minutes of stretching before you lie down. it tells your body the day is done.",
                italic: ["five minutes of stretching", "the day is done"]
            ), durationSeconds: 11),

            LessonBeat(id: "pause_d5_b", kind: .pause(label: nil),
                       durationSeconds: 2),

            // ─── MOVEMENT ──────────────────────────────────────────
            LessonBeat(id: "movement", kind: .movement(
                invitation: "roll your neck. one slow circle each way. feel the release.",
                lottieFile: nil
            ), durationSeconds: 14),

            // ─── CLOSE + HANDOFF ───────────────────────────────────
            LessonBeat(id: "pause_almost", kind: .pause(label: "almost there"),
                       durationSeconds: 3),

            LessonBeat(id: "line_d5_identity", kind: .line(
                text: "this is what \(identityFeelingWord(for: user)) actually feels like. rested. not depleted.",
                italic: [identityFeelingWord(for: user), "rested"]
            ), durationSeconds: 9),

            LessonBeat(id: "line_d5_keep_going", kind: .line(
                text: "the program is yours now. one session, one bedtime, one day at a time.",
                italic: ["yours now"]
            ), durationSeconds: 10),

            LessonBeat(id: "workout_handoff", kind: .workoutHandoff(
                line: "let's close this the way we close every day. with the work.",
                italic: ["close every day", "the work"],
                ctaLabel: "start today's workout"
            ), durationSeconds: nil),
        ]
    }

    // MARK: - Module 6 — short pre-workout warmup

    /// Phase 9.23 — Module 6 runs daily after the 5-lesson arc
    /// completes. Tight pre-workout warmup: name greeting → one
    /// breath cycle → rotating intention cue → workout hand-off.
    /// ~45-55 seconds total. The intention rotates on a 3-day cycle
    /// (form / breath / quality) so daily users see a different cue
    /// each day without weekday calendar drift.
    private static func genericBeats(user: JeniMethodUserContext) -> [LessonBeat] {
        let intention = dailyIntention(for: .now)

        return [
            // ─── OPEN ──────────────────────────────────────────────
            LessonBeat(id: "welcome", kind: .welcome(
                line: "\(namedPrefix(for: user))quick warmup.",
                italic: ["warmup"]
            ), durationSeconds: 5),

            LessonBeat(id: "line_intro", kind: .line(
                text: "today's session is short. let's make it count.",
                italic: ["make it count"]
            ), durationSeconds: 6),

            // ─── BREATH — single 4/6 cycle to settle ───────────────
            LessonBeat(id: "breath_open", kind: .breath(
                inhale: 4, exhale: 6, repeats: 1
            ), durationSeconds: 10),

            // ─── INTENTION — rotating daily cue ────────────────────
            LessonBeat(id: "line_intention", kind: .line(
                text: intention.text,
                italic: intention.italic
            ), durationSeconds: 8),

            // ─── BODY READY ────────────────────────────────────────
            LessonBeat(id: "line_body", kind: .line(
                text: "shoulders down. one breath out. you're ready.",
                italic: ["ready"]
            ), durationSeconds: 6),

            // ─── HANDOFF ───────────────────────────────────────────
            LessonBeat(id: "workout_handoff", kind: .workoutHandoff(
                line: "let's go.",
                italic: ["let's go"],
                ctaLabel: "start today's workout"
            ), durationSeconds: nil),
        ]
    }

    /// Phase 9.23 — three rotating intention cues for the Module 6
    /// pre-workout warmup, picked by day-of-year mod 3 so each
    /// consecutive day shows a different one. Topics rotate through
    /// the three things that matter most during the actual session:
    /// form, breath, and quality.
    private static func dailyIntention(for date: Date) -> (text: String, italic: [String]) {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        switch day % 3 {
        case 0:
            return ("one thing today — quality over speed. a good slow rep beats three sloppy fast ones.",
                    ["quality over speed"])
        case 1:
            return ("one thing today — breathe through the hard parts. don't hold it.",
                    ["breathe through"])
        default:
            return ("one thing today — focus on form. the result follows the form.",
                    ["focus on form"])
        }
    }

    private static func stubBeats(label: String) -> [LessonBeat] {
        // Placeholder for Days 2-5 until content is written. Three beats
        // so the ritual flow is still demoable for these days.
        [
            LessonBeat(id: "welcome", kind: .welcome(
                line: "\(label). coming soon.",
                italic: [label]
            ), durationSeconds: 5),
            LessonBeat(id: "breath", kind: .breath(
                inhale: 4, exhale: 6, repeats: 2
            ), durationSeconds: 20),
            LessonBeat(id: "close", kind: .close(
                line: "come back when this is ready.",
                italic: ["ready"]
            ), durationSeconds: nil),
        ]
    }
}
