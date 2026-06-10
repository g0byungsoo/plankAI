import Foundation

// MARK: - Lesson page model (Phase 10 — primer-style rewrite)
//
// Replaces the auto-paced beat engine (welcome → breath circle → one line
// at a time) with a short sequence of static, tappable "pages" modeled on
// the breathwork-primer screen: pink gradient + sticker scatter, an
// optional paper-craft illustration in a rounded frame, an eyebrow, a big
// italic-Fraunces headline, a body paragraph, an optional citation, an
// optional one-line breath cue, and a pinned CTA. No center bubble, no
// auto-advance — the user taps "continue" to move on; the final page hands
// off to today's workout.
//
// Day 1 is a ~4-page welcome (it has the most to say). Days 2-14 are tight
// 2-page drops: one illustrated fact, one action + identity. The generic
// Day 15+ ritual is a single warmup page.

struct LessonPage: Identifiable, Equatable {
    let id: String
    /// Paper-craft illustration asset, shown in a pink rounded frame.
    /// nil = a text/sticker page. Mutually exclusive with `sticker`.
    let illustration: String?
    /// Single glossy sticker accent for text/action pages (no illustration).
    let sticker: StickerName?
    let eyebrow: String?
    let headline: String
    let italic: [String]
    let body: String?
    /// Small gray research credit under the body (fact pages) — reinforces
    /// the "this is real" signal without overclaiming.
    let citation: String?
    /// Calm one-line breath cue under the body (intro pages only) — the
    /// folded-in replacement for the removed animated breath beat.
    let breathLine: String?
    let ctaLabel: String
    /// Final page of a lesson — its CTA launches today's workout.
    let isHandoff: Bool

    init(
        id: String,
        illustration: String? = nil,
        sticker: StickerName? = nil,
        eyebrow: String? = nil,
        headline: String,
        italic: [String] = [],
        body: String? = nil,
        citation: String? = nil,
        breathLine: String? = nil,
        ctaLabel: String,
        isHandoff: Bool = false
    ) {
        self.id = id
        self.illustration = illustration
        self.sticker = sticker
        self.eyebrow = eyebrow
        self.headline = headline
        self.italic = italic
        self.body = body
        self.citation = citation
        self.breathLine = breathLine
        self.ctaLabel = ctaLabel
        self.isHandoff = isHandoff
    }
}

struct LessonScript: Equatable {
    let id: Int
    let topic: String
    let pages: [LessonPage]
    let standingSafetyLine: String   // shown subtly in the page footer
    let voice: String
}

// MARK: - Content + resolver

enum JeniMethodRitualContent {

    /// Single resolver — branches on the per-day page builder. Day 1
    /// additionally branches on user goal; every day personalizes via
    /// name + identityFeeling + bodyFocus inside its builder.
    static func resolve(lesson: LessonID, user: JeniMethodUserContext) -> LessonScript {
        let voice = JeniMethodContent.voiceForDietContent(user.voicePreference)
        let pages: [LessonPage]
        switch lesson {
        case .day1:    pages = day1Pages(user: user)
        case .day2:    pages = day2Pages(user: user)
        case .day3:    pages = day3Pages(user: user)
        case .day4:    pages = day4Pages(user: user)
        case .day5:    pages = day5Pages(user: user)
        case .day6:    pages = day6Pages(user: user)
        case .day7:    pages = day7Pages(user: user)
        case .day8:    pages = day8Pages(user: user)
        case .day9:    pages = day9Pages(user: user)
        case .day10:   pages = day10Pages(user: user)
        case .day11:   pages = day11Pages(user: user)
        case .day12:   pages = day12Pages(user: user)
        case .day13:   pages = day13Pages(user: user)
        case .day14:   pages = day14Pages(user: user)
        case .generic: pages = genericPages(user: user)
        }
        return LessonScript(
            id: lesson.rawValue,
            topic: lesson.topicSlug,
            pages: pages,
            standingSafetyLine: JeniMethodSafetyLine.text,
            voice: voice
        )
    }

    // MARK: - Personalization helpers

    /// Leading "[name]. " prefix (lowercased, casual) usable in any
    /// headline, or "" when the user has no name.
    private static func namedPrefix(for user: JeniMethodUserContext) -> String {
        let trimmed = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : "\(trimmed.lowercased()). "
    }

    /// The user's Q140 identity feeling as a word, defaulting to
    /// "stronger" — universal and on-brand without promising a body.
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

    /// Friendly phrase for the user's onboarding bodyFocus selection.
    /// Echoes their chosen words verbatim; empty falls through to a
    /// neutral "a stronger body" so onboarding-skipped users see a
    /// complete sentence.
    private static func bodyFocusPhrase(for user: JeniMethodUserContext) -> String {
        let labels: [String: String] = [
            "flatBelly":  "a flat belly",
            "tonedArms":  "toned arms",
            "roundButt":  "round glutes",
            "slimLegs":   "slim legs",
            "fullBody":   "a full body workout",
        ]
        let mapped = user.bodyFocus.compactMap { labels[$0] }
        if mapped.isEmpty { return "a stronger body" }
        if mapped.count == 1 { return mapped[0] }
        if mapped.count == 2 { return "\(mapped[0]) and \(mapped[1])" }
        let head = mapped.dropLast().joined(separator: ", ")
        return "\(head), and \(mapped.last!)"
    }

    /// Rotating one-line breath cue for a lesson's intro page. Replaces
    /// the old animated breath beat — same calming intent, no bubble.
    private static func breathLine(day: Int) -> String {
        switch day % 4 {
        case 2:  return "first, two soft breaths in. one long breath out."
        case 3:  return "first, in for five, out for five. find the even line."
        case 0:  return "first, slow it down. in for four, out for seven."
        default: return "first, one slow breath. make the exhale the long part."
        }
    }

    // MARK: - Day 1 — the welcome (recomp / muscle math)

    /// Day 1 keeps the full welcome substance (Jeni intro, the muscle
    /// math, the recomp window, the plan + handoff) but re-presented as
    /// four primer pages instead of the long beat ritual. Branches on
    /// goal frame for the opening reframe line.
    private static func day1Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let isFatLoss = JeniMethodContent.goalFrame(for: user.goal) == .fatLossPrimary
        let word = identityFeelingWord(for: user)
        let openReframe = isFatLoss ? "this isn't a diet. it never was." : "this isn't a quick fix."
        return [
            LessonPage(
                id: "welcome",
                sticker: .bowSatin,
                eyebrow: "day 1 · welcome",
                headline: "\(namedPrefix(for: user))you're in.",
                italic: ["in"],
                body: "i'm jeni, and i'll be right here every day. five minutes a day. that's all i'm asking. each day i'll teach you one true thing about your body. then we move. that's the whole method.",
                breathLine: "before we start: one slow breath. make the exhale the long part.",
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "math",
                illustration: "lesson_d1_science",
                eyebrow: "real talk",
                headline: "muscle changes the math.",
                italic: ["math"],
                body: "\(openReframe) kg for kg, muscle burns about three times more energy at rest than fat. the more muscle you carry, the more your body spends every day — even sitting still. most plans get this backwards.",
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "recomp",
                illustration: "lesson_d1_recomp",
                eyebrow: "one more thing",
                headline: "right now, you're in a rare window.",
                italic: ["rare window"],
                body: "shrink with eating-less alone and a quarter of what you lose isn't fat — it's muscle. less muscle, lower burn, and it creeps back. but if you're new to training, your body can do something rare: lose fat and build muscle at the same time. researchers call it recomposition. let's not miss it.",
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "plan",
                sticker: .heartGlossy,
                eyebrow: "your plan",
                headline: "you showed up. that's who we are now.",
                italic: ["showed up"],
                body: "the plan i built for you leans into \(bodyFocusPhrase(for: user)). short on purpose — five minutes done well beats forty you skip. this is what \(word) looks like at the start.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 2 — the exercise paradox (Pontzer 2016)

    private static func day2Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d2_paradox",
                eyebrow: "the thing nobody says",
                headline: "you can't out-burn the machine.",
                italic: ["out-burn"],
                body: "you ever crush a workout and the scale just shrugs? scientists tracked people who move a lot all day, and their bodies quietly spend less elsewhere to even it out. the treadmill number lies. but moving is still the best thing we know of for keeping weight off. not losing it fast. keeping it gone.",
                citation: "pontzer et al., current biology (2016)",
                breathLine: breathLine(day: 2),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .sparkleGlossy,
                eyebrow: "today",
                headline: "notice how you feel an hour after.",
                italic: ["how you feel"],
                body: "that feeling is the point. \(word) isn't earned in calories — it's built in showing up. so we stop treating a workout like something you pay for eating.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 3 — the invisible burn (NEAT)

    private static func day3Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d3_neat",
                eyebrow: "the invisible burn",
                headline: "your day burns more than your workout.",
                italic: ["your day"],
                body: "standing, walking, stairs, carrying things, even fidgeting — scientists call it NEAT. for a lot of women it adds up to more than a thirty-minute session, every single day, and it costs nothing. sit still for eight hours straight and it quietly disappears.",
                citation: "levine et al. · non-exercise activity thermogenesis",
                breathLine: breathLine(day: 3),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .butterflyRing,
                eyebrow: "today",
                headline: "stand and move two minutes, once an hour.",
                italic: ["once an hour"],
                body: "set a timer if you have to. \(word) gets built between sessions, not just during them.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 4 — stillness is training (isometrics, Edwards 2023)

    private static func day4Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d4_plank",
                eyebrow: "real talk",
                headline: "the boring hold wins.",
                italic: ["the boring hold"],
                body: "the biggest study ever on exercise and blood pressure looked at two hundred and seventy trials. the winner wasn't running. wasn't weights. wasn't sweaty intervals. it was holding still — planks, wall-sits. the quiet one beat all of them. that's why we plank. it looks like nothing. it's doing the most.",
                citation: "edwards et al., br j sports med (2023)",
                breathLine: breathLine(day: 4),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .flower3D,
                eyebrow: "today",
                headline: "hold one plank as long as feels steady.",
                italic: ["steady"],
                body: "a wall-sit counts too. stillness is real work. \(word) is quiet — it doesn't have to look impressive to be working.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 5 — walk right after you eat (Engeroff 2023)

    private static func day5Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d5_walk",
                eyebrow: "tiny, but mighty",
                headline: "walk right after you eat.",
                italic: ["right after"],
                body: "a slow walk in the first hour after a meal calms your blood-sugar spike more than the same walk done earlier. and the sooner you go, the better it works. no pace goal, no distance — just don't sit straight back down. ten easy minutes is the whole thing.",
                citation: "engeroff et al., sports medicine (2023)",
                breathLine: breathLine(day: 5),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .teacup,
                eyebrow: "today",
                headline: "after your biggest meal, walk ten easy minutes.",
                italic: ["ten easy minutes"],
                body: "around the block, around the kitchen — doesn't matter. \(word) is built from small, repeatable things. this is one.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 6 — small beats heroic (consistency)

    private static func day6Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d2_consistency",
                eyebrow: "the rule that wins",
                headline: "small you'll do beats heroic you won't.",
                italic: ["small you'll do"],
                body: "you came back. honestly, that's most of the whole thing. the people who keep weight off long-term aren't the ones who went hardest — study after study, they're the ones who kept showing up. five minutes you actually do beats forty-five you skip. even one rep is more than zero. always.",
                citation: "national weight control registry",
                breathLine: breathLine(day: 6),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .cherries,
                eyebrow: "today",
                headline: "if you can do five minutes, you do five.",
                italic: ["five minutes"],
                body: "don't let it become optional. \(word) looks boring up close. repeatable. that's the secret.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 7 — sixty-six days, not twenty-one (Lally 2010)

    private static func day7Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d7_habit",
                eyebrow: "real talk",
                headline: "it takes about sixty-six days. and that's okay.",
                italic: ["sixty-six days"],
                body: "you've heard it takes twenty-one days to build a habit. that's a myth. researchers tracked people forming a new habit and the real average was about sixty-six days. and the best part: missing one day didn't break the process at all. not even a little. so we're not chasing perfect. we're chasing most days.",
                citation: "lally et al., eur j social psychology (2010)",
                breathLine: breathLine(day: 7),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .starLineart,
                eyebrow: "today",
                headline: "aim for 'most days,' not 'every day.'",
                italic: ["most days"],
                body: "one miss is a non-event. truly. \(word) isn't a streak you can shatter — it's a direction you keep facing.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 8 — the return (what-the-hell effect, Polivy & Herman)

    private static func day8Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d8_return",
                eyebrow: "the trap",
                headline: "one slip doesn't undo you. the story does.",
                italic: ["the story does"],
                body: "here's the trap that ends more plans than any hard workout. psychologists call it the what-the-hell effect: you miss once, decide you've blown it, and that thought is what makes you quit. the missed day barely mattered. believing it ruined everything is what does the damage.",
                citation: "polivy & herman · restraint theory",
                breathLine: breathLine(day: 8),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .heartLock,
                eyebrow: "today, a promise",
                headline: "next time you miss, you come back small.",
                italic: ["come back small"],
                body: "open this and do one tiny thing. the return is the whole skill. \(word) isn't never falling — it's how fast you come back.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 9 — be your own friend (self-compassion, Adams & Leary 2007)

    private static func day9Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d9_kindness",
                eyebrow: "real talk",
                headline: "kindness gets you back on track. guilt doesn't.",
                italic: ["kindness"],
                body: "if a friend missed a workout, you wouldn't call her lazy and hopeless. so why do we do it to ourselves? this surprises people: being hard on yourself after a slip makes you more likely to give up, not less. the women who met a setback with self-kindness bounced back faster. guilt is the thing that quietly derails you.",
                citation: "adams & leary (2007)",
                breathLine: breathLine(day: 9),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .fluffyHeart,
                eyebrow: "today",
                headline: "talk to yourself like you'd talk to a friend.",
                italic: ["like a friend"],
                body: "when something doesn't go to plan, say it gently, then take the next small step. \(word) and gentle aren't opposites. the strongest people are kind to themselves first.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 10 — protein at every meal (ED-sensitive)

    private static func day10Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d4_protein",
                eyebrow: "one rule",
                headline: "protein at every meal. that's it.",
                italic: ["that's it"],
                body: "one rule. nothing to count, nothing off-limits. protein is the signal that tells your body 'keep this muscle' while you change, and it keeps you full longer. a palm-sized portion: chicken, fish, eggs, yogurt, tofu, beans. no apps, no tracking — just a glance: did i get protein in today? and you never earn food by working out. you eat because you're alive.",
                breathLine: breathLine(day: 10),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .peach,
                eyebrow: "today",
                headline: "a palm of protein on the plate, each meal.",
                italic: ["each meal"],
                body: "pick what you'll actually eat. \(word) doesn't come from skipping meals — it comes from fueling them.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 11 — enjoyment is the active ingredient (Keating 2017)

    private static func day11Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d11_enjoy",
                eyebrow: "real talk",
                headline: "the workout you'll repeat wins.",
                italic: ["you'll repeat"],
                body: "the whole 'no pain, no gain' thing? for fat loss, it's mostly a lie. when researchers compare brutal intervals to gentle steady movement, the fat-loss difference is tiny. what actually predicts results is whether you keep doing it. enjoyment isn't a bonus. it's the active ingredient.",
                citation: "keating et al., obesity reviews (2017)",
                breathLine: breathLine(day: 11),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .iceCream,
                eyebrow: "today",
                headline: "go at a pace you could almost talk through.",
                italic: ["almost talk through"],
                body: "easy counts. pick the version you don't dread — that's not settling, that's strategy. \(word) doesn't require punishment. it requires showing up again tomorrow.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 12 — exercise snacks (VILPA, Stamatakis 2022)

    private static func day12Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d12_snack",
                eyebrow: "the surprising part",
                headline: "a few one-minute bursts actually count.",
                italic: ["actually count"],
                body: "you don't always need a whole 'workout' for the win. a huge study followed people who never exercised. the ones who did just three or four minutes of quick, hard effort scattered through the day — fast stairs, hauling groceries — were linked to living longer and healthier. movement doesn't have to come in a thirty-minute block to matter.",
                citation: "stamatakis et al., nature medicine (2022)",
                breathLine: breathLine(day: 12),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .toteBag,
                eyebrow: "today",
                headline: "take one flight of stairs like you mean it.",
                italic: ["like you mean it"],
                body: "or carry the groceries in one trip. that's a snack. \(word) is built in tiny bursts most people never notice.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 13 — sleep is the multiplier

    private static func day13Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d5_sleep",
                eyebrow: "the multiplier",
                headline: "sleep is where the change happens.",
                italic: ["where the change happens"],
                body: "the thing that decides if all of this works isn't another workout. under-slept, your hunger hormones shift by morning — you wake up hungrier and reach for sugar without noticing. short sleep also keeps your stress hormone high, the one most tied to belly fat. you can train perfectly, and bad sleep will stall it. rest isn't the absence of work. it's part of the work.",
                citation: "spiegel et al. · sleep & appetite hormones",
                breathLine: breathLine(day: 13),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .cherub,
                eyebrow: "tonight",
                headline: "pick a bedtime and protect it.",
                italic: ["protect it"],
                body: "phone out of the room thirty minutes before. \(word) feels like being rested, not running on empty.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Day 14 — begin again (fresh-start effect, Dai/Milkman 2014)

    private static func day14Pages(user: JeniMethodUserContext) -> [LessonPage] {
        let word = identityFeelingWord(for: user)
        return [
            LessonPage(
                id: "fact",
                illustration: "lesson_d14_freshstart",
                eyebrow: "one last thing",
                headline: "you can always begin again.",
                italic: ["always"],
                body: "you made it two weeks. here's the part that keeps it going for good. any day can be a fresh start — a monday, the first of a month, a random tuesday. studies show we naturally find more motivation at these clean-slate moments. but you don't have to wait for one. you can decide today is the line.",
                citation: "dai, milkman & riis (2014)",
                breathLine: breathLine(day: 14),
                ctaLabel: "continue"
            ),
            LessonPage(
                id: "action",
                sticker: .bowIridescent,
                eyebrow: "from here",
                headline: "name your one tiny thing for tomorrow.",
                italic: ["one tiny thing"],
                body: "say it with a when: 'after my morning coffee, i'll move.' from here it's just you and the daily ritual, one day at a time. \(word) isn't a finish line. it's who you're becoming.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    // MARK: - Generic (Day 15+) — short pre-workout warmup

    /// Daily loop after the 14-day arc. One page: a calm rotating
    /// intention + breath cue, straight into the workout.
    private static func genericPages(user: JeniMethodUserContext) -> [LessonPage] {
        let intention = dailyIntention(for: .now)
        return [
            LessonPage(
                id: "warmup",
                sticker: .heartGlossy,
                eyebrow: "today",
                headline: "\(namedPrefix(for: user))good to see you.",
                italic: ["good to see you"],
                body: intention,
                breathLine: "one breath out. shoulders down. you're ready.",
                ctaLabel: "start today's workout",
                isHandoff: true
            ),
        ]
    }

    /// Three rotating one-line intentions for the generic warmup, picked
    /// by day-of-year so consecutive days differ. Form / breath / quality.
    private static func dailyIntention(for date: Date) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        switch day % 3 {
        case 0:  return "one thing today: quality over speed. a good slow rep beats three sloppy fast ones."
        case 1:  return "one thing today: breathe through the hard parts. don't hold it."
        default: return "one thing today: focus on form. the result follows the form."
        }
    }
}
